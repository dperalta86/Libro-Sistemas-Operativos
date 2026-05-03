#!/bin/bash
# ============================================================
# Sincronizar Datos Editoriales → Primeras Páginas
# Lee datos-editoriales.yaml y sustituye placeholders en metadata-*.yaml
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🔄 Sincronizando Datos Editoriales${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

DATOS_FILE="datos-editoriales.yaml"
METADATA_B5="metadata-b5.yaml"
METADATA_A4="metadata-a4.yaml"
METADATA_A5="metadata-a5.yaml"

# Verificar que existen los archivos
if [ ! -f "$DATOS_FILE" ]; then
    echo -e "${RED}✗${NC} Archivo $DATOS_FILE no encontrado"
    exit 1
fi

echo -e "${YELLOW}Leyendo datos de: $DATOS_FILE${NC}"
echo ""

# Función para extraer valores del YAML
get_yaml_value() {
    local key="$1"
    local file="$2"
    grep "^$key:" "$file" 2>/dev/null | sed 's/^[^:]*: *//g' | sed "s/['\"]//g" | head -1
}

# Leer datos del YAML
TITULO=$(get_yaml_value "titulo" "$DATOS_FILE")
AUTOR=$(get_yaml_value "autor" "$DATOS_FILE")
EDICION=$(get_yaml_value "edicion" "$DATOS_FILE")
FECHA=$(get_yaml_value "fecha_publicacion" "$DATOS_FILE")

ISBN=$(grep "^isbn:" "$DATOS_FILE" | sed 's/^[^:]*: *//g' | sed "s/[\[\]'\"]//g" | head -1)
DEPOSITO=$(grep "^deposito_legal:" "$DATOS_FILE" | sed 's/^[^:]*: *//g' | sed "s/[\[\]'\"]//g" | head -1)

EDITORIAL=$(get_yaml_value "editorial_nombre" "$DATOS_FILE")
DIRECCION=$(get_yaml_value "editorial_direccion" "$DATOS_FILE")
EMAIL_EDITORIAL=$(get_yaml_value "editorial_email" "$DATOS_FILE")
SITIO=$(get_yaml_value "editorial_sitio" "$DATOS_FILE")

# Leer dedicatoria (primera línea si es una lista)
DEDICATORIA=$(grep -A1 "^dedicatoria:" "$DATOS_FILE" | tail -1 | sed 's/^ *- *//g' | sed "s/['\"]//g")

echo -e "${GREEN}✓ Datos leídos:${NC}"
echo "  • Título: $TITULO"
echo "  • Autor: $AUTOR"
echo "  • Edición: $EDICION"
echo "  • ISBN: $ISBN"
echo "  • Depósito Legal: $DEPOSITO"
echo "  • Dedicatoria: ${DEDICATORIA:0:60}..."
echo ""

# Escapar caracteres especiales para sed
escape_for_sed() {
    echo "$1" | sed 's/[\/&]/\\&/g'
}

ISBN_ESC=$(escape_for_sed "$ISBN")
DEPOSITO_ESC=$(escape_for_sed "$DEPOSITO")
EDITORIAL_ESC=$(escape_for_sed "$EDITORIAL")
DIRECCION_ESC=$(escape_for_sed "$DIRECCION")
EMAIL_EDITORIAL_ESC=$(escape_for_sed "$EMAIL_EDITORIAL")
SITIO_ESC=$(escape_for_sed "$SITIO")
DEDICATORIA_ESC=$(escape_for_sed "$DEDICATORIA")

# Función para sustituir en archivo
substitute_metadata() {
    local file="$1"
    local count=0
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠${NC} Archivo $file no existe, saltando..."
        return
    fi
    
    echo -e "${YELLOW}📝 Actualizando: $file${NC}"
    
    # ISBN
    if grep -q "COMPLETAR_CON_ISBN" "$file"; then
        sed -i "s/\[COMPLETAR_CON_ISBN\]/$ISBN_ESC/g" "$file"
        echo "  ✓ ISBN actualizado"
        count=$((count + 1))
    fi
    
    # Depósito Legal
    if grep -q "COMPLETAR_CON_DEPOSITO_LEGAL" "$file"; then
        sed -i "s/\[COMPLETAR_CON_DEPOSITO_LEGAL\]/$DEPOSITO_ESC/g" "$file"
        echo "  ✓ Depósito Legal actualizado"
        count=$((count + 1))
    fi
    
    # Editorial (para impresión privada, opcional)
    if grep -q "COMPLETAR_CON_EDITORIAL" "$file"; then
        if [ -n "$EDITORIAL" ] && [[ "$EDITORIAL" != *"COMPLETAR"* ]]; then
            sed -i "s/\[COMPLETAR_CON_EDITORIAL\]/$EDITORIAL_ESC/g" "$file"
            echo "  ✓ Editorial actualizada"
            count=$((count + 1))
        fi
    fi
    
    # Dirección
    if grep -q "COMPLETAR_CON_DIRECCION" "$file"; then
        if [ -n "$DIRECCION" ] && [[ "$DIRECCION" != *"COMPLETAR"* ]]; then
            sed -i "s/\[COMPLETAR_CON_DIRECCION\]/$DIRECCION_ESC/g" "$file"
            echo "  ✓ Dirección actualizada"
            count=$((count + 1))
        fi
    fi
    
    # Dedicatoria
    if grep -q "COMPLETAR_CON_DEDICATORIA" "$file"; then
        if [ -n "$DEDICATORIA" ] && [[ "$DEDICATORIA" != *"COMPLETAR"* ]]; then
            sed -i "s/\[COMPLETAR_CON_DEDICATORIA\]/$DEDICATORIA_ESC/g" "$file"
            echo "  ✓ Dedicatoria actualizada"
            count=$((count + 1))
        fi
    fi
    
    if [ $count -eq 0 ]; then
        echo "  ℹ No hay placeholders para actualizar"
    fi
}

# Sustituir en todos los metadata files
substitute_metadata "$METADATA_B5"
substitute_metadata "$METADATA_A4"
substitute_metadata "$METADATA_A5"

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Sincronización completada${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Próximo paso:${NC}"
echo "  make print-b5    # Generar PDF con datos actualizados"
echo "  make view-frontmatter  # Ver el resultado"
echo ""
