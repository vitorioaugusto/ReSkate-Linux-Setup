#!/usr/bin/env bash
set -Eeuo pipefail

VKD3D_VERSION="${VKD3D_VERSION:-3.0.1}"
DXVK_VERSION="${DXVK_VERSION:-3.1}"
NVAPI_VERSION="${NVAPI_VERSION:-0.9.2}"

PREFIX="${RESKATE_PREFIX:-$HOME/.local/share/wineprefixes/reskate-test}"
BACKUP_ROOT="${RESKATE_BACKUP_ROOT:-$HOME/ReSkate-backups}"
GAME_DIR="${GAME_DIR:-}"
MODE="auto"

log(){ printf '\n==> %s\n' "$*"; }
warn(){ printf '\nAVISO: %s\n' "$*" >&2; }
die(){ printf '\nERRO: %s\n' "$*" >&2; exit 1; }

usage(){
cat <<'EOF'
Uso:
  reskate-setup.sh
  reskate-setup.sh --backup-only
  reskate-setup.sh --repair
  reskate-setup.sh --reinstall
  reskate-setup.sh --launcher-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup-only) MODE="backup-only" ;;
    --repair) MODE="repair" ;;
    --reinstall) MODE="reinstall" ;;
    --launcher-only) MODE="launcher-only" ;;
    --help|-h) usage; exit 0 ;;
    *) die "Opção desconhecida: $1" ;;
  esac
  shift
done

if [[ "$MODE" == "auto" ]]; then
  echo
  echo "============================================================"
  echo " ReSkate Linux Setup"
  echo "============================================================"
  echo
  echo "  1) Instalar / reparar a configuração"
  echo "  2) Reinstalar o prefixo do zero"
  echo "  3) Fazer apenas um backup"
  echo "  4) Criar/recriar apenas o launcher e os atalhos"
  echo "  5) Sair"
  echo
  read -r -p "Digite um número (padrão=1): " choice
  case "${choice:-1}" in
    1) MODE="repair" ;;
    2) MODE="reinstall" ;;
    3) MODE="backup-only" ;;
    4) MODE="launcher-only" ;;
    5) exit 0 ;;
    *) die "Opção inválida." ;;
  esac
fi

cleanup(){
  [[ -n "${TMPDIR_RES:-}" && -d "${TMPDIR_RES:-}" ]] && rm -rf "$TMPDIR_RES"
}
trap cleanup EXIT

[[ "$(uname -m)" == "x86_64" ]] || die "Este setup suporta Linux x86_64."

if [[ -z "$GAME_DIR" ]]; then
  for candidate in     "$HOME/.local/share/Steam/steamapps/common/Skate"     "$HOME/.steam/steam/steamapps/common/Skate"     "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Skate"
  do
    [[ -f "$candidate/Skate.exe" ]] && GAME_DIR="$candidate" && break
  done
fi

[[ -n "$GAME_DIR" ]] || die "Skate não encontrado. Defina GAME_DIR=/caminho/para/Skate."
[[ -f "$GAME_DIR/Skate.exe" ]] || die "Skate.exe não encontrado em $GAME_DIR"
[[ -f "$GAME_DIR/ReSkateLauncher.exe" ]] || die "ReSkateLauncher.exe não encontrado em $GAME_DIR"

PREFIX_EXISTS=0
[[ -f "$PREFIX/system.reg" && -d "$PREFIX/drive_c" ]] && PREFIX_EXISTS=1

GPU_VENDOR="unknown"
GPU_MODEL=""
DLSS_CAPABLE=0

detect_gpu(){
  GPU_VENDOR="unknown"; GPU_MODEL=""; DLSS_CAPABLE=0

  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_MODEL="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
    if [[ -n "$GPU_MODEL" ]]; then
      GPU_VENDOR="nvidia"
      grep -qi RTX <<<"$GPU_MODEL" && DLSS_CAPABLE=1
      return
    fi
  fi

  if command -v lspci >/dev/null 2>&1; then
    local lines
    lines="$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)"
    grep -qi NVIDIA <<<"$lines" && GPU_VENDOR="nvidia"
    grep -Eqi 'AMD|ATI' <<<"$lines" && GPU_VENDOR="amd"
    grep -qi Intel <<<"$lines" && GPU_VENDOR="intel"
  fi
}

detect_gpu

make_backup(){
  mkdir -p "$BACKUP_ROOT"
  local stamp dir parent name
  stamp="$(date '+%Y%m%d-%H%M%S')"
  dir="$BACKUP_ROOT/$stamp"
  mkdir -p "$dir/launcher" "$dir/game-files"

  {
    echo "ReSkate Linux backup"
    echo "GAME_DIR=$GAME_DIR"
    echo "PREFIX=$PREFIX"
    echo "GPU_VENDOR=$GPU_VENDOR"
    echo "GPU_MODEL=$GPU_MODEL"
  } > "$dir/info.txt"

  if (( PREFIX_EXISTS )); then
    command -v tar >/dev/null || die "tar é necessário para backup."
    command -v zstd >/dev/null || die "zstd é necessário para backup."
    parent="$(dirname "$PREFIX")"
    name="$(basename "$PREFIX")"
    tar -C "$parent" -cf - "$name" | zstd -T0 -3 -q -o "$dir/prefix.tar.zst"
    [[ -s "$dir/prefix.tar.zst" ]] || die "Falha ao criar backup."
  fi

  [[ -f "$HOME/.local/bin/reskate" ]] && cp -a "$HOME/.local/bin/reskate" "$dir/launcher/" || true
  [[ -f "$HOME/.local/share/applications/reskate.desktop" ]] && cp -a "$HOME/.local/share/applications/reskate.desktop" "$dir/launcher/" || true
  for f in nvngx.dll _nvngx.dll; do
    [[ -e "$GAME_DIR/$f" ]] && cp -aL "$GAME_DIR/$f" "$dir/game-files/$f" || true
  done

  printf '%s\n' "$dir"
}

create_launcher(){
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

  cat > "$HOME/.local/bin/reskate" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export WINEPREFIX="$PREFIX"

if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME="\$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
  if grep -qi RTX <<<"\$GPU_NAME"; then
    export DXVK_ENABLE_NVAPI=1
    export DXVK_NVAPI_DRS_SETTINGS="0x10E41E06=1,0x10E41E01=1,0x10E41DF3=0x00ffffff"
  fi
fi

cd "$GAME_DIR"
exec wine ./ReSkateLauncher.exe --offline --no-update --no-gui --log-level=info
EOF
  chmod +x "$HOME/.local/bin/reskate"

  cat > "$HOME/.local/share/applications/reskate.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ReSkate
Comment=Skate offline via ReSkate e Wine
Exec=$HOME/.local/bin/reskate
Icon=applications-games
Terminal=false
Categories=Game;
StartupNotify=true
EOF
  chmod +x "$HOME/.local/share/applications/reskate.desktop"

  local desktop=""
  command -v xdg-user-dir >/dev/null 2>&1 && desktop="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  [[ -n "$desktop" ]] || desktop="$HOME/Desktop"
  [[ -d "$desktop" ]] && cp -f "$HOME/.local/share/applications/reskate.desktop" "$desktop/ReSkate.desktop" || true

  echo "Launcher criado em $HOME/.local/bin/reskate"
}

if [[ "$MODE" == "launcher-only" ]]; then
  (( PREFIX_EXISTS )) || die "Prefixo não encontrado em $PREFIX"
  create_launcher
  exit 0
fi

if [[ "$MODE" == "backup-only" ]]; then
  dir="$(make_backup)"
  echo "Backup criado em: $dir"
  exit 0
fi

if (( PREFIX_EXISTS )); then
  dir="$(make_backup)"
  echo "Backup criado em: $dir"
fi

if [[ "$MODE" == "reinstall" && "$PREFIX_EXISTS" -eq 1 ]]; then
  WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  [[ "$PREFIX" == "$HOME/"* ]] || die "Recusando remover prefixo fora da HOME."
  rm -rf -- "$PREFIX"
fi

if command -v pacman >/dev/null 2>&1; then
  log "Instalando/verificando dependências no Arch"
  sudo pacman -S --needed wine-staging curl tar zstd pciutils vulkan-icd-loader lib32-vulkan-icd-loader
  detect_gpu
  [[ "$GPU_VENDOR" == "nvidia" && -x "$(command -v nvidia-smi || true)" ]] && sudo pacman -S --needed nvidia-utils lib32-nvidia-utils || true
  [[ "$GPU_VENDOR" == "amd" ]] && sudo pacman -S --needed vulkan-radeon lib32-vulkan-radeon || true
  [[ "$GPU_VENDOR" == "intel" ]] && sudo pacman -S --needed vulkan-intel lib32-vulkan-intel || true
else
  warn "Distro não-Arch: instale Wine, curl, tar, zstd e Vulkan 64/32-bit manualmente."
fi

for cmd in wine wineboot wineserver curl tar zstd; do
  command -v "$cmd" >/dev/null 2>&1 || die "Comando ausente: $cmd"
done

detect_gpu
echo "GPU detectada: $GPU_VENDOR ${GPU_MODEL:+($GPU_MODEL)}"

mkdir -p "$PREFIX"
if [[ ! -f "$PREFIX/system.reg" ]]; then
  WINEPREFIX="$PREFIX" WINEARCH=win64 wineboot -u
else
  WINEPREFIX="$PREFIX" wineboot -u
fi
WINEPREFIX="$PREFIX" wineserver -w || true

SYSTEM32="$PREFIX/drive_c/windows/system32"
SYSWOW64="$PREFIX/drive_c/windows/syswow64"
[[ -f "$SYSTEM32/dbghelp.dll" ]] || die "dbghelp.dll não encontrado."

MINIDUMP_API="$SYSTEM32/api-ms-win-core-debug-minidump-l1-1-0.dll"
[[ -e "$MINIDUMP_API" ]] || ln -s dbghelp.dll "$MINIDUMP_API"

TMPDIR_RES="$(mktemp -d)"

log "Instalando VKD3D-Proton $VKD3D_VERSION"
curl -fL --retry 3 -o "$TMPDIR_RES/vkd3d.tar.zst"   "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v${VKD3D_VERSION}/vkd3d-proton-${VKD3D_VERSION}.tar.zst"
tar -xf "$TMPDIR_RES/vkd3d.tar.zst" -C "$TMPDIR_RES"
VKD3D_SETUP="$(find "$TMPDIR_RES" -type f -name setup_vkd3d_proton.sh -print -quit)"
[[ -n "$VKD3D_SETUP" ]] || die "Instalador VKD3D-Proton não encontrado."
chmod +x "$VKD3D_SETUP"
WINEPREFIX="$PREFIX" "$VKD3D_SETUP" install

log "Instalando DXVK $DXVK_VERSION (DXGI)"
curl -fL --retry 3 -o "$TMPDIR_RES/dxvk.tar.gz"   "https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"
tar -xzf "$TMPDIR_RES/dxvk.tar.gz" -C "$TMPDIR_RES"
DXGI64="$(find "$TMPDIR_RES" -type f -path '*/x64/dxgi.dll' -print -quit)"
DXGI32="$(find "$TMPDIR_RES" -type f -path '*/x32/dxgi.dll' -print -quit)"
cp -f "$DXGI64" "$SYSTEM32/dxgi.dll"
cp -f "$DXGI32" "$SYSWOW64/dxgi.dll"
WINEPREFIX="$PREFIX" wine reg add 'HKCU\Software\Wine\DllOverrides' /v dxgi /d 'native,builtin' /f >/dev/null

if (( DLSS_CAPABLE )); then
  log "Configurando DXVK-NVAPI $NVAPI_VERSION e NVIDIA NGX"
  curl -fL --retry 3 -o "$TMPDIR_RES/nvapi.tar.gz"     "https://github.com/jp7677/dxvk-nvapi/releases/download/v${NVAPI_VERSION}/dxvk-nvapi-v${NVAPI_VERSION}.tar.gz"
  mkdir -p "$TMPDIR_RES/nvapi"
  tar -xzf "$TMPDIR_RES/nvapi.tar.gz" -C "$TMPDIR_RES/nvapi"

  NVAPI64="$(find "$TMPDIR_RES/nvapi" -type f -path '*/x64/nvapi64.dll' -print -quit)"
  NVOF64="$(find "$TMPDIR_RES/nvapi" -type f -path '*/x64/nvofapi64.dll' -print -quit)"
  NVAPI32="$(find "$TMPDIR_RES/nvapi" -type f -path '*/x32/nvapi.dll' -print -quit || true)"
  NVOF32="$(find "$TMPDIR_RES/nvapi" -type f -path '*/x32/nvofapi.dll' -print -quit || true)"

  cp -f "$NVAPI64" "$SYSTEM32/nvapi64.dll"
  cp -f "$NVOF64" "$SYSTEM32/nvofapi64.dll"
  [[ -n "$NVAPI32" ]] && cp -f "$NVAPI32" "$SYSWOW64/nvapi.dll"
  [[ -n "$NVOF32" ]] && cp -f "$NVOF32" "$SYSWOW64/nvofapi.dll"

  for value in nvapi nvapi64 nvofapi64; do
    WINEPREFIX="$PREFIX" wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$value" /d 'native,builtin' /f >/dev/null
  done

  NVIDIA_WINE_DIR="${NVIDIA_WINE_DIR:-}"
  if [[ -z "$NVIDIA_WINE_DIR" ]]; then
    for candidate in /usr/lib/nvidia/wine /usr/lib64/nvidia/wine /usr/lib/x86_64-linux-gnu/nvidia/wine /run/opengl-driver/lib/nvidia/wine; do
      if [[ -f "$candidate/nvngx.dll" && -f "$candidate/_nvngx.dll" ]]; then
        NVIDIA_WINE_DIR="$candidate"
        break
      fi
    done
  fi

  [[ -n "$NVIDIA_WINE_DIR" ]] || die "RTX detectada, mas nvngx.dll/_nvngx.dll não foram encontrados."

  cp -f "$NVIDIA_WINE_DIR/nvngx.dll" "$SYSTEM32/nvngx.dll"
  cp -f "$NVIDIA_WINE_DIR/_nvngx.dll" "$SYSTEM32/_nvngx.dll"
  cp -f "$NVIDIA_WINE_DIR/nvngx.dll" "$GAME_DIR/nvngx.dll"
  cp -f "$NVIDIA_WINE_DIR/_nvngx.dll" "$GAME_DIR/_nvngx.dll"

  WINEPREFIX="$PREFIX" wine reg add 'HKCU\Software\Wine\DllOverrides' /v nvngx /d 'native,builtin' /f >/dev/null
  WINEPREFIX="$PREFIX" wine reg add 'HKCU\Software\Wine\DllOverrides' /v _nvngx /d 'native,builtin' /f >/dev/null
  WINEPREFIX="$PREFIX" wine reg delete 'HKCU\Software\Wine\DllOverrides' /v nvcuda /f >/dev/null 2>&1 || true

  WINEPREFIX="$PREFIX" wine reg add 'HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore'     /v FullPath /t REG_SZ /d 'C:\Windows\System32' /f /reg:64 >/dev/null
  WINEPREFIX="$PREFIX" wine reg add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\NGXCore'     /v NGXPath /t REG_SZ /d 'C:\Windows\System32' /f /reg:64 >/dev/null
  WINEPREFIX="$PREFIX" wine reg add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\NGXCore'     /v NGXPath /t REG_SZ /d 'C:\Windows\System32' /f /reg:64 >/dev/null
else
  log "GPU sem DLSS: configuração NVIDIA/NGX ignorada"
fi

cat > "$PREFIX/.reskate-linux-setup" <<EOF
installed_at=$(date --iso-8601=seconds 2>/dev/null || date)
game_dir=$GAME_DIR
vkd3d=$VKD3D_VERSION
dxvk=$DXVK_VERSION
dxvk_nvapi=$([[ "$DLSS_CAPABLE" -eq 1 ]] && echo "$NVAPI_VERSION" || echo disabled)
gpu_vendor=$GPU_VENDOR
gpu_model=$GPU_MODEL
EOF

create_launcher

echo
echo "============================================================"
echo " ReSkate configurado com sucesso"
echo "============================================================"
echo "Jogo:    $GAME_DIR"
echo "Prefixo: $PREFIX"
echo "Wine:    $(wine --version)"
echo "VKD3D:   $VKD3D_VERSION"
echo "DXVK:    $DXVK_VERSION"
(( DLSS_CAPABLE )) && echo "DLSS SR: configurado" || echo "DLSS SR: não ativado"
echo "Launcher: $HOME/.local/bin/reskate"
