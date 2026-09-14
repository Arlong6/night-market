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
#else
    private static string W1_GetOwnQuery() => "(editor)";
    private static string W1_GetParentQuery() => "(editor)";
    private static string W1_GetReferrer() => "(editor)";
    private static int W1_IsInIframe() => 0;
    private static void W1_TryCopy(string t, string o, string m) { }
    private static string W1_GetVisibility() => "(editor)";
    private static int W1_GetOnline() => 1;
    private static float W1_Now() => Time.realtimeSinceStartup * 1000f;
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

    private void Awake()
    {
        gameObject.name = ObjectName;   // SendMessage 需要固定名稱
        DontDestroyOnLoad(gameObject);
    }

    private void Start()
    {
        m_BootMs = W1_Now();
        Refresh();
        Debug.Log($"[W1WEB] boot ownQuery='{m_OwnQuery}' parentQuery='{m_ParentQuery}' " +
                  $"iframe={m_InIframe} referrer='{m_Referrer}'");
    }

    private void Refresh()
    {
        m_OwnQuery = W1_GetOwnQuery();
        m_ParentQuery = W1_GetParentQuery();
        m_Referrer = W1_GetReferrer();
        m_InIframe = W1_IsInIframe();
        m_Visibility = W1_GetVisibility();
        m_Online = W1_GetOnline();
    }

    private void Update()
    {
        // 背景分頁偵測（[P-7]）：輪詢 visibilityState 的變化次數。
        // 若 build 在背景時完全不跑 Update，回到前景後這個計數與時間戳會露出破綻。
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
        GUILayout.Label($"[P-7] navigator.onLine: {(m_Online == 1 ? "true" : m_Online == 0 ? "false" : "?")}", mono);
        GUILayout.Label($"[P-7] .jslib 回呼存活 : {(m_CopyResult == "(未測試)" ? "待測（按下方按鈕）" : "是 —— 收到回呼")}", mono);
        GUILayout.Space(6);
        GUILayout.Label($"[P-19] clipboard 結果 : {m_CopyResult}", mono);
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
        GUILayout.Label("判讀：自身 query 有 ?code= → P-4 成立，帶碼連結可直接用。\n" +
                        "若自身為空而父視窗可讀 → 需改從父視窗取。\n" +
                        "若兩者皆空或顯示 CROSS_ORIGIN_BLOCKED → P-4 為假，輸碼路徑成為唯一入口。\n" +
                        "clipboard 顯示 OK → P-19 成立；DENIED/NO_API → 退化為可全選文字框。\n" +
                        "本頁任何一行能顯示 → 代表 .jslib 在 Stripping High 下存活（P-7）。", mono);
        GUILayout.EndArea();
    }
}
