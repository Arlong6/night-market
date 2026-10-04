# ADR-0005: 平台抽象層——瀏覽器能力是介面，不是 `#if`

## Status
Proposed

## Date
2026-10-01（r1：2026-10-03，依 `architecture-review-2026-10-01.md` §3 C6／§5／§6 與 `architecture-review-2026-10-01-r2.md` §3A X2／X3、§3B 修訂，與 ADR-0006 r1 成對；**r2：2026-10-03，依 `architecture-review-2026-10-03-r3.md` 修訂，與 ADR-0006 r2 成對**；逐條對照見文末「r1 修訂紀錄」與「r2 修訂紀錄」）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS（6000.3.24f1）、IL2CPP＋Managed Stripping High、NGO 2.13.2、MPS 2.3.1、UTP 2.7.4（W1 PackageCache 實際解析值；r2 依 r3 §6 釘版） |
| **Domain** | Core / Platform（Web 橋接 ＋ Networking 的平台鉤子） |
| **Knowledge Risk** | HIGH——6.1–6.3 超出模型訓練資料；本 ADR 只引用 engine-reference 與 W1 實測已證實的行為 |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`；`modules/web.md`（:17-18 WebSocket 僅 UTP↔UTP、:40-60 背景分頁主迴圈、:130 硬指標）；`modules/multiplayer.md`（:109 `ReconnectionTimeoutMS` 僅 DTLS、:143-145 Relay 三協定與 `UseWebSockets`、:159-172 首選拓撲）；`breaking-changes.md`（:11 Windows 預設 DX12、:45 Instant Games 棄用）；`deprecated-apis.md`（:17-18 通用 `[Rpc]`、MPS Sessions）；`design/gdd/netcode-session.md`（#8／#12／#17／#20／#27／#28，`[P-7]`／`[P-13]`／`[P-14]`／`[P-18]`／`[P-19]`）；ADR-0001 Decision 9；`prototypes/w1-netcode/Assets/Scripts/W1WebProbe.cs`；`docs/research/steam-feasibility-2026-10-01.md`；**r1 新增**：`docs/architecture/architecture-review-2026-10-01.md`（§3 C6、§5 ADR Revision Flags、§6）、`docs/architecture/architecture-review-2026-10-01-r2.md`（§3A X2／X3、§3B）、ADR-0006（Decision 4／9／10）、netcode GDD `[P-4]`（:1614）與 #12（:229-236）、`com.unity.services.wire` 1.5.0 的 `unity-websocket-sharp.asmdef`（asmdef 平台字串旁證）；**r2 新增**：`docs/architecture/architecture-review-2026-10-03-r3.md`（§3A FV-4、EA-4，§3C EA-7／EA-9，§4 CX-8）；Wire `Runtime/WebSocket.cs:275-276,775-785` 與 `Unity.Services.Wire.Internal.asmdef:4-8`（組合根＋一處 `#if` 的先例）；W1 的 Bee 編譯參數（`Library/Bee/artifacts/2000b0aE.dag/*.rsp`、`2000b0aP.dag/*.rsp`、`Player67b9b48d.dag.json` 的 UnityLinker 節點）；Unity 6000.3 文件 `Scripting.AlwaysLinkAssemblyAttribute`、Manual「managed-code-stripping-preserving／marking-rules」「assembly-definitions-referencing／creating」、`Application.wantsToQuit`／`Application.quitting`；HTML 規範 §7.3.1.6、§7.4.2.4、§7.5.9 與 `PageTransitionEvent.persisted`；Blink `document.cc`、Gecko `nsDocumentViewer.cpp`、WebKit `FrameLoader.cpp`（`beforeunload` 確認框在跨源 iframe 的處理）；web.dev「Back/forward cache」；MDN BCD（`fetch` keepalive、`fetchLater`）；WPT `fetch/api/redirect/redirect-keepalive.any.html` |
| **Post-Cutoff APIs Used** | ① MPS 2.3.1 `RelayProtocol.WSS`／`Default`（`Default` 在非 WebGL 變 DTLS，`RelayProtocol.cs:34-38`——technical-director 與 unity-specialist 兩次獨立原始碼核對）② `UnityTransport.UseWebSockets`（UTP 2.7.4，`multiplayer.md:143`；Editor 與桌面沒勾時只記 LogError，然後以 UDP 介面接 WSS 端點，必然失敗，`UnityTransport.cs:1866-1890`）③ `com.unity.services.qos` 1.4.1 於桌面平台：套件已在相依樹，桌面路徑為 `#if UGS_QOS_SUPPORTED && !UNITY_WEBGL`（`UGS_QOS_SUPPORTED` 由 asmdef versionDefines 賦值，理應涵蓋 6000.3，**未實機確認**）；WebGL 端拋 `PlatformNotSupportedException` 已核實（`WrappedQosService.cs:107-109`）。其餘 `Application.wantsToQuit`／`Application.Quit`／`Application.runInBackground`／`Application.internetReachability`／`Time.realtimeSinceStartupAsDouble`／`GUIUtility.systemCopyBuffer`（standalone 可寫）皆為訓練截止前 API，6.1–6.3 無異動紀錄；`Application.wantsToQuit` 回 false 取消退出、`Application.quitting` 只在退出無法再取消時觸發（6000.3 Scripting API 文件，r2 查證）④ **r2**：瀏覽器端 `pagehide`／`pageshow` 的 `PageTransitionEvent.persisted`、`beforeunload` 的 `preventDefault()`＋`returnValue`、`fetch(…, { keepalive: true })`（MDN BCD：Chrome 66、Firefox 133、Safari 13——這是 keepalive 本身的版本；帶 CORS preflight 的 keepalive 在各引擎的下限未查證，交 ADR-0006 V10） |
| **Verification Required** | **T1-Web**（Release，IL2CPP＋Stripping High＋Gzip）：① `PlatformComposition.Create()` 回傳的實際型別是 Web 版（r2 依 r3 EA-4）；② W1 第 2／4 批的 `[P-7]`（stripping 存活）與 `[P-19]`（剪貼簿）經本層重跑，結果不得變；③ `[P-18]` 只沿用「`pagehide` 與 `beforeunload` 在關分頁時都會觸發」這個結論——它量的是同源 `sendBeacon`，與正式路徑的形狀（跨源 `DELETE`＋`Authorization`＋preflight＋keepalive）完全沒有交集，離開通知改由 ADR-0006 的 V10 與 T1-Web (l0)–(l5) 驗（r2 依 r3 FV-9 更正 r1 的「beacon 8/8 結果不得變」）；④ `RoomCode` 自 itch.io 的 `document.referrer` 解析成功（`[P-4]` 重跑）；⑤ 確認框：iframe 內有過點擊後，Host 於 InShift 關分頁，Chrome 與 Firefox 跳框、Safari 不跳框（WebKit 擋下跨源 frame 的確認框）；按「留下」時零 `DELETE` ｜ **T1-Desktop**（**只在 Windows standalone 測，不得用 Editor Play Mode 頂替**——停止 Play Mode 不是應用程式 Quit，`wantsToQuit` 極可能不觸發）：①a 點 X／Alt-F4（皆走 WM_CLOSE）→ `wantsToQuit` 第一次回 false → Teardown → 「NGO 已停（stopped 事件或 `!IsListening`）且 leave／delete 的 Task 已完成」或 1 s 逾時 → `CompleteQuit()`；斷言刪房請求在退出前送出、不與 MPS 退出時的 remove-self 並行（r2 依 r3 EA-7）①b 工作管理員強殺 → 確認本層不承諾、#20 心跳接手 ② `IRegionSelector` 桌面 QoS 在 ≤ 2 s 內回 region，失敗退時區鏈；同時確認 `UGS_QOS_SUPPORTED` 在 6000.3 確有定義 ③ `IPageLifecycle.IsHidden` 於桌面失焦、最小化時皆為 false 且主迴圈不節流（`Application.runInBackground = true`）④ DX12 預設下 build 可跑（Steam Overlay 另於 Steam 整合 ADR 驗）⑤ **Windows IL2CPP standalone 連結成功**——`.Web` 組件被 asmdef 排除後，桌面 build 不得含任何 `DllImport("__Internal")`（Editor 走 Mono、P/Invoke 延遲解析，測不出這個）⑥ `PlatformComposition.Create()` 回傳 Desktop 版 ｜ **建置期**：`DllImport("__Internal")` 只允許出現在 `NightShift.Platform.Web`；遊戲程式碼中任何前置處理式含 `UNITY_WEBGL` 者恰 1 處、位於 `PlatformComposition`，且必須帶 `!UNITY_EDITOR`（grep `^\s*#\s*(if|elif).*UNITY_WEBGL`；r2 依 r3 CX-8 統一位置）；asmdef 平台字串以 6000.3 Editor 的 Inspector 勾選產生、不手刻 JSON，EditMode 以 `CompilationPipeline.GetAssemblyDefinitionPlatforms()` 斷言 `WebGL` 是有效名稱（unity-specialist 判斷 Unity 會靜默忽略無法辨識的平台字串，那樣 `.Web` 會進所有平台編譯；旁證：Unity 自家 `com.unity.services.wire` 1.5.0 的 `unity-websocket-sharp.asmdef` 以 `"excludePlatforms": ["WebGL"]` 排除 WebGL，本機 6000.3.24f1 內建的 `Unity.UnifiedRayTracing.Runtime.asmdef` 也寫 `"WebGL"`）；**r2 新增**：EditMode 在 active target 為 WebGL 時斷言 `CompilationPipeline.GetAssemblies(AssembliesType.Editor)` 不含 `NightShift.Platform.Web`（「include-only 組件不在 Editor 編譯」目前只是由文件與 exclude 案例對稱推得）；組合根對 `.Web`（include-only）的 asmdef 參照在 Editor／桌面編譯時被靜默拿掉——W1 只實證過 exclude 的方向（Wire.Internal → websocket-sharp），這個方向若不成立，第一次編譯就會大聲失敗 |
## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None（r1 依 r2 §3B Resolution 1：原列 ADR-0001。本 ADR 依賴的是分層紀律 `movement_logic_outside_core`——那已是 registry 的全專案禁用模式，不是 ADR-0001 的決策輸出；真正的消費方向相反，是 ADR-0001 的轉接層取用本 ADR 的 `IPageLifecycle`。保留原列會在 ADR-0001 r1 引用 ADR-0006 的 `PeerKey` 時成環 0001→0006→0005→0001。ADR-0001 改列於 Related Decisions） |
| **Enables** | ADR-0006 連線會談生命週期（`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector` 是它的平台輸入，r2 成對 Accept）；ADR-0001 的 `adoptInput` 供給側（ADR-0001 Decision 9 的 `visibilitychange` 通道）；Steam 桌面 build（Alpha，`docs/research/steam-feasibility-2026-10-01.md`）；日後「傳輸協定與混房」ADR（DTLS×WSS 探針）；「Steam 整合範圍」ADR（Rich Presence、成就、雲存檔） |
| **Blocks** | 所有會新增 `DllImport("__Internal")` 的 story（netcode #12／#17／#28、大廳 #8 帶碼連結、剪貼簿）——必須經本層；第一個正式 netcode 實作 story 前本 ADR 應 Accepted |
| **Ordering Note** | **與 ADR-0006 r2 成對 Accept**（它依賴本 ADR r2 的 `InstallLeaveBeacon(url, method, authorization)`、`SetLeaveConfirmation`、`RestoredFromBackForwardCache` 與組合根）。Accept 順序依 r3 §4A：ADR-0005 r2＋ADR-0006 r2 → ADR-0001 r1 → ADR-0002／0003 r1。**本 ADR 不得把 ADR-0006 列入 Depends On**——ADR-0006 已依賴本 ADR，反向再列即成兩點環。與 ADR-0004（機台互動組 Core 分層，保留編號）互不依賴、可並行 |

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
- **IL2CPP＋Managed Stripping High**：`.jslib` 對應的 C# 端必須 `[Preserve]`（`[P-7]` 證實此寫法存活）。
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
   - **兩個實作都由直接呼叫可達**，所以不需要 `[RuntimeInitializeOnLoadMethod]`、不需要 `[assembly: AlwaysLinkAssembly]`，也沒有「無人註冊」這種狀態。r1 的寫法有兩個問題。其一，`.Web` 沒有任何組件引用，只靠 RIOLM 進場；而 W1 的 WebGL build 裡，UnityLinker 只把場景裡有型別的兩個組件當 root，其餘 26 個玩家組件中有 8 個整包被剝掉（`Player67b9b48d.dag.json`），`.Web` 沒加 `AlwaysLinkAssembly` 就會無聲消失。其二，「無人註冊時回 Desktop」需要 `NightShift.Platform` 引用 `.Desktop`，而 `.Desktop` 為了實作介面又要引用 `NightShift.Platform`，形成 asmdef 循環，Unity 不允許；況且 WebGL build 根本不編譯 `.Desktop`，這個分支在 Web 上不可能存在，只會把剝除造成的失效掩蓋成「靜默假值」——正是本 ADR 要防的事。
   - **前提：組合根本身必須從 root 可達**。它要被開機場景裡的 `MonoBehaviour` 呼叫，或者住在 Assembly-CSharp 裡；不得只靠 RIOLM 進場，否則剝除問題會原封不動搬到組合根身上。
   - `Application.runInBackground` 的斷言與強制設定移到 `DesktopPlatformServices` 的建構子（r1 寫在「`PlatformRoot.Create()` 的 Desktop 分支」，那個分支已不存在）。
   - 不用 `Application.platform` 執行期分支選實作——連結期問題只能在編譯期解。雙鎖比照 ADR-0001：asmdef 約束＋建置期 grep，缺一不可。
4. **`.jslib` 只有一個檔**：`Assets/Plugins/WebGL/NightShiftPlatform.jslib`，`mergeInto(LibraryManager.library, …)`；參數只收原生數值與 UTF-8 字串指標（`UTF8ToString`），字串回傳走 `_malloc`＋`stringToUTF8`（W1 全檔既證寫法，6.3 無變更跡象）。受控物件（例如 `IReadOnlyDictionary`）收不進 `.jslib`，所以介面一律以字串表達（r2 依 r3 EA-9）。**`[Preserve]` 標在 JS→C# 的 `SendMessage` 回呼接收方法上**（如 `OnCopyResult`，`W1WebProbe.cs:162`），不是每個 `extern` 宣告——extern 由直接呼叫可達，`[P-7]` 證實無標記亦存活。W1 的 `W1Web.jslib` 是原型，不遷移，只當對照；它有三個行為**不得**帶進正式碼：只安裝一次（`:67`，重裝被忽略，token 換了也換不進去）、在 `visibilitychange → hidden` 也送出（`:88-92`，切分頁就刪房）、以 `sendBeacon` 為主路徑（`:70-86`）。
5. **桌面語意表**（R1）：

| 介面 | Web（`.jslib`） | Desktop（含 Editor） |
|---|---|---|
| `IPageLifecycle.IsHidden` | `document.visibilityState == "hidden"`，邊緣事件 `HiddenChanged` | **恆 false**——桌面失焦、最小化時主迴圈不節流（`Application.runInBackground = true` 為契約）；netcode #17 在桌面「一律在前景」。焦點**不在**本介面：`adoptInput` 的焦點來源是 `Cursor.lockState`（ADR-0001 Decision 9），失焦時指標本就解鎖 |
| `IPageLifecycle.NowMs` | `performance.now()` | `Time.realtimeSinceStartupAsDouble × 1000`（單調） |
| `IPageLifecycle.IsOnline` | `navigator.onLine`（只作快速否定，netcode #20） | `Application.internetReachability != NotReachable`（同樣只作快速否定） |
| `IUnloadNotifier` | **離開通知只在 `pagehide` 送出**（r2 依 r3 FV-4、arlong 2026-10-03 裁決）：`fetch(url, { method, headers: { Authorization }, keepalive: true })`，無 body、不設 `Content-Type`、`credentials` 維持預設。**不分 `persisted`**：Chrome 149 起（release notes "Active WebSocket connections no longer prevent a page from entering the Back/Forward Cache"；WPT 在 Chrome 154 通過）與 Safari（WebKit bug 143505；WPT 在 Safari 27 通過）進 bfcache 時會主動關閉 WebSocket（Firefox 有 WebSocket 就不進 bfcache；Chrome 是否已對所有使用者開放，T1-Web 實測），session 實際上已經斷了，之後被逐出又沒有事件，不送就永遠沒人送。`.jslib` 的單發旗標只擋 bfcache 往返後的第二次 `pagehide`。r1 的「`pagehide`（主）＋`beforeunload`（備援）」實際上是由 `beforeunload` 送出：依 HTML 規範，`beforeunload` 先對整棵框架樹派發、需要時先問使用者，按「留下」就整個中止，`pagehide` 不會觸發（§7.3.1.6、§7.4.2.4）。所以 `beforeunload` **永不送出**，只負責確認框：`SetLeaveConfirmation(true)` 時才掛上監聽器，處理器只做 `e.preventDefault(); e.returnValue = "1";`；`false` 時卸下（Chrome 建議永遠不要無條件掛 `beforeunload`）。是否真的跳框由瀏覽器決定：iframe 本身要有 sticky activation；Chrome 與 Firefox 在跨源 iframe 內會跳框，WebKit 擋下與祖先不同源的 frame 要求的確認框，所以 Safari 在 itch.io 上不跳框。`pageshow` 的 `persisted == true` → `.jslib` 先觸發 `RestoredFromBackForwardCache`（只供記錄與測試），隨即自行 `location.reload()`：WebSocket 已被瀏覽器關閉、`DELETE` 已送出；重載在 `.jslib` 內完成，C# 端沒有、也不需要重載的介面（r2 依審查補：否則依 R1，沒有人能執行這次重載）。`visibilitychange` 只餵 `IPageLifecycle`，**不得**送出（背景≠離開）。不用 `sendBeacon`：它只能 POST、帶不了 `Authorization`（r1 依 r2 X2）。重複呼叫 `InstallLeaveBeacon` 即覆寫（token 換發後重裝）；`ClearLeaveBeacon()` 之後關分頁不再送。瀏覽器下限：Firefox ≥ 133 才有 fetch keepalive；Safari 的 BCD 記 13，但帶 preflight 的 keepalive 未實證，下限交 ADR-0006 V10 | `Application.wantsToQuit` 第一次回 false → ADR-0006 的 Teardown（NGO 在跑才 `Shutdown()`；client `LeaveAsync`、Host `DeleteAsync`）→ 等「NGO 已停（`OnServerStopped`／`OnClientStopped` 已觸發，或 `!IsListening`）**且** leave／delete 的 Task 已完成」，或 1 s 逾時 → `CompleteQuit()` 設旗標後 `Application.Quit()`，第二次 `wantsToQuit` 回 true（r2 依 r3 EA-7：r1 沿用的「`Shutdown()` 0.08 s」是對端收到的時間；`Shutdown()` 本身只設旗標）。不得以 `ISession.State` 判斷完成：Host 的 `DeleteAsync` 在送出刪房請求之前就把 State 設為 `Disconnected`（`SessionHandler.cs:901-903`），照 State 判斷會在 DELETE 送出前就退出。反過來，State 一離開 `Connected`，MPS 的 `OnQuitting` 就直接返回（`:1224-1229`），所以 Host 刪房與 MPS 的 remove-self（`LeaveAsync` 對 player-host 等於 `RemovePlayer(自己)`）並行，只可能發生在 `DeleteAsync` 開始之前，而 Teardown 一開始就呼叫它。逾時先到時，進行中的 `DELETE` 可能隨行程結束而中斷，退化為服務端約 132 s 回收。`Application.quitting` 只在退出無法再取消時觸發，所以第一次被擋下的退出不會引發 MPS 的自動 leave。本層不依賴 MPS 在退出時自動 leave。`SetLeaveConfirmation` 在桌面是 no-op，`RestoredFromBackForwardCache` 永不觸發 |
| `ILaunchParams.RoomCode` | `IsEmbedded` 時解析 **`document.referrer`** 的 `?code=`（r1 依 r2 X3；`[P-4]` 實測：itch.io 把自身 `location.search` 改寫成 `?v=…`，父頁 `parent.location.search` 跨域被擋，唯一可讀的是 referrer）；非 iframe 部署（如 GitLab Pages 直開）讀自身 `location.search`。referrer 可能被瀏覽器隱私設定或 `Referrer-Policy` 削減，所以回 `null` 是正常情況，輸碼備援不可砍（netcode AC2） | 命令列 `--code=XXXX`；**Steam 延伸點**：Rich Presence `connect` 落到同一欄位（Steam 整合 ADR 再定） |
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
    event Action<bool> HiddenChanged;      // 邊緣觸發；Desktop 永不觸發；只供計時與手勢中斷，不得當成離開
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
    event Action RestoredFromBackForwardCache;   // r2：pageshow(persisted) 時觸發，隨後 .jslib 自行 location.reload()；WebSocket 已被瀏覽器關閉、DELETE 已送出。Desktop 永不觸發
    event Func<bool> QuitRequested;        // Desktop: Application.wantsToQuit；回 false = 延後退出；Web: 不觸發
    void CompleteQuit();                   // Desktop: 有序關閉完成後真正 Application.Quit()（第二次 wantsToQuit 回 true）
}

public interface ILaunchParams
{
    string RoomCode { get; }               // 無則 null（Web 的 referrer 被削減時常見——輸碼備援不可砍）；Steam Rich Presence connect 的落點
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

T0 fake 各一個（`FakePageLifecycle` 可手動切 hidden／online；`FakeUnloadNotifier` 記錄 `Install`／`Clear`／`SetLeaveConfirmation` 的呼叫、可觸發 `QuitRequested` 與 `RestoredFromBackForwardCache`；其餘回固定值），放在 `NightShift.Platform.Tests`。

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
- **Cons**: 要同時維持三個機制（RIOLM、`AlwaysLinkAssembly`、註冊表狀態）；6000.3 文件對 `AlwaysLinkAssembly` 的措辭是「package or precompiled assemblies」，Assets 底下的 asmdef 是否同樣適用沒有明講，要實建驗證；RIOLM 在 High 下雖然本來就是 root（`managed-code-stripping-marking-rules`），註冊時序仍是一個額外的變因。UGS 另外還有第二道保險——Services Core 在 build 時生成 `link.xml`（`LinkFileGenerator.cs:80-121`），但它只認 UGS 自己的介面，照顧不到我們的組件。
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

### Risks
- **`Application.runInBackground` 漏設**（桌面失焦 → 主迴圈停 → Host 心跳斷）→ 緩解：`DesktopPlatformServices` 的建構子斷言並強制設為 true（r2：r1 掛在已不存在的 `PlatformRoot` Desktop 分支）；T1-Desktop ③ 驗證。
- **組合根不在 root 可達的路徑上**（r2）→ 它若只靠 RIOLM 進場，IL2CPP 剝除的問題會原封不動搬到它身上 → 緩解：由開機場景的 `MonoBehaviour` 呼叫 `PlatformComposition.Create()`；T1-Web ① 與 T1-Desktop ⑥ 在 Release 下斷言實作型別。
- **include-only 參照的行為只是推論**（r2）→ 組合根在 Editor 與桌面編譯時，對 `.Web` 的參照「應該」被靜默拿掉（W1 只實證過 exclude 的方向）→ 推論若錯，第一次編譯就會大聲失敗，不會靜默。
- **桌面 `wantsToQuit` 路徑被工作管理員強殺略過**（Alt-F4 與點 X 同走 WM_CLOSE，應會觸發——T1-Desktop ①a／①b 分開驗，不預設同類）→ 緩解：與 Web 一樣，#20 心跳仍是最終救命索（netcode `[P-14]`：kill -9 後 87 s 才被偵測，心跳 8 s）；本層不承諾覆蓋強殺。
- **asmdef 平台約束漏設或被人拿掉** → 桌面 IL2CPP 連結期硬性失敗且 Editor 測不出 → 緩解：建置期 grep 第二鎖；T1-Desktop ⑤ 每次 standalone build 都是一次驗證。
- **Editor Play Mode 被拿來頂替退出路徑測試** → 緩解：Validation 明寫只認 standalone。
- **QoS 於桌面的行為未實測**（本專案只知道 WebGL 會拋例外）→ 緩解：T1-Desktop ②；失敗退時區鏈，功能不受影響只是 region 較差。
- **有人在本層外新增 `DllImport`** → 緩解：建置期 grep（`grep -rn 'DllImport("__Internal")' Assets --include=*.cs` 必須只命中 `NightShift.Platform.Web`）。
- **MPS 升版改變 `RelayProtocol.Default` 語意** → 緩解：Decision 6 顯式指定，不依賴 `Default`。
- **keepalive `fetch` 沒送到**（V10）→ Host 關頁退化為服務端約 132 s 才回收，但 ADR-0006 的本地 30 s 靜默提示已保底；client 關頁退化為 Host 的心跳路徑 8 s。r2 的證據比 r1 強很多：UGS 對 itch.io 來源的 preflight 已實測放行（204、`Access-Control-Allow-Origin: *`、允許 `DELETE` 與 `authorization`、`Max-Age 600`）；WPT 的「cross-origin redirect＋preflight」keepalive 子測試在 Chrome 154、Firefox 157、Safari 27 全數通過；keepalive 的 64 KiB 配額只算 body，無 body 的 `DELETE` 佔 0。剩下的風險是瀏覽器下限（Firefox < 133 沒有 keepalive，ESR 128 也沒有）與行動端多半不觸發 `pagehide`。若真有主流瀏覽器不支援，備案是一個只收 `sendBeacon`、代為帶 Bearer 呼叫 Lobby REST 的極小轉發端點——那會引入新的伺服器元件，需另寫 ADR。`fetchLater`（Chrome 135+ 獨有，跨源 iframe 預設只有 8 KiB 配額）不當主路徑。
- **`Referrer-Policy` 或瀏覽器隱私設定削減 referrer**（r1）→ `RoomCode` 回 `null`、退到輸碼（netcode AC2 保底）。`[P-4]` 在 itch.io 實測可讀，但使用者端的設定不在我們控制內。
- **asmdef 平台字串打錯會被靜默忽略**（unity-specialist 判斷）→ `.Web` 進所有平台編譯，桌面 IL2CPP 連結期失敗 → 緩解：Inspector 產生字串＋`GetAssemblyDefinitionPlatforms()` EditMode 斷言（r1）；T1-Desktop ⑤ 仍是最後一道。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| netcode-session.md | #17 背景分流：以 `visibilitychange` 在背景當下標記 `t_hidden`／`t_visible`，時間源必須單調（`:258-265`） | `IPageLifecycle.HiddenChanged`＋`NowMs`；桌面恆前景、主迴圈不節流 |
| netcode-session.md | #12 離開通知須 `sendBeacon`／`keepalive` 語義，`pagehide`＋`beforeunload` 需 `.jslib`、雙觸發須冪等、確認框 best-effort（`:205-210`、`:229-236`，`[P-18]`；TR-netcode-010） | `IUnloadNotifier`（r2）：`InstallLeaveBeacon(url, method, authorization)` 只在 `pagehide` 送出、不分 `persisted`；`SetLeaveConfirmation` 只掛確認框、永不送出；`RestoredFromBackForwardCache`；桌面改 `wantsToQuit` 有序關閉 |
| netcode-session.md | #20 判定表第 2 列 `navigator.onLine`（`:301`） | `IPageLifecycle.IsOnline`，兩平台皆只作快速否定 |
| netcode-session.md | #8 帶碼連結是主要入口（`:140`、`[P-4]`；TR-netcode-007） | `ILaunchParams.RoomCode`：iframe 內讀 `document.referrer`（r1）、可能為 `null`，輸碼備援不可砍；`IsEmbedded`；桌面命令列；Steam 延伸點 |
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
1. 本 ADR Accepted 後，第一個正式 netcode 實作 story 先建 `NightShift.Platform`（四個 asmdef：介面、`.Web`、`.Desktop`、`.Composition`；一個 `.jslib`；五個 fake），再實作 #12／#17／#28。開機場景放一個呼叫 `PlatformComposition.Create()` 的 `MonoBehaviour`。
2. `W1WebProbe.cs`／`.jslib` 保留為原型對照，不遷移；W1 第 2／4 批的 `[P-7]`／`[P-19]` 改經本層重跑（T1-Web），`[P-18]` 改由 ADR-0006 的 T1-Web (l0)–(l5) 取代。
3. CI（尚未建立）加入兩條 grep：`DllImport("__Internal")` 只在 `NightShift.Platform.Web`；`^\s*#\s*(if|elif).*UNITY_WEBGL` 在遊戲程式碼恰 1 處、位於 `PlatformComposition`，且帶 `!UNITY_EDITOR`（r2 依 r3 CX-8 統一：r1 的 Migration 3 寫「只在 `PlatformRoot`」，與 R2、D3 互相矛盾，照寫的 CI 會擋下合規的程式碼）。
4. Steam 桌面 build 於 Alpha 啟動時，只需新增 `NightShift.Platform.Desktop` 的 QoS 相依與命令列解析，轉接層零改動。
5. **r2 遷移**：`.jslib` 重寫，不從 W1 搬——只掛 `pagehide` 一個送出監聽器，`beforeunload` 隨 `SetLeaveConfirmation` 動態增刪，`pageshow` 監聽 `persisted`；明文禁止 W1 的三個行為（只安裝一次、`visibilitychange` 送出、`sendBeacon` 主路徑）。`RoomCode` 改讀 `document.referrer`（`[P-4]` 重跑）。

## Validation Criteria
- T0：五個 fake 存在，netcode #12／#17／#28 的純邏輯測試只依賴 fake（不引用 UnityEngine）；`FakeUnloadNotifier` 能斷言 `InstallLeaveBeacon`／`ClearLeaveBeacon`／`SetLeaveConfirmation` 的呼叫順序。
- T1-Web：見 Verification Required 的 ①–⑤；離開通知與確認框的完整案例在 ADR-0006 的 T1-Web (l0)–(l5)（Playwright，三引擎，`page.close({ runBeforeUnload: true })`，包裝頁與遊戲頁不同 hostname）。
- T1-Desktop（Windows standalone，非 Editor Play Mode）：①a 點 X／Alt-F4 → 「NGO 已停且 leave／delete 的 Task 已完成」或 1 s 後退出，刪房請求在退出前送出、不與 MPS 的 remove-self 並行 ①b 強殺不承諾、心跳接手 ② QoS ≤ 2 s 回 region、失敗退時區鏈 ③ 失焦／最小化 `IsHidden` 恆 false、主迴圈持續，且 `DesktopPlatformServices` 的 `runInBackground` 斷言生效 ④ DX12 預設下 build 可跑 ⑤ IL2CPP 連結成功、build 內零 `DllImport("__Internal")` ⑥ `PlatformComposition.Create()` 回傳 Desktop 版。
- 建置期：兩條 grep 皆通過；`.Web.asmdef` 含 `"includePlatforms": ["WebGL"]`；Core asmdef 無 `NightShift.Platform` 參照；EditMode 以 `CompilationPipeline.GetAssemblyDefinitionPlatforms()` 斷言 `WebGL` 是有效平台名（r1）；active target 為 WebGL 時，`CompilationPipeline.GetAssemblies(AssembliesType.Editor)` 不含 `NightShift.Platform.Web`（r2）。
- 決策正確的訊號：Alpha 開 Steam 版時，netcode／FP／MI 轉接層零改動。

## Related Decisions
- ADR-0001（r1 由 Depends On 改列 Related：轉接層契約、`adoptInput`、grep 守門）；ADR-0002（Verification ③ WSS 上 RPC 順序——Decision 6 固定 WSS 的理由之一）；ADR-0003（預設值靜默生效的先例）。
- ADR-0006 連線會談生命週期（消費 `IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector`；與本 ADR r2 成對 Accept；`InstallLeaveBeacon` 的簽章、確認框、bfcache 恢復事件與 `RoomCode` 的 referrer 來源都是它提出的義務；它的 Migration 3 登記了 ADR-0001 r1 的 pointer lock T1-Web 項）。
- `docs/architecture/architecture-review-2026-10-03-r3.md`（r2 的修訂依據）。
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
| FV-4 | 🟡 必修（與 ADR-0006 共同） | 只在 `pagehide` 送出、不分 `persisted`（**推翻 r3 Resolution 第二點**）；`beforeunload` 只掛確認框（`SetLeaveConfirmation`）；`RestoredFromBackForwardCache`；瀏覽器矩陣 | Decision 5 表；Key Interfaces；Verification ⑤ |
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
