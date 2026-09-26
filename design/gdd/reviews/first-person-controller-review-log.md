# Review Log — 第一人稱控制器 (`first-person-controller.md`)

## Review — 2026-09-26 — Verdict: NEEDS REVISION

Scope signal: **L**（多系統整合、7 條公式、5 條下游硬依賴、零 ADR 但需要至少一個）
——但**修訂本身是 S**（十項句子級，約半天）；**若 OQ-F1 失敗則是 XL 重做**。

Specialists: game-designer, systems-designer, qa-lead, network-programmer,
gameplay-programmer, unity-specialist, ux-designer, level-designer, audio-director,
creative-director（資深綜合）

Blocking items: 6（壓縮後）｜Recommended: 9｜Prior verdict resolved: First review

### Summary

九位專家共提出 42 條 BLOCKING，creative-director 壓成**四個根因**並駁回／降級 6 條。
判決為 NEEDS REVISION 而非 MAJOR，理由具體：**零條 Core Rule 需改、零個介面需改、
零條 levy 需撤回，且唯一硬交付站得住**——`player_move_speed_max` 可能由 1.39 移到
1.32 或 1.47，但上游要的是「存在且具名」，netcode 的 AC4／AC15／AC23 不會被重新封鎖。

**最重要的發現不在任何單一專家的領域裡**：OQ-F1（itch.io iframe 內 pointer lock）
應排在所有修訂之前。成本 1 小時，失敗則本檔全文作廢。

### 四個根因

1. **攝影機是一個沒有擁有者的子系統**——本檔寫「攝影機（本系統擁有）」卻沒宣告任何
   攝影機數值（眼高、近裁面、視野角、C5 三個時間常數、動暈曝險）。吃掉四位專家的五條
   BLOCKING。🔴 連帶：實作者拿 Unity URP 預設近裁面 0.30 時安全速度是 **0.88 m/s
   而非 1.39——超標 58%**，症狀是 ghost 從臉上穿過，會被歸因成「網路爛」。
2. **levy 表只登記了三分之二**——給 #5 的四條硬拒絕與給 #8 的節拍邊界，
   `systems-index.md` 前向義務表裡一列都沒有；依本檔自己第 508／1349 行立的規則，
   那六條現在等於不存在，而判準 3／6 的分母整個壓在 #8 那一條上。
3. **自我稽核文字裡有四處算錯，design 文字裡只有一處**——AC6 的 26 幀應為 13 幀、
   AC1「恆真通過」的分類錯、分層表 24/43(56%) 應為 31/43(72%)、
   「每條上界 AC 都配下界子句」的宣稱不成立（至少四條反例）。
4. **`W = 0.9 m` 與 Player Fantasy 散文互斥**——`W ≥ 4r_c = 1.2 m` 才可能並肩不重疊，
   0.9 下強制殘留 0.3 m 重疊，每次迎面都是保證接觸，而第 85 行寫「差一點撞到」。
   creative-director 裁決**錯的是散文不是幾何**，處置是刪除。

### 兩條 creative-director 自產、九位專家皆未提出的發現

- **`depenetration_margin` 的缺失輸入是攝影機近裁面**，補上不等式
  `margin ≤ 1 − near/(2·r_c)` 後，`near = 0.15` 恰好複現文件的 0.75；
  而實際使用值是 **0.785，超標 4.7%**。這同時揭露一條比現有處置順序四步都便宜的槓桿。
- **F4 在 2026-09-23 的修補方向是反的**：客人脫離 26 幀、隊友 13 幀，
  **客人是隊友的 2 倍黏**，而 AC13③ 宣稱「恰為一半」，**差 4 倍**。
  且不可由 scale 修正（不對稱性在 `n_correcting_ends` 裡）。
  → 「擠開一個客人不需要道歉」這句設計意圖**由任何機制交付零次**。
  建議 `npc_pin_timeout_sec` 由 4.0 下修為 1.5 s，連帶解掉 level-designer 的兩條 BLOCKING。

### 主評審獨立查證（非專家轉述）

**驗證為真**：netcode `:96`／`:800` 錨點逐字相符；美術聖經 §3.1 剪影論證成立；
§4.5 的 4.5:1 理由確實明文含「第一人稱移動鏡頭」；零 ADR；無 CI；八個旋鈕常數
已進 registry；**上游 netcode AC23 已引用 1.39、`blocked-by` 已解除——硬交付確實兌現**。

**驗證為假／有缺口**：
- #5 四條硬拒絕與 #8 節拍邊界**未登記**，而本檔宣稱「已登記」（M1）
- F6 的回填不等式缺「攝影機眼高」，而**兩份美術聖經都零筆記載**（M2）
- `r_c`／`L_p95`／`depenetration_margin` **三個 F1 輸入都不是 registry 註冊實體**，
  只有輸出 1.39 是 → #11 交出真值時無任何機制會把它標紅（M3）
- Overview 對 netcode 的引用已過期（好消息被寫成壞消息）（M4）
- `L_p95 = 0.339 s` 標「東京 relay」，但東京實測 p95 是 **94.5 ms**（差 3.6 倍）；
  339 落在美國中部 335.8 ms 的 0.95% 內，而那是上游明文標為「AC22 已失敗」的反面案例。
  `netcode-session.md` 搜 `339`／`L_p95` **零命中**

### 專家歧見（未由主評審裁決者）

- **D4：level-designer vs creative-director** — `W = 0.9` 該犧牲「側身敘事」還是
  「NPC 密度＝波次曲線」。level-designer 主張必須先裁決，否則 #11 拿到自相矛盾的規格；
  creative-director 不同意犧牲的前提。**未收斂。**
- **D5：audio-director 不同意「autoplay 與 `Unlocked` 進場衝突」** 這個前提
  （transient activation 是分頁層級），但自承沒讀過 #12 的 GDD（Not Started）。

### creative-director 對「這份文件的誠實是真的還是儀式」的裁決

> **真的，但已經開始長出儀式。** 判斷依據不是誠實的密度，是它的**代價**——
> 這份文件付過四次錢（三次具名推翻自己、AC5i 紅燈時改常數而非加容差、
> 主動標記 F3 係數是挑的、主動撤回一個對自己有利的說法）。儀式誠實不會讓作者付錢。
>
> 而四處算錯的分佈是本輪最重要的資訊：**每一處都在為了展示嚴謹而寫的文字裡，
> 沒有一處在 Core Rule、介面邊界或 levy 裡。設計推理撐過了三輪對抗式評審；
> 關於設計推理的後設評論，一輪都沒撐過。**
>
> 處方是刪：**一個誠實的標記必須改變一個數字、一個射程、或一個擁有者。
> 只改變散文的標記是裝飾。**

### 🟢 OQ-F1 已於同日實測通過（2026-09-26）

`prototypes/w1-pointerlock-probe/` 部署至 `arlong666/w1-pointerlock-probe:html5`。
Chrome / macOS / dPR=2 實測：

- **指標鎖定在 itch.io 的 iframe 內成功取得，第一次嘗試即成功**（Promise → resolved）
- **Esc 解除後，一次玩家點擊即可重新取得鎖定**，未觀察到 UA 抑制
  （C15 未測的另一半是「不帶手勢的自動重鎖會失敗」，操作上無影響——AC27 本就禁止該呼叫）
- **結構性原因：itch.io 的遊戲 iframe 沒有 `sandbox` 屬性**，而 pointer lock 由
  sandbox 的 `allow-pointer-lock` token 管，沒有 sandbox 就沒有那條限制

🔴 **本檔 OQ-F1 的憂慮建立在一個錯誤類比上，應在修訂中更正**：原文以
「`clipboard-write` 缺席導致 Clipboard API 被擋，故『缺席＝被擋』有前例」支持憂慮，
但 `clipboard-write` **是** Permissions Policy feature 而 `pointer-lock` **不是**
（實測：即使 sandbox 明確給了 `allow-pointer-lock`，`allowedFeatures()` 裡也沒有它）。
**拿 `allow` 字串推論 pointer lock 可用性從一開始就問錯問題。**

**OQ-F2 亦取得第一筆數據**：鎖定期間 `screenX` 完全凍結，`movementX/Y` 是唯一視角訊號
（可直接寫進 GDD）；但 `look_deg_per_unit` 的換算係數仍待受控量測。

**⇒ 「本檔可能全文作廢」的風險已解除，十項句子級修訂可以動工。**

### 下一步（依 creative-director 排序）

1. ~~**跑 OQ-F1**（1 小時）。失敗則本文件作廢，不要先修。~~ ✅ **已完成，通過。**
2. 執行十項句子級修訂（約半天）。
3. **寫那一個 `.cs` 檔，跑 31 條 T0。**
   「再開一輪散文評審的邊際產出，低於跑一次測試。」

### 可證偽的檢定（用來判斷本次裁決對不對）

若 31 條 T0 跑起來後紅燈集中在 **AC6／AC13③／AC1③**（被點名「文件算錯」的那三條）
而 Core Rule 衍生條目（AC8a／AC8b／AC9／AC10／AC11／AC21）**全綠**，本裁決為真。
**若反過來，則 C8／C9 的碰撞模型才是真正該被重審的東西，根因排序要重來。**

### ✅ 三項裁決（arlong，2026-09-26）— 全數採納 creative-director 建議

| # | 項目 | 裁決 |
|---|---|---|
| 1 | `camera_near_clip_m` | **0.10** ⇒ `player_move_speed_max` 1.39 → **1.47** |
| 2 | `npc_pin_timeout_sec` | **1.5 s**（由 4.0 下修，並升格為獨立旋鈕） |
| 3 | #14 tier | **碰撞音進 MVP、腳步音留 VS**（`systems-index.md:44` 已同步） |

### ✅ 修訂已於 2026-09-26 套用

十項句子級修訂全部完成，動了三個檔案：

- **`first-person-controller.md`**：新增 §F0 攝影機常數；F1 全段重寫（margin 由「挑的 0.79」
  改為「推導的 0.831」，補上 `margin ≤ 1 − near/(2·r_c)` 不等式，並記錄 `near=0.15` 恰好複現
  舊文的 0.75——**那不是錯數字，是藏了輸入的數字**）；F1 新增「`L_p95` 這個數字的來源」一節並
  更正標示；F4／F5 改寫（客人比隊友黏 1.9 倍，意圖改由門檻交付）；處置順序新增近裁面為第一階；
  Player Fantasy 刪「差一點」並補幾何說明；AC1③／AC3／AC4／AC5（新增子句 j、k）／AC6（26→13 幀
  並補「兩端各自求解」的 GIVEN）／AC7／AC11／AC13③（方向反轉）／AC14（新增 NPC 分支）／AC23／
  AC24／AC25／AC36（探針代答）／AC40（拆成過衝與抖動兩項記錄）；分層表 56%→72%；
  恆真清單補七組子句並改寫「每條上界都配下界」的不實宣稱；OQ-F1／F3／F9 關閉。
- **`entities.yaml`**：`player_move_speed_max` 1.39→1.47、`npc_pin_timeout_sec` 4.0→1.5；
  **新增六筆** `camera_near_clip_m`、`camera_eye_height_m`、`camera_fov_deg`、`r_c`、
  `L_p95`、`depenetration_margin`——**F1 的三個輸入先前都不是註冊實體，只有輸出是**，
  於是 `/consistency-check` 無法在輸入變動時標紅那個衍生常數。
- **`systems-index.md`**：前向義務表**新增 #5（四條硬拒絕）與 #8（節拍邊界）兩列**；
  #14 那列由祈使句改寫為經裁決的 tier 變更；Priority Tiers 第 44 行同步。

**未動**：任何 Core Rule 的語義、任何介面、任何 levy 的存廢。C1–C16 只有 C11／F4 的理由段改寫。

**最終一致性驗算**（以文件自己宣告的值重算 AC5 全表）：a–k 九條全部 ✔，無一條需要容差。

### ✅ 31 條 T0 已於同日跑過（`prototypes/fp-controller-core/`）

**creative-director 的可證偽檢定成立**：修訂後 AC6／AC13③／AC1③ 全綠，Core Rule 衍生條目
AC8b／AC9／AC10／AC11／AC21 全綠 ⇒ **C8／C9 碰撞模型健全，壞的確實是自我稽核層**。

第一次跑 30/32，兩條紅燈性質不同：
- **AC25③**：實作漏了 C14「回前景第一幀不移動」——只歸零速度不夠，斜坡第一幀就給 0.306 m/s。**實作錯，已修。**
- 🔴 **AC8a③**：**文件矛盾，十位專家全漏**。斷言位移 `== 0.05 m`，但每幀預算只有 0.0245（舊值 0.023167 同樣不夠）
  ——**與 AC3／C12 互斥，從寫下那天起就不可能通過**；且 0.05 只在「C12 被誤讀」的世界裡合法，
  是照著 AC6 要抓的那個誤讀寫出來的。鑑別力倖存（0 vs 0.0245）。**已依 arlong 批准改為 `min(0.5p, 預算)`。**

另抓到三項**程式碼被迫替文件決定**的規格空白，已補回 GDD：C10「輸入被持續抵銷」的可判定謂詞
（新旋鈕 `input_cancel_threshold` = 0.5 🔬）與計時器三條語意、F7 的 `time_to_contact` 封閉式與短路求值順序。

最終：**PASS 32 / FAIL 0**。

### 下一輪的對象不是散文

依 creative-director 的排序，**第 3 步現在是唯一該做的事**：寫那一個 `.cs` 檔，跑 31 條 T0。
本輪刻意**未補**三條缺失的反恆真子句（AC12①／AC15①／AC23①），理由是補它們要新增斷言，
而本輪方向是刪散文、修算錯——**先把「每條上界都配下界」這個宣稱改成真話，
比先把它變成真的更重要**。那三條連同 qa-lead 的其餘建議留給實作輪。
