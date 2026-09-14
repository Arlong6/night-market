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
| 第 2 批 | itch.io 部署（`[P-4]`／`[P-6]`／`[P-19]`） | 未開始 |
| 第 3 批 | Release Web build（`[P-7]`／`[P-18]`） | 未開始 |
| 第 4 批 | tick ＋ RTT ＋ AC22 聯測 | 未開始 |

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

### 尚未回答

`[P-10]`(a) 服務端多久回收背景分頁的 session、`[P-14]` kill 行程的偵測時刻、
`[P-4]`/`[P-6]`/`[P-19]` itch.io 平台行為、`[P-7]`/`[P-18]` Release build 的 `.jslib` 行為。

## 注意

依 `.claude/rules/prototype-code.md`：本目錄是 **throwaway**。
若 W1 的結論支持進入生產，程式碼**重寫**而非移植；本目錄保留供參考但不再擴充。
生產程式碼不得引用 `prototypes/`。
