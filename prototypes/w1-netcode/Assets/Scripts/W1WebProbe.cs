// W1 原型 — Web 平台探針
//
// 一個畫面就同時回答第 2、3 批的四個假設：
//   [P-4]  itch.io 的 iframe 會不會把 `?code=` 轉發給遊戲
//   [P-19] WebGL 能不能用 Clipboard API（需 user gesture，且 iframe 可能被 permissions policy 擋）
//   [P-7]  `.jslib` 橋接在 **Release ＋ Managed Stripping High** 下是否仍然活著
//          （`[Preserve]` 是否真的擋住了 stripping）
//   [P-6]  Brotli 由 HTTP response header 判讀，不需遊戲內程式碼，但本頁面會顯示載入資訊
//
// 為什麼所有結果都畫在螢幕上：itch.io 上沒有 console 可看，
// 截圖就是證據。`/design-review` 的證據要求也是這樣。
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-4]／[P-6]／[P-7]／[P-19]、Core Rule #8／#23

using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.Scripting;

public class W1WebProbe : MonoBehaviour
{
#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")] private static extern string W1_GetOwnQuery();
    [DllImport("__Internal")] private static extern string W1_GetParentQuery();
    [DllImport("__Internal")] private static extern string W1_GetReferrer();
    [DllImport("__Internal")] private static extern int    W1_IsInIframe();
    [DllImport("__Internal")] private static extern void   W1_TryCopy(string text, string obj, string method);
    [DllImport("__Internal")] private static extern string W1_GetVisibility();
    [DllImport("__Internal")] private static extern int    W1_GetOnline();
    [DllImport("__Internal")] private static extern float  W1_Now();
    [DllImport("__Internal")] private static extern void   W1_InstallUnloadBeacon(string url, string tag);
    [DllImport("__Internal")] private static extern string W1_GetBeaconLog();
#else
    private static string W1_GetOwnQuery() => "(editor)";
    private static string W1_GetParentQuery() => "(editor)";
    private static string W1_GetReferrer() => "(editor)";
    private static int W1_IsInIframe() => 0;
    private static void W1_TryCopy(string t, string o, string m) { }
    private static string W1_GetVisibility() => "(editor)";
    private static int W1_GetOnline() => 1;
    private static float W1_Now() => Time.realtimeSinceStartup * 1000f;
    private static void W1_InstallUnloadBeacon(string u, string t) { }
    private static string W1_GetBeaconLog() => "(editor)";
#endif

    private const string ObjectName = "W1WebProbe";

    private string m_OwnQuery = "?";
    private string m_ParentQuery = "?";
    private string m_Referrer = "?";
    private int m_InIframe = -1;
    private string m_CopyResult = "(未測試)";
    private string m_Visibility = "?";
    private int m_Online = -1;
    private float m_BootMs;
    private int m_VisibilityChanges;
    private string m_LastVisibilityAt = "-";

    // ── [P-10](a) 的核心量測 ──────────────────────────────────────
    // 問題不是「session 多久被回收」，而是它的前提：**背景分頁時 Unity 主迴圈
    // 是完全停止，還是只是被節流？** MPS 的 lobby heartbeat 掛在 PlayerLoop 上、
    // 間隔 10 秒。若瀏覽器只節流到 1Hz，heartbeat 照樣送得出去，session 根本不會
    // 被回收；若完全停止，heartbeat 才會斷。這一格數字就決定了整條 #23b 的成立與否。
    // ── [P-18] 離開通知 ──────────────────────────────────────────
    // 送達率由**伺服器端**數，本地這份只是「我以為送出了幾筆」。
    // 兩邊對不上才是真正要知道的事。
    private string m_BeaconLog = "(未安裝)";
    private string m_BeaconTag = "?";

    private int m_UpdateCount;
    private float m_LastUpdateMs;
    private float m_MaxGapMs;
    private float m_MaxGapAtMs;

    private void Awake()
    {
        gameObject.name = ObjectName;   // SendMessage 需要固定名稱
        DontDestroyOnLoad(gameObject);
    }

    private void Start()
    {
        // beacon 的目標位址與標籤由 query 帶入（?beacon=<url>&tag=<id>），
        // 讓外部腳本每次載入都給一個獨立 tag，才數得出到達率。
        var q = W1_GetOwnQuery();
        m_BeaconTag = ParseQuery(q, "tag");
        var beaconUrl = ParseQuery(q, "beacon");
        if (!string.IsNullOrEmpty(beaconUrl))
        {
            W1_InstallUnloadBeacon(UnityWebRequest.UnEscapeURL(beaconUrl), m_BeaconTag);
            m_BeaconLog = "(已安裝，尚未觸發)";
            Debug.Log($"[W1WEB] beacon 已安裝 tag={m_BeaconTag} url={beaconUrl}");
        }

        m_BootMs = W1_Now();
        m_LastUpdateMs = m_BootMs;
        Refresh();
        Debug.Log($"[W1WEB] boot ownQuery='{m_OwnQuery}' parentQuery='{m_ParentQuery}' " +
                  $"iframe={m_InIframe} referrer='{m_Referrer}'");
    }

    private static string ParseQuery(string q, string key)
    {
        if (string.IsNullOrEmpty(q)) return "";
        foreach (var kv in q.TrimStart('?').Split('&'))
        {
            var i = kv.IndexOf('=');
            if (i > 0 && kv.Substring(0, i) == key) return kv.Substring(i + 1);
        }
        return "";
    }

    private void Refresh()
    {
        m_OwnQuery = W1_GetOwnQuery();
        m_ParentQuery = W1_GetParentQuery();
        m_Referrer = W1_GetReferrer();
        m_InIframe = W1_IsInIframe();
        m_Visibility = W1_GetVisibility();
        m_Online = W1_GetOnline();
        var bl = W1_GetBeaconLog();
        if (!string.IsNullOrEmpty(bl)) m_BeaconLog = bl;
    }

    private void Update()
    {
        // 主迴圈是否被停掉：量 Update 之間的最大間隔。
        // 回到前景後，若最大間隔 ≈ 背景時長 → 主迴圈**完全停止**（heartbeat 會斷）。
        // 若最大間隔 ≈ 1 秒 → 只是**節流到 1Hz**（10 秒的 heartbeat 仍送得出去）。
        var now = W1_Now();
        var gap = now - m_LastUpdateMs;
        if (gap > m_MaxGapMs)
        {
            m_MaxGapMs = gap;
            m_MaxGapAtMs = now - m_BootMs;
        }
        m_LastUpdateMs = now;
        m_UpdateCount++;

        var v = W1_GetVisibility();
        if (v != m_Visibility)
        {
            m_Visibility = v;
            m_VisibilityChanges++;
            m_LastVisibilityAt = $"{(W1_Now() - m_BootMs) / 1000f:F1}s";
            Debug.Log($"[W1WEB] visibility -> {v} at {m_LastVisibilityAt}");
        }
    }

    /// 由 .jslib 經 SendMessage 回呼。**必須 [Preserve]**，否則 Managed Stripping High
    /// 會把它當死碼裁掉——而那只在正式 build 才會現形，正是 [P-7] 的核心風險。
    [Preserve]
    public void OnCopyResult(string result)
    {
        m_CopyResult = result;
        Debug.Log($"[W1WEB] clipboard result = {result}");
    }

    private static string Shorten(string s, int max = 60)
    {
        if (string.IsNullOrEmpty(s)) return "(空字串)";
        return s.Length <= max ? s : s.Substring(0, max) + "…";
    }

    private void OnGUI()
    {
        var w = Mathf.Min(Screen.width - 20, 900);
        GUILayout.BeginArea(new Rect(10, 10, w, Screen.height - 20));
        var title = new GUIStyle(GUI.skin.label) { fontSize = 22, fontStyle = FontStyle.Bold };
        var mono = new GUIStyle(GUI.skin.label) { fontSize = 15, wordWrap = true };

        GUILayout.Label("W1 Web 探針 — 第 2/3 批假設驗證", title);
        GUILayout.Space(6);

        GUILayout.Label($"[P-4] 自身 query      : {Shorten(m_OwnQuery)}", mono);
        GUILayout.Label($"[P-4] 父視窗 query    : {Shorten(m_ParentQuery)}", mono);
        GUILayout.Label($"[P-4] document.referrer: {Shorten(m_Referrer)}", mono);
        GUILayout.Label($"[P-4] 在 iframe 內     : {(m_InIframe == 1 ? "是" : m_InIframe == 0 ? "否" : "?")}", mono);
        GUILayout.Space(6);
        GUILayout.Label($"[P-7] visibilityState : {m_Visibility}（變化 {m_VisibilityChanges} 次，最後 {m_LastVisibilityAt}）", mono);
        var elapsed = (W1_Now() - m_BootMs) / 1000f;
        GUILayout.Label($"[P-10a] Update 次數     : {m_UpdateCount}（經過 {elapsed:F1}s，平均 {(elapsed > 0 ? m_UpdateCount / elapsed : 0):F1} fps）", mono);
        GUILayout.Label($"[P-10a] **最大 Update 間隔** : {m_MaxGapMs:F0} ms（發生在 {m_MaxGapAtMs / 1000f:F1}s）", mono);
        GUILayout.Label($"[P-7] navigator.onLine: {(m_Online == 1 ? "true" : m_Online == 0 ? "false" : "?")}", mono);
        GUILayout.Label($"[P-7] .jslib 回呼存活 : {(m_CopyResult == "(未測試)" ? "待測（按下方按鈕）" : "是 —— 收到回呼")}", mono);
        GUILayout.Space(6);
        GUILayout.Label($"[P-19] clipboard 結果 : {m_CopyResult}", mono);
        GUILayout.Label($"[P-18] beacon tag      : {m_BeaconTag}", mono);
        GUILayout.Label($"[P-18] 本地送出記錄    : {Shorten(m_BeaconLog, 70)}", mono);
        GUILayout.Space(10);

        if (GUILayout.Button("測試 clipboard（這一下就是 user gesture）", GUILayout.Height(42)))
        {
            m_CopyResult = "(等待瀏覽器回應…)";
            W1_TryCopy("W1-CLIPBOARD-TEST", ObjectName, nameof(OnCopyResult));
        }
        if (GUILayout.Button("重新讀取所有值", GUILayout.Height(34)))
        {
            Refresh();
        }

        GUILayout.Space(10);
        GUILayout.Label("[P-10a] 判讀：最大間隔 ≈ 背景時長 → 主迴圈完全停止，heartbeat 會斷。\n" +
                        "        最大間隔 ≈ 1000ms → 僅節流到 1Hz，10 秒的 heartbeat 仍送得出去。\n" +
                        "判讀：自身 query 有 ?code= → P-4 成立，帶碼連結可直接用。\n" +
                        "若自身為空而父視窗可讀 → 需改從父視窗取。\n" +
                        "若兩者皆空或顯示 CROSS_ORIGIN_BLOCKED → P-4 為假，輸碼路徑成為唯一入口。\n" +
                        "clipboard 顯示 OK → P-19 成立；DENIED/NO_API → 退化為可全選文字框。\n" +
                        "本頁任何一行能顯示 → 代表 .jslib 在 Stripping High 下存活（P-7）。", mono);
        GUILayout.EndArea();
    }
}
