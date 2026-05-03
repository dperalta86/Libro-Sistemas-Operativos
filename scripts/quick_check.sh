#!/bin/bash
# ============================================================
# Quick Check - Verificación rápida post-instalación
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 Quick Check - Verificación Rápida${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

FAIL_COUNT=0
WARN_COUNT=0

# Función para revisar comando
check_cmd() {
    local cmd=$1
    local name=$2
    local critical=$3
    
    if command -v "$cmd" &> /dev/null; then
        VERSION=$(eval "$cmd --version 2>/dev/null | head -1" || echo "instalado")
        echo -e "${GREEN}✓${NC} $name"
        echo "  └─ $VERSION"
    else
        if [ "$critical" = "critical" ]; then
            echo -e "${RED}✗${NC} $name (CRÍTICO - FALTA)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        else
            echo -e "${YELLOW}⚠${NC} $name (opcional)"
            WARN_COUNT=$((WARN_COUNT + 1))
        fi
    fi
}

# Verificaciones
echo "Componentes críticos:"
check_cmd "pandoc" "Pandoc" "critical"
check_cmd "xelatex" "XeLaTeX" "critical"
check_cmd "wkhtmltoimage" "wkhtmltopdf" "critical"

echo ""
echo "Componentes opcionales:"
check_cmd "mmdc" "mermaid-cli" "optional"
check_cmd "node" "Node.js" "optional"

echo ""

# Verificación de espacios
echo "Espacio disponible:"
SPACE=$(df -h . | tail -1 | awk '{print $4}')
echo -e "  Disponible: ${BLUE}$SPACE${NC}"

echo ""

# Resultado final
if [ $FAIL_COUNT -eq 0 ]; then
    if [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        echo -e "${GREEN}✓ ¡PERFECTO! Todo instalado correctamente${NC}"
        echo -e "${GREEN}════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}Próximos pasos:${NC}"
        echo "  • Prueba: make print-b5"
        echo "  • Todos:  make print-all"
        echo "  • Guía:   cat FORMATOS.md"
        exit 0
    else
        echo -e "${YELLOW}════════════════════════════════════════${NC}"
        echo -e "${YELLOW}✓ Funciona, pero faltan $WARN_COUNT componentes opcionales${NC}"
        echo -e "${YELLOW}════════════════════════════════════════${NC}"
        echo ""
        echo "Si necesitas diagramas .mmd:"
        echo "  sudo npm install -g @mermaid-js/mermaid-cli"
        exit 0
    fi
else
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}✗ Faltan $FAIL_COUNT componentes CRÍTICOS${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Ejecuta:${NC}"
    echo "  ./scripts/setup_minimalista.sh"
    exit 1
fi
