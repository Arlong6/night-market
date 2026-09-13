# Unity 6.3 LTS — Current Best Practices（訓練截止後的實務變化）

> Last verified: 2026-09-03

## URP / 渲染

- **Render graph 是唯一路徑**（Compatibility Mode 已在 6.3 移除）——所有自訂 pass 一開始就寫 render graph
- 6.1 新增 **Deferred+** 渲染路徑；PSO ahead-of-time shader 編譯減卡頓
- 6.3 新增 **Kawase/Dual bloom**（低階裝置便宜很多——Web 目標優先用）
- 6.3 起 Shader Graph 可做 URP 自訂 lighting、terrain、UI material；`unity_RendererUserValue` 做 per-renderer 材質變化
- 本專案（低多邊形＋Web）：URP + 少量 Shader Graph；避免自訂 Renderer Feature 除非必要

## Input System

- 6.3 世代為 Input System 1.14–1.15
- **Project-wide Actions（`InputSystem.actions`）是標準做法**，也是 `PlayerInput` 的預設 actions
- 設定搬到 Project Settings → "Input System Package"

## UI Toolkit vs UGUI

- UI Toolkit 在此窗口大幅補強 runtime：**World Space UI（6.2）**、runtime data binding、
  USS filters（6.3：opacity/tint/grayscale/blur）、UI Test Framework 套件（6.3）、
  glyph-level 文字動畫（6.3）
- 官方定位：資料驅動／螢幕 UI 用 UI Toolkit；重動畫的 diegetic/世界內 UI 用 UGUI 仍可
- 本專案：HUD／大廳／結算用 UI Toolkit；客人頭頂需求圖示屬世界內顯示，可用 World Space UI（6.2+）或簡單 quad

## 專案設定建議（本專案）

- 平台：Web（6.0 起改名，不叫 WebGL）；WebGPU 在 6.3 仍是實驗性——**不要用**，走 WebGL2
- 壓縮：Brotli；考慮開 **WebAssembly 2023** 目標（原生例外、SIMD、較小體積；需現代瀏覽器）
- Scripting backend：Web 一律 IL2CPP；Managed Stripping High（配 link.xml 保 NGO 反射需求——NGO 2.6+ 已改 codegen，實測為準）
- C# 語言層：**C# 9.0**，見 deprecated-apis.md 的語言層警告
