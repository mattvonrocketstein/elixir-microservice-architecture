#!/usr/bin/env bash
source common.sh
elixir --sname api --cookie $COOKIE -S mix start.api
