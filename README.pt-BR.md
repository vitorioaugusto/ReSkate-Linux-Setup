# ReSkate Linux Setup

[English](README.md) | **Português (Brasil)**

> [!IMPORTANT]
> **Todo este projeto foi vibe-codado com auxílio de IA.** O código foi construído de forma iterativa por meio de prompts, testes, depuração e refinamentos, em vez de seguir um fluxo tradicional de programação do zero.

Uma forma de configurar **Skate + ReSkate no Linux** usando Wine, VKD3D-Proton e DXVK, com um launcher simples e opções de backup, reparo e reinstalação.

> **Status:** configuração desenvolvida e testada em Arch Linux/CachyOS com GPU NVIDIA RTX.  
> O script foi escrito para ignorar automaticamente NVAPI/NGX/DLSS em AMD e Intel, mas essas GPUs ainda precisam de testes da comunidade.

## O que o projeto faz

- cria um prefixo Wine dedicado ao ReSkate;
- aplica o workaround necessário para `api-ms-win-core-debug-minidump-l1-1-0.dll`;
- instala **VKD3D-Proton 3.0.1** para D3D12;
- instala **DXVK 3.1** para DXGI;
- em NVIDIA RTX:
  - instala **DXVK-NVAPI 0.9.2**;
  - configura NVIDIA NGX;
  - habilita DLSS Super Resolution;
- cria o launcher `~/.local/bin/reskate`;
- cria atalhos `.desktop`;
- permite backup, reparo, reinstalação do prefixo e recriação apenas dos atalhos.

## Requisitos e preparação

Antes de usar o ReSkate Linux Setup, primeiro prepare o jogo e o ReSkate.

### 1. Instale o skate. pela Steam

Instale o **skate.** normalmente pela Steam.

Quando o download terminar, abra a pasta do jogo por:

```text
Steam → Biblioteca → skate. → Gerenciar → Procurar arquivos locais
```

Deixe essa pasta aberta. É nela que fica o arquivo `Skate.exe`.

### 2. Baixe o ReSkate

Abra a página oficial de Releases do ReSkate:

[**Baixar o ReSkate em Dingo-Shenanigans/ReSkate**](https://github.com/Dingo-Shenanigans/ReSkate/releases/latest)

Baixe o arquivo mais recente:

```text
ReSkate-<versão>.zip
```

### 3. Extraia o ReSkate dentro da pasta do skate.

Extraia o conteúdo do ZIP do ReSkate para a **mesma pasta onde está o `Skate.exe`**.

Depois da extração, os principais arquivos do ReSkate devem ficar ao lado do executável do jogo, por exemplo:

```text
Skate/
├── Skate.exe
├── ReSkateLauncher.exe
├── ReSkate.dll
└── ...
```

Não deixe os arquivos dentro de uma pasta extra, como `Skate/ReSkate-1.x.x/`.

### 4. Execute o ReSkate Linux Setup

Somente depois que o jogo e os arquivos do ReSkate estiverem no lugar você deve usar o executável deste repositório. O setup detecta a pasta do skate. e configura o ambiente Wine/Vulkan necessário para iniciar o ReSkate no Linux.

> [!NOTE]
> Este projeto **não distribui** os arquivos do Skate ou do ReSkate. Você deve obter o skate. pela Steam e o ReSkate pelo repositório oficial no GitHub.

### Dependências no Linux

#### Arch / CachyOS / Manjaro

O script consegue instalar várias dependências automaticamente através do `pacman`.

#### Outras distribuições

Antes de executar o setup, deixe disponíveis:

- Wine ou Wine-Staging 64-bit;
- `curl`;
- `tar`;
- `zstd`;
- driver Vulkan 64-bit e 32-bit correspondente à sua GPU.

A parte de instalação de pacotes do sistema ainda é automatizada somente em distribuições baseadas em Arch.

## Baixar o executável

Se você só quer usar o setup sem clonar o repositório ou compilar nada, baixe o executável pronto pela página de **Releases**:

[**Baixar a versão mais recente**](https://github.com/vitorioaugusto/ReSkate-Linux-Setup/releases/latest)

Para a forma mais simples, baixe:

```text
ReSkate-Setup-x86_64.tar.gz
```

Depois é só extrair o arquivo e dar dois cliques em `ReSkate-Setup-x86_64`.

O arquivo compactado preserva a permissão de execução, então na maioria dos gerenciadores de arquivos Linux você não deve precisar usar `chmod` manualmente.

O binário avulso `ReSkate-Setup-x86_64` também fica disponível na Release. Se o seu gerenciador de arquivos não permitir executá-lo, ative a permissão em **Propriedades → Permissões**.

## Uso

Você pode executar diretamente o script:

```bash
bash scripts/reskate-setup.sh
```

Sem argumentos, ele abre primeiro um menu interativo:

```text
1) Instalar / reparar a configuração
2) Reinstalar o prefixo do zero
3) Fazer apenas um backup
4) Criar/recriar apenas o launcher e os atalhos
5) Sair
```

Depois que você escolhe a ação, o instalador pede para confirmar a **pasta onde o skate. está instalado antes de fazer qualquer alteração**. Ele verifica o local padrão da Steam e também bibliotecas adicionais da Steam, inclusive as que ficam em outros SSDs. Se encontrar mais de uma instalação, você pode escolher a correta; também é possível colar um caminho manualmente.

Os modos também podem ser chamados diretamente:

```bash
bash scripts/reskate-setup.sh --backup-only
bash scripts/reskate-setup.sh --repair
bash scripts/reskate-setup.sh --reinstall
bash scripts/reskate-setup.sh --launcher-only
```

### Segurança

Quando já existe um prefixo ReSkate, as opções de reparo e reinstalação criam um backup antes das alterações.

Os backups são armazenados por padrão em:

```text
~/ReSkate-backups/
```

O modo `--launcher-only` não altera Wine, DLLs, registro, VKD3D, DXVK ou o prefixo.

## Compilar o launcher

O repositório também contém um pequeno launcher em C que incorpora o script dentro de um único executável.

Dependências de build:

- GCC;
- GNU Make;
- Python 3.

Build normal:

```bash
make
```

Build estático:

```bash
make static
```

O resultado será:

```text
ReSkate-Setup-x86_64
```

Quando aberto por duplo clique, o launcher tenta iniciar o setup em um terminal gráfico nesta ordem: **Konsole**, **GNOME Terminal**, **XFCE Terminal** e **xterm**.

O script embutido é extraído temporariamente para:

```text
~/.cache/reskate-setup/reskate-setup-final-safe.sh
```

## Steam

Depois de concluir a configuração, você pode adicionar como jogo não-Steam:

```text
~/.local/bin/reskate
```

Não force Proton/Steam Play nesse atalho. O launcher já chama o Wine e o prefixo configurados pelo setup.

## NVIDIA, AMD e Intel

A configuração de NVIDIA NVAPI/NGX/DLSS é condicional.

Em uma NVIDIA RTX com driver proprietário ativo, o launcher habilita as variáveis usadas pelo DXVK-NVAPI e pelo DLSS.

Em AMD e Intel, o script pula essa seção e mantém apenas o caminho baseado em VKD3D-Proton + DXVK. Esse comportamento foi implementado para evitar que componentes NVIDIA sejam aplicados a outras GPUs, mas testes adicionais nessas placas são bem-vindos.

## Estrutura do repositório

```text
.
├── Makefile
├── README.md
├── README.pt-BR.md
├── LICENSE
├── scripts/
│   └── reskate-setup.sh
└── src/
    ├── embed.py
    └── launcher.c
```

## Contribuições

Issues e pull requests são bem-vindos, especialmente para:

- testes em outras distribuições;
- testes em GPUs AMD e Intel;
- melhorias na detecção de caminhos da Steam;
- suporte a outros terminais;
- melhorias na instalação de dependências fora do ecossistema Arch.

## Aviso

Este é um projeto comunitário e **não é afiliado à EA, Electronic Arts, ReSkate, NVIDIA, Valve, Wine, DXVK ou VKD3D-Proton**.

Todas as marcas pertencem aos seus respectivos proprietários.

## Licença

Este projeto é distribuído sob a [MIT License](LICENSE).
