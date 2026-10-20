#!/bin/bash
# Renders demo screenshots of the panel into marketing/snapshots/
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); OUT=marketing/snapshots; mkdir -p $OUT
sed 's/^@main$//' Sources/App.swift > $T/App.swift
swiftc -swift-version 5 -o $T/snap $T/App.swift Sources/AudioEngine.swift Sources/Bluetooth.swift Tools/snapshots.swift
$T/snap "$PWD/$OUT"
