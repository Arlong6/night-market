# Sprint 1 — REVIVED 2026-06-02 (launch sprint)

> **Created**: 2026-05-28
> **Shelved**: 2026-05-29 (creative-director defer reverted; pivoted to Lexicon Village MVP)
> **Revived**: 2026-06-02 (post-v0.55; MVP for both games shippable)
> **Sprint window**: 2026-06-06 → 2026-06-08 (weekend + Monday)
> **Review mode**: solo (PR-SPRINT producer gate skipped)
> **Predecessor**: per-version commits v0.10 → v0.55

## Sprint Goal

推 v0.55 內容上 itch.io 公開發布（v1.0 release-ready）— 產出可信賴的 Web build，做 fresh smoke pass，準備好商店頁面素材。**新版含兩款遊戲：夜市採購 (Night Market) + 字典村莊 (Lexicon Village MVP)**。

### What changed since 2026-05-29

- ✅ 字典村莊 MVP 完成（13 systems, 140 lexicon tests）
- ✅ Cascade shimmer SPIKE 1 完成（v0.55, 26 tests, 真實 per-glyph wavefront）
- ✅ 視覺修復（CJK font, NPC head/body draw, centered UI）
- ✅ 總測試 466/466 全綠
- 🔧 L-001 / L-002 / L-005 scope 擴大到含 lexicon village

## Capacity

- Total days: 3 (週末 + 週一)
- Buffer (30%): ~7h reserved for browser quirks + lexicon playtest iteration
- Available: ~16h dev/QA + ~7h buffer = ~23h total

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-001 | 產 Web HTML5 build & 跨 browser 驗證（含兩款遊戲） | self | 3h | v0.55 export config | `exports/web/` 產出；Chrome + Firefox 載入無 console error；total download <20MB；**NM**: title→play→buy→win flow 走得通；**Lexicon Village**: title→start→click baker→vignette→notebook 3 icons→cascade shimmer→ending→restart 走得通 |
| L-002 | Fresh smoke check 涵蓋兩款遊戲 + cascade shimmer | self / qa-tester | 3h | L-001 | `production/qa/smoke-2026-06-06-v1.0.md` 完成；**NM**: 街頭藝人 tip、寵物追隨、時段變化、抽獎攤 3 抽、女媽結算 全部觀察通過；**Lexicon Village**: AC-15 spread-language 測試（≥3 testers, 用 wave/sweep/spread, 不用 flash/pop）；cascade shimmer 視覺品質確認 |
| L-003 | itch.io 頁面素材包 | self / art-director | 4h | L-001 | cover.png (630×500)、3–5 張 in-game screenshots（含 2 款遊戲）、~10s gameplay GIF（NM + cascade shimmer）、英中雙語 description (~200 字)、tags 列表 |
| L-004 | README 更新（玩家導向） | self / writer | 1h | L-001, L-003 | README.md 頂部含 itch.io link 佔位符、1 張 hero screenshot、"play in browser" CTA、controls 摘要、兩款遊戲簡介 |
| L-005 | 全 regression suite 綠燈 (466 tests) on fresh clone | self | 1h | — | `git clean -fdx` → fresh checkout → `gut_cmdln` 跑完 466/466 pass，記錄 run log 到 smoke 檔 |
| L-006 | 發布版 patch notes（v0.1 → v1.0） | self / community-manager | 1h | L-002 | `production/release-notes/v1.0.md` 完成，玩家可讀，列 5 個 NM highlight + 1 段 Lexicon Village 介紹 |
| L-007 | Git tag v1.0 + push | self | 0.5h | L-001–L-006 全綠 | `git tag -a v1.0`，commit 訊息含 changelog link，user 親自 push（不自動 push） |

**Must Have 小計：~13.5h**

### Should Have

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-008 | Audio gesture-unlock 驗證 | self | 1h | L-001 | 首次 user click 前無 audio error；click 後 SFX/BGM 正常觸發；cascade shimmer chime 在 user-gesture 後可聽到 |
| L-009 | 行動版瀏覽器 quick check（觸控） | self | 1h | L-001 | iOS Safari / Android Chrome 開啟可看到內容；觸控可用程度記錄為 known limitation（非 blocker） |
| L-010 | INDEX.md backfill / archive | self | 1h | — | `production/stories/INDEX.md` 標 R-001→R-009 為 Done；增列 v0.10→v0.55 已 ship features 為 reference（或 archive 整份） |
| L-013 | 字典村莊 playtest AC-15 — ≥3 testers describe spread | self / qa-lead | 2h | L-001 | 找 3 個 first-time testers 玩到 cascade shimmer；用 wave/sweep/spread 描述（不用 flash/pop）；若失敗，調整 RIPPLE_DURATION/DWELL_DURATION |

**Should Have 小計：~5h**

### Nice to Have

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-011 | itch.io page polish — devlog 第一篇 | self / community-manager | 1h | L-007 | 短 devlog "夜市採購 + 字典村莊 雙作品上架"，含開發里程碑回顧 |
| L-012 | Performance profile：載入時間 & FPS | self / performance-analyst | 1h | L-001 | 中階筆電 Chrome 載入 <8s；steady-state 60fps（兩款遊戲都測）；產出短 profile 報告 |

**Nice to Have 小計：~2h**

**總計：Must (13.5h) + Should (5h) + Nice (2h) = 20.5h** — 落在 ~16h 工時 + 7h buffer 內。

## Carryover from Previous Sprint

無 — 這是第一個 formal sprint。先前以 per-version commits ship 至 v0.55。

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Web build size >20MB（CJK font + assets + lexicon 內容） | Medium | High（拖累載入體驗） | L-001 用 godot-specialist memory 的 CJK subset 模式；如 >20MB，先 ship 較小的英文版本，CJK 為 V1.1 |
| Firefox drag/audio 行為與 Chrome 不同 | Medium | Medium（操作可用即可） | L-001 顯式測兩個 browser；任一壞掉降為 known issue 寫入 README |
| itch.io 頁面素材時間爆炸（GIF 製作） | High | Low | L-003 設 hard cap 4h；超過就用 3 張 screenshots + 簡短 GIF 出貨 |
| 第一次 fresh-clone test 揭露隱性 deps | Low | High（blocker） | L-005 排在 L-007 tag 前；如失敗 sprint 不結束 |
| 抽獎攤 random 在 Web build 不 deterministic | Low | Low | L-002 在 smoke check 順手記錄 3 次抽獎 outcome；如異常作為 bug 帶入下個 sprint |
| **cascade shimmer 在 Web 上看不出 "spread" 感** (CENTRAL FEEL 風險) | Medium | High（lexicon village 核心體驗失敗） | L-013 — 真人測試確認；如失敗，加長 RIPPLE_DURATION 或縮短 DWELL_DURATION，回到 SPIKE 1 重做 |
| 雙遊戲讓 itch.io 頁面定位混亂 | Medium | Medium | L-003 描述明確分兩段；考慮"雙作品合輯"框架 |

## Dependencies on External Factors

- itch.io 帳號已存在（user 須確認）
- 無第三方 API / cloud service 依賴
- 3 位 first-time testers for L-013（user 自找）

## Definition of Done for this Sprint

- [ ] L-001 → L-007 全部 Done（Must Have）
- [ ] All 466 tests pass on fresh clone
- [ ] Smoke check `smoke-2026-06-06-v1.0.md` written
- [ ] Web build deployed to `exports/web/`，user 已在 Chrome 親自試玩
- [ ] `production/release-notes/v1.0.md` 存在
- [ ] Git tag v1.0 已建立（user 親自 push）
- [ ] itch.io 頁面素材包齊全（user 親自上傳）
- [ ] 無 S1/S2 bug 在 delivered features 中
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] AC-15 字典村莊 spread-language playtest 通過或調整 knob 後通過

## QA Plan

`production/qa/qa-plan-sprint-1-2026-05-28.md` 已存在但需 update。Required for Production → Polish gate sign-off.

## Scope check

If implementation surfaces additions beyond this list, run `/scope-check launch-prep` to detect creep before continuing.
