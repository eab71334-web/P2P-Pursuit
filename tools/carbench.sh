#!/bin/bash
# usage: tools/carbench.sh [car]   -> prints 0-100, top speed, braking per car in Realistic mode
set -e
SRC=${SRC:-/home/claude/p2p-pursuit}
rm -rf /tmp/bench && mkdir -p /tmp/bench && cp -r $SRC/. /tmp/bench/ && cd /tmp/bench
cat > bench.tscn <<'S'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tools/carbench.gd" id="1"]
[node name="Bench" type="Node3D"]
script = ExtResource("1")
S
godot --headless --path . --import >/dev/null 2>&1 || true
CAR=$1 timeout ${T:-300} godot --headless --path . --fixed-fps 60 res://bench.tscn 2>&1 | grep -v "ALSA\|JSON\|WARNING\|^$\|CANT_OPEN\|^   at"
