#!/bin/bash
# W1 [P-14] Host 行程被強制終止 → 其他 client 多久發現
#
# 需要兩個真實進程：Unity 不允許兩個實例開同一專案，故 client 用 w1-client 副本。
# 步驟：起 host → 等 session 就緒 → 起 client → 等 client 訂閱完成 → kill -9 host → 讀結果
set -u
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
BASE="/Users/arlong/Projects/Claude-Code-Game-Studios/prototypes"
OUT="$BASE/w1-p14-out"
rm -rf "$OUT"; mkdir -p "$OUT"

wait_for () { # $1=檔名 $2=秒數上限
  local i=0
  while [ ! -f "$OUT/$1" ] && [ $i -lt "$2" ]; do sleep 1; i=$((i+1)); done
  [ -f "$OUT/$1" ]
}

echo "[1/5] 啟動 host…"
"$U" -batchmode -nographics -projectPath "$BASE/w1-netcode" \
     -executeMethod W1Harness.RunHost -w1out "$OUT" \
     -logFile "$BASE/w1-p14-host.log" & HOST_PID=$!
echo "      host pid=$HOST_PID"

if ! wait_for host-ready.txt 240; then
  echo "FAIL: host 未就緒"; kill -9 $HOST_PID 2>/dev/null; exit 1
fi
echo "      session code=$(cat "$OUT/code.txt")"

echo "[2/5] 啟動 client…"
"$U" -batchmode -nographics -projectPath "$BASE/w1-client" \
     -executeMethod W1Harness.RunClient -w1out "$OUT" \
     -logFile "$BASE/w1-p14-client.log" & CLIENT_PID=$!

if ! wait_for client-armed.txt 300; then
  echo "FAIL: client 未完成訂閱"; kill -9 $HOST_PID $CLIENT_PID 2>/dev/null; exit 1
fi
echo "      client joined: $(cat "$OUT/client-joined.txt")"

echo "[3/5] 強制終止 host（kill -9，模擬行程被砍）…"
KILL_TS=$(date +%s)
kill -9 $HOST_PID 2>/dev/null
echo "      killed at $KILL_TS"

echo "[4/5] 等待 client 偵測…"
wait_for result.txt 100

echo "[5/5] 結果："
if [ -f "$OUT/result.txt" ]; then cat "$OUT/result.txt"; echo; else echo "NONE (timeout)"; fi
touch "$OUT/stop.txt"
kill -9 $CLIENT_PID 2>/dev/null
wait 2>/dev/null
