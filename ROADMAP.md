# BloxTacos — roadmap

## v0.6.0 — multiplayer ENet alpha, catálogo GLB e rotinas NPC

- [x] Autoload NetworkManager com ENet host/cliente e servidor dedicado headless.
- [x] Roster de jogadores, líder de sessão e seleção de experiência autorizada pelo servidor.
- [x] Sincronização de posição/rotação, nomes, avatar Noob/Bacon, acessórios equipados e chat com limites simples.
- [x] Validação básica no host: lista de avatares/acessórios/modos permitidos, limite de movimento, frequência e tamanho de chat.
- [x] Guia de testes LAN/VPS e script para iniciar a instância headless.
- [x] Permissão Android INTERNET e verificação do manifesto no workflow ARM64.
- [x] Dez modelos GLB 3D de acessórios originais do BloxTacos, ligados ao inventário e às prévias 3D.
- [x] Rotinas de NPC com três clientes (fila, pedido, mesa, refeição e saída) e três funcionários (caixa, cozinha e entregas) em rotas com pausas e animação simples.
- [x] Scooter de entrega anexada ao avatar, rodas animadas, rota marcada, interação e recompensa.
- [x] Desastres com debris físicos e desmoronamento parcial de partes da torre/telhados.

## Limites deliberados desta alpha

- Não há contas, autenticação, reconexão inteligente, persistência em nuvem nem moderação online completa.
- A posição é enviada pelo cliente e limitada pelo servidor, mas ainda não existe simulação de movimento/colisão totalmente autoritativa.
- A carteira, as compras, o inventário e a propriedade dos acessórios continuam locais. O servidor aceita IDs de cosméticos permitidos para mostrar a aparência, sem validar propriedade paga.
- Pizza Place, ciclos de pedidos, entregas, clientes NPCs e física/desastres continuam executados localmente em cada cliente; não são uma partida cooperativa sincronizada ainda.
- A scooter usa o controlador CharacterBody3D existente, com velocidade de entrega e visual de veículo; ainda não é um VehicleBody3D independente com suspensão e rodas físicas.
- As rotinas NPC são máquinas de estados determinísticas, não IA aprendida ou navegação avançada.
- Os desastres soltam peças pré-selecionadas de estruturas e debris; não existe destruição estrutural generalizada de todo o mapa.
- Os 10 acessórios GLB atuais são modelos originais do projeto sob MIT. Pacotes CC0 de terceiros foram pesquisados e documentados, mas não foram redistribuídos nesta versão.

## Próximos marcos

1. Migrar pedidos, papéis, entregas, desastres, recompensas, saldo e inventário para lógica autoritativa no servidor.
2. Adicionar identidade de conta, autenticação, salvamento persistente seguro, moderação e reconexão.
3. Sincronizar NPCs, estados de tarefas, objetos de trabalho e veículos entre todos os clientes.
4. Fazer scooter com assento, colisões dedicadas, direção e física independente.
5. Expandir o catálogo com modelos GLB CC0/CC-BY baixados e verificados individualmente; registrar arquivo, autor, fonte e licença.
6. Aprimorar rigs, animações idle/walk/run/jump/sit e expressões.
7. Destruição estrutural por partes com restauração entre rodadas e mais variações de mapas.
8. Testes multiplayer em LAN/VPS, perda de pacotes, reconexão e carga antes de qualquer servidor público.

## Princípios

- Código próprio e assets fornecidos pelo projeto ou com licença individual verificada.
- Não incluir arquivos proprietários, privados, vazados ou extraídos sem autorização.
- Não declarar uma funcionalidade online quando ela ainda é local.
