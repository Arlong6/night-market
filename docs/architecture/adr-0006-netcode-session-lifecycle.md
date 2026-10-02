# ADR-0006: 連線會談生命週期——兩層會談、一台純 C# 狀態機、slot 是玩家身份

## Status
Proposed

## Date
2026-10-01（r1：2026-10-03，依 `architecture-review-2026-10-01-r2.md` §3B、§3C 修訂；逐條對照見文末「r1 修訂紀錄」）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS（6000.3.24f1）、IL2CPP＋Managed Stripping High、NGO 2.13.2、Multiplayer Services 2.3.1、UTP 2.7.4（實機解析值，NGO 相依宣告寫 2.6.0） |
| **Domain** | Networking（Foundation：拓撲、Session 生命週期、連線健康、identity 契約） |
| **Knowledge Risk** | HIGH——NGO 2.x、MPS Sessions API、UTP 2.7 皆在模型訓練資料之後；本 ADR 只採用 engine-reference 與 W1 原型已查證的 API，未查證者全部列入 Verification Required |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`；`modules/multiplayer.md`（:14-20 套件版本、:22-36 NGO 2.x 差異、:63-95 ownership 與斷線處置、:97-113 逾時常數、:115-122 Relay TTL、:124-140 房間碼流程、:142-148 Web 組態、:158-165 建議架構）；`breaking-changes.md`（:40-42 `NetworkTransform.Update`、Multiplay Hosting 移除）；`deprecated-apis.md`（:16-18 `[Rpc]`、MPS Sessions）；`design/gdd/netcode-session.md`（Core Rules #8–#28 :140-702、適用性矩陣 :704-745、States :746-776、Interactions :778-883、Tuning Knobs :1173-1294、`[P]` 表 :1544-1640、OQ :1641-）；`design/gdd/machine-interaction.md`（C10、C20）；`design/gdd/game-concept-night-shift.md`；`docs/architecture/architecture-review-2026-10-01.md`（§2 G1 :38-44、§3 C1 :116-122、§6 :281）；`prototypes/w1-netcode/README.md`（:132-149 RTT、:306-307 雙重 unload 事件、:320-332 優雅／強制終止、:347-358 關分頁）與測試 `ApprovalCallbackTests.cs`、`DiscRoleTests.cs`、`TwoProcessRoleTests.cs`、`RttRoleTests.cs`、`OwnershipRoleTests.cs`、`EngineFactProbeTests.cs`；ADR-0001／0002／0003／0005；**r1 新增**：`docs/architecture/architecture-review-2026-10-01-r2.md`（§3B、§3C E1–E13、§5），以及 NGO 2.13.2／MPS 2.3.1 原始碼（`prototypes/w1-netcode/Library/PackageCache/`）——NGO：`NetworkConnectionManager.cs`、`NetworkSpawnManager.cs`、`NetworkObject.cs`、`NetworkBehaviour.cs`、`NetworkBehaviourUpdater.cs`、`MessageDelivery.cs`、`NetworkManager.cs`、`ForceNetworkSerializeByMemcpy.cs`、`Editor/CodeGen/NetworkBehaviourILPP.cs`、`Transports/SinglePlayer/SinglePlayerTransport.cs`、`Documentation~/advanced-topics/singleplayer.md`；MPS：`NetworkModule.cs`、`NetworkManagerSession.cs`、`GameObjectsNetcodeNetworkHandler.cs`、`RelayNetworkOptions.cs`、`IHostSessionNetwork.cs`、`IClientSessionNetwork.cs` |
| **Post-Cutoff APIs Used** | ① **MPS 2.3.1 Sessions**：`MultiplayerService.Instance.CreateSessionAsync` ／ `JoinSessionByCodeAsync`、`SessionOptions.WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS })`（只設定不啟動）、`IHostSession.Network.StartRelayNetworkAsync(RelayNetworkOptions)` ／ `StopNetworkAsync()`、`ISession` 事件 `Deleted`／`SessionHostChanged`／`PlayerLeaving`／`PlayerHasLeft`／`PlayerJoined`／`RemovedFromSession`／`SessionMigrated`／`StateChanged`、`ISession.Host`／`HasPlayer`／`Players`／`PlayerCount`／`State`／`Code`／`CurrentPlayer.Id`、`IHostSession.RemovePlayerAsync`／`DeleteAsync`（W1 第 1 批編譯＋runtime 驗證，`[P-10]`；2026-10-01 unity-specialist 原始碼複核：`SessionHandler.cs:65,191,481`、`IHostSessionNetwork.cs:69,94`）、`ISession.LeaveAsync()`（`Unity.Services.Multiplayer.api:1241`；**2.3.1 沒有 `LeaveSessionAsync`**，`NetworkManagerSession.cs:424` 明寫 "Use ISession.LeaveAsync instead"）、`RelayNetworkOptions(string region = null, bool preserveRegion = false)`（`RelayNetworkOptions.cs:163-167`；三個帶 `RelayProtocol` 的建構子皆 `[Obsolete]`，`:57,:87,:121`——r1 更正，原引 :258／:288／:322 有誤）、`SessionProperty(string value, VisibilityPropertyOptions, PropertyIndex)`（`SessionProperty.cs:6-35`）與 `event Action SessionPropertiesChanged`（`SessionHandler.cs:272`）；`ISession.ReconnectAsync()` 存在但未演練；**r1 新增**：`IClientSessionNetwork.StartFailed`（`IClientSessionNetwork.cs:19`）、`IHostSessionNetwork.MigrationFailed` 與 `IClientSessionNetwork.MigrationFailed`（皆 `:29`）、成員端自動加入網路（`NetworkModule.cs:113-123,505-541`） ② **NGO 2.13.2**：`ConnectionApprovalCallback` 在 Sessions 啟網下照常觸發、`ConnectionData` payload 完整（`[P-17]`，`ApprovalCallbackTests.cs:66,82,104-107`）；`RpcAttribute.Delivery`（`RpcAttributes.cs:88`，unreliable 上限 1296 bytes，`NetworkBehaviour.cs:372`）；`SendTo.SpecifiedInParams`＋`RpcTarget.Single(ulong, RpcTargetUse)`（`RpcTarget.cs:79,95-101,257`）；`NetworkManager.Shutdown()` 回傳 2 ms、對端 80 ms 收到（`[P-15]`）；`NetworkTransport` 抽象成員（`NetworkTransport.cs:11-112`，為 `MonoBehaviour` 子類）與 `StartHost()` 只呼叫 `StartServer()`、本機 client 全程在行程內（`NetworkManager.cs:1446,1474`）；`NetworkManager.DisconnectReason`（`NetworkManager.cs:659`）與 `DisconnectReasonMessage`（`DisconnectReasonMessage.cs:1-62`）；**r1 新增**：`NetworkManager.DisconnectClient(ulong, string)`（`NetworkManager.cs:1570,1578`；非空 reason 先送原因、延後斷線，`NetworkConnectionManager.cs:917-931`）、`NetworkObject.DontDestroyWithOwner` 的斷線處置分支（`NetworkConnectionManager.cs:1366-1420`）、`Unity.Netcode.Transports.SinglePlayer.SinglePlayerTransport`（NGO 2.4.0 起內建，只能以 Host 啟動）③ **UTP 2.7.4**：`DisconnectTimeoutMS`／`HeartbeatTimeoutMS`／`ConnectTimeoutMS`／`MaxConnectAttempts`（`EngineFactProbeTests.cs` 8/8、`multiplayer.md:98-104`）；`NetworkConfig` 預設值 `TickRate=30`／`ClientConnectionBufferTimeout=10`／`ConnectionApproval=false`／`EnableSceneManagement=true`（`NetworkConfig.cs:53,71,77,109`）④ `AuthenticationService.Instance.PlayerId` ≡ `session.CurrentPlayer.Id`（`[P-2b]` 實測，兩個獨立 session 同值） |
| **Verification Required** | **V1** 延後啟網的 client 側：機制已由原始碼證實（r2）——成員端在 session 網路屬性的**值改變**、且本機網路未啟動時，由 SDK 自動 `JoinNetworkAsync`（MPS `NetworkModule.cs:505-541`）；新加入一個網路已啟動的 session 時，模組初始化同樣觸發（`:113-123`）。待量的是延遲，以及「失敗不重試」之下復原路徑的成本（Decision 2）｜ **V2** approval 拒絕原因在遠端 client 可讀——原始碼已證實（r2：拒絕先送 `DisconnectReasonMessage` 再斷線，`NetworkConnectionManager.cs:889,917-927`；遠端讀 `NetworkManager.DisconnectReason`，`NetworkManager.cs:659`），T1 (h) 實跑一次即結案 ｜ **V3** `SinglePlayerTransport` 在 WebGL IL2CPP build 下 `StartHost()` 成功、本機 RPC／NetworkVariable 路徑正常；離開 Solo 指回 `UnityTransport` 後 MPS 啟網成功（Decision 10）｜ **V4** `MaxConnectAttempts = 10` 後連線階段 10 s 內失敗可見且不影響 Relay 路徑成功率｜ **V5** 心跳 `RpcDelivery.Unreliable` 在 WSS 下的到達間隔分布（`[P-11]`，W2）｜ **V6** send queue 深度監控點與 `MaxSendQueueSize` 定值（`[P-16]`，W2）｜ **V7** 行動瀏覽器 `visibilitychange` 與 WebGL context loss（OQ#10／#13，W2）｜ **V8** Post-MVP slot 保留與 `ReconnectAsync`（`[P-2a]`，W2）｜ ~~**V9**~~ **結案**（r2 原始碼核對：`UnityTransport.MaxSendQueueSize` 存在，預設 0 時由 `DisconnectTimeoutMS` 推算，`UnityTransport.cs:142,154-157`；`RosterState`／`RosterEntry` 的 `INetworkSerializable`＋`IEquatable` 組合合規，`NetworkBehaviourILPP.cs:359-372`）｜ **V10** 離開通知走 `fetch keepalive` 帶 Bearer token 到 UGS Lobby REST，自 itch.io iframe 發出能成功（CORS、token 有效期；`sendBeacon` 不能帶 Authorization 標頭，見 Decision 9）。⚠ `DELETE`＋`Authorization` 一定觸發 CORS preflight，各瀏覽器在 unload 期間對「需要 preflight 的 keepalive 請求」支援到什麼程度，目前不知道；實測須涵蓋 Chrome／Firefox／Safari。這條路徑繞過 Sessions SDK，MPS 升版時沒有編譯期保護 ｜ **V11**（r1 新增）Lobby\* 沙盒收場與自動加入的競態：Host 在 #23a 拆網後一秒內就 #26 重新啟網時，等待者的 `AbortSandbox` 是否一定先於 SDK 的自動加入；若不是，`StartFailed` → 重新加入要多久（Decision 10）｜ **V12**（r1 新增）client 斷線時手上的道具在每個留守 client 上存活、並收斂到 Host 的落地座標；`OnClientDisconnectCallback` 與心跳兩種觸發源都要測（Decision 7 前提 3；T1 (i′)） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005（Proposed）——`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector`／`IClipboard` 是本 ADR 的平台輸入；Relay WSS 共用 helper（ADR-0005 Decision 6）由本 ADR 的 `SessionServices` 呼叫。實際依賴的是 ADR-0005 **r1**（`InstallLeaveBeacon` 收 `method`／`headers`、`RoomCode` 讀 `document.referrer`），兩者須成對 Accept。本 ADR **不依賴** ADR-0003：NPC id 值域由本 ADR 擁有（Decision 4） |
| **Enables** | G2「同步物件生命週期與所有權轉移」（以本 ADR 的 `PeerLost` 序列與 slot 鍵為前提）；ADR-0004 機台互動組 Core（`PeerKey`、`PlayerDisconnected` 事件、`host_claim_delay_ms` 所需的延遲數字）；ADR-0001／0002／0003 r1（引用 Decision 4 identity 契約）；G8 延遲模型；G9 遊戲時鐘（`ShiftEndTs` 真相在本 ADR）；`NightShift.Identity` 組件（`PeerKey`／`PlayerSlot`／`NpcId`，零依賴，Decision 4） |
| **Blocks** | #1 Session／房間系統與 #2 網路同步層的全部 story；任何呼叫 `MultiplayerService`、`NetworkManager.StartHost`／`StartClient`、`ConnectionApprovalCallback` 的程式碼 |
| **Ordering Note** | **Accept 順序（r1 依 r2 §3B Resolution 1）**：ADR-0005 r1＋本 ADR r1（成對）→ ADR-0001 r1 → ADR-0002 r1、ADR-0003 r1 → G2 → ADR-0004。ADR-0001 因此不再是最先可 Accept 的那份：先 Accept 0001 r0 再改鍵，#3 的 story 會先以 `string Id` 寫下去。**依賴環的拆法**：ADR-0001 r1 一引用 `PeerKey` 就依賴本 ADR，而本 ADR 依賴 ADR-0005；ADR-0005 r1 因此把對 ADR-0001 的依賴改為 Related——它依賴的是 registry 的全專案禁用模式 `movement_logic_outside_core`，不是 ADR-0001 的決策輸出——否則成環 0001→0006→0005→0001。ADR-0001／0002／0003 的 r1 在本 ADR Accepted 後進行；在那之前，三份 ADR 的 Key Interfaces 視為「邊界轉換待補」而非衝突 |

## Context

### Problem Statement

四份既有 ADR 全把「NGO client-server 拓撲、client-as-host、Relay WSS、MPS Sessions」當**前提**引用，沒有任何 ADR 正式裁決它（architecture-review §2 G1，TR-concept-012）。netcode GDD r4 的 28 條 Core Rules、12 態狀態機、W1 原型結案的假設，全部只活在 GDD 裡，不在 ADR／registry 治理之下：

| 只存在於 GDD 的機制 | GDD 位置 | 為什麼必須升格為架構決策 |
|---|---|---|
| 心跳 2 s／8 s | #20 :363-407 | W1 實測 Host 被 `kill -9` 後 client 要 **87 s** 才收到 `OnClientDisconnectCallback`（`README.md:321,326-332`），AC6b 只給 12 s。心跳是**唯一**能把 87 s 壓進 12 s 的機制，不是優化 |
| approval 閘門＋版本閘 | #9 :153-176 | 版本閘的全部意義是「在任何資料交換之前擋下」；放錯層（連線後踢）在語義上做不到 |
| MPS 成員唯一寫入者＝Host | #24a :607-617 | 拔線者的 C# 不會執行，無人代為移除就會撞「這班人滿了」 |
| Lobby 延後建連、局間 teardown | #23／#23a :415-507 | 兩個狀態機（MPS session、NGO network）壽命不同，誰在什麼時候啟停必須有唯一答案 |
| Host 消失排歧表 | #18 :284-355 | 「Host 走了」與「我自己斷線」從本機 socket 看起來一模一樣，排歧需要兩條獨立路徑 |
| teardown 不變式 | #17a :272-283 | 只切 UI 不拆連線會留下「陰陽人」：client 已回主選單、Host 眼中仍在線 |
| 重連身分 `PlayerId↔slot` | :849-851 | NGO 重連配發新 `ClientId`，身分對照不是引擎能力 |

第二個問題是 architecture-review 唯一的 BLOCKING（§3 C1 :116-122、§6 :281）：ADR-0001 用 `string Id`、ADR-0002 用 `ulong clientId`（`ClaimState.ClaimedBy`）、ADR-0003 用 slot 位元，NPC 又有 `string Id` 與 `int npcId` 兩套，**沒有轉換契約、沒有重連穩定性宣告**。重連換號時 `PairMachine` 的舊鍵條目成孤兒，claim 側意外有 `claim_lock_timeout_sec` 保護，`PassThrough` 側沒有任何保險絲。review 把解法指派給本 ADR：玩家身份＝slot，`PlayerId↔slot` 對照為真相，clientId 只在 NGO 邊界出現。

W1 原型（`prototypes/w1-netcode`）已經把 20 條 `[P]` 假設結案 9 條、推翻 4 條，數字如下。本 ADR 的每一項決策都要能回指到這張表，而不是回指到訓練資料：

| 情境 | 層 | 訊號 | 延遲 | 來源 |
|---|---|---|---|---|
| Host `Shutdown()`（優雅） | NGO／Relay WSS | `OnClientDisconnectCallback` | 0.08 s | `README.md:320-325`、`[P-8]`／`[P-15]` |
| Host `kill -9` | NGO／Relay WSS | `OnClientDisconnectCallback` | ≈87 s（n=1，重試遇 UGS 429） | `README.md:321,326-332`、`[P-14]` |
| Host `kill -9` | MPS session 層（Lobby） | `PlayerLeaving` | 132.61 s | `w1-p14-out/result.txt`、#25 |
| Host `DeleteAsync()`（優雅） | MPS session 層（Lobby） | `Deleted` | 1.14 s | `w1-p14g-out/result.txt`、#25 |
| 瀏覽器關分頁 | NGO／Relay WSS | 逾時（無 close frame） | 15.23 s／18.99 s | `README.md:347-358`、`[P-13]` |
| `beforeunload`＋`pagehide` → `sendBeacon` | 瀏覽器 | 伺服器端實收 | 8/8 試驗、16/16 送達（含 itch.io iframe 父頁關閉） | `[P-18]` |
| 同區 RTT（`asia-northeast1`） | NGO named message | — | median 88.8／p95 94.5 ms | `README.md:144`、`[P-3]` |

### Constraints
- **Web 是 MVP 唯一平台**：WSS 之下是單一 TCP；背景分頁節流到 1 Hz（W1 第 3 批，六分半鐘未凍結）；`ReconnectionTimeoutMS` 只支援 DTLS，**WSS 沒有傳輸層自動重連**（`multiplayer.md:110-111`）。
- **Relay 每 client 連線 TTL 10 s**（host 無 peer 時 60 s），由 NGO 每 `HeartbeatTimeoutMS`＝500 ms 的 PING 重置；該常數兼 UTP heartbeat，**不得調動**（`multiplayer.md:107-109,115-122`）。
- **支柱硬標**：開連結就開玩 ≤ 60 s（`join_time_budget_sec`，分段 `T_load`／`T_lobby`／`T_spawn`＝25／10／10）；沒有人在等（純看戲 > 30 s 就重做）。
- **`max_players`**：MVP build＝2，VS 起＝4；型別與容器一律按 4 設計。
- **既有登記立場**：`NetworkConfig.TickRate = 10`（ADR-0001）；Relay 協定所有平台顯式 WSS、共用 helper（ADR-0005 Decision 6）；平台能力只經 `NightShift.Platform` 介面（ADR-0005）；`movement_logic_outside_core` 的分層紀律（ADR-0001）；狀態真相走 NetworkVariable、RPC 只驅動表現層（ADR-0002／0003）。
- **UGS 限流**：快速重試 create／join 會被 429 且誤報為 `SessionException: lobby not found`（`w1-disc-client-kill.log:701-1491`）。
- **一人團隊**：型別要少，fake 要便宜；所有決策邏輯必須在沒有 NGO、沒有 UGS 的 EditMode 裡測得到（TR-netcode-044）。
- **範圍邊界**：物件 spawn／despawn／ownership 轉移歸 G2；機台 claim 清理語意歸 ADR-0004（C10 已裁決「斷線只放 claim」）；DTLS 混房歸未來傳輸協定 ADR；Steam 歸 Alpha 的 Steam 整合 ADR。本 ADR 對它們只提供**事件與鍵**。

### Requirements
- **R1** 正式裁決拓撲，並以 ADR 記錄 plan B（TR-concept-012、TR-netcode-040）。
- **R2** Session 層（MPS）與 Connection 層（Relay＋NGO）壽命獨立：Lobby 只有 MPS；#26 才啟網；#23a 局間拆回 MPS-only（TR-netcode-019）。
- **R3** 狀態機與 GDD States 表逐態相同、適用性矩陣逐格可斷言，且為純 C#（TR-netcode-028／044）。
- **R4** approval 閘門是截止與版本閘的唯一執行點，拒絕發生在任何資料交換之前（TR-netcode-008／009）。
- **R5** 心跳 2 s／8 s 自 NGO 連線起、雙向存活確認、單向失效走斷線序列、offset 與 ping 同源（TR-netcode-017）。
- **R6** Host 是 MPS 成員唯一寫入者；斷線處置有固定順序與 2 s 上限；本 ADR 不定義 claim／物件的清理語意（TR-netcode-024、C10）。
- **R7** Host 消失排歧、Lobby 的 Host 離開偵測、teardown 不變式（TR-netcode-015／025）。
- **R8** identity 契約：`PlayerId↔slot↔clientId`、slot 指派與回收、重連穩定性、NPC id 值域與 `CapsuleGhost.Id` 的關係（TR-netcode-035、review C1）。
- **R9** UTP／NGO 常數契約與 send queue 溢位防護（TR-netcode-021／018）。
- **R10** 班次時鐘真相、ServiceError 與單人模式不經 UGS、常數 data-driven 可機械驗證、`connection_state` 店語表（TR-netcode-036／039／041／045）。
- **R11** 進房分段預算各自為硬閘門；離線立即重取樣與旗標（TR-netcode-011／012）。

## Decision

1. **拓撲正式裁決**。NGO 2.13.2 **client-server** 拓撲、**client-as-host**（Host＝權威＋本機玩家，`clientId = 0`）、**MPS 2.3.1 Sessions** 管房間碼／roster／成員資格、**Relay WSS** 為唯一傳輸（ADR-0005 Decision 6），`NetworkConfig.TickRate = 10`（ADR-0001）、`EnableSceneManagement = false`（兩端必須一致，否則握手失敗 "Scene Hash … does not exist"，`README.md:182-183`）、`ConnectionApproval = true`。不用 Distributed Authority；不用 `WithDirectNetwork()`（瀏覽器無 inbound）。**Plan B 正式記錄**（TR-netcode-040）：第一退路 Distributed Authority（NGO 2.1.1+／UTP 2.3.0+／MPS 1.0.2+ 有官方 Web 支援），第二退路自租機器跑 headless＋nginx/caddy 反代 wss（Multiplay Hosting 已自 6.3 移除）。觸發條件只有兩個：client-as-host over Relay WSS 出現本 ADR 機制繞不過的根本障礙，或 Relay 免費額度（50 平均月 CCU）超額。

2. **兩層會談，壽命不同**。
   - **Session 層（MPS `ISession`）**：壽命＝一次開房到拆房，跨多個班次（Lobby → InShift → Settlement → Lobby → …）。成員資格、房間碼、Host 身份、`max_players`（唯一執行點＝MPS join）都在這層。唯一寫入者 Host（#24a）。
   - **Connection 層（Relay allocation＋NGO）**：壽命＝一個班次。#26「開始上班」時 Host 呼叫 `session.Network.StartRelayNetworkAsync(new RelayNetworkOptions(region))` 建立；Settlement 結束時 `StopNetworkAsync()` 拆除（#23a），MPS 的 `SessionState` 維持 `Connected`（本 ADR Core 的狀態型別叫 `SessionPhase`，見 Decision 3）。Lobby／Lobby\* 期間**不存在**對外的 NetworkManager 連線（Lobby\* 的練習沙盒只是本機 Host，見 Decision 10）——W1 證實連 `NetworkManager` 單例都不需要存在（#23 :440-441）。
   - **協定在建 session 當下一次性決定**：`CreateSessionAsync(new SessionOptions { MaxPlayers = 4 }.WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }))` 只設定不啟動；每個加入者 `JoinSessionByCodeAsync(code, new JoinSessionOptions().WithNetworkOptions(…WSS))` 再宣告一次，**協定不會從 Host 傳染給加入者**（`DiscRoleTests.cs:178-180`）。兩處都經 ADR-0005 的共用 Relay helper，任何一條加入路徑漏掉就在該路徑單獨拋 `Mismatched`。
   - **Region**：#26 建 allocation 前 `IRegionSelector.SelectRegionAsync(available, fallback, ct)` → `new RelayNetworkOptions(region)`（#28，貼著 Host 選）。**只准用 `RelayNetworkOptions(string region = null, bool preserveRegion = false)`**：三個帶 `RelayProtocol` 參數的建構子在 2.3.1 已 `[Obsolete]`（`RelayNetworkOptions.cs:57,87,121`；r1 更正行號），協定只能在 `WithNetworkOptions()` 設，任何人把協定參數「修回」這裡都是倒退。
   - **client 側啟網（V1）**：由 SDK 自動完成（r2 以原始碼證實）——成員端在 session 網路屬性的**值改變**、且本機網路未啟動時自動 `JoinNetworkAsync`（MPS `NetworkModule.cs:505-541`）；Host `StopNetworkAsync()` 移除該屬性時，已啟網的成員端自動停網（`:510-514`）；新加入一個網路已啟動的 session 時，模組初始化同樣觸發加入（`:113-123`，也就是 #9 中途加入走的路）。對 Core 都只是一個 `NetworkStarted` 事件。⚠ **自動加入失敗不重試**：`m_Property` 在嘗試之前就更新，同一個屬性值不會觸發第二次。轉接層因此在 Lobby／Lobby\* 訂閱 `IClientSessionNetwork.StartFailed`（`IClientSessionNetwork.cs:19`），收到即復原：`LeaveAsync()` 後以同一個房間碼 `JoinSessionByCodeAsync`，借模組初始化重新觸發加入；成本約一次加入，W2 與 V11 一起量。原稿的 `network_epoch` 屬性退路不再需要。班次剩餘時間的預檢走同一個 session property 機制（Decision 5）。

3. **純 C# `SessionMachine`（`NightShift.Session.Core`，`noEngineReferences = true`）**。
   - **狀態**＝GDD States 表的 12 態，一字不改：`Booting`、`LoadFailed`、`Idle`、`ServiceError`、`CreatingRoom`、`JoiningRoom`、`Lobby`、`LobbyWaiting`（＝Lobby\*，前一班進行中）、`Onboarding`、`InShift`、`Disconnected`、`Settlement`；另加 `SessionMode { Online, Solo }` 旗標（Decision 10）。C# 型別名是 **`SessionPhase`**（r1 依 r2 X4 改名）：`SessionState` 是 MPS 的型別（None／Connected／Disconnected／Deleted），轉接層同時 using 兩個命名空間會撞名，而且本 ADR 的 Decision 2 與 T1 (g) 提到的 `SessionState.Connected` 指的正是 MPS 那個。
   - **輸入**＝離散 `SessionEvent`，由轉接層翻譯引擎／服務事件而來；**輸出**＝`SessionEffect` 命令清單，由轉接層執行。Core 不呼叫任何 Unity、NGO、UGS API，也不持有 Task。
   - **適用性矩陣（GDD :704-745）就是守衛表**：矩陣實為 **32 列**（#1–#28 加 #15a、#17a、#23a、#24a）× **11 欄**（Booting／LoadFailed 合為 Boot 欄），Core 以表驅動實作，EditMode 測試逐格斷言全部 352 格。（r1 依 r2 E4 更正：原寫 28 × 12，照字面只測 28 列，會漏掉 #17a teardown 不變式與 #24a MPS 成員唯一寫入者——恰好是本 ADR 最核心的兩條。）
   - **每一列先定「主詞」，再讀欄位**（r1 依 r2 E4）。欄是狀態，但不是每一列都在問「本機現在是什麼狀態」；全部當成本機狀態來實作，會把 #24 寫錯——Host 永遠不會處於 Onboarding 或 Disconnected：

     | 主詞 | 列 | 欄位讀的是誰的狀態 |
     |---|---|---|
     | 本機 | 其餘 25 列 | 本機 `SessionPhase` |
     | 受影響的 peer（Host 執行） | #11、#14、#15、#15a、#16、#24 | Onb／InShift／Settle 欄讀該 peer 在 `SlotTable` 的 `PeerPhase`；Lobby／Lobby\* 欄讀 Host 本機（那時沒有 NGO 連線，peer 不存在）；Disc 欄不讀——Host 不會處於 Disconnected，peer 在被判離線的那一刻就退出 `SlotTable`。GDD r5 為矩陣加「主詞」欄時一併收斂這一欄 |
     | 加入者與 Host 各讀一半 | #9 | Joining 欄讀加入者本機（UI 預檢）；InShift／Settle 欄讀 Host 本機（approval 閘門） |

     矩陣的「–」格只在主詞為本機時於 Core `throw`（事件在該狀態下不該出現）；主詞為 peer 時，「–」與「N」都是忽略並記錄。
   - **Onboarding 期間斷線＝視同從未加入**（#11／#24 的 Onb 欄＝N；r1 補上原稿沒有定義的 slot 回收路徑）：釋放 slot，但**不發** `PlayerLeft`（`PlayerJoined` 要等 avatar 進場才發，這時還沒發過）、不計 #15a、不重取樣。Host 仍要 despawn approval 時就已建立的 avatar、仍要 `RemovePlayerAsync`（#24a 的 Onb 欄＝Y）、仍要切斷 NGO 連線。各參與者從 `PeerLostContext.Phase` 得知這種情況（Decision 7）。
   - **時間源**：Core 只認 `nowMs`（由轉接層以 `IPageLifecycle.NowMs` 餵入，單調）。沒有 `DateTime.Now`、沒有 `Time.*`。
   - 這條分層紀律登記為 forbidden pattern `session_logic_outside_core`：任何「要不要判斷線、能不能加入、該不該 teardown」的決策不得住在 `NetworkBehaviour`／`MonoBehaviour`／UGS 回呼裡。

4. **Identity 契約**（review C1；取代三份 ADR 各自為政的編碼）。
   - 三種 id、三個範圍，**只在邊界轉換**：

   | id | 型別 | 壽命／範圍 | 誰指派 | 允許出現的位置 |
   |---|---|---|---|---|
   | `PlayerId` | `string`（UGS 匿名帳號，≡ `session.CurrentPlayer.Id`） | 跨 session、跨班次；清快取／換瀏覽器即換（`[P-2b]`，設計接受） | UGS Authentication | MPS 層、approval payload、Core `SlotTable`、#15a 離線計數、結算 `final_roster` |
   | `Slot` | `byte`，`0 .. max_players−1` | 一個班次內穩定；離線即回收（MVP）；Post-MVP 保留 `reconnect_window_sec` | Host 於 approval 時指派（最小空位） | **所有遊戲系統的玩家鍵**：`CapsuleGhost.Id`、`PairKey`、`PassThroughPlayerMask` 位元、`ClaimState.ClaimedBy`、roster、HUD |
   | `clientId` | `ulong`（NGO） | 一次 NGO 連線；重連換號；Host 恆 0 | NGO | **只在 NGO 邊界**：`RpcParams.Receive.SenderClientId`、`OwnerClientId`、`OnClientConnected/DisconnectCallback`、`RpcTarget.Single(clientId)` |

   - **真相＝Host 的 `SlotTable`（Core）**；複製為 `SessionRoot.Roster`（Host 寫 `NetworkVariable<RosterState>`，固定 4 格，遲加入者自動取得現值）。轉接層在 RPC 進 Core 前先 `SlotOf(senderClientId)`，Core 內**不出現** `ulong`。`SlotOf` 回 `PlayerSlot.NoSlot` 的 RPC 與 NGO 回呼一律**丟棄並記錄**、不進 Core（r1 依 r2 E6）：這涵蓋「心跳已判離線、NGO 連線還在」的窗口（Decision 7 第 5a 步之前），以及其後遲到的 `OnClientDisconnectCallback`。`NoSlot` 與 claim 的「無人」同為 255，不丟棄的話，鬼連線送來的請求會被當成「無人」送來的。
   - **回收規則**：#24 序列第 4 步把 `Roster[slot].Online = false` 並釋放 slot（MVP）。Core 保證對同一 slot，`PlayerLeft(slot)` 一定先於下一個 `PlayerJoined(slot)` 送出，且兩者之間至少隔 `onboarding_duration_sec` 下限 **3.0 s**。這個間隔是**結構性**的：slot 回收後可以立即指派給下一個 approval（**不設指派冷卻**——r1 依 r2 E10 刪除；冷卻會讓 2 人房裡唯一的空位在 3 s 內被判 `Full`），但 `PlayerJoined` 要等定長過場結束、avatar 進場才發。⚠ 新玩家的 avatar `NetworkObject` 在 approval 當下就由 NGO 建立（`CreatePlayerObject = true`），所以 3.0 s 保護的是 `PlayerJoined` 的時刻，不是物件存不存在；ADR-0003 :95「新玩家的 `NetworkObject` 物理上不可能存在」須在其 r1 改述。消費者（`PairMachine`、PassThrough 遮罩、claim 表、HUD 名牌）**必須在 `PlayerLeft(slot)` 清掉該 slot 的一切條目**——這就是「重連換號的孤兒回收」：重連者拿到的是新 slot（MVP）或同一 slot（Post-MVP 保留），兩種情況下舊條目都已被 `PlayerLeft` 清除，不存在以 clientId 為鍵的殘留。PassThrough 遮罩是 owner-write（ADR-0003 D1）：**由每個玩家自己的擁有者端**在收到 `PlayerLeft(slot)` 時清掉自己遮罩的第 slot 位；Host 不得代清，代清的寫入會被 `CannotWrite()` 靜默丟棄（r1 依 r2 X5）。
   - **NPC id**：`int npcId ∈ [0, NpcId.Max)`，`NpcId.Max = 64`。**值域由本 ADR 擁有**（r1 依 r2 §3B Resolution 1 反轉：原寫「由 ADR-0003 的遮罩決定」，會在 ADR-0003 r1 改用 `PeerKey` 時形成 0003↔0006 環）；ADR-0003 的 `PassThroughNpcMask`（`ulong`，64 位）寬度由此推導，並以靜態斷言 `NpcId.Max <= 64` 釘住。Host 指派，`npc_id_reuse_cooldown_sec ≥ 1.0` 後才可重用（ADR-0003 :97）。與玩家鍵**不共用值域**：ADR-0001 的 `CapsuleGhost.Id` 與 `PairKey` 改用 `PeerKey { PeerKind Kind; byte Index; }`，玩家 `Index = slot`、NPC `Index = npcId`。
   - **組件**（r1 依 r2 §3B Resolution 1）：`PeerKind`、`PeerKey`、`PlayerSlot`、`NpcId` 住在獨立的 **`NightShift.Identity`**（asmdef `noEngineReferences = true`、不引用任何組件）。契約由本 ADR 裁決，程式碼卻不放在 `Session.Core`——`Movement.Core`（ADR-0001）與 `Interaction.Core`（ADR-0002）不必為了一個兩欄 struct 引用整個 session 核心。ADR-0001／0003 r1 改鍵為 `PeerKey`；ADR-0002 r1 把 `ClaimState.ClaimedBy` 與 `InteractValidator.Validate(…, ulong requester, …)` 都改為 `byte` slot（`PlayerSlot.NoSlot`＝無人）。
   - **#15a 離線計數**以 `PlayerId` 為鍵、班次為範圍（Core 內 `Dictionary<string,int>`，`Settlement → Lobby` 時清空）；換裝置即重新計數（GDD 已接受）。

5. **Approval 閘門（#9，唯一執行點）**。`NetworkManager.ConnectionApprovalCallback` → 轉接層解碼 `request.Payload` → Core `ApprovalGate.Evaluate(ApprovalRequest, HostView)` → `ApprovalVerdict`，純函式、µs 級，遠在 `ClientConnectionBufferTimeout`（10 s）之內。
   - **Payload**（`NetworkConfig.ConnectionData`，固定二進位，≤ 80 bytes）：`byte PayloadVersion`、`ushort ProtocolVersion`（本 ADR 的 session 協定版本常數，任何 RPC／NetworkVariable 佈局變更即 +1）、`uint BuildId`（build 時產生的內容雜湊；dev build 以 `SessionConfig.AllowDevBuilds` 旗標放行 0）、`FixedString64Bytes PlayerId`。
   - **判定順序**（第一個命中即拒，`Reason` 字串＝`JoinRejectReason` 枚舉名（r1 依 r2 X4 改名：ADR-0002 互動層也有一個 `RejectReason`，同名不同義），店語翻譯在 client 的 `connection_state` 表）：
     1. `PayloadVersion`／`ProtocolVersion`／`BuildId` 不符 → `StaleBuild`（「這是舊的班表，重新整理一下」；AC54 的「任何資料交換之前」）
     2. `PlayerId` 不在 `HostView.MemberIds` → `NotAMember`（Online 時＝`session.Players`：NGO 連線者必須先是 MPS 成員，`max_players` 已由 MPS 擋，這裡只做二次驗證與防偽；Solo 與 Lobby\* 沙盒＝`{ 本機 PlayerId }`，見下方「Host 自核准」）
     3. 同 `PlayerId` 已占用在線 slot → `Duplicate`（同帳號雙開）
     4. `ShiftEndTs − HostNowMs ≤ late_join_cutoff_sec`（含端點、含 Settlement 全程）→ `LateJoinCutoff`（client 進 `LobbyWaiting`）
     5. 無空 slot → `Full`（到不了：MPS 已擋，且 r1 已拿掉 slot 指派冷卻，見 Decision 4）
     6. 否則 `Approve(slot)`：`response.Approved = true`、`CreatePlayerObject = true`（avatar prefab 契約歸 ADR-0001／G2；其中 `DontDestroyWithOwner = true` 是本 ADR 的前提，見 Decision 7）
   - **Host 自核准**（r1 依 r2 E2）：NGO 對 Host 本機 client（clientId 0）照樣呼叫 approval callback，但 `Approved = false` 只記一行警告就無條件核准，而且照 `response.CreatePlayerObject` 決定建不建 avatar（`NetworkManager.cs:1510-1516`）。所以 `ApprovalGate` 若誤拒 Host 自己的請求，結果不是進不了場，而是**靜默進場、`SlotTable` 沒有 slot 0、Host 沒有 avatar**。三道防線：① `HostView.MemberIds` 一定含 Host 自己——Online 為 `session.Players`（建房者即成員）；Solo 與 Lobby\* 沙盒沒有可用的 MPS 成員表，`MemberIds = { 本機 PlayerId }`：已登入用 UGS `PlayerId`，未登入（Solo 不初始化 UGS）用常數 `SessionConfig.SoloLocalPlayerId`，payload 帶同一個值；② T0 (b) 對 Online、Solo、沙盒三種 Host 規範請求斷言「永不被拒」；③ 轉接層在 `StartHost()` 返回後斷言 `SlotTable.SlotOf(0) == 0` 且 `NetworkManager.LocalClient.PlayerObject != null`，失敗即 Teardown 並記錄（dev build 直接拋例外）。
   - **UI 預檢與 Lobby\* 剩餘時間（非權威；r1 依 r2 E5 改寫）**：沒有 NGO 連線的端（Lobby 預檢、Lobby\* 等待畫面）也沒有心跳 offset，拿到以 Host 單調時鐘為基準的 `ShiftEndTs` 無從換算。所以 session property 發布的是**發布當下的相對量** `shift_eta = { phase ∈ {Lobby, InShift, Settlement}, remaining_ms }`（字串編碼由實作定）；client 收到時以本機 `IPageLifecycle.NowMs` 錨定：`remaining(now) = remaining_ms − (now − t_received)`。誤差約等於屬性傳播延遲（量級參考：W1 的 `Deleted` 事件 1.14 s），對非權威提示足夠；能不能加入一律以 approval 為準。Host 只在階段改變與 `end_shift_early` 時重發，每班 2–3 次，碰不到 UGS 限流。`phase` 回到 `Lobby` 同時是 Lobby\* 沙盒收場的訊號（Decision 10）。對應 TR-netcode-046。

6. **心跳（#20）**。
   - **載體**：`SessionRoot : NetworkBehaviour`，Host 擁有，#26 啟網後**第一個** `Spawn()` 的物件；壽命＝班次；承載 `Roster`、`ShiftEndTs` 兩個 Host 寫 NetworkVariable 與心跳 RPC。
   - **RPC**：`[Rpc(SendTo.Server, Delivery = RpcDelivery.Unreliable)] HeartbeatToHostRpc(HeartbeatWire p, RpcParams rp = default)`；`[Rpc(SendTo.SpecifiedInParams, Delivery = RpcDelivery.Unreliable)] HeartbeatToClientRpc(HeartbeatWire p, RpcParams rp)`，目標以 `RpcTarget.Single(clientId, RpcTargetUse.Temp)` 執行期定址（ADR-0002 的理由同樣適用：掛載位置不影響收件人）。
   - **Payload**（邏輯 **20 bytes**；r1 更正原寫的 16 bytes）：`ushort Seq`、`ushort LastPeerSeqSeen`、`long HostShiftEndTsMs`、`long HostNowMs`。前三個是 GDD 定案的 `{seq, last_peer_seq_seen, host_shift_end_ts}`；`HostNowMs` 是 offset 公式 `offset = host_value − (local_value + RTT/2)` 的 `host_value` 本身——沒有它公式無法成立，GDD r5 應補列。**型別分兩層**（r1 依 r2 E8）：Core 的 `HeartbeatPayload` 是純 BCL 的 `readonly struct`（`noEngineReferences` 之下不能實作 NGO 介面）；RPC 參數是轉接層的 `HeartbeatWire : INetworkSerializable`，逐欄序列化成 20 bytes。原稿把 Core 型別直接當 RPC 參數，ILPP 會在建置期報 "Don't know how to serialize"（`NetworkBehaviourILPP.cs:2654,3194`）。**不採用 `ForceNetworkSerializeByMemcpy<HeartbeatPayload>`**：它過得了 ILPP（`ForceNetworkSerializeByMemcpy.cs:10`，約束 `unmanaged, IEquatable<T>`），但 memcpy 的線上格式就是原生 struct 佈局（含 4 bytes 填充，實送 24 bytes），「兩端佈局相同」因此成了隱性前提。ADR-0005 要讓 Web（wasm32）與桌面（x64）同房，這個前提在 EditMode 裡測不到。Unreliable RPC 的參數上限是 **1296 bytes**（`NetworkMessageManager.DefaultNonFragmentedMessageMaxSize`，超過即 `OverflowException`，`NetworkBehaviour.cs:372`）；payload 日後加欄位以此為硬牆。
   - **時序**：雙方各自每 `heartbeat_interval_sec`（2 s）發一拍，每拍帶自己的 `Seq` 與「最後看到對方的 `Seq`」。Host 側判定（每個 slot 獨立）：`now − lastRx[slot] > heartbeat_timeout_sec`（8 s）→ `PeerLost(slot, HeartbeatTimeout)`；對方回報的 `LastPeerSeqSeen` 落後 Host 已送 `Seq` 超過 `heartbeat_timeout_sec / heartbeat_interval_sec`＝4 拍 → `PeerLost(slot, OneWayLoss)`（雙向存活確認，在還通的那個方向上偵測單向失效）。client 側：`now − lastRxFromHost > 8 s` → 進 #18 排歧（Decision 8）。
   - **RTT 與 offset**：client 記每個 `Seq` 的送出時刻；收到 Host 心跳時 `rtt = now − sentAt[p.LastPeerSeqSeen]`，`offset = p.HostNowMs − (now + rtt/2)` 以 EMA 平滑至 `clock_offset_tolerance_ms`（100 ms）；同一次往返供 HUD ping。顯示層 catch-up 進行中不套用新 offset（公式③）。
   - **運行範圍**：Host 自 `OnClientConnectedCallback`、client 自本機 NGO 連線建立起，到 `StopNetwork`／`ShutdownNgo` 為止——涵蓋 Onboarding、InShift、Settlement；Lobby／Lobby\* 不跑（沒有 NGO 連線）。
   - **選 Unreliable 的理由**：WSS 單一 TCP 之下 reliable／unreliable 的到達時刻無差（GDD #20 :398-406），但 unreliable 不占 UTP reliable 視窗，心跳不會與大流量搶同一個 reliable 序列而被 `NetworkSendQueueFull` 拖累（`[P-16]`）。V5 量到達分布後若需改 reliable，只改 attribute 參數。

7. **斷線處置的觸發與分工（#24／#24a；C10 邊界）**。
   - **觸發源（Host）**：心跳逾時、單向失效、`OnClientDisconnectCallback`。三者在 Core 匯流為一個 `PeerLost(slot, playerId, cause)` 效果，**冪等**：同一 slot 在同一次在線期間只執行一次，後到的觸發源被吸收——在轉接層就因 `SlotOf` 回 `NoSlot` 而被丟棄（Decision 4）。
   - **前提**（r1 依 r2 E1；NGO 2.13.2 原始碼）。觸發源為 `OnClientDisconnectCallback` 時，NGO 在呼叫回呼**之前**就已處置該 client 的 PlayerObject 與 owned 物件（`NetworkConnectionManager.cs:1366-1420`；回呼在 :1567）：
     1. **avatar prefab 必須 `NetworkObject.DontDestroyWithOwner = true`**（預設 false）。否則 avatar 在序列開跑之前就已 despawn＋destroy。Host 端 NGO 會把子 `NetworkObject` 移到根節點（`NetworkSpawnManager.cs:1714-1760`，條件為 `IsServer || distributedAuthority`），**client 端沒有這層保護**（`OnDespawnNonAuthorityObject`，:1664-1680）：以 `Transform.SetParent` 掛在手部 socket 的道具（machine C13，`AutoObjectParentSync = false`）會跟著 avatar 一起被銷毀——**Host 還有這件道具，所有 client 都沒有了**。設為 true 後 NGO 只做 `RemoveOwnership()`，由本序列掌握順序、第 5 步顯式 despawn。可攜道具的同一設定（GDD #24 前置條件）不變。
     2. **代價：Host 端那具 avatar 會短暫「變成 Host 的本機玩家」**。`RemoveOwnership()` 就是 `ChangeOwnership(obj, 0)`（`NetworkSpawnManager.cs:457-467`），它不清 `IsPlayerObject`，所以 Host 上該 avatar 的 `IsOwner` 與 `IsLocalPlayer` 都會變成 true（`NetworkObject.cs:1232,1237`），並觸發 `OnGainedOwnership`／`OnOwnershipChanged`；`NetworkTransform`（`AuthorityMode = Owner`）也改由 Host 提交。序列在同一個回呼內同步跑到第 5 步 despawn，`Update()` 看不到這個窗口，ownership 回呼看得到。**規則**：avatar 上的元件在 `OnNetworkSpawn()` 快取一次「是否為本機玩家」，之後不再以 `IsOwner`／`IsLocalPlayer` 的即時值判斷；`OnGainedOwnership`／`OnOwnershipChanged` 不得做輸入、攝影機或 HUD 綁定。這是 ADR-0001 r1 與 G2 的義務。
     3. **掉落的道具在每個留守 client 上都必須存活，而且不能只靠 NetworkVariable**。心跳觸發源同樣適用：即使第 2 步在 Host 端先 unparent，`AutoObjectParentSync = false` 下這個 unparent 不會複製出去，第 5 步的 despawn 一到，client 照樣把道具一起銷毀。寫 NV 救不了它：NV 的 delta 要到下一個 network tick 才送（`NetworkBehaviourUpdater.cs:227,239-242`），一定排在 `Despawn()` 當下就入列的 `DestroyObjectMessage`（`NetworkSpawnManager.cs:1815-1826`）之後。可行的兩條路由 G2 二選一：**(a)（推薦）client 端自救**——NGO 在銷毀 GameObject 之前先呼叫 `OnNetworkDespawn()`（`NetworkSpawnManager.cs:1767` 先於 :1854，Host 與 client 皆然），avatar 在其中把手部 socket 上的道具移到根節點、保留世界座標，Host 的權威落地座標再以任何途徑校正（這時 NV 也行）。這條路不依賴訊息到達序。**(b) 先於 despawn 入列的 reliable 掉落訊息**——reliable RPC 在呼叫當下入列（`NetworkBehaviour.cs:408`），與 `DestroyObjectMessage` 同屬 `ReliableFragmentedSequenced`（`MessageDelivery.cs:37,50`），在每個 client 上依序處理。但「所有 reliable 訊息走同一條佇列」是 NGO 的實作細節，原始碼自註 "For now"，選 (b) 就得在 NGO 每次升版時重驗。本 ADR 只定契約：第 5 步之後，道具在每個 client 上都存在，且收斂到 Host 的落地座標（V12、T1 (i′)）。
   - **轉接層 `DisconnectSequencer`** 依固定優先序呼叫 `IDisconnectParticipant.OnPeerLost(in PeerLostContext ctx)`，全序列在同一幀同步完成（第 6 步的服務呼叫為 fire-and-forget＋失敗重試一次，不阻塞），上限 `disconnect_cleanup_sec`（2 s）：

   | 序 | 優先序常數 | 誰 | 做什麼 |
   |---|---|---|---|
   | 1 | `FreezeInput = 0` | ADR-0001 轉接層 | 停止採納該 slot 的 NetworkTransform 更新（已被判離線的角色不得再動） |
   | 2 | `DropHeldItems = 10` | G2 | 手持物 unparent、落地座標、`RemoveOwnership()`（道具與 avatar 皆 `DontDestroyWithOwner = true` 為前提）；道具在每個 client 上必須存活（前提 3） |
   | 3 | `ReleaseClaims = 20` | ADR-0004 | 站台**只釋放 claim**、`ClaimGeneration + 1`；不判 `Failed`（C10） |
   | 4 | `Roster = 30` | 本 ADR | `Roster[slot].Online = false`、slot 回收、`PlayerLeft(slot)` |
   | 5 | `DespawnAvatar = 40` | G2 | despawn 該玩家 avatar，不留殭屍 |
   | 5a | `DisconnectTransport = 45` | 本 ADR | cause 不是 `TransportDisconnect` 時（心跳逾時、單向失效、`LeaveRequested`）呼叫 `NetworkManager.DisconnectClient(clientId, reason)`，**reason 必須非空**（＝`PeerLostCause` 名）。非空時 NGO 先送 `DisconnectReasonMessage`、把斷線排進延後佇列，不在本幀重入序列；空字串或 `null` 會同步斷線、在本幀重入（`NetworkConnectionManager.cs:917-931`）。⚠ 單參數多載 `DisconnectClient(clientId)` 會自動補一個非空 reason（`NetworkManager.cs:1570`），`DisconnectClient(clientId, null)` 卻是同步的——一律顯式傳。不切的話，該 client 在 NGO 層仍是 connected client 與 observer，直到 UTP `DisconnectTimeoutMS`（30 s）；這段期間它送來的 RPC 照常被處理（`NetworkConnectionManager.cs:588-603`）（r1 依 r2 E6） |
   | 6 | `ReleaseMembership = 50` | 本 ADR | `session.AsHost().RemovePlayerAsync(playerId)`（Host 唯一寫入者） |
   | 7 | `Resample = 60` | 本 ADR | `online_player_count` 重取樣、grace／`host_solo` 旗標、#15a 計數 +1 → 波次導演 |

   參與者以優先序註冊（DI），Core 不知道參與者是誰；本 ADR 只擁有第 1 步的**觸發**與第 4／5a／6／7 步的**內容**，第 2／3／5 步的語意分別歸 G2 與 ADR-0004。`PeerLostContext` 帶 `PeerPhase Phase`：`Phase == Onboarding` 時第 1、2、3、7 步不做事，第 4 步只釋放 slot、不發 `PlayerLeft`（Decision 3）。
   - **Host 自己消失**：無人執行本序列；服務端回收（Relay 每 client TTL 10 s、MPS lobby heartbeat 逾時 ≈ 132 s）。MVP 接受，見 Decision 11。

8. **Host 消失排歧（#18）與 Lobby 偵測（#25）**。Core `HostLossDisambiguator.Decide(in HostLossSignals s)` 實作 GDD 六列優先表，第一個命中即定案；輸入由轉接層採樣：MPS 事件（序 1：`Deleted`／`SessionHostChanged`／`PlayerLeaving(host)`／`PlayerHasLeft(host)`）、`IPageLifecycle.IsOnline`（序 2，`false` 才算證據）、`session.HasPlayer(session.Host)`（序 3／4）、`session.State == Disconnected` 或查詢拋錯（序 5）。三個結論（`HostGone`／`SelfOffline`／`Undetermined`）都走 Teardown，差別只在店語。若心跳空窗期間曾背景化，一律優先走 #17 的背景分流，不進本表。Lobby／Lobby\*：進入時訂閱同一組 `ISession` 事件，收到 Host 對應事件即 `HostGone`；另以 Core 計時器自最後一次 session 事件起算 `lobby_host_silence_timeout_sec`（30 s）顯示靜默提示＋離開鈕，**不等服務端**（arlong 2026-09-13 裁決）。

9. **Teardown 不變式（#17a）與離開通知（#12）**。Core 在每一條進 `Idle` 的邊上輸出**恰好一個** `Teardown` 效果（#17 的 > 5 s 分支、#18 三個結論、玩家主動離開、Onboarding 期間自身斷線）；轉接層的執行順序固定：`NetworkManager.Shutdown()`（同步、2 ms 回傳、對端 80 ms 收到）→ `session.LeaveAsync()`（client；GDD 寫的 `LeaveSessionAsync` 在 2.3.1 不存在，GDD r5 改名）或 `session.AsHost().DeleteAsync()`（Host）best-effort 不等待 → 才切 UI。⚠ 先 `Shutdown()` 再 `LeaveAsync()` 會讓 MPS 記一條警告 "Do not call NetworkManager.Shutdown when using a session. Use ISession.LeaveAsync instead."（`NetworkManagerSession.cs:424`）；`LeaveAsync()` 內的網路模組動作與已執行的 `Shutdown()` 重疊，由逐模組的 try/catch 吞掉（`SessionHandler.cs:770-781`）。**這條警告是預期的，不得為了消警告而改順序**：`Shutdown()` 同步、對端 80 ms 得知；`LeaveAsync()` 在 unload 時多半送不出去（r1 依 r2 E13）。Host 關頁：進 Lobby 時 `IUnloadNotifier.InstallLeaveBeacon(…)` 安裝離開通知；`beforeunload` 與 `pagehide` **兩者都會觸發**（相隔 1–24 ms）。**冪等在送出端做**（r1 依 r2 E7 更正：UGS Lobby 不認我們自訂的 nonce，對已刪除的 lobby 再送一次 `DELETE` 會回錯誤碼——效果冪等、回應不冪等）：`.jslib` 以單發旗標只送第一次；第二次若仍送出，其 404 視為成功。**端點**：UGS Lobby REST 的刪除／退出端點需要 `Authorization: Bearer <AccessToken>`，而 `navigator.sendBeacon` 不能帶自訂標頭，因此離開通知走 **`fetch(url, { keepalive: true, headers })`**（W1 的 `.jslib` 已有此 fallback 路徑）；ADR-0005 r1 的 `InstallLeaveBeacon` 改收 `method` 與 `headers`（V10）。這條路徑繞過 Sessions SDK、直打 UGS Lobby REST，「session id ＝ lobby id、REST 路徑、Bearer 授權」三件事都沒有編譯期保護，MPS 升版必重驗 V10。桌面：`QuitRequested` → 同一 Teardown 序列 → `CompleteQuit()`。

10. **單人練習（Solo）＝同一條 NGO 路徑，零服務依賴**（OQ#4 裁決）。`SessionMode.Solo` 時 Session 層不存在（不呼叫 `UnityServices.InitializeAsync`、不登入、不配 Relay）；Connection 層以 NGO 內建的 **`SinglePlayerTransport`**（`Unity.Netcode.Transports.SinglePlayer`，NGO 2.4.0 起）啟 `StartHost()`。r1 依 r2 E3 以它取代原稿手刻的 `OfflineTransport`：官方版由 NGO 團隊維護、隨版本演進，2.13.1 起並附官方切換範例（`Documentation~/advanced-topics/singleplayer.md`）。它只能以 Host 啟動（`StartClient()` 回 false 並報錯）；Host 本機的 approval、連線、spawn 與 RPC 本來就不經 transport（`NetworkManager.cs:1501-1537`）。
   - **兩個 transport 元件並存，只切指派**（r1 刪除原稿「兩者不得同時存在於同一個 NetworkManager」——與官方範例相反）：NetworkManager 物件上同時掛 `UnityTransport` 與 `SinglePlayerTransport`；Solo 入口在 `StartHost()` 之前把 `NetworkConfig.NetworkTransport` 指向後者，**離開 Solo（含 Lobby\* 沙盒的 `AbortSandbox`）時，在 `Shutdown()` 之後立刻指回 `UnityTransport`**。漏掉這一步，Solo 本身不會出事，出事的是下一次上線：MPS 啟網時以 `NetworkConfig.NetworkTransport as UnityTransport` 取 transport（`NetworkManagerSession.cs:66-69`），取不到就拋 `SessionException(TransportComponentMissing)`（`GameObjectsNetcodeNetworkHandler.cs:179-185`）；在成員端自動加入的路徑上，這個例外會落進「失敗不重試」，玩家只會靜靜錯過整班。
   - `SessionRoot`、approval（slot 0；`HostView.MemberIds = { 本機 PlayerId }`，見 Decision 5）、`ShiftEndTs`、Settlement 全部照常；心跳沒有 peer 就不發。`ServiceError → 放棄 → Idle` 後 Solo 仍可玩（TR-netcode-039）。
   - **Lobby\* 等待沙盒就是同一條 Solo 路徑**：MPS 成員資格保留，沙盒不共享任何狀態。前一班結束的訊號（Host 在 #23a 把 `shift_eta.phase` 改回 `Lobby`，見 Decision 5；或 session 事件）一到，Core 即輸出 `AbortSandbox` → `Shutdown()` → transport 指回 `UnityTransport` → 合流進 Lobby，可中斷、不延遲。⚠ **自動加入的競態**（r1 依 r2 E11）：若 Host 拆網後一秒內就 #26 重新啟網，兩次屬性變更可能在等待者端合併成一次通知，SDK 的自動加入撞上還在跑的沙盒 Host 而失敗，而且不重試（`NetworkModule.cs:505-541`）。緩解是 Decision 2 的復原路徑（`StartFailed` → 重新加入）；V11 量這個競態實際多常發生、復原要多久。forbidden pattern `lobby_with_live_relay` 的措辭隨之改為「不得存在 Relay allocation 或**對外的** NGO 連線（Lobby\* 的本機練習沙盒除外）」。
   - Solo 不計 Relay 額度、不受 UGS 429 影響，機台、NPC、RPC、NetworkVariable 不需要第二條程式路徑。V3 驗 WebGL IL2CPP 下的 `SinglePlayerTransport`。

11. **MVP 無 host migration（OQ#18 裁決），明文保留擴充點**。#12「房主關頁＝本局結束」不變。`ISession.SessionMigrated`、`IClientSessionNetwork.MigrationFailed` 與 `IHostSessionNetwork.MigrationFailed`（兩者皆 `:29`；r1 補 Host 側）、`NetworkState.Migrating` 在 MVP **一律映射為 `HostGone`** 走 Teardown，不得靜默忽略。日後啟用 migration 的三項前提，各自需要別的 ADR 先落地：① Host 權威狀態（NPC 狀態機、波次、計分、claim、`ShiftEndTs`）全部可序列化為 `HostMigrationData`（G2 的 spawn 契約）；② Relay 重配＋全員重連的時間預算與 Lobby\* 合流規則（本 ADR 的狀態機要加 `Migrating` 態）；③ 時鐘真相接管（新 Host 的 `HostNowMs` 基準補償，G9）。#28 已指出 migration 的一個真實用途：讓離多數玩家近的人當 Host。

12. **UTP 與 NGO 常數契約（TR-netcode-021／018）**。所有值由 `SessionConfig` 注入（ScriptableObject，自 registry 常數生成），EditMode `EngineFactProbeTests` 續用為「引擎值仍如此」的斷言，建置期斷言「專案值已套用」：

   | 欄位 | 值 | 理由 |
   |---|---|---|
   | `UnityTransport.HeartbeatTimeoutMS` | **500（不得動）** | 兼 Relay PING 間隔；> 10 s 即被 Relay 踢（`multiplayer.md:107-109`） |
   | `UnityTransport.DisconnectTimeoutMS` | 30000（維持預設） | ≥ 8 s 讓 app 心跳是先判定者（約束⑤）；調小會縮 send queue 容量 |
   | `UnityTransport.ConnectTimeoutMS` × `MaxConnectAttempts` | 1000 × **10** | 連線階段總逾時由預設 60 s 調為 10 s＝`T_spawn` 閘門，失敗即早可見（V4） |
   | `UnityTransport.MaxSendQueueSize` | 顯式設定，值由 `[P-16]`（W2）定 | 預設由 `DisconnectTimeoutMS` 推算；Host 出站 payload 上限與佇列深度監控點必備（V6） |
   | `NetworkConfig.ClientConnectionBufferTimeout` | 10（維持預設） | approval 為純函式，遠在其內 |
   | `NetworkConfig.TickRate` | 10 | ADR-0001；在連線雜湊裡，跨平台同房兩端必須一致 |
   | `NetworkConfig.EnableSceneManagement` | false | 單一場景；不一致則握手失敗 |
   | `NetworkConfig.ConnectionApproval` | true | Decision 5 |
   | 心跳／截止／寬限等 GDD 常數 | 依 Tuning Knobs | 可機械驗證的 11 條約束（①②③⑤⑥⑦⑨⑩⑪⑫⑬）以 `SessionConfig.Validate()` 檢查，非法組態在 EditMode 與建置期 fail（TR-netcode-041）。④（情境分析）、⑧（架構規則＋執行期 RTT）、⑭（AC 撰寫規則）、⑮（執行期 RTT／region 模型）不是組態不等式，交 T1／T3 與 code review（r1 依 r2 E9） |

13. **班次時鐘真相與 Session 層對外事件（TR-netcode-036／012／045）**。`SessionRoot.ShiftEndTs`（Host 寫 `NetworkVariable<long>`，單位 ms，Host 單調時鐘基準）是班次剩餘的唯一真相；`end_shift_early` 直接改寫它；所有「剩餘」的權威判定在 Host，client 的倒數是套用 offset 後的估計。對外事件採 GDD 契約表（:795-809）的名稱，C# 只改 PascalCase：`PlayerJoined(slot, playerId)`、`PlayerLeft(slot, playerId)`、`PlayerDisconnected(slot, playerId, heldItems)`（＝`PeerLost` 給 G2／ADR-0004 的面）、`OnlinePlayerCountChanged(count, graceActive, hostSolo)`、`ConnectionStateChanged(ConnectionState)`、`RoomCodeAvailable(code)`、`SessionStarted`、`RosterUpdated`、`FinalRoster`／`DisconnectLog`。`ConnectionState` 枚舉是給 UI 的**唯一**連線狀態來源，店語字串表 data-driven、禁技術詞（TR-netcode-045）。

14. **進房分段預算是 Core 的狀態計時（TR-netcode-011）**。`CreatingRoom`／`JoiningRoom` ≤ `T_lobby`（10 s），#26 轉場與 `Onboarding` 的連線階段 ≤ `T_spawn`（10 s，與 `MaxConnectAttempts` 對齊），超時→該狀態的失敗出口與店語訊息；`Booting` 的 stall 偵測（`load_stall_timeout_sec`）在 loader 層、Unity 之外（ADR-0005／Web template）。UGS 呼叫失敗的重試一律指數退避、首次 ≥ 2 s，避免 429。

### Architecture Diagram

```
                NightShift.Platform（ADR-0005）           Unity Gaming Services
   IPageLifecycle  IUnloadNotifier  ILaunchParams  IRegionSelector     MPS Sessions / Relay
         │               │              │              │                     │
         ▼               ▼              ▼              ▼                     ▼
 ┌───────────────────────────────────────────────────────────────────────────────────┐
 │  NightShift.Session.Unity（轉接層：翻譯事件、執行效果，不含決策）                   │
 │   SessionServices ──── ISession / IHostSession（建房、加入、Start/StopNetwork、     │
 │                        RemovePlayerAsync、事件訂閱、property 預檢）                 │
 │   NgoBridge ────────── NetworkManager（ConnectionApprovalCallback、Connected／      │
 │                        DisconnectCallback、OnTransportFailure、Shutdown）           │
 │   SessionRoot ──────── NetworkBehaviour：Roster NV、ShiftEndTs NV、Heartbeat RPC    │
 │   DisconnectSequencer  依優先序呼叫 IDisconnectParticipant（ADR-0001／G2／ADR-0004）│
 │   TransportSwitch ──── Solo／沙盒：SinglePlayerTransport ⇄ UnityTransport（只切指派）│
 └───────────────▲───────────────────────────────────────────────┬───────────────────┘
                 │ SessionEvent（含 nowMs、slot，不含 clientId）     │ SessionEffect[]
 ┌───────────────┴───────────────────────────────────────────────▼───────────────────┐
 │  NightShift.Session.Core（純 C#，noEngineReferences = true）                       │
 │   SessionMachine ── 12 態 × 32 列守衛表（適用性矩陣；列分本機／peer 主詞）          │
 │   SlotTable ─────── PlayerId ↔ slot ↔ clientId（clientId 只在 SlotOf()/ClientOf()）  │
 │   ApprovalGate ──── 版本閘 → 成員 → 重複 → 截止 → 空位                              │
 │   HeartbeatMonitor  seq／lastPeerSeqSeen／逾時／單向失效／RTT／offset                │
 │   HostLossDisambiguator  六列優先表                                                  │
 │   SessionConfig ─── 常數＋約束①–⑮ Validate()                                        │
 └─────────────────────────────────────────────────────────────────────────────────────┘
                 ▲ EditMode 測試（fake clock，無 NGO、無 UGS）
   NightShift.Identity（零依賴）：PeerKind／PeerKey／PlayerSlot／NpcId ← Session.Core、Movement.Core、Interaction.Core 共用

 時間軸（兩層壽命）：
   MPS session   ├── CreatingRoom/JoiningRoom ── Lobby ── InShift ── Settlement ── Lobby ── … ──┤ DeleteAsync
   Relay + NGO                                 ├ #26 Start ─────────── #23a Stop ┤   ├ Start ───
   心跳                                              ├ Onboarding ── InShift ── Settlement ┤
```

### Key Interfaces

以下為 C# 9（Unity 6.3，無 file-scoped namespace）。命名依專案慣例：RPC 以 `Rpc` 結尾、`NetworkVariable` 為 PascalCase 名詞、查詢介面 `I` 開頭、常數 snake_case 帶單位。簽章中引擎型別的確切名稱以 V9 核對結果為準。

```csharp
namespace NightShift.Identity
{
    // 獨立組件：asmdef noEngineReferences = true、不引用任何組件（r1 依 r2 §3B Resolution 1）。
    // 契約由本 ADR Decision 4 裁決；Session.Core、Movement.Core（ADR-0001）、Interaction.Core（ADR-0002）都只引用本組件。

    public enum PeerKind : byte { Player = 0, Npc = 1 }

    /// <summary>所有遊戲系統的「誰」鍵。玩家 Index＝slot，NPC Index＝npcId（[0, NpcId.Max)）。</summary>
    public readonly struct PeerKey : System.IEquatable<PeerKey>
    {
        public readonly PeerKind Kind;
        public readonly byte Index;
        public PeerKey(PeerKind kind, byte index) { Kind = kind; Index = index; }
        public static PeerKey Player(byte slot) { return new PeerKey(PeerKind.Player, slot); }
        public static PeerKey Npc(byte npcId) { return new PeerKey(PeerKind.Npc, npcId); }
        public bool Equals(PeerKey o) { return Kind == o.Kind && Index == o.Index; }
        public override bool Equals(object o) { return o is PeerKey k && Equals(k); }
        public override int GetHashCode() { return ((int)Kind << 8) | Index; }
    }

    public static class PlayerSlot
    {
        public const byte NoSlot = byte.MaxValue;   // 未知／無人；machine GDD C20 的 NoSlot = 255（r1：原稿把常數寫在 namespace 層級，C# 不允許，CS0116）
        public const int Capacity = 4;              // 容器按 4 設計；MVP max_players = 2
    }

    public static class NpcId
    {
        public const int Max = 64;                  // npcId ∈ [0, Max)；值域歸本 ADR，ADR-0003 的 PassThroughNpcMask 寬度由此推導並靜態斷言
    }
}

namespace NightShift.Session.Core
{
    using NightShift.Identity;

    /// <summary>Host 端逐 slot 追蹤的 peer 階段；適用性矩陣中主詞為 peer 的列讀它（Decision 3）。</summary>
    public enum PeerPhase : byte { Onboarding, InShift, Settlement }

    /// <summary>Host 端真相；每班次重建。clientId 只在 SlotOf/ClientOf 兩個邊界查詢出現。</summary>
    public sealed class SlotTable
    {
        public SlotTable(int maxPlayers);                       // 容量固定 PlayerSlot.Capacity，MVP 只用 2
        public bool TryAssign(string playerId, ulong clientId, long nowMs, out byte slot);   // 最小空位；不設指派冷卻（r1 依 r2 E10）
        public bool Release(byte slot, long nowMs);             // #24 第 4 步；同時清掉 clientId 對照，之後 SlotOf(舊 clientId) 回 NoSlot
        public byte SlotOf(ulong clientId);                     // PlayerSlot.NoSlot 表示未知 → 轉接層丟棄該 RPC／回呼
        public byte SlotOf(string playerId);
        public ulong ClientOf(byte slot);
        public bool IsOnline(byte slot);
        public PeerPhase PhaseOf(byte slot);                    // r1：approval 時 Onboarding → PlayerJoined 時 InShift → Settlement
        public int OnlineCount { get; }                         // = online_player_count
        public int OfflineCountOf(string playerId);             // #15a，班次範圍
    }

    public enum JoinRejectReason : byte   // r1 依 r2 X4 改名：ADR-0002 的 NightShift.Interaction.Core.RejectReason 是互動層拒絕，同名不同義
    {
        Ok = 0, StaleBuild, NotAMember, Duplicate, LateJoinCutoff, Full
    }

    public readonly struct ApprovalRequest
    {
        public readonly byte PayloadVersion;
        public readonly ushort ProtocolVersion;
        public readonly uint BuildId;
        public readonly string PlayerId;
        public readonly ulong ClientId;                         // 只用來回填 SlotTable，Core 決策不讀它
    }

    public readonly struct ApprovalVerdict
    {
        public readonly JoinRejectReason Reason;                // Ok 即核准
        public readonly byte Slot;                              // Ok 時有效
    }

    public static class ApprovalGate
    {
        public const ushort ProtocolVersion = 1;                // 任何 RPC／NV 佈局變更即 +1
        public static ApprovalVerdict Evaluate(in ApprovalRequest req, in HostView host, SlotTable slots, SessionConfig cfg);
        // HostView = { long NowMs; long ShiftEndTsMs; bool InSettlement; uint BuildId; IReadOnlyCollection<string> MemberIds }
        // MemberIds：Online＝session.Players；Solo 與 Lobby* 沙盒＝{ 本機 PlayerId }（r1，Decision 5「Host 自核准」）
    }

    /// <summary>邏輯 20 bytes（r1 更正原寫的 16）。前三欄＝GDD #20 定案；HostNowMs 為 offset 公式的 host_value。
    /// 純 BCL：不能當 RPC 參數（ILPP 會拒），轉接層以 HeartbeatWire 逐欄序列化（Decision 6）。</summary>
    public readonly struct HeartbeatPayload : System.IEquatable<HeartbeatPayload>
    {
        public readonly ushort Seq;
        public readonly ushort LastPeerSeqSeen;
        public readonly long HostShiftEndTsMs;
        public readonly long HostNowMs;
        public HeartbeatPayload(ushort seq, ushort lastPeerSeqSeen, long hostShiftEndTsMs, long hostNowMs)
        { Seq = seq; LastPeerSeqSeen = lastPeerSeqSeen; HostShiftEndTsMs = hostShiftEndTsMs; HostNowMs = hostNowMs; }
        public bool Equals(HeartbeatPayload o)
        { return Seq == o.Seq && LastPeerSeqSeen == o.LastPeerSeqSeen && HostShiftEndTsMs == o.HostShiftEndTsMs && HostNowMs == o.HostNowMs; }
    }

    public enum PeerLostCause : byte { HeartbeatTimeout, OneWayLoss, TransportDisconnect, LeaveRequested }

    public sealed class HeartbeatMonitor
    {
        public HeartbeatMonitor(SessionConfig cfg);
        public void OnConnected(byte slot, long nowMs);
        public void OnReceived(byte slot, in HeartbeatPayload p, long nowMs);
        public bool TryNextSend(byte slot, long nowMs, out HeartbeatPayload p);   // 每 heartbeat_interval_sec 一拍
        public bool TryDetectLoss(long nowMs, out byte slot, out PeerLostCause cause);
        public double RttMs(byte slot);                        // client 端：對 Host 的 RTT；HUD ping 同源
        public double ClockOffsetMs { get; }                   // client 端：EMA 平滑後的 offset
    }

    public enum HostLossVerdict : byte { HostGone, SelfOffline, Undetermined }

    public readonly struct HostLossSignals
    {
        public readonly bool HostLeaveEventSeen;    // 序 1：Deleted／SessionHostChanged／PlayerLeaving(host)／PlayerHasLeft(host)
        public readonly bool IsOnline;              // 序 2：false 才是證據
        public readonly bool? HostStillMember;      // 序 3／4：session 層可達時 HasPlayer(Host)；不可達為 null
        public readonly bool SessionLayerReachable; // 序 5
    }

    public static class HostLossDisambiguator
    {
        public static HostLossVerdict Decide(in HostLossSignals s);
    }

    public enum SessionPhase : byte   // r1 依 r2 X4 改名：SessionState 是 MPS 的型別（None／Connected／Disconnected／Deleted）
    {
        Booting, LoadFailed, Idle, ServiceError, CreatingRoom, JoiningRoom,
        Lobby, LobbyWaiting, Onboarding, InShift, Disconnected, Settlement
    }

    public enum SessionMode : byte { Online, Solo }

    /// <summary>純狀態機：Step 吃一個事件、回傳零到多個效果；所有時間由事件攜帶的 nowMs 提供。</summary>
    public sealed class SessionMachine
    {
        public SessionMachine(SessionConfig cfg, SessionMode mode, bool isHost);
        public SessionPhase Phase { get; }
        public int Step(in SessionEvent e, System.Span<SessionEffect> effectsOut);   // 零配置
    }
}
```

```csharp
namespace NightShift.Session.Unity
{
    /// <summary>Host 擁有、啟網後第一個 Spawn；壽命＝班次。Solo 模式亦存在。</summary>
    public sealed class SessionRoot : NetworkBehaviour
    {
        // 兩個 Host 寫、全員讀的真相；建構子預設即 Server 寫權，不需也不得改 Owner
        public readonly NetworkVariable<RosterState> Roster = new NetworkVariable<RosterState>();
        public readonly NetworkVariable<long> ShiftEndTs = new NetworkVariable<long>();

        [Rpc(SendTo.Server, Delivery = RpcDelivery.Unreliable)]
        public void HeartbeatToHostRpc(HeartbeatWire p, RpcParams rp = default);   // 轉接層先 SlotOf(rp.Receive.SenderClientId)

        [Rpc(SendTo.SpecifiedInParams, Delivery = RpcDelivery.Unreliable)]
        public void HeartbeatToClientRpc(HeartbeatWire p, RpcParams rp);           // RpcTarget.Single(clientId, RpcTargetUse.Temp)
    }

    /// <summary>心跳的線上格式：逐欄序列化，20 bytes，與 struct 佈局無關（r1 依 r2 E8；不用 ForceNetworkSerializeByMemcpy 的理由見 Decision 6）。</summary>
    public struct HeartbeatWire : INetworkSerializable
    {
        public ushort Seq, LastPeerSeqSeen;
        public long HostShiftEndTsMs, HostNowMs;
        public void NetworkSerialize<T>(BufferSerializer<T> s) where T : IReaderWriter
        {
            s.SerializeValue(ref Seq); s.SerializeValue(ref LastPeerSeqSeen);
            s.SerializeValue(ref HostShiftEndTsMs); s.SerializeValue(ref HostNowMs);
        }
        public static HeartbeatWire From(in HeartbeatPayload p);
        public HeartbeatPayload ToCore();
    }

    /// <summary>固定 4 格；INetworkSerializable ＋ IEquatable（缺後者 NGO 每幀誤判 dirty）。</summary>
    public struct RosterState : INetworkSerializable, System.IEquatable<RosterState>
    {
        public RosterEntry S0, S1, S2, S3;
        public RosterEntry this[byte slot] { get; }
    }

    public struct RosterEntry : INetworkSerializable, System.IEquatable<RosterEntry>
    {
        public FixedString64Bytes PlayerId;   // 28 字元匿名 id；FixedString32Bytes 上限 29 太貼邊
        public ulong ClientId;                // 只供轉接層回查，Core 不讀
        public bool Online;
        public int JoinedTick;
    }

    /// <summary>#24 固定順序的參與者；Priority 常數見 Decision 7 的表。</summary>
    public interface IDisconnectParticipant
    {
        int Priority { get; }
        void OnPeerLost(in PeerLostContext ctx);   // ctx = { byte Slot; string PlayerId; PeerLostCause Cause; PeerPhase Phase; long NowMs }（r1：Phase 供 Onboarding 期間斷線分流）
    }

    /// <summary>Solo／Lobby* 沙盒的 transport 切換（r1 依 r2 E3：改用 NGO 內建 SinglePlayerTransport，刪除手刻的 OfflineTransport）。
    /// 兩個元件並存於 NetworkManager 物件，只切 NetworkConfig.NetworkTransport 的指派。</summary>
    public static class TransportSwitch
    {
        public static void UseSinglePlayer(NetworkManager nm);    // StartHost() 之前
        public static void UseUnityTransport(NetworkManager nm);  // Shutdown() 之後、任何 MPS 網路呼叫之前；MPS 以 `as UnityTransport` 取用，漏掉即 TransportComponentMissing
    }
}
```

**Approval payload 佈局**（`NetworkConfig.ConnectionData`，little-endian）：`[0] PayloadVersion=1`、`[1..2] ProtocolVersion`、`[3..6] BuildId`、`[7] PlayerId 長度 n ≤ 64`、`[8..8+n) PlayerId UTF-8`。總長 ≤ 72 bytes。

**離開通知**（`fetch keepalive`，經 ADR-0005 r1 的 `IUnloadNotifier.InstallLeaveBeacon(url, method, headers, body)`）：Host → `DELETE lobbies/{id}`；client → `DELETE lobbies/{id}/players/{playerId}`；皆帶 `Authorization: Bearer <AccessToken>`、無 body。去重在送出端（`.jslib` 單發旗標），第二次若仍送出，其 404 視為成功（Decision 9；r1 依 r2 E7 刪除原稿的服務端 nonce 去重）。

## Alternatives Considered

### Alternative 1: NetworkBehaviour 為中心的 ConnectionManager（Boss Room 式）
- **Description**：一個 `ConnectionManager : MonoBehaviour` 直接訂閱 `NetworkManager` 與 `ISession` 事件，以 Unity 物件持有狀態與計時器；狀態轉移寫在回呼裡。
- **Pros**：樣板直接、程式碼最少；Boss Room v3.0.0 已遷移到 MPS Sessions，可照抄。
- **Cons**：心跳逾時、排歧表、截止閘門、slot 回收都要在 NGO 連線存在時才測得到；32 × 11 的守衛表沒有任何自動化可以逐格斷言；與 ADR-0001 的分層紀律相反。Boss Room 無 WebGL 支援，照抄的部分正是背景分頁與關分頁最不同的部分。
- **Rejection Reason**：TR-netcode-044 要求 EditMode 純邏輯測試覆蓋心跳／排歧／世代；W1 已證明「對一個沒人跑過的系統的斷言」只能靠儀器反駁，而儀器必須在沒有 NGO 時也能跑。

### Alternative 2: Distributed Authority 拓撲
- **Description**：改用 NGO 的 DA session（Unity 雲端的 DA 服務），每個 client 對自己 spawn 的物件有權威；host 消失由服務端處理。
- **Pros**：有官方 Web 支援與 quickstart；天生免 host migration 痛點；NetworkVariable 預設 owner 寫。
- **Cons**：authority 心智模型與本專案 Core Rule #1（Host 權威）相反——客人 NPC、波次、計分都得重新設計誰擁有；綁 Unity 雲（DA 服務），免費額度另計；2–4 人、容忍 300 ms 的本作用不到它的好處；W1 的 20 條假設全部要重驗。
- **Rejection Reason**：GDD 已否決，但依 review 要求以本 ADR 記為**正式 plan B**（Decision 1），觸發條件明文。

### Alternative 3: Lobby 階段即建 Relay／NGO（`WithRelayNetwork()` 便利路徑）
- **Description**：建 session 時就 `WithRelayNetwork()`，Relay 與 NGO 從 Lobby 活到拆房；一個狀態機、無局間 teardown。
- **Pros**：一次呼叫；開始上班不需等 allocation（省 1–3 s）；W1 第 3 批證明背景分頁只節流到 1 Hz，Relay PING 照送，Lobby 不會因切分頁被踢。
- **Cons**：Lobby 多一層會逾時的即時連線（Relay 10 s TTL 在行動瀏覽器仍未驗，OQ#10）；局間「再開一班」沒有乾淨的語意邊界，第二班的 roster／NV 殘留要靠手動清；Lobby 期間就占 Relay 連線分鐘。
- **Rejection Reason**：GDD #23／#23a 已裁決延後建連；#23c 把它從「必需」降為「好設計」，但它仍是較單純的狀態與較低的資源占用，且重建成本（≈ WSS handshake）已入 `T_spawn` 預算並以世界語言遮蔽。

### Alternative 4: 自架 headless 伺服器＋wss 反代
- **Description**：自租機器跑 Unity headless（或純 C# server），nginx／caddy 終結 wss 反代；不用 Relay、不用 MPS。
- **Pros**：不受 Relay 額度與 UGS 限流影響；server 權威天然、無 host 消失問題。
- **Cons**：維運、憑證、區域部署全是一人團隊的成本；Multiplay Hosting 已自 6.3 移除，沒有託管捷徑；房間碼、roster 要自建。
- **Rejection Reason**：免費額度對 2–4 人派對遊戲≈每月數千場，商業化前碰不到帳單；列為第二退路。

### Alternative 5: 以 NGO `clientId` 為玩家身份、重連時用 `PlayerId` 查舊 clientId 轉換
- **Description**：維持 ADR-0002 的 `ClaimedBy: ulong`，加一張 `PlayerId → 歷史 clientId` 表，重連時把舊 clientId 的條目改寫到新 clientId。
- **Pros**：三份既有 ADR 不用改鍵。
- **Cons**：每個消費者都要知道「clientId 可能換號」並訂閱改寫事件；`OwnerClientId` 不保證連續、Host 恆 0，`PassThroughPlayerMask` 的位元無法用 clientId 索引；改寫窗口內的 RPC 會帶舊 id。
- **Rejection Reason**：review C1 指出 slot 指派／回收系統「一定存在但不在任何 ADR 裡」；把它寫出來（Decision 4）比在每個消費者補洞便宜，且遮罩位元本來就只能是 slot。

## Consequences

### Positive
- 四份 ADR 的隱含前提變成一份可治理的決策；G2、ADR-0004、G8、G9 有了明確的上游。
- 玩家身份只有一種鍵（slot），clientId 不再漏進遊戲邏輯；重連換號的孤兒回收有唯一時刻（`PlayerLeft(slot)`）。
- 心跳、排歧、閘門、slot 回收全部可在 EditMode 以 fake clock 走完 GDD 的時間算術 AC，不必開 NGO。
- Solo 與 Online 共用同一條 NGO 路徑，機台／NPC／互動不需第二套程式碼，`ServiceError` 時仍可玩。
- Lobby 零 Relay 流量；局間 teardown 有 API 對應（`StopNetworkAsync`）與實測證據。

### Negative
- 多一個 Core 組件與一組事件／效果型別；轉接層要為每個引擎回呼寫翻譯，初期比直接在回呼裡寫邏輯多約一倍的檔案數。
- ADR-0001／0002／0003 各需一次 r1 改鍵（`PeerKey`、`ClaimedBy`）；ADR-0005 r1（與本 ADR r1 成對）改 `InstallLeaveBeacon` 簽章與 `ILaunchParams.RoomCode` 的 referrer 來源。
- avatar 設 `DontDestroyWithOwner = true` 換來序列的定序權，代價是 Host 端短暫的 ownership 回呼窗口（Decision 7 前提 2）：avatar 上的元件多一條「不以 ownership 變化觸發副作用」的紀律。
- 多一個零依賴組件 `NightShift.Identity`（四個型別），換掉一條潛在的 ADR 依賴環。
- 「開始上班」要付一次 Relay allocation＋WSS handshake（第二班起每次都付）；已入 `T_spawn`。
- MVP 無 migration：Host 關頁全員散場，這是明示給玩家的限制。

### Risks
- **V1／V11 自動加入失敗不重試**：自動啟網的機制已由原始碼證實（r2），風險變成「失敗了不會再試」。`StartFailed` → 重新加入的復原路徑（Decision 2／10）要在 W2 第一批就驗，否則等待者會靜靜錯過整班；復原的成本（約一次加入）要對照 `T_spawn` 預算。
- **V2 拒絕原因送不到遠端**：原始碼已證實送得到（r2），T1 (h) 實跑一次即結案。若實跑不符，版本閘照樣成立（連線不會建立），只是店語退化為通用的「加入失敗」；AC54 不受影響，AC5／AC35 的鑑別靠 client 端預檢補。
- **Host 自己的 approval 拒絕會被 NGO 強制核准**：`NetworkManager.HostServerInitialize` 對 Host 本機 client（clientId 0）的拒絕只記一行警告 "You cannot decline the host connection. The connection was automatically approved." 就照樣核准，而且照 `response.CreatePlayerObject` 決定建不建 avatar（`NetworkManager.cs:1510-1516`）。`ApprovalGate` 若在 slot 0 的路徑有 bug，**不會失敗出聲**，而是靜默進場、`SlotTable` 沒有 slot 0、Host 沒有 avatar；原稿在 Solo 與 Lobby\* 沙盒下的第 2 項就會這樣必拒（r2 E2）。緩解見 Decision 5「Host 自核准」的三道防線。這與 ADR-0001 `enableOverlapRecovery`、ADR-0003 建構子參數同屬「預設行為悄悄生效、沒有錯誤訊息」。
- **V3 `SinglePlayerTransport` 在 WebGL 失敗**：退路是 Solo 改走 Relay 單人房（Alternative 列為 Decision 10 的次選），代價是 Solo 依賴 UGS；此時 `ServiceError → Solo 仍可玩` 不成立，GDD States 表需改。
- **V10 keepalive fetch 被 CORS 或 token 過期擋下**：Host 關頁退化為 132 s 的服務端路徑，但 #25 的 30 s 本地靜默提示已保底，支柱 5 不破；client 關頁退化為 Host 心跳路徑 8 s。
- **斷線掉落依賴訊息到達序**（只在 G2 選 Decision 7 前提 3 的 (b) 時存在）：NGO 2.13.2 把所有 reliable 訊息放進同一條 `ReliableFragmentedSequenced`，原始碼自註這是暫時做法；哪天升版改掉，client 上的道具會重新跟著 avatar 消失，T1 (i′) 會紅燈。選 (a) client 端自救就不依賴它——這是推薦 (a) 的理由。
- **UGS 429**：建房／加入的重試退避已寫入 Decision 14；測試基建不得並行建多個 session。
- **行動瀏覽器**（OQ#10／#13）：背景回收與 context loss 未驗；行動端為次要目標，MVP 不承諾。
- **n=1 的數字**：87 s 與 1.14 s 皆單次樣本（UGS 限流），但與 12 s／30 s 紅線的差距遠大於合理變異；ADR 的決策不依賴其精確值，只依賴「傳輸層救不了、心跳與主動通知是唯一快路徑」這個量級結論。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| netcode-session.md | TR-netcode-001 Host 權威（NPC／波次／計分／時鐘／道具／結算） | Decision 1 正式裁決 client-server＋client-as-host；Decision 13 `ShiftEndTs` Host 寫 |
| netcode-session.md | TR-netcode-008 截止閘門唯一執行點＝`ConnectionApprovalCallback` | Decision 5 判定順序第 4 項；預檢非權威 |
| netcode-session.md | TR-netcode-009 approval payload 帶版本、不符即拒 | Decision 5 payload 佈局與第 1 項；`ProtocolVersion` 常數 |
| netcode-session.md | TR-netcode-011 進房分段預算各自硬閘門 | Decision 14 狀態計時；Decision 12 `MaxConnectAttempts = 10` |
| netcode-session.md | TR-netcode-012 離線立即重取樣、grace／`host_solo`、#15a 以 `PlayerId` | Decision 7 第 7 步；Decision 4 `OfflineCountOf(playerId)` |
| netcode-session.md | TR-netcode-015 Host 消失排歧（兩層獨立） | Decision 8 `HostLossDisambiguator` 六列表 |
| netcode-session.md | TR-netcode-017 心跳 2 s／8 s、payload、雙向存活、offset | Decision 6 全條（payload 20 bytes、`HeartbeatWire` 逐欄序列化） |
| netcode-session.md | TR-netcode-018 send queue 溢位防護 | Decision 12 `MaxSendQueueSize` 顯式＋監控點（V6） |
| netcode-session.md | TR-netcode-019 Lobby 延後建連、局間 teardown | Decision 2 兩層壽命；V1 |
| netcode-session.md | TR-netcode-021 UTP 常數契約、連線總逾時調小 | Decision 12 表 |
| netcode-session.md | TR-netcode-024 MPS 成員唯一寫入者＝Host；兩個人數不同 | Decision 7 第 6 步；`SlotTable.OnlineCount` 與 `session.PlayerCount` 分離 |
| netcode-session.md | TR-netcode-025 Lobby Host 離開＝事件＋30 s 本地靜默 | Decision 8 末段 |
| netcode-session.md | TR-netcode-028 12 態＋適用性矩陣；Lobby\* 合流；Host 獨留不結束 | Decision 3 守衛表（32 列 × 11 欄、列分本機／peer 主詞、Onboarding 期間斷線的回收路徑）；Decision 10 沙盒；Decision 7 不結束 session |
| netcode-session.md | TR-netcode-035 重連身分 `PlayerId↔slot`，ClientId 會變 | Decision 4 identity 契約 |
| netcode-session.md | TR-netcode-036 班次時鐘真相＝Host `shift_end_ts` NV | Decision 13 |
| netcode-session.md | TR-netcode-039 UGS 失敗→ServiceError；單人不經 UGS | Decision 10 Solo 零服務依賴（`SinglePlayerTransport`）；Decision 5 Host 自核准 |
| netcode-session.md | TR-netcode-040 plan B | Decision 1 兩條退路與觸發條件 |
| netcode-session.md | TR-netcode-041 常數 data-driven、約束可機械驗證 | Decision 12 `SessionConfig.Validate()`（可機械驗證的 11 條約束） |
| netcode-session.md | TR-netcode-044 EditMode 純邏輯／PlayMode 多實例／Release 實機分層 | Decision 3 Core 組件；Validation Criteria |
| netcode-session.md | TR-netcode-045 `connection_state` 店語表 | Decision 13 `ConnectionState` 唯一來源 |
| netcode-session.md | TR-netcode-010 Host 關頁＝局終；`pagehide`＋`beforeunload` 離開通知（r1 補列） | Decision 9（送出端去重、keepalive fetch＋headers）；Decision 11 無 migration |
| netcode-session.md | TR-netcode-013 `visibilitychange` 背景分流（r1 補列） | **部分**：> 5 s 分支是 Decision 9 的 Teardown 邊；≤ 5 s 的公式③ catch-up 歸 G9 |
| netcode-session.md | TR-netcode-014 teardown 不變式（r1 補列） | Decision 9：每條進 `Idle` 的邊恰好一個 `Teardown`，順序固定；MPS 的 Shutdown 警告是預期的 |
| netcode-session.md | TR-netcode-023 道具 `DontDestroyWithOwner`、Host 自行 unparent（r1 補列） | **部分**：Decision 7 前提 1–3（avatar 也須 `DontDestroyWithOwner = true`、道具在 client 上存活的契約）；掉落與 despawn 的實作歸 G2 |
| netcode-session.md | TR-netcode-031 單一場景、不啟用 `NetworkSceneManager`（r1 補列） | **部分**：Decision 1 `EnableSceneManagement = false`；Decision 4 依賴更衣室 3.0 s；「同步未完仍進場」的 runtime 規則無 ADR |
| netcode-session.md | TR-netcode-046 沒有 NGO 連線的端也能顯示班次剩餘時間、不依賴心跳 offset（r1 補列） | Decision 5 `shift_eta`（發布當下的相對量，收到時以本機時鐘錨定） |
| game-concept-night-shift.md | TR-concept-009 房間碼進房、大廳、斷線重連走 MPS Sessions | Decision 2；Decision 4 MVP 重連＝新加入 |
| game-concept-night-shift.md | TR-concept-010 斷線基本保障（偵測、掉落、解鎖、降載） | Decision 6 偵測；Decision 7 序列（掉落／解鎖歸 G2／ADR-0004） |
| game-concept-night-shift.md | TR-concept-012 NGO client-server＋Relay＋Sessions、client-hosted | Decision 1 |
| systems-index.md | TR-index-021 撲空對稱（房主永不撲空） | 本 ADR 只提供數字：Host 自身 RPC 走 `LocalSendRpcTarget` 零往返，同區單程 ≈ 44–47 ms（p95 94.5／2）；`host_claim_delay_ms` 的裁決歸 ADR-0004（review :174） |
| systems-index.md | TR-index-022 claim 租約續期、到期只釋放 claim | Decision 7 第 3 步只釋放 claim（C10）；租約語意歸 ADR-0004 |
| machine-interaction.md | C10 斷線只放 claim；C20 RPC 契約 | Decision 7 參與者邊界；Decision 4 `PeerKey` 供 C20 簽章 |
| game-concept-night-shift.md | TR-concept-002 2–4 人（MVP 2）、連續值班（r1 補列） | Constraints `max_players`（容器按 4）；Decision 2 session 跨班次存活 |
| game-concept-night-shift.md | TR-concept-007 波次導演＋遊戲時鐘（r1 補列） | **部分**：Decision 13 時鐘真相與複製；波次導演與 #9 遊戲時鐘無 ADR |
| machine-interaction.md | TR-machine-001 `ClaimState.ClaimedBy` 的型別（r1 補列） | Decision 4：`byte` slot，`PlayerSlot.NoSlot`＝無人 |
| machine-interaction.md | TR-machine-019 強制釋放只放 claim（r1 補列） | **部分**：Decision 7 第 3 步（斷線路徑）；其餘觸發源歸 ADR-0004 |
| machine-interaction.md | TR-machine-045 時基與班次結束（r1 補列） | **部分**：Decision 13 `ShiftEndTs`；`ServerTime.Tick` 時基與「班次結束拒收站台 RPC」歸 G9／ADR-0004 |
| machine-interaction.md | TR-machine-049 斷線實走保險絲、判定後 ≤ 2 s（r1 補列） | Decision 6 心跳 8 s 判定；Decision 7 判定後 ≤ 2 s 跑完全序列；Host 自身消失不跑序列 |
| product-database.md | TR-product-026 兩端 SKU 表一致性的版本 token（r1 補列） | **部分**：Decision 5 `BuildId` 為內容雜湊、不符即 `StaleBuild`；雜湊輸入須含 `ProductCatalogAsset`，由 G4 定 |

## Performance Implications
- **CPU**：Core 每事件 O(1)（固定 4 slot 陣列）；approval 純函式 µs 級；心跳每端每 2 s 一次序列化。Lobby 期間零 NGO 工作。
- **Memory**：`SlotTable`／`RosterState` 固定大小（4 × ≈ 80 B）；`SessionEffect` 以 `Span` 回傳零配置；無 `NetworkList`。
- **Load Time**：#26 多一次 Relay allocation＋WSS handshake（同區實測 RTT ≈ 90 ms 量級，allocation 以秒計），已入 `T_spawn ≤ 10 s`；Lobby 不預熱 Relay 是刻意的。
- **Network**：心跳 4 peer × 0.5 Hz × ≈ 40 B（含標頭）≈ 160 B/s 上行，可忽略；`Roster`／`ShiftEndTs` 只在變更時同步；離開通知一次 ≤ 1 KB。Host 上行上限與佇列監控待 `[P-16]`（OQ#12 粗估 15–25 KB/s，遠低於 3 GiB/CCU 免費額度）。

## Migration Plan
1. **從 W1 搬進 `src/`**：`ApprovalCallbackTests` 的 approval 註冊寫法、Relay WSS helper（已由 ADR-0005 收編）、`EngineFactProbeTests`（續用為常數契約的斷言）、`.jslib` 的 `pagehide`／`beforeunload` keepalive 路徑（經 ADR-0005 介面）。W1 的 `DiscRoleTests`／`TwoProcessRoleTests` 改寫為 PlayMode 多實例測試樣板。
2. **新寫**：`NightShift.Identity`（`PeerKind`、`PeerKey`、`PlayerSlot`、`NpcId`；零依賴）；`NightShift.Session.Core`（`SessionMachine`、`SlotTable`、`ApprovalGate`、`HeartbeatMonitor`、`HostLossDisambiguator`、`SessionConfig`）與 EditMode 測試；`NightShift.Session.Unity`（`SessionServices`、`NgoBridge`、`SessionRoot`、`HeartbeatWire`、`DisconnectSequencer`、`TransportSwitch`）。
3. **既有 ADR 的 r1 義務**（本 ADR Accepted 後）：
   - **ADR-0001**：`CapsuleGhost.Id`／`PairKey` 改 `PeerKey`（引用 `NightShift.Identity`）；轉接層提供 `FreezeInput` 參與者；avatar 元件在 `OnNetworkSpawn()` 快取「是否為本機玩家」，`OnGainedOwnership`／`OnOwnershipChanged` 不做輸入、攝影機、HUD 綁定（Decision 7 前提 2）。
   - **ADR-0002**：`ClaimState.ClaimedBy` 與 `InteractValidator.Validate(…, ulong requester, …)` 都改為 `byte` slot（r1 補列後者）；`SlotOf` 回 `NoSlot` 的請求在轉接層丟棄。
   - **ADR-0003**：`PairKey` 改 `PeerKey`；遮罩由擁有者端消費 `PlayerLeft(slot)` 清位元；Constraints「狀態實例以玩家 id 為鍵，不以 slot 為鍵（AC19）」與 GDD 對照表的 AC19 列改為以 `PeerKey` 為鍵（r1 補列）；:95 的保護改述為「`PlayerJoined(s)` 晚於 `PlayerLeft(s)` ≥ 3.0 s」——avatar 的 `NetworkObject` 在 approval 當下就存在；`PassThroughNpcMask` 的寬度改由 `NpcId.Max` 推導並靜態斷言。
   - **ADR-0005**（與本 ADR r1 成對）：`InstallLeaveBeacon` 改收 `method`／`headers`（keepalive fetch）並在送出端單發去重；`ILaunchParams.RoomCode` 在 Web 以 `document.referrer` 解析（`[P-4]`）；`IUnloadNotifier` 同時掛 `pagehide`；Depends On ADR-0001 改為 Related。
4. **GDD r5 回填**：`netcode-session.md` #20 心跳 payload 補 `host_now_ms`（:379、:865）；#17a／#12／#24a 的 `LeaveSessionAsync` 改為 SDK 實名 `LeaveAsync`（:206、:275、:609）；#24a 補「NGO approval 二次驗證 `PlayerId` 必為 MPS 成員」；OQ#4／OQ#18 標記已裁決並指回本 ADR；`max_players` 的型別註記「容器按 4 設計、MVP 值 2」。`machine-interaction.md` C20 資料契約表（:268）`ClaimState.ClaimedBy` 由 `ulong` 改為 `byte`（slot，`NoSlot = 255`）。**r1 補列**：`netcode-session.md` #24 前置條件（:580-592）補「avatar prefab 也須 `DontDestroyWithOwner = true`，且掉落的道具在每個 client 上都必須存活」；#9 預檢（:161）與 Lobby\* 約束 (c)（:776）改讀 `shift_eta`；:379 心跳 payload 改 20 bytes；:794 輸入訊號表改為 `pagehide`＋keepalive fetch；:801 `InteractResult`、:807 `RequestHandoff` 的玩家鍵改 slot；適用性矩陣加「主詞」欄並收斂 peer 主詞列的 Disc 欄。`first-person-controller.md` :397-399「以玩家 id 為鍵、不以 slot 為鍵」改為「以 `PeerKey` 為鍵；`PlayerLeft(slot)` 時清除該 slot 的一切條目」，AC19 改名為「slot 重用不繼承」（THEN 子句不變）。
5. **registry**（r1 同步，見 `docs/registry/architecture.yaml`）：`solo_offline_transport` 改為 `SinglePlayerTransport`；`session_heartbeat` 的 16 bytes 改 20 bytes、RPC 參數型別改 `HeartbeatWire`；`session_events.consumers` 移除 customer-system 那一行（遮罩由擁有者端清）；`player_identity_key` 補 `NightShift.Identity` 與 `NpcId.Max` 的歸屬；`approval_payload` 的 `RejectReason` 改 `JoinRejectReason`；`disconnect_sequence` 補 `DisconnectTransport = 45` 與 `PeerLostContext.Phase`；`shift_end_ts` 補「沒有 NGO 連線的端改讀 `shift_eta`」；`lobby_with_live_relay` 措辭補「對外」與 Lobby\* 沙盒例外；新增 forbidden pattern `avatar_destroyed_with_owner`、`avatar_ownership_callback_side_effects`；新增 api_decision `lobby_rest_leave_notification`。

## Validation Criteria
- **T0 EditMode（純 C#，fake clock）**：(a) 適用性矩陣 32 列 × 11 欄逐格測試，peer 主詞列以 `PeerPhase` 驅動；(b) `ApprovalGate` 六條判定順序與 AC54（版本不符不得產生任何 `Approve`）、AC5／AC35（`late_join_cutoff_sec` 端點 30.0 s 鎖、29.5 s 過）、**Host 本機請求（clientId 0、自己的 `PlayerId`）在 Online（Lobby 剛啟網）、Solo（`SoloLocalPlayerId`）、Lobby\* 沙盒三種 `HostView` 下都永不被拒**（NGO 會靜默強制核准、且照 `CreatePlayerObject` 決定建不建 avatar，見 Decision 5）；(c) `HeartbeatMonitor`：8.0 s 判、7.9 s 不判（AC27／AC44）、單向失效在 4 拍落後時觸發、offset 收斂 ≤ 100 ms；轉接層的 `HeartbeatWire` 以 `FastBufferWriter` 序列化恰為 20 bytes 且往返等值（EditMode，引用 NGO 但不需連線）；(d) `HostLossDisambiguator` 六列全部可達、矛盾走 `Undetermined`；(e) `SlotTable`：回收後可立即重派同 slot（無指派冷卻），但 `PlayerLeft(s)` 必先於同 slot 的下一個 `PlayerJoined(s)`、間隔 ≥ 定長過場下限 3.0 s；回收後 `SlotOf(舊 clientId)` 回 `NoSlot`；Onboarding 期間斷線不發 `PlayerLeft`、不計 #15a；#15a 第 2 次離線不給寬限（AC50）；(f) `SessionConfig.Validate()` 對 11 條可機械驗證約束（①②③⑤⑥⑦⑨⑩⑪⑫⑬）的非法組態 fail。
- **T1 PlayMode 多實例（Editor 兩進程，Relay WSS）**：(g) Lobby 期間無 `NetworkManager` 連線、#26 後 `IsListening`、#23a 後 `NetworkState.Stopped` 且 MPS 的 `SessionState.Connected`（AC52）；(h) 遠端 client 被 `StaleBuild` 拒絕時 Host 端零 RPC／NV 收發（AC54）、client 端讀到 `Reason`（V2）；(i) client `kill -9` 後 Host 於 ≤ 12 s 完成 #24 全序列且 `RemovePlayerAsync` 成功、同帳號重新加入不撞 `Full`（AC6b／AC33／AC36／AC53）；(i′) client 手持道具時斷線——`Shutdown()`（走 `OnClientDisconnectCallback`）與 `kill -9`（走心跳）各一次——每個留守 client 在 2 s 內看到道具落在 Host 的落地座標，Host 與各 client 的道具 `NetworkObjectId` 集合一致（AC10／AC14；V12），且 Host 的本機輸入與攝影機在斷線瞬間不受影響（Decision 7 前提 2）；(i″) 以阻斷單向流量觸發心跳判定後，該 client 退出 `ConnectedClientsIds`，其後送到的 RPC 不進 Core（Decision 7 第 5a 步）；(j) Host `kill -9` 後 client 於 ≤ 12 s 顯示 `HostGone` 並 teardown（AC6b／AC28）；(k) Solo：`SinglePlayerTransport` 下 `StartHost`、`SessionRoot` spawn、approval slot 0、Host 有 avatar、Settlement 可達；離開 Solo 後指回 `UnityTransport`、隨即建房啟網成功（V3）；(k′) Lobby\* 沙盒進行中，Host 拆網後一秒內重新啟網，等待者最終進入新班次——自動加入或經 `StartFailed` 復原（V11）。
- **T1-Web Release（IL2CPP＋Stripping High＋Gzip，Playwright）**：(l) Host 關分頁 → 其他成員 ≤ 1.14 s 量級收到 `Deleted`，瀏覽器只發出一筆 `DELETE`（送出端去重）（AC6c；V10）；(m) client 關分頁 → Host 心跳路徑 ≤ 8 s（AC16 退化版）；(n) 背景分頁 30 s／120 s 在 Lobby 不掉房（AC34a／b）、InShift 背景 5.1 s 走 teardown、4.9 s 走 catch-up（AC29）。
- **決策正確的量化標準**：Host 消失全員得知 ≤ `session_end_worstcase_sec` 12 s（取代 87 s）；Lobby 內 Host 優雅離開 ≤ 2 s；版本不符的 client 連線期間 Host 收到的 NetworkVariable delta 數＝0；重連後 `PairMachine`／遮罩中以舊身份殘留的條目數＝0；client 斷線後，Host 與每個 client 的道具 `NetworkObjectId` 集合差＝0。

## Related Decisions
- ADR-0001 純 C# 移動求解器（分層紀律、`TickRate = 10`、`AuthorityMode = Owner`、Decision 9 `adoptInput`）
- ADR-0002 互動驗證只驗水平（`RequestInteractRpc`、`RpcTarget.Single`、`ClaimState`、`claim_lock_timeout_sec` 保險絲）
- ADR-0003 膠囊與 PassThrough 查詢（遮罩 bit＝slot、3.0 s 地板、`npc_id_reuse_cooldown_sec`、`ChangeOwnership` 不清 NV）
- ADR-0005 平台抽象層（`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector`、Relay WSS helper）
- 待寫：G2 `network-object-lifecycle-ownership`、ADR-0004 `machine-interaction-core`、G8 延遲模型、G9 遊戲時鐘、未來「傳輸協定與混房」ADR、Alpha 的 Steam 整合 ADR
- `design/gdd/netcode-session.md`（r4，2026-09-13）；`design/gdd/machine-interaction.md`（r1，C10／C20）；`docs/architecture/architecture-review-2026-10-01.md`（G1、C1）；`docs/architecture/architecture-review-2026-10-01-r2.md`（§3B、§3C，r1 的修訂依據）
- `prototypes/w1-netcode/README.md`（W1 實測紀錄，`.claude/rules/prototype-code.md` 指定的權威來源）；`docs/research/steam-feasibility-2026-10-01.md`

## r1 修訂紀錄（2026-10-03）

依 `architecture-review-2026-10-01-r2.md` 修訂。每一條修法都回到 NGO 2.13.2／MPS 2.3.1 原始碼核對過（`prototypes/w1-netcode/Library/PackageCache/`）。

| r2 編號 | 嚴重度 | 修訂 | 位置 |
|---|---|---|---|
| E1 | 🔴 必修 | avatar 也須 `DontDestroyWithOwner = true`；掉落的道具在每個 client 上必須存活，只寫 NV 不夠；兩條可行路由交 G2，推薦 client 端自救 | Decision 7 前提 1、3；V12；T1 (i′) |
| E2 | 🔴 必修 | Solo／沙盒的 `HostView.MemberIds = { 本機 PlayerId }`；三道防線 | Decision 5「Host 自核准」；Decision 10；T0 (b) |
| E6 | 🟡 必修 | 新增第 5a 步 `DisconnectTransport = 45`（非空 reason）；`NoSlot` 的 RPC 與回呼一律丟棄 | Decision 7 表；Decision 4 |
| E8 | 🟡 必修 | Core `HeartbeatPayload`（純 BCL）＋轉接層 `HeartbeatWire : INetworkSerializable`；20 bytes | Decision 6；Key Interfaces |
| E4 | 🟡 應修 | 矩陣 32 × 11；列分本機／peer 主詞；Onboarding 期間斷線的回收路徑 | Decision 3；T0 (a)、(e) |
| E5 | 🟡 應修 | session property 改發 `shift_eta`（發布當下的相對量），收到時以本機時鐘錨定 | Decision 5；TR-netcode-046 |
| E3 | LOW | 改用 NGO 內建 `SinglePlayerTransport`；兩個 transport 並存、只切指派 | Decision 10；Key Interfaces `TransportSwitch` |
| E7 | LOW | 冪等改在送出端（`.jslib` 單發旗標、404 視為成功） | Decision 9；離開通知段 |
| E9 | LOW | `Validate()` 只涵蓋 11 條可機械驗證的約束 | Decision 12；T0 (f) |
| E10 | LOW | 刪除 slot 指派冷卻；3.0 s 間隔改述為結構性 | Decision 4；T0 (e) |
| E11 | LOW-MEDIUM | 自動加入失敗不重試 → `StartFailed` 復原；沙盒收場訊號；forbidden pattern 措辭 | Decision 2、10；V11；T1 (k′) |
| E12 | LOW | GDD 對照表補 13 列；`NoSlot` 移入 `PlayerSlot`；`RelayNetworkOptions` 行號；Host 側 `MigrationFailed` | 各處 |
| E13 | NOTE | MPS 對 `Shutdown()` 的警告是預期的，順序不改 | Decision 9 |
| X1 | 傳播 | Migration 3 補 ADR-0002 `Validate` 的 `ulong`、ADR-0003 Constraints 與 AC19 列、FPC :397-399 與 AC19 | Migration Plan 3、4 |
| X4 | LOW | `SessionState` → `SessionPhase`；`RejectReason` → `JoinRejectReason` | Decision 3、5；Key Interfaces |
| X5 | LOW | 遮罩由擁有者端清，Host 不得代清；registry 消費者修正 | Decision 4；registry |
| §3B | 依賴環 | NPC id 值域歸本 ADR；`PeerKey` 等移到零依賴的 `NightShift.Identity`；Accept 順序 | Decision 4；ADR Dependencies |

**r1 核對原始碼時新發現、r2 沒寫到的四件事**：
1. 被拒的 Host 不只沒有 slot 0，連 avatar 都沒有——NGO 強制核准時照 `response.CreatePlayerObject` 建物件（`NetworkManager.cs:1516`）。
2. avatar 改 `DontDestroyWithOwner = true` 之後，Host 端那具 avatar 會短暫 `IsOwner`／`IsLocalPlayer` 皆為 true，並觸發 ownership 回呼（`NetworkSpawnManager.cs:457-467`、`NetworkObject.cs:1232,1237`）→ Decision 7 前提 2。
3. 用 NetworkVariable 傳掉落，一定晚於 despawn（NV 到下一個 tick 才送）；而 client 端的 `OnNetworkDespawn()` 先於 GameObject 銷毀，可以就地自救 → Decision 7 前提 3 (a)。
4. 離開 Solo 時沒把 transport 指回 `UnityTransport`，下一次上線 MPS 會拋 `TransportComponentMissing`；在自動加入路徑上，它會變成靜默錯過整班 → Decision 10。

**偏離 r2 建議之處**：
- E8：r2 建議 `ForceNetworkSerializeByMemcpy<HeartbeatPayload>`；r1 改採 `INetworkSerializable` 包裝。理由見 Decision 6：memcpy 的線上格式綁定原生佈局，與 ADR-0005 的跨平台同房方向相衝。
- E1：r2 列的兩條路（同幀先送 RPC、或改 parent sync）都保留給 G2，但 r1 推薦第三條「client 端 `OnNetworkDespawn()` 自救」，因為它不依賴 NGO 自己標為暫時的佇列映射。
- arlong 2026-10-03 裁示：兩處皆採 r1 寫法（E8 用 `INetworkSerializable` 包裝）。

**不在 r1 範圍**（已登記，待各自的 ADR 或文件處理）：`BuildId` 的雜湊輸入須含 `ProductCatalogAsset`（G4）；`modules/multiplayer.md` 的四處缺口（`SinglePlayerTransport`、成員端自動加入、`Shutdown()` 警告、房間碼範例用了 `WithRelayNetwork()`）；GDD r5 的回填項（Migration Plan 4）。
