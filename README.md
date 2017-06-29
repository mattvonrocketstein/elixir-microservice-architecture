## About


This is a sketch of a microservice architecture using
[Elixir](https://elixir-lang.org/) and
[docker-compose](https://docs.docker.com/compose/), featuring
[command/query responsibility separation](https://martinfowler.com/bliki/CQRS.html).  


## CQRS

For the purposes of this architectural skeleton, the data flow is like this:

1. work is accepted via http POST on a web API
1. work is pushed by API onto a queue (Redis)
1. web API returns unique callback id, where client may check work status
1. pending work is popped from queue by elixir workers (separate docker instances)
1. work is completed and result is written by worker to storage (also Redis), with a TTL
1. (optional) given callback ID previously, client may retrieve completed work within TTL

## Clustering

Additionally, this architectural skeleton features a lightweight, self-contained approach for automatic registration & clustering of the workers (elixir nodes).  By self-contained we mean there is no consul to configure, and no zookeeper to install.  Under the hood a plain docker Redis image is dropped into [docker-compose.yml](docker-compose.yml), with no additional hackery.  By "lightweight" we mean this registration is better than a mere toy, but by avoiding the complexity of something like [libcluster](https://github.com/bitwalker/libcluster) we also lose the huge feature set.  As a result our approach has no hardcoded host lists, no noisy UDP broadcasting, no kubernetes prerequisites, etc.

Some will object that any networking amongst workers compromises the "purity" of the architecture, since part of the point of command/query separation is leveraging a *principle of isolation* that implies workers should not *need* to communicate.  That's true, but on the other hand, nothing is forcing them to communicate, and in the real world individual queue-worker types often morph gradually into more significant services in their own right.  

One might alternatively view this clustering impurity as a stepping stone to a lightweight "[service mesh](https://blog.buoyant.io/2017/04/25/whats-a-service-mesh-and-why-do-i-need-one/)" since that term is in vogue lately, and marvel at how easy Elixir / Erlang's VM makes it to take those first steps.  

 To quote from the [distributed task docs](https://elixir-lang.org/getting-started/mix-otp/distributed-tasks-and-configuration.html),

 > Elixir ships with facilities to connect nodes and exchange information
between them. In fact, we use the same concepts of processes, message passing
and receiving messages when working in a distributed environment because Elixir
processes are location transparent. This means that when sending a message, it
doesn’t matter if the recipient process is on the same node or on another node,
the VM will be able to deliver the message in both cases.

## Prequisites

You need to have [docker](https://docs.docker.com/installation/) and [docker-compose](https://docs.docker.com/compose/install/) already installed.  An Elixir stack is not necessary on your dev host, rather, one will be provided and used via docker-compose.

## Usage & Demo

**Start Queue & Registration Service** in the background.  It's usually ok if you don't do this explicitly, [docker-compose.yml](docker-compose.yml) ensures it will be started when required by other services.

    $ docker-compose up -d redis


**Start System-monitor Service** in the foreground, which will automatically start the registration service (Redis).  After running the command below, then cluster status and membership will be displayed in a loop on the terminal, and a (*unauthenticated!*) web console is available at [http://localhost:5984](http://localhost:5984).

    $ docker-compose up sysmon

**Start one or more Elixir worker nodes** in the foreground of another terminal.  Scale up and down by changing the numeric value in the command below, and you can watch the system monitor console as registration/peering automatically updates.  

    $ docker-compose scale node=2

**Start the Web API** in the background, so we can POST and GET work from it.

    $ docker-compose up -d api

**POSTing work to the web API with curl**, can be done like so.  Note the callback ID in the response:

    $ curl -XPOST -d '{"data":"foo"}' http://localhost:5983/api/work
    {status: "accepted", callback: "callback_id"}

**Check the status of submitted work** with a command like what you see below.  Status can be one of `accepted`, `pending`, or `done`.  (For our purposes the "work" done for all input submissions is to pause a few seconds, then return a random permutation of the original input string.)  Note that this record for work status/completed work is removed automatically after a timeout is reached, and requesting it after that point from the web API simply results in a 404.

    $ curl -X GET http://localhost:5983/api/status/callback_id
    {status: "done", value: "eg-srgtm-reihsno-eose"}


**Inspect the environment with the shell** if you like.  To make your dockerized Elixir node instances interactive (i.e. run the node registration loop + open the iex shell), use this command (note the usage here of `run` vs `up`)

    $ docker-compose run shell

**Simulate network failures** if you like, just to show that Elixir/Erlang style "[happy path](https://en.wikipedia.org/wiki/Happy_path)" coding is really working and that this system is crash resistant and self-healing.  

Try taking down Redis while watching the system monitor,  and you'll see that while registration and cluster-join tasks will fail repeatedly, neither our monitor or our workers should crash when they can't read/write registration data.

    $ docker-compose stop redis

Bring Redis back up and keep an eye on the system monitor to watch the system recover:

    $ docker-compose up redis

## Ideas for Extension

1. Add integration tests
1. Add some treatment for retries/failures
1. Add a brief guide for production-ready deployments
1. Test with [kompose](https://github.com/kubernetes-incubator/kompose) for kubernetes translations
1. Add support for polyglot workers, maybe using [erlport](#)
1. Incorporate [pubsub](https://github.com/whatyouhide/redix_pubsub)
1. Find a way to use [observer](https://www.packtpub.com/mapt/book/application_development/9781784397517/1/ch01lvl1sec15/inspecting-your-system-with-observer) with docker-compose (probably requires X11 on guest and XQuartz on host)
1. Add more worker types and message types, exploring the line between plain queue-workers and [agent oriented programming](https://en.wikipedia.org/wiki/Agent-oriented_programming) with [agent communicational languages](https://en.wikipedia.org/wiki/Agent_Communications_Language)
