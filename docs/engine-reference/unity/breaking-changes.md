# Unity — Breaking Changes (6.0 → 6.3 LTS)

> Last verified: 2026-09-03
> Sources: official upgrade guides
> 6.1: https://docs.unity3d.com/6000.1/Documentation/Manual/UpgradeGuideUnity61.html
> 6.2: https://docs.unity3d.com/6000.2/Documentation/Manual/UpgradeGuideUnity62.html
> 6.3: https://docs.unity3d.com/6000.3/Documentation/Manual/UpgradeGuideUnity63.html

## 6.0 → 6.1 (2025-04)

- Windows 新專案預設圖形 API 改為 **DirectX 12**（升級專案維持原設定）
- URP shader keyword `_FORWARD_PLUS` → `_CLUSTER_LIGHT_LOOP`（自訂 shader 需改）
- URP 17.1：ScriptableRendererFeature 不得在 `AddRenderPasses` 碰 render targets；
  `ClearFlag.Depth` 不再隱式清 stencil（需 `ClearFlag.Stencil`）
- `Rigidbody.SetDensity()` 棄用 → `Rigidbody.mass`
- PVRTC 壓縮棄用 → ASTC/ETC
- Android：Gradle 8.11 / AGP 8.7.2 / NDK r27c（自訂 Gradle 模板可能要重建）
- 編輯器選單重組（Package Manager 等移入子選單，自訂快捷鍵失效）

## 6.1 → 6.2 (2025-08)

- **URP 行為變更**：`RenderPassEvent.AfterRendering` 現在永遠在最終 blit 之後執行；
  要舊行為改用 `AfterRenderingPostProcessing`（可回溯相容 6.0+）
- URP `SetupRenderPasses`（6.1 才加的）在 6.2 棄用 → 直接寫 render graph
- UI Toolkit `VisualElement.transform` 棄用 → 寫入用 `style.translate/rotate/scale`、
  讀取用 `resolvedStyle.*`
- 一批 shader API 棄用（完整清單在 6.2 release notes）

## 6.2 → 6.3 LTS (2025-12) — 本專案版本

- **`[SerializeField]` 只能用在欄位**——用在屬性/方法/型別是編譯錯誤；
  auto-property 用 `[field: SerializeField]`（最常見升級地雷）
- **URP Compatibility Mode（非 render graph 路徑）移除**——6.0 棄用、6.3 刪除。
  所有自訂 pass/Renderer Feature 必須是 render graph 寫法
- **USS 解析器變嚴**——以前容忍的錯誤 selector/括號/分號現在報錯
  （可用 "Unsupported Selector Action" 設定調整）
- `AccessibilityRole` 由 flags enum 改為一般 enum（bitwise 組合會爆）；底層型別 int→byte
- `Scene.handle` int→`SceneHandle`；GI 的 `instanceID` 欄位改 `entityID`（`EntityId` 型別）
  ——C# 原始碼隱式轉換可過，**預編譯 DLL 必須重編**
- Netcode：`NetworkTransform.Update` 不可 override → 用 `NetworkTransform.OnUpdate` /
  `INetworkUpdateSystem`
- Multiplay Hosting 自編輯器/runtime 移除（服務 2026-03-31 終止）
- Legacy ETC 壓縮器移除（自動轉換，貼圖外觀可能變）
- Legacy Unity Ads 棄用 → Unity LevelPlay
- Web：Facebook Instant Games build target 棄用（6.1 加入的）→ 用一般 Web platform
- Android：Gradle 9.1 / AGP 9.0；round/legacy icon 棄用（用 adaptive）
- `UPM_NPM_CACHE_PATH` 環境變數移除 → `UPM_CACHE_ROOT`
- Adaptive Performance 由套件併入核心模組
