#!/bin/bash
set -xeuo pipefail
IFS=$'\n\t'
tmux kill-session -a
docker-compose down -t 1
docker-compose up -d redis
docker-compose up -d api
docker-compose up -d lb
tmux new-session -d -s demo 'docker-compose logs -f api'
tmux rename-window 'demo'
tmux selectp -t demo
tmux split-window -t demo 'docker-compose up sysmon'
# tmux split-window -t demo 'watch -n 1 date'
# tmux set-window-option -g window-status-current-bg blue
# tmux split-window -t demo 'watch -n 1 docker-compose ps'
tmux split-window -t demo 'docker-compose up worker'
# tmux select-layout even-vertical
tmux select-layout tiled
tmux split-window -t demo 'bash'
tmux attach -t demo
