// W1 原型 — [P-20](b) 用的「可攜帶物」最小實作
//
// 只有一個 owner-write 的 NetworkVariable。存在的理由是複現 NGO 原始碼裡那句警告：
//   [Rapid Ownership Change Detected][Potential Loss in State]
// 該警告建議兩次 ownership 變更間隔 6 個 network tick，但讀 NetworkVariableDeltaMessage
// 後發現真正的機制是：送出端在**下一個 tick 序列化時**才評估 CanWrite()，
// 若那時所有權已被收回，delta 根本不會被送出 —— 值靜靜地不見。
// 本類就是拿來把那個門檻量出來的。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-20](b)、OQ#17、約束⑧

using Unity.Netcode;

public class W1Carryable : NetworkBehaviour
{
    public readonly NetworkVariable<int> Value = new NetworkVariable<int>(
        -1,
        NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Owner);

    /// client 端在拿到所有權的當下就寫入，之後所有權多快被收回由 host 控制
    public override void OnGainedOwnership()
    {
        base.OnGainedOwnership();
        W1OwnershipSignals.RaiseGained(this);
    }
}

/// 靜態轉接，讓測試不必去場景裡找物件
public static class W1OwnershipSignals
{
    public static System.Action<W1Carryable> Gained;
    public static void RaiseGained(W1Carryable c) => Gained?.Invoke(c);
}
