.PHONY: all clean debug structure test-latex tables setup install-deps fedora fix-mermaid check-datos edit-datos sync-datos view-frontmatter list-todos

# Configuración del libro
BOOK_NAME = Introduccion_a_los_Sistemas_Operativos
OUTPUT_DIR = build
SRC_DIR = src

# Lista de capítulos en orden
CAPITULOS = $(SRC_DIR)/prefacio.md \
	$(SRC_DIR)/arquitectura-de-computadores.md \
	$(SRC_DIR)/fundamentos-SO.md \
	$(SRC_DIR)/procesos.md \
	$(SRC_DIR)/planificacion.md \
	$(SRC_DIR)/hilos.md \
	$(SRC_DIR)/sincronizacion.md \
	$(SRC_DIR)/interbloqueo.md \
	$(SRC_DIR)/memoria-real.md \
	$(SRC_DIR)/memoria-virtual.md \
	$(SRC_DIR)/filesystem.md \
	$(SRC_DIR)/io.md \
	$(SRC_DIR)/apendice.md \
	$(SRC_DIR)/glosario.md

# Archivos de configuración por formato
METADATA_A4 = metadata-a4.yaml
METADATA_B5 = metadata-b5.yaml
METADATA = metadata-a4.yaml
COMBINED_MD = libro-completo.md
COMBINED_MD_A4 = libro-a4.md
COMBINED_MD_B5 = libro-b5.md
TEMPLATE = templates/eisvogel-modified.latex

# Diagramas Mermaid
DIAGRAMS := $(wildcard $(SRC_DIR)/diagrams/*.mmd)
PNG_DIAGRAMS := $(DIAGRAMS:.mmd=.png)

# Tablas HTML
TABLES := $(wildcard $(SRC_DIR)/tables/*.html)
PNG_TABLES := $(TABLES:.html=.png)

# Todas las imágenes
ALL_PNG := $(PNG_DIAGRAMS) $(PNG_TABLES)

# ===========================
# Targets principales por formato
# ===========================
# Pantalla/E-book (A4)
all: setup $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Impresión - Targets específicos por formato
print: print-b5
	@echo "✅ Versión de impresión recomendada (B5) generada"

print-a4: setup $(OUTPUT_DIR)/$(BOOK_NAME).pdf
	@echo "✅ PDF A4 para impresión generado"

print-b5: setup $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf
	@echo "✅ PDF B5 (formato recomendado) generado"

## print-a5 removed to simplify formats (A4 default, B5 available)

# Generar todos los formatos de impresión

print-all: print-a4 print-b5
	@echo "✅ Todos los formatos de impresión generados en $(OUTPUT_DIR)/"

# ===========================
# Target especial Fedora
# ===========================
fedora:
	@echo "🐧 Configuración especial para Fedora..."
	@chmod +x ./scripts/setup_fedora.sh
	./scripts/setup_fedora.sh
	$(MAKE) all

# ===========================
# Fix Mermaid - Soluciona problemas con diagramas
# ===========================
fix-mermaid:
	@echo "🔧 Configurando mermaid-cli..."
	@chmod +x ./scripts/fix_mermaid.sh
	@./scripts/fix_mermaid.sh

# ===========================
# Setup - Verificar dependencias
# ===========================
setup: install-deps tables
	@echo "✅ Setup completado - listo para generar PDFs"

# ===========================
# Dependencias - Verificación inteligente
# ===========================
install-deps:
	@echo "🔧 Verificando dependencias..."
	@echo ""
	@echo "Verificando comandos CRÍTICOS:"
	@command -v pandoc >/dev/null 2>&1 && echo "  ✓ pandoc" || { echo "  ✗ pandoc (FALTA - crítico)"; exit 1; }
	@command -v xelatex >/dev/null 2>&1 && echo "  ✓ xelatex" || { echo "  ✗ xelatex (FALTA - crítico)"; exit 1; }
	@echo ""
	@echo "Verificando comandos RECOMENDADOS (con fallbacks automáticos):"
	@command -v mmdc >/dev/null 2>&1 && echo "  ✓ mermaid-cli (diagramas .mmd)" || echo "  ⚠ mermaid-cli (para diagramas - opcional)"
	@if command -v chromium-browser >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1; then \
		echo "  ✓ Chromium (para tablas HTML→PNG)"; \
	else \
		echo "  ⚠ Chromium (fallback automático si falta wkhtmltopdf)"; \
	fi
	@echo ""
	@echo "💡 Para instalación completa en Kubuntu/Debian:"
	@echo "   ./scripts/setup_minimalista.sh"
	@echo ""
	@echo "✅ Verificación de dependencias completada"

# ===========================
# Generar archivo combinado (múltiples versiones)
# ===========================
$(COMBINED_MD): $(METADATA) $(CAPITULOS)
	@echo "🔄 Combinando archivos markdown..."
	@echo "---" > $(COMBINED_MD)
	@cat $(METADATA) >> $(COMBINED_MD)
	@echo "..." >> $(COMBINED_MD)
	@echo "" >> $(COMBINED_MD)
	@for capitulo in $(CAPITULOS); do \
		if [ -f "$$capitulo" ]; then \
			echo "✅ Agregando $$capitulo..."; \
			echo "" >> $(COMBINED_MD); \
			cat "$$capitulo" >> $(COMBINED_MD); \
			echo "" >> $(COMBINED_MD); \
		else \
			echo "⚠️ Advertencia: $$capitulo no existe"; \
		fi \
	done
	@echo "📄 Archivo combinado generado: $(COMBINED_MD)"

# Versión A4
$(COMBINED_MD_A4): $(METADATA_A4) $(CAPITULOS)
	@echo "🔄 Combinando archivos markdown (A4)..."
	@echo "---" > $(COMBINED_MD_A4)
	@cat $(METADATA_A4) >> $(COMBINED_MD_A4) && echo "" >> $(COMBINED_MD_A4)
	@echo "..." >> $(COMBINED_MD_A4)
	@echo "" >> $(COMBINED_MD_A4)
	@for capitulo in $(CAPITULOS); do \
		if [ -f "$$capitulo" ]; then \
			echo "" >> $(COMBINED_MD_A4); \
			cat "$$capitulo" >> $(COMBINED_MD_A4); \
			echo "" >> $(COMBINED_MD_A4); \
		fi \
	done

# Versión B5 (RECOMENDADA)
$(COMBINED_MD_B5): $(METADATA_B5) $(CAPITULOS)
	@echo "🔄 Combinando archivos markdown (B5)..."
	@echo "---" > $(COMBINED_MD_B5)
	@cat $(METADATA_B5) >> $(COMBINED_MD_B5) && echo "" >> $(COMBINED_MD_B5)
	@echo "..." >> $(COMBINED_MD_B5)
	@echo "" >> $(COMBINED_MD_B5)
	@for capitulo in $(CAPITULOS); do \
		if [ -f "$$capitulo" ]; then \
			echo "" >> $(COMBINED_MD_B5); \
			cat "$$capitulo" >> $(COMBINED_MD_B5); \
			echo "" >> $(COMBINED_MD_B5); \
		fi \
	done

## A5 support removed from Makefile to simplify metadata management

# ===========================
# Renderizar diagramas
# ===========================
$(PNG_DIAGRAMS): %.png : %.mmd
	@if command -v mmdc >/dev/null 2>&1; then \
		echo "🖼️  Exportando diagrama Mermaid: $< → $@"; \
		mkdir -p $(dir $@); \
		if mmdc -i $< -o $@ --backgroundColor white --theme neutral 2>/dev/null; then \
			echo "✓ Diagrama exportado: $@"; \
		else \
			echo "⚠️  mermaid-cli falla (probablemente falta Chromium)"; \
			echo ""; \
			echo "   Soluciones:"; \
			echo "   1. Instalar Chromium sistema: sudo apt-get install chromium-browser"; \
			echo "   2. O instalar Chrome para puppeteer: npx puppeteer browsers install chrome-headless-shell"; \
			echo "   3. O configurar PUPPETEER_EXECUTABLE_PATH"; \
			echo ""; \
			echo "   Intenta: npx puppeteer browsers install chrome-headless-shell"; \
			exit 1; \
		fi; \
	else \
		echo "⚠️  mermaid-cli no disponible, saltando diagrama: $<"; \
	fi

$(PNG_TABLES): %.png : %.html
	@if command -v wkhtmltoimage >/dev/null 2>&1; then \
		echo "📊 Exportando tabla HTML: $< → $@ (usando wkhtmltoimage)"; \
		mkdir -p $(dir $@); \
		wkhtmltoimage --width 1200 --quality 100 $< $@; \
	elif command -v chromium-browser >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1; then \
		echo "📊 Exportando tabla HTML: $< → $@ (usando Chromium)"; \
		mkdir -p $(dir $@); \
		chmod +x ./scripts/html2png-chromium.sh; \
		./scripts/html2png-chromium.sh $< $@; \
	else \
		echo "⚠️  wkhtmltoimage ni Chromium disponibles, saltando tabla: $<"; \
		mkdir -p $(dir $@); \
		touch $@; \
	fi

tables: install-deps
	@if command -v wkhtmltoimage >/dev/null 2>&1; then \
		echo "🔄 Convirtiendo tablas HTML a PNG..."; \
		$(MAKE) $(PNG_TABLES); \
		echo "✅ Tablas HTML convertidas a PNG"; \
	else \
		echo "⚠️  wkhtmltopdf no instalado - tablas HTML se incluirán como imágenes directas"; \
	fi

# ===========================
# Generar PDF - A4 (Pantalla/E-book) - DEFAULT
# Produce: $(OUTPUT_DIR)/$(BOOK_NAME).pdf (sin sufijos)
# ===========================
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD_A4) $(ALL_PNG) $(TEMPLATE) $(METADATA_A4)
	@echo "📚 Generando PDF A4 (versión por defecto)..."
	@mkdir -p $(OUTPUT_DIR)
	pandoc $(COMBINED_MD_A4) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME).pdf \
		--from markdown \
		--metadata-file $(METADATA_A4) \
		--template $(TEMPLATE) \
		--pdf-engine=xelatex \
		--pdf-engine-opt=-shell-escape \
		--top-level-division="chapter" \
		--number-sections \
		--highlight-style tango \
		--listings \
		--shift-heading-level-by=0 \
		-V include-before='\input{frontmatter-a4.tex}' \
		--verbose
	@echo "✅ PDF A4 generado: $(OUTPUT_DIR)/$(BOOK_NAME).pdf"
	@ls -lh $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Nota: la variante de impresión A4 usa la versión por defecto

# ===========================
# Generar PDF - B5 (Impresión recomendada: 176×250mm)
# ===========================
$(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf: $(COMBINED_MD_B5) $(ALL_PNG) $(TEMPLATE) $(METADATA_B5)
	@echo "📚 Generando PDF B5 (impresión recomendada)..."
	@mkdir -p $(OUTPUT_DIR)
	pandoc $(COMBINED_MD_B5) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf \
		--from markdown \
		--metadata-file $(METADATA_B5) \
		--template $(TEMPLATE) \
		--pdf-engine=xelatex \
		--pdf-engine-opt=-shell-escape \
		--top-level-division="chapter" \
		--number-sections \
		--highlight-style tango \
		--listings \
		--shift-heading-level-by=0 \
		-V include-before='\input{frontmatter-b5.tex}' \
		--verbose
	@echo "✅ PDF B5 generado: $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf"
	@ls -lh $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf

## A5 target removed

# ===========================
# Primeras Páginas y Datos Editoriales
# ===========================

# Verificar qué datos faltan completar
check-datos:
	@echo "🔍 Verificando datos editoriales..."
	@chmod +x ./scripts/verificar_datos.sh
	@./scripts/verificar_datos.sh

# Editar archivo de datos editoriales
edit-datos:
	@echo "📝 Editando datos editoriales..."
	nano datos-editoriales.yaml

# Sincronizar datos desde datos-editoriales.yaml a metadata-*.yaml
sync-datos:
	@echo "🔄 Sincronizando datos editoriales a primeras páginas..."
	@chmod +x ./scripts/sync_datos.sh
	@./scripts/sync_datos.sh
	@echo ""
	@echo "✅ Datos sincronizados. Ahora ejecuta:"
	@echo "   make print-b5"

# Ver las primeras páginas del PDF generado
view-frontmatter: print-b5
	@echo "👁️  Abriendo las primeras páginas..."
	@if command -v evince >/dev/null 2>&1; then \
		evince $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf & \
	elif command -v okular >/dev/null 2>&1; then \
		okular $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf & \
	else \
		echo "📖 Abre manualmente: $(OUTPUT_DIR)/$(BOOK_NAME)-b5.pdf"; \
	fi

# Listar qué placeholders faltan completar
list-todos:
	@echo "📋 Placeholders pendientes:"
	@echo ""
	@echo "En metadata-b5.yaml:"
	@grep -n "COMPLETAR_CON" metadata-b5.yaml || echo "  ✓ Ninguno"
	@echo ""
	@echo "En datos-editoriales.yaml:"
	@grep -n "\[COMPLETAR_CON_" datos-editoriales.yaml | head -20 || echo "  ✓ Ninguno"

# ===========================
# Utilidades
# ===========================
debug: $(COMBINED_MD)
	@echo "🔍 Información de debugging:"
	@wc -l $(COMBINED_MD)
	@echo "📊 Diagrams: $(DIAGRAMS)"
	@echo "📊 Tablas: $(TABLES)"

clean:
	rm -f $(COMBINED_MD) $(COMBINED_MD_A4) $(COMBINED_MD_B5)
	rm -f pandoc.log
	rm -rf $(OUTPUT_DIR)
	rm -f $(PNG_DIAGRAMS) $(PNG_TABLES)
	@echo "🧹 Archivos temporales eliminados"

structure:
	@echo "📂 Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.latex" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" -o -name "*.mmd" -o -name "*.html" | sort
