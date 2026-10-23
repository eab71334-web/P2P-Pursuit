#!/bin/bash
# Starts the three online rooms (one process per mode). Run on any Linux machine with a public IP.
# Open UDP ports 24570-24572 in the firewall / router.
cd "$(dirname "$0")"
BIN=./rally-server.x86_64
$BIN --headless -- --server --port=24570 --teams=1 &
$BIN --headless -- --server --port=24571 --teams=2 &
$BIN --headless -- --server --port=24572 --ffa=4 &
wait
