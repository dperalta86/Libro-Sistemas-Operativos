#!/bin/bash
# ============================================================
# html2png-chromium.sh - Convierte HTML→PNG usando Chromium
# Alternativa a wkhtmltopdf (que no está en Ubuntu 24.04+)
# ============================================================

set -e

if [ $# -lt 2 ]; then
    echo "Uso: html2png-chromium.sh <archivo.html> <archivo.png>"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

# Detectar Chromium en diferentes ubicaciones
CHROMIUM=""
for cmd in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "$cmd" &>/dev/null; then
        CHROMIUM="$cmd"
        break
    fi
done

if [ -z "$CHROMIUM" ]; then
    echo "Error: Chromium/Chrome no encontrado"
    exit 1
fi

# Convertir ruta relativa a absoluta
if [[ ! "$INPUT" = /* ]]; then
    INPUT="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
fi

# Crear directorio de salida si no existe
mkdir -p "$(dirname "$OUTPUT")"

# Usar Chromium headless para captura de pantalla
# --headless=new usa el nuevo modo headless
# --screenshot guarda como PNG
# --window-size es importante para la salida
"$CHROMIUM" \
    --headless=new \
    --disable-gpu \
    --no-sandbox \
    --screenshot="$OUTPUT" \
    --window-size=1200,1600 \
    "file://$INPUT" 2>/dev/null

# Chromium por defecto guarda en "screenshot.png" en el directorio actual
if [ -f "screenshot.png" ]; then
    mv "screenshot.png" "$OUTPUT"
fi

if [ -f "$OUTPUT" ]; then
    exit 0
else
    echo "Error: No se pudo convertir $INPUT"
    exit 1
fi
