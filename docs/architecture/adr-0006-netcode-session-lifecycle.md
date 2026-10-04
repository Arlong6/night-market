# ADR-0006: 連線會談生命週期——兩層會談、一台純 C# 狀態機、slot 是玩家身份

## Status
Proposed

## Date
2026-10-01（r1：2026-10-03，依 `architecture-review-2026-10-01-r2.md` §3B、§3C 修訂；**r2：2026-10-03，依 `architecture-review-2026-10-03-r3.md` 修訂，與 ADR-0005 r2 成對**；逐條對照見文末「r1 修訂紀錄」與「r2 修訂紀錄」）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6.3 LTS（6000.3.24f1）、IL2CPP＋Managed Stripping High、NGO 2.13.2、Multiplayer Services 2.3.1、UTP 2.7.4（實機解析值，NGO 相依宣告寫 2.6.0） |
| **Domain** | Networking（Foundation：拓撲、Session 生命週期、連線健康、identity 契約） |
| **Knowledge Risk** | HIGH——NGO 2.x、MPS Sessions API、UTP 2.7 皆在模型訓練資料之後；本 ADR 只採用 engine-reference 與 W1 原型已查證的 API，未查證者全部列入 Verification Required |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`；`modules/multiplayer.md`（:14-20 套件版本、:22-36 NGO 2.x 差異、:63-95 ownership 與斷線處置、:97-113 逾時常數、:115-122 Relay TTL、:124-140 房間碼流程、:142-148 Web 組態、:158-165 建議架構）；`breaking-changes.md`（:40-42 `NetworkTransform.Update`、Multiplay Hosting 移除）；`deprecated-apis.md`（:16-18 `[Rpc]`、MPS Sessions）；`design/gdd/netcode-session.md`（Core Rules #8–#28 :140-702、適用性矩陣 :704-745、States :746-776、Interactions :778-883、Tuning Knobs :1173-1294、`[P]` 表 :1544-1640、OQ :1641-）；`design/gdd/machine-interaction.md`（C10、C20）；`design/gdd/game-concept-night-shift.md`；`docs/architecture/architecture-review-2026-10-01.md`（§2 G1 :38-44、§3 C1 :116-122、§6 :281）；`prototypes/w1-netcode/README.md`（:132-149 RTT、:306-307 雙重 unload 事件、:320-332 優雅／強制終止、:347-358 關分頁）與測試 `ApprovalCallbackTests.cs`、`DiscRoleTests.cs`、`TwoProcessRoleTests.cs`、`RttRoleTests.cs`、`OwnershipRoleTests.cs`、`EngineFactProbeTests.cs`；ADR-0001／0002／0003／0005；**r1 新增**：`docs/architecture/architecture-review-2026-10-01-r2.md`（§3B、§3C E1–E13、§5），以及 NGO 2.13.2／MPS 2.3.1 原始碼（`prototypes/w1-netcode/Library/PackageCache/`）——NGO：`NetworkConnectionManager.cs`、`NetworkSpawnManager.cs`、`NetworkObject.cs`、`NetworkBehaviour.cs`、`NetworkBehaviourUpdater.cs`、`MessageDelivery.cs`、`NetworkManager.cs`、`ForceNetworkSerializeByMemcpy.cs`、`Editor/CodeGen/NetworkBehaviourILPP.cs`、`Transports/SinglePlayer/SinglePlayerTransport.cs`、`Documentation~/advanced-topics/singleplayer.md`；MPS：`NetworkModule.cs`、`NetworkManagerSession.cs`、`GameObjectsNetcodeNetworkHandler.cs`、`RelayNetworkOptions.cs`、`IHostSessionNetwork.cs`、`IClientSessionNetwork.cs`；**r2 新增**：`docs/architecture/architecture-review-2026-10-03-r3.md`（§3A–§4、§6）；MPS：`SessionManager.cs`、`SessionHandler.cs`、`NetworkModule.cs`（兩條自動加入路徑）、`INetworkHandler.cs`、`NetworkConfiguration.cs`、`GameObjectsNetcodeNetworkHandler.cs`、`NetworkManagerSession.cs`、`SessionOptionsExtensions.cs`、`LobbyHandler.cs`、`Lobbies/SDK/InternalLobbyService.cs`、`Lobbies/SDK/WrappedLobbyService.cs`、`Lobbies/Apis/LobbyApiRequests.cs`、`Lobbies/SDK/LobbyCacher/LobbyCacher.cs`；Authentication：`AuthenticationServiceInternal.cs`；NGO：`ConnectionRequestMessage.cs`、`NetworkConfig.cs`、`RpcAttributes.cs`、`ProxyMessage.cs`、`ConnectionApprovedMessage.cs`、`UnityTransport.cs`；Collections：`FixedString.gen.cs`；UGS 文件 Create a lobby（私人 lobby 可以碼加入）；HTML 規範 §7.3.1.6／§7.4.2.4／§7.5.9（關閉時 beforeunload → pagehide 的順序）；web.dev「Back/forward cache」 |
| **Post-Cutoff APIs Used** | ① **MPS 2.3.1 Sessions**：`MultiplayerService.Instance.CreateSessionAsync` ／ `JoinSessionByCodeAsync`、`SessionOptions.WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS })`（只設定不啟動）、`IHostSession.Network.StartRelayNetworkAsync(RelayNetworkOptions)` ／ `StopNetworkAsync()`、`ISession` 事件 `Deleted`／`SessionHostChanged`／`PlayerLeaving`／`PlayerHasLeft`／`PlayerJoined`／`RemovedFromSession`／`SessionMigrated`／`StateChanged`、`ISession.Host`／`HasPlayer`／`Players`／`PlayerCount`／`State`／`Code`／`CurrentPlayer.Id`、`IHostSession.RemovePlayerAsync`／`DeleteAsync`（W1 第 1 批編譯＋runtime 驗證，`[P-10]`；2026-10-01 unity-specialist 原始碼複核：`SessionHandler.cs:65,191,481`、`IHostSessionNetwork.cs:69,94`）、`ISession.LeaveAsync()`（`Unity.Services.Multiplayer.api:1241`；**2.3.1 沒有 `LeaveSessionAsync`**，`NetworkManagerSession.cs:424` 明寫 "Use ISession.LeaveAsync instead"）、`RelayNetworkOptions(string region = null, bool preserveRegion = false)`（`RelayNetworkOptions.cs:163-167`；三個帶 `RelayProtocol` 的建構子皆 `[Obsolete]`，`:57,:87,:121`——r1 更正，原引 :258／:288／:322 有誤）、`SessionProperty(string value, VisibilityPropertyOptions, PropertyIndex)`（`SessionProperty.cs:6-35`）與 `event Action SessionPropertiesChanged`（`SessionHandler.cs:272`）；`ISession.ReconnectAsync()` 存在但未演練；**r1 新增**：`IClientSessionNetwork.StartFailed`（`IClientSessionNetwork.cs:19`）、`IHostSessionNetwork.MigrationFailed` 與 `IClientSessionNetwork.MigrationFailed`（皆 `:29`）、成員端自動加入網路（`NetworkModule.cs:113-123,505-541`） ② **NGO 2.13.2**：`ConnectionApprovalCallback` 在 Sessions 啟網下照常觸發、`ConnectionData` payload 完整（`[P-17]`，`ApprovalCallbackTests.cs:66,82,104-107`）；`RpcAttribute.Delivery`（`RpcAttributes.cs:88`，unreliable 上限 1296 bytes，`NetworkBehaviour.cs:372`）；`SendTo.SpecifiedInParams`＋`RpcTarget.Single(ulong, RpcTargetUse)`（`RpcTarget.cs:79,95-101,257`）；`NetworkManager.Shutdown()` 只設旗標、實際拆除在 PostLateUpdate（`NetworkManager.cs:1590-1604,509-520`；呼叫本身 2 ms、對端 80 ms 收到，`[P-15]`——r2 更正：不是同步完成）；`NetworkTransport` 抽象成員（`NetworkTransport.cs:11-112`，為 `MonoBehaviour` 子類）與 `StartHost()` 只呼叫 `StartServer()`、本機 client 全程在行程內（`NetworkManager.cs:1446,1474`）；`NetworkManager.DisconnectReason`（`NetworkManager.cs:659`）與 `DisconnectReasonMessage`（`DisconnectReasonMessage.cs:1-62`）；**r1 新增**：`NetworkManager.DisconnectClient(ulong, string)`（`NetworkManager.cs:1570,1578`；非空 reason 先送原因、延後斷線，`NetworkConnectionManager.cs:917-931`）、`NetworkObject.DontDestroyWithOwner` 的斷線處置分支（`NetworkConnectionManager.cs:1366-1420`）、`Unity.Netcode.Transports.SinglePlayer.SinglePlayerTransport`（NGO 2.4.0 起內建，只能以 Host 啟動）③ **UTP 2.7.4**：`DisconnectTimeoutMS`／`HeartbeatTimeoutMS`／`ConnectTimeoutMS`／`MaxConnectAttempts`（`EngineFactProbeTests.cs` 8/8、`multiplayer.md:98-104`）；`NetworkConfig` 預設值 `TickRate=30`／`ClientConnectionBufferTimeout=10`／`ConnectionApproval=false`／`EnableSceneManagement=true`（`NetworkConfig.cs:53,71,77,109`）④ `AuthenticationService.Instance.PlayerId` ≡ `session.CurrentPlayer.Id`（`[P-2b]` 實測，兩個獨立 session 同值）⑤ **r2 新增**：MPS `INetworkHandler`（`StartAsync(NetworkConfiguration)`／`StopAsync()`，`INetworkHandler.cs:14-40`）、`WithNetworkHandler<T>(INetworkHandler)`（`SessionOptionsExtensions.cs:205-210`，約束 `BaseSessionOptions`，建房與加入都能帶）、`NetworkConfiguration.Role`／`RelayServerData`、`IHostSessionNetwork.NetworkHandler`／`IClientSessionNetwork.NetworkHandler`（public get／set；setter 只在模組 `State == Stopped` 時可用，否則 throw `InvalidOperation`，`NetworkModule.cs:83-97`）、`SessionOptions.IsPrivate`；NGO `NetworkManager.OnServerStarted`、`OnServerStopped(bool)`、`OnClientStopped(bool)`、`ShutdownInProgress`（`NetworkManager.cs:861,903,925,931`；`OnStopped` 是 **internal**，`:937`）、`NetworkManager.OnConnectionEvent`（`PeerConnected`／`PeerDisconnected`；2.13.2 **沒有**公開的 `OnPeerDisconnectedCallback`）、`NetworkObject.SpawnAsPlayerObject(ulong)`（`NetworkObject.cs:2103`）、`RpcAttribute.InvokePermission`＋`RpcInvokePermission { Everyone, Server, Owner }`（`RpcAttributes.cs:24-40`；`RequireOwnership` 已 `[Obsolete]`）、`NetworkConfig.GetConfig(bool)`（`NetworkConfig.cs:328-366`）、`NetworkVariable<T>.Reset(T)`；Authentication `AccessToken`（公開 getter，續發後立即回新值）與 `Expired` 事件 |
| **Verification Required** | **V1**（r2 改寫）NGO 啟停一律經轉接層自有的 `SessionNetworkHandler`（Decision 2）。原始碼已證實：MPS 對每個 session 一律建網路模組（`MultiplayerInitializer.cs:104-118`、`SessionManager.cs:288-309`）；client 的兩條自動加入路徑（初始化路徑 `NetworkModule.cs:113-124`；屬性變更路徑 `:505-561`）都只經 `INetworkHandler.StartAsync`；handler 正常返回就不會觸發 SDK 的 leave（`SessionManager.cs:311-347` 只在例外時清理）。待實跑：handler 在 WebGL IL2CPP＋Stripping High 下的行為；建房與加入後斷言 `session.Network.NetworkHandler == h`——`ProcessOptions` 會吞掉例外、只記一行 LogError 就繼續，呼叫端拿不到例外，handler 退回預設（`SessionManager.cs:390-397`）——退回就等於回到 FV-1 ｜ **V2** approval 拒絕原因在遠端 client 可讀：原始碼已證實（拒絕先送 `DisconnectReasonMessage` 再延後斷線，`NetworkConnectionManager.cs:886-889,917-927`；`ServerDisconnectReason` 只在下一次 Initialize 清空，`:1651-1652`）。T1 (h) 在 Relay WSS 上實跑一次，斷言字串恰等於 `JoinRejectReason` 的列舉名 ｜ **V3** `SinglePlayerTransport` 在 WebGL IL2CPP 下 `StartHost()` 成功、本機 RPC／NV 路徑正常；在 `OnServerStopped` 指回 `UnityTransport` 後 MPS 啟網成功（Decision 10）｜ **V4** `MaxConnectAttempts = 10` 後連線階段 10 s 內失敗可見，且不影響 Relay 路徑成功率 ｜ **V5** 心跳 `RpcDelivery.Unreliable` 在 WSS 下的到達間隔分布（`[P-11]`，W2）｜ **V6** send queue 深度監控點與 `MaxSendQueueSize` 定值（`[P-16]`，W2）｜ **V7** 行動瀏覽器 `visibilitychange` 與 WebGL context loss（OQ#10／#13，W2）｜ **V8** Post-MVP slot 保留與 `ReconnectAsync`（`[P-2a]`，W2）。⚠ r2：`ReconnectAsync` 重建 options 時只帶 handler、不帶 `NetworkOptions`（`SessionManager.cs:209-232`），協定會落回 `RelayProtocol.Default`（桌面為 DTLS），啟用前必須另解 ｜ ~~**V9**~~ **結案**（r1 原始碼核對：`UnityTransport.MaxSendQueueSize` 存在，預設 0 時由 `DisconnectTimeoutMS` 推算，`UnityTransport.cs:142,154-157`；`RosterState`／`RosterEntry` 的 `INetworkSerializable`＋`IEquatable` 組合合規，`NetworkBehaviourILPP.cs:359-372`）｜ **V10**（r2 改寫）離開通知以 `fetch keepalive` 帶 `Authorization: Bearer`，自 itch.io 跨源 iframe 在 `pagehide` 內送達 UGS Lobby REST。已知兩件事：UGS 對 `Origin: https://html-classic.itch.zone` 的 preflight 回 204、`Access-Control-Allow-Origin: *`、允許 `DELETE` 與 `authorization`、`Max-Age 600`（2026-10-03 實測，未帶憑證）；WPT `fetch/api/redirect/redirect-keepalive.any.html` 的「cross-origin redirect＋preflight」子測試（在巢狀 iframe 的 unload 處理器裡送出，接著關閉視窗）在 Chrome 154、Firefox 157、Safari 27 的 stable 版全數通過。後者是強旁證，但形狀不同（GET＋自訂標頭、`window.close()`）。待實測：三引擎在使用者關分頁時是否真的送達，以及最舊支援版本（Firefox ≥ 133 才有 keepalive；Safari 的下限查不到）。`[P-18]` 量的是同源 `sendBeacon`，**不能代證**這條路徑。這條路徑繞過 Sessions SDK，MPS 升版必重驗 ｜ **V11**（r2 改寫）班次交界的屬性合併：client 若把 #23a 的「移除網路屬性」與 #26 的「新值」合併成一次變更，而模組 State 仍是 `Started`，新值會被靜默吃掉（`NetworkModule.cs:510-521,537-549`），等待者錯過整班。合併的主要來源是 client 自己任何一次帶回較新版本的 REST 回應（`WrappedLobbyService.cs:846-858`、`LobbyCacher.cs:97-105`），以及 Wire 缺號後的補抓。實測時注入兩種情境：「班次交界時 client 寫 player data」與「丟掉一筆 Wire 訊息」，量看門狗（Decision 2）多久把等待者帶進新班，並據此定出 `min_lobby_dwell_ms` ｜ **V12** client 斷線時手上的道具在每個留守 client 上都存活，並收斂到 Host 的落地座標；`OnClientDisconnectCallback` 與心跳兩種觸發源都要測；**至少 3 個實例**（Host＋2 個 client；2 人房斷線後沒有留守 client 可斷言，r3 GF-7）｜ **V13**（r2 新增）中途加入且已過截止：handler 的 `StartAsync` 確實被呼叫（證明自訂 handler 已套上）、回報 `Rejected(LateJoinCutoff)`；`JoinSessionByCodeAsync` 正常回傳；玩家仍是 MPS 成員，並在 `LobbyWaiting` 停留 ≥ 150 s（大於 W1 實測的 lobby 回收時間 132.61 s，留約 15% 餘量，`w1-p14-out/result.txt`）；停留期間看門狗零觸發；下一班自動合流。原始碼已排除一條機制：MPS 2.3.1 從不把 `AllocationId` 送上 Lobby（`SavePlayerDataAsync` 只送 `Data`，`SessionHandler.cs:942-964`；`LobbyConverter.ToLobbyPlayer(Player)` 沒有呼叫者，`:43-58`），所以 Lobby↔Relay 的斷線連動不會因為那筆已斷線的 join allocation 而移出成員；服務端是否另有因「沒有 NGO 連線」而移除成員的機制，原始碼回答不了 ｜ **V14**（r2 新增）avatar 延後 spawn（Decision 7 前提 4）：3 個實例下，T1、T2、`LeaveRequested` 三種觸發源各跑一次，記錄留守 client 上 avatar `OnNetworkDespawn`、`PeerDisconnected`、`Roster.OnValueChanged` 的實際順序；另驗晚加入者看得到既有 avatar，而且 `Slot` NV 在 `OnNetworkSpawn` 時已是正確值 ｜ **V15**（r2 新增）UGS 的實際回應：對已移除的成員再 `RemovePlayer`、對已刪的房再 `DeleteLobby`，記錄狀態碼與 problem+json 的 `code`（預期 404＋16002／16001；原始碼只有 SDK 設計上的旁證）；順手解碼 JWT，記錄 token 實際效期 `exp − iat` ｜ **V16**（r2 新增）同帳號雙開：第二個分頁以碼加入時是否得到 `SessionConflict`（`WrappedLobbyService.cs:205-235,720-739`）。這決定 `Duplicate` 是否真的走得到 approval |
## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005（Proposed）——`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector` 是本 ADR 的平台輸入（r2 依 r3 CX-9 刪去 `IClipboard`：它的消費者是大廳 UI，不是本 ADR）。ADR-0005 Decision 6 的 WSS 規則由本 ADR `SessionServices` 唯一的 options 工廠套用；`SessionNetworkHandler` 也由同一個工廠掛上，不經 ADR-0005（`NightShift.Platform` 不引用 Netcode 與 MPS，Decision 2）。實際依賴的是 ADR-0005 **r2**：`InstallLeaveBeacon(url, method, authorization)`、`SetLeaveConfirmation(bool)`、`RestoredFromBackForwardCache`、組合根 `PlatformComposition.Create()`。兩者須成對 Accept。本 ADR **不依賴** ADR-0003：NPC id 值域由本 ADR 擁有（Decision 4） |
| **Enables** | G2「同步物件生命週期與所有權轉移」（以本 ADR 的 `PeerLost` 序列與 slot 鍵為前提）；ADR-0004 機台互動組 Core（`PeerKey`、`PlayerDisconnected` 事件、`host_claim_delay_ms` 所需的延遲數字）；ADR-0001／0002／0003 r1（引用 Decision 4 identity 契約）；G8 延遲模型；G9 遊戲時鐘（`ShiftEndTs` 真相在本 ADR）；`NightShift.Identity` 組件（`PeerKey`／`PlayerSlot`／`NpcId`，零依賴，Decision 4）；G2 的 avatar 延後 spawn 契約（`SpawnAvatar(slot, playerId)`，Decision 7 前提 4，r2） |
| **Blocks** | #1 Session／房間系統與 #2 網路同步層的全部 story；任何呼叫 `MultiplayerService`、`NetworkManager.StartHost`／`StartClient`、`ConnectionApprovalCallback` 的程式碼 |
| **Ordering Note** | **Accept 順序（r2 依 r3 §4A）**：ADR-0005 r2＋本 ADR r2（成對）→ ADR-0001 r1 → ADR-0002 r1、ADR-0003 r1 → G2 → ADR-0004。ADR-0001 因此不再是最先可 Accept 的那份：先 Accept 0001 r0 再改鍵，#3 的 story 會先以 `string Id` 寫下去。**依賴環的拆法**：ADR-0001 r1 一引用 `PeerKey` 就依賴本 ADR，而本 ADR 依賴 ADR-0005；ADR-0005 r1 因此把對 ADR-0001 的依賴改為 Related——它依賴的是 registry 的全專案禁用模式 `movement_logic_outside_core`，不是 ADR-0001 的決策輸出——否則成環 0001→0006→0005→0001。ADR-0001／0002／0003 的 r1 在本 ADR Accepted 後進行；在那之前，三份 ADR 的 Key Interfaces 視為「邊界轉換待補」而非衝突。**`NetworkConfig.TickRate` 由本 ADR 擁有**（r2 依 r3 CX-4；registry 本來就登記在 `session_topology`）：ADR-0001 r1 改為引用。否則 ADR-0001 r1 一宣告 Depends On 本 ADR，本 ADR 正文再回指 ADR-0001 的 TickRate，就形成 0001↔0006 兩點環 |

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
| `beforeunload`＋`pagehide` → `sendBeacon` | 瀏覽器 | 伺服器端實收 | 8/8 試驗、16/16 送達（含 itch.io iframe 父頁關閉） | `[P-18]`（同源 `sendBeacon`；只證明事件會觸發，不能代證 Decision 9 的跨源 `DELETE`，r2） |
| 同區 RTT（`asia-northeast1`） | NGO named message | — | median 88.8／p95 94.5 ms | `README.md:144`、`[P-3]` |

### Constraints
- **Web 是 MVP 唯一平台**：WSS 之下是單一 TCP；背景分頁節流到 1 Hz（W1 第 3 批，六分半鐘未凍結）；`ReconnectionTimeoutMS` 只支援 DTLS，**WSS 沒有傳輸層自動重連**（`multiplayer.md:110-111`）。
- **Relay 每 client 連線 TTL 10 s**（host 無 peer 時 60 s），由 NGO 每 `HeartbeatTimeoutMS`＝500 ms 的 PING 重置；該常數兼 UTP heartbeat，**不得調動**（`multiplayer.md:107-109,115-122`）。
- **支柱硬標**：開連結就開玩 ≤ 60 s（`join_time_budget_sec`，分段 `T_load`／`T_lobby`／`T_spawn`＝25／10／10）；沒有人在等（純看戲 > 30 s 就重做）。
- **`max_players`**：MVP build＝2，VS 起＝4；型別與容器一律按 4 設計。
- **既有登記立場**：`NetworkConfig.TickRate = 10`（本 ADR 擁有，registry `session_topology`；r2 依 r3 CX-4）；Relay 協定所有平台顯式 WSS、共用 helper（ADR-0005 Decision 6）；平台能力只經 `NightShift.Platform` 介面（ADR-0005）；`movement_logic_outside_core` 的分層紀律（ADR-0001）；狀態真相走 NetworkVariable、RPC 只驅動表現層（ADR-0002／0003）。
- **UGS 限流**：快速重試 create／join 會被 429 且誤報為 `SessionException: lobby not found`（`w1-disc-client-kill.log:701-1491`）。
- **SDK 會替我們做決定**（r3 §4 指出的新模式）：MPS 在模組初始化失敗時自動 leave、NGO 的設定雜湊搶在 approval 之前擋人、`Shutdown()` 延後執行、IL2CPP 剝除沒人引用的組件。r2 的每一條時序都沿 SDK 的實際呼叫鏈寫，並附行號。
- **一人團隊**：型別要少，fake 要便宜；所有決策邏輯必須在沒有 NGO、沒有 UGS 的 EditMode 裡測得到（TR-netcode-044）。
- **範圍邊界**：物件 spawn／despawn／ownership 轉移歸 G2；機台 claim 清理語意歸 ADR-0004（C10 已裁決「斷線只放 claim」）；DTLS 混房歸未來傳輸協定 ADR；Steam 歸 Alpha 的 Steam 整合 ADR。本 ADR 對它們只提供**事件與鍵**。

### Requirements
- **R1** 正式裁決拓撲，並以 ADR 記錄 plan B（TR-concept-012、TR-netcode-040）。
- **R2** Session 層（MPS）與 Connection 層（Relay＋NGO）壽命獨立：Lobby 只有 MPS；#26 才啟網；#23a 局間拆回 MPS-only（TR-netcode-019）。
- **R3** 狀態機與 GDD States 表逐態相同、適用性矩陣逐格可斷言，且為純 C#（TR-netcode-028／044）。
- **R4** 拒絕發生在任何資料交換之前，分兩層：NGO 連線設定雜湊是引擎層硬閘，在前，原因字串是通用的；approval 閘門是截止與版本閘唯一的**決策**閘，在後，給 `JoinRejectReason`。被拒的中途加入者仍是 MPS 成員（Lobby\*）（TR-netcode-008／009；r2 依 r3 EA-2、FV-1 改寫）。
- **R5** 心跳 2 s／8 s 自 NGO 連線起、雙向存活確認、單向失效走斷線序列、offset 與 ping 同源（TR-netcode-017）。
- **R6** Host 是 MPS 成員唯一寫入者；斷線處置有固定順序與 2 s 上限；本 ADR 不定義 claim／物件的清理語意（TR-netcode-024、C10）。
- **R7** Host 消失排歧、Lobby 的 Host 離開偵測、teardown 不變式（TR-netcode-015／025）。
- **R8** identity 契約：`PlayerId↔slot↔clientId`、slot 指派與回收、重連穩定性、NPC id 值域與 `CapsuleGhost.Id` 的關係（TR-netcode-035、review C1）。
- **R9** UTP／NGO 常數契約與 send queue 溢位防護（TR-netcode-021／018）。
- **R10** 班次時鐘真相、ServiceError 與單人模式不經 UGS、常數 data-driven 可機械驗證、`connection_state` 店語表（TR-netcode-036／039／041／045）。
- **R11** 進房分段預算各自為硬閘門；離線立即重取樣與旗標（TR-netcode-011／012）。

## Decision

1. **拓撲正式裁決**。NGO 2.13.2 **client-server** 拓撲、**client-as-host**（Host＝權威＋本機玩家，`clientId = 0`）、**MPS 2.3.1 Sessions** 管房間碼／roster／成員資格、**Relay WSS** 為唯一傳輸（ADR-0005 Decision 6），`NetworkConfig.TickRate = 10`（本 ADR 擁有，ADR-0001 r1 引用）、`EnableSceneManagement = false`（兩端必須一致，否則握手失敗 "Scene Hash … does not exist"，`README.md:182-183`）、`ConnectionApproval = true`、`PlayerPrefab = null`（avatar 由轉接層在 `PlayerJoined` 時 `SpawnAsPlayerObject`，Decision 7 前提 4）、`ProtocolVersion = 0`（與 `ApprovalGate.ProtocolVersion` 是兩回事，Decision 5）、`ForceSamePrefabs = true`（預設值）。不用 Distributed Authority；不用 `WithDirectNetwork()`（瀏覽器無 inbound）。**Plan B 正式記錄**（TR-netcode-040）：第一退路 Distributed Authority（NGO 2.1.1+／UTP 2.3.0+／MPS 1.0.2+ 有官方 Web 支援），第二退路自租機器跑 headless＋nginx/caddy 反代 wss（Multiplay Hosting 已自 6.3 移除）。觸發條件只有兩個：client-as-host over Relay WSS 出現本 ADR 機制繞不過的根本障礙，或 Relay 免費額度（50 平均月 CCU）超額。

2. **兩層會談，壽命不同；NGO 啟停只有一個擁有者**。
   - **Session 層（MPS `ISession`）**：壽命＝一次開房到拆房，跨多個班次（Lobby → InShift → Settlement → Lobby → …）。成員資格、房間碼、Host 身份、`max_players`（唯一執行點＝MPS join）都在這層。唯一寫入者 Host（#24a）。
   - **Connection 層（Relay allocation＋NGO）**：壽命＝一個班次。#26「開始上班」時 Host 呼叫 `session.Network.StartRelayNetworkAsync(new RelayNetworkOptions(region))` 建立；Settlement 結束時 `StopNetworkAsync()` 拆除（#23a），MPS 的 `SessionState` 維持 `Connected`（本 ADR Core 的狀態型別叫 `SessionPhase`，見 Decision 3）。Lobby／Lobby\* 期間**不存在**對外的 NetworkManager 連線（Lobby\* 的練習沙盒只是本機 Host，見 Decision 10）——W1 證實連 `NetworkManager` 單例都不需要存在（#23 :440-441）。
   - **建房與加入的 options 一次決定**（r2 補 `IsPrivate`、`MaxPlayers` 與 handler）：建房、加入、復原的重新加入，options 一律由 `SessionServices` **唯一的 options 工廠**產生——它套用 ADR-0005 Decision 6 的 WSS 規則，並掛上本 ADR 的 `SessionNetworkHandler`：`CreateSessionAsync(new SessionOptions { MaxPlayers = cfg.MaxPlayers, IsPrivate = true, Type = <每次新產生> }.WithNetworkOptions(new NetworkOptions { RelayProtocol = RelayProtocol.WSS }).WithNetworkHandler(h))` 只設定、不啟網（不得帶 `WithRelayNetwork()`，否則建房當下就啟網並呼叫 handler）；每個加入者 `JoinSessionByCodeAsync(code, new JoinSessionOptions { Type = <每次新產生> }.WithNetworkOptions(…WSS).WithNetworkHandler(h))` 各自再宣告一次。handler 不經 ADR-0005：`NightShift.Platform` 不引用 Netcode 與 MPS（ADR-0005 Decision 1），ADR-0005 只擁有「顯式 WSS」這條規則。
     - **協定不會從 Host 傳染給加入者**（`DiscRoleTests.cs:178-180`）：任何一條加入路徑漏掉 WSS，就會在該路徑單獨拋 `Mismatched`。兩個 option 以不同型別為鍵、可以並存，但同一型別重複加入會 throw（`BaseSessionOptions.cs:105-115`）。
     - **`MaxPlayers = SessionConfig.MaxPlayers`**（＝`max_players`：MVP 2、VS 4；r2 依審查更正：寫死 4 會讓 MVP 房放進第 3 人，與「`max_players` 唯一執行點＝MPS join」矛盾，Lobby\* 等待者也會在下一班與上一班的玩家搶唯一的 slot）。`PlayerSlot.Capacity = 4` 只是容器上限。
     - **`IsPrivate = true`**：房間不出現在查詢結果、只能以碼加入（UGS 文件明載私人 lobby 可以碼加入；W1 測的是預設的公開房，但全程只用 `JoinSessionByCodeAsync`，V13 一併覆蓋）。r2 的 Lobby\* 走法不需要任何人在 session 外讀房間資料；公開房只會多一個面：改過的 client 能以查詢結果的 id 直接進房。
     - **每次建房與加入都用新的 `SessionOptions.Type`**（r2 通則）：MPS 以 Type 為鍵登記 session（`SessionManager.cs:359-363`），只有 `Deleted`／`RemovedFromSession` 才會移除（`:306-307,435-441`）。會留下舊登記的情況有四種：token 遺失的殭屍 session（Decision 8）、被判 `Duplicate` 而不 leave 的分頁、`LeaveAsync` 在 `RemovePlayerAsync` 失敗時於發出 `RemovedFromSession` 之前就拋出（`SessionHandler.cs:806-823`）、`JoiningRoom` 逾時後才回傳的加入。重用 Type 會得到 `SessionTypeAlreadyExists`。
   - **Region**：#26 建 allocation 前 `IRegionSelector.SelectRegionAsync(available, fallback, ct)` → `new RelayNetworkOptions(region)`（#28，貼著 Host 選）。**只准用 `RelayNetworkOptions(string region = null, bool preserveRegion = false)`**：三個帶 `RelayProtocol` 參數的建構子在 2.3.1 已 `[Obsolete]`（`RelayNetworkOptions.cs:57,87,121`；r1 更正行號），協定只能在 `WithNetworkOptions()` 設，任何人把協定參數「修回」這裡都是倒退。
   - **NGO 啟停的唯一擁有者是轉接層的 `SessionNetworkHandler : INetworkHandler`**（r2 依 r3 FV-1、arlong 2026-10-03 裁決，取代 r1 的「SDK 自動啟網＋`StartFailed` 復原」）。依據全部是 MPS 2.3.1 原始碼：
     - MPS 對每個 session 一律建網路模組，options 只改它的欄位（`MultiplayerInitializer.cs:104-118`、`SessionManager.cs:288-309,382-400`）。client 沒有公開的手動啟網 API（`IClientSessionNetwork.StartNetworkAsync` 是 internal，`IClientSessionNetwork.cs:47`），而 client 啟網有兩條自動路徑：**初始化路徑**——加入一個網路屬性 `_session_network` 已存在的 session（#9 中途加入），在 `JoinSessionByCodeAsync` 內的模組初始化觸發（`NetworkModule.cs:113-124`）；**屬性變更路徑**——已是成員者，在 Host #26 寫入新屬性值時觸發（`:107-109,132-147,505-561`）。兩條路都先做 Relay `JoinAllocationAsync`，再呼叫 `INetworkHandler.StartAsync`（`:423-470`）。
     - **r3 FV-1 的病根**：初始化路徑上，只要 handler 拋例外，SDK 就會在把例外交給呼叫端之前 `CleanupSessionAsync` → `LeaveAsync` → `RemovePlayerAsync(PlayerId)`（`SessionManager.cs:311-347`、`SessionHandler.cs:785-824`）。預設的 `GameObjectsNetcodeNetworkHandler` 在 approval 拒絕時就是拋例外（`NetworkManagerSession.cs:411-419`），所以被截止擋下的中途加入者在拿到 `ISession` 之前就已不是成員，Lobby\* 根本到不了，r1 的 `StartFailed` 也訂閱不到。
     - **handler 是唯一的掛點**：handler 正常返回時，模組設 `State = Started`、不發 `StartFailed`（`NetworkModule.cs:470-477`），初始化照常完成、`JoinSessionByCodeAsync` 回傳 `ISession`，成員資格保留。MPS 內沒有任何其他程式會因 NGO 斷線而 leave（整個套件只有預設 handler 自己訂閱 NGO 事件，`NetworkManagerSession.cs:317-334`）。預設 handler 是 internal（`GameObjectsNetcodeNetworkHandler.cs:15`），無法包 decorator，所以本 ADR **自己實作一份**（約百行），Host 與 client 共用，由 `SessionServices` 的 options 工廠掛上。
   - **`SessionNetworkHandler` 契約**（H1–H7；違反任何一條，都會靜默回到 FV-1 或卡住整班）：
     - **綁定**：handler 建構時只拿 NGO 與 transport。MPS 要等模組初始化與 `SaveCurrentPlayerDataAsync` 都完成，才 `RegisterSession`（`SessionManager.cs:249-270`），而 `NetworkConfiguration` 不帶任何 session 資訊（`NetworkConfiguration.cs:13-104`），所以 handler 在**初始化路徑上讀不到 session**。轉接層在建房、加入、復原的重新加入回傳後，通過 H7 斷言就立即 `h.Bind(session)`。屬性變更路徑也可能在 `Bind` 之前就觸發——加入途中 `SaveCurrentPlayerDataAsync` 的回應就會發一次 `LobbyChanged`（`LobbyHandler.cs:532-533`）——所以 H1 ①④ 的條件是「是否已 `Bind`」，不是「哪一條路徑」。
     - **H1 client 啟網的閘門**：`StartAsync(cfg)` 且 `cfg.Role == Client` 時，同步觸發 `AttemptStarted`，然後依序：① 若已 `Bind`，記下進入當下 `session.Properties[NetworkModule.SessionPropertyKey]`（＝`"_session_network"`，`NetworkModule.cs:10`）的值；未 `Bind` 時略過 ① 與 ④，**不得把「讀不到」當成「缺席」而 throw**——那會讓 SDK leave（`SessionManager.cs:317-320`），連本可核准的中途加入者也一起失敗，回到 FV-1。略過 ④ 只會晚一點失敗：Host 若已拆網，NGO 拆網不送原因字串（`NetworkConnectionManager.cs:1713-1716`），不會被 H2 誤判，最後經 ⑥ 走 H3。② 若本機練習沙盒仍在跑，**立即**請轉接層送 `NetworkJoinRequested` 進 Online Core（停在 `LobbyWaiting` 的那一台，沙盒的生命週期歸它管），由它輸出 `AbortSandbox`（不等 `shift_eta.phase` 回到 `Lobby`：屬性合併時 client 可能根本看不到那一筆），然後等 `!IsListening && !ShutdownInProgress`，且距上一次 stopped 事件至少 1 幀；③ 斷言指派的 transport 是 `UnityTransport`（Decision 10 的不變式）；④ 已 `Bind` 時再比一次 `_session_network`，缺席或已不同就 throw `SessionException`（閘門期間 Host 已拆網或換班，這次 allocation 作廢）；⑤ `(transport as UnityTransport).SetRelayServerData(cfg.RelayServerData)` → `NgoOwner = Online` → `StartClient()`。client 也用 `RelayServerData`：MPS 的 XML 註解說 client 沒有這個值（`NetworkConfiguration.cs:51-55`），但 2.3.1 的 client 路徑正是把 join allocation 放在這裡（`NetworkModule.cs:428-441`），預設 handler 也這樣用（`GameObjectsNetcodeNetworkHandler.cs:188`）；`RelayClientData` 只在 Netcode for Entities 下才有值，不得改用；⑥ 等到 `IsConnectedClient`（成功），或 `!IsListening && !ShutdownInProgress`（結束）。② 到 ⑥ 共用一個 `T_spawn` 上限，逾時依 H3 throw；⑦ 在 stopped 回呼的**下一幀**才完成 Task——stopped 回呼在 NGO 的 `ShutdownInternal` 內同步觸發（`NetworkManager.cs:1713`），當場完成會讓 MPS 的後續動作在關機途中重入。這個閘門用排序消掉了 r1 的 V11 沙盒競態，也從根本消除 `TransportComponentMissing`。
     - **H2 拒絕永不 throw**：結束時若 `NetworkManager.DisconnectReason` 能精確解析為 `JoinRejectReason`，或在 `OnClientConnectedCallback` 之前斷線、且原因符合 NGO 的通用字串 `^Client-\d+ disconnected by server\.$`（暫歸 `StaleBuild`；轉接層 leave 之前先比對 `build_token`，相符就改歸 `Failed`，Decision 5），就記下 `LastOutcome = Rejected(reason)` 並**正常返回**。原因要在 stopped 當下快照並綁定這次嘗試，因為下一次 NGO Start 會清空它（`NetworkConnectionManager.cs:1651-1652`），沙盒的 `StartHost` 也算。
     - **H3 真故障才 throw**：逾時、transport 失敗，以及 ④ 的屬性比對失敗，一律 throw `SessionException`（非 `SessionException` 會被 MPS 一律改包成 `NetworkSetupFailed`：client 的 `JoinNetworkAsync` 在 `NetworkModule.cs:489-497`，屬性變更路徑再經 `:551-559`；Host 路徑見 `:372-380`）。在初始化路徑上，這會讓 SDK leave、`JoinSessionByCodeAsync` 拋例外，Core 走 `JoiningRoom` 的失敗出口；在屬性變更路徑上，SDK 只發 `StartFailed`、不 leave（例外落進 `async void`，`NetworkModule.cs:132-147`），由下方的「復原」接手。被取消時也必須 throw，不得正常返回，否則模組會謊報 `Started`。
     - **H4 Host 角色**：`cfg.Role ∈ {Host, Server}` 時一律以 Host 啟動：先等 `!IsListening && !ShutdownInProgress`，且距上一次 stopped 事件至少 1 幀（計入 `T_spawn`）——有 peer 的 Host 在 `Shutdown()` 之後至少再跑兩幀才真正關閉（`NetworkManager.cs:547-593`），這段期間 `StartHost()` 會被 `CanStart` 擋下（`:1300-1306`）；再斷言 `UnityTransport`、`SetRelayServerData`、`NgoOwner = Online`、`StartHost()`。回 false 就 throw `SessionException`，MPS 隨即發 `StartFailed`，屬性不會發布。Host 自核准的第三道防線與 #26 的時序掛在 `OnServerStarted`（Decision 5）。`StartRelayNetworkAsync` 若在 handler 成功**之後**才失敗——寫 `_session_network` 的 `SavePropertiesAsync` 遇到 429 或斷網（`NetworkModule.cs:355-359`；`SetAllocationId` 只是同步寫欄位，`Player.cs:81-85`）——MPS 不會呼叫 `StopAsync`（`:362-380`），也不會撤回已寫進本機字典的 `_session_network`（`SetProperty` 只改本機，`Modified` 要存檔成功才清，`SessionHandler.cs:1019-1023,1056`）。轉接層必須依序：① `h.StopAsync()`，否則 NGO Host 洩漏；② `SetProperty(SessionPropertyKey, null)`，並把本機 `shift_eta` 還原成 #26 之前的值，否則下一次任何存檔都會把已沒有 Host 的 join code 發布出去，所有 Lobby 成員對著它啟網、失敗、復原、再被 SDK 移出；③ Core 走 `ShiftStartAborted`（Decision 5）。
     - **H5 `StopAsync` 永不 throw、永不懸掛、冪等**：從建房那一刻起，每次 Leave、Delete、被踢、`OnQuitting`、失去成員資格時，MPS 都會呼叫它，即使從未啟網也一樣（`NetworkModule.cs:720-735`、`SessionHandler.cs:770-783,839,901,1224-1241`）。它只在**本 handler 啟動的** NGO 仍在跑時呼叫 `Shutdown()`，接著立刻回傳已完成的 Task；「等 NGO 真的停了」留給下一次 `StartAsync` 的閘門，Host 的 #23a 另以 `OnServerStopped` 判定完成。它會取消進行中的閘門，該次 `StartAsync` 隨之 throw；不碰 Solo 與沙盒的 NGO。它若 throw，client 的 `StopNetworkAsync` 會把 State 設回 `Started` 並發 `StopFailed`（`:711-716`），下一班就被吃掉；它若懸掛，`Stopping` 窗口會放行下一次加入，撞上還沒清掉的 join allocation（`AllocationAlreadyExists`，`RelayHandler.cs:79,144-150`）。
     - **H6 一個 session 一個實例**：以 session 世代標記，跨班次重複使用；舊模組延遲執行的程式碼不得碰到新 session 的 NGO。
     - **H7 套用斷言與綁定**：建房與加入回傳後，斷言 `session.Network.NetworkHandler == h`，通過即 `h.Bind(session)`。`ProcessOptions` 會吞掉 option 套用時的例外，只記一行 LogError（"Process Options Exception"）就繼續，呼叫端拿不到例外，handler 退回預設（`SessionManager.cs:390-397`）——退回就等於回到 FV-1。`NetworkHandler` 有 public setter，但只在模組 `State == Stopped` 時可用（`NetworkModule.cs:83-97`）：斷言失敗而模組仍是 `Stopped`（建房後，或在 Lobby 加入、尚未啟網）就以 setter 補掛 `h`；初始化路徑已經以預設 handler 啟網的，就無法補救，只能 Teardown。
     - ⚠ 這份契約**違反 `INetworkHandler` 的兩句文件註解**：`StartAsync`「Task 完成後 client 應已連線」（`INetworkHandler.cs:20-22`）——H2 被拒時正常返回、沒有連線；`StopAsync`「Task 完成後不應再連線或接受連線」（`:34-36`）——H5 在 `Shutdown()` 只設旗標時就回傳。MPS 2.3.1 都沒有強制（`ResetAsync` 在 `StopAsync` 之後只清 Relay 欄位，`NetworkModule.cs:720-735`），升版時必重驗（V1）。
   - **真相規則**：`IClientSessionNetwork.State`／`StateChanged` **不是** NGO 狀態的真相。被拒之後它一直報 `Started`（`NetworkModule.cs:470-477`），閘門期間則是 `Starting`（`:403`）；MPS 也沒有從 NGO 回寫模組狀態的通道（`INetworkHandler` 只有兩個方法）。Core 的 `NetworkStarted`／`NetworkStopped`／`JoinRejected(reason)` 只從 handler 觀察到的 NGO 狀態產生。
   - **NGO 的擁有者**（r2 依審查新增）：Lobby\* 的練習沙盒也用同一個 `NetworkManager`（Decision 10）。`NgoBridge` 以**啟動時記錄的擁有者**路由所有 NGO 回呼與 avatar／`SessionRoot` 事件：`TransportSwitch.UseSinglePlayer` 在 `StartHost()` 之前設 `NgoOwner = Sandbox`，handler 在 `StartClient()`／`StartHost()` 之前設 `NgoOwner = Online`；stopped 回呼結束後的下一幀才清除。不得以當下的 transport 指派判斷：`UseUnityTransport` 本身就掛在 `OnServerStopped`，訂閱順序一變，沙盒自己的 `OnServerStopped` 就會被誤送給 Online Core。沙盒收場時 NGO 會發 `OnClientDisconnectCallback(0)`，而那時 `m_ShuttingDown` 已經設回 false（`NetworkManager.cs:1678,1681-1684`），`ShutdownInProgress` 守衛擋不住；它若進了 Online Core，就會被 Decision 13 讀成本機離線。
   - **Lobby\* 的入口**：handler 回報 `Rejected(LateJoinCutoff)` 時，Core 在 session 內進 `LobbyWaiting`，成員資格保留。兩條路徑都一樣：初始化路徑對應中途加入；屬性變更路徑對應閘門期間截止線滑過的競態。`StaleBuild`（`build_token` 比對確認後）、`NotAMember`、`Full` 被拒的人拿到 `ISession` 後，由轉接層自己 `LeaveAsync`，避免一直占著 `MaxPlayers` 的名額。`Duplicate` 不 leave，也不安裝離開通知：兩個分頁共用同一個 `PlayerId`，leave 會把合法的那一端也移出（Decision 9）。
   - **看門狗**（r2 新增，V11；只在 client 端；判定是 Core 的純函式 `JoinWatchdog`，轉接層只採樣與執行）：模組的 `m_Property` 在嘗試之前就先更新，而且只有 State 不是 `Starting`／`Started` 時才會加入（`NetworkModule.cs:518-521,537`）；State 為 `Starting` 時，連「屬性被移除」也會被忽略（`:510` 只處理 `Started`）。所以 #23a 與 #26 在 client 端合併成一次變更、或 #23a 落在某次 `StartAsync` 進行中，#26 的新值都會被靜默吃掉。合併的主要來源是 client 自己任何一次帶回較新版本的 REST 回應（`LobbyCacher.cs:97-105`）。
     - **`attemptedSeq`**：屬性變更路徑上，`AttemptStarted` 觸發時（模組已經 await 過 `JoinAllocationAsync`，`NetworkModule.cs:427,470`），轉接層當場讀已綁定 session 的 `shift_eta.shift_seq` 交給 Core；初始化路徑上，`JoinSessionByCodeAsync` 回傳後，若這次加入期間 `AttemptStarted` 觸發過，就以回傳 session 的 `shift_eta.shift_seq` 回填。加入拋例外則不回填。
     - **武裝**：在每次 `ISession.Changed`，以及每次 handler 嘗試結束時評估：Core 處於 `Lobby` 或 `LobbyWaiting`、`shift_eta.shift_seq > attemptedSeq`、`phase == InShift`、`_session_network` 存在、handler 未連線，而且沒有進行中的 `StartAsync`。條件成立就以 Core 的狀態計時（`nowMs`）對這個 seq 武裝一次 `network_join_watchdog_ms`；同一個 seq 只武裝一次，起點是首次符合條件的時刻；期間 handler 一被呼叫就解除。不聽 `SessionPropertiesChanged`：新增 key 的 diff 只發 `DataAdded`，它不會觸發（`LobbyHandler.cs:224-232`）。
     - **觸發**：到期時重檢同一組條件，仍成立才走「復原」。不得只在 `Changed` 當下判斷時窗：Wire 是事件驅動（`MultiplayerInitializer.cs:88`，`usePolling = false`），班次中可能好幾分鐘都沒有下一次 `Changed`；而 #26 那一次 `Changed` 裡，模組才剛 await `JoinAllocationAsync`（`:403,427`），handler 還沒被呼叫。
     - **Host 端的寫入配對**（Decision 5）：#26 的 `shift_eta` 與 `_session_network` 同一次存檔送出；#23a 的 `shift_eta(Lobby)` 與屬性移除同一次存檔送出。Host 另守 `min_lobby_dwell_ms`：#23a 移除屬性的存檔完成後至少等這麼久，才允許下一次 #26。它只降低合併的機率，對「移除落在某次 `StartAsync` 進行中」無效，那一種靠看門狗。
   - **復原**（取代 r1 的「`StartFailed` → `LeaveAsync` → 以同碼重新加入」，那條路會把已保住的 Lobby\* 親手送進初始化路徑；判定同樣是 Core 的純函式 `RecoveryPolicy`）：
     - **觸發**只有兩個來源：屬性變更路徑的 `StartFailed`——**而且失敗當下 `_session_network` 仍存在、值與這次嘗試相同**（已移除或換值時不復原，模組會在下一次變更自己啟網）；以及看門狗到期。被拒絕一律不復原（H2 已把拒絕攔下，`StartFailed` 只剩真故障）；被判 `Duplicate` 的分頁一律不復原；Teardown 進行中一律不復原（以 session 世代擋）。
     - **節制**：同一時間只跑一個，至少延後 1 幀；**每個 `shift_seq` 最多 2 次**；退避依 Decision 14（首次 ≥ 2 s、指數、加抖動——以碼加入的上限是每人 1/s）。`lobby not found` 可能其實是 429（`README.md:334-339`）。
     - **動作**依序：`AbortSandbox` → session 世代加一，並**解除對舊 `ISession` 的所有訂閱**（`LeaveAsync` 成功時，會在同一個呼叫內發出 `StateChanged(Disconnected)` 與 `RemovedFromSession`，`SessionHandler.cs:822-823`；不先退訂，轉接層就會把它當成「被移出」而 Teardown，復原的加入隨後完成，玩家在 `Idle` 畫面上卻是成員）→ `LeaveAsync` → 以同碼、新的 `SessionOptions.Type` 呼叫 `JoinSessionByCodeAsync`。因為 H2，這條初始化路徑上被拒也不會被移出。
     - **用盡**（第 2 次仍失敗）：Core 走 Teardown → `Idle`，店語「跟店裡斷線了，用房間碼再進來一次」。
     - 2 人房的等待者在 leave 與重新加入之間的空檔，座位可能被持碼的第三人拿走；這時重新加入得到「這班人滿了」，MVP 接受。
   - 班次剩餘時間的預檢與 Lobby\* 的倒數，都走同一個 session property 機制（Decision 5）。

3. **純 C# `SessionMachine`（`NightShift.Session.Core`，`noEngineReferences = true`）**。
   - **狀態**＝GDD States 表的 12 態，一字不改：`Booting`、`LoadFailed`、`Idle`、`ServiceError`、`CreatingRoom`、`JoiningRoom`、`Lobby`、`LobbyWaiting`（＝Lobby\*，前一班進行中）、`Onboarding`、`InShift`、`Disconnected`、`Settlement`；另加 `SessionMode { Online, Solo }` 旗標（Decision 10）。C# 型別名是 **`SessionPhase`**（r1 依 r2 X4 改名）：`SessionState` 是 MPS 的型別（None／Connected／Disconnected／Deleted），轉接層同時 using 兩個命名空間會撞名，而且本 ADR 的 Decision 2 與 T1 (g) 提到的 `SessionState.Connected` 指的正是 MPS 那個。
   - **輸入**＝離散 `SessionEvent`，由轉接層翻譯引擎／服務事件而來；**輸出**＝`SessionEffect` 命令清單，由轉接層執行。Core 不呼叫任何 Unity、NGO、UGS API，也不持有 Task。
   - **適用性矩陣（GDD :704-745）就是守衛表**：矩陣實為 **32 列**（#1–#28 加 #15a、#17a、#23a、#24a）× **11 欄**（Booting／LoadFailed 合為 Boot 欄），Core 以表驅動實作，EditMode 測試逐格斷言全部 352 格。（r1 依 r2 E4 更正：原寫 28 × 12，照字面只測 28 列，會漏掉 #17a teardown 不變式與 #24a MPS 成員唯一寫入者——恰好是本 ADR 最核心的兩條。）
   - **每一列先定「主詞」，再讀欄位**（r1 依 r2 E4）。欄是狀態，但不是每一列都在問「本機現在是什麼狀態」；全部當成本機狀態來實作，會把 #24 寫錯——Host 永遠不會處於 Onboarding 或 Disconnected：

     | 主詞 | 列 | 欄位讀的是誰的狀態 |
     |---|---|---|
     | 本機 | 其餘 24 列 | 本機 `SessionPhase` |
     | 受影響的 peer（Host 執行） | #11、#14、#15、#15a、#16、#24 | Onb／InShift／Settle 欄讀該 peer 在 `SlotTable` 的 `PeerPhase`；Lobby／Lobby\* 欄讀 Host 本機（那時沒有 NGO 連線，peer 不存在）；Disc 欄不讀——Host 不會處於 Disconnected，peer 在被判離線的那一刻就退出 `SlotTable`。GDD r5 為矩陣加「主詞」欄時一併收斂這一欄 |
     | 加入者與 Host 各讀一半 | #9 | Joining 欄讀加入者本機：r2 起私人房在加入前讀不到任何資料，此格在 Core 恆為「不預檢截止、照常加入」，過截止者被 approval 拒絕即落 Lobby\*（Decision 5）；InShift／Settle 欄讀 Host 本機（approval 閘門）；Lobby 欄只會被 Host 自身的請求讀到——那是 #26 的一部分，不經 #9 的矩陣守衛，不 throw（Decision 5「#26 的時序」） |
     | Host 本機與受影響的 peer 各讀一半（r2 依 r3 FV-8 改歸） | #24a | Creating／Joining／Lobby／Lobby\* 欄讀 Host 本機（Host 隨時是 MPS 成員的唯一寫入者）；Onb／InShift／Settle 欄讀該 peer 的 `PeerPhase`（Decision 7 第 6 步）；Disc 欄同上不讀。r1 把它歸為本機主詞，與下方「Onboarding 期間斷線仍要 `RemovePlayerAsync`（#24a 的 Onb 欄＝Y）」的讀法互相矛盾 |

     矩陣的「–」格只在主詞為本機時於 Core `throw`（事件在該狀態下不該出現）；主詞為 peer 時，「–」與「N」都是忽略並記錄。
   - **Onboarding 期間斷線＝視同從未加入**（#11／#24 的 Onb 欄＝N；r1 補上 slot 回收路徑，r2 依 avatar 延後 spawn 簡化）：釋放 slot，**不發** `PlayerLeft`（`PlayerJoined` 要等定長過場結束才發，這時還沒發過）、不計 #15a、不重取樣。這時**沒有 avatar 要 despawn**：avatar 到 `PlayerJoined` 才 spawn（Decision 7 前提 4）。待發的 `PlayerJoined` 只存在 Core 裡，所以由 **Core** 在 `PeerLost`（`Phase == Onboarding`）的同一個 `Step` 內取消它，連帶不會輸出 `SpawnAvatar`；已經輸出、轉接層還沒執行的 `SpawnAvatar`，由 Decision 7 前提 4 ① 的在線檢查丟棄。Host 仍要 `RemovePlayerAsync`（#24a 的 Onb 欄＝Y），仍要切斷 NGO 連線。各參與者從 `PeerLostContext.Phase` 得知這種情況（Decision 7）。
   - **Settlement 期間斷線**（r2 依 r3 FV-8 新增；矩陣 Settle 欄：#11／#14／#15／#15a／#16＝N，#24／#24a＝Y）：第 1、2、3、7 步不做事（Settlement 沒有移動、沒有掉落與解鎖、不重取樣、不計 #15a）；第 4 步照樣 `Roster[slot].Online = false`、發 `PlayerLeft`、釋放 slot——Settlement 全程鎖 join（#9 Settle 欄），回收的 slot 不會被重派，「slot 隨結算釋放」與立刻釋放沒有可觀察的差別；第 5、5a、6 步照常，不留殭屍 avatar、不留鬼連線、名額照釋放。r1 只定義了 Onboarding 的分流，照字面讀，Settlement 中斷線也會照跑第 7 步。
   - **進 Settlement 時有 peer 仍在 Onboarding**（r2 依審查新增；只會因 `end_shift_early` 發生——approval 要求剩餘 > 30 s，比過場上限 5 s 長，自然收班撞不到）：Core 取消所有待發的 `PlayerJoined` 與 `SpawnAvatar`，該 slot 的 `PeerPhase` 直接轉 `Settlement` 並計入 `final_roster`；client 以 `shift_eta.phase == Settlement`（或 `SessionRoot` 的結算訊號）結束更衣室過場、顯示結算，不等自己的 avatar。
   - **時間源**：Core 只認 `nowMs`（由轉接層以 `IPageLifecycle.NowMs` 餵入，單調）。沒有 `DateTime.Now`、沒有 `Time.*`。
   - 這條分層紀律登記為 forbidden pattern `session_logic_outside_core`：任何「要不要判斷線、能不能加入、該不該 teardown」的決策不得住在 `NetworkBehaviour`／`MonoBehaviour`／UGS 回呼裡。

4. **Identity 契約**（review C1；取代三份 ADR 各自為政的編碼）。
   - 三種 id、三個範圍，**只在邊界轉換**：

   | id | 型別 | 壽命／範圍 | 誰指派 | 允許出現的位置 |
   |---|---|---|---|---|
   | `PlayerId` | `string`（UGS 匿名帳號，≡ `session.CurrentPlayer.Id`） | 跨 session、跨班次；清快取／換瀏覽器即換（`[P-2b]`，設計接受） | UGS Authentication | MPS 層、approval payload（UTF-8 ≤ 61 bytes，Decision 5）、Core `SlotTable`、#15a 離線計數、session 事件的 `playerId` 參數（`PlayerJoined`／`PlayerLeft`／`PlayerDisconnected`，Decision 13）、結算 `final_roster`（r2 依 r3 CX-9 補齊：r1 的範圍比本 ADR 自己的事件窄） |
   | `Slot` | `byte`，`0 .. max_players−1` | 一個班次內穩定；離線即回收（MVP）；Post-MVP 保留 `reconnect_window_sec` | Host 於 approval 時指派（最小空位） | **所有遊戲系統的玩家鍵**：`CapsuleGhost.Id`、`PairKey`、`PassThroughPlayerMask` 位元、`ClaimState.ClaimedBy`、roster、HUD |
   | `clientId` | `ulong`（NGO） | 一次 NGO 連線；重連換號；Host 恆 0 | NGO | **只在 NGO 邊界**：`RpcParams.Receive.SenderClientId`、`OwnerClientId`、`OnClientConnected/DisconnectCallback`、`RpcTarget.Single(clientId)`、轉接層對 NGO 的呼叫（`SpawnAsPlayerObject`、`DisconnectClient`；r2）。唯一例外是 `SessionRoot.Roster` 的 `ClientId` 欄：它是 slot 的占用世代，只准比較「變了沒」，不得拿來查表、定址或當鍵（Decision 13，r2） |

   - **真相＝Host 的 `SlotTable`（Core）**；複製為 `SessionRoot.Roster`（Host 寫 `NetworkVariable<RosterState>`，固定 4 格，遲加入者自動取得現值）。轉接層在 RPC 進 Core 前先 `SlotOf(senderClientId)`，Core 內**不出現** `ulong`。`SlotOf` 回 `PlayerSlot.NoSlot` 的 RPC 與 NGO 回呼一律**丟棄並記錄**、不進 Core（r1 依 r2 E6）：這涵蓋「心跳已判離線、NGO 連線還在」的窗口（Decision 7 第 5a 步之前），以及其後遲到的 `OnClientDisconnectCallback`。`NoSlot` 與 claim 的「無人」同為 255，不丟棄的話，鬼連線送來的請求會被當成「無人」送來的。
   - **回收規則**：#24 序列第 4 步把 `Roster[slot].Online = false` 並釋放 slot（MVP）。Core 保證對同一 slot，`PlayerLeft(slot)` 一定先於下一個 `PlayerJoined(slot)` 送出，且兩者之間至少隔 `onboarding_duration_sec` 下限 **3.0 s**。這個間隔是**結構性**的：slot 回收後可以立即指派給下一個 approval（**不設指派冷卻**——r1 依 r2 E10 刪除；冷卻會讓 2 人房裡唯一的空位在 3 s 內被判 `Full`），但中途加入者的 `PlayerJoined` 要等定長過場結束才發；開班同批只會拿到本班從未被占用的 slot（Decision 7 前提 4 (i)），沒有前一個 `PlayerLeft` 需要隔開。**r2：avatar 也到 `PlayerJoined` 才 spawn**（Decision 7 前提 4），所以這 3.0 s 同時保護事件與物件：新玩家的 avatar `NetworkObject` 在那之前任何一端都不存在，ADR-0003 :95「新玩家的 `NetworkObject` 物理上不可能存在」恢復成立（r1 曾要求 ADR-0003 r1 改述，r2 撤回）。消費者（`PairMachine`、PassThrough 遮罩、claim 表、HUD 名牌）**必須在本端的 `PlayerLeft(slot)` 清掉該 slot 的一切條目**；「本端的 `PlayerLeft`」在 Host 是 Core 事件，在其他端是該 slot avatar 的 `OnNetworkDespawn`（Decision 13 的分端來源表，r2 依 r3 CX-2）——這就是「重連換號的孤兒回收」：重連者拿到的是新 slot（MVP）或同一 slot（Post-MVP 保留），兩種情況下舊條目都已清除，不存在以 clientId 為鍵的殘留。PassThrough 遮罩是 owner-write（ADR-0003 D1）：**由每個玩家自己的擁有者端**，在本端看到該 slot 的 avatar despawn 時，清掉自己遮罩的第 slot 位；Host 不得代清，代清的寫入會被 `CannotWrite()` 靜默丟棄（r1 依 r2 X5）。r1 寫「在收到 `PlayerLeft(slot)` 時清」，但非 Host 端根本收不到這個事件（r3 CX-2）。
   - **NPC id**：`int npcId ∈ [0, NpcId.Max)`，`NpcId.Max = 64`。**值域由本 ADR 擁有**（r1 依 r2 §3B Resolution 1 反轉：原寫「由 ADR-0003 的遮罩決定」，會在 ADR-0003 r1 改用 `PeerKey` 時形成 0003↔0006 環）；ADR-0003 的 `PassThroughNpcMask`（`ulong`，64 位）寬度由此推導，並以靜態斷言 `NpcId.Max <= 64` 釘住。Host 指派；重用冷卻規則屬 ADR-0003（`npc_id_reuse_cooldown_sec`，:97），此處只引用、不重述（r2 依 r3 CX-4：重述會在 ADR-0003 r1 改動時形成隱性回指）。與玩家鍵**不共用值域**：ADR-0001 的 `CapsuleGhost.Id` 與 `PairKey` 改用 `PeerKey { PeerKind Kind; byte Index; }`，玩家 `Index = slot`、NPC `Index = npcId`。
   - **組件**（r1 依 r2 §3B Resolution 1）：`PeerKind`、`PeerKey`、`PlayerSlot`、`NpcId` 住在獨立的 **`NightShift.Identity`**（asmdef `noEngineReferences = true`、不引用任何組件）。契約由本 ADR 裁決，程式碼卻不放在 `Session.Core`——`Movement.Core`（ADR-0001）與 `Interaction.Core`（ADR-0002）不必為了一個兩欄 struct 引用整個 session 核心。ADR-0001／0003 r1 改鍵為 `PeerKey`；ADR-0002 r1 把 `ClaimState.ClaimedBy` 與 `InteractValidator.Validate(…, ulong requester, …)` 都改為 `byte` slot（`PlayerSlot.NoSlot`＝無人）。
   - **#15a 離線計數**以 `PlayerId` 為鍵、班次為範圍（Core 內 `Dictionary<string,int>`，`Settlement → Lobby` 時清空）；換裝置即重新計數（GDD 已接受）。

5. **Approval 閘門（#9）：唯一的決策閘，前面還有一道引擎層硬閘**（r2 依 r3 EA-2 改為兩層）。`NetworkManager.ConnectionApprovalCallback` → 轉接層解碼 `request.Payload` → Core `ApprovalGate.Evaluate(ApprovalRequest, HostView)` → `ApprovalVerdict`，純函式、µs 級，遠在 `ClientConnectionBufferTimeout`（10 s）之內。
   - **兩層**：
     - **第 0 層：NGO 連線設定雜湊（引擎層硬閘，在前）**。`ConnectionRequestMessage.Deserialize` 先比對 `ConfigHash`，不符就 `DisconnectClient(senderId)` 並回 false，approval 根本不會跑（`ConnectionRequestMessage.cs:140-151`；approval 在 `Handle` 內，`:206-210`）。雜湊輸入（`NetworkConfig.GetConfig`，`NetworkConfig.cs:328-366`）：`NetworkConfig.ProtocolVersion`、NGO 內部協定版本（`NetworkConstants.PROTOCOL_VERSION`，2.13.2 為 `"15.0.0"`）、`ForceSamePrefabs` 為 true 時的全部 network prefab 鍵（`SourcePrefabGlobalObjectIdHash`，來自資產 GUID 與 fileID，與 prefab 內容無關）、`TickRate`、`ConnectionApproval`、`ForceSamePrefabs`、`EnableSceneManagement`、`EnsureNetworkVariableLengthSafety`、`RpcHashSize`。所以兩個 build 之間只要增刪過任何 network prefab、升過改了協定版本的 NGO、或改了上述任一設定，擋人的是 NGO，不是 `ApprovalGate`。被擋的 client 讀到的 `DisconnectReason` 是通用字串 `Client-{id} disconnected by server.`（`NetworkManager.cs:1570`）。在連線前這個階段，這個字串出自 `ConnectionRequestMessage` 的四個分支（訊息不完整或雜湊不符，兩者都代表 build 不相容），以及 Host 端的 approval 逾時——`ClientConnectionBufferTimeout` 內沒處理完連線請求時，Host 也以單參數多載斷線（`NetworkConnectionManager.cs:772-835`）。本專案的 approval 是同步的，後者只會在 client 的連線請求延遲超過 10 s（例如分頁凍結）時出現。所以 `SessionNetworkHandler`（H2）在 `OnClientConnectedCallback` 之前看到它，先暫歸 `StaleBuild`；轉接層 leave 之前比對加入後讀到的 `build_token`（見下方「加入後的版本比對」），不符才確認為 `StaleBuild`、顯示同一套店語，相符就改歸 `Failed`、不 leave。前提是**本專案的程式碼不得呼叫無原因的 `DisconnectClient(ulong)` 多載**（registry `disconnectclient_without_reason`），否則這個字串就失去辨識力。
     - **第 1 層：`ApprovalGate`（唯一的決策閘，在後）**。截止、成員、重複、空位的判定，以及 `BuildId`／`ProtocolVersion` 的版本閘，都只在這裡。
     - 兩層都在任何資料交換之前擋下，AC54 成立。`NetworkConfig.ProtocolVersion` **固定為 0**，與 `ApprovalGate.ProtocolVersion` 是兩回事：把它設成我們的協定版本，只會讓協定不符從 `StaleBuild` 搬到 NGO 的通用字串，店語反而變模糊。`ForceSamePrefabs` 保持 true（另一種做法「改 false、由 `BuildId` 涵蓋 prefab 清單」見 Alternative 10）。`BuildId` 的雜湊輸入應涵蓋 `NetworkConfig.GetConfig(false)`，這樣「`BuildId` 不符」的集合就包含「NGO 雜湊不符」的集合（交 G4，與 `ProductCatalogAsset` 一併定）。
   - **Payload**（`NetworkConfig.ConnectionData`，固定二進位，**≤ 69 bytes**；r2 依 r3 FV-9 更正 r1 的 80／72）：`byte PayloadVersion`、`ushort ProtocolVersion`（本 ADR 的 session 協定版本常數，任何 RPC／NetworkVariable 佈局變更即 +1）、`uint BuildId`（build 時產生的內容雜湊；dev build 以 `SessionConfig.AllowDevBuilds` 旗標放行 0）、`PlayerId`（UTF-8，**n ≤ 61**——`FixedString64Bytes` 的實際容量是 61 bytes，`FixedString.gen.cs:2652-2655`）。解碼端先檢查 `n ≤ FixedString64Bytes.UTF8MaxLengthInBytes`，超過就判 `NotAMember`：release build 不開 Collections 檢查，超長字串會被靜默截斷成另一個 `PlayerId`（`FixedString.gen.cs:3599-3604`）。UGS `PlayerId` 為 28 字元，遠在上限內。
   - **判定順序**（第一個命中即拒，`response.Reason`＝`JoinRejectReason` 的列舉名，**每一個拒絕都必須帶非空原因**——空字串時 NGO 不送 `DisconnectReasonMessage`，`NetworkConnectionManager.cs:917-927`，client 就只拿到通用字串；店語翻譯在 client 的 `connection_state` 表）：
     1. `PayloadVersion`／`ProtocolVersion`／`BuildId` 不符 → `StaleBuild`（「這是舊的班表，重新整理一下」；AC54 的「任何資料交換之前」）
     2. `PlayerId` 不在 `HostView.MemberIds` → `NotAMember`（Online 時＝`session.Players`：NGO 連線者必須先是 MPS 成員，`max_players` 已由 MPS 擋，這裡只做二次驗證與防偽；Solo 與 Lobby\* 沙盒＝`{ 本機 PlayerId }`，見下方「Host 自核准」）。Host 的 `session.Players` 只靠 Wire 事件更新（`SessionHandler.cs:1076-1112,1208-1221`），與加入者的 NGO 連線請求沒有先後保證，所以**第一次**判到 `NotAMember` 時，`ApprovalVerdict` 帶 `RetryAfterMemberRefresh`：轉接層回 `response.Pending = true`（NGO 2.13.2 支援延後核准，`NetworkManager.cs:831-833`、`NetworkConnectionManager.cs:869-895`），`await session.RefreshAsync()` 後以新的 `MemberIds` 重判一次，仍不在才拒；整段要在 `ClientConnectionBufferTimeout`（10 s）之內（r2 依審查新增）
     3. 同 `PlayerId` 已占用在線 slot → `Duplicate`（同帳號雙開；以碼加入的第二個分頁多半在 MPS 層就得到 `SessionConflict`，走不到這裡，V16）
     4. `ShiftEndTs − HostNowMs ≤ late_join_cutoff_sec`（含端點、含 Settlement 全程）→ `LateJoinCutoff`（client 在 session 內進 `LobbyWaiting`；r2：handler 不 throw，成員資格保留，Decision 2）
     5. 無空 slot → `Full`（多半到不了：MPS 的 `MaxPlayers` 等於 `max_players`，且 r1 已拿掉 slot 指派冷卻；只會出現在「某成員已被自己的離開通知移出 MPS、其 NGO 連線尚未被心跳判離線」的 ≤ 8 s 窗口，被拒者依 Decision 2 `LeaveAsync`）
     6. 否則 `Approve(slot)`：`response.Approved = true`、**`response.CreatePlayerObject = false`**（r2，arlong 2026-10-03 裁決：avatar 到 `PlayerJoined` 才由轉接層 `SpawnAsPlayerObject`，見 Decision 7 前提 4）。`NetworkConfig.PlayerPrefab = null`、avatar prefab 只登記在 NetworkPrefabsList：只要有任何一條路徑沒呼叫 approval callback，NGO 就會依 `PlayerPrefab != null` 自動建 avatar：Host 本機是 `ConnectionApproval = false` 或 callback 為 null（`NetworkManager.cs:1519-1522`）；遠端 client 的請求在 Host 上處理，`ConnectionApproval = false` 時同理（`ConnectionRequestMessage.cs:211-222`）——callback 為 null 時遠端請求則不會被核准，只停在 pending 直到逾時（`NetworkConnectionManager.cs:849-852`）。之後 Core 再 spawn 一具，同一個 client 就有兩具身體。
   - **Host 自核准**（r1 依 r2 E2；r2 依 r3 FV-3 補完）：NGO 對 Host 本機 client（clientId 0）照樣呼叫 approval callback，但 `Approved = false` 只記一行警告就強制核准（`NetworkManager.cs:1507-1517`）。所以 `ApprovalGate` 若誤拒 Host 自己的請求，結果不是進不了場，而是**靜默進場、`SlotTable` 沒有 slot 0**。r2 的規則：
     - **Host 自身的請求（`ClientNetworkId == NetworkManager.ServerClientId`）只判第 1–3 項，不判第 4、5 項**。理由是時點不可控：Online 的自核准發生在 MPS `StartRelayNetworkAsync` 的兩次 Relay REST 之後、由本 ADR 的 handler（H4）呼叫的 `StartHost()` 之內（`NetworkModule.cs:285-303`）。那一刻 `SessionRoot` 還不存在（它在 `OnServerStarted` 才 spawn），`ShiftEndTs` 若從 NV 取就是預設 0，Host 的 `SessionPhase` 也還沒定義——r1 只修了第 2 項，Host 照樣可能被第 4 項拒絕。Host 自身請求的 `HostView` 輸入，在呼叫 `StartRelayNetworkAsync`／`StartHost()` 之前就固定，期間不變。
     - **三道防線**：① `HostView.MemberIds` 一定含 Host 自己——Online 為 `session.Players`（建房者即成員）；Solo 與 Lobby\* 沙盒沒有可用的 MPS 成員表，`MemberIds = { 本機 PlayerId }`：已登入用 UGS `PlayerId`，未登入（Solo 不初始化 UGS）用常數 `SessionConfig.SoloLocalPlayerId`，payload 帶同一個值；② T0 (b) 對 Online（`ShiftEndTsMs` 未設定、`SessionPhase` 仍為 Lobby）、Solo、沙盒三種 Host 規範請求斷言「永不被拒」；③ **掛點是 `NetworkManager.OnServerStarted`，三種模式通用**（r1 寫「`StartHost()` 返回後」：r2 起 Online 的 `StartHost()` 雖由 H4 呼叫，但它返回之後，MPS 還要寫 allocation 與屬性；三種模式唯一共通、而且早於 join code 發布的公開時點是 `OnServerStarted`）。它是唯一一個「slot 0 已確定、而任何遠端都還不可能連上」的公開時點（Online 的 join code 還沒經 session property 發布）。handler 內依序做：斷言 `SlotTable.SlotOf(0) == 0` → 寫入 `ShiftEndTs` 的初值（見下方「#26 的時序」）→ spawn `SessionRoot` → 發 Host 的 `PlayerJoined(0)` → `SpawnAsPlayerObject(ServerClientId)` → 斷言 `avatar.IsSpawned && NetworkManager.LocalClient.PlayerObject == avatar` → 送 Core `HostShiftStarted`（`SpawnAsPlayerObject` 失敗只記 log、不拋例外，`NetworkObject.cs:1844-1851,1909-1914`，所以一定要斷言）。任何一步失敗就 throw：NGO 的 `StartHost` 會接住 → `ShutdownInternal` → 回 false（`NetworkManager.cs:1486-1494`）。Solo 與沙盒直接看到 false；Online 由 `SessionNetworkHandler`（H4）把 false 轉成 `SessionException`，MPS 發 `StartFailed`，屬性不會發布。注意兩件事：失敗路徑的 `ShutdownInternal` 會在 `StartHost` 內同步觸發 stopped 回呼，這些訂閱者不得 throw，否則 `StartHost` 會拋出例外而不是回 false；`OnServerStarted` 的訂閱者只准有這一個，排在它後面的訂閱者在它 throw 時不會執行。
   - **#26 的時序與 `ShiftEndTs` 的建立時刻**（r2 依 r3 FV-3 補完：r1 沒定義 #26 啟網當下 Host 的 `SessionPhase`，也沒定義 `ShiftEndTs` 何時寫入；若晚寫，第 4 項會以預設值 0 計算，把整批開班者送進 Lobby\*）：
     - **按下開始到 `OnServerStarted` 之間**：Online 的 Host 維持 `Lobby`（#26 轉場屬於 Lobby → InShift 這條邊，GDD :757、:759）。Host 自身的 approval 因此一定在 `Lobby` 讀到；這個請求是 #26 的一部分，**不經 #9 列的矩陣守衛**，只跑 `ApprovalGate` 第 1–3 項。
     - **`OnServerStarted` 內**：第三道防線的那個唯一訂閱者，在 spawn `SessionRoot` 之前以 `nowMs + shift_length_sec` 寫入 `ShiftEndTs` 的初值（GDD :862 與 AC47 所說的「建立時刻」就是這一刻）；最後一個斷言通過後送 Core `HostShiftStarted`：Host `Lobby → InShift`，`HostView.ShiftEndTsMs` 自此非 null。這一步的效果不得 throw。
     - **遠端請求必定在這之後才到**：MPS 先 await handler，而 `OnServerStarted` 在 `StartHost()` 之內同步觸發（`NetworkManager.cs:1507-1530`）；MPS 之後才 `SetProperty(_session_network)` 並 `SavePropertiesAsync`（`NetworkModule.cs:303,348-359`），在那之前沒有任何 client 拿得到 join code。所以遠端請求讀到的 Host 一定是 `InShift` 或 `Settlement`，`ShiftEndTs` 也一定已經設定。非自身請求若遇到 `ShiftEndTsMs == null`，屬程式錯誤：記錄、不 throw、跳過第 4 項，不得以 0 代入。
     - **寫入配對**：#26 的 `shift_eta`（`InShift`、`shift_seq + 1`、`remaining_ms`、`published_utc_ms`）在 `OnServerStarted` 那唯一的訂閱者內以 `SetProperty` 寫入本機、不另存，由 MPS 自己那一次 `SavePropertiesAsync` 與 `_session_network` 一起送出（`SetProperty` 只改本機字典，`SavePropertiesAsync` 送出整份 `Properties`，`SessionHandler.cs:1019-1057`）。#23a 先 `SetProperty` `shift_eta(Lobby)`，再呼叫 `StopNetworkAsync`，由它移除屬性的那一次存檔一併送出（`NetworkModule.cs:702-706`）。兩組各自成為 client 端看到的同一次變更，看門狗與沙盒收場都因此有可靠的訊號；也避免兩次 `SavePropertiesAsync` 並行——那會發生什麼沒有查證。
     - **#26 中止**：`StartRelayNetworkAsync` 在 handler 成功之後才失敗時（H4），join code 從未發布，不可能有遠端 peer。轉接層完成 H4 的三個步驟後送 Core `ShiftStartAborted`：`InShift → Lobby`、清除 `ShiftEndTs`、`SetLeaveConfirmation(false)`、`shift_seq` 不前進。GDD States 沒有這條邊，交 r5（Migration 4）。在 handler 之前就失敗（allocation、join code）時，Host 仍在 `Lobby`，不需要這條邊。
     - **Solo 與沙盒**：Solo 在同一個掛點寫 `ShiftEndTs`。Lobby\* 沙盒只替沙盒自己的 `SessionRoot` 寫初值，不改等待者 Online Core 的 `SessionPhase`（仍是 `LobbyWaiting`）。
   - **加入後的版本比對**（r2 依審查新增）：私人 lobby 在加入前讀不到任何資料，加入請求送出之前沒有預檢可做；但 Lobby 期間沒有 NGO 連線，approval 要到 #26 才跑。若什麼都不做，開著舊頁的玩家可以在 2 人房占住唯一的座位、以隊友身分出現在大廳，直到 Host 按下開始上班才被拒。所以 Host 建房時以 Member 可見度發布 `build_token`（`PayloadVersion`／`ApprovalGate.ProtocolVersion`／`BuildId`），轉接層在 `JoinSessionByCodeAsync` 回傳後立刻比對：不符就顯示 `StaleBuild` 店語並 `LeaveAsync`。H2 把 NGO 通用字串暫歸 `StaleBuild` 時，也以這個比對確認。
   - **`shift_eta`：沒有 NGO 連線的端怎麼知道班次還剩多久**（r1 依 r2 E5；r2 依 r3 FV-2 補發布時刻）：Host 以 session property 發布 `shift_eta = { phase ∈ {Lobby, InShift, Settlement}, shift_seq, remaining_ms, published_utc_ms }`，可見度 **Member**（`IsPrivate = true` 之下，讀者一律是成員）。讀者計算 `remaining(now) = clamp(remaining_ms − (utc_now − published_utc_ms), 0, remaining_ms)`。r1 的「收到當下以本機時鐘錨定」只對發布當下就在線的讀者成立；而 TR-netcode-046 點名的讀者——加入後才讀到的人、Lobby\* 的等待者——都是晚到的，誤差會等於屬性的年齡，最長一整班。改用發布時刻後，誤差只剩 Host 與讀者之間的牆鐘偏差：有 NTP 的機器通常在 1 s 內，設錯的機器沒有上限，但 clamp 保證不會比發布值更長，而且這只是非權威的提示——能不能加入，一律以 approval 為準。UTC 由轉接層取（`DateTime.UtcNow`；Core 只收事件攜帶的 `utcNowMs`，不碰時鐘 API）。MPS 的 `LastUpdated` 記的是 lobby 任何變更的時刻，不能當錨點。Host 只在階段改變與 `end_shift_early` 時重發，每班 2–3 次，碰不到 UGS 限流；#26 與 #23a 那兩次和網路屬性同一次存檔送出（見上方「寫入配對」）。`shift_seq` 每次 #26 加 1，供看門狗（Decision 2）判斷「新的一班已經開始」。`phase` 回到 `Lobby`，同時是 Lobby\* 沙盒收場的訊號（Decision 10）。對應 TR-netcode-046。
   - **#9 的 UI 預檢**：私人 lobby 不能在加入前讀到任何資料，所以 `JoiningRoom` 階段沒有截止預檢可做。這不影響體驗：r2 之後，過截止的人加入後被拒，落點就是 Lobby\*，正是他該去的地方，不會「白跑一趟」。加入後，`shift_eta` 只用來顯示倒數；版本另由上方的 `build_token` 比對。GDD r5 回填這一點（Migration 4）。

6. **心跳（#20）**。
   - **載體**：`SessionRoot : NetworkBehaviour`，Host 擁有；壽命＝班次；承載 `Roster`、`ShiftEndTs` 兩個 Host 寫 NetworkVariable 與心跳 RPC。它是 Host 在 `NetworkManager.OnServerStarted` 內**第一個由轉接層 spawn 的物件**（r2 依 r3 EA-6 改述：r1 寫「啟網後第一個 `Spawn()`」，但當時 Host 的 avatar 在 `StartHost()` 同一個呼叫內就先 spawn 了，`NetworkManager.cs:1516`）。r2 的 avatar 延後到 `PlayerJoined` 才 spawn，所以在 Host 端它確實先於所有 avatar，Host 自己的 avatar 緊接其後（Decision 5 第三道防線）。晚加入者經 `ConnectionApprovedMessage` 一次收到 `SessionRoot` 與既有 avatar，同一則訊息內的先後原始碼沒追完，所以 avatar 與 HUD **不得在 `OnNetworkSpawn` 假設 `SessionRoot` 已存在**，改訂閱 `SessionRoot.OnNetworkSpawn` 發出的 ready 訊號，或讀它的現值（G2／ADR-0001 r1 的義務）。
   - **RPC**：`[Rpc(SendTo.Server, Delivery = RpcDelivery.Unreliable)] HeartbeatToHostRpc(HeartbeatWire p, RpcParams rp = default)`；`[Rpc(SendTo.SpecifiedInParams, Delivery = RpcDelivery.Unreliable, InvokePermission = RpcInvokePermission.Server)] HeartbeatToClientRpc(HeartbeatWire p, RpcParams rp)`，目標以 `RpcTarget.Single(clientId, RpcTargetUse.Temp)` 執行期定址（ADR-0002 的理由同樣適用：掛載位置不影響收件人）。**`InvokePermission = Server`**（r2 依 r3 EA-5）：`[Rpc]` 的預設是 `Everyone`（`RpcAttributes.cs:24-40,88-93`），非 server 的 client 呼叫指向其他 client 的 RPC 時，NGO 會經 Host 以 `ProxyMessage` 代轉，並把 `SenderClientId` 改寫成真正的發送者（`RpcTarget.cs:257-279`、`ProxyMessage.cs:47-70`）。所以偽造的「Host 心跳」帶的是偽造者自己的 id，r3 說的「偽裝成 Host」不成立；真正的漏洞是收端沒有檢查，任何 client 都能汙染別人的 offset 與倒數。設成 `Server` 後，NGO 在送端（拋 `RpcException`，`NetworkBehaviour.cs:331-334`）、代轉端與收端（`RpcMessages.cs:67-68`）三處擋下。不用 `RequireOwnership`：它已 `[Obsolete]`，和 `InvokePermission` 同時宣告時 ILPP 會報錯（`NetworkBehaviourILPP.cs:1710-1712`）。`HeartbeatToHostRpc` 維持預設的 `Everyone`：每個 client 都要送自己的心跳，而 `SessionRoot` 由 Host 擁有，不能設 `Owner`。
   - **Payload**（邏輯 **20 bytes**；r1 更正原寫的 16 bytes）：`ushort Seq`、`ushort LastPeerSeqSeen`、`long HostShiftEndTsMs`、`long HostNowMs`。前三個是 GDD 定案的 `{seq, last_peer_seq_seen, host_shift_end_ts}`；`HostNowMs` 是 offset 公式 `offset = host_value − (local_value + RTT/2)` 的 `host_value` 本身——沒有它公式無法成立，GDD r5 應補列。**型別分兩層**（r1 依 r2 E8）：Core 的 `HeartbeatPayload` 是純 BCL 的 `readonly struct`（`noEngineReferences` 之下不能實作 NGO 介面）；RPC 參數是轉接層的 `HeartbeatWire : INetworkSerializable`，逐欄序列化成 20 bytes。原稿把 Core 型別直接當 RPC 參數，ILPP 會在建置期報 "Don't know how to serialize"（`NetworkBehaviourILPP.cs:2654,3194`）。**不採用 `ForceNetworkSerializeByMemcpy<HeartbeatPayload>`**：它過得了 ILPP（`ForceNetworkSerializeByMemcpy.cs:10`，約束 `unmanaged, IEquatable<T>`），但 memcpy 的線上格式就是原生 struct 佈局（含 4 bytes 填充，實送 24 bytes），「兩端佈局相同」因此成了隱性前提。ADR-0005 要讓 Web（wasm32）與桌面（x64）同房，這個前提在 EditMode 裡測不到。Unreliable RPC 的參數上限是 **1296 bytes**（`NetworkMessageManager.DefaultNonFragmentedMessageMaxSize`，超過即 `OverflowException`，`NetworkBehaviour.cs:372`）；payload 日後加欄位以此為硬牆。
   - **時序**：雙方各自每 `heartbeat_interval_sec`（2 s）發一拍，每拍帶自己的 `Seq` 與「最後看到對方的 `Seq`」。Host 側判定（每個 slot 獨立）：`now − lastRx[slot] > heartbeat_timeout_sec`（8 s）→ `PeerLost(slot, HeartbeatTimeout)`；對方回報的 `LastPeerSeqSeen` 落後 Host 已送 `Seq` 超過 `heartbeat_timeout_sec / heartbeat_interval_sec`＝4 拍 → `PeerLost(slot, OneWayLoss)`（雙向存活確認，在還通的那個方向上偵測單向失效）。client 側：`now − lastRxFromHost > 8 s` → 進 #18 排歧（Decision 8）。
   - **RTT 與 offset**：client 記每個 `Seq` 的送出時刻；收到 Host 心跳時 `rtt = now − sentAt[p.LastPeerSeqSeen]`，`offset = p.HostNowMs − (now + rtt/2)` 以 EMA 平滑至 `clock_offset_tolerance_ms`（100 ms）；同一次往返供 HUD ping。顯示層 catch-up 進行中不套用新 offset（公式③）。
   - **運行範圍**：Host 自 `OnClientConnectedCallback`、client 自本機 NGO 連線建立起（只限 `NgoOwner == Online`；練習沙盒的本機 Host 不跑心跳，Decision 2「NGO 的擁有者」），到 `StopNetwork`／`ShutdownNgo` 為止——涵蓋 Onboarding、InShift、Settlement；Lobby／Lobby\* 不跑（沒有 NGO 連線）。
   - **slot 重用時重置**（r2 依 r3 FV-10）：r1 拿掉指派冷卻後，slot 回收的同一刻就可能重派。`HeartbeatMonitor` 以 slot 為鍵保存的 `Seq`、`LastPeerSeqSeen`、`lastRx`、`sentAt` 若不清，新占用者的 `LastPeerSeqSeen` 從 0 起算、Host 的 `Seq` 卻延續舊值，相差超過 4 拍就被判 `OneWayLoss`。所以第 4 步在 `SlotTable.Release(slot)` 的同一個呼叫內執行 `HeartbeatMonitor.Release(slot)`；`OnConnected(slot, nowMs)` 改為全欄重置。舊連線遲到的心跳不會汙染新人：NGO 的 clientId 在一個 session 內單調遞增、不重用（`NetworkConnectionManager.cs:350,531`），`SlotOf(舊 clientId)` 回 `NoSlot`，直接丟棄。
   - **選 Unreliable 的理由**：WSS 單一 TCP 之下 reliable／unreliable 的到達時刻無差（GDD #20 :398-406），但 unreliable 不占 UTP reliable 視窗，心跳不會與大流量搶同一個 reliable 序列而被 `NetworkSendQueueFull` 拖累（`[P-16]`）。V5 量到達分布後若需改 reliable，只改 attribute 參數。

7. **斷線處置的觸發與分工（#24／#24a；C10 邊界）**。
   - **觸發源（Host）**：心跳逾時、單向失效、`OnClientDisconnectCallback`。三者在 Core 匯流為一個 `PeerLost(slot, playerId, cause)` 效果，**冪等**：同一 slot 在同一次在線期間只執行一次，後到的觸發源被吸收——在轉接層就因 `SlotOf` 回 `NoSlot` 而被丟棄（Decision 4）。r2 補兩個守衛（`NetworkManager.cs:861,1681-1684`）：`clientId == ServerClientId` 的斷線回呼一律忽略（那是 Host 自己關機時的回呼）；`ShutdownInProgress` 為 true 時不跑本序列（那是本機 Teardown，不是 peer 掉線）。心跳觸發的序列在 `MonoBehaviour.Update` 中執行。
   - **前提**（r1 依 r2 E1；NGO 2.13.2 原始碼）。觸發源為 `OnClientDisconnectCallback` 時，NGO 在呼叫回呼**之前**就已處置該 client 的 PlayerObject 與 owned 物件（`NetworkConnectionManager.cs:1366-1420`；回呼在 :1567）：
     1. **avatar prefab 必須 `NetworkObject.DontDestroyWithOwner = true`**（預設 false）。否則 avatar 在序列開跑之前就已 despawn＋destroy。Host 端 NGO 會把子 `NetworkObject` 移到根節點（`NetworkSpawnManager.cs:1714-1760`，條件為 `IsServer || distributedAuthority`），**client 端沒有這層保護**（`OnDespawnNonAuthorityObject`，:1664-1680）：以 `Transform.SetParent` 掛在手部 socket 的道具（machine C13，`AutoObjectParentSync = false`）會跟著 avatar 一起被銷毀——**Host 還有這件道具，所有 client 都沒有了**。設為 true 後 NGO 只做 `RemoveOwnership()`，由本序列掌握順序、第 5 步顯式 despawn。可攜道具的同一設定（GDD #24 前置條件）不變。r2 補三點：NGO 的斷線處置只看 `ConnectedClients[clientId].PlayerObject` 與 `DontDestroyWithOwner`，不管 avatar 是怎麼 spawn 的，所以前提 4 的 `SpawnAsPlayerObject` 走同一個分支（`:1366-1394`）；第 5 步必須 `Despawn(destroy: true)`、**不得池化**（`NetworkSpawnManager.cs:186-194`；ADR-0003 D7「slot 重用是新 NetworkObject」靠的就是這一點，r3 CX-6）；第 5 步必須在同一個回呼鏈內**同步**完成——`RemoveOwnership` 不清 `IsPlayerObject`，這段期間若有晚加入者，它會把這具孤兒 avatar 誤認為 Host 的 PlayerObject，並把 Host 真正 avatar 的 `IsPlayerObject` 改成 false（`NetworkSpawnManager.cs:124-160`、`NetworkObject.cs:3492-3493`）。日後若加重連寬限期，不能只是把第 5 步改成非同步。
     2. **代價：Host 端那具 avatar 會短暫「變成 Host 的本機玩家」**。`RemoveOwnership()` 就是 `ChangeOwnership(obj, 0)`（`NetworkSpawnManager.cs:457-467`），它不清 `IsPlayerObject`，所以 Host 上該 avatar 的 `IsOwner` 與 `IsLocalPlayer` 都會變成 true（`NetworkObject.cs:1232,1237`），並觸發 `OnGainedOwnership`／`OnOwnershipChanged`；`NetworkTransform`（`AuthorityMode = Owner`）也改由 Host 提交。序列在同一個回呼內同步跑到第 5 步 despawn，`Update()` 看不到這個窗口，ownership 回呼看得到。**規則**：avatar 上的元件在 `OnNetworkSpawn()` 快取一次「是否為本機玩家」，之後不再以 `IsOwner`／`IsLocalPlayer` 的即時值判斷；`OnGainedOwnership`／`OnOwnershipChanged` 不得做輸入、攝影機或 HUD 綁定。這是 ADR-0001 r1 與 G2 的義務；r2 依 r3 CX-7 補上：ADR-0002 掛在 avatar 上的互動 RPC 元件、ADR-0003 的遮罩元件同樣適用。
     3. **掉落的道具在每個留守 client 上都必須存活，而且不能只靠 NetworkVariable**。心跳觸發源同樣適用：即使第 2 步在 Host 端先 unparent，`AutoObjectParentSync = false` 下這個 unparent 不會複製出去，第 5 步的 despawn 一到，client 照樣把道具一起銷毀。寫 NV 救不了它：NV 的 delta 要到下一個 network tick 才送（`NetworkBehaviourUpdater.cs:227,239-242`），一定排在 `Despawn()` 當下就入列的 `DestroyObjectMessage`（`NetworkSpawnManager.cs:1815-1826`）之後。可行的兩條路由 G2 二選一：**(a)（推薦）client 端自救**——NGO 在銷毀 GameObject 之前先呼叫 `OnNetworkDespawn()`（`NetworkSpawnManager.cs:1767` 先於 :1854，Host 與 client 皆然），avatar 在其中把手部 socket 上的道具移到根節點、保留世界座標，Host 的權威落地座標再以任何途徑校正（這時 NV 也行）。這條路不依賴訊息到達序。**(b) 先於 despawn 入列的 reliable 掉落訊息**——reliable RPC 在呼叫當下入列（`NetworkBehaviour.cs:408`），與 `DestroyObjectMessage` 同屬 `ReliableFragmentedSequenced`（`MessageDelivery.cs:37,50`），UTP 把三種 reliable delivery 都對應到同一條 pipeline（`UnityTransport.cs:690-703`），所以依序處理。但這是 NGO 的實作細節（原始碼自註 "For now"），執行期的順序還要等 ADR-0002 V③ 在 WSS 上實測（r2 依 r3 §4 改述：r1 把它當成已證實的事實），選 (b) 就得在 NGO 每次升版時重驗。本 ADR 只定契約：第 5 步之後，道具在每個 client 上都存在，且收斂到 Host 的落地座標（V12、T1 (i′)）。
     4. **avatar 延後到 `PlayerJoined` 才 spawn**（r2；arlong 2026-10-03 裁決；解 r3 CX-2、CX-3）。approval 回 `CreatePlayerObject = false`、`NetworkConfig.PlayerPrefab = null`（Decision 5）。**`PlayerJoined` 的時點分兩種**（GDD States：開班者走 Lobby →#26→ InShift，不經 Onboarding；Onboarding 只屬中途加入者，`netcode-session.md:756-759`）。Core 在 `HostShiftStarted` 時快照 `ShiftCohort = HostView.MemberIds − { Host }`，approval 指派 slot 時分兩路：**(i) 開班同批**——`PlayerId ∈ ShiftCohort`、這是它本班第一次被指派、而且該 slot 本班從未被占用：`PeerPhase` 直接設 `InShift`；Host 在該 client 的 `OnClientConnectedCallback` 送 Core `PeerConnected(slot)`，同一個 `Step` 輸出 `PlayerJoined(slot)` 與 `SpawnAvatar`。`EnableSceneManagement = false` 時，NGO 在送出 `ConnectionApprovedMessage` 的同一個呼叫內觸發這個回呼（`NetworkConnectionManager.cs:1057-1063`），所以 avatar 的生成訊息必定排在它之後；這也就是 GDD :785 的「`OnClientConnectedCallback`＝#26 轉場完成判定」。**(ii) 其餘一律當作中途加入**：`PeerPhase = Onboarding`，定長過場結束才發 `PlayerJoined`。判不準時寧可落到 (ii)：代價只是 avatar 晚 3–5 s 出現，這段時間 client 仍在 #26 轉場畫面內。「該 slot 本班從未被占用」這一條不能省：`Capacity = 4` 時，同批晚到的人可能分到剛被釋放的 slot，若直接發 `PlayerJoined`，就繞過了 Decision 4 的 3.0 s 間隔（MVP `max_players = 2` 時不會發生）。**Host 的 `local_ready`**：Host 的 avatar 在 `OnServerStarted` 就生成，比其他人早數秒；Host 的輸入要等 #26 世界語言轉場結束才開放（開班同批全數 `PlayerJoined`，或 `T_spawn` 到期），不等於自己 avatar 的 `OnNetworkSpawn`（ADR-0001 r1 與 GDD r5 的義務）。Core 在發出 `PlayerJoined(slot)` 的同一個 `Step` 內輸出 `SpawnAvatar(slot, playerId)`，轉接層依序執行：① 同步檢查 `NetworkManager.ConnectedClients.ContainsKey(clientId)`，不在就丟棄——`SpawnInternal` 不檢查 owner 是否還在線，`UpdateNetworkClientPlayer` 找不到該 id 時會 `AddClient` 把它加回去，並對所有人廣播 `ClientConnectedMessage`，而 transport 端早已沒有這條連線，產生一個永遠不會被清掉的鬼 client（`NetworkSpawnManager.cs:127-131`、`NetworkConnectionManager.cs:1239-1265`）；② `Instantiate` avatar，以 `NetworkVariable.Reset(value)` 寫入 Host 寫權的 `Slot`／`PlayerId`（直接寫 `.Value` 也能生效，但 spawn 前每寫一次就印一行不受 LogLevel 控制的警告，`NetworkVariableBase.cs:316-323`）；③ `SpawnAsPlayerObject(clientId)`。這個操作對每個 client 必須**冪等**：對同一個 clientId 再 spawn 一次，舊的那具只會被拿掉 `IsPlayerObject`、仍然存活，第 5 步卻只抓 PlayerObject，它就永遠不會被清掉（`NetworkSpawnManager.cs:134-139,159`）。待發 `PlayerJoined` 的取消由 Core 負責（Decision 3）；轉接層只靠 ① 的在線檢查兜底。效果：avatar 的 spawn／despawn 成為各端「在場」的訊號，而且依序到達（Decision 13 的分端來源表）；Onboarding 期間任何一端都沒有這具身體，`PairMachine` 與遮罩自然看不到它。代價也一併登記為 G2／ADR-0001 r1 的義務：攝影機、HUD、輸入的綁定改掛在 avatar 的 `OnNetworkSpawn`（以 `IsLocalPlayer` 判斷），不掛在 `OnClientConnectedCallback`（那時 `PlayerObject` 還是 null）；avatar 的 `OnNetworkSpawn` 不得讀 `LocalClient.PlayerObject`（它在 `OnNetworkSpawn` 之後才指派，`NetworkSpawnManager.cs:1295,1299`）；不得依賴 `OnNetworkSessionSynchronized`——延後 spawn 的 avatar 收不到它（`NetworkSpawnManager.cs:2316-2324`；只有晚加入者在 `ConnectionApprovedMessage` 內一次收到的既有物件會收到，`ConnectionApprovedMessage.cs:343-363`）。
   - **轉接層 `DisconnectSequencer`** 依固定優先序呼叫 `IDisconnectParticipant.OnPeerLost(in PeerLostContext ctx)`，全序列在同一幀同步完成，上限 `disconnect_cleanup_sec`（2 s）。第 6 步的服務呼叫不阻塞序列，但必須以 `try { await … } catch` 包住：`RemovePlayerAsync` 與 `AsHost()` 的包裝層會**同步**拋出 `NotAuthorized`／`NotInLobby`／`Forbidden`，寫成 `_ = …` 時這些例外會直接逸出、打斷序列（`LobbyHandler.cs:682-701,933-955`、`SessionHandler.cs:873-881`）。

   | 序 | 優先序常數 | 誰 | 做什麼 |
   |---|---|---|---|
   | 1 | `FreezeInput = 0` | ADR-0001 轉接層 | 停止採納該 slot 的 NetworkTransform 更新（已被判離線的角色不得再動） |
   | 2 | `DropHeldItems = 10` | G2 | 手持物 unparent、落地座標、`RemoveOwnership()`（道具與 avatar 皆 `DontDestroyWithOwner = true` 為前提）；道具在每個 client 上必須存活（前提 3） |
   | 3 | `ReleaseClaims = 20` | ADR-0004 | 站台**只釋放 claim**、`ClaimGeneration + 1`；不判 `Failed`（C10） |
   | 4 | `Roster = 30` | 本 ADR | `Roster[slot].Online = false`、slot 回收、`HeartbeatMonitor.Release(slot)`（Decision 6，r2）、`PlayerLeft(slot)` |
   | 5 | `DespawnAvatar = 40` | G2 | `Despawn(destroy: true)` 該玩家的 avatar，同步完成、不池化（前提 1，r2）；Onboarding 期間不做事（沒有 avatar；待發的 `PlayerJoined` 已由 Core 取消） |
   | 5a | `DisconnectTransport = 45` | 本 ADR | cause 不是 `TransportDisconnect` 時（心跳逾時、單向失效、`LeaveRequested`）呼叫 `NetworkManager.DisconnectClient(clientId, reason)`，**reason 必須非空**（＝`PeerLostCause` 名）。非空時 NGO 先送 `DisconnectReasonMessage`、把斷線排進延後佇列，不在本幀重入序列；空字串或 `null` 會同步斷線、在本幀重入（`NetworkConnectionManager.cs:917-931`）。⚠ 單參數多載 `DisconnectClient(clientId)` 會自動補一個非空 reason（`NetworkManager.cs:1570`），`DisconnectClient(clientId, null)` 卻是同步的——一律顯式傳；r2 起單參數多載也禁用（registry `disconnectclient_without_reason`），它的通用字串保留給第 0 層雜湊閘的辨識（Decision 5）。不切的話，該 client 在 NGO 層仍是 connected client 與 observer，直到 UTP `DisconnectTimeoutMS`（30 s）；這段期間它送來的 RPC 照常被處理（`NetworkConnectionManager.cs:588-603`）（r1 依 r2 E6） |
   | 6 | `ReleaseMembership = 50` | 本 ADR | `await session.AsHost().RemovePlayerAsync(playerId)`（Host 唯一寫入者）。成員若已被它自己的離開通知移除，SDK 會在最內層吞掉 `PlayerNotFound`（`WrappedLobbyService.cs:342-346`），不會拋到這裡——r3 EA-8 只看了 `LobbyHandler` 那一層，前提有誤（r2 更正）。`SessionNotFound`（lobby 已不存在）、`NotInLobby` 視為完成；其餘錯誤記 log、不重試、不阻塞 Core，由服務端回收兜底 |
   | 7 | `Resample = 60` | 本 ADR | `online_player_count` 重取樣、grace／`host_solo` 旗標、#15a 計數 +1 → 波次導演 |

   參與者以優先序註冊（DI），Core 不知道參與者是誰；本 ADR 只擁有第 1 步的**觸發**與第 4／5a／6／7 步的**內容**，第 2／3／5 步的語意分別歸 G2 與 ADR-0004。`PeerLostContext` 帶 `PeerPhase Phase`：`Phase == Onboarding` 時第 1、2、3、5、7 步不做事，第 4 步只釋放 slot、不發 `PlayerLeft`；`Phase == Settlement` 時第 1、2、3、7 步不做事，第 4 步照發 `PlayerLeft`、不計 #15a（Decision 3，r2 依 r3 FV-8）。第 4 步（`Roster`）與第 5 步（`DespawnAvatar`）之間不得插入會轉移 Host 所擁有物件的參與者：`ChangeOwnership` 在原 owner 是 Host 時會強制送出**所有** dirty 的 NV（`NetworkSpawnManager.cs:594-597`、`NetworkObject.cs:3027-3035`），`Roster` 的 delta 會跑到 `DestroyObjectMessage` 前面。不過任何設計都不准依賴這兩者的相對順序（Decision 13）。
   - **Host 自己消失**：無人執行本序列；服務端回收（Relay 每 client TTL 10 s、MPS lobby heartbeat 逾時 ≈ 132 s）。MVP 接受，見 Decision 11。

8. **Host 消失排歧（#18）與 Lobby 偵測（#25）**。Core `HostLossDisambiguator.Decide(in HostLossSignals s)` 實作 GDD 六列優先表，第一個命中即定案；輸入由轉接層採樣：MPS 事件（序 1：`Deleted`／`SessionHostChanged`／`PlayerLeaving(host)`／`PlayerHasLeft(host)`）、`IPageLifecycle.IsOnline`（序 2，`false` 才算證據）、`session.HasPlayer(session.Host)`（序 3／4）、`session.State == Disconnected` 或查詢拋錯（序 5）。三個結論（`HostGone`／`SelfOffline`／`Undetermined`）都走 Teardown，差別只在店語。若心跳空窗期間曾背景化，一律優先走 #17 的背景分流，不進本表。Lobby／Lobby\*：進入時訂閱同一組 `ISession` 事件，收到 Host 對應事件即 `HostGone`；另以 Core 計時器自最後一次 session 事件起算 `lobby_host_silence_timeout_sec`（30 s）顯示靜默提示＋離開鈕，**不等服務端**（arlong 2026-09-13 裁決）。
   - **token 遺失是一條進 `Idle` 的邊**（r2 新增）：Authentication 續發遇到網路錯誤或空回應時每 30 s 重試，一路失敗到 `exp − 15 s` 才清掉 token；續發被服務端拒絕（`RequestFailedException`）時則**立刻** `Expire()`。兩條路都清 token，並發公開事件 `Expired`（`AuthenticationServiceInternal.cs:359-405,507-541`；15 s／30 s 定義在 `AuthenticationSettings.cs:6-7`）。token 變 null 時，MPS 會把 lobby 狀態重置、把 session 設為 `SessionState.None`，但**不發** `Deleted`／`RemovedFromSession`，session 也不會從 `MultiplayerService.Sessions` 移除（`LobbyHandler.cs:962-967`、`SessionHandler.cs:1145-1156,1206-1217`、`SessionManager.cs:306-307,429-441`）。NGO 是否被拆取決於事件時序：`LobbyHandler.ResetAsync` 若在 `SessionHandler` 設 `None` 之前就同步跑完，`Changed` 會讓 `NetworkModule` 因 `!IsMember` 走 `ResetAsync` → `StopAsync`（`NetworkModule.cs:132-140`）；否則 NGO 照跑。兩種結果都可能出現，所以 session 至少會變成殭屍，NGO 則不一定還在。所以轉接層訂閱 `AuthenticationService.Expired` 與 `ISession.StateChanged → None`，Core 輸出 Teardown（店語同「跟店裡斷線了」）；Teardown 要自己 `Shutdown()` NGO，不能指望 MPS（H5 冪等，兩種情況都安全）。之後的 `LeaveAsync` 會拋 `InvalidOperation`，屬預期。殭屍 session 還占著舊的 Type，下一次建房或加入本來就用新的 `SessionOptions.Type`（Decision 2 的通則）。不得以 `SignedIn` 當作「已復原」：背景分頁恢復時，refresh 與 expiration 可能落在同一個 tick，token 先被清掉、隨後 refresh 成功又發 `SignedIn`，這時 session 已經是殭屍了。

9. **Teardown 不變式（#17a）與離開通知（#12）**（r2 依 r3 FV-4、EA-1、FV-6／CX-5、EA-3／FV-7 改寫）。
   - **Teardown**：Core 在每一條進 `Idle` 的邊上輸出**恰好一個** `Teardown` 效果（#17 的 > 5 s 分支、#18 三個結論、玩家主動離開、Onboarding 期間自身斷線、token 遺失）。轉接層的執行順序固定：
     1. `IUnloadNotifier.SetLeaveConfirmation(false)`。
     2. NGO 在跑（`IsListening`）才呼叫 `NetworkManager.Shutdown()`。它**只設旗標**，真正的拆除在 PostLateUpdate：client 與沒有 peer 的 Host 在同一幀完成；有 peer 的 Host 在第 N 幀送出斷線原因，第 N+1 幀才拆，最多等 5 s（`NetworkManager.cs:509-520,547-593,1590-1604`）。完成的訊號是 `OnServerStopped`／`OnClientStopped`，NGO 原本就沒在跑時則不會有任何事件（r1 寫的「同步、2 ms 回傳」，2 ms 只是這個呼叫本身花的時間，80 ms 是對端收到的時間）。
     3. client 呼叫 `session.LeaveAsync()`，Host 呼叫 `session.AsHost().DeleteAsync()`。Host 不得改用 `LeaveAsync`：player-host 的 `IsServer` 為 false，`LeaveAsync` 走的是 `RemovePlayer(自己)`，不會刪房（`SessionHandler.cs:785-824`、`LobbyHandler.cs:156`）。**例外**：被判 `Duplicate` 的分頁不 leave、不 delete——兩個分頁共用同一筆成員資格（Decision 2）——只做第 5 步的退訂；舊 session 留在 `MultiplayerService.Sessions`，下一次建房或加入本來就用新的 `SessionOptions.Type`。這兩個呼叫 best-effort，以 `try { await … } catch` 包住、不擋 UI。MPS 會在其中呼叫 `SessionNetworkHandler.StopAsync`（H5，冪等）。GDD 寫的 `LeaveSessionAsync` 在 2.3.1 不存在，GDD r5 改名。
     4. 上一步的 Task 結束時（成功或失敗；沒有 session 就立刻），把這次 Teardown 的 `leaveTaskEnded` 設為 true，並立即重算一次 `LeaveBeaconPlan`（它隨之回 false，轉接層 `ClearLeaveBeacon()`）。不在 Teardown 第一步就清，是因為 SDK 的 leave 送出之前玩家若剛好關掉分頁，keepalive 還能補上這一筆；兩筆都送到也無害，服務端的效果本來就冪等。`InstallLeaveBeacon`／`ClearLeaveBeacon` **只准由這條宣告式規則呼叫**，「上次結果」的快取也只由它更新，而且計畫綁定 session 世代——直接呼叫 `ClearLeaveBeacon()` 的話，舊 Teardown 的 leave 若在新房裝好通知之後才結束，會把新房的通知清掉，而「結果和上次不同才重裝」讓它再也裝不回來。
     5. 解除對舊 `ISession` 的所有訂閱。`SessionHandler` 從不退訂 `AccessTokenChanged`（`SessionHandler.cs:736`），舊 session 物件日後仍可能發出幽靈 `StateChanged`。
     6. 切 UI。
     - r1 說先 `Shutdown()` 再 `LeaveAsync()` 會印出 MPS 警告 "Do not call NetworkManager.Shutdown when using a session"，而且「這是預期的」（r1 E13）。r2 刪除這段：那條警告出自預設 handler 的 `NetworkManagerSession`（`:411-430`），本 ADR 的自有 handler 取代了它，警告從此不會出現。就算還用預設 handler，常見路徑走的也是 `TrySetException` 分支，根本不印（r3 FV-7）。順序本身維持不變：先 `Shutdown()`，因為它在同一幀就讓對端得知。
   - **離開通知的送出點：只有 `pagehide`**（r2 依 r3 FV-4，arlong 2026-10-03 裁決）。依 HTML 規範，關閉分頁時會先對整棵框架樹（含跨源 iframe）派發 `beforeunload`，若有人要求確認就先問使用者；使用者按「留下」，演算法直接返回，`pagehide` 根本不會觸發（§7.3.1.6、§7.4.2.4、§7.5.9）。r1 的「`pagehide`（主）＋`beforeunload`（備援）＋單發旗標」實際上是由 `beforeunload` 送出，所以 Host 一掛確認框，`DELETE` 就會在玩家決定之前送出去，按「留下」時房間已經被刪了。r2 的規則：
     - `pagehide` 是唯一的送出點，**不分 `persisted`**。Chrome 149 起（release notes："Active WebSocket connections no longer prevent a page from entering the Back/Forward Cache"；WPT `back-forward-cache-closes-open-websocket-connection` 在 Chrome 154 通過）與 Safari（WebKit bug 143505：進 page cache 時關閉 WebSocket；WPT 在 Safari 27 通過）會在頁面進入 bfcache 時主動關閉 WebSocket；Firefox 則是有 WebSocket 就不進 bfcache（同一組 WPT 在 Firefox 157 走舊行為）。有第三方回報 Chrome 150 的乾淨 profile 仍不進 bfcache，疑為分批開放，T1-Web (l4) 實測。無論哪一種，NGO 與 Wire 的連線都已經斷了；`persisted = true` 只表示頁面「可能」被重用，之後若被逐出，不會再有任何事件，這時不送就永遠沒人送。`.jslib` 的單發旗標只用來擋「bfcache 往返後的第二次 `pagehide`」。這一點推翻 r3 FV-4 Resolution 的第二點。
     - `beforeunload` **永不送出**，只用來掛確認框：Host 進 `InShift` 時 `SetLeaveConfirmation(true)`，離開 `InShift`（進 Settlement 或任何 Teardown）時 `SetLeaveConfirmation(false)`；client 永不掛（GDD AC42）。是否真的跳框由瀏覽器決定：iframe 本身要有 sticky activation（在遊戲畫面裡點擊過）。Chrome 與 Firefox 在 itch.io 的跨源 iframe 內會跳框（Blink `document.cc` 只看該 frame 的 activation；Gecko `nsDocumentViewer.cpp` 走訪整棵樹）。WebKit 則明確擋下「與祖先不同源的 frame」所要求的確認框（`FrameLoader.cpp`），所以 Safari 在 itch.io 上永遠不跳框——這是瀏覽器政策，不是缺陷；`pagehide` 送出不受影響。AC42 只要求桌面 Chrome，GDD r5 補註 Safari。
     - `pageshow` 收到 `persisted = true`（從 bfcache 恢復）時，`.jslib` 先觸發 ADR-0005 的 `RestoredFromBackForwardCache`（只供記錄與測試），隨即自行 `location.reload()` 重載 iframe：WebSocket 已被瀏覽器關閉、`DELETE` 已經送出。重載在 `.jslib` 內完成，C# 端沒有、也不需要重載的介面；轉接層不得嘗試續連。
     - `visibilitychange → hidden` 不得作為送出點：背景≠離開（AC34a／b：Lobby 背景 30 s／120 s 不掉房）。行動瀏覽器關分頁時多半不觸發 `pagehide`，所以行動端接受退化路徑：Lobby 由約 132 s 的服務端回收，加上 30 s 本地提示保底；InShift 由 8 s 心跳接手。
   - **端點**（r2 依 r3 EA-1 更正）：base 為常數 `LobbyRestBase = "https://lobby.services.api.unity.com/v1"`，取自 MPS 2.3.1 `InternalLobbyService.cs:57`。只有 Unity 內部的 cloud-environment 旗標等於 `staging` 時，SDK 才會改用 lobby-stg，本作不支援。UGS 的 environment 名稱（production／development）不影響 URL，也不加任何標頭：environment 在登入時就編進 token 的 audience（`AuthenticationNetworkClient.cs:213-219`、`AuthenticationServiceInternal.cs:431-434`），所以 JS 端用同一顆 token 打 REST，自然落在同一個 environment。SDK 的 base path 沒有公開 getter，因此加一條 PlayMode 守門測試：以反射讀 `LobbyService.Instance → m_LobbyService → Configuration.BasePath`，斷言等於常數，MPS 升版必跑；正式碼不呼叫 `SetBasePath`。
     - Host：`DELETE {LobbyRestBase}/{session.Id}`；client：`DELETE {LobbyRestBase}/{session.Id}/players/{AuthenticationService.Instance.PlayerId}`（`LobbyApiRequests.cs:705,760,2097`；`session.Id ≡ Lobby.Id`，`SessionHandler.cs:1065`）。r1 寫的 `lobbies/{id}` 多了一段，照寫只會拿到 404。兩個 id 都不跳脫，與 SDK 一致。
     - 只帶 `Authorization: Bearer <AccessToken>`：無 body、不設 `Content-Type`、不加 `Unity-Client-*`（SDK 原始碼註明是 analytics 用途，`LobbyApiRequests.cs:744-746`），`credentials` 維持預設、不得設成 `include`。UGS 的 preflight 回 `Access-Control-Allow-Origin: *`、允許 `DELETE` 與 `authorization`（V10）。
     - 回應的判讀規則（unload 期間沒人讀回應，這組規則給 T1-Web 的 dry-run 斷言用）：只有 204 算成功。404 只有在 problem+json 的 `code` 為 16001（刪房），或 16002／16001（退出）時，才算「效果已達成」；沒有 body 的 404、或其他 `code`，代表路徑寫錯，判失敗。401、403、429、5xx 都判失敗。r1 的「第二次的 404 視為成功」刪除：只掛 `pagehide` 一個監聽器之後，正式路徑不會有第二筆。
   - **token 保鮮：一條宣告式規則**（r2 依 r3 FV-6／CX-5）。Core 提供純函式 `LeaveBeaconPlan.TryFor(mode, isHost, isDuplicateTab, leaveTaskEnded, sessionId, playerId, accessToken, out url, out method, out authorization)`，回 false 就是沒有計畫。轉接層在每次階段變更時、以及每 `leave_beacon_refresh_ms` 重算一次；結果和上次不同才呼叫 `InstallLeaveBeacon`，回 false 就呼叫 `ClearLeaveBeacon()`。`authorization` 是完整的標頭值、含 `Bearer ` 前綴，`.jslib` 原樣放進 `Authorization` 標頭。這一條規則同時涵蓋：
     - 安裝時點：Host 在 `CreateSessionAsync` 回傳後，client 在 `JoinSessionByCodeAsync` 回傳後（含 Lobby\*；被判 `Duplicate` 的分頁除外，Decision 2）。
     - 續發後重裝：token 在 `exp − 300 s` 續發（300 s 定義在 `AuthenticationSettings.cs:5`，排程見 `AuthenticationServiceInternal.cs:442-454`），舊 token 到 `exp` 之前都有效，所以在 Unity 主迴圈還在跑的前提下（背景分頁的 1 Hz 也可以），任何短於 300 s 的週期都能讓裝著的 token 保持有效。SDK 續發與本規則都靠主迴圈驅動；分頁被凍結超過 token 剩餘效期時，`pagehide` 送出的是過期 token、得到 401，退化為 132 s／8 s，MVP 接受（推論，T1-Web 記錄回應碼）。續發時公開事件 `SignedIn` 不會觸發（`:573-577`），不能拿它當訊號。
     - token 遺失時清除；Teardown 時在 leave 的 Task 結束後清除；Solo 與被判 `Duplicate` 的分頁一律沒有計畫。
     - 不採用 `IAccessTokenObserver`：它在 `Unity.Services.Authentication.Internal` 命名空間，要手動引用 `autoReferenced = false` 的 `Unity.Services.Core.Internal` 組件，而且沒有穩定性承諾（見 Alternatives）。
   - **桌面**：`QuitRequested` → 同一個 Teardown 序列 → 等兩個條件都成立：NGO 已停（stopped 事件已觸發，或 `!IsListening`），且 leave／delete 的 **Task 已完成**；或 1 s 逾時 → `CompleteQuit()`（ADR-0005 r2）。不得以 `ISession.State` 判斷完成：Host 的 `DeleteAsync` 在送出刪房請求**之前**就把 State 設為 `Disconnected`（`SessionHandler.cs:901-903`），以 State 判斷會在 DELETE 送出前就退出。反過來，State 一離開 `Connected`，MPS 的 `OnQuitting` 就直接返回（`:1224-1229`），所以 Host 刪房與 MPS 的 remove-self 並行，只可能發生在 `DeleteAsync` 開始之前——Teardown 一開始就呼叫 `DeleteAsync`，這個窗口極小。逾時先到時，進行中的 `DELETE` 可能隨行程結束而中斷，退化為服務端約 132 s 回收；client 已經由 NGO 斷線得知 Host 離開。本 ADR 不依賴 MPS 在退出時自動 leave。
   - 這條路徑繞過 Sessions SDK、直打 UGS Lobby REST：「session id ＝ lobby id、REST 路徑、Bearer 授權」三件事都沒有編譯期保護，MPS 升版時必重驗 V10，並重跑反射守門測試。

10. **單人練習（Solo）＝同一條 NGO 路徑，零服務依賴**（OQ#4 裁決）。`SessionMode.Solo` 時 Session 層不存在（不呼叫 `UnityServices.InitializeAsync`、不登入、不配 Relay）；Connection 層以 NGO 內建的 **`SinglePlayerTransport`**（`Unity.Netcode.Transports.SinglePlayer`，NGO 2.4.0 起）啟 `StartHost()`。r1 依 r2 E3 以它取代原稿手刻的 `OfflineTransport`：官方版由 NGO 團隊維護、隨版本演進，2.13.1 起並附官方切換範例（`Documentation~/advanced-topics/singleplayer.md`）。它只能以 Host 啟動（`StartClient()` 回 false 並報錯）；Host 本機的 approval、連線、spawn 與 RPC 本來就不經 transport（`NetworkManager.cs:1501-1537`）。
   - **兩個 transport 元件並存，只切指派**（r1 刪除原稿「兩者不得同時存在於同一個 NetworkManager」——與官方範例相反）：NetworkManager 物件上同時掛 `UnityTransport` 與 `SinglePlayerTransport`。**切換時機**（r2 依 r3 EA-3 改寫；r3 修法提到的 `NetworkManager.OnStopped` 是 internal 事件，`NetworkManager.cs:937`，用不了）：
     - `UseSinglePlayer`：前置條件是 `!IsListening && !ShutdownInProgress`，而且距上一次 stopped 事件至少 1 幀；條件成立後緊接著呼叫 `StartHost()`。這與官方範例一致：每次 Start 之前才指派，關機時不改回（`SinglePlayerSessions.cs:39-65`）。`StartHost()` 若回 false，當場 `UseUnityTransport`：有些失敗路徑會先清掉角色再關機，`OnServerStopped` 不會觸發（`NetworkConnectionManager.cs:709-721`）。
     - `UseUnityTransport`：掛在 `OnServerStopped`（public，觸發時 `IsListening` 已為 false、transport 已關，`NetworkManager.cs:1677-1720`），而且只在當前指派是 `SinglePlayerTransport` 時才換。退出程式時，NGO 的 `OnApplicationQuit` 會同步跑 `ShutdownInternal`，同一個訂閱者照樣觸發。stopped 回呼的訂閱者不得 throw：Host 會先觸發 `OnClientStopped(true)` 再觸發 `OnServerStopped(true)`，兩者都沒有例外保護，前一個訂閱者一旦拋例外，後一個就不會觸發；而且在 `StartHost` 的失敗路徑上，拋例外會讓 `StartHost` 改成拋出，而不是回 false。
     - **不變式：NGO 閒置 ⇒ 指派的一定是 `UnityTransport`**。`IsListening || ShutdownInProgress` 期間禁止改指派；UI 的「單人練習」在這段期間不可按。r1 的「`Shutdown()` 之後立刻指回」刪除：`Shutdown()` 只設旗標，拆網窗口內 NGO 有些路徑讀的是**當前**指派（EarlyUpdate、PostLateUpdate、關機時的 `transport.Shutdown()`，`NetworkManager.cs:356,489`、`NetworkConnectionManager.cs:1746-1765`），有些讀 Initialize 時**快取**的那一個（`:447,1657`）。這時改指派，UTP 的 driver 與 Relay 連線會洩漏，而且窗口內若有 MPS 啟網，會被誤判為已經 listening 而回報成功（`NetworkManagerSession.cs:148-152`）。
     - 漏掉指回的後果不變：下一次上線時 MPS（或本 ADR 的 handler）以 `as UnityTransport` 取不到 transport。r2 由 handler 的閘門（Decision 2 H1 ③）在每次 client 啟網前斷言，Host 端在呼叫 `StartRelayNetworkAsync` 之前也斷言一次，所以不會再落進「失敗不重試」而靜默錯過整班。
   - `SessionRoot`、approval（slot 0；`HostView.MemberIds = { 本機 PlayerId }`，見 Decision 5）、`ShiftEndTs`、Settlement 全部照常；心跳沒有 peer 就不發。`ServiceError → 放棄 → Idle` 後 Solo 仍可玩（TR-netcode-039）。
   - **Lobby\* 等待沙盒走同一條 Solo 路徑，但用獨立的 Core**（r2 依審查補）：沙盒以另一台 `SessionMachine(cfg, SessionMode.Solo, isHost: true)` 運行，與停在 `LobbyWaiting` 的 Online client Core 互不相通；`NgoBridge` 依 `NgoOwner` 路由（Decision 2「NGO 的擁有者」）。沙盒期間 Online Core 不接收任何 NGO 回呼、avatar spawn／despawn、`SessionRoot.Ready`，也不啟動 client 心跳——沙盒 Host 自己就會觸發 `OnServerStarted` 與 `OnClientConnectedCallback(0)`（`NetworkManager.cs:1530,1537`），本機 avatar 的 `OnNetworkSpawn` 也帶 `IsLocalPlayer`，若被 Online Core 收到，Decision 13 會把它讀成「進 InShift」，client 心跳 8 s 後就走 #18 而 Teardown。MPS 成員資格保留（r2：handler 被拒時不 throw，Decision 2），沙盒不共享任何狀態。前一班結束的訊號一到——Host 在 #23a 把 `shift_eta.phase` 改回 `Lobby`（與屬性移除同一次存檔，Decision 5），或 handler 的 `StartAsync` 被呼叫（屬性合併時 client 可能看不到 Lobby 那一筆，Decision 2 H1 ②）——Online Core 即輸出 `AbortSandbox` → `Shutdown()` → `OnServerStopped` → 指回 `UnityTransport` → 合流進 Lobby，可中斷、不延遲。**r1 的自動加入競態（E11／V11）由排序消除**（r2）：下一班 Host #26 寫入新屬性時，MPS 呼叫的是本 ADR 的 handler；它的閘門會先收掉沙盒、確認 transport 已指回，才 `StartClient()`（Decision 2 H1 ②③），不會撞上還在跑的沙盒 Host。剩下的風險是班次交界的屬性合併（V11 改寫），由看門狗與 Host 端的 `min_lobby_dwell_ms` 處理。forbidden pattern `lobby_with_live_relay` 的措辭補上一個例外：因 approval 被拒而進 Lobby\* 的一端，MPS 網路模組仍報 `Started`，並在帳面上保留那筆已斷線的 join allocation，直到 Host #23a 移除網路屬性（`NetworkModule.cs:470-477,720-735`）——這不是連線，不得據此判斷有無連線。
   - Solo 不計 Relay 額度、不受 UGS 429 影響，機台、NPC、RPC、NetworkVariable 不需要第二條程式路徑。V3 驗 WebGL IL2CPP 下的 `SinglePlayerTransport`。

11. **MVP 無 host migration（OQ#18 裁決），明文保留擴充點**。#12「房主關頁＝本局結束」不變。`ISession.SessionMigrated`、`IClientSessionNetwork.MigrationFailed` 與 `IHostSessionNetwork.MigrationFailed`（兩者皆 `:29`；r1 補 Host 側）、`NetworkState.Migrating` 在 MVP **一律映射為 `HostGone`** 走 Teardown，不得靜默忽略。日後啟用 migration 的三項前提，各自需要別的 ADR 先落地：① Host 權威狀態（NPC 狀態機、波次、計分、claim、`ShiftEndTs`）全部可序列化為 `HostMigrationData`（G2 的 spawn 契約）；② Relay 重配＋全員重連的時間預算與 Lobby\* 合流規則（本 ADR 的狀態機要加 `Migrating` 態）；③ 時鐘真相接管（新 Host 的 `HostNowMs` 基準補償，G9）。#28 已指出 migration 的一個真實用途：讓離多數玩家近的人當 Host。

12. **UTP 與 NGO 常數契約（TR-netcode-021／018）**。所有值由 Core 的 `SessionConfig` 提供，EditMode `EngineFactProbeTests` 續用為「引擎值仍如此」的斷言，建置期斷言「專案值已套用」。**設定分兩層**（r2 依 r3 FV-5：r1 把 ScriptableObject 放進 `noEngineReferences` 的 `Session.Core`，照寫會編譯失敗）：Core 的 `SessionConfig` 是純 C# `sealed class`，以 readonly 欄位加建構子組成，`Validate()` 也住在 Core，並提供 `static SessionConfig Default`（自 registry 常數生成）；`Session.Unity` 另設 `SessionConfigAsset : ScriptableObject`（`[SerializeField] private` 欄位，符合 6.3「只能標在欄位上」的規則），以 `ToCore()` 轉成 Core 型別。建置期斷言放在 Editor 專用組件 `NightShift.Session.Editor`（asmdef `includePlatforms: [Editor]`）：以 `IPreprocessBuildWithReport` 斷言 `ToCore().Validate()` 為空、專案值已套用到 `UnityTransport` 與 `NetworkConfig`。`IPreprocessBuildWithReport` 在 `UnityEditor.Build` 命名空間，放進 runtime 組件會讓 player build 失敗——與 FV-5 同類的坑。這和 `HeartbeatPayload`／`HeartbeatWire` 是同一族的兩層型別：Core 純值、轉接層持有引擎型別。

   | 欄位 | 值 | 理由 |
   |---|---|---|
   | `UnityTransport.HeartbeatTimeoutMS` | **500（不得動）** | 兼 Relay PING 間隔；> 10 s 即被 Relay 踢（`multiplayer.md:107-109`） |
   | `UnityTransport.DisconnectTimeoutMS` | 30000（維持預設） | ≥ 8 s 讓 app 心跳是先判定者（約束⑤）；調小會縮 send queue 容量 |
   | `UnityTransport.ConnectTimeoutMS` × `MaxConnectAttempts` | 1000 × **10** | 連線階段總逾時由預設 60 s 調為 10 s＝`T_spawn` 閘門，失敗即早可見（V4） |
   | `UnityTransport.MaxSendQueueSize` | 顯式設定，值由 `[P-16]`（W2）定 | 預設由 `DisconnectTimeoutMS` 推算；Host 出站 payload 上限與佇列深度監控點必備（V6） |
   | `NetworkConfig.ClientConnectionBufferTimeout` | 10（維持預設） | approval 為純函式，遠在其內 |
   | `NetworkConfig.TickRate` | 10 | 本 ADR 擁有（r2 依 r3 CX-4；ADR-0001 r1 引用）；在連線雜湊裡，跨平台同房兩端必須一致 |
   | `NetworkConfig.EnableSceneManagement` | false | 單一場景；不一致則握手失敗 |
   | `NetworkConfig.ConnectionApproval` | true | Decision 5 |
   | `NetworkConfig.PlayerPrefab` | **null**（r2） | avatar 只登記在 NetworkPrefabsList，由轉接層在 `PlayerJoined` 時 `SpawnAsPlayerObject`；非 null 時，任何沒呼叫 approval callback 的路徑都會讓 NGO 自動建 avatar（Decision 5、Decision 7 前提 4） |
   | `NetworkConfig.ProtocolVersion` | **0**（r2） | 與 `ApprovalGate.ProtocolVersion` 無關；設成我們的協定版本只會讓店語變模糊（Decision 5） |
   | `NetworkConfig.ForceSamePrefabs` | true（維持預設，r2 明列） | prefab 清單在連線雜湊裡，第 0 層硬閘（Decision 5） |
   | `UnityTransport.UseWebSockets` | true（**擁有者是 ADR-0005 Decision 6**，列在這裡只為了建置期斷言） | Editor 與桌面沒勾時，NGO 內附的 UTP 轉接器先記 LogError、改用 UDP 介面建 driver（NGO `UnityTransport.cs:1866-1890`），接著 UTP 2.7.4 的 `NetworkDriver.Create` 因 Relay 資料是 WSS 而拋 `Mismatched Relay configuration and network interface`（`com.unity.transport` `NetworkDriver.cs:518-529`），`StartHost`／`StartClient` 回 false；WebGL player 會自動退用 WebSocket |
   | 心跳／截止／寬限等 GDD 常數 | 依 Tuning Knobs | 可機械驗證的 11 條約束（①②③⑤⑥⑦⑨⑩⑪⑫⑬）以 `SessionConfig.Validate()` 檢查，非法組態在 EditMode 與建置期 fail（TR-netcode-041）。④（情境分析）、⑧（架構規則＋執行期 RTT）、⑭（AC 撰寫規則）、⑮（執行期 RTT／region 模型）不是組態不等式，交 T1／T3 與 code review（r1 依 r2 E9）。r2 新增三個旋鈕：`min_lobby_dwell_ms`（#23a 存檔完成到允許 #26 的最短間隔；下限是一次 `JoinSessionByCodeAsync` 的實測 P95，初值由 V11 定）、`network_join_watchdog_ms`（看門狗等待 handler 被呼叫的上限，初值 `T_spawn`）、`leave_beacon_refresh_ms`（離開通知重算週期，1000）。`Validate()` 因此檢查 **12 條**：GDD 的 11 條，加上 r2 的 `leave_beacon_refresh_ms < AccessTokenRefreshBuffer × 1000`（＝300 000，`AuthenticationSettings.cs:5`；超過時裝著的 token 可能已經過期）。`SessionConfig` 另含 `MaxPlayers`（＝`max_players`，Decision 2） |

13. **班次時鐘真相與 Session 層對外事件（TR-netcode-036／012／045）**。`SessionRoot.ShiftEndTs`（Host 寫 `NetworkVariable<long>`，單位 ms，Host 單調時鐘基準）是班次剩餘的唯一真相；`end_shift_early` 直接改寫它；所有「剩餘」的權威判定在 Host，client 的倒數是套用 offset 後的估計。對外事件採 GDD 契約表（:795-809）的名稱，C# 只改 PascalCase：`PlayerJoined(slot, playerId)`、`PlayerLeft(slot, playerId)`、`PlayerDisconnected(slot, playerId, heldItems)`（＝`PeerLost` 給 G2／ADR-0004 的面）、`OnlinePlayerCountChanged(count, graceActive, hostSolo)`、`ConnectionStateChanged(ConnectionState)`、`RoomCodeAvailable(code)`、`SessionStarted`、`RosterUpdated`、`FinalRoster`／`DisconnectLog`。`ConnectionState` 枚舉是給 UI 的**唯一**連線狀態來源，店語字串表 data-driven、禁技術詞（TR-netcode-045）。
   - **事件的分端來源**（r2 依 r3 CX-2 新增）：`PlayerJoined`／`PlayerLeft` 是 Host Core 的事件，`SlotTable` 也只在 Host；非 Host 端收不到它們。r1 要求每個擁有者端「在收到 `PlayerLeft(slot)` 時」清遮罩，非 Host 端因此永遠不清，同 slot 的新玩家一進場就會被全場穿過（AC19 的症狀）。r2 規定各端的來源如下（NGO 2.13.2 原始碼，V14 實測順序）。下表只適用於 `NgoOwner == Online` 的 NGO；練習沙盒的事件只進沙盒自己的 Core（Decision 2、10）：

     | 事件 | Host | 其他 client | 本機 client |
     |---|---|---|---|
     | `PlayerJoined(slot)` | Core 事件；同一個 `Step` 輸出 `SpawnAvatar`，轉接層 `SpawnAsPlayerObject` | 該 slot avatar 的 `OnNetworkSpawn`（`Slot` NV 在此之前已套用，`NetworkSpawnManager.cs:1214,1239,1295`） | 自己 avatar 的 `OnNetworkSpawn`（`IsLocalPlayer`）→ 進 InShift（開班同批＝#26 轉場完成；中途加入者＝Onboarding 結束） |
     | 晚加入時的既有玩家 | — | `ConnectionApprovedMessage` 內每具既有 avatar 的 `OnNetworkSpawn`，視同補發的 `PlayerJoined` | 同左 |
     | `PlayerLeft(slot)` | Core 第 4 步 → 第 5 步 avatar despawn | 該 slot avatar 的 `OnNetworkDespawn`。T1、T2 兩種觸發源下，它都先於 `Roster` 的 NV delta 到達 | 自己的離線以 `OnClientDisconnectCallback(LocalClientId)` 加 `DisconnectReason` 為準；自己 avatar 的 despawn 不算 `PlayerLeft` |
     | 成員資格 | MPS 事件 | MPS 事件（只代表成員資格，比 NGO 訊號晚、秒級） | 同左 |

     三條不變式：(a) 對同一個 client，Host 入列的 reliable 訊息依入列順序到達：每個 client 一條有序的送出佇列（`NetworkMessageManager.cs:700-713,818-880`），UTP 三種 reliable delivery 走同一條 pipeline（`UnityTransport.cs:690-703`）。這是 NGO 的實作細節（`MessageDelivery.cs` 自註 "For now"），升版必重驗。(b) 由 (a) 與 3.0 s 間隔推得：同一 slot 舊 avatar 的 Destroy 必先於新 avatar 的 Create。(c) **不得依賴 NV 與 Destroy／Create 的相對順序**：NV delta 要到下一個 tick 才入列，`ChangeOwnership` 又會強制先送出所有 dirty 的 NV（Decision 7）。所以 avatar 的 spawn 與 despawn 是「在場」的唯一來源；`SessionRoot.Roster` 只供 UI 與冪等補強，消費者不得在 avatar 的 `OnNetworkSpawn`／`OnNetworkDespawn` 內拿 Roster 交叉驗證，那一個 tick 的落差會讓它們看起來不一致。
     - `OnNetworkDespawn` 要排除兩種情況：本機 `NetworkManager.ShutdownInProgress`——本機關閉時，所有 avatar 都會 despawn（`NetworkManager.cs:1659`），不排除的話，自己斷線就會替每個人各發一次 `PlayerLeft`；以及本機自己的 avatar。
     - `NetworkManager.OnConnectionEvent` 的 `PeerConnected`／`PeerDisconnected` **只供記錄**。2.13.2 沒有公開的 `OnPeerDisconnectedCallback`，r3 引的名稱不存在（`NetworkConnectionManager.cs:230-251` 是 internal）。這兩個事件帶的是 clientId，`PeerConnected` 在 approval 當下就觸發，比 `PlayerJoined` 早 3 s 以上；`PeerDisconnected` 相對 despawn 的先後，在 T1 與 T2 之間會翻轉。
     - `RosterEntry` 加上 `PeerPhase Phase`。`Online` 的定義是「`PlayerJoined` 已發、`PlayerLeft` 未發」。要判斷「slot 換人」看的是 `ClientId` 有沒有變（clientId 單調、不重用，可當占用世代）：同一個 tick 內的多次寫入會被合併，`Online = false` 那一刻可能根本送不出去（`NetworkVariable.cs:317-319`）。

14. **進房分段預算是 Core 的狀態計時（TR-netcode-011）**。`CreatingRoom`／`JoiningRoom` ≤ `T_lobby`（10 s），#26 轉場與 `Onboarding` 的連線階段 ≤ `T_spawn`（10 s，與 `MaxConnectAttempts` 對齊；`SessionNetworkHandler` 的等待上限也是它，Decision 2 H1），超時→該狀態的失敗出口與店語訊息。中途加入時，`JoinSessionByCodeAsync` 內就包含 Relay join 與 NGO 連線（初始化路徑），所以 handler 的 `AttemptStarted` 一觸發，Core 就結束 `T_lobby`、改計 `T_spawn`（與 GDD AC7a 的分段一致；r2 依審查補）。任一計時到期，Core 走失敗出口，但轉接層保留進行中的 `JoinSessionByCodeAsync` Task：它日後若成功回傳，立即以已過期的世代對該 session 執行 Teardown（`Shutdown()`＋`LeaveAsync()`），不得讓已回 `Idle` 的玩家在 Host 端被核准、生成 avatar。r2 註：W1 量到的「#26 `StartRelayNetworkAsync` 耗時」含預設 handler 每 1 s 輪詢一次的人為延遲（`NetworkManagerSession.cs:43,351-356`），自有 handler 在 `StartHost()` 返回後即完成，這個數字要重量；`Booting` 的 stall 偵測（`load_stall_timeout_sec`）在 loader 層、Unity 之外（ADR-0005／Web template）。UGS 呼叫失敗的重試一律指數退避、首次 ≥ 2 s，避免 429。

### Architecture Diagram

```
                NightShift.Platform（ADR-0005；組合根 PlatformComposition.Create()）      Unity Gaming Services
   IPageLifecycle  IUnloadNotifier  ILaunchParams  IRegionSelector                     MPS Sessions / Relay
         │               │              │              │                                     │
         ▼               ▼              ▼              ▼                                     ▼
 ┌───────────────────────────────────────────────────────────────────────────────────────┐
 │  NightShift.Session.Unity（轉接層：翻譯事件、執行效果，不含決策）                       │
 │   SessionServices ──── ISession / IHostSession（建房、加入、StartRelay/StopNetwork、    │
 │                        RemovePlayerAsync、事件訂閱、shift_eta、options 工廠、           │
 │                        採樣看門狗輸入、執行復原效果）                                 │
 │   SessionNetworkHandler : INetworkHandler（r2）── NGO 啟停的唯一擁有者：閘門、拒絕不   │
 │                        throw、StopAsync 冪等；OnServerStarted 第三道防線＋SessionRoot   │
 │   NgoBridge ────────── NetworkManager（ApprovalCallback、Connected／Disconnect 回呼、   │
 │                        OnServerStopped／OnClientStopped、SpawnAsPlayerObject；          │
 │                        依 NgoOwner 把事件送進 Online Core 或沙盒 Core）               │
 │   SessionRoot ──────── NetworkBehaviour：Roster NV、ShiftEndTs NV、Heartbeat RPC        │
 │   DisconnectSequencer  依優先序呼叫 IDisconnectParticipant（ADR-0001／G2／ADR-0004）    │
 │   TransportSwitch ──── Solo／沙盒：SinglePlayerTransport ⇄ UnityTransport（OnServerStopped）│
 │   SessionConfigAsset : ScriptableObject ── ToCore()（r2）                               │
 └───────────────▲───────────────────────────────────────────────────────┬───────────────┘
                 │ SessionEvent（含 nowMs、utcNowMs、slot，不含 clientId）     │ SessionEffect[]
 ┌───────────────┴───────────────────────────────────────────────────────▼───────────────┐
 │  NightShift.Session.Core（純 C#，noEngineReferences = true）                            │
 │   SessionMachine ── 12 態 × 32 列守衛表（列分本機／peer／各讀一半三種主詞）             │
 │   SlotTable ─────── PlayerId ↔ slot ↔ clientId（clientId 只在 SlotOf()/ClientOf()）       │
 │   ApprovalGate ──── 版本閘 → 成員 → 重複 → 截止 → 空位（Host 自身只判前三項）            │
 │   HeartbeatMonitor  seq／lastPeerSeqSeen／逾時／單向失效／RTT／offset／Release(slot)     │
 │   HostLossDisambiguator  六列優先表                                                       │
 │   ShiftEta ──────── 發布與剩餘時間換算（clamp）                                          │
 │   LeaveBeaconPlan ─ TryFor(mode, isHost, dup, leaveEnded, sessionId, playerId, token)      │
 │   JoinWatchdog／RecoveryPolicy ── 看門狗武裝與觸發、復原的次數與退避（r2）               │
 │   SessionConfig ─── 純 C# 常數（含 MaxPlayers）＋12 條可機械驗證約束的 Validate()         │
 └───────────────────────────────────────────────────────────────────────────────────────┘
                 ▲ EditMode 測試（fake clock，無 NGO、無 UGS）
   NightShift.Identity（零依賴）：PeerKind／PeerKey／PlayerSlot／NpcId ← Session.Core、Movement.Core、Interaction.Core 共用

 時間軸（兩層壽命）：
   MPS session   ├── CreatingRoom/JoiningRoom ── Lobby ── InShift ── Settlement ── Lobby ── … ──┤ DeleteAsync
   Relay + NGO                                 ├ #26 Start ─────────── #23a Stop ┤ ≥min_lobby_dwell ├ Start ───
   心跳                                              ├ Onboarding ── InShift ── Settlement ┤
   avatar（r2）                                           ├ PlayerJoined ─────────── PlayerLeft ┤
```

### Key Interfaces

以下為 C# 9（Unity 6.3，無 file-scoped namespace）的簽章草圖，不是可直接編譯的檔案。命名依專案慣例：RPC 以 `Rpc` 結尾、`NetworkVariable` 為 PascalCase 名詞、查詢介面 `I` 開頭、C# 常數 PascalCase（technical-preferences）；snake_case 帶單位的是 GDD／registry 的 Tuning Knob 資料鍵。⚠ 轉接層命名空間 `NightShift.Session.Unity` 會遮蔽根命名空間 `Unity`：在看得到它的組件裡（`Session.Unity` 本身與引用它的組件），位於 `NightShift.Session` 或其子命名空間內的程式碼，`Unity.` 開頭的名稱會先解析成 `NightShift.Session.Unity`，得到 CS0234；寫在 namespace 本體內的 `using Unity.Netcode;` 也一樣失敗（不能比照下方 `using NightShift.Identity;` 的位置）。引擎與套件的 `using` 一律寫在檔案頂層、namespace 之外，或以 `global::Unity.…` 限定（6000.3.24f1 內建 Roslyn 以 `-langversion:9` 實測，r2 審查）。ADR-0001 的 `NightShift.Movement.Unity` 同理。

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

    /// <summary>Host 端逐 slot 追蹤的 peer 階段；適用性矩陣中主詞為 peer 的列讀它（Decision 3）。r2：也複製進 RosterEntry。</summary>
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
        public PeerPhase PhaseOf(byte slot);                    // approval 時 Onboarding → PlayerJoined 時 InShift → Settlement
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
        public readonly string PlayerId;                        // 解碼端已檢查 UTF-8 ≤ 61 bytes（Decision 5）
        public readonly ulong ClientId;                         // 只用來回填 SlotTable 與判斷「是否 Host 自身」，Core 的其餘決策不讀它
        public readonly bool IsHostSelf;                        // r2：ClientNetworkId == ServerClientId → 只判第 1–3 項
    }

    public readonly struct ApprovalVerdict
    {
        public readonly JoinRejectReason Reason;                // Ok 即核准；非 Ok 時 response.Reason = Reason.ToString()（必須非空）
        public readonly byte Slot;                              // Ok 時有效
        public readonly bool RetryAfterMemberRefresh;           // r2：第一次判到 NotAMember 時為 true → 轉接層回 Pending、RefreshAsync 後重判（Decision 5 第 2 項）
    }

    public static class ApprovalGate
    {
        public const ushort ProtocolVersion = 1;                // 任何 RPC／NV 佈局變更即 +1；與 NetworkConfig.ProtocolVersion（固定 0）無關
        public static ApprovalVerdict Evaluate(in ApprovalRequest req, in HostView host, SlotTable slots, SessionConfig cfg);
        // HostView = { long NowMs; long? ShiftEndTsMs; bool InSettlement; uint BuildId; IReadOnlyCollection<string> MemberIds }
        // MemberIds：Online＝session.Players；Solo 與 Lobby* 沙盒＝{ 本機 PlayerId }（r1）
        // r2：IsHostSelf 時不經 #9 矩陣守衛、只判第 1–3 項，此時 ShiftEndTsMs 為 null；非自身請求時必非 null（OnServerStarted 已固定，Decision 5「#26 的時序」）
    }

    /// <summary>shift_eta session property（Member 可見）。r2 依 r3 FV-2 加 shift_seq 與 published_utc_ms。</summary>
    public readonly struct ShiftEta
    {
        public readonly SessionPhase Phase;                     // Lobby／InShift／Settlement
        public readonly int ShiftSeq;                           // 每次 #26 +1；看門狗用
        public readonly long RemainingMs;
        public readonly long PublishedUtcMs;
        public long RemainingAt(long utcNowMs);                 // clamp(RemainingMs − (utcNowMs − PublishedUtcMs), 0, RemainingMs)
    }

    /// <summary>離開通知的宣告式計畫（Decision 9）。轉接層每次階段變更與每 leave_beacon_refresh_ms 重算，結果不同才 Install，null 即 Clear。</summary>
    public static class LeaveBeaconPlan
    {
        public const string LobbyRestBase = "https://lobby.services.api.unity.com/v1";   // MPS 2.3.1 InternalLobbyService.cs:57；PlayMode 反射守門測試比對
        public static bool TryFor(SessionMode mode, bool isHost, bool isDuplicateTab, bool leaveTaskEnded,
                                  string sessionId, string playerId, string accessToken,
                                  out string url, out string method, out string authorization);
        // Host：DELETE {base}/{sessionId}；client：DELETE {base}/{sessionId}/players/{playerId}；authorization = "Bearer " + accessToken
        // 回 false（＝Clear）：mode == Solo、sessionId 或 accessToken 為 null、isDuplicateTab、leaveTaskEnded。計畫綁定 session 世代；只准由宣告式規則呼叫 Install／Clear（Decision 9 第 4 步）
    }

    /// <summary>r2 依審查新增：看門狗的武裝與觸發（Decision 2）。純函式＋小狀態，計時只用 nowMs；轉接層只採樣、不判斷。</summary>
    public sealed class JoinWatchdog
    {
        public JoinWatchdog(SessionConfig cfg);
        public void OnAttemptStarted(int shiftSeqAtAttempt);   // attemptedSeq：屬性變更路徑當場讀；初始化路徑在加入回傳後回填
        // 每次 ISession.Changed 與每次 handler 嘗試結束時呼叫；回 true＝到期且條件仍成立 → 交 RecoveryPolicy
        public bool Evaluate(SessionPhase phase, int observedShiftSeq, bool etaInShift, bool networkPropertyPresent,
                             bool handlerConnected, bool attemptInProgress, long nowMs);
    }

    /// <summary>r2 依審查新增：復原的觸發過濾、每個 shift_seq 最多 2 次、退避（Decision 14）、用盡即 Teardown。</summary>
    public sealed class RecoveryPolicy
    {
        public RecoveryPolicy(SessionConfig cfg);
        public bool ShouldRecoverOnStartFailed(bool networkPropertyStillSameAsAttempt, bool isDuplicateTab, bool teardownPending);
        public bool TryNextAttempt(int shiftSeq, long nowMs, out long notBeforeMs);   // false＝用盡 → Core 輸出 Teardown
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
        public void OnConnected(byte slot, long nowMs);         // r2：全欄重置
        public void Release(byte slot);                         // r2 依 r3 FV-10：#24 第 4 步與 SlotTable.Release 同一呼叫內執行
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

    /// <summary>r2 依 r3 FV-5：純 C#，取代 r1 的 ScriptableObject。Session.Unity 的 SessionConfigAsset.ToCore() 產生它。</summary>
    public sealed class SessionConfig
    {
        public static SessionConfig Default { get; }            // 自 registry／GDD Tuning Knobs 常數生成
        // readonly 欄位＋建構子（不用 init accessor），欄位依 Decision 12 表與 GDD Tuning Knobs
        public int MaxPlayers { get; }                          // ＝max_players（MVP 2、VS 4）；建房的 SessionOptions.MaxPlayers 取它（Decision 2）
        public System.Collections.Generic.IReadOnlyList<string> Validate();   // 12 條可機械驗證約束（GDD 11 條＋leave_beacon_refresh_ms < 300 000）；空清單＝合法
    }

    /// <summary>純狀態機：Step 吃一個事件、回傳零到多個效果；所有時間由事件攜帶的 nowMs／utcNowMs 提供。</summary>
    public sealed class SessionMachine
    {
        public SessionMachine(SessionConfig cfg, SessionMode mode, bool isHost);
        public SessionPhase Phase { get; }
        public int Step(in SessionEvent e, System.Span<SessionEffect> effectsOut);   // 零配置；PlayerJoined 同一個 Step 輸出 SpawnAvatar（r2）
    }
}
```

```csharp
namespace NightShift.Session.Unity
{
    /// <summary>Host 擁有；Host 在 OnServerStarted 內第一個由轉接層 spawn 的物件，先於所有 avatar（r2）；壽命＝班次。Solo 模式亦存在。</summary>
    public sealed class SessionRoot : NetworkBehaviour
    {
        // 兩個 Host 寫、全員讀的真相；建構子預設即 Server 寫權，不需也不得改 Owner
        public readonly NetworkVariable<RosterState> Roster = new NetworkVariable<RosterState>();
        public readonly NetworkVariable<long> ShiftEndTs = new NetworkVariable<long>();
        public event System.Action Ready;                       // r2：OnNetworkSpawn 時發；avatar／HUD 訂閱它，不假設 SessionRoot 先到

        [Rpc(SendTo.Server, Delivery = RpcDelivery.Unreliable)]
        public void HeartbeatToHostRpc(HeartbeatWire p, RpcParams rp = default);   // 轉接層先 SlotOf(rp.Receive.SenderClientId)

        [Rpc(SendTo.SpecifiedInParams, Delivery = RpcDelivery.Unreliable, InvokePermission = RpcInvokePermission.Server)]
        public void HeartbeatToClientRpc(HeartbeatWire p, RpcParams rp);           // RpcTarget.Single(clientId, RpcTargetUse.Temp)；r2 依 r3 EA-5 限 Server
    }

    /// <summary>心跳的線上格式：逐欄序列化，20 bytes 酬載（NGO 層線上約 46 B），與 struct 佈局無關（r1 依 r2 E8）。</summary>
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

    /// <summary>固定 4 格；INetworkSerializable ＋ IEquatable（缺後者 NGO 每幀誤判 dirty）。只供 UI 與冪等補強，不是在場的來源（Decision 13）。</summary>
    public struct RosterState : INetworkSerializable, System.IEquatable<RosterState>
    {
        public RosterEntry S0, S1, S2, S3;
        public RosterEntry this[byte slot] { get; }
    }

    public struct RosterEntry : INetworkSerializable, System.IEquatable<RosterEntry>
    {
        public FixedString64Bytes PlayerId;   // UTF-8 ≤ 61 bytes（r2 更正）；UGS PlayerId 28 字元
        public ulong ClientId;                // 占用世代：單調、不重用；判斷「slot 換人」看它有沒有變（r2）
        public PeerPhase Phase;               // r2 依 r3 CX-2
        public bool Online;                   // PlayerJoined 已發、PlayerLeft 未發（r2 定義）
        public int JoinedTick;
    }

    /// <summary>#24 固定順序的參與者；Priority 常數見 Decision 7 的表。</summary>
    public interface IDisconnectParticipant
    {
        int Priority { get; }
        void OnPeerLost(in PeerLostContext ctx);   // ctx = { byte Slot; string PlayerId; PeerLostCause Cause; PeerPhase Phase; long NowMs }
    }

    public enum StartOutcomeKind : byte { None, Connected, Rejected, Failed }

    /// <summary>r2 依 r3 FV-1：NGO 啟停的唯一擁有者，取代 MPS 預設的 GameObjectsNetcodeNetworkHandler（internal，無法包裝）。
    /// 契約 H1–H7 見 Decision 2。由 SessionServices 唯一的 options 工廠以 WithNetworkHandler 掛上（不經 ADR-0005），Host 與 client 共用。</summary>
    public sealed class SessionNetworkHandler : global::Unity.Services.Multiplayer.INetworkHandler   // global::：見本節開頭的命名空間遮蔽
    {
        public SessionNetworkHandler(NetworkManager nm, UnityTransport relayTransport, int sessionGeneration);
        public void Bind(global::Unity.Services.Multiplayer.ISession session);   // H7 斷言通過後由轉接層立即呼叫（建房、加入、復原的重新加入各一次）；Bind 之前讀不到任何 session property，H1 ①④ 略過
        public event System.Action AttemptStarted;             // Client 角色的 StartAsync 進入時同步觸發；轉接層據此維護 attemptedSeq、結束 T_lobby 改計 T_spawn
        public System.Threading.Tasks.Task StartAsync(NetworkConfiguration cfg);   // Client：H1 閘門→StartClient；被拒 H2 正常返回；真故障 H3 throw SessionException
                                                                                  // Host／Server：H4 一律 StartHost，false 即 throw
        public System.Threading.Tasks.Task StopAsync();                           // H5：冪等、永不 throw、永不懸掛、只停自己啟的 NGO、取消進行中的閘門
        public StartOutcomeKind LastOutcome { get; }
        public JoinRejectReason LastRejectReason { get; }      // LastOutcome == Rejected 時有效；DisconnectReason 在 stopped 當下快照
        public bool IsConnected { get; }                       // Core 的 NetworkStarted／NetworkStopped 只從這裡產生，不讀 IClientSessionNetwork.State
    }

    /// <summary>Solo／沙盒的 transport 切換（r2 依 r3 EA-3 改掛點）。兩個元件並存於 NetworkManager 物件，只切 NetworkConfig.NetworkTransport 的指派。</summary>
    public static class TransportSwitch
    {
        public static void UseSinglePlayer(NetworkManager nm);    // 前置：!IsListening && !ShutdownInProgress 且距上次 stopped ≥ 1 幀；緊接 StartHost()
        public static void UseUnityTransport(NetworkManager nm);  // 掛 OnServerStopped（OnStopped 是 internal）；StartHost() 回 false 時當場呼叫；不變式：NGO 閒置 ⇒ UnityTransport
    }

    /// <summary>r2 依 r3 FV-5：Inspector 調參的設定資產；Core 不認識它。</summary>
    public sealed class SessionConfigAsset : UnityEngine.ScriptableObject
    {
        // [SerializeField] private 欄位（6.3：SerializeField 只能標在欄位上）
        public SessionConfig ToCore();                          // 建置期斷言在 Editor 專用組件 NightShift.Session.Editor（IPreprocessBuildWithReport）
    }
}
```

**Approval payload 佈局**（`NetworkConfig.ConnectionData`，little-endian）：`[0] PayloadVersion=1`、`[1..2] ProtocolVersion`、`[3..6] BuildId`、`[7] PlayerId 長度 n ≤ 61`、`[8..8+n) PlayerId UTF-8`。總長 ≤ 69 bytes（r2 依 r3 FV-9 更正：r1 寫 n ≤ 64、≤ 72 bytes，但 `FixedString64Bytes` 只容 61 bytes）。解碼端先檢查 n，超過即拒。

**離開通知**（`fetch keepalive`，經 ADR-0005 r2 的 `IUnloadNotifier.InstallLeaveBeacon(url, method, authorization)`；只在 `pagehide` 送出）：Host → `DELETE https://lobby.services.api.unity.com/v1/{session.Id}`；client → `DELETE https://lobby.services.api.unity.com/v1/{session.Id}/players/{PlayerId}`；只帶 `Authorization: Bearer <AccessToken>`、無 body。只有 204 算成功（Decision 9；r2 依 r3 EA-1 更正路徑，刪除「第二次的 404 視為成功」）。

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

### Alternative 6: 沿用 MPS 預設 handler，以 `StartFailed` 復原（r1 的寫法）
- **Description**：加入時只帶 `WithNetworkOptions(WSS)`，由 SDK 內建的 `GameObjectsNetcodeNetworkHandler` 自動啟網；Lobby／Lobby\* 訂閱 `IClientSessionNetwork.StartFailed`，收到就 `LeaveAsync()`，再以同碼重新加入。
- **Pros**：不必自己寫 NGO 啟停；跟著 MPS 升版。
- **Cons**：預設 handler 在 approval 拒絕時拋例外，初始化路徑上 SDK 因此先 leave，被截止擋下的中途加入者在拿到 `ISession` 之前就已不是成員，Lobby\* 不可達（r3 FV-1）。`StartFailed` 在那條路上訂閱不到；在屬性變更路徑上，「leave＋以碼重新加入」反而把已經保住的成員資格送進初始化路徑，結果被移出。另外還有 1 s 輪詢的 `TaskCanceledException` 競態會謊報 `Started`（`GameObjectsNetcodeNetworkHandler.cs:79-82`）。預設 handler 是 internal，連包一層 decorator 都做不到。
- **Rejection Reason**：Lobby\* 是 MVP（AC51）；arlong 2026-10-03 裁決採自有 handler（Decision 2）。

### Alternative 7: Lobby\* 改為「核准但不建 avatar」或「session 外等待」
- **Description**：(b) 過截止者照樣核准，但 `CreatePlayerObject = false`，停在 `LobbyWaiting`；(c′) 過截止者不加入，在 session 外以公開房的查詢預檢、每 ≥ 5 s 輪詢一次，等前一班結束再加入。
- **Pros**：(b) 不必自寫 handler；(c′) R4 原封不動，等待期間不受屬性變更與自動加入影響。
- **Cons**：(b) 等待者的 NGO 以 client 身分連著 Host，`NetworkManager` 單例被占用，`StartHost()` 被 `CanStart` 擋下（`NetworkManager.cs:1300-1306`），練習沙盒（AC51）就此消失；還要對每一個 NetworkObject 掛上 `CheckObjectVisibility`，變成全專案的不變式，`ApprovalVerdict` 也要多一種結果。Relay 名額倒不是問題：MPS 以 `MaxPlayers` 建 allocation（`NetworkModule.cs:285`）。(c′) 房間必須公開，`shift_eta` 與新增的房間鍵也要改成 Public；等待期間座位不保留，2 人房的唯一空位可能被搶走；GDD :758「MPS 成員已成立」的定義要改。
- **Rejection Reason**：arlong 2026-10-03 裁決 (a)；(b) 會讓 AC51 不成立，(c′) 會改 GDD 的 Lobby\* 定義，並打開公開房這個面。

### Alternative 8: avatar 維持在 approval 當下 spawn，以三個條件定義「在場」
- **Description**：approval 照舊 `CreatePlayerObject = true`；「在場」定義為「avatar 存在、`Roster[slot].Phase ≥ InShift`，而且 `Roster[slot].ClientId` 與該 avatar 的 owner 一致」，每個消費者都套用這個定義。
- **Pros**：不動 NGO 的預設流程；approval 一過，Host 就拿得到 `PlayerObject`。
- **Cons**：每個消費者，包括 Host 端的 `PairMachine`，都要實作三條件判斷；Onboarding 期間的 avatar 對其他人照樣可見、可碰撞；NGO 的可見性機制藏不住 approval 時建出來的 player object——`AddPlayerObject` 不檢查 `CheckObjectVisibility`（`NetworkSpawnManager.cs:96-113`）；Roster 的 NV 又晚一個 tick 才到，判斷容易在交界處失準。
- **Rejection Reason**：arlong 2026-10-03 裁決採延後 spawn（Decision 7 前提 4）。

### Alternative 9: 以 `IAccessTokenObserver` 監聽 token 換發
- **Description**：以 `CoreRegistry.Instance.GetServiceComponent<IAccessTokenObserver>()` 訂閱 `AccessTokenChanged`，token 一換就重裝離開通知。
- **Pros**：事件驅動，不必每秒重算。
- **Cons**：它在 `Unity.Services.Authentication.Internal` 命名空間，要手動引用 `autoReferenced = false` 的 `Unity.Services.Core.Internal` 組件，而且沒有穩定性承諾。每秒重算只是一次字串比對，換發提前 300 s，任何短於 300 s 的週期就夠了。
- **Rejection Reason**：用公開 API 加上宣告式重算（Decision 9），就能拿到同樣的保證。

### Alternative 10: `ForceSamePrefabs = false`，讓 `BuildId` 涵蓋 prefab 清單
- **Description**：依 NGO 文件的 dynamic prefabs 範例，關掉 NGO 的 prefab 清單比對，改由 approval 自己判斷（`Documentation~/samples/bitesize/bitesize-dynamicprefabs.md:43,138`），這樣幾乎所有過期 build 都會落到 `StaleBuild`。
- **Pros**：店語更精確。
- **Cons**：拿 NGO 的早期硬閘，去換我們自己雜湊的完整性；其餘雜湊欄位（NGO 協定版本、TickRate 等）照樣由 NGO 先擋，第 0 層並不會消失。
- **Rejection Reason**：第 0 層的通用字串已能辨識（Decision 5），保持 NGO 預設即可。

## Consequences

### Positive
- 四份 ADR 的隱含前提變成一份可治理的決策；G2、ADR-0004、G8、G9 有了明確的上游。
- 玩家身份只有一種鍵（slot），clientId 不再漏進遊戲邏輯；重連換號的孤兒回收有唯一時刻（`PlayerLeft(slot)`）。
- 心跳、排歧、閘門、slot 回收全部可在 EditMode 以 fake clock 走完 GDD 的時間算術 AC，不必開 NGO。
- Solo 與 Online 共用同一條 NGO 路徑，機台／NPC／互動不需第二套程式碼，`ServiceError` 時仍可玩。
- （r2）Lobby\* 在 MPS 2.3.1 下可達，而且等待者始終是成員；NGO 啟停只剩一個擁有者（`SessionNetworkHandler`），沙盒競態與 `TransportComponentMissing` 都由排序消除。
- （r2）avatar 的 spawn／despawn 是各端唯一的在場訊號：Onboarding 中的人任何一端都看不到、碰不到，ADR-0003 :95 的保證恢復成立。
- Lobby 零 Relay 流量；局間 teardown 有 API 對應（`StopNetworkAsync`）與實測證據。

### Negative
- 多一個 Core 組件與一組事件／效果型別；轉接層要為每個引擎回呼寫翻譯，初期比直接在回呼裡寫邏輯多約一倍的檔案數。
- ADR-0001／0002／0003 各需一次 r1 改鍵（`PeerKey`、`ClaimedBy`）；ADR-0005 r1／r2（與本 ADR 成對）改 `InstallLeaveBeacon` 簽章（r2 為三個字串）、新增 `SetLeaveConfirmation`／`RestoredFromBackForwardCache`、`ILaunchParams.RoomCode` 改讀 referrer，並以組合根取代自我註冊。
- avatar 設 `DontDestroyWithOwner = true` 換來序列的定序權，代價是 Host 端短暫的 ownership 回呼窗口（Decision 7 前提 2）：avatar 上的元件多一條「不以 ownership 變化觸發副作用」的紀律。
- 多一個零依賴組件 `NightShift.Identity`（四個型別），換掉一條潛在的 ADR 依賴環。
- （r2）自寫約百行的 `SessionNetworkHandler`，等於接下 MPS 預設整合的維護責任；它在被拒時正常返回，違反 `INetworkHandler` 文件註解寫的「Task 完成後 client 應已連線」，MPS 每次升版都要重驗 V1／V13。
- （r2）`IClientSessionNetwork.State` 不能再當 NGO 狀態用；轉接層要多一個看門狗與一條復原路徑。
- （r2）延後 spawn 讓攝影機、HUD、輸入的綁定改掛在 avatar 的 `OnNetworkSpawn`，`OnClientConnectedCallback` 時拿不到 `PlayerObject`；延後 spawn 的 avatar 收不到 `OnNetworkSessionSynchronized`（只有晚加入者一次收到的既有物件會收到，`ConnectionApprovedMessage.cs:343-363`），所以一律不得依賴它（ADR-0001 r1／G2 的義務）。
- 「開始上班」要付一次 Relay allocation＋WSS handshake（第二班起每次都付）；已入 `T_spawn`。
- MVP 無 migration：Host 關頁全員散場，這是明示給玩家的限制。

### Risks
- **V1／V13 自有 handler 的契約**（r2 改寫）：整條 Lobby\* 的成立，靠的是「handler 正常返回，SDK 就不 leave」這條 MPS 2.3.1 的原始碼事實，以及 `ProcessOptions` 真的把 handler 套上（H7）。兩者都沒有編譯期保護，MPS 升版必跑 V13。另外，handler 之前的失敗分兩類。Relay `JoinAllocation` 失敗、或加入途中 Host 恰好換班使 join code 失效，會拋例外、讓 SDK leave，走 `JoiningRoom` 的失敗出口（`NetworkModule.cs:423-443,479-497`）。`_session_network` 的 `HostId` 與 `session.Host` 不符時則是**靜默不啟網**：不拋例外、不 leave、handler 從未被呼叫，`JoinSessionByCodeAsync` 正常回傳（`:537-543`），由看門狗接手。
- **V11 班次交界的屬性合併**（r2 改寫）：模組謊報 `Started` 時，新值會被靜默吃掉（Decision 2 看門狗）。看門狗與 `min_lobby_dwell_ms` 是緩解，不是消除；V11 量實際的錯過率。
- **`SaveCurrentPlayerDataAsync` 不在 SDK 的清理範圍內**（r2 新增）：在初始化路徑上啟網的加入（中途加入）會因 `SetAllocationId` 多打一次 `UpdatePlayer`（`NetworkModule.cs:472-475` → `SessionManager.cs:264-267`；`SavePlayerDataAsync` 在 `Modified` 為 false 時直接返回，`SessionHandler.cs:946-947`）。它若失敗（429、斷網），`JoinSessionByCodeAsync` 會拋例外，但玩家已是成員、也可能已經連上 NGO，只是拿不到 `ISession`。處理方式：handler 若已連上，轉接層就 `Shutdown()` NGO，Host 的心跳路徑接著跑 #24，第 6 步會把成員移出；handler 若是被拒（Lobby\*），成員會掛到 session 結束。這種情況罕見，MVP 接受。
- **V2 拒絕原因送不到遠端**：原始碼已證實送得到（r2），T1 (h) 實跑一次即結案。若實跑不符，版本閘照樣成立（連線不會建立），只是店語退化為通用的「加入失敗」；AC54 不受影響。AC5／AC35 的鑑別改在 `JoinSessionByCodeAsync` 回傳後讀 `shift_eta` 補：剩餘 ≤ `late_join_cutoff_sec`，或 phase 為 Settlement，就判為 `LateJoinCutoff`。
- **Host 自己的 approval 拒絕會被 NGO 強制核准**：`NetworkManager.HostServerInitialize` 對 Host 本機 client（clientId 0）的拒絕只記一行警告 "You cannot decline the host connection. The connection was automatically approved." 就照樣核准，而且照 `response.CreatePlayerObject` 決定建不建 avatar（`NetworkManager.cs:1510-1516`）。`ApprovalGate` 若在 slot 0 的路徑有 bug，**不會失敗出聲**，而是靜默進場、`SlotTable` 沒有 slot 0；原稿在 Solo 與 Lobby\* 沙盒下的第 2 項就會這樣必拒（r2 E2），r1 在 Online 下仍可能被第 4 項拒絕（r3 FV-3）。r2 起 approval 一律回 `CreatePlayerObject = false`，Host 的 avatar 改在 `OnServerStarted` 內生成，所以「Host 沒有 avatar」改由同一個掛點的斷言攔下。緩解見 Decision 5「Host 自核准」：Host 自身只判第 1–3 項，加上三道防線。這與 ADR-0001 `enableOverlapRecovery`、ADR-0003 建構子參數同屬「預設行為悄悄生效、沒有錯誤訊息」。
- **V3 `SinglePlayerTransport` 在 WebGL 失敗**：退路是 Solo 改走 Relay 單人房，代價是 Solo 依賴 UGS；此時 `ServiceError → Solo 仍可玩` 不成立，GDD States 表需改。這條退路沒有列為 Alternative，屆時另行裁決（r2 依 r3 FV-9：r1 引用了一個不存在的 Alternative）。
- **V10 keepalive fetch 沒送到**：Host 關頁退化為 132 s 的服務端路徑，但 #25 的 30 s 本地靜默提示已保底，支柱 5 不破；client 關頁退化為 Host 心跳路徑 8 s。r2：伺服器端的 CORS 已實測放行，三引擎的 WPT 也通過了同類測試（V10），剩下的風險在瀏覽器版本下限（Firefox < 133 沒有 keepalive），以及行動端多半根本不觸發 `pagehide`。
- **token 遺失使 MPS session 變殭屍**（r2 新增）：見 Decision 8。殭屍 session 占著 `SessionOptions.Type`，下一次建房或加入必須換一個新的 Type。
- **同帳號雙開**（r2 新增，V16）：兩個分頁共用 `PlayerId`，任一邊 leave 或送出離開通知，都會把唯一的那筆成員資格刪掉。被判 `Duplicate` 的分頁不 leave、不安裝離開通知（Decision 2、9）。
- **斷線掉落依賴訊息到達序**（只在 G2 選 Decision 7 前提 3 的 (b) 時存在）：NGO 2.13.2 把所有 reliable 訊息放進同一條 `ReliableFragmentedSequenced`，原始碼自註這是暫時做法；哪天升版改掉，client 上的道具會重新跟著 avatar 消失，T1 (i′) 會紅燈。選 (a) client 端自救就不依賴它——這是推薦 (a) 的理由。
- **UGS 429**：建房／加入的重試退避已寫入 Decision 14；測試基建不得並行建多個 session。
- **行動瀏覽器**（OQ#10／#13）：背景回收與 context loss 未驗；行動端為次要目標，MVP 不承諾。
- **n=1 的數字**：87 s 與 1.14 s 皆單次樣本（UGS 限流），但與 12 s／30 s 紅線的差距遠大於合理變異；ADR 的決策不依賴其精確值，只依賴「傳輸層救不了、心跳與主動通知是唯一快路徑」這個量級結論。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| netcode-session.md | TR-netcode-001 Host 權威（NPC／波次／計分／時鐘／道具／結算） | Decision 1 正式裁決 client-server＋client-as-host；Decision 13 `ShiftEndTs` Host 寫 |
| netcode-session.md | TR-netcode-008 截止閘門唯一執行點＝`ConnectionApprovalCallback` | Decision 5 判定順序第 4 項（唯一的決策閘；前面的 NGO 雜湊閘不判截止）；被拒者仍是成員、在 session 內進 Lobby\*（Decision 2，r2） |
| netcode-session.md | TR-netcode-009 approval payload 帶版本、不符即拒 | Decision 5 payload 佈局（≤ 69 bytes）與第 1 項；兩層閘門：NGO 雜湊不符時以通用字串歸為 `StaleBuild`（r2 依 r3 EA-2） |
| netcode-session.md | TR-netcode-011 進房分段預算各自硬閘門 | **部分**：Decision 14 狀態計時；Decision 12 `MaxConnectAttempts = 10`；`T_load` 的硬閘門在 loader 層，本 ADR 只裁決 stall 偵測的歸屬 |
| netcode-session.md | TR-netcode-012 離線立即重取樣、grace／`host_solo`、#15a 以 `PlayerId` | Decision 7 第 7 步；Decision 4 `OfflineCountOf(playerId)` |
| netcode-session.md | TR-netcode-015 Host 消失排歧（兩層獨立） | Decision 8 `HostLossDisambiguator` 六列表 |
| netcode-session.md | TR-netcode-017 心跳 2 s／8 s、payload、雙向存活、offset | Decision 6 全條（payload 20 bytes、`HeartbeatWire` 逐欄序列化） |
| netcode-session.md | TR-netcode-018 send queue 溢位防護 | **部分**：Decision 12 `MaxSendQueueSize` 顯式＋監控點；定值與監控閾值待 `[P-16]`（V6） |
| netcode-session.md | TR-netcode-019 Lobby 延後建連、局間 teardown | Decision 2 兩層壽命；V1 |
| netcode-session.md | TR-netcode-021 UTP 常數契約、連線總逾時調小 | Decision 12 表 |
| netcode-session.md | TR-netcode-024 MPS 成員唯一寫入者＝Host；兩個人數不同 | Decision 7 第 6 步；`SlotTable.OnlineCount` 與 `session.PlayerCount` 分離 |
| netcode-session.md | TR-netcode-025 Lobby Host 離開＝事件＋30 s 本地靜默 | Decision 8 末段 |
| netcode-session.md | TR-netcode-028 12 態＋適用性矩陣；Lobby\* 合流；Host 獨留不結束 | **部分**：Decision 3 守衛表（32 列 × 11 欄、三種主詞、Onboarding 與 Settlement 期間斷線的分流）；Decision 2 Lobby\* 入口與看門狗（r2）；Decision 10 沙盒；Decision 7 不結束 session；班次交界的錯過率待 V11 |
| netcode-session.md | TR-netcode-035 重連身分 `PlayerId↔slot`，ClientId 會變 | Decision 4 identity 契約 |
| netcode-session.md | TR-netcode-036 班次時鐘真相＝Host `shift_end_ts` NV | Decision 13 |
| netcode-session.md | TR-netcode-039 UGS 失敗→ServiceError；單人不經 UGS | Decision 10 Solo 零服務依賴（`SinglePlayerTransport`）；Decision 5 Host 自核准 |
| netcode-session.md | TR-netcode-040 plan B | Decision 1 兩條退路與觸發條件 |
| netcode-session.md | TR-netcode-041 常數 data-driven、約束可機械驗證 | Decision 12 `SessionConfig.Validate()`（可機械驗證的 12 條約束：GDD 的 11 條＋r2 的 `leave_beacon_refresh_ms` 上限） |
| netcode-session.md | TR-netcode-044 EditMode 純邏輯／PlayMode 多實例／Release 實機分層 | **部分**：Decision 3 Core 組件；Validation Criteria；「鉤子 build flag 隔離」未裁決 |
| netcode-session.md | TR-netcode-045 `connection_state` 店語表 | Decision 13 `ConnectionState` 唯一來源 |
| netcode-session.md | TR-netcode-010 Host 關頁＝局終；`pagehide`＋`beforeunload` 離開通知；確認框 best-effort（r1 補列） | Decision 9（r2：只在 `pagehide` 送出、不分 `persisted`；`beforeunload` 只掛 Host InShift 的確認框；keepalive fetch＋`Authorization`；完整 REST URL）；Decision 11 無 migration。Safari 在 itch.io 的跨源 iframe 內不跳框（瀏覽器政策） |
| netcode-session.md | TR-netcode-013 `visibilitychange` 背景分流（r1 補列） | **部分**：> 5 s 分支是 Decision 9 的 Teardown 邊；≤ 5 s 的公式③ catch-up 歸 G9 |
| netcode-session.md | TR-netcode-014 teardown 不變式（r1 補列） | Decision 9：每條進 `Idle` 的邊恰好一個 `Teardown`，順序固定（`SetLeaveConfirmation(false)` → NGO 在跑才 `Shutdown()` → client `LeaveAsync`／Host `DeleteAsync` → 該 Task 結束後由宣告式規則清掉離開通知 → 退訂舊 `ISession` → 切 UI）；自有 handler 取代 MPS 預設整合後，r1 說「預期中」的 Shutdown 警告不再出現 |
| netcode-session.md | TR-netcode-023 道具 `DontDestroyWithOwner`、Host 自行 unparent（r1 補列） | **部分**：Decision 7 前提 1–3（avatar 也須 `DontDestroyWithOwner = true`、道具在 client 上存活的契約）；掉落與 despawn 的實作歸 G2 |
| netcode-session.md | TR-netcode-031 單一場景、不啟用 `NetworkSceneManager`（r1 補列） | **部分**：Decision 1 `EnableSceneManagement = false`；Decision 4 依賴更衣室 3.0 s；「同步未完仍進場」的 runtime 規則無 ADR |
| netcode-session.md | TR-netcode-046 沒有 NGO 連線的端也能顯示班次剩餘時間、不依賴心跳 offset（r1 補列） | **部分**：Decision 5 `shift_eta`（r2 加 `published_utc_ms` 與 `shift_seq`，晚到的讀者也成立）；牆鐘偏差沒有上限，只以 clamp 兜底 |
| netcode-session.md | TR-netcode-027 Relay region 貼著 Host（r2 補列） | **部分**：Decision 2 Region（只准 `RelayNetworkOptions(region)`）；選 region 的機制在 ADR-0005 `IRegionSelector`；同區 RTT ≤ 300、跨區降級契約未裁決 |
| netcode-session.md | TR-netcode-029 本層輸入訊號表＋下游契約表（r2 補列） | **部分**：Decision 13 對外事件與分端來源表（r2）；`local_ready` 的定義見 TR-fpc-027 列；GDD 契約表的鍵改 slot 待 r5 |
| game-concept-night-shift.md | TR-concept-009 房間碼進房、大廳、斷線重連走 MPS Sessions | Decision 2；Decision 4 MVP 重連＝新加入 |
| game-concept-night-shift.md | TR-concept-010 斷線基本保障（偵測、掉落、解鎖、降載） | **部分**：Decision 6 偵測；Decision 7 序列與掉落契約（路由交 G2，解鎖交 ADR-0004） |
| game-concept-night-shift.md | TR-concept-012 NGO client-server＋Relay＋Sessions、client-hosted | Decision 1 |
| systems-index.md | TR-index-021 撲空對稱（房主永不撲空） | **部分**：本 ADR 只提供數字：Host 自身 RPC 走 `LocalSendRpcTarget` 零往返，同區單程 ≈ 44–47 ms（p95 94.5／2）；`host_claim_delay_ms` 的裁決歸 ADR-0004（review :174） |
| systems-index.md | TR-index-022 claim 租約續期、到期只釋放 claim | **部分**：Decision 7 第 3 步只釋放 claim（C10）；租約語意歸 ADR-0004 |
| systems-index.md | TR-index-018 版本 token 涵蓋純內容變更；兩平台同版本同時發版（r2 補列） | **部分**：Decision 5 `BuildId`＋兩層閘門；`HeartbeatWire` 逐欄序列化，避開 wasm32／x64 的佈局相依；雜湊輸入（含 `GetConfig(false)`、`ProductCatalogAsset`）交 G4 |
| game-concept-night-shift.md | TR-concept-001 Web、開連結＋房間碼即玩、進房 ≤ 60 s（r2 補列） | **部分**：Decision 14 分段預算；Decision 2 以碼加入（私人房）；帶碼連結在 ADR-0005 `ILaunchParams`；`T_load` 只有 stall 偵測 |
| first-person-controller.md | TR-fpc-011 狀態實例的鍵；一端 despawn 銷毀兩實例（r2 補列） | **部分**：Decision 4 鍵＝`PeerKey`，與 TR 原文「以玩家 id 為鍵非 slot」衝突，GDD r5 依 Migration 4 改寫；Decision 13 分端表規定非 Host 端以 avatar despawn 清除；ADR-0001／0003 r1 落地 |
| first-person-controller.md | TR-fpc-027 過場結束即可移動；`local_ready` 的定義（r2 補列） | **部分**：Decision 7 前提 4——本機 avatar 的 `OnNetworkSpawn`（`IsLocalPlayer`）就是 `local_ready`；更衣室與店面是否同場景不在本 ADR |
| first-person-controller.md | TR-fpc-028 與 #2 的事件介面（r2 補列） | **部分**：Decision 13 分端來源表（非 Host 端的 `player_joined/left` 來源）；輸入採納的階段驅動歸 ADR-0001 r1 |
| machine-interaction.md | TR-machine-020 `ClaimGeneration` 遞增規則（r2 補列） | **部分**：Decision 7 第 3 步（斷線釋放時 +1）；其餘遞增與仲裁歸 ADR-0004 |
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
- **Load Time**：#26 多一次 Relay allocation＋WSS handshake（同區實測 RTT ≈ 90 ms 量級，allocation 以秒計），已入 `T_spawn ≤ 10 s`；Lobby 不預熱 Relay 是刻意的。r2：自有 handler 在 `StartHost()` 返回後即完成，少掉預設 handler 約 1 s 的輪詢延遲；過截止的中途加入者多付一次 Relay join＋WSS 握手＋approval 才落到 Lobby\*（約 1–3 s，未量）。
- **Network**：4 人房（Host＋3 client）的心跳每 2 s 雙向各一拍，每拍 ≈ 46 B（20 B 酬載＋NGO 層標頭；r2 依 r3 E8 更正 r1 的 ≈ 40 B）：Host 上行 3 × 0.5 Hz × 46 B ≈ 69 B/s，每個 client 上行 ≈ 23 B/s，全房合計 ≈ 138 B/s，可忽略（r2 依審查更正 r1 漏乘的算式）；`Roster`／`ShiftEndTs` 只在變更時同步；離開通知一次 ≤ 1 KB。Host 上行上限與佇列監控待 `[P-16]`（OQ#12 粗估 15–25 KB/s，遠低於 3 GiB/CCU 免費額度）。

## Migration Plan
1. **從 W1 搬進 `src/`**：`ApprovalCallbackTests` 的 approval 註冊寫法、Relay WSS helper（已由 ADR-0005 收編）、`EngineFactProbeTests`（續用為常數契約的斷言）。W1 的 `DiscRoleTests`／`TwoProcessRoleTests` 改寫為 PlayMode 多實例測試樣板。**W1 的 `.jslib` 不搬、重寫**（r2）：它有三個行為不得帶進正式碼——只安裝一次（重裝被忽略，token 換了也換不進去，`W1Web.jslib:67`）、在 `visibilitychange → hidden` 也送出（切分頁就刪房，`:88-92`）、以 `sendBeacon` 為主路徑（`:70-86`）。
2. **新寫**：`NightShift.Identity`（`PeerKind`、`PeerKey`、`PlayerSlot`、`NpcId`；零依賴）；`NightShift.Session.Core`（`SessionMachine`、`SlotTable`、`ApprovalGate`、`HeartbeatMonitor`、`HostLossDisambiguator`、`ShiftEta`、`LeaveBeaconPlan`、`JoinWatchdog`、`RecoveryPolicy`、`SessionConfig`）與 EditMode 測試；`NightShift.Session.Unity`（`SessionServices`、`SessionNetworkHandler`、`NgoBridge`、`SessionRoot`、`HeartbeatWire`、`DisconnectSequencer`、`TransportSwitch`、`SessionConfigAsset`）；`NightShift.Session.Editor`（asmdef `includePlatforms: [Editor]`；建置期斷言）。
3. **既有 ADR 的 r1 義務**（本 ADR Accepted 後；r2 依 r3 CX-7 補齊漏列）：
   - **ADR-0001**：`CapsuleGhost.Id`／`PairKey` 改 `PeerKey`（引用 `NightShift.Identity`），`Solve(…, string selfId, …)` 的 `selfId` 也改 `PeerKey`（r2 補列）；Depends On 補 ADR-0006；`TickRate = 10` 改為引用本 ADR（r2，CX-4）；轉接層提供 `FreezeInput` 參與者；avatar 元件在 `OnNetworkSpawn()` 快取「是否為本機玩家」，`OnGainedOwnership`／`OnOwnershipChanged` 不做輸入、攝影機、HUD 綁定（Decision 7 前提 2）；**r2 新增**：攝影機、HUD、輸入綁定改掛 avatar 的 `OnNetworkSpawn`（`IsLocalPlayer`），不掛 `OnClientConnectedCallback`、不依賴 `OnNetworkSessionSynchronized`，`OnNetworkSpawn` 內不讀 `LocalClient.PlayerObject`；不得在 `OnNetworkSpawn` 假設 `SessionRoot` 已存在，改訂閱 `SessionRoot.Ready`（Decision 6、7）；`PairMachine` 以本端的 avatar spawn／despawn 為在場來源（Decision 13）；新增 pointer lock 的 T1-Web 項（`Cursor.lockState` 在 itch.io iframe 內的重鎖；ADR-0005 r1 的 C6 把 TR-fpc-019／020 交給 ADR-0001，但 ADR-0001 沒有 T1-Web，r3 附錄）。
   - **ADR-0002**：`ClaimState.ClaimedBy` 與 `InteractValidator.Validate(…, ulong requester, …)` 都改為 `byte` slot；`SlotOf` 回 `NoSlot` 的請求在轉接層丟棄；Depends On 補 ADR-0006（r2 補列）；掛在 avatar 上的互動 RPC 元件同樣遵守 ownership 回呼紀律（r2 補列，Decision 7 前提 2）；Verification ③（WSS 上 reliable 的順序）同時是本 ADR 前提 3 (b) 的執行期證據。
   - **ADR-0003**：`PairKey` 改 `PeerKey`；Constraints「狀態實例以玩家 id 為鍵，不以 slot 為鍵（AC19）」與 GDD 對照表的 AC19 列改為以 `PeerKey` 為鍵；Depends On 補 ADR-0006（r2 補列）；遮罩由擁有者端在**本端看到該 slot 的 avatar despawn** 時清位元（r2 依 r3 CX-2：r1 寫「收到 `PlayerLeft(slot)` 時」，非 Host 端收不到這個事件）；:95「新玩家的 `NetworkObject` 物理上不可能存在」**不必改述**——avatar 延後到 `PlayerJoined` 才 spawn，原句恢復成立（r2 撤回 r1 的改述義務）；遮罩元件同樣遵守 ownership 回呼紀律（r2 補列）；`PassThroughNpcMask` 的寬度改由 `NpcId.Max` 推導並靜態斷言。
   - **G2**（`network-object-lifecycle-ownership`，r2 新增本列）：avatar 延後 spawn 的契約（`SpawnAvatar(slot, playerId)`：在線檢查、`Reset()` 寫 NV、冪等，Decision 7 前提 4）；掉落路由 (a)／(b) 二選一（前提 3）；第 5 步 `Despawn(destroy: true)`、同步、不池化（前提 1）；首輪 C3「ownership 轉移後的物件」禁令要明列 avatar 例外（r3 CX-6）；道具的「地面」狀態與持有者欄（r3 GF-12）；`SessionRoot.Ready` 訊號。
   - **ADR-0005**（與本 ADR r2 成對）：`InstallLeaveBeacon(url, method, authorization)`、`ClearLeaveBeacon()`、`SetLeaveConfirmation(bool)`、`RestoredFromBackForwardCache`；只在 `pagehide` 送出；組合根取代自我註冊；桌面退出以 stopped 事件加「leave／delete 的 Task 已完成」判定（不看 `ISession.State`）（見 ADR-0005 r2 修訂紀錄）。
4. **GDD r5 回填**：`netcode-session.md` #20 心跳 payload 補 `host_now_ms`（:379、:865）；#17a／#12／#24a 的 `LeaveSessionAsync` 改為 SDK 實名 `LeaveAsync`（:206、:275、:609）；#24a 補「NGO approval 二次驗證 `PlayerId` 必為 MPS 成員」；OQ#4／OQ#18 標記已裁決並指回本 ADR；`max_players` 的型別註記「容器按 4 設計、MVP 值 2」。`machine-interaction.md` C20 資料契約表（:268）`ClaimState.ClaimedBy` 由 `ulong` 改為 `byte`（slot，`NoSlot = 255`）。**r1 補列**：`netcode-session.md` #24 前置條件（:580-592）補「avatar prefab 也須 `DontDestroyWithOwner = true`，且掉落的道具在每個 client 上都必須存活」；:379 心跳 payload 改 20 bytes；:794 輸入訊號表改為 `pagehide`＋keepalive fetch；:801 `InteractResult`、:807 `RequestHandoff` 的玩家鍵改 slot；適用性矩陣加「主詞」欄並收斂 peer 主詞列的 Disc 欄。`first-person-controller.md` :397-399「以玩家 id 為鍵、不以 slot 為鍵」改為「以 `PeerKey` 為鍵；本端該 slot 的 avatar despawn 時清除該 slot 的一切條目」，AC19 改名為「slot 重用不繼承」（THEN 子句不變）。**r2 補列**（對應 r3 §5）：
   - GF-20：:758 Lobby\* 的定義「approval 閘門拒絕但 MPS 成員已成立」**維持不變**，補一句機制（自有 handler 被拒不 throw，Decision 2）；AC51 照舊成立。
   - GF-9／#9：:161-162 的 UI 預檢改為「私人房在加入前讀不到任何資料，過截止者加入後被拒，即落在 Lobby\*」；#9 與 Lobby\* 約束 (c)（:776）的倒數改讀 `shift_eta` 的 `remaining_ms − (utc_now − published_utc_ms)`。
   - GF-7：AC56 的斷言改在**留守 client** 上做，PlayMode 至少 3 個實例；:588-591 只看 Host 端的寫法同步改；:836-837 的「未經確證」改指本 ADR Decision 7 前提 3。
   - GF-14：#12（:205-209、:232-233、:406、:794）與 AC6c 改寫為「只在 `pagehide` 以 keepalive fetch 送出、`beforeunload` 只掛確認框」；[P-18] 的結論限縮為「事件會觸發」；Safari 在跨源 iframe 不跳框的註記補在 #12 與 AC42。
   - GF-15：適用性矩陣加「主詞」欄（本機／peer／各讀一半）；#24a 歸「各讀一半」。
   - GF-16：:723、:739、:756、AC37 的「Onboarding 期間斷線＝整條跳過 #24」改為「slot 照釋放、成員照移除、NGO 照切；不發 `PlayerLeft`；沒有 avatar 要 despawn」。
   - GF-17：#24 的七步補第 5a 步（`DisconnectTransport`）與「觸發源重複到達以 `NoSlot` 丟棄」；Settlement 期間斷線的跳步規則（Decision 3）。
   - GF-13：:789、:800-802、:807 的契約表改以 slot 為鍵，MPS 事件名更新；`player_joined/left` 在非 Host 端的來源指向 Decision 13 分端表。
   - 更衣室 #10：Onboarding 期間本機沒有 avatar，`local_ready`＝本機 avatar 的 `OnNetworkSpawn`；開班同批不經更衣室，avatar 在 `OnClientConnectedCallback` 時生成（Decision 7 前提 4）。Host 的輸入等 #26 轉場結束才開放。
   - #26：States 表補一條 `InShift → Lobby` 的 `ShiftStartAborted` 邊（Host 端在 handler 成功後寫屬性失敗，Decision 5）；`shift_end_ts` 的「建立時刻」明定為 Host 的 `OnServerStarted`。
   - #9：適用性矩陣 #9 的 Joining 格改為「不預檢截止」；加入後以 `build_token` 比對版本（Decision 5）；`end_shift_early` 時仍在更衣室的人直接進結算（Decision 3）。
   - Tuning Knobs：補 `min_lobby_dwell_ms`（初值由 V11 定）、`network_join_watchdog_ms`（初值 `T_spawn`）、`leave_beacon_refresh_ms`（1000，約束 < 300 000）三列；`max_players` 註明它同時是建房的 `SessionOptions.MaxPlayers`。
5. **registry**（r2 同步，見 `docs/registry/architecture.yaml`）：`session_layer_split` 改為自有 handler、options 工廠、`MaxPlayers = max_players`、`IsPrivate`、每次新的 Type、看門狗與復原（判定在 Core）；`approval_payload` 改為兩層閘門、≤ 69 bytes、`CreatePlayerObject = false`、Host 自身只判第 1–3 項、`OnServerStarted` 掛點、`NotAMember` 先 pending 重查；`session_heartbeat` 補 `InvokePermission = Server`，`SessionRoot` 改述；`session_events` 補分端來源；`session_roster` 補 `PeerPhase`、`ClientId` 作為占用世代；`shift_end_ts` 補 `shift_eta` 的欄位、建立時刻與寫入配對；`session_topology` 補 `IsPrivate`、`PlayerPrefab`、`ProtocolVersion`、`ForceSamePrefabs`，並明定 TickRate 由本 ADR 擁有；`disconnect_sequence` 補 Settlement 分流、`Release(slot)`、第 5 步不池化、第 6 步 `try { await }`、兩個守衛；`solo_offline_transport` 改為掛 `OnServerStopped`；`utp_constants_contract` 補 `SessionConfig` 分層（`UseWebSockets` 改為引用 ADR-0005 的 `relay_transport_protocol`）；`player_identity_key` 補齊 `PlayerId` 的範圍；`clientid_as_player_identity` 補 NGO 呼叫端與 `Roster.ClientId` 的世代例外；`session_logic_outside_core` 補看門狗與復原屬於 Core；`lobby_with_live_relay` 補 Lobby\* 端帳面 allocation 的例外；`lobby_rest_leave_notification` 改為完整 URL、單一標頭、只在 `pagehide` 送出、204 判讀；`avatar_destroyed_with_owner` 補「不得池化、同步」與延後 spawn；`avatar_ownership_callback_side_effects` 擴及 ADR-0002／0003 的 avatar 元件與延後 spawn 下的綁定時點；新增 api_decision `session_network_handler`；新增 forbidden pattern `ngo_start_outside_session_handler`、`disconnectclient_without_reason`、`presence_from_connection_events`。

## Validation Criteria
標號只在各自的層內唯一，引用時一律帶 T0／T1／T1-Web 前綴（r2 依審查加註：r1 的 T1-Web (m)(n) 已改為 (l6)(l7)）。
- **T0 EditMode（純 C#，fake clock）**：
  - (a) 適用性矩陣 32 列 × 11 欄逐格測試，peer 主詞列以 `PeerPhase` 驅動，#9 與 #24a 兩列各讀一半。
  - (b) `ApprovalGate` 六條判定順序；AC54（版本不符不得產生任何 `Approve`）；AC5／AC35（Host 端剩餘 30.5 s 核准；30.0 s（端點，含）與 29.5 s 判 `LateJoinCutoff`，GDD :1458——r2 依審查更正 r1 寫反的「29.5 s 過」）；**Host 本機請求（`IsHostSelf`）在三種 `HostView` 下都永不被拒**：Online（`ShiftEndTsMs` 未設定、`SessionPhase` 仍為 Lobby——r2 依 r3 FV-3 加入）、Solo（`SoloLocalPlayerId`）、Lobby\* 沙盒；`HostShiftStarted` 之後、`ShiftEndTs` 剛固定時的遠端請求一律核准；`ShiftStartAborted` 之後 Host 回到 `Lobby`、`ShiftEndTsMs` 回到 null；第一次 `NotAMember` 帶 `RetryAfterMemberRefresh`，重判仍不在才拒；解碼端對 n > 61 的 payload 判拒。
  - (c) `HeartbeatMonitor`：8.0 s 判、7.9 s 不判（AC27／AC44）、單向失效在 4 拍落後時觸發、offset 收斂 ≤ 100 ms；**`Release(slot)` 後 0.1 s 對同一 slot 呼叫 `OnConnected`，前 4 拍內不得判 `OneWayLoss`**（r2，FV-10）；轉接層的 `HeartbeatWire` 以 `FastBufferWriter` 序列化恰為 20 bytes 且往返等值（EditMode，引用 NGO 但不需連線）。
  - (d) `HostLossDisambiguator` 六列全部可達、矛盾走 `Undetermined`。
  - (e) `SlotTable`：回收後可立即重派同 slot（無指派冷卻），但中途加入者的 `PlayerLeft(s)` 必先於同 slot 的下一個 `PlayerJoined(s)`、間隔 ≥ 定長過場下限 3.0 s；回收後 `SlotOf(舊 clientId)` 回 `NoSlot`；Onboarding 期間斷線不發 `PlayerLeft`、不計 #15a，Core 在同一個 `Step` 取消待發的 `PlayerJoined` 與 `SpawnAvatar`；Settlement 期間斷線照發 `PlayerLeft`、不計 #15a、不重取樣（r2，FV-8）；`end_shift_early` 時仍在 Onboarding 的 peer 直接轉 `Settlement`、不發 `PlayerJoined`（r2）；#15a 第 2 次離線不給寬限（AC50）；`PlayerJoined` 與 `SpawnAvatar` 在同一個 `Step` 輸出；開班同批（`ShiftCohort` 內、本班首次指派、slot 本班未被占用）在 `PeerConnected` 的同一個 `Step` 得到 `PlayerJoined`＋`SpawnAvatar`，同一 `PlayerId` 本班第二次被指派、或分到本班已被占用過的 slot，一律走中途加入（r2）。
  - (f) `SessionConfig.Validate()`（Core 純 C#）對 12 條可機械驗證約束（GDD 的 ①②③⑤⑥⑦⑨⑩⑪⑫⑬，加 `leave_beacon_refresh_ms < 300 000`）的非法組態回傳違規清單。
  - (g) `ShiftEta.RemainingAt`：發布值為 `shift_length_sec`（fixture 取自 `SessionConfig.Default`），晚到 `shift_length_sec − 20` s 的讀者在無牆鐘偏差時顯示 20 s（AC51 的場景）；偏差 ±5 s 時誤差 ≤ 5 s；任何偏差下都不超過 `RemainingMs`、不低於 0（r2，FV-2）。
  - (h) `LeaveBeaconPlan.TryFor`：Host 與 client 的 URL 形狀與 `Bearer ` 前綴；token 變更 → 結果不同；`mode == Solo`、token 為 null、`isDuplicateTab`、`leaveTaskEnded` → 回 false；舊 Teardown 的 leave Task 在新 session 安裝之後才結束 → 新 session 的計畫仍在（世代綁定，r2 依審查）（r2，EA-1、FV-6）。
  - (i) 拒絕原因的分類（轉接層的純函式部分）：`JoinRejectReason` 列舉名精確解析；`^Client-\d+ disconnected by server\.$` 在 connected 之前 → `StaleBuild`，之後 → 不分類（r2，EA-2）。
  - (j) **（r2 新增）** `JoinWatchdog`／`RecoveryPolicy`：#26 那一次 `Changed` 時 handler 尚未被呼叫，不武裝（`attemptInProgress` 或剛開始的嘗試）；已連線的 client 遇到 `shift_seq` 更新不武裝；同一個 seq 只武裝一次；到期重檢不成立就不觸發；`StartFailed` 時 `_session_network` 已移除或換值、`Duplicate`、Teardown 中 → 不復原；同一個 `shift_seq` 第 3 次 → 用盡、輸出 Teardown；退避首次 ≥ 2 s。
- **T1 PlayMode 多實例（Editor 多進程，Relay WSS）**：
  - (g) Lobby 期間無 `NetworkManager` 連線、#26 後 `IsListening`、#23a 後 `NetworkState.Stopped` 且 MPS 的 `SessionState.Connected`（AC52）；Host 的 #23a 以「`StopNetworkAsync` 返回且已觀察到 `OnServerStopped`」為完成點（自有 handler 的 `StopAsync` 不等待，r2）。
  - (h) 遠端 client 被 `StaleBuild` 拒絕時 Host 端零 RPC／NV 收發（AC54）、client 端讀到的 `DisconnectReason` 恰等於列舉名（V2）；另加兩個 NGO 雜湊不符的案例——prefab 清單不同、`TickRate` 不同——斷言 client 歸為 `StaleBuild`、Host 端零 RPC／NV（r2，EA-2）。
  - (i) client `kill -9` 後 Host 於 ≤ 12 s 完成 #24 全序列且 `RemovePlayerAsync` 不拋例外、同帳號重新加入不撞 `Full`（AC6b／AC33／AC36／AC53）；client 先以 keepalive 退出後，Host 第 6 步仍不拋例外（r2，EA-8 更正）。
  - (i′) client 手持道具時斷線——`Shutdown()`（走 `OnClientDisconnectCallback`）與 `kill -9`（走心跳）各一次——**至少 3 個實例**（Host＋2 個 client），每個留守 client 在 2 s 內看到道具落在 Host 的落地座標，Host 與各 client 的道具 `NetworkObjectId` 集合一致（AC10／AC14；V12），且 Host 的本機輸入與攝影機在斷線瞬間不受影響（Decision 7 前提 2）。
  - (i″) 以阻斷單向流量觸發心跳判定後，該 client 退出 `ConnectedClientsIds`，其後送到的 RPC 不進 Core（Decision 7 第 5a 步）。
  - (j) Host `kill -9` 後 client 於 ≤ 12 s 顯示 `HostGone` 並 teardown（AC6b／AC28）。
  - (k) Solo：`SinglePlayerTransport` 下 `StartHost`、`SessionRoot` spawn、approval slot 0、Host 的 avatar 在 `OnServerStarted` 內生成、Settlement 可達；離開 Solo 後在 `OnServerStopped` 指回 `UnityTransport`，隨即建房啟網成功（V3）。
  - (k′) Lobby\* 沙盒進行中，Host 在 `min_lobby_dwell_ms` 一到就重新啟網，等待者最終進入新班次，過程中**沒有** `TransportComponentMissing`（handler 閘門排序，r2）；另加一案：#23a 的屬性移除單獨到達、Lobby 與 #26 合併到達，handler 的閘門主動收掉沙盒；沙盒進行 ≥ 10 s 再收場，Online Core 全程停在 `LobbyWaiting`，零 #18 判定、零 Core 例外（`NgoOwner` 路由，r2）。
  - (l) **（r2 新增，V13）** 中途加入且已過截止，**3 個實例**：handler 的 `StartAsync` 被呼叫、回報 `Rejected(LateJoinCutoff)`；`JoinSessionByCodeAsync` 正常回傳；`session.Network.NetworkHandler == h`；玩家仍是成員，並在 `LobbyWaiting` 停留 ≥ 150 s；停留期間第三人於 InShift 中加入一次（間隔 > `network_join_watchdog_ms`），看門狗零觸發、零 `LeaveAsync`；下一班自動合流。
  - (m) **（r2 新增）** 屬性變更路徑上被拒，兩個案例：① 注入 `LateJoinCutoff`（閘門期間截止線滑過）：`StartFailed` 不發、SDK 沒有 leave、成員資格保留，並進 `LobbyWaiting`；② 注入 `StaleBuild`：`StartFailed` 不發、SDK 沒有 leave，隨後轉接層比對 `build_token` 不符，依 Decision 2 自行 `LeaveAsync`。
  - (n) **（r2 新增，V11）** 看門狗：注入「班次交界時 client 寫 player data」「丟掉一筆 Wire 訊息」「#23a 落在某 client 的 `StartAsync` 進行中」「InShift 期間 ≥ 10 s 無任何 lobby 變更」，斷言等待者在 `network_join_watchdog_ms`＋一次加入的時間內進入新班；反向斷言：正常 #26、3 人房中途有人加入或離開時，已連線 client 的看門狗零觸發、零 `LeaveAsync`；復原途中注入 `RemovePlayer` 429，重新加入用新的 Type、不撞 `SessionTypeAlreadyExists`。
  - (o) **（r2 新增，V14）** avatar 延後 spawn 的事件順序：3 個實例，T1／T2／`LeaveRequested` 各一次，記錄留守 client 上 avatar `OnNetworkDespawn`、`PeerDisconnected`、`Roster.OnValueChanged` 的順序；晚加入者看得到既有 avatar，且 `Slot` NV 在 `OnNetworkSpawn` 時已是正確值；Onboarding 中的玩家在任何一端都沒有 avatar。
  - (p) **（r2 新增）** Host 自核准的第三道防線：Online／Solo／沙盒各注入一次失敗——Online 得到 `SessionException` 加 `StartFailed` 且屬性未發布；Solo／沙盒得到 `StartHost() == false`，且指派已回到 `UnityTransport`。另加一案：注入 `StartRelayNetworkAsync` 的屬性存檔失敗，Host 走 `ShiftStartAborted` 回 Lobby 並發布 `shift_eta(Lobby)` 之後，client 端零啟網嘗試（H4 的屬性撤回）。
  - (q) **（r2 新增，V16）** 同帳號雙開：以碼加入的第二個分頁得到什麼；被判 `Duplicate` 的分頁不 leave、不安裝離開通知、不復原，回主選單後合法分頁仍是成員；`Duplicate` 分頁再次加入不撞 `SessionTypeAlreadyExists`。
  - (r) **（r2 新增）** `NotAMember` 的 Wire 競態：Host 端的 Wire 事件延遲 2 s，中途加入者仍被核准（pending＋`RefreshAsync`）。
  - (s) **（r2 新增）** `JoiningRoom` 逾時：注入 NGO 連線在 `T_spawn` 之後才完成，Core 已走失敗出口回 `Idle`；遲到的加入回傳後立即以過期世代 Teardown，Host 端不生成 avatar。
- **T1-Web Release（IL2CPP＋Stripping High＋Gzip，Playwright；r2 依 r3 FV-4 改寫）**：包裝頁與遊戲頁用兩個不同的 hostname，重現 itch.io 的跨源 iframe；每個案例先在 iframe 內做一次真實點擊以取得 activation；關分頁一律用 `page.close({ runBeforeUnload: true })`——預設的 `page.close()` 不跑任何 unload 處理器，只能當「被殺」的對照組。三引擎（Chromium、Firefox、WebKit）都跑。
  - (l0) 在非 unload 狀態下，以同一個 `.jslib` 函式 dry-run 一次 `DELETE`，斷言 204，證明 CORS 與 token 都通；並記錄錯誤回應的 body（V15）。
  - (l1) Host 於 InShift 關分頁、`dialog.dismiss()` → 對 `lobby.services.api.unity.com` 零 OPTIONS、零 `DELETE`，其他成員 5 s 內沒有收到 `Deleted`。
  - (l2) 同 (l1) 但 `dialog.accept()` → 至多 1 筆 OPTIONS（204）、恰好 1 筆 `DELETE`（204），其他成員 ≤ 1.14 s 量級收到 `Deleted`（AC6c；V10）。WebKit 上斷言「沒有 dialog 事件」，`DELETE` 照樣送出。
  - (l3) Lobby 中關分頁、或 client 關分頁（未掛確認框）→ 不跳框、恰好 1 筆 `DELETE`。
  - (l4) 包裝頁在頂層導航離開再返回 → Chromium 與 WebKit 收到 `persisted = true`、恰好 1 筆 `DELETE`、返回後 iframe 重載、沒有殘留死 session。
  - (l5) 預設的 `page.close()` → 零 `DELETE`，驗證 132 s／30 s 的退化路徑。
  - (l6) client 關分頁 → Host 的心跳路徑 ≤ 8 s（AC16 退化版）。
  - (l7) 背景分頁 30 s／120 s 在 Lobby 不掉房（AC34a／b）、InShift 背景 5.1 s 走 teardown、4.9 s 走 catch-up（AC29）。
  - (l8) **（r2 新增）** 分頁隱藏超過 token 剩餘效期後關閉，記錄 `DELETE` 的回應碼（預期 401，Decision 9 的已知退化）。
  - 另需人工在真實 itch.io 上以桌面 Chrome 驗收 AC42，並以支援範圍內最舊的 Safari 驗 keepalive＋preflight。
- **決策正確的量化標準**：Host 消失全員得知 ≤ `session_end_worstcase_sec` 12 s（取代 87 s）；Lobby 內 Host 優雅離開 ≤ 2 s；版本不符的 client 連線期間 Host 收到的 NetworkVariable delta 數＝0；重連後 `PairMachine`／遮罩中以舊身份殘留的條目數＝0；client 斷線後，Host 與每個 client 的道具 `NetworkObjectId` 集合差＝0；**（r2）過截止的中途加入者被移出 session 的次數＝0；Lobby\* 等待者錯過下一班的比率由 V11 量出、以看門狗收斂到 0**。

## Related Decisions
- ADR-0001 純 C# 移動求解器（分層紀律、`AuthorityMode = Owner`、Decision 9 `adoptInput`；`TickRate = 10` 自 r2 起由本 ADR 擁有，ADR-0001 r1 引用）
- ADR-0002 互動驗證只驗水平（`RequestInteractRpc`、`RpcTarget.Single`、`ClaimState`、`claim_lock_timeout_sec` 保險絲）
- ADR-0003 膠囊與 PassThrough 查詢（遮罩 bit＝slot、3.0 s 地板、`npc_id_reuse_cooldown_sec`、`ChangeOwnership` 不清 NV）
- ADR-0005 平台抽象層（`IPageLifecycle`／`IUnloadNotifier`／`ILaunchParams`／`IRegionSelector`、Relay WSS helper、組合根；r2 成對）
- 待寫：G2 `network-object-lifecycle-ownership`、ADR-0004 `machine-interaction-core`、G8 延遲模型、G9 遊戲時鐘、未來「傳輸協定與混房」ADR、Alpha 的 Steam 整合 ADR
- `design/gdd/netcode-session.md`（r4，2026-09-13）；`design/gdd/machine-interaction.md`（r1，C10／C20）；`docs/architecture/architecture-review-2026-10-01.md`（G1、C1）；`docs/architecture/architecture-review-2026-10-01-r2.md`（§3B、§3C，r1 的修訂依據）；`docs/architecture/architecture-review-2026-10-03-r3.md`（§3A–§4、§6，r2 的修訂依據）
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

## r2 修訂紀錄（2026-10-03）

依 `architecture-review-2026-10-03-r3.md` 修訂，與 ADR-0005 r2 成對。每一條修法都回到 NGO 2.13.2／MPS 2.3.1／Authentication 的原始碼核對過（`prototypes/w1-netcode/Library/PackageCache/`），瀏覽器行為對照 HTML 規範、Blink／Gecko／WebKit 原始碼與 WPT 結果。查證分兩輪：7 個查證 agent 各負責一組必修項，再由 5 個反駁者各守一個視角推翻承重主張；承重主張無一被整條推翻，部分修正 4 條（已併入正文）。

**arlong 2026-10-03 裁決**：① FV-1 採 (a) 轉接層自有 `INetworkHandler`；② avatar 延後到 `PlayerJoined` 才 spawn；③ `pagehide` 不分 `persisted` 一律送出，`pageshow(persisted)` 時重載；④ ADR-0005 改用組合根加一處 `#if`。

| r3 編號 | 嚴重度 | 修訂 | 位置 |
|---|---|---|---|
| FV-1 | 🔴 必修 | 自有 `SessionNetworkHandler` 取代 MPS 預設整合；被拒不 throw，SDK 就不 leave，Lobby\* 在 session 內可達；契約 H1–H7 與 `Bind`；真相規則（`IClientSessionNetwork.State` 不是 NGO 狀態）；`NgoOwner` 路由（沙盒用獨立的 Core）；看門狗（計時器驅動，判定在 Core）；復原只處理真故障；options 工廠（`IsPrivate`、`MaxPlayers = max_players`、每次新的 Type）；加入後比對 `build_token` | Decision 2、5、10；Key Interfaces；V1、V13；T0 (j)；T1 (k′)(l)(m)(n)(r)(s)；Alternative 6、7 |
| FV-3 | 🟡 必修 | Host 自身的請求只判第 1–3 項、不經 #9 矩陣守衛；第三道防線改掛 `OnServerStarted`（三種模式通用）；#26 的時序：Host 在 `OnServerStarted` 固定 `ShiftEndTs` 並轉 InShift，遠端請求必定在這之後；`ShiftStartAborted`；`shift_eta` 與網路屬性同一次存檔 | Decision 3、5；Key Interfaces `ApprovalRequest.IsHostSelf`；T0 (b)；T1 (p) |
| CX-2 | 🟡 必修 | 事件的分端來源表；非 Host 端的在場來源是 avatar 的 spawn／despawn；三條不變式；`OnConnectionEvent` 只供記錄（r3 引的 `OnPeerDisconnectedCallback` 不存在）；`RosterEntry` 加 `Phase`、`ClientId` 當占用世代 | Decision 13；Decision 4；Key Interfaces；V14；T1 (o) |
| EA-1 | 🟡 必修 | 完整 URL 常數 `https://lobby.services.api.unity.com/v1/{id}`（及 `/players/{playerId}`）；只帶 `Authorization`；只有 204 算成功；刪除「第二次的 404 視為成功」；反射守門測試 | Decision 9；Key Interfaces `LeaveBeaconPlan`；T0 (h)；T1-Web (l0) |
| FV-4 | 🟡 必修（與 ADR-0005 共同） | 只在 `pagehide` 送出；`beforeunload` 只掛 Host InShift 的確認框；`persisted` 一律送＋重載（**推翻 r3 Resolution 第二點**，arlong 裁決③）；瀏覽器矩陣（Safari 在跨源 iframe 不跳框；Firefox ≥ 133） | Decision 9；V10；T1-Web (l1)–(l5) |
| FV-5 | 🟡 必修 | `SessionConfig` 改為 Core 純 C#；`Session.Unity` 的 `SessionConfigAsset.ToCore()` | Decision 12；Key Interfaces；Migration 2；T0 (f) |
| EA-4 | 🟡 必修（ADR-0005） | 見 ADR-0005 r2 | — |
| FV-2 | 🟡 應修 | `shift_eta` 加 `published_utc_ms` 與 `shift_seq`；clamp | Decision 5；Key Interfaces `ShiftEta`；T0 (g) |
| FV-6／CX-5 | 🟡 應修 | `LeaveBeaconPlan` 宣告式保鮮（每秒＋階段變更重算）；leave Task 結束後才 `ClearLeaveBeacon()`；桌面退出條件 | Decision 9 |
| EA-2 | 🟡 應修 | 兩層閘門；NGO 雜湊組成；通用字串歸 `StaleBuild`；`NetworkConfig.ProtocolVersion = 0`；禁用無原因的 `DisconnectClient` 多載 | R4；Decision 5、12；T1 (h)；Alternative 10 |
| EA-3（含 FV-7） | 🟡 應修 | `UseUnityTransport` 掛 `OnServerStopped`（**r3 寫的 `OnStopped` 是 internal，更正**）；`Shutdown()` 的時序改述；E13 的「警告是預期的」刪除 | Decision 9、10；Key Interfaces `TransportSwitch` |
| FV-8 | LOW | Settlement 期間斷線的跳步規則；#24a 改歸「各讀一半」 | Decision 3、7 |
| FV-9 | LOW | 架構圖的「①–⑮」改為實際檢查的條數（r2 為 12 條：GDD 11 條＋`leave_beacon_refresh_ms` 上限）；payload ≤ 69 bytes、n ≤ 61；Risks 不再引用不存在的 Alternative | 架構圖；Decision 5；Risks |
| FV-10 | LOW | `HeartbeatMonitor.Release(slot)`；`OnConnected` 全欄重置 | Decision 6；T0 (c) |
| EA-5 | LOW | `HeartbeatToClientRpc` 設 `InvokePermission = Server`；理由更正（代轉會改寫 `SenderClientId`，漏洞在收端不檢查） | Decision 6；Key Interfaces |
| EA-6 | LOW | `SessionRoot` 改述為「`OnServerStarted` 內第一個由轉接層 spawn」；`SessionRoot.Ready` | Decision 6；Key Interfaces |
| EA-7 | LOW | 桌面退出：stopped 事件＋leave／delete 的 Task 已完成（不得看 `ISession.State`：Host 的 `DeleteAsync` 在送出請求前就設 `Disconnected`）；不依賴 MPS 退出時的自動 leave | Decision 9；ADR-0005 r2 |
| EA-8 | NOTE | **前提更正**：SDK 已吞 `PlayerNotFound`（`WrappedLobbyService.cs:342-346`）；第 6 步改為 `try { await }`，`SessionNotFound`／`NotInLobby` 視為完成 | Decision 7 第 6 步；T1 (i) |
| EA-9 | LOW | 見 ADR-0005 r2（`InstallLeaveBeacon` 改收三個字串） | — |
| N5 | LOW | 由 handler 閘門的排序消除 | Decision 2 H1、Decision 10 |
| CX-3 | LOW | 由延後 spawn 解決；ADR-0003 :95 原句恢復成立 | Decision 4、7 |
| CX-4 | LOW | `TickRate` 歸本 ADR；ADR-0003 的 NPC 冷卻規則改為引用 | ADR Dependencies；Decision 1、4、12 |
| CX-6 | LOW | 第 5 步不池化、同步；G2 禁令的 avatar 例外 | Decision 7 前提 1；Migration 3 G2 |
| CX-7 | LOW | Migration 3 補 `Solve` 的 `selfId`、0002／0003 的 Depends On、ownership 回呼紀律擴及 0002／0003 的 avatar 元件 | Migration 3 |
| CX-9 | LOW | `player_identity_key` 範圍、payload 位元組數、Depends On 刪 `IClipboard`、registry 的 `not:` 措辭 | Decision 4、5；ADR Dependencies；registry |
| EA 跨 ADR | LOW | 前提 3 (b) 改述為「原始碼證實同一條 pipeline，執行期待 ADR-0002 V③」 | Decision 7 前提 3 |
| E12 類 | 文件 | GDD 對照表補標「部分」8 列、補 8 列 TR、刪除沒有 TR-ID 的 C10／C20 列 | GDD Requirements Addressed |
| GF-7、14–17、20 | GDD | 列入 Migration 4 的 r2 補列 | Migration 4 |

**原始碼核對時新發現、r3 沒寫到的事**（已寫進正文）：
1. client 啟網沒有公開的手動 API，唯一的控制點是 `WithNetworkHandler`；「加入時不帶 network options 就不會自動啟網」不成立（r3 FV-1 候選 (a) 的子方案）。
2. MPS 2.3.1 從建房那一刻起，每次 Leave／Delete／被踢都會呼叫自訂 handler 的 `StopAsync`，即使從未啟網；照 W1 的寫法「`Shutdown()` 後等 `OnServerStopped`」會在 NGO 沒在跑時永遠掛住，連帶卡住 `DeleteAsync`。
3. 班次交界的屬性合併主要來自 client 自己的 REST 回應（`LobbyCacher` 的 diff），不是 Wire 事件；模組謊報 `Started` 時，新值被靜默吃掉。
4. 延後 spawn 時，對已斷線的 clientId 呼叫 `SpawnAsPlayerObject`，會被 `AddClient` 加回成永遠清不掉的鬼 client。
5. token 遺失讓 MPS session 變成殭屍：不發 `Deleted`、不拆 NGO、還占著 `SessionOptions.Type`。
6. Host 端 `StartRelayNetworkAsync` 若在 handler 成功之後才失敗，MPS 不呼叫 `StopAsync`，NGO Host 會洩漏。
7. `SaveCurrentPlayerDataAsync` 不在 SDK 的清理範圍內，失敗時玩家是成員卻拿不到 `ISession`。

**偏離 r3 建議之處**：
- FV-4：r3 要求 `persisted == true` 時不送；r2 一律送，再於恢復時重載（arlong 裁決③）。理由：Chrome 149+ 與 Safari 進 bfcache 時會關掉 WebSocket，之後被逐出又沒有任何事件，不送就永遠沒人送。
- EA-3：r3 要求掛 `NetworkManager.OnStopped`，那是 internal 事件；r2 改掛 `OnServerStopped`。
- EA-8：r3 的前提有誤（見上表）。
- FV-1：r3 傾向的 (a)「啟網前先讀 `shift_eta`、過截止就不啟網」做不到——handler 拿不到 `ISession`，屬性要等 `JoinSessionByCodeAsync` 返回才讀得到。r2 改為「照常啟網、被拒不 throw」：過截止的人多付一次握手，換來不必依賴 Relay join allocation 的 bind 期限（原始碼與文件都查不到）。
- EA-4：r3 要求註冊方法標 `[Preserve]`；在 Stripping High 下 `[RuntimeInitializeOnLoadMethod]` 本來就是 root（Unity 6000.3 文件），而且 ADR-0005 r2 改用組合根，不再自我註冊。
- EA-1：r3 要求 base path「取 SDK 同一份環境設定、不寫死」；SDK 的 base path 沒有公開 getter，environment 又已編進 token 的 audience，所以改用常數 `LobbyRestBase`，加 PlayMode 反射守門測試（Decision 9）。
- EA-2：r3 建議把 `BuildId`／`ProtocolVersion` 發布為 session property，在 Relay join 之前預檢；私人房在加入前讀不到屬性，SDK 又在 `JoinSessionByCodeAsync` 內就做 Relay join 並啟網，加入前的預檢沒有落點。改為兩件事：handler 把連線前的 NGO 通用字串暫歸 `StaleBuild`；轉接層在加入回傳後立刻比對 `build_token`（Decision 5）。
- FV-6：r3 要求 Teardown 第一步就 `ClearLeaveBeacon()`；改為 leave 的 Task 結束後由宣告式規則清掉，讓 SDK 的 leave 送出之前關分頁時，keepalive 還能補上一筆（Decision 9 第 4 步）。

**草稿審查輪**（寫入前）：r2 草稿另經 6 個視角審查（r3 覆蓋、原始碼引用、一致性、設計攻擊、C#／模板、registry），高嚴重度發現再交反駁者驗證，共 100 條（blocking 2、high 5、medium 32、low 61），原始碼核對 108 處。據此補上的設計：handler 的 `Bind`（初始化路徑上讀不到 session，原寫法會把 FV-1 帶回來）；#26 的 Host 時序與 `ShiftEndTs` 的建立時刻；看門狗改由計時器驅動、判定移入 Core（只在 `Changed` 時判斷，在它要處理的情境裡永遠不觸發）；沙盒用獨立的 Core 與 `NgoOwner` 路由（沙盒的 NGO 回呼原本會被 Online Core 讀成「進 InShift」）；開班同批與中途加入的 `PlayerJoined` 時點分流；加入後的 `build_token` 比對；`MaxPlayers = max_players`；`NotAMember` 先 pending 重查；`T_lobby`／`T_spawn` 分段；每次建房與加入都用新的 `SessionOptions.Type`；H4 的屬性撤回；`NightShift.Session.Unity` 遮蔽根命名空間 `Unity` 的編譯陷阱。

**不在 r2 範圍**（已登記，待各自的 ADR 或文件處理）：`docs/engine-reference/unity/` 的 15 條缺口（r3 §6）；GDD r5 回填（Migration 4）；ADR-0001／0002／0003 r1（Migration 3）；G2；`BuildId` 的雜湊輸入（G4）。
