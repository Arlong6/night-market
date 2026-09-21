# 原型：商品資料庫核心（product-database-core）

> **狀態**：**已結案（concluded）** — 2026-09-21
> **來源**：`design/gdd/product-database.md` r3 複審終審裁定
> **評審紀錄**：`design/gdd/reviews/product-database-review-log.md`（r3 條目）

## 測試的假設

這個原型**不是**用來驗證玩法，也不是商品資料庫的實作起點。它回答的是一個**流程問題**：

> 商品資料庫的 GDD 經過三輪評審、十一位專家、約 220 條累計發現，寫到 1,593 行，
> 去規格一個只有 **4 個型別、1 個介面 6 個成員、2 個純函式、4 個 enum** 的資料層。
> **繼續寫文件，還是去建那四個型別？**

r3 的 creative-director 裁定「去建」，並附了一條**可證偽的 Design Test**：

> 若原型在以下五項裡**至少撞到三項**——AC6c 的建構路徑、AC6b／AC6c 互斥、
> AC11a 的家族量詞、AC13 案例 ④、`FakeProductCatalog` 的假綠——
> **則「不再開 r4 散文輪」這個裁決成立。**
> **若它一項都沒撞到，則裁決錯了**，r3 的專家比終審以為的更準，應該回去開 r4。

## 怎麼跑

本機沒有 dotnet SDK，改用 Unity 6.3 內附的 Mono：

```sh
cd prototypes/product-database-core
./run.sh
```

或手動：

```sh
M=/Applications/Unity/Hub/Editor/6000.3.24f1/Unity.app/Contents/Resources/Scripting/MonoBleedingEdge/bin
"$M/mcs" -langversion:7.2 -out:tests.exe ProductDatabase.cs Tests.cs
"$M/mono" tests.exe
```

⚠ **語言版本**：`mcs` 上限是 C# 7.2，而專案正式目標是 C# 9.0。7.2 是 9.0 的子集，
所以**這裡編得過的在 Unity 裡一定編得過；反之不然**。本原型不驗證 C# 8/9 特性。

## 兩種輸出，不要混為一談

| 標記 | 意義 |
|---|---|
| `PASS` / `FAIL` | **實作**測試。對照 r3 修訂後的 GDD。 |
| `TRIP` / `HOLDS` | **文件**探針。斷言的是「GDD **前一版**的字面應該為假」。`TRIP` ＝ 那句話確實是假的。 |

探針**刻意不計入** pass/fail。一個永遠帶著五個紅燈的測試套件，
它的紅燈會在第三天被學會忽略——而「學會忽略紅燈」正是這份 GDD 三輪來反覆被指出的失敗模式。

## 結果

```
實作測試   PASS 50 / FAIL 0
文件探針   TRIP  5 / HOLDS 0
→ Design Test 撞到 3 / 5：裁決成立，不再開 r4 散文輪。
```

### AC15a 已是一條活的絆線（不是宣稱，是實跑）

測試**真的去讀** `design/registry/sku-shipped-snapshot.txt`，並與現行 C# enum 雙向比對。
為了證明它不是恆真通過，做了三次汙染測試，**三次都亮紅、還原後回綠**：

| 汙染 | 結果 |
|---|---|
| `Oden = 2` / `Microwave = 3` **對調** | `AC15a-fwd` FAIL — 「不符：MachineFamily.Oden, MachineFamily.Microwave」 |
| underlying `byte` → `ushort`（規則 1c 禁止，r3 之前零 AC 覆蓋） | `AC15a-under` FAIL — 「不符：MachineFamily (現行 ushort)」 |
| 新增未登記成員 `HotDogRoller = 5` | `AC15a-rev` FAIL — 「缺列：MachineFamily.HotDogRoller」 |
| 還原 | 全部 PASS，50 / 0 |

第一項正是 r1 的 creative-director 排在**嚴重度／成本比最高**的那一類失敗
（enum 重排 → 既有資產語意靜默錯位 → 不編譯錯誤、不拋例外、直接出貨）。
**它現在有守衛了，而且守衛被證明會叫。**

### 另一條在原型裡才發現的缺陷

`AC15a-keyonce`：快照檔的**說明文字**裡若再出現一次區塊鍵的字面，
一個「切在第一個鍵上」的 parser 會切到註解、拿到空區塊，然後**靜默通過**。
r3 修訂當下就踩到了——那段解釋「這個鍵原本不存在」的註解自己寫了一次帶冒號的鍵名。
**這與同一輪在 AC12b 範本上抓到的 `gate1: PASS` 是同一個形狀：解釋漏洞的文字本身變成下一個漏洞。**
已修，並由 `AC15a-keyonce` 機器守——**不是靠註解裡的一句約定。**

### 撞到的三項（r2 的字面在執行下被推翻）

| # | Design Test 項目 | 執行結果 |
|---|---|---|
| 1 | **AC6c 的建構路徑** | r2 斷言「`CustomerDemand` **無其他公開建構路徑**」＋「讓非法狀態**無法被表示**」。實測：`default(CustomerDemand).Kind == Invalid`，`new CustomerDemand[3]` 給出三個非法實例。**對 `struct` 而言這句話在 C# 語言層面不可能為真。** r3 把宣稱降為「無法被**意外**地表示」是必要的，不是品味。 |
| 3 | **AC11a 的家族量詞** | r2 斷言「`GetByMachineFamily(f)` 的結果集**恰等於**原結果集 ∪ {e}」——對任意 `f`。實測：加入一筆 Oden 的 SKU 後，CoffeeMachine 家族預期 2 筆、實得 1 筆。**四個查詢裡三個不成立**，而 r2 用「同理」兩個字帶過。 |
| 4 | **AC13 案例 ④** | r2 的槽位規則字面只有「Named 先於 Family、索引較小、尚未填滿」，**沒有資格述詞**。實測：訂單 `[Family:Oden, Named:咖啡]` 交付一份黑輪，字面規則會把它分配到**槽 1（指名咖啡的槽）**，而正確答案是槽 0。**規則與它自己的驗收條目 AC13-⑤ 互相矛盾。** |

### 沒撞到的兩項（同樣是資訊）

| # | 項目 | 為什麼沒撞到 |
|---|---|---|
| 2 | AC6b／AC6c 互斥 | **r3 提的解法經執行確認可行。** r3 主張不需要 `InternalsVisibleTo` 後門——用「建構時合法、事後被下架／降級／移除」這三條路即可構造出 AC6b 要的非法 demand。三條路 `AC6b-a/b/c` 全部通過。 |
| 5 | `FakeProductCatalog` 假綠 | **r3 已經修掉了它**（純函式移出 `IProductCatalog`）。反事實仍留在 `SabotagedCatalogWithMatches`：若 `Matches()` 留在介面上，夾具**必須**自己實作它，於是 `FAKE-R2SHAPE` 那條測試全綠，而真實作從頭到尾沒被執行過。 |

## 發現（回填給 GDD 的內容）

**這些發現全部支持 r3 已經寫進 GDD 的修正，沒有一條要求新增規格。**
依終審給 r4 的處方 P1（「禁止新增斷言作為預設修法」），本原型的回填是**確認**，不是擴充：

1. **AC6c、AC23 的「無法被表示」宣稱，對 `struct` 一律要降為「無法被意外表示」。** 已在 GDD。
2. **AC11a 的量詞必須分「e 自己的家族」與「其餘家族」兩句。** 已在 GDD。
3. **`AllocateSlot` 的資格述詞是載重的，不是贅述。** 已在 GDD。
4. **AC17a 的驗證器確實是純函式**：空表、髒資料、門檻分級全部在**零 Unity、零資產、零 build**
   的情況下跑得動。這證實了 r3「軸 1 證據閘今天就生效」那條裁決——
   **r2 把 15 條 AC 整批降為 ADVISORY 是錯的。**
5. **AC17a-vacuum 值得單獨記一筆**：空表之下 AC3 與 AC20 **仍然亮紅**，
   不是恆真通過。這反過來確認了 r3 對 AC1b 的重新分類——**AC1b 的量詞域是現行 SKU 表，
   空表時恆真**，而 r2 曾宣稱它「不受真空影響」。

## 對這份原型自己的限制（誠實標示）

- **只覆蓋純 C# 的那一半。** 需要 Unity 或需要資產的部分沒驗：AC1a／AC4／AC4b／AC4c／
  AC14／AC15b／AC18／AC19／AC12b，以及**整個建置期閘門**。
  （**AC15a 是例外，它已驗**——見上方汙染測試。它只需要讀一個文字檔與反射現行 enum。）
- **AC22（`Spawn()` 前寫入）完全沒碰**——它需要雙行程 NGO 實測，屬 W2。
  而它是 r3 終審評為**最被低估**的一條。
- **C# 7.2 子集**，未驗證 C# 8/9 特性。
- 依 `.claude/rules/prototype-code.md`：**本原型的程式碼不得直接搬進 production**，
  真要實作時重寫。這裡的價值在 `Tests.cs` 記錄下來的那五個探針。

## 下一步

1. ~~有界修訂~~ ✅
2. ~~arlong 裁決 `nameable` 下限~~ ✅ N = 2
3. ~~純 C# 原型~~ ✅ 本檔
4. **用實作結果回填 GDD** —— 本原型的結論是「r3 的修正全部必要且充分」，
   **沒有要新增的斷言**。回填動作＝在 GDD 的相關條目旁註記「已由原型執行確認」。
5. **不再開散文輪。** 下一個評審對象應該是 Unity 專案裡的實作，不是這份文件。
