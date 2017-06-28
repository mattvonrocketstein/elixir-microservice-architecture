#!/usr/bin/env bash
source common.sh
iex --no-halt --sname shell --cookie $COOKIE -S mix run
