.PHONY: all clean debug structure

# Configuración del libro
BOOK_NAME = Introduccion_a_los_Sistemas_Operativos
OUTPUT_DIR = build
SRC_DIR = src

# Lista de capítulos en orden (ajusta según tus archivos)
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

all: $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Generar archivo markdown combinado
$(COMBINED_MD): $(METADATA) $(CAPITULOS)
	@echo "Combinando archivos markdown..."
	@echo "---" > $(COMBINED_MD)
	@cat $(METADATA) >> $(COMBINED_MD)
	@echo "..." >> $(COMBINED_MD)
	@echo "" >> $(COMBINED_MD)
	@for capitulo in $(CAPITULOS); do \
		if [ -f "$$capitulo" ]; then \
			echo "Agregando $$capitulo..."; \
			echo "" >> $(COMBINED_MD); \
			cat "$$capitulo" >> $(COMBINED_MD); \
			echo "" >> $(COMBINED_MD); \
		else \
			echo "Advertencia: $$capitulo no existe"; \
		fi \
	done

# Lista todos los diagramas Mermaid
DIAGRAMS := $(wildcard src/diagrams/*.mmd)
PNG := $(DIAGRAMS:.mmd=.png)

$(PNG): %.png : %.mmd
	mmdc -i $< -o $@

# Generar PDF
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD) $(PNG) $(TEMPLATE)
	@echo "Generando PDF..."
	@mkdir -p $(OUTPUT_DIR)
	pandoc $(COMBINED_MD) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME).pdf \
		--from markdown \
		--template $(TEMPLATE) \
		--pdf-engine xelatex \
		--top-level-division="chapter" \
		--number-sections \
		--highlight-style tango \
		--listings \
		--shift-heading-level-by=0 \
		--verbose
	@echo "PDF generado exitosamente: $(OUTPUT_DIR)/$(BOOK_NAME).pdf"

# Para debugging - no borra el archivo temporal
debug: $(COMBINED_MD)
	@echo "Archivo temporal generado: $(COMBINED_MD)"
	@echo "Revisa su contenido antes de generar el PDF"
	@wc -l $(COMBINED_MD)

# Limpiar archivos temporales
clean:
	rm -f $(COMBINED_MD)
	rm -rf $(OUTPUT_DIR)
	@echo "Archivos temporales eliminados"

# Mostrar estructura del proyecto
structure:
	@echo "Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" | sort