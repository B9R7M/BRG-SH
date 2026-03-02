#!/bin/bash

# AxionOS Unofficial para Motorola Edge 20 Pro (pstar)
# Baseado em: LineageOS Wiki for pstar + AxionOS Manifest on Github

# Otimizações:
#  - THREADS limitadas a 4
#  - JACK server desabilitado
#  - Swap mínimo recomendado de 16GB antes de compilar (Quanto menos RAM, maior o Swap)
#  - Ninja limitado a 4 jobs paralelos (Use um CPU de pelo menos 4 núcleos)
#  - ccache com compressão ativada (pouco espaço para SSD limitado)
#  - Heap do Java aumentado mas com teto seguro

set -e  # Em caso de falha

# Configs:
DEVICE="pstar"
BRANCH_AXION="lineage-23.1"  # Branch atual da AxionOS (Pode mudar em Syncs futuros, altere se isso aconteça)
BRANCH_LINEAGE="lineage-23.2"  # Branch do device tree LineageOS (Também pode mudar no futuro, altere caso isso aconteça)
BUILD_DIR="$HOME/android/axion"  # Local repo da AxionOS
BIN_DIR="$HOME/bin"  # Se não sabe o que está fazendo, não altere!
CCACHE_DIR="$HOME/.ccache" # Crie manualmente o ccache em sua máquina
CCACHE_SIZE="50G"  # Padrão da Wiki
JOBS=4  # NÃO aumente isso no seu hardware, caso ele seja fraco!
GIT_EMAIL="username@email.com" # Seu Email (Obrigatório)
GIT_NAME="Name"  # Seu nome (Obrigatório)

# Variante de build definida por padrão (Pode ser alterado no menu)
BUILD_VARIANT="gms_core"

# Diretório onde os backups das configs serão salvos
BACKUP_DIR="$HOME/axion_backup"

# Arquivos monitorados para backup
# Adicione aqui qualquer arquivo que você editar manualmente
BACKUP_FILES=(
    "device/motorola/pstar/device.mk"
    "device/motorola/pstar/lineage_pstar.mk"
    "device/motorola/pstar/BoardConfig.mk"
    "device/motorola/pstar/BoardConfigVendor.mk"
    "device/motorola/pstar/sepolicy/genfs_contexts"
    "device/motorola/pstar/rootdir/etc/init.pstar.rc"
)

# Cores pra output legível:
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções auxiliares:
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

confirm() {
    read -rp "$(echo -e "${YELLOW}$1 [s/N]: ${NC}")" resp
    [[ "$resp" =~ ^[sS]$ ]] || { info "Pulando etapa."; return 1; }
    return 0
}

check_space() {
    local required_gb=$1
    local path=$2
    local available_gb
    available_gb=$(df -BG "$path" | tail -1 | awk '{print $4}' | tr -d 'G')
    if [ "$available_gb" -lt "$required_gb" ]; then
        error "Espaço insuficiente em $path. Necessário: ${required_gb}GB | Disponível: ${available_gb}GB"
    fi
    success "Espaço disponível em $path: ${available_gb}GB (mínimo: ${required_gb}GB)"
}

check_ram_and_swap() {
    local total_ram_mb
    local total_swap_mb
    total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    total_swap_mb=$(free -m | awk '/^Swap:/{print $2}')

    info "RAM: ${total_ram_mb}MB | Swap: ${total_swap_mb}MB | Total: $((total_ram_mb + total_swap_mb))MB"

    if [ "$total_swap_mb" -lt 8192 ]; then
        warn "Swap menor que 8GB detectado!"
        warn "Pouca RAM e sem swap adequado, a build PODE travar/matar processos."
        warn "Execute ANTES de compilar:"
        echo ""
        echo "  sudo fallocate -l 16G /swapfile" # Mínimo recomendo
        echo "  sudo chmod 600 /swapfile"
        echo "  sudo mkswap /swapfile"
        echo "  sudo swapon /swapfile"
        echo ""
        warn "Para swap permanente, adicione ao /etc/fstab:"
        echo "  /swapfile none swap sw 0 0"
        echo ""
        confirm "Continuar mesmo assim (NÃO recomendado)?" || exit 1
    else
        success "Swap adequado detectado."
    fi
}

# Seleção de variante de builds:
select_variant() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             Selecione a Variante de Build            ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                 [1] GMS Core             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                    ______                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                 [2] GMS Pico             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                    ______                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                 [3] Vanilla              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Variante atual: ${GREEN}${BUILD_VARIANT}${NC}"
    echo ""
    read -rp "$(echo -e "${YELLOW}Escolha [1/2/3] ou Enter pra manter atual: ${NC}")" var_opt

    case "$var_opt" in
        1) BUILD_VARIANT="gms_core"; success "Variante: GMS Core (Google completo)" ;;
        2) BUILD_VARIANT="gms_pico"; success "Variante: GMS Pico (Google mínimo)" ;;
        3) BUILD_VARIANT="vanilla";  success "Variante: Vanilla (sem Google)" ;;
        "") info "Mantendo variante: $BUILD_VARIANT" ;;
        *)  warn "Opção inválida. Mantendo: $BUILD_VARIANT" ;;
    esac
}

# Converte variante interna para o argumento do comando 'axion'
get_axion_variant_arg() {
    case "$BUILD_VARIANT" in
        gms_core) echo "gms core" ;;
        gms_pico) echo "gms pico" ;;
        vanilla)  echo "va" ;;
        *)        echo "gms core" ;;
    esac
}

# Função de backup:
step_backup_save() {
    info "══════════════════════════════════════════════════"
    info "   BACKUP: Salvando configurações customizadas"
    info "══════════════════════════════════════════════════"

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
            mkdir -p "$dest_dir"
            cp "$full_path" "$dest_dir/"
            info "  Salvo: $rel_path"
            ((saved++))
        else
            warn "  Não encontrado (pulando): $rel_path"
            ((skipped++))
        fi
    done

    # Salva também a variante de build atual
    {
        echo "BUILD_VARIANT=$BUILD_VARIANT"
        echo "BACKUP_DATE=$timestamp"
        echo "DEVICE=$DEVICE"
    } > "$backup_slot/build_config.env"

    # Atualiza symlink 'latest'
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

# Função de restauração após o Sync:
step_backup_restore() {
    info "══════════════════════════════════════════════════"
    info "     Restaurando configurações customizadas"
    info "══════════════════════════════════════════════════"

    if [ ! -d "$BACKUP_DIR" ]; then
        error "Nenhum backup encontrado em $BACKUP_DIR. Faça um backup primeiro."
    fi

    # Coleta backups disponíveis (sem o symlink 'latest')
    local backups=()
    while IFS= read -r b; do
        [[ "$b" != "latest" ]] && backups+=("$b")
    done < <(ls -1 "$BACKUP_DIR" | grep -v "^latest$" | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        error "Nenhum backup encontrado."
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
            # Salva .before_restore do arquivo atual antes de sobrescrever
            [ -f "$dest" ] && cp "$dest" "${dest}.before_restore"
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            info "  Restaurado: $rel_path"
            ((restored++))
        else
            warn "  Não está no backup (pulando): $rel_path"
            ((not_in_backup++))
        fi
    done

    # Restaura variante de build se disponível
    local config_env="$chosen_backup/build_config.env"
    if [ -f "$config_env" ]; then
        local saved_variant
        saved_variant=$(grep "^BUILD_VARIANT=" "$config_env" | cut -d'=' -f2)
        if [ -n "$saved_variant" ]; then
            BUILD_VARIANT="$saved_variant"
            info "  Variante de build restaurada: $BUILD_VARIANT"
        fi
    fi

    echo ""
    success "Restauração concluída! Restaurados: $restored | Não encontrados: $not_in_backup"
    warn "Os arquivos originais foram preservados com extensão .before_restore"
}

# Sync seguro:
step_sync_safe() {
    info "══════════════════════════════════════════════════"
    info "        Backup → Sync → Restore automático"
    info "══════════════════════════════════════════════════"
    warn "Faz backup antes do sync e restaura automaticamente depois."
    echo ""
    confirm "Executar sync seguro agora?" || return 0

    # 1. Backup
    info "Passo 1/3: Fazendo backup das configurações..."
    step_backup_save

    # 2. Sync
    info "Passo 2/3: Sincronizando source..."
    cd "$BUILD_DIR"
    "$BIN_DIR/repo" sync -j2 -c --no-tags --fail-fast

    # 3. Restore automático do backup mais recente (o que acabamos de criar)
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
        warn "Backup mais recente não encontrado. Verifique manualmente."
    fi
}

# ETAPA 0: VERIFICAÇÕES INICIAIS
step0_checks() {
    info "══════════════════════════════════════════"
    info "     Verificações iniciais do sistema"
    info "══════════════════════════════════════════"

    if ! grep -qi "mint\|ubuntu\|debian" /etc/os-release 2>/dev/null; then
        warn "Distro não reconhecida. Este script foi feito para Linux Mint/Ubuntu."
    fi

    check_space 150 "$HOME"
    check_ram_and_swap
    success "Verificações concluídas."
}

# ETAPA 1: DEPENDÊNCIAS
step1_dependencies() {
    info "══════════════════════════════════════════"
    info "         Instalando dependências"
    info "══════════════════════════════════════════"

    confirm "Instalar pacotes de build agora?" || return 0

    sudo apt update

    sudo apt install -y \
        bc bison build-essential ccache curl flex \
        g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
        protobuf-compiler python3-protobuf \
        lib32readline-dev lib32z1-dev libdw-dev libelf-dev \
        libgnutls28-dev lz4 libsdl1.2-dev libssl-dev \
        libxml2 libxml2-utils lzop pngcrush rsync \
        schedtool squashfs-tools xsltproc zip zlib1g-dev \
        openjdk-11-jdk python-is-python3

    if dpkg -l | grep -q "libncurses5 " 2>/dev/null; then
        success "libncurses5 já instalado."
    else
        info "Tentando instalar libncurses5..."
        if apt-cache show libncurses5 &>/dev/null; then
            sudo apt install -y libncurses5 lib32ncurses5-dev libncurses5-dev
        else
            warn "libncurses5 não encontrado nos repos. Instalando manualmente..."
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb
            wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb
            sudo dpkg -i libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb
            rm -f libtinfo5_6.3-2_amd64.deb libncurses5_6.3-2_amd64.deb
        fi
    fi

    success "Dependências instaladas."
}

# ETAPA 2: CONFIGURAR AMBIENTE
step2_environment() {
    info "══════════════════════════════════════════"
    info "          Configurando ambiente"
    info "══════════════════════════════════════════"

    mkdir -p "$BIN_DIR" "$BUILD_DIR" "$BACKUP_DIR"

    if [ ! -f "$BIN_DIR/repo" ]; then
        info "Baixando repo tool..."
        curl -s https://storage.googleapis.com/git-repo-downloads/repo > "$BIN_DIR/repo"
        chmod a+x "$BIN_DIR/repo"
        success "repo instalado em $BIN_DIR/repo"
    else
        success "repo já existe."
    fi

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
    fi

    if [ "$GIT_EMAIL" = "you@example.com" ]; then
        warn "Git email padrão detectado. Edite o script e altere GIT_EMAIL e GIT_NAME!"
    fi
    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_NAME"
    git lfs install
    git config --global trailer.changeid.key "Change-Id"
    success "Git configurado."

    if ! grep -q "USE_CCACHE" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# ccache para builds Android
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR="$HOME/.ccache"
export NINJA_ARGS="-j2"
EOF
        source ~/.bashrc 2>/dev/null || true
        success "ccache adicionado ao .bashrc"
    fi

    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    ccache -M "$CCACHE_SIZE"
    ccache -o compression=true
    success "ccache configurado: ${CCACHE_SIZE} com compressão ativada."

    export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx2g"
    export _JAVA_OPTIONS="-Xmx4g -Xms512m"
    success "Java heap limitado a 4GB (seguro para 12GB RAM)."
}

# ETAPA 3: BAIXAR O SOURCE DA AXIONOS
step3_source() {
    info "══════════════════════════════════════════"
    info "        Baixando source da AxionOS"
    info "══════════════════════════════════════════"
    warn "Tenha paciência e conexão estável, isso pode demorar muito!"

    cd "$BUILD_DIR"

    if [ -d ".repo" ]; then
        warn "Repo já inicializado. Pulando init."
    else
        confirm "Inicializar repo da AxionOS agora?" || return 0
        "$BIN_DIR/repo" init \
            -u https://github.com/AxionAOSP/android.git \
            -b "$BRANCH_AXION" \
            --git-lfs \
            --no-clone-bundle
        success "Repo inicializado."
    fi

    confirm "Sincronizar source agora? (pode demorar HORAS)" || return 0
    "$BIN_DIR/repo" sync -j4 -c --no-tags --fail-fast
    success "Source sincronizado."
}

# ETAPA 4: CLONAR DEVICE TREES
step4_device_trees() {
    info "══════════════════════════════════════════"
    info "          Clonando device trees"
    info "══════════════════════════════════════════"

    cd "$BUILD_DIR"

    if [ ! -d "device/motorola/pstar" ]; then
        info "Clonando device tree (pstar)..."
        mkdir -p device/motorola
        git clone https://github.com/LineageOS/android_device_motorola_pstar.git \
            -b "$BRANCH_LINEAGE" \
            device/motorola/pstar
        success "Device tree clonado."
    else
        success "Device tree já existe."
    fi

    if [ ! -d "kernel/motorola/sm8250" ]; then
        info "Clonando kernel source..."
        mkdir -p kernel/motorola
        git clone https://github.com/LineageOS/android_kernel_motorola_sm8250 \
            kernel/motorola/sm8250
        success "Kernel clonado."
    else
        success "Kernel já existe."
    fi

    if [ ! -d "vendor/motorola/pstar" ]; then
        info "Clonando vendor blobs (pstar)..."
        mkdir -p vendor/motorola
        git clone https://github.com/TheMuppets/proprietary_vendor_motorola_pstar.git \
            -b "$BRANCH_LINEAGE" \
            vendor/motorola/pstar
        success "Vendor pstar clonado."
    else
        success "Vendor pstar já existe."
    fi
    
    rm -rf vendor/motorola/sm8250-common
    git clone https://github.com/TheMuppets/proprietary_vendor_motorola_sm8250-common.git \
        -b lineage-23.0 \
        vendor/motorola/sm8250-common
    cd vendor/motorola/sm8250-common
    git fetch --all --tags
    git checkout lineage-23.0
    cd "$BUILD_DIR"
    success "Vendor sm8250-common clonado/checkout lineage-23.0 (libtinyxml2-v34 OK)."

    # Verificação automática (pra debug futuro)
    local current_branch
    current_branch=$(git -C vendor/motorola/sm8250-common rev-parse --abbrev-ref HEAD 2>/dev/null || echo "erro")
    if [ "$current_branch" = "lineage-23.0" ] && grep -q "libtinyxml2-v34" vendor/motorola/sm8250-common/Android.bp 2>/dev/null; then
        success "Vendor sm8250-common OK: branch $current_branch + libtinyxml2-v34 ✅"
    else
        error "Vendor sm8250-common falhou: branch '$current_branch' ou sem libtinyxml2-v34!"
    fi

    success "Todos os device trees prontos."
}

# ETAPA 5: APLICAR PATCHES DA AXIONOS NO DEVICE TREE
step5_axion_patches() {
    info "══════════════════════════════════════════"
    info "      Aplicando configurações AxionOS"
    info "══════════════════════════════════════════"

    local device_mk="$BUILD_DIR/device/motorola/pstar/device.mk"
    local lineage_products="$BUILD_DIR/device/motorola/pstar/lineage_pstar.mk"

    if grep -q "AxionOS" "$device_mk" 2>/dev/null; then
        warn "Patches AxionOS já aplicados. Pulando."
        return 0
    fi

    cp "$device_mk" "${device_mk}.bak"
    info "Backup criado: ${device_mk}.bak"

    cat >> "$device_mk" << 'EOF'

# ─── AxionOS Configuration ───────────────────────────────────────────────────
# AxionOS unofficial build for Motorola Edge 20 Pro (pstar)
# Pré-aplicado automaticamente pelo script axion_pstar.sh

TARGET_DISABLE_EPPE := true

# Device info para "Sobre o telefone" da AxionOS
AXION_CAMERA_REAR_INFO := 108,16,8
AXION_CAMERA_FRONT_INFO := 32
AXION_MAINTAINER := B9R7M (@BNRSM)
AXION_PROCESSOR := Qualcomm Snapdragon™ 870

# Performance — SM8250 suporta schedutil
PERF_GOV_SUPPORTED := true
PERF_DEFAULT_GOV := schedutil
PERF_ANIM_OVERRIDE := true

# Flashlight com ajuste de intensidade (Teste)
TORCH_STR_SUPPORTED := true

# Refresh rates do Edge 20 Pro (144Hz)
TARGET_SUPPORTED_REFRESH_RATES := 45,60,90,120,144

# RAM 6GB/8GB/12GB
TARGET_IS_LOW_RAM := false

# Bypass charging (verifique o path real no seu kernel)
BYPASS_CHARGE_SUPPORTED := true
BYPASS_CHARGE_TOGGLE_PATH := /sys/class/power_supply/qcom_battery/input_suspend

# HBM
HBM_SUPPORTED := true
HBM_NODE := /sys/devices/platform/soc/soc:qcom,dsi-display-primary/hbm

# ScrollOptimizer
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.perf.scroll_opt=true \
    persist.sys.perf.scroll_opt.heavy_app=1
EOF

    if [ -f "$lineage_products" ]; then
        cp "$lineage_products" "${lineage_products}.bak"
        sed -i 's|$(call inherit-product, vendor/lineage/config/common_full_phone.mk)|# LineageOS replaced by AxionOS\n$(call inherit-product, vendor/lineage/config/common_full_phone.mk)|' \
            "$lineage_products"
        echo -e "\n# AxionOS extras\nTARGET_ENABLE_BLUR := true" >> "$lineage_products"
    fi

    success "Patches AxionOS aplicados."
    warn "ATENÇÃO: Verifique manualmente os paths de HBM e Bypass Charging se quiser habilitá-los."
}

# ETAPA 6: COMPILAR
step6_build() {
    info "══════════════════════════════════════════"
    info "      Compilando AxionOS para pstar"
    info "══════════════════════════════════════════"

    # Seleciona variante antes de começar
    select_variant

    local axion_variant_arg
    axion_variant_arg=$(get_axion_variant_arg)

    echo ""
    echo -e "  Dispositivo : ${GREEN}$DEVICE${NC}"
    echo -e "  Variante    : ${GREEN}$BUILD_VARIANT${NC}  →  argumento: '${axion_variant_arg}'"
    echo -e "  Threads     : ${GREEN}$JOBS${NC}"
    echo ""
    warn "Estimativa de tempo no seu hardware: 8-16 horas (ou mais)."
    confirm "Iniciar compilação agora?" || return 0

    cd "$BUILD_DIR"

    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache
    export CCACHE_COMPRESSION=1
    export NINJA_ARGS="-j${JOBS}"
    export _JAVA_OPTIONS="-Xmx4g -Xms512m"
    export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx2g"
    export PRODUCT_DEX_PREOPT_BOOT_FLAGS="--num-threads=2"

    source build/envsetup.sh

    # Gerar chaves privadas (só precisa fazer uma vez)
    # Usa openssl diretamente — evita o bug do 'gk' que tenta criar
    # diretório com path vazio quando $ANDROID_BUILD_TOP não está exportado
    local CERT_DIR="$BUILD_DIR/certs"
    if [ ! -d "$CERT_DIR" ]; then
        info "Gerando chaves privadas em: $CERT_DIR"
        mkdir -p "$CERT_DIR"
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
            rm "${cert}.pem"  # .pem intermediário não é necessário após gerar .pk8
        done

        cd "$BUILD_DIR"
        success "Chaves geradas em: $CERT_DIR"
        info "Arquivos criados:"
        ls -lh "$CERT_DIR"
    else
        success "Chaves já existem em $CERT_DIR — pulando geração."
    fi

    # Configurar device com variante selecionada
    info "Configurando build: $DEVICE | $axion_variant_arg"
    if command -v axion &>/dev/null; then
        # shellcheck disable=SC2086
        axion "$DEVICE" $axion_variant_arg
    else
        warn "Comando 'axion' não encontrado. Usando breakfast como fallback..."
        breakfast "$DEVICE"
    fi

    # Compilar
    info "Iniciando compilação com $JOBS threads..."
    info "Log em: $BUILD_DIR/build_${BUILD_VARIANT}.log"

    if command -v ax &>/dev/null; then
        ax -br -j${JOBS} 2>&1 | tee "$BUILD_DIR/build_${BUILD_VARIANT}.log"
    else
        warn "Comando 'ax' não encontrado. Usando brunch como fallback..."
        brunch "$DEVICE" 2>&1 | tee "$BUILD_DIR/build_${BUILD_VARIANT}.log"
    fi

    echo ""
    success "════════════════════════════════════════════"
    success " Build concluída! Variante: $BUILD_VARIANT"
    success "════════════════════════════════════════════"
    info "Arquivos em: $BUILD_DIR/out/target/product/$DEVICE/"
    ls -lh "$BUILD_DIR/out/target/product/$DEVICE/"*.zip 2>/dev/null || \
        warn "Nenhum .zip encontrado — verifique: build_${BUILD_VARIANT}.log"
}

# DIAGNÓSTICO — Verifica branches de todos os repositórios clonado
step_diagnose() {
    info "══════════════════════════════════════════════════"
    info "      Verificando branches dos repositórios"
    info "══════════════════════════════════════════════════"

    # Mapa de repositório → branch esperada
    declare -A expected_branches=(
        ["device/motorola/pstar"]="lineage-23.2"
        ["kernel/motorola/sm8250"]="lineage-23.2"   # kernel geralmente não tem branch fixa
        ["vendor/motorola/pstar"]="lineage-23.2"
        ["vendor/motorola/sm8250-common"]="lineage-23.0"
    )

    local all_ok=true

    for rel_path in "${!expected_branches[@]}"; do
        local full_path="$BUILD_DIR/$rel_path"
        local expected="${expected_branches[$rel_path]}"

        if [ ! -d "$full_path" ]; then
            warn "  NÃO ENCONTRADO : $rel_path"
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
        fi
    done

    echo ""
    if $all_ok; then
        success "Todos os repositórios estão nas branches corretas."
    else
        warn "Um ou mais repositórios estão com branch incorreta."
        warn "Branches erradas causam erros de soong bootstrap como o 'libtinyxml2-v34'."
        echo ""
        info "Para corrigir o sm8250-common manualmente:"
        echo "  cd $BUILD_DIR/vendor/motorola/sm8250-common"
        echo "  git fetch origin lineage-23.0"
        echo "  git checkout lineage-23.0"
    fi
}

# MENU:
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   AxionOS Unofficial — Motorola Edge 20 Pro (pstar)  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Branch AxionOS  : $BRANCH_AXION"
    echo -e "  Branch DevTree  : $BRANCH_LINEAGE"
    echo -e "  Diretório build : $BUILD_DIR"
    echo -e "  Diretório backup: $BACKUP_DIR"
    echo -e "  Threads         : $JOBS  (otimizado pra baixa RAM)"
    echo -e "  Variante atual  : ${GREEN}$BUILD_VARIANT${NC}"
    echo ""
    echo "  ── Setup (primeira vez) ──────────────────────────────"
    echo "  [0] Tudo do zero (setup completo + compilar)"
    echo "  [1] Verificações iniciais do sistema"
    echo "  [2] Instalar dependências"
    echo "  [3] Configurar ambiente (repo, git, ccache)"
    echo "  [4] Baixar source da AxionOS"
    echo "  [5] Clonar device trees (device/kernel/vendor)"
    echo "  [6] Aplicar patches AxionOS no device tree"
    echo ""
    echo "  ── Build ─────────────────────────────────────────────"
    echo "  [7] Compilar (pergunta a variante antes)"
    echo "  [v] Só mudar variante de build"
    echo ""
    echo "  ── Backup & Sync ─────────────────────────────────────"
    echo "  [b] Fazer backup das configs customizadas"
    echo "  [r] Restaurar backup (escolhe qual)"
    echo "  [s] Sync seguro (backup → sync → restore automático)"
    echo ""
    echo "  ── Diagnóstico ───────────────────────────────────────"
    echo "  [d] Verificar branches de todos os repositórios"
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
            step5_axion_patches
            step6_build
            ;;
        1) step0_checks ;;
        2) step1_dependencies ;;
        3) step2_environment ;;
        4) step3_source ;;
        5) step4_device_trees ;;
        6) step5_axion_patches ;;
        7) step6_build ;;
        v|V) select_variant; main ;;
        b|B) step_backup_save ;;
        r|R) step_backup_restore ;;
        s|S) step_sync_safe ;;
        d|D) step_diagnose ;;
        q|Q) info "Saindo."; exit 0 ;;
        *) warn "Opção inválida."; main ;;
    esac
}

# Entrada:
main
