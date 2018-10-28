## About


This is a sketch of a microservice architecture using
[Elixir](https://elixir-lang.org/), Redis, HAProxy, and
[docker-compose](https://docs.docker.com/compose/).  It showcases a kind of
[command/query responsibility separation](https://martinfowler.com/bliki/CQRS.html), a load-balanced web API, and clustered queue-workers that are capable of message-passing amongst themselves.
<br/>
<br/>
<br/>
<a href=diagram.png><img src=diagram.png width=100%></a>


## Data Flow

For the purposes of this architectural skeleton, the data flow is like this:

1. work is accepted via http POST on a [web API](lib/api.ex)
1. work is pushed by API onto a queue (Redis)
1. the web API returns unique callback id, where client may check work status
1. pending work is popped from queue by elixir workers (separate docker instances)
1. work is completed and result is written by worker to storage (also Redis), with a TTL
1. (optional) given callback ID previously, client may retrieve completed work within TTL

## Clustering

This architectural skeleton also features a lightweight, self-contained approach for automatic registration & clustering of the queue workers (Elixir nodes).  

1. *Clustering* means nodes may communicate by engaging in message passing, and even process spawning
1. *Self-contained* means there is no external consul to configure, and no zookeeper to install, etc. Under the hood a plain docker Redis image is dropped into [docker-compose.yml](docker-compose.yml) with no additional hackery.  
1. *Lightweight* means this registration mechanism is somewhat better than a toy, but by avoiding the complexity of something like [libcluster](https://github.com/bitwalker/libcluster) we also lose the huge feature set.  For better our worse, this approach has no hardcoded host/seed lists, no noisy UDP broadcasting, no kubernetes prerequisites, etc etc.

Some might (reasonably) object that any networking/message-passing amongst workers compromises the "purity" of the architecture, since part of the point of queue workers and command/query separation is leveraging a *principle of isolation* that implies workers should not *need* to communicate.  That's true, but on the other hand,

1. nothing is forcing workers to communicate
1. individual queue-worker types often gradually morph into more significant services in their own right
1. and besides, Erlang VM clustering is extremely interesting :)

One might alternatively view this worker-clustering impurity as a stepping stone to a lightweight "[service mesh](https://blog.buoyant.io/2017/04/25/whats-a-service-mesh-and-why-do-i-need-one/)" since that term is in vogue lately, and marvel at how easy Elixir / Erlang's VM makes it to take those first steps.  

 To quote from the [distributed task docs](https://elixir-lang.org/getting-started/mix-otp/distributed-tasks-and-configuration.html),

 > Elixir ships with facilities to connect nodes and exchange information
between them. In fact, we use the same concepts of processes, message passing
and receiving messages when working in a distributed environment because Elixir
processes are location transparent. This means that when sending a message, it
doesn’t matter if the recipient process is on the same node or on another node,
the VM will be able to deliver the message in both cases.

## Prequisites

An Elixir stack is not necessary on your dev host, rather, one will be provided and used via docker-compose.

You need to have [docker](https://docs.docker.com/installation/) and [docker-compose](https://docs.docker.com/compose/install/) already installed.

For the purposes of the demos and dashboards that appear in this documentation, you'll also need `tmux`, `curl`, and `jq` which you can install with the package manager of your choice (including homebrew).

## Build the software

You can build the software by using the docker proxies for standard elixir mix commands.

```
$ docker-compose up deps.get
$ docker-compose up compile
```

## Usage & Demo

### Dashboard

A `tmux` based dashboard for simulating the whole distributed system on your local environment can be launched with a single command:

```
bash dashboard.sh
```

### Step by Step

If you prefer to use separate terminals rather than a consolidated dashboard, follow the commands below in sequence.  Service-level dependencies are declared in docker-compose, but in some cases order still matters in the steps below.

**1. Start Queue & Registration Service**

Queuing is done with redis, and you normally want this in the background.  It's even ok if you don't do this explicitly, the [docker-compose.yml](docker-compose.yml) file ensures it will be started when required by other services.

```
$ docker-compose up -d redis
```

**2. Start System-monitor Service** in the foreground, which will automatically start the registration service (Redis).  After running the command below, then cluster status and membership will be displayed in a loop on the terminal, and a (*unauthenticated!*) web console is available at [http://localhost:5984](http://localhost:5984).

```
$ docker-compose up sysmon
```

**3. Start one or more Elixir worker nodes** in the foreground of another terminal.  Scale up and down by changing the numeric value in the command below, and you can watch the system monitor console as registration/peering automatically updates.  

```
$ docker-compose scale worker=2
```

**4. Start one or more API nodes** in the background, so we can POST and GET work to them.  You can ensure it started ok afterwards by using the `logs` or `ps` subcommands.  

```
$ docker-compose scale api=2
$ docker-compose ps
```

**5. Start the HAProxy load balancer** in the background, so the API instances are actually accessible from "outside".  You can ensure it started ok afterwards by using the `logs` or `ps` subcommands.  The LB depends on the API services.  If you're trying live-coding changes into the API server, you may need to restart the LB.

```
$ docker-compose up -d lb
$ docker-compose logs lb
```

### Exercising the System

#### POSTing work with curl

**POSTing static data** can be done with a command like what you see below.  Note the callback ID in the response, which is just a simple hash of the input data.

Because of the way work is hashed into a callback.. this is deterministic.  (Since there's a predictable callback here, we'll use the hash below later to check on the work status)

```
curl -s -XPOST -d '{"data":"foo"}' http://localhost/api/v1/work | jq
{
  "accepted_by": "api@62e5542039f7",
  "callback": "ACBD18DB4CC2F85CEDEF654FCCC4A4D8",
  "data": "foo",
  "status": "accepted"
}
```

You can post more dynamic data using shell-interpolation that fills in the current date time.  By running this command repeatedly and inspecting the `accepted_by` field, you can also confirm that the load balancer is hitting different instances of the web API.  If this command produces no output.. the load-balancer may need to be restarted.

```
$ curl -s -XPOST -d "{\"data\":\"`date`\"}" http://localhost/api/v1/work | jq
{
  "accepted_by": "api@f5cc90c08c73",
  "callback": "1E9F3958A4A792599AEF156CA7223C86",
  "data": "Sat Oct 27 23:05:22 EDT 2018",
  "status": "accepted"
}
```

#### Check the status of submitted work

Work status is always one of `accepted`, `pending`, `working`, or `worked`. For our purposes the "work" done for all input submissions is to just pause a few seconds.  Note that the record for completed work is removed automatically after a timeout is reached, and requesting it after that point from the web API simply results in a 404.  This TTL prevents the need for additional janitor processes acting against the data store, etc.

```
$ curl -X GET http://localhost/api/v1/work/ACBD18DB4CC2F85CEDEF654FCCC4A4D8
{status: "pending"}

$ curl -X GET http://localhost/api/v1/work/ACBD18DB4CC2F85CEDEF654FCCC4A4D8
{status: "working"}

$ curl -X GET http://localhost/api/v1/work/ACBD18DB4CC2F85CEDEF654FCCC4A4D8
{status: "worked"}

$ curl -X GET http://localhost/api/v1/work/ACBD18DB4CC2F85CEDEF654FCCC4A4D8
{"status":"404. not found!"}
```

## Further Experiments

#### Inspect the environment with the shell

To make your dockerized Elixir node instances interactive (i.e. run the node registration loop + open the iex shell), use this command (note the usage here of `run` vs `up`)

```
$ docker-compose run shell
```

####  Simulate network failures

If you like, just to show that Elixir/Erlang style "[happy path](https://en.wikipedia.org/wiki/Happy_path)" coding is really working and that this system is crash resistant and self-healing.  

Try taking down Redis while watching the system monitor,  and you'll see that while registration and cluster-join tasks will fail repeatedly, neither our monitor or our workers should crash when they can't read/write registration data.

```
$ docker-compose stop redis
```

Bring Redis back up and keep an eye on the system monitor to watch the system recover:

```
$ docker-compose up redis
```

## Caveats

**Is this ProductionReady™?**  Not exactly, although tools like [kompose](https://github.com/kubernetes-incubator/kompose) and [ecs-cli compose](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/cmd-ecs-cli-compose.html) continue to improve, and are making additional work at the infrastructure layer increasingly unnecessary.

At the architecture layer, the cluster registration ledger should really be separate from the work-tracking K/V store.  In this case for simplicity, we use the same Redis instance for both.

At the application layer, there is only a naive hashing algorithm to generate keys, little to no treatment of duplicate work submissions, retries, etc.  

## Ideas for Extension

- [ ] Add integration/infrastructure tests
- [ ] Just for fun, split registration/work tracking persistence among redis and cassandra instead of using 1 data store
- [ ] Add some treatment for retries/failures
- [ ] Add a brief guide for production(ish) deployments
- [ ] Testing with `ecs-cli compose` for AWS and `kompose` for kubernetes translations
- [ ] Add demo for polyglot workers, maybe using [erlport](http://erlport.org/docs/python.html)
- [ ] Add demo for [pubsub](https://github.com/whatyouhide/redix_pubsub)
- [ ] Find a way to use [observer](https://www.packtpub.com/mapt/book/application_development/9781784397517/1/ch01lvl1sec15/inspecting-your-system-with-observer) with docker-compose (probably requires X11 on guest and XQuartz on OSX host)
- [ ] Add more worker types and message types, exploring the line between plain queue-workers and [AOP](https://en.wikipedia.org/wiki/Agent-oriented_programming) with [ACLs](https://en.wikipedia.org/wiki/Agent_Communications_Language)
