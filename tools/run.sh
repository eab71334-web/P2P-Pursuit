#!/bin/bash
# usage: tools/run.sh <mode> ; copies project to /tmp/t, injects the harness, runs under Xvfb
set -e
SRC=/home/claude/rally-lan
rm -rf /tmp/t && mkdir -p /tmp/t /tmp/shots && cp -r $SRC/. /tmp/t/ && cd /tmp/t
cp tools/auto.gd scripts/auto.gd
[ "$1" != intro ] && sed -i 's|scenes/intro.tscn|scenes/main.tscn|' project.godot
sed -i 's|^Profile=.*|&\nAuto="*res://scripts/auto.gd"|' project.godot
godot --headless --path . --import >/dev/null 2>&1 || true
GFXP=${GFXP:-} FORCE_TOUCH=${TOUCH:-} AUTO=$1 SHOT_DIR=/tmp/shots timeout ${2:-90} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 2>&1 | grep -v "^$" | tail -${3:-30}
