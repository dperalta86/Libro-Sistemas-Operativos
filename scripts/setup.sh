#!/usr/bin/env bash
set -e

echo "🔎 Verificando dependencias..."

# Detectar sistema
if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL="sudo apt-get install -y"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    INSTALL="sudo dnf install -y"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    INSTALL="sudo pacman -S --noconfirm"
else
    echo "❌ No se detectó un gestor de paquetes compatible (apt-get/dnf/pacman)."
    exit 1
fi

# Función auxiliar para instalar si falta
install_if_missing() {
    local pkg=$1
    local bin=$2
    if ! command -v "$bin" &>/dev/null; then
        echo "⚡ Instalando $pkg..."
        $INSTALL $pkg
    else
        echo "✅ $pkg ya instalado."
    fi
}

# Dependencias generales
install_if_missing "pandoc" "pandoc"
install_if_missing "texlive-xetex" "xelatex" || true
install_if_missing "texlive-latex-extra" "pdflatex" || true
install_if_missing "fonts-firacode" "fc-list" || true

# Verificar fuente Fira Code
if ! fc-list | grep -qi "Fira Code"; then
    echo "⚡ Instalando fuente Fira Code manualmente..."
    mkdir -p ~/.local/share/fonts
    wget -q https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip -O /tmp/firacode.zip
    unzip -o /tmp/firacode.zip -d ~/.local/share/fonts
    fc-cache -fv
    echo "✅ Fuente Fira Code instalada."
else
    echo "✅ Fuente Fira Code disponible."
fi

echo "🚀 Entorno listo!"
