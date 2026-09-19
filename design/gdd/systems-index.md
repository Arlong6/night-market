# Systems Index: 大夜班 (Night Shift)

> **Created**: 2026-09-04
> **Concept**: `design/gdd/game-concept-night-shift.md`
> **Art Bible**: `design/art/art-bible-night-shift.md`
> **Engine**: Unity 6.3 LTS / C# / Web
> **Review mode**: solo（TD-SYSTEM-BOUNDARY、PR-SCOPE、CD-SYSTEMS 已跳過）
> 舊專案（夜市）索引已改名為 `systems-index-night-market.md`。

## Overview

2-4 人連線第一人稱合作派對遊戲，共 19 個系統。連線是最大技術風險（新引擎＋
Web transport 未驗證），因此設計與原型順序以網路層優先。MVP 假設：「兩個朋友
透過瀏覽器連線，在一間超商裡合作應付客潮，能連玩 30 分鐘以上還想再開一班。」

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Session／房間系統 | Core | MVP | **Revised r4 (2026-09-13) — 待原型驗證，不再散文複審**（併入 netcode GDD） | [netcode-session.md](netcode-session.md) | — |
| 2 | 網路同步層 | Core | MVP | **Revised r4 (2026-09-13) — 待原型驗證，不再散文複審** | [netcode-session.md](netcode-session.md) | Session |
| 3 | 第一人稱控制器 | Core | MVP | Not Started | — | 網路同步層 |
| 4 | 攜帶與交付 | Gameplay | MVP | Not Started | — | FP控制器, 機台互動組, 客人系統, **商品資料庫** |
| 5 | 機台互動組 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫 |
| 6 | 商品資料庫 | Core | MVP | **Designed (2026-09-19)** — 待 /design-review | [product-database.md](product-database.md) | — |
| 7 | 客人系統 | Gameplay | MVP | Not Started | — | 網路同步層, 商品資料庫 |
| 8 | 波次導演 | Gameplay | MVP | Not Started | — | 客人系統, 遊戲時鐘, **商品資料庫**（軟） |
| 9 | 遊戲時鐘 | Core | MVP | Not Started | — | — |
| 10 | 窗外天色系統 | UI/Presentation | Vertical Slice | Not Started | — | 遊戲時鐘 |
| 11 | HUD 與需求 icon | UI | MVP | Not Started | — | 機台互動組, 客人系統, **商品資料庫** |
| 12 | 大廳 UI 與流程 | UI | MVP(輸碼加入)/VS(完整) | Not Started | — | Session |
| 13 | 結算畫面 | UI | MVP | Not Started | — | 評分邏輯, **商品資料庫**（軟） |
| 14 | 音效系統 | Audio | MVP(機台音效)/VS(全套) | Not Started | — | 機台互動組, 客人系統 |
| 15 | 評分邏輯 | Gameplay | MVP | Not Started | — | 商品資料庫 |
| 16 | 進度與解鎖 | Progression | Alpha/Full | Not Started | — | 評分邏輯 |
| 17 | 教學／第一班 | Meta | Alpha | Not Started | — | 波次導演 |
| 18 | 設定與無障礙 | Persistence | Alpha | Not Started | — | — |
| 19 | 單人練習模式 | Meta | Alpha | Not Started | — | 波次導演 |

## Priority Tiers

| Tier | Definition | 本作對應 |
|------|-----------|---------|
| **MVP** | 核心假設無法驗證就不算數的系統 | 1-9, 11, 13, 14(最小), 15, 12(僅輸碼) |
| **Vertical Slice** | 一班完整體驗（熬到天亮的情緒弧） | 10, 12(完整), 14(全套) |
| **Alpha** | 機制齊備粗胚 | 16, 17, 18, 19 |
| **Full Vision** | 內容完整（店型/裝飾全集） | 16 的長尾內容 |

## Dependency Map

### Foundation Layer (no dependencies)
1. Session／房間系統 — 一切連線的入口（MPS Sessions＋房間碼）
2. 商品資料庫 — 資料驅動之法：所有需求與 SKU 的單一真相源
3. 遊戲時鐘 — 21:00→08:00，導演與天色的共同骨幹

### Core Layer
1. 網路同步層 — depends on: Session（NGO 物件所有權、互動同步、RPC 慣例、重連）
2. 第一人稱控制器 — depends on: 網路同步層
3. 機台互動組 — depends on: 網路同步層, 商品資料庫
4. 客人系統 — depends on: 網路同步層, 商品資料庫
5. 評分邏輯 — depends on: 商品資料庫（純邏輯，EditMode 可測）

### Feature Layer
1. 攜帶與交付 — depends on: FP控制器, 機台互動組, 客人系統, 商品資料庫（搬運 ProductInstance）
2. 波次導演 — depends on: 客人系統, 遊戲時鐘, 商品資料庫（依站台配重抽樣，軟依賴）
3. 單人練習縮放 — depends on: 波次導演

### Presentation Layer
1. HUD 與需求 icon — depends on: 機台互動組, 客人系統, 商品資料庫（icon 查詢鍵）
2. 窗外天色系統 — depends on: 遊戲時鐘
3. 大廳 UI 與流程 — depends on: Session
4. 結算畫面 — depends on: 評分邏輯, 商品資料庫（display_label，軟依賴）
5. 音效系統 — depends on: 機台互動組, 客人系統

### Polish Layer
1. 進度與解鎖 — depends on: 評分邏輯
2. 教學／第一班 — depends on: 波次導演
3. 設定與無障礙 — depends on: —

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 網路同步層＋Session（合併設計） | MVP | Foundation/Core | technical-director, network-programmer | M |
| 2 | 商品資料庫 | MVP | Foundation | systems-designer | S |
| 3 | 第一人稱控制器 | MVP | Core | gameplay-programmer, game-designer | S |
| 4 | 機台互動組 | MVP | Core | game-designer, systems-designer | M |
| 5 | 客人系統 | MVP | Core | game-designer, ai-programmer | M |
| 6 | 評分邏輯 | MVP | Core | systems-designer | S |
| 7 | 波次導演＋遊戲時鐘（合併設計） | MVP | Feature | game-designer, systems-designer | M |
| 8 | 攜帶與交付 | MVP | Feature | game-designer | S |
| 9 | HUD 與需求 icon | MVP | Presentation | ux-designer, ui-programmer | S |
| 10 | 結算畫面 | MVP | Presentation | game-designer, ux-designer | S |
| 11 | 大廳 UI 與流程（MVP 版） | MVP | Presentation | ux-designer | S |
| 12 | 音效系統（機台音效） | MVP | Presentation | sound-designer | S |
| 13 | 窗外天色系統 | VS | Presentation | technical-artist | S |
| 14 | 其餘（16-19） | Alpha+ | — | — | — |

## Circular Dependencies

- None found。
- 注意「攜帶與交付 ↔ 客人系統」的介面邊界：客人只認「收到符合需求的商品」事件，
  不知道商品怎麼來——用事件契約切開，避免日後互相糾纏。

## High-Risk Systems

1. **網路同步層（最高風險）**：新引擎＋NGO 2.x＋Relay WSS on Web 無官方端到端範例
   ——**GDD 寫完直接做技術原型驗證，不等其他系統**
2. **機台互動組**：五站小手感是「忙得有節奏」的爽感來源，需大量調校
3. **波次導演**：「忙到爽 vs 忙到煩」一線之隔，數值全走商品資料庫以便快速迭代

## Progress Tracker

19 systems: 2 Revised r4 (待原型) / 1 Designed (待 review) / 0 Approved / 16 Not Started
（#1 Session＋#2 網路同步層 → netcode-session.md，2026-09-04 首版；r3 修訂 2026-09-06；
r4 修訂 2026-09-13，698→1224 行）

> **netcode GDD 的流程狀態（creative-director 於 r4 裁定）**：
> **r4 是最後一輪散文式評審，不再開 r5 六專家複審。** 四輪下來每一輪的 blocking 都長在
> 上一輪修補的縫隙裡，而約四成的確認項是「對一個沒人跑過的系統的斷言」——散文評審沒有
> 可以反駁它們的儀器。下一步是 (1) 重跑三張機械檢查、(2) **直接開 W1 技術原型**。
> 原型回填造成的變更走「回填 diff 複核」，不再開全審。
> **原型 W1 優先序**：P-10 → P-4/P-6/P-19（同一次 itch.io 部署）→ P-7 → P-3 ＋ OQ#1（與 AC22 聯測）
> → P-13/P-14/P-15 → P-9/P-16 → P-17/P-18/P-20。
> **W1 成功判準**：原型報告必須回填 [P] 表的「影響」欄——每條被推翻的假設要明講它殺掉了哪幾條 AC。
