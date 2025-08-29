# 📚 Libro de Sistemas Operativos

Un libro colaborativo de Sistemas Operativos diseñado específicamente para estudiantes de Ingeniería, con enfoque en evaluaciones teórico-prácticas y ejercicios tipo parcial.

## 🎯 Sobre este proyecto

Este libro surge de la necesidad de contar con material didáctico específico para la cátedra de Sistemas Operativos. Está orientado a estudiantes que cursan la materia y buscan:

- **Explicaciones didácticas** de conceptos complejos
- **Ejercicios resueltos paso a paso** similares a los de parciales
- **Código en C comentado** y funcional
- **Enfoque práctico** basado en sistemas Unix/Linux
- **Material libre** y accesible para todos

## 📖 Contenido

### Capítulos disponibles

- [x] **Capítulo 1**: Introducción a los Sistemas Operativos
- [x] **Capítulo 2**: Procesos
- [x] **Capítulo 3**: Planificación de Procesos
- [x] **Capítulo 4**: Hilos (Threads)
- [x] **Capítulo 5**: Sincronización

### En desarrollo

- [ ] **Capítulo 6**: Interbloqueo (Deadlock)
- [ ] **Capítulo 7**: Gestión de Memoria Real
- [ ] **Capítulo 8**: Memoria Virtual
- [ ] **Capítulo 9**: Sistema de Archivos

## 🚀 Descarga y uso

### 📥 Versión PDF compilada

[![📄 Descargar PDF](https://img.shields.io/github/v/release/dperalta86/Libro-Sistemas-Operativos?label=Descargar%20PDF&style=for-the-badge&color=blue)](https://github.com/dperalta86/Libro-Sistemas-Operativos/releases/latest/download/Introduccion_a_los_Sistemas_Operativos.pdf)

### Leer online

Puedes leer los capítulos individuales directamente en GitHub:
- [Capítulo 1: Introducción](docs/cap01-introduccion.md)
- [Capítulo 2: Procesos](docs/cap02-procesos.md)
- [Capítulo 3: Planificación](docs/cap03-planificacion.md)
- [Capítulo 4: Hilos](docs/cap04-hilos.md)
- [Capítulo 5: Sincronización](docs/cap05-sincronizacion.md)

## 🔧 Compilación local

Si querés compilar el libro localmente o contribuir:

### Prerequisitos

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install pandoc texlive-latex-recommended texlive-latex-extra make

# Instalar mermaid-cli para diagramas
npm install -g @mermaid-js/mermaid-cli
```

### Generar el libro

```bash
# Clonar el repositorio
git clone https://github.com/dperalta86/Libro-Sistemas-Operativos.git
cd Libro-Sistemas-Operativos

# Compilar PDF completo
make

# Ver otros targets disponibles
make help
```

El PDF generado estará en `build/Introduccion_a_los_Sistemas_Operativos.pdf`.

### Estructura del proyecto

```
libro-sistemas-operativos/
├── docs/                          # Capítulos en Markdown
│   ├── cap01-introduccion.md
│   ├── cap02-procesos.md
│   └── ...
├── diagrams/                      # Diagramas en Mermaid
│   ├── *.mmd
│   └── generated/                 # Imágenes generadas
├── build/                         # PDFs compilados
├── templates/                     # Plantillas Pandoc
├── Makefile                       # Automatización de build
├── LICENSE                        # Licencia MIT (código)
├── CONTENT_LICENSE               # Licencia CC BY-SA 4.0 (contenido)
└── README.md                     # Este archivo
```

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Este es un proyecto colaborativo para la comunidad estudiantil.

### Formas de contribuir

- **📝 Contenido**: Mejorar explicaciones, agregar ejemplos, corregir errores
- **🐛 Reportar errores**: Usar GitHub Issues para reportar problemas
- **💡 Sugerencias**: Proponer mejoras o nuevos enfoques
- **🎨 Diagramas**: Crear o mejorar diagramas y visualizaciones
- **📋 Ejercicios**: Agregar más ejercicios resueltos

### Proceso de contribución

1. **Fork** el repositorio
2. **Crea una rama** para tu contribución: `git checkout -b mejora/nuevo-contenido`
3. **Realiza tus cambios** siguiendo el estilo del libro
4. **Prueba la compilación**: `make`
5. **Envía un Pull Request** con descripción clara de los cambios

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para guías detalladas de estilo y contribución.

### Estilo y estructura

Cada capítulo sigue esta estructura:
- **Objetivos de aprendizaje**
- **Introducción y contexto**
- **Conceptos fundamentales**
- **Análisis técnico detallado**
- **Código en C comentado**
- **Casos de estudio y ejercicios**
- **Síntesis y puntos clave**

## 📄 Licencias

Este proyecto utiliza dos licencias diferentes:

### 🔧 Código del proyecto (MIT License)
Los scripts, Makefile, configuraciones y herramientas están bajo **MIT License**.
Ver [LICENSE](LICENSE) para detalles completos.

### 📖 Contenido educativo (CC BY-SA 4.0)
El contenido del libro (textos, ejercicios, diagramas) está bajo **Creative Commons Attribution-ShareAlike 4.0**.
Ver [CONTENT_LICENSE](CONTENT_LICENSE) para detalles completos.

**En resumen:**
- ✅ **Libre uso, modificación y distribución** del contenido
- ✅ **Reutilización del código** del proyecto
- ⚠️ **Atribución requerida** al redistribuir el contenido
- 🔄 **Derivados del contenido** deben mantener la misma licencia libre

## 🙏 Reconocimientos

### Autores principales
- **Daniel Peralta** - Fundador del proyecto e autor principal

### Contribuidores
Agradecimientos especiales a todos los que han contribuido:
- Ver la lista completa en [Contributors](https://github.com/dperalta86/Libro-Sistemas-Operativos/graphs/contributors)

### Material de referencia
- **Stallings, W.** - Operating Systems: Internals and Design Principles
- **Silberschatz, A.** - Operating System Concepts
- **Tanenbaum, A.S.** - Modern Operating Systems

## 💖 Apoyo al proyecto

Este libro es completamente **gratuito y libre**. Si te ha sido útil y querés apoyar su desarrollo continuo:

### Formas de apoyar
- ⭐ **Dale una estrella** al repositorio en GitHub
- 📢 **Comparte el libro** con otros estudiantes
- 🤝 **Contribuye** con contenido, correcciones o mejoras
- 🗣️ **Recomienda** el proyecto en tu facultad o grupos de estudio

### Donaciones voluntarias

Si el libro te ayudó a entender la materia o conseguir mejores notas, y querés hacer una contribución monetaria voluntaria para apoyar el desarrollo:

- ☕ **[Invitame un café](https://ko-fi.com/[tu-usuario])** - Ko-fi (Próximamente...)
- 💳 **[Donación única](https://paypal.me/[tu-paypal])** - PayPal (Próximamente...)
- 🇦🇷 **Transferencia/MP**: `dperalta86` (Argentina)

> 💡 **Importante**: Las donaciones son completamente voluntarias. El libro seguirá siendo libre y gratuito independientemente del apoyo económico recibido.

### ¿Para qué se usan las donaciones?

Las contribuciones ayudan a:
- 🖥️ Mantener la infraestructura del proyecto
- 📚 Adquirir material de referencia actualizado
- ☕ Motivar a los contribuidores con café durante las sesiones de escritura
- 🎨 Contratar diseñadores para mejorar diagramas y visualizaciones
- 📖 Imprimir copias físicas para bibliotecas de facultades

## 📊 Estadísticas del proyecto

![GitHub stars](https://img.shields.io/github/stars/dperalta86/Libro-Sistemas-Operativos?style=social)
![GitHub forks](https://img.shields.io/github/forks/dperalta86/Libro-Sistemas-Operativos?style=social)
![GitHub contributors](https://img.shields.io/github/contributors/dperalta86/Libro-Sistemas-Operativos)
![GitHub last commit](https://img.shields.io/github/last-commit/dperalta86/Libro-Sistemas-Operativos)
![PDF Build](https://img.shields.io/github/actions/workflow/status/dperalta86/Libro-Sistemas-Operativos/build.yml?label=PDF%20Build)

## 📞 Contacto

- **GitHub Issues**: Para reportes de errores y sugerencias
- **Email** (temas puntuales que no se puedan resolver en un issue): [dp25443@gmil.com]
- **X (Twitter)**: [@dperalta_ok](https://x.com/dperalta_ok)

---

<p align="center">
  <strong>Hecho con ❤️ por y para la comunidad estudiantil</strong><br>
  <em>¡Esperamos que este libro te ayude a dominar los Sistemas Operativos!</em>
</p>
