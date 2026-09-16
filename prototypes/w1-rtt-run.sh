#!/bin/bash
# W1 [P-14] Host 行程被強制終止 → 其他 client 多久發現
#
# 需要兩個真實進程：Unity 不允許兩個實例開同一專案，故 client 用 w1-client 副本。
# 步驟：起 host → 等 session 就緒 → 起 client → 等 client 訂閱完成 → kill -9 host → 讀結果
set -u
TICK="${1:-10}"; REGION="${2:-}"
echo "[cfg] tick=$TICK region=${REGION:-(default)}"
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
BASE="/Users/arlong/Projects/Claude-Code-Game-Studios/prototypes"
OUT="$BASE/w1-rtt-out"
rm -rf "$OUT"; mkdir -p "$OUT"

wait_for () { # $1=檔名 $2=秒數上限
  local i=0
  while [ ! -f "$OUT/$1" ] && [ $i -lt "$2" ]; do sleep 1; i=$((i+1)); done
  [ -f "$OUT/$1" ]
}

echo "[1/5] 啟動 host…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-netcode" \
     -testPlatform PlayMode -testFilter "W1RttHost" -w1out "$OUT" -w1tick "$TICK" -w1region "$REGION" \
     -testResults "$BASE/w1-rtt-host-results.xml" \
     -logFile "$BASE/w1-rtt-host.log" & HOST_PID=$!
echo "      host pid=$HOST_PID"

if ! wait_for host-ready.txt 240; then
  echo "FAIL: host 未就緒"; kill -9 $HOST_PID 2>/dev/null; exit 1
fi
echo "      session code=$(cat "$OUT/code.txt")"

echo "[2/5] 啟動 client…"
"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-client" \
     -testPlatform PlayMode -testFilter "W1RttClient" -w1out "$OUT" -w1tick "$TICK" -w1region "$REGION" \
     -testResults "$BASE/w1-rtt-client-results.xml" \
     -logFile "$BASE/w1-rtt-client.log" & CLIENT_PID=$!

echo "[3/4] 量測 RTT 中（20 樣本，每 250ms 一次）…"
# RTT 的 client 只寫 rtt.txt（client-joined.txt 是 P-14 的協定，這裡沒有），
# 直接等最終結果；含 Unity 冷啟動＋登入＋加入，給 420 秒。
wait_for rtt.txt 420

echo "[4/4] 結果："
if [ -f "$OUT/rtt.txt" ]; then cat "$OUT/rtt.txt"; echo; else echo "NONE (timeout)"; fi
touch "$OUT/stop.txt"
sleep 3; kill -9 $CLIENT_PID $HOST_PID 2>/dev/null
wait 2>/dev/null
