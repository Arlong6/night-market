# 機台互動組 (Machine Interaction)

> **Status**: In Review r1（2026-09-29 `/design-review` full 九位專家＋creative-director：**NEEDS REVISION**，同日依 arlong 四項裁決修訂——見文末「r1 修訂紀錄」；CD 指示：修完不再開散文輪，直接寫純 C# 站台狀態機跑 T0，AC 自相矛盾會自己亮紅燈）
> **System**: #5（Gameplay / Core / MVP）
> **Author**: arlong + design-system skill
> **Last Updated**: 2026-09-29
> **Implements Pillar**: 支柱 1「忙得有節奏」（主：機台是「爆」的內容本體與「靜」的維護工作）、支柱 3「隊友是活的動線」（設備是難度槓桿）、支柱 2「台灣人秒懂」（每個手勢都是真實超商動作）
> **Concept**: `design/gdd/game-concept-night-shift.md`
> **Systems Index**: `design/gdd/systems-index.md`
> **Review mode**: solo（CD-GDD-ALIGN 依規格跳過）
>
> **上游 ADR**：`docs/architecture/adr-0002-horizontal-only-interaction-validation.md`——本系統的驗證述詞、
> `station_reach_m`／`station_leave_m` 的關係式、`RejectReason`（六個拒絕值＋`Ok`，enum 七成員；本 GDD E 節追加 `NothingToTake` 成八成員，已登記 levy）、離開即中斷三層（E0.3 追加第四觸發源）皆已由它定案；
> **本 GDD 擁有的是那些常數的值與每台機台的行為，不重寫驗證模型。**
> ADR-0001（Core 分層；互動鍵住獨立 `Interaction` map，AC1③ 不需豁免——C17）、ADR-0003（`PassThrough` 對站台前玩家的推離）亦約束本系統。
>
> **鎖定的上游決定**：MVP 5 機台 ＝ 4 個產出家族（`Shelf`／`Oden`／`Microwave`／`CoffeeMachine`）＋ 1 個交付動作（收銀）（商品資料庫規則 3b）；
> 本系統擁有加工計時、燒焦／溢出閾值、庫存與過期、`ProductInstance` 執行期實例化（規則 4）；
> 不得鎖移動、不得有需蹲跳的互動點、Host 只驗水平、離開半徑 > 0.6 m（第一人稱控制器四條硬拒絕）。

## Overview

機台互動組決定**玩家在店裡能對什麼東西做什麼、做了之後世界怎麼變**。它是客人需求（#7）與商品（#6）之間唯一的兌現通道：客人要的是一個商品 ID，本系統是把那個 ID 從「菜單上的一項」變成「玩家手上一份 `ProductInstance`」的地方，也是把手上那份東西刷掉、換成一張滿意度的地方。

**MVP 有五台，而它們不是五個同樣的東西**（商品資料庫規則 3b）：四個**產出家族**——貨架（`Shelf`）、關東煮（`Oden`）、微波（`Microwave`）、咖啡機（`CoffeeMachine`）——各自產出一份帶家族身份的商品；加上一個**交付動作**——收銀，它不產出任何東西，只消耗一份既有商品並比對訂單。每一台有自己的小手感與自己的失敗方式（撈、按、刷、倒；燒焦、溢出、刷錯、缺貨），這是概念文件把 Sensation 排進 MDA 前三的原因，也是本系統對外最顯眼的那一面。

在玩家看不到的那一側，每台機台是一台 **Host 權威的狀態機**，帶一組 `IsClaimed`＋`ClaimedBy`＋`ClaimGeneration`（netcode Core Rule #4）：誰在用、用到哪一步、還剩幾份、什麼時候壞掉。玩家按 E 是一則 RPC 請求，Host 驗證後廣播——**驗證只驗水平距離與水平朝向，不驗瞄準**，因為 Host 手上沒有俯仰（第一人稱控制器 C6）；驗證模型、容差關係式與六種拒絕原因已由 **ADR-0002** 定案，本 GDD 擁有的是那些常數的值與每台的行為，不重寫模型。站定需求以「離開站台即中斷」實作，**永不鎖住玩家移動**（第一人稱控制器四條硬拒絕之一）。

每台機台有兩面：**「爆」的服務動作**（尖峰時客人要什麼就在這裡做）與**「靜」的維護動作**（空檔補貨、換湯、煮茶葉蛋、報廢過期品）。兩面都歸本系統——商品資料庫規則 4 把庫存與過期判給了這裡，拆開會製造雙擁有者——**但 MVP 只實作 `Shelf` 的補貨**（2026-09-28 arlong 裁決）：它是庫存機制的另一半，不做就沒有庫存；換湯、茶葉蛋、報廢留 Vertical Slice。

**沒有它，遊戲失去的是支柱 3 的難度槓桿本身。** 概念文件的 design test 寫「要加難度時，寧可加設備，不加坪數」——設備就是這個系統。每多一台機台，就多一條動線、多一個排隊點、多一種失敗。它也是支柱 1 兩段式節奏的內容本體：尖峰的「爆」是機台同時叫，空檔的「靜」是機台等人來維護。

| 不歸這裡 | 歸誰 |
|---|---|
| SKU 是什麼、屬哪個家族、兩個東西算不算相符 | #6 商品資料庫（規則 4） |
| 客人要什麼、什麼時候要 | #7 客人系統 |
| 拿在手上、走動、交給另一個人 | #4 攜帶與交付（本系統只在站台**產出**與**收走**） |
| 星級怎麼算、耐心怎麼扣 | #15 評分邏輯 |
| 需求 icon、機台狀態的 HUD 顯示 | #11 HUD（本系統提供狀態查詢） |
| 第一班只開收銀＋一種熟食 | #17 教學／第一班（逐台點亮的順序，不是機台的射程；2026-09-28 裁決：本 GDD 設計全部五台） |

**本 GDD 對外的硬交付**：`station_reach_m`、`station_leave_m` 的值（ADR-0002 只給了關係式）；`Shelf` 家族的可得性查詢（商品資料庫的 levy，且量詞推廣到三個產生器家族：**站台一次只服務一人**）；`ProductInstance` 的執行期實例化，`is_spoiled`／`network_index` 為 server-write 且必須在 `NetworkObject.Spawn()` 之前寫入。

## Player Fantasy

這是一個**兩層**的幻想，而下層是上層的載體。

### 上層：手會記得

**錨點時刻**：

> 尖峰。你在收銀台刷第三位客人的東西——嗶、嗶、嗶，同一個拍子，你的手已經不用看了。你的眼睛在別的地方：隊伍還有兩個人，微波爐的數字剩 4。背後磨豆機轟地響起，你沒回頭——那是他剛按了咖啡。嗶，最後一件。叮。你轉身把便當拿出來、塞進袋子，客人的手機都還沒收好。
> **整段你只看了機台一眼。其他全是用聽的。**

五台機台共享的那一個感受是**俐落**：一個動作、一聲回應，就做完了。它的反面是「手忙腳亂」——而那正是鬧劇的來源，不是懲罰。這是核心幻想「亂中維持專業」縮小到手的尺度。**玩家的成長方向不是「更準」，是「不用看」。**

本作已經讓移動「沒有對錯」（第一人稱控制器 AC 節）、讓商品「不需要學」（商品資料庫的准入門檻），所以**瞬間尺度的 Competence 只剩機台這一個出口**。它必須由手勢本身承載，但**難度不得跑進手勢裡**——手勢有技巧門檻等於把 Sensation 換成 Challenge，並違反支柱 4。

### 下層：耳朵是主要頻道

第一人稱唯一看不到的方向，正好是熱食機台所在的方向——真實台灣超商的關東煮、咖啡機、微波爐就在收銀台後面。所以站在收銀台的人，靠的是聲音：磨豆聲停了換成滴水聲，是咖啡好了；叮一聲又一聲，是兩個便當先後到；湯勺碰鍋緣，是隊友在撈。**隊友的狀態回報就是他手上那台機器的聲音**——本作 MVP 沒有音樂（概念文件），機台聲就是整間店的配樂。

下層一壞，手就得靠眼睛，上層在尖峰時會當場崩掉。

### 判準（可證偽）

| # | 判準 | 誰擁有 |
|---|---|---|
| **1** | **出包是分心，不是手殘。** 機台可以要你看一眼，不能要你一直盯著。證偽：遙測記下每次燒焦／溢出／刷錯發生時，機台是否在玩家朝向範圍內——看著機台時失敗率應接近 0；沒看時的失敗率隨班次下降。**若看著也常出包，框架錯了** | **本表**（Core Rules 的手勢設計） |
| **2** | **無技巧門檻。** 新玩家看著機台、無時間壓力，每台第一班成功率 ≥ 9/10（暫定）。哪一台做不到，就是難度跑進了手勢裡 | **本表** |
| **3** | **雙頻道。** 每個需要玩家反應的機台狀態，都要**聽得出來、也看一眼就知道**——聽障玩家與吵雜環境走「看一眼」那條路。五台的聲音要閉著眼也分得出來 | 本表 ＋ **#14**（機台音效已在 MVP 射程）＋ 美術聖經 §3.2「曲面＝活著、正在運作」（轉盤、出水口、蒸氣是現成的視覺線索） |
| **4** | **撲空必須讀作「兩個人都伸手了」**，不得讀作「我明明先到的」，也不得讀作「遊戲吃我輸入」。兩件事各自壓在一個技術事實上：①在輸家的畫面上，贏家的到站永遠比 claim 狀態晚至少一個 tick 抵達（≥ 100 ms）——**演出層必須把撲空動畫對齊贏家在本機畫面上的到達時間，不對齊封包**，原則是「搶走我的，永遠是我螢幕上看到的那隻手」（第一人稱控制器 C8 在機台上的對應）②**撲空必須對稱**：現行規格下房主幾乎不可能撲空，2 人房裡所有撲空落在同一個人身上 | ①**本表**（Visual/Audio 節兌現）②**netcode**（已登記前向義務表，2026-09-28） |
| **5** | **站在機台前不等於釘在原地。** 持有 claim 的人仍可被擠、仍可轉頭看別台、走開就是把機台讓給下一個人。**轉頭不得中斷互動**——否則判準 1 的「眼睛留給店裡其他地方」在機制上不成立 | **本表**（Core Rules：持有期間只驗身份與位置綁定，不重驗朝向；離開與否交給離開半徑） |
| **6** | **出包要像鬧劇，不能像懲罰。** 燒焦、溢出、刷錯的演出是「啊！」，不是扣分畫面（美術聖經 §2「喜劇式的『啊！』」） | 本表 ＋ #11 ＋ #14 |

**若只能守住兩條，守 1（分心不是手殘）與 4（撲空讀作兩個人都伸手）。** 前者是這個系統存在的理由，後者是它與 Fellowship 唯一的直接接點。

### 五台之間，哪些差異屬於幻想層

**寫進來的**：

- **產出 vs 交付**：四台產出，一台交付。收銀是唯一有客人站在對面看你的機台——「維持專業」在這裡有觀眾。
- **手上的失敗 vs 供給的失敗**：燒焦、溢出、刷錯發生在「爆」；缺貨是在「靜」埋下、在「爆」爆發。**補貨→缺貨是 MVP 裡，支柱 1 的「靜→爆」在機台上唯一一條因果線。** 這也是補貨留在 MVP 的理由。
- **補貨是站著做的**——第一人稱控制器的上層錨點「前面那個灰藍色的背影正彎腰補貨」建立在這個動作上。
- **關東煮是永遠不出包的那一台**（2026-09-28 arlong 裁決）。它是美術聖經的英雄物件（湯色＝熱、家、休息，§4.1），是商品資料庫說的「一整班發生最多次的事」；它的失敗只從供給面來（撈完與湯底皆 VS，隨換湯一起；MVP 無界）。**它是新手與慌了的人的安全牌**，「每台有獨立失敗方式」那句在它身上是刻意的例外。

**不寫進來的**：哪一台對應時機、計數、節奏或時長，以及任何判定窗、閾值、失敗的具體觸發。理由是上游三處說法不一致（概念文件把收銀留給原型做「節奏按鍵 vs 對準掃描」的 A/B；商品資料庫寫「微波是計時持續按、咖啡機是沖煮等待」），**幻想節寫下任何一台的手勢類型，就是替原型先給了答案。** 那些歸 Core Rules 與原型。

### 設計測試（可證偽）

> **第一次 playtest：看著機台時的失敗率接近 0。三班之內，玩家持有 claim 時鏡頭離開機台的時間比例上升，而失敗率不上升。**
>
> 若看著也常出包，或三班後玩家仍然全程盯著機台——**不是調參數的問題，是要換框架**（候選：「借過，我來」把撲空與接手當笑點，但它建立在現行規格最不公平的互動上，須先修對稱性）。

### 做壞了會怎樣

玩家不會說「這台好難」。他會想說「你幫我顧一下微波」——**卻沒有語音可以說**（MVP 不做語音，商品資料庫 OQ-P13 已裁決）。機台搶走了眼睛，尖峰時兩個人各自低頭盯著自己那台；**店裡最吵的時候，隊伍反而最安靜。** 那是 Fellowship 從機台這一側被關掉。

### 本節不負責

- **各台手勢的類型與判定**：歸 Core Rules 與原型（收銀的 A/B 尤其）。
- **撲空的對稱性怎麼做到**：歸 netcode（已登記）。本節只立下「必須對稱」。
- **聲音本身**：歸 #14。本節只要求「五台閉眼可分、每個需反應的狀態雙頻道」。
- **claim 的 5 秒保險絲是否續期**：歸 netcode（已登記）。長單與補貨會踩到它，但那是機制不是幻想。
- **關東煮的失敗從供給面來**：「撈完」與「換湯」皆 VS（C2、C11：MVP 無界）。
- **接手的體驗**（走開後別人接著做）：歸 Core Rules 的狀態機；本節只承諾「走開就是讓出」。

## Detailed Design

### Core Rules

**寫作層級**：本節只寫「系統做什麼」。承載與封裝（`StationStatus` 的 struct 形狀、RPC 簽章）已由 ADR-0002 與本節「States」定形；實作模式標 → ADR。

#### C1 — Host 驗證有兩種，理由完全不同，不得混用

- **claim**（搶一個排他資源）→ 防作弊 → ADR-0002「信但要綁」：自報姿態、複製品綁住、精確驗 reach 與 ±60°。**只在到站那一下。**
- **手勢結果**（`is_spoiled`、`progress`、產出）→ **單一真相**，不是防作弊：站台被 claim 之後沒有第二個人在跟你搶同一個動作的結果，本機說謊只會讓自己的關東煮不燒焦。Host 需要的是「事件發生的時刻」（Host 自己收到 RPC 的時刻），不是本機自報的時間戳，**不綁公差**。

若把「信但要綁」整套搬到手勢上（每一下都綁窗口），是不必要的重量級；若反過來讓本機自報 `is_spoiled`，兩端會看到不同的結果。

#### C2 — 五台的手勢原型

| 機台 | 原型 | 為什麼 | 失敗從哪來（必須是分心，不是手殘） | 靜／爆 |
|---|---|---|---|---|
| 貨架 `Shelf` | **單鍵** | 判準 2 最保守的示範：現實拿貨零技巧，鎖住「看著必成功」的下限 | 只有**缺貨**（供給面），與按鍵無關 | 爆＝拿取；靜＝補貨（MVP） |
| 關東煮 `Oden` | **單鍵** | 永遠不出包的那一台（已裁決）；新手與慌了的人的安全牌 | 無手勢失敗；**MVP 無界（C11）**——「撈完」隨換湯留 VS | 爆＝撈；靜＝換湯（VS） |
| 微波 `Microwave` | **兩事件**：啟動、回收 | 「時長」拆成兩次點擊而非按住——按住會把人釘在站台，撞支柱 5 與判準 5 | **燒焦**＝做好後太久沒回來收，是「忘記」不是「鬆手時機不對」 | 爆＝啟動＋回收 |
| 咖啡機 `CoffeeMachine` | **兩事件**：啟動、回收（同微波骨架） | 與微波共用骨架，五台要學的操作種類壓到最少 | **溢出**＝沖好後太久沒回來收 | 爆＝啟動＋回收 |
| 收銀 | **待原型 A/B**（節奏按鍵 vs 對準掃描） | 唯一有客人在對面看的站台；手感屬上游分歧，本節只給邊界 | **刷錯**＝選錯或漏看訂單，**不論哪個原型都不得由手速或精準度觸發** | 爆＝結帳 |

**收銀兩原型皆須滿足**：①不趕時間、看著螢幕時錯誤率貼近零（判準 2）②失敗只由選錯／漏看觸發（判準 1）③**不得疊加「限 0.X 秒內完成」的窗口**——排隊客人本身已是分心來源，機制不該再加一層手部門檻。

🔬 貨架／關東煮的單鍵是否因太瞬間而缺乏 Sensation 回饋，靠音效／動畫補（#14／美術），本節不負責解。

#### C3 — 兩事件原型：啟動後倒數由 Host 自走，人可以走（2026-09-28 arlong 裁決 C）

啟動 RPC 送出後，Host 用**自己收到 RPC 的時刻**起算 `WorkStartTick`，倒數在 Host 自走，**與持有者在不在場無關**。做好進 `Ready`，開始寬限計時；寬限內任何人回收即成功，逾時進 `Spoiled`（燒焦／溢出）。

這條讓錨點場景「微波數字剩 4」「磨豆機響你沒回頭」在機制上成立；讓判準 1 長成最純形式（失敗只測「多久沒回來」，不含任何手速判定）；讓「等待」不被焊回遊戲（支柱 5）。

**連帶**：`Working`／`Ready` 與 `IsClaimed = false` 是**合法組合**——站台在跑，沒人 claim。walk-through 裡「產出」那一刻是玩家其實已可離場的隱形轉折點。

#### C4 — 失敗的來源表

| 失敗 | 哪台 | 觸發 | 不是什麼 |
|---|---|---|---|
| 燒焦 | 微波 | `Ready` 後 `microwave_burn_grace_sec` 內無人回收 | 不是按太久、不是秒數選錯 |
| 溢出 | 咖啡機 | `Ready` 後 `coffee_overflow_grace_sec` 內無人回收 | 不是倒太久 |
| 刷錯 | 收銀 | `Matches()` 回 `WrongFamily`／`WrongSku`（選錯商品）；漏刷 | 不是手速、不是對不準 |
| 缺貨 | 貨架 | 目標 SKU 全域 `stock_count == 0` | 不是手勢 |
| （無） | 關東煮 | — | 刻意的例外 |

失敗的演出一律「啊！」（判準 6）；`Spoiled` 產出**仍然生成**（`is_spoiled = true`），要有人收走丟掉——鬧劇要有實體。

#### C5 — 每個手勢一則 RPC、只在承諾那一刻送、fire-and-forget

本機做完整段樂觀表現（≤ `optimistic_anim_max_ms` = 100 ms，含任何蓄力視覺，零網路流量），只在**承諾的那一刻**（啟動、回收、刷、拿、補）送一則 RPC。**送出端不等 Host 回應才播下一個本機動作**——約束⑧的 300 ms 管的是「Host 真相多快收斂」，不是本機手感；若寫成「等 ack 才播下一步」，300 ms 會直接焊進手感。

設一個防連發的最小間隔 `action_min_interval_ms`（新常數，Section D）。

#### C6 — 持有期間只驗身份與位置綁定，不重驗朝向

ADR-0002 述詞⑤⑥只在 claim 時跑；持有者後續的每一下動作只跑②③④（身份、世代、位置綁定）。**轉頭看微波爐不得是一次 `NotFacing`**——否則判準 5 在機制上不成立。離開與否交給 ADR-0002 Decision 7 的三層中斷。（→ ADR-0002 須加註）

#### C7 — 任何通過驗證的動作就是續租訊號（provisional，待 netcode）

claim 的 5 秒保險絲現行從 lock 建立起算、無續期（已登記 netcode）。本 GDD 假設修法為「從持有者最後一次有效操作起算」，並定義：**Host 每接受一次 `InteractRpc`／`TakeOutputRpc`（C20），即重設倒數**。續期不需要新機制，是動作 RPC 的自然副產物——但必須寫下來，不會自動發生。保險絲對 `Ready` 階段同樣生效。

**保險絲到期只釋放 claim，不碰加工（r1，C10）**：`Working` 期間持有者沒有任何動作可送（再按 E 是 no-op，E1），5 s 必到期——若到期等於失敗，守在微波前看數字的人反而被懲罰（Player Fantasy 錨點「微波數字剩 4」、判準 5「站在機台前不等於釘在原地」）。到期後 `IsClaimed → false`、`ClaimGeneration + 1`，倒數照樣自走（C3）、成品任何人可收（C9）。

#### C8 — 一次一人；一人一台

- 站台一次只服務一人（商品資料庫 levy ①的量詞推廣到四個產出家族與收銀）。
- **不得同時持有兩台 claim**：一人多站等於用效率吃掉隊友的動線分工，抵銷支柱 3。**落地方式（2026-09-29 裁決，Edge Cases E0.3）：對另一台送 claim 即視為離開前一台——ADR-0002 三層中斷之外的第四個觸發源，不需要新的拒絕原因。**
- **不得跨越他人 claim 撈取或代為收尾——限 `Ready` 之前的階段**（`Claimed`／`Working`／`Restocking`／`Scanning`）：排他性一旦模糊，判準 4 會被讀成「他搶我的」。`Ready`／`Spoiled` 的收走依 C9 不看 claim，那時站台已不屬於任何人（r1：原文與 C9 字面互斥，已限定）。
- 補貨與拿貨共用同一個 claim（🔬 若 playtest 證實尖峰時補貨擋住拿貨是瓶頸，再回頭裁決拆分——那會修改「一次一人」）。

#### C9 — Ready 產出任何隊友都能拿（2026-09-28 arlong 裁決）

`TakeOutputRpc` 不驗 `ClaimedBy`。理由：本人被卡在別處時 Ready 產出不得卡死站台、逼隊友乾等（支柱 5）；「叮一聲又一聲」是廣播給全店。🔬 待 playtest：會不會疊加「你搶我單」的社交摩擦。

#### C10 — 強制釋放一律只釋放 claim；`Failed` 只剩班次結束一個觸發源（r1，2026-09-29 arlong 裁決）

netcode AC11 寫斷線時「進行中互動歸零」（自 Host 判定時刻起）；本 GDD 定義**「歸零」＝清掉 claim**，不是作廢加工：

- 持有者在 `Working`／`Ready`／`Spoiled` 被強制釋放（**保險絲到期、斷線**）→ `IsClaimed → false`、`ClaimGeneration + 1`，**Phase 不變**：倒數照 C3 自走到 `Ready`，成品任何人可收（C9）。不存在「幽靈 `Working`」——那是一台正在跑的微波，不是卡住的站台；作廢它反而銷毀了隊友想接手的那份。
- 持有者在 `Restocking` 被強制釋放 → `Restocking → Idle`，不加庫存（補貨沒有產出可保留，E1）。
- 仍連線只是走開 → 與上同：只釋放 claim（三層中斷，ADR-0002 Decision 7）。
- **`Failed` 的唯一觸發源是 `shift_end_ts`**（E1）：班次結束時 `Working → Failed`，不產出。

r0 原文把「保險絲」與「斷線」並列判 `Failed`，與 C3「與在不在場無關」自相矛盾（AC3 與舊 AC10① 不可能同時通過），且守在微波前的人 5 s 內必被判失敗——正好倒轉判準 1。

**斷線的真實延遲**（network-programmer，r1）：Interactions 表的「強制釋放 ≤ 2 s」是 **Host 判定後**的清理預算；判定本身依 netcode #20 心跳（8 s），退化到 NGO 偵測時瀏覽器關分頁實測 15–19 s（P-13）、kill -9 實測 87 s（P-14）。常態約 10 s、最壞 87 s；在那之前站台由 5 s 保險絲釋放——**保險絲才是斷線真正走的路徑**，這也是它必須「只放 claim」的另一個理由。

**Shelf 預扣歸還**：F7 下拿取在同一次處理內完成（`Working` 0 tick），預扣→`Failed` 的路徑不可達；本條保留為防遺忘：若 F7 日後 > 0，`shift_end_ts` 造成的 `Working → Failed` 必須歸還預扣。

#### C11 — Shelf 是計數，不是實例

- 貨架上的東西是 `stock_count[sku]`（整數），**拿起來（`Working → Ready`）才實例化**。與「不得以 `NetworkList` 承載 `ProductInstance`」天生相容；滿架排面是純美術，與計數無 1:1 對應。
- **庫存全域跨站台共享、claim 分站台**：一個倉庫、多個陳列點；#7 的可得性查詢不必知道哪一格。
- **取貨開始即預扣**（`Claimed → Working` 那一刻 `−1`）：兩人幾乎同時要最後一個時，Host 單執行緒依序處理，後者落到 `OutOfStock`，不會兩人都以為拿到。
- **補貨完成才加，且補的是整架（r1，E0.2）**：`Restocking` 計時完成那一 tick，本架**所有** `stock_count[sku] < stock_max` 的 SKU 同時設為 `stock_max`（不再是 `+=` 增量，天然冪等）；庫存憑空預先出現沒有物理直覺，Host 到時才寫。
- **補貨手勢：點按＝拿，按住＝補整架（2026-09-29 r1 arlong 裁決，E0.2）**：對貨架任一槽——`stock_count[sku] > 0` 時按下（`started`）即在 0 ms 送拿取（E0.4 一則 RPC）；**持續按住 ≥ `optimistic_anim_max_ms`（100 ms，F8）且本架任一 SKU 未滿** → 送第二則 `InteractRpc(action = Restock)`（claim ＋ 啟動 `Restocking`，C20），Host 自走 `restock_duration_sec`，放開＝`InterruptRpc`，中途放開不保留進度。`== 0` 的槽按下即直接啟動補貨（無拿取可送）。有貨槽是「先拿後補」：真實店員從架上取下一件、接著蹲下補貨；手滿時拿取 no-op（C15 不送 RPC）、只補貨。全架皆滿時按住無事。r0 的「只有 0 的槽能補」讓部分消耗的架子在靜窗無法維護，「靜→爆」因果線只在尖峰剛好見底時成立（粗估約 37% 的尖峰結束時剩 1–2 件），且誘發「拿光逼 0 再補」的退化招——r1 改此。
- **可得性查詢**（兌現商品資料庫 levy ①）：`int GetAvailableStock(byte networkIndex)`，Host-only 純函式，回傳含預扣後的即時值；#7 只需 `> 0`。**有人正在拿 ＝ 不可得。** 只覆蓋 `Shelf`——另外三個產生器家族「站過去等夠久永遠拿得到」，不需要查詢；levy 說的「量詞推廣」推廣的是**一次一人**這條排他性（C8），不是查詢射程。
- `stock_count == 0` 時 claim **仍會成功**（ADR-0002 述詞不查庫存），站台在同一 tick 自報無事可做並自我釋放——**這不是撲空**：回 `NothingToTake`（E 節新增的值），演出是空手不是「被搶」。`OutOfStock` 是**每 SKU 的全域條件**（`stock_count[sku] == 0`），不是站台 Phase（2026-09-29，E0.1）。

#### C12 — 收銀是交付動作

- Host **不信 RPC 參數裡的商品身份**：自己從 ownership（Core Rule #6，Host 權威）查「這個 client 現在拿著哪一個 `ProductInstance`」。
- 呼叫 `Matches()`／`AllocateSlot()`（#6 純函式）：命中 → 消耗該實例（ownership 移出玩家）、槽位標滿、最後一槽補滿時向 #7／#15 發「訂單完成」；不中 → **實例留在手上不消耗**，退回／掉地／計失誤歸 #4／#15；播撲空等級回饋，**與 claim 撲空共用同一視聽語彙**（本質都是「你伸手了，但沒拿到」）。
- 空手按刷 → no-op，**連 RPC 都不送**。
- 訂單來自 **#7**（`ICheckoutCustomerQuery`，Host-only 讀 #7 的 NetworkVariable 現值——provisional，#7 未設計）；#4 只搬東西，不持有需求。
- **不得做 SKU 選單**（商品資料庫 levy ④）：站台只回答「能不能生產這張訂單」。

#### C13 — `ProductInstance` 的生命週期

- **只在 `Working → Ready`／`Spoiled` 那一刻、以及 `Ready → Spoiled` 那一刻（despawn Fresh、spawn 一份 Spoiled，Edge Cases E1）由 Host 建立**——`Working` 期間根本沒有實例，只有 Host 的計時值。`TakeOutputRpc` 以站台為目標、不帶實例 id。
- `is_spoiled`／`network_index` 在 `Spawn()` **之前**寫入（既定裁決；那一刻已知道是不是燒焦）。
- spawn 時 **Host 持有**；`TakeOutputRpc` 通過後 `ChangeOwnership(requester)` 並**回讀 `OwnerClientId` 確認**（6a）；6b 的 6-tick 冷卻在這第一腿自動滿足，**#4 須知道該物件的冷卻起點是這次 transfer，不是 spawn**。
- **不掛 `NetworkTransform`**：`Ready` 時本機掛靠站台出貨位 socket，拿起後掛靠 owner 的手部 socket（Core Rule #7 附著點原則），整個生命週期零位置同步。各 client 靠 `StationStatus.PendingProductNetId`（C20）找到實例、靠 `OwnerClientId` 決定掛誰的手。
- **`AutoObjectParentSync = false` 是契約（r1）**：NGO 2.13.2 預設 `true`（`NetworkObject.cs:1398`），`OnTransformParentChanged()` 會把非 authority 端、以及掛到非 `NetworkObject` 父物件下的重設父物件**強制還原並 log**（`:2599-2627`）——照 r0 字面實作必然失敗。`ProductInstance` prefab 顯式關閉；只用 `Transform.SetParent()`，禁 `NetworkObject.TrySetParent()`。比照 ADR-0001 對 `CharacterController` 三旗標的手法列為 T1 斷言（→ ADR-0004）。
- **掛靠必須容忍到達序（r1）**：`PendingProductNetId` 走 NetworkVariable（10 Hz 批次），實例本身走 Spawn 訊息，兩條路徑到達序無保證（ADR-0002 Decision 8 同一風險家族）。client 讀到指向尚未 spawn 的 id 時不視為錯誤，下一次 Spawn 事件重試掛靠；反向（先 spawn 後讀到 id）亦然。

#### C14 — 家族參數啟動時寫一次，不可追加

加工目標 SKU 在 `Claimed → Working` 那一刻寫進 `StationStatus.Sku`（r1：取代 r0 的 `FamilyParam`——E0.1 之後 SKU 由槽決定、F3 之後時長由家族決定，「微波秒數、咖啡杯型」已無合法來源），持有期間**不得中途改**——「啟動→自走→回收」的骨架建立在目標鎖定上，中途改單製造的是記憶負擔不是分心。

#### C15 — 瞄準：每幀一次 raycast，HUD 與送出共用同一結果

- 起點攝影機（`camera_eye_height_m`），方向取攝影機 forward（同時吃 yaw 與 pitch——正是它必須留在本機的原因）。
- **產出站台的可互動體以 SKU 槽為單位（2026-09-29 裁決，Edge Cases E0.1）**：射線回傳 `(stationId, sku)`，動作 RPC 帶 `sku`，Host 只驗「sku ∈ `GetByMachineFamily(station.family)`」，不驗瞄準。**述詞⑤⑥的錨點＝被瞄準的槽的錨點，不是站台中心（r1）**：寬貨架的邊緣槽對站台中心錨點可能超過 ±60°（站 0.4 m、偏心 > 0.69 m 即 `NotFacing`）而提示明明亮著；Host 由 `sku` 查槽錨點，ADR-0002 的述詞不動、只換錨點輸入（⏳ levy ADR-0002 加註）。
- 射線長 `interact_ray_length_m ≥ station_reach_m + r_c + margin`（新常數）：射線只選台與亮提示，不驗證；長度不小於 Host 會接受的最大距離，就不會出現「Host 覺得你在範圍內但提示沒亮」——**前提是槽高在 F6 的高度帶內**（r1：眼高 1.60、射線 1.4 m 時，槽高 < 0.73 m 的槽在 1.1 m 處斜線超過射線長，且同一射線也決定「送給哪台」，低槽整個叫不動；高度帶為版面約束，⏳ levy #11／關卡佈局）。
- **每幀只查一次**，`(stationId, sku)?` 同時餵 HUD 與「按 E 送給哪台」——兩條獨立查詢會在同一幀分裂（第一人稱控制器 C16 的「腳在跑但身體沒動」同一課）。
- 站台專用 interactable layer；`Physics.Raycast` 明寫 `QueryTriggerInteraction.Collide`（槽 collider 若為 Trigger，預設多載受 `Physics.queriesHitTriggers` 影響會靜默漏檢，r1）。🔬 隊友的 `CharacterController` 會不會擋射線，6.3 場景實測。
- 若日後改寬成 SphereCast，tie-break：距離最近者勝，次選視線夾角最小者。
- **提示亮滅＝本機以自報姿態跑述詞⑤⑥（r1）**：⑤⑥的輸入本來就是 client 自報的 `(x, z, yaw)`，本機能算出與 Host 完全相同的結果，所以非持有者的提示直接照⑤⑥亮滅，**不套 1.1／1.3 m 遲滯**（遲滯是持有者的離開語意，E3）——否則被擠到 1.2 m 的非持有者提示仍亮、按下必 `OutOfReach`。
- **每次按 E 都要有反饋**：本機提示與 Host 判準仍是兩套時刻（自報姿態與複製品綁定有 `tol_lag`）；不一致一律收斂成撲空動畫，不得靜默無事發生。

#### C16 — 分頁隱藏由轉接層主動中斷手勢，不依賴輸入系統的釋放回呼

第一人稱控制器 C14 已修過一次同一個坑（失焦時釋放事件不一定送）。互動的任何進行中手勢（收銀掃描、補貨動作）在 `visibilitychange` 時由轉接層**直接呼叫 Core 的手勢中斷**，不接 Input System 的 `canceled`。兩事件原型（微波／咖啡）不受影響——倒數在 Host。

#### C17 — 互動鍵住獨立的 `Interaction` action map（2026-09-28 arlong 裁決）

`Interaction: {Interact}`。第一人稱控制器 AC1③ 的斷言 `{Move2D, Look2D}` **完全不動**；本系統擁有一條同形的反射測試「`Interaction` map 恰為 `{Interact}`」。日後 #4 加動作，加在它自己的 map，不得動這兩條。按住式手勢（若收銀 A/B 選到）不用 Input System 的 Hold interaction 計時——只取 `started`／`canceled` 兩個邊界，時長由 Core 自己的 `dt` 累加（與 `MoveSolver` 同一哲學）。

#### C18 — 對外狀態變更邊緣觸發；站台是 Host 動態 spawn 的 NetworkPrefab

站台狀態只在轉移時寫 `NetworkVariable`（`AreEqual` 後才 dirty，構造上邊緣觸發）；`progress` **不送 float**，送 `WorkStartTick` 由各端自算（仿 `shift_end_ts`）。五台機台必須是**開班時由 Host 動態 spawn**，不得 scene-placed（netcode `:827-828`）——**前提是本專案關閉 `NetworkSceneManager`**（單一場景設計），不是 NGO 通則；在此前提下 in-scene placed 物件的 NetworkVariable 不會同步給中途加入者（MVP 依 Core Rule #9／#10 確有中途加入）。`StockRegistry`（C20）同理。

#### C19 — `Faulted` 態預留，MVP 不實作（2026-09-28 arlong 裁決）

概念文件的「咖啡機故障」留 VS。狀態機保留 `Faulted`（由 #8 置入、玩家一個維護動作解除）的**位置與介面形狀**，MVP 不接任何觸發源。「微波爐連環叫」是密度現象（多張同家族單同時到），歸 #7／#8 抽樣，不需要機台層支援。

#### C20 — RPC 與資料形狀（語意表；r1 新增，C# 簽章與型別最終由 ADR-0004 定）

r0 第 112 行說「承載與封裝已定形」，評審證實沒有：正文出現五個 RPC 名、registry 只登記一則且無 `sku`。本節是唯一真相；下列名稱取代正文他處的 `RequestInteractRpc`／`PerformActionRpc`／`ScanRpc`／「Start」／「中斷 RPC」。

| RPC（client → Host） | 欄位 | 何時送 | Host 驗證 | 效果 |
|---|---|---|---|---|
| `InteractRpc` | `stationId`、`sku`、`action ∈ {Interact, Restock}`、`claimGenerationSeen`、`selfX`、`selfZ`、`selfYawDeg` | 對任一槽按下（E0.4 第一下）；收銀每一刷；貨架按住 ≥ 100 ms 時的 `Restock`（E0.2） | requester 未持有此站 claim → 六段述詞①–⑥（錨點＝槽，C15）；已持有 → 只跑②③④（C6）；`sku ∈ GetByMachineFamily(family)`（E0.1） | 同一次處理內建立 claim 並執行家族動作：Shelf／Oden 走完整鏈、微波／咖啡進 `Working`、收銀進 `Scanning`、`Restock` 進 `Restocking` |
| `TakeOutputRpc` | `stationId`、`selfX`、`selfZ`、`selfYawDeg` | client 讀到 Phase ∈ {Ready, Spoiled} 時按下 | ①④⑤⑥，不看 claim（C9） | `ChangeOwnership(requester)`、`Taken → Idle`、清空 claim（States） |
| `InterruptRpc` | `stationId`、`claimGenerationSeen` | owner 端離開半徑、放開按住、分頁隱藏（C16） | ②③ | 釋放 claim；`Restocking → Idle` 不加庫存；`Working`／`Ready` Phase 不變（C10） |
| `InteractResponseRpc`（Host → 發起者） | `RejectReason`（八成員） | 每則上述 RPC 一則回應 | — | **只送發起者**（`RpcTarget.Single`，ADR-0002 Decision 5）；撲空三種、`NothingToTake`、收銀命中／不中的**個人**回饋全部從這裡來，不從 NetworkVariable（Interactions #14 列 r1 修訂） |

| 複製狀態（Host 寫、Everyone 讀） | 欄位（皆 unmanaged、blittable） | 誰寫、何時 |
|---|---|---|
| `ClaimState` | `bool IsClaimed; ulong ClaimedBy; uint ClaimGeneration` | netcode Core Rule #4 既定 |
| `StationStatus` | `byte Phase; int WorkStartTick; byte Sku; ulong PendingProductNetId` | `Sku`：`Claimed → Working` 寫（C14）；`WorkStartTick`：同時寫 Host 收到 RPC 的 tick；`PendingProductNetId`：spawn 成品時寫該 `NetworkObjectId`，`Taken` 清 0；`Phase`：每次轉移 |
| `StockState`（r0 稱 `StationStock`，已改名——它不屬於任何站台） | 定長 `byte[N]`，以 `network_index` 索引，N ＝ #6 的 Active SKU 上限 | 掛在 Host 開班動態 spawn 的 `StockRegistry` NetworkObject 上（C18）；全域一份（C11）；`StockChanged` 回呼＝它的變更回呼 |

`sku` 在 RPC 與狀態中一律是 #6 的 `network_index`（`byte`）。`FamilyParam` 不存在（C14）。registry `architecture.yaml` 現登記的 `RequestInteractRpc` 簽章與本表不同步，由 ADR-0004 一併改（OQ-M17）。Core 的測試接縫介面（`ISpawner`、`IOwnershipTransferer`、`IStockWriter`、`ICheckoutCustomerQuery`）在 AC 節具名，簽章歸 ADR-0004。

#### 「不得」總表

| 不得 | 理由 |
|---|---|
| 同時持有兩台 claim | 支柱 3（C8） |
| 中途改已啟動的加工目標 | C14 |
| 跨越他人 claim 撈取或代為收尾（`Ready`／`Spoiled` 除外——C9） | 判準 4（C8） |
| 做 SKU 選單 | 商品資料庫 levy ④（C12） |
| 引入需要精準瞄準／對準的判定 | ADR-0002 只驗水平；判準 2 |
| 需要蹲下或移動鍵以外操作的互動點 | FP 硬拒絕②（C17 的鍵只有 `Interact`） |
| 讓轉頭、換手持物等非位置因素觸發中斷 | 判準 5（C6） |
| 用時間分級結果（越快越好）製造競速誘因 | 判準 1：「俐落」不是「競速」 |
| 等 Host ack 才播下一個本機動作 | C5 |
| 持有期間逐幀送「還在按」的 RPC | C5、C17 |

**交給 Formulas 定的量**（只列名）：`station_reach_m`、`station_leave_m`、`leave_hysteresis_m`、`microwave_cook_duration_sec`、`microwave_burn_grace_sec`、`coffee_brew_duration_sec`、`coffee_overflow_grace_sec`、`shelf_grab_duration_sec`、`oden_scoop_duration_sec`、`checkout_scan_duration_sec`、`stock_max[sku]`、`stock_initial[sku]`、~~`restock_amount_per_action`~~（r1 廢，F5：補貨是設值不是加值）、`restock_duration_sec`、`action_min_interval_ms`、`interact_ray_length_m`、`whiff_arrival_wait_max_ms`、`ready_item_spoil_sec`（🔬 貨架／關東煮的 Ready 是否也會過期）。**D 節已判定**：九個旋鈕、三個推導量（`station_leave_m`、`interact_ray_length_m`、`whiff_arrival_wait_max_ms`）、其餘合併（F7、F8）或不存在（F9）。

### States and Transitions

#### A：產出家族（四台共用骨架，家族分支標明）

**狀態實例＝一台站台**；`ClaimState` 三元組與 `StationStatus{Phase, WorkStartTick, Sku, PendingProductNetId}`（C20）是兩個獨立的 Host 寫 `NetworkVariable`（前者已鎖定為獨立 struct）。

| 狀態 | 意義 | 可轉移到 | 條件 | 誰擁有轉移 |
|---|---|---|---|---|
| `Idle` | 無人用、無產出。Shelf 目標 SKU 尚有庫存即可服務；其餘三家族恆可 | `Claimed` | 通過 ADR-0002 六段述詞的 claim | 玩家發起；Host 驗證 |
| `Claimed` | 取得使用權，尚未觸發家族動作 | `Working`／`Restocking`（Shelf）／`Idle`（Shelf 庫存 0，同 tick 自我釋放） | 持有者送啟動（單鍵台＝啟動即完成）；Shelf 依 `action` 分流（r1）：`Interact` 且庫存 > 0 → 拿取；`Interact` 且庫存 0 → `NothingToTake` 同 tick 自我釋放；`Restock` 且本架任一 SKU 未滿 → `Restocking`（E0.2） | 持有者觸發；Host 執行庫存預扣 |
| `Working` | 加工中，倒數在 Host 自走；**`IsClaimed` 可為 false**（C3） | `Ready`／`Failed` | `ServerTick − WorkStartTick ≥ duration` → `Ready`；`shift_end_ts` 到達 → `Failed`（E1）。claim 被釋放（走開／保險絲／斷線）→ **Phase 不變**（C10，r1） | Host（時間）／Host（班次結束） |
| `Ready` | 一份 Fresh `ProductInstance` 已 spawn（Host 持有）；寬限計時中；**`IsClaimed` 可為 false** | `Taken`／`Spoiled` | 任何人 `TakeOutputRpc` 通過 → `Taken`；寬限逾時 → `Spoiled`（微波／咖啡） | 拿走者觸發，Host 驗證＋transfer／Host（時間） |
| `Spoiled` | 一份 Spoiled 實例已 spawn（燒焦／溢出）；語意「收走以丟棄」 | `Taken` | 同 `Ready` | 同上 |
| `Failed` | 班次結束時中止的加工，無產出（唯一觸發源 `shift_end_ts`，C10 r1）；Shelf 預扣已歸還（F7 > 0 時才可達） | `Idle` | 同 tick 自動 | Host |
| `Taken` | 收走瞬間，零時長；實例 ownership 移出站台；**清空 claim**（`IsClaimed → false`、`ClaimGeneration + 1`）——即使拿走者 ≠ 持有者：`Ready` 之後站台不屬於任何人（C9），原持有者若還要用，下一次按鍵就是新 claim（E0.4，一則 RPC）。刻意決策，r1 明寫 | `Idle`（Shelf 見底時該 SKU 的槽同 tick 鏡像 `OutOfStock`，E0.1） | 自動 | Host |
| `OutOfStock`（Shelf） | 目標 SKU 全域庫存 0——**2026-09-29 起為每 SKU 全域條件的鏡像，不是站台 Phase**：任何顯示該 SKU 的槽同 tick 鏡像（E0.1） | `Idle` | 任一貨架完成補貨使該 SKU `> 0`，所有鏡像同 tick 回復 | Host |
| `Restocking`（Shelf，MVP） | 補貨中（按住式），`IsClaimed = true` | `Idle` | 補貨計時完成 → 本架所有未滿 SKU 設為 `stock_max`（E0.2 r1）；**中斷**（放開／走開／斷線／分頁隱藏／保險絲）→ `Idle`，不加庫存，`ClaimGeneration + 1`（E1） | 持有者觸發；Host 計時與寫入 |
| `Faulted`（預留） | #8 置入的故障；玩家一個維護動作解除 | `Idle` | **MVP 不接觸發源** | #8／持有者（VS） |

單鍵台（貨架、關東煮）的 `Working` 時長趨近 0：`Claimed → Working → Ready` 在同一次 Host 處理內完成。**第一下＝claim ＋ 第一個家族動作，一則 RPC**（E0.4）：對 `Idle` 站台的第一次按鍵，Host 在同一次處理內跑六段述詞、建立 claim、執行第一個家族動作——貨架／關東煮跑完 `Claimed → Working → Ready → Taken → Idle` 整條鏈，微波／咖啡跑到 `Working`，收銀跑到 `Scanning`。`Claimed` 作為可觀察的持續狀態只出現在收銀。

**`ClaimGeneration` 遞增規則**：**每一次 `IsClaimed` 從 true 變 false 都 +1**（走開釋放、強制釋放、`Taken` 後正常釋放）；`Idle → Claimed` **不遞增**——兩人同搶時真正的仲裁者是述詞②在 Host 單執行緒的處理順序，世代只負責擋掉對「已換過主人的站台」的過期請求。（netcode `:1112` 的逾時案例同構。）

**接手**：claim 到 `Working`／`Ready`／`Spoiled` 等同 claim 到 `Idle`——站台在跑或已好，新持有者接續；`Ready`／`Spoiled` 的收走不需要 claim（C9）。

**client 顯示規則**：一律讀 `NetworkVariable` 回呼；`ClaimState` 與 `StationStatus` 是兩個變數，**任一回呼觸發時都重讀兩者**、整套重算，不得用「哪個先觸發」推斷另一個已是新值（ADR-0002 Decision 8 的延伸）。

#### B：收銀（消耗型迴圈）

| 狀態 | 意義 | 可轉移到 | 條件 | 誰擁有 |
|---|---|---|---|---|
| `Idle` | 無人收銀（與有沒有客人排隊無關） | `Claimed` | 通過 ADR-0002 驗證 | 玩家；Host |
| `Claimed` | 取得收銀機，尚未刷下一件 | `Scanning`／`Idle` | → `Scanning`：持有者對手上商品觸發刷（`InteractRpc`，E0.4）。→ `Idle`（r1 補列，r0 只在散文）：保險絲 5 s 無刷（E2）、持有者出 `station_leave_m`（三層中斷）、對另一台送 claim（E0.3）、斷線、`shift_end_ts`——皆 `ClaimGeneration + 1` | 持有者；Host |
| `Scanning` | 判定中（時長 0） | `Claimed`（命中）／`Claimed`（不中） | `Matches()`／`AllocateSlot()` ≥ 0 命中；`−1` 不中。時長 0 ⇒ 同一次處理內回到 `Claimed`，`StationStatus` 對其他 client **無可觀察變化**；隊友端的「嗶」由 #7 訂單槽變化觸發（⏳ levy，r1） | Host |

命中／不中的附加效果見 C12。訂單填滿 → 向 #7／#15 發「訂單完成」；站台留在 `Claimed` 等下一位客人或持有者離開。

#### 撲空的畫面順序（判準 4①，本節的演出約束）

輸家收到「我輸了」後**不立即播撲空**，進入待命；每幀讀畫面上贏家的內插位置，其水平距離 ≤ `accept_radius_m`（1.1 m，F1）時才播，對齊贏家此刻的位置（r1：r0 用 `station_reach_m` 0.8，但 Host 以 1.1 接受 claim——在 0.8–1.1 m 贏的人永遠觸發不了演出，輸家白等 400 ms 後看到無方向撲空，正是「遊戲吃我輸入」）。超過 `whiff_arrival_wait_max_ms`（推導量：內插地板 200 ms ＋ 單程 p95 150 ms = 350，出貨取整 400，見 Formulas F4）仍未到 → **降級為無方向的一般撲空**——原則是不演出畫面上看不到的東西。

### Interactions with Other Systems

| 系統 | 流進本系統 | 流出 | 介面擁有者 |
|---|---|---|---|
| **#2 網路同步層** | `ClaimState` 複製；RPC request→validate 骨架；`player_disconnected` → 強制釋放 ≤ 2 s（判定後；判定本身 8–87 s，C10）；`claim_lock_timeout_sec` 保險絲 | `StationStatus`／`StockState` 的 struct 形狀（C20，本系統定）；**C7 續租規則**（provisional） | 三元組歸 #2；站台狀態 struct 歸本系統但守約束⑧ |
| **#3 第一人稱控制器** | 本機座標／yaw／射線起點（永不上網）；`r_c`、`player_move_speed_max` | `station_reach_m`／`station_leave_m`／`leave_hysteresis_m` 的值 | 述詞歸 ADR-0002；公尺數歸本系統 |
| **#4 攜帶與交付** | 收銀需要「這個 client 手上是哪個實例」——**Host 自己從 ownership 讀**，不經 #4 的介面 | `Taken` 釋出的已 spawn 實例（Host→player transfer 已完成）；6b 冷卻起點＝該 transfer；不中時實例留在手上 | 實例 struct 歸 #6；交接機制歸 #4／#2；**本系統只是產生端與消耗端**。⚠ #4 未設計，provisional |
| **#6 商品資料庫** | `GetByMachineFamily()` 決定合法輸出；`ProductInstance.Create(networkIndex, isSpoiled)` 唯一建構路徑；`Matches()`／`AllocateSlot()` | `Working → Ready`／`Spoiled` 時呼叫 `Create()`；資料庫唯讀 | 查詢與 struct 歸 #6；實例化時機與 `is_spoiled` 判定歸本系統 |
| **#7 客人系統** | `ICheckoutCustomerQuery`（Host-only，讀 #7 的 NetworkVariable 現值）：收銀前是誰、`CustomerOrder`、哪些槽已滿 | `IShelfAvailabilityQuery.GetAvailableStock(networkIndex)`（兌現 levy ①）；「訂單完成」邊緣事件 | 訂單內容歸 #7；查詢各擁有被查的那一半。⚠ #7 未設計，兩者 provisional |
| **#8 波次導演** | （VS）置入 `Faulted` 的觸發 | 無 | **MVP 零介面**；密度事件歸 #7／#8 抽樣 |
| **#11 HUD** | 無 | `StationStatus`（含 `WorkStartTick` 供自算進度）、`ClaimState`（誰在用）、`StockState`（缺貨視覺）、收銀命中／不中、本機瞄準的 `(stationId, sku)?`（C15）；**背後站台 `Ready`／臨界寬限的離散方向提示**（判準 3 聽障路徑，r1 ⏳ levy） | 本系統給鍵與值；圖形歸 #11 |
| **#14 音效** | 無 | **兩種觸發源（r1）**：①站台狀態邊緣（開始 Working／Ready／Spoiled／OutOfStock／claim 成功）＝`NetworkVariable` 回呼，全店可聞的事件走這裡 ②**個人結果**（撲空三種、`NothingToTake`、收銀命中／不中）＝`InteractResponseRpc`（C20）——`ClaimState` 沒有「你撲空了」欄位，拒絕回應依 ADR-0002 Decision 5 只送發起者，r0「一律 NetworkVariable 回呼」在架構上不可能 ③隊友端的收銀「嗶」：`Scanning` 時長 0、NetworkVariable 無變化，改由 #7 訂單槽變化觸發（⏳ levy） | 時機歸本系統；內容與「五台閉眼可分」歸 #14 |
| **#15 評分** | 無 | `Matches()` 的回傳（`WrongFamily`＝去別台、`WrongSku`＝同鍋換一個）；「訂單完成」 | 判定純函式歸 #6；星等歸 #15；本系統只是判定的現場 |

**本系統對外的硬拒絕與 levy**（已於 2026-09-28 登記進 `systems-index.md` 前向義務表；依專案規則，登記前等於不存在。⏳ 標記者為 2026-09-29 Edge Cases 新增，已於同日登記）：

- **#4**：拿到實例後的 6b 冷卻起點是站台 transfer 那一刻；不中的實例不消耗、退回歸 #4。
- **#7**：`ICheckoutCustomerQuery` 的形狀；訂單完成事件的消費；`Shelf` 的 `Named` 需求前先查可得性（既有 levy 的兌現方）；⏳ **判定時刻一致性**——`Scanning` 以 Host 處理 RPC 那一刻的查詢現值為準（E5）。
- **#11**：撲空的畫面順序約束（判準 4①）；`WorkStartTick` 自算進度的顯示；⏳ HUD 提示以 1.1 m 亮、1.3 m 滅，不得把 1.1 當手感範圍（E3）。
- ⏳ **#11／關卡佈局**：站台可互動體不得重疊（E3）。
- **#14**：機台音效已在 MVP；事件清單如上；五台閉眼可分。
- **netcode**：C6（持有期間不重驗朝向 → ADR-0002 加註）；C7 續租掛鉤（動作 RPC 即續租）；**互動延遲 AC 須在真實併發負載下驗證**（單一 TCP，HOL 阻塞在傳輸層——孤立雙進程的 300 ms 不代表 4 人同時移動＋互動時的數字）；⏳ **ADR-0002 加註（E 節新增）**：動作 RPC 沿用 `RejectReason` 並新增 `NothingToTake`；「對另一台送 claim」為第四個中斷觸發源（E0.3）。
- ⏳ **#15**：班次結束時未收走與手上的實例如何結算（E1，provisional）。
- **原型 T0／T1**：`[Rpc(SendTo.SpecifiedInParams)]` r1 已以 NGO 2.13.2 原始碼確認（`RpcTarget.cs:79`，OQ-M11 結案）；「Spawn 前寫入的值隨初始同步送給 observer」同樣已確認（`NetworkObject.cs:3410-3428`，OQ-M12 結案）。仍排 T1 的：`AutoObjectParentSync = false`（C13）、槽 collider 與 `CharacterController` 遮擋（C15）、E2 的 tick 鉤子（ADR-0004）。
- ⏳ **r1 新增（2026-09-29 `/design-review` 後，已登記索引前向義務表）**：**#17 教學**——「教會玩家按住補貨」（E0.2 無文字、無中間態、第一人稱看不到自己彎腰，r0 沒有人接下這條義務）；**#11**——背後站台 `Ready`／臨界寬限的離散方向提示（判準 3 的聽障路徑在收銀站沒有落地機制）；**#7**——關東煮家族需求占比上限（零風險站的常駐躲藏）＋收銀「嗶」由訂單槽變化觸發；**#4**——手部容量契約（手滿時的拿取／Take：client 已知無效即不送 RPC、輕提示，C15）；**ADR-0002**——述詞⑤⑥錨點以槽為單位（C15）；**#11／關卡佈局**——可互動槽高度帶（F6）、站台錨點定義與異家族最小淨距（E3）。

## Formulas

**寫作層級**：每條公式先給表達式，再給變數表、輸出範圍與算例。**旋鈕**（真正要 playtest 單獨轉的）與**推導量**（由旋鈕與上游常數算出，不得獨立調）分開標；本節最後一段是淨旋鈕清單，Tuning Knobs 節只會列那幾個。

**共用輸入**（registry 已鎖定，本節只引用不改）：`player_move_speed_max` v = 1.47 m/s、`r_c` = 0.30 m、`network_tick_rate` = 10 Hz（1 tick = 100 ms）、`optimistic_anim_max_ms` = 100、`interact_rtt_p95_ms` = 300、`npc_pin_timeout_sec` = 1.5、`claim_lock_timeout_sec` = 5、`camera_eye_height_m` = 1.60。

### F1 `station_reach_m` — 旋鈕（沿用 ADR-0002 暫定值）

`station_reach_m = 0.8`
`accept_radius_m = station_reach_m + r_c`（ADR-0002 述詞⑤：`dist ≤ R + r_c`）

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `station_reach_m` | R | float (m) | 0.5–1.2 | claim 精確驗證的水平半徑；上限由人體工學定（伸手＋一步） |
| `accept_radius_m` | — | float (m) | = R + r_c | Host 實際接受的玩家中心距離（推導） |

**輸出範圍**：R = 0.8 → 接受半徑 **1.1 m**。
**算例**：玩家中心距站台錨點 0.75 m ≤ 1.1 → 通過述詞⑤；1.15 m → `OutOfReach`。
🔬 回填觸發：ADR-0002 Decision 4 的 `OutOfReach` 比率 playtest；比率高於預期先查 R，再查容差。

### F2 `station_leave_m` — 推導量，不是旋鈕

`station_leave_m = max(station_reach_m + r_c + leave_hysteresis_m, 2·r_c)`

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `leave_hysteresis_m` | H | float (m) | 0.1–0.4 | 離開判定緩衝（**旋鈕**，暫定 **0.20**）：接受半徑外再走多遠才算走開 |
| `station_leave_m` | L | float (m) | ≥ 2·r_c | owner 端「離開即中斷」半徑（ADR-0002 Decision 7 第一層） |

**輸出範圍**：代入 → **1.3 m**。`2·r_c` = 0.6 這條下界（第一人稱控制器硬拒絕④）在 `r_c ∈ [0.25, 0.45]` 內**從未咬合**——要 `r_c > 1.0` 才會反轉；它存在是為了擋住 H 被調成負值這種病態，不是活躍約束。
**算例**：持有者後退到水平 1.3 m 的那一幀，owner 送 `InterruptRpc`；被隊友擠開一次的最大位移是 `2·r_c` = 0.6 m < 1.3 m，**一般擠壓不會誤觸中斷**——這正是硬拒絕④要保護的東西。
**交叉檢查**：`npc_pin_timeout_sec × v` = 1.5 × 1.47 = 2.2 m > 1.3 m——被客人卡到 pin 上限的累積路徑理論上可越過離開半徑。**可接受**：`Working` 在 Host 自走（C3）、`Ready` 任何人可收（C9）、保險絲兜底（C7）；被卡走的人損失的只是 claim，不是加工。

### F3 加工時長與寬限——本節的核心關係式

`T = crossing_time_sec`（單程含繞行穿越店面）
`B = disengage_buffer_sec = 2`（去程做一件小事／回程反應，共用一個量）

`cook_duration_sec ∈ [T_max, min(2·T_min + B, cook_cap_sec)]`，`cook_cap_sec = 30`（支柱 5 常數，非旋鈕）
`grace_sec ≥ T_max + B`

下界用**最長**穿越、上界用**最短**穿越，不等式才對整個 T 區間成立（2026-09-29 qa-lead 抓到原稿拿中點 T = 13 算，寬限 16 在 T = 15 差 1 s；已改 18）。**r1（arlong 裁決）**：`2·T_min + B` 保留為調參目標，但它依賴未實測的 T（level-designer：支柱 3 的店約 6×6–7×6 m，T 可能只有 [6, 11]，屆時咖啡 22 會超過此上界）；creative-director 則指出 C3 讓人走開、長烹煮是訂單延遲不是玩家等待，支柱 5「純看戲 > 30 s 重做」給的才是絕對上限——兩者並列，`min` 取小。T 由 level-designer 在 blockout 實測後回填 registry（`crossing_time_sec` 分登記 T_min／T_max），屆時重跑本節；在那之前 18／22 不動。**不變式**：`T_max ≤ 2·T_min + B`，否則 cook 區間為空集合（OQ-M2 重跑時必查）。

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `crossing_time_sec` | T | float (s) | 11–15（暫借） | ⚠ **暫借值，無文件出處**：直線下界 `10 m ÷ v ≈ 6.8 s`，繞行倍率 1.5–2；那個「10 m」是 FP GDD 一句側寫參照，從未當店面尺寸驗證——level-designer r1 估支柱 3 的店 T ≈ [6, 11]。registry 已登記，blockout 實測後以 T_min／T_max 兩值回填（OQ-M2） |
| `disengage_buffer_sec` | B | float (s) | 1–3 | 銜接緩衝（**旋鈕**）。r1：上限由 4 降為 3——B = 4 時 grace 下界 19 > 現值 18，B 與 grace 的安全範圍原本互不相容（systems-designer） |
| `microwave_cook_duration_sec` | Cm | float (s) | [15, 24] | **旋鈕**，暫定 **18** |
| `coffee_brew_duration_sec` | Cc | float (s) | [15, 24] | **旋鈕**，暫定 **22**（距上界 24 餘 2 s）——與微波刻意不同，讓兩台的聲音節奏可分（判準 3） |
| `microwave_burn_grace_sec` | Gm | float (s) | ≥ T_max + B（現值 17） | **旋鈕**，暫定 **18**（2026-09-29 由 16 修正）；安全範圍是式子不是數字——T 或 B 一改就重算 |
| `coffee_overflow_grace_sec` | Gc | float (s) | ≥ T_max + B（現值 17） | **旋鈕**，暫定 **18**（與 Gm 同值但獨立登記——兩台的失敗率要能分開調） |

**為什麼是這兩條不等式**：

- `cook ≥ T_max`：短於最長的穿越時間，玩家連走到別處都不夠——**沒有離開的理由**，C3 的「人可以走」形同虛設。
- `cook ≤ 2·T_min + B`：長於最短的一趟來回加一件小事，玩家辦完雜務回來仍要空等——**「等」被焊回遊戲**（支柱 5）。
- `grace ≥ T_max + B`：最長的回程必須幾何可行。**`grace → 0` 時判準 1 退化成手速判定**，正面牴觸 C3——這正是下界存在的理由。

**輸出範圍**：cook ∈ [15, 24]、grace ≥ 17；單物品生命週期 = cook + grace：微波 36、咖啡 40 s ≈ 一班 480–600 s 的 6–8%。
**算例**：t = 0 按下微波（18 s）→ 走去貨架補貨（4 s）→ 回收銀刷一件 → t = 18「叮」→ 走回微波（T ≈ 12）→ t = 30 < 18 + 18 = 36，來得及。若途中被客人卡 1.5 s 再繞路，t ≈ 33.5，餘 2.5 s——寬限 18 只比 T_max 的下界 17 多 1 s，那 1 s 就是被卡一次的餘裕。🔬 需 playtest 校準。
**邊界**：寬限對 T_max 只有 1 s 餘裕——v 降 10%（1.32）時 T 區間平移到 [12.3, 16.7]，grace 下界變 18.7，18 **不成立**；v 升到 1.62 時 T 平移到 [9.98, 13.6]，cook 上界 2·9.98 + 2 = **21.96，咖啡 22 超出 0.04 s**（r1：r0 寫「無事」是用取整的 10 算的）。**`player_move_speed_max` 上調下調都要重驗③與上界**。若店面穿越時間實測 T_max = 20 s：cook 下界 20（微波 18 不成立）、grace 下界 22——**問題在店面幾何，不在式子**；這依賴 FP GDD 欠 #11／關卡佈局的「穿越店面時間上限」常數成立。

### F4 `whiff_arrival_wait_max_ms` — 推導量，不是旋鈕

`whiff_arrival_wait_max_ms = interp_floor_ms + one_way_p95_ms`
`interp_floor_ms = 2 × (1000 / network_tick_rate)`
`one_way_p95_ms ≈ interact_rtt_p95_ms / 2`

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `interp_floor_ms` | F | int (ms) | 200 | 2-tick 內插地板（NGO `TickLatency` 下限，ADR-0002） |
| `one_way_p95_ms` | P | float (ms) | 150 | 單程 p95；對稱假設，待 ADR-0002 Verification ③實測 |
| `whiff_arrival_wait_max_ms` | W | int (ms) | ≥ 350 | 輸家等贏家在本機畫面上到站的上限，逾時降級為無方向撲空（States 節） |

**輸出範圍**：200 + 150 = 350 → 出貨取整 **400**（14% 安全邊際，不是獨立旋鈕）。因果是「地板＋單程」，**不是「地板的 2 倍」**——tick rate 改 20 Hz 時 F 變 100、W 變 250，2 倍的說法會給錯值。
**算例**：t = 380 ms 贏家仍未進 `accept_radius_m`（1.1 m，States r1）→ 繼續等；t = 410 ms → 降級。
**回填觸發（r1）**：`interact_rtt_p95_ms` 一改就重算——registry 已實測的 Relay p95（東京 94.5、預設 region 335.8、europe-west4 437.8 ms）代入 437.8 得 raw 200 + 219 = 419 > 400，14% 邊際轉負。逾時本就優雅降級為無方向撲空，**海外 Relay 玩家撲空較常降級為已接受**，不為它抬 W（creative-director）。

### F5 庫存三值與補貨——`d_peak` 未測量

`stock_max[sku] = stock_initial[sku] = d_peak`（r1：`restock_amount_per_action` 已無意義——補貨把每個未滿 SKU 設為 `stock_max`，不是加增量，E0.2）
`restock_duration_sec = 4`

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `d_peak` | D | int | 2–5 | 🔴 **未測量**：單 SKU 在單一尖峰窗內的預期指名購買次數。粗估 **3**（一班兩個尖峰窗、2 人房 MVP），**未經 #7／#8 客流模型驗證**——比照 FP GDD 對 `L_p95` 的標示方式 |
| `stock_max` = `stock_initial` | S | int | = D | 二名一值（r1）：開店滿架、一次補滿整架；C11 已無 clamp（設值而非加值） |
| `restock_duration_sec` | Rd | float (s) | 2–8 | **旋鈕**，暫定 **4**：顯著長於單鍵的 0（補貨要「像在做事」），遠短於尖峰間的靜窗 |

**輸出範圍**：`stock_count ∈ [0, 3]`。
**每班缺貨次數**（r1 改寫）：上界與下界都是**機率主張**——r0 說「≤ 2 是結構推導、與 D 無關」不成立：同一尖峰窗內可以見底→按住 4 s 補滿→再見底（`restock_duration_sec` 遠短於尖峰窗），上界只在「一窗最多一次見底」這個未證前提下成立。D 校準對了才有「每班 1–2 次」；**「靜→爆」因果線每班至少出現一次**這條設計意圖（Player Fantasy）同樣繫於 D。
**算例**：開班 3 → 宵夜潮第三位指名同 SKU 的客人觸發 `OutOfStock` → 靜窗按住 4 s 全架回到 3（部分消耗的 SKU 一起補滿，r1）→ 早餐潮可能再見底。
🔬 回填觸發：#7／#8 客流模型定案後重算 D；若校準後 D > 5，`stock_max = d_peak` 這條等式要重審（排面美術的可信上限）。

### F6 `interact_ray_length_m` — 推導量，不是旋鈕

`interact_ray_length_m = station_reach_m + 2·r_c`

| 變數 | 符號 | 型別 | 範圍 | 說明 |
|---|---|---|---|---|
| `interact_ray_length_m` | I | float (m) | ≥ R + r_c | 每幀互動 raycast 長度（C15）；C15 的 `margin` 取 `r_c` 本身當俯仰斜線餘量，不另設常數 |

**輸出範圍**：代入 → **1.4 m**；`r_c` → 0.25／0.45 時 1.3／1.7，與接受半徑同向縮放。
**槽高下限（r1 新增，判準 4 幾何④）**：`slot_height_min_m = camera_eye_height_m − √(interact_ray_length_m² − accept_radius_m²)` = 1.60 − √(1.96 − 1.21) = 1.60 − 0.866 ≈ **0.73 m**（出貨取 **0.75**）。低於此高度的槽，玩家站在 Host 會接受的最遠距離時射線打不到，且同一射線決定「送給哪台」（C15）——低槽整個叫不動，不只是提示不亮；r0「不會出現」的宣稱對貨架下層不成立。**可互動 SKU 槽的高度帶為 [0.75, 1.60] m**（上限＝眼高，人體工學而非幾何），其餘排面沿用 C11「滿架是純美術」；版面義務 ⏳ levy #11／關卡佈局。
**算例**：假設站台可互動碰撞體頂面高約 1.0 m、眼高 1.60：站在 Host 最大接受距離 1.1 m 略低頭，斜線長 ≈ √(1.1² + 0.6²) ≈ 1.25 < 1.4 → 命中 interactable layer；兩套幾何不會出現「Host 接受但提示沒亮」。🔬 margin = `r_c` 在極端俯仰角的幾何充分性在 6.3 場景實測，與 C15 的遮擋測試合併。

### F7 `instant_gesture_duration_sec` = 0 — 三名合一

貨架、關東煮的 `Working` 在同一次 Host 處理內完成（States 節）；收銀 `Scanning` 時長可為 0（States B）。Core Rules 列名的 `shelf_grab_duration_sec`、`oden_scoop_duration_sec`、`checkout_scan_duration_sec` 暫時合併為一個 **`instant_gesture_duration_sec` = 0**——三個 0 不需要三個名字。**收銀 A/B 原型定案後再分岔出 `checkout_scan_duration_sec`**（若選到按住式，它會 > 0）。

### F8 `action_min_interval_ms` ≡ `optimistic_anim_max_ms` — 不登記

`action_min_interval_ms = optimistic_anim_max_ms = 100`

更長會損俐落手感（「一個動作、一聲回應」），更短會疊播樂觀動畫。**不登記獨立常數**，C5 直接引用 `optimistic_anim_max_ms`。r1：同一個 100 ms 也是貨架「按住＝補貨」的判定門檻（E0.2）——按下即拿、持續按住過 100 ms 才送 `Restock`，三個用途一個常數。

### F9 `ready_item_spoil_sec` — 無此常數

單鍵台不存在可觀察的 `Ready` 窗（`Claimed → Working → Ready` 同一次處理內完成，拿取即 `Taken`）；為關東煮追加過期＝新增一種未裁決的失敗，牴觸「永遠不出包」（Player Fantasy）。**明寫不存在**，免得下一輪重新擔心一次。

### 淨旋鈕清單

真正要 playtest 單獨轉的，**九個**：

| 旋鈕 | 暫定 | 出處 |
|---|---|---|
| `station_reach_m` | 0.8 | F1 |
| `leave_hysteresis_m` | 0.20 | F2 |
| `disengage_buffer_sec` | 2 | F3 |
| `microwave_cook_duration_sec` | 18 | F3 |
| `coffee_brew_duration_sec` | 22 | F3 |
| `microwave_burn_grace_sec` | 18 | F3 |
| `coffee_overflow_grace_sec` | 18 | F3 |
| `d_peak`（→ `stock_max`／`stock_initial`） | 3（未測量） | F5 |
| `restock_duration_sec` | 4 | F5 |

加上收銀 A/B 後才分岔的 `checkout_scan_duration_sec`（F7）。固定常數（非旋鈕，r1）：`cook_cap_sec` = 30（支柱 5，F3）、`slot_height_min_m` ≈ 0.73 → 出貨 0.75（F6 推導）。Core Rules 列名的其餘量為推導量（`station_leave_m`、`interact_ray_length_m`、`whiff_arrival_wait_max_ms`）或已合併／不存在（F7–F9）。

## Edge Cases

**寫法**：每條 `If 條件 → 結果`。「已定」＝ C／F／States 已寫、此處明列免得實作者漏掉；「新定」＝本節定案（2026-09-29 裁決或提議）。本節先立四個 Section C 原本沒有的概念（E0），其餘邊界多半由它們推出；E0 已回寫 Section C（見節末「連帶修訂」）。systems-designer 從規則與公式空間找出 16 條、主 session 追加 4 條，全部納入。

### E0 本節新立的概念

**E0.1 SKU 槽（2026-09-29 裁決）**。產出站台的可互動體以 **SKU 槽**為單位：關東煮的每一格、貨架的每個排面、微波與咖啡機的每顆按鈕各是一個槽，一槽對應一筆 `Active` SKU。C15 的射線回傳 `(stationId, sku)`；動作 RPC 帶 `sku`；Host **只驗**「sku ∈ `GetByMachineFamily(station.family)`」——不驗瞄準（Host 沒有俯仰，ADR-0002 不動），因為選錯／竄改 sku 只會拿到同家族另一件合法商品（C1：手勢結果是單一真相，不是防作弊）。`Family` 需求撈哪格都對，`Named` 需求要撈對那格。**這不是商品資料庫 levy ④ 禁的選單**：商品的 3D 模型就是它的身份，不需要每筆 SKU 配符號。槽寬 30–40 cm、距離 ≤ 1.1 m，角尺寸約 15–20°，不構成「精準瞄準」。連帶：`OutOfStock` **不是站台 Phase，是每 SKU 的全域條件**（`stock_count[sku] == 0`），任何顯示該 SKU 的槽同 tick 鏡像。

**E0.2 點按＝拿，按住＝補整架（2026-09-29 r0 裁決；r1 同日依評審改，arlong 裁決）**。對貨架任一槽：按下（`started`）當幀，`stock_count[sku] > 0` → 0 ms 送拿取（`InteractRpc(action = Interact)`）；`== 0` → 直接送 `InteractRpc(action = Restock)`。**持續按住 ≥ `optimistic_anim_max_ms`（100 ms）且本架任一 SKU `< stock_max`** → 送 `Restock`（有貨槽是「先拿後補」；手滿時拿取為 client 端 no-op、只補）。`Restocking` 由 Host 自走 `restock_duration_sec`（同 C3 骨架），放開＝`InterruptRpc`（與離開中斷同一條路徑，C16 的分頁隱藏亦然），**Host 到時才把本架所有未滿 SKU 設為 `stock_max`**；中途放開不保留進度。不加鍵、不加道具；美術「0／非 0 二元、不做快沒了中間態」的裁決不動。r0 規則「只有 0 的槽能補」的代價比當時接受的更大：部分消耗的架子在靜窗無法維護，「靜→爆」因果線只在尖峰剛好見底時成立（粗估約 37% 的尖峰結束時剩 1–2 件），且誘發「拿光逼 0 再補」的退化招——r1 改此；代價換成 `action` 欄位與「補貨前可能多拿一件」。🔬 待 playtest：先拿後補會不會讓玩家覺得「我只是想補貨」。

**E0.3 對另一台送 claim ＝ 離開前一台（2026-09-29 裁決）**。ADR-0002 三層中斷之外的**第四個觸發源**：Host 收到 B 台的 claim 時，若 requester 仍持有 A 台，先對 A 走「走開釋放」（`Working` 照樣自走、`Restocking` 中斷不加庫存、收銀 `Claimed` 釋放、`ClaimGeneration + 1`），再驗 B。C8「不得同時持有兩台」由此在構造上成立，**不需要新的拒絕原因**；收銀員轉身按背後的微波不會被拒絕，回頭再刷即重新 claim（一則 RPC，E0.4）。**先放後驗、不回滾（r1 明寫）**：B 被拒（`OutOfReach`／`Claimed`…）時 A 不恢復，requester 結束時持有 0 個 claim——與 Host 一貫的不回滾哲學一致；實際代價只有收銀 claim（下一刷即重 claim）。`Restocking` 不會被 E0.3 打斷：互動只有一個鍵，要對 B 送 claim 必先放開，放開那一刻補貨已由 `InterruptRpc` 中斷（creative-director）。

**E0.4 第一下＝claim ＋ 第一個家族動作，一則 RPC**。對 `Idle` 站台的第一次按鍵，Host 在**同一次處理內**跑六段述詞、建立 claim、執行第一個家族動作：貨架／關東煮跑完 `Claimed → Working → Ready → Taken → Idle` 整條鏈（商品直接落到手上，一趟 RTT）；微波／咖啡跑到 `Working`；收銀跑到 `Scanning` 判定。`Claimed` 作為**可觀察的持續狀態只出現在收銀**（兩次刷之間）；產出站台的 `Claimed` 是同一次處理內的暫態。空手對收銀按鍵仍是 no-op 不送 RPC（C12），所以收銀的 claim 只由一次有效的刷建立。

### E1 狀態機 × 外部事件

- **If 站台在 `Ready`／`Spoiled`（出貨位有東西）而 Host 收到 Start**：no-op，回撲空等級回饋。**一站一個出貨位**，出貨位有東西時不得啟動；client 讀到 Phase ∈ {Ready, Spoiled} 時按鍵只送 `TakeOutputRpc`，Start 只會在競態下抵達。（新定；封掉「疊出第二份實例」）
- **If `Ready` 寬限逾時轉 `Spoiled`**：Host **despawn 那份 Fresh、spawn 一份 `is_spoiled = true` 的新實例**到同一出貨位——`is_spoiled` 在 `Spawn()` 前寫死且無 setter（商品資料庫 AC22／AC23），轉態只能換件。`TakeOutputRpc` 以**站台**為目標、不帶實例 id：飛行中的 Take 拿到的是換過的那份。（新定；C13 連帶修訂）
- **If 兩人同 tick 對同一份 `Ready` 送 Take**：Host 單執行緒依序處理，後者拒絕 **`NothingToTake`**（動作 RPC 沿用 `RejectReason`、新增此一值；⏳ levy ADR-0002）。演出：兩人都已在畫面上，輸家的撲空**立即**對齊贏家的手，不等 `whiff_arrival_wait_max_ms`。Take 跑述詞 ①④⑤⑥（不跑 ②③——它不看 claim，C9）。（新定）
- **If 持有者在 `Restocking` 中斷線／走開／分頁隱藏／保險絲到期**：`Restocking → Idle`，**不加庫存**，`ClaimGeneration + 1`。沒有 `Failed`——補貨沒有產出可作廢。（已定：netcode AC11 可推；States 表已補列）
- **If 持有者在 `Working`／`Ready` 走開、保險絲到期或斷線**：一律只釋放 claim（`IsClaimed → false`、gen+1），倒數自走、成品保留任何人可收（C10 r1）。r0「保險絲／斷線 → `Failed`」已廢止——守在微波前的人 5 s 內必被判失敗，倒轉判準 1。
- **If `shift_end_ts` 到達時站台在 `Working`／`Ready`／`Spoiled`／`Restocking`**：Host 對所有站台走強制釋放路徑（`Working → Failed`、`Ready`／`Spoiled` 保留實例、`Restocking → Idle` 不加庫存），之後拒收所有站台 RPC（回撲空）；未收走與手上的實例交 #15 結算。（新定，**provisional**：#15 未設計；⏳ levy）
- **If Host 自身斷線**：機台層零處理——netcode AC13b 整場在 `session_end_worstcase_sec`（12 s）內結束，不存在 Host 遷移。（已定，明列）
- **If 遲加入者進場時站台在任何非 `Idle` 狀態**：站台是 Host 動態 spawn 的 NetworkPrefab（C18），`ClaimState`／`StationStatus` 隨初始同步到達；進度用 `ServerTime.Tick − WorkStartTick` 自算，與在場者同式。（已定，明列）
- **If 對 `Working` 站台再按一次 E（例如連按微波）**：client 讀得到 Phase，no-op、不送 RPC、播撲空等級的輕回饋。原則：**client 已知無效的按鍵不送 RPC；只有 Host 端才知道的不一致才經回應收斂成撲空**（與 C12 的空手刷同構）。（新定）

### E2 同 tick 競合與時間邊界

- **If 保險絲／寬限／補貨計時在某 tick 到期，而同 tick 有相關 RPC 抵達**：Host **先處理該 tick 已到達的 RPC，再跑逾時掃描**；端點含（`t ≤ timeout` 視為逾時前，netcode AC21 同構）。推論：續租動作贏保險絲、Take 贏寬限（拿到 Fresh）、**補貨的放開中斷贏完成**（4.000 s 那一刻放開＝不加庫存；罕見且確定性，接受）。（新定）**落地機制（r1）**：NGO 的 RPC 每幀處理、非 tick-gated（`modules/multiplayer.md:43`），「tick」在本條是批次單位——逾時掃描必須掛在 `OnNetworkTick`／`INetworkUpdateSystem`（10 Hz）而不是 `Update()`，RPC 於該 tick 前的各幀先落地；Host 自己的 RPC 走 `LocalSendRpcTarget` 同步遞迴（ADR-0002 Decision 6），路徑不同構但順序仍成立。鉤子位置由 ADR-0004 寫死（AC39 必達建立於此）。端點引用改為 netcode AC38（`t ≤ 5.000` 的邊界數學在那裡，AC21 只有原則）。
- **If 收銀員站著等下一位客人超過 `claim_lock_timeout_sec`**：claim 到期釋放——**不是錯誤**：下一次有效的刷就是 claim ＋ 刷一則 RPC（E0.4），玩家看不出差別；唯一可觀察效果是 5 s 後隊友可以接手收銀。（已定 C7，明列）
- **If 等撲空的 `whiff_arrival_wait_max_ms` 內贏家又走掉**：逾時降級為無方向撲空（已定 F4）。
- **If 動作 RPC 抵達時 `ClaimGeneration` 已變**：`StaleGeneration`，撲空（已定 ADR-0002）。E0.3 的自動釋放也讓 A 台世代 +1，所以「按了 B 又立刻按 A」是一次新 claim，不是續租。

### E3 距離帶與瞄準

- **If 持有者退到 1.1–1.3 m 帶狀區（接受半徑外、離開半徑內）送動作**：**接受**——C6 只跑 ②③④，不重驗⑤。實際可操作半徑是 `station_leave_m`，不是 `station_reach_m + r_c`。**提示規則（r1 改）**：遲滯只屬於持有者——持有者的提示到 1.3 m 才滅；**非持有者的提示＝本機以自報姿態跑述詞⑤⑥的結果，無遲滯**（C15）。r0 讓非持有者也吃 1.1／1.3 遲滯：被擠到 1.2 m 的人提示仍亮、按下必 `OutOfReach`（判準 4 幾何②）。#11 不得把 1.1 當持有者的手感範圍。
- **If 玩家貼近寬貨架、瞄準偏心的邊緣槽**：述詞⑤⑥以**該槽的錨點**計算（C15 r1），不會因站台中心在 ±60° 外而 `NotFacing`。站台錨點的定義（員工站位正前方地面投影）與異家族最小淨距（建議 ≥ 1.2 m；熱食三台與收銀站立點 ≥ 1.3 m，否則判準 1 鼓勵的眼神游移會被 E0.3 讀成換站）⏳ levy #11／關卡佈局（level-designer）。（新定）
- **If 已持有 A 台、在 A 的 1.3 m 內對 B 台送 claim**：自動釋放 A（E0.3）。
- **If 射線同時穿過兩個站台的可互動體**：不允許發生——**可互動體不得重疊**是版面約束，射線命中的永遠是看到的那個；⏳ levy「#11／關卡佈局」。（新定）
- **If RPC 帶的 sku 不屬於該站家族或非 `Active`**（竄改，或 SKU 在按鍵與抵達之間被 `Deprecated`）：no-op，回撲空。不是安全事件（C1）。（新定）
- **If 按鍵那一幀與 RPC 送出之間射線目標變了**：RPC 帶的是**按鍵那一幀** C15 的結果，不重取。（已定，明列）

### E4 庫存

- **If client 看到 `stock > 0` 送拿取，Host 端已是 0（兩人搶最後一件的競態）**：claim 成功、Host 發現無貨、站台同 tick 自我釋放，回 **`NothingToTake`**——與 C11「這不是撲空」一致：演出是空手，不是「被搶」。（C11 已定；拒絕值新定）
- **If 補貨中（`Restocking`）另一人對同一架任一槽按鍵**：不論拿取或 `Restock`，claim 被 ② `Claimed` 拒絕 → 撲空（補貨與拿貨共用同一個 claim，C8）。（由 E0.2 推出）
- **If 預扣歸還與補貨完成同 tick 命中同一 SKU**：補貨是「設為 `stock_max`」而非加值，天然冪等，順序無關。C10 r1 之後預扣歸還只剩 `shift_end_ts` 一條路徑，且 F7 = 0 時不可達——寫下來是因為 F7 的 0 日後可能變大。（新定）
- **If 兩台貨架顯示同一 SKU，A 的拿取使它見底**：兩台該槽同 tick 進 `OutOfStock` 鏡像；任一台補貨完成，兩台同 tick 回復。MVP 只有一台貨架，此條為規格一致性。（E0.1 推出）
- **`stock_count` 不會變負**：預扣只在 Host 單執行緒確認 `> 0` 後執行（C11，明列）。

### E5 收銀

- **`MatchResult` 五值對命中／不中**：`Match` → 命中（消耗、槽位標滿）；`WrongFamily`／`WrongSku`／`Spoiled` → 不中（實例留手上；燒焦品要另外丟掉——歸 #4）；`Unevaluated` **不得出現**，出現即斷言失敗（商品資料庫 r2 的哨兵）。（已定，明列）
- **If Host 收到刷的 RPC 但 ownership 查無該 client 手上有實例**（延遲或 bug）：no-op、不消耗、不發「訂單完成」、回撲空。（新定）
- **If `Scanning` 判定時 #7 的收銀前客人已離隊／換位**：以 **Host 處理 RPC 那一刻** `ICheckoutCustomerQuery` 的現值為準；查無客人 → 不中，實例留手上。（新定，**provisional**；⏳ #7 的一致性義務登記 levy）
- **If 最後一槽補滿**：發「訂單完成」；站台留在 `Claimed` 等下一位（已定 States B）。

### E6 跨 GDD 違約檢查（systems-designer 逐條核對，2026-09-29）

FP 四條硬拒絕、netcode 約束⑧（互動結果不走 NetworkVariable）、ADR-0002 述詞順序、商品資料庫「不得以 `NetworkList` 承載 `ProductInstance`」——**四項皆未違反**。E0.1–E0.4 是缺口的補法，不是違反。

### 連帶修訂（Section C，已隨本節套用，2026-09-29）

| 位置 | 修訂 |
|---|---|
| C8 | 對另一台送 claim 即視為離開前一台（第四個中斷觸發源） |
| C11 | 補貨手勢語意（E0.2）；`OutOfStock` 為每 SKU 全域條件；庫存 0 的拿取回 `NothingToTake` |
| C13 | 加「以及 `Ready → Spoiled` 那一刻（despawn Fresh、spawn Spoiled）」；Take 以站台為目標 |
| C15 | SKU 槽（E0.1）；射線回 `(stationId, sku)` |
| States A | `Restocking` 列補中斷轉移；`OutOfStock` 列改為每 SKU 鏡像；表下段落加 E0.4 |
| Interactions levy 清單 | ⏳ ADR-0002：`NothingToTake`＋第四觸發源；⏳ #7：判定時刻一致性；⏳ #15：班次結束殘留實例；⏳ #11／關卡佈局：可互動體不得重疊——四條已於 2026-09-29 登記 |

## Dependencies

**硬／軟定義**：硬＝沒有它本系統無法運作或無法驗收；軟＝有它更好，沒有它可用 stub 暫代。狀態欄取自 `systems-index.md`（2026-09-29）。介面的細節在 Detailed Design「Interactions with Other Systems」表，本節只定方向、硬軟與雙向確認。

### 上游（本系統依賴）

| 來源 | 硬／軟 | 流入本系統的具體介面 | 狀態 | 雙向確認 |
|---|---|---|---|---|
| **#2 網路同步層** | 硬 | `ClaimState` 三元組複製（Core Rule #4）；RPC request→validate 骨架；`player_disconnected` → 強制釋放 ≤ 2 s；`claim_lock_timeout_sec` 保險絲；`shift_end_ts`（班次時鐘語義，E1）；`ServerTime.Tick`（`WorkStartTick` 的時基） | Revised r4 | netcode GDD 提及本系統 5 處 ✅ |
| **#6 商品資料庫** | 硬 | `GetByMachineFamily()`（SKU 槽的合法集合，E0.1）；`ProductInstance.Create(networkIndex, isSpoiled)` 唯一建構路徑；`Matches()`／`AllocateSlot()`；`MatchResult` 五值；`CustomerDemand` 形狀 | In Review r3，純 C# 原型 44/44 | 5 處 ✅，本系統列於其 Interactions |
| **#3 第一人稱控制器** | 硬 | 本機座標／yaw／攝影機起點（永不上網）；`r_c`、`player_move_speed_max`、`camera_eye_height_m`；四條硬拒絕；C14 分頁隱藏模式；`Movement` 與 `Interaction` 兩個 action map 並存 | Revised，待複審 | 4 處 ✅，其 levy 表有本系統列 |
| **ADR-0002** | 硬 | 六段述詞、`RejectReason`、`tol_lag`、三層中斷、Decision 8 顯示規則——本 GDD 是其 GDD Requirements 的主體 | Proposed | ✅ |
| **#7 客人系統** | 硬（可 stub） | `ICheckoutCustomerQuery`：收銀前是誰、`CustomerOrder`、哪些槽已滿——provisional | Not Started | ✅ 索引 #7 列已補登（2026-09-29） |
| ADR-0001 | 軟 | Core 分層的先例（手勢時長由 Core 的 `dt` 累加，C17）；AC1③ 由獨立 map 化解，不需豁免。本系統自己的分層 → ADR 候選 | Proposed | 3 處 |
| ADR-0003 | 軟 | `PassThrough` 對站台前玩家的推離：單次擠壓 ≤ `2·r_c` < `station_leave_m`（F2 的前提） | Proposed | 0 處——ADR 不需列消費者，可接受 |
| #9 遊戲時鐘 | 軟（經 #2） | `shift_end_ts` 的時間源；本系統不直接讀 | Not Started | 經 netcode |
| #8 波次導演 | 無（MVP） | `Faulted` 觸發源，VS | Not Started | — |

### 下游（依賴本系統）

| 消費者 | 硬／軟 | 本系統流出的具體介面 | 狀態 | 雙向確認 |
|---|---|---|---|---|
| **#4 攜帶與交付** | 硬（雙向 provisional） | `Taken` 釋出的已 spawn 實例（Host→player transfer 已完成、6b 冷卻起點＝該 transfer）；不中時實例留手上；`Spoiled` 品要丟 | Not Started | ✅ 索引 #4 列有本系統；levy 已登記 |
| **#7 客人系統** | 硬 | `IShelfAvailabilityQuery.GetAvailableStock(networkIndex)`；「訂單完成」邊緣事件 | Not Started | ✅ 已補登（2026-09-29） |
| **#11 HUD 與需求 icon** | 硬 | `StationStatus`（`WorkStartTick` 自算進度）、`ClaimState`、每 SKU `OutOfStock`、命中／不中、本機 `(stationId, sku)?`、提示遲滯 1.1／1.3 m | Not Started | ✅ 索引列有；levy 已登記（含 2026-09-29 兩條） |
| **#14 音效** | 硬（MVP 機台音效） | 站台狀態邊緣事件清單（Interactions 表） | Not Started | ✅ |
| **#15 評分** | 軟 | `MatchResult` 回傳的現場；「訂單完成」；班次結束殘留實例（⏳） | Not Started | ✅ 索引 #15 列已補登（2026-09-29，軟） |
| #13 結算畫面 | 無直接 | 經 #15 | — | — |

### 索引不一致（已於 2026-09-29 修）

索引 #7、#15 兩列的依賴欄原缺「機台互動組」——#7 兩個方向都有介面，#15 至少是軟依賴，已補登。其餘雙向皆成立；未設計系統的「對方文件提及」以 `systems-index.md` 前向義務表代行。

## Tuning Knobs

只列 Formulas 判定為旋鈕的九個（＋收銀 A/B 後分岔的一個）。上游旋鈕（`optimistic_anim_max_ms`、`claim_lock_timeout_sec`、`npc_pin_timeout_sec`、`interact_rtt_p95_ms`、`player_move_speed_max`、`r_c`）指向來源 GDD，不複製。

| 旋鈕 | 暫定 | 安全範圍 | 影響的玩法面 | 調太高 | 調太低 | 與誰互動 |
|---|---|---|---|---|---|---|
| `station_reach_m` | 0.8 | 0.5–1.2 | 到站的寬鬆度、`OutOfReach` 比率 | 隔著隊友也能 claim，判準 4「兩個人都伸手」失真；站台間距 < 2×接受半徑時同時在兩台範圍內（E0.3 頻繁觸發） | 要站很準，`OutOfReach` 撲空變多（判準 2） | `station_leave_m` 同向移動；`interact_ray_length_m` |
| `leave_hysteresis_m` | 0.20 | 0.1–0.4 | 被擠、後退時的中斷容忍 | 遠在 1.1 m 外仍可操作，HUD 與 Host 幾何脫節（E3） | 一次擠壓（≤ 0.6 m）就中斷，FP 硬拒絕④失守；負值由 `L > 2·r_c` 擋住 | `station_reach_m`、`r_c` |
| `disengage_buffer_sec` | 2 | 1–3（r1，由 grace 現值反推） | 兩事件台「走開做一件事」的餘裕 | cook 上界與 grace 下界一起放寬 → 等待感回來 | 生命週期壓縮，寬限逼近手速判定（判準 1） | 所有 cook／grace 的區間界 |
| `microwave_cook_duration_sec` | 18 | [15, 24] ＝ [T_max, min(2·T_min+B, 30)] | 微波的「走開」窗 | 辦完雜務回來還要空等（支柱 5） | 不夠走到別處，C3 形同虛設 | T、B；與咖啡刻意不同值（判準 3） |
| `coffee_brew_duration_sec` | 22 | [15, 24] | 同上 | 同上 | 同上 | 同上 |
| `microwave_burn_grace_sec` | 18 | ≥ T_max + B（現值 17；B 或 T 一改就重算，B = 4 會要求 ≥ 19） | 燒焦率＝分心懲罰的鬆緊 | 幾乎不燒焦，C4 的失敗來源空轉 | 回程幾何不可行 → 判準 1 退化成手速 | T、B；`npc_pin_timeout_sec`（被卡住吃掉 1.5 s） |
| `coffee_overflow_grace_sec` | 18 | ≥ 17 | 溢出率 | 同上 | 同上 | 同上；與 Gm 獨立登記，兩台失敗率可分開調 |
| `d_peak` →（`stock_max`＝`stock_initial`） | 3（**未測量**） | 2–5 | 每班缺貨次數＝「靜→爆」因果線的出現率 | 從不缺貨，補貨無用武之地 | 每個尖峰都缺貨，補貨變成尖峰動作而非靜窗動作 | #7／#8 客流模型；`restock_duration_sec`；> 5 時重審 `stock_max = d_peak`（F5） |
| `restock_duration_sec` | 4 | 2–8 | 補貨「像在做事」的感覺、尖峰補貨的代價；r1 起一次補整架，本值＝維護一台貨架的固定成本 | 靜窗也補不完，變成懲罰 | 按住與點按無感差別，E0.2 的按住失去意義 | `d_peak`；`optimistic_anim_max_ms`（按住起手須能與點按區分） |
| `checkout_scan_duration_sec` | A/B 後 | 0–? | 收銀節奏 | — | — | 收銀原型定案後才存在（F7） |

**旋鈕之間的耦合**：四個時間旋鈕全掛在 `crossing_time_sec` T 上——T 不是旋鈕，是店面幾何的量測值（暫借 11–15）；**換店面版面＝重跑 F3，不是逐個微調**。`d_peak` 與 `restock_duration_sec` 一起決定補貨在一班裡的存在感；只調其中一個會讓另一個失去意義。

**不是旋鈕，不得獨立調**：`station_leave_m`（F2）、`interact_ray_length_m`（F6）、`whiff_arrival_wait_max_ms`（F4）、`accept_radius_m`（F1）、HUD 遲滯 1.1／1.3（E3，即 F1／F2）、`action_min_interval_ms`（≡ `optimistic_anim_max_ms`，F8）、`instant_gesture_duration_sec`（F7）、`cook_cap_sec` = 30（支柱 5 常數，F3 r1）、`slot_height_min_m`（F6 推導，r1）；`accept_radius_m` 同時是撲空對齊門檻（States r1）；`ready_item_spoil_sec` 不存在（F9）。

## Visual/Audio Requirements

本節只寫**需求與約束**：資產規格歸 `/asset-spec`，HUD 圖形歸 #11，聲音本體歸 #14。來源：art-director 與 audio-director 2026-09-29 回報，主 session 逐條對照 GDD 核過；三項裁決（Spoiled 每家族一款、Ready 疊互動黃、空排面不做中間態）為 2026-09-29 arlong 裁決。

### 兩條分工原則（貫穿本節）

1. **形狀決定「是什麼／什麼狀態」，色彩只決定「現在能不能對它動作」**（美術聖經支撐原則 1、2）。Ready 用 Fresh 模型、Spoiled 用相異模型（E1「換件不是變色」）；互動黃＝可互動、警示紅＝出事，**本系統不得為 SKU 身份或機台狀態另開新色相**（§4.3 兩色配額）。
2. **聲音是遠場的主頻道，視覺是近場的確認頻道**（判準 3）。每個需要玩家反應的狀態，遠處靠聽、近處看一眼；世界事件用**站台空間定位的具象音**（foley），不用 UI 音。

### 表 1 事件 → 視覺／音訊回饋

| 事件 | 世界內／HUD | 視覺必要元素 | 音訊 | 遠處可辨 |
|---|---|---|---|---|
| 第一下（claim ＋ 家族動作，E0.4） | 世界內（硬性） | 持有者第三人稱姿態即時切換為該家族專屬動作（伸手／彎腰撈／按鍵／刷）；本機樂觀動畫 ≤ 100 ms（C5）；遠端觸發源＝`ClaimState` 回呼 | **不另配 claim 音**——併入該家族動作的 onset，「一個動作、一聲回應」 | **是**——隊友純靠背影剪影讀出「他在做什麼」（錨點「灰藍色背影正彎腰補貨」） |
| Working 自走（微波／咖啡） | 世界內（硬性，**非 HUD**） | 機台進入運作動態（轉盤／出水口，§3.2 曲面＝活著）；讀秒為機台上的**實體顯示**，本機由 `WorkStartTick` 自算（C18 不送 float） | 必聲、遠場、loop：微波＝單一穩態電子嗡鳴；咖啡＝研磨（寬頻粗糙）→ Ready 時**質地轉換**為滴水／蒸氣 hiss | 部分——動態剪影中距可辨；遠距主頻道是聲音 |
| Ready | 世界內 | 商品模型出現在出貨位 socket（C13）＋**互動黃待命光暈**（「現在可拿」，支撐原則 1；裁決：加） | 必聲、**混音絕對最高**、遠場（C9 全店可拿；**衰減曲線須設 floor**——既要站台空間定位又要全店等響，用 `AudioSource` 自訂 rolloff＋`minDistance`／`maxDistance`，Web 支援，r1）：微波＝清亮單擊「叮」；咖啡＝研磨停止換質地（offset 型訊號天生比 onset 弱，AC43 前 3 秒可辨的要求對它更嚴）。**兩台不得共用同一顆 Ready 資產** | 部分——模型／光暈中近距；全店靠聲音 |
| Spoiled（換件瞬間） | 世界內 | Fresh despawn、外觀相異的 Spoiled 模型 spawn 到同一出貨位（E1）；swap 瞬間局部警示紅閃＋蒸氣爆（演出層，§2「啊！」） | 必聲（判準 6 載體）、近場＋弱遠場（C4 仍生成待收）、one-shot 驚嚇 | 部分 |
| OutOfStock（每 SKU，E0.1） | 世界內 | 所有顯示該 SKU 的槽**同 tick**切為「空」幾何（裸架）；**不得只降飽和或加符號**，填充物本身消失 | **一聲短促中性「見底」**（r1：r0 無聲——但架上最後一件被拿走是「靜→爆」最關鍵的時刻，且空排面幾何尚未設計，無聲違反判準 3「每個需反應的狀態都要聽得出來」）；近場＋弱遠場，**不得沿用撲空家族**；`NothingToTake` 另配中性空音（個人、`InteractResponseRpc` 觸發） | **是**——中距即可辨，避免無效走位（判準 1） |
| 撲空——輸給對手 | 世界內（個人） | 等贏家的內插位置進 `accept_radius_m`（1.1 m，States r1）才播，方向對齊他的手；逾 400 ms 降級（States、F4） | 必聲（判準 4 兌現點）、近場、不廣播；**觸發源＝`InteractResponseRpc`，不是 NetworkVariable**（C20，r1） | 否 |
| 撲空——降級（無方向） | 世界內（個人） | 無方向的一般撲空 | 同上家族 | 否 |
| `NothingToTake`（缺貨型，E4） | 世界內（個人） | **與「輸給對手」必須是不同演出**：空手／攤手，不指向任何人；立即播、不等待 | 中性空音，**不得沿用撲空家族**（C11「這不是撲空」；混用會讀成被搶） | 否 |
| 收銀命中 | 世界內（近端） | 手上實例移出（C12）；可疊短暫互動黃或完成綠（§4.2，非常駐） | 必聲、近場、每刷一響「嗶」（上層錨點的節奏錨） | 否——「嗶」走店內廣播頻道（#14） |
| 收銀不中 | 世界內（近端） | 實例留手上；**與撲空共用同一視聽語彙**（C12） | 必聲、近場 | 否 |
| 補貨——按住中 | 世界內＋近端 | 持續彎腰姿態（遠距可辨）；進度為貨架上的**實體填充**，本機由按住起點自算；**不得是通用 HUD 進度條** | 必聲（須與點按有感區分）、近場、4 s loop「窸窣」 | 部分——「有人在補貨」遠距可辨 |
| 補貨——完成 | 世界內 | 本架所有未滿排面同 tick 恢復滿載（`StockChanged` 回呼，r1） | 必聲、近場、one-shot 滿足感（靜→爆因果線收尾）；**要短**（比照 onset 長度級距）——同一顆在靜窗讀作滿足、在尖峰被迫補貨時讀作「終於補完」，做成拉長的收尾才會顯得矯情（audio-director，r1） | 部分 |
| 補貨——中斷 | 世界內（本機） | 填充視覺立即回退為空——這是 C5 的樂觀表現：若 Host 其實已在前一 tick 完成，`StockChanged` 回呼會把排面填回滿 | 極輕提示、非驚嚇（不是失敗）；loop 自然停止 | 否 |

### 五台聲音剪影（閉眼可分，判準 3）

| 站台 | 剪影 | 最易混淆 | 拆法 |
|---|---|---|---|
| 貨架 | 乾脆瞬時、寬頻無音高（紙箱／塑膠摩擦），無底噪；補貨才有連續窸窣 | — | 五台最乾的材質，天然基準 |
| 關東煮 | **唯一有持續底噪的站台**：濕暖低頻冒泡氛圍床（與狀態無關）；`Taken` 才有湯勺碰鍋緣高音 | 貨架（同為瞬間手動） | 材質對立；「存在感」取代「狀態變化」——永遠不出包的英雄物件（§3.4） |
| 微波 | 全程單一穩態嗡鳴；Ready＝**新聲音出現**（「叮」） | **咖啡機** | 見右 |
| 咖啡機 | 研磨 → Ready＝**舊聲音停止換質地**（滴水／蒸氣） | **微波** | ①穩態 vs 演化，前 3 秒即可辨 ②Ready 觸發路徑相反 ③時長已錯開 18／22 s（F3）④音高帶不重疊，疊播不互蓋 |
| 收銀 | 短促重複「嗶」，全店唯一快速重複觸發的家族 | — | 不需拆 |

### 尖峰混音優先序（高 → 低）

1. **Ready「叮」——絕對最高**：蓋掉＝沒人知道收＝推高 Spoiled（寬限貼著下界，F3）
2. Spoiled「啊！」
3. 撲空（個人近場）
4. 收銀命中／不中「嗶」
5. 家族動作 onset（遠場、短促）
6. 補貨 loop（可被 1–4 duck）
7. Working loop（環境層，永遠讓位給 1–4）
8. 關東煮底噪（最底層，permanently ducked）

**落地（r1）**：Unity 6000.3 Web 的 AudioMixer 只能調各 group 音量，其他屬性與效果器（含 Duck）不支援；`spatialBlend` 不在 Web 支援清單，位置感只剩 pan＋距離衰減（`minDistance`／`maxDistance`／`rolloffMode`）——已驗證：https://docs.unity3d.com/6000.3/Documentation/Manual/webgl-audio.html 。因此本表以腳本實作（per-source volume），且拆成兩組：**全域 duck 組**（1、2，連帶 7、8 環境層的讓位）與**近場共存組**（3–6，靠距離衰減自然共存，**不得**被全域 duck 壓——否則關東煮的撲空會壓掉店另一頭收銀的「嗶」，全文唯一具體的節奏錨點）。🔬 rolloff floor 與 pan 在 Web build 的實際行為排一小時探針（OQ-M16）。

### 「啊！」的視聽語彙

燒焦、溢出、刷錯、撲空共用一個**喜劇失敗家族**：輕質、彈性、上揚尾音，**不是**低頻警報或下墜音、**不是**扣分畫面（C4、判準 6、§2）；近場即時、只回饋「你剛做的那個動作」、不廣播。**允許依站台做音高／音色變體**——四個「啊！」若完全相同，判準 3 的可辨識性在失敗時刻反而崩掉。變體表歸 #14。

### SKU 槽的視覺契約（E0.1 的美術落地）

1. **一槽一筆 Active SKU，模型即身份**：不得有文字標籤、價格牌、選單 UI（商品資料庫 §3.3、levy ④）。
2. **最小可辨尺寸**：在 1.1 m（`accept_radius_m`）、槽寬 30–40 cm、視角 15–20° 的觀看條件下，主輪廓／包裝形狀不用近看即可辨；相鄰槽間距須讓正常站位下射線不誤中鄰格（版面義務歸 #11／關卡佈局，E3）。
3. **同家族剪影可分**：把美術聖經 §3.1 的縮圖剪影測試延伸到產品模型，作為 `/asset-spec` 的驗收方法；本節不自訂數值。商品資料庫准入門檻 3／AC4b（`mesh_ref` 必填）是上游依據。
4. **滿架是純美術，唯一例外是 0**：排面密度與 `stock_count` 無 1:1（C11）；`== 0` 時所有顯示該 SKU 的槽同 tick 切「空」。**不做「快沒了」中間態**（裁決：GDD 只要求 0／非 0 二元，多一態是複雜度不是資訊）。
5. **槽不標示訂單**：`Family` 撈哪格都對、`Named` 要撈對那格——「該拿哪個」的指引屬 #11 的需求 icon；槽永遠只誠實顯示商品身份，不疊訂單相關高亮。

### 動畫與風格約束

1. 樂觀動畫 ≤ 100 ms、零網路流量（C5）。
2. 撲空對齊贏家的手，不對齊封包；逾 400 ms 降級（F4）；三種撲空級演出（輸給對手／降級無方向／`NothingToTake`）視聽上可分。
3. **五個家族各一套第三人稱可辨姿態**（含收銀），把 §3.1 的剪影身份哲學從客人延伸到隊友動作——這是新的資產類別。
4. 新特效不開新色相：Spoiled 爆點、補貨完成脈動、claim 回饋一律吃既有互動黃／警示紅，或落在無配額的演出層（蒸氣、粉塵，§5.1）。
5. **一律程式 tween，禁骨架動畫**（§8.7；Animator 是 WebGL 已知 CPU 瓶頸）。
6. 世界內進度一律本機自算（`WorkStartTick`／按住起點）——網路約束直接決定它必須是機台上的實體視覺，不是 HUD 浮動元素。

### 對 #14 的「不得」

1. 不得用 UI 音表示世界事件（Ready／Spoiled／動作 onset 須空間定位）。
2. Working loop 不得掩蓋 Ready（自動讓位，否則 C9 在尖峰失效）。
3. 微波與咖啡的 Ready 不得共用同一顆資產。
4. 「啊！」不得做成警報或扣分式音色。
5. 不得為「轉頭」「被擠」等 C6 刻意不重驗的因素配中斷音——不得在音效層復活 Core Rules 已拒絕的機制（判準 5）。
6. `OutOfStock`／`NothingToTake` 不得沿用撲空家族。
7. 個人結果音（撲空三種／`NothingToTake`／收銀命中／不中）只能由 `InteractResponseRpc` 觸發，不得從 NetworkVariable 推斷（C20，r1）；隊友端的收銀「嗶」由 #7 訂單槽變化觸發。

### Web 平台限制

`AudioContext` 需一次使用者手勢解鎖：大廳／進房點擊（#12）天然提供，應在該次點擊 `resume()`；**開班第一聲不可假設必然可聞**，context 仍 suspended 時遊戲邏輯不得等音訊回呼。責任：#14 實作、#12 提供手勢；本 GDD 只標注。

### 美術聖經缺口（`/asset-spec` 或後續補章）

① Spoiled 商品本身的外觀語言（Mood 節只寫了機台的紅光＋蒸氣）——**每家族一款**（裁決：判準 6 讀的是鬧劇不是哪個商品燒了，playtest 要求具體性再拆）；② 空排面幾何變體（§5.2 只有「密」態）；③ 隊友逐家族的第三人稱手勢姿態（§3.1 只到基礎剪影）。

### 資產類別與數量級

| 類別 | 數量級 | 備註 |
|---|---|---|
| 站台本體（含收銀台） | ×5 | 既有義務；動態零件走 ProBuilder 曲面例外（§8.1） |
| 家族專屬第三人稱手勢（程式 tween） | ×5 | **新增** |
| Spoiled 換件模型 | ×2（微波、咖啡各一） | **新增**，每家族一款 |
| 空排面幾何變體 | ×1 | **新增**，僅 Shelf |
| 世界內自走進度顯示 | ×2–3 | **新增**：微波／咖啡面板＋貨架填充；禁 HUD |
| 事件性 VFX（撲空塵 ×2、Spoiled 蒸氣爆、補貨脈動、claim 回饋） | ×4–6 | **新增**，演出層，`vfx_` 命名 |
| 材質／Emission、頭頂符號 | ×0 | 沿用既有 |
| 音訊資產（r1 補列，r0 漏計） | ×22–25 | 家族 onset ×5、Working loop ×2、Ready ×2、Spoiled ×2、撲空 ×2–3、「啊」變體 ×4、收銀嗶 ×2、補貨 loop／完成／中斷 ×3、關東煮底噪 ×1、見底 ×1、`NothingToTake` ×1；數量級由 #14 定稿 |

📌 **Asset Spec** — 本節寫定後，美術聖經核准即可跑 `/asset-spec system:machine-interaction`。

## UI Requirements

本系統**沒有自己的畫面**；它供給 #11 HUD 的鍵與值，並對 HUD 立約束。圖形、版面、icon 歸 #11（`/ux-design` 前置）。

### 本系統供給 HUD 的資料（全部本機可讀，零額外網路）

| 資料 | 來源 | HUD 用途 |
|---|---|---|
| `(stationId, sku)?` 本機瞄準結果 | C15 每幀一次 raycast | 互動提示的亮／滅與對象 |
| `ClaimState{IsClaimed, ClaimedBy, ClaimGeneration}` | NetworkVariable 回呼 | 「誰在用」（隊友名／顏色） |
| `StationStatus{Phase, WorkStartTick, Sku, PendingProductNetId}`（C20） | NetworkVariable 回呼 | 進度自算：狀態邊界用 `ServerTime.Tick − WorkStartTick`，畫面插值用 `NetworkTime.TimeAsFloat`（整數 tick 只 10 Hz 變化，直接餵進度條會是階梯，r1）；Ready／Spoiled 標示 |
| 每 SKU `stock_count`、OutOfStock 條件 | `StockChanged` 回呼 | 缺貨標示（世界內為主、HUD 為輔） |
| 動作回應 `RejectReason`（八成員，`InteractResponseRpc`） | RPC 回應（只送發起者） | 撲空／`NothingToTake`／收銀命中不中的 HUD 端回饋（若有） |
| 收銀命中／不中、訂單槽填滿 | RPC 回應＋#7 訂單狀態 | 訂單槽 UI（#7／#11 共有） |

### 對 #11 的約束

1. **非持有者**的互動提示＝本機以自報姿態跑述詞⑤⑥的結果（C15 r1），無遲滯；**持有者**的提示到 `station_leave_m` = 1.3 m 才滅（E3）；**不得把 1.1 當持有者的可操作範圍**。
2. 提示與送出共用同一幀的 `(stationId, sku)?`（C15）——HUD 不得另跑查詢。
3. 進度一律自算，不顯示任何來自網路的 float；世界內實體顯示優先（Visual/Audio），HUD 進度只能是輔助且不得與世界內顯示不一致。
4. 撲空畫面順序（判準 4①）：HUD 若有撲空回饋，同樣等贏家到站才播、逾 400 ms 降級；`NothingToTake` 立即播且不指向任何人。
5. 不得做 SKU 選單（商品資料庫 levy ④）；「該拿哪個」由需求 icon 表達（#11 既有預算）。
6. `ClaimState` 與 `StationStatus` 任一回呼觸發時都重讀兩者（States、ADR-0002 Decision 8）。
7. `Faulted` 預留態不顯示（C19）。
8. **背後站台的離散提示（r1 新增，判準 3 聽障路徑）**：本機玩家視錐外的站台進 `Ready`、或寬限進入最後 `disengage_buffer_sec` 時，HUD 給一個離散、非連續進度的方向提示（螢幕邊緣指示即可）。收銀員背對熱食機台是本 GDD 自寫的常態站位，r0 沒有任何「看一眼」的落地機制；約束 3 管的是連續進度，不擋離散事件。⏳ levy #11。

> **📌 UX Flag — 機台互動組**：本系統對 HUD 有真實需求（互動提示、站台狀態、缺貨、撲空回饋）。Phase 4 前先跑 `/ux-design` 產出 `design/ux/hud.md`，引用 UI 的 story 須引 UX spec 而非本 GDD。

## Acceptance Criteria

**證據等級**：**T0** 純 C# EditMode（Logic，BLOCKING；**不碰 NGO 型別**——凡引擎行為一律經 fake 接縫：`ISpawner`、`IOwnershipTransferer`、`IStockWriter`、`IStationStatusWriter`、`ICheckoutCustomerQuery`，C20）；**T1s** 單機 PlayMode（PhysX、Input System；r1 新增一級）；**T1** NGO 雙進程（Integration，BLOCKING）；**PT** playtest／遙測（documented）；**SS** 截圖＋lead 簽核（ADVISORY）。**必達**＝任一紅燈即 GDD 自相矛盾或硬拒絕失守：AC19、AC24、AC25、AC32、AC37、AC39、**AC11、AC38**（r1 加入：兩者防的是稀缺資源被重複發放，比數值邊界更貼近「硬拒絕失守」）。來源：qa-lead 2026-09-29 起草 AC1–40 與覆蓋矩陣，主 session 逐條對照核過並追加 AC41–45（Player Fantasy 判準與 Visual/Audio 的 PT／SS 證據）。

**AC 可測 ≠ story 解封**：ADR-0001／0002／0003 皆 Proposed，依 `docs/CLAUDE.md` 引用 Proposed ADR 的 story 自動 block。未設計依賴（#4／#7／#15）以 fake 介面自證本系統的消費紀律，不是整合契約。判準 4②（撲空對稱）歸 netcode，本節不列。

| AC | GIVEN | WHEN | THEN | 證據 |
|---|---|---|---|---|
| 1 | 站台 Idle，玩家送第一下 RPC；另一情境：claim 已成立，送手勢 RPC | Host 驗證 | ①第一下依序跑述詞①–⑥（錨點＝槽，C15），回傳 ∈ `RejectReason` 八成員（ADR-0002 七成員含 `Ok` ＋ `NothingToTake`），述詞本身只產生前七個 ②手勢的時刻判定只用 Host 收到 RPC 的 tick，client 自報時間戳一律不讀（C1） | T0 |
| 2 | 收銀 A 或 B 任一原型，`Matches()` 已判定 | 計算命中／不中 | 結果只依賴 {手上 SKU、訂單槽}，與經過的 ms 無關；`RejectReason`／`MatchResult` 不存在任何「太慢」變體（C2） | T0（原型未定，僅負向） |
| 3 | 微波 `Claimed → Working` 於 tick T0，`Sku` 已寫入、`microwave_cook_duration_sec` = 18 | 玩家全程不送 RPC，**在場站著不動**或離開皆可 | Host 於 `T0 + 180` tick 自轉 `Ready`，與在場無關；期間保險絲於 T0 + 50 到期只釋放 claim、Phase 仍為 `Working`（C10 r1）；轉態瞬間 `IsClaimed` 可為 false（C3） | T0 |
| 4 | 五台各自進入 Ready／判定情境 | 計時或判定完成 | ①微波 Ready 起 `microwave_burn_grace_sec` 無人收 → Spoiled ②咖啡同以 `coffee_overflow_grace_sec` ③收銀只有 `WrongFamily`／`WrongSku` 算刷錯 ④貨架只有該 sku 全域 0 算缺貨 ⑤關東煮狀態機不存在任何通往失敗態的邊（C4） | T0 |
| 5 | 任一手勢的樂觀動畫已開始（≤ 100 ms） | 播放期間 vs 承諾瞬間 | 播放期間 RPC 數 = 0；承諾瞬間恰 1 則；送出後不等 Host 回應即可播下一個本機動作（C5） | T0 |
| 6 | P 持有 claim | P 轉頭 180° 後送下一個有效動作 | Host 只評估述詞②③④；述詞⑥ 0 次被評估（C6） | T0 |
| 7 | 保險絲 5 s 於 tick N 啟動 | Host 到期前接受同一持有者的動作／Take RPC | 倒數自該 tick 重設為 5 s（C7）；到期時只 `IsClaimed → false`、gen+1，`StationStatus` 不變（C10 r1）——對照現行 netcode「從 lock 起算、無續期」今天會紅燈，**紅燈是預期**，levy 已登記 | T0（provisional） |
| 8 | S 被 X 持有，Phase ∉ {Ready, Spoiled} | Y ≠ X 對 S 送動作／Take | 述詞② 回 `Claimed`，Y 撲空，S 狀態欄位不變（C8） | T0 |
| 9 | Phase = Ready；fake `IOwnershipTransferer` 記錄呼叫 | 任意 Y 送 `TakeOutputRpc` | Host 跑①④⑤⑥、跳過②③（不讀 `ClaimedBy`／`ClaimGeneration`），通過即呼叫 `Transfer(instance, Y)` 恰 1 次（C9）；**若 `IsClaimed = true`、`ClaimedBy = X ≠ Y`，Take 後 `IsClaimed → false`、gen+1**（States r1） | T0 |
| 10a | 持有者於 `Working` 被強制釋放（保險絲到期或斷線） | 觸發 | `IsClaimed → false`、gen+1；**Phase 仍為 `Working`**、倒數不中斷、之後照常轉 `Ready`（C10 r1；r0 判 `Failed` 已廢止） | T0 |
| 10b | 持有者於 `Ready`／`Spoiled` 被強制釋放 | 觸發 | 實例保留、`PendingProductNetId` 不變、任何人可收（C10） | T0 |
| 10c | 持有者於 `Restocking` 被強制釋放 | 觸發 | `Restocking → Idle`，`stock_count` 不變，gen+1（E1） | T0 |
| 10d | 持有者於 `Working` 僅走開（仍連線） | 出 `station_leave_m` | 同 10a——走開與強制釋放在 Phase 上無區別（C10） | T0 |
| 10e | `shift_end_ts` 到達，各站台分別處於 `Working`／`Ready`／`Restocking` | Host 逐一套用 | `Working → Failed`（唯一的 `Failed` 觸發源）、`Ready`／`Spoiled` 實例保留、`Restocking → Idle` 不加庫存；之後本班站台 RPC 一律撲空（E1） | T0 |
| 11 | `stock_count[sku] = 1`，兩 client 同時對同 sku 送第一下 | Host 依序處理 | 先到者預扣 → 0；後到者評估到 0，同 tick 自我釋放回 `NothingToTake`（非 `OutOfReach`／`Claimed`）；`Restock` 完成把本架所有未滿 SKU 設為 3（E0.2 r1），已滿者不變（C11、E4） | T0 **必達** |
| 12 | client 送刷 RPC 自報 sku = X，Host ownership 查得實持 Y ≠ X；另兩情境：空手／查無實例 | Host 處理 | ①`Matches()` 一律用 Y；回傳 ∈ {Match, WrongFamily, WrongSku, Spoiled}，`Unevaluated` 0 次 ②空手 RPC 數 = 0 ③查無實例 → no-op、不消耗、不發訂單完成、撲空（C12、E5） | T0（跨 #6） |
| 13 | `Working → Ready` 或 `Ready → Spoiled` | `Create()` 並準備 spawn | `is_spoiled`／`network_index` 的寫入在 `Spawn()` 之前（fake spawner 記錄呼叫序）；Spawn 後 0 次寫入（C13） | T0 |
| 14 | Take 通過驗證；fake `IOwnershipTransferer` | Core 呼叫 `Transfer(instance, requester)` | 呼叫參數 = requester、緊接一次 `ReadOwner(instance)` 回讀確認（6a 的呼叫契約）；6-tick 冷卻起點 = 本次 transfer tick，非 Spawn tick（C13）。真正的 `ChangeOwnership`／`OwnerClientId` 行為由 T1 驗（r1：r0 標 T0 卻碰 NGO） | T0 |
| 15 | 微波 Working 已寫 `Sku` | 同站再收一次 `InteractRpc` | `Sku` 不被覆寫；client 已讀到 Working 時不送第二則（no-op＋輕撲空）（C14、E1） | T0 |
| 16 | 可互動體以 SKU 槽為單位，raycast 回 `(stationId, sku)` | Host 收帶 sku 的 RPC | ①只驗 `sku ∈ GetByMachineFamily(family)`，不重驗瞄準 ②Family 命中任一槽皆合法、Named 須命中指定槽 ③sku 不屬家族或已 `Deprecated` → no-op＋撲空，非安全事件（E0.1、E3） | T0 |
| 17 | 同一渲染幀 | 互動系統 Update 一次 | 對 interactable layer 恰 1 次、長 1.4 m、`QueryTriggerInteraction.Collide` 的 raycast；`(stationId, sku)?` 同時餵 HUD 與送出路徑，不存在第二條查詢（C15） | T1s（單機 PlayMode，r1） |
| 18 | 進行中手勢（Scanning／Restocking） | `visibilitychange` hidden | 轉接層直接呼叫 Core 中斷（call-order 斷言）；Input System `canceled` 0 次作為觸發源（C16） | T0 |
| 19 | 編譯後的 Interaction 模組 | 反射列舉 InputActionMap | 恰 1 個 `Interaction` map，動作集合恰為 `{Interact}`；同測試斷言 `Movement` 仍為 `{Move2D, Look2D}`（C17、FP AC1③） | T0 **必達** |
| 20 | `StationStatus.Phase` 兩次更新間未變；fake `IStationStatusWriter` 計數賦值 | Host 處理 | 值未變時賦值次數 = 0；確實改變則恰 1 次；型別中不存在 float `progress`（C18；`AreEqual` 短路是 NGO 行為，不在 T0 測，r1） | T0 |
| 21 | 開班的 Shift 場景 | lead 開 Hierarchy 截圖 | 0 個場景預置的站台 NetworkObject；五台只在 Play 時由 Host `Spawn()`（C18） | SS |
| 22 | Host 端全部狀態轉移 | 靜態列舉呼叫端點 | 除列舉定義處外，0 個非測試路徑以 `Faulted` 為轉移目標（C19） | T0 |
| 23 | 貨架某槽；本架另一 SKU 為 2/3 | 按下並放開 | ①`> 0` 短按（< 100 ms 放開）→ 恰 1 則 `InteractRpc(Interact)`，0 則 `Restock` ②`> 0` 按住 ≥ 100 ms → 第 2 則 `InteractRpc(Restock)`，Host 自走 4.0 s，完成時本架所有未滿 SKU = 3 ③`== 0` 按下 → 直接 1 則 `Restock` ④t < 4.000 s 放開 → `InterruptRpc`，`stock_count` 不變 ⑤全架皆滿時按住 → 0 則 `Restock`（E0.2 r1） | T0 |
| 24 | P 持有 A | P 對 B 送 claim | 同一次處理內先對 A 走開釋放（Working 不受影響／Restocking → Idle 不加庫存／收銀 Claimed 釋放），A 的 `ClaimGeneration + 1`；再評估 B：**B 回 `Ok` → P 持有 B；B 回非 `Ok` → P 持有 0 個，A 不恢復**（E0.3 r1 明寫的分支）；任何情況結束時 P 最多持有 1 個 claim（E0.3） | T0 **必達** |
| 25 | 站台 Idle，第一次有效按鍵 | Host 處理 | ①Shelf／Oden 同一次處理走完 `Claimed → Working → Ready → Taken → Idle`，Ok 回應時商品已在 requester ownership 下 ②微波／咖啡走到 Working ③收銀走到 Scanning；外部觀察者 0 次讀到產出家族的 `Claimed`（E0.4） | T0 **必達** |
| 26 | `IsClaimed` true → false 的任一轉移 | 提交 | `ClaimGeneration` 恰 +1；`Idle → Claimed` +0（States） | T0（跨 netcode） |
| 27 | 兩個 Shelf 槽顯示同一 sku | 任一槽 Taken 使其降到 0 | 兩槽同一 tick 鏡像 OutOfStock；任一補貨完成，兩槽同 tick 取消（E0.1、E4） | T0 |
| 28 | 收銀 Claimed，刷一件命中且填滿最後一槽 | — | `Claimed → Scanning → Claimed`；恰 1 次「訂單完成」；站台維持 Claimed（States B、E5） | T0 |
| 29 | 輸家本機 tick t0 收到 `InteractResponseRpc(Claimed)` | 贏家內插位置於 t1 進 `accept_radius_m` 1.1 m（r1：r0 的 0.8 讓 0.8–1.1 m 贏的人永遠觸發不了） | 撲空於 t1 播並對齊贏家位置；`t1 − t0 > 400 ms` 且未到 → 恰 400 ms 降級為無方向（States、F4） | T1（今天不可執行：需站台 prefab＋雙進程 harness，r1 標明） |
| 30 | R = 0.8、r_c = 0.30 | 述詞⑤ | 距離 = 1.1 m → Ok（邊界含）；1.10001 m → `OutOfReach`（F1） | T0 |
| 31 | L = 1.3 m | ①PassThrough 單次擠壓 0.6 m ②持有者距 1.3 m | ①0 次 `InterruptRpc` ②到達 1.3 m 當幀送 `InterruptRpc` ③`1.5 × 1.47 = 2.205 > 1.3` 記為可接受風險（F2） | T0（跨 FP／ADR-0003） |
| 32 | T_min／T_max、B、cook、grace **一律讀 registry 現值**（暫借 11／15、2、18／22、18／18；r1：r0 寫死借來的 T 是假綠燈） | 四不等式以 T 兩端點驗 | ①`cook ≥ T_max` ②`cook ≤ min(2·T_min + B, 30)` ③`grace ≥ T_max + B` ④不變式 `T_max ≤ 2·T_min + B`；現值下 18、22 ≥ 15 ✓／18、22 ≤ 24 ✓／18、18 ≥ 17 ✓／15 ≤ 24 ✓；另斷言 B 的安全上限 3 代入③仍成立（B = 4 會紅燈——這是 r1 把上限降為 3 的理由）（F3） | T0 **必達** |
| 33 | tick 10 Hz、RTT p95 300 | 算 floor 200、one-way 150 | 和 = 350，出貨 400；若 tick 改 20 Hz，floor 100、one-way 仍 150 → 250——斷言路徑是 `floor + one_way` 不是 `2 × floor`（F4） | T0 |
| 34 | 二名一值 = 3；本架另一 SKU 為 1/3 | 3 次 Take、無補貨；再 `Restock` | 3 → 2 → 1 → 0，第 3 次後 OutOfStock 鏡像；`Restock` 滿 4.000 s 後兩個 SKU 皆 = 3，任何路徑不超過 3（F5 r1） | T0 |
| 34b | `d_peak` 校準後 | 三班 playtest | 每班缺貨次數 ∈ [1, 2]（F5 機率主張，r1 自 AC34 拆出，不再掛在 T0 列下） | PT（provisional） |
| 35 | 假設 R 改 1.0 | 重算 | `interact_ray_length_m` 自動成 1.6，不停留於 1.4——純函式非獨立常數（F6） | T0 |
| 36 | Shelf／Oden 的 Working；`action_min_interval_ms`；單鍵台的 Ready | 量測／檢視 | ①Working = 0 tick ②`action_min_interval_ms`、按住補貨門檻與 `optimistic_anim_max_ms` 為同一常數引用（F8 r1） ③不存在 `ready_item_spoil_sec` 或等效欄位（F7–F9） | T0 |
| 37 | Phase = Ready，1 份 Fresh | 兩 client 同 tick 送 Take | 贏家跑①④⑤⑥ transfer 成功；輸家收 `NothingToTake`（非 `StaleGeneration`／`OutOfReach`），撲空 0 ms 立即播（E1） | T0 **必達** |
| 38 | Phase ∈ {Ready, Spoiled} | Host 收該站 Start；另一情境：寬限於 tick N 到期 | no-op＋撲空、不生成第二份；到期時同一出貨位 despawn Fresh、spawn `is_spoiled = true`，飛行中的 Take（以站台為目標）拿到換過的那份（E1） | T0 |
| 39 | 保險絲／寬限／補貨計時於 tick N 到期，同 tick 有相關 RPC | Host 處理 tick N | 先處理已抵達 RPC 再跑逾時掃描（`t ≤ timeout` 為逾時前）；補貨恰 4.000 s 到期同 tick 收放開 → 放開贏、不加庫存（E2） | T0 **必達** |
| 40 | fake `ICheckoutCustomerQuery` 於 N−1 回 V1、N 回 V2 或 null | Host 於 N 處理收銀的 `InteractRpc`（C20） | 用 V2 不用 V1；null → 不中：不消耗、ownership 不變、不發訂單完成、撲空（E5） | T0（provisional） |
| 41 | 遙測記錄每次燒焦／溢出／刷錯時機台是否在玩家視錐內 | 三班 playtest | 看著時失敗率 ≤ 5%（暫定，判準 1「接近 0」）；沒看時的失敗率隨班次下降 | PT |
| 42 | 新玩家、看著機台、無時間壓力 | 每台第一班 | 成功率 ≥ 9/10（判準 2）；收銀待 A/B 原型存在後才可排 | PT |
| 43 | 五台的 Working／Ready 提示音 | 閉眼辨台測試 | 辨台正確率 ≥ 9/10；微波 vs 咖啡於前 3 秒可辨（判準 3、Visual/Audio） | PT |
| 44 | 空排面、Spoiled 換件、五家族第三人稱姿態、Ready 光暈 | 3 m 外截圖 | lead 簽核「不看 HUD 可辨」（判準 3、Visual/Audio） | SS |
| 45 | 持有 claim 期間的鏡頭朝向遙測 | 三班內 | 鏡頭離開機台的時間比例上升而失敗率不上升（Player Fantasy 設計測試） | PT |
| 46 | 非持有者 P 自報 `(x, z, yaw)`；同一組輸入餵 Host 述詞⑤⑥與本機提示 | 比對 | 提示亮 ⇔ 本機⑤⑥通過 ⇔ Host ⑤⑥通過（同一純函式、同一輸入、錨點＝槽）；P 被推到 1.2 m 時提示滅（無遲滯）；持有者於 1.2 m 提示仍亮（C15、E3 r1） | T0 |
| 47 | 眼高 1.60、R = 0.8、r_c = 0.30 | 算 `slot_height_min_m` | = 1.60 − √(1.4² − 1.1²) ≈ 0.734；槽高 0.30 m 的槽在 1.1 m 處斜線 1.70 > 1.4 → 純函式回「不可達」；槽高 0.75 → 可達（F6 r1） | T0 |
| 48 | 站台 A `Working`，`ClaimedBy = X`、`IsClaimed = true`，X 站著不動 | 5.0 s 保險絲到期 | `IsClaimed → false`、gen+1、Phase 仍 `Working`，之後照常 `Ready`（與 AC3 相容；r0 的 AC10① 與 AC3 互斥，r1） | T0 |
| 49 | 持有者於 1.1–1.3 m 帶狀區 | 送手勢／Take | 述詞⑤不重驗、通過（E3；r0 矩陣未覆蓋） | T0 |

### 覆蓋矩陣

| 規則 | AC | | 規則 | AC |
|---|---|---|---|---|
| C1–C7 | 1–7 | | F1／F2／F3 | 30／31／32 |
| C8 | 8、24 | | F4 | 33、29 |
| C9／C10／C11／C12 | 9+48／10a–e+48／11／12 | | F5／F6 | 34+34b／35+47 |
| C13 | 13、14 | | F7–F9 | 36 |
| C14／C15／C16／C17 | 15／16+17+46／18／19 | | E0.1／E0.2／E0.3／E0.4 | 16+27／23／24／25 |
| C18 | 20、21 | | E1 | 37、38、10a–e |
| C20（RPC／資料契約） | 1、14、20（fake 接縫具名） | | E3 帶狀區／提示 | 46、49 |
| C19 | 22 | | E2 | 39 |
| 判準 1／2／3 | 41／42／43+44 | | E4／E5 | 11+27／12+40 |

**列在矩陣但今天寫不出可跑測試的**：E3 可互動體不重疊（站台座標不存在，#11／關卡佈局 Not Started）、E4 退款＋補貨同 tick（現行設計路徑不可達）——留作防遺忘，見 Open Questions。

## Open Questions

| # | 問題 | 擁有者 | 目標時點 |
|---|---|---|---|
| OQ-M1 | 收銀手勢 A/B（節奏按鍵 vs 對準掃描）；判準 2 的正向主張在原型存在前無法排 PT（AC42）；`checkout_scan_duration_sec` 分岔（F7） | game-designer ＋ prototyper | 收銀原型 T1 前 |
| OQ-M2 | `crossing_time_sec` T ∈ [11, 15] 暫借無出處（level-designer r1 估支柱 3 的店 T ≈ [6, 11]）；寬限 18 對 T_max 只有 1 s 餘裕，v 降 10% 即不成立；v 升到 1.62 咖啡 22 超出上界 0.04 s；重跑時必查不變式 `T_max ≤ 2·T_min + B`（F3 r1） | level-designer（blockout 實測 T_min／T_max 回填 registry） | blockout |
| OQ-M3 | `d_peak = 3` 未測量；每班缺貨 ∈ [1, 2] 只是 provisional（F5、AC34） | #7／#8 | 客流模型定案 |
| OQ-M4 | C7 續租：netcode 現行從 lock 起算、無續期；AC7 對現行紅燈 | netcode（levy 已登記） | netcode 修法 |
| OQ-M5 | 補貨與拿貨共用 claim 是否成尖峰瓶頸（C8 🔬）——若是，會修改「一次一人」 | playtest | 第一次 4 人 playtest |
| OQ-M6 | Ready 任何人可拿的社交摩擦「你搶我單」（C9 🔬） | playtest | 同上 |
| OQ-M7 | 隊友 `CharacterController` 會不會擋射線；margin = `r_c` 在極端俯仰角的充分性（C15、F6 🔬） | unity-specialist | 6.3 場景 T1 |
| OQ-M8 | 貨架／關東煮單鍵太瞬間、缺 Sensation 回饋（C2 🔬）——靠 #14／美術補 | #14、art-director | V/A 資產後 playtest |
| OQ-M9 | E3 可互動體不重疊、E4 退款＋補貨同 tick——今天寫不出可跑測試（AC 節） | 關卡佈局／本系統 | 站台座標存在後；F7 > 0 時 |
| OQ-M10 | ADR-0001／0002／0003 皆 Proposed → 引用它們的 story 自動 block（AC 節前言） | technical-director | 下次新 session `/architecture-review` |
| OQ-M11 | **已結案（r1）**：`SendTo.SpecifiedInParams` 於 NGO 2.13.2 `RpcTarget.cs:79` 確認存在（unity-specialist、network-programmer 原始碼核對） | — | — |
| OQ-M12 | **已結案（r1）**：`NetworkObject.cs:3410-3428 SynchronizeNetworkBehaviours()` 把 Spawn 前寫入的 NetworkVariable 值序列化進初始同步；T1 仍保留一條斷言 | — | T1 |
| OQ-M13 | Web 首次手勢音訊解鎖的責任分工 #12／#14（Visual/Audio） | #12、#14 | 大廳 UI 設計時 |
| OQ-M14 | **ADR-0004 範圍（r1 明列）**：C20 的 C# 簽章與型別、`AutoObjectParentSync = false` 契約（C13）、Core 測試接縫介面（`ISpawner`／`IOwnershipTransferer`／`IStockWriter`／`IStationStatusWriter`）、E2 逾時掃描掛 `OnNetworkTick` 的 Host 迴圈形狀、雙時鐘規則（Host tick 是真相、本機 dt 只管視覺）、`visibilitychange` 同源餵 ADR-0001 連續布林與 C16 邊緣事件的共享匯流排、registry `architecture.yaml` 簽章同步（OQ-M17） | technical-director | `/architecture-decision` |
| OQ-M15 | 本系統無獨立效能預算：每幀 1 次 raycast＋NetworkVariable 回呼，預期 < 0.1 ms／幀；T1 量到超過再回填。r1：unmanaged struct 的 NetworkVariable 走 bytewise memcmp、不 boxing、不需 `IEquatable`（unity-specialist 原始碼核對），GC 疑慮消解——`Sku`／`PendingProductNetId` 保持 blittable | performance-analyst | T1 |
| OQ-M16 | Web 音訊：rolloff floor、pan 在 Unity 6000.3 Web build 的實際行為（AudioMixer 只剩音量、`spatialBlend` 不支援，已由手冊確認）；一小時探針 | #14、audio-director | #14 動工前 |
| OQ-M17 | registry `architecture.yaml` 的 `RequestInteractRpc(stationId, claimGenerationSeen, selfX, selfZ, selfYawDeg)` 與 C20 不同步（缺 `sku`、`action`） | technical-director | ADR-0004 |
| OQ-M18 | E0.2 r1「先拿後補」的體感（玩家只想補貨卻先拿到一件）；收銀 A/B 評選加「可預期節奏」（錨點「同一個拍子」）與支柱 2 真實動作對應度；關東煮零風險站的常駐躲藏（占比上限已 levy #7）；2 人房單人多線負載量測 | game-designer、playtest | 第一次 4 人 playtest |

## r1 修訂紀錄（2026-09-29）

`/design-review` full：九位專家（game-designer、systems-designer、qa-lead、network-programmer、gameplay-programmer、unity-specialist、ux-designer、audio-director、level-designer）＋creative-director 綜合。判決 **NEEDS REVISION**；專家共約 20 條 BLOCKING，CD 校準後留 7、真紅燈 5；FP 那輪 42 條留 1，專家校準明顯變好。arlong 四項裁決：E0.2 選「點按拿、按住補整架」、斷線也只放 claim、F3 保留公式＋支柱 5 硬帽、完整變更集。本 session 接著修，評審紀錄只能寫「作者宣稱已處理」。

| # | 阻擋項 | 修法落點 |
|---|---|---|
| 1 | C7×C10：保險絲到期判 `Failed`，守在微波前的人被懲罰；AC3 與 AC10① 互斥 | C10 重寫、States 表 A、E1、AC3、AC7、AC10a–e、AC48；`Failed` 只剩 `shift_end_ts` |
| 2 | 判準 4 幾何四處靜默失效（撲空門檻 0.8 vs 接受 1.1；非持有者遲滯；偏心槽 `NotFacing`；低槽射線不及） | States 撲空順序改 `accept_radius_m`；C15 提示＝本機⑤⑥、錨點＝槽；E3；F6 槽高下限；UI 約束 1；AC29／46／47／49 |
| 3 | E0.2 只能補 0 的槽拆掉「靜→爆」 | E0.2／C11／F5／F8／States／AC11／AC23／AC34 改為點按拿、按住補整架；`action` 欄位；levy #17 教學 |
| 4 | RPC／資料契約自稱定形其實沒有（五個 RPC 名、`FamilyParam` 無來源、`StationStock` 未定義、`PendingProductId` 未接） | 新 C20 語意表；C14 `Sku`；C13 `PendingProductNetId`；AC 接縫具名；OQ-M14／M17 |
| 5 | 耳朵頻道交付面空缺（撲空觸發源與 ADR-0002 D5 矛盾；收銀第二刷起無 NV 變化；Web 混音只有音量；收銀站聽障盲區） | Interactions #14 拆兩種觸發源；C20 `InteractResponseRpc`；V/A 混音落地註記＋Web 限制（手冊已驗證）；UI 約束 8；levy #11／#7 |
| 6 | 狀態機回掃（表 B 缺 `Claimed → Idle`；C8 vs C9；`Taken` 是否踢掉持有者；OutOfStock 無聲） | 表 B 補三條邊；C8 限定 Ready 之前；`Taken` 清 claim 明寫；OutOfStock 改「見底」一聲 |
| 7 | F3：T 暫借無出處、B = 4 破 grace 不等式、v = 1.62 咖啡超界、AC32 假綠燈 | `min(2·T_min+B, 30)`、B 範圍 1–3、grace 範圍寫成式子、不變式、AC32 讀 registry |

一句話級 Recommended 已一併套用：`AutoObjectParentSync = false`、掛靠到達序容忍、斷線偵測真實延遲、E2 綁 `OnNetworkTick`、C18 覆述前提、`QueryTriggerInteraction.Collide`、`NetworkTime.TimeAsFloat`、F4 回填觸發、F5 機率主張、`RejectReason` 用語、OQ-M11／M12／M15 結案、AC9／14／20 fake 接縫、AC17 T1s、AC24 分支、AC34b、音訊資產數量級。**未套用、留下一輪**：AC1／AC16 子句拆分；V/A「不得」與 UI 約束的 SS 簽核清單；撲空「近場不廣播」的理由；「啊」變體資產表。

**下一步（CD）**：不再開散文評審輪——寫純 C# 站台狀態機跑 T0（54 條 AC 中約 40 條 T0），`/architecture-decision` 產 ADR-0004，level-designer blockout 量 T。
