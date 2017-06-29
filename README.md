## About

## Architecture

This is a sketch of a microservice architecture using [Elixir](#) and [docker-compose](#), featuring
[command/query responsibility separation](#). The data flow is like this:

1. work is accepted via http POST on a web API
2. work is pushed onto a queue (Redis)
3. client is given a callback id, where they may check whether work is completed or not
4. pending work is popped from queue by workers
5. work is completed and result is written by worker to storage, with a TTL
6. (optional) given callback ID previously, client may retrieve completed work within TTL

Additionally, this architectural skeleton features a lightweight, self-contained
approach for automatic registration & clustering of the workers (elixir nodes).  
By self-contained we no consul to configure, and no zookeeper to install.  Under the
hood we use the vanilla docker Redis image dropped into docker-compose.yml, with
no additional hackery.  By "lightweight" we mean this registration is slightly
better than a mere toy, but by rejecting the feature set of something like
[libcluster](https://github.com/bitwalker/libcluster) we have no noisy UDP
broadcasting, etc etc.

Some will object that any networking amongst workers compromises
the "purity" of the architecture, since part of the point of command/query
separation is leveraging a principle of isolation that implies workers should not
*need* to communicate.  That's somewhat true, but on the other hand, nothing is
forcing them to communicate, and in the real world individual queue-worker-types
often gradually morph into more significant services in their own right.  

One might alternatively view this clustering impurity as a stepping stone
to a lightweight
"[service mesh](https://blog.buoyant.io/2017/04/25/whats-a-service-mesh-and-why-do-i-need-one/)",
since that term is in vogue lately, and marvel at how easy Erlang's VM makes it to take
 those first steps.  

 To quote from the [distributed task docs](https://elixir-lang.org/getting-started/mix-otp/distributed-tasks-and-configuration.html),

 > Elixir ships with facilities to connect nodes and exchange information between them. In fact, we use the same concepts of processes, message passing and receiving messages when working in a distributed environment because Elixir processes are location transparent. This means that when sending a message, it doesn’t matter if the recipient process is on the same node or on another node, the VM will be able to deliver the message in both cases.

## Prequisites

You need to have [docker](https://docs.docker.com/installation/) and [docker-compose](https://docs.docker.com/compose/install/) already installed.  An Elixir stack is not necessary on your dev host, rather, one will be provided and used via docker-compose.

## Usage & Demo

First bring up the system-monitor service, which will automatically start the
registration service (Redis).  After running the command below, then cluster
status and membership will be displayed in a loop on the terminal, and a
(unauthenticated!) web console is available at
[http://localhost:5984](http://localhost:5984).

    $ docker-compose up sysmon

Next, in another terminal, bring up the web API and one or more Elixir worker nodes.

    $ docker-compose up api
    $ docker-compose scale node=2

Scale up and down by changing the numeric values, and you can watch the system
monitor console as registration/peering automatically happens.  Post work to the
web API with curl, and note the callback ID in the response:

    $ curl -X POST http://localhost:5983/api/work?data=some-string-goes-here
    {callback: "callback_id"}

Check the status of submitted work with a command like what you see below.  Status
can be one of `accepted`, `pending`, or `done`.  For our purposes the "work" done
for all submissions is to pause 3 seconds, then return a random permutation of
the original input string.  Note that work status/completed work is removed
automatically after a timeout is reached, and requesting it after that point
from the web API simply results in a 404.

    $ curl -X GET http://localhost:5983/api/status/callback_id
    {status: "done", value: "eg-srgtm-reihsno-eose"}

It's also possible to make your Elixir node instances interactive (i.e. run the
node registration loop + open the iex shell).  Use this command (note the usage
  here of `run` vs `up`)

    $ docker-compose run shell

## Ideas for Extension

1. Add integration tests
1. Add more message and worker types
1. Add some treatment for retries/failures
1. Add support for polyglot workers, maybe using [erlport](#)
1. Incorporate [pubsub](https://github.com/whatyouhide/redix_pubsub)
1. Find a way to use [observer](#) with docker-compose (probably requires X11 on guest and XQuartz on host)
