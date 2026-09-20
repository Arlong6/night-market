# Review Log — 商品資料庫 (Product Database)

文件：`design/gdd/product-database.md`

---

## Review — 2026-09-20 — Verdict: NEEDS REVISION（首審，同日修訂完畢）

Scope signal: **M（自 S 上修）**，另加一條 L 形岔路——建置期資料治理閘門是沒有任何
系統擁有的跨切面基礎設施，應拆獨立 ADR，不得吸收進本系統的估算（見 OQ-P11）。

Specialists: game-designer, systems-designer, qa-lead, network-programmer, ux-designer,
unity-specialist ＋ creative-director（終審）

Blocking items: **30 條（CD 合併為 6 個根因）** | Recommended: 20 條
Prior verdict resolved: 首審

### ⚠ 程序瑕疵（必須記錄）

**本次評審與撰寫在同一個 session**，違反 /design-review「評審必須獨立於撰寫脈絡」的
規定。使用者在知情下裁決照跑。緩解措施：六位專家全部是零背景新 agent，只拿到檔案路徑
與專案標準文件。**但彙整層（主審）就是作者本人。**

creative-director 的程序判斷：**「沒有偵測到壓制。殘餘偏誤是『不利綜合的缺席』，
不是『發現的扭曲』。」** 它獨立複核了唯一驗得動的核心指控（P-17），結果與主審陳述一致，
且主審在可以自我緩頰處（AC54 原文其實 build／protocol 兩者都提）選擇不緩頰。

但它指出三處真實偏誤：
1. **嚴重度排序是扁平的**——產出全套唯一「安靜出貨的資料損毀」的 unity-specialist 被排在最後。
2. **兩組相乘效應沒被點出**，而用交付的材料就做得出來：
   - 幻想錨在指名 × 指名 icon 可讀性預算為零 → 幻想把下游推向沒有預算的那一半。
   - enum 預設值是合法值 × enum 重排 × fake catalog 碰不到真實資產 → **一個閉環**：
     汙染與測試套件一起漂移。sd 與 unity 各看到圓弧一段，沒人畫出那個圓。
3. **一處軟性框架**：主審以讚許語氣描述文件的「誠實標示」機制。CD 反轉此評價——
   **「這份文件的特徵性失敗模式，正是『一段寫得很好的揭露，旁邊站著一個更大而未被
   揭露的缺口』。揭露密度做了它沒有掙得的聲譽工作。」**

**下次同 session 評審的修法**：緩解措施應瞄準**接合層**（指派一位專家專職交叉引用
其他人的發現，或要求彙整者以自己無從選擇的順序呈現），因為零背景保護的是輸入，
不是接合。

### 六個根因

| RC | 內容 |
|---|---|
| RC-1 | **沒有任何預設值是安全的**——設計了 `Get()` 的 fail-fast 防線並花三段論證，然後讓每一條繞過它的路徑裸奔（Named 分支、下游直讀裸欄位、資產裡的 enum 整數），而唯一在崗的哨兵（AC9 的 assert）在 Release Web build 整段消失 |
| RC-2 | **擋不住的閘門**——四次寫「擋建置」，但 Unity 無內建機制讓測試綠燈成為 Build 前置，且專案無 CI。文件整個安全論證都押在建置期強制上 |
| RC-3 | **資訊架構決策被包裝成資料決策出口**——規則 3 在客人頭頂這個既有視覺頻道開了第二條語意軸，然後用「本系統沒有自己的 UI」送給一個連 GDD 都沒有的系統。12 條 AC 沒有一條看得見它 |
| RC-4 | **單一真相源的三處超額承諾**，而反例就在同一份文件裡（P-17、加工閾值分裂、4vs5 機台、deprecated 資產） |
| RC-5 | **`is_spoiled` 的信任邊界無處安放**——全文唯一「決定評分、由別系統寫入、要跨端傳」卻無線路規格的欄位 |
| RC-6 | **回饋粒度在源頭被丟棄**（CD 判定診斷對、定價錯，降為 Recommended 但仍採納，理由改為判例一致性） |

### 專家分歧與裁決

1. **槽位分配要不要現在測**：本次 qa-lead 說「邏輯已齊備、延後是破洞」；撰寫時另一位
   qa-lead 說「宿主不存在、現在寫是空殼」。**CD 裁決：拆兩層，兩條都留。**
   規則本身現在測（AC13），整合維持延後給 #15／#4，並保留要求 #15 反向引用的 ⚠
   ——因為綠燈會**加劇**「兩邊都以為對方測過」而非消除它。
   CD 另指出「延後」節把一個假理由（槽位分配）與一個真理由（deprecated 跨表掃描）
   並列，是**真缺口被鄰近的正當理由洗白**的典型路徑。
2. **兩級需求機制的歸屬**：ux-designer 主張它是被偽裝的資訊架構決策；game-designer
   主張門檻該拆兩組。**CD 裁決：採用 gd 的處方，裝進 ux 的框架**——
   「這份文件欠的不是像素，是**對像素的約束**；它已經會這招了，只是沒對 icon 用。」

### CD 認為被低估的

- **enum 序列化重排**：全套唯一「安靜、不可回復、會出貨」且**測試套件會主動配合汙染**
  的失敗模式。修法兩行。**嚴重度／成本比最高。**
- **deprecated 釘住美術資產引用**：Overview 原句「讓 44MB 硬標不會被品項數吃掉」
  在規則 2 之下**是一句主動錯誤的主張**，不是未規格化。
- **准入門檻稽核了錯誤的頻道**（CD 自己補，無專家點出）：四條門檻全是聽覺判準、
  全作用在 `display_label` 上，但尖峰的高風險管道是玩家永遠不會聽到的視覺 icon。

### CD 認為被高估的

- `MatchResult`：布林沒有銷毀資訊，降 Recommended（但採納，理由改為判例一致性）。
- 「AC5-AC10 的證據等級是空話」過重——SO vs POCO 真正缺的只是一句話。
- **「沒人追蹤 20-40 筆 SKU 內容何時由誰產出」＝唯一一條對 S 規模 Foundation 文件的
  過度要求。GDD 不是排程。**

### 同日修訂（全部 blocking 已處理）

使用者裁決四項：①`display_label` 拆兩個常數（新增 `sku_holler_max_chars = 4`）
②Player Fantasy 補一個家族級錨點場景 ③`Matches()` 改回傳 `MatchResult`
④「擋建置」明寫 `IPreprocessBuildWithReport` 機制並拆 ADR。

修訂範圍：Overview／Player Fantasy／Core Rules（新增規則 1b、3b）／States／
Interactions／Formulas／Edge Cases／Dependencies／Tuning Knobs／Visual-Audio／
UI Requirements／Acceptance Criteria（12→17 條）／Open Questions（7→12 條）。
514 → 768 行。registry 同步（`product_matches` 改 enum、`machine_family_values`
改明確整數值、`sku_network_index_type` 從 1 起、新增 `sku_holler_max_chars`）。

**尚未複審。** 下一輪應在**全新 session** 執行。
