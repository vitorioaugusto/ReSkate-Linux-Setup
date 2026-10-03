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
warn(){ printf '\nWARNING: %s\n' "$*" >&2; }
die(){ printf '\nERROR: %s\n' "$*" >&2; exit 1; }

usage(){
cat <<'EOF'
Usage:
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
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [[ "$MODE" == "auto" ]]; then
  echo
  echo "============================================================"
  echo " ReSkate Linux Setup"
  echo "============================================================"
  echo
  echo "  1) Install / repair the configuration"
  echo "  2) Reinstall the Wine prefix from scratch"
  echo "  3) Create a backup only"
  echo "  4) Recreate only the launcher and shortcuts"
  echo "  5) Exit"
  echo
  read -r -p "Enter a number (default=1): " choice
  case "${choice:-1}" in
    1) MODE="repair" ;;
    2) MODE="reinstall" ;;
    3) MODE="backup-only" ;;
    4) MODE="launcher-only" ;;
    5) exit 0 ;;
    *) die "Invalid option." ;;
  esac
fi

cleanup(){
  [[ -n "${TMPDIR_RES:-}" && -d "${TMPDIR_RES:-}" ]] && rm -rf "$TMPDIR_RES"
}
trap cleanup EXIT

[[ "$(uname -m)" == "x86_64" ]] || die "This setup supports Linux x86_64 only."

discover_game_dirs(){
  local -a steam_roots=()
  local -a found=()
  local vdf root line path candidate existing

  steam_roots+=(
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
  )

  for root in "${steam_roots[@]}"; do
    candidate="$root/steamapps/common/Skate"
    if [[ -f "$candidate/Skate.exe" ]]; then
      found+=("$candidate")
    fi

    vdf="$root/steamapps/libraryfolders.vdf"
    [[ -f "$vdf" ]] || continue

    while IFS= read -r line; do
      if [[ "$line" =~ \"path\"[[:space:]]+\"([^\"]+)\" ]]; then
        path="${BASH_REMATCH[1]}"
        candidate="$path/steamapps/common/Skate"
        [[ -f "$candidate/Skate.exe" ]] && found+=("$candidate")
      fi
    done < "$vdf"
  done

  for candidate in "${found[@]}"; do
    existing=0
    for path in "${GAME_CANDIDATES[@]:-}"; do
      [[ "$path" == "$candidate" ]] && existing=1 && break
    done
    (( existing == 0 )) && GAME_CANDIDATES+=("$candidate")
  done
}

normalize_game_dir(){
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"

  if [[ "$value" == "~" ]]; then
    value="$HOME"
  elif [[ "$value" == "~/"* ]]; then
    value="$HOME/${value#~/}"
  fi

  if [[ -f "$value" && "$(basename "$value")" == "Skate.exe" ]]; then
    value="$(dirname "$value")"
  fi

  value="${value%/}"
  printf '%s\n' "$value"
}

validate_game_dir(){
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/Skate.exe" ]] || return 1
  [[ -f "$dir/ReSkateLauncher.exe" ]] || return 2
  return 0
}

choose_game_dir(){
  local answer status i
  GAME_CANDIDATES=()
  discover_game_dirs

  echo
  echo "============================================================"
  echo " skate. installation location"
  echo "============================================================"
  echo
  echo "Before continuing, confirm where the game is installed."
  echo "This is important if you use another Steam library or a different SSD."
  echo

  if (( ${#GAME_CANDIDATES[@]} > 0 )); then
    echo "Detected installations:"
    for i in "${!GAME_CANDIDATES[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "${GAME_CANDIDATES[$i]}"
    done
    echo
    echo "Enter the installation number or paste a custom path."
    read -r -p "Game location (default=1): " answer
    answer="${answer:-1}"

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#GAME_CANDIDATES[@]} )); then
      GAME_DIR="${GAME_CANDIDATES[$((answer - 1))]}"
    else
      GAME_DIR="$(normalize_game_dir "$answer")"
    fi
  else
    echo "No valid installation was detected automatically."
    echo "In Steam, open: Library → skate. → Manage → Browse local files"
    echo "Then paste below the path to the folder that contains Skate.exe."
    echo
    read -r -p "skate. folder: " answer
    GAME_DIR="$(normalize_game_dir "$answer")"
  fi

  while true; do
    if validate_game_dir "$GAME_DIR"; then
      status=0
    else
      status=$?
    fi

    if (( status == 0 )); then
      echo
      echo "Game confirmed at:"
      echo "  $GAME_DIR"
      echo
      return
    fi

    echo
    if (( status == 2 )); then
      warn "Skate.exe was found, but ReSkateLauncher.exe is not in this folder."
      echo "Extract the ReSkate files into the same folder as Skate.exe before continuing."
    else
      warn "Skate.exe was not found in: $GAME_DIR"
    fi

    read -r -p "Enter another path or 'q' to quit: " answer
    [[ "$answer" == "q" || "$answer" == "Q" ]] && exit 1
    GAME_DIR="$(normalize_game_dir "$answer")"
  done
}

if [[ -n "$GAME_DIR" ]]; then
  GAME_DIR="$(normalize_game_dir "$GAME_DIR")"
  validate_game_dir "$GAME_DIR" || die "Invalid GAME_DIR or missing ReSkate files: $GAME_DIR"
elif [[ -t 0 && -t 1 ]]; then
  choose_game_dir
else
  GAME_CANDIDATES=()
  discover_game_dirs
  if (( ${#GAME_CANDIDATES[@]} == 1 )); then
    GAME_DIR="${GAME_CANDIDATES[0]}"
  elif (( ${#GAME_CANDIDATES[@]} > 1 )); then
    die "Multiple skate. installations were found. Set GAME_DIR=/path/to/Skate."
  else
    die "skate. was not found. Set GAME_DIR=/path/to/Skate."
  fi
fi

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
    command -v tar >/dev/null || die "tar is required for backups."
    command -v zstd >/dev/null || die "zstd is required for backups."
    parent="$(dirname "$PREFIX")"
    name="$(basename "$PREFIX")"
    tar -C "$parent" -cf - "$name" | zstd -T0 -3 -q -o "$dir/prefix.tar.zst"
    [[ -s "$dir/prefix.tar.zst" ]] || die "Failed to create backup."
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
Comment=Skate offline via ReSkate and Wine
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

  echo "Launcher created at $HOME/.local/bin/reskate"
}

if [[ "$MODE" == "launcher-only" ]]; then
  (( PREFIX_EXISTS )) || die "Wine prefix not found at $PREFIX"
  create_launcher
  exit 0
fi

if [[ "$MODE" == "backup-only" ]]; then
  dir="$(make_backup)"
  echo "Backup created at: $dir"
  exit 0
fi

if (( PREFIX_EXISTS )); then
  dir="$(make_backup)"
  echo "Backup created at: $dir"
fi

if [[ "$MODE" == "reinstall" && "$PREFIX_EXISTS" -eq 1 ]]; then
  WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  [[ "$PREFIX" == "$HOME/"* ]] || die "Refusing to remove a Wine prefix outside HOME."
  rm -rf -- "$PREFIX"
fi

if command -v pacman >/dev/null 2>&1; then
  log "Installing/checking dependencies on Arch"
  sudo pacman -S --needed wine-staging curl tar zstd pciutils vulkan-icd-loader lib32-vulkan-icd-loader
  detect_gpu
  [[ "$GPU_VENDOR" == "nvidia" && -x "$(command -v nvidia-smi || true)" ]] && sudo pacman -S --needed nvidia-utils lib32-nvidia-utils || true
  [[ "$GPU_VENDOR" == "amd" ]] && sudo pacman -S --needed vulkan-radeon lib32-vulkan-radeon || true
  [[ "$GPU_VENDOR" == "intel" ]] && sudo pacman -S --needed vulkan-intel lib32-vulkan-intel || true
else
  warn "Non-Arch distribution: install Wine, curl, tar, zstd, and 64/32-bit Vulkan support manually."
fi

for cmd in wine wineboot wineserver curl tar zstd; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
done

detect_gpu
echo "Detected GPU: $GPU_VENDOR ${GPU_MODEL:+($GPU_MODEL)}"

mkdir -p "$PREFIX"
if [[ ! -f "$PREFIX/system.reg" ]]; then
  WINEPREFIX="$PREFIX" WINEARCH=win64 wineboot -u
else
  WINEPREFIX="$PREFIX" wineboot -u
fi
WINEPREFIX="$PREFIX" wineserver -w || true

SYSTEM32="$PREFIX/drive_c/windows/system32"
SYSWOW64="$PREFIX/drive_c/windows/syswow64"
[[ -f "$SYSTEM32/dbghelp.dll" ]] || die "dbghelp.dll was not found."

MINIDUMP_API="$SYSTEM32/api-ms-win-core-debug-minidump-l1-1-0.dll"
[[ -e "$MINIDUMP_API" ]] || ln -s dbghelp.dll "$MINIDUMP_API"

TMPDIR_RES="$(mktemp -d)"

log "Installing VKD3D-Proton $VKD3D_VERSION"
curl -fL --retry 3 -o "$TMPDIR_RES/vkd3d.tar.zst"   "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v${VKD3D_VERSION}/vkd3d-proton-${VKD3D_VERSION}.tar.zst"
tar -xf "$TMPDIR_RES/vkd3d.tar.zst" -C "$TMPDIR_RES"
VKD3D_SETUP="$(find "$TMPDIR_RES" -type f -name setup_vkd3d_proton.sh -print -quit)"
[[ -n "$VKD3D_SETUP" ]] || die "VKD3D-Proton installer was not found."
chmod +x "$VKD3D_SETUP"
WINEPREFIX="$PREFIX" "$VKD3D_SETUP" install

log "Installing DXVK $DXVK_VERSION (DXGI)"
curl -fL --retry 3 -o "$TMPDIR_RES/dxvk.tar.gz"   "https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"
tar -xzf "$TMPDIR_RES/dxvk.tar.gz" -C "$TMPDIR_RES"
DXGI64="$(find "$TMPDIR_RES" -type f -path '*/x64/dxgi.dll' -print -quit)"
DXGI32="$(find "$TMPDIR_RES" -type f -path '*/x32/dxgi.dll' -print -quit)"
cp -f "$DXGI64" "$SYSTEM32/dxgi.dll"
cp -f "$DXGI32" "$SYSWOW64/dxgi.dll"
WINEPREFIX="$PREFIX" wine reg add 'HKCU\Software\Wine\DllOverrides' /v dxgi /d 'native,builtin' /f >/dev/null

if (( DLSS_CAPABLE )); then
  log "Configuring DXVK-NVAPI $NVAPI_VERSION and NVIDIA NGX"
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

  [[ -n "$NVIDIA_WINE_DIR" ]] || die "An RTX GPU was detected, but nvngx.dll/_nvngx.dll were not found."

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
  log "GPU without DLSS support: skipping NVIDIA/NGX configuration"
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
echo " ReSkate configured successfully"
echo "============================================================"
echo "Game:     $GAME_DIR"
echo "Prefix:   $PREFIX"
echo "Wine:    $(wine --version)"
echo "VKD3D:   $VKD3D_VERSION"
echo "DXVK:    $DXVK_VERSION"
(( DLSS_CAPABLE )) && echo "DLSS SR: configured" || echo "DLSS SR: not enabled"
echo "Launcher: $HOME/.local/bin/reskate"
