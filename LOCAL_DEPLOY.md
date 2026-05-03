# Compilacion local

Guia rapida para generar el libro en local con los targets actuales del Makefile.

## 1) Clonar y entrar al proyecto

```bash
git clone https://github.com/dperalta86/Libro-Sistemas-Operativos.git
cd Libro-Sistemas-Operativos
```

## 2) Instalar dependencias

### Ubuntu/Debian (minimo)

```bash
sudo apt update
sudo apt install -y make pandoc texlive-xetex texlive-latex-recommended texlive-latex-extra
```

### Diagramas Mermaid (recomendado)

```bash
npm install -g @mermaid-js/mermaid-cli
```

### Script de ayuda (opcional)

```bash
./scripts/setup_minimalista.sh
```

En Fedora hay setup dedicado:

```bash
make fedora
```

## 3) Verificar entorno

```bash
make install-deps
```

## 4) Generar PDFs

### A4 digital

```bash
make all
```

Salida:

- build/Introduccion_a_los_Sistemas_Operativos-a4.pdf

### B5 imprenta (recomendado)

```bash
make print
```

O explicito:

```bash
make print-b5
```

Salida:

- build/Introduccion_a_los_Sistemas_Operativos-b5.pdf

### A4 imprenta

```bash
make print-a4
```

Salida:

- build/Introduccion_a_los_Sistemas_Operativos-a4-print.pdf

### A5 compacto

```bash
make print-a5
```

Salida:

- build/Introduccion_a_los_Sistemas_Operativos-a5.pdf

### Todos los formatos

```bash
make print-all
```

## 5) Datos editoriales (ISBN, deposito legal, etc.)

```bash
make check-datos
make edit-datos
make sync-datos
```

Sugerencia de flujo:

1. Revisar faltantes con make check-datos.
2. Completar datos en datos-editoriales.yaml con make edit-datos.
3. Sincronizar a metadata con make sync-datos.
4. Regenerar B5 con make print-b5.

## 6) Utilidades

```bash
# Ver placeholders pendientes
make list-todos

# Abrir PDF con foco en primeras paginas (genera B5 si hace falta)
make view-frontmatter

# Limpiar archivos generados
make clean
```

## 7) Resolucion de problemas rapida

- Si fallan diagramas Mermaid, ejecutar:

```bash
make fix-mermaid
```

- Si falta Chromium para mermaid-cli, instalar chromium-browser o seguir las sugerencias que imprime make.
- Si falta xelatex/pandoc, volver a correr install-deps y revisar salida.
