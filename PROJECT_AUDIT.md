# Auditoria e mudanças — BloxTacos 0.6.0

## Base inspecionada

Arquivo recebido: `BloxTacos_v0.2.0.zip`. A extração continha projeto Godot 4.7.2 com `project.godot`, `scenes/main.tscn`, scripts de UI/movimento/itens, os dois avatares GLB, preset Android e workflow GitHub Actions. Os arquivos principais foram mantidos nos seus caminhos originais; não houve renomeação em massa nem remoção de modelos.

## Estado funcional observado no código original (referência histórica da versão recebida)

Já existiam três modos locais (`classic`, `disaster`, `pizza`), controlador de personagem, joystick, chat local, carteira e catálogo, persistência local e os dois GLBs. A reconstrução preservou essas partes e corrigiu a camada visual/fluxo onde possível.

## Alterações entregues

### Interface e inicialização
- `scripts/main.gd`: carregamento inicial próprio com progresso da carga em thread dos dois GLBs; logo do taco; menu retrato com navegação compacta; páginas Home, Games, Avatar, Profile, Catalog, Inventory, Chat e Settings; capas; lista de jogadores que distingue sessão local de sessão ENet conectada; chat in-game; controles compactos; transições retrato/paisagem; configurações persistidas; pausa dos timers quando o menu está aberto; confirmação de compra; pedidos e gorjetas persistidos; recompensas da Pizza Place atualizam a carteira.
- `scripts/avatar_preview.gd`: novo script para girar prévias 3D de avatar por toque/arraste e rotação de descanso.
- `scripts/player_controller.gd`: bloqueio de movimento, câmera e input de gameplay enquanto o menu está aberto.

### Imagens e ícones
- `assets/bloxtacos_taco.png`: recorte transparente da imagem de taco fornecida pelo usuário.
- `assets/icon.png`, `assets/icon_foreground.png`, `assets/icon_background.png`: ícone Android principal e adaptativo.
- `assets/covers/*.png`: ilustrações originais das três experiências.
- `assets/catalog/icons/*.png`: miniaturas ilustradas para os itens do catálogo.

### Android
- `project.godot`: base lógica vertical 720×1280, stretch adaptável e orientação sensor para permitir a alternância solicitada pelo script.
- `export_presets.cfg`: preset Android ARM64 revisado; Min/Target SDK seguem os padrões do exportador (24/36), sem overrides Gradle desnecessários; splash Godot padrão desabilitada e ícones configurados. A versão anterior do arquivo estava em 0.3.0; a entrega atual usa 0.6.0.
- `.github/workflows/android-apk.yml`: download do editor e templates estáveis pareados, instalação pelo caminho correto de export templates, verificação `version.txt`, SDK/JDK, import, smoke test, export APK, assinatura e metadados do manifesto.
- `ANDROID_BUILD_NOTES.md`: explicação técnica do erro `.build_version` versus `version.txt`.

### Documentação
- `README.md`: funcionalidades presentes, limitações, execução, build e comandos Git/Termux.
- `THIRD_PARTY_NOTICES.md`: metadados de origem/licença dos dois GLBs, taco do usuário e conteúdo original.
- `ROADMAP.md`: escopo efetivamente entregue e pendências realistas.

## Diagnóstico do erro Android

O código-fonte `4.7.2-stable` define o Min SDK padrão como 24 e Target SDK padrão como 36. As opções `gradle_build/min_sdk` e `gradle_build/target_sdk` só podem ser sobrescritas quando o Gradle está ativado. O erro de `.build_version` só é verificado dentro do ramo de exportação Gradle. O preset original estava em uma configuração contraditória: Gradle desligado, mas campo de Min SDK preenchido; o erro relatado anteriormente é compatível com uma execução anterior em que Gradle estava ligado e o marcador `.build_version` do template de projeto não existia. A solução escolhida foi usar templates APK pré-compilados correspondentes ao editor e manter `use_gradle_build=false`, sem gerar um projeto Gradle customizado.

## Limites e testes

- **Não foi possível executar o Godot nesta sessão**: o binário Godot não estava instalado e o ambiente não conseguiu resolver `github.com` para baixar a versão 4.7.2. Por isso, não afirmo que o projeto abriu, que GDScript compilou, que o APK foi gerado ou que a instalação foi testada.
- O workflow no GitHub é o teste reproduzível previsto. Ele fará importação de recursos, carregamento headless da cena, exportação e validação de assinatura/manifesto. Se falhar, o log da etapa identifica o primeiro erro real.
- **Estado da versão original 0.2.0, antes das atualizações v0.4/v0.5:** o jogo era local, sem multiplayer e com clientes Pizza Place estáticos. As atualizações posteriores abaixo substituem essa descrição.
- **Estado da versão original 0.2.0:** a loja usava miniaturas 2D e acessórios geométricos provisórios. Na v0.5 foram adicionados dez modelos GLB originais de catálogo; referências externas CC0 são documentadas separadamente, sem redistribuição.
- As capas 2D são ilustrações de navegação, não cenários renderizados capturados do jogo.


## Atualização de escopo v0.4.0

- Adicionado `NetworkManager` como autoload, com ENet host/client, RPCs de roster, chat, posição/rotação de avatars e seleção de experiência.
- Adicionado script Linux para iniciar servidor dedicado em headless e `SERVER_GUIDE.md`.
- Preset Android agora declara `permissions/internet=true`; o workflow testa essa opção e a permissão no APK exportado.
- NPCs da pizzaria receberam estados e rótulos de pedidos; scooter recebeu rotação das rodas; desastres têm mais debris e torque.
- Limite: ainda não é um servidor de jogo totalmente autoritativo. Carteira, inventário, interações detalhadas de Pizza Place/desastres e rotinas dos NPCs continuam locais em cada cliente. Não há contas, persistência em nuvem nem moderação.
- Validação estática executada nesta atualização; Godot CLI não está instalado neste ambiente, portanto parser/runtime/export Android continuam pendentes do GitHub Actions.


## Atualização de escopo v0.5.0 (camada multiplayer alpha e catálogo 3D)

- `scripts/network_manager.gd`: líder de sessão para host LAN e para o primeiro cliente de servidor dedicado; roster no dedicated deixa de criar um jogador fictício do servidor; clientes somente trocam de experiência após aceitação do servidor; acessórios equipados entram na lista de aparência remota.
- `scripts/main.gd`: clientes não mudam de modo localmente antes da aprovação do servidor; prévias e avatares remotos usam os GLBs de acessórios; servidor dedicado sincroniza estado de sessão e seleção de experiência.
- `assets/catalog/models/*.glb`: dez acessórios 3D originais criados para o projeto; `AvatarItems` carrega esses GLBs em vez de montar o catálogo com caixas.
- `scripts/pizza_customer.gd` e `scripts/pizza_worker.gd`: clientes percorrem fila/pedido/mesa/refeição/saída; três funcionários percorrem rotas de caixa, cozinha e entregas com pausas de rotina e animação procedural simples.
- `scripts/main.gd`: desastre libera peças rígidas de torre e telhados e acrescenta forças/torque a debris; destruição continua parcial.
- `scripts/player_controller.gd` / `scripts/delivery_scooter.gd`: scooter de entrega recebe alinhamento visual, luz dianteira e rodas animadas; ainda usa o movimento do personagem, sem física independente.
- `tools/generate_catalog_accessories.py` e `tools/requirements-assets.txt`: geração reprodutível das malhas GLB próprias.
- `ASSET_RESEARCH.md`: referências CC0 pesquisadas e separadas dos assets efetivamente incluídos.
- Validação de GLB, imagens, referências de recursos, YAML e script shell executada estaticamente. Godot CLI permanece indisponível neste ambiente; parsing/runtime real e export Android dependem do GitHub Actions.


## Atualização de escopo v0.6.0 (rotinas de equipe)

- `scripts/pizza_worker.gd`: novo comportamento de funcionários com waypoint loop, pausas de rotina, rótulo de função e animação de caminhada R6.
- `scripts/main.gd`: spawna três funcionários (caixa, cozinheiro e entregas) em rotas separadas na pizzaria, além dos três clientes existentes.
- `export_presets.cfg`: version name `0.6.0`, version code `6`.
- Limite: rotinas são locais e determinísticas, com waypoints fixos; não usam pathfinding avançado nem são autoridade do servidor.
- Validação desta entrega permanece estática; Godot CLI não está disponível no ambiente de edição.
