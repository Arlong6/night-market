# Module: Web Platform（Unity 6.3 LTS）

> Last verified: 2026-09-03
> 主要來源：https://docs.unity3d.com/Manual/webgl-networking.html 、
> https://docs.unity3d.com/6000.3/Documentation/Manual/wasm-2023-features.html

## 名稱與現況

- Build target 叫 **Web**（6.0 起；文件網址仍常見 `webgl-*`）
- 圖形：WebGL2 為預設且唯一生產可用；**WebGPU 在 6.3 仍為實驗性，禁用於本專案**（6.6 才轉正——那不是我們的版本）
- 手機瀏覽器：官方支援（部分瀏覽器），體積是最大關鍵

## 網路限制（本專案命脈）

- **瀏覽器無 TCP/UDP socket**——`System.Net.Sockets` 全滅
- `UnityWebRequest` 可用（底層是 Fetch）
- WebSocket：Unity Transport (UTP) 提供 `WebSocketNetworkInterface`，僅限 UTP↔UTP 連線
  （不是通用 WebSocket client）；NGO 走 UTP WebSocket 支援 Web
- HTTPS 頁面只能連 **wss**（瀏覽器擋不安全 ws）——itch.io 是 HTTPS，一律 wss
- 詳見 `modules/multiplayer.md`

## 體積與效能槓桿

- 6.3：IL2CPP metadata 變長度索引 → 體積縮小；Emscripten 原生跑 Apple Silicon（建置變快）
- **WebAssembly 2023** 開關：原生 Wasm 例外、SIMD、優化 memcpy、BigInt 互通——
  效能升、體積降，需現代瀏覽器（本專案目標客群 OK，建議開）
- 壓縮 Brotli；Strip Engine Code；Managed Stripping High（實測 NGO 相容性）
- 音訊：首次使用者手勢前不可自動播放（跟 Godot web 相同——標題畫面點擊開始的模式沿用）
- Web Profiler 可用裝置 IP attach 到執行中的 build（6.3）

## 本專案硬指標

- 壓縮後下載 ≤ 50MB（支柱「開連結就開玩」）
- WebGL heap 固定大小——記憶體上限 512MB，開發早期就在真瀏覽器驗證
