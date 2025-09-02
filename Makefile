.PHONY: all clean debug structure test-latex tables setup install-deps

# Configuración del libro
BOOK_NAME = Introduccion_a_los_Sistemas_Operativos
OUTPUT_DIR = build
SRC_DIR = src

# Lista de capítulos en orden
CAPITULOS = $(SRC_DIR)/capitulo-00.md \
$(SRC_DIR)/capitulo-01.md \
$(SRC_DIR)/capitulo-02.md \
$(SRC_DIR)/capitulo-03.md \
$(SRC_DIR)/capitulo-04.md \
$(SRC_DIR)/capitulo-05.md

# Archivos de configuración
METADATA = metadata.yaml
COMBINED_MD = libro-completo.md
TEMPLATE = templates/eisvogel.latex

# Lista todos los diagramas Mermaid
DIAGRAMS := $(wildcard $(SRC_DIR)/diagrams/*.mmd)
PNG_DIAGRAMS := $(DIAGRAMS:.mmd=.png)

# Lista todas las tablas HTML
TABLES := $(wildcard $(SRC_DIR)/tables/*.html)
PNG_TABLES := $(TABLES:.html=.png)

# Todas las imágenes PNG (diagramas + tablas)
ALL_PNG := $(PNG_DIAGRAMS) $(PNG_TABLES)

# Target principal - versión digital (pantalla)
all: setup $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Target para versión de impresión
print: setup $(OUTPUT_DIR)/$(BOOK_NAME)_print.pdf

# Verificar e instalar dependencias
install-deps:
	@echo "🔧 Verificando dependencias..."
	@command -v wkhtmltoimage >/dev/null 2>&1 || { \
		echo "❌ wkhtmltopdf no está instalado"; \
		echo "💡 Instalando wkhtmltopdf..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y wkhtmltopdf; \
		elif command -v yum >/dev/null 2>&1; then \
			sudo yum install -y wkhtmltopdf; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install wkhtmltopdf; \
		else \
			echo "❌ No se pudo instalar wkhtmltopdf automáticamente"; \
			echo "   Por favor instálalo manualmente según tu sistema operativo"; \
			exit 1; \
		fi; \
	}
	@command -v mmdc >/dev/null 2>&1 || { \
		echo "⚠️  mermaid-cli no está instalado (opcional para diagramas)"; \
		echo "💡 Para instalar: npm install -g @mermaid-js/mermaid-cli"; \
	}
	sudo apt install fonts-ibm-plex
	sudo apt install fonts-jetbrains-mono
	@echo "✅ Dependencias verificadas"

# Generar archivo markdown combinado
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

# Renderizar diagramas Mermaid
$(PNG_DIAGRAMS): %.png : %.mmd
	@echo "🖼️  Exportando diagrama Mermaid: $< → $@"
	@mkdir -p $(dir $@)
	@command -v mmdc >/dev/null 2>&1 || { \
		echo "❌ mermaid-cli no está instalado. Instalando..."; \
		npm install -g @mermaid-js/mermaid-cli; \
	}
	mmdc -i $< -o $@ --backgroundColor white --theme neutral

# Convertir tablas HTML a PNG
$(PNG_TABLES): %.png : %.html
	@echo "📊 Exportando tabla HTML: $< → $@"
	@mkdir -p $(dir $@)
	wkhtmltoimage --width 1200 --quality 100 $< $@

# Target para generar todas las tablas
tables: install-deps $(PNG_TABLES)
	@echo "✅ Todas las tablas HTML convertidas a PNG"

# Generar PDF versión digital (pantalla)
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD) $(ALL_PNG) $(TEMPLATE)
	@echo "📚 Generando PDF (versión digital)..."
	@mkdir -p $(OUTPUT_DIR)
	@echo "🔧 Verificando template..."
	@if [ ! -f "$(TEMPLATE)" ]; then \
		echo "❌ Template no encontrado: $(TEMPLATE)"; \
		exit 1; \
	fi
	@echo "🔧 Ejecutando pandoc..."
	pandoc $(COMBINED_MD) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME).pdf \
		--from markdown \
		--template templates/eisvogel.latex \
		--pdf-engine=xelatex \
		--pdf-engine-opt=-shell-escape \
		--top-level-division="chapter" \
		--number-sections \
		--highlight-style tango \
		--listings \
		--shift-heading-level-by=0 \
		--verbose
	@echo "✅ PDF digital generado: $(OUTPUT_DIR)/$(BOOK_NAME).pdf"
	@ls -lh $(OUTPUT_DIR)/$(BOOK_NAME).pdf


# Para debugging
debug: $(COMBINED_MD)
	@echo "🔍 Información de debugging:"
	@echo "📄 Archivo temporal generado: $(COMBINED_MD)"
	@wc -l $(COMBINED_MD)
	@echo "📊 Diagrams encontrados: $(DIAGRAMS)"
	@echo "📊 Tablas encontradas: $(TABLES)"
	@echo "📊 PNGs de diagramas: $(PNG_DIAGRAMS)"
	@echo "📊 PNGs de tablas: $(PNG_TABLES)"
	@echo "📊 Primeras 20 líneas del archivo combinado:"
	@head -20 $(COMBINED_MD)
	@echo "📊 Últimas 10 líneas del archivo combinado:"
	@tail -10 $(COMBINED_MD)

# Limpiar archivos temporales
clean:
	rm -f $(COMBINED_MD)
	rm -f pandoc.log
	rm -rf $(OUTPUT_DIR)
	rm -f test.*
	rm -f $(PNG_DIAGRAMS)
	rm -f $(PNG_TABLES)
	@echo "🧹 Archivos temporales eliminados"

# Mostrar estructura del proyecto
structure:
	@echo "📂 Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.latex" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" -o -name "*.mmd" -o -name "*.html" | sort
	@echo ""
	@echo "📊 Estadísticas:"
	@echo "   • Capítulos: $(words $(CAPITULOS))"
	@echo "   • Diagramas Mermaid: $(words $(DIAGRAMS))"
	@echo "   • Tablas HTML: $(words $(TABLES))"

# Llamamos al setup antes de compilar
setup: install-deps
	@chmod +x ./scripts/setup.sh
	./scripts/setup.sh