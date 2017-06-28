## About

## Architecture

## Prequisites

You need to have docker and docker-compose already installed.  An Elixir stack
is not necessary on your dev host, rather one will be used via docker-compose.

## Demo

First bring up the system-monitor service, which will automatically start the registration service (Redis).  
Cluster status and membership will be displayed in a loop on the terminal, and a (unauthenticated!) web console
 is available at [http://localhost:5984](http://localhost:5984).

    $ docker-compose up sysmon

Next, in another terminal, bring up one or more Elixir nodes.  (I call these EVMs for "elixir virtual machines", simply because "Node" and "Agent", etc are both already used as specific terminology in Elixir).

    $ docker-compose scale evm=2

Scale up and down, and watch the system monitor console as registration/peering automatically happens.

It's possible to make your agent instance interactive (i.e. open the iex shell+agent registration loop).  Use this command (note the usage of `run` vs `up`)

    $ docker-compose run shell

## Integration Tests

## Extending
