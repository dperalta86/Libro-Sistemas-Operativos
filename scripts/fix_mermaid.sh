#!/bin/bash
# ============================================================
# Fix Mermaid - Soluciona problemas con mermaid-cli
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Fix Mermaid - Configurar Chrome/Chromium${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# ============================================================
# 1. Verificar mermaid-cli
# ============================================================
if ! command -v mmdc &> /dev/null; then
    echo -e "${RED}✗${NC} mermaid-cli no instalado"
    echo ""
    echo -e "${YELLOW}Instala con:${NC}"
    echo "  sudo npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

echo -e "${GREEN}✓${NC} mermaid-cli instalado: $(mmdc --version)"
echo ""

# ============================================================
# 2. Buscar Chromium en diferentes ubicaciones
# ============================================================
echo -e "${BLUE}Buscando Chromium/Chrome...${NC}"
echo ""

CHROME_PATHS=(
    "/usr/bin/chromium-browser"
    "/usr/bin/chromium"
    "/snap/bin/chromium"
    "/opt/google/chrome/chrome"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
)

FOUND_CHROME=""
for path in "${CHROME_PATHS[@]}"; do
    if [ -x "$path" ]; then
        FOUND_CHROME="$path"
        echo -e "${GREEN}✓ Encontrado en:${NC} $path"
        break
    fi
done

echo ""

# ============================================================
# 3. Si no encontró, instalar puppeteer
# ============================================================
if [ -z "$FOUND_CHROME" ]; then
    echo -e "${YELLOW}⚠${NC} No se encontró Chromium en ubicaciones estándar"
    echo ""
    echo -e "${YELLOW}Instalando Chrome para Puppeteer...${NC}"
    echo ""
    
    npx puppeteer browsers install chrome-headless-shell
    
    echo ""
    echo -e "${GREEN}✓ Chrome instalado para Puppeteer${NC}"
    FOUND_CHROME="puppeteer"
else
    # Verificar que mermaid pueda encontrarlo
    if mmdc --version >/dev/null 2>&1; then
        echo -e "${YELLOW}→${NC} Probando mmdc con Chromium encontrado..."
        
        # Crear un test diagram simple
        TEST_FILE="/tmp/test-mermaid.mmd"
        echo "graph TD; A[Test] --> B[OK]" > "$TEST_FILE"
        
        if mmdc -i "$TEST_FILE" -o "/tmp/test-mermaid.png" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} mermaid funciona correctamente"
            rm -f "$TEST_FILE" "/tmp/test-mermaid.png"
            exit 0
        else
            echo -e "${YELLOW}⚠${NC} mermaid detecta Chromium pero falla"
            echo -e "${YELLOW}→${NC} Instalando Chrome para Puppeteer como fallback..."
            echo ""
            npx puppeteer browsers install chrome-headless-shell
        fi
    fi
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Configuración completada${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Ahora intenta:${NC}"
echo "  make clean"
echo "  make print-b5"
echo ""
