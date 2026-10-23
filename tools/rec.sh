#!/bin/bash
# usage: tools/rec.sh <mode> <out.avi> [seconds] [fps] ; records game video+audio with Godot's movie writer
set -e
SRC=/home/claude/rally-lan
rm -rf /tmp/t && mkdir -p /tmp/t /tmp/shots && cp -r $SRC/. /tmp/t/ && cd /tmp/t
cp tools/auto.gd scripts/auto.gd
[ "$1" != intro ] && sed -i 's|scenes/intro.tscn|scenes/main.tscn|' project.godot
sed -i 's|^Profile=.*|&\nAuto="*res://scripts/auto.gd"|' project.godot
godot --headless --path . --import >/dev/null 2>&1 || true
FORCE_TOUCH=${TOUCH:-} AUTO=$1 SHOT_DIR=/tmp/shots timeout ${3:-300} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --write-movie $2 --fixed-fps ${4:-24} 2>&1 | tee /tmp/rec.log | grep -v "^$" | tail -5
