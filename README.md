**Português Brasileiro** | **[English](https://github.com/B9R7M/BRG-SH/blob/main/eng-wiki/eng-README.md)**

---

# BRG-SH (build_rom_generic.sh)

É um script interativo escrito em `bash` para **compilar Custom ROMs AOSP** (LineageOS, AxionOS,
crDroid, PixelOS, Evolution X etc.) em distros Ubuntu/Debian.

---

## Leia antes de começar!

Este script **não funciona automaticamente** para qualquer dispositivo.
Você precisará **configurar manualmente** as variáveis no topo do arquivo
e **encontrar os repositórios corretos** para o **SEU dispositivo** (Se disponível).

### Fontes recomendadas

- **XDA Developers** > [xdaforums.com](https://xdaforums.com)
  - Pesquise pelo modelo do seu dispositivo (Threads de desenvolvimento costumam
  listar todos os repositórios necessários).

- **LineageOS Wiki** > [wiki.lineageos.org/devices](https://wiki.lineageos.org/devices)
  - Lista oficial de dispositivos suportados com links diretos para os device trees. (Mesmo que não queira a LineageOS, as trees são base para outras ROMs).

- **GitHub** > [github.com](https://github.com)
  - Pesquise por:
    - `android_device_<fabricante>_<codename>` > **device tree**
    - `android_kernel_<fabricante>_<chipset>` > **kernel source**
    - `proprietary_vendor_<fabricante>_<codename>` > **vendor blobs**
  
- **Organizações relevantes:** `LineageOS`, `TheMuppets`, `AOSPA`, `crdroidandroid`, `PixelOS`, `/e/OS`

  - **Telegram / Matrix** > Grupos de desenvolvimento de ROMs. Muitos projetos têm grupos onde maintainers e usuários compartilham repositórios, patches e suporte. Veja no site/GitHub da sua ROM para links de comunidades.

### Termos essenciais

Esse script também **não fornece todo o conhecimento necessário** para compilar qualquer ROM sem um estudo aprofundado prévio. É indispensável possuir conhecimentos técnicos anteriores sobre o processo para prosseguir com êxito.

Clique **[AQUI](https://drive.google.com/drive/folders/1zojYA3EaUBtd_drbRoTjIgxNxFVzFGUI)** para acessar o material básico necessário para prosseguir com o guia.

> [!NOTE]  
> Se trata de uma planilha hospedada no Google Drive. Utilize o Google Sheets ou qualquer software compatível com arquivos Excel `(.xlsx)` para visualizá-la.

---

## Configuração Inicial

Abra o arquivo `build_rom_generic.sh` e edite a **Seção 1 — Configurações**:

```bash
# Codename do dispositivo (ex: pstar, tundra, mh2lm)
DEVICE="seu_codename_aqui"

# Fabricante (ex: motorola, oneplus, google, xiaomi)
MANUFACTURER="fabricante_aqui"

# Branch da ROM (ex: lineage-23.1, fourteen, udc)
BRANCH_ROM="nome-da-branch-aqui"

# Branch do device tree (pode ser diferente)
BRANCH_DEVICE="nome-da-branch-device-tree"

# URL do manifest da ROM
ROM_MANIFEST_URL="https://github.com/SuaROM/android.git"

# URLs dos repositórios do seu dispositivo
DEVICE_TREE_URL="https://github.com/..."
KERNEL_REPO_URL="https://github.com/..."
VENDOR_REPO_URL="https://github.com/..."

# Número de threads (veja seção de Hardware abaixo)
JOBS=4

# Seus dados do git (obrigatório)
GIT_EMAIL="voce@exemplo.com"
GIT_NAME="Seu Nome"
```

---

## Requisitos mínimos de Hardware

| Componente  | Mínimo recomendado | Notas                                                   |
|-------------|--------------------|---------------------------------------------------------|
| CPU         | 4 núcleos          | Quanto mais, melhor!                                    |
| RAM         | 16 GB              | Configure swap (veja abaixo)                            |
| Swap        | 16 GB              | Essencial e útil com pouca RAM                          |
| Espaço      | 400GB – 1TB        | SSD recomendado                                         |
| SO          | Ubuntu (ex. 24.04) | Também funciona em Linux Mint, Debian, Pop!_OS          |

### Configurar Swap

```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Para tornar permanente, adicione ao `/etc/fstab`:
```
/swapfile none swap sw 0 0
```
> [!TIP]
> O swap utiliza o armazenamento interno como área de troca para a memória RAM. Assim, quanto maior a velocidade do SSD, melhor. Sempre que possível, é recomendado a utilização de SSDs NVMe, que oferecem taxas de transferência superiores em comparação aos modelos SATA.

> [!CAUTION]
> Configurar um espaço de swap maior que a quantidade de RAM disponível pode acelerar o desgaste do SSD, reduzindo sua vida útil. Apesar de ser uma prática necessária para evitar a ativação do OOM Killer, é recomendável monitorar constantemente a temperatura e o estado de saúde do SSD durante cargas de trabalho intensas.

### Configurar JOBS conforme seu hardware

| CPU              | RAM     | JOBS recomendado |
|------------------|---------|------------------|
| 4 núcleos        | 16 GB   | 2 a 4            |
| 8 núcleos        | 32 GB   | 6 a 8            |
| 12+ núcleos      | 48 GB+  | 10 a 12          |

> [!WARNING]
> O limite de JOBS é a sua quantidade de núcleos no CPU, se ultrapassar o limite, pode fazer sistema travar por OOM/OOM Killer (Out Of Memory/Killer).

---

## Como Usar

```bash
chmod +x build_rom_generic.sh
./build_rom_generic.sh
```

O script exibirá um menu interativo:

```
  ── Setup (primeira vez) ──────────────────────────────────
  [0] Tudo do zero (todas as etapas em sequência)
  [1] Verificações iniciais do sistema
  [2] Instalar dependências
  [3] Configurar ambiente (repo, git, ccache)
  [4] Baixar source da ROM
  [5] Clonar device trees (device / kernel / vendor)
  [6] Aplicar patches/configurações da ROM

  ── Build ─────────────────────────────────────────────────
  [7] Compilar (pergunta variante antes)
  [v] Mudar variante de build

  ── Backup & Sync ─────────────────────────────────────────
  [b] Fazer backup das configurações customizadas
  [r] Restaurar backup (escolhe qual)
  [s] Sync seguro (backup → sync → restore automático)

  ── Diagnóstico ───────────────────────────────────────────
  [d] Verificar branches dos repositórios
```

### Primeira vez? Use a opção `[0]`

Ela executa todas as etapas em sequência, pedindo confirmação em cada uma.

---

## Etapas detalhadas

### `[1]` Verificações iniciais
Verifica distro Linux, espaço em disco e memória disponível.

### `[2]` Instalar dependências
Instala todos os pacotes necessários via `apt`. Requer `sudo`.

> [!IMPORTANT]
> A utilização do `sudo` em scripts de automação pode causar falhas no workflow. Para evitar esse problema, é necessário configurar o `visudo` de modo a permitir a execução sem solicitação de senha antes da execução do script.

> [!WARNING]
> Desativar a senha do `sudo` reduz a segurança do sistema.
> Qualquer script malicioso ou usuário não autorizado pode executar comandos como root sem nenhuma barreira.
> **Use apenas em ambientes controlados** (VM local, container, máquina de build isolada).

- **Como configurar**

  Edite o arquivo de sudoers **sempre via `visudo`** — ele valida a sintaxe antes de salvar, evitando travar o sistema.

  ```bash
  sudo visudo
  ```

  Adicione ao final do arquivo:

  ```
  # Sem senha para um usuário específico
  seuusuario ALL=(ALL) NOPASSWD: ALL

  # Ou para um grupo inteiro (ex.: sudo/wheel)
  %sudo ALL=(ALL) NOPASSWD: ALL
  ```

  Salve e feche. A mudança entra em vigor imediatamente.

- **Usando um arquivo separado (recomendado)**

  ```bash
  echo "seuusuario ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/nopasswd
  sudo chmod 440 /etc/sudoers.d/nopasswd
  ```

- **Reverter (Caso sentir necessidade)**

  Basta remover a linha adicionada via `visudo` ou deletar o arquivo criado:

  ```bash
  sudo rm /etc/sudoers.d/nopasswd
  ```
> [!TIP]
> > Em pipelines CI/CD, prefira criar um usuário dedicado com `NOPASSWD` restrito a comandos específicos, em vez de liberar tudo com `ALL`.

### `[3]` Configurar ambiente
Configura `repo`, `git`, `ccache` e variáveis de ambiente no `.bashrc`/`.profile`.

> [!TIP]
> Algumas distribuições Linux exigem configuração prévia do `ccache` antes de iniciar o build. Seja por restrições de permissão ou limitações do próprio sistema.

 - **Instalação**

   ```bash
   # Debian/Ubuntu
   sudo apt install ccache

   # Arch
   sudo pacman -S ccache

   # Fedora/RHEL
   sudo dnf install ccache
   ```

- **Configuração básica**

  Defina o diretório e o tamanho máximo do cache:

  ```bash
  # Diretório padrão: ~/.cache/ccache (pode    ser alterado)
  export CCACHE_DIR=~/.cache/ccache

  # Tamanho máximo recomendado para builds     AOSP: 50–100 GB
  ccache -M 50G
  ```

  Adicione ao `~/.bashrc` ou `~/.zshrc` para   persistir:

  ```bash
  export USE_CCACHE=1
  export CCACHE_DIR=~/.cache/ccache
  ```

- **Problemas comuns**

  | Problema | Causa | Solução |
  |---|---|---|
  | `permission denied` | Diretório sem permissão de escrita | `sudo chown -R $USER ~/.cache/ccache` |
  | `ccache: not found` | Não instalado ou fora do PATH | Instale e adicione `/usr/lib/ccache` ao `$PATH` |
  | Cache não sendo usado | Variável `USE_CCACHE` não exportada | Adicione ao `.bashrc` e rode `source ~/.bashrc` |


- **Verificar se está funcionando**

  ```bash
  ccache -s
  ```

  Após a compilação de uma build limpa, os campos `cache hit` devem   aumentar nas execuções seguintes.

---

### `[4]` Baixar source da ROM
Inicializa o `repo` e faz o sync do source. Pode demorar **horas** dependendo
da sua conexão (150–200GB de download em média em buids mais recentes).

> [!TIP]
> Se o sync travar ou cair no meio, basta executar novamente, ele continua de onde parou.

### `[5]` Clonar device trees
Clona device tree, kernel e vendor blobs. **Você precisa configurar as URLs corretas.**

### `[6]` Patches
Etapa personalizável. Por padrão não faz nada, edite a função `step5_patches()` para
adicionar patches específicos da sua ROM.

### `[7]` Compilar
Configura o target e inicia a compilação. O log é salvo em `$BUILD_DIR/build_*.log`.

---

## Sistema de backups

O script inclui um sistema de backup para **preservar modificações manuais** que seriam
sobrescritas por um `repo sync`.

### Como funciona

1. `[b]` — Faz backup dos arquivos listados em `BACKUP_FILES`
2. `[r]` — Restaura um backup anterior (você escolhe qual)
3. `[s]` — **Sync seguro**: backup → sync → restore automático

### Configurar arquivos para backup

Edite a variável `BACKUP_FILES` no script:

```bash
BACKUP_FILES=(
    "device/fabricante/codename/device.mk"
    "device/fabricante/codename/BoardConfig.mk"
    # Adicione outros arquivos que você editar manualmente
)
```

Os backups ficam em `~/rom_backup/` com timestamp, e um symlink `latest` aponta sempre
para o mais recente.

---

## Diagnóstico de problemas

### Branches incorretas
Um dos problemas mais comuns. Use a opção `[d]` para verificar se todos os repositórios
estão na branch correta.

Para corrigir manualmente:
```bash
cd $BUILD_DIR/device/fabricante/codename
git fetch origin branch-correta
git checkout branch-correta
```

### Erros comuns de `mkdir`

| Mensagem                            | Causa provável                                   | Solução                                      |
|-------------------------------------|--------------------------------------------------|----------------------------------------------|
| `Permission denied`                 | Sem permissão no diretório pai (raíz)            | `sudo chown $USER:$USER <diretório>`         |
| `Not a directory`                   | Existe um arquivo com o mesmo nome               | `rm <nome>` e crie o diretório novamente     |
| `No such file or directory`         | Diretório pai não existe                         | `mkdir -p <caminho completo>`                |
| `mkdir: cannot create directory`    | Caminho inválido ou dispositivo cheio            | Verifique espaço em disco: `df -h`           |

> [!TIP]
> O script usa `mkdir -p` em todas as criações de diretório. Se mesmo assim falhar,
> crie os diretórios manualmente e tente novamente.

### Erros comuns de compilação

| Erro                                 | Causa provável                     | Solução                                             |
|--------------------------------------|------------------------------------|-----------------------------------------------------|
| `soong bootstrap failed`             | Branch errada nos repos            | Use `[d]` para verificar e corrigir branches        |
| `module not found: <módulo>`         | Dependência não clonada            | Clone o repositório faltante                        |
| `Out of memory` / OOM killer         | RAM insuficiente                   | Adicione swap, reduza JOBS                          |
| `ninja: build stopped`               | Erro de compilação genérico        | Veja o log completo                                 |
| `repository not found`               | URL incorreta                      | Verifique a URL no GitHub / XDA                     |
| `breakfast: command not found`       | envsetup.sh não carregado          | Execute `source build/envsetup.sh` manualmente      |

### Verificar o log de compilação

```bash
# Ver as últimas linhas do log
tail -100 ~/android/rom/build_userdebug_*.log

# Buscar erros
grep -i "error\|failed\|FAILED" ~/android/rom/build_userdebug_*.log | tail -30
```

---

## Chaves de assinatura

Na primeira compilação, o script gera automaticamente chaves de assinatura em `$BUILD_DIR/certs/`.

> [!TIP]
> Caso ocorra algum erro durante a geração de chaves, como a tentativa de criação de um diretório inexistente, pode ser necessário criar manualmente esse diretório. Para identificar o local correto, é recomendado analisar o script presente na source da ROM, que na maioria dos casos se encontra em `build/envsetup.sh`.

> [!CAUTION]
> **Guarde essas chaves!** Se perdê-las, builds futuras não serão compatíveis com as anteriores e você precisará fazer **wipe** completo para instalar uma nova build.

Faça backup das chaves:
```bash
cp -r ~/android/rom/certs ~/minha-pasta-segura/
```

---

## Variantes de build

| Variante     | Uso                        | ADB Root | Descrição                          |
|--------------|----------------------------|----------|------------------------------------|
| `userdebug`  | Desenvolvimento / teste    | Sim      | Recomendado para testes e debugging|
| `user`       | Uso diário / distribuição  | Não      | Mais restrito, mais próximo do prod|
| `eng`        | Engenharia                 | Sim      | Muito permissivo, não recomendado  |

Algumas ROMs usam variantes próprias (ex: `gms_core`, `gms_pico`, `vanilla`).
Consulte a documentação da sua ROM.

---

## Estrutura básica de diretórios

```
~/android/rom/ ← Source da ROM (BUILD_DIR)
├── .repo/ ← Configuração do repo
├── build/ ← Sistema de build do Android
├── device/
│   └── fabricante/
│       └── codename/ ← Device tree
├── kernel/
│   └── fabricante/
│       └── chipset/ ← Kernel source
├── vendor/
│   └── fabricante/
│       └── codename/ ← Vendor blobs
├── certs/ ← Chaves de assinatura (NÃO delete!)
├── out/target/product/
│   └── codename/ ← Arquivos gerados (.zip, .img)
└── build_*.log ← Logs de compilação

~/rom_backup/ ← Backups das customizações (BACKUP_DIR)
├── 20250101_120000/ ← Backup com timestamp
├── 20250115_090000/
└── latest -> ... ← Symlink para o mais recente
```

---

## Adaptação para diferentes ROMs

O script foi escrito para ser adaptado. Pontos principais para customizar:

1. **Variáveis no topo** — URLs, branches, device, manufacturer
2. **`BACKUP_FILES`** — Arquivos que você editar manualmente
3. **`step5_patches()`** — Patches específicos da ROM (ex: flags no device.mk)
4. **`step4_device_trees()`** — Adicione repos extras se a ROM exigir
5. **`step6_build()`** — Adapte o comando de build conforme a ROM

---

## Licença

**[MIT](https://github.com/B9R7M/ACL-SH/blob/main/LICENSE)** — Faça o que quiser, mas sem garantias. Use por sua conta e risco.

---

### Fontes:

- **[AOSP](https://source.android.com)**
- **[LineageOS for pstar](https://wiki.lineageos.org/devices/pstar/build)**
- **[VegaData](https://youtu.be/vX8t9l8gnT0)** (**[VegaBobo - Github](https://github.com/VegaBobo))**
- **[AxionOS Manifest](https://github.com/AxionAOSP/android)**
- **[XDA Fóruns](https://xdaforums.com)**
- **[TheMuppets](https://github.com/TheMuppets)**

---
