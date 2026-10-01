# ADR-0005: 平台抽象層——瀏覽器能力是介面，不是 `#if`

## Status
Proposed

## Date
2026-10-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS（6000.3）、IL2CPP＋Managed Stripping High、NGO 2.13.2、MPS 2.3.1、UTP 2.x |
| **Domain** | Core / Platform（Web 橋接 ＋ Networking 的平台鉤子） |
| **Knowledge Risk** | HIGH——6.1–6.3 超出模型訓練資料；本 ADR 只引用 engine-reference 與 W1 實測已證實的行為 |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`；`modules/web.md`（:17-18 WebSocket 僅 UTP↔UTP、:40-60 背景分頁主迴圈、:130 硬指標）；`modules/multiplayer.md`（:109 `ReconnectionTimeoutMS` 僅 DTLS、:143-145 Relay 三協定與 `UseWebSockets`、:159-172 首選拓撲）；`breaking-changes.md`（:11 Windows 預設 DX12、:45 Instant Games 棄用）；`deprecated-apis.md`（:17-18 通用 `[Rpc]`、MPS Sessions）；`design/gdd/netcode-session.md`（#8／#12／#17／#20／#27／#28，`[P-7]`／`[P-13]`／`[P-14]`／`[P-18]`／`[P-19]`）；ADR-0001 Decision 9；`prototypes/w1-netcode/Assets/Scripts/W1WebProbe.cs`；`docs/research/steam-feasibility-2026-10-01.md` |
| **Post-Cutoff APIs Used** | ① MPS 2.3.1 `RelayProtocol.WSS`／`Default`（`Default` 在非 WebGL 變 DTLS，`RelayProtocol.cs:34-38`——technical-director 與 unity-specialist 兩次獨立原始碼核對）② `UnityTransport.UseWebSockets`（UTP 2.x，`multiplayer.md:143`）③ `com.unity.services.qos` 1.4.1 於桌面平台：套件已在相依樹，桌面路徑為 `#if UGS_QOS_SUPPORTED && !UNITY_WEBGL`（`UGS_QOS_SUPPORTED` 由 asmdef versionDefines 賦值，理應涵蓋 6000.3，**未實機確認**）；WebGL 端拋 `PlatformNotSupportedException` 已核實（`WrappedQosService.cs:107-109`）。其餘 `Application.wantsToQuit`／`Application.Quit`／`Application.runInBackground`／`Application.internetReachability`／`Time.realtimeSinceStartupAsDouble`／`GUIUtility.systemCopyBuffer`（standalone 可寫）皆為訓練截止前 API，6.1–6.3 無異動紀錄 |
| **Verification Required** | T1-Web：既有 W1 第 2／4 批（`[P-7]` stripping 存活、`[P-18]` beacon 8/8、`[P-19]` 剪貼簿）改經本層重跑，結果不得變 ｜ T1-Desktop（**只在 Windows standalone 測，不得用 Editor Play Mode 頂替**——停止 Play Mode 不是應用程式 Quit，`wantsToQuit` 極可能不觸發，未對 6.3 覆核）：①a 點 X／Alt-F4（皆走 WM_CLOSE）→ `wantsToQuit` 路徑 ≤ 1 s 完成 `NetworkManager.Shutdown()`＋session leave 後才真正退出 ①b 工作管理員強殺 → 確認本層不承諾、#20 心跳接手 ②`IRegionSelector` 桌面 QoS 在 ≤ 2 s 內回 region，失敗退時區鏈；同時確認 `UGS_QOS_SUPPORTED` 在 6000.3 確有定義 ③`IPageLifecycle.IsHidden` 於桌面失焦、最小化時皆為 false 且主迴圈不節流（`Application.runInBackground = true`）④DX12 預設下 build 可跑（Steam Overlay 另於 Steam 整合 ADR 驗）⑤**Windows IL2CPP standalone 連結成功**——`.Web` 組件被 asmdef 排除後，桌面 build 不得含任何 `DllImport("__Internal")`（Editor 走 Mono、P/Invoke 延遲解析，測不出這個） ｜ 建置期：`DllImport("__Internal")` 只允許出現在 `NightShift.Platform.Web`；`#if UNITY_WEBGL` 在遊戲程式碼恰 1 處且位於 `NightShift.Platform.Web` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（Proposed）——轉接層契約：Core 只收 `adoptInput` 布林，`visibilitychange` 通道由轉接層消費（Decision 9）。本 ADR 是那條通道的供給側 |
| **Enables** | Steam 桌面 build（Alpha，`docs/research/steam-feasibility-2026-10-01.md`）；日後「傳輸協定與混房」ADR（DTLS×WSS 探針）；「Steam 整合範圍」ADR（Rich Presence、成就、雲存檔） |
| **Blocks** | 所有會新增 `DllImport("__Internal")` 的 story（netcode #12／#17／#28、大廳 #8 帶碼連結、剪貼簿）——必須經本層；第一個正式 netcode 實作 story 前本 ADR 應 Accepted |
| **Ordering Note** | 與 ADR-0004（機台互動組 Core 分層，保留編號）互不依賴、可並行。ADR-0001 仍 Proposed 時本 ADR 可先寫，但兩者需一起在 `/architecture-review` 過關 |

## Context

### Problem Statement

netcode GDD、第一人稱控制器 GDD、機台互動組 GDD 與 ADR-0001 共同依賴約十項**只有瀏覽器才有**的能力，而且每一項在 Web 上都沒有 C# 直達路徑，只能靠 `.jslib`：

| 能力 | 誰用 | 來源 |
|---|---|---|
| `visibilitychange`（背景分頁當下標記時刻） | netcode #17 背景分流、FP C14、MI C16 | netcode `:258`、`[P-7]` |
| `performance.now()` 單調時鐘 | netcode #17 的 `t_hidden`／`t_visible` | netcode `:264-265` |
| `beforeunload`＋`sendBeacon` 離開通知 | netcode #12 | `:205-210`、`[P-18]` 8/8 實證 |
| `navigator.onLine` | netcode #20 判定表第 2 列（快速否定） | `:301` |
| 帶碼連結（自身與 iframe 父頁的 query） | netcode #8、大廳 UI | `[P-4]`、`:140` |
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
- R1 每項瀏覽器能力都有一個介面，桌面實作提供**語意等價**的行為，或明寫「不適用」的固定值——不得是假值。
- R2 遊戲程式碼中 `#if UNITY_WEBGL && !UNITY_EDITOR` **恰好一處**，且住在 Web 實作組件的註冊入口；`DllImport("__Internal")` 只存在於 Web 實作組件，而該組件以 asmdef 平台約束在桌面 build 根本不編譯（雙鎖：asmdef＋建置期 grep，缺一不可——比照 ADR-0001）。
- R3 Core 組件（`NightShift.*.Core`）不引用本層；轉接層把介面結果轉成 Core 已定義的純值（如 `adoptInput`）。
- R4 每個介面有 T0 可用的 fake。
- R5 Web 行為與 W1 實證逐位相同（`[P-7]`／`[P-18]`／`[P-19]` 重跑不變）。
- R6 Editor 就是桌面平台：Editor 一律用 Desktop 實作，不再有 `"(editor)"` 假值（arlong 2026-10-01 裁決）。
- R7 為 Steam 留延伸點但不定 Steam 介面（arlong 2026-10-01 裁決）：Rich Presence 的 `connect` 字串落在 `ILaunchParams.RoomCode`。

## Decision

**瀏覽器專屬能力收進一個獨立組件 `NightShift.Platform` 的五個小介面；Web 與 Desktop 各一個實作；只有組合根用 `#if` 選一次。Core 看不到本層，轉接層只拿自己需要的那一個介面。**

1. **組件**：`NightShift.Platform`（asmdef，可引用 UnityEngine，不引用任何 Core 或 Netcode）。子組件 `NightShift.Platform.Web`（含全部 `DllImport("__Internal")` 與唯一的 `.jslib`）、`NightShift.Platform.Desktop`。Core 組件的 asmdef 不得引用 `NightShift.Platform`——`/story-readiness` 與建置期 grep 同時擋。
2. **五個介面**（見 Key Interfaces）：`IPageLifecycle`（可見性＋單調時鐘＋連線狀態）、`IUnloadNotifier`（離開通知）、`ILaunchParams`（帶碼連結）、`IClipboard`、`IRegionSelector`。每個消費者的建構子只收自己需要的那一個；沒有「`IPlatformBridge` 大介面」。
3. **選擇實作靠 asmdef 平台約束＋自我註冊，組合根本身沒有 `#if`**（r1 依 unity-specialist B2 修正）：
   - `NightShift.Platform.Web.asmdef`：`"includePlatforms": ["WebGL"]`——桌面 build **根本不編譯**這個組件，`DllImport("__Internal")` 不可能進到 Windows IL2CPP 的原生連結期（單靠 IL2CPP 可達性分析排除從未驗證過，而且 Editor 走 Mono、P/Invoke 延遲解析，測不出連結失敗）。
   - `NightShift.Platform.Desktop.asmdef`：`"excludePlatforms": ["WebGL"]`——Editor 與所有 standalone 都編譯，Editor 因此天然就是 Desktop（R6）。
   - 兩個實作組件各以 `[RuntimeInitializeOnLoadMethod(SubsystemRegistration)]` 向 `PlatformRoot` 註冊；`.Web` 的註冊入口用 `#if UNITY_WEBGL && !UNITY_EDITOR` 包住（這是遊戲程式碼裡**唯一**的 `#if UNITY_WEBGL`，擋的是「Editor 切到 WebGL 目標時 `.Web` 也會被編譯」的情況）。`PlatformRoot.Create()` 回傳已註冊者，無人註冊時回 Desktop。
   - 不用 `Application.platform` 執行期分支選實作——連結期問題只能在編譯期解。雙鎖比照 ADR-0001：asmdef 約束＋建置期 grep，缺一不可。
4. **`.jslib` 只有一個檔**：`Assets/Plugins/WebGL/NightShiftPlatform.jslib`，`mergeInto(LibraryManager.library, …)`、字串回傳走 `_malloc`＋`stringToUTF8`（W1 全檔既證寫法，6.3 無變更跡象）。**`[Preserve]` 標在 JS→C# 的 `SendMessage` 回呼接收方法上**（如 `OnCopyResult`，`W1WebProbe.cs:162`），不是每個 `extern` 宣告——extern 由直接呼叫可達，`[P-7]` 證實無標記亦存活。W1 的 `W1Web.jslib` 是原型，不遷移，只當對照。
5. **桌面語意表**（R1）：

| 介面 | Web（`.jslib`） | Desktop（含 Editor） |
|---|---|---|
| `IPageLifecycle.IsHidden` | `document.visibilityState == "hidden"`，邊緣事件 `HiddenChanged` | **恆 false**——桌面失焦、最小化時主迴圈不節流（`Application.runInBackground = true` 為契約）；netcode #17 在桌面「一律在前景」。焦點**不在**本介面：`adoptInput` 的焦點來源是 `Cursor.lockState`（ADR-0001 Decision 9），失焦時指標本就解鎖 |
| `IPageLifecycle.NowMs` | `performance.now()` | `Time.realtimeSinceStartupAsDouble × 1000`（單調） |
| `IPageLifecycle.IsOnline` | `navigator.onLine`（只作快速否定，netcode #20） | `Application.internetReachability != NotReachable`（同樣只作快速否定） |
| `IUnloadNotifier` | `beforeunload` → `sendBeacon(url, payload)`（`[P-18]`） | `Application.wantsToQuit` 回 false → 執行 `NetworkManager.Shutdown()`＋session leave（netcode 實測 `Shutdown()` 0.08 s）→ 完成或 ≤ 1 s 逾時後 `Application.Quit()`。桌面不需要 beacon：關閉是有序的 |
| `ILaunchParams.RoomCode` | 自身 query `?code=` → iframe 父頁 query（`[P-4]`） | 命令列 `--code=XXXX`；**Steam 延伸點**：Rich Presence `connect` 落到同一欄位（Steam 整合 ADR 再定） |
| `ILaunchParams.IsEmbedded` | `window.self !== window.top` | 恆 false |
| `IClipboard.TryCopyAsync` | Clipboard API **本質非同步**（`.then/.catch` 經 `SendMessage` 回呼，`W1Web.jslib:33-43`）；需 user gesture，iframe 可能被 permissions policy 擋（`[P-19]`）→ `Task<bool>` 在回呼抵達時完成 | `GUIUtility.systemCopyBuffer = text`，`Task.FromResult(true)` |
| `IRegionSelector.SelectRegionAsync` | `Intl.DateTimeFormat().resolvedOptions().timeZone` 查 `relay_region_by_timezone` → `relay_region_offset_fallback` → 預設值（Core Rule #28 原鏈） | QoS（`com.unity.services.qos`）取最低延遲 region → 失敗或逾時 2 s 時退到同一條時區鏈（桌面可用 `TimeZoneInfo.Local`）。規則「貼著 Host 選」不變，只是桌面多一個更準的第一步 |
| netcode #27 下載卡住偵測 | loader HTML 層，Unity 啟動前 | 不適用（無 loader） |

6. **傳輸協定在本 ADR 有效期間固定 WSS**：共用的 Relay helper 對所有平台**顯式**設 `RelayProtocol.WSS`＋`UnityTransport.UseWebSockets = true`，禁用 `RelayProtocol.Default`（MPS 2.3.1 在非 WebGL 平台會解析成 DTLS，與 `UseWebSockets = true` 對不上就拋 Mismatched）。桌面走 WSS 已由 W1 雙進程實測（Editor 桌面進程，`RttRoleTests.cs:65,122`，p95 94.5 ms）。改 DTLS 是另一份 ADR 的事，前提是 DTLS×WSS 混房探針通過。
7. **Steam 不在本 ADR**：不定 `ISocialPlatform`；成就、雲存檔、Overlay 到 Alpha 的 Steam 整合 ADR。本 ADR 只保證 Steam 版不會踩到假值。

### Architecture Diagram

```
                         NightShift.Platform（介面，可引用 UnityEngine）
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ IPageLifecycle  IUnloadNotifier  ILaunchParams  IClipboard  IRegionSelector │
   └──────────────────────────────────────────────────────────────────────────┘
            ▲                                            ▲
   NightShift.Platform.Web                      NightShift.Platform.Desktop
   （唯一的 .jslib ＋ DllImport("__Internal")）  （Application.* / GUIUtility / QoS）
            ▲                                            ▲
            └──────────── PlatformRoot.Create() ─────────┘
                    遊戲程式碼裡唯一的 #if UNITY_WEBGL && !UNITY_EDITOR
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
    event Action<bool> HiddenChanged;      // 邊緣觸發；Desktop 永不觸發
}

public interface IUnloadNotifier
{
    void InstallLeaveBeacon(string url, string payload);   // Web: beforeunload→sendBeacon；Desktop: no-op
    event Func<bool> QuitRequested;        // Desktop: Application.wantsToQuit；回 false = 延後退出；Web: 不觸發
    void CompleteQuit();                   // Desktop: 有序關閉完成後真正 Application.Quit()
}

public interface ILaunchParams
{
    string RoomCode { get; }               // 無則 null；Steam Rich Presence connect 的落點
    bool IsEmbedded { get; }               // Web: iframe 內；Desktop: false
}

public interface IClipboard
{
    Task<bool> TryCopyAsync(string text);  // Web: Clipboard API 非同步、需 user gesture；false 時 UI 顯示手動複製（r1：原同步 bool 無法承載 W1 已證的回呼流程）
}

public interface IRegionSelector
{
    Task<string> SelectRegionAsync(IReadOnlyList<string> available, string fallback, CancellationToken ct);
}

public static class PlatformRoot
{
    public static void Register(PlatformServices services);   // 由 .Web／.Desktop 的 RuntimeInitializeOnLoadMethod 呼叫
    public static PlatformServices Create();                   // 回傳已註冊者；無人註冊 → Desktop。本方法沒有 #if
}

// NightShift.Platform.Web.asmdef   →  "includePlatforms": ["WebGL"]
// NightShift.Platform.Desktop.asmdef →  "excludePlatforms": ["WebGL"]
// .Web 註冊入口：#if UNITY_WEBGL && !UNITY_EDITOR（遊戲程式碼唯一的一處）

public sealed class PlatformServices          // 五個介面的簡單容器，供轉接層拆用；不是 service locator
{
    public IPageLifecycle PageLifecycle { get; }
    public IUnloadNotifier UnloadNotifier { get; }
    public ILaunchParams LaunchParams { get; }
    public IClipboard Clipboard { get; }
    public IRegionSelector RegionSelector { get; }
}
```

T0 fake 各一個（`FakePageLifecycle` 可手動切 hidden／online；`FakeUnloadNotifier` 可觸發 `QuitRequested`；其餘回固定值），放在 `NightShift.Platform.Tests`。

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

## Consequences

### Positive
- Steam 版的平台差異集中在兩個組件，netcode／FP／MI 的轉接層零平台分支。
- 五個介面都有 fake，netcode #12／#17／#28 的邏輯可在 T0 測（現在是 T1 才碰得到）。
- `#if` 恰一處、`DllImport` 恰一組件，建置期 grep 可擋回歸（沿用 ADR-0001 的 grep 守門）。
- Editor＝Desktop，不再有「Editor 綠、Web 紅」以外的第三種行為。

### Negative
- 多兩個 asmdef 與一個 `.jslib` 的搬遷；W1 的 `W1WebProbe` 要對照重驗三批實測。
- `IPageLifecycle.IsHidden` 在桌面恆 false，等於桌面放棄 netcode #17 的背景分流——這是刻意的（桌面主迴圈不節流），但 `Application.runInBackground = true` 成為契約，忘記設會讓桌面失焦時整個 Host 停擺。
- QoS 套件只在桌面載入，多一個平台專屬相依。

### Risks
- **`Application.runInBackground` 漏設**（桌面失焦 → 主迴圈停 → Host 心跳斷）→ 緩解：`PlatformRoot.Create()` 的 Desktop 分支在建構時斷言並強制設為 true；T1-Desktop ③ 驗證。
- **桌面 `wantsToQuit` 路徑被工作管理員強殺略過**（Alt-F4 與點 X 同走 WM_CLOSE，應會觸發——T1-Desktop ①a／①b 分開驗，不預設同類）→ 緩解：與 Web 一樣，#20 心跳仍是最終救命索（netcode `[P-14]`：kill -9 後 87 s 才被偵測，心跳 8 s）；本層不承諾覆蓋強殺。
- **asmdef 平台約束漏設或被人拿掉** → 桌面 IL2CPP 連結期硬性失敗且 Editor 測不出 → 緩解：建置期 grep 第二鎖；T1-Desktop ⑤ 每次 standalone build 都是一次驗證。
- **Editor Play Mode 被拿來頂替退出路徑測試** → 緩解：Validation 明寫只認 standalone。
- **QoS 於桌面的行為未實測**（本專案只知道 WebGL 會拋例外）→ 緩解：T1-Desktop ②；失敗退時區鏈，功能不受影響只是 region 較差。
- **有人在本層外新增 `DllImport`** → 緩解：建置期 grep（`grep -rn 'DllImport("__Internal")' Assets --include=*.cs` 必須只命中 `NightShift.Platform.Web`）。
- **MPS 升版改變 `RelayProtocol.Default` 語意** → 緩解：Decision 6 顯式指定，不依賴 `Default`。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| netcode-session.md | #17 背景分流：以 `visibilitychange` 在背景當下標記 `t_hidden`／`t_visible`，時間源必須單調（`:258-265`） | `IPageLifecycle.HiddenChanged`＋`NowMs`；桌面恆前景、主迴圈不節流 |
| netcode-session.md | #12 離開通知須 `sendBeacon`／`keepalive` 語義，`beforeunload` 需 `.jslib`（`:205-210`，`[P-18]`） | `IUnloadNotifier.InstallLeaveBeacon`；桌面改 `wantsToQuit` 有序關閉 |
| netcode-session.md | #20 判定表第 2 列 `navigator.onLine`（`:301`） | `IPageLifecycle.IsOnline`，兩平台皆只作快速否定 |
| netcode-session.md | #8 帶碼連結是主要入口；iframe 父頁 query 轉發（`:140`、`[P-4]`） | `ILaunchParams.RoomCode`／`IsEmbedded`；桌面命令列；Steam 延伸點 |
| netcode-session.md | Core Rule #28 region 貼著 Host 選；時區須經 `.jslib` `Intl`（`:680-700`）；QoS 不支援 WebGL（`:487`） | `IRegionSelector`：Web 時區鏈、桌面 QoS → 時區鏈；規則不變、機制分平台 |
| netcode-session.md | `[P-19]` 剪貼簿需 user gesture＋`.jslib` | `IClipboard.TryCopy` 回 false 時 UI 退手動複製 |
| netcode-session.md | 兩平台 tick rate 一致（`NetworkConfig.cs:351` 連線雜湊） | 本 ADR 不動 tick；Decision 6 固定 WSS |
| first-person-controller.md | C14 分頁隱藏時移動輸入歸零、回前景第一幀不移動 | FP 轉接層由 `IPageLifecycle` 產 `adoptInput`（ADR-0001 Decision 9） |
| machine-interaction.md | C16 分頁隱藏由轉接層主動中斷手勢，不依賴 Input System `canceled` | MI 轉接層訂閱 `IPageLifecycle.HiddenChanged` |
| systems-index.md | #20 平台服務：Web 橋接 MVP、Steam Alpha | 本 ADR 定 MVP 的那一半；Steam 一半留 Alpha ADR |

## Performance Implications
- **CPU**：`HiddenChanged` 邊緣觸發、`NowMs` 為一次 `.jslib` 呼叫或一個屬性讀取；每幀成本可忽略（< 0.01 ms）。`SelectRegionAsync` 每班次一次。
- **Memory**：五個單例物件；Web 版多一個 `.jslib`（數 KB，計入 44 MB 硬標但可忽略）。
- **Load Time**：無變化；QoS 只在桌面且與 auth 預熱並行。
- **Network**：桌面 QoS 探測數個 region 各一次 ping（每班次一次）；其餘零流量。

## Migration Plan
1. 本 ADR Accepted 後，第一個正式 netcode 實作 story 先建 `NightShift.Platform`（三個 asmdef、一個 `.jslib`、五個 fake），再實作 #12／#17／#28。
2. `W1WebProbe.cs`／`.jslib` 保留為原型對照，不遷移；W1 第 2／4 批的三項實測改經本層重跑（T1-Web）。
3. CI（尚未建立）加入兩條 grep：`DllImport("__Internal")` 只在 `NightShift.Platform.Web`；`#if UNITY_WEBGL` 只在 `PlatformRoot`。
4. Steam 桌面 build 於 Alpha 啟動時，只需新增 `NightShift.Platform.Desktop` 的 QoS 相依與命令列解析，轉接層零改動。

## Validation Criteria
- T0：五個 fake 存在且 netcode #12／#17／#28 的純邏輯測試只依賴 fake（不引用 UnityEngine）。
- T1-Web：`[P-7]`／`[P-18]`／`[P-19]` 三批實測經本層重跑，結果與 W1 相同（stripping 存活、beacon 8/8、剪貼簿 gesture 條件）。
- T1-Desktop（Windows standalone，非 Editor Play Mode）：①a 點 X／Alt-F4 退出路徑 ≤ 1 s 完成 Shutdown＋leave ①b 強殺不承諾、心跳接手 ②QoS ≤ 2 s 回 region、失敗退時區鏈 ③失焦／最小化 `IsHidden` 恆 false 且主迴圈持續 ④`runInBackground` 斷言生效 ⑤IL2CPP 連結成功、build 內零 `DllImport("__Internal")`。
- 建置期：兩條 grep 皆通過（`DllImport("__Internal")` 只在 `.Web`；`#if UNITY_WEBGL` 恰 1 處且在 `.Web`）；`.Web.asmdef` 含 `"includePlatforms": ["WebGL"]`；Core asmdef 無 `NightShift.Platform` 參照。
- 決策正確的訊號：Alpha 開 Steam 版時，netcode／FP／MI 轉接層零改動。

## Related Decisions
- ADR-0001（轉接層契約、`adoptInput`、grep 守門）；ADR-0002（Verification ③ WSS 上 RPC 順序——Decision 6 固定 WSS 的理由之一）；ADR-0003（預設值靜默生效的先例）。
- `docs/research/steam-feasibility-2026-10-01.md`（本 ADR 的動機與 Steam 時程）。
- `design/gdd/netcode-session.md`、`design/gdd/systems-index.md` #20。
- 後續：ADR「傳輸協定與 DTLS×WSS 混房」（VS 前探針後）、ADR「Steam 整合範圍」（Alpha）。
