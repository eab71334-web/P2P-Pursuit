#!/bin/bash
# usage: tools/art.sh square|cover  -> /tmp/shots/icon_<mode>.png
set -e
SRC=/home/claude/rally-lan
rm -rf /tmp/t && mkdir -p /tmp/t /tmp/shots && cp -r $SRC/. /tmp/t/ && cd /tmp/t
cp tools/auto.gd scripts/auto.gd
sed -i 's|scenes/intro.tscn|scenes/main.tscn|' project.godot
sed -i 's|^Profile=.*|&\nAuto="*res://scripts/auto.gd"|' project.godot
godot --headless --path . --import >/dev/null 2>&1 || true
if [ "$1" = cover ]; then R=1920x1080; else R=1024x1024; fi
ICON_MODE=$1 AUTO=icon SHOT_DIR=/tmp/shots timeout 90 xvfb-run -a -s "-screen 0 ${R}x24" godot --path . --rendering-driver opengl3 --resolution $R 2>&1 | grep -E "SCRIPT ERROR|SHOT" | head
