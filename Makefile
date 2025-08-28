.PHONY: all clean debug install-template check-template install-template-manual

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

all: $(OUTPUT_DIR)/$(BOOK_NAME).pdf

# Instalar plantilla Eisvogel (ejecutar una sola vez)
install-template:
	@echo "Limpiando instalaciones previas..."
	rm -f ~/.pandoc/templates/eisvogel.latex
	rm -f eisvogel.tar.gz eisvogel.latex Eisvogel-*.tar.gz
	@echo "Descargando plantilla Eisvogel (método 1)..."
	curl -L -o eisvogel.tar.gz "https://github.com/Wandmalfarbe/pandoc-latex-template/releases/download/v2.4.2/Eisvogel-2.4.2.tar.gz" || \
	(echo "Método 1 falló, probando método 2..." && \
	 wget -O eisvogel.tar.gz "https://github.com/Wandmalfarbe/pandoc-latex-template/releases/download/v2.4.2/Eisvogel-2.4.2.tar.gz") || \
	(echo "Método 2 falló, probando descarga directa..." && \
	 curl -L -o eisvogel.latex "https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template/v2.4.2/eisvogel.latex")
	@echo "Verificando descarga..."
	@if [ -f eisvogel.latex ]; then \
		echo "Descarga directa exitosa"; \
		mkdir -p ~/.pandoc/templates; \
		cp eisvogel.latex ~/.pandoc/templates/; \
	elif [ -f eisvogel.tar.gz ] && [ $(stat -f%z eisvogel.tar.gz 2>/dev/null || stat -c%s eisvogel.tar.gz 2>/dev/null || echo 0) -gt 1000 ]; then \
		echo "Extrayendo archivo..."; \
		tar -xzf eisvogel.tar.gz; \
		mkdir -p ~/.pandoc/templates; \
		cp eisvogel.latex ~/.pandoc/templates/; \
	else \
		echo "Error en la descarga. Instalación manual:"; \
		echo "1. Ve a https://github.com/Wandmalfarbe/pandoc-latex-template/releases"; \
		echo "2. Descarga Eisvogel-2.4.2.tar.gz"; \
		echo "3. Extrae eisvogel.latex"; \
		echo "4. Copia a ~/.pandoc/templates/eisvogel.latex"; \
		exit 1; \
	fi
	@echo "Limpiando archivos temporales..."
	rm -f eisvogel.tar.gz eisvogel.latex Eisvogel-*.tar.gz
	@echo "Plantilla Eisvogel instalada correctamente en ~/.pandoc/templates/"
	@echo "Verificando instalación..."
	ls -la ~/.pandoc/templates/eisvogel.latex

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
$(OUTPUT_DIR)/$(BOOK_NAME).pdf: $(COMBINED_MD) $(PNG)
	@echo "Generando PDF..."
	@mkdir -p $(OUTPUT_DIR)
	pandoc $(COMBINED_MD) \
		-o $(OUTPUT_DIR)/$(BOOK_NAME).pdf \
		--from markdown \
		--template eisvogel \
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

# Instalación manual simple de Eisvogel
install-template-manual:
	@echo "Instalación manual de plantilla Eisvogel..."
	@echo "Descargando archivo LaTeX directamente..."
	mkdir -p ~/.pandoc/templates
	curl -L -o ~/.pandoc/templates/eisvogel.latex "https://raw.githubusercontent.com/Wandmalfarbe/pandoc-latex-template/v2.4.2/eisvogel.latex"
	@echo "Verificando instalación..."
	ls -la ~/.pandoc/templates/eisvogel.latex
	@echo "¡Listo! Plantilla instalada correctamente."

# Verificar si la plantilla está correctamente instalada
check-template:
	@echo "Verificando instalación de plantilla Eisvogel..."
	@if [ -f ~/.pandoc/templates/eisvogel.latex ]; then \
		echo "✓ Plantilla encontrada en ~/.pandoc/templates/eisvogel.latex"; \
		echo "Tamaño del archivo:"; \
		ls -lh ~/.pandoc/templates/eisvogel.latex; \
	else \
		echo "✗ Plantilla NO encontrada. Ejecuta: make install-template"; \
	fi
	@echo ""
	@echo "Plantillas disponibles en Pandoc:"
	pandoc --list-templates 2>/dev/null | grep eisvogel || echo "eisvogel no encontrada en la lista"

# Mostrar estructura del proyecto
structure:
	@echo "Estructura actual del proyecto:"
	@find . -name "*.md" -o -name "*.yaml" -o -name "*.jpeg" -o -name "*.jpg" -o -name "*.png" | sort