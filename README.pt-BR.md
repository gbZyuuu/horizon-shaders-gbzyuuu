# Compatibilidade de shaders no Horizon

[English](README.md) | **Português (Brasil)**

Correções não oficiais do renderizador e compilador de shaders do Horizon por **gbZyuuu**, para compatibilidade com [Photon](https://modrinth.com/shader/photon-shader) e [Complementary Unbound](https://modrinth.com/shader/complementary-unbound).

Os shaderpacks continuam em **GLSL original dos autores**. Não foram reescritos em Rust: adaptamos o cliente Rust para carregá-los. O projeto não é uma versão oficial do Horizon nem dos shaderpacks.

## Instalar

Requer Windows x64, uma instalação preparada do **Horizon v0.2.93** e seus próprios recursos do Minecraft Java 26.3. Salve e feche o jogo e o launcher. Execute no PowerShell normal, sem administrador:

```powershell
irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1' | iex
```

O instalador localiza perfis padrão/portáteis compatíveis, mostra o destino, verifica os hashes e instala o jogo corrigido e as DLLs necessárias com backup. Se houver vários perfis, mostra uma escolha numerada. Clientes desconhecidos ou com outras modificações são preservados. O launcher não é modificado e os ports privados de mods não estão incluídos. Não exige Rust, Codex, Iris ou OptiFine.

- **Photon 1.4:** o ZIP original é baixado diretamente do Modrinth e verificado por SHA-512.
- **Complementary Unbound r5.9.3:** opcional, com **download manual** pela [página oficial](https://modrinth.com/shader/complementary-unbound). Coloque o ZIP original, sem extrair ou editar, na pasta shaderpacks indicada pelo instalador. Cópias existentes são preservadas.

Abra pelo launcher habitual e selecione o pack nas configurações de vídeo/shaders. A primeira compilação pode demorar; trocar a API gráfica ainda exige reiniciar.

[Download manual do pacote](https://github.com/gbZyuuu/horizon-shaders-gbzyuuu/releases/download/v1.0.0/horizon-shaders-1.0.0.zip): extraia todo o ZIP e abra `Install.cmd`. Caminhos personalizados podem ser informados com `-ClientPath`, `-GameDirectory`, `-LauncherDirectory` ou os overrides oficiais de ambiente.

## Conferir e restaurar

Conferir sem alterar o jogo:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1'))) -Check
```

Restaurar o executável anterior e os arquivos gerenciados:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/gbZyuuu/horizon-shaders-gbzyuuu/main/Install.ps1'))) -Undo
```

Repita os caminhos personalizados ao restaurar. Preserve `.gbzyuuu-shaders-backup` ao lado do executável. Alterações posteriores nos arquivos são detectadas. Mundos, contas, autenticação e configurações são preservados. Atualizações do launcher podem substituir este cliente não oficial.

`-ShaderPacksOnly` baixa somente a Photon, sem alterar o executável/DLLs. Isso não adiciona suporte ao renderizador: a Photon crashou no teste Vulkan do cliente oficial v0.2.93 sem alterações.

## Escopo e testes

Inclui correções de compilação/carregamento de shaders, recorte transparente da vegetação e integração de renderização. **Experimental:** não certificamos equivalência visual total com Java/Iris nem todas as GPUs. Podem continuar existindo diferenças de iluminação, água e horizonte.

O jogo do pacote é o mesmo binário v0.2.93 já testado: 72 testes do compilador, cena real Photon/Vulkan e confirmação manual. O instalador passou nos casos de instalação, reinstalação, preservação da Complementary manual e restauração de backups antigos. A cobertura e suas limitações estão em `VALIDATION.json` e no [relatório do instalador](INSTALLER-POLICY-VALIDATION.json). A consolidação altera o empacotamento e a documentação, não o comportamento do jogo.

## Código e licenças

Base: [Horizon](https://github.com/horizon-rust/horizon), copyright 2026 Ludovic Marie e contribuidores, sob MIT. O pacote inclui os fontes completos, patch, licença do Horizon e avisos das dependências, incluindo DirectX Shader Compiler. Não inclui recursos do Minecraft, ZIPs dos shaderpacks, contas ou mundos.

Consulte [licenças e créditos](THIRD-PARTY-NOTICES.md), em inglês. A licença MIT deste projeto não substitui as licenças da Photon, Complementary ou de outras dependências. Preserve os avisos originais. Os problemas desta integração não oficial são responsabilidade deste projeto. As alterações são mantidas separadamente e não serão enviadas ao Horizon como trabalho clean-room. Preparado com assistência do Codex.
