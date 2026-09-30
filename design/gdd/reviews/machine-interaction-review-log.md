# Review Log — 機台互動組 (Machine Interaction)

GDD：`design/gdd/machine-interaction.md`（系統 #5）

## Review — 2026-09-29 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, network-programmer, gameplay-programmer, unity-specialist, ux-designer, audio-director, level-designer; senior reviewer: creative-director
Blocking items: 7 | Recommended: 14
Summary: 骨架站得住（C3／C5／C6／C9／E0.4 就是把 Player Fantasy 做成機制，FP 四條硬拒絕全守住，五支柱無核心違反），但 C10 把「保險絲到期」與「斷線」並列判 `Failed`，守在微波前的人 5 s 內必被判失敗、倒轉判準 1，AC3 與 AC10① 互斥；判準 4 的幾何有四處靜默失效（撲空門檻用 0.8 m 但 Host 以 1.1 m 接受、非持有者吃了持有者的遲滯、偏心槽 `NotFacing`、槽高 < 0.73 m 射線不及）且沒有 AC 抓得到；E0.2「只有 0 的槽能補」拆掉 Player Fantasy 宣稱的「靜→爆」唯一因果線（需 arlong 裁決）；RPC／資料契約自稱「已定形」其實五個 RPC 名對不齊、`FamilyParam` 無來源、`StationStock` 未定義；「耳朵是主頻道」需求寫滿但交付面是空的（撲空觸發源與 ADR-0002 Decision 5 矛盾、Web AudioMixer 只剩音量、收銀站聽障盲區）。專家共約 20 條 BLOCKING，CD 校準後留 7、真紅燈 5；錯誤集中在用來證明嚴謹的文字裡（F5「結構推導」、F3「v = 1.62 無事」、F6「不會出現」）。
Prior verdict resolved: First review

### 專家間分歧（供日後追蹤）
1. `AutoObjectParentSync` 嚴重度：network-programmer BLOCKING vs unity-specialist RECOMMENDED；CD 採前者修法、後者嚴重度。
2. E0.2：game-designer BLOCKING vs ux-designer／systems-designer RECOMMENDED；CD 實質採 game-designer，但拒絕「玩法 vs 美術」假兩難，提出「按住補整架」選項。
3. E0.3 先放後驗：gameplay-programmer「已明寫」vs 其餘三位「後果未言明」；CD 採前者，AC24 補分支。
4. F3 上界錨定：level-designer（支柱 3 的店 T ≈ [6, 11]，咖啡 22 超界）vs creative-director（上界應錨支柱 5 的 30 s）；未解，交 arlong。
5. C7×C10：main review BLOCKING vs network-programmer RECOMMENDED；CD 採 BLOCKING。
6. F4 400 ms 無餘裕：systems-designer BLOCKING vs CD RECOMMENDED（優雅降級）。
7. 必達集合：qa-lead 加 AC10b vs CD 駁回（F7 = 0 路徑不可達）；AC11／AC38 升必達兩方同意。
8. main review S9（C18 遲加入理由過時）撤回：前提「關閉 NetworkSceneManager」在 netcode `:827-828`，MVP 確有中途加入。

### 同日修訂 r1（作者宣稱已處理；依 CD 指示不再開散文複審輪）
arlong 四項裁決：E0.2 選「點按拿、按住 ≥ 100 ms 補整架」；斷線也只放 claim（`Failed` 只剩 `shift_end_ts`）；F3 保留 `2·T_min + B` 並加支柱 5 硬帽 30 s；完整變更集（GDD、索引狀態＋五列新前向義務、本紀錄、entities.yaml 六條備註）。

| # | 阻擋項 | 修法落點 |
|---|---|---|
| 1 | C7×C10 保險絲→`Failed` | C10 重寫、States 表 A、E1、AC3／7／10a–e／48 |
| 2 | 判準 4 幾何 ×4 | 撲空門檻 `accept_radius_m`；提示＝本機述詞⑤⑥；錨點＝槽；F6 槽高 ≥ 0.75；AC29／46／47／49 |
| 3 | E0.2 只能補 0 | E0.2／C11／F5／F8／States／AC11／23／34；`InteractRpc.action`；levy #17 |
| 4 | RPC／資料契約 | 新 C20 語意表（`InteractRpc`／`TakeOutputRpc`／`InterruptRpc`／`InteractResponseRpc`；`StationStatus{Phase, WorkStartTick, Sku, PendingProductNetId}`；`StockState`）；OQ-M14／M17 |
| 5 | 耳朵頻道交付面 | Interactions #14 拆兩種觸發源；V/A 混音落地註記＋Unity 6000.3 Web 音訊限制（手冊已驗證）；UI 約束 8；levy #11／#7 |
| 6 | 狀態機回掃 | 表 B 補 `Claimed → Idle` 三條邊；C8 限定 Ready 之前；`Taken` 清 claim 明寫；OutOfStock 改「見底」一聲 |
| 7 | F3 T／B／AC32 | `min(2·T_min+B, 30)`、B 1–3、grace 範圍寫成式子、不變式、AC32 讀 registry |

AC 45 → 54（AC10 拆為 10a–e、新增 34b、46–49），必達 6 → 8（加 AC11、AC38）。未套用留下一輪：AC1／AC16 子句拆分、V/A「不得」與 UI 約束的 SS 簽核清單、撲空「近場不廣播」理由、「啊」變體資產表。

**下一步**：純 C# 站台狀態機跑 T0（AC3 與舊 AC10① 這類矛盾會自己亮紅燈）→ `/architecture-decision` ADR-0004 → level-designer blockout 量 T 回填 registry。
