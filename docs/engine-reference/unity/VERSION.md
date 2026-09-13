# Unity Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Unity 6.3 LTS (6000.3) |
| **Release Date** | December 2025 |
| **LTS Support Until** | December 2027 |
| **Project Pinned** | 2026-09-03 |
| **Last Docs Verified** | 2026-09-03 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | HIGH — 6.1 (partial), 6.2, 6.3 are beyond LLM training data |

## Knowledge Gap Warning

The LLM's training data covers Unity up to ~6.0 (Oct 2024) and early 6.1.
Unity 6.1 (2025-04), 6.2 (2025-08), and 6.3 LTS (2025-12) introduced breaking
changes the model does NOT reliably know. **Always cross-reference this
directory before suggesting Unity API calls**, especially for:

- URP custom rendering (Compatibility Mode REMOVED in 6.3 — render graph only)
- `[SerializeField]` usage (fields only in 6.3 — compile error otherwise)
- Netcode / Multiplayer Services (major package reorganization post-cutoff — see `modules/multiplayer.md`)
- Web platform capabilities (see `modules/web.md`)

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 6.1 (6000.1) | 2025-04 | MEDIUM | DX12 default on Windows, URP `_CLUSTER_LIGHT_LOOP`, Deferred+, WebGPU experimental |
| 6.2 (6000.2) | 2025-08 | MEDIUM | URP AfterRendering behavior change, `SetupRenderPasses` deprecated, UI Toolkit World Space UI |
| 6.3 LTS (6000.3) | 2025-12 | HIGH | `[SerializeField]` fields-only, URP Compat Mode removed, USS strict parsing, NetworkTransform.Update sealed |
| 6.5 / 6.6 (context) | 2026 | — | NOT our version. WebGPU exits experimental in 6.6; CoreCLR is 6.7+. Do not use features from these. |

## Scripting Level (6.3 LTS)

- **C# 9.0**, Roslyn. Backends: Mono (editor/JIT) + IL2CPP (AOT). **No CoreCLR** (that is 6.7+).
- Web builds are always IL2CPP.
- Do NOT suggest C# 10+ syntax (file-scoped namespaces, required members, primary constructors…).

## Reference Files

- `breaking-changes.md` — version-by-version breaking changes 6.0→6.3
- `deprecated-apis.md` — don't-use → use-instead table
- `current-best-practices.md` — post-cutoff practice changes (URP render graph, Input System, UI Toolkit)
- `modules/web.md` — Web (WebGL) platform: capabilities, size levers, networking constraints
- `modules/multiplayer.md` — NGO / Multiplayer Services / Relay / Web transport (project-critical)

## Verified Sources

- Support/release policy: https://unity.com/releases/unity-6/support
- 6.1 upgrade guide: https://docs.unity3d.com/6000.1/Documentation/Manual/UpgradeGuideUnity61.html
- 6.2 upgrade guide: https://docs.unity3d.com/6000.2/Documentation/Manual/UpgradeGuideUnity62.html
- 6.3 upgrade guide: https://docs.unity3d.com/6000.3/Documentation/Manual/UpgradeGuideUnity63.html
- 6.3 LTS announcement: https://unity.com/blog/unity-6-3-lts-is-now-available
- C# compiler level: https://docs.unity3d.com/6000.3/Documentation/Manual/csharp-compiler.html
