# Architecture Review Report r3 — 大夜班 (Night Shift)

> **Date**: 2026-10-03（觸發＝ADR-0006 r1＋ADR-0005 r1 寫入，commit `78350dd`）
> **Mode**: `/architecture-review` full（增量審查：只有 3 個輸入變動，其餘延續 r2 判定並逐列抽查）
> **Engine**: Unity 6.3 LTS（6000.3.24f1）、C# 9.0、IL2CPP＋Managed Stripping High、Web (WebGL)；NGO 2.13.2、MPS 2.3.1、UTP 2.7.4（PackageCache 實際解析值）
> **GDDs Reviewed**: 5（`netcode-session.md` #1/#2、`first-person-controller.md` #3、`machine-interaction.md` #5、`product-database.md` #6、`game-concept-night-shift.md`）＋ `systems-index.md`——皆未變動
> **ADRs Reviewed**: 5（ADR-0001／0002／0003 未變；ADR-0005 r1、ADR-0006 r1；皆 **Proposed**；ADR-0004 保留編號未寫）
> **前幾輪**: r2 `architecture-review-2026-10-01-r2.md`（FAIL）、首輪 `architecture-review-2026-10-01.md`（FAIL）——三份並存，本檔不覆寫它們
> **自 r2 以來的變動**: ADR-0006（r1，508→619 行）、ADR-0005（r1，259→287 行）、`docs/registry/architecture.yaml`（13 條 revised、3 條新增）。GDD、ADR-0001／0002／0003、`tr-registry.yaml`、`traceability-index.md` 皆未動（mtime 與 `git diff 5b97c50 78350dd -- design/gdd/` 為證）
> **證據來源**: 套件原始碼 `prototypes/w1-netcode/Library/PackageCache/`（NGO、MPS、UTP、Authentication、Wire）；本機 Unity 6000.3.24f1 內建套件。以下 `NGO`／`MPS` 指該目錄下的 `com.unity.netcode.gameobjects@cfd429cc91ec/Runtime`、`com.unity.services.multiplayer@0a90950aff70/Runtime`
> **審查方式**: 平行審查＋對抗式驗證（見 §10）；主審親自抽查 FV-1、EA-1、EA-2、EA-4 的原始碼與文件行
> **不在範圍**: 同 r2；`docs/architecture/architecture.md`、`control-manifest.md`、`docs/consistency-failures.md`、`production/epics/` 皆不存在（Phase 3b、Phase 6、Reflexion log 跳過）

---

## 0. 一句話

**r1 把 r2 的四條必修修好三條半；但它新寫的三塊（`StartFailed` 復原、`shift_eta`、keepalive 離開通知）與一條從沒人走過的路徑（MPS 中途加入的 join 流程）又長出 Accept 前必修。覆蓋率數字與 r2 完全相同。**

最重的是 **FV-1**：MPS 2.3.1 在 approval 拒絕時，會把中途加入者移出 session，所以 Lobby\* 在主路徑上進不去。這不是局部修法，需要先裁決 Lobby\* 的入口改走哪條路。其餘必修都是局部修法：改一個 URL、改一個掛點、拆一個型別、加一個 assembly 屬性、改一條送出規則。

---

## 1. Traceability Summary

| 項目 | 首輪 | r2 | **r3** | r2→r3 |
|---|---|---|---|---|
| **Total requirements** | 227 | 228 | **228** | 0（本輪無新 TR） |
| ✅ Covered | 50 | 71（31.1%） | **71（31.1%）** | 0（netcode-007 ↑、netcode-010 ↓） |
| ⚠️ Partial | 70 | 74（32.5%） | **74（32.5%）** | 0 |
| ❌ Gap | 107 | 83（36.4%） | **83（36.4%）** | 0 |
| **Foundation 層 Gap** | 30 | 20 | **20** | 0 |

| GDD | TR | ✅ | ⚠️ | ❌ | 本輪變化 |
|---|---|---|---|---|---|
| `netcode-session.md` | 46 | 25 | 19 | 2 | 007 ⚠️→✅；010 ✅→⚠️ |
| `first-person-controller.md` | 44 | 26 | 11 | 7 | 無（011 的降級理由加重） |
| `machine-interaction.md` | 57 | 7 | 18 | 32 | 無 |
| `product-database.md` | 34 | 0 | 5 | 29 | 無 |
| `game-concept-night-shift.md` | 19 | 7 | 9 | 3 | 無 |
| `systems-index.md` | 28 | 6 | 12 | 10 | 無 |

**Foundation 層 20 條 Gap 不變**：product 13（TR-product-001–007、014、016、018、020–022）、machine 4（TR-machine-010、023、027、054）、fpc 2（TR-fpc-029、040）、netcode 1（TR-netcode-033）。ADR-0006 r1 與 ADR-0005 r1 都沒有觸及 G2／G4／G5／G6／G7／G8／ADR-0004 的範圍，所以這個數字本輪本來就不會動。

### 狀態變動（2 列）

| TR | r2 | r3 | 理由 |
|---|---|---|---|
| TR-netcode-007 | ⚠️ | ✅ | r2 只卡在 X3。ADR-0005 r1 已改為 iframe 內讀 `document.referrer`（:87），可能為 null，輸碼備援不可砍（:146）；registry `launch_params` 已同步；房間碼走 `JoinSessionByCodeAsync`（0006 D2）。「大小寫不敏感、可貼上」視為 GDD #8 的 UI 規則。附註：MPS 的 `JoinSessionByCodeAsync` 不做大小寫正規化（`WrappedMultiplayerService.cs:96`），轉接層或 UI 要自己轉大寫——屬實作細節 |
| TR-netcode-010 | ✅ | ⚠️ | **驗證員推翻追溯審查員的「維持 ✅」**。TR 原文含「確認框 best-effort」，GDD AC42（MVP 必達，:1467）要求 Host 在 InShift 關分頁時跳 `beforeunload` 確認框。兩份 ADR 對確認框零決策，`IUnloadNotifier` 也沒有掛確認框的介面。更糟的是 r1 的「雙事件＋單發旗標」讓 `beforeunload` 成了實際送出點，玩家按「留下」時 `DELETE` 已經送出（FV-4）。r2 判 ✅ 時沒有檢查確認框這一款 |

理由有變、狀態不變的列見附錄（22 列）。

### ADR-0006 r1 自報與本審查判定的差異

- E12 宣稱「補 13 列」屬實：r2 點名的 12 列加上 TR-netcode-046，其中 7 列 partial 都加了「部分」標記。
- **自報沒標「部分」，本審查判 ⚠️**：TR-netcode-011、018、028、044、046；TR-concept-010、TR-index-021、022。後三列在同一格文字裡就把實質裁決交給了 G2／ADR-0004。
- **依它自己的收錄口徑漏報**（它收了 product-026、machine-019）：TR-netcode-027、029、TR-concept-001、TR-index-018、TR-machine-020、TR-fpc-011、027、028，都應以「部分」補列。TR-fpc-011 尤其該列：本 ADR 的 D4 直接決定它的鍵型別，卻沒把與 ADR-0001／0003 的衝突寫進自報。
- :543「machine C10／C20」列沒有 TR-ID：C10 與 TR-machine-019 重複，C20 屬 ADR-0004。應改掛 TR-ID 或刪除。
- ADR-0005 r1 漏列它確實覆蓋的 TR-concept-011、019、TR-fpc-015、TR-machine-037，只是自報遺漏。它在 :242 對 #20 自報「本 ADR 定 MVP 的那一半」，但 TR-index-027 仍判 ⚠️（FV-4）。

---

## 2. r2 修訂項核對

### 2A. Accept 前必修四條

| r2 項 | 判定 | 依據 |
|---|---|---|
| **E1** 斷線時手持物在 Host 存活、在每個 client 消失 | ✅ **已修（契約層）** | D7 前提 1–3（:148-151）、第 2 步（:157）、V12、T1 (i′)、registry `avatar_destroyed_with_owner`。驗證員獨立重追兩種觸發源、兩端，結論如下。avatar 設 `DontDestroyWithOwner = true` 後，NGO 只做 `RemoveOwnership`（`NGO Connection/NetworkConnectionManager.cs:1392`），回呼在其後（:1567）。client 端 `InvokeBehaviourNetworkDespawn`（`Spawning/NetworkSpawnManager.cs:1767`）先於 `Object.Destroy`（:1854）。`AutoObjectParentSync = false` 時 `OnTransformParentChanged` 直接 return（`Core/NetworkObject.cs:2553-2559`），所以 client 在 `OnNetworkDespawn` 內 `SetParent(null)` 合法，路線 (a) 成立。實作與驗證全押在 G2。⚠ T1 (i′) 寫「Editor 兩進程」，但 2 人房斷線後沒有留守 client 可斷言，至少要 3 個實例（GF-7） |
| **E2** Solo 的 approval 被靜默強制核准 | ⚠️ **修了一半** | 第 2 項（`MemberIds` 含 Host 自己，Online／Solo／沙盒三種）已落地。但 Host 自核准那一刻，第 4 項 `LateJoinCutoff` 讀的 `ShiftEndTs` 與 Host 當下的 `SessionPhase` 都沒有定義。若 `HostView` 從 `SessionRoot.ShiftEndTs` 這個 NV 取值，預設是 0：Host 照樣被拒→被強制核准→沒有 slot 0、沒有 avatar。第三道防線寫「`StartHost()` 返回後」，但 Online 的 `StartHost` 是 MPS 在 `StartRelayNetworkAsync` 內部呼叫的（`MPS …/NetworkManagerSession.cs:323-328`），轉接層沒有這個呼叫點。→ FV-3 |
| **E6** 心跳判定不切 NGO 連線 | ✅ | 第 5a 步（:161）＋NoSlot 丟棄（:119）。非空 reason 先排進延後佇列，在同幀 PostLateUpdate 斷線（`NetworkConnectionManager.cs:917-953`、`NetworkManager.cs:497-504`），鬼連線窗口 ≤ 1 幀。小前提：第 5 步必須以 `destroyGameObject = true` despawn（`NetworkSpawnManager.cs:186-194`），G2 要寫明 |
| **E8** 心跳 payload 過不了 ILPP | ✅ | Core 用純 BCL 的 `HeartbeatPayload`，轉接層用 `HeartbeatWire : INetworkSerializable`。逐欄固定寬度、無 packing、無長度前綴（`FastBufferWriter.cs:932-938`、`NetworkBehaviourILPP.cs:2540,2582`），酬載恰為 20 bytes。不採 memcpy 的理由成立。附註：20 bytes 是**酬載**；NGO 層線上總量約 46 B，Performance 寫的「≈ 40 B 含標頭」略低，不影響任何決策 |

### 2B. 其餘 r2 項

| 項 | 判定 | 殘留 |
|---|---|---|
| E3 `SinglePlayerTransport` | ✅ | 切換時機錯（EA-3） |
| E4 矩陣 32×11、主詞、Onboarding 回收 | ⚠️ | Settlement 欄的 peer 分流未定；#24a 主詞歸錯（FV-8） |
| E5 預檢時間基準 | ⚠️ | 時間基準解了，但晚到的讀者顯示錯誤（FV-2） |
| E7 冪等改在送出端 | ✅ | 單發旗標實際送出的是 `beforeunload`（FV-4） |
| E9 `Validate()` 11 條 | ⚠️ | 架構圖 :223 仍寫「約束①–⑮」（FV-9） |
| E10 拿掉指派冷卻 | ✅ | `HeartbeatMonitor` 缺 slot 重置點（FV-10） |
| E11 Lobby\* 沙盒與自動加入 | ⚠️ | 復原路徑的前提被 FV-1 推翻；切換時機（EA-3） |
| E12 文件層缺漏 | ✅ | — |
| E13 teardown 警告註明 | ✅ | 但「警告是預期的」多半不成立：常見路徑走 `TrySetException` 分支，根本不印（FV-7） |
| X1 身份傳播 | ❌ 未落地 | 依計畫在 ADR-0006 Accepted 之後；漏列的三項已補，另有新漏列（CX-1、CX-7） |
| X2 離開通知 headers／pagehide | ⚠️ | ADR-0006 沒承接 `ClearLeaveBeacon` 與 token 重裝（FV-6／CX-5）；路徑寫錯（EA-1） |
| X3 `document.referrer` | ✅ | — |
| X4 改名 `SessionPhase`／`JoinRejectReason` | ✅ | — |
| X5 `session_events` 消費者 | ⚠️ | 清零掛在 client 收不到的事件上（CX-2） |
| §3B 依賴邊改向、NPC 值域、`NightShift.Identity` | ✅ | 宣告環已拆；TickRate 隱性回指（CX-4） |
| C6 ADR-0005 R1 列舉制 | ✅ | 交棒對象不存在：「ADR-0001 的 T1-Web」沒有這一項（TR-fpc-019／020） |
| ASMDEF `"WebGL"` 字串 | ✅ | 本機 6000.3.24f1 內建的 `Unity.UnifiedRayTracing.Runtime.asmdef` 也寫 `"WebGL"`，旁證比 ADR 引的更強 |
| TR-netcode-046 | ⚠️ | FV-2、FV-1 |
| 首輪 C2、C3、C4、D1、D3、D4、D6、D9／D10 | ❌ 未動 | C3 的前提已變（CX-6）；C4 多了 CX-8 |

---

## 3. ADR-0006 r1／ADR-0005 r1 的新缺陷

嚴重度：🔴 HIGH＝Accept 前必修，且會靜默失效或需要設計裁決；🟡 MEDIUM；LOW／NOTE。**Accept 前必修 7 條：FV-1、FV-3、EA-1、FV-4、FV-5、EA-4，以及 §4 的 CX-2。**

### 3A. Accept 前必修

**FV-1 [🔴 HIGH，必修，需裁決] Lobby\* 入口在 MPS 2.3.1 下不可達**——Integration
- **ADR 怎麼寫**：D2（:91）說中途加入者在 `JoinSessionByCodeAsync` 的模組初始化裡自動啟網；D5 第 4 項說 `LateJoinCutoff` 之後 client 進 `LobbyWaiting`；D10 說 Lobby\* 期間 MPS 成員資格保留。GDD :758 對 Lobby\* 的定義是「approval 閘門拒絕但 MPS 成員已成立」。
- **原始碼怎麼走**：
  1. `JoinSessionByCodeAsync` → `SetupSessionAsync` → `await InitializeModulesAsync`（`MPS …/SessionManager.cs:257`）。
  2. 非 Host 走 `ValidateNetworkPropertyAsync` → `JoinNetworkAsync`（`NetworkModule.cs:113-124`、:516-541）。
  3. client `StartClient`，直到 `IsConnectedClient` 才完成（`NetworkManagerSession.cs:330-336`、:358-382）。
  4. approval 拒絕 → NGO client `Shutdown`（`NGO …/NetworkConnectionManager.cs:692-699`）→ `OnClientStopped` → 下一幀 `OnStopCompleted` 以 `NetworkManagerStartFailed` 結束（`NetworkManagerSession.cs:411-419`、:455-477）。
  5. 模組發 `StartFailed` 並 rethrow（`NetworkModule.cs:479-497`）。
  6. `SessionManager` 捕捉任何例外 → `CleanupSessionAsync(cleanupAndLeave = true)` → `session.LeaveAsync()`（`SessionManager.cs:311-347`），裡面會 `RemovePlayerAsync(PlayerId)`。
  7. `JoinSessionByCodeAsync` 拋出例外。
- **結果**：被截止擋下的人已經不是 MPS 成員。Lobby\*（等待畫面、練習沙盒、下一班自動合流；AC51 標 MVP）在主路徑上根本不存在。而且這條路上轉接層在拿到 `ISession` **之前**就失敗了，r1 新增的 `StartFailed` 復原無從訂閱。
- **連帶影響**（驗證員修正後的版本）：
  - 少見的競態：1 s 輪詢先看到 `!IsListening` → `TrySetCanceled`，這個例外被 `GameObjectsNetcodeNetworkHandler.cs:79-82` 吞掉。這條路上成員資格反而保住了，碰巧就是 ADR 要的 Lobby\*。但 `IClientSessionNetwork.State` 會謊報 `Started`，也不發 `StartFailed`；要到 #23a 移除網路屬性時才自動復位。
  - `StartFailed` 復原遇到 `StaleBuild`／`Duplicate` 不會形成迴圈，但會多打一輪 leave＋join＋Relay join，最後玩家還是被移出。
  - ⚠ **不確定**：`Duplicate` 情境下，被拒那一端以共用的 `PlayerId` 呼叫 `RemovePlayerAsync`，可能把合法的那一端一起移出。這取決於 UGS Lobby 對同 id 重複加入的行為，原始碼查不到。
- **查證狀態**：三個 agent 各自獨立走到同一結論（r1 修訂核對、netcode 追溯、對抗驗證），主審親自抽查 `SessionManager.cs:243-347`、`NetworkModule.cs:108-126`、:470-560、`NetworkManagerSession.cs:325-480`、`SessionHandler.cs:762-768`、`NetworkConnectionManager.cs:684-700`，全鏈吻合。**未實跑**——W1 從未測過遠端 client 被拒。
- **Resolution**：ADR-0006 r2 要先重新裁決 Lobby\* 的入口。以下候選皆未驗證：
  - **(a) 轉接層掌握 client 何時啟網**：用 MPS 的 `WithNetworkHandler<T>`（`SessionOptionsExtensions.cs:205`）自訂 handler，或查證「加入時不帶 network options 就不會自動啟網」是否成立。啟網前先讀 `shift_eta`，已過截止就不啟網、留在 session 內等待。
  - **(b) 過截止者照樣核准，但 `CreatePlayerObject = false`**，停在 `LobbyWaiting`。代價是會收到整班的複製流量、占 Relay 名額，而且要重審 R4「拒絕發生在任何資料交換之前」。
  - **(c) 接受被移出**：把 Lobby\* 改成 session 外的等待，前一班結束後以同碼重新加入。但 session 外收不到 `shift_eta`，只能輪詢加入，會撞 UGS 429。
  - 無論選哪條：`StartFailed` 復原必須先讀 `NetworkManager.DisconnectReason`，是 `JoinRejectReason` 就不復原；新增 **V13**（中途加入且過截止：斷言仍是 MPS 成員、進入 `LobbyWaiting`）；GDD :758 同步。
  - 主審傾向 (a)，但它的可行性要在 ADR-0006 r2 以原始碼和一次雙進程 T1 查證後才能定。

**FV-3 [🟡 MEDIUM，必修] E2 只修一半：Host 自核准仍可能被第 4 項拒絕，第三道防線的掛點在 Online 不存在**
- 見 §2A E2。另一個佐證：GDD 矩陣 #9 的 Lobby 欄是「–」（`netcode-session.md:721`），而 ADR 沒定義 #26 啟網當下 Host 的 `SessionPhase`。若那時仍是 Lobby，依 D3「主詞為本機時『–』格 throw」，Core 會 throw。
- 行號更正：approval 在 `NetworkManager.cs:1507-1517`，`OnServerStarted` 在 :1530。
- **Resolution**：D5 擇一明定：Host 自身的請求（`ClientNetworkId == ServerClientId`）只判第 1–3 項；或者 Core 在輸出 `StartNetwork` 效果之前就轉 `InShift` 並固定 `ShiftEndTs`。第三道防線改掛 `OnServerStarted`，或 `await StartRelayNetworkAsync` 之後，並寫明 Online／Solo／沙盒三種模式各自的掛點。T0 (b) 的 Online 案例明確設 `ShiftEndTsMs = 未設定`。

**EA-1 [🟡 MEDIUM，必修] Lobby REST 路徑多了一個不存在的 `lobbies/`，「404 視為成功」會把錯吞掉**——靜默失效
- ADR-0006 :446 與 registry `lobby_rest_leave_notification`（:526）寫的是：Host `DELETE lobbies/{id}`、client `DELETE lobbies/{id}/players/{playerId}`，沒寫 base URL。
- MPS 的實際行為：
  - base path 是 `https://lobby.services.api.unity.com/v1`；staging 為 `lobby-stg`（`MPS Lobbies/SDK/InternalLobbyService.cs:50-58`），也可被 `SetBasePath` 覆寫。
  - DeleteLobby 的路徑是 `/{lobbyId}`（`Lobbies/Apis/LobbyApiRequests.cs:705`），RemovePlayer 是 `/{lobbyId}/players/{playerId}`（:2097）。
  - 方法是 `DELETE`，成功回 204。SDK 視為必要的標頭只有 `authorization: Bearer`（:740-743），`Unity-Client-*` 標明是 analytics 用途。
  - `session.Id ≡ Lobby.Id`（`SessionHandler.cs:1065`）。
  - 主審已抽查 :705 與 base path，吻合。
- 照字面實作會拿到 404；ADR 規定「404 視為成功」，unload 期間又沒人讀回應，結果是靜默退化成 132 s 的服務端回收。
- **Resolution**：寫完整 URL，base path 取 SDK 同一份環境設定、不寫死。T1-Web (l) 斷言第一筆回 204；「404 視為成功」只適用於單發旗標失守時的第二筆。
- 附帶 **EA-8 [NOTE]**：Host 端第 6 步 `RemovePlayerAsync` 遇到已被 keepalive 移除的成員會拋例外（`LobbyHandler.cs:682-701`；`PlayerNotFound = 16002`），SDK 只對刪房吞 NotFound。第 6 步應把 NotFound 視為成功、不重試。

**FV-4 [🟡 MEDIUM，必修；ADR-0005＋0006 共同] 單發旗標下實際送出的是 `beforeunload`，與確認框衝突**
- 兩份 ADR 都寫「`pagehide`（主）＋`beforeunload`（備援），`.jslib` 單發旗標只送第一次」。依 HTML 規範，`beforeunload`（prompt to unload）先於 `pagehide`（unload），所以真正送出 `DELETE` 的是 `beforeunload`，「pagehide 為主」只是名目。W1 只記了兩者相隔 1–24 ms，沒記先後；README :345 顯示 [P-13] 實際上以 `beforeunload` 的 beacon 當時間基準。
- GDD AC42（MVP）要 Host 在 InShift 掛確認框。玩家按「留下」時房間已經被刪，所有成員收到 `Deleted` 而散場。
- 兩份 ADR 與 registry 對「確認框」「`returnValue`」「`persisted`」「bfcache」全部零命中；W1 的 `.jslib` 也沒設 `returnValue`（`W1Web.jslib:88-89`），所以 [P-18] 測不到這種情況。
- **Resolution**：
  - 只在 `pagehide` 送出；`beforeunload` 只在沒掛確認框時才送，或乾脆不送。
  - `pagehide` 的 `persisted == true` 時不送。
  - 依 ADR-0005 R1 的列舉制，需要 `.jslib` 的能力一律要有介面，所以 `IUnloadNotifier` 要加掛確認框的介面。
  - T1-Web 加兩個案例：確認框後按留下不得送出 `DELETE`；bfcache 往返。
  - ⚠ 不確定：itch.io 跨源 iframe 裡的確認框會不會顯示；帶 WebSocket 的頁面能不能進 bfcache。Lobby 期間 MPS 的 Wire 就開著一條 WebSocket（`Wire Plugins/WebSocket.jslib:136`）。

**FV-5 [🟡 MEDIUM，必修] `SessionConfig` 是 ScriptableObject，卻放在 `noEngineReferences` 的 `Session.Core`**
- D12（:180）把它定為 ScriptableObject；架構圖（:223）、Key Interfaces（:316、:339、:374）與 Migration 2（:560）卻都把它放在 Core。照寫會編譯失敗，與 r2 E8 同性質：大聲失敗，但照 Key Interfaces 寫就不能編。
- **Resolution**：Core 的 `SessionConfig` 改成純 C# sealed class 或 readonly struct，`Validate()` 也住在 Core；`Session.Unity` 另設 `SessionConfigAsset : ScriptableObject`，提供 `ToCore()`，並負責建置期斷言。

**EA-4 [🟡 MEDIUM，必修；ADR-0005] 自我註冊組件缺 `[assembly: AlwaysLinkAssembly]`；「無人註冊時回 Desktop」需要 asmdef 環**
- `.Web`／`.Desktop` 沒有任何組件引用，只靠 `[RuntimeInitializeOnLoadMethod]` 自我註冊（:76、:160-169）。Unity 自家的 UGS 套件用的正是這個模式，而且都加了 `[assembly: AlwaysLinkAssembly]`：MPS `Runtime/AssemblyInfo.cs:5-6`（註解原文 "// prevent Il2CPP code stripping"），Wire 與 Authentication 同。`[P-7]` 驗的是場景引用的 `W1WebProbe : MonoBehaviour`（在 Assembly-CSharp 裡），可達路徑完全不同，不能代證。
- `PlatformRoot`（在 `NightShift.Platform`）要在無人註冊時建出 Desktop 實作，就得引用 `.Desktop`；而 `.Desktop` 為了實作介面又要引用 `NightShift.Platform`，形成 asmdef 循環，Unity 不允許。況且 WebGL build 根本不編譯 `.Desktop`。所以「回 Desktop」在 Web 上不可能成立；真正的失效是 `.Web` 被剝除→無人註冊→靜默。這正是 ADR-0005 要防的「靜默假值」。主審已核對 :76、:160-163 的文字。
- **Resolution**：`.Web`／`.Desktop` 的 AssemblyInfo 加 `[assembly: UnityEngine.Scripting.AlwaysLinkAssembly]`，註冊方法標 `[Preserve]`。`PlatformRoot.Create()` 在無人註冊時拋例外（大聲失敗）；或改由同時引用兩者的 bootstrap 組件當組合根。T1-Web 斷言回傳的實作型別是 Web 版（IL2CPP＋Stripping High＋Release）。⚠ `AlwaysLinkAssembly` 的必要性，是以 UGS 套件的做法與其註解為旁證推得，未在本專案實建驗證。

### 3B. 應修（MEDIUM，非 Accept 阻擋）

**FV-2 `shift_eta` 只在階段改變時發布，晚到的讀者會把屬性年齡算成剩餘時間**
- 公式 `remaining(now) = remaining_ms − (now − t_received)` 只對「發布當下就在線」的讀者成立。屬性不帶發布時刻，Host 每班只重發 2–3 次，而且沒有「截止」這一階。TR-netcode-046 點名的兩類讀者（預檢者、Lobby\* 等待者）都是晚到的，誤差等於屬性年齡，最長一整班。例如 AC51「剩 20 s 才加入」照原樣實作，會顯示約 8–10 分鐘。
- r2 E5 的建議原本含「必要時 Host 定期重發」，r1 明確拒絕了這一點。
- **Resolution**：屬性帶一個所有讀者共用時間基準的發布時刻（例如 Host 的 `Date.now()`，兩端 wall clock 差幾秒，對非權威提示可接受）；或在截止窗口附近定期重發。MPS 的 lobby `LastUpdated`（`SessionInfo.cs:55`）記的是任何變更的時刻，不夠當錨點。UGS 屬性更新的限流數值未查證。這條會與 FV-1 的裁決一起動 D5。

**FV-6／CX-5 `IUnloadNotifier` 的生命週期義務兩邊都沒接**
- ADR-0005 r1 把「token 換發後重裝」「Teardown 時 `ClearLeaveBeacon()`」交給轉接層，也就是 ADR-0006 的 `Session.Unity`。但 ADR-0006 全文 `ClearLeaveBeacon` 零命中；D9 只寫 Host「進 Lobby 時」安裝，client 什麼時候安裝沒定。
- Authentication SDK 會在 `expiresIn − 300 s` 自動續發 token（`AuthenticationServiceInternal.cs:442-448`），但從 Refreshing 進到 Authorized 時**刻意不發** `SignedIn`（:573-577）。`AccessTokenComponent` 是 internal 類別，公開介面上沒有可訂閱的「token 已換」事件，只有 Core.Internal 的 `IAccessTokenObserver`。
- 連續值班 30–90 分鐘，Bearer 可能過期，離開通知會退化到 132 s／8 s。token 的實際效期由伺服器決定，原始碼看不到（印象約 1 小時，待查證）。
- 桌面列「Shutdown＋leave → ≤ 1 s 後 Quit」也沒人承接：ADR-0006 D9 是「best-effort 不等待」。
- **Resolution**：ADR-0006 D9 明定四件事：安裝時點（Host 與 client）、每次安裝時讀當下的 `AccessToken`（或用 `IAccessTokenObserver`）、Teardown 第一步 `ClearLeaveBeacon()`、桌面 `QuitRequested` 最多等 1 s。registry `unload_notifier` 只保留單一安裝者。

**EA-2 NGO 的連線設定雜湊比 approval 更早擋人：真正的舊版 build 多半拿不到 `StaleBuild` 店語**
- `ConnectionRequestMessage.cs:127-151` 先比對 `ConfigHash`，不符就 `DisconnectClient(SenderId)`，approval 根本不會跑；原因是通用字串（`NetworkManager.cs:1570`）。主審已抽查 :127-151，吻合。
- 雜湊包含 `NetworkConfig.ProtocolVersion`、NGO 協定版本、**所有 network prefab 的雜湊**（`ForceSamePrefabs` 預設 true，`NetworkConfig.cs:116,341-349`）、TickRate 等。兩個 build 之間只要增刪過任何一個 network prefab，擋人的就是 NGO，不是 `ApprovalGate`。
- AC54（擋在任何資料交換之前）仍然成立；壞掉的是 R4「唯一執行點」的措辭、V2 與店語。
- **Resolution**：R4／D5 改為兩層：NGO 設定雜湊在前、給通用原因；`ApprovalGate` 在後、給 `StaleBuild`。Host 把 `BuildId`／`ProtocolVersion` 發布為 session property，加入者在 Relay join 之前預檢。T1 (h) 加「prefab 清單不同的 build」案例。並註明 ADR 的 `ProtocolVersion` 與 NGO 的 `NetworkConfig.ProtocolVersion` 是兩個不同的東西。

**EA-3（含 FV-7）TransportSwitch 的切換點落在 NGO 延後關機的窗口裡**
- `Shutdown()` 只設旗標（`NetworkManager.cs:1590-1604`），真正拆除在 PostLateUpdate（:509-520）；有 peer 的 Host 最多等 5 s（:547-593）。
- 這段窗口裡，NGO 有的路徑讀**當前**指派的 transport（EarlyUpdate :356、PostLateUpdate :489、關機 `NetworkConnectionManager.cs:1746-1765`），有的讀 Initialize 時**快取**的那個（:447、:1657）。所以「`Shutdown()` 之後立刻指回 `UnityTransport`」關到的是錯的 transport。
- 若 MPS 在同一窗口啟網，`IsListening` 為真時它只記警告就返回（`NetworkManagerSession.cs:148-152`），不發 `StartFailed`，State 卻設成 `Started`。
- **Resolution**：`UseUnityTransport` 移到 `NetworkManager.OnStopped`（:1723）裡呼叫；`UseSinglePlayer` 照官方範例，只在 `!IsListening` 時、緊接 `StartHost()` 之前呼叫；UI 的「單人練習」在 `IsListening || ShutdownInProgress` 時不可按。D2 的復原條件再加「MPS 回報 Started，但 `T_spawn` 內 NGO 沒連上」。D9 改述 `Shutdown()` 的時序；ADR-0005 桌面列同步（EA-7）。

### 3C. LOW／NOTE

| ID | 內容 | 修法 |
|---|---|---|
| FV-7 | 「`Shutdown()` 同步」不實；E13「這條警告是預期的」多半不會出現，常見的 Shutdown→LeaveAsync 路徑走 `TrySetException` 分支 | 併入 EA-3 改述 |
| FV-8 | `PeerPhase` 只定義了 Onboarding 的分流。Settlement 欄的 peer 列（#11／#14／#15／#15a／#16 為 N）與 D7 相反：照字面，Settlement 中斷線照跑第 7 步。#24a 歸為本機主詞，與 :106 的讀法矛盾 | D7 補 `Phase == Settlement` 的跳步規則；#24a 改歸 peer 列 |
| FV-9 | 四處修訂殘留：架構圖「①–⑮」；payload「≤ 80 bytes」對「≤ 72」，且 `FixedString64Bytes` 只容 61 bytes，「n ≤ 64」放不進；Risks 引用不存在的 Alternative；ADR-0005 R5／Verification／Validation 仍寫「beacon 8/8 結果不得變」 | 逐處更正 |
| FV-10 | `HeartbeatMonitor` 沒有 slot 回收時的重置點；拿掉冷卻之後 slot 可立即重用，新占用者會被舊狀態判成 `OneWayLoss` | 加 `Release(slot)`；T0 加「回收後 0.1 s 重派」案例 |
| EA-5 | `HeartbeatToClientRpc` 的 `InvokePermission` 預設 `Everyone`（`RpcAttributes.cs:24-39`），任何 client 都能經 Host 轉發，偽造「Host 心跳」，汙染別人的 offset 與倒數 | `InvokePermission = RpcInvokePermission.Server`；client 端核對 `SenderClientId == ServerClientId` |
| EA-6 | 「`SessionRoot` 是啟網後第一個 Spawn」做不到：Host 的 avatar 在 `StartHost()` 同一個呼叫內就先 spawn（`NetworkManager.cs:1501-1516`） | 改述；avatar／HUD 不得假設 `OnNetworkSpawn` 時 `SessionRoot` 已存在（G2／ADR-0001 r1 義務） |
| EA-7 | ADR-0005 桌面退出沿用「Shutdown 0.08 s」，那是對端收到的時間；也沒算到 MPS 在 `Application.quitting` 時會自動再 `LeaveAsync` 一次（`SessionHandler.cs:759,1224-1241`） | 以 `OnStopped`＋leave Task 判定完成 |
| EA-8 | 見 EA-1 附帶 | — |
| EA-9 | `.jslib` 收不了 `IReadOnlyDictionary`；`JsonUtility` 不支援 Dictionary，Newtonsoft 在 Stripping High 下需要 link.xml | ADR-0005 D4 定封送格式（手寫 JSON），或介面只收單一 authorization 值 |
| N5 | `StartFailed` 復原沒有規定先 `AbortSandbox`，沙盒還在跑時重新加入會再撞 `TransportComponentMissing` | 併入 FV-1 的裁決 |

---

## 4. Cross-ADR Conflicts（Phase 4）

> **Known conflict-prone areas**：`docs/consistency-failures.md` 不存在。前兩輪反覆出現的模式是「引擎預設值靜默生效」。**本輪出現一個新模式：SDK 自己的控制流程替我們做了決定**——MPS 在模組初始化失敗時自動 leave（FV-1）、NGO 的設定雜湊搶在 approval 之前（EA-2）、`Shutdown()` 延後執行（EA-3）、IL2CPP 剝除沒人引用的組件（EA-4）、REST 回應被「404 視為成功」吞掉（EA-1）。這些 ADR 寫的流程都是自己定的順序，沒有沿著 SDK 的實際呼叫鏈走一遍。

| ID | 嚴重度 | 衝突 | 修法 |
|---|---|---|---|
| **CX-1** | 🔴 HIGH（擋 0001／0002／0003 Accept） | **r2 X1 延續**。ADR-0001 `CapsuleGhost.Id: string`（:132）、`Solve(…, string selfId, …)`（:141）、以 id 為鍵的字典（:111、:144、:220）；ADR-0002 `ulong ClaimedBy`（:137）、`Validate(…, ulong requester, …)`（:141，住在 `Interaction.Core`）；ADR-0003 Constraints「不以 slot 為鍵」（:46、:167）。三者都違反 registry `player_identity_key`（:513-516）與 `clientid_as_player_identity`（:650-655）。`FillSolidCapsules(int npcId…)` 與 ADR-0006 D4 一致，**不構成衝突** | 依 ADR-0006 Migration 3 在三份 r1 改鍵；不擋 0005／0006 |
| **CX-2** | 🟡 MEDIUM（**ADR-0006 必修**） | **`session_events` 在非 Host 端沒有來源**。X5 的修法要每個擁有者端在收到 `PlayerLeft(slot)` 時清自己遮罩的位元，`PairMachine`／claim 表／HUD 也一律在 `PlayerLeft` 清除；但 `PlayerLeft` 只在 Host 的第 4 步發出，`SlotTable` 只存在於 Host。若由 `Roster` NV 推導，NV 下一個 tick 才送，所以 client 上第 5 步的 avatar despawn 一定先到；`RosterEntry` 也沒有 `PeerPhase`，推不出 `PlayerJoined` 的時刻。NGO 雖有現成的 client 端訊號 `ClientDisconnectedMessage` → `OnPeerDisconnectedCallback`（`NetworkConnectionManager.cs:1539-1550`），但它在回呼觸發源下早於 despawn、在心跳觸發源下晚於 despawn，兩條路的順序不一致。若 ADR-0003 r1 依 Migration 3 把清零觸發點從 despawn 改成 `PlayerLeft`，非 Host 的 client 就永遠不清位元，同 slot 的新玩家一進場就被全場穿過（AC19 的症狀） | ADR-0006 r2 補一張「事件的分端來源」表；`RosterEntry` 加 `PeerPhase`，或只在 `PlayerJoined` 時才設 `Online = true`；明定非 Host 端的主清理觸發點仍是 avatar despawn（AC20①），`PlayerLeft` 只當冪等補強 |
| CX-3 | LOW | 3.0 s 地板保護的是 `PlayerJoined` 這個事件，ADR-0001／0003 的消費端卻以「物件存在」為準。Onboarding 中的 avatar 在 approval 當下就已是膠囊、也是 `PairMachine` 的參與者（`NetworkConnectionManager.cs:1010-1035`）；ADR-0003 :95 照 Migration 改寫後的保證不成立 | 「在場玩家」定為「`PlayerJoined` 已發出且 Online」，或由 G2 保證 avatar 在那之前不可碰撞、不可見 |
| CX-4 | LOW | `TickRate = 10` 有三方擁有者：ADR-0001 自己裁決；ADR-0006 :64、:84、:189 標「ADR-0001」；registry 卻登記在 ADR-0006 的 `session_topology`。ADR-0001 r1 一宣告 Depends On ADR-0006，就形成 0001↔0006 兩點環 | 以 registry 為準由 ADR-0006 擁有，ADR-0001 r1 改為引用；D4 重述的 ADR-0003 規則改為 Related |
| CX-5 | LOW | 併入 FV-6 | — |
| CX-6 | LOW | avatar 不再是「ownership 永不轉移」的物件（`RemoveOwnership` → Host 成為遮罩擁有者）。首輪 C3 對 ADR-0003 的安全前提失效；目前寫入時機不會出錯，但 G2 若照首輪原文登記禁令，avatar 會直接違反。ADR-0003 D7「slot 重用是新 NetworkObject」現在取決於第 5 步是 destroy、不池化 | G2 的禁令限定「轉移後仍存活的物件」並明列 avatar 例外；`avatar_destroyed_with_owner` 補一句「不得池化」 |
| CX-7 | LOW | Migration 3 補齊了 r2 指出的三項，仍有新漏列：ADR-0001 的 `Solve` `selfId`；0002／0003 r1 沒被要求在 Depends On 補列 ADR-0006；`avatar_ownership_callback_side_effects` 只派給 ADR-0001，但 ADR-0002 的 RPC 與 ADR-0003 的遮罩也掛在 avatar 上 | 補進 Migration 3 |
| CX-8 | LOW | ADR-0005 對 `#if UNITY_WEBGL` 的位置自相矛盾：D3、Key Interfaces、registry 說只在 `.Web` 的註冊入口；Migration 3（:255）與架構圖（:107-108）說在 `PlatformRoot`。照 :255 寫的 CI grep 會擋下合規程式碼 | 統一為「`.Web` 的註冊入口」 |
| CX-9 | LOW | registry 與 ADR 本文有 5 處漂移：`player_identity_key` 的 PlayerId 範圍比 ADR 自己的事件窄；`approval_payload` 的位元組數（同 FV-9）；`utp_constants_contract` 對上架構圖；ADR-0006 Depends On 列了 `IClipboard`；`lobby_rest_leave_notification.not` 把「unload 時 LeaveAsync 會被取消」寫成事實（[P-18] 量的是 sendBeacon） | 逐條更正 |
| EA 跨 ADR | LOW | ADR-0002 V③ 把「WSS 上 reliable 的順序」列為待實測，ADR-0006 前提 3 (b) 卻當成事實（ADR-0006 推薦 (a)，影響小）；ADR-0005／0006 對 `Shutdown()` 有同一個錯誤前提（EA-3／EA-7） | (b) 回指 ADR-0002 V③ |

新增的兩條 forbidden pattern 不違反 ADR-0001／0003 的任何文字：`avatar_destroyed_with_owner` 在兩種觸發源下都不會破壞 ADR-0003 遮罩的寫入時機（`RemoveOwnership` 與回呼在同一個同步呼叫內，:1392→:1567）。registry 16 條（13 revised＋3 新增）中有 11 條與 ADR 本文一字相符。

### 4A. ADR Dependency Ordering

```
現行宣告（X ──► Y 表示 X Depends On Y）
  0002 ──► 0001 ◄── 0003
  0006 ──► 0005
  0001、0005：無依賴          拓撲：L0 {0001, 0005} → L1 {0002, 0003, 0006}     無環

Migration 義務落地後
  0005 ◄── 0006 ◄── 0001 r1 ◄── {0002 r1 ∥ 0003 r1}
  G2 ──► 0006、0001、0003
  0004 ──► 0002、0006、G2、0005      宣告層無環
```

- **r2 的宣告環 0001→0006→0005→0001 已拆**。真正拆環的是 ADR-0005 的 Depends On 改成 None（adr-0005:24）。把 `PeerKey` 搬到 `NightShift.Identity` 拆的是組件耦合，不是 ADR 依賴：`NightShift.Identity` 的契約仍歸 ADR-0006（:122、:25；registry :517），所以 ADR-0001 r1 在決策層仍要 Depends On ADR-0006。
- ⚠ **潛在兩點環**：正文裡 0006 ⇢ 0001 的 TickRate 回指，會在 ADR-0001 r1 落地時形成 0001↔0006（CX-4，修法是 TickRate 歸 0006）。另有三條弱回指：0006 ⇢ 0003（冷卻、owner-write）、0005 ⇢ 0006（桌面 Teardown 順序）、0005 ⇢ 0001（`Cursor.lockState`）。
- ⚠ 每一條依賴邊都是 Proposed 依賴 Proposed；ADR-0006 依賴的是 ADR-0005 的 **r1／r2**，兩者必須成對 Accept。ADR-0006 的 Validation（V12、T1 (i′)）要等 G2 與 ADR-0004 落地後才能全部跑完——這不構成決策環。
- **建議的 Accept 順序**：ADR-0005 r2＋ADR-0006 r2（成對）→ ADR-0001 r1 → ADR-0002 r1 ∥ ADR-0003 r1 → G2 → ADR-0004 → G4 → …

---

## 5. GDD Revision Flags（Phase 5b）

共 20 條：4 HIGH／7 MEDIUM／9 LOW。r2 的 13 條**全數仍在**（8 條沿用、5 條內容有變），本輪新增 7 條。GDD 自 r2 以來沒有改動；ADR-0006 Migration 4 原列的回填項已做 3 處（`host_now_ms`、`LeaveAsync` 改名、`ClaimedBy` 改 byte，都在 r2 基準內），r1 補列的全部未做。

| ID | GDD 行 | 假設 → 現實 | 嚴重度 | 狀態 |
|---|---|---|---|---|
| GF-1 | netcode :1188、:1256、AC23 :1433；`entities.yaml:1460` | `interpolation_buffer_ms = 150` → NGO 實際內插為 `max(1, TickLatency + InterpolationBufferTickOffset)` ticks（`NetworkTransform.cs:4250`），10 Hz 下至少 200 ms | 🔴 HIGH | 沿用 |
| GF-2 | FPC F1 :564-578（`L_p95 = 0.339`）、:634、:642、:655、:1009、:1036；`entities.yaml:227` | 含 150 ms 項；`player_move_speed_max = 1.47` 餘裕轉負 | 🔴 HIGH | 沿用 |
| GF-7 | netcode #24 前置條件 :580-592、:594-605、:830-837、AC56 :1488 | 只要求道具 `DontDestroyWithOwner`；:588-591 只看 Host 端；:836-837「未經確證、不得斷言」與替代做法；**AC56 只在 Host 端斷言**，在失效情境下會亮綠燈，2 人房也沒有留守 client 可斷言 | 🔴 HIGH | 內容有變（r1 證實只寫 NV 救不回，推薦 client 端 `OnNetworkDespawn` 自救） |
| **GF-20** | netcode :758（Lobby\* 進入條件）、:772-776、AC51 :1485 | 「approval 拒絕但 MPS 成員已成立」→ MPS 2.3.1 預設 handler 下，被拒者已被 SDK 移出 session（FV-1） | 🔴 HIGH | **新增**（待 FV-1 裁決後回填） |
| GF-8 | FPC :397-399、AC19 :1385-1388、AC20② :1395 | 「以玩家 id 為鍵，不以 slot 為鍵」→ ADR-0006 D4 玩家鍵＝slot | 🟡 MEDIUM | 沿用（Migration 4 已逐字指定改寫文字） |
| GF-9 | netcode #9 :161-162、:758、:775-776、AC51 :1485 | 預檢讀 `shift_end_ts` → ADR 改發 `shift_eta`，但 `shift_eta` 本身對晚到讀者失效（FV-2）；先修 ADR 再改 GDD | 🟡 MEDIUM | 內容有變 |
| GF-12 | machine C13 :215-222、C20 :268-269 | 「整個生命週期零位置同步」禁止了 V12 要求的落地座標收斂通道；「靠 `OwnerClientId` 決定掛誰的手」在 `RemoveOwnership()` 之後會把掉落的道具掛到 **Host 手上**（`NetworkSpawnManager.cs:457-467`），2 人房就看得到；C13／C20 沒有「地面」這個狀態 | 🟡 MEDIUM | 內容有變（由 LOW 升） |
| GF-14 | netcode :205-209、:232-233、:406、:794、AC6c :1400、[P-18] :1637 | 走 `sendBeacon`、[P-18]「疑慮解除」→ registry `not: sendBeacon`；[P-18] 只測過同源伺服器，V10 未驗 | 🟡 MEDIUM | 新增 |
| GF-15 | netcode 矩陣 :704-745 | 沒有「主詞」欄，照字面讀會把 #24 寫錯 | 🟡 MEDIUM | 新增 |
| GF-16 | netcode :723、:739、:756、:1095-1096、AC37 :1460 | 「Onboarding 期間斷線＝整條跳過 #24」→ ADR 在 approval 時就指派 slot、建 avatar；照 GDD 跳過，會留下殭屍 avatar，slot 也不釋放，2 人房的下一位會被判「這班人滿了」 | 🟡 MEDIUM | 新增（ADR Migration 4 漏列） |
| GF-17 | netcode #24 :594-605、:786、:1066-1073 | 七步沒有切斷 NGO 連線、沒有處理觸發源重複到達 → ADR 第 5a 步＋NoSlot 丟棄 | 🟡 MEDIUM | 新增（ADR Migration 4 漏列） |
| GF-3 | FPC :61 | 「本系統不引用任何 ADR」 | LOW | 沿用 |
| GF-4 | machine OQ-M14 :850 | `visibilitychange` 匯流排已由 ADR-0005 承接 | LOW | 沿用 |
| GF-5 | concept :233、:308 | 體積未標單位、「Unity Relay + Lobby」、「CLAUDE.md 釘 Godot 4.6」 | LOW | 沿用 |
| GF-6 | systems-index :12、:222 | 「19 個系統」，實為 20 | LOW | 沿用 |
| GF-10 | netcode OQ#4 :1650、OQ#18 :1665、#24a :612、:1219 | 已由 ADR-0006 D5／D10／D11 裁決，未回填 | LOW | 沿用 |
| GF-11 | netcode :379、:381-383、:1069-1070 | 「16 bytes」→ 20；單向失效判準把序號和秒數混在一起 →「落後 4 拍」 | LOW | 內容有變 |
| GF-13 | netcode :789、:800-802、:807 | 契約表以 id／clientId 為鍵、MPS 事件名過時 | LOW | 內容有變 |
| GF-18 | netcode #8 :140-142、:846-847 | 「[P-4] itch.io 未驗證」「高風險假設」都已過時 | LOW | 新增 |
| GF-19 | systems-index :38 | #19 單人練習排 Alpha，但 Lobby\* 沙盒與 Solo 是 MVP 依賴 | LOW | 新增 |

**`systems-index.md` 備註現況**：
- #1／#2（Needs Revision）未涵蓋 4 條 MEDIUM（GF-14、15、16、17），也沒有 GF-20；GF-7 的措辭是 r2 版本，已過時。
- #3（Needs Revision）完整。
- #5（🟡 In Review r1）完全沒有架構回饋，缺 GF-12（MEDIUM）。

---

## 6. Engine Compatibility（Phase 5）

### Engine Audit Results

Engine：Unity 6.3 LTS（6000.3.24f1）／NGO 2.13.2／MPS 2.3.1／UTP 2.7.4
ADRs with Engine Compatibility section：**5 / 5**

- **版本一致性**：五份彼此一致，也與 PackageCache 的實際解析值相符。ADR-0005 寫「UTP 2.x」「6000.3」，建議釘成 2.7.4、6000.3.24f1。Input System 1.14–1.15 不在 W1 的 PackageCache 裡，本機無法核對。
- **Deprecated API References**：實際使用 **0**。grep 命中全部是正確引用或誤報。例如 `HeartbeatToClientRpc` 含 `ClientRpc` 子字串，但 ILPP 只要求 `[Rpc]` 方法以 `Rpc` 結尾（`NetworkBehaviourILPP.cs:1652-1656`），照樣可編。
- **Stale Version References**：無。
- **Post-Cutoff API Conflicts**（新）：
  1. `NetworkManager.Shutdown()` 的完成時機——ADR-0005／0006 有同一個錯誤前提（EA-3、EA-7）。
  2. WSS 上 reliable 的到達順序——ADR-0002 列為待實測，ADR-0006 當成事實（§4）。
  3. 設定雜湊與 approval 誰先擋（EA-2）。
  - 其餘 6 組交叉比對一致：`RpcTarget.Single`、`UseWebSockets` 手動設、`LeaveAsync`／`DeleteAsync`、`InstallLeaveBeacon` 簽章、NV 寫權、avatar `RemoveOwnership`。

### 參考庫（`docs/engine-reference/unity/`）缺口

參考庫自 09-28（`20aa076`）之後沒動過。**r2 列的四條全部仍缺**：`SinglePlayerTransport`；成員端自動加入；session 中呼叫 `Shutdown()` 的警告；`multiplayer.md:131` 房間碼範例用了 `WithRelayNetwork()`。本輪新增 11 條：

| 檔 | 缺口 |
|---|---|
| multiplayer.md | `Shutdown()` 延後執行、有 peer 的 Host 最多等 5 s，正確掛點是 `OnServerStopped`／`OnClientStopped`／`OnStopped` |
| multiplayer.md | NGO 混讀「當前」與「快取」的 `NetworkTransport`，切換時機因此有約束 |
| multiplayer.md | 連線設定雜湊的組成（含 prefab 清單），以及它先於 approval、失敗時給通用原因 |
| multiplayer.md | **MPS 在模組初始化失敗時自動 `LeaveAsync`**（FV-1） |
| multiplayer.md | MPS session 語義：Host 的 `LeaveAsync` 就是 `DeleteAsync`；`Application.quitting` 時自動 leave；`DeleteLobby` 吞 NotFound、`RemovePlayer` 不吞 |
| multiplayer.md | UGS Lobby REST 契約：base URL、路徑、標頭、`session.Id == Lobby.Id` |
| multiplayer.md | MPS 在 `IsListening` 時提早返回：只記警告，不發 `StartFailed` |
| multiplayer.md | Unreliable RPC 參數上限 1296 bytes（instance 欄位，每次 Initialize 重設） |
| deprecated-apis.md | `RpcAttribute.RequireOwnership` 已 `[Obsolete]` → `InvokePermission`；`networking.md:68` 仍寫 `[ServerRpc(RequireOwnership = false)]` |
| deprecated-apis.md | `RelayNetworkOptions` 帶 `RelayProtocol` 的建構子已 `[Obsolete]` |
| web.md／current-best-practices.md | 自我註冊組件需要 `[assembly: AlwaysLinkAssembly]`；web.md 沒有「離開通知」一節（keepalive、CORS preflight、bfcache、Lobby 期間 Wire 開著 WebSocket） |

延續（r2 已列）：`current-best-practices.md:30` 與 `web.md:27` 仍寫 Brotli、`web.md:132` 仍寫「≤ 50MB」（現行 44MB gzip）、`networking.md` 的 NGO 1.x 範例、`VERSION.md` 的驗證日期 09-03。

### Engine Specialist Findings

| 主張 | 結論 | 證據 |
|---|---|---|
| Lobby REST 路徑 `DELETE lobbies/{id}` | ❌ 錯 | EA-1 |
| HTTP 方法 DELETE、session id ＝ lobby id | ✅ | `LobbyApiRequests.cs:760`；`SessionHandler.cs:1065` |
| 必要標頭只有 Bearer | ⚠️ 部分 | 從客戶端原始碼看只有 Bearer；伺服器端是否拒絕缺 `Unity-Client-*` 的請求，原始碼無從證明（推論可信度中高） |
| 「第二次的 404 視為成功」 | ⚠️ 部分 | 刪房會吞 NotFound，`RemovePlayer` 不吞（EA-8） |
| `HeartbeatWire` 20 bytes | ✅（酬載） | §2A E8 |
| 兩個 transport 並存、只切指派 | ✅ | NGO 不自動抓 transport，也不對多個發警告（`NetworkManager.cs:1069-1084,1212-1216`）；官方範例同（`SinglePlayerSessions.cs:32-43`）；MPS 的 Relay 路徑不改指派 |
| 「`Shutdown()` 之後立刻指回」 | ❌ 錯 | EA-3 |
| keepalive＋`Authorization`（觸發 preflight）在 unload 期間能否完成 | ❓ 無法查證 | 規格推論，可信度中低：記得 Chromium 曾直接拒絕「keepalive＋preflight」，後來的版本是否支援**不確定**；Firefox 很晚才支援 fetch keepalive（**不確定**是哪一版）；Safari 不明。若 SDK 先前對同一 URL 做過 preflight、伺服器的 Allow-Methods 含 DELETE 且 Max-Age 未過，可能不需要再 preflight。V10 應在三個瀏覽器記錄有沒有出現 OPTIONS、以及第一筆 DELETE 的狀態碼 |
| keepalive 64 KiB 配額 | ❓ | 規格推論：只算 body，這個請求沒有 body，不是問題 |
| bfcache 對帶 WebSocket 頁面的行為 | ❓ | 不確定；但無論是否發生，`persisted == true` 都不應送 DELETE（FV-4） |

**對抗式驗證（原始碼型 9 項）**：FV-1、FV-3、FV-7、CX-2、CX-6、FIX-E1、FIX-E2、FIX-E6、FIX-E8 全部 CONFIRMED，嚴重度不變。另有三處修正：FV-1 的兩個連帶後果已改寫（見 §3A）；FV-3 的行號；CX-2 補上 NGO 現成的 `OnPeerDisconnectedCallback`。

---

## 7. Architecture Document Coverage（Phase 6）

`docs/architecture/architecture.md`、`control-manifest.md` 仍不存在。建議在 G2、ADR-0004、G4 落地後跑 `/create-architecture`。

---

## 8. Verdict

### **FAIL**（覆蓋率與 r2 相同；ADR-0006 r1 仍不能 Accept——必修從 4 條變成 7 條，其中一條需要設計裁決）

依本 skill 判準「FAIL：Foundation／Core 層需求無 ADR，或有 blocking 的跨 ADR 衝突」。Foundation 層仍有 **20 條 Gap**，而且本輪的修訂範圍本來就碰不到它們。

**走勢**：

| 指標 | 首輪 | r2 | r3 |
|---|---|---|---|
| ✅ Covered | 50 | 71 | 71 |
| Foundation Gap | 30 | 20 | 20 |
| ADR-0006 Accept 前必修 | — | 4 | 7（1 條沿用 E2 殘留、6 條新） |
| 原始碼型主張經對抗驗證被推翻 | — | 0 | 0／9 |

必修數上升，不是 r1 退步：r2 的 E1／E6／E8 都真的修好了。新的 7 條分三類：

- **r1 新寫的段落**：EA-1（REST 路徑）、FV-4（送出點）、FV-3（E2 的另一半）。
- **一直存在、前兩輪沒人沿 SDK 呼叫鏈走過**：FV-1（MPS join 流程）、FV-5（`SessionConfig` 分層）、EA-4（IL2CPP 剝除）。
- **r2 X5 的修法把問題挪了位置**：CX-2。

除了 FV-1，每一條都是局部修法。

### Blocking Issues（解除後方能 PASS）

1. **Foundation 無 ADR**（20 條，與 r2 同）：G4（product-001–005、014、016）、G5（product-018、020–022；machine-054）、G6（product-006、007）、G2（netcode-033；machine-010、027）、G7（fpc-029）、G8（fpc-040）、ADR-0004（machine-023）。
2. **ADR-0004 未寫**；ADR-0002 與 machine C20 的 8 處分叉不變（首輪 D1）。
3. **`interpolation_buffer_ms` 模型錯誤**仍在兩份 GDD 的數值骨幹裡（GF-1、GF-2）。
4. **身份契約已裁決、未傳播**（CX-1）：擋 ADR-0001／0002／0003 的 Accept。
5. **ADR-0006／ADR-0005 的 Accept 前必修 7 條**：
   - FV-1 Lobby\* 入口不可達（**需裁決**）
   - FV-3 Host 自核准的第 4 項與掛點
   - CX-2 `session_events` 在非 Host 端沒有來源
   - EA-1 REST 路徑寫錯、404 被吞
   - FV-4 `beforeunload` 才是實際送出點，與確認框衝突
   - FV-5 `SessionConfig` 分層
   - EA-4 自我註冊組件與 asmdef 環

### Non-blocking（CONCERNS，進 PASS 前應收斂）

- **ADR 本身**：§3B（FV-2、FV-6／CX-5、EA-2、EA-3）；§3C（FV-7–10、EA-5–9、N5）；§4 的 CX-3、4、6–9。
- **GDD**：§5 的 MEDIUM／LOW 旗標。
- **參考庫**：§6 的 15 條缺口。
- **首輪延續**：C2–C4、D4、D6、D9／D10。

### Required ADRs（最 Foundation 者優先）

| 序 | ADR | Layer | Engine Risk | 理由 |
|---|---|---|---|---|
| 1 | **ADR-0006 r2 ＋ ADR-0005 r2**（成對） | Foundation | HIGH | 必修 7 條，FV-1 需先裁決；V13 加入 W2 第一批；修 FV-1 時一併處理 FV-2 與 N5 |
| 2 | **ADR-0001／0002／0003 r1** | Core | — | CX-1 身份傳播；CX-3、CX-6、CX-7；TickRate 改為引用 ADR-0006（CX-4）；pointer lock 的 T1-Web 交棒（TR-fpc-019） |
| 3 | **G2** 同步物件生命週期與所有權轉移 | Foundation／Core | HIGH | 15 條 TR（3 條 Foundation Gap）。要登記：avatar 契約；掉落路由 (a)／(b)；第 5 步以 destroy 方式 despawn、不池化；Onboarding avatar 的可見性與碰撞（CX-3）；C3 禁令含 avatar 例外（CX-6）；道具的「地面」狀態與持有者欄（GF-12） |
| 4 | **ADR-0004** 機台互動組 Core | Core | MEDIUM | 29 條 TR；吸收 ADR-0002 的 8 處分叉 |
| 5 | **G4** SKU 資料格式與序列化凍結 | Foundation | MEDIUM | 16 條 TR（7 條 Foundation Gap）；`BuildId` 雜湊輸入含 `ProductCatalogAsset`；EA-2 的 prefab 雜湊也是版本 token 的一部分 |
| 6 | **G8** 延遲模型與容差 | Core | HIGH | 解 GF-1、GF-2 |
| 7 | **G5** 建置期資料治理閘門與 CI | Foundation | MEDIUM | 四個客戶押在同一塊不存在的 CI 上（CX-8 會直接流進來） |
| 8 | **G7** 攝影機與渲染基線 | Core／Pres | HIGH | 不變 |
| 9 | **G6** 資產繫結與載入 | Foundation | MEDIUM | 不變；可併 G4 |
| 10 | **G9** 遊戲時鐘與班次時基 | Foundation | LOW | 先 `/design-system 遊戲時鐘` |

---

## 9. arlong 裁決（Phase 8，2026-10-03）

| 問題 | 裁決 |
|---|---|
| 寫入範圍 | 三份都寫：本報告另存 `architecture-review-2026-10-03-r3.md`（r2、首輪保留）；`traceability-index.md` 就地更新；`tr-registry.yaml` 升 version 4（TR-netcode-007 partial→covered、TR-netcode-010 covered→partial；無新 TR、無 deprecated） |
| `systems-index.md` | #1／#2 備註補 GF-14～17、GF-20，GF-7 改為 r1 的措辭；#5 備註補 GF-12，Status 由「🟡 In Review r1」改為 **Needs Revision** |
| 下一步 | 新 session 修 **ADR-0006 r2＋ADR-0005 r2**（成對，7 條必修）。FV-1 先在那個 session 以原始碼查證方向 (a)（轉接層掌握 client 何時啟網）是否可行，再請 arlong 裁決 Lobby\* 入口 |

---

## 10. 審查方法與可信度

| 階段 | agent | 結果 |
|---|---|---|
| 審查 | 追溯×2（netcode 46 條；其餘 182 條）、r1 修訂核對、跨 ADR＋依賴、GDD 旗標、引擎×2（unity-specialist） | 5 份完成；**2 份 unity-specialist 無輸出**——agent 定義 `.claude/agents/unity-specialist.md` 寫 `maxTurns: 20`，查原始碼查到一半就被截斷 |
| 對抗驗證 | 文件型 33 項（含追溯狀態變更）；原始碼型 9 項（unity-specialist，同樣被截斷） | 文件型：32 CONFIRMED、1 REFUTED（TR-netcode-010） |
| 補跑 | 2 個不設回合上限的 agent，扮演 unity-specialist：引擎稽核；原始碼型 9 項的對抗驗證 | 9／9 CONFIRMED；新發現 EA-1–EA-9 |
| 主審抽查 | FV-1 全鏈、EA-1、EA-2、EA-4 的文件行 | 全部吻合 |

**未經對抗驗證**：EA-1–EA-9 只有單一稽核者，其中 EA-1、EA-2、EA-4 經主審抽查；LOW 級的 CX 與 GF。

**不確定之處**（照實標註）：
- keepalive＋preflight 在 unload 期間的各瀏覽器支援度。
- bfcache 對帶 WebSocket 頁面的行為。
- itch.io 跨源 iframe 會不會顯示確認框。
- UGS access token 的效期。
- `Duplicate` 情境下的 `RemovePlayerAsync`。
- `AlwaysLinkAssembly` 在本專案是否必要（以 UGS 的做法為旁證）。
- FV-1 少見競態的實際機率。
- FV-1 的三個修法方向都未實測。

---

## 附錄 — 本輪理由有變、狀態不變的列

| ID | r3 | 理由更新 |
|---|---|---|
| TR-netcode-008 | ✅ | 閘門不變。預檢改讀 `shift_eta`，但晚到者讀到舊值（FV-2）；被拒的中途加入者會被 MPS 移出（FV-1）——影響 #9「拒絕後導向 Lobby\*」那半句，那半句不在本 TR 文字內 |
| TR-netcode-009 | ✅ | AC54 成立；但 NGO 設定雜湊先擋，真正的舊版 build 多半拿不到 `StaleBuild` 店語（EA-2） |
| TR-netcode-017 | ✅ | E8 已修，酬載 20 bytes；GDD :379 待 r5 回填 |
| TR-netcode-019 | ✅ | 兩層壽命不變；r1 新增的 `StartFailed` 復原對 FV-1 路徑無效（轉接層拿到 `ISession` 前就失敗） |
| TR-netcode-023 | ⚠️ | E1 契約層已修；Host 自行 unparent＋落地座標仍交 G2 |
| TR-netcode-028 | ⚠️ | E4 已修；殘留 FV-8（Settlement 欄）、**FV-1（Lobby\* 合流的入口不可達）** |
| TR-netcode-029 | ⚠️ | :794／:801／:807 已列入 GDD r5；`local_ready` 仍無任何 ADR 定義 |
| TR-netcode-039 | ✅ | E2（Solo 的 MemberIds）、E3 已修；Online Host 自核准的殘留歸 FV-3（不在本 TR 文字內） |
| TR-netcode-041 | ✅ | E9 已修；`SessionConfig` 分層問題（FV-5）不影響「可機械驗證」 |
| TR-netcode-046 | ⚠️ | 時間基準已解；FV-2（晚到讀者）、FV-1（Lobby\* 等待者可能不是成員） |
| TR-fpc-011 | ⚠️ | ADR-0001／0003 未改；ADR-0003 :95 的前提被推翻（avatar 在 approval 當下就 spawn），Onboarding 期間的 avatar 會不會進碰撞，無人裁決（CX-3） |
| TR-fpc-019 | ❌ | ADR-0005 r1 明文把 pointer lock 交給 ADR-0001／#11，但 ADR-0001 沒有承接，ADR-0006 開給 ADR-0001 r1 的義務也沒有這一項 |
| TR-fpc-020 | ⚠️ | 「焦點≠隱藏」已裁決；ADR-0005 說 Unity 層「由 ADR-0001 的 T1-Web 驗」，但 ADR-0001 沒有 T1-Web |
| TR-machine-001 | ✅ | `NoSlot` 已移進 `PlayerSlot`；NoSlot RPC 一律丟棄；ADR-0002 仍為 `ulong`（CX-1） |
| TR-machine-049 | ✅ | E6 已修，30 s 窗口在 NGO 層與遊戲層皆已關閉 |
| TR-product-026 | ⚠️ | 雜湊輸入範圍明文交 G4 |
| TR-concept-001 | ⚠️ | 開連結的 X3 已解；`T_load` 仍只有 stall 偵測 |
| TR-concept-003 | ⚠️ | referrer 帶碼已補；pointer lock 的驗證交棒對象不存在 |
| TR-concept-010 | ⚠️ | 掉落的結果契約已寫死、路線 (a) 原始碼可行；實作路由交 G2，解鎖交 ADR-0004 |
| TR-concept-016 | ❌ | ADR-0005 r1 明文把 `AudioContext` 交給「#14 音效 ADR」，該 ADR 不存在 |
| TR-index-018 | ⚠️ | `HeartbeatWire` 逐欄序列化，避開 wasm32／x64 的佈局相依；雜湊輸入仍交 G4 |
| TR-index-027 | ⚠️ | r2 的待辦都已完成；新缺陷 FV-4、EA-1；V10 未驗 |
