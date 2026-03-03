#!/bin/bash
# =============================================================================
#  BRG-SH
#  Versão: 1.0
# =============================================================================

set -e  # Aborta o script em qualquer erro não tratado

# =============================================================================
#  SEÇÃO 1: CONFIGURAÇÕES — EDITE AQUI ANTES DE EXECUTAR
# =============================================================================

# ── Identificação do dispositivo ──────────────────────────────────────────────
# Codename do dispositivo (ex: "pstar", "tundra", "sunfish", "rosy")
# DICA: O codename geralmente está na pasta "device/<fabricante>/<codename>"
# Na device tree, e pode ser encontrado na XDA ou Wiki do LineageOS.
DEVICE="seu_codename_aqui"

# Fabricante do dispositivo (ex: "motorola", "oneplus", "google", "xiaomi")
MANUFACTURER="fabricante_aqui"

# ── Branches da ROM e da device tree ─────────────────────────────────────────
# Branch da ROM que você quer compilar
# DICA: Veja o repositório da ROM no GitHub para saber as branches disponíveis.
# Exemplos: "lineage-21", "lineage-22.2", "lineage-23.1", "fourteen", "udc, etc"
BRANCH_ROM="nome-da-branch-aqui"

# Branch da device tree (pode ser diferente da branch da ROM)
# DICA: Veja o repositório da device tree para saber as branches disponíveis.
#       Normalmente segue o mesmo padrão da ROM se tiver suporte oficial (ex: "lineage-23.2"), mas tem excessões
BRANCH_DEVICE="nome-da-branch-device-tree"

# ── URLs dos repositórios ─────────────────────────────────────────────────────
# Manifest = (repositório principal) da ROM
# DICA: Geralmente está no GitHub da ROM. Procure um repo chamado "android"
#       ou "manifest" na organização da ROM (ex: github.com/AxionAOSP/android)
ROM_MANIFEST_URL="https://github.com/SuaROM/android.git"

# Device tree do seu dispositivo
# DICA: Pesquise no GitHub: android_device_<fabricante>_<codename>
#       Exemplo: android_device_motorola_pstar
DEVICE_TREE_URL="https://github.com/LineageOS/android_device_${MANUFACTURER}_${DEVICE}.git"

# Kernel source do seu dispositivo
# DICA: Pesquise no GitHub: android_kernel_<fabricante>_<chipset>
#       O chipset pode ser encontrado nas specs do dispositivo (ex: sm8250, mt6768)
#       ATENÇÃO: Nem toda ROM recompila o kernel. Verifique a documentação da sua ROM (Se disponível)
KERNEL_REPO_URL="https://github.com/LineageOS/android_kernel_${MANUFACTURER}_chipset.git"

# Vendor blobs do dispositivo
# DICA: Pesquise no GitHub: proprietary_vendor_<fabricante>_<codename>
#       Fontes comuns: TheMuppets (https://github.com/TheMuppets)
VENDOR_REPO_URL="https://github.com/TheMuppets/proprietary_vendor_${MANUFACTURER}_${DEVICE}.git"

# ── Diretórios ────────────────────────────────────────────────────────────────
# Diretório onde o source da ROM será baixado
# IMPORTANTE: Precisa de muito espaço (~400-600GB dependendo da ROM)
BUILD_DIR="$HOME/android/rom"

# Diretório para o binário "repo"
# DICA: Se encontrar erro de "repo: command not found", verifique se esse
#       diretório está no seu PATH. Adicione ao ~/.bashrc: export PATH="$HOME/bin:$PATH"
BIN_DIR="$HOME/bin"

# Diretório do ccache (cache de compilação)
# DICA: Coloque em disco rápido (SSD). Não altere se não sabe o que está fazendo.
CCACHE_DIR="$HOME/.ccache"

# Diretório de backup das suas customizações
# ATENÇÃO: Se encontrar erro ao criar esse diretório (ex: "Permission denied"),
#          crie-o manualmente: mkdir -p ~/rom_backup
BACKUP_DIR="$HOME/rom_backup"

# ── Performance ───────────────────────────────────────────────────────────────
# Tamanho do ccache. Padrão recomendado: 50G (50 GB)
# Com mais espaço, compilações subsequentes ficam MUITO mais rápidas.
CCACHE_SIZE="50G"

# Número de threads de compilação
# REGRA GERAL: número de núcleos da CPU (ex: 8 cores → JOBS=8)
# SE TEM POUCA RAM (<16GB): use metade dos núcleos (ex: 8 cores → JOBS=4)
# COM MENOS DE 8GB RAM: NEM TENTE COMPILAR!
# ATENÇÃO: Aumentar demais pode travar o sistema por falta de memória!
JOBS=4

# ── Git ───────────────────────────────────────────────────────────────────────
# Seu e-mail e nome para o git (obrigatório para o repo sync funcionar)
GIT_EMAIL="voce@exemplo.com"
GIT_NAME="Seu Nome"

# ── Variante de build ─────────────────────────────────────────────────────────
# Muitas ROMs possuem variantes. Ajuste conforme sua ROM:
#   "userdebug" → Para desenvolvimento/debug (mais comum)
#   "user"      → Para uso diário (mais restrito, sem ADB root)
#   "eng"       → Engenharia (muito permissivo, não recomendado para uso)
# ALGUMAS ROMs usam nomes próprios (ex: "gms_core", "vanilla")
BUILD_TYPE="userdebug"

# =============================================================================
#  SEÇÃO 2: ARQUIVOS PARA BACKUP
#  Liste aqui qualquer arquivo que você editar manualmente na source.
#  Caminhos relativos à BUILD_DIR.
# =============================================================================

# Exemplos de arquivos comuns que precisam de backup após modificação manual:
BACKUP_FILES=(
    "device/${MANUFACTURER}/${DEVICE}/device.mk"
    "device/${MANUFACTURER}/${DEVICE}/BoardConfig.mk"
    "device/${MANUFACTURER}/${DEVICE}/BoardConfigVendor.mk"
    # Adicione outros arquivos que você modificar:
    # "device/<fabricante>/<dispositivo>/sepolicy/genfs_contexts"
    # "device/<fabricante>/<dispositivo>/rootdir/etc/init.<codename>.rc"
)

# =============================================================================
#  SEÇÃO 3: CORES E FUNÇÕES DE OUTPUT
#  Não é necessário editar nada abaixo desta linha para uso básico.
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color (reset)

# Funções de saída formatada:
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }
tip()     { echo -e "${MAGENTA}[DICA]${NC} $1"; }

# Função de confirmação interativa (resposta s/N)
confirm() {
    read -rp "$(echo -e "${YELLOW}$1 [s/N]: ${NC}")" resp
    [[ "$resp" =~ ^[sS]$ ]] || { info "Pulando etapa."; return 1; }
    return 0
}

# =============================================================================
#  SEÇÃO 4: VERIFICAÇÕES DO SISTEMA
# =============================================================================

# Verifica espaço em disco disponível em um dado caminho
# Uso: check_space <gb_necessários> <caminho>
check_space() {
    local required_gb=$1
    local path=$2
    local available_gb

    # Cria o diretório se não existir, para poder verificar
    mkdir -p "$path" 2>/dev/null || true

    available_gb=$(df -BG "$path" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')

    if [ -z "$available_gb" ] || [ "$available_gb" -lt "$required_gb" ]; then
        error "Espaço insuficiente em $path. Necessário: ${required_gb}GB | Disponível: ${available_gb:-?}GB"
    fi
    success "Espaço em $path: ${available_gb}GB disponíveis (mínimo: ${required_gb}GB)"
}

# Verifica RAM e swap disponíveis
# DICA: Compilar Android requer muita memória. Mínimo recomendado: 16GB RAM+Swap
check_ram_and_swap() {
    local total_ram_mb
    local total_swap_mb
    total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    total_swap_mb=$(free -m | awk '/^Swap:/{print $2}')
    local total_mb=$(( total_ram_mb + total_swap_mb ))

    info "RAM: ${total_ram_mb}MB | Swap: ${total_swap_mb}MB | Total: ${total_mb}MB"

    if [ "$total_swap_mb" -lt 8192 ]; then
        warn "Swap menor que 8GB detectado!"
        warn "Com pouca swap, a compilação PODE travar ou matar processos (OOM Killer)."
        warn "Comandos para criar swap (execute antes de compilar):"
        echo ""
        echo "  sudo fallocate -l 16G /swapfile"
        echo "  sudo chmod 600 /swapfile"
        echo "  sudo mkswap /swapfile"
        echo "  sudo swapon /swapfile"
        echo ""
        warn "Para tornar permanente, adicione ao /etc/fstab:"
        echo "  /swapfile none swap sw 0 0"
        echo ""
        tip "Se seu HD/SSD for lento, swap em arquivo pode ser mais lento que RAM."
        tip "Nesse caso, considere zram: sudo apt install zram-config"
        echo ""
        confirm "Continuar mesmo sem swap adequado? (NÃO recomendado)" || exit 1
    else
        success "Swap adequado detectado."
    fi
}

# =============================================================================
#  SEÇÃO 5: SELEÇÃO DE VARIANTE DE BUILD
#  Adapte conforme as variantes suportadas pela sua ROM.
# =============================================================================

select_variant() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Selecione a Variante de Build              ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}   [1] userdebug  — Desenvolvimento       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   [2] user       — Uso diário            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   [3] eng        — Engenharia            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   NOTA: Algumas ROMs usam nomes próprios ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ex. gms_core, gms_pico, vanilla        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Variante atual: ${GREEN}${BUILD_TYPE}${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Escolha [1/2/3] ou Enter pra manter atual: ${NC}")" var_opt

    case "$var_opt" in
        1) BUILD_TYPE="userdebug"; success "Variante: userdebug" ;;
        2) BUILD_TYPE="user";      success "Variante: user" ;;
        3) BUILD_TYPE="eng";       warn "Variante: eng (não recomendado para uso diário)" ;;
        "") info "Mantendo variante: $BUILD_TYPE" ;;
        *) warn "Opção inválida. Mantendo: $BUILD_TYPE" ;;
    esac
}

# =============================================================================
#  SEÇÃO 6: BACKUP E RESTAURAÇÃO
#  Salva e restaura arquivos editados manualmente (útil após repo sync)
# =============================================================================

step_backup_save() {
    info "══════════════════════════════════════════════════"
    info "   BACKUP: Salvando configurações customizadas"
    info "══════════════════════════════════════════════════"

    # Cria o diretório de backup
    # DICA: Se der erro de "Permission denied" ou "No such file or directory",
    #       crie manualmente: mkdir -p ~/rom_backup
    mkdir -p "$BACKUP_DIR" || error "Não foi possível criar $BACKUP_DIR. Crie manualmente: mkdir -p $BACKUP_DIR"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_slot="$BACKUP_DIR/$timestamp"

    mkdir -p "$backup_slot"

    local saved=0
    local skipped=0

    for rel_path in "${BACKUP_FILES[@]}"; do
        local full_path="$BUILD_DIR/$rel_path"
        if [ -f "$full_path" ]; then
            local dest_dir="$backup_slot/$(dirname "$rel_path")"
            # DICA: Se der erro em mkdir aqui, o caminho pode conter caracteres especiais.
            #       Verifique os nomes em BACKUP_FILES acima.
            mkdir -p "$dest_dir"
            cp "$full_path" "$dest_dir/"
            info "  Salvo: $rel_path"
            ((saved++))
        else
            warn "  Não encontrado (pulando): $rel_path"
            ((skipped++))
        fi
    done

    # Salva também a variante de build e configurações gerais
    {
        echo "BUILD_TYPE=$BUILD_TYPE"
        echo "BACKUP_DATE=$timestamp"
        echo "DEVICE=$DEVICE"
        echo "BRANCH_ROM=$BRANCH_ROM"
    } > "$backup_slot/build_config.env"

    # Cria symlink "latest" apontando para o backup mais recente
    ln -sfn "$backup_slot" "$BACKUP_DIR/latest"

    echo ""
    success "Backup salvo em: $backup_slot"
    success "Arquivos salvos: $saved | Não encontrados: $skipped"
    info "Acesso rápido: $BACKUP_DIR/latest"

    echo ""
    info "Backups disponíveis (últimos 10):"
    ls -1 "$BACKUP_DIR" | grep -v "^latest$" | sort -r | head -10 | \
        while read -r b; do echo "  • $b"; done
}

step_backup_restore() {
    info "══════════════════════════════════════════════════"
    info "     Restaurando configurações customizadas"
    info "══════════════════════════════════════════════════"

    if [ ! -d "$BACKUP_DIR" ]; then
        error "Nenhum backup encontrado em $BACKUP_DIR. Faça um backup primeiro (opção [b])."
    fi

    # Lista backups disponíveis (exclui o symlink 'latest')
    local backups=()
    while IFS= read -r b; do
        [[ "$b" != "latest" ]] && backups+=("$b")
    done < <(ls -1 "$BACKUP_DIR" | grep -v "^latest$" | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        error "Nenhum backup encontrado em $BACKUP_DIR."
    fi

    echo ""
    echo "  Backups disponíveis (mais recente primeiro):"
    echo ""

    local latest_target
    latest_target=$(readlink "$BACKUP_DIR/latest" 2>/dev/null | xargs basename 2>/dev/null || echo "")

    for i in "${!backups[@]}"; do
        local b="${backups[$i]}"
        local tag=""
        [[ "$b" == "$latest_target" ]] && tag=" ${GREEN}← mais recente${NC}"
        printf "  [%d] %s%b\n" "$((i+1))" "$b" "$tag"
    done

    echo ""
    read -rp "$(echo -e "${YELLOW}Qual restaurar? [1-${#backups[@]}] ou Enter para o mais recente: ${NC}")" restore_opt

    local chosen_backup
    if [ -z "$restore_opt" ]; then
        chosen_backup="$BACKUP_DIR/${backups[0]}"
        info "Usando backup mais recente: ${backups[0]}"
    elif [[ "$restore_opt" =~ ^[0-9]+$ ]] && \
         [ "$restore_opt" -ge 1 ] && \
         [ "$restore_opt" -le "${#backups[@]}" ]; then
        chosen_backup="$BACKUP_DIR/${backups[$((restore_opt-1))]}"
        info "Usando backup: ${backups[$((restore_opt-1))]}"
    else
        error "Opção inválida."
    fi

    echo ""
    confirm "Confirmar restauração de $(basename "$chosen_backup")?" || return 0

    local restored=0
    local not_in_backup=0

    for rel_path in "${BACKUP_FILES[@]}"; do
        local src="$chosen_backup/$rel_path"
        local dest="$BUILD_DIR/$rel_path"

        if [ -f "$src" ]; then
            # Preserva o arquivo atual com extensão .before_restore (safety net)
            [ -f "$dest" ] && cp "$dest" "${dest}.before_restore"

            # DICA: Se der erro em mkdir ao restaurar, o caminho destino pode não existir.
            #       Isso pode acontecer se a device tree ainda não foi clonado.
            #       Clone a device tree primeiro (opção [5]) e tente novamente.
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            info "  Restaurado: $rel_path"
            ((restored++))
        else
            warn "  Não está no backup (pulando): $rel_path"
            ((not_in_backup++))
        fi
    done

    # Restaura variante de build se disponível no backup
    local config_env="$chosen_backup/build_config.env"
    if [ -f "$config_env" ]; then
        local saved_variant
        saved_variant=$(grep "^BUILD_TYPE=" "$config_env" | cut -d'=' -f2)
        if [ -n "$saved_variant" ]; then
            BUILD_TYPE="$saved_variant"
            info "  Variante de build restaurada: $BUILD_TYPE"
        fi
    fi

    echo ""
    success "Restauração concluída! Restaurados: $restored | Não encontrados: $not_in_backup"
    warn "Arquivos originais preservados com extensão .before_restore"
}

# =============================================================================
#  SEÇÃO 7: SYNC SEGURO
#  Faz backup → sync do source → restaura automaticamente
# =============================================================================

step_sync_safe() {
    info "══════════════════════════════════════════════════"
    info "       Backup → Sync → Restore automático"
    info "══════════════════════════════════════════════════"
    warn "Esta opção faz backup das suas customizações ANTES do sync e"
    warn "as restaura automaticamente DEPOIS. Ideal para manter patches."
    echo ""
    confirm "Executar sync seguro agora?" || return 0

    info "Passo 1/3: Fazendo backup das configurações..."
    step_backup_save

    info "Passo 2/3: Sincronizando source..."
    cd "$BUILD_DIR"
    # DICA: "-j4" = 4 downloads paralelos. Aumente se tiver boa conexão.
    #        "-c" = apenas a branch atual (economiza espaço e tempo)
    #        "--no-tags" = ignora tags (mais rápido)
    "$BIN_DIR/repo" sync -j4 -c --no-tags --fail-fast

    info "Passo 3/3: Restaurando configurações customizadas..."
    local latest_backup
    latest_backup=$(readlink "$BACKUP_DIR/latest" 2>/dev/null || echo "")

    if [ -d "$latest_backup" ]; then
        local restored=0
        for rel_path in "${BACKUP_FILES[@]}"; do
            local src="$latest_backup/$rel_path"
            local dest="$BUILD_DIR/$rel_path"
            if [ -f "$src" ]; then
                mkdir -p "$(dirname "$dest")"
                cp "$src" "$dest"
                info "  Restaurado: $rel_path"
                ((restored++))
            fi
        done
        success "Sync seguro concluído! $restored arquivo(s) restaurado(s)."
    else
        warn "Backup mais recente não encontrado. Verifique manualmente em $BACKUP_DIR."
    fi
}

# =============================================================================
#  ETAPA 0: VERIFICAÇÕES INICIAIS DO SISTEMA
# =============================================================================

step0_checks() {
    info "══════════════════════════════════════════"
    info "     Verificações iniciais do sistema"
    info "══════════════════════════════════════════"

    # Verifica distribuição Linux
    if ! grep -qi "ubuntu\|debian\|mint\|pop" /etc/os-release 2>/dev/null; then
        warn "Distro não reconhecida como Ubuntu/Debian."
        warn "Este script foi testado em Ubuntu 20.04/22.04/24.04, Linux Mint e Debian."
        warn "Em outras distros, o instalador de dependências pode não funcionar."
        tip "Em Arch/Manjaro, use o AUR. Em Fedora, adapte os pacotes para dnf."
    fi

    # Verifica Python 3 (necessário para o repo)
    if ! command -v python3 &>/dev/null; then
        error "Python 3 não encontrado. Instale: sudo apt install python3"
    fi

    # Verifica git
    if ! command -v git &>/dev/null; then
        error "git não encontrado. Instale: sudo apt install git"
    fi

    # Verifica espaço em disco (mínimo recomendado: 400GB)
    # DICA: ROMs com GMS podem exigir até 500GB. Vanilla geralmente ~200GB.
    check_space 400 "$HOME"

    # Verifica RAM e swap
    check_ram_and_swap

    success "Verificações iniciais concluídas."
}

# =============================================================================
#  ETAPA 1: INSTALAR DEPENDÊNCIAS
#  Pacotes necessários para compilar Android (baseado em Ubuntu/Debian)
# =============================================================================

step1_dependencies() {
    info "══════════════════════════════════════════"
    info "         Instalando dependências"
    info "══════════════════════════════════════════"
    tip "Requer conexão com a internet e permissão sudo."
    echo ""
    confirm "Instalar pacotes de build agora?" || return 0

    sudo apt update

    # Pacotes essenciais para compilar Android (AOSP e derivados)
    sudo apt install -y \
        bc bison build-essential ccache curl flex \
        g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
        lib32readline-dev lib32z1-dev libdw-dev libelf-dev \
        libgnutls28-dev lz4 libsdl1.2-dev libssl-dev \
        libxml2 libxml2-utils lzop pngcrush rsync \
        schedtool squashfs-tools xsltproc zip zlib1g-dev \
        protobuf-compiler python3-protobuf \
        openjdk-11-jdk python-is-python3

    # libncurses5 — necessária em algumas ROMs antigas, mas não está nos repos do Ubuntu 22.04+
    if dpkg -l | grep -q "libncurses5 " 2>/dev/null; then
        success "libncurses5 já instalado."
    else
        info "Tentando instalar libncurses5..."
        if apt-cache show libncurses5 &>/dev/null; then
            sudo apt install -y libncurses5 lib32ncurses5-dev libncurses5-dev
        else
            warn "libncurses5 não encontrado nos repositórios."
            warn "Instalando manualmente via pacote do Ubuntu 20.04..."
            tip "Se isso falhar, ignore. Nem toda ROM precisa da libncurses5."
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb 2>/dev/null && \
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb 2>/dev/null && \
            sudo dpkg -i libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb 2>/dev/null && \
            rm -f libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb || \
            warn "Instalação manual da libncurses5 falhou. Continue e veja se causa erro na compilação."
        fi
    fi

    success "Dependências instaladas."
    tip "Se encontrar erros de compilação por pacote faltando, consulte a Wiki da ROM."
}

# =============================================================================
#  ETAPA 2: CONFIGURAR AMBIENTE DE BUILD
#  Configura repo, git, ccache e variáveis de ambiente
# =============================================================================

step2_environment() {
    info "══════════════════════════════════════════"
    info "          Configurando ambiente"
    info "══════════════════════════════════════════"

    # Cria diretórios necessários
    # DICA: Se qualquer mkdir falhar com "Permission denied" ou "Not a directory",
    #       verifique se o caminho não tem um arquivo com o mesmo nome.
    #       Exemplo: se existe um arquivo ~/android, não é possível criar ~/android/rom
    #       Solução: rm ~/android (se for arquivo) ou mude BUILD_DIR para outro local.
    for dir in "$BIN_DIR" "$BUILD_DIR" "$BACKUP_DIR"; do
        mkdir -p "$dir" || error "Não foi possível criar: $dir\n Tente criar manualmente: mkdir -p $dir"
        success "Diretório OK: $dir"
    done

    # Instala o binário "repo" (ferramenta do Google para gerenciar o source AOSP)
    if [ ! -f "$BIN_DIR/repo" ]; then
        info "Baixando repo tool..."
        curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$BIN_DIR/repo" || \
            error "Falha ao baixar o repo. Verifique sua conexão com a internet."
        chmod a+x "$BIN_DIR/repo"
        success "repo instalado em $BIN_DIR/repo"
    else
        success "repo já existe em $BIN_DIR/repo."
    fi

    # Adiciona ~/bin ao PATH no ~/.profile (persistente entre sessões)
    if ! grep -q "HOME/bin" ~/.profile 2>/dev/null; then
        cat >> ~/.profile << 'EOF'

# Android build tools
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
EOF
        success "PATH atualizado em ~/.profile"
        tip "Execute 'source ~/.profile' ou abra um novo terminal para ativar."
    else
        success "PATH já configurado em ~/.profile"
    fi

    # Valida configuração do git
    if [ "$GIT_EMAIL" = "voce@exemplo.com" ] || [ "$GIT_NAME" = "Seu Nome" ]; then
        error "GIT_EMAIL e GIT_NAME ainda estão com os valores padrão!\nEdite o script e preencha seus dados reais no topo do arquivo."
    fi

    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_NAME"
    git lfs install
    git config --global trailer.changeid.key "Change-Id"
    success "Git configurado: $GIT_NAME <$GIT_EMAIL>"

    # Configura ccache no ~/.bashrc (cache de compilação — acelera builds repetidas)
    if ! grep -q "USE_CCACHE" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# ccache para builds Android
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$HOME/.ccache"
EOF
        success "ccache adicionado ao .bashrc"
    fi

    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    ccache -M "$CCACHE_SIZE"
    ccache -o compression=true
    success "ccache configurado: ${CCACHE_SIZE}, compressão ativada."

    # Configurações de heap Java
    # DICA: Ajuste -Xmx conforme sua RAM disponível:
    #   16GB RAM > -Xmx8g
    #   32GB RAM > -Xmx12g
    #   64GB RAM > -Xmx32g
    export _JAVA_OPTIONS="-Xmx6g -Xms512m"
    export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
    success "Java heap configurado."
}

# =============================================================================
#  ETAPA 3: BAIXAR O SOURCE DA ROM
#  Inicializa o repo e sincroniza o source (pode demorar horas!)
# =============================================================================

step3_source() {
    info "══════════════════════════════════════════"
    info "          Baixando source da ROM"
    info "══════════════════════════════════════════"
    warn "Isso pode demorar MUITO dependendo da sua conexão."
    warn "O source completo pode ocupar 200-300GB de espaço!"
    echo ""
    tip "Se o sync travar ou falhar no meio, rode novamente — ele continua de onde parou."
    tip "Se tiver erros de 'Connection reset', tente diminuir o -j (ex: -j2)."
    echo ""

    # ATENÇÃO: Verifique se ROM_MANIFEST_URL está correto antes de continuar!
    if [[ "$ROM_MANIFEST_URL" == *"SuaROM"* ]]; then
        error "ROM_MANIFEST_URL ainda está com o valor padrão!\nEdite o script e preencha a URL correta do manifest da sua ROM."
    fi

    cd "$BUILD_DIR"

    if [ -d ".repo" ]; then
        warn "Repo já inicializado em $BUILD_DIR. Pulando init."
        tip "Se quiser trocar de ROM, exclua $BUILD_DIR e comece do zero."
    else
        confirm "Inicializar repo (${ROM_MANIFEST_URL} @ ${BRANCH_ROM})?" || return 0
        "$BIN_DIR/repo" init \
            -u "$ROM_MANIFEST_URL" \
            -b "$BRANCH_ROM" \
            --git-lfs \
            --no-clone-bundle
        success "Repo inicializado."
    fi

    confirm "Sincronizar source agora? (pode demorar HORAS)" || return 0

    # Sync da source
    # DICA: Ajuste -j conforme sua conexão. -j8 = 8 downloads paralelos.
    #       Em conexões instáveis, use -j2 ou -j4.
    "$BIN_DIR/repo" sync -j4 -c --no-tags --fail-fast

    success "Source sincronizado com sucesso."
}

# =============================================================================
#  ETAPA 4: CLONAR DEVICE TREES
#  Clona device tree, kernel source e vendor blobs
#
#  ATENÇÃO: Você PRECISA encontrar os repositórios corretos para o seu dispositivo!
#  Fontes recomendadas:
#    - LineageOS: https://github.com/LineageOS
#    - TheMuppets (vendor blobs): https://github.com/TheMuppets
#    - XDA Developers: https://xdaforums.com
#    - Telegram do seu dispositivo ou da ROM
# =============================================================================

step4_device_trees() {
    info "══════════════════════════════════════════"
    info "          Clonando device trees"
    info "══════════════════════════════════════════"
    warn "IMPORTANTE: Verifique se as URLs abaixo estão corretas para seu dispositivo!"
    warn "Se o repositório não existir, você precisará encontrá-lo manualmente."
    tip "Pesquise no GitHub: android_device_${MANUFACTURER}_${DEVICE}"
    echo ""

    # Verifica se as variáveis foram preenchidas
    if [ "$DEVICE" = "seu_codename_aqui" ]; then
        error "Variável DEVICE não configurada! Edite o script e preencha o codename do seu dispositivo."
    fi

    cd "$BUILD_DIR"

    # ── Device tree ──────────────────────────────────────────────────────────
    local device_path="device/${MANUFACTURER}/${DEVICE}"
    if [ ! -d "$device_path" ]; then
        info "Clonando device tree para: $device_path"
        # DICA: Se der erro "repository not found", a URL está errada.
        #       Pesquise o repositório correto no GitHub ou XDA.
        # DICA: Se der erro em mkdir, verifique se device/${MANUFACTURER} tem permissão de escrita.
        mkdir -p "device/${MANUFACTURER}"
        git clone "$DEVICE_TREE_URL" \
            -b "$BRANCH_DEVICE" \
            "$device_path" || {
            warn "Falha ao clonar device tree."
            tip "Verifique a URL: $DEVICE_TREE_URL"
            tip "E a branch: $BRANCH_DEVICE"
            tip "Pesquise o repositório correto no GitHub ou XDA Developers."
            error "Clone do device tree falhou."
        }
        success "Device tree clonado em: $device_path"
    else
        success "Device tree já existe: $device_path"
    fi

    # ── Kernel source ────────────────────────────────────────────────────────
    # NOTA: Nem toda ROM exige recompilar o kernel.
    # Verifique na documentação da sua ROM se é necessário clonar o kernel.
    local kernel_path="kernel/${MANUFACTURER}/$(basename "$KERNEL_REPO_URL" .git | sed 's/android_kernel_[^_]*_//')"
    if [ ! -d "$kernel_path" ]; then
        info "Clonando kernel source..."
        tip "Se sua ROM usa kernel precompilado, você pode pular esta etapa."
        mkdir -p "$(dirname "$kernel_path")"
        git clone "$KERNEL_REPO_URL" "$kernel_path" || {
            warn "Falha ao clonar kernel."
            tip "Verifique a URL: $KERNEL_REPO_URL"
            tip "Se não tiver kernel source, veja se a ROM usa 'vendor kernel' (precompilado)."
            warn "Continuando sem kernel clonado — pode causar erro na build se necessário."
        }
    else
        success "Kernel já existe: $kernel_path"
    fi

    # ── Vendor blobs ─────────────────────────────────────────────────────────
    local vendor_path="vendor/${MANUFACTURER}/${DEVICE}"
    if [ ! -d "$vendor_path" ]; then
        info "Clonando vendor blobs..."
        tip "Se o repositório não existir no TheMuppets, tente extrair do firmware stock."
        tip "Veja: https://wiki.lineageos.org/extracting_blobs_from_zips"
        mkdir -p "vendor/${MANUFACTURER}"
        git clone "$VENDOR_REPO_URL" \
            -b "$BRANCH_DEVICE" \
            "$vendor_path" || {
            warn "Falha ao clonar vendor blobs."
            tip "Verifique a URL: $VENDOR_REPO_URL"
            tip "Alternativas:"
            tip "  1. TheMuppets: https://github.com/TheMuppets"
            tip "  2. Extrair do firmware stock com extract-files.sh"
            tip "  3. Pedir ao maintainer da ROM pelo Telegram/XDA"
            error "Clone dos vendor blobs falhou."
        }
        success "Vendor blobs clonados em: $vendor_path"
    else
        success "Vendor blobs já existem: $vendor_path"
    fi

    success "Device trees prontos."
    echo ""
    tip "Se sua ROM exige repos adicionais (ex: common device tree, soc-vendor),"
    tip "clone-os manualmente antes de compilar. Veja a documentação do device tree."
}

# =============================================================================
#  ETAPA 5: PATCHES / CONFIGURAÇÕES ESPECÍFICAS DA ROM
#  Adapte conforme as necessidades da sua ROM e dispositivo.
#  Esta etapa é altamente específica — use como template.
# =============================================================================

step5_patches() {
    info "══════════════════════════════════════════"
    info "   Aplicando patches/configurações da ROM"
    info "══════════════════════════════════════════"
    warn "Esta etapa é específica para cada ROM e dispositivo."
    warn "Por padrão, nenhum patch é aplicado."
    echo ""
    tip "Se sua ROM exige patches no device tree, adicione-os aqui."
    tip "Exemplos comuns:"
    tip "  - Adicionar variáveis da ROM ao device.mk"
    tip "  - Modificar propriedades no lineage_<device>.mk ou <rom>_<device>.mk"
    tip "  - Adicionar arquivos de configuração específicos"
    echo ""

    # EXEMPLO: Como adicionar variáveis ao device.mk
    # Descomente e adapte conforme necessário:
    #
    # local device_mk="$BUILD_DIR/device/${MANUFACTURER}/${DEVICE}/device.mk"
    #
    # if grep -q "MinhaROM" "$device_mk" 2>/dev/null; then
    #     warn "Patches já aplicados. Pulando."
    #     return 0
    # fi
    #
    # cp "$device_mk" "${device_mk}.bak"
    # cat >> "$device_mk" << 'EOF'
    #
    # # ── ROM Configuration ──────────────────────────────────────────────────
    # TARGET_DISABLE_EPPE := true
    # MINHA_ROM_MAINTAINER := Seu Nome
    # EOF
    #
    # success "Patches aplicados em device.mk"

    info "Nenhum patch padrão aplicado."
    tip "Edite a função step5_patches() no script para adicionar seus patches."
}

# =============================================================================
#  ETAPA 6: COMPILAR A ROM
#  Configura o ambiente e inicia a compilação
# =============================================================================

step6_build() {
    info "══════════════════════════════════════════"
    info "           Compilando a ROM"
    info "══════════════════════════════════════════"

    # Seleciona variante antes de compilar
    select_variant

    echo ""
    echo -e "  Dispositivo : ${GREEN}$DEVICE${NC}"
    echo -e "  Variante    : ${GREEN}$BUILD_TYPE${NC}"
    echo -e "  Threads     : ${GREEN}$JOBS${NC}"
    echo -e "  Branch ROM  : ${GREEN}$BRANCH_ROM${NC}"
    echo ""
    warn "O tempo de compilação varia muito conforme o hardware:"
    warn "  CPU fraca (4 cores, 16GB RAM)    : 16hrs - 2 dias"
    warn "  CPU média (8 cores, 16GB RAM+)   : 2-6 horas"
    warn "  CPU potente (12+ cores, 32GB+)   : 30min-2 horas"
    warn "  Com ccache (builds subsequentes) : muito mais rápido"
    echo ""
    confirm "Iniciar compilação agora?" || return 0

    cd "$BUILD_DIR"

    # Configurações de ambiente para a build
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_COMPRESSION=1
    export NINJA_ARGS="-j${JOBS}"
    export _JAVA_OPTIONS="-Xmx6g -Xms512m"

    # Carrega o ambiente de build do Android (envsetup.sh)
    # DICA: Se "source build/envsetup.sh" falhar, verifique se a source foi
    #       sincronizado corretamente (etapa [4]).
    if [ ! -f "$BUILD_DIR/build/envsetup.sh" ]; then
        error "build/envsetup.sh não encontrado!\nVerifique se o source foi sincronizado (etapa [4])."
    fi

    source build/envsetup.sh

    # Gera chaves de assinatura (necessário apenas na primeira vez)
    # DICA: As chaves identificam suas builds. Não delete-as após geradas!
    #       Se perder as chaves, builds futuras não serão compatíveis com as anteriores.
    local CERT_DIR="$BUILD_DIR/certs"
    if [ ! -d "$CERT_DIR" ]; then
        info "Gerando chaves privadas em: $CERT_DIR"
        mkdir -p "$CERT_DIR" || error "Não foi possível criar $CERT_DIR. Tente: mkdir -p $CERT_DIR"
        cd "$CERT_DIR"

        for cert in releasekey platform shared media networkstack testkey; do
            info "  Gerando: $cert"
            openssl genrsa -out "${cert}.pem" 4096 2>/dev/null
            openssl req -new -x509 -key "${cert}.pem" \
                -out "${cert}.x509.pem" \
                -days 10000 \
                -subj "/C=US/ST=State/L=City/O=Android/OU=Android/CN=Android" \
                2>/dev/null
            openssl pkcs8 -in "${cert}.pem" -topk8 -nocrypt \
                -out "${cert}.pk8" -outform DER \
                2>/dev/null
            rm "${cert}.pem"
        done

        cd "$BUILD_DIR"
        success "Chaves geradas em: $CERT_DIR"
        warn "GUARDE ESSAS CHAVES! Sem elas, não poderá atualizar sua ROM sem wipe."
    else
        success "Chaves já existem em $CERT_DIR — pulando geração."
    fi

    # Configura o target de build
    # DICA: "breakfast" é o comando padrão da LineageOS/derivados para configurar o target.
    #       Algumas ROMs usam comandos próprios (ex: "axion" para AxionOS, "crave" para CrDroid).
    #       Verifique a documentação da sua ROM!
    info "Configurando target: $DEVICE ($BUILD_TYPE)"
    if command -v breakfast &>/dev/null; then
        breakfast "$DEVICE" "$BUILD_TYPE" || \
            error "breakfast falhou. Verifique se o device tree está correto (etapa [5])."
    else
        warn "Comando 'breakfast' não encontrado."
        tip "Algumas ROMs usam comandos próprios. Tente manualmente:"
        tip "  lunch <rom>_${DEVICE}-${BUILD_TYPE}"
        tip "  Ou veja a documentação da ROM para o comando correto."
        error "Configure o target manualmente e use a opção [7] novamente."
    fi

    # Inicia a compilação
    local log_file="$BUILD_DIR/build_${BUILD_TYPE}_$(date +%Y%m%d_%H%M).log"
    info "Iniciando compilação com $JOBS threads..."
    info "Log em: $log_file"
    echo ""

    # Tenta comandos comuns de build de diferentes ROMs
    # DICA: Adapte conforme a sua ROM:
    #   LineageOS / derivados → brunch <device>
    #   PixelOS               → m bacon
    #   Algumas ROMs          → mka bacon ou mka <rom>
    if command -v brunch &>/dev/null; then
        brunch "$DEVICE" 2>&1 | tee "$log_file"
    else
        warn "Comando 'brunch' não encontrado. Tentando 'm bacon'..."
        m bacon -j"$JOBS" 2>&1 | tee "$log_file" || \
            error "Compilação falhou. Verifique o log em: $log_file"
    fi

    echo ""
    success "════════════════════════════════════════════"
    success " Build concluída!"
    success "════════════════════════════════════════════"
    info "Arquivos de saída em: $BUILD_DIR/out/target/product/$DEVICE/"

    # Lista os arquivos .zip gerados
    local zips
    zips=$(ls -lh "$BUILD_DIR/out/target/product/$DEVICE/"*.zip 2>/dev/null)
    if [ -n "$zips" ]; then
        echo "$zips"
    else
        warn "Nenhum .zip encontrado. Verifique o log: $log_file"
        tip "Procure por 'error:' ou 'FAILED:' no log para identificar o problema."
    fi
}

# =============================================================================
#  DIAGNÓSTICO: Verifica branches dos repositórios clonados
#  Útil para identificar problemas de branch incorreta
# =============================================================================

step_diagnose() {
    info "══════════════════════════════════════════════════"
    info "      Verificando branches dos repositórios"
    info "══════════════════════════════════════════════════"
    tip "Branches erradas são causa comum de erros de compilação."
    echo ""

    # Mapa de repositório → branch esperada
    # DICA: Adicione aqui os repositórios que você clonou manualmente
    declare -A expected_branches=(
        ["device/${MANUFACTURER}/${DEVICE}"]="$BRANCH_DEVICE"
        ["vendor/${MANUFACTURER}/${DEVICE}"]="$BRANCH_DEVICE"
        # Adicione outros conforme necessário:
        # ["device/${MANUFACTURER}/${DEVICE}-common"]="$BRANCH_DEVICE"
        # ["kernel/${MANUFACTURER}/chipset"]="$BRANCH_DEVICE"
    )

    local all_ok=true

    for rel_path in "${!expected_branches[@]}"; do
        local full_path="$BUILD_DIR/$rel_path"
        local expected="${expected_branches[$rel_path]}"

        if [ ! -d "$full_path" ]; then
            warn "  NÃO ENCONTRADO: $rel_path"
            all_ok=false
            continue
        fi

        local current
        current=$(git -C "$full_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "erro")
        local last_commit
        last_commit=$(git -C "$full_path" log -1 --format="%h %s" 2>/dev/null || echo "N/A")

        if [ "$current" = "$expected" ]; then
            success "  OK  $rel_path"
            info "       Branch: $current | Commit: $last_commit"
        else
            warn "  BRANCH ERRADA: $rel_path"
            warn "       Esperada : $expected"
            warn "       Atual    : $current"
            warn "       Commit   : $last_commit"
            all_ok=false

            tip "Para corrigir: cd $BUILD_DIR/$rel_path"
            tip "               git fetch origin $expected"
            tip "               git checkout $expected"
        fi
    done

    echo ""
    if $all_ok; then
        success "Todos os repositórios estão nas branches corretas."
    else
        warn "Um ou mais repositórios estão com branch incorreta."
        warn "Branches erradas causam erros como 'soong bootstrap failed' ou 'module not found'."
    fi
}

# =============================================================================
#  MENU PRINCIPAL
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                         < BRG-SH >                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Dispositivo   : ${GREEN}${DEVICE}${NC} (${MANUFACTURER})"
    echo -e "  Branch ROM    : ${GREEN}${BRANCH_ROM}${NC}"
    echo -e "  Branch DevTree: ${GREEN}${BRANCH_DEVICE}${NC}"
    echo -e "  Diretório     : ${BLUE}${BUILD_DIR}${NC}"
    echo -e "  Backup        : ${BLUE}${BACKUP_DIR}${NC}"
    echo -e "  Threads       : ${GREEN}${JOBS}${NC}"
    echo -e "  Variante      : ${GREEN}${BUILD_TYPE}${NC}"
    echo ""
    echo "  ── Setup (primeira vez) ──────────────────────────────────"
    echo "  [0] Tudo do zero (todas as etapas em sequência)"
    echo "  [1] Verificações iniciais do sistema"
    echo "  [2] Instalar dependências"
    echo "  [3] Configurar ambiente (repo, git, ccache)"
    echo "  [4] Baixar source da ROM"
    echo "  [5] Clonar device trees (device / kernel / vendor)"
    echo "  [6] Aplicar patches/configurações da ROM"
    echo ""
    echo "  ── Build ─────────────────────────────────────────────────"
    echo "  [7] Compilar (pergunta variante antes)"
    echo "  [v] Mudar variante de build"
    echo ""
    echo "  ── Backup & Sync ─────────────────────────────────────────"
    echo "  [b] Fazer backup das configurações customizadas"
    echo "  [r] Restaurar backup (escolhe qual)"
    echo "  [s] Sync seguro (backup → sync → restore automático)"
    echo ""
    echo "  ── Diagnóstico ───────────────────────────────────────────"
    echo "  [d] Verificar branches dos repositórios"
    echo ""
    echo "  [q] Sair"
    echo ""
    read -rp "$(echo -e "${YELLOW}Opção: ${NC}")" opt

    case "$opt" in
        0)
            step0_checks
            step1_dependencies
            step2_environment
            step3_source
            step4_device_trees
            step5_patches
            step6_build
            ;;
        1) step0_checks ;;
        2) step1_dependencies ;;
        3) step2_environment ;;
        4) step3_source ;;
        5) step4_device_trees ;;
        6) step5_patches ;;
        7) step6_build ;;
        v|V) select_variant; main ;;
        b|B) step_backup_save ;;
        r|R) step_backup_restore ;;
        s|S) step_sync_safe ;;
        d|D) step_diagnose ;;
        q|Q) info "Saindo. Boas builds!"; exit 0 ;;
        *) warn "Opção inválida."; main ;;
    esac
}

# Ponto de entrada
main
