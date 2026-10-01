# Steam 可行性評估 — 大夜班 (Night Shift)

> **日期**：2026-10-01
> **性質**：唯讀評估＋arlong 裁決紀錄。由 technical-director 與 producer 兩位專家平行評估，主 session 整理；發行面數字以官方 Steamworks 文件為準，URL 已以 `curl -sI` 驗證（見文末）。
> **結論**：**能上，門檻不高，但現在不該上。** 桌面版沿用 Relay WSS 就能與 Web 玩家同房，傳輸層零改動；真正要做的是平台抽象層與手把全覆蓋。發行資格台灣個人即可，每款 US$100。開案第 4 週、正式程式碼 0 行，MVP 內容撐不起付費——先用 Web 版驗證核心假設，VS playtest 過關再開 Steam 頁，瞄準 2027-06 Next Fest。

## arlong 裁決（2026-10-01）

| 題目 | 裁決 |
|---|---|
| 方向 | **A**：記下方向，現在只做兩件便宜的事——平台抽象 ADR（ADR-0005，S）＋系統索引加「平台服務」一列（Web 橋接實作 MVP、Steam 實作 Alpha）。Steam 本體等 VS playtest 達到「連玩 30 分鐘還想再開一班」再啟動 |
| 商業模型傾向 | **C**：Steam 付費＋Web 當免費入口／訪客端（Friend Pass 模式）；支柱 4 分平台改寫交 creative-director 於 VS 前裁決 |
| 本評估 | 存檔於此，不 commit（等 arlong 指示） |

## 一、技術面（technical-director）

### 一句話
能，而且傳輸層不用改。桌面版沿用 Relay WSS 就能和 Web 玩家同房。真正要做的有兩件：把瀏覽器橋接抽成平台層，以及補上手把／Deck 支援。Steam 版建議 Alpha 再做，但平台抽象 ADR 應該現在寫——正式程式碼還沒開始，現在改最便宜。

### 最小技術路徑
1. **平台層**：netcode GDD 用到的瀏覽器橋接（`netcode-session.md:792-794` 那幾條，加上時區、剪貼簿、帶碼連結）收進同一個介面。Web 走 `.jslib`，桌面走 Unity 原生 API，region 交給 QoS 選。W1 已用 `#if UNITY_WEBGL && !UNITY_EDITOR` 包住 DllImport（`prototypes/w1-netcode/Assets/Scripts/W1WebProbe.cs:22`），桌面照樣能編譯。
2. **傳輸**：共用 helper 要同時鎖定 `RelayProtocol.WSS` 與 `UseWebSockets = true`，**不能用 `Default`**——MPS 2.3.1 的 `Default` 在非 WebGL 平台會變成 DTLS（`RelayProtocol.cs:34-38`），與 `UseWebSockets = true` 對不上就拋 Mismatched。桌面走 WSS 已實測：W1 的雙進程 RTT、ownership、斷線測試跑的就是 Editor 桌面進程加 WSS（`RttRoleTests.cs:65,122`），94.5 ms 就是這樣量出來的。standalone player 尚未測。
3. **平台**：只出 Windows build，Deck 靠 Proton 跑。URP 與 Input System 都跨平台；手把只是在現有 action 上加綁定，不違反 FP AC1③。
4. **Steam 端**：上架必要＝Steamworks 帳號、商店頁、SteamPipe 上傳；選配＝Steamworks.NET、Overlay、Rich Presence `connect` 帶房間碼（等於 Web 的帶碼連結）、成就、雲存檔、Deck Verified（評級，不是門檻）。DRM 不建議。
5. **發版**：Web 與 Steam 必須同版本同時發——tick rate 在 NGO 連線雜湊裡（`NetworkConfig.cs:351`），只對單一平台熱修會讓跨平台握手全部失敗。

### Web 特有決策對照表

| 決策 | Web 特有 | Steam 版 |
|---|---|---|
| ≤ 44 MB gzip、heap 512 MB | 是 | Steam 沒有此限制；但只要 Web 版還在又共用內容，它仍是內容上限 |
| Gzip＋`decompressionFallback = false` | 是 | 只留在 Web 的 build profile |
| 混音只能調音量、`AudioContext` 解鎖 | 是 | 現行腳本式音量設計可原樣使用；不做桌面專屬音效 |
| 指標鎖定「不得自動重鎖」 | 是 | 三態模型保留（Alt-Tab、Overlay 仍會失焦），只放寬這一條 |
| 10 Hz tick | 否 | 跨平台兩端必須一致（連線雜湊） |
| 約束⑧（互動結果走 RPC） | 否 | 原樣保留 |
| Core Rule #28 依時區選 region | 機制是 | 桌面改用 QoS；allocation 由 Host 建立，自然貼著 Host |
| #17 背景分流、#12 sendBeacon、#27 下載卡住偵測 | 是 | #17 回報「一律在前景」；#12 改 `wantsToQuit`；#27 不適用；#20 心跳仍需要 |

### 傳輸層選項

| 選項 | 延遲／HOL | 能否與 Web 同房 | 代價 |
|---|---|---|---|
| **A 桌面沿用 WSS（推薦）** | 與 Web 相同 | 能 | 零 |
| B 桌面改 DTLS | 中位數應相近；丟包時尾端延遲較好（未查證） | 官方文件寫同一 allocation 可混用協定（[UTP cross-play](https://docs.unity3d.com/Packages/com.unity.transport@2.0/manual/cross-play.html)）；本專案未實測 | 三處設計建立在「TCP 不丟包」前提上要重審：netcode `:389-397`、ADR-0002 驗證③、machine-interaction F2 交叉檢查 |
| C Steam Datagram Relay | 未查證 | **不能**，玩家池分裂成兩個 | session 層重做、W1 實測全部重跑；社群 transport 對 NGO 2.13 的支援未查證（[community contributions](https://github.com/Unity-Technologies/multiplayer-community-contributions)） |

跨平台同房時 tick 被鎖住，300 ms 預算與 F4（200＋150 → 400）不變；只有 Steam 自成玩家池時 tick 才能拉到 20 Hz、F4 變 250。C 只在放棄 Web、或超過 Relay 每月平均 50 CCU 免費額度時才划算。

### 需要的 ADR 與工時（建議）
- ADR：平台抽象（S，**現在寫**＝ADR-0005）、傳輸協定（S）、Steam 整合範圍（S）、版本檢查與同步發版（S）。
- systems-index：加「平台服務」一列（Web 實作 MVP、Steam 實作 Alpha）。
- CI：目前沒有 CI，需要加一條 Windows standalone build（M）。
- 手把全覆蓋：UI 導覽、按鍵提示圖示、搖桿 Look 常數（M–L）；搖桿瞄準 SKU 槽可能需要吸附輔助（設計決策）。
- 整體 M–L，切入點 Alpha。

### 風險
- 單一平台熱修 → 連線雜湊不一致 → 跨平台握手全失敗。
- 一人維護兩個 build，驗證加倍。
- 支柱 4 在 Steam 上沒有免安裝的路：Remote Play Together 只串流房主一個畫面（[Steam Deck compat](https://partner.steamgames.com/doc/steamdeck/compat) 另外要求全手把可玩）；Playtest 與 Demo 都要安裝。
- Steam 收費、Web 免費且跨平台同房＝提供免費完整客戶端——商業決策（已由裁決 C 處理：Web 只放有限內容）。

### 未查證（TD）
1. DTLS 與 WSS 混房：用 W1 harness，一端桌面 DTLS、一端 Release Web 實測。
2. DTLS 在丟包下的 p95：netem 丟 2% 對照。
3. 社群 Steam transport 對 NGO 2.13 的相容性：裝進 w1 原型連一次。
4. Steamworks.NET 與 Facepunch 的維護狀態：看 GitHub 最近 release。
5. 能否在 macOS 建 Windows IL2CPP：原型試建；不行就 Mono 或 Windows CI。
6. Deck 審查細則（全手把、自動螢幕鍵盤、字級 9 px @ 1280×800）：登入 partner 文件核對。
7. DX12 下 Overlay 與 Proton：最小 build 實測。
8. Steam Input 把手把映射成鍵鼠時 Deck 評級是否只到 Playable。

## 二、發行面（producer）

### 上架門檻與時間線（官方文件，已驗證）
- **資格**：個人可註冊（公司形式 Sole Proprietorship），銀行戶名須與註冊名一致；稅務訪談 5–10 分鐘，之後驗證 2–7 個工作天（[onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding)）。
- **費用**：每款 US$100，不退；該作調整後毛收入達 US$1,000 後回補（[appfee](https://partner.steamgames.com/doc/gettingstarted/appfee)）。
- **收款**：美國境外 USD SWIFT 電匯，月結，未滿 US$100 不撥（[payments FAQ](https://partner.steamgames.com/doc/finance/payments_salesreporting/faq)）；文件未列 PayPal。
- **美國稅**：無租稅協定國家，美國來源收入預扣 30%（[tax FAQ](https://partner.steamgames.com/doc/finance/taxfaq)）；第三方解讀為只扣美國買家那一塊（未驗證）。台美避免雙重課稅法案 2026-06 仍卡參院（producer 查得，URL 未驗證）。
- **台灣稅**：個人海外所得；全戶海外所得達 100 萬才計入基本所得額，基本所得額超過 750 萬才繳基本稅額（[財政部](https://www.mof.gov.tw/singlehtml/384fb3077bb349ea973e7fc6f13b6974?cntId=aa76b844d30d4b56b21b22655b41b926)）。要不要營業登記／發票：未查證，問會計師。
- **流程**：付費後 30 天等待；即將推出頁至少公開 2 週；店面與 build 各審 3–5 個工作天，建議各提前 7 天送（[releasing](https://partner.steamgames.com/doc/store/releasing)、[review process](https://partner.steamgames.com/doc/store/review_process)）。
- **素材**：Header 920×430、Small 462×174、Main 1232×706、Vertical 748×896、Library 600×900（[assets](https://partner.steamgames.com/doc/store/assets/standard)）；截圖至少 5 張（第三方整理）；預告片最高 1080p。
- **Next Fest**：每款一次；商店頁先公開、開幕時要有公開 demo、活動結束後才發售（[nextfest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)）。2026-10 場已截止；**2027-02 場報名到 01-10**（[feb_2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027)）；**2027-06 場（06-14～21）報名到 04-25**（[june_2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027)）。
- **Playtest 與 Demo**：Playtest 不影響評論與願望單（[playtest](https://partner.steamgames.com/doc/features/playtest)）；Demo 可有獨立頁面與評論，上線能通知願望單一次（[demos](https://partner.steamgames.com/doc/store/application/demos)）。
- **Early Access**：須可玩、不能承諾未來內容、**價格不得高於其他任何平台**（[earlyaccess](https://partner.steamgames.com/doc/store/earlyaccess)）——Web 完整版免費且內容相同時，Steam EA 收費會撞這條。
- **免費遊戲**：F2P 不一定要有內購；付費改免費要提前一週公告（[freetoplay](https://partner.steamgames.com/doc/store/freetoplay)）。

### 商業模型選項

| 路線 | 內容 | 代價 | 最早時點 |
|---|---|---|---|
| A 兩邊都免費 | 冷啟動最好（Supermarket Together 免費，評論數第三方統計約 9.9 萬，未驗證） | 零收入；Relay 超過月均 50 CCU 要自付（[UGS pricing](https://unity.com/products/gaming-services/pricing)） | 2027 Q1 |
| B Web 完整免費＋Steam 加值 | Cookie Clicker 模式（網頁版有廣告、Steam 版 US$4.99 多原聲帶／雲存檔／成就） | 我們的網頁版沒廣告，Steam 缺購買理由；撞 EA 價格條款，只能直接 1.0 | Full Vision 後 |
| **C Steam 付費＋Web 免費入口／訪客端（推薦，arlong 傾向）** | Web 只放有限內容並當訪客端；Steam 由房主付費，朋友用 Web 連結或 Friend Pass 免費加入。先例：Jackbox（[how to play](https://www.jackboxgames.com/how-to-play)）、[Timemelters Friend Pass](https://store.steampowered.com/app/2477230/Timemelters__Friend_Pass/)、Vampire Survivors 從 itch 網頁版走到 Steam EA | 支柱 4 分平台改寫（CD 裁決）；Friend Pass 是第二個免費 app（3–5 天） | VS 後開頁 → 2027-06 Next Fest → EA |

C 是唯一同時保住支柱 4 與收入的路線；「4 人房只要 1 人付費」直接對沖概念文件的冷啟動風險。不建議報 2027-02 場：VS 不一定完成，而每款只能參加一次。啟動條件：VS playtest 達到「連玩 30 分鐘還想再開一班」。

### 支柱 4 怎麼處理
- **Remote Play Together 解不了**：它串流房主單一畫面，官方只對本地多人／分割畫面自動啟用（[remoteplay](https://partner.steamgames.com/doc/features/remoteplay)）；本作每人有自己的第一人稱視角。訪客不用帳號、不用買，但要裝 Steam Link app。
- **建議分平台改寫**：Web＝「開連結就開玩」；Steam＝「一人買、朋友免費進」。這是支柱變更，由 creative-director 裁決（已登記索引前向義務表）。
- **技術前提未驗證**：Relay DTLS／WSS 混房 W1 只測過 WSS 對 WSS——VS 前開 1–2 天探針。

### 製作面新增工作項（solo 粗估，未用 `/estimate` 細拆）

| 項目 | 階段 | 粗估 |
|---|---|---|
| Steamworks 註冊、稅務訪談、問會計師營業登記 | VS 前 | 1 天＋等待 |
| 跨平台連線探針（DTLS×WSS 混房） | VS 前 | 1–2 天 |
| Windows 移植（`.jslib` 路徑換桌面做法＝平台抽象層） | VS 後 | 5–8 天 |
| Steamworks SDK（好友邀請轉房間碼、Overlay） | VS 後 | 3–5 天 |
| Friend Pass（第二個免費 app） | 選配 | 3–5 天 |
| 店面素材＋預告片 | VS 後 | 6–9 天 |
| Demo 切分＋Next Fest 準備 | Fest 前 8 週 | 5–7 天 |
| en／zh-CN 在地化（字型、梗改寫） | Alpha | 5–8 天＋翻譯 |
| 成就＋雲存檔 | Alpha | 3–5 天 |
| Steam Deck 相容 | Alpha 後 | 3–5 天 |
| 雙平台 QA | 每次發行 | 3–5 天／次 |

合計約 40–60 人日，約等於再做一個 VS。系統索引原 19 個系統裡沒有平台、成就、存檔、在地化——已加 #20 平台服務，其餘待補。附帶好處：Steam Playtest 可招海外測試者，補量 W1 的跨區延遲（217–306 ms 目前只是推估）。

### 風險
1. **速度**：概念文件的 MVP 4–6 週已不成立（正式程式碼 0 行、GDD 0 份 Approved、`production/` 無大夜班里程碑或 sprint）。任何 Steam 工作不得排在 MVP 前。
2. **市場不是空白**：Supermarket Together、Supermarket Simulator 已在；類型天花板 Overcooked 2、PlateUp!（評論數來自第三方統計站，`curl` 回 500，未驗證）。真正的空白只有「台灣超商 × 亂鬥」這個窄交集。
3. **美術**：itch → Steam 的成功作多半伴隨畫面升級（[howtomarketagame](https://howtomarketagame.com/2025/05/22/more-games-that-made-the-itch-io-to-steam-transition/)）；「零美術素材」路線在 Steam 的競爭力需 art-director 評估。
4. **語言**：Steam 硬體軟體調查繁中約 1.31%、簡中約 23.97%（[hwsurvey](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam)，producer 讀數 2026-08 月份，主 session 未逐項核對）；支柱 2 的在地梗外銷未必秒懂；台灣元素在簡中社群有被刷負評的風險（推論）。
5. **台灣題材規模參照**：九日、返校、廖添丁皆為單機，沒有合作派對遊戲先例（數字未驗證）。
6. **一人維護兩平台**：兩版連線協定必須同步發版；44 MB 硬標只綁 Web，要防兩版內容分岔；美國 30% 預扣持續到台美法案通過。

### 未查證（producer）
Overcooked 2 線上合作是否每人一份；台灣營業登記／發票；免費遊戲的評論與曝光機制差異；Library Hero／Logo 尺寸、預告片是否必填；Steamworks.NET vs Facepunch；即將推出頁提早 6–12 個月的常識；評論數換算銷量倍數；台美法案 2026-06 後進度；本報告所有工時與「VS 約 2027 Q1」的推估。

## 三、下一步

1. **現在**：ADR-0005 平台抽象層（`/architecture-decision`）；索引 #20 平台服務（已加）。
2. **VS 前**：creative-director 裁決支柱 4 分平台改寫；DTLS×WSS 混房探針 1–2 天；Steamworks 註冊與稅務訪談；問會計師。
3. **VS playtest 過關後**：開 Coming Soon 頁累積願望單；Windows 移植、Steamworks SDK、店面素材。
4. **目標**：2027-06 Next Fest（報名截止 2027-04-25，需公開 demo）→ Early Access。
5. **Alpha**：成就、雲存檔、en／zh-CN 在地化、Steam Deck。

## 已驗證 URL（`curl -sI` 200，2026-10-01）
- https://partner.steamgames.com/doc/gettingstarted/onboarding
- https://partner.steamgames.com/doc/gettingstarted/appfee
- https://partner.steamgames.com/doc/finance/payments_salesreporting/faq
- https://partner.steamgames.com/doc/finance/taxfaq
- https://partner.steamgames.com/doc/store/releasing
- https://partner.steamgames.com/doc/store/review_process
- https://partner.steamgames.com/doc/store/assets/standard
- https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest
- https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027
- https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027
- https://partner.steamgames.com/doc/features/playtest
- https://partner.steamgames.com/doc/store/application/demos
- https://partner.steamgames.com/doc/store/earlyaccess
- https://partner.steamgames.com/doc/store/freetoplay
- https://partner.steamgames.com/doc/features/remoteplay
- https://partner.steamgames.com/doc/steamdeck/compat
- https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam
- https://www.mof.gov.tw/singlehtml/384fb3077bb349ea973e7fc6f13b6974?cntId=aa76b844d30d4b56b21b22655b41b926
- https://www.jackboxgames.com/how-to-play
- https://store.steampowered.com/app/2477230/Timemelters__Friend_Pass/
- https://howtomarketagame.com/2025/05/22/more-games-that-made-the-itch-io-to-steam-transition/
- https://unity.com/products/gaming-services/pricing
- https://docs.unity3d.com/Packages/com.unity.transport@2.0/manual/cross-play.html
- https://github.com/Unity-Technologies/multiplayer-community-contributions

未驗證或第三方：steambase.io 各頁（`curl` 回 500）、presskit.gg、fapa.org、cna.com.tw、accounting.sme.gov.tw、steampageanalyzer.com、howtomarketagame 2024 demo 文、pcgamesn、steamcommunity 討論串、Operation: Tango Friend Pass 頁、wikipedia、gamesradar、neowin、tweaktown、pcgamer、ghacks、gnn.gamer.com.tw、inside.com.tw、techraptor、Nine Sols／Detention／廖添丁 商店頁。
