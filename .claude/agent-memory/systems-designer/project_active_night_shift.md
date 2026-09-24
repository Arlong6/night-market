---
name: project-active-night-shift
description: 大夜班 (Night Shift, Unity 6.3) 是現行設計主線；Lexicon Village 的舊筆記已過期
metadata:
  type: project
---

**大夜班 (Night Shift)** 是目前的設計主線（Unity 6.3 LTS、Web-only、4 人合作超商）。
先前記憶裡「Lexicon Village 是 active design focus」(2026-05-29) **已過期**，
現在 `design/gdd/` 的活動檔案是 netcode-session、product-database、first-person-controller。

**Why:** 2026-09 期間的 GDD 撰寫與 W1 網路原型全部落在 Night Shift；
Lexicon Village 的 GDD（game-session-state、lexicon-village-*）仍在 registry 裡但沒有新進度。

**How to apply:** 被叫去做系統設計時，預設脈絡是 Night Shift。
若使用者提到 vignette／symbol binding／notebook，那才是 Lexicon Village。

**這個專案對數值的硬要求**（跨三輪評審建立，違反會被退件）：
每一個數字都要標明四態之一——上游已鎖定／本節推導得出／暫定值（附回填觸發）／
需實測才能定（附量測方法）。**猜的數字不得看起來像推導出來的。**
引用檔案一律給行號並自己開檔確認（前三輪抓到大量引錯行號）。
評審終審處方：**禁止新增斷言作為預設修法**——提出新常數時要同時指出哪些可以合併或刪掉。

相關：[[feedback-constants-need-inequalities]]
