.PHONY: all clean debug structure test-latex tables setup install-deps fedora

# Configuración del libro
BOOK_NAME = Introduccion_a_los_Sistemas_Operativos
OUTPUT_DIR = build
SRC_DIR = src

# Lista de capítulos en orden
CAPITULOS = $(SRC_DIR)/capitulo-01.md \
$(SRC_DIR)/capitulo-02.md \
$(SRC_DIR)/capitulo-03.md \
$(SRC_DIR)/capitulo-04.md \
$(SRC_DIR)/capitulo-05.md \
$(SRC_DIR)/capitulo-06.md \
$(SRC_DIR)/capitulo-07.md \
$(SRC_DIR)/capitulo-08.md

# Archivos de configuración
METADATA = metadata.yaml
COMBINED_MD = libro-completo.md
TEMPLATE = templates/eisvogel.latex

# Diagramas Mermaid
DIAGRAMS := $(wildcard $(SRC_DIR)/diagrams/*.mmd)
PNG_DIAGRAMS := $(DIAGRAMS:.mmd=.png)

# Tablas HTML
TABLES := $(wildcard $(SRC_DIR)/tables/*.html)
PNG_TABLES := $(TABLES:.html=.png)

# Todas las imágenes
ALL_PNG := $(PNG_DIAGRAMS) $(PNG_TABLES)

# ===========================
# Target principal
# ===========================
all: setup $(OUTPUT_DIR)/$(BOOK_NAME).pdf

print: setup $(OUTPUT_DIR)/$(BOOK_NAME)_print.pdf

# ===========================
# Target especial Fedora
# ===========================
fedora:
	@echo "🐧 Configuración especial para Fedora..."
	@chmod +x ./scripts/setup_fedora.sh
	./scripts/setup_fedora.sh
	$(MAKE) all

# ===========================
# Dependencias básicas (comunes a todos)
# ===========================
install-deps:
	@echo "🔧 Verificando dependencias..."
	@command -v wkhtmltoimage >/dev/null 2>&1 || { \
		echo "❌ wkhtmltopdf no está instalado"; \
		echo "💡 Instalando wkhtmltopdf..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y wkhtmltopdf; \
		elif command -v yum >/dev/null 2>&1; then \
			sudo yum install -y wkhtmltopdf; \
		elif command -v dnf >/dev/null 2>&1; then \
			sudo dnf install -y wkhtmltopdf; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install wkhtmltopdf; \
		else \
			echo "❌ No se pudo instalar wkhtmltopdf automáticamente"; \
			exit 1; \
		fi; \
	}
	@command -v mmdc >/dev/null 2>&1 || { \
		echo "⚠️  mermaid-cli no está instalado (opcional para diagramas)"; \
		echo "💡 Para instalar: npm install -g @mermaid-js/mermaid-cli"; \
	}
	@echo "✅ Dependencias comunes verificadas"

# ===========================
# Generar archivo combinado
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

# ===========================
# Renderizar diagramas
# ===========================
$(PNG_DIAGRAMS): %.png : %.mmd
	@echo "🖼️  Exportando diagrama Mermaid: $< → $@"
	@mkdir -p $(dir $@)
	npx mmdc -i $< -o $@ --backgroundColor white --theme neutral

$(PNG_TABLES): %.png : %.html
	@echo "📊 Exportando tabla HTML: $< → $@"
	@mkdir -p $(dir $@)
	wkhtmltoimage --width 1200 --quality 100 $< $@

tables: install-deps $(PNG_TABLES)
	@echo "✅ Todas las tablas HTML convertidas a PNG"

# ===========================
# Generar PDF
# ===========================
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD) $(ALL_PNG) $(TEMPLATE)
	@echo "📚 Generando PDF (versión digital)..."
	@mkdir -p $(OUTPUT_DIR)
	pandoc $(COMBINED_MD) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME).pdf \
		--from markdown \
		--template $(TEMPLATE) \
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

# ===========================
# Utilidades
# ===========================
debug: $(COMBINED_MD)
	@echo "🔍 Información de debugging:"
	@wc -l $(COMBINED_MD)
	@echo "📊 Diagrams: $(DIAGRAMS)"
	@echo "📊 Tablas: $(TABLES)"

clean:
	rm -f $(COMBINED_MD)
	rm -f pandoc.log
	rm -rf $(OUTPUT_DIR)
	rm -f $(PNG_DIAGRAMS) $(PNG_TABLES)
	@echo "🧹 Archivos temporales eliminados"

structure:
	@echo "📂 Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.latex" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" -o -name "*.mmd" -o -name "*.html" | sort
