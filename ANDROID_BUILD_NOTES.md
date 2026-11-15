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
