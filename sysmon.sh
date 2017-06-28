#!/usr/bin/env bash
source common.sh
elixir --sname sysmon --cookie $COOKIE -S mix start.sysmon 
