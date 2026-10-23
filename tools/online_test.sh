#!/bin/bash
# local online test: 1 headless server + 2 harness clients on this machine
set -e
cd /home/claude/rally-lan
tools/run.sh none 4 1 >/dev/null 2>&1 || true
cd /tmp/t
pkill -x godot || true
godot --headless --path . -- --server --ffa=2 > /tmp/srv.log 2>&1 &
sleep 4
for n in A B; do
  AUTO=online NAME=$n SHOT_DIR=/tmp/shots timeout 60 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 > /tmp/cl$n.log 2>&1 &
done
wait %2 %3 || true
sleep 1
echo "--- server"; grep -v "^$" /tmp/srv.log | tail -15
echo "--- A"; grep -E "JOIN|CLOSED|INGAME|SCENE|SCRIPT" /tmp/clA.log | head
echo "--- B"; grep -E "JOIN|CLOSED|INGAME|SCENE|SCRIPT" /tmp/clB.log | head
pkill -x godot || true
