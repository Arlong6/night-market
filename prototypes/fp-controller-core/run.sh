#!/bin/sh
# 第一人稱控制器核心原型 — 編譯並執行 T0 驗收（AC1–AC31）
# 本機無 dotnet SDK，使用 Unity 6.3 內附的 Mono（mcs 上限 C# 7.2，是專案目標 C# 9.0 的子集）
set -e
M="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/Resources/Scripting/MonoBleedingEdge/bin"
if [ ! -x "$M/mcs" ]; then
  echo "找不到 Unity 內附的 Mono：$M"
  exit 127
fi
cd "$(dirname "$0")"
"$M/mcs" -langversion:7.2 -out:tests.exe FpController.cs Tests.cs
exec "$M/mono" tests.exe
