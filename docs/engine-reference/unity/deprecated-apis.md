# Unity — Deprecated APIs (訓練資料截止後的「別用 X → 改用 Y」)

> Last verified: 2026-09-03
> 適用版本：Unity 6.3 LTS (6000.3)

| 別用（Deprecated） | 改用（Replacement） | 自版本 |
|---|---|---|
| `Rigidbody.SetDensity()` | `Rigidbody.mass` | 6.1 |
| `_FORWARD_PLUS` shader keyword (URP) | `_CLUSTER_LIGHT_LOOP` | 6.1 |
| PVRTC 貼圖壓縮 | ASTC 或 ETC | 6.1 |
| URP `ScriptableRendererFeature.SetupRenderPasses` | render graph 路徑（`AddRenderPasses` 內走 render graph API） | 6.2 |
| UI Toolkit `VisualElement.transform` | 寫：`style.translate/rotate/scale`；讀：`resolvedStyle.*` | 6.2 |
| `RenderPassEvent.AfterRendering`（要在 blit 前跑的 pass） | `AfterRenderingPostProcessing` | 6.2（行為變更） |
| `[SerializeField]` 用在屬性/方法 | 只准欄位；auto-property 用 `[field: SerializeField]` | 6.3（編譯錯誤） |
| URP Compatibility Mode | render graph（6.3 已移除，非棄用） | 6.3 |
| `NetworkTransform.Update` override | `NetworkTransform.OnUpdate` / `INetworkUpdateSystem` | NGO 2.x/6.3 |
| `[ServerRpc]` / `[ClientRpc]`（NGO 1.x 風格） | 通用 `[Rpc]` attribute（NGO 2.0+，可指定目標含 client-to-client） | NGO 2.0 |
| 獨立 Lobby / Relay 套件 API | Multiplayer Services SDK (`com.unity.services.multiplayer`) 的 **Sessions** API | MPS 1.0+ |
| `AccessibilityNode.selected` | `AccessibilityNode.invoked` | 6.3 |
| Legacy Unity Ads SDK | Unity LevelPlay（Ads Mediation） | 6.3 |
| Facebook Instant Games build target | Web platform | 6.3 |
| `UPM_NPM_CACHE_PATH` | `UPM_CACHE_ROOT` | 6.3 |
| Android round/legacy icons | Adaptive icons | 6.3 |

## 語言層警告

Unity 6.3 LTS 是 **C# 9.0**（Mono/IL2CPP，無 CoreCLR）。別寫：
file-scoped namespace（C# 10）、`required` 成員（C# 11）、primary constructor（C# 12）、
collection expressions `[..]`（C# 12）。
