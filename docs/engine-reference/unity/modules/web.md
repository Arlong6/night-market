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

## 字型（2026-09-13 W1 原型實測）

- ⚠ **Unity 內建 GUI skin 的預設字型不含 CJK glyph**。Release Web build 實測：
  介面上的中文字元**完全不渲染**（英數與符號正常）。
- **任何以中文呈現 UI 的專案都必須打包自己的 CJK 字型**並設為預設，不得依賴引擎內建。
- **體積警告**：CJK 字型即使子集化仍有明顯體積，而 Web 的下載預算通常吃緊。
  **字型子集化應視為建置步驟而非後期優化。**
- 註：Godot 也有同一個坑（`ThemeDB.fallback_font` 無 CJK）——**這是 Web 平台的通例，不是引擎特性**。

## ⚠ itch.io 的壓縮陷阱（2026-09-14 W1 原型實測，強制建置規範）

**itch.io 不支援 Brotli `Content-Encoding`，而且會把上傳的 `.br` 檔解壓後重新提供**
（`Web.data.br` 下載後前 4 位元組是 `UnityFS` 明文即為證據）。
遊戲照樣能跑——**壞消息全在傳輸量裡，功能上看不出來**。

| 建置設定 | 副檔名 | 本地 | itch.io 實際傳輸 | 倍數 |
|---|---|---|---|---|
| `decompressionFallback = false` | `.br` | 7,353,738 | **14,733,035** | **2.00** |
| `decompressionFallback = true` | `.unityweb` | 7,444,699 | **7,416,748** | **0.99** |

**強制設定：`PlayerSettings.WebGL.decompressionFallback = true`。**
副檔名變成 `.unityweb` 後 itch.io 不認得它是壓縮檔，原樣提供，改由 Unity 的 loader
自行解壓。代價是 `Web.loader.js` 由約 27KB 增為約 118KB（內含 JS Brotli 解壓器），
外加解壓的 CPU 時間。

🔴 **若誤用預設的 `.br`，50MB 的 build 在 itch.io 上等於約 100MB 傳輸。**
逐檔看更清楚：`Web.data.br` 的膨脹率是 **4.32 倍**（完全未壓縮送出）。

## Build size 參考值（2026-09-13 W1 原型實測）

一個**幾乎空的專案**（單一 OnGUI 腳本 ＋ NGO 2.13.2 ＋ Multiplayer Services 2.3.1），
IL2CPP ＋ Managed Stripping High ＋ Strip Engine Code ＋ Brotli：

| 檔案 | 大小 |
|---|---|
| `Web.wasm.br` | 5607 KB |
| `Web.data.br` | 1472 KB |
| `Web.framework.js.br` | 77 KB |
| `Web.loader.js`（未壓縮） | 26 KB |
| **合計** | **約 7.0 MB** |

建置耗時約 3 分鐘（Apple Silicon，首次含 IL2CPP 編譯則更久）。
**即：執行環境與 netcode 套件就是約 7 MB 的地板**，規劃下載預算時要從這裡起算。

## 本專案硬指標

- 壓縮後下載 ≤ 50MB（支柱「開連結就開玩」）
- WebGL heap 固定大小——記憶體上限 512MB，開發早期就在真瀏覽器驗證
