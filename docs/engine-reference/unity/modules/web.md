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

## 背景分頁的主迴圈行為（2026-09-14 W1 原型實測）

**Chrome 桌面版把背景分頁的 Unity 主迴圈節流到穩定 1 Hz，不會停止。**

| 背景時長 | Update 次數 | 平均 | 最大 Update 間隔 |
|---|---|---|---|
| 4.4s | 9 | 2.1 fps | 1001 ms |
| 201.0s | 209 | 1.0 fps | 1601 ms（發生在第 6 秒） |
| 384.7s | 396 | 1.0 fps | 1601 ms（**六分半鐘內未惡化**） |

**後果（對任何掛在 PlayerLoop 上的週期性工作）**：間隔 ≥2 秒的工作在背景仍會執行，
只是時間點被拉到秒的粒度。具體到本專案：

- MPS lobby heartbeat（10 秒）→ 照常送出
- Relay PING（`HeartbeatTimeoutMS` = 500ms）→ 變成約 1 秒一次，仍遠低於 Relay 的 10 秒 TTL
- **兩者都不會因為背景分頁而斷線**

⚠ **量測邊界**：macOS 桌面 Chrome、**分頁背景化**（非視窗最小化、非系統休眠）、六分半鐘。
**行動瀏覽器不適用**——iOS Safari 的背景回收遠比桌面激進，需另行量測。
⚠ 也不要據此假設「幀率敏感的邏輯在背景仍正確」——1 Hz 意味著 `deltaTime` 會是約 1 秒，
任何以每幀為單位累加的模擬都會在背景期間行為異常。

## ⚠ itch.io 的壓縮設定（2026-09-18 定案，**強制建置規範**）

```
PlayerSettings.WebGL.compressionFormat    = WebGLCompressionFormat.Gzip
PlayerSettings.WebGL.decompressionFallback = false
```

**三種組合都實測過，gzip ＋ 不用 fallback 是唯一沒有隱藏代價的那個。**

| 建置設定 | 副檔名 | 本地 | itch.io 實際傳輸 | 傳輸倍數 | 解壓 CPU |
|---|---|---|---|---|---|
| Brotli, fallback=false | `.br` | 7,353,738 | **14,733,035** | **2.00** | – |
| Brotli, fallback=true | `.unityweb` | 7,444,699 | 7,416,748 | 0.99 | 🔴 **2268-2590 ms** |
| **Gzip, fallback=false** ✅ | `.gz` | 9,836,334 | **9,818,865** | 1.33 | **770 ms** |

### 為什麼 `.br` 會壞而 `.gz` 不會

itch.io 自己的文件講明了原因：

> "Brotli encoding **can not be detected** like gzip, so we must depend on the `.br` extension"

**gzip 由內容偵測（可靠），brotli 只能靠副檔名（壞的就是這條路）。**
`.br` 上傳後會被 itch.io 解壓，再依它自己的規則重新處理——`.wasm` 在它的自動 gzip
清單裡所以被重壓，`.data` 不在清單裡所以裸送（膨脹 4.32 倍）。
佐證：把那份 wasm 自己 gzip 一遍得 8,103,680 bytes，而 itch.io 實際送出 8,108,255，
差不到 5KB。

### `.gz` 的實測回應（部署後 curl）

| 檔案 | content-encoding | content-type | content-length |
|---|---|---|---|
| `Web.wasm.gz` | **gzip** | **application/wasm** | 7,805,140 |
| `Web.data.gz` | **gzip** | application/octet-stream | 1,913,539 |
| `Web.framework.js.gz` | **gzip** | text/javascript | 90,672 |
| `Web.loader.js` | gzip | text/javascript | 9,514 |

**每個 `content-length` 都與上傳位元組數完全相同**——未被解壓也未被重壓。
wasm 另得 `application/wasm`，`WebAssembly.instantiateStreaming` 可用。

### 不要用 `decompressionFallback = true`

它讓 Unity 的 **JS** 解壓器接手，吞吐只有 **16.3 MB/s**，
而瀏覽器原生 gzip 是 **85 MB/s**（差 5.2 倍）。
7MB 的 build 就要付 2.1 秒 CPU，且**與頻寬完全無關**（限速 20/5 Mbps 實測，
下載窗口拉長 300 倍而該 CPU 項不動 → 相加，不重疊）。
附帶代價：`loader.js` 由 26,983 膨脹為 117,894 bytes（內含 JS 解壓器）。

🔴 **絕對不要用預設的 Brotli `.br` 上 itch.io**：實測傳輸量正好 **2.00 倍**，
頂到硬標的 44MB build 會變成約 88MB 傳輸，`T_load` 直接翻倍。

**現行 build size 硬標：≤44MB，以實際出貨的 gzip 位元組計**（brotli 等效約 33MB——**兩個單位不可混用**）。來源與算式見 technical-preferences.md。

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
