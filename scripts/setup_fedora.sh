#!/bin/bash

# Setup script para compilar libro de Sistemas Operativos en Fedora
# Fecha: $(date +%Y-%m-%d)

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con colores
print_status() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}📦 $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Verificar que estamos en Fedora
check_fedora() {
    if [ ! -f /etc/fedora-release ]; then
        print_error "Este script está diseñado para Fedora"
        exit 1
    fi
    
    FEDORA_VERSION=$(cat /etc/fedora-release)
    print_status "Detectado: $FEDORA_VERSION"
}

# Actualizar sistema
update_system() {
    print_section "ACTUALIZACIÓN DEL SISTEMA"
    print_status "Actualizando repositorios y paquetes base..."
    
    sudo dnf update -y
    print_success "Sistema actualizado"
}

# Instalar dependencias básicas del sistema
install_system_deps() {
    print_section "DEPENDENCIAS DEL SISTEMA"
    
    print_status "Instalando herramientas de desarrollo básicas..."
    
    print_status "Instalando dependencias del sistema..."
    sudo dnf install -y \
        wget \
        curl \
        git \
        make \
        gcc \
        g++ \
        cmake \
        pkgconfig \
        fontconfig-devel \
        freetype-devel \
        libX11-devel \
        libXext-devel \
        libXrender-devel \
        xz \
        unzip \
        which \
        findutils
    
    print_success "Dependencias básicas instaladas"
}

# Instalar LaTeX (TeXLive)
install_latex() {
    print_section "INSTALACIÓN DE LATEX (TEXLIVE)"
    
    if command -v xelatex >/dev/null 2>&1; then
        print_success "XeLaTeX ya está instalado"
        xelatex --version | head -n 1
        return
    fi
    
    print_status "Instalando TeXLive mínimo necesario..."
    print_warning "Se instalarán solo los paquetes esenciales (~700 MiB)"

    sudo dnf install -y \
        texlive-xetex \
        texlive-fontspec \
        texlive-xcolor \
        texlive-tcolorbox \
        texlive-booktabs \
        texlive-float \
        texlive-ulem \
        texlive-listings \
        texlive-collection-fontsrecommended

    print_status "Instalando fuentes requeridas..."
    sudo dnf install -y \
        google-ibm-plex-fonts \
        jetbrains-mono-fonts-all \
        google-noto-emoji-color-fonts

    if command -v xelatex >/dev/null 2>&1; then
        print_success "LaTeX instalado correctamente"
        xelatex --version | head -n 1
    else
        print_error "Error instalando LaTeX"
        exit 1
    fi
}


# Instalar Pandoc
install_pandoc() {
    print_section "INSTALACIÓN DE PANDOC"
    
    if command -v pandoc >/dev/null 2>&1; then
        CURRENT_VERSION=$(pandoc --version | head -n 1)
        print_success "Pandoc ya está instalado: $CURRENT_VERSION"
        return
    fi
    
    print_status "Instalando Pandoc desde repositorios..."
    sudo dnf install -y pandoc
    
    # Verificar versión - necesitamos al menos 2.x para el template Eisvogel
    if command -v pandoc >/dev/null 2>&1; then
        PANDOC_VERSION=$(pandoc --version | head -n 1 | grep -oP '\d+\.\d+')
        if [[ $(echo "$PANDOC_VERSION < 2.0" | bc -l) -eq 1 ]]; then
            print_warning "Versión de Pandoc muy antigua ($PANDOC_VERSION), instalando versión más reciente..."
            install_pandoc_manual
        else
            print_success "Pandoc instalado: $(pandoc --version | head -n 1)"
        fi
    else
        print_error "Error instalando Pandoc"
        exit 1
    fi
}

# Instalar Pandoc manualmente si la versión del repo es muy antigua
install_pandoc_manual() {
    print_status "Descargando Pandoc más reciente..."
    
    PANDOC_VERSION="3.1.8"
    PANDOC_DEB="pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz"
    
    cd /tmp
    wget -q "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/${PANDOC_DEB}"
    
    tar -xzf "$PANDOC_DEB"
    sudo cp "pandoc-${PANDOC_VERSION}/bin/pandoc" /usr/local/bin/
    sudo cp "pandoc-${PANDOC_VERSION}/bin/pandoc-lua" /usr/local/bin/
    
    rm -rf "/tmp/pandoc-${PANDOC_VERSION}" "/tmp/${PANDOC_DEB}"
    
    print_success "Pandoc $PANDOC_VERSION instalado manualmente"
}

# Instalar Node.js y npm
install_nodejs() {
    print_section "INSTALACIÓN DE NODE.JS"
    
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        print_success "Node.js ya está instalado: $NODE_VERSION"
    else
        print_status "Instalando Node.js y npm..."
        sudo dnf install -y nodejs npm
        print_success "Node.js instalado: $(node --version)"
    fi
    
    # Verificar npm
    if command -v npm >/dev/null 2>&1; then
        print_success "npm disponible: $(npm --version)"
    else
        print_error "npm no está disponible"
        exit 1
    fi
}



# Instalar wkhtmltopdf
install_wkhtmltopdf() {
    print_section "INSTALACIÓN DE WKHTMLTOPDF"
    
    if command -v wkhtmltoimage >/dev/null 2>&1; then
        print_success "wkhtmltopdf ya está instalado"
        wkhtmltoimage --version | head -n 1
        return
    fi
    
    print_status "Instalando wkhtmltopdf..."
    sudo dnf install -y wkhtmltopdf
    
    if command -v wkhtmltoimage >/dev/null 2>&1; then
        print_success "wkhtmltopdf instalado correctamente"
        wkhtmltoimage --version | head -n 1
    else
        print_error "Error instalando wkhtmltopdf"
        exit 1
    fi
}

# Instalar fuentes requeridas
install_fonts() {
    print_section "INSTALACIÓN DE FUENTES"
    
    print_status "Instalando fuentes IBM Plex y JetBrains Mono..."
    
    # Fuentes disponibles en repos de Fedora
    sudo dnf install -y \
        fira-code-fonts \
        jetbrains-mono-fonts \
        ibm-plex-mono-fonts \
        google-noto-sans-fonts \
        dejavu-sans-fonts \
        dejavu-serif-fonts\
        texlive-bigfoot
    
    # Instalar IBM Plex manualmente si no está en repos
    install_ibm_plex_fonts
    
    # Instalar JetBrains Mono
    install_jetbrains_mono
    
    # Refrescar cache de fuentes
    print_status "Refrescando caché de fuentes..."
    fc-cache -f -v >/dev/null 2>&1
    print_success "Caché de fuentes actualizado"
}

# Instalar IBM Plex manualmente
install_ibm_plex_fonts() {
    print_status "Verificando fuentes IBM Plex..."
    
    if fc-list | grep -i "IBM Plex" >/dev/null; then
        print_success "IBM Plex ya está instalado"
        return
    fi
    
    print_status "Descargando e instalando IBM Plex..."
    
    # Crear directorio de fuentes del usuario
    mkdir -p ~/.local/share/fonts
    cd /tmp
    
    # Descargar IBM Plex
    wget -q "https://github.com/IBM/plex/releases/download/v6.0.2/OpenType.zip" -O ibm-plex.zip
    unzip -q ibm-plex.zip
    
    # Copiar fuentes
    cp OpenType/IBM-Plex-Sans/*.otf ~/.local/share/fonts/
    cp OpenType/IBM-Plex-Serif/*.otf ~/.local/share/fonts/
    cp OpenType/IBM-Plex-Mono/*.otf ~/.local/share/fonts/
    
    # Limpiar
    rm -rf OpenType ibm-plex.zip
    
    print_success "IBM Plex instalado"
}

# Instalar JetBrains Mono
install_jetbrains_mono() {
    print_status "Verificando JetBrains Mono..."
    
    if fc-list | grep -i "JetBrains Mono" >/dev/null; then
        print_success "JetBrains Mono ya está instalado"
        return
    fi
    
    print_status "Descargando e instalando JetBrains Mono..."
    
    cd /tmp
    
    # Descargar JetBrains Mono
    wget -q "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -O jetbrains-mono.zip
    unzip -q jetbrains-mono.zip
    
    # Copiar fuentes
    cp fonts/ttf/*.ttf ~/.local/share/fonts/
    
    # Limpiar
    rm -rf fonts jetbrains-mono.zip
    
    print_success "JetBrains Mono instalado"
}

# Crear directorios del proyecto
setup_project_structure() {
    print_section "CONFIGURACIÓN DE ESTRUCTURA DEL PROYECTO"
    
    print_status "Creando directorios necesarios..."
    
    # Crear directorios si no existen
    mkdir -p src/images
    mkdir -p src/diagrams  
    mkdir -p src/tables
    mkdir -p templates
    mkdir -p build
    mkdir -p scripts
    
    # Crear archivo gitignore si no existe
    if [ ! -f .gitignore ]; then
        cat > .gitignore << EOF
# Build outputs
build/
*.pdf
libro-completo.md
pandoc.log

# Temporary files
*.tmp
*.temp
test.*

# Generated images
src/diagrams/*.png
src/tables/*.png

# OS specific
.DS_Store
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vscode/
EOF
        print_success "Archivo .gitignore creado"
    fi
    
    print_success "Estructura del proyecto configurada"
}

# Verificar instalación completa
verify_installation() {
    print_section "VERIFICACIÓN DE INSTALACIÓN"
    
    local ERRORS=0
    
    # Verificar cada herramienta
    TOOLS=(
        "xelatex:XeLaTeX"
        "pandoc:Pandoc" 
        "node:Node.js"
        "npm:npm"
        "wkhtmltoimage:wkhtmltopdf"
        "make:Make"
        "git:Git"
    )
    
    for tool_info in "${TOOLS[@]}"; do
        IFS=':' read -r cmd name <<< "$tool_info"
        if command -v "$cmd" >/dev/null 2>&1; then
            print_success "$name disponible"
        else
            print_error "$name NO disponible"
            ((ERRORS++))
        fi
    done
    
    # Verificar fuentes
    if fc-list | grep -i "IBM Plex" >/dev/null; then
        print_success "Fuentes IBM Plex disponibles"
    else
        print_warning "Fuentes IBM Plex no encontradas"
        ((ERRORS++))
    fi
    
    if fc-list | grep -i "JetBrains Mono" >/dev/null; then
        print_success "Fuente JetBrains Mono disponible"  
    else
        print_warning "Fuente JetBrains Mono no encontrada"
        ((ERRORS++))
    fi
    
    echo ""
    if [ $ERRORS -eq 0 ]; then
        print_success "¡Instalación completa! Todo está listo para compilar el libro"
        echo ""
        echo -e "${GREEN}📚 Para compilar el libro ejecuta:${NC}"
        echo -e "${BLUE}   make all${NC}"
        echo ""
        echo -e "${GREEN}📊 Para generar solo las tablas:${NC}"
        echo -e "${BLUE}   make tables${NC}"
        echo ""
        echo -e "${GREEN}🧹 Para limpiar archivos temporales:${NC}"
        echo -e "${BLUE}   make clean${NC}"
    else
        print_error "Se encontraron $ERRORS errores. Revisa la instalación."
        exit 1
    fi
}

# Función principal
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║      🐧 Setup para Libro de Sistemas Operativos 📚           ║
║                     Fedora Edition                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    print_status "Iniciando instalación de dependencias..."
    echo ""
    
    # Verificar privilegios sudo
    if ! sudo -n true 2>/dev/null; then
        print_warning "Este script requiere privilegios sudo"
        sudo true
    fi
    
    # Ejecutar instalaciones
    check_fedora
    update_system
    install_system_deps
    install_latex
    install_pandoc
    install_nodejs
    install_wkhtmltopdf
    install_fonts
    setup_project_structure
    verify_installation
    
    print_section "🎉 INSTALACIÓN COMPLETADA"
    
    print_success "El entorno está listo para desarrollar el libro"
    echo ""
    echo -e "${YELLOW}💡 Consejos:${NC}"
    echo "   • Reinicia la terminal para que las fuentes se carguen correctamente"
    echo "   • Ejecuta 'make structure' para ver la estructura del proyecto"
    echo "   • El primer build puede tardar más debido a la descarga de paquetes LaTeX"
    echo ""
}

# Trap para cleanup en caso de error
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Error durante la instalación"
        print_status "Limpiando archivos temporales..."
        rm -rf /tmp/pandoc-* /tmp/ibm-plex.zip /tmp/jetbrains-mono.zip /tmp/OpenType /tmp/fonts
    fi
}
trap cleanup EXIT

# Ejecutar función principal
main "$@"
