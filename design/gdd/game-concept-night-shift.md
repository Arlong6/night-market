# Game Concept: 大夜班 (Night Shift)

*Created: 2026-09-03*
*Status: Draft*

---

## Elevator Pitch

> 這是一款瀏覽器就能玩的第一人稱連線合作派對遊戲：你和朋友是台灣超商的大夜班店員，
> 在狹窄的店裡撈關東煮、煮咖啡、刷條碼、補貨、收包裹，招呼一波波深夜奇人——
> 忙到天亮結算星級。像 Overcooked，但你「人在店裡」，而且每個台灣人都懂這些梗。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 合作工作亂鬥（co-op chaos）× 派對遊戲 |
| **Platform** | Web 瀏覽器（WebGL），開連結＋房間碼即玩 |
| **Target Audience** | 開黑朋友群、情侶、實況主與觀眾（見 Target Player Profile） |
| **Player Count** | 2-4 人連線合作（單人＝練習模式，不做平衡優先） |
| **Session Length** | 一班 8-10 分鐘；一場聚會 30-90 分鐘連續值班 |
| **Monetization** | 免費（itch.io），視反應再議 |
| **Estimated Scope** | Medium（MVP 4-6 週；完整願景 4-8 個月，solo＋新引擎學習） |
| **Comparable Titles** | Overcooked 2、PlateUp!、Sushi For Robots |

---

## Core Fantasy

「亂中維持專業」的爽感：警報四起、微波爐狂叫、五個客人同時按服務鈴，而你們一組人
用默契把場面撐住——或是徹底失控，咖啡潑滿走道，全員笑到不能自理。
別的遊戲給你當英雄；這款給你「跟朋友一起上班出包」的共同回憶，
而且是每個在台灣活過的人都親身排過隊的場景。

---

## Unique Hook

「像 Overcooked，**而且**是第一人稱、走進台灣超商裡面工作。」

- 第一人稱＋狹窄店面：**隊友本身就是障礙物**，「借過！」是核心機制而非干擾
- 題材空白：合作亂鬥類沒有人做過超商，華語圈共鳴天花板（「這就是我打過的工」）
- 瀏覽器開連結就進房：對 Steam/主機派對遊戲的不對稱優勢

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Fellowship** | 1 | 連線合作、喊單協調、救場、結算互相檢討的笑罵 |
| **Challenge** | 2 | 多工調度、尖峰波次、星級評分的精通曲線 |
| **Sensation** | 3 | 機台互動手感（撈、按、刷、倒）、亂流般的尖峰混亂演出 |
| **Fantasy** | 4 | 「當一晚超商店員」的角色扮演與制服 |
| **Expression** | 5 | 搞笑制服帽子、分工風格自由 |
| **Discovery** | 6 | 新店型／新服務／新怪客的解鎖驚喜 |
| **Narrative** | N/A | 無劇情主線（客人小劇場屬於風味） |
| **Submission** | N/A | 深夜空檔是節奏留白，不是主體驗 |

### Key Dynamics

- 玩家自然分工（櫃台手／補貨手／廚務手）且每班換位嘗試
- 出現團隊術語與喊單文化（「咖啡兩杯！」「關東煮誰顧！」）
- 失敗片段被截圖／剪片分享（實況與社群傳播的燃料）
- 老手帶新手：一人熟練即可帶整房朋友入坑（零安裝支撐此行為）

### Core Mechanics

1. **客人需求佇列**：每位客人是一台個性狀態機（需求、耐心值、特殊行為），程序化組合出波次
2. **機台互動組**：關東煮、微波、咖啡機、收銀刷條碼、貨架補貨——每台有獨立小手感與失敗方式
3. **兩段式節奏引擎**：深夜空檔（維護工作）與尖峰波次（客潮＋突發事件）交替調度
4. **星級評分**：顧客滿意度結算 1-3 星；永遠玩得完，只比誰漂亮
5. **連線房間**：房間碼進房、大廳選裝、斷線重連

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 分工自然湧現、路線與優先序自選 | Supporting |
| **Competence** | 多工調度越來越神、刷星精通 | Core |
| **Relatedness** | 喊單、救場、共同出包的故事 | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Socializers** — 主要：合作本身就是內容，故事來自彼此
- [x] **Achievers** — 次要：全店型三星、解鎖收集
- [ ] **Explorers** — 輕度：新怪客與新事件的驚喜
- [ ] **Killers/Competitors** — 不服務：無排名無對抗（反支柱）

### Flow State Design

- **Onboarding curve**：第一班只開收銀＋一種熟食，客人稀疏；機台隨班次逐台點亮
- **Difficulty scaling**：解鎖新服務＝新混亂源；店型改變客群組成；星級門檻拉高
- **Feedback clarity**：每單即時滿意度表情、班末結算逐項檢討（誰家咖啡砸了一目了然）
- **Recovery from failure**：無失敗重來——最差也是 1 星飛完，下一班立刻再開（教育不懲罰）

---

## Core Loop

### Moment-to-Moment (30 seconds)

叮咚（門鈴）→ 看客人需求 → 分頭執行（撈關東煮／微波按秒數／煮咖啡／貨架找貨）→
結帳（刷條碼節奏＋集點＋發票）→ 送客；空檔補貨、報廢過期品、換湯、煮茶葉蛋。
爽點：機台各自的小手感＋與隊友在窄走道的動線交錯（「借過——咖啡誰的！」）。

### Short-Term (5-15 minutes) — 一個夜班

21:00 交接開店 → 宵夜潮 → 深夜怪客時段 → 清晨到貨全員搬貨＋早餐潮 → 08:00 結算星級。
突發事件穿插：咖啡機故障、微波爐連環叫、下雨人潮湧入。「再一班」心理：結算檢討
直接變成「剛剛那波我們應該⋯」的重開動力。

### Session-Level (30-120 minutes)

朋友房連續值班，每班約 10 分鐘，自然停點＝店型通關或有人喊睡。
散場鉤子：「下次開山上店」「早餐潮到底怎麼三星」。

### Long-Term Progression

成長主體是技巧與知識（程序客群→無背版）。輕量解鎖：新服務（影印、代收、現烤地瓜⋯
店越高級＝越難）、新店型（商圈店／山上店／醫院店／夜店旁門市）、搞笑制服帽子。
全店型三星＝破關；之後無盡尖峰模式。

### Retention Hooks

- **Curiosity**：下一個店型的客群長怎樣、還有什麼怪客沒見過
- **Investment**：星級進度與解鎖收集
- **Social**：房間連結一貼朋友就進來；「上次那班」的共同記憶
- **Mastery**：三星門檻、無盡模式撐得久

---

## Game Pillars

### Pillar 1: 忙得有節奏

深夜的靜（維護、閒聊）與尖峰的爆（客潮、事件）是遊戲的呼吸，兩段式節奏不可破壞。

*Design test*：新機制必須明確屬於「靜」或「爆」其一；兩邊都不是就砍。

### Pillar 2: 台灣人秒懂

每個互動都來自真實的超商排隊經驗，共鳴即教學。

*Design test*：一個新內容若需要說明書才懂 → 換成大家都親身經歷過的真梗。

### Pillar 3: 隊友是活的動線

店面空間窄，合作的本體是喬動線；擁擠是設計出來的樂趣。

*Design test*：要加難度時，寧可加設備，不加坪數。

### Pillar 4: 開連結就開玩

瀏覽器＋房間碼，免安裝免帳號，上手零門檻。

*Design test*：任何讓新玩家進房超過 60 秒的功能 → 砍。

### Pillar 5: 沒有人在等

任何玩家狀態（等開局、掛機隊友、單人練習）都有事可做。

*Design test*：任何讓玩家純看戲超過 30 秒的機制 → 重做。

### Anti-Pillars (What This Game Is NOT)

- **NOT 寫實經營模擬**：不做進貨成本、損益表——這是派對不是 tycoon，會壓死節奏
- **NOT 真實品牌**：原創「好鄰居超商」；梗可以像，商標配色不能像（法律與上架風險）
- **NOT 數值變強 meta**：難度來自內容不來自 farm，保護派對公平與零門檻
- **NOT 單人優先**：永遠為 2-4 人設計；單人只是練習模式，不為它妥協合作設計
- **NOT 競技排名**：無天梯無對抗，星級只跟自己隊比

---

## Visual Identity Anchor

- **方向名**：**「日光燈下的積木超商」**
- **一句話視覺規則**：低多邊形原始幾何＋高飽和色塊，全店浸在超商標誌性的慘白日光燈裡，
  唯一的寫實元素是「光」。
- **支持原則**：
  1. **零美術素材**——一切用 primitive 幾何與程式化材質構成（延續開發者招牌，管線勞動最低）。
     檢驗：要加新物件時，先問「幾何＋顏色能不能表達」，不能才考慮貼圖。
  2. **燈光就是場景**——冷白店內 vs 窗外深夜藍黑的對比是畫面的主角；尖峰時燈光事件
     （閃爍、微波爐光、關東煮蒸氣）承擔演出。檢驗：氣氛不對時先調燈，不加模型。
  3. **可讀性優先於風格**——尖峰混亂中，客人需求與機台狀態必須一眼可讀（色彩編碼、
     頭頂圖示）。檢驗：美術與可讀性衝突時，可讀性贏。
- **色彩哲學**：店內冷白＋商品高飽和色塊（貨架本身就是調色盤）；窗外深夜藍；
  警示與需求用暖色（橘紅）跳出。

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Overcooked 2 | 合作亂鬥節奏、星級評分、事件關卡 | 第一人稱、連線原生、超商題材 | 驗證類型胃口（千萬套級） |
| PlateUp! | 解鎖新設備＝新難度的進度設計 | 不做 roguelike 失敗重來（星級制） | 驗證「擴店進度」的長線黏著 |
| R.E.P.O. / 畫畫躲貓貓 | 「開房拉朋友」的病毒傳播模型 | 用瀏覽器連結進一步降低門檻 | 使用者親身被吸引的傳播路徑 |
| 台灣超商文化 | 關東煮、集點、代收、大夜怪客 | ——（這就是本體） | 題材空白＋在地共鳴天花板 |

**Non-game inspirations**：台灣超商深夜眾生相（PTT/Dcard 超商店員文）、《俗女養成記》式
的日常喜劇節奏、便利商店廣告的日光燈美學。

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16-35，台灣／華語圈為核心 |
| **Gaming experience** | Casual 到 Mid-core（會開 Discord 開黑的程度） |
| **Time availability** | 晚上跟朋友連線 30-90 分鐘 |
| **Platform preference** | PC 瀏覽器為主；手機瀏覽器可加入但非首發重點 |
| **Current games they play** | Overcooked、Among Us、各種 party game、實況互動遊戲 |
| **What they're looking for** | 跟朋友「一起鬧」的低門檻新梗，不用人人買遊戲裝遊戲 |
| **What would turn them away** | 要註冊帳號、載入太久、單人沒朋友時完全沒事做 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | **Unity（使用者選定）**。關鍵理由：Unity Relay + Lobby 官方服務解決連線遊戲最大痛點（伺服器託管），Netcode for GameObjects 是成熟路徑。代價：開發者過去四款皆 Godot，引擎學習曲線是最大成本；WebGL 成品體積較大（30-50MB vs Godot 13MB） |
| **Key Technical Challenges** | (1) Unity WebGL＋NGO＋Relay 的 WebSocket 傳輸鏈路（WebGL 無 UDP）；(2) 窄空間多人碰撞／搬運的手感；(3) 斷線重連 |
| **Art Style** | 3D 低多邊形原始幾何＋程式化材質（見 Visual Identity Anchor） |
| **Art Pipeline Complexity** | Low——primitive/ProBuilder，零外部素材 |
| **Audio Needs** | Moderate：機台音效是手感核心（叮咚、微波叫、刷條碼嗶）；BGM 輕量 |
| **Networking** | Client-hosted + Unity Relay（免費額度）；房間碼＋Lobby；本類型容忍延遲（互動事件同步，非物理精準同步） |
| **Content Volume** | MVP：1 店型／5 機台／6 客人。完整：4 店型／10+ 服務／12+ 客人；通關約 3-5 小時＋無盡模式 |
| **Procedural Systems** | 客群波次組合程序生成（店型＝參數集）；店面本身手工佈局（窄空間動線需精調，支柱 3） |

---

## Risks and Open Questions

### Design Risks

- 「忙到爽」與「忙到煩」一線之隔——尖峰調度需大量實測（星級門檻、耐心值、波次密度）
- 沒朋友同時在線時的體驗谷底——單人練習模式與「貼連結就進房」是緩解，不是解答

### Technical Risks

- **新引擎**：Unity 全新起步，前 2-4 週產出會很慢，手感調校語彙要重建（最大風險）
- Unity WebGL 體積與手機瀏覽器相容性——「開連結就開玩」會被載入時間打折
- NGO + Relay 在 WebGL 的實際延遲與穩定性未經本人驗證——必須最先原型

### Market Risks

- 連線派對遊戲冷啟動難：沒有同時在線的朋友就沒有體驗——依賴實況主與社群傳播
- itch.io 免費發佈無收入模型；Steam 版才有商業可能，但那是後話

### Scope Risks

- 客人個性狀態機容易無限膨脹（「再加一種怪客」）——以反支柱與內容配額控制
- 店型 × 服務的組合爆炸——每店型只挑 2-3 個專屬元素

### Open Questions

- Unity WebGL + NGO + Relay 的端到端延遲實測值？→ **第一個技術原型直接驗證**（兩台裝置開瀏覽器互丟位置）
- 刷條碼結帳的手感做成什麼小遊戲最爽？→ 核心循環原型 A/B（節奏按鍵 vs 對準掃描）
- 2 人與 4 人的波次縮放公式？→ playtest 決定

---

## MVP Definition

**Core hypothesis**：「兩個朋友透過瀏覽器連線，在一間超商裡合作應付客潮，
能連玩 30 分鐘以上還想再開一班。」

**Required for MVP**:
1. 2 人連線（房間碼、Unity Relay）＋第一人稱移動與互動
2. 五種互動：關東煮、微波、咖啡機、收銀刷條碼、貨架補貨
3. 6 種客人狀態機＋兩段式波次調度（一班 8 分鐘）
4. 星級結算畫面（逐項檢討）

**Explicitly NOT in MVP**:
- 3-4 人（先證明 2 人好玩）
- 多店型、服務解鎖、制服裝飾
- 手機瀏覽器支援、**斷線重連打磨**（澄清 2026-09-05：指 30s slot 保留與原位恢復、
  重連演出、disconnect_log。**斷線的基本保障仍屬 MVP**——偵測、物品掉落、站台解鎖、
  留守者降載；否則 2 人房一斷就毀局，違反支柱「沒有人在等」。見
  `design/gdd/netcode-session.md` 驗收條件的層級欄）
- 音樂（只做機台音效——音效是手感，音樂是氣氛）

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 店、6 客人、5 機台 | 2 人連線＋核心循環＋星級 | 4-6 週（含 Unity 學習） |
| **Vertical Slice** | 商圈店完整（含事件） | 4 人、大廳打磨、音效全套 | +4 週 |
| **Alpha** | 4 店型粗胚、服務解鎖 | 全功能、斷線重連、單人練習 | +6-8 週 |
| **Full Vision** | 全內容＋無盡模式＋裝飾 | 打磨、手機瀏覽器、itch.io 上線 | 總計 4-8 個月 |

---

## Next Steps

- [ ] `/setup-engine` — 專案引擎改配 Unity（版本鎖定＋填補引擎參考文件；現有 CLAUDE.md 釘的是 Godot 4.6，需更新）
- [ ] `/art-bible` — 依 Visual Identity Anchor 展開視覺規格（在任何 GDD 之前）
- [ ] `/design-review design/gdd/game-concept-night-shift.md` — 概念完整性驗證
- [ ] `/map-systems` — 拆解系統、排依賴與設計順序
- [ ] `/design-system [system]` — 逐系統 GDD
- [ ] `/create-architecture` — 技術架構藍圖（連線架構是重頭戲）
- [ ] `/architecture-decision` ×N — 記錄關鍵決策（引擎轉換、NGO+Relay、WebGL 限制）
- [ ] `/gate-check` — 進入 production 前的階段關卡
- [ ] `/prototype netcode-relay` — **最優先原型：驗證 Unity WebGL 連線鏈路**
- [ ] `/playtest-report` — 原型驗證核心假設
- [ ] `/sprint-plan new` — 排第一個 sprint
