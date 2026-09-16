#!/bin/bash
# W1 [P-20](b) ownership transfer 實機行為 — 兩個進程
# 用法：./w1-own-run.sh [tick] [region]
set -u
TICK="${1:-10}"; REGION="${2:-asia-northeast1}"
echo "[cfg] tick=$TICK region=$REGION"
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
BASE="/Users/arlong/Projects/Claude-Code-Game-Studios/prototypes"
OUT="$BASE/w1-own-out"
rm -rf "$OUT"; mkdir -p "$OUT"

wait_for () { local i=0; while [ ! -f "$OUT/$1" ] && [ $i -lt "$2" ]; do sleep 2; i=$((i+2)); done; [ -f "$OUT/$1" ]; }

echo "[1/3] 啟動 host…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-netcode" \
     -testPlatform PlayMode -testFilter "W1OwnHost" -w1out "$OUT" \
     -w1tick "$TICK" -w1region "$REGION" \
     -testResults "$BASE/w1-own-host-results.xml" -logFile "$BASE/w1-own-host.log" & HOST_PID=$!

if ! wait_for host-ready.txt 300; then
  echo "FAIL: host 未就緒"; kill -9 $HOST_PID 2>/dev/null; exit 1
fi
echo "      session code=$(cat "$OUT/code.txt")"

echo "[2/3] 啟動 client…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-client" \
     -testPlatform PlayMode -testFilter "W1OwnClient" -w1out "$OUT" \
     -w1tick "$TICK" -w1region "$REGION" \
     -testResults "$BASE/w1-own-client-results.xml" -logFile "$BASE/w1-own-client.log" & CLIENT_PID=$!

echo "[3/3] 掃描中（8 個延遲值 × 3 次，每次約 3 秒）…"
wait_for ownership.txt 900

if [ -f "$OUT/ownership.txt" ]; then cat "$OUT/ownership.txt"; else echo "NONE (timeout)"; fi
sleep 3; kill -9 $CLIENT_PID $HOST_PID 2>/dev/null
wait 2>/dev/null
