# THIRD_PARTY_NOTICES.md — créditos e licenças (v0.6.0)

Este arquivo registra os recursos de terceiros preservados do ZIP original e os conteúdos originais adicionados até a versão 0.6.0. As licenças foram lidas dos metadados `asset.extras` dos GLBs incluídos no ZIP original. Os recursos fornecidos pelo usuário foram preservados, não substituídos.

## Modelos 3D de avatar

### ROBLOX Rigged R6 Noob
- Arquivo: `assets/avatars/noob_r6.glb`
- Autor nos metadados: youK197_YT (`https://sketchfab.com/youK197_YT`)
- Página de origem: https://sketchfab.com/3d-models/roblox-rigged-r6-noob-e2e3d71149e84c3db034284cf60d836a
- Licença indicada no GLB: **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**
- Texto da licença: https://creativecommons.org/licenses/by-sa/4.0/
- Metadados validados: 1 skin/esqueleto; sem animação embutida.

### Roblox-Bacon-Hair
- Arquivo: `assets/avatars/bacon_hair.glb`
- Autor nos metadados: Roblox (`https://sketchfab.com/Robloxs`)
- Página de origem: https://sketchfab.com/3d-models/roblox-bacon-hair-88a62bc6286947e9846c5cd445d2628b
- Licença indicada no GLB: **Creative Commons Attribution 4.0 International (CC BY 4.0)**
- Texto da licença: https://creativecommons.org/licenses/by/4.0/
- Metadados validados: 1 skin/esqueleto e uma animação chamada `mixamo.com`.

A atribuição reflete os metadados embutidos nos arquivos fornecidos. Para redistribuição pública/comercial, mantenha as atribuições e cumpra também as condições de cada licença.

## Logo e imagens de referência

- `assets/bloxtacos_taco.png`, `assets/icon.png` e `assets/icon_foreground.png` derivam da imagem de taco anexada pelo usuário nesta conversa. A imagem-fonte foi fornecida pelo proprietário do projeto; sua titularidade/licença original não pôde ser verificada independentemente.
- As capas em `assets/covers/` e os ícones de catálogo em `assets/catalog/icons/` foram desenhados especificamente para esta versão, sem download de arte externa.

## Ferramentas e SDK

- Godot Engine 4.7.2: https://godotengine.org/ — motor sob MIT License.
- Android SDK e Build Tools: os pacotes são baixados pelo GitHub Actions diretamente dos repositórios Android e permanecem sujeitos aos termos de licença da Google.
- GitHub Actions: o workflow usa actions de terceiros mantidas por `actions` e `android-actions`; as respectivas licenças e termos estão nos repositórios oficiais dos projetos.

## Código e conteúdo BloxTacos

Scripts, cenas, materiais, layouts, arte das capas e lógica local adicionados ao projeto nesta reconstrução são conteúdo independente do BloxTacos. O código original é coberto pelo arquivo `LICENSE` na raiz.

Não foram incluídos cliente Roblox, código privado, código vazado, serviços internos ou assets proprietários obtidos sem autorização.


## Recursos de código adicionados na versão 0.4.0

- `scripts/network_manager.gd`: implementação ENet/RPC original do BloxTacos; não é código derivado da Roblox.
- `scripts/pizza_customer.gd`: rotinas de NPC escritas para o BloxTacos.
- `scripts/delivery_scooter.gd`: geometria low-poly original feita em código para o BloxTacos; não é um modelo de terceiro.
- `tools/run_dedicated_server.sh`: script original de inicialização de servidor.
- Não foram embutidos novos modelos GLB externos nesta versão. Referências de assets encontradas durante a pesquisa não são redistribuídas no projeto sem download do modelo e verificação de licença individual.


## Acessórios GLB originais BloxTacos (v0.6.0)

Os arquivos abaixo foram modelados proceduralmente com malhas próprias para o BloxTacos e estão cobertos pela licença MIT incluída na raiz do projeto. Não são cópias de itens Roblox nem downloads de terceiros.

- `assets/catalog/models/classic_cap.glb` — boné com copa, aba e patch.
- `assets/catalog/models/retro_shades.glb` — armação, lentes, ponte e hastes.
- `assets/catalog/models/gold_crown.glb` — faixa, pontas e gemas.
- `assets/catalog/models/green_visor.glb` — copa, aba e faixa.
- `assets/catalog/models/red_backpack.glb` — mochila, bolso e alças.
- `assets/catalog/models/star_halo.glb` — aro e detalhes.
- `assets/catalog/models/headphones.glb` — arco, conchas e almofadas.
- `assets/catalog/models/classic_scarf.glb` — volta e ponta de cachecol.
- `assets/catalog/models/gold_chain.glb` — corrente e pingente.
- `assets/catalog/models/blue_tee.glb` — patch e emblema.

O script de autoria `tools/generate_catalog_accessories.py` usa Trimesh 4.11.x (MIT) e NumPy (BSD-3-Clause) apenas no processo de geração. Essas bibliotecas não são dependências do runtime Godot nem são carregadas pelo APK. Consulte `tools/requirements-assets.txt` para os intervalos de versões.

## Pesquisa CC0 não redistribuída

`ASSET_RESEARCH.md` registra links para Kenney Mini Characters (CC0), Kenney Car Kit (CC0), Poly Pizza Glasses de iPoly3D (CC0) e Poly Pizza Backpack de Quaternius (CC0). Esses arquivos não estão incluídos nesta versão; as páginas servem como referência para uma futura inclusão com conferência individual da licença e dos arquivos.
