# BloxTacos — reconstrução clássica independente

**Versão do projeto: 0.6.0 • Godot 4.7.2 stable • Android ARM64 • multiplayer ENet alpha**

BloxTacos é um projeto independente inspirado na estética de experiências de blocos de 2014–2017. Não é cliente Roblox, não utiliza serviços internos Roblox e não se conecta à economia oficial.

## O que existe nesta versão

- Menu mobile retrato e gameplay paisagem, com orientação por sensor opcional.
- Identidade visual com o taco fornecido pelo usuário, capas próprias e carregamento com progresso real da carga dos GLBs.
- Avatares Noob R6 e Bacon Hair, prévia 3D giratória e animação local/remota simples.
- Dez acessórios com modelos GLB 3D próprios, carregados no avatar: boné, óculos, coroa, viseira, mochila, auréola, fones, cachecol, corrente e emblema.
- Carteira fictícia inicial de 100 Robux de demonstração, catálogo, inventário e salvamento local.
- Chat local offline e chat distribuído via ENet quando conectado.
- Multiplayer alpha: host LAN e cliente; servidor dedicado headless; até 16 clientes remotos; lista de jogadores; seleção de experiência pelo líder; nomes, avatares, acessórios equipados, posições/rotação e chat sincronizados.
- Pizza Place: estações de trabalho, forno cronometrado, três NPCs clientes e três funcionários com rotinas e animação simples, rota de entrega, scooter visual com rodas animadas e recompensa local.
- Natural Disasters: enchente, terremoto e ventania; debris com forças físicas e queda parcial de peças da torre/telhados.
- Workflow Android ARM64 com permissão INTERNET e validação do SDK, APK, assinatura e manifesto.

## Multiplayer: leia antes de hospedar

A conexão é real via ENet/UDP. Para teste LAN, um dispositivo inicia **Settings → CRIAR SERVIDOR LAN** e outro digita o IP privado mostrado. Para internet, execute a instância dedicada em uma VPS/computador acessível e libere a porta **UDP 24680** no firewall/regras do provedor. O primeiro cliente conectado assume o papel de líder e pode selecionar a experiência; no host LAN, o próprio host é o líder.

Esta é uma alpha, não um backend de produção. O servidor mantém a lista, escolhe a experiência, distribui o chat e limita os pacotes de movimento. Os clientes ainda calculam movimento e enviam suas posições; não há física totalmente autoritativa. A carteira, compras, propriedade dos acessórios, tarefas da pizzaria, NPCs e desastres continuam locais por cliente. Não publique servidor aberto antes de adicionar autenticação, moderação e persistência segura.

Veja [`SERVER_GUIDE.md`](SERVER_GUIDE.md) para os comandos e o processo de implantação.

## NPCs, entregas e desastres

Os clientes da pizzaria percorrem estados de entrada, fila, pedido, mesa, refeição e saída. O jogador pode executar o ciclo de preparação, aguardar o forno, montar a scooter, seguir o marcador externo e concluir a entrega. A scooter ainda usa o controlador do personagem com velocidade ampliada; não é um veículo físico autônomo.

As rodadas naturais disparam forças sobre debris e soltam algumas peças predefinidas de telhados/torre. A destruição ainda é parcial e controlada por script, não uma simulação de dano em toda a estrutura.

## Abrir no Godot

1. Extraia o ZIP.
2. Abra a pasta do projeto no **Godot 4.7.2 stable**.
3. Aguarde a importação dos GLBs.
4. Execute `scenes/main.tscn`.

### Controles

- Android: joystick, PULAR, RENASCER e INTERAGIR. Arraste o lado direito para girar a câmera.
- PC: WASD/setas, Espaço, R para renascer, botão direito + arrastar para olhar e Enter para interagir na pizzaria.

## Servidor dedicado Linux

Após importar o projeto com a mesma versão da Godot, execute:

```bash
chmod +x tools/run_dedicated_server.sh
BLOXTACOS_PORT=24680 ./tools/run_dedicated_server.sh
```

Ou diretamente:

```bash
godot --headless --path . -- --server --port=24680
```

Libere **UDP 24680** no firewall da VPS. Os clientes inserem o IP público/domínio no menu Settings. Não use `127.0.0.1` para conectar um segundo dispositivo; esse endereço aponta para o próprio aparelho.

## Android ARM64

O workflow `.github/workflows/android-apk.yml` usa Godot 4.7.2 stable e seus templates pareados, JDK 17, Android SDK Platform 35, Build-Tools 35.0.1, NDK 28.1.13356709 e CMake 3.10.2.4988404. O preset usa Min SDK 24 e Target SDK 36 pelos padrões do exportador, ABI `arm64-v8a` e `permissions/internet=true`. Não é necessário ADB nem emulador para compilar.

No GitHub, abra **Actions → Build BloxTacos Android APK → Run workflow**. O APK esperado será publicado como artefato `BloxTacos-Android-APK-ARM64`, no caminho interno `build/BloxTacos.apk`. A geração só está confirmada após um Actions verde.

## Licenças e assets

Os modelos de acessórios `assets/catalog/models/*.glb` foram modelados originalmente para este projeto e ficam cobertos pela licença MIT da raiz. O script de geração está em `tools/generate_catalog_accessories.py`; ele é uma ferramenta de autoria e não é executado pelo jogo. O `THIRD_PARTY_NOTICES.md` lista os dois avatares GLB originais e as licenças indicadas nos próprios metadados. `ASSET_RESEARCH.md` lista referências CC0 pesquisadas, mas não redistribuídas nesta versão.


## Build Android 0.6.1

O importador de texturas ETC2/ASTC está habilitado em `project.godot`. O GitHub Actions apaga o cache de importação antes de reimportar recursos, corrige a animação de boot sem Tween infinito e exporta o APK ARM64 sem instalar em dispositivo ou emulador. Consulte `ANDROID_BUILD_NOTES.md`.

O preset Android está como não-runnable (`runnable=false`) para impedir que o editor procure aparelhos conectados durante uma simples exportação de APK. O workflow também desativa `export/android/shutdown_adb_on_exit`.
