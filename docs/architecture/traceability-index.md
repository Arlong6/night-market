# Architecture Traceability Index — 大夜班 (Night Shift)

> Last Updated: 2026-10-03（r3：ADR-0006 r1＋ADR-0005 r1 寫入後重跑）
> Engine: Unity 6.3 LTS (6000.3) ／ NGO 2.13.2 ／ MPS 2.3.1 ／ UTP 2.7.4
> Source: `/architecture-review` full——r3 報告 `docs/architecture/architecture-review-2026-10-03-r3.md`；r2 報告 `architecture-review-2026-10-01-r2.md`；首輪報告 `architecture-review-2026-10-01.md`
> TR-ID 權威來源：`docs/architecture/tr-registry.yaml`（本檔的 ADR 欄為審查當日快照）
> 狀態欄的「（r3 ↑／↓）」標記本輪變動，「（r2 ↑／↓）」為前一輪；理由欄以「r3：」起頭的部分為本輪更新，其中 FV／EA／CX／GF 編號指 r3 報告；§3A／§3C／§4 指 r2 報告章節

## Coverage Summary
- Total requirements: **228**
- Covered: 71（31.1%）
- Partial: 74（32.5%）
- Gaps: 83（36.4%）
- Foundation 層 Gap：20（product 13／machine 4／fpc 2／netcode 1）——首輪為 30（首輪報告誤記 29，漏算 TR-fpc-040）
- r3 與 r2 數字相同：TR-netcode-007 ↑、TR-netcode-010 ↓ 互相抵銷；另 22 列理由更新

| GDD | TR | ✅ | ⚠️ | ❌ | 首輪 |
|---|---|---|---|---|---|
| netcode-session.md（#1/#2） | 46 | 25 | 19 | 2 | 7／18／20 |
| first-person-controller.md（#3） | 44 | 26 | 11 | 7 | 27／10／7 |
| machine-interaction.md（#5） | 57 | 7 | 18 | 32 | 6／16／35 |
| product-database.md（#6） | 34 | 0 | 5 | 29 | 0／4／30 |
| 概念＋系統索引 | 47 | 13 | 21 | 13 | 10／22／15 |

## Full Matrix

### GDD: netcode-session.md（系統 #1 Session／房間系統 ＋ #2 網路同步層；Foundation／Core）

縮寫：L＝GDD 行號；D＝ADR Decision。

| ID | 需求 | GDD 行 | Domain | Layer | ADR | 狀態 | 理由 |
|---|---|---|---|---|---|---|---|
| TR-netcode-001 | Host 權威：NPC／波次／計分／班次時鐘／共用道具／結算 | #1 L95 | State | Foundation | 0006/0003 | ✅ Covered（r2 ↑） | ADR-0006 D1 正式裁決 client-as-host（Host＝權威）；D13 `ShiftEndTs` Host 寫；NPC 權威 0003 |
| TR-netcode-002 | Owner 權威移動；`AuthorityMode=Owner` 顯式＋runtime guard | #2 L96-103 | Net | Core | 0001 | ✅ Covered | D5 |
| TR-netcode-003 | request→Host validate→broadcast；樂觀動畫≤100ms；拒絕撲空不回滾 | #3/#5 L104-113 | Net | Core | 0002 | ✅ Covered | RPC 契約＋D4 |
| TR-netcode-004 | Claim 三元組同一 NetworkVariable struct（`INetworkSerializable`+`IEquatable`）；世代比對；lock 5s 含端點、仲裁純 C# | #4 L108-111,844,1112 | Data | Core | 0002 | ⚠️ Partial | 未提 IEquatable／lock 計時 |
| TR-netcode-005 | 交接＝`ChangeOwnership` 同步原子；回讀 `OwnerClientId` 才廣播；僅 server；拋物線不同步、socket 遮蔽 | #6/#7 L116-137 | Net | Core | — | ❌ Gap | 0002 僅稱述詞可沿用 |
| TR-netcode-006 | 交接冷卻≥6 tick；攜帶物狀態不得放 owner-write NetworkVariable（遺失窗口≈1 tick） | L131-134,1639 | Net | Core | 0002 | ⚠️ Partial | 約束⑧只涵蓋互動結果 |
| TR-netcode-007 | 房間碼＝`session.Code`，大小寫不敏感、可貼上；輸碼必備備援；帶碼連結須解析 `document.referrer` | #8 L140-150,1614 | Plat | Feature | 0005/0006 | ✅ Covered（r3 ↑） | 0005 r1 iframe 內讀 `document.referrer`（:87）、可為 null、輸碼備援不可砍（:146）；房間碼走 `JoinSessionByCodeAsync`（0006 D2）。大小寫不敏感／可貼上屬 GDD #8 的 UI 規則（MPS 不做大小寫正規化，轉接層或 UI 自轉） |
| TR-netcode-008 | 截止閘門唯一執行點＝`ConnectionApprovalCallback`，Host 側 `shift_end_ts−now`；MPS custom data 預檢非權威 | #9 L153-176 | Net | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D5 第 4 項（含端點）為唯一執行點；預檢非權威。r3：預檢改讀 `shift_eta`，晚到者讀到舊值（FV-2）；被拒的中途加入者會被 MPS 移出 session（FV-1），影響 #9「拒絕後導向 Lobby\*」，那半句不在本 TR 文字內 |
| TR-netcode-009 | approval payload 帶 build/protocol version，不符即拒（任何資料交換前） | L163-165,AC54 | Sec | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D5 payload＋第 1 項 `StaleBuild`。r3：AC54 成立，但 NGO 設定雜湊（含 prefab 清單）先於 approval 擋人、給通用原因，真正的舊版 build 多半拿不到 `StaleBuild` 店語（EA-2） |
| TR-netcode-010 | Host 關頁＝局終（無 migration）；`beforeunload`+`pagehide`→`sendBeacon`／`DeleteAsync`；處理冪等；確認框 best-effort | #12 L195-237 | Plat | Core | 0006/0005 | ⚠️ Partial（r3 ↓） | 0006 D9 雙掛＋keepalive fetch＋送出端單發、D11 無 migration。r3：TR 原文「確認框 best-effort」無 ADR 決策、`IUnloadNotifier` 無確認框介面（GDD AC42 MVP）；單發旗標下實際送出的是 `beforeunload`，按「留下」時 DELETE 已送出（FV-4）；REST 路徑見 EA-1；V10 未驗 |
| TR-netcode-011 | 進房預算 T_load≤25／T_lobby≤10／T_spawn≤10 各自硬閘門；auth 預熱並行 | #13 L218,898-907 | Perf | Foundation | 0006 | ⚠️ Partial（r2 ↑） | 0006 D14 `T_lobby`／`T_spawn` 為 Core 狀態計時＋`MaxConnectAttempts=10`；`T_load` 只有 stall 偵測（TR-026 仍 Partial）；auth 預熱並行未定 |
| TR-netcode-012 | 離線立即重取樣 `online_player_count`；grace／`host_solo` 旗標→波次導演；#15a 身分＝`AuthenticationService.PlayerId` | #14-16 L223-254,928 | State | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D7 第 7 步重取樣＋grace／`host_solo`；D4 #15a 以 `PlayerId` 為鍵、班次範圍；D13 `OnlinePlayerCountChanged` |
| TR-netcode-013 | `visibilitychange` 於 `.jslib` 以 `performance.now()` 標記；≤5s catch-up（公式③純邏輯）／>5s teardown；僅 InShift | #17 L257-270,909-926 | Plat | Core | 0005/0006 | ⚠️ Partial | >5 s 分支已是 0006 D9 的 Teardown 邊；≤5 s 的公式③ catch-up 仍無擁有者（G9） |
| TR-netcode-014 | teardown 不變式：任何 InShift→Idle 先 `Shutdown()`+`ISession.LeaveAsync()` 再切 UI | #17a L272-283 | Net | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D9：每條進 Idle 的邊恰一個 `Teardown` 效果，固定順序 `Shutdown()`→`LeaveAsync()`／`DeleteAsync()`→切 UI（與 MPS 警告的關係見 §5） |
| TR-netcode-015 | Host 消失排歧：MPS 層與 Relay 層獨立；序：session 事件→`onLine` false→`HasPlayer(Host)`→`State` | #18 L284-348 | Net | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D8 `HostLossDisambiguator` 實作 GDD 六列優先表 |
| TR-netcode-016 | 單物件 sequence（併 ClaimGeneration）、無全域序號；跨 channel 順序待驗 | #19 L356-360 | Data | Core | 0002 | ⚠️ Partial | 僅 Verification③／D8 |
| TR-netcode-017 | app 心跳 2s/8s 自 NGO 連線起；payload `{seq,last_peer_seq_seen,host_shift_end_ts,host_now_ms}`；雙向存活→單向失效走 #24；offset≤100ms 與 ping 同源；87s→12s 唯一機制 | #20 L362-406,864-868 | Net | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D6 全條。r3：E8 已修——Core 純 BCL `HeartbeatPayload`＋轉接層 `HeartbeatWire : INetworkSerializable`，酬載恰 20 bytes；GDD :379 仍寫 16，待 r5 |
| TR-netcode-018 | UTP send queue 溢位防護：Host 每 tick payload 上限＋佇列深度監控 | L398,P-16,OQ12 | Perf | Foundation | 0006 | ⚠️ Partial（r2 ↑） | 0006 D12 `MaxSendQueueSize` 顯式＋監控點必備；值與 Host 出站上限待 `[P-16]`（V6，W2） |
| TR-netcode-019 | Lobby 延後建連：`WithNetworkOptions(WSS)` 不啟動；開始上班才 `StartRelayNetworkAsync`；局間 `StopNetworkAsync` 回 MPS-only；重建成本入 T_spawn | #23/23a/26 L415-506,663 | Net | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D2 兩層壽命＋forbidden `lobby_with_live_relay`。r3：r1 新增的 `StartFailed` 復原對「中途加入被拒」無效（轉接層拿到 `ISession` 前就失敗，FV-1）；transport 切換時機見 EA-3 |
| TR-netcode-020 | WSS 每角色各自宣告（Join 亦需）＋`UseWebSockets=true`，集中 helper | L468-485 | Net | Foundation | 0005 | ✅ Covered | D6 |
| TR-netcode-021 | UTP 常數契約：`HeartbeatTimeoutMS=500` 不得動（兼 Relay PING）；`DisconnectTimeoutMS` 30s；`ClientConnectionBufferTimeout` 10s；連線總逾時 60s 應調小 | L529,1187,1230 | Net | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D12 常數表＋registry `utp_constants_contract` |
| TR-netcode-022 | 複製邀請連結：Clipboard 需 gesture＋`.jslib`；itch.io iframe 無 `clipboard-write`→文字框 fallback | L573,1638 | Plat | Feature | 0005 | ✅ Covered | `IClipboard` |
| TR-netcode-023 | 道具 `DontDestroyWithOwner=true`、Host 自行 unparent＋落地座標；斷線處置 7 步原子序列≤2s | #24 L580-605 | Net | Core | 0006（＋G2） | ⚠️ Partial（r2 ↑） | 0006 D7 定序與 2 s 上限。r3：E1 契約層已修（avatar 亦 `DontDestroyWithOwner`、道具須在每個 client 存活、推薦 client 端 `OnNetworkDespawn` 自救，原始碼可行）；Host 自行 unparent＋落地座標與 (a)／(b) 路由仍交 G2 |
| TR-netcode-024 | MPS 成員唯一寫入者＝Host（`AsHost().RemovePlayerAsync`）；`max_players` 執行點＝MPS join；`session_member_count`≠`online_player_count` | #24a L607-617,192 | Net | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D7 第 6 步 `RemovePlayerAsync`（Host 唯一寫入者）；`SlotTable.OnlineCount` 與 `session.PlayerCount` 分離 |
| TR-netcode-025 | Lobby Host 離開＝訂閱 `ISession` 事件＋本地 `lobby_host_silence_timeout_sec` 30s | #25 L619-661 | Net | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D8 末段：Lobby 訂閱 `ISession` 事件＋Core 計時 30 s，不等服務端 |
| TR-netcode-026 | 冷啟動 stall 偵測在 loader HTML 層→LoadFailed；客製 Web Template 取代預設 loader | #27 L672-677,76-85 | Plat | Presentation | 0005 | ⚠️ Partial | 只標位置無介面 |
| TR-netcode-027 | Relay region 貼著 Host：`.jslib` `Intl` 查表→fallback→可覆寫→`RelayNetworkOptions`；同區 RTT≤300、跨區降級契約 | #28 L679-702,1238,AC22a | Plat | Core | 0005/0006 | ⚠️ Partial | 0006 D2 定 `IRegionSelector`→`RelayNetworkOptions(region)` 於 #26；跨區降級契約（AC22a）仍無 |
| TR-netcode-028 | 狀態機 12 態（適用性矩陣 32 列 × 11 欄，Booting／LoadFailed 合欄）；Disconnected 僅由 InShift 進入；Lobby* 同 session 合流、沙盒不共享狀態；Host 獨留不結束 | L704-776,408 | State | Core | 0006 | ⚠️ Partial（r2 ↑） | 0006 D3 12 態＋32×11 守衛表＋主詞表＋Onboarding 回收（E4 已修）。r3 殘留：Settlement 欄的 peer 分流與 D7 衝突（FV-8）；**Lobby\* 入口在 MPS 2.3.1 下不可達（FV-1，HIGH）** |
| TR-netcode-029 | 本層輸入訊號表（NGO 四 callback、MPS 事件、瀏覽器三組）＋下游 11 系統契約表 | L780-810 | X-sys | Core | 0006/0002/0003/0005 | ⚠️ Partial | 0006 D13 `session_events`。r3：GDD :794／:801／:807 已列入 Migration 4；`local_ready` 仍無 ADR 定義；非 Host 端的事件來源未定（CX-2） |
| TR-netcode-030 | 同步頻率：`NetworkConfig.TickRate=10`（連帶 NetworkVariable 10Hz 須確認無害）；NPC 事件≥0.2s；RPC 不受 tick | L812-818,1185 | Perf | Foundation | 0001 | ⚠️ Partial | 連帶效應未評 |
| TR-netcode-031 | 單一場景、不啟用 `NetworkSceneManager`；更衣室為本地 UI 疊層、定長 3–5s、同步未完仍進場 | L821-822,177-185 | Scene | Foundation | 0006 | ⚠️ Partial（r2 ↑） | 0006 D1 `EnableSceneManagement=false`；D4 依賴更衣室 3.0 s 下限；「同步未完仍進場」runtime 規則無 ADR |
| TR-netcode-032 | 狀態真相走 NetworkVariable（Host 寫），RPC 只驅動表現層；不重播歷史 RPC | L823-826 | Data | Foundation | 0003 | ✅ Covered | 0002 D8 同 |
| TR-netcode-033 | 同步物件一律 Host 動態 spawn＋`NetworkPrefabsList`；禁 scene-placed；Addressables 共存、單執行緒寫死待 Web 平台 ADR | L827-829,1165,OQ6/11 | Scene | Foundation | — | ❌ Gap | 無 |
| TR-netcode-034 | RPC 一律 `[Rpc]` 禁 `[ServerRpc]/[ClientRpc]`；不繼承 `NetworkTransform`、`Update` 不可 override | L838-843 | Net | Foundation | 0001/0002 | ✅ Covered | D6／`[Rpc(SendTo.Server)]` |
| TR-netcode-035 | 重連身分 `PlayerId`↔slot 自建對照（ClientId 會變）；Post 重連窗口受 Relay 每 client TTL 10s 限制 | L849-851,886-896,1229 | Data | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D4 identity 契約：`PlayerId↔slot↔clientId`、MVP 重連＝新加入；Post-MVP 保留窗口列 V8 |
| TR-netcode-036 | 班次時鐘真相＝Host `shift_end_ts` NetworkVariable；`end_shift_early` 直接改寫；剩餘判定一律 Host 側 | L853-868,212 | State | Core | 0006 | ✅ Covered（r2 ↑） | 0006 D13 `SessionRoot.ShiftEndTs`（Host 寫 NV）；`end_shift_early` 直接改寫 |
| TR-netcode-037 | 模擬不快轉不補跑；三類物件顯示層各自追平；client NPC 凍結只套最新 milestone | L870-882 | State | Core | 0003 | ⚠️ Partial | 僅引為收斂前提 |
| TR-netcode-038 | 建置規範：Gzip＋`decompressionFallback=false`、≤44MB、Stripping High＋`[Preserve]`、CJK 字型子集化 | L1017-1049,1338 | Plat | Foundation | 0005 | ⚠️ Partial | 僅 `[Preserve]` 位置 |
| TR-netcode-039 | 上游 UGS 初始化／匿名登入失敗→ServiceError；單人模式不經 UGS | L1136,753 | Plat | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D10 Solo 零 UGS、`SinglePlayerTransport`（E3）、Solo／沙盒 `MemberIds`（E2 第 2 項）。r3：Online Host 自核准的第 4 項與掛點殘留歸 FV-3，不在本 TR 文字內；V3 待驗 |
| TR-netcode-040 | 退路 plan B：Distributed Authority（官方 Web 支援）／自架 headless＋wss 反代 | L1142-1153 | Net | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D1 兩條退路與觸發條件 |
| TR-netcode-041 | 常數 data-driven 登錄 registry；約束①–⑮ 非法組態應可機械驗證 | L1173-1241 | Data | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D12 `SessionConfig`＋`Validate()` 11 條（E9 已修）。r3：`SessionConfig` 為 ScriptableObject 卻放在 Core（FV-5），屬分層細節，不影響可機械驗證 |
| TR-netcode-042 | 約束⑧ 互動請求／結果一律走 RPC（越權 owner-write delta 中止整則訊息解析） | L1233,1639 | Net | Core | 0002 | ✅ Covered | Constraints 明列 |
| TR-netcode-043 | `interpolation_buffer_ms=150` 不對應 NGO（≥2 tick 隨 RTT）；`remote_step_tolerance` 未定義 | L1188,AC15/23 | Perf | Core | 0002 | ⚠️ Partial | levy 已提未解 |
| TR-netcode-044 | 測試分層：EditMode 純邏輯（心跳／公式③④／排歧／世代）；PlayMode 多實例；Playwright 實機 Release；鉤子 build flag 隔離 | L1493-1542 | Test | Foundation | 0006/0001/0002/0003/0005 | ⚠️ Partial | 0006 D3 `Session.Core`（noEngineReferences）＋T0／T1／T1-Web 分層補上 session 核心；公式③ 歸屬與測試鉤子的 build flag 隔離仍未定 |
| TR-netcode-045 | `connection_state` 枚舉→店語字串表 data-driven，禁技術詞 | L1300-1336 | Pres | Presentation | 0006 | ✅ Covered（r2 ↑） | 0006 D13 `ConnectionState` 為 UI 唯一連線狀態來源，店語表 data-driven |
| TR-netcode-046 | 未建 NGO 連線的端（Lobby 預檢、Lobby* 等待畫面）須能顯示班次剩餘時間；表示法不得依賴心跳 offset | #9 L161；Lobby* 約束 (c) L776 | State | Core | 0006 | ⚠️ Partial（r2 新增） | 0006 D5 改發 `shift_eta` 相對量（E5 時間基準已解）。r3：只在階段改變時重發、屬性不帶發布時刻，晚到讀者誤差等於屬性年齡（FV-2）；Lobby\* 等待者在主路徑上可能已不是成員（FV-1） |

小計（r2）：Covered 25／Partial 19／Gap 2（共 46）〔前次 7／18／20〕。ADR-0006 收掉 G1；剩 Gap 只有 TR-netcode-005、033（皆歸 G2）。Partial 中屬 ADR-0006 r1 待修的：011、018、023、028、031、044（§3C）

**需 ADR 才能關閉的 OQ**：「session 層 ADR」（L1171；MPS 成員寫入者、approval 閘門＋版本閘、心跳 payload）→ TR 008／009／017／023／024／025；「Web 平台 ADR」（單執行緒寫死 OQ6、`NetworkPrefabsList`×Addressables／`AddNetworkPrefab` 順序 OQ11、CJK 字型子集化）；OQ4 單人模式是否不初始化 UGS；OQ12＋P-16 頻寬上限／send queue 深度；OQ18 host migration（MPS API 為一等公民；牽動 #12／#21／AC6b／AC13b）；OQ10／OQ13 行動端閾值與 WebGL context loss；P-5 跨 channel 順序（與 ADR-0002 Verification③ 同題）；`remote_step_tolerance` 定義與歸屬；plan B 拓撲（DA）是否以 ADR 記錄為正式退路。

**本 GDD 已承諾給 ADR 的前提**：ADR-0001←Core Rule #2、`network_tick_rate=10`、`visibilitychange` 通道；ADR-0002←#3–#5、約束⑧、L1238 RTT 實測（ADR-0002 反向 levy `interpolation_buffer_ms` 尚未回應）；ADR-0003←更衣室 3.0 s 硬下限 L177、L803／L823-826／L881-882；ADR-0005←#8／#12／#17／#20／#27／#28 瀏覽器能力、桌面 `runInBackground=true` 契約。

### GDD: first-person-controller.md（系統 #3 第一人稱控制器；Core）

| ID | 需求 | GDD 節／行 | Domain | Layer | ADR | 狀態 | 理由 |
|---|---|---|---|---|---|---|---|
| TR-fpc-001 | 求解器純 C#，不引用 UnityEngine／NGO／InputSystem；31 條 T0 可 EditMode 跑 | AC 分層 :1141-1145；C1 :154；OQ-F11 :1605 | Testing/Movement | Core | 0001 | ✅ Covered | `noEngineReferences`＋grep 雙鎖，32/32 實證 |
| TR-fpc-002 | 無移動狀態機／無姿態 enum；Movement action map 恰 `{Move2D, Look2D}`；反射列舉可行 | C1 :157-166；AC1 :1156-1168 | Input/Movement | Core | 0001 | ✅ Covered | D7 限定 action map 範圍；V③ link.xml |
| TR-fpc-003 | `player_move_speed_max` 具名、`provisional` 標記、記錄三輸入、無其他速度字面量、資料驅動可調 | :15-20；AC2 :1172-1181；AC32 :1513 | Data | Foundation | 0001 | ⚠️ Partial | `K` 對應 entities.yaml，但執行期資料驅動載入機制未定 |
| TR-fpc-004 | 單幀預算 `v×min(dt,0.10)` 涵蓋輸入＋解除穿透；斜向正規化；整條鏈路（含 Unity 層）成立 | C12 :306-327；AC3/4 :1183-1200 | Movement | Core | 0001 | ✅ Covered | Core 夾制＋場景碰撞只能縮短＋投影不等式 |
| TR-fpc-005 | 解除穿透先於加總；超預算時犧牲輸入、不等比縮放 | C9 :255-258；Edge :815-817；AC10/11 :1295-1308 | Movement | Core | 0001 | ⚠️ Partial | `SolveResult` 分 Depenetration／Input 部分，但求解順序與犧牲契約未明寫 |
| TR-fpc-006 | 碰撞一律以本端渲染（內插後）位置解算；無仲裁、無回滾 | C8 :230-244；G12 :495-498；AC8a :1259-1275 | Physics/Netcode | Core | 0001 | ✅ Covered | `CapsuleGhost` 只封內插後 transform；forbidden pattern 已登記 |
| TR-fpc-007 | 求解器型別上取不到 owner 真值：唯一位置介面 readonly 無 setter | AC8b :1277-1283 | Testing/Movement | Core | 0001 | ✅ Covered | `readonly struct CapsuleGhost` |
| TR-fpc-008 | 雙向自我解除穿透，位移全額施加於自己，對他人零寫入 | C9 :246-254；AC9 :1285-1293 | Movement/Netcode | Core | 0001 | ✅ Covered | `PeerWrites` 恆 0 |
| TR-fpc-009 | NPC 硬擋、玩家對 NPC 零寫入、NPC 側恆 `Separated`、`npc_depenetration_scale=1` | C11 :291-304；F4 :686-710；AC13 :1319-1337 | Movement | Core | 0001/0003 | ✅ Covered | `IsNpc` ghost；0003 只看 player→npc 方向 |
| TR-fpc-010 | 有向對狀態機三態；`PassThrough` 唯一出口為完全分離；兩端獨立不保證同步 | States A :387-426；AC15/18 :1354-1383 | Movement | Core | 0001 | ✅ Covered | `PairMachine` 有向對 |
| TR-fpc-011 | 狀態實例以玩家 id 為鍵非 slot；一端 despawn 銷毀兩實例；無膠囊不建實例 | :397-399；Edge :841-842；AC19/20 :1385-1396 | Movement/Netcode | Core | 0001/0003 ⟂ 0006 | ⚠️ Partial（r2 ↓） | 0001／0003 以玩家 id 為鍵（未改），0006 D4 以 slot（`PeerKey`）為鍵；registry `player_identity_key` 已把 ADR-0001 的寫法列為 not（CX-1）。r3 加重：avatar 在 approval 當下即 spawn，ADR-0003 :95 的前提失效，Onboarding 期間的 avatar 是否進碰撞無人裁決（CX-3） |
| TR-fpc-012 | C10 計時主詞＝本機輸入；`IsInputCanceled` 述詞；歸零／遞增／維持三語意 | C10 :266-285；Edge :832-835；AC14/16 :1341-1368 | Movement | Core | 0001 | ✅ Covered | `Step(…, inputCanceled, dt)`＋`InputWasCanceled` |
| TR-fpc-013 | 多體：解除穿透向量相加一次施加、與順序無關；多對計時器並行推進 | Edge :858-863；AC21/22 :1400-1416 | Movement | Core | 0001 | ⚠️ Partial | 只在 Consequences 提 AC21 可測，決策本文未寫 |
| TR-fpc-014 | dt 夾制 `min(dt,0.10)` 不補跑；`Update()` 非 `FixedUpdate()` | C13 :329-335；F2 :670-676；AC24 :1431-1438 | Movement/Platform | Core | 0001 | ✅ Covered | D2 明文 |
| TR-fpc-015 | 背景偵測只消費 netcode 已裁決 `visibilitychange` 通道，不自建 | C13 :334-335 | Platform | Feature | 0001/0005 | ✅ Covered | D9＋`IPageLifecycle` |
| TR-fpc-016 | 隱藏／失鎖時輸入與速度歸零、回前景首幀不動、仍解除穿透可被推（`adoptInput`） | C14 :337-353；C7 :224-228；AC25 :1440-1449 | Input/Movement | Core | 0001/0005 | ✅ Covered | Core 只收布林 |
| TR-fpc-017 | 輸入真相＝本幀按鍵狀態，非事件差分（黏鍵免疫） | C14 :344；:1448-1449；AC37 :1518 | Input | Feature | 0001 | ⚠️ Partial | D7 用 Input System 但未定輪詢 `ReadValue` vs `performed/canceled` |
| TR-fpc-018 | 指標鎖定三態；`Unlocked≡Lost`；角色仍在場、可被推、計入他人計時 | C15 :355-368；States B :428-444；AC26 :1451-1460 | Input/Platform | Core | 0001 | ✅ Covered | 折成 `adoptInput` 布林，行為等價成立 |
| TR-fpc-019 | 不自動重鎖；重鎖手勢由 #11 提供；該點擊須吞掉；鎖定狀態輸出 HUD | C15 :363-365；:479；UI :1099-1103；AC27 :1462-1468 | Platform/Input | Feature | — | ❌ Gap | r3：ADR-0005 r1 明文把 pointer lock 交給 ADR-0001／#11，但 ADR-0001 未承接，ADR-0006 給 0001 r1 的義務也無此項；AC27 的假鎖定介面無擁有者 |
| TR-fpc-020 | Web pointer lock 平台能力：iframe 可用（僅 Chrome/macOS 實測）、Esc 解除、焦點遺失≠分頁隱藏 | OQ-F1 :1595；AC35-37 :1516-1518；:463-467 | Platform | Feature | 0001/0005 | ⚠️ Partial | 0005 D5 焦點歸 `Cursor.lockState`、隱藏歸 `IPageLifecycle`。r3：0005 說 Unity 層「由 ADR-0001 的 T1-Web 驗」，但 ADR-0001 沒有 T1-Web；OQ-F1 只測 Chrome/macOS |
| TR-fpc-021 | 俯仰不出本機；payload 無 pitch、無走／停；走停由內插位置微分導出 | C6 :210-216；C16 :375-377；AC28 :1472-1475 | Netcode | Core | 0001/0002 | ✅ Covered | per-axis 關 pitch；0002 以此為前提 |
| TR-fpc-022 | 對外廣播邊緣觸發、無每幀路徑、不另建管道 | C16 :370-374；AC28③ :1475-1480 | Netcode | Feature | 0001/0003 | ✅ Covered | stock NT 門檻；NV `AreEqual` 後才 dirty |
| TR-fpc-023 | G2 本機即時／遠端內插；`AuthorityMode=Owner` 顯式＋runtime guard | :34-38；:487-493；AC33 :1514 | Netcode | Foundation | 0001 | ✅ Covered | D4／D5 |
| TR-fpc-024 | 班次零傳送：無 `SetPosition/Teleport`；本機 NT 永不 `SetState()` | C12 :326-327；AC12 :1310-1317 | Movement/Netcode | Core | 0001 | ✅ Covered | 型別＋契約（Unity 層僅紀律，ADR 自承） |
| TR-fpc-025 | 實作模式：`CharacterController`、不繼承 `NetworkTransform` | :154-155；:1557 | Physics | Core | 0001 | ✅ Covered | D6；Alt 2 Rigidbody 否決 |
| TR-fpc-026 | 場景碰撞不穿牆不離地；CC 三旗標歸零；`Move()` 投影 ≤ \|delta\|；場景位移在預算外只能縮短 | AC34 :1515；C2 :177-179 | Physics | Core | 0001 | ✅ Covered | D3；GDD 原本對此零字，ADR 補洞 |
| TR-fpc-027 | 過場結束即可移動（netcode AC40）；`local_ready`＝已有可收輸入的角色；更衣室與店面同場景與否 | States C :454-467；Edge :878-880；OQ-F8 :1602 | Netcode/Platform | Feature | 0001/0006 | ⚠️ Partial | OQ-F8 已由 0006 D1 回答（單一場景、`EnableSceneManagement=false`）；`local_ready` 訊號仍未定 |
| TR-fpc-028 | 與 #2 事件介面：送 `local_ready`、消費 `player_joined/left`、各階段輸入採納由 #2 驅動 | :55；:475；States C :446-457 | Netcode | Feature | 0003/0006 | ⚠️ Partial | 0006 D13 `PlayerJoined/PlayerLeft(slot)`、D7 `FreezeInput` 參與者；`local_ready` 與過場／結算期間誰翻 `adoptInput` 仍無 ADR |
| TR-fpc-029 | 攝影機常數本系統擁有且資料驅動：near clip 0.10 覆寫 URP 預設 0.30、eye height、FOV；攝影機在膠囊中軸；transform 輸出 #11 | F0 :544-562；F1 :598-603；AC5j :1216；:479 | Camera | Foundation | — | ❌ Gap | 無任一 ADR 觸及攝影機；F0 自述預設值會靜默破 F1（安全速度 1.47→0.88 且症狀被歸因成網路） |
| TR-fpc-030 | 常數層：推導值非旋鈕；跨 GDD 常數（tick_rate、interp buffer、bg threshold、r_c）可被 AC5 同一測試讀取 | F2/F4 :670-689；Tuning :1018-1039；AC5 :1202-1218 | Data | Foundation | 0001 | ⚠️ Partial | 只定 Movement 的 `K`；跨組件常數真相源未定 |
| TR-fpc-031 | 視角：線性、無平滑、硬夾 <90° 不回彈；`movementX/Y` 唯一訊號；`look_deg_per_unit` 校正 | F6 :759-770；OQ-F2 :1596；AC29/30 :1482-1495 | Camera/Input | Core | 0001 | ⚠️ Partial | `LookState` 覆蓋 Core；WebGL 鎖定下滑鼠 delta 來源未定 |
| TR-fpc-032 | F7 `ShouldWarn` 純函式；短路順序為規格；`closing_speed` 夾制；取渲染值 | F7 :772-795；AC31 :1497-1507 | Movement | Core | 0001 | ✅ Covered | `Warn.ShouldWarn` 在 Core |
| TR-fpc-033 | `PassThrough` 時對 #7 膠囊查詢同步停供；回傳本端渲染位置；跨端最終一致有界 | Edge :836-837；AC17 :1370-1375 | Interface | Feature | 0003 | ✅ Covered | `ISolidCapsuleQuery`＋owner-write NV 遮罩 |
| TR-fpc-034 | `PassThrough` 對 #11 雙向可見，同一旗標不另建管道 | :425-426；:533；UI :1101 | Interface | Presentation | 0003 | ✅ Covered | D5 |
| TR-fpc-035 | 對 #4 輸出：座標、yaw、手持掛載點 transform、膠囊尺寸；流進為空 | :476；:937；:502-515 | Interface | Feature | — | ❌ Gap | 無 #4 ADR |
| TR-fpc-036 | 對 #5：僅本機俯仰與射線起點；Host 只驗水平；離開半徑 >0.6 m；不鎖移動 | :477；:517-527；C6 :214-216 | Interface/Netcode | Feature | 0002 | ✅ Covered | 述詞無 pitch；三層中斷關係式 |
| TR-fpc-037 | C7 其他系統不得鎖移動；#4 硬拒絕：手持物不改速度、不參與角色碰撞 | C7 :218-222；:502-515 | Interface | Core | 0002 | ⚠️ Partial | 只蓋 #5；#4 兩條無 ADR |
| TR-fpc-038 | Presentation 回饋：C5 偏移 MVP 預設關且可關；碰撞衝擊事件雙方皆收；位置給 #14 空間化 | C5 :203-208；:1057-1087；:941；OQ-F9 :1603 | Camera/Audio | Presentation | — | ❌ Gap | 無 ADR；碰撞接觸事件由誰發出未定 |
| TR-fpc-039 | 浮點／遲滯：`PassThrough` 退出餘裕、零中心距容差、F7 NaN 短路、IL2CPP 浮點行為 | Edge :845-848、:881-882、:899；F7 :790-792 | Movement | Core | — | ❌ Gap | GDD 明寫「→ ADR（平台浮點行為）」，尚無 ADR |
| TR-fpc-040 | netcode 側實測義務：`remote_step_tolerance`（U1）、`L_p95` 三進程實測、HOL burst、`interpolation_buffer_ms` 對應 NGO | U1 :797-805；:617-644；OQ-F4/F7/F10；:1548 | Netcode | Foundation | 0002 | ❌ Gap | 0002 只加 levy（150 ms 不對應 NGO 機制），未解 |
| TR-fpc-041 | 效能：每幀純向量運算零配置；12 有向對；唯一每幀系統守 60 fps | :25；:389-390 | Performance | Core | 0001 | ✅ Covered | Performance Implications |
| TR-fpc-042 | 測試落點 `Tests/EditMode/FirstPersonController/`；T0 runner；原型斷言搬遷 | :1112-1113；:1121；:1127 | Testing | Foundation | 0001 | ✅ Covered | Migration Plan |
| TR-fpc-043 | NPC 位置／在場狀態讀「該端顯示中」值；在場走 NetworkVariable 非 RPC | :478；C11 :292-294；Edge :841 | Netcode/Interface | Core | 0001/0003 | ✅ Covered | NPC ghost＋0003 D4 |
| TR-fpc-044 | 玩家可調值（`look_scale`、C5 開關）MVP 以資料驅動預設值交付、無 UI；持久化未定 | :1041-1050；OQ-F9 :1603；:536 | Data/Platform | Feature | — | ❌ Gap | 無設定持久化 ADR |

小計（r2）：Covered 26／Partial 11／Gap 7（共 44）〔前次 27／10／7〕。唯一變動是 TR-fpc-011 ✅→⚠️：ADR-0006 D4 改以 slot 為鍵，與 GDD :397-399／AC19 字面相反（§3A X1、§4）。Gap 不變：029、019、035、038、039、040、044

**供 Phase 5b**：GDD :634／:642／:655／:1009／:1036 的 F1 敏感度分析與 `L_p95 = 0.339` 重建皆以 `interpolation_buffer_ms = 150` 為項——ADR-0002 查證 NGO 2.13.2 實際內插延遲 ≥ 2 ticks（200 ms 起跳、隨 RTT 增長）。若屬實，`L_p95` 上修、F1 餘裕（現 0.33%）轉負，`player_move_speed_max = 1.47` 可能須下修。GDD 尚未回應此 levy。另：GDD :61 頭註「本系統不引用任何 ADR」已過時。觸控／手把在 GDD 零記載（technical-preferences 標 Partial）。

**需 ADR 才能關閉的 OQ**：OQ-F11 ✅ ADR-0001；OQ-F1 實測關閉但衍生重鎖策略（TR-019）無 ADR；OQ-F2（WebGL 鎖定下 Input System delta 來源）無 ADR；OQ-F7（`remote_step_tolerance`）無 ADR；OQ-F8（更衣室與店面同場景與否）無 ADR；:899「→ ADR（平台浮點行為）」無 ADR。

### GDD: machine-interaction.md（系統 #5 機台互動組；Core）

| ID | 需求 | GDD 節／行 | Domain | Layer | ADR | 狀態 | 理由 |
|---|---|---|---|---|---|---|---|
| TR-machine-001 | `ClaimState{bool IsClaimed; byte ClaimedBy; uint ClaimGeneration}`（`ClaimedBy`＝slot，`NoSlot=255`）為 Host 寫、全員讀的獨立 NetworkVariable struct | C20 L268；States L295 | Networking | Foundation | 0006（型別）/0002 | ✅ Covered | GDD :268 `byte ClaimedBy`；0006 D4 定案。r3：`NoSlot` 已移進 `NightShift.Identity.PlayerSlot`（255）；NoSlot 的 RPC 一律丟棄；0002 Key Interfaces 仍為 `ulong`（CX-1） |
| TR-machine-002 | `StationStatus{byte Phase; int WorkStartTick; byte Sku; ulong PendingProductNetId}` 為另一獨立 Host 寫 NV，unmanaged／blittable | C20 L269；OQ-M15 L851 | Networking | Core | — | ❌ Gap | → ADR-0004 預定（C20 型別） |
| TR-machine-003 | `StockState` 定長 `byte[N]`（N＝#6 Active 上限）掛 Host 動態 spawn 的 `StockRegistry`，全域一份，`StockChanged` 回呼 | C20 L270；C11 L200 | Networking | Core | — | ❌ Gap | → ADR-0004 預定 |
| TR-machine-004 | 三則 client→Host RPC：`InteractRpc(stationId, sku, action∈{Interact,Restock}, gen, selfX, selfZ, selfYaw)`／`TakeOutputRpc(stationId, pose)`／`InterruptRpc(stationId, gen)` | C20 L257-263 | Networking | Core | 0002 | ⚠️ Partial | ADR 只有 `RequestInteractRpc` 五參數、無 `sku`／`action`／Take；GDD L257 明寫取代名稱；registry L153 落後（OQ-M17）→ ADR-0004 預定 |
| TR-machine-005 | `InteractResponseRpc` 只送發起者（`RpcTarget.Single`），承載 `RejectReason` | C20 L264 | Networking | Core | 0002 | ✅ Covered | D5 執行期定址明寫 |
| TR-machine-006 | `RejectReason` 擴為八成員（＋`NothingToTake`），述詞只產前七個 | C11 L205；E1 L514；AC1 L762 | Networking | Core | 0002 | ❌ Gap | ADR enum 七成員（L138）；levy 已登記、ADR 未改 |
| TR-machine-007 | `sku` 一律為 #6 `network_index`（byte）；`FamilyParam` 不存在；`Sku` 於 `Claimed→Working` 寫一次不可改 | C14 L226；C20 L272 | Data | Core | — | ❌ Gap | → ADR-0004 預定 |
| TR-machine-008 | `ProductInstance` 唯一建構 `Create(networkIndex, isSpoiled)`；`is_spoiled`／`network_index` 在 `Spawn()` 前寫、無 setter | C13 L217-218；L42；E1 L513 | Networking | Core | — | ❌ Gap | 依 #6 GDD 規則；spawn 接縫 → ADR-0004 預定 |
| TR-machine-009 | 實例不掛 `NetworkTransform`；`Transform.SetParent()` 掛站台出貨位／owner 手部 socket，零位置同步 | C13 L220 | Networking | Core | — | ❌ Gap | → ADR-0004 預定 |
| TR-machine-010 | `AutoObjectParentSync = false` 為 prefab 契約；禁 `NetworkObject.TrySetParent()`；T1 斷言 | C13 L221 | Networking | Foundation | — | ❌ Gap | → ADR-0004 預定（OQ-M14 明列） |
| TR-machine-011 | 掛靠容忍 `PendingProductNetId`（NV）與 Spawn 訊息到達序，雙向重試 | C13 L222 | Networking | Core | 0002 | ⚠️ Partial | D8 只講 RPC vs NV；NV vs Spawn 未涵蓋 |
| TR-machine-012 | spawn 時 Host 持有；Take 通過後 `ChangeOwnership(requester)` 並回讀 `OwnerClientId`；6b 冷卻起點＝transfer 非 spawn | C13 L219；AC14 L779 | Networking | Core | — | ❌ Gap | netcode Core Rule #6 為 GDD 規則，無 ADR |
| TR-machine-013 | 收銀 Host 自 ownership 查 client 手上實例，不信 RPC 商品參數 | C12 L209；AC12 L777 | Networking | Feature | — | ❌ Gap | 無 ADR |
| TR-machine-014 | 每站一台 Host 權威狀態機（Idle／Claimed／Working／Ready／Spoiled／Failed／Taken／Restocking／Faulted 預留）；`OutOfStock` 為每 SKU 全域條件非 Phase | States L297-308；E0.1 L502 | Core | Core | — | ❌ Gap | → ADR-0004 預定（Core 分層） |
| TR-machine-015 | 兩種驗證：claim 走①–⑥只在到站；手勢結果為單一真相，以 Host 收到 RPC 的 tick 計時、不讀 client 時間戳、不綁公差 | C1 L114-119；AC1② | Core | Core | 0002 | ⚠️ Partial | claim 半邊由 ADR 定；手勢時刻規則無 ADR |
| TR-machine-016 | 持有者後續動作只跑②③④、⑤⑥ 0 次（轉頭≠`NotFacing`）；1.1–1.3 m 帶狀區動作接受 | C6 L163；E3 L531；AC6／49 | Core | Core | 0002 | ❌ Gap | ADR `Validate` 每請求跑全部六段；GDD 自注「→ ADR-0002 須加註」 |
| TR-machine-017 | 倒數在 Host 自走：`WorkStartTick`＝Host 收 RPC tick，與持有者在場無關；`Working`／`Ready` 可 `IsClaimed=false` | C3 L137-141；AC3 L764 | Core | Core | — | ❌ Gap | → ADR-0004 預定（雙時鐘規則） |
| TR-machine-018 | 每次接受的 `InteractRpc`／`TakeOutputRpc` 重設 5 s 保險絲（續租）；保險絲對 `Ready` 亦生效 | C7 L167-169；AC7 L768 | Networking | Core | 0002 | ❌ Gap | D7 保險絲「netcode 既有」從 lock 起算無續期；OQ-M4 levy |
| TR-machine-019 | 強制釋放（保險絲／斷線／走開／E0.3）只放 claim：`IsClaimed→false`、gen+1、Phase 不變；`Restocking→Idle` 不加庫存；`Failed` 唯一來源 `shift_end_ts` | C10 L182-189；E1 L515-517；AC10a-e | Core | Core | 0006（＋ADR-0004） | ⚠️ Partial（r2 ↑） | 0006 D7 第 3 步：斷線只釋放 claim、`ClaimGeneration+1`、不判 Failed；D13 `ShiftEndTs`。其餘觸發源（保險絲／走開／E0.3）與 `Restocking→Idle` 歸 ADR-0004 |
| TR-machine-020 | `ClaimGeneration` 每次 true→false +1、`Idle→Claimed` +0；仲裁＝述詞②在 Host 單執行緒處理順序 | States L312；AC26 L791 | Networking | Core | 0002/0006 | ⚠️ Partial | 0006 D7 第 3 步重申斷線路徑 +1；完整遞增規則與仲裁仍歸 ADR-0004 |
| TR-machine-021 | 第一下＝claim＋第一個家族動作，一則 RPC、同一次 Host 處理；Shelf／Oden 一趟跑完 `Claimed→…→Idle` | E0.4 L508；States L310；AC25 | Core | Core | — | ❌ Gap | → ADR-0004 預定 |
| TR-machine-022 | 第四中斷觸發源：對 B 送 claim 先釋放 A，先放後驗、不回滾 | E0.3 L506；C8 L174；AC24 | Core | Core | 0002 | ❌ Gap | D7 只有三層；levy 已登記未落 ADR |
| TR-machine-023 | 同 tick 先處理已到 RPC 再逾時掃描；掃描掛 `OnNetworkTick`／`INetworkUpdateSystem`（10 Hz）非 `Update()`；`t ≤ timeout` 含端點 | E2 L524；AC39 L805 | Networking | Foundation | — | ❌ Gap | → ADR-0004 預定（OQ-M14 明列） |
| TR-machine-024 | `TakeOutputRpc` 不看 claim：跑①④⑤⑥、跳②③ | C9 L180；E1 L514；AC9 | Core | Core | 0002 | ⚠️ Partial | 述詞來自 ADR，子集變體未定 |
| TR-machine-025 | Shelf 為計數：`Claimed→Working` 預扣；補貨完成把本架所有未滿 SKU 設為 `stock_max`（設值冪等）；Host 單執行緒保證不為負 | C11 L199-203；E4 L540-544 | Core | Feature | — | ❌ Gap | → ADR-0004 預定（`IStockWriter`） |
| TR-machine-026 | NV 只在轉移時寫（邊緣觸發）；`progress` 不送 float，各端由 `WorkStartTick` 自算 | C18 L249；AC20 L785 | Networking | Core | 0003 | ⚠️ Partial | ADR-0003 L75 證 `AreEqual→SetDirty`，但針對遮罩非 `StationStatus` |
| TR-machine-027 | 五台與 `StockRegistry` 開班由 Host 動態 `Spawn()`，不得 scene-placed（前提：關閉 `NetworkSceneManager`＋中途加入） | C18 L249；AC21；E1 L519 | Networking | Foundation | — | ❌ Gap | 無 ADR（場景管理關閉是 netcode 層決策） |
| TR-machine-028 | client 顯示只讀 NV 回呼；`ClaimState`／`StationStatus` 任一回呼觸發皆重讀兩者整套重算 | States L316；UI L748 | Networking | Presentation | 0002 | ⚠️ Partial | D8 只講 RPC vs NV；兩 NV 互不推斷為延伸 |
| TR-machine-029 | 樂觀動畫 ≤ 100 ms 零流量；承諾瞬間恰 1 則 RPC；不等 ack 播下一步；`action_min_interval_ms ≡ optimistic_anim_max_ms` | C5 L157-159；F8 L470；AC5 | Core | Presentation | 0002 | ⚠️ Partial | D1 提 ≤100 ms 樂觀動畫；fire-and-forget／防連發未定 |
| TR-machine-030 | 互動延遲 300 ms（約束⑧）須在 4 人併發（單一 WSS、HOL 阻塞）下驗證 | Interactions L353 | Networking | Foundation | 0002 | ⚠️ Partial | Verification ③只驗 WSS 順序，未驗負載 |
| TR-machine-031 | 每幀恰 1 次 `Physics.Raycast`：專用 interactable layer、長 `interact_ray_length_m`、`QueryTriggerInteraction.Collide`，回 `(stationId, sku)?` 同餵 HUD 與送出 | C15 L228-234；AC17 L782 | Physics | Core | 0002 | ⚠️ Partial | D1 只說本機 raycast 選 `stationId`；槽粒度／layer／trigger 旗標未定 |
| TR-machine-032 | 述詞⑤⑥錨點＝被瞄準槽的錨點；Host 由 `sku` 查槽錨點 | C15 L231；E3 L532；AC46 | Core | Core | 0002 | ❌ Gap | `StationDef{AnchorX, AnchorZ}` 為站台中心（L136）；levy 已登記 |
| TR-machine-033 | Host 只驗 `sku ∈ GetByMachineFamily(family)`，不驗瞄準；非法／Deprecated sku → no-op＋撲空，非安全事件 | E0.1 L502；E3 L535；AC16 | Core | Core | — | ❌ Gap | → ADR-0004 預定；依 #6 |
| TR-machine-034 | 非持有者提示＝本機以自報姿態跑同一⑤⑥純函式、無遲滯；持有者提示到 `station_leave_m` 才滅 | C15 L236；E3 L531；AC46 | UI | Presentation | 0002 | ⚠️ Partial | 述詞純函式使本機可算；提示規則未定 |
| TR-machine-035 | `Interaction` action map 恰為 `{Interact}`、`Movement` 不動；按住式只取 `started`／`canceled` 邊界，時長由 Core `dt` 累加 | C17 L245；AC19 L784 | Input | Foundation | 0001 | ⚠️ Partial | D7 定 Movement map，稱互動鍵「須明文豁免 AC1③」；GDD 改獨立 map 不需豁免——措辭漂移 |
| TR-machine-036 | `visibilitychange` 由轉接層直接呼叫 Core 手勢中斷，不接 Input System `canceled` | C16 L241；AC18 L783 | Platform | Foundation | 0005 | ✅ Covered | GDD Requirements L233：`IPageLifecycle.HiddenChanged` |
| TR-machine-037 | 同源可見性匯流排同時餵 ADR-0001 `adoptInput` 與 C16 邊緣事件 | OQ-M14 L850 | Platform | Foundation | 0005 | ✅ Covered | 架構圖 L112-116 FP／MI 轉接層共用 `IPageLifecycle`；OQ-M14 仍列為 ADR-0004 範圍——應移出 |
| TR-machine-038 | Host 玩家走同一 RPC 路徑（`LocalSendRpcTarget` 同步遞迴），不得捷徑改狀態 | E2 L524 | Networking | Foundation | 0002 | ✅ Covered | D6 明寫 |
| TR-machine-039 | 音效雙觸發源：站台狀態邊緣＝NV 回呼；個人結果＝`InteractResponseRpc`，不得從 NV 推斷 | Interactions L343；V/A L701 | Audio | Presentation | 0002 | ⚠️ Partial | D5 為基礎；分流規則未定 |
| TR-machine-040 | `IShelfAvailabilityQuery.GetAvailableStock(byte networkIndex)` Host-only 純函式，回含預扣即時值 | C11 L204；Interactions L340 | Core | Feature | — | ❌ Gap | → ADR-0004 預定（介面簽章） |
| TR-machine-041 | `ICheckoutCustomerQuery` Host-only 讀 #7 NV 現值，以 Host 處理 RPC 那一刻為準；null → 不中 | C12 L212；E5 L550；AC40 | Core | Feature | — | ❌ Gap | → ADR-0004 預定（C20 L272 具名，但不在 OQ-M14 括號清單內） |
| TR-machine-042 | 「訂單完成」邊緣事件於最後一槽補滿時發 #7／#15；`Matches()`／`AllocateSlot()`／`MatchResult` 為 #6 純函式，`Unevaluated` 即斷言失敗 | C12 L210；E5 L548；AC28 | Core | Feature | — | ❌ Gap | 依 #6／#7／#15 GDD，無 ADR |
| TR-machine-043 | HUD 供料：`StationStatus`／`ClaimState`／`StockState`／`(stationId, sku)?`／`RejectReason`；進度邊界用 `ServerTime.Tick − WorkStartTick`、插值用 `NetworkTime.TimeAsFloat` | UI L734-739 | UI | Presentation | — | ❌ Gap | 無 ADR |
| TR-machine-044 | 對 #4：6b 冷卻起點＝transfer；不中實例留手上；手滿時 client 已知無效即不送 RPC | Interactions L348／356 | Core | Feature | — | ❌ Gap | provisional，#4 未設計 |
| TR-machine-045 | 時基 `ServerTime.Tick`（`WorkStartTick`）與 `shift_end_ts` 來自 #2；班次結束後拒收所有站台 RPC | E1 L517；Deps L576 | Networking | Foundation | 0006（＋G9／ADR-0004） | ⚠️ Partial（r2 ↑） | 0006 D13 `ShiftEndTs` 真相；`ServerTime.Tick` 時基與「班次結束拒收站台 RPC」未定 |
| TR-machine-046 | `station_reach_m=0.8`、`accept_radius_m=R+r_c=1.1`、`station_leave_m=max(R+r_c+H, 2·r_c)=1.3`、`H=0.20`：值歸 GDD、關係式歸 ADR | F1 L366；F2 L380 | Core | Core | 0002 | ✅ Covered | D3⑤／D7 關係式；值明示由 #5 擁有 |
| TR-machine-047 | 撲空演出對齊贏家內插位置進 `accept_radius_m`；`whiff_arrival_wait_max_ms = 2-tick 地板 + one_way_p95 = 350→400` | States L330；F4 L422-434 | UI | Presentation | 0002 | ⚠️ Partial | 2-tick 地板（Context 3）／單程 p95 來自 ADR；演出規則未定 |
| TR-machine-048 | client 已知無效按鍵不送 RPC（Working 再按、空手刷、手滿）；只有 Host 端才知的不一致經回應收斂為撲空 | E1 L520；C12 L211；C15 L237 | Core | Core | — | ❌ Gap | 無 ADR |
| TR-machine-049 | 斷線實走保險絲（Host 判定 8–87 s）；「強制釋放 ≤ 2 s」為判定後預算；Host 自身斷線機台層零處理 | C10 L193；E1 L518 | Networking | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D6 8 s 判定、D7 ≤ 2 s 序列、Host 自身消失不跑序列。r3：E6 已修——第 5a 步以非空 reason `DisconnectClient`，鬼連線窗口 ≤ 1 幀 |
| TR-machine-050 | 遲加入者由 NV 初始同步取得 `ClaimState`／`StationStatus`（Spawn 前寫入值隨初始同步），同式自算進度 | E1 L519；OQ-M12 L848 | Networking | Foundation | 0003 | ⚠️ Partial | ADR-0003 L17 證 `WriteFieldSynchronization` 為 NGO 事實，未對站台陳述 |
| TR-machine-051 | 站台狀態機為純 C#、T0 不碰 NGO；fake 接縫 `ISpawner`／`IOwnershipTransferer`／`IStockWriter`／`IStationStatusWriter`／`ICheckoutCustomerQuery`；約 40 條 T0 | AC 前言 L756；C20 L272 | Testing | Core | — | ❌ Gap | → ADR-0004 預定（OQ-M14 明列） |
| TR-machine-052 | 一站一個出貨位：Ready／Spoiled 時 Start no-op；`Ready→Spoiled` despawn Fresh、spawn Spoiled 同位；Take 以站台為目標不帶實例 id | E1 L512-513；AC38 | Core | Core | — | ❌ Gap | → ADR-0004 預定（spawn 接縫） |
| TR-machine-053 | `Faulted` 預留狀態與介面形狀、MVP 零觸發源；靜態列舉斷言無轉移目標 | C19 L253；AC22 L787 | Core | Core | — | ❌ Gap | → ADR-0004 預定（狀態 enum） |
| TR-machine-054 | 九旋鈕進 registry；推導量為純函式不得獨立常數；`cook_cap_sec=30` 固定；AC32 讀 registry 現值 | F 淨旋鈕 L480-494；Tuning L620；AC32／35 | Config | Foundation | — | ❌ Gap | 無資料驅動載入（registry→ScriptableObject）ADR |
| TR-machine-055 | 版面約束：站台錨點定義、可互動體不重疊、異家族淨距 ≥ 1.2 m、槽高度帶 [0.75, 1.60] m | E3 L532-534；F6 L461 | Core | Feature | — | ❌ Gap | levy #11／關卡佈局，無 ADR |
| TR-machine-056 | 一律程式 tween、禁骨架動畫（Animator 為 WebGL CPU 瓶頸）；世界內進度為實體視覺本機自算 | V/A L690-691 | Presentation | Presentation | — | ❌ Gap | 美術聖經 §8.7 規則，無 ADR |
| TR-machine-057 | NV 承載 struct 保持 blittable（bytewise memcmp、無 boxing）；本系統每幀預算 < 0.1 ms | OQ-M15 L851 | Networking | Core | 0003 | ⚠️ Partial | ADR-0003 證 NV 只在變更送；blittable 要求未明寫 |

小計（r2）：Covered 7／Partial 18／Gap 32（共 57）〔前次 6／16／35〕。049 →✅（心跳＋2 s 序列）；019、045 →⚠️（斷線只放 claim、`ShiftEndTs` 真相已定，其餘歸 ADR-0004／G9）；001 的型別改由 ADR-0006 擁有

**OQ-M14 列出的 ADR-0004 範圍**：C20 C# 簽章與型別；`AutoObjectParentSync = false` 契約（C13）；Core 測試接縫介面（`ISpawner`／`IOwnershipTransferer`／`IStockWriter`／`IStationStatusWriter`）；E2 逾時掃描掛 `OnNetworkTick` 的 Host 迴圈形狀；雙時鐘規則；`visibilitychange` 共享匯流排（⚠ 已由 ADR-0005 承接，應刪以免雙擁有者）；registry 簽章同步（OQ-M17）。⚠ C20 L272 另把 `ICheckoutCustomerQuery` 簽章歸 ADR-0004，OQ-M14 括號清單漏列，應補。

**與 ADR-0002 本文的不一致**（數值全部吻合；不一致全在語意）：①錨點：單一站台錨點 vs 每 SKU 槽錨點 ②`RejectReason` 七成員 vs 八成員 ③中斷三層 vs 第四觸發源 ④`Validate()` 單一簽章每請求跑①–⑥ vs 三種子集（持有者②③④、Take ①④⑤⑥、首次①–⑥）——AC6「⑥ 0 次被評估」對 ADR 現狀必紅 ⑤保險絲從 lock 起算 vs 每次有效動作重設、對 `Ready` 生效、到期只放 claim ⑥RPC 集：`RequestInteractRpc(int, uint, float×3)` vs `InteractRpc` 多 `sku`／`action`＋`TakeOutputRpc`；registry L153 仍為 ADR 版 ⑦raycast 回 `stationId` vs `(stationId, sku)` ⑧ADR-0001 D7「互動鍵加入時 AC1③ 須明文豁免」 vs GDD C17 獨立 map 不需豁免——效果不衝突，措辭過時。

**需 ADR 才能關閉的 OQ**：OQ-M14（ADR-0004 本體）、M17（registry 同步）、M15（blittable 型別）、M4（續租→ADR-0002 修訂或 netcode ADR 定起算點）、M10（三份 ADR Proposed→story 自動 block）、M13 候選（`AudioContext` 首次手勢解鎖是瀏覽器能力，ADR-0005 五介面無對應——依 R1「每項瀏覽器能力一個介面」應納 ADR-0005 修訂）。

### GDD: product-database.md（系統 #6 商品資料庫；Foundation）

| ID | 需求 | GDD 節／行 | Domain | Layer | ADR | 狀態 | 理由 |
|---|---|---|---|---|---|---|---|
| TR-product-001 | SKU 身份、`machine_family` 歸屬、`ProductInstance` 形狀、`Matches()` 判定只在本系統定義；#5／#7／#15 不自帶商品知識 | Overview L28-35；規則 4 L390-397 | Data | Foundation | — | ❌ Gap | 無商品資料 ADR |
| TR-product-002 | 兩層 ID：`sku_id` string 設計期鍵、不進封包；`network_index` byte 1-255 循序、永不重用、0=Invalid；線路只傳 byte，SKU 表不跨端同步 | 規則 1 L234-235；規則 2 L317-342 | Data／Networking | Foundation | — | ❌ Gap | 同上 |
| TR-product-003 | 零值即無效：所有 enum 顯式整數值、`Invalid=0` 哨兵、只可附加不可重排不可改值；`MatchResult.Unevaluated=0` | 規則 1b L253-289；Edge L935-942 | Serialization | Foundation | — | ❌ Gap | 同上 |
| TR-product-004 | 序列化欄位名／型別一經上線永不變更；改名必加 `[FormerlySerializedAs]`；snake_case→`_camelCase` 對應表於第一筆資產前定案；byte→ushort 需實測遷移＋`[P-17]` token 遞增 | 規則 1c L291-310；L959-965 | Serialization | Foundation | — | ❌ Gap | 同上 |
| TR-product-005 | `ProductDefinition : ScriptableObject` 僅作者期容器，catalog 建置時一次性轉 immutable POCO／struct；`ProductEntry`／`ProductInstance`／`CustomerDemand` 不繼承 `UnityEngine.Object` | Interactions L531-538；AC14② | Data | Foundation | — | ❌ Gap | 同上 |
| TR-product-006 | 容器 `ProductCatalogAsset` 持 `ProductDefinition[]`，由 boot scene `[SerializeField]` 引用走序列化依賴鏈進 build；執行期零發現、零 async、零 `Resources`、零 `AssetDatabase` | OQ-P11 L1589 | Asset Loading | Foundation | — | ❌ Gap | 同上 |
| TR-product-007 | `mesh_ref`／`icon_ref` 直接強引用；`Deprecated` 時必清 null；不採 Addressables／`Resources`；下架殘留納 44MB 硬標 | 規則 2 L323-338；Overview L48-57；Deps L996-1001 | Asset Loading | Foundation | — | ❌ Gap | 同上 |
| TR-product-008 | `ProductInstance { network_index: byte, is_spoiled: bool }`；唯一公開建構點 `Create(networkIndex, isSpoiled)`，無 public 無參建構／設值器；`Create(0,_)` 拋 | States B L417；L468-470、L512-515；AC23 | Data | Core | — | ❌ Gap | 同上 |
| TR-product-009 | `CustomerDemand` 攤平 tagged-union struct（無 GC alloc），無 public 建構子；由 catalog 工廠 `FamilyDemand`／`NamedDemand` 建構時驗證拋；`default` 落哨兵由 `Matches()` 攔 | L457-459、L480-511；AC6c | Data | Core | — | ❌ Gap | 同上 |
| TR-product-010 | `CustomerOrder { slots: CustomerDemand[] }`；「兩串」= 兩槽，無 `qty`；修飾語不進資料結構 | L652-669 | Data | Core | — | ❌ Gap | 同上 |
| TR-product-011 | `IProductCatalog` 四個唯讀查詢：`Get()` 含 deprecated、未指派值無條件 throw（禁 `[Conditional]` assert）；`GetByMachineFamily`／`GetOrderable`／`GetNameable` 只回 Active、建置時算一次快取、回同一 `IReadOnlyList` 引用；空池回空陣列 | L450-455、L523-530；Edge L921-931；AC9／10／16 | Core API | Core | — | ❌ Gap | 同上 |
| TR-product-012 | `Matches()`／`AllocateSlot()` 住 `static ProductMatching`、不在介面上（fake 只供資料不供邏輯）；全函式無狀態；可完全不建 catalog 呼叫 | L461-479；L827-831；AC14③ | Core Logic | Core | ADR-0001 | ⚠️ Partial | 0001 立「純 C# 核心」先例與 asmdef 分層哲學，但只約束移動，對 #6 無約束力 |
| TR-product-013 | `Matches` 輸入域驗證先於判定、回四值 enum 無部分分數；`AllocateSlot` 前置 `filled.Length == slots.Length` 否則 `ArgumentException`、資格述詞＝`Match` | Formulas L677-697、L774-799 | Core Logic | Core | — | ❌ Gap | 同上 |
| TR-product-014 | 資料庫無執行期狀態、無任何寫入者、不接網路同步層與遊戲時鐘；載入期固定靜態表隨 build 出貨 | States L400-402；L448；L340-342 | Architecture | Foundation | — | ❌ Gap | 同上 |
| TR-product-015 | asmdef 邊界：`NightShift.ProductDatabase` 可引 `UnityEngine.CoreModule`，不得引 `Unity.Netcode.Runtime`／`UnityEditor`／自家 `.Editor`；以 `CompilationPipeline.GetAssemblies(Player)` 遞迴閉包驗證 | L540-548；AC14① | Assembly | Foundation | ADR-0001／0005 | ⚠️ Partial | 兩 ADR 立「asmdef＋建置期 grep 雙鎖」模式但未涵蓋本組件；本組件允許 CoreModule，與 0001 的 `noEngineReferences=true` 分層不同 |
| TR-product-016 | 四個組件：runtime／`Tests.EditMode`／`Tests.EditMode.Content`／`.Editor`（`includePlatforms:["Editor"]`、`defineConstraints:[]`）；runtime 不得引 `.Editor` | L1417-1426 | Assembly／Test | Foundation | — | ❌ Gap | 同上 |
| TR-product-017 | 無 per-SKU 硬編：組件內不得有以 `sku_id`／`network_index` 分支的 switch／if、不得自動產生 per-SKU enum（靜態掃描） | AC11b L1353 | Data-driven | Core | — | ❌ Gap | 同上 |
| TR-product-018 | 資料不變量除 EditMode 外必同時實作於 `IPreprocessBuildWithReport.OnPreprocessBuild`，失敗 `throw BuildFailedException`；共用純函式 `ProductCatalogValidator.Validate(entries, snapshot)` | Edge L851-861；AC17a | Build Pipeline | Foundation | — | ❌ Gap | GDD 自指 ADR-XXX 尚未撰寫 |
| TR-product-019 | 繞過路徑對策：驗證器 asmdef 釘 Editor＋空 defineConstraints；`TypeCache` 確認鉤子型別唯一（AC17b）；`-batchmode` 須 `EditorApplication.Exit(1)`；Addressables／SBP build 不經此鉤子需另建閘 | L863-889；AC17b | Build Pipeline | Foundation | ADR-0001／0005 | ⚠️ Partial | 兩 ADR 同樣押在尚不存在的 CI grep 上（0005 Migration 3）——同一塊基礎設施的三個客戶，無人擁有 |
| TR-product-020 | 快照檔 `design/registry/sku-shipped-snapshot.txt`：append-only 事件日誌＋`frozen_enum:` 可解析鍵；`[FrozenEnum]` 屬性掃描、雙向比對含 underlying type；快照缺席一律失敗；以 `System.IO` 相對 `Application.dataPath` 讀 | AC1a／1b／15a／15b；L1431-1437；L1450-1476 | Data Governance | Foundation | — | ❌ Gap | 同上 |
| TR-product-021 | 資產不變量建置檢查：icon 64×64 Sprite、mipmap、被 `Atlas_Ui` 收錄；Active 必有 mesh；∀家族有 `Ui_Icon_[family]`；`Ui_IconTier_*` 存在且層級正確；Deprecated 清 null；審查紀錄 `gateN_verdict:` 可解析＋新鮮度 | Edge L895-915；AC4／4b／4c／12b／18／19 | Asset Validation | Foundation | — | ❌ Gap | 同上 |
| TR-product-022 | 建置期資料治理閘門為跨切面基礎設施，拆獨立 ADR-XXX＋工具任務；兩軸：證據閘今日生效、建置期強制待 ADR（僅資料不變量 14 條，不含 AC6c） | L891-893；L1367-1413；OQ-P11 | Governance | Foundation | — | ❌ Gap | 同上 |
| TR-product-023 | `network_index`／`is_spoiled` 以 server-write `NetworkVariable` 分開掛 #5 的 `NetworkBehaviour`；必於 `Spawn()` 之前寫入、之後不可變；遲加入者靠 spawn 同步取現值 | L576-634；AC22 | Networking | Core | ADR-0003 | ⚠️ Partial | 0003 已查證 NV 寫權限建構子陷阱、遲加入者同步、`ChangeOwnership` 不清值；但 Spawn-前寫入與 `ProductInstance` 承載無 ADR |
| TR-product-024 | 不把 `ProductInstance` 整包過線（資料組件不宣告 `INetworkSerializable`）；#4／#5 不得以 `NetworkVariable`／`NetworkList` 承載其集合，若要須 W1 式實測並重裁 AC14；`UserNetworkVariableSerialization<T>` 存在性待查 | L635-651；OQ-P12 | Networking／Serialization | Core | — | ❌ Gap | 0002 用 `NetworkVariable<struct>` 承載 `ClaimState` 是先例非裁決 |
| TR-product-025 | `RequestHandoff.itemId` 型別為 `NetworkObjectId (ulong)`，與 SKU 身份分離；Host 必驗 `itemId` 仍在 `SpawnedObjects`，查無回明確失敗不得靜默 no-op | L558-575；OQ-P7 | Networking | Core | — | ❌ Gap | 歸 ADR-0004 或 #4 ADR |
| TR-product-026 | 兩端 SKU 表一致性依 `[P-17]` 版本 token，其粒度須涵蓋純內容變更（或自建 SKU 表雜湊）；舊 client 收新 `network_index` → `Get()` 拋，目前零 AC 覆蓋 | 規則 2 L344-360；OQ-P8 | Versioning | Core | 0006 | ⚠️ Partial（r2 ↑） | 0006 D5 `BuildId` 內容雜湊、不符即拒；r3：雜湊輸入（含 `ProductCatalogAsset`）明文交 G4；dev build 以 0 放行；舊 client 收新 `network_index` 仍無 AC |
| TR-product-027 | 給 #5：`GetByMachineFamily()` 決定菜單；#5 建 `ProductInstance` 並蓋 `is_spoiled`；#5 須提供 `Shelf` 可得性查詢，查詢存在前 #7 不得從 `Shelf` 抽 `Named` | L552-553；L976-986；OQ-P15 | Cross-system | Feature | — | ❌ Gap | 介面歸 ADR-0004；已 levy 至 systems-index |
| TR-product-028 | 給 #7／#8：`GetOrderable()`／`GetNameable()` 池、兩個需求工廠；levy `sku_concurrent_distinct_max=4`（計槽）、指名比例由 #7 定並反向引用 | L485-489；L553；L1133-1140 | Cross-system | Feature | — | ❌ Gap | 無 ADR |
| TR-product-029 | 給 #15／#4：`Matches()` 四值 `MatchResult`、`AllocateSlot()` 單訂單內有效；槽位佔用狀態歸 #15／#4；跨訂單分配歸 #4；#15 必含整合測並反向引用 | L554；L820-836；L972-975 | Cross-system | Feature | — | ❌ Gap | 無 ADR |
| TR-product-030 | 給 #11／#13：`machine_family`／`network_index` 為 icon 鍵；`display_label` 給 #13；層級標記於 Sprite Atlas 打包期合成、不得執行期疊加 | L555-556；L1243-1248；L1308-1311 | Presentation | Presentation | — | ❌ Gap | 無 ADR |
| TR-product-031 | 內容配額資料驅動常數（`sku_holler_max_chars=4`、`sku_display_label_max_chars=6`、`sku_nameable_max=6`、nameable 下限 2、每家族 Active≥1、`sku_count_target`）；以 `StringInfo.LengthInTextElements` 計數、`Normalize(FormKC)` 查重 | Tuning L1069-1077；AC2a／2b／3／20 | Config | Feature | — | ❌ Gap | 結構性要求（常數外置、計數法釘死） |
| TR-product-032 | 資產命名綁定 `sku_id`／enum 名：`Mesh_[sku_id]`、`Ui_Icon_[sku_id]`、`Ui_Icon_[family]`、`Ui_IconTier_Family／Named`；手持模型禁貼圖、icon 為貼圖 | Visual/Audio L1144-1152、L1202-1208 | Asset Pipeline | Presentation | — | ❌ Gap | 無 ADR |
| TR-product-033 | 本地化：明示假設繁中單一語系；新增語系時 `display_label` 須拆兩欄（喊名／顯示 key），不得動 `sku_id` | L1074；OQ-P17 L1595 | Localization | Presentation | — | ❌ Gap | 無 ADR |
| TR-product-034 | 內容審查輔助工具（advisory）：注音距離腳本（門檻 3）、icon 機器前篩（門檻 6）；重跑觸發器＝審查紀錄的內容雜湊 | L178-191；L1484-1487 | Tooling | Presentation | — | ❌ Gap | 無 ADR |

小計（r2）：Covered 0／Partial 5／Gap 29（共 34）〔前次 0／4／30〕。026 →⚠️：`BuildId` 內容雜湊即版本 token，雜湊輸入須明列含 `ProductCatalogAsset`（併入 G4）

**Gap 分群（建議新 ADR）**：
- ADR「SKU 資料格式、ID 與序列化凍結」：001–005、008–010、014、017（並裁決是否仿 ADR-0001 拆 `.Core`/`.Unity`）
- ADR「商品目錄 API、組件邊界與測試接縫」：011–013、015、016（可併上一份）
- ADR「資產繫結與載入：強引用＋容器 SO、無 Addressables」：006、007、032（關閉 OQ-P6）
- ADR-XXX「建置期資料治理閘門」（technical-director＋devops）：018–022；⚠ ADR-0001／0005 的 grep 守門是同一基礎設施的客戶，應由此 ADR 一併收
- ADR「`ProductInstance` 網路承載契約」（併入 ADR-0004 或獨立）：023–025；026 歸 netcode 版本 ADR
- 不需 ADR、需登記 `architecture.yaml` interfaces／systems-index：027–031
- 延後（Presentation）：033、034

**需 ADR 才能關閉的 OQ**：OQ-P6（資產載入）、P7（`itemId` 型別＋`SpawnedObjects` 驗證→ADR-0004／#4）、P8（`[P-17]` token 粒度→netcode 版本 ADR；netcode GDD 零引用，孤兒風險）、P9（`is_spoiled` 信任邊界；約束⑧ 讀法→承載 ADR，擋 #5）、P11（建置期閘門＝一份 ADR）、P12（`INetworkSerializable`／`NetworkList`→承載 ADR，需 W1 式實測，擋 #4）、P15（`Shelf` 可得性查詢形狀→ADR-0004）、P17（`display_label` 拆欄，資料格式 ADR 預留）

### 概念文件＋系統索引（game-concept-night-shift.md；systems-index.md 20 系統）

（概＝game-concept 行號；索＝systems-index 行號）

| ID | 需求 | 文件節／行 | Domain | Layer | ADR | 狀態 | 理由 |
|---|---|---|---|---|---|---|---|
| TR-concept-001 | Web/WebGL、開連結＋房間碼即玩、進房 ≤60 s | 概 L21、L163-166 | Platform | Foundation | 0005/0006 | ⚠️ Partial | 0006 D14 `T_lobby`／`T_spawn` 硬閘門；`T_load` 只有 stall 偵測。r3：開連結的 X3 已解（0005 r1 referrer） |
| TR-concept-002 | 2–4 人（MVP 2）、一班 8–10 分、連續值班 30–90 分 | 概 L23-24 | Networking | Foundation | 0006/0003 | ✅ Covered（r2 ↑） | 0006 Constraints：`max_players` 容器按 4、MVP 2；D2 session 跨班次存活（連續值班） |
| TR-concept-003 | itch.io iframe 發行（pointer lock、clipboard、permissions policy） | 概 L25、L260；索 L22、L145① | Platform | Platform | 0005 | ⚠️ Partial | `IsEmbedded`／`IClipboard`／referrer 帶碼（0005 r1）。r3：pointer lock 被 0005 r1 排除在平台層外，交棒的「ADR-0001 T1-Web」不存在 |
| TR-concept-004 | 隊友即障礙：窄空間互撞、借過、PassThrough 降級 | 概 L44、L158、L234② | Core/Physics | Core | 0001, 0003 | ✅ Covered | 純 C# 求解器＋`PairMachine`＋owner-write 遮罩 |
| TR-concept-005 | 客人＝個性狀態機；Host 權威 NPC、里程碑事件複製 | 概 L74 | AI/Networking | Core | 0003 | ⚠️ Partial | 只定在場狀態走 NetworkVariable；狀態機複製無 ADR |
| TR-concept-006 | 機台互動 request→validate→broadcast | 概 L75 | Networking | Core | 0002 | ⚠️ Partial | 驗證述詞已定；Core 分層／RPC 契約＝ADR-0004 未寫 |
| TR-concept-007 | 兩段式節奏：波次導演＋遊戲時鐘（含突發事件） | 概 L76、L118-119 | Gameplay | Feature | 0006 | ⚠️ Partial（r2 ↑） | 0006 D13 定時鐘真相與複製（`ShiftEndTs` NV＋心跳 offset）；波次導演無 ADR，#9 遊戲時鐘無 GDD |
| TR-concept-008 | 星級評分＋結算：純邏輯、EditMode 可測、槽位分配整合測項 | 概 L77、L284；索 L62、L135 | Gameplay | Core | — | ❌ Gap | 僅 tech-prefs 測試慣例 |
| TR-concept-009 | 房間碼進房、大廳、斷線重連；Session 走 MPS Sessions | 概 L78；索 L53、L58 | Networking | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D2 房間碼／大廳兩層會談；D4 MVP 重連＝新加入；D8 Lobby Host 離開 |
| TR-concept-010 | 斷線基本保障（MVP）：偵測、物品掉落、站台解鎖、留守者降載 | 概 L289-293 | Networking | Core | 0006（＋G2／ADR-0004） | ⚠️ Partial | 偵測（0006 D6）與降載（D7 第 7 步）已定。r3：掉落的結果契約已寫死（V12），路線 (a) 原始碼可行；實作路由交 G2、解鎖交 ADR-0004 |
| TR-concept-011 | WebGL 無 UDP → WSS 傳輸鏈路 | 概 L234① | Networking/Platform | Foundation | 0005 | ✅ Covered | D6 全平台顯式 WSS、禁 `Default`（RPC 順序保證待 ADR-0002 V③ 實測） |
| TR-concept-012 | NGO client-server ＋ Relay ＋ Sessions、client-hosted | 概 L233、L238 | Networking | Foundation | 0006 | ✅ Covered（r2 ↑） | 0006 D1 正式裁決拓撲 |
| TR-concept-013 | 互動事件同步、非物理精準同步 | 概 L238 | Networking | Core | 0001, 0002 | ✅ Covered | C1 無物理模擬、owner 權威＋內插；互動走 RPC |
| TR-concept-014 | 建置 ≤44 MB gzip；Gzip＋`decompressionFallback=false`；Stripping High | 概 L233、L254；tech-prefs L24-65 | Build/Platform | Platform | 0001, 0005 | ⚠️ Partial | 僅作約束引用；壓縮／剝除決策只在 tech-prefs |
| TR-concept-015 | URP 渲染：燈光即場景、零美術素材、程序化材質、頭頂 icon 可讀 | 概 L187-197、L235-236 | Rendering | Presentation | — | ❌ Gap | 6.3 URP 僅 render graph 的硬約束無人承接 |
| TR-concept-016 | 機台音效＝手感核心；Web 首次手勢前禁自動播放 | 概 L237；tech-prefs L26-27 | Audio/Platform | Presentation | — | ❌ Gap | r3：0005 r1 明文把 `AudioContext` 與首次手勢前禁播交給「#14 音效 ADR」，該 ADR 不存在 |
| TR-concept-017 | 資料驅動內容：店型＝參數集、程序波次；店面手工佈局 | 概 L239-240 | Data/Level | Feature | 0001 | ⚠️ Partial | D3 把「幾何卡住」缺口推給 #11 死巷清查，無人擁有 |
| TR-concept-018 | 鍵鼠主、觸控／手把次；手機瀏覽器後期 | 概 L222、L254、L302；tech-prefs L20-23 | Input | Core | 0001 | ⚠️ Partial | action map 固定 `{Move2D, Look2D}`；觸控無 pointer lock → `adoptInput` 來源缺 |
| TR-concept-019 | Steam 桌面版（Alpha） | 概 L260 | Platform | Platform | 0005 | ✅ Covered | 平台抽象層；Steam 整合 ADR 留 Alpha |
| TR-index-001 | #5←#3：僅本機俯仰＋射線起點；自報 (x,z,yaw) | 索 L24 | Core/Networking | Core | 0002 | ✅ Covered | D1-2 瞄準本機；`SelfPose` 構造無 pitch |
| TR-index-002 | #5→ADR-0002 硬依賴：Host 只驗水平距離＋朝向 | 索 L24、L129③ | Networking | Core | 0002 | ✅ Covered | 述詞①–⑥、`tol_lag` 綁定 |
| TR-index-003 | `ICheckoutCustomerQuery`（Host-only，讀 #7 NV 現值，同 tick 自洽） | 索 L24、L141①、L151 | Gameplay/Networking | Core | — | ❌ Gap | 孤兒契約（提供方 #7 無 GDD） |
| TR-index-004 | `IShelfAvailabilityQuery.GetAvailableStock`；「有人正在拿＝不可得」 | 索 L26、L126①、L141③ | Gameplay | Core | — | ❌ Gap | 無 ADR |
| TR-index-005 | 訂單完成／交付邊緣事件契約（#5→#7、#4→#7） | 索 L26、L105、L141② | Gameplay | Feature | — | ❌ Gap | 無 ADR |
| TR-index-006 | `ISolidCapsuleQuery` #7←#3 膠囊（軟） | 索 L26、L61 | Core | Core | 0003 | ✅ Covered | `FillSolidCapsules` 零配置 |
| TR-index-007 | `ProductInstance` 攜帶：禁 NetworkList 承載；ownership transfer；冷卻起點＝Taken | 索 L125②、L126③、L140①③ | Networking | Feature | 0003 | ⚠️ Partial | 僅 D7 警告 `ChangeOwnership` 不清 NV；攜帶表示法無 ADR |
| TR-index-008 | `is_spoiled`／`network_index` server-write、Spawn 前寫入、之後不可變 | 索 L126② | Networking/Data | Core | — | ❌ Gap | 無 ADR |
| TR-index-009 | #11 PassThrough 雙向可見用同一遮罩 | 索 L128②、L132② | UI/Networking | Presentation | 0003 | ✅ Covered | D5 不另建管道 |
| TR-index-010 | 非語音「我要這個」ping | 索 L128④ | UI/Networking | Presentation | — | ❌ Gap | 無 ADR |
| TR-index-011 | 走道幾何：無兩具身體互釘死；spawn 進幾何無保險絲 | 索 L128⑤、L132④ | Level | Feature | 0001 | ⚠️ Partial | D3 明文推給 #11；無擁有者 |
| TR-index-012 | 不鎖移動、離開即中斷半徑 >0.6 m、無垂直互動 | 索 L129①②④ | Gameplay/Networking | Core | 0002 | ✅ Covered | D7 三層中斷＋關係式；述詞無 Y |
| TR-index-013 | #8 節拍邊界；`2×beat ≥ player_pin_timeout_sec`；穿越店面時間上限三方聯署 | 索 L130、L132⑤ | Gameplay | Feature | — | ❌ Gap | 無 ADR |
| TR-index-014 | `npc_id_reuse_cooldown_sec ≥1.0`；NPC 在場讀 NV 不讀 RPC | 索 L131①② | AI/Networking | Core | 0003 | ✅ Covered | D4 裁決 |
| TR-index-015 | #7 避讓二選一（自訂 steering vs `NavMeshAgent` → AC17 作廢） | 索 L131③ | AI | Core | 0003 | ⚠️ Partial | D6 框定選項，裁決推給尚不存在的 #7 ADR |
| TR-index-016 | #14：遠端碰撞音自內插位置微分；邊緣事件走 NV 回呼；衰減／發聲數／遮蔽／混音 | 索 L133、L143、L156② | Audio | Presentation | 0001, 0002 | ⚠️ Partial | D8 不另建管道、讀 NV 回呼確立來源；音效架構無 ADR |
| TR-index-017 | #18 動暈／靈敏度／FOV／鍵位重綁在 MVP 曝險 | 索 L134、L148③④ | Accessibility/Input | Polish | — | ❌ Gap | ADR-0001 Input System 僅技術鉤子 |
| TR-index-018 | 版本 token 涵蓋純內容變更；兩平台同版本同時發版 | 索 L136①、L160④ | Build/Networking | Platform | 0005/0006 | ⚠️ Partial | 0006 D5 `BuildId` 內容雜湊；雜湊輸入範圍交 G4。r3：`HeartbeatWire` 逐欄序列化，避開 wasm32／x64 佈局相依；NGO 設定雜湊也是版本 token 的一部分（EA-2） |
| TR-index-019 | 約束⑧讀法：結果走 RPC、狀態走 NV；netcode 自相矛盾；`is_spoiled` 歸屬 | 索 L136② | Networking | Core | 0002, 0003 | ⚠️ Partial | 兩份 ADR 默採窄義，未裁決矛盾 |
| TR-index-020 | 延遲模型：4 段 relay 腿；內插 ≥200 ms（TickLatency）；`remote_step_tolerance`；判準側 dt 上限；併發負載下驗 | 索 L137①③⑤、L138、L144③ | Networking | Core | 0002 | ⚠️ Partial | 內插模型已糾正；容差、dt 夾制、併發負載無人擁有 |
| TR-index-021 | 撲空對稱：房主永不撲空 | 索 L139① | Networking/Gameplay | Core | 0006（數字） | ⚠️ Partial（r2 ↑） | 0006 只提供數字（Host 自身 RPC 零往返、同區單程 ≈ 44–47 ms）；公平窗口的裁決歸 ADR-0004 |
| TR-index-022 | claim 租約續期（每次接受動作 RPC 重設）；到期只釋放 claim | 索 L139②、L144②、L158④ | Networking | Core | 0002/0006 | ⚠️ Partial | 0006 D7 第 3 步：斷線只釋放 claim；租約續期語意歸 ADR-0004 |
| TR-index-023 | 撲空畫面順序（等贏家內插進 reach）；進度由 `WorkStartTick` 各端自算 | 索 L142 | UI/Networking | Presentation | 0002 | ⚠️ Partial | D4 只定觸發；順序與進度無 ADR |
| TR-index-024 | ADR-0002 待加註：持有期只驗②③④；⑤⑥錨點以槽為單位；`NothingToTake`；第四中斷源；C20 RPC 集取代 `RequestInteractRpc` | 索 L144①、L150①②、L158①⑤ | Networking | Core | 0002 | ⚠️ Partial | 五項修正均未入 ADR；RPC 簽章已與 GDD 衝突（待 ADR-0004 同步） |
| TR-index-025 | 同 tick 順序（先 RPC 再逾時掃描）；E2 掛 `OnNetworkTick`；`AutoObjectParentSync=false` | 索 L150③、L158②③ | Networking | Core | — | ❌ Gap | ADR-0004 範圍 |
| TR-index-026 | ADR-XXX 建置期資料治理閘門（14 條資料不變量） | 索 L146 | Build/Data | Platform | — | ❌ Gap | 索引明列待寫 |
| TR-index-027 | #20 平台鉤子：region／背景分流／sendBeacon／帶碼連結↔Rich Presence；心跳；分頁隱藏≠失焦 | 索 L39、L63、L137④ | Platform/Networking | Platform | 0005/0006 | ⚠️ Partial | 心跳 0006 D6；離開通知 0005 r1 keepalive fetch＋headers、送出端單發（r2 待辦已完成）。r3 新缺陷：`beforeunload` 為實際送出點、與確認框衝突（FV-4）；REST 路徑寫錯被 404 吞掉（EA-1）；V10 未驗；Rich Presence 歸 Alpha |
| TR-index-028 | 攝影機常數（near clip 0.10）擁有者；#11 讀攝影機 transform | 索 L22、L71 | Rendering/Core | Core | — | ❌ Gap | 曾為「無擁有者子系統」，仍無 ADR |

小計（r2）：Covered 13／Partial 21／Gap 13（共 47）〔前次 10／22／15〕。002／009／012 →✅（拓撲、兩層會談、容器按 4）；concept-007、index-021 →⚠️。孤兒契約（#4／#7／#8／#9／#11–#15）不變

**索引中的 ADR 依賴宣告**：#3→ADR-0001（Proposed；Blocks：Accepted 前 #3 全部 Logic story）；#5→ADR-0002 硬＋ADR-0004 待寫；#7←ADR-0003 三條 levy，且 D6 要求 #7 自己的避讓 ADR（不存在）；#20→ADR-0005（已寫），衍生「DTLS×WSS 混房」（VS 前）與「Steam 整合範圍」（Alpha）兩份未來 ADR；technical-director＋devops→ADR-XXX 建置期資料治理閘門（不存在）。

**孤兒契約（被依賴但無 GDD 無 ADR）**：#4 手部容量查詢、跨訂單分配、`ProductInstance` 搬運／退回／掉地；#7 `ICheckoutCustomerQuery`／`CustomerOrder`、訂單完成事件消費、NPC id 分配與冷卻、指名比例、關東煮占比；#8 節拍邊界、密度抽樣、單人縮放；**#9 遊戲時鐘：`shift_end_ts`、21:00→08:00 骨幹——#8／#10／#15／#5 共同依賴，零文件**；#11 `design/ux/hud.md`、多 icon 擺位、撲空順序、提示遲滯、背後站台提示、槽高度帶、錨點／淨距、隊友不在指示、重鎖點擊面積；#12 大廳流程；#13 `display_label` 消費；#14 事件清單、收銀「嗶」觸發源、步頻；#15 `MatchResult` 消費、槽位整合測、班次結束殘留、不中計失誤；#20 心跳在 ADR-0005 與 GDD 之外；#17「按住＝補貨」affordance 在 MVP 落到 #11。

**CD／TD 待決（架構類）**：TD——`remote_step_tolerance` 定義＋判準側 dt 夾制；建置期資料治理閘門 ADR；DTLS×WSS 混房探針（VS 前）。netcode GDD 擁有者——約束⑧ 讀法、撲空對稱修法、`interpolation_buffer_ms` 三處重推。CD——視野角在 MVP 無擁有者；#18 時序矛盾；ADR-0004 直接寫；Steam 支柱 4 分平台改寫與商業模型 C。arlong——若 #4 需 `NetworkList<ProductInstance>`，須 W1 式實測並重裁 AC14。

**概念 vs technical-preferences 不一致**：①建置體積：概 L233「30-50MB」未標單位 vs tech-prefs「≤44 MB gzip」（2026-09-18 修訂）②連線服務命名：概「Unity Relay + Lobby」 vs MPS Sessions（`deprecated-apis.md` 走 Sessions）③Target Platforms 只列 Web，索 #20／ADR-0005 已加 Steam（Alpha）④Allowed Libraries 仍是「NGO／Relay／Lobby 待補」佔位，四份 ADR 已釘 NGO 2.13.2／MPS 2.3.1／UTP 2.x——版本真相只在 ADR 表頭 ⑤概念無幀率／記憶體陳述（缺口非矛盾）⑥索 L12、L223 寫「19 個系統」但表有 20 列；概 L308 仍寫「CLAUDE.md 釘的是 Godot 4.6」；`docs/CLAUDE.md` 末行仍指向 godot VERSION.md。


## Known Gaps（依建議 ADR 分群；r3）

見 r3 報告 §3、§8（分群沿用 r2 報告 §2）。摘要：
- ~~**G1** 網路拓撲、Session 生命週期與連線健康~~ → **ADR-0006**（Proposed，r1）。殘留 Partial：TR-netcode-010/011/013/018/023/028/031/044/046。**ADR-0006 r2＋ADR-0005 r2 的 Accept 前必修 7 條**：FV-1（Lobby\* 入口不可達，需裁決）、FV-3、CX-2、EA-1、FV-4、FV-5、EA-4（r3 報告 §3A）
- **G2** 同步物件生命週期與所有權轉移（Foundation/Core，HIGH）：TR-netcode-005/006/023/033；TR-machine-008/009/010/012/013/027；TR-product-023/024/025；TR-index-007/008。**須登記**（r3 更新）：avatar prefab `DontDestroyWithOwner = true`；第 5 步之後道具在每個 client 上存活並收斂到 Host 落地座標，路由 (a) client 端 `OnNetworkDespawn` 自救（推薦）／(b) 先於 despawn 的 reliable 訊息二選一；第 5 步以 destroy 方式 despawn、不池化；Onboarding avatar 的可見性與碰撞（CX-3）；`owner_write_networkvariable_on_transferable_object` 含 avatar 例外（CX-6）；道具的「地面」狀態與持有者欄（GF-12）；掉落後再拾取 ≥ 6 tick
- **ADR-0004** 機台互動組 Core 分層與 RPC 契約（Core，MEDIUM）：TR-machine-002/003/004/007/014/015/017/019/020/021/024/025/033/040/041/042/045/048/051/052/053；TR-index-003/004/005/021/022/024/025；TR-product-027
- **G4** SKU 資料格式、ID 與序列化凍結（Foundation，MEDIUM）：TR-product-001–005/008–017/026；TR-machine-007。r3：NGO 設定雜湊（含 prefab 清單）也是版本 token 的一部分（EA-2）
- **G5** 建置期資料治理閘門與 CI 守門（Foundation，MEDIUM）：TR-product-018–022；TR-machine-054；TR-index-026；ADR-0006 D12 建置期斷言
- **G6** 資產繫結與載入（Foundation，MEDIUM）：TR-product-006/007/032；TR-netcode-033；TR-concept-014
- **G7** 攝影機與渲染基線（Core/Pres，HIGH）：TR-fpc-029；TR-index-028；TR-concept-015；TR-machine-056；TR-product-030
- **G8** 延遲模型與容差（Core，HIGH）：TR-fpc-040；TR-netcode-016/030/043；TR-index-020；TR-machine-030
- **G9** 遊戲時鐘與班次時基（Foundation，LOW；先寫 #9 GDD）：TR-concept-007；TR-machine-045；TR-netcode-013（公式③）。`ShiftEndTs` 真相已在 ADR-0006 D13
- ~~**ADR-0005 r1**~~（2026-10-03 已寫；X2／X3／C6／DEP 已修）→ **ADR-0005 r2**：必修 FV-4（只在 `pagehide` 送出、確認框介面）、EA-4（`AlwaysLinkAssembly`、無人註冊即拋例外）；另 CX-8、EA-7、EA-9、FV-9。相關 TR：TR-netcode-010/013/026/027；TR-fpc-019/020；TR-concept-003/016/018；TR-index-027
- **ADR-0002 r1**：TR-machine-006/016/018/022/032；TR-index-024；＋`ClaimedBy`／`requester` 改 slot、`RejectReason` 改名
- **ADR-0001／0003 r1**：`PeerKey`（TR-fpc-011）、`FreezeInput` 參與者、遮罩清零的觸發點（非 Host 端仍以 avatar despawn 為主，見 CX-2）；r3 追加：`Solve` 的 `selfId`、Depends On 補列 ADR-0006、avatar 元件快取本機判定（CX-7）、「在場玩家」＝`PlayerJoined` 已發出（CX-3）、TickRate 改引用 ADR-0006（CX-4）、pointer lock 的 T1-Web 承接（TR-fpc-019／020）
- **延後／需先有 GDD**：見首輪報告 §2 G12

## Superseded Requirements
無 deprecated。r3 無措辭修訂。r2 修訂措辭（同一意圖、ID 不變）：TR-netcode-014（`LeaveSessionAsync`→`ISession.LeaveAsync`）、TR-netcode-017（payload 補 `host_now_ms`）、TR-netcode-028（12 態；矩陣 32 列 × 11 欄）、TR-machine-001（`ClaimedBy` ulong→byte slot）。

## History
| Date | Covered | Partial | Gap | Verdict | Notes |
|---|---|---|---|---|---|
| 2026-10-01 | 50 | 70 | 107 | FAIL（覆蓋＋1 BLOCKING 身份契約） | 首次審查；4 ADR（皆 Proposed）對 5 GDD |
| 2026-10-01（r2） | 71 | 74 | 83 | FAIL（Foundation Gap 20；身份契約已裁決待傳播；ADR-0006 四條 Accept 前必修） | ADR-0006 寫入後重跑；5 ADR（皆 Proposed）；netcode Foundation Gap 9→1 |
| 2026-10-03（r3） | 71 | 74 | 83 | FAIL（Foundation Gap 20；ADR-0006／0005 Accept 前必修 7 條，FV-1 需裁決） | ADR-0006 r1＋ADR-0005 r1 寫入後重跑；r2 必修 E1／E6／E8 已修、E2 半修；TR-netcode-007 ↑、010 ↓ |
