# ADR-0005: 平台抽象層——瀏覽器能力是介面，不是 `#if`

## Status
Proposed

## Date
2026-10-01（r1：2026-10-03，依 `architecture-review-2026-10-01.md` §3 C6／§5／§6 與 `architecture-review-2026-10-01-r2.md` §3A X2／X3、§3B 修訂，與 ADR-0006 r1 成對；**r2：2026-10-03，依 `architecture-review-2026-10-03-r3.md` 修訂，與 ADR-0006 r2 成對**；**r3（小修）：2026-10-12，依 `architecture-review-2026-10-04-r4.md` 修訂，與 ADR-0006 r3 成對**；逐條對照見文末「r1 修訂紀錄」「r2 修訂紀錄」與「r3 修訂紀錄」）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS（6000.3.24f1）、IL2CPP＋Managed Stripping High、NGO 2.13.2、MPS 2.3.1、UTP 2.7.4（W1 PackageCache 實際解析值；r2 依 r3 §6 釘版） |
| **Domain** | Core / Platform（Web 橋接 ＋ Networking 的平台鉤子） |
| **Knowledge Risk** | HIGH——6.1–6.3 超出模型訓練資料；本 ADR 只引用 engine-reference 與 W1 實測已證實的行為 |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`；`modules/web.md`（:17-18 WebSocket 僅 UTP↔UTP、:40-60 背景分頁主迴圈、:130 硬指標）；`modules/multiplayer.md`（:109 `ReconnectionTimeoutMS` 僅 DTLS、:143-145 Relay 三協定與 `UseWebSockets`、:159-172 首選拓撲）；`breaking-changes.md`（:11 Windows 預設 DX12、:45 Instant Games 棄用）；`deprecated-apis.md`（:17-18 通用 `[Rpc]`、MPS Sessions）；`design/gdd/netcode-session.md`（#8／#12／#17／#20／#27／#28，`[P-7]`／`[P-13]`／`[P-14]`／`[P-18]`／`[P-19]`）；ADR-0001 Decision 9；`prototypes/w1-netcode/Assets/Scripts/W1WebProbe.cs`；`docs/research/steam-feasibility-2026-10-01.md`；**r1 新增**：`docs/architecture/architecture-review-2026-10-01.md`（§3 C6、§5 ADR Revision Flags、§6）、`docs/architecture/architecture-review-2026-10-01-r2.md`（§3A X2／X3、§3B）、ADR-0006（Decision 4／9／10）、netcode GDD `[P-4]`（:1614）與 #12（:229-236）、`com.unity.services.wire` 1.5.0 的 `unity-websocket-sharp.asmdef`（asmdef 平台字串旁證）；**r2 新增**：`docs/architecture/architecture-review-2026-10-03-r3.md`（§3A FV-4、EA-4，§3C EA-7／EA-9，§4 CX-8）；Wire `Runtime/WebSocket.cs:275-276,775-785` 與 `Unity.Services.Wire.Internal.asmdef:4-8`（組合根＋一處 `#if` 的先例）；W1 的 Bee 編譯參數（`Library/Bee/artifacts/2000b0aE.dag/*.rsp`、`2000b0aP.dag/*.rsp`、`Player67b9b48d.dag.json` 的 UnityLinker 節點）；Unity 6000.3 文件 `Scripting.AlwaysLinkAssemblyAttribute`、Manual「managed-code-stripping-preserving／marking-rules」「assembly-definitions-referencing／creating」、`Application.wantsToQuit`／`Application.quitting`；HTML 規範 §7.3.1.6、§7.4.2.4、§7.5.9 與 `PageTransitionEvent.persisted`；Blink `document.cc`、Gecko `nsDocumentViewer.cpp`、WebKit `FrameLoader.cpp`（`beforeunload` 確認框在跨源 iframe 的處理）；web.dev「Back/forward cache」；MDN BCD（`fetch` keepalive、`fetchLater`）；WPT `fetch/api/redirect/redirect-keepalive.any.html`；**r3 新增**：`docs/architecture/architecture-review-2026-10-04-r4.md`（§3B R4F-3／R4F-5、§3C R4C-25／R4C-26／R4E-5／R4E-6／R4F-6–10／N-a、§6 瀏覽器查證）；Unity 6000.3 Manual「web-interacting-browser-unity-to-js」（`SendMessage` 只能呼叫 GameObject 上的腳本方法）與「EditorCommandLineArguments」（`-quit`、`-buildTarget`、`-executeMethod` 的結束碼）；Scripting API `BuildPipeline.BuildPlayer`、`BuildOptions.BuildScriptsOnly`、`Build.Player.PlayerBuildInterface.CompilePlayerScripts`、`Build.Player.ScriptCompilationSettings`、`Build.Reporting.BuildSummary.result`、`EditorApplication.Exit`；W1 `Library/Bee/artifacts/UnityLinkerInputs/TypesInScenes.xml` 與 `W1WebProbe.cs` 的行號（:20、:22-45、:162）；瀏覽器：r4 的 Playwright 1.63 本機實測（Chrome 154 stable、Chromium 153、Firefox 155、WebKit 26.6）、Blink `dom_websocket.cc`／`websocket_channel_impl.cc`、WebKit `WebSocket.cpp`、WebKit Tracking Prevention 政策（第三方 referrer 降為 origin）、whatwg/html PR #12349、Firefox ESR 時程 |
| **Post-Cutoff APIs Used** | ① MPS 2.3.1 `RelayProtocol.WSS`／`Default`（`Default` 在非 WebGL 變 DTLS，`RelayProtocol.cs:34-38`——technical-director 與 unity-specialist 兩次獨立原始碼核對）② `UnityTransport.UseWebSockets`（UTP 2.7.4，`multiplayer.md:143`；Editor 與桌面沒勾時只記 LogError，然後以 UDP 介面接 WSS 端點，必然失敗，`UnityTransport.cs:1866-1890`）③ `com.unity.services.qos` 1.4.1 於桌面平台：套件已在相依樹，桌面路徑為 `#if UGS_QOS_SUPPORTED && !UNITY_WEBGL`（`UGS_QOS_SUPPORTED` 由 asmdef versionDefines 賦值，理應涵蓋 6000.3，**未實機確認**）；WebGL 端拋 `PlatformNotSupportedException` 已核實（`WrappedQosService.cs:107-109`）。其餘 `Application.wantsToQuit`／`Application.Quit`／`Application.runInBackground`／`Application.internetReachability`／`Time.realtimeSinceStartupAsDouble`／`GUIUtility.systemCopyBuffer`（standalone 可寫）皆為訓練截止前 API，6.1–6.3 無異動紀錄；`Application.wantsToQuit` 回 false 取消退出、`Application.quitting` 只在退出無法再取消時觸發（6000.3 Scripting API 文件，r2 查證）④ **r2**：瀏覽器端 `pagehide`／`pageshow` 的 `PageTransitionEvent.persisted`、`beforeunload` 的 `preventDefault()`＋`returnValue`、`fetch(…, { keepalive: true })`（MDN BCD：Chrome 66、Firefox 133、Safari 13——這是 keepalive 本身的版本；帶 CORS preflight 的 keepalive：Firefox 在 WPT 上 133 起通過，Safari 在 WPT 上 17.5 起通過（更舊者無法判讀），真實瀏覽器送達見 ADR-0006 V10；r3 依 r4 R4F-7） ⑤ **r3 新增**：瀏覽器端 Chrome 149 起允許開著 WebSocket 的頁面進 bfcache（WebSocket 在頁面層判為失敗，連線到恢復或逐出才關，Chrome 154 實測）、Firefox 155 關分頁時 `visibilitychange` 先於 `pagehide`、Safari 對第三方 referrer 只給 origin（r4 §6 本機實測與 WebKit 政策）；CI 用到的 `BuildPipeline.BuildPlayer`、`BuildReport.summary.result`、`EditorApplication.Exit` 與命令列 `-batchmode -quit -buildTarget webgl -executeMethod -logFile -` 皆為訓練截止前 API，r3 依 6000.3 Manual 與 Scripting API 核對；`PlayerBuildInterface.CompilePlayerScripts` 只列為須先實測的選項，未採用 |
| **Verification Required** | **T1-Web**（Release，IL2CPP＋Stripping High＋Gzip）：① `PlatformComposition.Create()` 回傳的實際型別是 Web 版（r2 依 r3 EA-4）——斷言寫在消費端：開機 `MonoBehaviour` 實際拿到的 `PlatformServices` 五個介面皆非 `null`、型別屬於 `NightShift.Platform.Web`；組合根或實作若因間接取得而被剝除，表現為 `null` 或例外而不是錯誤型別，同一條斷言照樣抓到（r3 依 r4 R4E-5／R4E-6）；② W1 第 2／4 批的 `[P-7]`（stripping 存活）與 `[P-19]`（剪貼簿）經本層重跑，結果不得變；③ `[P-18]` 只沿用「`pagehide` 與 `beforeunload` 在關分頁時都會觸發」這個結論——它量的是同源 `sendBeacon`，與正式路徑的形狀（跨源 `DELETE`＋`Authorization`＋preflight＋keepalive）完全沒有交集，離開通知改由 ADR-0006 的 V10 與 T1-Web (l0)–(l5) 驗（r2 依 r3 FV-9 更正 r1 的「beacon 8/8 結果不得變」）；④ `RoomCode` 自 itch.io 的 `document.referrer` 解析成功（`[P-4]` 重跑）——**限桌面 Chrome（與 Firefox 預設模式）**；Safari 上記錄實際值（預期 `null`，用以驗證 Decision 5 表的推論），Firefox 的 Strict ETP／無痕模式不列入（r3 依 r4 R4F-5）；⑤ 確認框：iframe 內有過點擊後，Host 於 InShift 關分頁，Chrome 與 Firefox 跳框、WebKit（Playwright）不跳框（WebKit 擋下跨源 frame 的確認框）；真實 Safari 的跳框併入 ADR-0006 T1-Web 末段的人工驗收（r3 依審查更正）；按「留下」時零 `DELETE`（只適用 Chrome 與 Firefox：WebKit 沒有框可按）。Playwright 的操作本身就讓 iframe 取得 activation，「沒點過就不跳框」的負向分支測不到，併入真實 itch.io 的人工驗收（ADR-0006 T1-Web 末段；r3 依 r4 R4F-6） ｜ **T1-Desktop**（**只在 Windows standalone 測，不得用 Editor Play Mode 頂替**——停止 Play Mode 不是應用程式 Quit，`wantsToQuit` 極可能不觸發）：①a 點 X／Alt-F4（皆走 WM_CLOSE）→ `wantsToQuit` 第一次回 false → Teardown → 「NGO 已停（stopped 事件或 `!IsListening`）且 leave／delete 的 Task 已完成」或 1 s 逾時 → `CompleteQuit()`；斷言刪房請求在退出前送出、不與 MPS 退出時的 remove-self 並行（r2 依 r3 EA-7）①b 工作管理員強殺 → 確認本層不承諾、#20 心跳接手 ② `IRegionSelector` 桌面 QoS 在 ≤ 2 s 內回 region，失敗退時區鏈；同時確認 `UGS_QOS_SUPPORTED` 在 6000.3 確有定義 ③ `IPageLifecycle.IsHidden` 於桌面失焦、最小化時皆為 false 且主迴圈不節流（`Application.runInBackground = true`）④ DX12 預設下 build 可跑（Steam Overlay 另於 Steam 整合 ADR 驗）⑤ **Windows IL2CPP standalone 連結成功**——`.Web` 組件被 asmdef 排除後，桌面 build 不得含任何 `DllImport("__Internal")`（Editor 走 Mono、P/Invoke 延遲解析，測不出這個）⑥ `PlatformComposition.Create()` 回傳 Desktop 版（同 T1-Web ①，從消費端斷言五個介面皆非 `null`、型別屬於 `NightShift.Platform.Desktop`；r3 依 r4 R4E-6） ｜ **建置期**：`DllImport("__Internal")` 只允許出現在 `NightShift.Platform.Web`；遊戲程式碼中任何前置處理式含 `UNITY_WEBGL` 者恰 1 處、位於 `PlatformComposition`，且必須帶 `!UNITY_EDITOR`（grep `^\s*#\s*(if\|elif).*UNITY_WEBGL`；r2 依 r3 CX-8 統一位置）；asmdef 平台字串以 6000.3 Editor 的 Inspector 勾選產生、不手刻 JSON，EditMode 以 `CompilationPipeline.GetAssemblyDefinitionPlatforms()` 斷言 `WebGL` 是有效名稱（unity-specialist 判斷 Unity 會靜默忽略無法辨識的平台字串，那樣 `.Web` 會進所有平台編譯；旁證：Unity 自家 `com.unity.services.wire` 1.5.0 的 `unity-websocket-sharp.asmdef` 以 `"excludePlatforms": ["WebGL"]` 排除 WebGL，本機 6000.3.24f1 內建的 `Unity.UnifiedRayTracing.Runtime.asmdef` 也寫 `"WebGL"`）；**r2 新增**：EditMode 在 active target 為 WebGL 時斷言 `CompilationPipeline.GetAssemblies(AssembliesType.Editor)` 不含 `NightShift.Platform.Web`（「include-only 組件不在 Editor 編譯」目前只是由文件與 exclude 案例對稱推得）；組合根對 `.Web`（include-only）的 asmdef 參照在 Editor／桌面編譯時被靜默拿掉——W1 只實證過 exclude 的方向（Wire.Internal → websocket-sharp），這個方向若不成立，第一次編譯就會大聲失敗；**r3 新增**（依 r4 R4C-26）：CI 每次 push 以 `BuildPipeline.BuildPlayer` 完整建一次 WebGL player、失敗即擋（Migration 3；只編腳本的 `CompilePlayerScripts` 必須先通過 Migration 3 所述的故意錯誤實測，才可替代）——`.Web` 與組合根的 Web 分支在 Editor 永遠不編譯，這是唯一會編到它們的自動步驟 |
## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None（r1 依 r2 §3B Resolution 1：原列 ADR-0001。本 ADR 依賴的是分層紀律 `movement_logic_outside_core`——那已是 registry 的全專案禁用模式，不是 ADR-0001 的決策輸出；真正的消費方向相反，是 ADR-0001 的轉接層取用本 ADR 的 `IPageLifecycle`。保留原列會在 ADR-0001 r1 引用 ADR-0006 的 `PeerKey` 時成環 0001→0006→0005→0001。ADR-0001 改列於 Related Decisions） |
| **Enables** | ADR-0006 連線會談生命週期（`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector` 是它的平台輸入，r3 成對 Accept）；ADR-0001 的 `adoptInput` 供給側（ADR-0001 Decision 9 的 `visibilitychange` 通道）；Steam 桌面 build（Alpha，`docs/research/steam-feasibility-2026-10-01.md`）；日後「傳輸協定與混房」ADR（DTLS×WSS 探針）；「Steam 整合範圍」ADR（Rich Presence、成就、雲存檔） |
| **Blocks** | 所有會新增 `DllImport("__Internal")` 的 story（netcode #12／#17／#28、大廳 #8 帶碼連結、剪貼簿）——必須經本層；第一個正式 netcode 實作 story 前本 ADR 應 Accepted |
| **Ordering Note** | **與 ADR-0006 r3 成對 Accept**（它依賴本 ADR r2 起的 `InstallLeaveBeacon(url, method, authorization)`、`SetLeaveConfirmation` 與組合根；本 ADR r3 為小修，依 r4 R4C-25 刪去 `RestoredFromBackForwardCache`）。Accept 順序（r2 依 r3 §4A；r3 依 r4 §4A 沿用）：ADR-0005 r3＋ADR-0006 r3 → ADR-0001 r1 → ADR-0002／0003 r1。**本 ADR 不得把 ADR-0006 列入 Depends On**——ADR-0006 已依賴本 ADR，反向再列即成兩點環。與 ADR-0004（機台互動組 Core 分層，保留編號）互不依賴、可並行 |

## Context

### Problem Statement

netcode GDD、第一人稱控制器 GDD、機台互動組 GDD 與 ADR-0001 共同依賴約十項**只有瀏覽器才有**的能力，而且每一項在 Web 上都沒有 C# 直達路徑，只能靠 `.jslib`：

| 能力 | 誰用 | 來源 |
|---|---|---|
| `visibilitychange`（背景分頁當下標記時刻） | netcode #17 背景分流、FP C14、MI C16 | netcode `:258`、`[P-7]` |
| `performance.now()` 單調時鐘 | netcode #17 的 `t_hidden`／`t_visible` | netcode `:264-265` |
| 離開通知（r2：只在 `pagehide` 送出，keepalive `fetch` 帶 `Authorization`）與 Host 關頁確認框（`beforeunload`） | netcode #12、AC42、ADR-0006 Decision 9 | `:205-210`、`:229-236`；`[P-18]` 只證明事件會觸發（同源 `sendBeacon`），正式路徑待 V10 |
| `navigator.onLine` | netcode #20 判定表第 2 列（快速否定） | `:301` |
| 帶碼連結（iframe 內只能讀 `document.referrer`，r1） | netcode #8、大廳 UI | `[P-4]`（:1614）、`:140` |
| 剪貼簿（需 user gesture） | 大廳 UI 複製房間碼 | `[P-19]` |
| 時區（`Intl.DateTimeFormat`，不可用 .NET `TimeZoneInfo`） | netcode Core Rule #28 選 region | `:680-700` |
| 下載卡住偵測 | netcode #27 | loader 層，Unity 啟動前 |

W1 原型的寫法是每個消費者自己 `#if UNITY_WEBGL && !UNITY_EDITOR` 包 `DllImport`，`#else` 回 `"(editor)"`、`1`、`Time.realtimeSinceStartup` 這類**假值**（`W1WebProbe.cs:22-45`）。在 Editor 裡這無傷；在真正的桌面 build（Steam 版）裡，這些假值會**靜默生效**：`GetOnline()` 永遠 1、`GetVisibility()` 永遠 `"(editor)"`、離開通知永遠不送——與 ADR-0001 抓到的 `enableOverlapRecovery`、ADR-0003 的 `NetworkVariable` 建構子參數是同一種坑：預設值悄悄生效、沒有錯誤訊息。

2026-10-01 的 Steam 可行性評估結論是「能上、Alpha 做、但平台抽象 ADR 現在就寫——正式程式碼還是零，現在改最便宜」。這份 ADR 就是那件事。

### Constraints
- **Web 是 MVP 唯一平台**；桌面 build 到 Alpha 才做。本 ADR 不得讓 Web 版多付任何成本（體積、幀時間、載入）。
- **IL2CPP＋Managed Stripping High**：`.jslib` 的兩個方向分開看（r3 依 r4 N-a 統一為 Decision 4 的說法；r1 起此處寫「`.jslib` 對應的 C# 端必須 `[Preserve]`」，與 Decision 4「只標在 `SendMessage` 接收方法上、extern 不標」互相矛盾）：C#→JS 的 `extern` 宣告由直接呼叫可達，不標 `[Preserve]`；JS→C# 的 `SendMessage` 接收方法標 `[Preserve]`，但真正保住它的是它所在的 MonoBehaviour 被標記（Decision 4）。組合根與實作組件的可達性見 Decision 3。
- **Web 沒有 QoS**（`PlatformNotSupportedException`，netcode `:487`）；桌面有。Core Rule #28「region 貼著 Host 選」不變，機制分平台。
- **ADR-0001 禁用模式 `movement_logic_outside_core`**：Core 組件 `noEngineReferences = true`；本層可以引用 UnityEngine，但 Core 永遠不引用本層。
- **兩平台必須同版本同時發版**：tick rate 在 NGO 連線雜湊裡（`NetworkConfig.cs:351`），本 ADR 不動 tick。
- 一人團隊：介面要少、fake 要便宜。

### Requirements
- R1 **需要 `.jslib` 的**瀏覽器能力，每一項都有一個介面；本 ADR 收編的清單就是 Decision 2 的五個介面（列舉制；r1 依首輪 review C6 改寫——原文「每項瀏覽器能力都有一個介面」把 pointer lock 與 `AudioContext` 也含了進去，卻沒有給它們介面）。Unity 跨平台 API 已涵蓋的能力不在本層：pointer lock 由 Unity 的 `Cursor.lockState` 提供（瀏覽器層的可用性已由 `[OQ-F1]` 實測：itch.io iframe 可鎖、Esc 後一次點擊可重鎖；Unity 這一層的行為要由 ADR-0001 新增的 T1-Web 項驗——r1 寫「由 ADR-0001 的 T1-Web 驗」，但 ADR-0001 沒有這一項，r2 把它登記為 ADR-0001 r1 的義務，見 ADR-0006 Migration 3），歸 ADR-0001 轉接層與 #11 HUD 的重鎖提示（TR-fpc-019／020）；Web 首次手勢前禁自動播放與 `AudioContext` 的恢復歸 #14 音效 ADR，以 Release Web build 驗證 Unity 自帶的恢復是否足夠（TR-concept-016）。**任一能力日後若需要 `.jslib`，一律在本組件新增介面**，不得在他處 `DllImport`（`dllimport_outside_platform_web`）。桌面實作提供**語意等價**的行為，或明寫「不適用」的固定值——不得是假值。
- R2 遊戲程式碼中 `#if UNITY_WEBGL && !UNITY_EDITOR` **恰好一處**，住在組合根 `PlatformComposition.Create()`（r2 依 r3 CX-8 統一：r1 的 R2、D3、Key Interfaces、Validation 說在 `.Web` 的註冊入口，架構圖與 Migration 3 卻說在 `PlatformRoot`）；`DllImport("__Internal")` 只存在於 Web 實作組件，而該組件以 asmdef 平台約束在桌面 build 根本不編譯（雙鎖：asmdef＋建置期 grep，缺一不可——比照 ADR-0001）。
- R3 Core 組件（`NightShift.*.Core`）不引用本層；轉接層把介面結果轉成 Core 已定義的純值（如 `adoptInput`）。
- R4 每個介面有 T0 可用的 fake。
- R5 Web 行為與 W1 實證相同：`[P-7]`／`[P-19]` 重跑不變；`[P-18]` 只沿用「事件會觸發」，離開通知的形狀已改（V10；r2 依 r3 FV-9）。
- R6 Editor 就是桌面平台：Editor 一律用 Desktop 實作，不再有 `"(editor)"` 假值（arlong 2026-10-01 裁決）。r2 補證：active target 切到 WebGL 時，Editor 編譯同時定義 `UNITY_EDITOR` 與 `UNITY_WEBGL`（W1 `2000b0aE.dag/Assembly-CSharp.rsp`），`excludePlatforms: ["WebGL"]` 的組件在 Editor 照樣編譯（W1 `unity-websocket-sharp.rsp`）——所以只要判斷式帶 `!UNITY_EDITOR`，這條在 WebGL target 下仍然成立。第三方套件不受本規則約束：MPS 的 `RelayProtocol.Default` 只寫 `#if UNITY_WEBGL`，在 Editor＋WebGL target 下會解析成 WSS（`RelayProtocol.cs:34-38`）；Decision 6 本來就顯式指定 WSS，不受影響。
- R7 為 Steam 留延伸點但不定 Steam 介面（arlong 2026-10-01 裁決）：Rich Presence 的 `connect` 字串落在 `ILaunchParams.RoomCode`。

## Decision

**瀏覽器專屬能力收進一個獨立組件 `NightShift.Platform` 的五個小介面；Web 與 Desktop 各一個實作；只有組合根 `PlatformComposition` 用 `#if` 選一次。Core 看不到本層，轉接層只拿自己需要的那一個介面。**

1. **組件**：`NightShift.Platform`（asmdef，可引用 UnityEngine，不引用任何 Core 或 Netcode；只放介面與 `PlatformServices` 容器）。子組件 `NightShift.Platform.Web`（含全部 `DllImport("__Internal")` 與唯一的 `.jslib`）、`NightShift.Platform.Desktop`；**組合根 `NightShift.Platform.Composition`**（r2）同時引用前三者。Core 組件的 asmdef 不得引用 `NightShift.Platform`——`/story-readiness` 與建置期 grep 同時擋。
2. **五個介面**（見 Key Interfaces）：`IPageLifecycle`（可見性＋單調時鐘＋連線狀態）、`IUnloadNotifier`（離開通知）、`ILaunchParams`（帶碼連結）、`IClipboard`、`IRegionSelector`。每個消費者的建構子只收自己需要的那一個；沒有「`IPlatformBridge` 大介面」。
3. **選擇實作靠 asmdef 平台約束＋組合根的一處 `#if`**（r2 依 r3 EA-4、CX-8，arlong 2026-10-03 裁決；取代 r1 的「自我註冊＋無人註冊時回 Desktop」）：
   - `NightShift.Platform.Web.asmdef`：`"includePlatforms": ["WebGL"]`——桌面 build **根本不編譯**這個組件，`DllImport("__Internal")` 不可能進到 Windows IL2CPP 的原生連結期（單靠 IL2CPP 可達性分析排除從未驗證過，而且 Editor 走 Mono、P/Invoke 延遲解析，測不出連結失敗）。依 6000.3 文件，Editor 本身就是平台清單裡的一項，沒勾就不編譯，所以 `.Web` 在 Editor 裡也不編譯，不論 active target 是什麼（由文件與 exclude 案例對稱推得，EditMode 斷言，見 Verification）。
   - `NightShift.Platform.Desktop.asmdef`：`"excludePlatforms": ["WebGL"]`——Editor 與所有 standalone 都編譯；active target 是 WebGL 時 Editor 照樣編譯它（W1 實證），Editor 因此天然就是 Desktop（R6）。
   - **`NightShift.Platform.Composition`**：asmdef 引用 `NightShift.Platform`、`.Web`、`.Desktop`。player 編譯時，被平台排除的那一個組件的參照會被**靜默拿掉**，不會報錯（W1 實證：WebGL player 編譯 `Wire.Internal` 時，對 `excludePlatforms: [WebGL]` 的 websocket-sharp 參照為 0 筆，`2000b0aP.dag/Unity.Services.Wire.Internal.rsp`）。`PlatformComposition.Create()` 裡唯一一處 `#if UNITY_WEBGL && !UNITY_EDITOR` 決定 `new WebPlatformServices().Build()` 或 `new DesktopPlatformServices().Build()`——兩者是各實作組件的工廠，`Build()` 回傳填好五個介面的 `PlatformServices`。這正是 Unity 自家 Wire 套件的寫法（`WebSocket.cs:775-785`、`Unity.Services.Wire.Internal.asmdef:4-8`）。`!UNITY_EDITOR` 不可省：active target 是 WebGL 時，Editor 編譯也定義 `UNITY_WEBGL`，而 `.Web` 不在 Editor 裡編譯。
   - **兩個實作都由直接呼叫可達**，所以不需要 `[RuntimeInitializeOnLoadMethod]`、不需要 `[assembly: AlwaysLinkAssembly]`，也沒有「無人註冊」這種狀態。r1 的寫法有兩個問題。其一，`.Web` 沒有任何組件引用，只靠 RIOLM 進場；而 W1 的 WebGL build 裡，UnityLinker 只把場景裡有型別的兩個非引擎組件（Assembly-CSharp、Unity.Netcode.Runtime）當 root（r3 依審查更正），其餘 26 個玩家組件中有 8 個整包被剝掉（`Player67b9b48d.dag.json`），`.Web` 沒加 `AlwaysLinkAssembly` 就會無聲消失。其二，「無人註冊時回 Desktop」需要 `NightShift.Platform` 引用 `.Desktop`，而 `.Desktop` 為了實作介面又要引用 `NightShift.Platform`，形成 asmdef 循環，Unity 不允許；況且 WebGL build 根本不編譯 `.Desktop`，這個分支在 Web 上不可能存在，只會把剝除造成的失效掩蓋成「靜默假值」——正是本 ADR 要防的事。
   - **前提：組合根本身必須從 root 可達**。可達性由**呼叫端**保證，不由組合根住在哪個組件保證（r3 依 r4 R4E-6）：`PlatformComposition.Create()` **唯一的呼叫點**是開機場景（Build Profiles 場景清單第 0 個）裡序列化的 `MonoBehaviour`，在 `Awake` 直接呼叫，每個行程只呼叫一次；它把拿到的 `PlatformServices`（或其中的單一介面）以建構子注入各轉接層，轉接層不得自己呼叫 `Create()`。`Create()` 不是冪等的——每次呼叫都 new 一份實作再 `Build()`；Web 上兩份 `WebPlatformServices` 會各建一個 `SendMessage` 接收物件，而 JS 端的 `SendMessage` 以物件名稱定址（6000.3 Manual「web-interacting-browser-unity-to-js」），只有其中一份收得到，另一份的 `HiddenChanged`／`TryCopyAsync` 永不觸發而且靜默；Desktop 上兩份建構子都會訂閱 `Application.wantsToQuit`。單一呼叫點由 CI grep 鎖住（Migration 3）。依 6000.3 `managed-code-stripping-marking-rules`，Medium／High 下的 root 只有 MonoBehaviour／ScriptableObject 衍生型別、帶 `[RuntimeInitializeOnLoadMethod]` 或 `[Preserve]` 的方法與 link.xml 項目，一般 static class 不是 root；linker 標記 MonoBehaviour 時會標記其全部成員，所以那次呼叫、`#if` 選中的工廠都跟著被標記，`.Composition` 與該平台的實作組件也因被引用而進入 linker 處理。r2 的「或者住在 Assembly-CSharp 裡」刪除：Assembly-CSharp 只有在場景引用它的型別時才是 root 組件（W1 的兩個 `--include-unity-root-assembly` 正是 `TypesInScenes.xml` 中的兩個非引擎組件 Assembly-CSharp 與 Unity.Netcode.Runtime），而且即使是 root 組件，裡面的 static class 也不會因此存活。**典型的禁止寫法**是由 RIOLM 把 `Create()` 的結果寫進靜態欄位、消費者再讀那個欄位——消費者不引用 `.Composition`，這個組件就不會被 linker 處理，裡面的 RIOLM 也就不會被看到（`Scripting.AlwaysLinkAssemblyAttribute` 文件：沒有被已納入組件引用的組件預設不處理）。凡不是由存活程式碼直接呼叫 `Create()` 的取得方式（包括以 `Type.GetType`／`Activator.CreateInstance` 反射取實作）一律禁止：High 下反射呼叫不在依賴標記之列。可達性的原理只有一條——存活的程式碼直接呼叫的方法一定存活；這是開機 `MonoBehaviour` 這一個呼叫點足以保住整條鏈的理由，不是允許多個呼叫點的理由。
   - `Application.runInBackground` 的斷言與強制設定移到 `DesktopPlatformServices` 的建構子（r1 寫在「`PlatformRoot.Create()` 的 Desktop 分支」，那個分支已不存在）。
   - 不用 `Application.platform` 執行期分支選實作——連結期問題只能在編譯期解。雙鎖比照 ADR-0001：asmdef 約束＋建置期 grep，缺一不可。
4. **`.jslib` 只有一個檔**：`Assets/Plugins/WebGL/NightShiftPlatform.jslib`，`mergeInto(LibraryManager.library, …)`；參數只收原生數值與 UTF-8 字串指標（`UTF8ToString`），字串回傳走 `_malloc`＋`stringToUTF8`（W1 全檔既證寫法，6.3 無變更跡象）。受控物件（例如 `IReadOnlyDictionary`）收不進 `.jslib`，所以介面一律以字串表達（r2 依 r3 EA-9）。**`[Preserve]` 標在 JS→C# 的 `SendMessage` 回呼接收方法上**（如 `OnCopyResult`，`W1WebProbe.cs:162`），不是每個 `extern` 宣告——extern 由直接呼叫可達，`[P-7]` 證實無標記亦存活。接收方法上的 `[Preserve]` 是保險，不是唯一防線（r3 依 r4 N-a）：`SendMessage` 只能呼叫掛在 GameObject 上的腳本方法（6000.3 Manual「web-interacting-browser-unity-to-js」），而依 `managed-code-stripping-marking-rules`，High 下被處理的組件裡 MonoBehaviour 衍生型別本身就是 root，linker 標記 MonoBehaviour 時又會標記它的全部成員。`[P-7]` 的接收方法既帶 `[Preserve]`、又屬於場景裡的 MonoBehaviour（W1 `Library/Bee/artifacts/UnityLinkerInputs/TypesInScenes.xml` 列有 `W1WebProbe`），所以它證明的是「這種寫法存活」，分不出是哪一道保住了它。前半句的 extern 也受同一個限定：W1 的 10 個 extern 是同一個場景 MonoBehaviour（`W1WebProbe.cs:20`）的 private static 成員（`:23-32`，皆無 `[Preserve]`），同樣可由「MonoBehaviour 全成員標記」解釋，`[P-7]` 分不出它們是靠直接呼叫可達還是靠全成員標記存活。正式碼的 extern 放在 `.Web` 的非 MonoBehaviour 類別，存活只依賴標準的直接呼叫依賴標記，由 T1-Web ②（`[P-7]` 經本層重跑）驗證。正式碼的接收元件因此必須是 MonoBehaviour，且所在組件要經由組合根被引用（Decision 3），單標 `[Preserve]` 救不了未被 linker 處理的組件。W1 的 `W1Web.jslib` 是原型，不遷移，只當對照；它有三個行為**不得**帶進正式碼：只安裝一次（`:67`，重裝被忽略，token 換了也換不進去）、在 `visibilitychange → hidden` 也送出（`:88-92`，切分頁就刪房）、以 `sendBeacon` 為主路徑（`:70-86`）。
5. **桌面語意表**（R1）：

| 介面 | Web（`.jslib`） | Desktop（含 Editor） |
|---|---|---|
| `IPageLifecycle.IsHidden` | `document.visibilityState == "hidden"`，邊緣事件 `HiddenChanged` | **恆 false**——桌面失焦、最小化時主迴圈不節流（`Application.runInBackground = true` 為契約）；netcode #17 在桌面「一律在前景」。焦點**不在**本介面：`adoptInput` 的焦點來源是 `Cursor.lockState`（ADR-0001 Decision 9），失焦時指標本就解鎖 |
| `IPageLifecycle.NowMs` | `performance.now()` | `Time.realtimeSinceStartupAsDouble × 1000`（單調） |
| `IPageLifecycle.IsOnline` | `navigator.onLine`（只作快速否定，netcode #20） | `Application.internetReachability != NotReachable`（同樣只作快速否定） |
| `IUnloadNotifier` | **離開通知只在 `pagehide` 送出**（r2 依 r3 FV-4、arlong 2026-10-03 裁決）：`fetch(url, { method, headers: { Authorization }, keepalive: true })`，無 body、不設 `Content-Type`、`credentials` 維持預設。**不分 `persisted`**：進了 bfcache，這個頁面持有的 session 就已不可用，之後被逐出又沒有事件，不送就永遠沒人送。三個引擎對開著 WebSocket 的頁面行為各異——Chrome 149 起可進 bfcache，WebSocket 在頁面層判為失敗、網路連線要到恢復或逐出才關（Chrome 154 實測 ≥ 30 s）；Safari 進入即關；Firefox 不進；HTML 規範仍寫不可留存，本層以實作為準——證據與對端看到的後果只記在 ADR-0006 Decision 9（r3 依 r4 R4F-3 更正 r2 的「進 bfcache 時會主動關閉 WebSocket」、R4F-9）。`.jslib` 的單發旗標只擋 bfcache 往返後的第二次 `pagehide`。r1 的「`pagehide`（主）＋`beforeunload`（備援）」實際上是由 `beforeunload` 送出：依 HTML 規範，`beforeunload` 先對整棵框架樹派發、需要時先問使用者，按「留下」就整個中止，`pagehide` 不會觸發（§7.3.1.6、§7.4.2.4）。所以 `beforeunload` **永不送出**，只負責確認框：`SetLeaveConfirmation(true)` 時才掛上監聽器，處理器只做 `e.preventDefault(); e.returnValue = "1";`；`false` 時卸下（Chrome 建議永遠不要無條件掛 `beforeunload`）。是否真的跳框由瀏覽器決定：iframe 本身要有 sticky activation；Chrome 與 Firefox 在跨源 iframe 內會跳框，WebKit 擋下與祖先不同源的 frame 要求的確認框，所以 Safari 在 itch.io 上不跳框。`pageshow` 的 `persisted == true` → `.jslib` 先卸下 `beforeunload` 確認框監聽器（等同 `SetLeaveConfirmation(false)`：Host 在 InShift 離開時它還掛著，而 `location.reload()` 會再派發一次 `beforeunload`，不卸就可能跳出第二個確認框（是否跳框取決於該 frame 的 sticky activation 在恢復後是否還在，未查證）、或在自動化環境被 Playwright 自動關掉而取消重載；r3 依審查補），再以固定前綴寫一行 `console.info`（供 ADR-0006 T1-Web (l4) 讀取），隨即自行 `location.reload()`：`DELETE` 已在 `pagehide` 送出（有計畫時），這個文件持有的 session 不再可用；重載在 `.jslib` 內完成，C# 端沒有、也不需要重載或恢復的介面（r2 依審查補：否則依 R1，沒有人能執行這次重載）。r2 的 `RestoredFromBackForwardCache` 事件刪除（r3 依 r4 R4C-25）：它在重載前同步觸發，C# 端此刻只做得了同步的事，寫下的狀態隨重載消失、async 工作來不及完成，沒有任何消費者；T1-Web 改讀 `.jslib` 的那行紀錄與 iframe 的重新導航。重載前舊文件可能還跑幾幀、Wire／UTP 隨之回報斷線，見 ADR-0006 Decision 9。重載不看階段：Idle／Solo 的頁面從 bfcache 返回同樣重載，Solo 進度不跨導航保留（r3 依 r4 R4C-25，MVP 接受）。`visibilitychange` 只餵 `IPageLifecycle`，**不得**送出（背景≠離開）。不用 `sendBeacon`：它只能 POST、帶不了 `Authorization`（r1 依 r2 X2）。重複呼叫 `InstallLeaveBeacon` 即覆寫（token 換發後重裝）；`ClearLeaveBeacon()` 之後關分頁不再送。瀏覽器下限（r3 依 r4 R4F-7）：Firefox ≥ 133 才有 fetch keepalive（ESR 140／153 有；仍在延長支援的 ESR 115 沒有）；Safari 的 BCD 記 13，帶 preflight 的 keepalive 在 WPT 上 17.5 起通過（更舊的版本無法判讀）；送達的本機實測與剩餘缺口（真實 Safari、真實 itch.io、真實網路）見 ADR-0006 V10 | `Application.wantsToQuit` 第一次回 false → ADR-0006 的 Teardown（NGO 在跑、且屬於這次 Teardown 才 `Shutdown()`；client `LeaveAsync`、Host `DeleteAsync`）→ 等「NGO 已停（`OnServerStopped`／`OnClientStopped` 已觸發，或 `!IsListening`）**且** leave／delete 的 Task 已完成」（只等 SDK 那一次呼叫，不等 ADR-0006 的移除重試；r3 依 r4 K13；沒有 leave／delete 在途時——被判 `Duplicate`、Solo——只等 NGO 已停，未啟動即成立；已在 `Idle` 且沒有 Solo 在跑時不產生 Teardown，`QuitRequested` 直接回 true，r3 依審查補，ADR-0006 Decision 9），或 1 s 逾時 → `CompleteQuit()` 設旗標後 `Application.Quit()`，第二次 `wantsToQuit` 回 true（r2 依 r3 EA-7：r1 沿用的「`Shutdown()` 0.08 s」是對端收到的時間；`Shutdown()` 本身只設旗標）。完成判定不得看 `ISession.State`，理由與並行窗口見 ADR-0006 Decision 9「桌面」。`Application.quitting` 只在退出無法再取消時觸發，所以第一次被擋下的退出不會引發 MPS 的自動 leave。本層不依賴 MPS 在退出時自動 leave。`SetLeaveConfirmation` 在桌面是 no-op（r3 刪去 `RestoredFromBackForwardCache`） |
| `ILaunchParams.RoomCode` | `IsEmbedded` 時解析 **`document.referrer`** 的 `?code=`（r1 依 r2 X3；`[P-4]` 實測：itch.io 把自身 `location.search` 改寫成 `?v=…`，父頁 `parent.location.search` 跨域被擋，唯一可讀的是 referrer）；非 iframe 部署（如 GitLab Pages 直開）讀自身 `location.search`。referrer 可能被瀏覽器隱私設定或 `Referrer-Policy` 削減，所以回 `null` 是正常情況，輸碼備援不可砍（netcode AC2）。itch.io 頂層送 `Referrer-Policy: no-referrer-when-downgrade`，Chrome 照用，iframe 讀得到含 query 的 referrer；**Safari 恆為 `null`**：WebKit 對所有第三方 referrer 預設只給 origin，HTTP 標頭與 `document.referrer` 都一樣，而 itch.io 頁面載入 `html-classic.itch.zone` 是跨站，iframe 只看得到 `https://<user>.itch.io/`、永遠沒有 query（政策 CONFIRMED；itch.io 上實際為 `null` 是推論，未以真實 Safari 驗，Verification ④ 記錄實值）。Firefox 93 起在 Strict ETP 與無痕模式也忽略這類寬鬆政策（預設模式的現況未查證）（r3 依 r4 R4F-5） | 命令列 `--code=XXXX`；**Steam 延伸點**：Rich Presence `connect` 落到同一欄位（Steam 整合 ADR 再定） |
| `ILaunchParams.IsEmbedded` | `window.self !== window.top` | 恆 false |
| `IClipboard.TryCopyAsync` | Clipboard API **本質非同步**（`.then/.catch` 經 `SendMessage` 回呼，`W1Web.jslib:33-43`）；需 user gesture，iframe 可能被 permissions policy 擋（`[P-19]`）→ `Task<bool>` 在回呼抵達時完成 | `GUIUtility.systemCopyBuffer = text`，`Task.FromResult(true)` |
| `IRegionSelector.SelectRegionAsync` | `Intl.DateTimeFormat().resolvedOptions().timeZone` 查 `relay_region_by_timezone` → `relay_region_offset_fallback` → 預設值（Core Rule #28 原鏈） | QoS（`com.unity.services.qos`）取最低延遲 region → 失敗或逾時 2 s 時退到同一條時區鏈（桌面可用 `TimeZoneInfo.Local`）。規則「貼著 Host 選」不變，只是桌面多一個更準的第一步 |
| netcode #27 下載卡住偵測 | loader HTML 層，Unity 啟動前 | 不適用（無 loader） |

6. **傳輸協定在本 ADR 有效期間固定 WSS**：共用的 Relay helper 對所有平台**顯式**設 `RelayProtocol.WSS`＋`UnityTransport.UseWebSockets = true`，禁用 `RelayProtocol.Default`（MPS 2.3.1 在非 WebGL 平台會解析成 DTLS，與 `UseWebSockets = true` 對不上就拋 Mismatched）。桌面走 WSS 已由 W1 雙進程實測（Editor 桌面進程，`RttRoleTests.cs:65,122`，p95 94.5 ms）。改 DTLS 是另一份 ADR 的事，前提是 DTLS×WSS 混房探針通過。r2 澄清歸屬：helper 要引用 MPS 與 UTP，而 `NightShift.Platform` 不引用 Netcode（Decision 1），所以它實際上住在 ADR-0006 的 `NightShift.Session.Unity`，也就是 ADR-0006 那個唯一的 options 工廠；本 ADR 只擁有「顯式 WSS、`UseWebSockets = true`、不用 `Default`」這條規則。ADR-0006 的 `SessionNetworkHandler` 也由同一個工廠掛上，不屬本 ADR。
7. **Steam 不在本 ADR**：不定 `ISocialPlatform`；成就、雲存檔、Overlay 到 Alpha 的 Steam 整合 ADR。本 ADR 只保證 Steam 版不會踩到假值。

### Architecture Diagram

```
                         NightShift.Platform（介面＋PlatformServices 容器，可引用 UnityEngine）
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ IPageLifecycle  IUnloadNotifier  ILaunchParams  IClipboard  IRegionSelector │
   └──────────────────────────────────────────────────────────────────────────┘
            ▲                                            ▲
   NightShift.Platform.Web                      NightShift.Platform.Desktop
   （includePlatforms [WebGL]；                   （excludePlatforms [WebGL]；
     唯一的 .jslib ＋ DllImport("__Internal")）     Application.* / GUIUtility / QoS）
            ▲                                            ▲
            └──── NightShift.Platform.Composition（r2）───┘
                  PlatformComposition.Create()：遊戲程式碼裡唯一的
                  #if UNITY_WEBGL && !UNITY_EDITOR → new Web… : new Desktop…
                  （由開機場景的 MonoBehaviour 呼叫，從 root 可達）
                                      │
      ┌───────────────────────────────┼───────────────────────────────┐
      ▼                               ▼                               ▼
 netcode 轉接層                  FP 轉接層                       MI 轉接層
 #17 ← IPageLifecycle       C14 ← IPageLifecycle → adoptInput   C16 ← IPageLifecycle → 中斷手勢
 #12 ← IUnloadNotifier      （ADR-0001 Decision 9）
 #28 ← IRegionSelector
 #8  ← ILaunchParams
 #20 ← IPageLifecycle.IsOnline
      │                               │                               │
      ▼                               ▼                               ▼
   Core（純 C#，noEngineReferences = true）——只收布林／數值，永遠看不到本層
```

### Key Interfaces（`NightShift.Platform`）

```csharp
public interface IPageLifecycle
{
    bool IsHidden { get; }                 // Web: visibilityState=="hidden"；Desktop: 恆 false
    double NowMs { get; }                  // 單調時鐘（ms）；Web: performance.now()
    bool IsOnline { get; }                 // 只作快速否定（netcode #20 判定表第 2 列）
    event Action<bool> HiddenChanged;      // 邊緣觸發；Desktop 永不觸發；只供計時與手勢中斷，不得當成離開（Firefox 關分頁時 hidden 可能先於 pagehide 到達，r3 依 r4 R4F-10）
}

public interface IUnloadNotifier
{
    // r2 依 r3 FV-4、EA-9：唯一送出點是 pagehide（不分 persisted）→ fetch keepalive，帶 Authorization、無 body。
    // .jslib 只收字串；單發旗標只擋 bfcache 往返後的第二次 pagehide。重複呼叫即覆寫（token 換發後重裝）。Desktop：no-op。
    void InstallLeaveBeacon(string url, string method, string authorization);   // authorization＝完整標頭值、含 "Bearer " 前綴（ADR-0006 LeaveBeaconPlan 產生），.jslib 原樣放進 Authorization 標頭
    void ClearLeaveBeacon();               // 之後關分頁不再送
    // r2：確認框。armed=true 時才掛 beforeunload，處理器只 preventDefault＋設 returnValue，永不送出。
    // 是否真的跳框由瀏覽器決定（iframe 要有 sticky activation；Safari 對跨源 iframe 一律不跳）。Desktop：no-op。
    void SetLeaveConfirmation(bool armed);
    // r3 依 r4 R4C-25 刪除 r2 的 event Action RestoredFromBackForwardCache：它在 .jslib 的 location.reload() 之前同步觸發，沒有消費者。
    // pageshow(persisted) 時 .jslib 自行寫一行 console.info 並 location.reload()，C# 端無事件、無介面（Decision 5 表）。
    event Func<bool> QuitRequested;        // Desktop: Application.wantsToQuit；回 false = 延後退出；Web: 不觸發
    void CompleteQuit();                   // Desktop: 有序關閉完成後真正 Application.Quit()（第二次 wantsToQuit 回 true）
}

public interface ILaunchParams
{
    string RoomCode { get; }               // 無則 null（Web 的 referrer 被削減時常見；Safari 在 itch.io 上恆為 null，r3 依 r4 R4F-5——輸碼備援不可砍）；Steam Rich Presence connect 的落點
    bool IsEmbedded { get; }               // Web: iframe 內；Desktop: false
}

public interface IClipboard
{
    Task<bool> TryCopyAsync(string text);  // Web: Clipboard API 非同步、需 user gesture；false 時 UI 顯示手動複製（撰寫期修正：原同步 bool 無法承載 W1 已證的回呼流程）
}

public interface IRegionSelector
{
    Task<string> SelectRegionAsync(IReadOnlyList<string> available, string fallback, CancellationToken ct);
}

public sealed class PlatformServices          // 五個介面的簡單容器，供轉接層拆用；不是 service locator
{
    public IPageLifecycle PageLifecycle { get; }
    public IUnloadNotifier UnloadNotifier { get; }
    public ILaunchParams LaunchParams { get; }
    public IClipboard Clipboard { get; }
    public IRegionSelector RegionSelector { get; }
    public PlatformServices(IPageLifecycle pageLifecycle, IUnloadNotifier unloadNotifier, ILaunchParams launchParams,
                            IClipboard clipboard, IRegionSelector regionSelector)
    {
        PageLifecycle = pageLifecycle; UnloadNotifier = unloadNotifier; LaunchParams = launchParams;
        Clipboard = clipboard; RegionSelector = regionSelector;
    }
}

// ── NightShift.Platform.Composition（r2；asmdef 引用 NightShift.Platform、.Web、.Desktop）──
public static class PlatformComposition
{
    public static PlatformServices Create()
    {
#if UNITY_WEBGL && !UNITY_EDITOR                 // 遊戲程式碼唯一的一處；!UNITY_EDITOR 不可省（Editor＋WebGL target 也定義 UNITY_WEBGL）
        return new NightShift.Platform.Web.WebPlatformServices().Build();
#else
        return new NightShift.Platform.Desktop.DesktopPlatformServices().Build();   // 建構子斷言並強制 Application.runInBackground = true
#endif
    }
}

// NightShift.Platform.Web.asmdef     →  "includePlatforms": ["WebGL"]   （Editor 與桌面都不編譯）
// NightShift.Platform.Desktop.asmdef →  "excludePlatforms": ["WebGL"]   （Editor 一律編譯）
// 平台字串以 6000.3 Editor 的 asmdef Inspector 勾選產生、不手刻；EditMode 以 CompilationPipeline.GetAssemblyDefinitionPlatforms() 斷言 "WebGL" 有效（r1）
// r2 刪除：PlatformRoot.Register／Create、兩個實作組件的 [RuntimeInitializeOnLoadMethod] 自我註冊、「無人註冊 → Desktop」
```

T0 fake 各一個（`FakePageLifecycle` 可手動切 hidden／online；`FakeUnloadNotifier` 記錄 `Install`／`Clear`／`SetLeaveConfirmation` 的呼叫、可觸發 `QuitRequested`（r3 刪去 `RestoredFromBackForwardCache`）；其餘回固定值），放在 `NightShift.Platform.Tests`。

## Alternatives Considered

### Alternative 1: 維持散落的 `#if UNITY_WEBGL && !UNITY_EDITOR`（W1 現狀）
- **Description**: 每個需要瀏覽器能力的 MonoBehaviour 自己包 `DllImport`，`#else` 給 Editor 假值。
- **Pros**: 零新組件；W1 已證明能建置。
- **Cons**: 桌面 build 靜默拿到假值（`GetOnline() => 1`、離開通知不送）；同一能力多處實作、多處漂移；T0 無法 fake。
- **Rejection Reason**: 與 ADR-0001／0003 抓到的「預設值靜默生效」是同一類錯誤，且會在 Steam 版第一天全部爆發。

### Alternative 2: 只用 Unity 跨平台 API，不寫 `.jslib`
- **Description**: 以 `Application.focusChanged`、`OnApplicationPause`、`Application.wantsToQuit` 等統一處理。
- **Pros**: 一套程式碼、零 JS。
- **Cons**: Web 上這些 API 對應不到 `visibilitychange`／`beforeunload`／`sendBeacon`／`Intl` 時區／iframe query——`[P-7]`、`[P-18]`、`[P-19]` 三批實測的結論就是「非 `.jslib` 不可」；`TimeZoneInfo` 在 Web 不可靠（netcode `:698`）。
- **Rejection Reason**: MVP 平台正好是唯一做不到的那個。

### Alternative 3: 現在就做完整平台服務層（含 Steamworks）
- **Description**: 一次定好 `ISocialPlatform`（好友邀請、Rich Presence、成就、雲存檔）與 Steamworks.NET／Facepunch 綁定。
- **Pros**: Alpha 少一份 ADR。
- **Cons**: Steamworks 綁定的維護狀態未查證；商業模型（Friend Pass／Web 訪客端）VS 後才裁決；空介面先定型會綁死日後選擇。
- **Rejection Reason**: 過早；本 ADR 只需保證 Steam 版不踩假值，延伸點留在 `ILaunchParams.RoomCode` 即可（arlong 2026-10-01 裁決）。

### Alternative 4: 保留自我註冊，加 `[assembly: AlwaysLinkAssembly]`（r1 的寫法加上 r3 EA-4 的修法 A）
- **Description**: `.Web`／`.Desktop` 各以 `[RuntimeInitializeOnLoadMethod]` 向 `PlatformRoot` 註冊，兩個組件都加 `[assembly: UnityEngine.Scripting.AlwaysLinkAssembly]`；`PlatformRoot.Create()` 在無人註冊或重複註冊時拋例外。UGS 自家套件（MPS、Wire、Authentication、QoS）都是這個模式，註解寫 "prevent Il2CPP code stripping"（MPS `Runtime/AssemblyInfo.cs:5-6`）。
- **Pros**: 組合根不必知道有哪些實作；新增平台只加一個組件。
- **Cons**: 要同時維持三個機制（RIOLM、`AlwaysLinkAssembly`、註冊表狀態）；6000.3 文件對 `AlwaysLinkAssembly` 的措辭是「package or precompiled assemblies」，Assets 底下的 asmdef 是否同樣適用沒有明講，要實建驗證；RIOLM 在 High 下雖然是 root（`managed-code-stripping-marking-rules`），但只限被 linker 處理的組件——沒有被任何已納入組件引用的組件預設不處理，裡面的 RIOLM 根本不會被看到，這正是本方案必須加 `AlwaysLinkAssembly` 的原因；而 `AlwaysLinkAssembly` 也只讓 linker 處理該組件，組件內若沒有任何程式元素符合 root 規則，照樣整包移除（`Scripting.AlwaysLinkAssemblyAttribute` 文件原文；r3 依 r4 R4E-5 補完）。註冊時序仍是一個額外的變因。UGS 另外還有第二道保險——Services Core 在 build 時生成 `link.xml`（`LinkFileGenerator.cs:80-121`），但它只認 UGS 自己的介面，照顧不到我們的組件。
- **Rejection Reason**: 組合根以一處 `#if` 換掉三個機制，兩個實作都由直接呼叫可達，沒有「無人註冊」這種狀態（arlong 2026-10-03 裁決，Decision 3）。r2 的 `#if` 額度仍是 R2 原本就給的那一處。

## Consequences

### Positive
- Steam 版的平台差異集中在兩個組件，netcode／FP／MI 的轉接層零平台分支。
- 五個介面都有 fake，netcode #12／#17／#28 的邏輯可在 T0 測（現在是 T1 才碰得到）。
- `#if` 恰一處（在組合根）、`DllImport` 恰一組件，建置期 grep 可擋回歸（沿用 ADR-0001 的 grep 守門）。
- （r2）實作選擇不再依賴註冊時序與 IL2CPP 剝除的行為：兩個實作都由組合根直接呼叫。
- Editor＝Desktop，不再有「Editor 綠、Web 紅」以外的第三種行為。

### Negative
- 多四個 asmdef（`NightShift.Platform`、`.Web`、`.Desktop`、`.Composition`；r2 比 r1 多了 `.Composition`）與一個新寫的 `.jslib`；W1 的 `W1WebProbe` 要對照重驗 `[P-7]`／`[P-19]`。
- `IPageLifecycle.IsHidden` 在桌面恆 false，等於桌面放棄 netcode #17 的背景分流——這是刻意的（桌面主迴圈不節流），但 `Application.runInBackground = true` 成為契約，忘記設會讓桌面失焦時整個 Host 停擺。
- QoS 套件只在桌面載入，多一個平台專屬相依。
- 離開通知改用 keepalive `fetch` 之後，成敗取決於瀏覽器在 unload 期間對 CORS preflight 的支援（V10）；W1 `sendBeacon` 的 8/8 實證不能直接沿用（r1）。
- （r2）Safari 在 itch.io 的跨源 iframe 內永遠不跳確認框（WebKit 政策）；GDD AC42 只要求桌面 Chrome，不受影響，但 #12 要補註。
- （r3 依 r4 R4F-5）Safari 讀不到帶碼連結的 `?code=`：WebKit 對跨站 iframe 的 `document.referrer` 只給 origin，`RoomCode` 恆為 `null`，Safari 使用者每次都要輸碼（推論，Verification ④ 記錄實值）。設計不壞（輸碼備援本來就保留），但 GDD #8「帶碼連結是主要入口」對 Safari 不成立（ADR-0006 Migration 4 GF-27）。

### Risks
- **`Application.runInBackground` 漏設**（桌面失焦 → 主迴圈停 → Host 心跳斷）→ 緩解：`DesktopPlatformServices` 的建構子斷言並強制設為 true（r2：r1 掛在已不存在的 `PlatformRoot` Desktop 分支）；T1-Desktop ③ 驗證。
- **組合根不在 root 可達的路徑上**（r2）→ 若改成由 RIOLM 把結果寫進靜態欄位、消費者讀欄位，消費者就不再引用 `.Composition`，這個組件不會被 linker 處理，IL2CPP 剝除的問題會原封不動搬到它身上；把組合根搬進 Assembly-CSharp 也不能保證可達（r3 依 r4 R4E-6，見 Decision 3）→ 緩解：由開機場景序列化的 `MonoBehaviour` 在 `Awake` 直接呼叫 `PlatformComposition.Create()`；T1-Web ① 與 T1-Desktop ⑥ 在 Release 下從消費端斷言實作型別——間接取得的路徑一旦被剝除，消費端拿到的是 `null` 或例外，同一條斷言就會失敗。
- **include-only 參照的行為只是推論**（r2）→ 組合根在 Editor 與桌面編譯時，對 `.Web` 的參照「應該」被靜默拿掉（W1 只實證過 exclude 的方向）→ 推論若錯，第一次編譯就會大聲失敗，不會靜默。
- **`.Web` 與組合根的 Web 分支只在 WebGL player build 編譯**（r3 依 r4 R4C-26）→ 開發迴圈（Editor、EditMode、桌面 build）都編不到，`.Web` 內的 C# 錯誤會拖到出 Web build 才發現 → 緩解：CI 每次 push 以 `BuildPipeline.BuildPlayer` 建一次 WebGL player、失敗即擋（Migration 3）。
- **桌面 `wantsToQuit` 路徑被工作管理員強殺略過**（Alt-F4 與點 X 同走 WM_CLOSE，應會觸發——T1-Desktop ①a／①b 分開驗，不預設同類）→ 緩解：與 Web 一樣，#20 心跳仍是最終救命索（netcode `[P-14]`：kill -9 後 87 s 才被偵測，心跳 8 s）；本層不承諾覆蓋強殺。
- **asmdef 平台約束漏設或被人拿掉** → 桌面 IL2CPP 連結期硬性失敗且 Editor 測不出 → 緩解：建置期 grep 第二鎖；T1-Desktop ⑤ 每次 standalone build 都是一次驗證。
- **Editor Play Mode 被拿來頂替退出路徑測試** → 緩解：Validation 明寫只認 standalone。
- **QoS 於桌面的行為未實測**（本專案只知道 WebGL 會拋例外）→ 緩解：T1-Desktop ②；失敗退時區鏈，功能不受影響只是 region 較差。
- **有人在本層外新增 `DllImport`** → 緩解：建置期 grep（`grep -rn 'DllImport("__Internal")' Assets --include=*.cs` 必須只命中 `NightShift.Platform.Web`）。
- **MPS 升版改變 `RelayProtocol.Default` 語意** → 緩解：Decision 6 顯式指定，不依賴 `Default`。
- **keepalive `fetch` 沒送到**（V10）→ Host 關頁退化為服務端約 132 s 才回收，但 ADR-0006 的本地 30 s 靜默提示已保底；client 關頁退化為 Host 的心跳路徑 8 s。r2 的證據比 r1 強很多：UGS 對 itch.io 來源的 preflight 已實測放行（204、`Access-Control-Allow-Origin: *`、允許 `DELETE` 與 `authorization`、`Max-Age 600`）；WPT 的「cross-origin redirect＋preflight」keepalive 子測試在 Chrome 154、Firefox 157、Safari 27 全數通過；keepalive 的 64 KiB 配額只算 body，無 body 的 `DELETE` 佔 0。r4 的本機實測（Playwright：Chrome 154 stable、Chromium 153、Firefox 155、WebKit 26.6；跨站 iframe 在 `pagehide` 送出、接收端延遲 800 ms 回應）四者都送達（ADR-0006 V10）。剩下的風險是瀏覽器下限（Firefox < 133 沒有 keepalive，仍在延長支援的 ESR 115 也沒有）、Safari（只有 WPT 證據，17.5 起通過；真實 Safari 的送達與 bfcache 往返未實測，交 ADR-0006 T1-Web 末段的人工驗收）、真實網路下多一個 preflight RTT（r3 依 r4 R4F-7），以及行動端多半不觸發 `pagehide`。若真有主流瀏覽器不支援，備案是一個只收 `sendBeacon`、代為帶 Bearer 呼叫 Lobby REST 的極小轉發端點——那會引入新的伺服器元件，需另寫 ADR。`fetchLater`（Chrome 135+ 獨有，跨源 iframe 預設只有 8 KiB 配額）不當主路徑。
- **`Referrer-Policy` 或瀏覽器隱私設定削減 referrer**（r1）→ `RoomCode` 回 `null`、退到輸碼（netcode AC2 保底）。`[P-4]` 在 itch.io 實測可讀，但使用者端的設定不在我們控制內。Safari 不是設定問題：WebKit 對跨站 iframe 一律只給 origin，Safari 使用者每次都要輸碼（推論，Verification ④ 記錄實值；r3 依 r4 R4F-5；要不要為 Safari 另找入口是產品決策，GDD #8 補註見 ADR-0006 Migration 4 GF-27）。
- **asmdef 平台字串打錯會被靜默忽略**（unity-specialist 判斷）→ `.Web` 進所有平台編譯，桌面 IL2CPP 連結期失敗 → 緩解：Inspector 產生字串＋`GetAssemblyDefinitionPlatforms()` EditMode 斷言（r1）；T1-Desktop ⑤ 仍是最後一道。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| netcode-session.md | #17 背景分流：以 `visibilitychange` 在背景當下標記 `t_hidden`／`t_visible`，時間源必須單調（`:258-265`） | `IPageLifecycle.HiddenChanged`＋`NowMs`；桌面恆前景、主迴圈不節流 |
| netcode-session.md | #12 離開通知須 `sendBeacon`／`keepalive` 語義，`pagehide`＋`beforeunload` 需 `.jslib`、雙觸發須冪等、確認框 best-effort（`:205-210`、`:229-236`，`[P-18]`；TR-netcode-010） | `IUnloadNotifier`（r2）：`InstallLeaveBeacon(url, method, authorization)` 只在 `pagehide` 送出、不分 `persisted`；`SetLeaveConfirmation` 只掛確認框、永不送出；`pageshow(persisted)` 時 `.jslib` 自行重載（r3 刪去恢復事件，R4C-25）；桌面改 `wantsToQuit` 有序關閉 |
| netcode-session.md | #20 判定表第 2 列 `navigator.onLine`（`:301`） | `IPageLifecycle.IsOnline`，兩平台皆只作快速否定 |
| netcode-session.md | #8 帶碼連結是主要入口（`:140`、`[P-4]`；TR-netcode-007） | `ILaunchParams.RoomCode`：iframe 內讀 `document.referrer`（r1）、可能為 `null`，Safari 恆為 `null`（r3 依 r4 R4F-5，GDD #8 補註），輸碼備援不可砍；`IsEmbedded`；桌面命令列；Steam 延伸點 |
| netcode-session.md | Core Rule #28 region 貼著 Host 選；時區須經 `.jslib` `Intl`（`:680-700`）；QoS 不支援 WebGL（`:487`） | `IRegionSelector`：Web 時區鏈、桌面 QoS → 時區鏈；規則不變、機制分平台 |
| netcode-session.md | `[P-19]` 剪貼簿需 user gesture＋`.jslib` | `IClipboard.TryCopyAsync` 回 false 時 UI 退手動複製 |
| netcode-session.md | 兩平台 tick rate 一致（`NetworkConfig.cs:351` 連線雜湊） | 本 ADR 不動 tick；Decision 6 固定 WSS |
| first-person-controller.md | C14 分頁隱藏時移動輸入歸零、回前景第一幀不移動 | FP 轉接層由 `IPageLifecycle` 產 `adoptInput`（ADR-0001 Decision 9） |
| machine-interaction.md | C16 分頁隱藏由轉接層主動中斷手勢，不依賴 Input System `canceled` | MI 轉接層訂閱 `IPageLifecycle.HiddenChanged` |
| systems-index.md | #20 平台服務：Web 橋接 MVP、Steam Alpha（TR-index-027） | **部分**：本 ADR 定 MVP 的那一半（r2 補上確認框與 bfcache）；Steam 一半留 Alpha ADR；離開通知的實際送達待 V10 |
| first-person-controller.md | TR-fpc-019／020 pointer lock（重鎖手勢、吞掉重鎖點擊、iframe 可用性） | **不在本層**（r1 列舉制）：由 Unity `Cursor.lockState` 提供，歸 ADR-0001 轉接層與 #11；日後若需 `.jslib`，依 R1 於本組件新增介面 |
| game-concept-night-shift.md | TR-concept-016 Web 首次手勢前禁自動播放 | **不在本層**（r1 列舉制）：歸 #14 音效 ADR；若 Unity 自帶的 `AudioContext` 恢復不足而需 `.jslib`，依 R1 於本組件新增介面 |
| game-concept-night-shift.md | TR-concept-011 WebGL 無 UDP → WSS 傳輸鏈路（r2 補列） | Decision 6：所有平台顯式 WSS＋`UseWebSockets = true` |
| game-concept-night-shift.md | TR-concept-019 Steam 桌面版（Alpha）（r2 補列） | **部分**：Desktop 實作與桌面語意表（Decision 5）、組合根（Decision 3）；Steam 整合本身留 Alpha ADR |
| first-person-controller.md | TR-fpc-015 背景偵測只消費 netcode 已裁決的 `visibilitychange` 通道（r2 補列） | `IPageLifecycle.HiddenChanged`；FP 轉接層由它產 `adoptInput` |
| machine-interaction.md | TR-machine-037 同源可見性匯流排同時餵 `adoptInput` 與 C16（r2 補列） | `IPageLifecycle.HiddenChanged` 是唯一的來源，FP 與 MI 轉接層各自訂閱 |

## Performance Implications
- **CPU**：`HiddenChanged` 邊緣觸發、`NowMs` 為一次 `.jslib` 呼叫或一個屬性讀取；每幀成本可忽略（< 0.01 ms）。`SelectRegionAsync` 每班次一次。
- **Memory**：五個單例物件；Web 版多一個 `.jslib`（數 KB，計入 44 MB 硬標但可忽略）。
- **Load Time**：無變化；QoS 只在桌面且與 auth 預熱並行。
- **Network**：桌面 QoS 探測數個 region 各一次 ping（每班次一次）；其餘零流量。

## Migration Plan
1. 本 ADR Accepted 後，第一個正式 netcode 實作 story 先建 `NightShift.Platform`（四個 asmdef：介面、`.Web`、`.Desktop`、`.Composition`；一個 `.jslib`；五個 fake），再實作 #12／#17／#28。開機場景放一個呼叫 `PlatformComposition.Create()` 的 `MonoBehaviour`（序列化在場景裡、`Awake` 直接呼叫、每個行程一次，結果以建構子注入各轉接層；這是 `Create()` 唯一的呼叫點，不得改成 RIOLM 寫靜態欄位或反射的間接取得——r3 依 r4 R4E-6，Decision 3）。
2. `W1WebProbe.cs`／`.jslib` 保留為原型對照，不遷移；W1 第 2／4 批的 `[P-7]`／`[P-19]` 改經本層重跑（T1-Web），`[P-18]` 改由 ADR-0006 的 T1-Web (l0)–(l5) 取代。
3. CI（尚未建立）加入兩條 grep：`DllImport("__Internal")` 只在 `NightShift.Platform.Web`；`^\s*#\s*(if|elif).*UNITY_WEBGL` 在遊戲程式碼恰 1 處、位於 `PlatformComposition`，且帶 `!UNITY_EDITOR`（r2 依 r3 CX-8 統一：r1 的 Migration 3 寫「只在 `PlatformRoot`」，與 R2、D3 互相矛盾，照寫的 CI 會擋下合規的程式碼）。**另加一步 WebGL player 建置（`BuildPipeline.BuildPlayer`）**（r3 依 r4 R4C-26）：`.Web` 是 include-only（Decision 3），Editor 不編譯它；`PlatformComposition` 的 `#if UNITY_WEBGL && !UNITY_EDITOR` 分支在 Editor 也不成立。開發迴圈裡沒有任何步驟會編到這兩段，C# 錯誤要到 WebGL player build 才浮現。只以 `-buildTarget webgl` 開 Editor 不夠：那仍是 Editor 編譯（定義 `UNITY_EDITOR`，W1 `2000b0aE.dag/Assembly-CSharp.rsp`）。做法（寫死，不留給實作者猜）：`Unity -batchmode -quit -projectPath <專案> -buildTarget webgl -executeMethod <CI 入口> -logFile -`。入口是放在 Editor 資料夾的 static 方法，以 `BuildPipeline.BuildPlayer` 建 WebGL player，`BuildReport.summary.result` 不是 `BuildResult.Succeeded` 就 `EditorApplication.Exit(1)`；成功時正常返回，由 `-quit` 結束 Editor（6000.3 Manual「EditorCommandLineArguments」：`-quit` 是「Quit the Unity Editor after other commands have finished executing」，頁首範例即 `-batchmode -quit -executeMethod`；`-executeMethod` 內拋例外或以非零碼呼叫 `EditorApplication.Exit` 都會讓行程以非零碼結束——文件只定義了失敗出口，少了 `-quit` 成功路徑上 Editor 不會自行結束，CI 會掛到逾時；`-logFile -` 把 log 輸出到主控台）。`BuildOptions.BuildScriptsOnly` 不能單獨當 CI 步驟：6000.3 文件要求先做過一次完整建置。較快的 `PlayerBuildInterface.CompilePlayerScripts(ScriptCompilationSettings, outputFolder)`（`target = BuildTarget.WebGL`、`group = BuildTargetGroup.WebGL`）只編腳本、不跑 IL2CPP，但文件註明它供 Scriptable Build Pipeline 使用、「internal use only」，也沒寫編譯失敗時怎麼回報；要用它，先在 6000.3.24f1 上把一個故意的編譯錯誤放進 `.Web`，確認 CI 會失敗。**另加第三條 grep**（r3 依 r4 R4E-6）：`PlatformComposition.Create(` 在遊戲程式碼恰 1 處、位於開機場景的 `MonoBehaviour`（Decision 3 的單一呼叫點）。比照第一條加錨定（r3 依審查補：doc comment 與 EditMode 測試很自然會寫到這個名字）：只掃 `Assets/` 下 `Tests/` 以外的 `.cs`，排除第一個非空白字元是 `//` 的行——`grep -rn --include='*.cs' --exclude-dir=Tests -E '^\s*([^/*[:space:]].*)?PlatformComposition\.Create\(' Assets` 恰 1 筆（r3 依審查更正：原式 `[^/[:space:]]` 會吃掉行首的 `P`，換行寫法的第二處呼叫因此漏判，`*` 開頭的區塊註解行反被計入；`--include` 不加引號時 zsh 的 nomatch 會直接報錯），且落在開機 `MonoBehaviour` 的檔案。不改用「第二次呼叫拋例外」的執行期守衛：靜態旗標在 EditMode 測試之間、以及關閉 domain reload 的 Enter Play Mode 之間不會重設，第二次進 Play Mode 就會誤拋。
4. Steam 桌面 build 於 Alpha 啟動時，只需新增 `NightShift.Platform.Desktop` 的 QoS 相依與命令列解析，轉接層零改動。
5. **r2 遷移**：`.jslib` 重寫，不從 W1 搬——只掛 `pagehide` 一個送出監聽器，`beforeunload` 隨 `SetLeaveConfirmation` 動態增刪，`pageshow` 監聽 `persisted`；明文禁止 W1 的三個行為（只安裝一次、`visibilitychange` 送出、`sendBeacon` 主路徑）。`RoomCode` 改讀 `document.referrer`（`[P-4]` 重跑）。

## Validation Criteria
- T0：五個 fake 存在，netcode #12／#17／#28 的純邏輯測試只依賴 fake（不引用 UnityEngine）；`FakeUnloadNotifier` 能斷言 `InstallLeaveBeacon`／`ClearLeaveBeacon`／`SetLeaveConfirmation` 的呼叫順序。
- T1-Web：見 Verification Required 的 ①–⑤；離開通知與確認框的完整案例在 ADR-0006 的 T1-Web (l0)–(l5)（Playwright，包裝頁與遊戲頁屬於不同 site（registrable domain 不同；r3 依審查更正：不同 hostname 只保證跨源）、包裝頁固定掛不攔截的 `beforeunload` 監聽器；關分頁用 `page.close({ runBeforeUnload: true })`——預設的 `page.close()` 照樣跑 `pagehide`，不能當「被殺」，(l5) 改用強殺行程；(l1) 不適用 WebKit；(l4) 只在 Google Chrome stable（`channel: 'chrome'`）跑，Safari 併入人工驗收；r3 依 r4 R4F-1／R4F-2／R4F-4）。
- T1-Desktop（Windows standalone，非 Editor Play Mode）：①a 點 X／Alt-F4 → 「NGO 已停且 leave／delete 的 Task 已完成」或 1 s 後退出，刪房請求在退出前送出、不與 MPS 的 remove-self 並行 ①b 強殺不承諾、心跳接手 ② QoS ≤ 2 s 回 region、失敗退時區鏈 ③ 失焦／最小化 `IsHidden` 恆 false、主迴圈持續，且 `DesktopPlatformServices` 的 `runInBackground` 斷言生效 ④ DX12 預設下 build 可跑 ⑤ IL2CPP 連結成功、build 內零 `DllImport("__Internal")` ⑥ `PlatformComposition.Create()` 回傳 Desktop 版——同 Verification Required 的 T1-Desktop ⑥，從消費端斷言五個介面皆非 `null`、型別屬於 `NightShift.Platform.Desktop`（r3 依 r4 R4E-6）。
- 建置期：兩條 grep 皆通過；`.Web.asmdef` 含 `"includePlatforms": ["WebGL"]`；Core asmdef 無 `NightShift.Platform` 參照；EditMode 以 `CompilationPipeline.GetAssemblyDefinitionPlatforms()` 斷言 `WebGL` 是有效平台名（r1）；active target 為 WebGL 時，`CompilationPipeline.GetAssemblies(AssembliesType.Editor)` 不含 `NightShift.Platform.Web`（r2）；CI 的 WebGL player 建置通過（r3 依 r4 R4C-26，Migration 3）；`PlatformComposition.Create(` 單一呼叫點的第三條 grep 通過（r3 依 r4 R4E-6，Migration 3）。
- 決策正確的訊號：Alpha 開 Steam 版時，netcode／FP／MI 轉接層零改動。

## Related Decisions
- ADR-0001（r1 由 Depends On 改列 Related：轉接層契約、`adoptInput`、grep 守門）；ADR-0002（Verification ③ WSS 上 RPC 順序——Decision 6 固定 WSS 的理由之一）；ADR-0003（預設值靜默生效的先例）。
- ADR-0006 連線會談生命週期（消費 `IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector`；r2 起與本 ADR 成對 Accept（ADR-0006 r3＋本 ADR r3）；`InstallLeaveBeacon` 的簽章、確認框、bfcache 恢復時的重載（r3 起不再有 C# 事件）與 `RoomCode` 的 referrer 來源都是它提出的義務；它的 Migration 3 登記了 ADR-0001 r1 的 pointer lock T1-Web 項）。
- `docs/architecture/architecture-review-2026-10-03-r3.md`（r2 的修訂依據）；`docs/architecture/architecture-review-2026-10-04-r4.md`（r3 小修的依據）。
- `docs/research/steam-feasibility-2026-10-01.md`（本 ADR 的動機與 Steam 時程）。
- `design/gdd/netcode-session.md`、`design/gdd/systems-index.md` #20。
- 後續：ADR「傳輸協定與 DTLS×WSS 混房」（VS 前探針後）、ADR「Steam 整合範圍」（Alpha）。

## r1 修訂紀錄（2026-10-03）

依 `architecture-review-2026-10-01.md`（首輪）與 `architecture-review-2026-10-01-r2.md` 修訂，與 ADR-0006 r1 成對。撰寫期 unity-specialist 兩條 BLOCKING 的修正（`IClipboard` 改非同步、`.Web` asmdef 平台約束）原本標為「r1」；為了與兩輪審查和 ADR-0006 的引用一致，改稱「撰寫期修正」，本次才是 r1。

| 來源 | 修訂 | 位置 |
|---|---|---|
| r2 X2；首輪 §5（`pagehide`＋冪等） | `IUnloadNotifier` 改為 `pagehide`（主）＋`beforeunload`（備援）→ keepalive `fetch` 帶 `method`／`headers`；送出端單發去重；新增 `ClearLeaveBeacon()` | Decision 5 表；Key Interfaces |
| r2 X3；首輪 §6（`[P-4]`） | `RoomCode` 在 iframe 內讀 `document.referrer`；可能為 `null`，輸碼備援不可砍 | Decision 5 表；Context 表；Risks |
| 首輪 §3 C6 | R1 改為列舉制；pointer lock 歸 ADR-0001／#11，`AudioContext` 歸 #14；需要 `.jslib` 時一律進本組件 | Requirements R1；GDD 對照表 |
| 首輪 §6 specialist CONCERN | asmdef 平台字串以 Inspector 產生，並以 `GetAssemblyDefinitionPlatforms()` 斷言；找到 Unity 6 仍用 `WebGL` 的旁證 | Verification Required；Risks；Validation |
| r2 §3B | Depends On ADR-0001 → None（ADR-0001 改列 Related）；Enables 補 ADR-0006；不得反向依賴 ADR-0006 | ADR Dependencies；Related Decisions |
| r2 E13 | 桌面退出路徑同樣先 `Shutdown()` 再 leave，MPS 的警告是預期的 | Decision 5 表 |
| 一致性 | GDD 對照表的 `IClipboard.TryCopy` 改為 `TryCopyAsync`；補 TR 編號 | GDD Requirements Addressed |

arlong 2026-10-03 裁示：C6 採列舉制，pointer lock 與 `AudioContext` 不放進平台層。

## r2 修訂紀錄（2026-10-03）

依 `architecture-review-2026-10-03-r3.md` 修訂，與 ADR-0006 r2 成對。查證方式同 ADR-0006 r2 修訂紀錄（查證 agent 加反駁者；瀏覽器行為對照 HTML 規範、Blink／Gecko／WebKit 原始碼、WPT 結果與一次 UGS preflight 實測）。

**arlong 2026-10-03 裁決**：`pagehide` 不分 `persisted` 一律送出、恢復時重載；實作選擇改用組合根加一處 `#if`。

| r3 編號 | 嚴重度 | 修訂 | 位置 |
|---|---|---|---|
| EA-4 | 🟡 必修 | 組合根 `NightShift.Platform.Composition` 取代自我註冊；刪除「無人註冊時回 Desktop」（asmdef 循環，且 WebGL 不編譯 `.Desktop`）；不需要 `AlwaysLinkAssembly` 與 `[Preserve]`；組合根須從 root 可達；T1-Web／T1-Desktop 斷言實作型別 | Decision 1、3；Key Interfaces；Verification；Risks；Alternative 4 |
| FV-4 | 🟡 必修（與 ADR-0006 共同） | 只在 `pagehide` 送出、不分 `persisted`（**推翻 r3 Resolution 第二點**）；`beforeunload` 只掛確認框（`SetLeaveConfirmation`）；`RestoredFromBackForwardCache`（r3 更正：已刪，r4 R4C-25）；瀏覽器矩陣 | Decision 5 表；Key Interfaces；Verification ⑤ |
| CX-8 | LOW | `#if` 的位置統一為組合根；涵蓋 r3 點名之外的 :69、:73、:163、:168、:218、:263 與 registry；`runInBackground` 斷言移到 `DesktopPlatformServices` 建構子；CI grep 改比對 `#if` 與 `#elif` | R2；Decision 3；Migration 3；Risks |
| EA-7 | LOW | 桌面退出以「NGO 已停且 leave／delete 的 Task 已完成」或 1 s 判定（不得看 `ISession.State`）；不依賴 MPS 退出時的自動 leave；`Shutdown()` 只設旗標 | Decision 5 表；T1-Desktop ①a |
| EA-9 | LOW | `InstallLeaveBeacon(url, method, authorization)`：`.jslib` 只收字串，刪掉 headers 字典與 body | Decision 4；Key Interfaces |
| FV-9 | LOW | R5／Verification／Validation 的「beacon 8/8 結果不得變」改為「`[P-18]` 只證事件觸發」 | R5；Verification ③；Validation |
| §6 | NOTE | 版本釘成 UTP 2.7.4、6000.3.24f1 | Engine Compatibility |
| 附錄 | 文件 | 補列 TR-concept-011、019，TR-fpc-015，TR-machine-037；#20 列標「部分」（TR-index-027） | GDD Requirements Addressed |
| 附錄 TR-fpc-019／020 | 文件 | pointer lock 的 T1-Web 交棒對象不存在 → 登記為 ADR-0001 r1 的義務（ADR-0006 Migration 3） | R1 |

**r3 沒寫到、查證時新發現的事**：
1. active target 為 WebGL 時，Editor 編譯同時定義 `UNITY_EDITOR` 與 `UNITY_WEBGL`；include-only 的 `.Web` 依文件在 Editor 不編譯。所以 r1 :76 給 `#if` 的理由（「擋 Editor 切到 WebGL 目標時 `.Web` 也會被編譯」）多半不成立；真正需要 `!UNITY_EDITOR` 的理由是 Editor＋WebGL target 下 `UNITY_WEBGL` 有定義。
2. W1 的 WebGL build 中，UnityLinker 只把場景裡有型別的兩個組件當 root，其餘玩家組件有 8 個整包被剝除——r1 的 `.Web` 自我註冊在 Stripping High 下有實際的失效路徑。
3. W1 的 `.jslib` 在 `visibilitychange → hidden` 也會送出；若照搬，Lobby 中切個分頁就會刪房。
4. `[P-18]` 的收端與 build 同源，從未經過 preflight；W1 也從未出現過確認框（`beforeunload` 處理器沒有 `preventDefault`／`returnValue`）。

**偏離 r3 建議之處**：
- FV-4 第二點（`persisted == true` 時不送）：改為一律送、恢復時重載。理由見 Decision 5 表。
- EA-4：r3 給了兩個修法，r2 採「組合根」那一個，不採「`AlwaysLinkAssembly`＋`[Preserve]`」；後者記為 Alternative 4。

**不在 r2 範圍**：`docs/engine-reference/unity/modules/web.md` 新增「離開通知」一節（keepalive、preflight 實測標頭、bfcache 各瀏覽器行為、確認框矩陣）與 `current-best-practices.md` 補 `AlwaysLinkAssembly`（r3 §6，待參考庫更新）；GDD #12／AC42 的 Safari 註記（ADR-0006 Migration 4）。

## r3 修訂紀錄（2026-10-12）

依 `architecture-review-2026-10-04-r4.md` 修訂，屬小修，與 ADR-0006 r3 成對。r4 §3A 的 9 條必修全部屬 ADR-0006；本 ADR 只處理 §3B、§3C 中落在平台層的項目，以及兩份 ADR 的共同項。查證方式同 ADR-0006 r3 修訂紀錄：
- **設計、審查、修訂**：分主題由 cluster 設計，交獨立的對抗審查者推翻，再由設計者修訂。本 ADR 的主體是 H（組合根、`[Preserve]`、CI）與 G（瀏覽器）兩個 cluster，審查 findings 共 17 條，全數採納。
- **跨 cluster 協調**：整合後做了 5 輪，第 4、5 輪動到本 ADR。
- **草稿審查輪**（寫入前）：與 ADR-0006 共用同一輪審查，落在本 ADR 的 findings 由修訂者 F3 改入，見表後的「r3 審查輪的修訂」。
- **查證依據**：Unity 6000.3 的 Manual 與 Scripting API；W1 的 Bee 建置產物；r4 的瀏覽器本機實測（Playwright 1.63：Chrome 154 stable、Chromium 153、Firefox 155、WebKit 26.6），以及規範與引擎原始碼。

本輪沒有新的 arlong 設計裁決；r2 的兩項裁決（`pagehide` 一律送出並在恢復時重載、組合根加一處 `#if`）沿用。

| r4 編號 | 嚴重度 | 修訂 | 位置 |
|---|---|---|---|
| R4C-25 | LOW（與 ADR-0006 共同） | 刪除 `RestoredFromBackForwardCache`：它在重載前同步觸發，沒有消費者。`pageshow(persisted)` 時 `.jslib` 依序：① 卸下 `beforeunload` 確認框監聽器（否則 `location.reload()` 會再派發一次 `beforeunload`）；② 寫一行 `console.info`，供 ADR-0006 T1-Web (l4) 讀取；③ 重載。Idle／Solo 也照樣重載，Solo 進度不跨導航保留（MVP 接受）。r2 修訂紀錄 FV-4 列附加 r3 更正 | Decision 5 表；Key Interfaces；T0 fake；GDD 對照表；Ordering Note；Related Decisions；r2 修訂紀錄 |
| R4C-26 | NOTE | CI 每次 push 完整建一次 WebGL player，指令寫死：`Unity -batchmode -quit -projectPath <專案> -buildTarget webgl -executeMethod <CI 入口> -logFile -`。入口以 `BuildPipeline.BuildPlayer` 建置，`BuildReport.summary.result` 不是 `Succeeded` 就 `EditorApplication.Exit(1)`。`CompilePlayerScripts` 必須先通過故意錯誤的實測，才可替代 | Migration 3；Verification 建置期；Validation 建置期；Risks；registry `platform_implementation_dispatch`、`dllimport_outside_platform_web` |
| R4E-5 | LOW | 「Stripping High 下 RIOLM 本來就是 root」補上限定：只限被 UnityLinker 處理的組件。Alternative 4 的 Cons 補完兩半句 | Alternative 4；Verification ①；registry `platform_implementation_dispatch` |
| R4E-6 | LOW | 組合根的可達性改由呼叫端保證。`Create()` 唯一的呼叫點是開機場景序列化的 `MonoBehaviour`：在 `Awake` 呼叫，每個行程一次，結果以建構子注入各轉接層；`Create()` 非冪等。CI 加第三條 grep，鎖住單一呼叫點。刪除「或者住在 Assembly-CSharp 裡」。凡不是直接呼叫的取得方式一律禁止，包括以 RIOLM 寫靜態欄位與反射。T1 從消費端斷言：五個介面皆非 null，型別屬於該平台 | Decision 3；Risks；Migration 1、3；Verification ①⑥；Validation T1-Desktop ⑥、建置期；registry `platform_implementation_dispatch` |
| N-a | NOTE | Constraints 的 `[Preserve]` 說法統一為 Decision 4：extern 不標，`SendMessage` 的接收方法標。Decision 4 補明 `[Preserve]` 只是保險：W1 的 extern 與接收方法都是場景 `MonoBehaviour` 的成員，`[P-7]` 分不出是哪一道保住的。正式碼的 extern 由 T1-Web ② 驗 | Constraints；Decision 4 |
| R4F-3 | 🟡 應修（與 ADR-0006 共同） | 改述：Chrome 149 起可進 bfcache，WebSocket 在頁面層判為失敗，網路連線要到恢復或逐出才關（Chrome 154 實測 ≥ 30 s）；Safari 進入即關；Firefox 不進。本表只留摘要，證據與對端看到的後果只記在 ADR-0006 Decision 9 | Decision 5 表 |
| R4F-5 | 🟡 應修 | Safari 的 `RoomCode` 恆為 null：WebKit 對第三方 referrer 一律只給 origin（政策 CONFIRMED；itch.io 上實際為 null 是推論）。Verification ④ 限桌面 Chrome（與 Firefox 預設模式），Safari 記錄實值。Negative、Risks 補推論標記；GDD 對照表 TR-netcode-007 列補 Safari；GF-27 交 ADR-0006 Migration 4 | Decision 5 表；Key Interfaces；Verification ④；Negative；Risks；GDD 對照表；registry `launch_params` |
| R4F-1／R4F-2／R4F-4 | 🟡 應修（與 ADR-0006 共同） | Validation 的 T1-Web 改寫：包裝頁固定掛不攔截的 `beforeunload` 監聽器；預設的 `page.close()` 照樣跑 `pagehide`，不能當「被殺」，(l5) 改用強殺行程；(l1) 不適用 WebKit；(l4) 只在 Google Chrome stable 跑，Safari 併入人工驗收。案例本體在 ADR-0006 | Validation T1-Web |
| R4F-6 | LOW（與 ADR-0006 共同） | Playwright 的操作本身就讓 iframe 取得 activation，「沒點過就不跳框」的負向分支併入真實 itch.io 的人工驗收；「按留下零 `DELETE`」只適用 Chrome 與 Firefox | Verification ⑤ |
| R4F-7 | LOW（與 ADR-0006 共同） | 瀏覽器下限：Firefox ≥ 133（ESR 140／153 有，仍在延長支援的 ESR 115 沒有）；Safari 帶 preflight 的 keepalive 在 WPT 上 17.5 起通過。Risks 補 r4 的本機送達實測，以及真實 Safari、真實 itch.io 的缺口。Post-Cutoff ④ 原寫「下限未查證」，與 Decision 5 表矛盾，同步改為 WPT 的 Firefox 133／Safari 17.5（r3 依審查補） | Engine Compatibility Post-Cutoff ④；Decision 5 表；Risks |
| R4F-9 | NOTE（與 ADR-0006 共同） | HTML 規範仍寫「有 WebSocket 就不可留存」，本層以實作為準 | Decision 5 表 |
| R4F-10 | NOTE（與 ADR-0006 共同） | `HiddenChanged` 註明：Firefox 關分頁時 hidden 可能先於 `pagehide` 到達，不得當成離開 | Key Interfaces |
| K13 | 🟡 應修（與 ADR-0006 共同） | Desktop 欄：只等 SDK 那一次 leave／delete 呼叫，不等 ADR-0006 的移除重試與「離開已確認」。理由：桌面的 `IUnloadNotifier` 是 no-op，退出後也沒人能續試 | Decision 5 表 |
| R4C-13 | 🟡 應修（與 ADR-0006 共同） | Desktop 欄的 Teardown 摘要改為「NGO 在跑、且屬於這次 Teardown 才 `Shutdown()`」，與 ADR-0006 Teardown 第 2 步一致 | Decision 5 表 |
| §4A／§8 | 文件（與 ADR-0006 共同） | 成對關係改為 ADR-0006 r3＋本 ADR r3；Accept 順序沿用 r4 §4A；Related 補 r4 報告作為 r3 的依據 | ADR Dependencies（Enables、Ordering Note）；Related Decisions |

**r3 審查輪的修訂**（r4 以外；與 ADR-0006 r3 修訂紀錄的同名表成對）：

| 審查項目 | 修訂 | 位置 |
|---|---|---|
| 3C-4 | Post-Cutoff ④ 的 keepalive＋preflight 下限改為 WPT 的 Firefox 133、Safari 17.5（併入上表 R4F-7） | Engine Compatibility Post-Cutoff ④ |
| consistency-6、O8 | Verification 格內 grep 的 `(if\|elif)` 加跳脫，表格不再多出一欄（GFM 在 code span 內也把未跳脫的管線當欄分隔） | Engine Compatibility Verification Required |
| consistency-7 | 第 76 行「場景裡有型別的兩個組件」改為「兩個非引擎組件（Assembly-CSharp、Unity.Netcode.Runtime）」：初稿只在下一段改述，新發現 1 宣稱的改述此時才完整 | Decision 3 |
| browser-0005-7 | Verification ⑤ 的「Safari 不跳框」改為「WebKit（Playwright）不跳框」，真實 Safari 併入 ADR-0006 T1-Web 末段的人工驗收 | Verification Required ⑤ |
| browser-0005-4 | 包裝頁與遊戲頁改為「不同 site」：不同 hostname 只保證跨源，ADR-0006 (l5) 的 OOPIF 與 WebKit 的 referrer 裁切都要跨站 | Validation T1-Web |
| browser-0005-9 | Desktop 欄補：沒有 leave／delete 在途時（`Duplicate`、Solo）只等 NGO 已停；已在 `Idle` 時 `QuitRequested` 直接回 true | Decision 5 表；registry `unload_notifier` |
| browser-0005-10 | 第三條 grep 比照第一條寫死：只掃 `Tests/` 以外的 `.cs`、排除 `//` 開頭的行，避免 doc comment 與 EditMode 測試讓合規程式碼失敗 | Migration 3；registry `platform_implementation_dispatch` |
| O11 | 不改：Desktop 欄已寫「NGO 在跑、且屬於這次 Teardown 才 `Shutdown()`」（上表 R4C-13） | — |
| 最終檢查 | Migration 3 第三條 grep 改為 `^\s*([^/*[:space:]].*)?PlatformComposition\.Create\(`：原式會漏掉換行寫法的第二處呼叫、誤計 `*` 開頭的註解行；`--include` 加引號 | Migration 3 |

**原始碼與文件核對時新發現、r4 沒寫到的事**（已寫進正文）：
1. W1 的 `TypesInScenes.xml` 實際列了三個組件，其中兩個是非引擎組件（第 2、5、8 行）。r2 的「UnityLinker 只把場景裡有型別的兩個組件當 root」據此改述為「兩個非引擎組件」。
2. 依 6000.3 Manual「managed-code-stripping-preserving／marking-rules」，Stripping High 下的 root 是 `MonoBehaviour` 衍生型別，static class 在任何被處理的組件裡都不是 root。所以「組合根住在不在 root 組件」不是重點，重點是呼叫端有沒有被標記（R4E-6 的依據）。
3. W1 的 extern 是場景 `MonoBehaviour` `W1WebProbe` 的 private static 成員（`W1WebProbe.cs:20`、`:22-45`），`OnCopyResult` 也在同一個型別上（`:162`）。依標記規則，兩者不靠 `[Preserve]` 也會存活，所以 `[P-7]` 的「`[Preserve]` 擋住了裁切」分不出是哪一道保住的（N-a 的依據）。
4. 6000.3 文件要求 `BuildOptions.BuildScriptsOnly` 之前先做過一次完整建置，所以乾淨的 CI runner 不能單獨用它。`PlayerBuildInterface.CompilePlayerScripts` 標為供 Scriptable Build Pipeline 使用的「internal use only」，也沒寫編譯失敗時怎麼回報。
5. 「EditorCommandLineArguments」只定義了失敗出口：`-executeMethod` 內拋例外，或以非零碼呼叫 `EditorApplication.Exit`。少了 `-quit`，成功路徑上 Editor 不會自行結束，CI 會掛到逾時。
6. `pageshow(persisted)` 時，若 Host 在 InShift 離開，`beforeunload` 確認框監聽器還掛著，而 `location.reload()` 會再派發一次 `beforeunload`，可能跳出第二個確認框，或在自動化環境被自動關掉而取消重載。所以 `.jslib` 必須先卸監聽器再重載。恢復後 sticky activation 還在不在，未查證。

**偏離 r4 建議之處**：
- **R4C-26**：報告建議「CI 加一次 WebGL 腳本編譯」（`BuildOptions.BuildScriptsOnly`）。6000.3 文件要求先做過完整建置，所以主路徑改為完整的 WebGL player 建置；`CompilePlayerScripts` 列為需先實測的加速選項。
- **R4E-5**：報告說 Alternative 4 的 Cons「已寫對兩半，維持即可」。實讀只寫了「RIOLM 在 High 下雖然本來就是 root」，沒有「只限被處理的組件」，所以一併補完。
- **N-a**：報告只要求以 Decision 4 為準改述 Constraints。實查後發現 Decision 4 自身的依據也要限定（新發現 3），一併補明。
- **R4C-25**：報告給「刪事件」或「寫明消費者」兩個選項，本輪選刪。報告原始輸出另提議「只在真的送出 `DELETE` 或當時有 session 時才重載」，那會改變裁決的執行方式，所以不採；改為一律重載，並把 Idle／Solo 的後果寫明。
- **§4A**：r4 建議的 Accept 組合是「ADR-0005 r2＋ADR-0006 r3」。本 ADR 的正文因上表各項而改動，所以標為 r3（小修），兩者成對 Accept；順序不變。

**不在 r3 範圍**：
- **GDD 對照表的漏報**（r4 §1）：未補 TR-netcode-020（Decision 6 就是它的決策）；表內 7 列以 GDD 規則號書寫、沒附 TR-ID（#17、#28、[P-19]、tick、C14、C16、#20 onLine），也未補。
- **參考庫**：`docs/engine-reference/unity/modules/web.md`「離開通知」一節，需要 r2 列的素材加上 r4 的實測：keepalive＋preflight 三引擎送達、Chrome bfcache 中 WebSocket 不立即斷、Safari 第三方 referrer 降為 origin、Playwright 的 `page.close()` 會跑 `pagehide`、預設關 bfcache、WebKit `runBeforeUnload` 會卡住。`current-best-practices.md` 也還沒補 `AlwaysLinkAssembly`。兩者都屬 r3／r4 §6 的參考庫缺口。
- **GDD**：GF-27 是否為 Safari 另找入口，屬產品決策；GDD #12／AC42 的 Safari 註記交 ADR-0006 Migration 4。
- **待確認**：`Create()` 不加「第二次呼叫拋例外」的執行期守衛，理由是靜態旗標在關閉 domain reload 時不會重設。這一點依訓練知識推論，未親讀 6000.3 文件。
