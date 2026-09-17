# W1 — 網路同步層技術原型

## 測試什麼假設

`design/gdd/netcode-session.md` 是全專案最高技術風險的系統（新引擎 ＋ Web transport
無官方端到端範例）。四輪設計評審後，creative-director 裁定 **r4 是最後一輪散文式評審**，
理由是約四成的確認項是「對一個沒人跑過的系統的斷言」——散文評審沒有可以反駁它們的儀器。

本原型就是那台儀器。它驗證 GDD 的 Provisional Assumptions 表（`[P-1]` ~ `[P-20]`），
並回填「影響」欄。**GDD 明訂：沒有回填影響欄的原型報告不算完成。**

判準（GDD 標頭）：**任何 fallback 會殺掉 MVP-必達 AC 的假設，其 fallback 本身即為 blocking。**

## 怎麼跑

環境：Unity **6000.3.24f1**（＝GDD 釘選的 6.3 LTS）＋ Web Build Support。
套件：NGO 2.13.2、Multiplayer Services 2.3.1、UTP 2.7.4。
UGS Project ID 已寫入 `ProjectSettings.asset`（`cloudProjectId` ＋ `cloudEnabled: 1`）。

```bash
U="/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/MacOS/Unity"
P="$(pwd)"   # prototypes/w1-netcode

# 引擎事實與 API 形狀（不連線）
"$U" -runTests -batchmode -nographics -projectPath "$P" -testPlatform EditMode \
     -testResults ../w1-editmode-results.xml -logFile ../w1-tests.log

# 真實連上 UGS（會建立並刪除 session；用量對 50 CCU/月 額度微不足道）
"$U" -runTests -batchmode -nographics -projectPath "$P" -testPlatform PlayMode \
     -testResults ../w1-playmode-results.xml -logFile ../w1-playmode.log

# 雙進程：Host 被 kill -9 後 client 多久發現
cd .. && ./w1-p14-run.sh
```

`w1-client/` 是本專案的副本，**只為雙進程測試存在**（Unity 不允許兩個實例開同一專案）。
它的 `productName` 刻意改為 `w1-client`，讓 PlayerPrefs 分開，兩邊才會拿到**不同的匿名帳號**。

## 現況

**進行中。** 第 0 批（文件查詢）與第 1 批（API 形狀 ＋ runtime）已完成。

| 批次 | 內容 | 狀態 |
|---|---|---|
| 第 0 批 | 純 API 文件查詢，零原型成本 | 完成，並以 EditMode 測試在實機複驗 |
| 第 1 批 | Sessions API 形狀 ＋ 真實連線 | 完成（`[P-10]`(a) 除外） |
| 第 2 批 | Release Web build ＋ itch.io 部署 | 完成（`[P-4]`／`[P-6]`／`[P-7]`／`[P-19]`） |
| 第 3 批 | 背景分頁下的服務端回收秒數（`[P-10]`(a)／`[P-18]`） | 完成（主迴圈只被節流到 1Hz，`#23b` 的擔憂解除） |
| 第 4 批 | tick ＋ RTT ＋ AC22 聯測、JS 解壓的 CPU 成本 | **RTT 與 tick 已完成**；JS 解壓 CPU 成本、`[P-18]`、`[P-20]`(b) 未做 |

## 發現

完整記錄在 `design/gdd/reviews/netcode-session-review-log.md`，以下是摘要。

### 推翻設計的

- **權威模型寫錯了。** GDD #2 原文「Owner 權威是 NetworkTransform 預設，不改寫」——
  client-server 拓撲下 `AuthorityMode` **預設是 `Server`**，必須顯式改寫。
  照原文實作會得到 server 權威的移動，而**本地 host 測試永遠看不出來**。
- **斷線處置序列的第 2 步建立在為假的前提上。** `DontDestroyWithOwner` 預設 `false`
  ＝預設銷毀，且銷毀發生在 `OnClientDisconnectCallback` **之前**、同一 call stack。
  「掉落手持物」寫成第 2 步時，物件早已不存在。已改為 prefab 的前置條件。
  且 `RemoveOwnership()` **不做 unparent**，「掉落在原地」必須自己實作。
- **約束⑧的前提是錯的。** 它假設 RPC 按 network tick 批次，因而判定互動延遲 AC
  在 10Hz 下不可達。**RPC 完全不受 tick 影響**（每幀於 `PostLateUpdate` 送出）；
  受影響的是 NetworkVariable 與 NetworkTransform。該 AC 因此**可達成**，
  但追加硬規則：互動結果一律走 RPC，不得用 NetworkVariable 承載。

### 讓設計變簡單的

- **房間碼字集已避開易混淆字元。** 實測 6 樣本皆為固定 6 碼全大寫，
  字集 `689BCDFGHJKLMPQRTW`——無母音、無 `0/O/1/I/L`。
  因此 **#8 的「易混淆字元正規化」規則已刪除**，`[P-1]` 的 fallback 也不需要。
- **排歧表比原設計簡單。** `ISession` 直接提供 `Host` 與 `HasPlayer(id)`，
  不需要「輪詢 roster 再比對」。**B4（全輪最嚴重的 blocking）徹底解決。**
- **Lobby 延後建連可行，且優於預期。** 不帶 network 的 session **連 NGO 單例都不需要存在**；
  `StartRelayNetworkAsync` 可延後呼叫；`StopNetworkAsync` 讓局間 teardown 有了 API。

### 新增的風險

- **雲端 session 的保活訊號掛在 Unity PlayerLoop 上**（`ActionScheduler` 使用
  `PlayerLoopSystem.JoinPlayerLoopSystem()`），間隔 **10 秒**。
  WebGL 主迴圈由瀏覽器動畫影格驅動，**背景分頁會被節流或停止** →
  保活訊號停送。這正是 `[P-10]`(a) 擔心的事，已在原始碼層面確認機制，
  只剩「服務端多久回收」待實測。
- **Relay 對每個 client 連線的 TTL 是 10 秒**，靠 NGO 自動 PING 重置。
  同樣受背景分頁節流影響。這讓 Core Rule #23（Lobby 延後建連）
  **從優化升格為必需**。
- **兩次 ownership 變更需間隔 6 個 network tick**，否則 owner-write 的
  NetworkVariable 更新可能遺失。10Hz 下即 **600ms**，對「互相拋接道具」的玩法
  是可感知的延遲，已列為待裁決事項。

### 第 1 批（連線）

- **大廳延後建連可行，且優於預期**：不帶 network 的 session **連 NGO 單例都不需要存在**；
  `StartRelayNetworkAsync` 可延後呼叫；`StopNetworkAsync` 讓局間 teardown 有了 API。
- **B4 徹底解決**：`ISession` 直接有 `Host` 與 `HasPlayer(id)`，排歧表不必輪詢名冊再比對。
- **`RemovePlayerAsync` 存在**——r4 全表唯一「沒有退路」的查證項解除。
- **房間碼** 固定 6 碼全大寫，字集 `689BCDFGHJKLMPQRTW`（無母音、無 `0/O/1/I/L`）
  → **刪掉了一條設計規則**（易混淆字元正規化）。
- **身分跨 session 延續**：`CurrentPlayer.Id` ＝ `AuthenticationService.PlayerId`。
- 🔴 **Host 被 `kill -9` 後，大廳的其他人要 132.61 秒才知道**；但 **優雅離開只要 1.14 秒**。
  差 116 倍 → `beforeunload` ＋ 主動通知從「best-effort」升格為**關鍵機制**。
  慢路徑由 arlong 裁決為「本地逾時提示」（新常數 `lobby_host_silence_timeout_sec`）。
- **意外**：host migration 在 MPS 是一等公民 → GDD 的「MVP 無 migration」是**選擇**而非限制（OQ#18）。

### 第 2 批（Web build ＋ itch.io）

- **`.jslib` 雙向在 Release ＋ Stripping High 下全通過**——`[Preserve]` 確實有效。
- 🔴 **帶碼連結不會穿過 iframe**：`location.search` 被換成 itch.io 的 `?v=`，
  父視窗跨域。**`document.referrer` 是唯一路徑**，且 referrer 可被隱私設定削減
  → 輸碼備援不可砍。
- 🔴 **itch.io 不支援 Brotli**，還會把 `.br` 解壓後重送 → 傳輸量 **2.00 倍**
  （資料檔膨脹 4.32 倍）。**遊戲照樣能跑，壞消息全在傳輸量裡。**
  解法已驗證：`decompressionFallback = true`（產出 `.unityweb`）→ 回到 **0.99 倍**。
  **這是強制建置規範。**
- 🔴 **iframe 的 `allow` 沒有 `clipboard-write`** → 複製邀請連結必須降級為可全選文字框。
- ⚠ **這三項在本地全是綠的**：兩項測過通過，第三項在本地根本觀察不到（伺服器是自己寫的）。
  「必須真的部署」這件事本身就是結論。

### 第 4 批（RTT ＋ tick ＋ region）

跑法：`./w1-rtt-run.sh [tick] [region]`，雙進程經真實 Relay WSS，每組 20 樣本。

- **`RPC 不受 network tick 閘門控制` 由推論升格為實測事實。**
  tick 改十倍，往返一毫秒未動：

  | tick | min | median | p95 | max |
  |---|---|---|---|---|
  | 10 Hz | 329.2 | 331.1 | 335.8 | 337.2 |
  | 1 Hz | 329.2 | 330.7 | 333.0 | 336.5 |

  若 RPC 真的按 tick 批次，1Hz 下每筆最長要等 1 秒，p95 必落在秒級。它沒有。
  約束⑧ 的原前提正式作廢，AC22 不再受 tick 威脅。

- 🔴 **但同一次量測掀出一個原設計完全沒有的變數：Relay region。**
  上表兩組都是**預設 region**，而 `interact_rtt_p95_ms` 的上限是 300ms——
  **p95 335.8ms，遊戲邏輯一行都還沒跑就已經超標。**
  只把 region 指定為 `asia-northeast1`（其餘完全不變）：

  ```
  samples=20;min=85.4;median=88.8;p95=94.5;max=104.4;tick=10;region=asia-northeast1
  ```

  **3.7 倍。AC22 的成敗實際上由 region 決定，不是由 tick 決定。**

- **補測第三點把模型釘死了**（`europe-west4`：median 434.3／p95 437.8ms）。
  兩個進程都在台灣，故 `RTT = 4 × d(台灣, R)`，三點反推的單程值
  （東京 22.2ms／美中 82.8ms／荷蘭 108.6ms）都落在該路線的合理範圍。
  **模型成立 → 可以拿來推還沒量的組合。**

- **arlong 裁決「讓國外的人也可以參與」→ 不能寫死任一大區。**
  解法不是折衷，是可證明的：`RTT_i = 2 × (d(i,R) + d(R,H))`，由三角不等式，
  **`R = H` 讓每個 client 同時拿到各自的理論下限**；移向任一 client 只會讓其他人變差。
  → **relay 貼著 Host 選**（GDD Core Rule #28），由時區查表決定、可覆寫。
  ⚠ 修正一個先前的錯誤前提：**Host 不付這筆延遲**（它是權威，自身互動本地結算），
  所以最佳化目標是所有 *client* 的延遲，Host 不計入。
  <br>殘留代價已如實記錄：歐洲玩家在台灣 Host 房中的裸往返，由已測值夾擠得
  **217–306ms**——**能玩，但正好壓在 300ms 邊緣**。故 AC22 拆為同區（必達 300ms）
  與跨區（降級契約：慢但正確、有回饋、不卡死）。
  ⚠ 該區間是**夾擠推得，非直接量測**，待有海外測試者時補量。
  而這條**沒有自動解**：Relay 的 QoS（自動挑最近 region）在 Web 上拋
  `PlatformNotSupportedException: QoS SDK does not support WebGL`，本作又是 Web-only。
  已升為 GDD 約束⑮ ＋ Core Rule #28 ＋ registry 的兩張對照表
  （`relay_region_by_timezone`／`relay_region_offset_fallback`）＋ AC22／22a/22b。
  **OQ#20 已結案。** 可用 region 無台灣／香港節點，東亞最近是東京。

- **Web 的協定設定有兩個會讓人踩空的地方**，兩個都是實際撞到才發現的：
  1. Relay 協定**只能在建 session 當下**經 `SessionOptions.WithNetworkOptions()` 指定
     （`RelayNetworkOptions(RelayProtocol)` 已 `[Obsolete]`，而延後建連用的
     `StartRelayNetworkAsync` 根本沒有 protocol 參數）。
     好消息是它**只設定不啟動**——Core Rule #23 的延後建連與指定 WSS 可以並存，
     實測 `CreateSessionAsync` 後 `NetworkState` 仍為 `Stopped`。
  2. **協定不會從 Host 傳染給加入者。** Host 設好 WSS 且 `IsListening=True` 之後，
     加入端只傳房間碼照樣拋 `Mismatched Relay configuration and network interface`；
     `JoinSessionOptions` 必須自己再宣告一次。
     → 實作上協定設定必須集中成共用 helper，漏掉任一條加入路徑都會**只在該路徑失敗**，
     而 Host 端一切正常——這種不對稱失敗在本地單機測試中看不出來。

- 附帶：`EnableSceneManagement` 兩端必須一致，否則 NGO 在握手階段就拒絕連線
  （測試場景不在 build list 時會先撞到 `Scene Hash ... does not exist`）。

### 第 4 批（續）— ownership transfer（`[P-20]`(b)）

跑法：`./w1-own-run.sh [tick] [region]`，雙進程，一個 owner-write `NetworkVariable<int>`。
協定：host 交出所有權 → client 在 `OnGainedOwnership` 當下寫入 marker 並回報 →
host 等 `delay` 毫秒後收回 → 讀值比對。

- **OQ#17 消解，而且是被量測消解的，不是被裁決消解的。**
  GDD 原文「引擎要求兩次 ownership 變更間隔 ≥6 tick，10Hz → 600ms 可感知交接延遲」
  兩個前提都不成立：那個 `6` 只存在於一則**被 `LogLevel == Developer` 擋著的警告**裡，
  **不延遲也不阻擋任何交接**；而交接實測 **100-104ms（tick=10）／101-105ms（tick=1）**，
  **不受 tick 影響**，與同 region 的 RTT 同量級。**沒有 600ms 這回事。**

- **真正存在的是 owner-write NetworkVariable 的遺失窗口，且它 ≈ 一個 tick 週期**（非六個）：

  | delay ms | 0 | 40 | 80 | 120 | 160 | 240 | 400 | 700 |
  |---|---|---|---|---|---|---|---|---|
  | **tick=10** | 0/3 | 1/3 | **3/3** | 3/3 | 3/3 | 3/3 | 3/3 | 3/3 |
  | **tick=1** | 0/3 | 0/3 | 0/3 | 0/3 | 1/3 | 1/3 | 1/3 | 2/3 |

  tick=1 是刻意的對照組。存活率近乎 `delay ÷ tick 週期`，正是「寫入落在 tick 週期內的
  **隨機相位**」該有的分布。機制：送出端在**下一個 tick 序列化時**才評估 `CanWrite()`，
  屆時若已非 owner，該筆 delta 根本不會被送出。

- 🔴 **唯一的壞消息，而且比原設計假設的嚴重**：伺服器收到越權 delta 時記錄
  `Client wrote to NetworkVariable without permission.` **`No more variables can be read.
  This is critical.`** —— 它**中止解析整則訊息的其餘部分**，
  所以**同一物件上其他無關的 NetworkVariable 也會一起掉**。
  → **約束⑧ 的「互動結果一律走 RPC」從效能考量升格為正確性要求。**

- 兩個過程中的坑：(1) 第一版測試「失敗」的訊息本身就是上面那個發現 ——
  UTF 把未預期的 Error 日誌當失敗，**若當初直接把它關成雜訊就會錯過**。
  (2) runtime 造的 prefab 若 `SetActive(false)`，client 端拋
  `OverflowException: Reading past the end of the buffer`：NGO 反序列化時的
  `networkBehaviour?.Synchronize(...)` 在 behaviour 為 null 時**靜靜跳過但資料仍在緩衝區**，
  而 inactive 實例不跑 `Awake`。host 端沒事只因為我手動啟用了 —— 又一次只在跨進程才現形的
  不對稱失敗。

### 第 4 批（續）— JS 解壓的 CPU 成本

第 2 批留下的帳：`decompressionFallback = true` 當時記錄為「傳輸量減半，公式⑤ 的
T_load 預算恢復」，但解壓的 CPU 時間沒量。量出來之後——**預算沒有恢復，
只是從網路搬到了 CPU。**

量法：在 build 的 `index.html` 插計時點，在 localhost 量（網路趨近 0），
對照組是把三個 `.unityweb` 用原生 brotli **預先解壓、檔名不變**再服務一次
（Unity 的 loader 對無壓縮標頭的檔案會原樣通過，實測成立）。同一分頁先後載入。

| | 值 |
|---|---|
| 壓縮 → 解壓後 | 6.98 MB → **34.13 MB**（4.89×） |
| 原生 C brotli | **86 ms**（397 MB/s） |
| 壓縮版 CPU | 2268-2590 ms（暖）／3600-4323 ms（冷） |
| 預先解壓版 CPU | **331-412 ms** |
| **差值＝JS 解壓** | **≈ 2.0-2.2 s（16.3 MB/s，慢原生約 23 倍）** |
| wasm 編譯（27.5MB，單獨計時） | 346 ms |

**我中途推錯過一次，記在這裡**：拿到「CPU 4.3 秒」時我第一個假設是 wasm 編譯，
聽起來很合理；單獨量完是 **346 ms**，不到十分之一。**若當時沒去單獨量，
就會寫下一條「build 越小編譯越快」的錯誤結論，而真正的槓桿會被漏掉。**

**對公式⑤ 的衝擊**：原式沒有 CPU 項。補上後代入 50MB 硬標 →
`T_load ≈ 40.4 s`，AC7a 的 ≤25s 破，**有效 build 天花板降到約 28 MB** → **OQ#21**。

✅ **該複驗當天就做了，沒有翻案。** 自寫限速伺服器（`w1-serve-throttled.py`），
判別法：若解壓與下載重疊，網路變慢時 CPU 項會被吸收而縮小。

| 網路 | 下載窗口 | **資料在手後 CPU** | 總計 |
|---|---|---|---|
| localhost（暖） | ~0.03 s | **2.27-2.59 s** | 2.5 s |
| 20 Mbps | 2.45 s | **3.23 s** | 5.82 s |
| 5 Mbps | **9.35 s** | **2.51 s** | 12.05 s |

**下載拉長 300 倍，CPU 紋風不動 → 不重疊，相加成立，40.4s 不是高估。**
5 Mbps 下 wasm 於 198→9380ms 下載而 t_ready 在 12052ms，解壓確實在下載**之後**才開始。
OQ#21 至此無技術前置，剩下純粹是產品取捨。

順帶修掉量測自身的一個缺陷：原本用「各檔 duration 加總」當網路時間，但檔案是**並行**
下載的，加總會重複計算；改成牆鐘窗口才對。localhost 上看不出差別，一限速就差很多。

### 尚未回答

`[P-18]` `sendBeacon` 在 unload 的可靠性（需重建 build，尚未做）——**W1 只剩這一項**。
OQ#10（行動瀏覽器的背景回收）與 OQ#18（是否啟用 host migration）待裁決。
另有兩項由 API 形狀推得但未實測：跨班次能否重選 region（`StopNetworkAsync` →
`StartRelayNetworkAsync(另一個 region)`）、以及真實跨洲往返的實測值。

## 注意

依 `.claude/rules/prototype-code.md`：本目錄是 **throwaway**。
若 W1 的結論支持進入生產，程式碼**重寫**而非移植；本目錄保留供參考但不再擴充。
生產程式碼不得引用 `prototypes/`。
