// 商品資料庫 — 核心型別與純函式（純 C#，零 Unity 依賴）
//
// 規格來源：design/gdd/product-database.md（r3 修訂版）
// 目的：r3 終審裁定「不再開散文輪，去建那四個 C# 型別與其測試」。
//       這份實作刻意「照著 GDD 的字面寫」，不預先修正它——
//       測試撞到什麼，就是 GDD 真的欠什麼。
//
// ⚠ 語言版本：本機沒有 dotnet SDK，使用 Unity 6.3 內附的 Mono mcs（上限 C# 7.2）。
//   專案正式目標是 C# 9.0（technical-preferences.md），而 7.2 是它的子集，
//   所以這裡編得過的，在 Unity 裡一定編得過。反之不然——本原型不驗證 C# 8/9 特性。

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Linq;

namespace NightShift.ProductDatabase
{
    // ─────────────────────────────────────────────────────────────
    // 規則 1b：零值即無效。每個 enum 的 0 都是哨兵，且整數值顯式寫死。
    // 規則 1c：underlying type 亦凍結（此處為 byte，與快照 frozen_enum 一致）。
    // ─────────────────────────────────────────────────────────────

    public enum MachineFamily : byte
    {
        Invalid = 0,
        Shelf = 1,
        Oden = 2,
        Microwave = 3,
        CoffeeMachine = 4,
    }

    public enum SkuStatus : byte
    {
        Invalid = 0,
        Active = 1,
        Deprecated = 2,
    }

    public enum DemandKind : byte
    {
        Invalid = 0,
        Family = 1,
        Named = 2,
    }

    public enum MatchResult : byte
    {
        Unevaluated = 0,   // 零值即「未評估」，不是「通過」
        Match = 1,
        WrongFamily = 2,
        WrongSku = 3,
        Spoiled = 4,
    }

    /// <summary>一筆 SKU 的身份資料。immutable POCO，不繼承 UnityEngine.Object。</summary>
    public sealed class ProductEntry
    {
        public string SkuId { get; private set; }
        public byte NetworkIndex { get; private set; }
        public string DisplayLabel { get; private set; }
        public MachineFamily Family { get; private set; }
        public bool Nameable { get; private set; }
        public SkuStatus Status { get; private set; }

        public ProductEntry(string skuId, byte networkIndex, string displayLabel,
                            MachineFamily family, bool nameable, SkuStatus status)
        {
            SkuId = skuId;
            NetworkIndex = networkIndex;
            DisplayLabel = displayLabel;
            Family = family;
            Nameable = nameable;
            Status = status;
        }
    }

    /// <summary>
    /// 玩家手上那一份。AC23：唯一公開建構路徑是 Create()，兩個參數皆必填。
    /// ⚠ 但 default(ProductInstance) 在 C# 仍然可達——見測試 T-AC23b。
    /// </summary>
    public readonly struct ProductInstance
    {
        public readonly byte NetworkIndex;
        public readonly bool IsSpoiled;

        private ProductInstance(byte networkIndex, bool isSpoiled)
        {
            NetworkIndex = networkIndex;
            IsSpoiled = isSpoiled;
        }

        public static ProductInstance Create(byte networkIndex, bool isSpoiled)
        {
            if (networkIndex == 0)
                throw new ArgumentOutOfRangeException("networkIndex", "0 是 Invalid 哨兵，不得作為實體身份");
            return new ProductInstance(networkIndex, isSpoiled);
        }
    }

    /// <summary>
    /// 攤平的 tagged union。工廠在 IProductCatalog 上（它們需要查表才驗得動契約）。
    /// ⚠ 宣稱是「無法被**意外**地表示」，不是「無法被表示」——見測試 T-AC6c-b。
    /// </summary>
    public readonly struct CustomerDemand
    {
        public readonly DemandKind Kind;
        public readonly MachineFamily Family;
        public readonly byte NetworkIndex;

        internal CustomerDemand(DemandKind kind, MachineFamily family, byte networkIndex)
        {
            Kind = kind;
            Family = family;
            NetworkIndex = networkIndex;
        }
    }

    public interface IProductCatalog
    {
        ProductEntry Get(byte networkIndex);
        IReadOnlyList<ProductEntry> GetByMachineFamily(MachineFamily family);
        IReadOnlyList<ProductEntry> GetOrderable();
        IReadOnlyList<ProductEntry> GetNameable();

        CustomerDemand FamilyDemand(MachineFamily family);
        CustomerDemand NamedDemand(byte networkIndex);
    }

    public sealed class ProductCatalog : IProductCatalog
    {
        private readonly Dictionary<byte, ProductEntry> _byIndex;
        private readonly Dictionary<MachineFamily, IReadOnlyList<ProductEntry>> _byFamily;
        private readonly IReadOnlyList<ProductEntry> _orderable;
        private readonly IReadOnlyList<ProductEntry> _nameable;

        public ProductCatalog(ProductEntry[] entries)
        {
            _byIndex = new Dictionary<byte, ProductEntry>();
            foreach (var e in entries) _byIndex.Add(e.NetworkIndex, e);

            // 契約：算一次並快取，回傳同一份引用（AC16）
            _byFamily = new Dictionary<MachineFamily, IReadOnlyList<ProductEntry>>();
            foreach (MachineFamily f in Enum.GetValues(typeof(MachineFamily)))
            {
                if (f == MachineFamily.Invalid) continue;
                _byFamily[f] = entries.Where(e => e.Status == SkuStatus.Active && e.Family == f).ToArray();
            }
            _orderable = entries.Where(e => e.Status == SkuStatus.Active).ToArray();
            _nameable = entries.Where(e => e.Status == SkuStatus.Active && e.Nameable).ToArray();
        }

        public ProductEntry Get(byte networkIndex)
        {
            ProductEntry e;
            if (!_byIndex.TryGetValue(networkIndex, out e))
                throw new ArgumentOutOfRangeException("networkIndex",
                    "從未指派過的 network_index: " + networkIndex + "（含 0 = Invalid）");
            return e;   // deprecated 完整回傳，不丟例外、不回 null
        }

        public IReadOnlyList<ProductEntry> GetByMachineFamily(MachineFamily family)
        {
            IReadOnlyList<ProductEntry> r;
            if (!_byFamily.TryGetValue(family, out r)) return new ProductEntry[0];
            return r;
        }

        public IReadOnlyList<ProductEntry> GetOrderable() { return _orderable; }
        public IReadOnlyList<ProductEntry> GetNameable() { return _nameable; }

        public CustomerDemand FamilyDemand(MachineFamily family)
        {
            if (family == MachineFamily.Invalid)
                throw new ArgumentOutOfRangeException("family", "Invalid 是哨兵，不得作為需求家族");
            return new CustomerDemand(DemandKind.Family, family, 0);
        }

        public CustomerDemand NamedDemand(byte networkIndex)
        {
            if (networkIndex == 0)
                throw new ArgumentOutOfRangeException("networkIndex", "0 是 Invalid 哨兵");
            var e = Get(networkIndex);                       // 未指派值在此拋
            if (e.Status != SkuStatus.Active)
                throw new ArgumentOutOfRangeException("networkIndex", "指名需求不得指向非 Active 條目");
            if (!e.Nameable)
                throw new ArgumentOutOfRangeException("networkIndex", "該 SKU 的 nameable == false");
            return new CustomerDemand(DemandKind.Named, MachineFamily.Invalid, networkIndex);
        }
    }

    /// <summary>
    /// 純函式。r3 裁決：移出 IProductCatalog，避免測試夾具重新實作判定邏輯而假綠。
    /// catalog 是「資料來源」參數，不是「邏輯來源」。
    /// </summary>
    public static class ProductMatching
    {
        public static MatchResult Matches(IProductCatalog catalog, ProductInstance instance, CustomerDemand demand)
        {
            // ── 兩側輸入域先驗 ──
            var entry = catalog.Get(instance.NetworkIndex);

            if (demand.Kind == DemandKind.Invalid)
                throw new ArgumentOutOfRangeException("demand", "kind == Invalid");

            ProductEntry demandEntry = null;
            if (demand.Kind == DemandKind.Family)
            {
                if (demand.Family == MachineFamily.Invalid)
                    throw new ArgumentOutOfRangeException("demand", "Family 需求的 family == Invalid");
            }
            else
            {
                demandEntry = catalog.Get(demand.NetworkIndex);
                if (demandEntry.Status != SkuStatus.Active)
                    throw new ArgumentOutOfRangeException("demand", "指名需求指向非 Active 條目");
                if (!demandEntry.Nameable)
                    throw new ArgumentOutOfRangeException("demand", "指名需求指向 nameable == false 的 SKU");
            }

            // ── 驗完才判定 ──
            if (instance.IsSpoiled) return MatchResult.Spoiled;

            if (demand.Kind == DemandKind.Family)
                return entry.Family == demand.Family ? MatchResult.Match : MatchResult.WrongFamily;

            if (instance.NetworkIndex == demand.NetworkIndex) return MatchResult.Match;
            return entry.Family == demandEntry.Family ? MatchResult.WrongSku : MatchResult.WrongFamily;
        }

        /// <summary>
        /// 前置條件 : filled.Length == slots.Length
        /// 資格述詞 : Matches(instance, s) == Match          ← r3 新增，載重
        /// 優先序   : 候選槽中 Named 先於 Family
        /// 同優先序 : 索引較小且尚未填滿
        /// 無候選槽 : -1
        /// </summary>
        public static int AllocateSlot(IProductCatalog catalog, CustomerDemand[] slots, bool[] filled, ProductInstance instance)
        {
            if (slots == null) throw new ArgumentNullException("slots");
            if (filled == null) throw new ArgumentNullException("filled");
            if (filled.Length != slots.Length)
                throw new ArgumentException("filled 與 slots 長度必須相同", "filled");

            int bestNamed = -1, bestFamily = -1;
            for (int i = 0; i < slots.Length; i++)
            {
                if (filled[i]) continue;
                if (Matches(catalog, instance, slots[i]) != MatchResult.Match) continue;   // 資格述詞
                if (slots[i].Kind == DemandKind.Named) { if (bestNamed < 0) bestNamed = i; }
                else { if (bestFamily < 0) bestFamily = i; }
            }
            if (bestNamed >= 0) return bestNamed;
            return bestFamily;   // 無候選時 bestFamily 仍為 -1
        }
    }

    // ─────────────────────────────────────────────────────────────
    // AC17a：驗證器是純函式。不需要 build、不需要內容、不需要資產。
    // ─────────────────────────────────────────────────────────────

    public sealed class Violation
    {
        public string Rule { get; private set; }
        public string Detail { get; private set; }
        public Violation(string rule, string detail) { Rule = rule; Detail = detail; }
        public override string ToString() { return Rule + ": " + Detail; }
    }

    public static class ProductCatalogValidator
    {
        public const int HollerMaxChars = 4;        // sku_holler_max_chars
        public const int DisplayLabelMaxChars = 6;  // sku_display_label_max_chars
        public const int NameableMin = 2;           // sku_nameable_min（arlong 裁決）
        public const int NameableMax = 6;           // sku_nameable_max（art-director 推導）

        public static IReadOnlyList<Violation> Validate(ProductEntry[] entries)
        {
            var v = new List<Violation>();
            if (entries == null) { v.Add(new Violation("AC1b", "entries 為 null")); return v; }

            // AC1b — 現行表自我一致
            var seenId = new HashSet<string>();
            var seenIdx = new HashSet<byte>();
            foreach (var e in entries)
            {
                if (string.IsNullOrEmpty(e.SkuId)) v.Add(new Violation("AC1b", "sku_id 為空"));
                else if (!seenId.Add(e.SkuId)) v.Add(new Violation("AC1b", "sku_id 重複: " + e.SkuId));
                if (e.NetworkIndex == 0) v.Add(new Violation("AC1b", "network_index == 0: " + e.SkuId));
                else if (!seenIdx.Add(e.NetworkIndex)) v.Add(new Violation("AC1b", "network_index 重複: " + e.NetworkIndex));
                if (e.Status == SkuStatus.Invalid) v.Add(new Violation("AC1b", "status == Invalid: " + e.SkuId));
                if (e.Family == MachineFamily.Invalid) v.Add(new Violation("AC1b", "machine_family == Invalid: " + e.SkuId));
            }

            // AC2a — 標籤長度，依 nameable 分兩級
            foreach (var e in entries)
            {
                if (e.Status != SkuStatus.Active) continue;
                int len = string.IsNullOrEmpty(e.DisplayLabel) ? 0 : new StringInfo(e.DisplayLabel).LengthInTextElements;
                int max = e.Nameable ? HollerMaxChars : DisplayLabelMaxChars;
                if (len < 1) v.Add(new Violation("AC2a", "display_label 為空: " + e.SkuId));
                else if (len > max) v.Add(new Violation("AC2a",
                    "display_label 超長 (" + len + " > " + max + ", nameable=" + e.Nameable + "): " + e.SkuId));
            }

            // AC2b — 標籤唯一（Active）
            var norm = new Dictionary<string, string>();
            foreach (var e in entries)
            {
                if (e.Status != SkuStatus.Active || string.IsNullOrEmpty(e.DisplayLabel)) continue;
                var k = e.DisplayLabel.Trim().Normalize(NormalizationForm.FormKC).ToLowerInvariant();
                string prev;
                if (norm.TryGetValue(k, out prev)) v.Add(new Violation("AC2b", "display_label 重複: " + prev + " / " + e.SkuId));
                else norm.Add(k, e.SkuId);
            }

            // AC3 — 無空殼站台（∀ 非 Invalid 成員）
            foreach (MachineFamily f in Enum.GetValues(typeof(MachineFamily)))
            {
                if (f == MachineFamily.Invalid) continue;
                if (!entries.Any(e => e.Status == SkuStatus.Active && e.Family == f))
                    v.Add(new Violation("AC3", "家族無 Active 條目: " + f));
            }

            // AC20 — 指名池上下限
            int nameableCount = entries.Count(e => e.Status == SkuStatus.Active && e.Nameable);
            if (nameableCount < NameableMin) v.Add(new Violation("AC20", "nameable 低於 MVP 下限: " + nameableCount + " < " + NameableMin));
            if (nameableCount > NameableMax) v.Add(new Violation("AC20", "nameable 超過上限: " + nameableCount + " > " + NameableMax));

            return v;
        }
    }
}
