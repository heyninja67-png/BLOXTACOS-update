# BloxTacos — servidor multiplayer ENet (alpha 0.6.0)

Esta versão adiciona um primeiro servidor real de sessão usando a API multiplayer de alto nível da Godot com `ENetMultiplayerPeer`. O servidor controla o registro da sessão, a lista de jogadores, os nomes/avatares/acessórios permitidos, a distribuição do chat e a seleção da experiência. No host LAN, o host é o líder; no servidor dedicado, o primeiro cliente conectado assume esse papel. As posições são enviadas pelos clientes a cada 100 ms; o servidor limita a frequência e a distância dos pacotes e retransmite os estados aos outros clientes.

> **Limite importante:** isto é uma primeira camada multiplayer funcional, não um backend de produção. Ainda não há contas/autenticação, persistência em nuvem, economia/inventário compartilhados, moderação online completa nem simulação física autoritativa. Cada cliente ainda executa localmente as interações e o estado detalhado de Pizza Place/desastres. Não abra um servidor público para pessoas desconhecidas antes de implementar autenticação, moderação, proteção contra trapaça e salvamento seguro no servidor.

## Opção 1 — teste na mesma rede Wi-Fi

1. Instale a mesma versão do APK BloxTacos em dois dispositivos ou execute duas cópias do jogo.
2. Conecte os dispositivos à **mesma rede Wi-Fi**.
3. No primeiro dispositivo, abra **Settings → CRIAR SERVIDOR LAN**.
4. O status mostra o IP privado encontrado e a porta UDP `24680`.
5. No segundo dispositivo, abra **Settings**, digite o IP que apareceu no primeiro e toque **CONECTAR**.
6. O painel de jogadores, os avatares remotos (incluindo acessórios equipados), o chat e o modo escolhido pelo host devem refletir a sessão conectada.

`127.0.0.1` só aponta para o próprio dispositivo. Não use esse endereço para conectar outro telefone; utilize o IP LAN mostrado pelo host.

## Opção 2 — servidor dedicado Linux / VPS

Requisitos: Linux x86_64, Godot **4.7.2 stable** e acesso para liberar uma porta **UDP**. O servidor pode ser iniciado em modo headless; não precisa de janela, GPU, ADB ou emulador Android.

### Preparar o projeto uma vez

```bash
git clone <URL-DO-SEU-REPOSITORIO> BloxTacos
cd BloxTacos
# Importa recursos Godot antes da primeira execução headless.
godot --headless --editor --path . --import --quit
chmod +x tools/run_dedicated_server.sh
```

### Iniciar

```bash
BLOXTACOS_PORT=24680 ./tools/run_dedicated_server.sh
```

Ou diretamente, sem o script:

```bash
godot --headless --path . -- --server --port=24680
```

Para usar outro executável Godot:

```bash
GODOT_BIN=/opt/godot/Godot_v4.7.2-stable_linux.x86_64 \
BLOXTACOS_PORT=24680 ./tools/run_dedicated_server.sh
```

Mantenha o processo ativo. Para VPS com UFW, libere somente a porta configurada para UDP:

```bash
sudo ufw allow 24680/udp
sudo ufw status
```

Também é necessário permitir essa porta UDP no firewall/regras de rede do provedor da VPS. TCP não substitui UDP para esta conexão ENet.

### Conectar ao VPS

Digite o IP público ou domínio da VPS no campo de endereço do menu Settings do BloxTacos e toque **CONECTAR**. O cliente utiliza a porta UDP `24680` nesta versão.

## O que sincroniza agora

- Entrada/saída de peers e lista da sessão.
- Nome, avatar escolhido (Noob ou Bacon Hair) e IDs permitidos de acessórios equipados. A posse e o pagamento dos itens ainda são locais, portanto esta alpha não valida a compra no servidor.
- Posição/rotação suavizadas dos avatares remotos.
- Chat distribuído pelo host, limitado a 140 caracteres e com limite simples de frequência.
- Seleção da experiência aceita pelo servidor: líder do host LAN ou primeiro cliente em uma instância dedicada.

## O que ainda fica local em cada cliente

- Saldo, compras, inventário e perfil salvo em `user://`.
- Pedidos, temporizador do forno, gorjetas e progresso de entregas.
- Resultado e física detalhada de cada rodada de desastre.
- Estado e movimento dos NPCs de clientes.

Não use a carteira local para conceder itens de valor real. A autenticação, o salvamento e a validação server-side desses sistemas precisam vir antes de uma economia multiplayer. Os IDs de acessórios são filtrados por allowlist, mas um cliente ainda pode informar que está usando um item sem ter comprado; isso é apenas cosmético nesta alpha.

## Diagnóstico rápido

- **Falha ao conectar:** confirme se o processo do servidor está ativo, o IP está certo e a porta UDP está liberada no firewall do host e do provedor.
- **Funciona no Wi-Fi, não pela internet:** o roteador pode não encaminhar UDP ou a operadora pode usar CGNAT. Uma VPS com IP público costuma ser mais simples para hospedar.
- **Dois telefones usando `127.0.0.1`:** cada um tenta conectar a si próprio. Use o IP privado do dispositivo host, ou o IP/domínio do VPS.
- **APK sem rede:** confira se o preset Android mantém `permissions/internet=true`; o workflow também verifica essa permissão no APK exportado.

## Arquitetura e próximo marco

O `NetworkManager` é um autoload compartilhado entre cliente e servidor. Ele utiliza RPCs `@rpc` da Godot, evitando um serviço de rede separado nesta primeira etapa. O próximo marco antes de um teste público é mover a simulação de partida, as ações de trabalho, os desastres, a carteira e o inventário para uma autoridade real no servidor e acrescentar contas, moderação, reconexão e testes de carga.
