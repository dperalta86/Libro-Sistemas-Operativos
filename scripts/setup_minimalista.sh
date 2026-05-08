#!/bin/bash
# ============================================================
# Script de instalación MINIMALISTA para Libro-Sistemas-Operativos
# Kubuntu - Solo lo esencial (sin los 6GB de basura)
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}📚 Instalación Minimalista - Libro SO${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================
# 1. Detectar distro y gestor de paquetes
# ============================================================
if grep -q "Ubuntu\|Kubuntu\|Debian" /etc/os-release; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
    UPDATE_CMD="sudo apt-get update"
    echo -e "${GREEN}✓${NC} Detectado: Debian/Ubuntu/Kubuntu"
elif grep -q "Fedora" /etc/os-release; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
    UPDATE_CMD="sudo dnf check-update"
    echo -e "${GREEN}✓${NC} Detectado: Fedora"
else
    echo -e "${RED}✗${NC} Distro no soportada"
    exit 1
fi

echo ""

# ============================================================
# 2. Función helper para revisar e instalar
# ============================================================
install_if_missing() {
    local cmd=$1
    local pkg=$2
    local description=$3
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $description ya instalado"
    else
        echo -e "${YELLOW}→${NC} Instalando $description..."
        eval "$INSTALL_CMD $pkg"
        echo -e "${GREEN}✓${NC} $description instalado"
    fi
}

# ============================================================
# 3. PANDOC (pandoc) - Core
# ============================================================
echo -e "${BLUE}[1/5]${NC} Verificando Pandoc..."
install_if_missing "pandoc" "pandoc" "Pandoc"

# ============================================================
# 4. XELATEX (texlive-xetex) - NO texlive-full
# ============================================================
echo ""
echo -e "${BLUE}[2/5]${NC} Verificando XeLaTeX (minimalista)..."

if command -v xelatex &> /dev/null; then
    echo -e "${GREEN}✓${NC} XeLaTeX ya instalado"
else
    echo -e "${YELLOW}→${NC} Instalando texlive-xetex (minimalista, ~400MB)..."
    echo -e "${YELLOW}   (NOT: texlive-full para evitar los 6GB)${NC}"
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $UPDATE_CMD
        # Paquetes esenciales pero MINIMALISTAS
        # Incluir texlive-lang-spanish para soporte del idioma
        # Incluir texlive-fonts-extra para fuentes (Source Sans Pro, Code Pro)
        $INSTALL_CMD \
            texlive-xetex \
            texlive-fonts-recommended \
            texlive-fonts-extra \
            texlive-latex-extra \
            texlive-lang-spanish
        
        # Intentar instalar fonts del sistema (opcional)
        if apt-cache policy fonts-source-code-pro &>/dev/null; then
            $INSTALL_CMD fonts-source-code-pro 2>/dev/null || true
            $INSTALL_CMD fonts-source-sans-pro 2>/dev/null || true
        fi
    else
        $INSTALL_CMD \
            texlive-xetex \
            texlive-fonts-recommended \
            texlive-fonts-extra \
            texlive-latex-extra
    fi
    echo -e "${GREEN}✓${NC} XeLaTeX instalado (minimalista)"
fi

# ============================================================
# 5. NODE.JS + mermaid-cli (para diagramas)
# ============================================================
echo ""
echo -e "${BLUE}[5/5]${NC} Verificando Node.js..."

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION ya instalado"
else
    echo -e "${YELLOW}→${NC} Instalando Node.js..."
    $UPDATE_CMD 2>/dev/null || true
    $INSTALL_CMD nodejs npm
    echo -e "${GREEN}✓${NC} Node.js instalado"
fi

# mermaid-cli via npm
echo -e "${BLUE}[5/5]${NC} Verificando mermaid-cli..."
if command -v mmdc &> /dev/null; then
    echo -e "${GREEN}✓${NC} mermaid-cli ya instalado"
else
    echo -e "${YELLOW}→${NC} Instalando @mermaid-js/mermaid-cli globalmente..."
    sudo npm install -g @mermaid-js/mermaid-cli --silent 2>/dev/null || true
    echo -e "${GREEN}✓${NC} mermaid-cli instalado"
fi

# ============================================================
# 7. Verificación final
# ============================================================
echo ""
echo -e "${BLUE}[5/5]${NC} Verificación final..."
echo ""

MISSING=0
WARNINGS=0

echo "Verificando comandos CRÍTICOS:"
for cmd in pandoc xelatex; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${RED}✗${NC} $cmd (FALTA)"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "Verificando comandos OPCIONALES:"
for cmd in mmdc node npm; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${YELLOW}⚠${NC} $cmd (opcional)"
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""

if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ¡INSTALACIÓN COMPLETADA!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠ Nota: Faltan $WARNINGS componentes opcionales${NC}"
        echo -e "  El proyecto funciona, pero algunas características opcionales no estarán disponibles"
    fi
    
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo "  1. Ir al directorio del proyecto:"
    echo "     cd \"Libro-Sistemas-Operativos\""
    echo ""
    echo "  2. Probar la versión B5:"
    echo "     make print-b5"
    echo ""
    echo "  3. O generar todos los formatos:"
    echo "     make print-all"
    echo ""
    echo "  4. Ver la guía de formatos:"
    echo "     cat FORMATOS.md"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Faltan $MISSING componentes CRÍTICOS${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Intenta ejecutar de nuevo este script o instala manualmente:"
    echo "  sudo apt-get install pandoc texlive-xetex texlive-fonts-recommended texlive-latex-extra"
    exit 1
fi
