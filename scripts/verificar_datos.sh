#!/bin/bash
# ============================================================
# Verificador de Datos Editoriales
# Verifica qué datos faltan completar antes de imprimir con ISBN
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📋 Verificador de Datos Editoriales${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Archivo a verificar
DATOS_FILE="datos-editoriales.yaml"

if [ ! -f "$DATOS_FILE" ]; then
    echo -e "${RED}✗${NC} Archivo $DATOS_FILE no encontrado"
    exit 1
fi

# Datos críticos que DEBEN completarse
CRITICOS=(
    "isbn"
    "deposito_legal"
    "editorial_nombre"
    "editorial_direccion"
    "autor"
)

# Datos importantes
IMPORTANTES=(
    "editorial_email"
    "editorial_sitio"
    "autor_bio"
    "camara_numero_inscripcion"
    "dedicatoria"
)

echo -e "${YELLOW}Analizando datos en: $DATOS_FILE${NC}"
echo ""

FALTANTES_CRITICOS=0
FALTANTES_IMPORTANTES=0

echo -e "${BLUE}DATOS CRÍTICOS (obligatorios para ISBN):${NC}"
echo ""

for dato in "${CRITICOS[@]}"; do
    valor=$(grep "^$dato:" "$DATOS_FILE" 2>/dev/null | cut -d':' -f2- | xargs || echo "")
    
    if [[ "$valor" == *"COMPLETAR"* ]] || [ -z "$valor" ]; then
        echo -e "  ${RED}✗${NC} $dato (FALTA)"
        FALTANTES_CRITICOS=$((FALTANTES_CRITICOS + 1))
    else
        echo -e "  ${GREEN}✓${NC} $dato"
    fi
done

echo ""
echo -e "${BLUE}DATOS IMPORTANTES (recomendados):${NC}"
echo ""

for dato in "${IMPORTANTES[@]}"; do
    valor=$(grep "^$dato:" "$DATOS_FILE" 2>/dev/null | cut -d':' -f2- | xargs || echo "")
    
    if [[ "$valor" == *"COMPLETAR"* ]] || [ -z "$valor" ]; then
        echo -e "  ${YELLOW}⚠${NC} $dato (no completado)"
        FALTANTES_IMPORTANTES=$((FALTANTES_IMPORTANTES + 1))
    else
        echo -e "  ${GREEN}✓${NC} $dato"
    fi
done

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [ $FALTANTES_CRITICOS -eq 0 ]; then
    echo -e "${GREEN}✓ Todos los datos críticos están completos${NC}"
else
    echo -e "${RED}✗ Faltan $FALTANTES_CRITICOS datos críticos${NC}"
fi

if [ $FALTANTES_IMPORTANTES -gt 0 ]; then
    echo -e "${YELLOW}⚠ Faltan $FALTANTES_IMPORTANTES datos importantes${NC}"
fi

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [ $FALTANTES_CRITICOS -eq 0 ]; then
    echo -e "${GREEN}Estás listo para generar el PDF final:${NC}"
    echo "  make print-b5"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo "  1. Revisar el PDF generado"
    echo "  2. Si todo está bien, registrar en Cámara del Libro"
    echo "  3. Obtener ISBN"
    echo "  4. Actualizar datos-editoriales.yaml con el ISBN real"
    echo "  5. Regenerar PDF final: make print-b5"
else
    echo -e "${RED}Por favor completa los datos críticos primero:${NC}"
    echo "  nano $DATOS_FILE"
    echo ""
    echo -e "${YELLOW}Datos críticos a completar:${NC}"
    for dato in "${CRITICOS[@]}"; do
        valor=$(grep "^$dato:" "$DATOS_FILE" 2>/dev/null | cut -d':' -f2- | xargs || echo "")
        if [[ "$valor" == *"COMPLETAR"* ]] || [ -z "$valor" ]; then
            echo "  - $dato"
        fi
    done
fi

echo ""
