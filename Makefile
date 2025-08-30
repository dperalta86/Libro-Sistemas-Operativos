.PHONY: all clean debug structure test-latex

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
PNG := $(DIAGRAMS:.mmd=.png)

all: setup $(OUTPUT_DIR)/$(BOOK_NAME).pdf

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
			echo "⚠️  Advertencia: $$capitulo no existe"; \
		fi \
	done
	@echo "📄 Archivo combinado generado: $(COMBINED_MD)"

# Renderizar diagramas Mermaid
$(PNG): %.png : %.mmd
	@echo "🖼️  Exportando diagrama Mermaid: $< → $@"
	@mkdir -p $(dir $@)
	mmdc -i $< -o $@ --backgroundColor white --theme neutral

# Generar PDF con mejor manejo de errores
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD) $(PNG) $(TEMPLATE)
	@echo "📚 Generando PDF..."
	@mkdir -p $(OUTPUT_DIR)
	@echo "🔧 Verificando template..."
	@if [ ! -f "$(TEMPLATE)" ]; then \
		echo "❌ Template no encontrado: $(TEMPLATE)"; \
		exit 1; \
	fi
	@echo "🔧 Ejecutando pandoc..."
	@mkdir -p $(OUTPUT_DIR)
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
	@echo "✅ PDF generado exitosamente: $(OUTPUT_DIR)/$(BOOK_NAME).pdf"
	@ls -lh $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Para debugging mejorado
debug: $(COMBINED_MD)
	@echo "🔍 Información de debugging:"
	@echo "📄 Archivo temporal generado: $(COMBINED_MD)"
	@wc -l $(COMBINED_MD)
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
	@echo "🧹 Archivos temporales eliminados"

# Mostrar estructura del proyecto
structure:
	@echo "📂 Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.latex" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" -o -name "*.mmd" | sort

# Llamamos al setup antes de compilar
setup:
	@chmod +x ./scripts/setup.sh
	./scripts/setup.sh