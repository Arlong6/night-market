// 商品資料庫核心 — 測試
//
// 這批測試的目的**不是**證明實作對，是回答 r3 終審的 Design Test：
//
//   「若原型在以下五項裡至少撞到三項——AC6c 的建構路徑、AC6b／AC6c 互斥、
//     AC11a 的家族量詞、AC13 案例 ④、FakeProductCatalog 的假綠——
//     則『不再開 r4 散文輪』這個裁決成立。若一項都沒撞到，則裁決錯了。」
//
// 因此每一條 Design Test 項目都有一條對應的測試，且**刻意跑 GDD 的字面**。
// 手刻 runner（本機無 dotnet SDK，NUnit 取不到）；判定是確定性的，無隨機、無時間相依。

using System;
using System.Collections.Generic;
using System.Linq;
using NightShift.ProductDatabase;

public static class Tests
{
    static int _pass, _fail, _tripped, _untripped;
    static readonly List<string> _failures = new List<string>();
    static readonly List<string> _trips = new List<string>();

    static void Check(string id, bool ok, string detail)
    {
        if (ok) { _pass++; Console.WriteLine("  PASS   " + id + "  " + detail); }
        else { _fail++; _failures.Add(id + " — " + detail); Console.WriteLine("  FAIL   " + id + "  " + detail); }
    }

    /// <summary>
    /// Design Test 探針：斷言的是「GDD 某個版本的字面**應該**為假」。
    /// 它不是實作的測試，是**文件的**測試。TRIP = 那句話確實是假的。
    /// 探針不計入 pass/fail，否則這個套件會永遠帶著紅燈，而紅燈會被學會忽略。
    /// </summary>
    static void Probe(string id, bool claimHolds, string detail)
    {
        if (!claimHolds) { _tripped++; _trips.Add(id + " — " + detail); Console.WriteLine("  TRIP   " + id + "  " + detail); }
        else { _untripped++; Console.WriteLine("  HOLDS  " + id + "  " + detail); }
    }

    static bool Throws<TEx>(Action a) where TEx : Exception
    {
        try { a(); return false; } catch (TEx) { return true; } catch { return false; }
    }

    // ── 測試資料：刻意做成「合法的最小 MVP 表」 ──
    const byte MiXue = 1, HeiLun = 2, GongWan = 3, Coffee = 4, Bento = 5, OniGiri = 6;

    static ProductEntry[] MakeEntries()
    {
        return new[]
        {
            //            sku_id      idx      label   family                    nameable status
            new ProductEntry("mi_xue",   MiXue,  "米血",  MachineFamily.Oden,          true,  SkuStatus.Active),
            new ProductEntry("hei_lun",  HeiLun, "黑輪",  MachineFamily.Oden,          false, SkuStatus.Active),
            new ProductEntry("gong_wan", GongWan,"貢丸",  MachineFamily.Oden,          false, SkuStatus.Active),
            new ProductEntry("coffee",   Coffee, "熱咖啡", MachineFamily.CoffeeMachine, true,  SkuStatus.Active),
            new ProductEntry("bento",    Bento,  "排骨便當",MachineFamily.Microwave,    false, SkuStatus.Active),
            new ProductEntry("onigiri",  OniGiri,"飯糰",  MachineFamily.Shelf,         false, SkuStatus.Active),
        };
    }

    static ProductCatalog MakeCatalog() { return new ProductCatalog(MakeEntries()); }

    public static int Main()
    {
        Console.WriteLine("商品資料庫核心原型 — r3 Design Test");
        Console.WriteLine(new string('=', 78));

        Section("AC5 — Matches() 家族模式");
        {
            var c = MakeCatalog();
            var fresh = ProductInstance.Create(MiXue, false);
            Check("AC5-a", ProductMatching.Matches(c, fresh, c.FamilyDemand(MachineFamily.Oden)) == MatchResult.Match, "米血 vs Family:Oden → Match");
            Check("AC5-b", ProductMatching.Matches(c, ProductInstance.Create(HeiLun, false), c.FamilyDemand(MachineFamily.Oden)) == MatchResult.Match, "黑輪 vs Family:Oden → Match（家族級不分哪一串）");
            Check("AC5-c", ProductMatching.Matches(c, ProductInstance.Create(Coffee, false), c.FamilyDemand(MachineFamily.Oden)) == MatchResult.WrongFamily, "咖啡 vs Family:Oden → WrongFamily");
        }

        Section("AC6 — Matches() 指名模式");
        {
            var c = MakeCatalog();
            Check("AC6-a", ProductMatching.Matches(c, ProductInstance.Create(MiXue, false), c.NamedDemand(MiXue)) == MatchResult.Match, "米血 vs Named:米血 → Match");
            Check("AC6-b", ProductMatching.Matches(c, ProductInstance.Create(HeiLun, false), c.NamedDemand(MiXue)) == MatchResult.WrongSku, "黑輪 vs Named:米血 → WrongSku（同家族仍不算）");
            Check("AC6-c", ProductMatching.Matches(c, ProductInstance.Create(Coffee, false), c.NamedDemand(MiXue)) == MatchResult.WrongFamily, "咖啡 vs Named:米血 → WrongFamily");
        }

        Section("AC7 — is_spoiled 短路（在輸入域驗證之後）");
        {
            var c = MakeCatalog();
            var rotten = ProductInstance.Create(MiXue, true);
            Check("AC7-a", ProductMatching.Matches(c, rotten, c.NamedDemand(MiXue)) == MatchResult.Spoiled, "壞掉的米血 vs Named:米血 → Spoiled");
            Check("AC7-b", ProductMatching.Matches(c, rotten, c.FamilyDemand(MachineFamily.Oden)) == MatchResult.Spoiled, "壞掉的米血 vs Family:Oden → Spoiled");
        }

        Section("AC8 / AC9 — Get() 契約");
        {
            var withDep = MakeEntries().ToList();
            withDep.Add(new ProductEntry("old_item", 200, "舊品", MachineFamily.Oden, false, SkuStatus.Deprecated));
            var c = new ProductCatalog(withDep.ToArray());
            Check("AC8", c.Get(200) != null && c.Get(200).Status == SkuStatus.Deprecated, "Get(deprecated) 完整回傳，不丟例外");
            Check("AC9-a", Throws<ArgumentOutOfRangeException>(() => c.Get(0)), "Get(0 = Invalid) 拋 ArgumentOutOfRangeException");
            Check("AC9-b", Throws<ArgumentOutOfRangeException>(() => c.Get(99)), "Get(未指派值) 拋 ArgumentOutOfRangeException");
        }

        Section("AC10 / AC16 — 查詢契約與快取");
        {
            var c = MakeCatalog();
            var noShelfEntries = MakeEntries().Where(e => e.Family != MachineFamily.Shelf).ToArray();
            var c2 = new ProductCatalog(noShelfEntries);
            Check("AC10", c2.GetByMachineFamily(MachineFamily.Shelf).Count == 0, "零筆 Active 的家族 → 空陣列，不丟例外");
            Check("AC16-a", !c.GetOrderable().Any(e => e.Status == SkuStatus.Deprecated), "GetOrderable() 不含 Deprecated");
            Check("AC16-b", ReferenceEquals(c.GetOrderable(), c.GetOrderable()), "連續兩次呼叫 ReferenceEquals == true（快取契約）");
            Check("AC16-c", ReferenceEquals(c.GetByMachineFamily(MachineFamily.Oden), c.GetByMachineFamily(MachineFamily.Oden)), "GetByMachineFamily 同上");
        }

        // ══════════════════════════════════════════════════════════════
        Section("【Design Test 1／5】AC6c — CustomerDemand 的建構路徑");
        // ══════════════════════════════════════════════════════════════
        {
            var c = MakeCatalog();
            Check("AC6c-a", Throws<ArgumentOutOfRangeException>(() => c.FamilyDemand(MachineFamily.Invalid)), "FamilyDemand(Invalid) 建構當下拋");
            Check("AC6c-b", Throws<ArgumentOutOfRangeException>(() => c.NamedDemand(0)), "NamedDemand(0) 建構當下拋");
            Check("AC6c-c", Throws<ArgumentOutOfRangeException>(() => c.NamedDemand(HeiLun)), "NamedDemand(nameable == false) 建構當下拋");

            // r2 的原文宣稱：「CustomerDemand 無其他公開建構路徑」＋「讓非法狀態無法被表示」
            var d = default(CustomerDemand);
            bool r2ClaimHolds = false;   // 若 default 不可達，這裡就到不了
            Probe("AC6c-R2CLAIM", r2ClaimHolds || d.Kind != DemandKind.Invalid,
                  "r2 宣稱『無其他公開建構路徑／非法狀態無法被表示』 → default(CustomerDemand).Kind == " + d.Kind);

            var arr = new CustomerDemand[3];
            Probe("AC6c-R2CLAIM-b", arr.All(x => x.Kind != DemandKind.Invalid),
                  "new CustomerDemand[3] 給出三個 Kind == " + arr[0].Kind + " 的實例");

            Check("AC6c-r3", Throws<ArgumentOutOfRangeException>(() => ProductMatching.Matches(c, ProductInstance.Create(MiXue, false), d)),
                  "r3 的降級版宣稱（無法被『意外』表示）：default 落在哨兵上，由 Matches() 攔截");
        }

        // ══════════════════════════════════════════════════════════════
        Section("【Design Test 2／5】AC6b 與 AC6c 是否互斥");
        // ══════════════════════════════════════════════════════════════
        {
            // AC6b 要求：把指向 deprecated／nameable==false／未指派值的 demand 餵進 Matches()，
            // 期待它拋。AC6c 要求：那種 demand 建構不出來。兩條都是 MVP-必達。
            // r3 宣稱不需要 InternalsVisibleTo：用「建構時合法、事後被下架」這條路。
            var before = MakeEntries();
            var cBefore = new ProductCatalog(before);
            var demand = cBefore.NamedDemand(MiXue);            // 此刻完全合法

            var after = before.Select(e => e.SkuId == "mi_xue"
                ? new ProductEntry(e.SkuId, e.NetworkIndex, e.DisplayLabel, e.Family, e.Nameable, SkuStatus.Deprecated)
                : e).ToArray();
            var cAfter = new ProductCatalog(after);

            Check("AC6b-a", Throws<ArgumentOutOfRangeException>(() => ProductMatching.Matches(cAfter, ProductInstance.Create(HeiLun, false), demand)),
                  "指向已被下架的 SKU 的 demand → Matches() 拋（無需 InternalsVisibleTo）");

            // 但「未指派值」與「nameable == false」這兩類呢？
            var cNoMiXue = new ProductCatalog(before.Where(e => e.SkuId != "mi_xue").ToArray());
            Check("AC6b-b", Throws<ArgumentOutOfRangeException>(() => ProductMatching.Matches(cNoMiXue, ProductInstance.Create(HeiLun, false), demand)),
                  "指向已從表中消失的 SKU 的 demand → Matches() 拋");

            var demoted = before.Select(e => e.SkuId == "mi_xue"
                ? new ProductEntry(e.SkuId, e.NetworkIndex, e.DisplayLabel, e.Family, false, e.Status)
                : e).ToArray();
            var cDemoted = new ProductCatalog(demoted);
            Check("AC6b-c", Throws<ArgumentOutOfRangeException>(() => ProductMatching.Matches(cDemoted, ProductInstance.Create(HeiLun, false), demand)),
                  "nameable 由 true 降級為 false 之後的舊 demand → Matches() 拋");
        }

        // ══════════════════════════════════════════════════════════════
        Section("【Design Test 3／5】AC11a — 家族量詞");
        // ══════════════════════════════════════════════════════════════
        {
            var baseEntries = MakeEntries();
            var cOld = new ProductCatalog(baseEntries);
            var oldOden = cOld.GetByMachineFamily(MachineFamily.Oden).ToArray();
            var oldCoffee = cOld.GetByMachineFamily(MachineFamily.CoffeeMachine).ToArray();

            var e2 = new ProductEntry("tian_bu_la", 7, "甜不辣", MachineFamily.Oden, false, SkuStatus.Active);
            var cNew = new ProductCatalog(baseEntries.Concat(new[] { e2 }).ToArray());

            var newOden = cNew.GetByMachineFamily(MachineFamily.Oden).ToArray();
            var newCoffee = cNew.GetByMachineFamily(MachineFamily.CoffeeMachine).ToArray();

            Check("AC11a-r3-a", newOden.Length == oldOden.Length + 1 && newOden.Contains(e2),
                  "e 自己的家族：結果集恰等於原結果集 ∪ {e}");
            Check("AC11a-r3-b", newCoffee.Length == oldCoffee.Length && !newCoffee.Contains(e2),
                  "其餘家族：結果集逐一不變（r3 的量詞）");

            // r2 的原文：「GetByMachineFamily(f) 的結果集恰等於原結果集 ∪ {e}」——對任意 f。
            bool r2WouldHold = newCoffee.Length == oldCoffee.Length + 1 && newCoffee.Contains(e2);
            Probe("AC11a-R2CLAIM", r2WouldHold,
                  "r2 的量詞（對任意 f 皆 ∪{e}）在 CoffeeMachine 上：預期 " + (oldCoffee.Length + 1) + " 筆、實得 " + newCoffee.Length + " 筆");

            // 「GetOrderable()／GetNameable() 同理」
            bool orderableUnion = cNew.GetOrderable().Count == cOld.GetOrderable().Count + 1;
            bool nameableUnion = cNew.GetNameable().Count == cOld.GetNameable().Count + 1;
            Probe("AC11a-R2CLAIM-b", orderableUnion && nameableUnion,
                  "r2 的『GetOrderable()／GetNameable() 同理』：orderable " + (orderableUnion ? "成立" : "成立") + "、nameable " + (nameableUnion ? "成立" : "不成立（e2 不是 nameable）"));
        }

        // ══════════════════════════════════════════════════════════════
        Section("【Design Test 4／5】AC13 — 槽位分配，特別是案例 ④");
        // ══════════════════════════════════════════════════════════════
        {
            var c = MakeCatalog();
            var miXueFresh = ProductInstance.Create(MiXue, false);
            var heiLunFresh = ProductInstance.Create(HeiLun, false);
            var coffeeFresh = ProductInstance.Create(Coffee, false);

            // ① 同時符合 Named 與 Family → Named 槽
            var o1 = new[] { c.FamilyDemand(MachineFamily.Oden), c.NamedDemand(MiXue) };
            Check("AC13-1", ProductMatching.AllocateSlot(c, o1, new bool[2], miXueFresh) == 1, "① Named 優先於 Family → 槽 1");

            // ② 兩個 Named 指向同一 SKU，連續兩次交付
            var o2 = new[] { c.NamedDemand(MiXue), c.NamedDemand(MiXue) };
            var f2 = new bool[2];
            int a = ProductMatching.AllocateSlot(c, o2, f2, miXueFresh); f2[a] = true;
            int b = ProductMatching.AllocateSlot(c, o2, f2, miXueFresh);
            Check("AC13-2", a == 0 && b == 1, "② 先填索引較小者、再填另一個 → 0 然後 1");

            // ③ 三槽混合
            var o3 = new[] { c.FamilyDemand(MachineFamily.Oden), c.NamedDemand(MiXue), c.FamilyDemand(MachineFamily.Oden) };
            var f3 = new bool[3];
            int s1 = ProductMatching.AllocateSlot(c, o3, f3, heiLunFresh); f3[s1] = true;
            int s2 = ProductMatching.AllocateSlot(c, o3, f3, miXueFresh); f3[s2] = true;
            int s3 = ProductMatching.AllocateSlot(c, o3, f3, heiLunFresh);
            Check("AC13-3", s1 == 0 && s2 == 1 && s3 == 2, "③ 三槽混合依交付序 → 0／1／2（實得 " + s1 + "／" + s2 + "／" + s3 + "）");

            // ④ 跨家族混合 —— r2 只給了標題，沒有期望值
            var o4 = new[] { c.FamilyDemand(MachineFamily.Oden), c.NamedDemand(Coffee) };
            int c4a = ProductMatching.AllocateSlot(c, o4, new bool[2], coffeeFresh);
            int c4b = ProductMatching.AllocateSlot(c, o4, new bool[2], heiLunFresh);
            Check("AC13-4a", c4a == 1, "④ 跨家族混合，交付咖啡 → 槽 1（實得 " + c4a + "）");
            Check("AC13-4b", c4b == 0, "④ 跨家族混合，交付黑輪 → 槽 0（實得 " + c4b + "）");

            // ④ 的反事實：若拿掉資格述詞（r2 的字面規則），黑輪會落到哪？
            int withoutPredicate = -1;
            for (int i = 0; i < o4.Length; i++) if (o4[i].Kind == DemandKind.Named) { withoutPredicate = i; break; }
            Probe("AC13-4-R2RULE", withoutPredicate == 0,
                  "r2 字面規則（Named 先於 Family、索引較小、無資格述詞）交付黑輪 → 槽 " + withoutPredicate + "，而正確答案是 0");

            // ⑤ 無可用槽
            Check("AC13-5", ProductMatching.AllocateSlot(c, o1, new bool[2], ProductInstance.Create(OniGiri, false)) == -1, "⑤ 商品不匹配任何槽 → -1");
            // ⑥ 零槽
            Check("AC13-6", ProductMatching.AllocateSlot(c, new CustomerDemand[0], new bool[0], miXueFresh) == -1, "⑥ 零槽 → -1");
            // ⑦ filled 長度不符
            Check("AC13-7", Throws<ArgumentException>(() => ProductMatching.AllocateSlot(c, o1, new bool[5], miXueFresh)), "⑦ filled.Length != slots.Length → 拋 ArgumentException");
        }

        // ══════════════════════════════════════════════════════════════
        Section("【Design Test 5／5】FakeProductCatalog 的假綠");
        // ══════════════════════════════════════════════════════════════
        {
            // r3 把 Matches()／AllocateSlot() 移出了 IProductCatalog，所以 fake 只能供給資料。
            var fake = new FakeProductCatalog(MakeEntries());
            var result = ProductMatching.Matches(fake, ProductInstance.Create(Coffee, false), fake.FamilyDemand(MachineFamily.Oden));
            Check("FAKE-r3", result == MatchResult.WrongFamily,
                  "r3：fake 只供資料，判定邏輯仍是真的 → 咖啡 vs Family:Oden = " + result);

            // 反事實：若 Matches() 留在介面上（r2 的形狀），fake 必須自己實作它。
            var sabotaged = new SabotagedCatalogWithMatches();
            Check("FAKE-R2SHAPE", sabotaged.Matches(ProductInstance.Create(Coffee, false), fake.FamilyDemand(MachineFamily.Oden)) == MatchResult.WrongFamily,
                  "r2 形狀：fake 自己實作 Matches()，回 " + sabotaged.Matches(ProductInstance.Create(Coffee, false), fake.FamilyDemand(MachineFamily.Oden)) + "（真實作永遠沒被執行）");
        }

        Section("AC17a — 驗證器是純函式（不需 build、不需內容、不需資產）");
        {
            Check("AC17a-clean", ProductCatalogValidator.Validate(MakeEntries()).Count == 0, "乾淨資料 → 零 Violation");

            var dirtyIdx0 = MakeEntries(); dirtyIdx0[0] = new ProductEntry("mi_xue", 0, "米血", MachineFamily.Oden, true, SkuStatus.Active);
            Check("AC17a-idx0", ProductCatalogValidator.Validate(dirtyIdx0).Any(x => x.Rule == "AC1b"), "network_index == 0 → AC1b Violation");

            var dirtyLabel = MakeEntries(); dirtyLabel[0] = new ProductEntry("mi_xue", MiXue, "特濃黑咖啡", MachineFamily.Oden, true, SkuStatus.Active);
            Check("AC17a-label", ProductCatalogValidator.Validate(dirtyLabel).Any(x => x.Rule == "AC2a"), "nameable 標籤 5 字 → AC2a Violation");

            var famFiller5 = MakeEntries();   // nameable == false 的 5 字標籤：分級表允許，AC2a 不得擋
            famFiller5[4] = new ProductEntry("bento", Bento, "排骨雞腿飯", MachineFamily.Microwave, false, SkuStatus.Active);
            Check("AC17a-tier", !ProductCatalogValidator.Validate(famFiller5).Any(x => x.Rule == "AC2a"), "家族填充型 5 字 → 不得產生 AC2a Violation（門檻適用分級）");

            var emptyFamily = MakeEntries().Where(e => e.Family != MachineFamily.Shelf).ToArray();
            Check("AC17a-ac3", ProductCatalogValidator.Validate(emptyFamily).Any(x => x.Rule == "AC3"), "某家族零筆 Active → AC3 Violation");

            var oneNameable = MakeEntries().Select(e => e.SkuId == "coffee"
                ? new ProductEntry(e.SkuId, e.NetworkIndex, e.DisplayLabel, e.Family, false, e.Status) : e).ToArray();
            Check("AC17a-ac20", ProductCatalogValidator.Validate(oneNameable).Any(x => x.Rule == "AC20"), "nameable 只剩 1 筆 → AC20 下限 Violation");

            Check("AC17a-vacuum", ProductCatalogValidator.Validate(new ProductEntry[0]).Any(x => x.Rule == "AC3"),
                  "空表 → AC3／AC20 仍然亮紅（不是恆真通過）");
        }

        Section("AC15a — enum 宣告未被更動（真的去讀快照檔，不是模擬）");
        {
            string path = FindSnapshot();
            if (path == null)
            {
                Check("AC15a-file", false, "找不到 design/registry/sku-shipped-snapshot.txt");
            }
            else
            {
                string txt = System.IO.File.ReadAllText(path);

                // ⚠ 這一條抓的是 r3 修訂當下自己踩到的坑：
                //    說明文字裡若再出現一次區塊鍵的字面，切在「第一個鍵」上的 parser
                //    會切到註解、拿到空區塊，然後**靜默通過**。
                int keyCount = CountOccurrences(txt, "\nfrozen_enum:");
                Check("AC15a-keyonce", keyCount == 1, "區塊鍵在全檔恰好出現 1 次（實得 " + keyCount + "）——說明文字不得重複它的字面");

                var snap = ParseFrozenEnum(txt);
                Check("AC15a-parse", snap.Count > 0, "區塊可解析，取得 " + snap.Count + " 組 (型別.成員 → 整數值)");

                // 雙向比對：快照 → 現行宣告
                var live = new Dictionary<string, long>();
                var underlying = new Dictionary<string, string>();
                foreach (var t in new[] { typeof(MachineFamily), typeof(SkuStatus), typeof(DemandKind), typeof(MatchResult) })
                {
                    underlying[t.Name] = Enum.GetUnderlyingType(t).Name.ToLowerInvariant().Replace("int16", "short").Replace("int32", "int");
                    foreach (var n in Enum.GetNames(t))
                        live[t.Name + "." + n] = Convert.ToInt64(Enum.Parse(t, n));
                }

                var missingInLive = snap.Where(kv => !live.ContainsKey(kv.Key) || live[kv.Key] != kv.Value).Select(kv => kv.Key).ToList();
                var missingInSnap = live.Keys.Where(k => !snap.ContainsKey(k)).ToList();
                Check("AC15a-fwd", missingInLive.Count == 0, "快照 → 現行宣告：全部一致" + (missingInLive.Count > 0 ? "（不符：" + string.Join(", ", missingInLive) + "）" : ""));
                Check("AC15a-rev", missingInSnap.Count == 0, "現行宣告 → 快照：全部有登記" + (missingInSnap.Count > 0 ? "（缺列：" + string.Join(", ", missingInSnap) + "）" : ""));

                var snapUnder = ParseUnderlying(txt);
                var underMismatch = underlying.Where(kv => !snapUnder.ContainsKey(kv.Key) || snapUnder[kv.Key] != kv.Value).Select(kv => kv.Key + " (現行 " + kv.Value + ")").ToList();
                Check("AC15a-under", underMismatch.Count == 0, "underlying type 全部凍結為快照登記的值" + (underMismatch.Count > 0 ? "（不符：" + string.Join(", ", underMismatch) + "）" : ""));

                // 缺席即失敗，不得視為通過
                Check("AC15a-absent", ParseFrozenEnum("# 沒有區塊鍵的檔案\n").Count == 0 && !HasBlock("# 沒有區塊鍵的檔案\n"),
                      "區塊缺席時 parser 回報缺席（呼叫端據此判失敗，不得視為通過）");
            }
        }

        Section("AC23 — ProductInstance 的建構路徑");
        {
            Check("AC23-a", Throws<ArgumentOutOfRangeException>(() => ProductInstance.Create(0, false)), "Create(0, _) 拋例外");
            var d = default(ProductInstance);
            Check("AC23-b", d.NetworkIndex == 0,
                  "default(ProductInstance).NetworkIndex == " + d.NetworkIndex + "（『無法被表示』對 struct 仍為假，靠 AC9 哨兵攔截）");
            var c = MakeCatalog();
            Check("AC23-c", Throws<ArgumentOutOfRangeException>(() => ProductMatching.Matches(c, d, c.FamilyDemand(MachineFamily.Oden))),
                  "未設定的 ProductInstance 進 Matches() → 撞 Invalid 哨兵並拋");
        }

        Console.WriteLine();
        Console.WriteLine(new string('=', 78));
        Console.WriteLine("實作測試   PASS " + _pass + " / FAIL " + _fail);
        Console.WriteLine("文件探針   TRIP " + _tripped + " / HOLDS " + _untripped + "（TRIP = GDD 前一版的字面確實為假）");
        if (_failures.Count > 0)
        {
            Console.WriteLine();
            Console.WriteLine("實作失敗：");
            foreach (var f in _failures) Console.WriteLine("  - " + f);
        }
        if (_trips.Count > 0)
        {
            Console.WriteLine();
            Console.WriteLine("探針觸發（r2 的字面在執行下被推翻，r3 的修正因此是必要的、不是品味）：");
            foreach (var t in _trips) Console.WriteLine("  - " + t);
        }
        Console.WriteLine();
        Console.WriteLine("── r3 終審 Design Test 記分 ──");
        Console.WriteLine("  判準：五項裡至少撞到三項 → 「不再開 r4 散文輪」成立；一項都沒撞到 → 裁決錯了。");
        Console.WriteLine("  1. AC6c 的建構路徑          " + (_trips.Any(t => t.StartsWith("AC6c-R2CLAIM")) ? "撞到" : "沒撞到"));
        Console.WriteLine("  2. AC6b／AC6c 互斥           沒撞到（r3 提的解法經執行確認可行，見 AC6b-a/b/c）");
        Console.WriteLine("  3. AC11a 的家族量詞         " + (_trips.Any(t => t.StartsWith("AC11a-R2CLAIM")) ? "撞到" : "沒撞到"));
        Console.WriteLine("  4. AC13 案例 ④              " + (_trips.Any(t => t.StartsWith("AC13-4-R2RULE")) ? "撞到" : "沒撞到"));
        Console.WriteLine("  5. FakeProductCatalog 假綠   沒撞到（r3 已把純函式移出介面；反事實見 FAKE-R2SHAPE）");
        int hit = (_trips.Any(t => t.StartsWith("AC6c-R2CLAIM")) ? 1 : 0)
                + (_trips.Any(t => t.StartsWith("AC11a-R2CLAIM")) ? 1 : 0)
                + (_trips.Any(t => t.StartsWith("AC13-4-R2RULE")) ? 1 : 0);
        Console.WriteLine("  → 撞到 " + hit + " / 5：" + (hit >= 3 ? "裁決成立，不再開 r4 散文輪。" : hit == 0 ? "裁決錯了，應回去開 r4。" : "未達判準，需人工裁定。"));
        return _fail == 0 ? 0 : 1;
    }

    // ── AC15a 的快照解析（刻意寫得跟 build hook 會用的一樣簡單） ──

    static string FindSnapshot()
    {
        var d = new System.IO.DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
        for (int i = 0; i < 6 && d != null; i++, d = d.Parent)
        {
            var p = System.IO.Path.Combine(d.FullName, "design/registry/sku-shipped-snapshot.txt");
            if (System.IO.File.Exists(p)) return p;
        }
        return null;
    }

    static int CountOccurrences(string haystack, string needle)
    {
        int n = 0, i = 0;
        while ((i = haystack.IndexOf(needle, i, StringComparison.Ordinal)) >= 0) { n++; i += needle.Length; }
        return n;
    }

    static bool HasBlock(string txt)
    {
        return txt.StartsWith("frozen_enum:", StringComparison.Ordinal) || txt.Contains("\nfrozen_enum:");
    }

    static string BlockBody(string txt)
    {
        int i = txt.IndexOf("\nfrozen_enum:", StringComparison.Ordinal);
        if (i < 0) return null;
        string rest = txt.Substring(i + "\nfrozen_enum:".Length);
        int j = rest.IndexOf("\nsku:", StringComparison.Ordinal);
        return j < 0 ? rest : rest.Substring(0, j);
    }

    static Dictionary<string, long> ParseFrozenEnum(string txt)
    {
        var r = new Dictionary<string, long>();
        var body = BlockBody(txt);
        if (body == null) return r;
        foreach (var raw in body.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith("#")) continue;
            int eq = line.IndexOf('=');
            if (eq < 0) continue;
            var key = line.Substring(0, eq).Trim();
            var val = line.Substring(eq + 1).Trim();
            if (key.Contains(":")) continue;          // underlying 行另外處理
            long n;
            if (key.Contains(".") && long.TryParse(val, out n)) r[key] = n;
        }
        return r;
    }

    static Dictionary<string, string> ParseUnderlying(string txt)
    {
        var r = new Dictionary<string, string>();
        var body = BlockBody(txt);
        if (body == null) return r;
        foreach (var raw in body.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith("#")) continue;
            int eq = line.IndexOf('=');
            if (eq < 0) continue;
            var key = line.Substring(0, eq).Trim();
            var val = line.Substring(eq + 1).Trim();
            if (key.EndsWith(":underlying")) r[key.Substring(0, key.Length - ":underlying".Length)] = val;
        }
        return r;
    }

    static void Section(string name)
    {
        Console.WriteLine();
        Console.WriteLine("── " + name + " " + new string('─', Math.Max(0, 74 - name.Length)));
    }
}

/// <summary>r3 形狀的測試夾具：只供給資料，碰不到判定邏輯。</summary>
public sealed class FakeProductCatalog : IProductCatalog
{
    private readonly ProductCatalog _inner;
    public FakeProductCatalog(ProductEntry[] entries) { _inner = new ProductCatalog(entries); }
    public ProductEntry Get(byte i) { return _inner.Get(i); }
    public IReadOnlyList<ProductEntry> GetByMachineFamily(MachineFamily f) { return _inner.GetByMachineFamily(f); }
    public IReadOnlyList<ProductEntry> GetOrderable() { return _inner.GetOrderable(); }
    public IReadOnlyList<ProductEntry> GetNameable() { return _inner.GetNameable(); }
    public CustomerDemand FamilyDemand(MachineFamily f) { return _inner.FamilyDemand(f); }
    public CustomerDemand NamedDemand(byte i) { return _inner.NamedDemand(i); }
}

/// <summary>
/// r2 形狀的反事實：Matches() 若在介面上，夾具就**必須**自己實作它。
/// 這裡刻意寫一個「看起來對、實際是自己那一套」的版本——它會讓測試全綠，
/// 而真正的 ProductMatching.Matches() 從頭到尾沒有被執行過。
/// </summary>
public sealed class SabotagedCatalogWithMatches
{
    public MatchResult Matches(ProductInstance instance, CustomerDemand demand)
    {
        // 夾具作者「照著 GDD 重寫了一次」，而且寫對了——今天。
        // 明天真實作改了規則，這裡不會跟著改，測試仍然全綠。
        if (instance.IsSpoiled) return MatchResult.Spoiled;
        if (demand.Kind == DemandKind.Family)
            return instance.NetworkIndex == 4 ? MatchResult.WrongFamily : MatchResult.Match;
        return instance.NetworkIndex == demand.NetworkIndex ? MatchResult.Match : MatchResult.WrongSku;
    }
}
