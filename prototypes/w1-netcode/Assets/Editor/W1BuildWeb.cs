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
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Brotli;
        // [P-6] 第一次建置刻意設 false，為的是測出**伺服器真實行為**——結果測到 itch.io
        // 不支援 Brotli：它把 .br 解壓後以 gzip/無壓縮重新提供，實際傳輸量變成 2.00 倍，
        // 直接打穿公式⑤ 的 T_load 預算。改為 true 後由 Unity 內建的 JS 解壓器處理 Brotli，
        // 不再依賴伺服器 header，傳輸量應回到 Brotli 水準（代價是解壓的 CPU 時間）。
        PlayerSettings.WebGL.decompressionFallback = true;
        PlayerSettings.WebGL.template = "APPLICATION:Default";
        PlayerSettings.WebGL.memorySize = 512;             // GDD 記憶體天花板
        PlayerSettings.runInBackground = true;             // [P-7] 要觀察背景行為，不要被這個設定先擋掉

        var opts = new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = OutDir,
            target = BuildTarget.WebGL,
            options = BuildOptions.None,                   // Release
        };

        Debug.Log("[W1BUILD] 開始建置 Web（IL2CPP / Stripping High / Brotli）…");
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
        var dir = Path.Combine(OutDir, "Build");
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
