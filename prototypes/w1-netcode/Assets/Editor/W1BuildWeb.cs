// W1 原型 — Web build 腳本（batchmode 用）
//
// 刻意採用 GDD 指定的正式設定，因為 [P-7] 的整個風險就在「只有 Release build 才現形」：
//   - Managed Stripping High（`[Preserve]` 是否真的擋住 stripping）
//   - Brotli 壓縮（[P-6] 要看 itch.io 回不回 Content-Encoding）
//   - IL2CPP Release
//
// 用法：
//   Unity -quit -batchmode -nographics -projectPath . -executeMethod W1BuildWeb.Build
//
// 對應 GDD：design/gdd/netcode-session.md 的 [P-4]／[P-6]／[P-7]／[P-19]、公式⑤

using System.IO;
using UnityEditor;
using UnityEditor.Build;            // NamedBuildTarget
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

public static class W1BuildWeb
{
    private const string ScenePath = "Assets/Scenes/W1Web.unity";
    private const string OutDir = "Build/Web";

    /// 建一個只含探針物件的最小場景。原型不需要美術。
    [MenuItem("W1/Create Web Probe Scene")]
    public static void CreateScene()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        var go = new GameObject("W1WebProbe");
        go.AddComponent<W1WebProbe>();
        Directory.CreateDirectory(Path.GetDirectoryName(ScenePath));
        EditorSceneManager.SaveScene(scene, ScenePath);
        Debug.Log($"[W1BUILD] scene saved: {ScenePath}");
    }

    public static void Build()
    {
        if (!File.Exists(ScenePath)) CreateScene();

        // GDD 要求的 Web 設定
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.WebGL, ScriptingImplementation.IL2CPP);
        PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.WebGL, ManagedStrippingLevel.High);
        PlayerSettings.stripEngineCode = true;
        // 壓縮方式由命令列 -w1compress 指定，讓三種方案跑**同一份建置腳本**：
        //   brotli-fallback（已廢止）：itch.io 不認 .br → Unity 的 JS 解壓器處理，代價 2.1s CPU
        //   gzip-native：itch.io 是**看內容偵測** gzip（.br 只能靠副檔名，而那條路壞了），
        //                故 gzip 應能拿到 content-encoding 並由瀏覽器原生解壓，CPU 幾乎為零
        //   brotli-native：需要能自訂 header 的主機
        var mode = "gzip-native";   // 2026-09-18 定案值（見 modules/web.md）
        var argv = System.Environment.GetCommandLineArgs();
        for (int i = 0; i < argv.Length - 1; i++)
            if (argv[i] == "-w1compress") mode = argv[i + 1];
        Debug.Log($"[W1BUILD] 壓縮方案 = {mode}");

        PlayerSettings.WebGL.compressionFormat =
            mode.StartsWith("gzip") ? WebGLCompressionFormat.Gzip : WebGLCompressionFormat.Brotli;
        // [P-6] 歷經三次修訂才定案，順序值得留著：
        //   ① Brotli + fallback=false → itch.io 把 .br 解壓後重送，傳輸量 2.00 倍。
        //   ② Brotli + fallback=true  → 傳輸量回到 0.99 倍，但**成本搬到 CPU**：
        //      Unity 的 JS 解壓器只有 16.3 MB/s，7MB build 就要 2.1 秒，且與頻寬無關。
        //   ③ Gzip + fallback=false  ✅ 定案：itch.io 對 gzip 是**看內容偵測**（可靠），
        //      對 brotli 只能靠副檔名（而那條路是壞的）。瀏覽器原生解壓 85 MB/s，
        //      實測 CPU 僅 770ms；代價是體積 1.338 倍。部署後 curl 驗證原樣轉發。
        PlayerSettings.WebGL.decompressionFallback = mode.EndsWith("fallback");
        PlayerSettings.WebGL.template = "APPLICATION:Default";
        PlayerSettings.WebGL.memorySize = 512;             // GDD 記憶體天花板
        PlayerSettings.runInBackground = true;             // [P-7] 要觀察背景行為，不要被這個設定先擋掉

        var opts = new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = OutDir + "-" + mode,
            target = BuildTarget.WebGL,
            options = BuildOptions.None,                   // Release
        };

        Debug.Log($"[W1BUILD] 開始建置 Web（IL2CPP / Stripping High / {PlayerSettings.WebGL.compressionFormat}／fallback={PlayerSettings.WebGL.decompressionFallback}）…");
        var report = BuildPipeline.BuildPlayer(opts);
        var s = report.summary;
        Debug.Log($"[W1BUILD] result={s.result} size={s.totalSize / (1024f * 1024f):F1}MB " +
                  $"time={s.totalTime.TotalMinutes:F1}min errors={s.totalErrors}");

        if (s.result != BuildResult.Succeeded)
        {
            Debug.LogError("[W1BUILD] 建置失敗");
            EditorApplication.Exit(1);
        }

        // 把實際產出的檔案與大小列出來，公式⑤ 的 T_load 預算要用
        var dir = Path.Combine(OutDir + "-" + mode, "Build");
        if (Directory.Exists(dir))
        {
            foreach (var f in Directory.GetFiles(dir))
            {
                var fi = new FileInfo(f);
                Debug.Log($"[W1BUILD] {fi.Name}  {fi.Length / 1024f:F0} KB");
            }
        }
        EditorApplication.Exit(0);
    }
}
