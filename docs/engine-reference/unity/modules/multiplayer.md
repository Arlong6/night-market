# Module: Multiplayer（NGO + Multiplayer Services）— 本專案最關鍵模組

> Last verified: 2026-09-03
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
- NetworkTransform 重寫：owner-authoritative 為預設；`NetworkTransform.Update` 不可 override（用 `OnUpdate`）
- `AnticipatedNetworkVariable` / `AnticipatedNetworkTransform` 做客端預測
- 2.6+ 用 codegen 取代反射初始化（stripping 相容性較好）

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
