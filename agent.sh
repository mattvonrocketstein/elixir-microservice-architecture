#!/usr/bin/env bash
source common.sh
elixir --sname $name --cookie $COOKIE -S mix start.agent #tmp.exs
