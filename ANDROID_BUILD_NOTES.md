# Android ARM64 — decisões de compilação e diagnóstico

## Caminho usado

- Godot editor: `4.7.2.stable`
- Templates APK: os arquivos `android_debug.apk` e `android_release.apk` do TPZ oficial da mesma versão
- Diretório Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`
- Identificador esperado em `version.txt`: `4.7.2.stable`
- Exportação: `Android ARM64` usando `--export-debug`
- `gradle_build/use_gradle_build=false`
- ABI arm64-v8a habilitada; demais ABIs desabilitadas
- Min SDK efetivo: 24 (padrão do exportador Godot 4.7.2)
- Target SDK efetivo: 36 (padrão do exportador Godot 4.7.2)
- Substituições `gradle_build/min_sdk` e `gradle_build/target_sdk`: vazias

A documentação Godot diferencia os templates APK pré-compilados do template Gradle. Os templates Android devem corresponder exatamente à versão do editor e ser instalados no diretório por versão; `version.txt` guarda essa identificação. Consulte: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html e https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html.

## Por que o erro antigo acontecia

No código-fonte da versão `4.7.2-stable`, `EditorExportPlatformAndroid::export_project_helper()` verifica `use_gradle_build`. Quando verdadeiro, tenta abrir `<gradle_build_directory base>/.build_version`. Se o arquivo não existe, emite literalmente: `Trying to build from a gradle built template, but no version info for it exists. Please reinstall from the 'Project' menu.`

Portanto:

- `version.txt` é usado para identificar os templates APK pré-compilados instalados globalmente.
- `.build_version` é o marcador do template de projeto Gradle instalado dentro do projeto.
- Criar um `version.txt` dentro da pasta global não corrige a falta de `.build_version` de um Gradle template.
- Como este projeto não exige customização do projeto Android/Gradle, o preset mantém `use_gradle_build=false` e o workflow valida isso antes da exportação. Os campos `gradle_build/min_sdk` e `gradle_build/target_sdk` também ficam vazios: a Godot 4.7.2 define internamente os padrões 24 e 36 e só permite substituir esses valores quando Gradle está ligado.

Código da verificação para a tag Godot 4.7.2-stable: https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/export/export_plugin.cpp (método `export_project_helper`, próximo à linha 3465).

## Ferramentas fixadas pelo workflow

- Temurin JDK 17
- Android SDK Platform 35
- Build Tools 35.0.1
- Platform Tools
- NDK 28.1.13356709
- CMake 3.10.2.4988404

O código-fonte da Godot 4.7.2 define `DEFAULT_MIN_SDK_VERSION = 24` e `DEFAULT_TARGET_SDK_VERSION = 36`. A lista do SDK corresponde aos requisitos da documentação Godot 4.7: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html.

## Validações automatizadas

O GitHub Actions verifica presença e versão de editor/templates, lê o preset, importa assets, inicializa a cena em modo headless, exporta o APK, testa a integridade ZIP, valida assinatura com `apksigner` e lê package/minSdk/targetSdk com `aapt`. Não usa ADB nem emulador.

Um resultado local não foi declarado: a exportação depende da execução do GitHub Actions e da disponibilidade dos artefatos oficiais de Godot/Android durante o workflow.


## Multiplayer Android permission (v0.4.0)

The Android export preset now explicitly sets `permissions/internet=true`, because the Godot 4.7 multiplayer documentation warns that Android blocks network sockets without the `INTERNET` permission. The workflow checks both the preset and the final APK manifest with `aapt dump permissions`. See https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html.


## Projeto 0.6.0 e rede Android

A versão do aplicativo foi atualizada para `0.6.0` (version code `6`). O preset declara `permissions/internet=true`; o workflow verifica essa configuração e também consulta o manifesto do APK com `aapt dump permissions`. Isso é necessário para os sockets ENet/UDP funcionarem no Android.


## Correções após a primeira execução do GitHub Actions (v0.6.1)

A primeira execução reportou `ETC2/ASTC texture compression is required for Android export`. O projeto usa Compatibility / GL Compatibility, mas o exportador Android ainda exige que os recursos de textura sejam importados para ETC2/ASTC. Foi habilitada a configuração global `rendering/textures/vram_compression/import_etc2_astc=true` em `project.godot`. O workflow agora apaga somente `.godot/imported/` antes da importação para obrigar a Godot a recriar os recursos com a configuração atual; a documentação informa que mudar essa configuração não altera os arquivos já importados.

O smoke test também reportou `Infinite loop detected` no Tween infinito da animação da logo de carregamento. A animação foi trocada por uma oscilação senoidal leve atualizada no `_process`, eliminando o Tween infinito em vez de silenciar o erro.

A mensagem `cannot connect to daemon at tcp:5037: Connection refused` é uma mensagem do cliente ADB, não a causa do erro de exportação mostrada nesta execução: a falha fatal explícita é a validação ETC2/ASTC. O workflow não instala APK em aparelho, não executa `adb install` e não inicia emulador. A etapa de verificação agora garante que não seja introduzida uma chamada ADB de instalação/dispositivo no workflow.

Versão do APK: `0.6.1` (version code `7`).


### Evitar detecção de dispositivos ADB no CI

O preset `Android ARM64` usa `runnable=false`, pois o workflow gera um APK para Artifact e não faz implantação com um clique. Na Godot 4.7.2, presets Android marcados como runnable iniciam a thread de verificação de dispositivos ADB; ao fechar o editor, `export/android/shutdown_adb_on_exit` também pode tentar executar `adb kill-server`. O workflow agora grava `export/android/shutdown_adb_on_exit=false` nas configurações do editor. O pacote `platform-tools` permanece instalado porque o caminho padrão do Android SDK deve conter `platform-tools/adb`, mas não há aparelho, emulador ou daemon ADB necessário para exportar o APK.
