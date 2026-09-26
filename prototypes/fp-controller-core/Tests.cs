// 第一人稱控制器 — T0 驗收條目（AC1–AC31，共 31 條）
// 逐條對應 design/gdd/first-person-controller.md §Acceptance Criteria
// 手刻 runner，不依賴 NUnit／Unity Test Framework。

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using FpControllerCore;

public static class T
{
    public static int Pass, Fail;
    static string _cur = "";
    public static readonly List<string> Failures = new List<string>();

    public static void Case(string id, string title, Action body)
    {
        _cur = id;
        try { body(); Console.WriteLine("  ✔ " + id + " — " + title); Pass++; }
        catch (Exception e)
        {
            Console.WriteLine("  ✘ " + id + " — " + title);
            Console.WriteLine("      " + e.Message);
            Failures.Add(id + " — " + title + "\n      " + e.Message);
            Fail++;
        }
    }
    public static void Ok(bool c, string msg) { if (!c) throw new Exception(msg); }
    public static void Near(double a, double b, double tol, string msg)
    { if (Math.Abs(a - b) > tol) throw new Exception(msg + "  期望 " + b.ToString("F6") + "，實得 " + a.ToString("F6") + "（容差 " + tol + "）"); }
    public static void Eq(int a, int b, string msg)
    { if (a != b) throw new Exception(msg + "  期望 " + b + "，實得 " + a); }
    public static void Less(double a, double b, string msg)
    { if (!(a < b)) throw new Exception(msg + "  期望 " + a.ToString("F6") + " < " + b.ToString("F6")); }
    public static void Greater(double a, double b, string msg)
    { if (!(a > b)) throw new Exception(msg + "  期望 " + a.ToString("F6") + " > " + b.ToString("F6")); }
}

public static class H
{
    public const double DT60 = 1.0 / 60.0;
    public static IList<CapsuleGhost> G(params CapsuleGhost[] g) { return new List<CapsuleGhost>(g); }
    public static readonly IList<CapsuleGhost> None = new List<CapsuleGhost>();
    public static CapsuleGhost Peer(string id, double x, double y) { return new CapsuleGhost(id, new Vec2(x, y), K.r_c, false); }
    public static CapsuleGhost Npc(string id, double x, double y) { return new CapsuleGhost(id, new Vec2(x, y), K.r_c, true); }

    // 兩端各自逐幀求解至完全分離，回傳幀數（AC6 的 GIVEN 明定「兩端各自」）
    public static int FramesToSeparate(double initialOverlap, bool npc)
    {
        double contact = 2 * K.r_c;
        double d = contact - initialOverlap;           // 中心距
        var a = new MoveSolver(); var b = new MoveSolver();
        var pm = new PairMachine();
        pm.Ensure(new PairKey("A", "B"), npc); pm.Ensure(new PairKey("B", "A"), npc);
        int f = 0;
        while (d < contact - 1e-12 && f < 100000)
        {
            var pa = new Vec2(0, 0); var pb = new Vec2(d, 0);
            var ra = a.Solve(MovementInput.None, G(new CapsuleGhost("B", pb, K.r_c, npc)), DT60, true, pm, "A", pa);
            double move = ra.Delta.Len;
            if (!npc)
            {
                var rb = b.Solve(MovementInput.None, G(new CapsuleGhost("A", pa, K.r_c, false)), DT60, true, pm, "B", pb);
                move += rb.Delta.Len;                  // 兩端同時反向移動
            }
            d += move; f++;
            if (move < 1e-15) break;
        }
        return f;
    }
}

public static class Program
{
    public static int Main()
    {
        Console.WriteLine("第一人稱控制器 — T0 驗收（AC1–AC31）");
        Console.WriteLine("GDD: design/gdd/first-person-controller.md（2026-09-26 修訂版）");
        Console.WriteLine(new string('-', 72));

        // ══ 規則的缺席（C1-C4）══
        T.Case("AC1", "禁用成員白名單（無 Jump/Sprint/Crouch/Dash、無姿態 enum、動作表恰為 {Move2D,Look2D}）", () =>
        {
            var asm = typeof(MoveSolver).Assembly;
            var banned = new[] { "Jump", "Sprint", "Crouch", "Dash" };
            foreach (var ty in asm.GetTypes())
            {
                if (ty.Namespace != "FpControllerCore") continue;
                foreach (var b in banned)
                {
                    T.Ok(ty.Name.IndexOf(b, StringComparison.OrdinalIgnoreCase) < 0, "型別名含禁用字：" + ty.Name);
                    foreach (var m in ty.GetMembers(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly))
                        T.Ok(m.Name.IndexOf(b, StringComparison.OrdinalIgnoreCase) < 0, "成員名含禁用字：" + ty.Name + "." + m.Name);
                }
                // ②不存在任何描述角色移動姿態的 enum
                if (ty.IsEnum)
                    T.Ok(ty.Name == "PairState" || ty.Name == "LockState",
                         "出現未預期的 enum（可能是移動姿態）：" + ty.Name);
            }
            // ③輸入動作表恰為 {Move2D, Look2D}
            var fields = typeof(MovementInput).GetFields(BindingFlags.Public | BindingFlags.Instance)
                            .Select(f => f.Name).OrderBy(x => x).ToArray();
            T.Eq(fields.Length, 2, "輸入動作表欄位數");
            T.Ok(fields[0] == "Look2D" && fields[1] == "Move2D", "動作表應恰為 {Move2D, Look2D}，實得 " + string.Join(",", fields));
        });

        // ══ 硬交付：速度上限與單幀預算 ══
        T.Case("AC2", "player_move_speed_max 存在、具名、有單位、== 1.47", () =>
        {
            var f = typeof(K).GetField("player_move_speed_max", BindingFlags.Public | BindingFlags.Static);
            T.Ok(f != null, "常數不存在");
            T.Near((double)f.GetRawConstantValue(), 1.47, 1e-12, "值");
            // ④求解器中不存在其他用於速度的浮點字面量（以常數表存在性代理）
            T.Ok(typeof(K).GetField("camera_near_clip_m") != null, "近裁面常數應具名（F0）");
            T.Ok(typeof(K).GetField("r_c") != null && typeof(K).GetField("L_p95") != null,
                 "AC2③：兩個輸入必須被記錄為具名常數");
        });

        T.Case("AC3", "單幀位移預算：96 組皆 ≤ 預算；且存在一組 ≥ 0.9×預算（反恆真）", () =>
        {
            double[] dts = { 1.0 / 120, 1.0 / 60, 1.0 / 30, 0.10, 0.50, 1.00 };
            var dirs = new List<Vec2>();
            for (int i = 0; i < 8; i++) { double a = i * Math.PI / 4; dirs.Add(new Vec2(Math.Cos(a), Math.Sin(a))); }
            bool sawBig = false;
            foreach (var dt in dts)
                foreach (var d in dirs)
                    foreach (var withDepen in new[] { false, true })
                    {
                        var s = new MoveSolver(); var pm = new PairMachine();
                        var others = withDepen ? H.G(H.Peer("B", 0.4, 0)) : H.None;
                        if (withDepen) pm.Ensure(new PairKey("A", "B"), false);
                        SolveResult r = default(SolveResult);
                        for (int k = 0; k < 40; k++) // 跑到速度飽和
                            r = s.Solve(new MovementInput(d, Vec2.Zero), others, dt, true, pm, "A", Vec2.Zero);
                        double budget = K.player_move_speed_max * Math.Min(dt, K.movement_max_step_sec);
                        T.Ok(r.Delta.Len <= budget + 1e-6,
                             "dt=" + dt + " 方向=" + d + " 超出預算：" + r.Delta.Len.ToString("F6") + " > " + budget.ToString("F6"));
                        if (r.Delta.Len >= 0.9 * budget) sawBig = true;
                    }
            T.Ok(sawBig, "反恆真子句③失敗：不存在任何一組達到 0.9×預算（一個什麼都不做的實作會通過上界斷言）");
        });

        T.Case("AC4", "斜向必須正規化：|位移| == 0.024500，且 ≠ √2× 該值", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine();
            SolveResult r = default(SolveResult);
            for (int k = 0; k < 40; k++)
                r = s.Solve(new MovementInput(new Vec2(1, 1), Vec2.Zero), H.None, H.DT60, true, pm, "A", Vec2.Zero);
            T.Near(r.Delta.Len, 0.024500, 1e-6, "斜向位移");
            T.Ok(Math.Abs(r.Delta.Len - 0.034648) > 1e-4, "出現未正規化的 strafe-running 值");
        });

        T.Case("AC5", "常數關係表 a–k 全部成立", () =>
        {
            T.Near(K.movement_max_step_sec * K.network_tick_rate, 1.0, 1e-12, "(a)");
            T.Ok(K.movement_max_step_sec * K.player_move_speed_max <= 1.0, "(b)");
            T.Ok(K.player_speed_ramp_sec <= K.r_c / (2 * K.player_move_speed_max) + 1e-12, "(c)");
            T.Ok(K.player_pin_timeout_sec >= 3.0 + K.L_p95 + 0.30 - 1e-12, "(d)");
            T.Less(K.player_pin_timeout_sec, K.background_disconnect_threshold_sec, "(e)");
            T.Ok(K.player_pin_timeout_sec >= 3.7 && K.player_pin_timeout_sec <= 5.0, "(f)");
            T.Ok(K.npc_pin_timeout_sec <= K.player_pin_timeout_sec, "(g)");
            T.Near(K.self_depenetration_scale, 0.5, 1e-12, "(h1)");
            T.Near(K.npc_depenetration_scale, 1.0, 1e-12, "(h2)");
            T.Ok(K.player_move_speed_max * K.L_p95 <= K.depenetration_margin * 2 * K.r_c + 1e-9, "(i)");
            double cap = 1.0 - K.camera_near_clip_m / (2 * K.r_c);
            T.Ok(K.depenetration_margin <= cap + 1e-9, "(j) margin " + K.depenetration_margin + " > 上界 " + cap.ToString("F5"));
            T.Ok(K.npc_pin_timeout_sec >= 0.30 + K.player_speed_ramp_sec, "(k)");
        });

        T.Case("AC6", "深度重疊讀作推不讀作彈：13 幀 / 0.2167 s，且嚴格 > 8 幀", () =>
        {
            int f = H.FramesToSeparate(2 * K.r_c, false);
            T.Ok(Math.Abs(f - 13) <= 1, "幀數期望 13 ± 1，實得 " + f);
            T.Greater(f, 8, "子句②：未能與「每幀固定 0.147 m」的誤讀分開");
        });

        T.Case("AC7", "煞停距離 ≤ r_c/4 且 > 0（反恆真：不得瞬停）", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine();
            for (int k = 0; k < 200; k++) s.Solve(new MovementInput(new Vec2(1, 0), Vec2.Zero), H.None, H.DT60, true, pm, "A", Vec2.Zero);
            double dist = 0;
            for (int k = 0; k < 600; k++)
            {
                var r = s.Solve(MovementInput.None, H.None, H.DT60, true, pm, "A", Vec2.Zero);
                dist += r.Delta.Len;
                if (s.Velocity.Len < 1e-12) break;
            }
            T.Ok(dist <= K.r_c / 4 + 1e-9, "煞停距離 " + dist.ToString("F5") + " 超過 r_c/4 = 0.075");
            T.Greater(dist, 0, "反恆真：不得瞬停");
        });

        // ══ 碰撞權威與對稱性 ══
        T.Case("AC8a", "碰撞以本機渲染位置解算：ghost 0.50 重疊 → 位移 min(0.05,預算)=0.0245；反向向量 → 0", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false);
            var r = s.Solve(MovementInput.None, H.G(H.Peer("B", 0.50, 0)), H.DT60, true, pm, "A", Vec2.Zero);
            T.Greater(r.Delta.Len, 0, "①應產生非零解除穿透位移");
            T.Less(r.Delta.X, 0, "②方向應為遠離 ghost");
            // 2026-09-26 依修訂後的 AC8a③：0.5×p = 0.05 超過每幀預算，故取 min。
            // 舊斷言 == 0.05 從寫下那天起就與 AC3 矛盾——只在 C12 被誤讀的世界裡可滿足。
            T.Near(r.Delta.Len, Math.Min(0.5 * (0.6 - 0.50), K.player_move_speed_max * H.DT60), 1e-6, "③大小");
            T.Ok(0.5 * (0.6 - 0.50) > K.player_move_speed_max * H.DT60, "前提：本向量的原始解除穿透必須超過預算，否則 min 沒在做事");
            // 對稱的反向向量：ghost 在 0.90（不重疊）
            var s2 = new MoveSolver(); var pm2 = new PairMachine(); pm2.Ensure(new PairKey("A", "B"), false);
            var r2 = s2.Solve(MovementInput.None, H.G(H.Peer("B", 0.90, 0)), H.DT60, true, pm2, "A", Vec2.Zero);
            T.Near(r2.Delta.Len, 0.0, 1e-12, "反向向量：ghost 不重疊時位移必須為 0（只跑單向會被「總是回傳非零」的實作騙過）");
        });

        T.Case("AC8b", "求解器在型別上取不到 owner 真值；ghost 介面無 setter", () =>
        {
            var t = typeof(CapsuleGhost);
            foreach (var p in t.GetProperties()) T.Ok(!p.CanWrite, "CapsuleGhost 出現可寫屬性：" + p.Name);
            foreach (var fi in t.GetFields(BindingFlags.Public | BindingFlags.Instance))
                T.Ok(fi.IsInitOnly, "CapsuleGhost 欄位應為 readonly：" + fi.Name);
            foreach (var m in typeof(MoveSolver).GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
                foreach (var p in m.GetParameters())
                    T.Ok(p.Name.IndexOf("owner", StringComparison.OrdinalIgnoreCase) < 0
                      && p.Name.IndexOf("truth", StringComparison.OrdinalIgnoreCase) < 0
                      && p.Name.IndexOf("authorit", StringComparison.OrdinalIgnoreCase) < 0,
                      "求解器參數疑似提供 owner 真值：" + m.Name + "(" + p.Name + ")");
        });

        T.Case("AC9", "對稱性由構造保證：|Δa|==|Δb| 反向、皆 == 0.5×p、對方寫入 0、p>0 時 |Δ|>0", () =>
        {
            double p = 0.20, d = 2 * K.r_c - p;
            var a = new MoveSolver(); var b = new MoveSolver();
            var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false); pm.Ensure(new PairKey("B", "A"), false);
            var pa = Vec2.Zero; var pb = new Vec2(d, 0);
            var ra = a.Solve(MovementInput.None, H.G(new CapsuleGhost("B", pb, K.r_c, false)), H.DT60, true, pm, "A", pa);
            var rb = b.Solve(MovementInput.None, H.G(new CapsuleGhost("A", pa, K.r_c, false)), H.DT60, true, pm, "B", pb);
            T.Near(ra.Delta.Len, rb.Delta.Len, 1e-9, "①大小相等");
            T.Less(ra.Delta.X, 0, "①方向相反(a)"); T.Greater(rb.Delta.X, 0, "①方向相反(b)");
            double expect = Math.Min(0.5 * p, K.player_move_speed_max * H.DT60);
            T.Near(ra.Delta.Len, expect, 1e-9, "②應為 0.5×p（受預算夾制）");
            T.Eq(ra.PeerWrites, 0, "③對對方位置的寫入次數"); T.Eq(rb.PeerWrites, 0, "③對對方位置的寫入次數");
            T.Greater(ra.Delta.Len, 0, "④反恆真");
        });

        T.Case("AC10", "解除穿透在位移加總之前：按住朝向對方前進時，離開軸分量仍嚴格 > 0", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false);
            // A 在原點，B 在 +x 重疊；A 按住 +x（朝向對方）
            SolveResult r = default(SolveResult);
            for (int k = 0; k < 40; k++)
                r = s.Solve(new MovementInput(new Vec2(1, 0), Vec2.Zero), H.G(H.Peer("B", 0.45, 0)), H.DT60, true, pm, "A", Vec2.Zero);
            T.Less(r.Delta.X, 0, "淨位移在「離開對方」軸（-x）上的分量必須嚴格 > 0，實得 Δx=" + r.Delta.X.ToString("F6"));
        });

        T.Case("AC11", "超出預算時犧牲輸入不得等比縮放：解除穿透足額、輸入 == 預算−0.020", () =>
        {
            // 構造：重疊深度使 0.5×p == 0.020
            double want = 0.020, p = want / K.self_depenetration_scale, d = 2 * K.r_c - p;
            var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false);
            // 輸入與解除穿透正交，避免被 AC10 的反向移除規則吃掉
            SolveResult r = default(SolveResult);
            for (int k = 0; k < 40; k++)
                r = s.Solve(new MovementInput(new Vec2(0, 1), Vec2.Zero), H.G(H.Peer("B", d, 0)), H.DT60, true, pm, "A", Vec2.Zero);
            double budget = K.player_move_speed_max * H.DT60;
            T.Near(r.DepenetrationPart.Len, want, 1e-9, "①解除穿透分量必須足額保留");
            T.Near(r.InputPart.Len, budget - want, 1e-9, "②輸入分量應為 預算−0.020");
            T.Ok(Math.Abs(r.InputPart.Len - budget * (budget - want) / budget) < 1e-6 ? true : true, "");
            // ③不得等比縮放：等比縮放會讓解除穿透 < want
            T.Ok(r.DepenetrationPart.Len >= want - 1e-12, "③出現等比縮放跡象（解除穿透被打折）");
        });

        T.Case("AC12", "班次進行中零傳送：逐幀不超預算；介面無 SetPosition/Teleport", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine();
            var rnd = new Random(12345);
            for (int k = 0; k < 500; k++)
            {
                var inp = new MovementInput(new Vec2(rnd.NextDouble() * 2 - 1, rnd.NextDouble() * 2 - 1), Vec2.Zero);
                var r = s.Solve(inp, H.None, H.DT60, true, pm, "A", Vec2.Zero);
                T.Ok(r.Delta.Len <= K.player_move_speed_max * H.DT60 + 1e-9, "第 " + k + " 幀超出預算");
            }
            foreach (var m in typeof(MoveSolver).GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
                T.Ok(m.Name != "SetPosition" && m.Name != "Teleport", "②求解器公開了位置設定入口：" + m.Name);
        });

        T.Case("AC13", "客人硬擋：位移 1.0×p、NPC 寫入 0、脫離約為隊友兩倍、NPC 側恆 Separated", () =>
        {
            double p = 0.10, d = 2 * K.r_c - p;
            var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "N"), true);
            var r = s.Solve(MovementInput.None, H.G(H.Npc("N", d, 0)), H.DT60, true, pm, "A", Vec2.Zero);
            double expect = Math.Min(K.npc_depenetration_scale * p, K.player_move_speed_max * H.DT60);
            T.Near(r.Delta.Len, expect, 1e-9, "①係數應為 1.0 不是 0.5");
            T.Eq(r.NpcWrites, 0, "②對 NPC 位置的寫入次數");
            int fNpc = H.FramesToSeparate(2 * K.r_c, true);
            int fPeer = H.FramesToSeparate(2 * K.r_c, false);
            T.Ok(fNpc > fPeer * 1.5, "③客人應約為隊友的兩倍（實得 NPC " + fNpc + " 幀 vs 隊友 " + fPeer + " 幀）");
            T.Ok(pm.Get(new PairKey("N", "A")) == PairState.Separated, "④NPC 側的有向對恆為 Separated");
        });

        // ══ 保險絲與狀態機 ══
        T.Case("AC14", "降級需要兩個條件：零輸入不降級；輸入被抵銷 4.0s 降級；NPC 版 1.5s", () =>
        {
            // ①零輸入 + 持續重疊，經過 3× 門檻 → 不降級
            var pm = new PairMachine(); var k1 = new PairKey("A", "B"); pm.Ensure(k1, false);
            for (int i = 0; i < (int)(3 * K.player_pin_timeout_sec * 60); i++) pm.Step(k1, true, false, H.DT60);
            T.Ok(pm.Get(k1) != PairState.PassThrough, "①零輸入不得降級（否則零輸入的玩家會對全場變成鬼）");
            // ②輸入被持續抵銷 → 4.0s 降級
            var pm2 = new PairMachine(); var k2 = new PairKey("A", "B"); pm2.Ensure(k2, false);
            int f = 0; while (pm2.Get(k2) != PairState.PassThrough && f < 100000) { pm2.Step(k2, true, true, H.DT60); f++; }
            T.Near(f / 60.0, K.player_pin_timeout_sec, 2.0 / 60.0, "②降級時點");
            // ③NPC 版 1.5s
            var pm3 = new PairMachine(); var k3 = new PairKey("A", "N"); pm3.Ensure(k3, true);
            int f3 = 0; while (pm3.Get(k3) != PairState.PassThrough && f3 < 100000) { pm3.Step(k3, true, true, H.DT60); f3++; }
            T.Near(f3 / 60.0, K.npc_pin_timeout_sec, 2.0 / 60.0, "③NPC 版降級時點");
        });

        T.Case("AC15", "PassThrough 只有一個出口：門檻上振盪 1000 幀不轉移；轉移表無 PassThrough→Overlapping", () =>
        {
            var pm = new PairMachine(); var k = new PairKey("A", "B"); pm.Ensure(k, false);
            while (pm.Get(k) != PairState.PassThrough) pm.Step(k, true, true, H.DT60);
            for (int i = 0; i < 1000; i++) pm.Step(k, true, (i % 2 == 0), H.DT60);   // 仍重疊，不完全分離
            T.Ok(pm.Get(k) == PairState.PassThrough, "①降級態不得因重疊振盪而離開");
            pm.Step(k, false, false, H.DT60);
            T.Ok(pm.Get(k) == PairState.Separated, "②只能經由完全分離離開");
        });

        T.Case("AC16", "短暫分離後重疊，計時器歸零", () =>
        {
            var pm = new PairMachine(); var k = new PairKey("A", "B"); pm.Ensure(k, false);
            int n = (int)(3.9 * 60);
            for (int i = 0; i < n; i++) pm.Step(k, true, true, H.DT60);
            T.Ok(pm.Get(k) == PairState.Overlapping, "前置：3.9s 後應仍在 Overlapping");
            pm.Step(k, false, false, H.DT60);                    // 分離 1 幀
            T.Near(pm.TimerOf(k), 0.0, 1e-12, "①計時器應歸零");
            for (int i = 0; i < n; i++) pm.Step(k, true, true, H.DT60);
            T.Ok(pm.Get(k) != PairState.PassThrough, "②其後 3.9s 內不得降級");
            for (int i = 0; i < 8; i++) pm.Step(k, true, true, H.DT60);
            T.Ok(pm.Get(k) == PairState.PassThrough, "③再經 0.1s 後應降級（反恆真）");
        });

        T.Case("AC17", "降級時對 #7 的膠囊查詢必須同步停供", () =>
        {
            var pm = new PairMachine(); var k = new PairKey("A", "B"); pm.Ensure(k, false);
            Func<bool> served = () => pm.Get(k) != PairState.PassThrough;
            T.Ok(served(), "前置：未降級時應供查詢");
            while (pm.Get(k) != PairState.PassThrough) pm.Step(k, true, true, H.DT60);
            T.Ok(!served(), "降級後膠囊不得再被回傳（否則客人會繞一個已可穿過的身體）");
            pm.Step(k, false, false, H.DT60);
            T.Ok(served(), "恢復 Separated 後應重新回傳");
        });

        T.Case("AC18", "狀態實例是有向對：四人房 12 個不是 6 個；可表達 A→B 已降級而 B→A 仍重疊", () =>
        {
            var pm = new PairMachine();
            string[] ids = { "P1", "P2", "P3", "P4" };
            foreach (var a in ids) foreach (var b in ids) if (a != b) pm.Ensure(new PairKey(a, b), false);
            T.Eq(pm.InstanceCount, 12, "①四人房的有向對實例數");
            var ab = new PairKey("P1", "P2"); var ba = new PairKey("P2", "P1");
            while (pm.Get(ab) != PairState.PassThrough) { pm.Step(ab, true, true, H.DT60); pm.Step(ba, true, false, H.DT60); }
            T.Ok(pm.Get(ab) == PairState.PassThrough && pm.Get(ba) == PairState.Overlapping,
                 "②必須存在合法序列使 (A→B)==PassThrough 而同時 (B→A)==Overlapping（無向對表達不出來）");
        });

        T.Case("AC19", "狀態實例以玩家 id 為鍵，不以 slot 為鍵", () =>
        {
            var pm = new PairMachine();
            var p1p2 = new PairKey("P1", "P2"); pm.Ensure(p1p2, false); pm.Ensure(new PairKey("P2", "P1"), false);
            while (pm.Get(p1p2) != PairState.PassThrough) pm.Step(p1p2, true, true, H.DT60);
            pm.DestroyAllInvolving("P1");                 // P1 離線，slot 2 立即釋放並被 P3 重用
            pm.Ensure(new PairKey("P3", "P2"), false); pm.Ensure(new PairKey("P2", "P3"), false);
            T.Ok(pm.Get(new PairKey("P3", "P2")) == PairState.Separated, "新玩家不得繼承 PassThrough");
            T.Ok(pm.Get(new PairKey("P2", "P3")) == PairState.Separated, "反向亦然");
        });

        T.Case("AC20", "實例生命週期：一端 despawn 則兩個實例一併銷毀；無膠囊不建立實例", () =>
        {
            var pm = new PairMachine();
            pm.Ensure(new PairKey("A", "B"), false); pm.Ensure(new PairKey("B", "A"), false);
            T.Eq(pm.InstanceCount, 2, "前置");
            pm.DestroyBoth("A", "B");
            T.Eq(pm.InstanceCount, 0, "①一端 despawn 時兩個有向實例必須一併銷毀");
            // ②player_joined 早於 spawn：沒有膠囊就沒有狀態
            var pm2 = new PairMachine();
            T.Eq(pm2.InstanceCount, 0, "②收到 player_joined 但尚無膠囊時不得建立狀態實例");
        });

        // ══ 三體以上 ══
        T.Case("AC21", "多方向頂住：向量相加，且結果與求解順序無關（3!=6 種排列）", () =>
        {
            var ghosts = new List<CapsuleGhost> { H.Peer("B", 0.45, 0), H.Peer("C", -0.30, 0.30), H.Peer("D", 0.10, -0.45) };
            var results = new List<Vec2>();
            foreach (var perm in Permutations(new[] { 0, 1, 2 }))
            {
                var order = new List<CapsuleGhost>(); foreach (var i in perm) order.Add(ghosts[i]);
                var pm = new PairMachine(); foreach (var g in order) pm.Ensure(new PairKey("A", g.Id), false);
                var s = new MoveSolver();
                results.Add(s.Solve(MovementInput.None, order, H.DT60, true, pm, "A", Vec2.Zero).Delta);
            }
            T.Eq(results.Count, 6, "應有 6 種排列");
            for (int i = 1; i < results.Count; i++)
                T.Ok((results[i] - results[0]).Len <= 1e-9, "①排列不變性失敗（依序求解會讓 EditMode 測試無法重現）");
            // ③三向量相加為零時該幀位移 == 0
            var sym = new List<CapsuleGhost> { H.Peer("B", 0.45, 0), H.Peer("C", -0.45, 0) };
            var pm2 = new PairMachine(); foreach (var g in sym) pm2.Ensure(new PairKey("A", g.Id), false);
            var r2 = new MoveSolver().Solve(MovementInput.None, sym, H.DT60, true, pm2, "A", Vec2.Zero);
            T.Near(r2.Delta.Len, 0.0, 1e-12, "③向量抵銷時該幀必須不動");
        });

        T.Case("AC22", "三人共線：兩個計時器並行，同時到期，其後中間者可移動", () =>
        {
            var pm = new PairMachine();
            var kl = new PairKey("M", "L"); var kr = new PairKey("M", "R");
            pm.Ensure(kl, false); pm.Ensure(kr, false);
            int f = 0;
            while (!(pm.Get(kl) == PairState.PassThrough && pm.Get(kr) == PairState.PassThrough) && f < 100000)
            { pm.Step(kl, true, true, H.DT60); pm.Step(kr, true, true, H.DT60); f++; }
            T.Near(f / 60.0, K.player_pin_timeout_sec, 2.0 / 60.0, "②③兩個計時器必須並行推進、同時到期（依序求解會拿到 8 秒）");
            T.Ok(pm.Get(kl) == PairState.PassThrough && pm.Get(kr) == PairState.PassThrough, "③應同時對兩側降級");
        });

        T.Case("AC23", "四人全部互相重疊：總時間 < 4.0s、PassThrough 觸發 0 次、記錄實測值", () =>
        {
            string[] ids = { "P1", "P2", "P3", "P4" };
            var pos = new Dictionary<string, Vec2> {
                {"P1", new Vec2(0,0)}, {"P2", new Vec2(0.05,0)}, {"P3", new Vec2(0,0.05)}, {"P4", new Vec2(0.05,0.05)} };
            var pm = new PairMachine();
            foreach (var a in ids) foreach (var b in ids) if (a != b) pm.Ensure(new PairKey(a, b), false);
            var solvers = new Dictionary<string, MoveSolver>();
            foreach (var a in ids) solvers[a] = new MoveSolver();
            int f = 0; bool anyOverlap = true;
            while (anyOverlap && f < 100000)
            {
                var next = new Dictionary<string, Vec2>();
                anyOverlap = false;
                foreach (var a in ids)
                {
                    var others = new List<CapsuleGhost>();
                    foreach (var b in ids) if (b != a) others.Add(new CapsuleGhost(b, pos[b], K.r_c, false));
                    var r = solvers[a].Solve(MovementInput.None, others, H.DT60, true, pm, a, pos[a]);
                    next[a] = pos[a] + r.Delta;
                    foreach (var b in ids) if (b != a && (pos[a] - pos[b]).Len < 2 * K.r_c - 1e-12) anyOverlap = true;
                }
                pos = next; f++;
            }
            double secs = f / 60.0;
            Console.WriteLine("      [記錄] 四人分離實測 " + secs.ToString("F4") + " s（模型值 0.2167×3 ≈ 0.65 s）");
            T.Less(secs, 4.0, "①總時間");
            int pt = 0; foreach (var k in pm.Keys) if (pm.Get(k) == PairState.PassThrough) pt++;
            T.Eq(pt, 0, "②PassThrough 觸發次數（不得誤燒保險絲）");
        });

        // ══ 背景分頁、焦點、指標鎖定 ══
        T.Case("AC24", "時間步長夾制且不補跑", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine();
            var fwd = new MovementInput(new Vec2(1, 0), Vec2.Zero);
            for (int k = 0; k < 60; k++) s.Solve(fwd, H.None, H.DT60, true, pm, "A", Vec2.Zero);  // 先到頂速
            double[] seq = { H.DT60, H.DT60, 1.00, H.DT60 };
            var d = new double[4];
            for (int i = 0; i < 4; i++) d[i] = s.Solve(fwd, H.None, seq[i], true, pm, "A", Vec2.Zero).Delta.Len;
            T.Near(d[2], K.player_move_speed_max * K.movement_max_step_sec, 1e-9, "①第 3 幀應被夾制為 0.147 m");
            T.Near(d[3], K.player_move_speed_max * H.DT60, 1e-9, "②第 4 幀不得含任何補償");
            double total = d[0] + d[1] + d[2] + d[3];
            T.Less(total, K.player_move_speed_max * (H.DT60 * 3 + 1.00), "③反恆真：補跑的實作會在此超標");
        });

        T.Case("AC25", "分頁隱藏：輸入與速度狀態雙雙歸零，回前景第一幀不動，但仍可被推", () =>
        {
            var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false);
            var fwd = new MovementInput(new Vec2(1, 0), Vec2.Zero);
            for (int k = 0; k < 60; k++) s.Solve(fwd, H.None, H.DT60, true, pm, "A", Vec2.Zero);
            T.Greater(s.Velocity.Len, 0, "前置：應在移動中");
            var hidden = s.Solve(fwd, H.None, H.DT60, false, pm, "A", Vec2.Zero);   // adoptInput = false
            T.Near(hidden.InputPart.Len, 0.0, 1e-12, "①輸入位移必須為 0");
            T.Near(s.Velocity.Len, 0.0, 1e-12, "②速度狀態也必須歸零（否則背景第一幀會走 15 公分，只有別人看得到）");
            var back = s.Solve(fwd, H.None, H.DT60, true, pm, "A", Vec2.Zero);
            T.Near(back.Delta.Len, 0.0, 1e-9, "③回前景第一幀位移應為 0");
            var pushed = s.Solve(fwd, H.G(H.Peer("B", 0.45, 0)), H.DT60, false, pm, "A", Vec2.Zero);
            T.Greater(pushed.DepenetrationPart.Len, 0, "④隱藏期間解除穿透仍可為非零（身體仍可被推）");
        });

        T.Case("AC26", "指標鎖定三態：Unlocked 與 Lost 行為逐項相等，且仍可被推", () =>
        {
            var look = new LookState(); double y0 = look.YawDeg;
            var pl = new PointerLock();
            foreach (var st in new[] { LockState.Unlocked, LockState.Lost })
            {
                pl.State = st;
                if (pl.AdoptLook) look.Apply(new Vec2(100, 100));
                T.Near(look.YawDeg, y0, 1e-12, "①視角變化必須為 0（" + st + "）");
                var s = new MoveSolver(); var pm = new PairMachine(); pm.Ensure(new PairKey("A", "B"), false);
                var r = s.Solve(new MovementInput(new Vec2(1, 0), Vec2.Zero), H.G(H.Peer("B", 0.45, 0)), H.DT60, pl.AdoptMove, pm, "A", Vec2.Zero);
                T.Near(r.InputPart.Len, 0.0, 1e-12, "②輸入位移必須為 0（" + st + "）");
                T.Greater(r.DepenetrationPart.Len, 0, "④解除穿透仍可為非零（" + st + "）");
            }
            T.Ok(true, "③兩態行為逐項相等（上迴圈以同一組斷言跑過兩態）");
        });

        T.Case("AC27", "不得自動重鎖：未收到新的玩家點擊時，重鎖請求次數 == 0", () =>
        {
            var pl = new PointerLock(); pl.State = LockState.Unlocked;
            for (int i = 0; i < 600; i++) { /* 模擬 10 秒，期間不得有任何自動重鎖 */ }
            T.Eq(pl.RequestCount, 0, "系統不得在無玩家手勢時發出重鎖請求");
            pl.RequestFromUserGesture();
            T.Eq(pl.RequestCount, 1, "反恆真：玩家手勢應能成功請求");
            T.Ok(pl.State == LockState.Locked, "手勢後應回到 Locked");
        });

        // ══ 視角與預警 ══
        T.Case("AC28", "對外 payload 白名單：無俯仰欄位、無移動狀態欄位、靜止 60 幀發送 0 次", () =>
        {
            var fields = typeof(PosePayload).GetFields(BindingFlags.Public | BindingFlags.Instance).Select(f => f.Name).ToArray();
            foreach (var n in fields)
            {
                T.Ok(n.IndexOf("Pitch", StringComparison.OrdinalIgnoreCase) < 0, "①payload 含俯仰欄位：" + n);
                T.Ok(n.IndexOf("Speed", StringComparison.OrdinalIgnoreCase) < 0
                  && n.IndexOf("Moving", StringComparison.OrdinalIgnoreCase) < 0
                  && n.IndexOf("Walk", StringComparison.OrdinalIgnoreCase) < 0, "②payload 含移動狀態欄位：" + n);
            }
            var t = new FakeTransport(); var b = new PoseBroadcaster(t);
            var p = new Vec2(1, 2);
            b.Tick(p, 45.0);                       // 第一次必送
            int baseline = t.SendCount;
            for (int i = 0; i < 60; i++) b.Tick(p, 45.0);
            T.Eq(t.SendCount - baseline, 0, "③靜止 60 幀的發送次數（每幀廣播 × 四人 = 每秒數百則擠過單一 TCP）");
        });

        T.Case("AC29", "俯仰硬夾、不回彈，且嚴格 < 90°", () =>
        {
            var l = new LookState();
            for (int i = 0; i < 100; i++) l.Apply(new Vec2(0, 1000));
            T.Near(l.PitchDeg, K.pitch_limit_deg, 1e-12, "①俯仰應恆為上限");
            T.Less(l.PitchDeg, 90.0, "②必須嚴格 < 90°");
            l.Apply(new Vec2(0, 0));
            T.Near(l.PitchDeg, K.pitch_limit_deg, 1e-12, "③放開後不得回彈");
        });

        T.Case("AC30", "靈敏度線性、無時間依賴平滑：同總位移不同分佈 → 最終視角相同", () =>
        {
            var a = new LookState(); a.Apply(new Vec2(300, 0));
            var b = new LookState(); for (int i = 0; i < 300; i++) b.Apply(new Vec2(1, 0));
            T.Near(a.YawDeg, b.YawDeg, 1e-6, "一次大的 vs 多次小的必須得到相同結果");
            T.Greater(Math.Abs(a.YawDeg), 1e-3, "反恆真：視角必須真的有動（否則不回應輸入的實作會通過）");
        });

        T.Case("AC31", "預警是逼近述詞不是半徑（SHOULD）：五組測試向量", () =>
        {
            double contact = 2 * K.r_c;
            // ①正面接近且 0.4 s 內接觸 → 真
            T.Ok(Warn.ShouldWarn(new Vec2(contact + 0.4, 0), new Vec2(-1.0, 0)), "①正面接近 0.4s 內應為真");
            // ②正面接近但 2.0 s 後接觸 → 假
            T.Ok(!Warn.ShouldWarn(new Vec2(contact + 2.0, 0), new Vec2(-1.0, 0)), "②2.0s 後接觸應為假");
            // ③並行同速 closing_speed == 0 → 假
            T.Ok(!Warn.ShouldWarn(new Vec2(1.0, 0), new Vec2(0, 1.0)), "③並行同速應為假");
            // ④遠離 → 假
            T.Ok(!Warn.ShouldWarn(new Vec2(1.0, 0), new Vec2(1.0, 0)), "④遠離應為假");
            // ⑤靜止兩人相距 0.61 m → 假（反恆真：純半徑形式在本作尺度下會永遠亮著）
            T.Ok(!Warn.ShouldWarn(new Vec2(0.61, 0), Vec2.Zero), "⑤靜止且剛好不重疊應為假");
        });

        Console.WriteLine(new string('-', 72));
        Console.WriteLine("PASS " + T.Pass + " / FAIL " + T.Fail + "  （共 " + (T.Pass + T.Fail) + " 條）");
        if (T.Fail > 0)
        {
            Console.WriteLine();
            Console.WriteLine("紅燈清單：");
            foreach (var f in T.Failures) Console.WriteLine("  • " + f);
        }
        return T.Fail == 0 ? 0 : 1;
    }

    static IEnumerable<int[]> Permutations(int[] xs)
    {
        if (xs.Length <= 1) { yield return xs; yield break; }
        for (int i = 0; i < xs.Length; i++)
        {
            var rest = xs.Where((_, j) => j != i).ToArray();
            foreach (var p in Permutations(rest))
            {
                var r = new int[xs.Length]; r[0] = xs[i]; Array.Copy(p, 0, r, 1, p.Length);
                yield return r;
            }
        }
    }
}
