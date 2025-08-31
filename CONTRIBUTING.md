# 🤝 Guía de Contribución

¡Gracias por tu interés en contribuir a **Introducción a los Sistemas Operativos**! Este documento te guiará a través del proceso de contribución para mantener la calidad y consistencia del libro.

## 📚 Sobre el Proyecto

Este es un libro educativo sobre sistemas operativos, escrito en **Markdown** y compilado automáticamente a **PDF** usando GitHub Actions, Pandoc y LaTeX. El objetivo es crear un recurso accesible y de calidad para estudiantes y profesionales.

## 🎯 Tipos de Contribuciones Bienvenidas

### ✅ **Contenido**
- 📝 Correcciones de texto, gramática y ortografía
- 📖 Mejoras en explicaciones y ejemplos
- 🔍 Adición de referencias y bibliografía
- 💡 Nuevos ejercicios y casos prácticos
- 🖼️ Mejora de diagramas existentes

### ✅ **Estructura y Formato**
- 🎨 Mejoras en el formato y presentación
- 📊 Optimización de tablas y diagramas
- 🔧 Correcciones en la configuración de build
- 📱 Mejoras en la experiencia de lectura

### ❌ **No Aceptamos**
- Cambios fundamentales en la estructura sin discusión previa
- Contenido que no esté relacionado con sistemas operativos
- Modificaciones que rompan el proceso de compilación
- Plagio o contenido sin atribución adecuada

## 🚀 Proceso de Contribución

### 1. **Preparación**

#### Fork y Clone
```bash
# 1. Haz fork del repositorio desde GitHub

# 2. Clona tu fork
git clone https://github.com/TU_USUARIO/introduccion-sistemas-operativos.git
cd introduccion-sistemas-operativos

# 3. Configura el repositorio original como upstream
git remote add upstream https://github.com/dperalta86/introduccion-sistemas-operativos.git

# 4. Verifica la configuración
git remote -v
```

#### Instalar dependencias locales
```bash
# Para compilar localmente (opcional pero recomendado)
sudo apt-get install pandoc texlive-xetex texlive-latex-extra
npm install -g @mermaid-js/mermaid-cli

# Verificar que funciona
make debug
make all
```

### 2. **Crear Branch de Trabajo**

```bash
# Siempre crear una nueva branch desde main actualizado
git checkout main
git pull upstream main
git checkout -b tipo/descripcion-breve

# Ejemplos de nombres de branch:
git checkout -b content/mejorar-capitulo-memoria
git checkout -b fix/corregir-diagrama-procesos  
git checkout -b docs/actualizar-ejemplos-cap3
git checkout -b feature/agregar-ejercicios-praticos
```

### 3. **Realizar Cambios**

#### **📝 Para cambios de contenido:**
- Edita los archivos en `src/capitulo-XX.md`
- Sigue las [guías de estilo](./style/style_guide.md)
- Usa los [colores definidos](./style/color_template.md)
- Agrega diagramas en `src/diagrams/` si es necesario

#### **🖼️ Para diagramas:**
- Crea archivos `.mmd` en `src/diagrams/`
- Sigue las convenciones de naming: `capitulo-XX-nombre-descriptivo.mmd`
- Usa los colores del template

#### **🔧 Para cambios técnicos:**
- Modifica `Makefile`, `.github/workflows/`, o `templates/`
- Asegúrate de que el build local funcione antes de pushear

### 4. **Testing Local**

```bash
# Generar el archivo combinado para revisar
make debug

# Compilar PDF completo
make

# Verificar que no hay errores
make structure
```

### 5. **Commit y Push**

#### **Formato de commits:**
```bash
# Usar conventional commits
git commit -m "tipo(scope): descripción

Explicación más detallada si es necesario.

- Cambio específico 1
- Cambio específico 2"

# Ejemplos:
git commit -m "fix(cap3): corregir explicación de scheduling Round Robin"
git commit -m "feat(cap5): agregar ejemplos de deadlock"
git commit -m "docs(readme): actualizar instrucciones de instalación"
git commit -m "style(cap2): mejorar formato de tablas de comparación"
```

#### **Push de la branch:**
```bash
git push origin nombre-de-tu-branch
```

### 6. **Crear Pull Request**

1. **Ve a GitHub** y crea el PR desde tu branch
2. **Usa este template:**

```markdown
## 📋 Descripción

Breve descripción de los cambios realizados.

## 🎯 Tipo de cambio

- [ ] 🐛 Bug fix (corrección)
- [ ] ✨ Nueva funcionalidad
- [ ] 📚 Mejora de contenido
- [ ] 🎨 Cambios de estilo/formato
- [ ] 📖 Documentación
- [ ] 🔧 Cambios de configuración

## 📝 Cambios específicos

- Cambio 1
- Cambio 2
- Cambio 3

## ✅ Checklist

- [ ] He seguido las guías de estilo del proyecto
- [ ] He probado la compilación localmente
- [ ] Los diagramas se renderizan correctamente
- [ ] He revisado la ortografía y gramática
- [ ] El contenido es técnicamente correcto

## 📸 Screenshots/Evidencia (si aplica)

<!-- Agrega capturas si hiciste cambios visuales -->
```

### 7. **Proceso de Review**

- ✅ **Automated checks** deben pasar (workflow de build)
- ✅ **Code review** por el maintainer
- ✅ **Resolución de comentarios** si los hay
- ✅ **Merge** cuando todo esté listo

## 📖 Guías de Estilo y Formato

### **📁 Estructura de Archivos**
```
src/
├── capitulo-00.md          # Prólogo/Introducción
├── capitulo-01.md          # Capítulo 1
├── capitulo-XX.md          # Capítulos subsiguientes
└── diagrams/               # Diagramas Mermaid
    ├── capitulo-01-proceso.mmd
    └── capitulo-02-memoria.mmd

style/                      # Guías de formato
├── style_guide.md          # Guía de estilo general
└── color_template.md       # Paleta de colores

templates/
└── eisvogel.latex          # Template LaTeX

.github/
├── workflows/
│   └── build.yml          # Workflow de compilación  
└── CODEOWNERS             # Owners de archivos críticos
```

### **📝 Convenciones de Escritura**

#### **Formato de Títulos:**
```markdown
# Capítulo X: Nombre del Capítulo

## X.1 Sección Principal

### X.1.1 Subsección

#### Punto Específico
```

#### **Referencias:**
- 📚 **Libros:** [Título](URL) - Autor (Año)
- 🔗 **Links:** Usar texto descriptivo, no "click aquí"
- 📊 **Diagramas:** Siempre con caption descriptivo

#### **Código:**
```markdown
<!-- Bloques de código con lenguaje especificado -->
```c
#include <stdio.h>
int main() {
    printf("Hello, OS!\n");
    return 0;
}
```

<!-- Comandos inline -->
Usa el comando `ls -la` para listar archivos.
```

### **🎨 Guías de Estilo**

**👀 Ver documentación detallada:**
- 📋 [Guía de Estilo Completa](./style/style_guide.md)
- 🎨 [Template de Colores](./style/color_template.md)

**Puntos clave:**
- Usar **negritas** para conceptos importantes
- Usar `código inline` para comandos y nombres de archivos
- Usar > blockquotes para notas importantes

## 🔍 Review Checklist para Maintainers

### **Antes de aprobar un PR:**

#### **✅ Contenido**
- [ ] La información es técnicamente correcta
- [ ] Sigue las guías de estilo del proyecto
- [ ] Los ejemplos son claros y funcionales
- [ ] No hay errores ortográficos o gramaticales

#### **✅ Formato**
- [ ] Los títulos siguen la estructura correcta
- [ ] Los diagramas se renderizan correctamente
- [ ] El código está bien formateado
- [ ] Las referencias están completas

#### **✅ Técnico**
- [ ] El workflow de build pasa correctamente
- [ ] El PDF se genera sin errores
- [ ] No se rompió ninguna funcionalidad existente
- [ ] Los archivos siguen la estructura del proyecto

## 🚨 Resolución de Problemas Comunes

### **❌ Build fallido**
```bash
# Compilar localmente para debugging
make clean
make debug
make all

# Verificar errores en diagramas
mmdc -i src/diagrams/problema.mmd -o test.png
```

### **❌ Conflictos de merge**
```bash
# Actualizar branch con main
git checkout tu-branch
git fetch upstream
git rebase upstream/main

# Resolver conflictos manualmente
# Luego:
git add .
git rebase --continue
git push --force-with-lease origin tu-branch
```

### **❌ Formato inconsistente**
- Revisar `style/style_guide.md`
- Usar herramientas como `markdownlint` localmente
- Pedir ayuda en el PR si no estás seguro

## 📞 Contacto y Ayuda

- 🐛 **Reportar bugs:** Abre un Issue
- 💡 **Sugerir mejoras:** Abre un Issue con label "enhancement"  
- ❓ **Preguntas:** Comenta en Issues existentes o abre uno nuevo
- 📧 **Contacto directo:** dp25443@gmail.com (solo temas puntuales que no se puedan resolver en issues)

## 📜 Licencia

Al contribuir, aceptas que tus contribuciones serán licenciadas bajo la misma licencia que el proyecto.

---

¡Gracias por ayudar a mejorar este recurso educativo! 🎓
