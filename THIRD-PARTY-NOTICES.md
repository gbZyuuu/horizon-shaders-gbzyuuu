# Licensing and attribution

This is an unofficial Horizon compatibility project by gbZyuuu, prepared with assistance from Codex. It is not endorsed by Horizon, Photon, Complementary Development, Iris, OptiFine, Mojang or Microsoft.

## What this project changes

The supplied executable is Horizon v0.2.93 with changes to its Rust renderer and shader compiler/loader. Photon and Complementary remain GLSL shaderpacks. They have not been rewritten in Rust. Compatibility is experimental; visual parity with Java and compatibility on every GPU are not certified. Problems in this unofficial integration are the responsibility of this project, not the shaderpack authors.

## Horizon and project code

[Horizon](https://github.com/horizon-rust/horizon) is copyright (c) 2026 Ludovic Marie and the Horizon contributors, under the [MIT license](LICENSES/Horizon-MIT.txt). The game package includes its build source, patch and original notices. The [repository MIT license](LICENSE) covers this project's original code, not third-party shaderpacks or third-party code under other licenses. This notice does not relicense any copied or adapted third-party material.

Horizon has its own contribution policy. These compatibility changes are maintained in this unofficial fork; they are not being submitted as clean-room work to upstream Horizon. A license to distribute a fork is separate from upstream accepting a contribution.

## Photon Shaders 1.4

Author: Benjamin Stott (SixthSurge), copyright 2021-2025. [Original project and download](https://modrinth.com/shader/photon-shader). [License shipped with version 1.4](LICENSES/Photon-1.4.txt).

The installer downloads the unmodified original ZIP directly from Modrinth and verifies its SHA-512. No Photon ZIP is hosted in this repository or its game payload. Photon retains its own license. It permits gameplay, commercially published screenshots/videos, personal modifications, source examination and redistribution subject to restrictions. Redistribution on platforms compensating creators, or charging for copies/derivatives, requires the author's explicit written permission; the license also contains a modpack grant. Preserve the full license and consult it before any redistribution or monetization.

## Complementary Shaders - Unbound r5.9.3

Author: Complementary Development. [Original project and download](https://modrinth.com/shader/complementary-unbound). [Official website](https://www.complementary.dev/). [License Agreement 1.7 shipped with r5.9.3](LICENSES/Complementary-Unbound-r5.9.3.txt).

Normal gameplay and content creation are permitted by section 1.1. The current installer does not download, modify, upload or bundle this shaderpack. Users obtain the original ZIP themselves from the official project page and place it in their shaderpacks directory. Existing installed copies are preserved. Only the version's own license governs it; the older V4 license linked by the project page must not be substituted for r5.9.3's license.

The modpack grant in section 1.2 requires unchanged contents and use of Modrinth/CurseForge's existing systems, prohibits direct-file reupload, and requires attribution when enabled by default. It does not explicitly establish authorization for this independent installer's automatic CDN download. We therefore use manual acquisition unless the author gives explicit permission or an explicitly supported distribution method is adopted. This is a conservative distribution policy, not an allegation that every third-party download is prohibited.

A modified-pack release has separate requirements under section 1.3, including credit/link, the unchanged applicable license, a different name, visibly different results and significant human-written visual code additions. We do not distribute such a modified pack or claim this project's MIT license covers Complementary. Other uses not granted remain reserved.

## Existing installations

Existing backup receipts containing both shaderpacks remain supported for restoration. The current installer automatically acquires only Photon. Users supply Complementary manually; automatic acquisition would require explicit authorization or an explicitly supported distribution method. Pack metadata retained for restoration is not permission to redistribute a shaderpack.

## Other dependencies

The game archive includes DirectX Shader Compiler licenses/provenance and other third-party notices. Preserve them with the binary/source distribution. No Minecraft resources, accounts or worlds are distributed. Users provide their own legitimately obtained game resources. Shaderpack licenses and compatibility claims must be reviewed again for a different version.
