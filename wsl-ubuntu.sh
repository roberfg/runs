#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[abort] linea $LINENO" >&2; exit 1' ERR

DOTFILES_REPO="https://github.com/roberfu/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
PACKAGES=(stow git curl)

declare -a RESULTS_OK=()
declare -a RESULTS_SKIP=()
declare -a RESULTS_FAIL=()

is_installed() {
    dpkg -s "$1" 2>/dev/null | grep -q "Status: install ok installed"
}

echo ">>> sudo apt update"
sudo apt update

echo ">>> sudo apt upgrade -y"
sudo apt upgrade -y

echo ">>> Instalando paquetes..."
for pkg in "${PACKAGES[@]}"; do
    if is_installed "$pkg"; then
        echo "  ya instalado: $pkg"
        RESULTS_SKIP+=("$pkg")
    else
        echo "  instalando: $pkg..."
        if sudo apt install -y "$pkg" >/dev/null 2>&1; then
            RESULTS_OK+=("$pkg")
        else
            echo "    fallo al instalar $pkg" >&2
            RESULTS_FAIL+=("$pkg")
        fi
    fi
done

echo ">>> Preparando dotfiles en $DOTFILES_DIR"
if [ -d "$DOTFILES_DIR" ]; then
    if [ -d "$DOTFILES_DIR/.git" ]; then
        echo "  Actualizando dotfiles (git pull --ff-only)..."
        if ! git -C "$DOTFILES_DIR" pull --ff-only; then
            echo "  Aviso: git pull fallo (puede haber cambios locales); continuando con la version actual" >&2
        fi
    else
        echo "  $DOTFILES_DIR existe pero no es un repo git. Eliminando para re-clonar." >&2
        rm -rf "$DOTFILES_DIR"
    fi
fi

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "  Clonando $DOTFILES_REPO -> $DOTFILES_DIR"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo ">>> Aplicando stow en $DOTFILES_DIR"
cd "$DOTFILES_DIR"
stow -v .

okCount=${#RESULTS_OK[@]}
skipCount=${#RESULTS_SKIP[@]}
failCount=${#RESULTS_FAIL[@]}

echo ""
echo ">>> Resumen"
echo "  Instalados en esta corrida: $okCount"
echo "  Ya estaban:                $skipCount"
if [ "$failCount" -gt 0 ]; then
    echo "  Fallos:                    $failCount"
    for f in "${RESULTS_FAIL[@]}"; do
        echo "    - $f"
    done
else
    echo "  Fallos:                    0"
fi
