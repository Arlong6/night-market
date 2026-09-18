#!/bin/bash
# W1 第 5 批 — 傳輸層斷線語義（[P-8]／[P-14]／[P-15]）
# 用法：./w1-disc-run.sh graceful|kill [region]
set -u
MODE="${1:-graceful}"; REGION="${2:-asia-northeast1}"
echo "[cfg] mode=$MODE region=$REGION"
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
BASE="/Users/arlong/Projects/Claude-Code-Game-Studios/prototypes"
OUT="$BASE/w1-disc-out-$MODE"
rm -rf "$OUT"; mkdir -p "$OUT"

wait_for () { local i=0; while [ ! -f "$OUT/$1" ] && [ $i -lt "$2" ]; do sleep 1; i=$((i+1)); done; [ -f "$OUT/$1" ]; }

echo "[1/4] 啟動 host…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-netcode" \
     -testPlatform PlayMode -testFilter "W1DiscHost" -w1out "$OUT" \
     -w1region "$REGION" -w1mode "$MODE" \
     -testResults "$BASE/w1-disc-host-$MODE.xml" -logFile "$BASE/w1-disc-host-$MODE.log" & HOST_PID=$!
echo "      host pid=$HOST_PID"
if ! wait_for host-ready.txt 300; then echo "FAIL: host 未就緒"; kill -9 $HOST_PID 2>/dev/null; exit 1; fi

echo "[2/4] 啟動 client…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-client" \
     -testPlatform PlayMode -testFilter "W1DiscClient" -w1out "$OUT" \
     -w1region "$REGION" -w1mode "$MODE" \
     -testResults "$BASE/w1-disc-client-$MODE.xml" -logFile "$BASE/w1-disc-client-$MODE.log" & CLIENT_PID=$!

if ! wait_for client-armed.txt 400; then
  echo "FAIL: client 未就緒"; kill -9 $HOST_PID $CLIENT_PID 2>/dev/null; exit 1; fi
echo "      client 已開始計時"

if [ "$MODE" = "kill" ]; then
  # host 自己寫下 action 時刻後才殺，確保時間基準一致
  wait_for host-action-at.txt 60
  sleep 2
  echo "[3/4] kill -9 host（pid=$HOST_PID）…"
  kill -9 $HOST_PID 2>/dev/null
  /usr/bin/python3 -c "import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat())" > "$OUT/shell-killed-at.txt"
else
  echo "[3/4] host 走 graceful Shutdown()，等 client 回報…"
fi

wait_for result.txt 300
echo "[4/4] 結果："
[ -f "$OUT/result.txt" ] && cat "$OUT/result.txt" || echo "NONE (timeout)"
[ -f "$OUT/host-shutdown-returned-ms.txt" ] && echo "Shutdown() 回傳耗時: $(cat "$OUT/host-shutdown-returned-ms.txt") ms"
echo
sleep 2; kill -9 $CLIENT_PID $HOST_PID 2>/dev/null; wait 2>/dev/null
