# Module: Multiplayer（NGO + Multiplayer Services）— 本專案最關鍵模組

> Last verified: 2026-09-03；**2026-09-13 W1 第 0 批原始碼查證補充（見下方三段查證區塊）**
> ⚠ `docs-multiplayer.unity3d.com/netcode/current/*` 已全數 301 轉址至
> `docs.unity3d.com/Packages/com.unity.netcode.gameobjects@latest/`——舊書籤與舊訓練資料中的
> 該網域連結現在全部落到 package 首頁，引用時請改用新網域並鎖版本號 `@2.13`。
> 適用：Unity 6.3 LTS、2-4 人 Web 合作派對遊戲（大夜班）
> 主要來源：https://docs.unity.com/en-us/mps-sdk 、
> https://docs.unity3d.com/6000.3/Documentation/Manual/com.unity.netcode.gameobjects.html 、
> https://docs.unity.com/en-us/relay/relay-and-ngo-standalone 、
> https://unity.com/products/gaming-services/pricing

## 套件版本（Unity 6.3 官方對應）

| 套件 | 版本 | 備註 |
|---|---|---|
| Netcode for GameObjects (`com.unity.netcode.gameobjects`) | **2.13.2** | 2.x 是快速釋出線；官方標示 for 6000.3 |
| Multiplayer Services (`com.unity.services.multiplayer`) | **2.3.1** | Lobby/Relay/Matchmaker 統一於此，**別用舊的獨立 Lobby/Relay 套件** |
| Unity Transport (UTP) | 2.x（隨 NGO） | Web 用 WebSocket 介面 |

## NGO 2.x 與訓練資料（1.x）的關鍵差異

- **通用 `[Rpc]` attribute** 取代 `[ServerRpc]`/`[ClientRpc]`——可指定目標（含 client-to-client）、可延遲執行
- **Distributed authority** 拓撲加入（DA session 中 NetworkVariable 預設 owner 寫/全體讀；
  client-server 拓撲仍是 server 權威）
- NetworkTransform 重寫：`NetworkTransform.Update` 不可 override（用 `OnUpdate` / `INetworkUpdateSystem`）
- ⚠ **更正（2026-09-13 原始碼查證）**：先前本檔寫「owner-authoritative 為預設」是**錯的**。
  `AuthorityModes` enum 的 `Server = 0` 是預設值，欄位 `public AuthorityModes AuthorityMode;`
  無初始值，Tooltip 原文「If server (**the default**), then only server-side adjustments…」。
  **client-server 拓撲下 NetworkTransform 預設是 server-authoritative**；只有
  **distributed authority** 拓撲才強制 owner authority。要 owner 權威必須**顯式**設
  `AuthorityMode = Owner`。
- `AnticipatedNetworkVariable` / `AnticipatedNetworkTransform` 做客端預測
- 2.6+ 用 codegen 取代反射初始化（stripping 相容性較好）

## Tick、RPC 與 NetworkVariable 的送出時機（2026-09-13 原始碼查證）

**這三者是分開的，先前被混為一談過：**

| 機制 | 送出時機 | 受 `NetworkConfig.TickRate` 影響？ |
|---|---|---|
| **RPC** | 每**幀**於 `NetworkUpdateStage.PostLateUpdate` 批次送出（`MessageManager.ProcessSendQueues()`，非 tick-gated）；接收端每幀 `EarlyUpdate` 處理 | **否**。60fps 下額外延遲 ≤16.6ms，與 TickRate 是 10 還是 60 無關 |
| **NetworkVariable** | 每個 network **tick** 收集一次 dirty 值後送出 | **是**。10Hz → 最多 +100ms |
| **NetworkTransform** | 每個 network tick 最多一次（`OnNetworkTick()` → `OnUpdateAuthoritativeState()`，全檔唯一呼叫點） | **是**，且**無 per-instance 頻率設定** |

- `NetworkConfig.TickRate` **預設 30**（Inspector 欄位名 `Tick Rate`）。Manual 未載明預設值，
  此值來自原始碼 `public uint TickRate = 30;`
- **NetworkTransform 不能單獨調送出頻率**。全檔 grep `SendRate`／`UpdateRate` 零命中。
  可調的只有「要不要送」的門檻：`PositionThreshold`（0.001f）、`RotAngleThreshold`（0.01f）、
  `ScaleThreshold`（0.01f）
- `NetworkVariableBase.SetUpdateTraits(new NetworkVariableUpdateTraits{ MinSecondsBetweenUpdates,
  MaxSecondsBetweenUpdates })` 是**唯一**的 per-object 節流 API，**只能降頻**，不能超過 tick rate
- **沒有任何公開的「立即 flush」API**（`ProcessSendQueues()` 與 `NetworkBehaviourUpdate(bool forceSend)` 皆 internal）
- `Interpolate` 預設 `true`；`InterpolationBufferTickOffset` 是 **static 全域**，不是 per-instance
  （⚠ XML 文件說預設 1 tick，但欄位宣告無初始值 → 實際 0，需實機以
  `NetworkTransform.GetTickLatencyInSeconds()` 確認）

**對延遲預算的直接後果**：需要低延遲的請求/回應（例如互動確認）**必須走 RPC，不得用
NetworkVariable 承載結果**。前者與 tick rate 無關，後者在 10Hz 下單邊就 +100ms。

## Ownership 與斷線處置（2026-09-13 原始碼查證，NGO 2.13.2）

- `NetworkObject.DontDestroyWithOwner` 是 **public bool field**（不是 property），**預設 `false`**
  （宣告無初始值；Tooltip 明寫 "default disabled"）。Inspector 可勾選，亦可程式碼設定。
- **預設行為＝owner 斷線時，其擁有的所有 spawned NetworkObject 會被 despawn 並 destroy。**
- ⚠ **處置發生在 `OnClientDisconnectCallback` 之前**，且在同一個同步方法
  （`NetworkConnectionManager.OnClientDisconnectFromServer`）的同一個 call stack 內。
  **無法在 disconnect callback 裡搶救物件**，那時它已不在 `SpawnedObjects` 裡。
- 設 `DontDestroyWithOwner = true` 時，client-server 走 `RemoveOwnership()` 分支 →
  ownership 交還 server，物件保留、NetworkObjectId 不變（不複製）。
- ⚠ **但官方對「保留時物件的 transform／parent 會怎樣」完全無記載**。`RemoveOwnership()`
  不做 unparent。道具若 parented 到玩家身上，玩家 GameObject 被銷毀時道具會跟著走。
  **「掉落在原地」必須自己在 server 端實作**（偵測 disconnect → unparent → 設落地座標）。
- ⚠ **版本陷阱**：`DontDestroyWithOwner` 在 **2.4.0 之前是壞的**（CHANGELOG：2.4.0 修
  "not being honored" #3477；2.4.3 修 client-server 下 `false` 時不被銷毀 #3522）。
  2.13.2 已含修正，但**網路上 2025 年上半年的討論與範例不可信**。

**Ownership transfer（client-server）**：
- API：`NetworkObject.ChangeOwnership(ulong)` / `NetworkObject.RemoveOwnership()`
- **只有 server 能發起**（非 server 呼叫 → `LogError("Only the server can change ownership! (ignoring)")` 後 return）
- **server 端提交是同步、原子的**：函式返回時 `OwnerClientId` 已是新值，
  `OnLostOwnership`／`OnGainedOwnership`／`OnOwnershipChanged` 皆已觸發。
  **client-server 下不存在 pending／待確認的中間態**
- ⚠ `ChangeOwnership` 回傳 `void`，**失敗是靜默的**——四條 early-return 路徑（未 spawned、
  目標已是 owner、非 server 呼叫、**目標不在 `Observers` 裡**）各只寫一行 log。
  安全做法是呼叫後**回讀 `OwnerClientId`** 確認
- ⚠ **兩次 ownership 變更之間至少間隔 6 個 network tick**，否則 owner-write 的
  NetworkVariable 更新可能遺失（原始碼 `k_MaximumTickOwnershipChangeMultiplier = 6`，
  超過會 `LogWarningServer("[Rapid Ownership Change Detected][Potential Loss in State]…")`）
- ⚠ `OwnershipStatus`／`SetOwnershipLock`／`RequestOwnership`／`IsRequestInProgress` 等整套
  權限機制**只在 distributed authority 有效**（官方文件明文：「Permissions are only valid
  when using the distributed authority network topology」）。**網路上大量 NGO 2.x ownership
  教學講的是 DA 模式，本專案不適用，不要照抄。**

## 逾時常數（2026-09-13 查證，UTP 2.6.0 / NGO 2.13.2）

| 欄位（`UnityTransport` 元件） | 預設值 | 說明 |
|---|---|---|
| `DisconnectTimeoutMS` | **30000**（30s） | 收不到任何封包多久判定 disconnect。**1.x→2.x 無更名** |
| `HeartbeatTimeoutMS` | **500** | UTP 連線 heartbeat 間隔 |
| `ConnectTimeoutMS` | 1000 | 連線嘗試間隔 |
| `MaxConnectAttempts` | 60 | 連線嘗試次數上限（× ConnectTimeout = 60s 總逾時） |
| `NetworkConfig.ClientConnectionBufferTimeout` | **10**（秒） | server 等待 connection approval 握手完成的時間，**獨立於 transport 逾時** |

- ⚠ **`HeartbeatTimeoutMS` 是雙重用途**：NGO 把它當成 **Relay PING 間隔**傳下去
  （`settings.WithRelayParameters(ref m_RelayServerData, m_HeartbeatTimeoutMS)`）。
  **調大到 >10s 會同時破壞 Relay keepalive 而被踢。建議不要動這個值。**
- ⚠ `ReconnectionTimeoutMS` **僅支援 DTLS**（文件明文）→ **WSS 沒有 transport 層自動重連**，
  重連必須完全由 app 層實作
- ⚠ `DisconnectTimeoutMS` 會影響 send queue 容量（`MaxSendQueueSize <= 0` 時由它推算）。
  調小會連帶縮小佇列，可能造成 `NetworkSendQueueFull`

## Relay 連線存活（2026-09-13 查證）

- **沒有以 allocation 為單位的 idle timeout**。文件記載的是**每個 client 連線的 TTL**：
  **10 秒**（一般），**60 秒**（host 在 BIND 後、尚無 peer CONNECT 時）
- **任何經過該 client 的訊息都會重置 TTL**；NGO 每 `HeartbeatTimeoutMS`（500ms）自動送 PING
- TTL **官方未記載任何設定方式**（不要寫成「可調」）
- ⚠ **最高風險**：瀏覽器會節流背景分頁的 timer，PING 可能停送 → **背景 10 秒即被 Relay 踢**。
  這是 Web build 的重大約束，任何「切分頁很久還要保住連線」的設計都要先過這一關

## 房間碼流程（就是本專案要的，官方直給）

```csharp
// 共同前置
await UnityServices.InitializeAsync();
await AuthenticationService.Instance.SignInAnonymouslyAsync();

// Host：
var options = new SessionOptions { MaxPlayers = 4 }.WithRelayNetwork();
var session = await MultiplayerService.Instance.CreateSessionAsync(options);
// 把 session.Code（人類可讀房間碼）顯示給玩家分享

// Client：
var session = await MultiplayerService.Instance.JoinSessionByCodeAsync(joinCode);
// Session 會自動處理 lobby、Relay allocation、NGO 連線
// 連線狀態：session.Network.State / StateChanged
```

## Web (WebGL) 組態

- `UnityTransport.UseWebSockets = true`（NetworkManager 上）
- Relay allocation 要求 connection type **`"wss"`**（HTTPS 頁面必須；itch.io 是 HTTPS）
- Relay 同時支援 UDP/DTLS/WSS——桌面玩家走 DTLS、Web 玩家走 WSS 可同房
- Distributed authority 也正式支援 WebGL（NGO 2.1.1+、UTP 2.3.0+、MPS 1.0.2+；
  DistributedAuthorityTransport 開 "Use Web Sockets"；TLS 由 Unity 雲端終結，免自簽憑證）

## 免費額度（2026-09 查證）

- **Relay**：前 50 平均月 CCU 免費（≈216 萬連線分鐘）＋ 3GiB/CCU 流量（上限 150GiB/月）；
  超出 $0.16/CCU、$0.09-0.16/GiB。**未超額不需綁卡。**
- **Lobby**：10GiB/月/區域群免費
- **Distributed Authority**：6,000 連線小時＋100GiB/月免費
- 對 2-4 人派對遊戲：免費額度≈每月數千場，商業化前碰不到帳單

## 本專案建議架構（分析結論，非官方原文）

1. **首選：client-as-host + Relay(WSS) + MPS Sessions**——標準 server 權威 NGO 寫法、
   零伺服器維運、房間碼原生支援、Boss Room 同款遷移路徑
2. 備選：distributed authority（Web 官方 quickstart 存在、免 host migration 痛點），
   但 authority 心智模型不同且綁 Unity 雲——2-4 人容忍延遲的本作用不到它的好處
3. 免費額度爆了才考慮：自架 WebSocket dedicated server（nginx/caddy 終結 wss 反代 Unity headless）
4. `WithDirectNetwork()` 對 Web 無意義（瀏覽器不能收 inbound）——不用

## 樣板與範例

- **6.3 Hub 新增 Multiplayer FPS / Third-Person 模板**（NGO＋Building Blocks）——
  Web 支援未聲明，參考架構用，別假設能直接出 Web
- Boss Room v3.0.0（2025-08）：已遷移至 MPS Sessions——遷移寫法的參考；無 WebGL 支援
- Asteroids Bitesize：DA 的官方小樣本
- 注意：**沒有官方端到端的「Relay-over-WSS Web」成品範例**——第一個原型就是在補這個證明
