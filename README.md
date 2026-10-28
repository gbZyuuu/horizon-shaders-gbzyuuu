# Horizon shader compatibility

**English** | [Português (Brasil)](README.pt-BR.md)

Unofficial Horizon renderer and shader compiler fixes by **gbZyuuu**, for compatibility with [Photon](https://modrinth.com/shader/photon-shader) and [Complementary Unbound](https://modrinth.com/shader/complementary-unbound).

The shaders remain their authors' original **GLSL** packs. They were not rewritten in Rust. This project adapts the Rust client to load them. It is not an official Horizon or shaderpack release.

## Install

Requires Windows x64, a prepared **Horizon v0.2.93** installation and your own Minecraft Java 26.3 resources. Save your world and close the game and launcher. Run in ordinary PowerShell without administrator privileges:

```powershell
irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1' | iex
```

The installer locates compatible standard/portable profiles, shows the destination, verifies download hashes, and installs the patched game executable and required shader compiler DLLs with a backup. Several compatible installations produce a numbered choice. Unknown/custom builds are preserved. The launcher is unchanged; private mod ports are not included. Rust, Codex, Iris and OptiFine are not required.

- **Photon 1.4:** the original ZIP is downloaded directly from Modrinth and verified with SHA-512.
- **Complementary Unbound r5.9.3:** optional **manual download** from its [official page](https://modrinth.com/shader/complementary-unbound). Place the original ZIP, without extracting/editing it, in the shaderpacks folder printed by the installer. Existing copies are preserved.

Open your usual launcher and select the pack in video/shader settings. The first compilation can take longer; changing graphics APIs currently requires restarting the game.

[Manual package download](https://github.com/gbZyuuu/horizon-shaders-gbzyuuu/releases/download/v1.0.0/horizon-shaders-1.0.0.zip): extract the complete ZIP and open `Install.cmd`. Custom `-ClientPath`, `-GameDirectory`, `-LauncherDirectory` arguments and the official environment overrides are supported.

## Check and restore

Check without changing the game:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1'))) -Check
```

Restore the previous executable and managed files:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1'))) -Undo
```

Repeat custom paths when restoring. Keep `.gbzyuuu-shaders-backup` beside the executable. Changed files are detected before restoration. Existing worlds, accounts, authentication and settings are not modified. Launcher updates may replace this unofficial client.

`-ShaderPacksOnly` downloads only Photon and leaves the executable/DLLs unchanged. It cannot add missing renderer support: Photon crashed in the unpatched official v0.2.93 Vulkan test.

## Scope and validation

Includes fixes for shader compilation/loading, vegetation alpha cutout and rendering integration. **Experimental:** full visual parity with Java/Iris and every GPU are not certified; lighting, water and horizon artifacts may remain.

The packaged game is the previously tested v0.2.93-based binary: 72 shader compiler tests, a real Vulkan Photon vegetation scene and manual desktop confirmation. The installer passed installation, repeat-installation, manual Complementary preservation and historical backup/restore cases. Exact coverage and limitations are included in `VALIDATION.json` and [installer validation](INSTALLER-POLICY-VALIDATION.json). Consolidation changes packaging and documentation, not game behavior.

## Source and licenses

[Horizon](https://github.com/horizon-rust/horizon), copyright 2026 Ludovic Marie and the Horizon contributors, is MIT licensed. The package includes full build source, the shader patch, Horizon's license and DirectX Shader Compiler/other dependency notices. No Minecraft resources, shaderpack ZIPs, accounts or worlds are bundled.

**Read [licensing and attribution](THIRD-PARTY-NOTICES.md).** This project's MIT license does not relicense Photon, Complementary or other third-party material. Keep all third-party notices. Compatibility issues in this unofficial integration are this project's responsibility. These changes are maintained independently and are not submitted to upstream Horizon as clean-room work. Prepared with assistance from Codex.
