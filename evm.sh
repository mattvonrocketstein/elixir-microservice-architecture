#!/usr/bin/env bash
source common.sh
elixir --sname $name --cookie $COOKIE -S mix start.evm #tmp.exs
