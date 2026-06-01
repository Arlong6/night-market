# Sprint 1 — 2026-05-30 to 2026-05-31

> **Created**: 2026-05-28
> **Review mode**: solo (PR-SPRINT producer gate skipped)
> **Predecessor**: per-version commits v0.10 → v0.53 (no prior formal sprint)

## Sprint Goal

推 v0.53 內容上 itch.io 公開發布（v1.0 release-ready）— 產出可信賴的 Web build，做 fresh smoke pass，準備好商店頁面素材。

## Capacity

- Total days: 2 (週末)
- Buffer (25%): ~5h reserved for browser quirks + page-asset iteration
- Available: ~16h dev/QA + ~5h buffer = ~21h total

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-001 | 產 Web HTML5 build & 跨 browser 驗證 | self | 2h | v0.53 export config | `exports/web/` 產出；Chrome + Firefox 載入無 console error；total download <20MB；title→play→buy→win flow 走得通 |
| L-002 | Fresh smoke check 涵蓋 post-MVP features | self / qa-tester | 2h | L-001 | `production/qa/smoke-2026-05-30-v1.0.md` 完成；街頭藝人 tip、寵物追隨、時段變化、抽獎攤 3 抽、女媽結算 全部觀察通過 |
| L-003 | itch.io 頁面素材包 | self / art-director | 4h | L-001 | cover.png (630×500)、3–5 張 in-game screenshots、~10s gameplay GIF、英中雙語 description (~150 字)、tags 列表 |
| L-004 | README 更新（玩家導向） | self / writer | 1h | L-001, L-003 | README.md 頂部含 itch.io link 佔位符、1 張 hero screenshot、"play in browser" CTA、controls 摘要 |
| L-005 | 全 regression suite 綠燈 (324 tests) on fresh clone | self | 1h | — | `git clean -fdx` → fresh checkout → `gut_cmdln` 跑完 324/324 pass，記錄 run log 到 smoke 檔 |
| L-006 | 發布版 patch notes（v0.1 → v1.0） | self / community-manager | 1h | L-002 | `production/release-notes/v1.0.md` 完成，玩家可讀，列 5 個 highlight 功能 |
| L-007 | Git tag v1.0 + push | self | 0.5h | L-001–L-006 全綠 | `git tag -a v1.0`，commit 訊息含 changelog link，user 親自 push（不自動 push） |

**Must Have 小計：~11.5h**

### Should Have

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-008 | Audio gesture-unlock 驗證 | self | 1h | L-001 | 首次 user click 前無 audio error；click 後 SFX/BGM 正常觸發；refresh 不破壞 |
| L-009 | 行動版瀏覽器 quick check（觸控） | self | 1h | L-001 | iOS Safari / Android Chrome 開啟可看到內容；觸控可用程度記錄為 known limitation（非 blocker） |
| L-010 | INDEX.md backfill / archive | self | 1h | — | `production/stories/INDEX.md` 標 R-001→R-009 為 Done；增列 v0.10→v0.53 已 ship features 為 reference（或 archive 整份） |

**Should Have 小計：~3h**

### Nice to Have

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| L-011 | itch.io page polish — devlog 第一篇 | self / community-manager | 1h | L-007 | 短 devlog "夜市採購大作戰已上架"，含開發里程碑回顧 |
| L-012 | Performance profile：載入時間 & FPS | self / performance-analyst | 1h | L-001 | 中階筆電 Chrome 載入 <8s；steady-state 60fps；產出短 profile 報告 |

**Nice to Have 小計：~2h**

**總計：Must (11.5h) + Should (3h) + Nice (2h) = 16.5h** — 落在 ~16h 工時 + 5h buffer 內。

## Carryover from Previous Sprint

無 — 這是第一個 formal sprint。先前以 per-version commits ship 至 v0.53。

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Web build size >20MB（CJK font + assets） | Medium | High（拖累載入體驗） | L-001 用 godot-specialist memory 的 CJK subset 模式；如 >20MB，先 ship 較小的英文版本，CJK 為 V1.1 |
| Firefox drag/audio 行為與 Chrome 不同 | Medium | Medium（操作可用即可） | L-001 顯式測兩個 browser；任一壞掉降為 known issue 寫入 README |
| itch.io 頁面素材時間爆炸（GIF 製作） | High | Low | L-003 設 hard cap 4h；超過就用 3 張 screenshots + 簡短 GIF 出貨 |
| 第一次 fresh-clone test 揭露隱性 deps | Low | High（blocker） | L-005 排在 L-007 tag 前；如失敗 sprint 不結束 |
| 抽獎攤 random 在 Web build 不 deterministic | Low | Low | L-002 在 smoke check 順手記錄 3 次抽獎 outcome；如異常作為 bug 帶入下個 sprint |

## Dependencies on External Factors

- itch.io 帳號已存在（user 須確認）
- 無第三方 API / cloud service 依賴

## Definition of Done for this Sprint

- [ ] L-001 → L-007 全部 Done（Must Have）
- [ ] All 324 tests pass on fresh clone
- [ ] Smoke check `smoke-2026-05-30-v1.0.md` written
- [ ] Web build deployed to `exports/web/`，user 已在 Chrome 親自試玩
- [ ] `production/release-notes/v1.0.md` 存在
- [ ] Git tag v1.0 已建立（user 親自 push）
- [ ] itch.io 頁面素材包齊全（user 親自上傳）
- [ ] 無 S1/S2 bug 在 delivered features 中
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md` — to be created via `/qa-plan sprint` next)

## QA Plan

To be authored via `/qa-plan sprint` immediately after this sprint plan is written. Required for Production → Polish gate sign-off.

## Scope check

If implementation surfaces additions beyond this list, run `/scope-check launch-prep` to detect creep before continuing.
