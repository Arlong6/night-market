// 第一人稱控制器核心 — 純 C# 原型
// 對應 design/gdd/first-person-controller.md（2026-09-26 修訂版）
//
// 刻意不引用任何 Unity 型別／PhysX／NGO —— 這是 AC 節 T0 層（31 條）成立的前提，
// 也是 OQ-F11 對 ADR 的請求。詳見 GDD「執行分層」節。
//
// ⚠ 原型碼，標準依 .claude/rules/prototype-code.md 放寬。

using System;
using System.Collections.Generic;

namespace FpControllerCore
{
    // ─────────────────────────────────────────────────────────────
    public struct Vec2
    {
        public readonly double X, Y;
        public Vec2(double x, double y) { X = x; Y = y; }
        public static readonly Vec2 Zero = new Vec2(0, 0);
        public double Len { get { return Math.Sqrt(X * X + Y * Y); } }
        public static Vec2 operator +(Vec2 a, Vec2 b) { return new Vec2(a.X + b.X, a.Y + b.Y); }
        public static Vec2 operator -(Vec2 a, Vec2 b) { return new Vec2(a.X - b.X, a.Y - b.Y); }
        public static Vec2 operator *(Vec2 a, double s) { return new Vec2(a.X * s, a.Y * s); }
        public static double Dot(Vec2 a, Vec2 b) { return a.X * b.X + a.Y * b.Y; }
        public Vec2 Normalized()
        {
            double l = Len;
            return l < 1e-12 ? Zero : new Vec2(X / l, Y / l);
        }
        public Vec2 ClampLen(double max)
        {
            double l = Len;
            return (l <= max || l < 1e-12) ? this : new Vec2(X / l * max, Y / l * max);
        }
        public override string ToString() { return "(" + X.ToString("F6") + ", " + Y.ToString("F6") + ")"; }
    }

    // ─────────────────────────────────────────────────────────────
    // 具名常數。AC2／AC5 的量詞域就是這個型別。
    public static class K
    {
        public const double player_move_speed_max = 1.47;   // F1，provisional
        public const double movement_max_step_sec = 0.10;   // F2 = 1/network_tick_rate
        public const int    network_tick_rate     = 10;
        public const double player_speed_ramp_sec = 0.08;   // F3
        public const double player_pin_timeout_sec = 4.0;   // F5
        public const double npc_pin_timeout_sec    = 1.5;   // F5（2026-09-26 與隊友版脫鉤）
        public const double self_depenetration_scale = 0.5; // F4 = 1/n_correcting_ends
        public const double npc_depenetration_scale  = 1.0; // F4（NPC 只有一端修正）
        public const double warning_lead_sec = 0.5;         // F7
        public const double camera_near_clip_m = 0.10;      // F0
        public const double camera_eye_height_m = 1.60;     // F0（假設值）
        public const double camera_fov_deg = 70.0;          // F0
        public const double r_c = 0.30;                     // 假設值，真身歸 #11
        public const double L_p95 = 0.339;                  // 未量測
        public const double depenetration_margin = 0.831;   // 推導自 camera_near_clip_m
        public const double background_disconnect_threshold_sec = 5.0; // netcode 擁有
        public const double pitch_limit_deg = 80.0;         // F6，暫定

        // ⚠ 規格空白：GDD 的 C10 只否決了「淨位移為零」的實作，沒給正確定義。
        // 這個門檻是實作端發明的，不是文件給的。見 README「實作端被迫發明的東西」。
        public const double input_cancel_threshold = 0.5;
        public const double input_dead_zone = 1e-6;
    }

    // ─────────────────────────────────────────────────────────────
    // AC8b：取得他人位置的唯一途徑。刻意沒有 setter，也沒有任何 owner 真值欄位。
    public struct CapsuleGhost
    {
        public readonly string Id;
        public readonly Vec2 RenderedPosition; // 本端當下渲染出來的位置（C8）
        public readonly double Radius;
        public readonly bool IsNpc;
        public CapsuleGhost(string id, Vec2 renderedPosition, double radius, bool isNpc)
        {
            Id = id; RenderedPosition = renderedPosition; Radius = radius; IsNpc = isNpc;
        }
    }

    public struct MovementInput
    {
        public readonly Vec2 Move2D;
        public readonly Vec2 Look2D;
        public MovementInput(Vec2 move, Vec2 look) { Move2D = move; Look2D = look; }
        public static readonly MovementInput None = new MovementInput(Vec2.Zero, Vec2.Zero);
    }

    public struct SolveResult
    {
        public Vec2 Delta;              // 本幀淨位移
        public Vec2 DepenetrationPart;  // 其中的解除穿透分量
        public Vec2 InputPart;          // 其中的輸入分量
        public double Budget;
        public bool InputWasCanceled;   // 供 C10 計時器使用
        public int NpcWrites;           // C11：必須恆為 0
        public int PeerWrites;          // C9：必須恆為 0
    }

    // ─────────────────────────────────────────────────────────────
    public enum PairState { Separated, Overlapping, PassThrough }

    // States A：狀態的實例是一個「有向對」，以玩家 id 為鍵（不得以 slot 為鍵）
    public class PairKey : IEquatable<PairKey>
    {
        public readonly string From, To;
        public PairKey(string from, string to) { From = from; To = to; }
        public bool Equals(PairKey o) { return o != null && From == o.From && To == o.To; }
        public override bool Equals(object o) { return Equals(o as PairKey); }
        public override int GetHashCode() { return From.GetHashCode() * 397 ^ To.GetHashCode(); }
        public override string ToString() { return From + "->" + To; }
    }

    public class PairMachine
    {
        readonly Dictionary<PairKey, PairState> _state = new Dictionary<PairKey, PairState>();
        readonly Dictionary<PairKey, double> _timer = new Dictionary<PairKey, double>();
        readonly Dictionary<PairKey, bool> _isNpc = new Dictionary<PairKey, bool>();

        public int InstanceCount { get { return _state.Count; } }
        public IEnumerable<PairKey> Keys { get { return new List<PairKey>(_state.Keys); } }

        public PairState Get(PairKey k)
        {
            PairState s;
            return _state.TryGetValue(k, out s) ? s : PairState.Separated;
        }
        public bool Has(PairKey k) { return _state.ContainsKey(k); }

        public void Ensure(PairKey k, bool isNpc)
        {
            if (!_state.ContainsKey(k))
            {
                _state[k] = PairState.Separated;
                _timer[k] = 0.0;
                _isNpc[k] = isNpc;
            }
        }

        // AC20①：一端 despawn → 該對的兩個有向實例一併銷毀
        public void DestroyBoth(string a, string b)
        {
            _state.Remove(new PairKey(a, b)); _timer.Remove(new PairKey(a, b)); _isNpc.Remove(new PairKey(a, b));
            _state.Remove(new PairKey(b, a)); _timer.Remove(new PairKey(b, a)); _isNpc.Remove(new PairKey(b, a));
        }
        public void DestroyAllInvolving(string id)
        {
            var doomed = new List<PairKey>();
            foreach (var k in _state.Keys) if (k.From == id || k.To == id) doomed.Add(k);
            foreach (var k in doomed) { _state.Remove(k); _timer.Remove(k); _isNpc.Remove(k); }
        }

        public double TimerOf(PairKey k) { double t; return _timer.TryGetValue(k, out t) ? t : 0.0; }

        // 逐幀推進一個有向對。overlapping = 本端看到的重疊；inputCanceled = 本端玩家自己的輸入被抵銷
        public void Step(PairKey k, bool overlapping, bool inputCanceled, double dt)
        {
            Ensure(k, _isNpc.ContainsKey(k) && _isNpc[k]);
            PairState s = _state[k];
            double timeout = _isNpc[k] ? K.npc_pin_timeout_sec : K.player_pin_timeout_sec;

            if (s == PairState.PassThrough)
            {
                // C10：只能經由「完全分離」離開降級態。不得有 PassThrough -> Overlapping。
                if (!overlapping) { _state[k] = PairState.Separated; _timer[k] = 0.0; }
                return;
            }

            if (!overlapping)
            {
                _state[k] = PairState.Separated;
                _timer[k] = 0.0;                       // AC16：短暫分離即歸零
                return;
            }

            _state[k] = PairState.Overlapping;
            // C10：條件是「重疊 ＋ 輸入被持續抵銷」，不是只有重疊。
            if (inputCanceled)
            {
                _timer[k] += dt;
                if (_timer[k] >= timeout - 1e-9)
                {
                    _state[k] = PairState.PassThrough;
                    _timer[k] = 0.0;
                }
            }
            // 注意：仍重疊但本幀未被抵銷時，計時器維持不變（不遞增也不歸零）。
            // ⚠ 這也是規格空白，文件只規定了「完全分離 → 歸零」。
        }
    }

    // ─────────────────────────────────────────────────────────────
    public class MoveSolver
    {
        Vec2 _velocity = Vec2.Zero;   // 速度是狀態（C14 要求切背景時一併歸零）
        bool _wasSuppressed;          // C14：「回前景第一幀不移動」需要記住上一幀的採納狀態
        public Vec2 Velocity { get { return _velocity; } }
        public void ZeroVelocityState() { _velocity = Vec2.Zero; }

        public SolveResult Solve(MovementInput input, IList<CapsuleGhost> others, double dt,
                                 bool adoptInput, PairMachine pairs, string selfId, Vec2 selfPos)
        {
            var r = new SolveResult();
            double dtc = Math.Min(dt, K.movement_max_step_sec);   // C12／C13：夾制時間步長，不補跑
            double budget = K.player_move_speed_max * dtc;
            r.Budget = budget;

            // ── 輸入 → 目標速度（C12 推論 1：斜向必須正規化）
            Vec2 raw = input.Move2D;
            Vec2 dir = raw.Len > 1.0 ? raw.Normalized() : raw;

            // C14：「回前景第一幀不移動」。恢復採納的那一幀仍不得產生輸入位移 ——
            // 只歸零速度狀態是不夠的，斜坡會在第一幀就給出非零速度。
            bool resumeFrame = adoptInput && _wasSuppressed;
            bool useInput = adoptInput && !resumeFrame;
            _wasSuppressed = !adoptInput;

            Vec2 target = useInput ? dir * K.player_move_speed_max : Vec2.Zero;
            if (!useInput) _velocity = Vec2.Zero;                 // C14／C15：不採納時速度狀態也歸零

            // ── 有限加減速（F3，加減速共用一個時間常數）
            double maxDv = K.player_move_speed_max / K.player_speed_ramp_sec * dtc;
            Vec2 dv = target - _velocity;
            _velocity = dv.Len <= maxDv ? target : _velocity + dv.Normalized() * maxDv;

            // ── 解除穿透（C9／C11）。多向量相加後一次施加，不得逐對依序求解（AC21）。
            Vec2 depen = Vec2.Zero;
            for (int i = 0; i < others.Count; i++)
            {
                CapsuleGhost g = others[i];
                var key = new PairKey(selfId, g.Id);
                if (pairs != null && pairs.Get(key) == PairState.PassThrough) continue; // 已降級則可穿過
                Vec2 away = selfPos - g.RenderedPosition;         // C8：一律用本端渲染位置
                double d = away.Len;
                double contact = K.r_c + g.Radius;
                if (d >= contact) continue;
                double depth = contact - d;
                double scale = g.IsNpc ? K.npc_depenetration_scale : K.self_depenetration_scale;
                Vec2 n = d < 1e-12 ? new Vec2(1, 0) : away.Normalized();
                depen = depen + n * (scale * depth);
            }
            // C11：玩家對 NPC 零位移寫入；C9：位移全額施加於自己，不寫對方
            r.NpcWrites = 0; r.PeerWrites = 0;

            // ── 夾制：解除穿透優先足額保留，犧牲輸入，不得等比縮放（Edge Cases）
            Vec2 depenClamped = depen.ClampLen(budget);
            Vec2 inputDisp = _velocity * dtc;

            // C9：解除穿透必須在位移加總之前執行 —— 輸入不得抵銷它（AC10）
            if (depenClamped.Len > 1e-12)
            {
                Vec2 dn = depenClamped.Normalized();
                double along = Vec2.Dot(inputDisp, dn);
                if (along < 0) inputDisp = inputDisp - dn * along;   // 移除反向分量
            }
            double remaining = Math.Max(0.0, budget - depenClamped.Len);
            Vec2 inputClamped = inputDisp.ClampLen(remaining);

            r.DepenetrationPart = depenClamped;
            r.InputPart = inputClamped;
            r.Delta = (depenClamped + inputClamped).ClampLen(budget);

            // C10 的計時條件：本端玩家自己的輸入被抵銷了多少
            double desiredLen = (dir * K.player_move_speed_max * dtc).Len;
            r.InputWasCanceled = useInput && raw.Len > K.input_dead_zone && desiredLen > 1e-12
                                 && inputClamped.Len < desiredLen * (1.0 - K.input_cancel_threshold);
            return r;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // F6：視角。線性、無時間依賴平滑、滑鼠加速預設關。
    public class LookState
    {
        public double YawDeg, PitchDeg;
        public double LookScale = 1.0;
        public double LookDegPerUnit = 0.1;   // ⬜ 待校正（OQ-F2）
        public void Apply(Vec2 mouseDelta)
        {
            YawDeg += mouseDelta.X * LookDegPerUnit * LookScale;
            PitchDeg += mouseDelta.Y * LookDegPerUnit * LookScale;
            if (PitchDeg > K.pitch_limit_deg) PitchDeg = K.pitch_limit_deg;   // 硬夾，不回彈
            if (PitchDeg < -K.pitch_limit_deg) PitchDeg = -K.pitch_limit_deg;
        }
    }

    // F7：判準 5 的交付是一個述詞，不是半徑。
    public static class Warn
    {
        // ⚠ 規格空白：GDD 從未給出 time_to_contact 的封閉式。這是實作端補的。
        public static double TimeToContact(Vec2 relPos, Vec2 relVel, double contactDist)
        {
            double closing = -Vec2.Dot(relPos.Normalized(), relVel);
            if (closing <= 1e-12) return double.PositiveInfinity;
            double gap = relPos.Len - contactDist;
            return gap <= 0 ? 0.0 : gap / closing;
        }
        public static double ClosingSpeed(Vec2 relPos, Vec2 relVel)
        {
            if (relPos.Len < 1e-12) return 0.0;
            double c = -Vec2.Dot(relPos.Normalized(), relVel);
            // Edge Cases：先夾至速度上限，否則 HOL 恢復後的 burst 會讓整畫面預警全亮
            return Math.Min(c, K.player_move_speed_max);
        }
        public static bool ShouldWarn(Vec2 relPos, Vec2 relVel)
        {
            double closing = ClosingSpeed(relPos, relVel);
            if (closing <= 0) return false;                       // 短路：先判方向再算除法
            double ttc = TimeToContact(relPos, relVel, 2 * K.r_c);
            return ttc <= K.warning_lead_sec;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // C16：對外廣播必須是邊緣觸發的。假的傳輸層，用來計發送次數（AC28③）。
    public class FakeTransport
    {
        public int SendCount;
        public readonly List<string> Sent = new List<string>();
        public void Send(string payloadTypeName) { SendCount++; Sent.Add(payloadTypeName); }
    }

    // AC28①②：對外 payload 的型別白名單。刻意不含俯仰、不含移動狀態。
    public struct PosePayload
    {
        public Vec2 Position;
        public double YawDeg;
        // 不得新增：任何俯仰欄位（C6）、任何走／停／速度欄位（C16）
    }

    public class PoseBroadcaster
    {
        Vec2 _lastPos; double _lastYaw; bool _primed;
        readonly FakeTransport _t;
        public PoseBroadcaster(FakeTransport t) { _t = t; }
        public void Tick(Vec2 pos, double yaw)
        {
            if (_primed && (pos - _lastPos).Len < 1e-9 && Math.Abs(yaw - _lastYaw) < 1e-9) return; // 邊緣觸發
            _primed = true; _lastPos = pos; _lastYaw = yaw;
            _t.Send("PosePayload");
        }
    }

    // 指標鎖定三態（C15／States B）
    public enum LockState { Locked, Unlocked, Lost }
    public class PointerLock
    {
        public LockState State = LockState.Locked;
        public int RequestCount;
        public bool AdoptLook { get { return State == LockState.Locked; } }
        public bool AdoptMove { get { return State == LockState.Locked; } }
        public void RequestFromUserGesture() { RequestCount++; State = LockState.Locked; }
        // AC27：不得自動重鎖 —— 刻意沒有任何不帶手勢的重鎖入口
    }
}
