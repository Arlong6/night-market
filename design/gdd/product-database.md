# 商品資料庫 (Product Database)

> **Status**: In Design
> **System**: #6（Core / Foundation / MVP）
> **Author**: arlong + design-system skill
> **Last Updated**: 2026-09-19
> **Implements Pillar**: 支柱 2「台灣人秒懂」（主）、支柱 1「忙得有節奏」（次）
> **Concept**: `design/gdd/game-concept-night-shift.md`
> **Systems Index**: `design/gdd/systems-index.md`

## Overview

商品資料庫是本作所有「可被玩家操作的品項」的**單一真相源**。每一筆資料描述一樣商品的
身份（它是什麼、屬於哪個機台家族）、它在店裡的取得路徑（從哪裡拿、要不要加工），
以及它被端到客人面前時算不算數。

機台互動組（#5）、客人系統（#7）、評分邏輯（#15）三個系統**都不自帶商品知識**，
一律向這張表查詢：客人的需求是一個商品 ID，機台的產出是一個商品 ID，評分比對的是
兩個 ID 是否相符。這使得「加一樣新商品」是改資料，不是改程式碼——正是編碼標準
「Gameplay values must be data-driven, never hardcoded」在本作的落點。
⚠ **但「不用改程式碼」不等於「不用重出 build」**：SKU 表隨主 build 一起序列化出貨，
新增品項仍必須重新出一次 Web build 才會出現在玩家手上。要做到免出 build 的內容更新，
需要 Addressables 遠端目錄＋一個內容 host，那是獨立於本 GDD 的技術決策（見 Open Questions）。

**範圍刻意畫得很窄**：只有「能被撈起、加熱、刷條碼、補上貨架」的品項進表，
估 20-40 筆。貨架上那幾百個商品排面依美術聖經 §5.1 是單張共用圖集的貼圖，
**不是資料**——它們負責「像超商」，不負責「被玩」。這一刀讓資料庫維持在系統索引
標定的 S 規模，也讓 44MB 的體積硬標不會被品項數吃掉。

而在玩家那一側，這個系統**從頭到尾不會被看見**。玩家感受到的是另一件事：走進店裡，
架上是茶葉蛋、黑輪、米血、飯糰、大熱狗、冰沙——每一樣都是他自己在凌晨三點
買過的東西，而且**不屬於任何一家**（反支柱 `NOT 真實品牌`）。支柱 2「台灣人秒懂」的設計測試（*一個新內容若需要說明書才懂 →
換成大家都親身經歷過的真梗*）實際上就是這張表的**准入門檻**：判準不是「這個商品
有趣嗎」，而是「台灣人看到它需不需要被解釋」。

反支柱在這裡劃了另一條線：本作 **NOT 寫實經營模擬**。表裡不會有進貨成本、利潤率、
庫存損益這類欄位；商品的價值只以它對當下這一單的貢獻衡量，不以金錢衡量。
（商品是否需要帶一個純演出用的售價供結帳畫面顯示，見 Open Questions。）

## Player Fantasy

這是一個**間接型**幻想：玩家永遠不會看見這張表，就像他不會看見自己腦裡那份
「便利商店有賣什麼」的清單。他會知道的是——**這鍋湯他撈過。**

**錨點時刻**：尖峰。你卡在咖啡機前抽不開身，微波爐在叫，第三個客人按鈴。
你頭也不回，往後喊一聲「**米血！兩串！**」——三秒後有隻手從你肩膀旁邊伸過來，
串好的放進盒子。你沒有回頭確認過那是誰，也沒有解釋過米血長什麼樣子。
**這一局裡沒有一個人需要問「那是什麼」。**

這張表不是給程式查的，是給**隔著兩排貨架的隊友喊的**。情緒是默契。

**准入門檻（本節唯一的硬產出，可證偽）**：一筆 SKU 必須通過「隔著貨架喊」測試——

1. **2-3 個音節喊得完**；
2. **對方不看畫面就知道是什麼**；
3. **不與表內任何其他品項聽錯**（「米血」與「米糕」不得同場入表）；
4. **台灣人秒懂，但不屬於任何一家**（反支柱 `NOT 真實品牌`）。

**邊界**：難度歸動線與時間，不歸解讀。任何讓人停下來想半秒的品項，
都是從尖峰偷走半秒——**那半秒是支柱 1 的**。

**本節不負責**：貨架上幾百個排面的辨識感由美術聖經 §5.1 的共享圖集負責，
不在本表射程；機台的撈／按／刷手感歸 #5 機台互動組；客人的語氣與個性歸 #7 客人系統。

## Detailed Design

### Core Rules

#### 規則 1：一筆 SKU 的欄位集合

| 欄位 | 型別 | 範圍 | 用途 | 誰讀它 |
|---|---|---|---|---|
| `sku_id` | string (snake_case) | 專案內唯一，**永不改名** | 設計期權威識別鍵；GDD、registry、文件互相引用都用它 | 人；不進封包 |
| `network_index` | byte | 0-255，循序指派，**永不重用** | 封包裡的實際識別碼 | 網路同步層、#4、#5、#7、#15 |
| `display_label` | string ≤6 漢字 | — | **這就是玩家隔著貨架喊的那個名字**，Player Fantasy 四條准入門檻即對本欄位生效；同時用於開發／QA／#13 結算逐項列表。**不含客人 NPC 的口白台詞**（那是 #7／#14 的內容，本表不定義） | 內容作者、QA、#13、准入審查 |
| `machine_family` | enum {`Shelf`,`Oden`,`Microwave`,`CoffeeMachine`} | 固定 4 值 | **三重用途**：#5 查自己的菜單／#7、#8 依站台配重抽樣／#11 查家族級 HUD icon | #5、#7、#8、#11 |
| `nameable` | bool | — | 這筆 SKU 是否可被「指名客」點名。**true 才需要專屬 icon 資產** | #7（抽指名需求）、#11（icon）、內容審查 |

**刻意不存在的欄位**：成本、售價、利潤、庫存量、取得路徑分類、組合配方、加工時間閾值。
前四項由反支柱 `NOT 寫實經營模擬` 擋掉（含「剩幾個」——庫存是 #5 貨架站台的運作狀態，
不是商品身份）；取得路徑可由 `machine_family` 完全推導，獨立欄位是對同一件事問兩次，
兩個欄位遲早漂移；後兩項歸 #5。

#### 規則 2：兩層 ID，各司其職

- **`sku_id` 是權威身份**。一旦上線永不改名。品項下架時**不刪除，標成 `deprecated`**
  ——比照 `design/registry/entities.yaml` 現行慣例，理由相同：避免殘留引用變成幽靈字串。
- **`network_index` 是線路身份**。新增時取下一個未用過的整數；**下架後號碼永久保留、
  不重新分配**。

**為什麼線路上不必傳字串**：這張表不需要跨端同步。它隨 build 一起序列化出貨，
而所有人從同一個連結進同一個 build，兩端內容保證一致。RPC 只需要傳「表格第幾格」。
這也順帶回答了「商品資料庫要不要接網路同步層」——**不要**，它是載入期就固定的靜態內容，
不是執行期狀態。

**版本一致性不需要另建防線**：netcode GDD 的 `[P-17]` 版本閘在任何資料交換之前就會擋下
build 不符的 client。因為 SKU 表與遊戲邏輯是同一份 build 出來的，**不存在「build 版本
一致但 SKU 表不一致」的中間態**。本 GDD 只引用既有版本閘，不發明第二套。

#### 規則 3：需求分兩級（家族級為主，指名為輔）

客人的需求有兩種：

- **家族級需求**（多數）：「一份關東煮」——`machine_family == Oden` 的任何 SKU 都算對。
  HUD 用既有的家族 icon。
- **指名需求**（少數）：「米血」——必須是那一筆 SKU。**只有 `nameable == true` 的品項
  可以被指名，而每一個都必須配一個專屬 icon 資產。**

指名需求的出現比例是 #7／#8 的旋鈕，不是本表的欄位。

`nameable` 有一個刻意的副作用：**它是內容配額的天然剎車**。想讓一樣商品可被指名，
就得畫一個新 icon——成本落在提出需求的人身上，而不是默默膨脹。

#### 規則 4：單一真相源的射程

**必須只在這裡定義**：SKU 身份（兩層 ID）、`machine_family` 歸屬、`ProductInstance`
的欄位形狀、以及「兩個東西算不算相符」的判定純函式。

**明確不歸這裡**：貨架排面視覺（美術聖經 §5.1 共享圖集）／加工手感與計時（#5）／
客人想要什麼、波次怎麼組（#7、#8）／星級怎麼算、耐心怎麼扣（#15）／庫存與過期
（#5 貨架站台）／icon 圖形資產本身（#11，本表只提供查詢鍵）。

### States and Transitions

商品資料庫本身**沒有執行期狀態**——它是載入期就固定的靜態表。本節描述的是兩個狀態空間，
兩者都不是「資料庫的狀態」。

**A：SKU 條目的編輯期生命週期**

| 狀態 | 意義 | 轉移 |
|---|---|---|
| `active` | 可被機台產出、可被需求抽中 | → `deprecated` |
| `deprecated` | 下架。ID 與號碼永久保留，不再被抽中也不再被產出 | **終態**——不得復活成新意義 |

執行期不會改變。存在的唯一理由是規則 2 的「永不重用」。

**B：商品實體的執行期狀態**

玩家手上那一份不是資料庫的一列，是一個兩欄位 struct：

```
ProductInstance { network_index: byte, is_spoiled: bool }
```

| 狀態 | 意義 |
|---|---|
| Fresh（`is_spoiled == false`） | 可以交付，能滿足需求 |
| Spoiled（`is_spoiled == true`） | 不能滿足任何需求（無論商品對不對） |

轉移**只有一個方向，而且不由資料庫執行**：Fresh → Spoiled，由產出它的機台（#5）
在交出成品時蓋章。沒有反向轉移（燒焦的便當不會自己好起來），沒有中間態。

**為什麼加工狀態機不在這裡**：微波是計時持續按、關東煮是撈起瞬間完成、
咖啡機是沖煮等待——三種形狀天差地遠。硬塞同一張通用狀態表只有兩種下場：
表被迫長出「只有某幾筆 SKU 用得到」的欄位（微波專屬燒焦閾值、咖啡專屬溢出閾值），
自己分裂成好幾種形狀；或為了統一做成好／壞二元——那就等於現在這個方案，
只是多一層無用的間接。

更根本的是分層：加工手感是系統索引標的**高風險高迭代**項。若閾值寫在 Foundation 層，
每次手感調校都要回頭改上游。**上游穩定、下游易變，這條不能倒過來。**

**代價（明講）**：沒有「有點焦但還能吃」。這是刻意的——多一個中間態就要回答
「它算不算符合需求、算幾星」，那是 #15 星級公式變複雜的起點，而本作不是精細評分模擬。

**什麼時候會反咬**：Alpha 期若新增一台形狀不同的機器（現烤地瓜、代收包裹），
走另一條路（狀態機在資料庫）會被迫回頭改 Foundation schema；走這條不會——
新機器自帶自己的狀態機，最後一樣蓋一個 `is_spoiled`。

### Interactions with Other Systems

對外只有三個唯讀查詢加一條純函式，**沒有任何系統寫入資料庫**：

```
IProductCatalog
    Get(network_index)              -> ProductEntry
    GetByMachineFamily(family)      -> IReadOnlyList<ProductEntry>
    GetOrderable()                  -> IReadOnlyList<ProductEntry>
    Matches(instance, demand)       -> bool
```

介面是**純 C# interface，不是 MonoBehaviour、不是單例**。正式資料以 ScriptableObject
資產承載，但下游只依賴這個介面——#15 的測試自己組一個假 catalog，不載入正式資產、
也不啟動場景。

| 系統 | 流進 | 流出 | 介面擁有者 |
|---|---|---|---|
| #5 機台互動組 | `GetByMachineFamily()` 決定菜單 | 建立 `ProductInstance`、蓋 `is_spoiled` | DB 擁有查詢與 struct 形狀；#5 擁有執行期實例化與狀態邏輯 |
| #7 客人系統 | `GetOrderable()`、`nameable` | 無 | DB 提供字典；**抽樣權重、偏好、指名比例全歸 #7／#8** |
| #15 評分邏輯 | `Matches()` | 無 | DB 提供單槽判定；**聚合成星等完全歸 #15** |
| #11 HUD 與需求 icon | `machine_family`／`network_index` | 無 | DB 只給查詢鍵，圖形資產歸 #11 與美術 |
| #4 攜帶與交付 | 搬運 `ProductInstance` | 無 | DB 只定義 struct 形狀 |

**關鍵釐清——`ProductInstance` 不是 NetworkObject**：netcode GDD 的
`RequestHandoff(itemId, targetId)` 裡的 `itemId` 與本表的 SKU 身份**極可能是兩個
不同的東西**。交接操作的是一個已經 spawn 的 NetworkObject 實例（**哪一個**），
SKU 是資料表的列（**哪一種**）。SKU 應是該實例上的唯讀欄位、spawn 時設定好，
接收端本地查一次即可，不需每次交接重傳。與 #5 對齊時須寫明。

**需求結構（本表定義形狀，內容歸 #7）**：

```
CustomerDemand { kind: {Family|Named}, family: machine_family, network_index: byte }
CustomerOrder  { slots: CustomerDemand[] }
```

「兩串米血」是**兩個都指向米血的槽**，不是一個帶 `qty=2` 的槽。這與本專案
`game-session-state.md` 已進 registry 的 `slots_in_vignette` 模式一致，
並且避開「交了一份還差一份」的部分完成狀態。

**修飾語（「加酸黃瓜」）不做成資料結構**。若某個口味變體真的有玩法效果，
它應該是**一筆獨立的原子 SKU**，且必須自己通過 Player Fantasy 的四條准入門檻；
若只是台詞風味，它只能活在 #7 的口白層，不得進入判定。
另註：「大熱狗一支，加酸黃瓜」這個例子**本身就違反門檻第 1 條**（2-3 音節喊得完）
——若真心想要修飾詞玩法，正確做法是回頭修改 Player Fantasy 的准入標準，
而不是繞過它加在資料結構裡。

## Formulas

本系統只有一條公式。它是一個純函式，沒有數值參數、沒有可調權重——所有加權與聚合都在 #15。

`Matches` 判定「一份商品能不能滿足一個需求槽」：

```
Matches(instance, demand) =
    (instance.is_spoiled == false)
    AND (
          demand.kind == Family
        ? Get(instance.network_index).machine_family == demand.family
        : instance.network_index == demand.network_index
    )
```

**變數**

| 變數 | 型別 | 範圍 | 說明 |
|---|---|---|---|
| `instance.network_index` | byte | 已登錄且 `active` 的 SKU 之一 | 實際交付的那一份商品的身份 |
| `instance.is_spoiled` | bool | {true, false} | 由產出它的機台（#5）蓋章。**資料庫定義這個欄位存在，但從不寫入它** |
| `demand.kind` | enum | {`Family`, `Named`} | 這個需求槽是家族級還是指名 |
| `demand.family` | enum | 4 值 | `kind == Family` 時有效 |
| `demand.network_index` | byte | 已登錄 SKU 之一 | `kind == Named` 時有效；該 SKU 的 `nameable` 必須為 true |
| 回傳 | bool | {true, false} | 刻意二元，**無部分分數、無近似匹配** |

**輸出範圍**：布林。不夾取、不加權、無中間值。

**為什麼不做近似匹配**：Player Fantasy 的准入門檻第 3 條已經要求 SKU 之間**刻意不可能
混淆**。若判定又對「接近但不對」給部分分數，等於在懲罰邏輯裡引入一個資料庫本身宣稱
不該存在的模糊地帶——自相矛盾。近似匹配只在「品項本身容易混淆」的遊戲裡有意義，
本作明確不是。

「送對大半也該有分」的體驗改由**訂單內槽位命中率**表達（`已命中槽數 / 總槽數`），
不改動單槽判定的嚴格度。該聚合公式歸 #15，不在本文件。

**Worked examples**

| # | instance | demand | 結果 | 理由 |
|---|---|---|---|---|
| 1 | 米血, fresh | Family: `Oden` | **true** | 家族相符 |
| 2 | 黑輪, fresh | Family: `Oden` | **true** | 同家族，家族級需求不分哪一串 |
| 3 | 咖啡, fresh | Family: `Oden` | **false** | 家族不符 |
| 4 | 米血, fresh | Named: 米血 | **true** | 指名命中 |
| 5 | 黑輪, fresh | Named: 米血 | **false** | 同家族仍不算——指名就是指名 |
| 6 | 米血, **spoiled** | Named: 米血 | **false** | 品項對，但壞了 |
| 7 | 米血, **spoiled** | Family: `Oden` | **false** | `is_spoiled` 先短路，家族對也沒用 |

第 2 列與第 5 列並列是這條公式的重點：**同一份米血，在家族級需求下可被黑輪替代，
在指名需求下不行。** 這正是「家族級為主、指名為輔」在程式上的全部差異。

### 槽位分配規則

`Matches()` 的定義域只到「單槽 vs 單商品」。當一份商品**同時被同一張訂單的多個槽接受**時
（訂單 `[Family:Oden, Named:米血]` 收到一份新鮮米血），公式本身不回答該消耗哪一槽。
補充規則：

```
消耗優先序 = Named 先於 Family
同優先序內 = 取 slots 陣列中索引較小、且尚未填滿的槽
一份商品只消耗一槽
```

理由與推演見 Edge Cases 節「雙模式判定」。本規則的程式歸屬是 #15（或 #4 的交付判定點），
不歸本表，但它存在的理由直接源自本表定義的 `demand.kind` 語意——**在此記載是為了讓
#15 設計時不會重新發明一套不一致的優先序。**

## Edge Cases

### 雙模式判定

- **若一份商品同時符合訂單裡不只一槽**（訂單 `[Family:Oden, Named:米血]`，交出新鮮米血）：
  **Named 優先於 Family；同優先序內取 `slots` 陣列索引較小且尚未填滿的槽。**
  理由：Named 是稀缺資源、Family 是彈性資源。若 Family 先吃，而整個波次只會出一份米血，
  Named 槽就永遠等不到第二份，訂單變成**不可能完成**；Named 先鎖定則 Family 槽事後
  可被任何黑輪、貢丸補上。**稀缺的先鎖定，才不會浪費彈性資源的替代能力。**
  （本規則同時記於 Formulas 節「槽位分配規則」。）
- **若訂單有兩個 Named 槽指向同一 SKU**（「兩串米血」）：第一份填索引較小的槽，
  第二份填另一槽——**一份商品只消耗一槽**，對應「你只交出一件東西」。

### 內容合法性（一律擋在建置期，不做 runtime 降級）

- **若某 SKU `nameable == true` 但找不到專屬 icon 資產**：**視為內容錯誤，擋建置。**
  icon 資產命名綁定 `sku_id`（`Ui_Icon_[sku_id]`），一條 EditMode 測試掃描所有
  `nameable == true` 條目確認對應資產存在。理由：`nameable` 的設計目的就是當內容配額的
  剎車，**剎車失靈（宣稱可指名卻沒配 icon）比放行更危險**，必須硬擋而非軟降級。
- **若兩筆 `active` SKU 的 `display_label` 相同**（大小寫、全形半形正規化後比對）：擋建置。
  雖然它不參與 `Matches()` 判定，但會出現在 #13 結算畫面的逐項列表上——讓玩家讀到兩個
  一樣的字樣卻對應不同商品，違反准入門檻第 3 條的精神。
- **若某 `machine_family` 底下一筆 `active` SKU 都沒有**：擋建置。那代表對應機台變成
  一個造不出任何東西的空殼站台。須有常駐 EditMode 測試檢查「4 個家族每個都 ≥1 筆 active」。
- **若其他資料表（波次配置、教學腳本）引用了已 `deprecated` 的 `sku_id`**：擋建置。
  這是 deprecation 的**唯一真實風險**——runtime 不可能遇到指向 `deprecated` 的需求，
  因為 #7 只能從 `GetOrderable()`（只回 `active`）抽樣，且 SKU 表隨 build 靜態出貨，
  一個班次全程使用同一份表（重連亦然，重連只重新同步既有執行期狀態）。

### 介面契約（刻意快速失敗，不優雅降級）

- **若 `Get()` 查詢一個 `deprecated` 條目**：**完整回傳該筆資料，不丟例外、不回 null。**
  `Matches()` 內部會呼叫 `Get(...).machine_family`，這個保證確保任何合法輸入都不會讓
  判定邏輯意外拋錯而讓交付流程當機。**deprecated 是選拔池的濾網，不是資料存在性的開關。**
- **若 `Get()` 收到從未被指派過的 `network_index`**（垃圾值或封包損毀）：
  **直接 assert／丟例外，不靜默降級、不回傳假資料。** `ProductInstance` 只應由
  host-authoritative 的 #5 建立；讓它安靜通過只會把 #5 或序列化層的真 bug 藏到更下游、
  更難定位的地方才爆炸。
- **若 `GetByMachineFamily()` 查一個零筆 `active` 的家族**：回傳空陣列，不丟例外。
  DB 的契約是誠實回報「沒有」，不保證「一定有」；呼叫方（#8）有義務在抽樣前檢查非空。

### 刻意不處理

- **`network_index` 255 格用完**：不設計 runtime 分支。MVP 20-40 筆、Full Vision
  內容量表（4 店型／10+ 服務／12+ 客人，且互動層 SKU 定義刻意窄縮）保守估計全內容
  生涯遠低於 100 筆，含 `deprecated` 永久燒掉的號碼亦然。真逼近上限的修法是型別換
  `ushort`——一行 wire-format 改動，既有數值原樣放進更大型別，不需資料遷移。
  **為機率趨近於零的情境設計執行期路徑，正是本文件一路在警戒的過度設計。**
- **槽位是否已被填過**：`Matches()` 是無狀態純函式，對同樣輸入永遠給同樣答案。
  槽位佔用狀態歸 #15／#4 自己維護，明確不在 DB 射程。
- **場上現在有幾份某 SKU 存在**（供給稀缺性、多名玩家搶同一份指名商品）：本表完全不追蹤。
  `Matches()` 只判斷「已送到手上的這一份」合不合格，稀缺性與競爭仲裁歸 #4／#5／#7。
- **零槽訂單**：本表只定義容器形狀，不設下限約束；是否允許由 #7 自行決定。

## Dependencies

### 上游（本系統依賴誰）

**無。** 商品資料庫是 Foundation 層、零上游依賴——這正是它能排在第二個設計的唯一理由。
它**不接網路同步層**（規則 2：靜態表不跨端同步）、不接遊戲時鐘、不接任何執行期系統。

唯一的非執行期耦合有兩處：美術資產（icon／模型／音效）依 `sku_id` 命名綁定；
以及 netcode GDD 的 `[P-17]` 版本閘——**引用，不重建**。

### 下游（誰依賴本系統）

| 系統 | 強度 | 介面 | 系統索引已宣告 |
|---|---|---|---|
| #5 機台互動組 | **硬**——沒有它機台不知道自己能產出什麼 | `GetByMachineFamily()`、建立 `ProductInstance` | 是 |
| #7 客人系統 | **硬**——沒有它客人不知道能要什麼 | `GetOrderable()`、`nameable` | 是 |
| #15 評分邏輯 | **硬**——沒有它無法判定對錯 | `Matches()` | 是 |
| #4 攜帶與交付 | **硬**——它搬運的就是 `ProductInstance` | struct 形狀 | **否** |
| #11 HUD 與需求 icon | **硬**——icon 查詢鍵來自本表 | `machine_family`／`network_index` | **否** |
| #13 結算畫面 | **軟**——逐項列表用 `display_label`；缺它仍可顯示星等 | `display_label` | **否** |
| #8 波次導演 | **軟**——依站台配重抽樣；退化成均勻抽樣仍可運作 | `GetByMachineFamily()` | **否**（推得，非明文） |

### 雙向一致性檢查

四條未宣告：#4、#11、#13、#8。

**這不是索引寫錯。** 這四條依賴在「商品資料庫要提供什麼」定案之前無法預見——
#4 要搬什麼、#11 要畫什麼 icon、#13 要列什麼字，全都是本 GDD 才定下來的。
其中 **#11 HUD 這條最值得注意**：它之所以浮出來，是因為「家族級＋指名」的裁決把
icon 選擇邏輯綁進了商品表；在那之前 HUD 確實只需要認識客人系統。
**這是一個裁決長出一條新依賴的例子，不是原本就漏掉的。**

系統索引的依賴圖於本文件落稿後一併更新。

## Tuning Knobs

本系統幾乎沒有旋鈕。所有數值都在 #5／#7／#8／#15，本節**不複製別人的旋鈕**，只指向真相源。

### 本系統擁有的旋鈕

本表唯一可調的東西就是**它自己的內容**。內容即旋鈕：

| 旋鈕 | 型別 | 安全範圍 | 調太高會怎樣 | 調太低會怎樣 |
|---|---|---|---|---|
| SKU 總筆數 | int | 20-40（MVP） | 尖峰可讀性下降、美術資產線性增加；理論上限 255（`network_index` 型別） | 低於約 12 筆時四個家族撐不出變化，波次重複感明顯 |
| 每家族 `active` 筆數 | int | **≥1（硬性）** | 同家族內差異模糊，家族級需求失去意義 | **0 = 建置失敗**，該機台變空殼站台 |
| `nameable == true` 的筆數 | int | 待定案（見 Open Questions） | **每一筆都必須配一張專屬 icon**，直接換算成美術工時 | 為 0 時「指名客」這個客人類型不存在，退化成純家族級 |
| `display_label` 長度 | int | ≤6 漢字 | #13 結算畫面逐項列表排版溢出 | — |

`nameable` 筆數的上限**不在本表定案**：它由美術（幾張 icon 畫得完）與 #7（指名客佔比
多少才有趣）共同決定，本表只負責**讓這個成本可見**。

**作業慣例（`nameable` 的預設值）**：新建 SKU 條目時 `nameable` 一律預設 `false`，
**只有在專屬 icon 資產進 repo 的同一個 commit 才翻成 `true`**。
這條慣例的作用是讓 AC4 的建置檢查不會在資產尚未畫完的早期誤報——
早期條目本來就該是 `false`。一旦有人宣稱可指名卻沒配 icon，紅燈立刻出現，
**那正是設計要的行為**。刻意**不**為此新增第三種「草稿中」狀態，
以免讓規則 2 的兩態模型長出未經定義的轉移分支。

⚠ **「SKU 總筆數 20-40」這個範圍是估的，不是推導出來的。** 真正能決定它的是
「一個家族內要有幾種東西，玩家才會覺得有變化但不會混亂」——那是 #7 與 #8 設計時
才量得出來的。此處寫成旋鈕而非定論，就是為了留這個口。

### 不屬於本系統、但受本表約束的旋鈕

| 旋鈕 | 真相源 | 本表的約束 |
|---|---|---|
| 指名需求出現比例 | #7 客人系統／#8 波次導演 | 只能從 `nameable == true` 的池子抽 |
| 各站台需求配重 | #8 波次導演 | 只能用 `machine_family` 的 4 值分類 |
| 加工時間、燒焦閾值、溢出閾值 | #5 機台互動組 | 本表不持有任何時間常數 |
| 星級門檻、耐心扣減 | #15 評分邏輯 | 本表只提供 `Matches()` 的布林輸出 |
| 每張訂單槽數 | #7 客人系統 | 本表只定義 `slots` 是陣列，不設上下限 |

## Visual/Audio Requirements

本系統不產生任何畫面或聲音。它產生的是**一份資產清單與一組命名約束**——每筆 SKU 上線時
必須有對應資產存在，命名由 `sku_id` 綁定（Edge Cases 的建置期檢查即靠此綁定運作）。

| 資產 | 顆粒度 | 規格來源 | 命名 |
|---|---|---|---|
| 手持模型 | 每筆 SKU | 美術聖經 §8.2（**級距未定，見 Open Questions**）、§8.4 Simple Lit、§5.1 互動層**禁貼圖** | `Mesh_[sku_id]` |
| 家族需求 icon | **每個 `machine_family` 一個，非每筆 SKU** | §3.3：單色剪影 64×64、白描邊、透明背景，進共享 `Atlas_Ui`，不用文字 | `Ui_Icon_[family]` |
| 指名需求 icon | **僅 `nameable == true` 者** | 同上 | `Ui_Icon_[sku_id]` |
| 取得音效 | 依機台家族共用，非每筆 SKU | 歸 #14 音效系統 | — |

**本表施加的美術約束**：互動層**禁貼圖**（美術聖經原則 2；§5.1 射程限縮後仍適用於互動層）。
商品的辨識度必須由**形狀與色塊**承擔，不能靠包裝圖案——這與准入門檻第 2 條
「對方不看畫面就知道是什麼」互為表裡：**若一樣商品非得看到包裝印刷才認得出來，
它本來就不該進表。** 背景層排面不在本表射程（§5.1 共享圖集）。

**已知缺口**：家族需求 icon **缺兩個**（`Microwave`、`Shelf`）。見 Open Questions。

📌 **Asset Spec** — Visual/Audio 需求已定義。美術聖經核准後，執行
`/asset-spec system:product-database` 產出逐資產的視覺描述、尺寸與生成提示。

## UI Requirements

**本系統沒有自己的 UI。** 它對兩個 UI 系統各貢獻一個欄位：

| 消費者 | 本表提供 | UI 決策歸誰 |
|---|---|---|
| #11 HUD 與需求 icon | 家族級用 `machine_family`、指名級用 `network_index` 當 icon 查詢鍵 | #11＋美術：icon 圖形、頭頂擺位、**尖峰時多 icon 並存的排版與可讀性** |
| #13 結算畫面 | `display_label`（≤6 漢字） | #13：逐項列表的排版、排序、是否顯示 |

`display_label` **是玩家喊的名字，但不是客人 NPC 說的台詞**——後者屬於 #7／#14 的
口白內容，本表不定義它。

📌 **UX Flag — 商品資料庫**：本表的 icon 查詢鍵會長成 #11 HUD 的畫面元素。
Phase 4（Pre-Production）應為 #11 執行 `/ux-design`，故事應引用 `design/ux/[screen].md`，
而非直接引用本 GDD。

## Acceptance Criteria

層級標記沿用 netcode GDD 慣例：**MVP-必達**＝本 GDD 已明講「必須硬擋／0＝建置失敗」的
不變量；**MVP**＝核心必備但無「硬擋」措辭。證據型別依 `.claude/docs/coding-standards.md`
的證據分級表。測試落點依 `.claude/docs/technical-preferences.md`：
`Assets/Tests/EditMode/ProductDatabase/[Feature]Tests.cs`，方法名 `Test_[Scenario]_[Expected]`。

| # | 準則 | 層級 | 證據 |
|---|---|---|---|
| AC1 | **身份永久性（規則 2）**。GIVEN 一份提交在 `Assets/Tests/EditMode/ProductDatabase/SkuRegistrySnapshot.txt` 的既有 `(sku_id, network_index)` 快照，WHEN 現行 SKU 表載入，THEN 快照中每一列在現行表裡原封不動存在（`sku_id` 未改名、`network_index` 未被任何其他列重用，即使該列已 `deprecated`），且現行表內不存在兩列共用同一 `network_index`。**快照檔只准新增列，禁止編輯既有列** | **MVP-必達** | Logic／自動化 `Test_SkuRegistry_MatchesSnapshot`（BLOCKING） |
| AC2 | **標籤唯一且不超長**。GIVEN 現行 `active` SKU 集合，WHEN 正規化（大小寫、全半形）後比對 `display_label`，THEN 無兩筆重複，且每筆 ≤6 漢字 | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC3 | **無空殼站台**。GIVEN 現行 SKU 表，WHEN 依 `machine_family` 分組統計 `active` 筆數，THEN 4 個家族每一個 ≥1 筆 | **MVP-必達** | Logic／自動化（BLOCKING） |
| AC4 | **`nameable` 必有 icon**。GIVEN `nameable == true` 的每一筆 `active` SKU，WHEN 掃描資產目錄，THEN 存在對應 `Ui_Icon_[sku_id]` 資產 | **MVP-必達** | Logic／自動化（BLOCKING）——早期誤報由 Tuning Knobs 的作業慣例避免，**不放寬本測試** |
| AC5 | **`Matches()` 家族模式**。GIVEN 一份 fresh instance，WHEN `demand.kind == Family`，THEN 家族相符回 true、不符回 false（Worked Examples #1-#3） | MVP | Logic／自動化（BLOCKING） |
| AC6 | **`Matches()` 指名模式**。GIVEN 一份 fresh instance，WHEN `demand.kind == Named`，THEN 僅 `network_index` 完全相符回 true；同家族但不同 SKU 回 false（#4-#5） | MVP | Logic／自動化（BLOCKING） |
| AC7 | **`is_spoiled` 短路**。GIVEN `instance.is_spoiled == true`，WHEN 對任一 `demand`（即使家族／SKU 本應相符），THEN 一律回 false（#6-#7） | MVP | Logic／自動化（BLOCKING） |
| AC8 | **`Get()` 查 deprecated**。GIVEN 一個 `deprecated` 條目的 `network_index`，WHEN 呼叫 `Get()`，THEN 完整回傳該筆資料，不丟例外、不回 null | MVP | Logic／自動化（BLOCKING） |
| AC9 | **`Get()` 查未指派值**。GIVEN 一個從未被指派過的 `network_index`，WHEN 呼叫 `Get()`，THEN 拋例外或觸發 assert，不靜默回傳假資料 | MVP | Logic／自動化（BLOCKING） |
| AC10 | **空家族查詢**。GIVEN 一個零筆 `active` 的 `machine_family`，WHEN 呼叫 `GetByMachineFamily()`，THEN 回傳空陣列，不丟例外 | MVP | Logic／自動化（BLOCKING） |
| AC11 | **「加商品不用改程式碼」承諾**。GIVEN 一份只追加一筆新條目、未修改任何生產 `.cs` 檔的測試資料集，WHEN 重跑 `Get()`／`GetByMachineFamily()`／`GetOrderable()`／`Matches()`，THEN 新條目被正確辨識，四個方法行為與原筆數時一致——即**對條目數量無感**（資料驅動，非硬編碼筆數或 switch-case） | MVP | Logic／自動化 `Test_CatalogQueries_ScaleWithArbitraryEntryCount`（BLOCKING） |
| AC12 | **准入門檻（四條合一）**。GIVEN 一筆新提案 SKU，WHEN 內容作者依 Player Fantasy 四條門檻逐項審查 `display_label`，THEN 產出審查紀錄（每條標記通過／不通過＋理由）存於 `production/qa/evidence/product-database/sku-admission/[sku_id].md`，四條全通過才可標 `active` | MVP | **內容審查紀錄（Design Review），非程式碼可驗證**（ADVISORY，但仍是上線前硬性步驟） |

### 四條准入門檻的可自動化程度（誠實標示）

| 條 | 可自動化？ |
|---|---|
| 1. 2-3 音節喊得完 | **可**——`display_label` 字數檢查（澄清措辭後成立） |
| 2. 對方不看畫面就知道是什麼 | **不可**——聽覺辨識＋常識判斷，無可程式化判準 |
| 3. 不與表內任何品項聽錯 | **部分**——可用注音／拼音編輯距離掃出疑似衝突配對供人工複核，**但「通過腳本」不等於「不會聽錯」**，最終判準是耳朵 |
| 4. 台灣人秒懂但不屬於任何一家 | **不可**——文化熟悉度與品牌歸屬（含商標／IP 風險）超出 QA 可獨力判定的界線 |

因此 AC12 是**人工審查**，不是自動化測試；但 ADVISORY 不代表可略過——它依然是每筆 SKU
上線前的硬性步驟，只是執行者是人不是 CI。第 3 條的輔助腳本是 advisory 標記產生器，
**不是 pass/fail gate**。

### 延後（宿主系統尚未存在，現在寫測試會恆真通過）

- **槽位分配規則（Named 優先於 Family）**：程式歸屬是 #15（或 #4 的交付判定點）。
  ⚠ **#15 的 GDD 必須包含此測項並反向引用本文件的「槽位分配規則」**，
  否則它會變成「兩邊都以為對方測過」的死角。
- **`deprecated` 的 `sku_id` 被其他資料表引用 → 擋建置**：掃描對象（波次配置、教學腳本）
  隨 #7／#8 落稿後才存在。不變量已寫在 Edge Cases，測試待宿主出現後補。

### 刻意不設 AC

- **規則 4「單一真相源的射程」**：它是架構治理原則（誰能定義什麼），不是可由 QA 獨立
  驗證的行為。可留痕的形式是靜態掃描（`ProductEntry`／`ProductInstance`／`machine_family`
  全 codebase 只能有一份定義），但目前無下游程式碼，現在寫也是恆真通過。待 #5 落地後補。
- **Overview 的「不用重出 build」澄清**：那是在界定承諾邊界，不是承諾一個行為。
  為它寫 AC 等於「測一個不存在功能的缺席」，沒有意義。

## Open Questions

| # | 問題 | 來源 | 擁有者 | 擋不擋進度 |
|---|---|---|---|---|
| OQ-P1 | **缺兩個家族需求 icon**：美術聖經 §3.3 現有四個（碗／杯／條碼／箱）中，條碼是每張單共通的結尾動作、箱是包裹代收，**皆非商品需求**；`Microwave` 與 `Shelf` 兩家族無對應符號 | 本 GDD Core Rules 規則 3 落稿時浮現 | art-director ＋ #11 | 不擋本文件；**擋 #11 HUD 設計** |
| OQ-P2 | **手持商品的 poly 級距未定**：美術聖經 §8.2 只有「機台類互動道具 ≤400 tris」與「貨架/環境模組 ≤150 tris」兩列，**沒有「手持商品」這一列**，兩者差 2.7 倍 | unity-specialist 體積估算時發現 | art-director | 不擋；**擋美術資產開工** |
| OQ-P3 | **`nameable == true` 的筆數上限**：每一筆都換算成一張 icon 的美術工時，但指名客佔比多少才有趣是玩法問題 | 本 GDD Tuning Knobs | art-director ＋ #7 | 不擋 |
| OQ-P4 | **SKU 總筆數 20-40 是估的，不是推導的**：真正的判準是「一個家族內幾種東西才有變化又不混亂」 | 本 GDD Overview／Tuning Knobs | #7 ＋ #8 設計時回填 | 不擋 |
| OQ-P5 | **是否需要純演出用售價欄位**（結帳畫面顯示用，無任何 runtime 邏輯讀它） | 本 GDD Overview | game-designer | 不擋；若要加是純附加欄位，不影響既有消費者 |
| OQ-P6 | **是否需要支援「不重出 build 就能加新商品」**：需 Addressables 遠端目錄＋內容 host，而現行發行通路（itch.io 靜態 host）不是為此設計的 | unity-specialist 糾正 Overview 承諾時提出 | **technical-director** | 不擋；**但這是獨立的技術決策，不該由本 GDD 默認** |
| OQ-P7 | **`RequestHandoff(itemId, ...)` 的 `itemId` 到底指什麼**：是 NetworkObject 實例（哪一個）還是 SKU（哪一種）？netcode GDD 未標型別 | unity-specialist 交叉比對時發現 | #5 設計時與 netcode GDD 對齊 | 不擋；**若對齊錯會在 #4 交接時重寫** |

⚠ **OQ-P7 是七條裡唯一會造成返工的。** 其餘六條都是「還沒決定」；它是
「兩份文件可能已經在講不同的東西，而沒有人發現」。
