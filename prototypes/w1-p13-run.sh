#!/bin/bash
# W1 [P-13] — 瀏覽器關分頁時 WebSocket close frame 是否送達
# host 在 batchmode 等瀏覽器的 NGO client 連上，再量它消失得多快。
# 時間基準借用 [P-18] 的 beacon（beforeunload 時送出，伺服器記時）。
set -u
REGION="${1:-asia-northeast1}"
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
BASE="/Users/arlong/Projects/Claude-Code-Game-Studios/prototypes"
OUT="$BASE/w1-p13-out"
rm -rf "$OUT"; mkdir -p "$OUT"
rm -f "$BASE/w1-netcode/Build/beacons.log"

"$U" -runTests -batchmode -nographics -projectPath "$BASE/w1-netcode" \
     -testPlatform PlayMode -testFilter "W1WebHostRole" -w1out "$OUT" \
     -w1region "$REGION" -testResults "$BASE/w1-p13-host.xml" \
     -logFile "$BASE/w1-p13-host.log" &
echo "host pid=$!"
/usr/bin/python3 "$BASE/w1-beacon-server.py" 8131 "$BASE/w1-netcode/Build/Web-gzip-native" &
echo "beacon-server pid=$!"
