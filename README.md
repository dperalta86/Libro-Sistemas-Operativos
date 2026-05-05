# Introducción a los Sistemas Operativos

> Fundamentos teóricos, ejercicios y código de ejemplo en C  
> Diseñado para estudiantes de Ingeniería que quieren entender los Sistemas Operativos — no solo aprobar.

**Daniel Isaías Peralta** · 1ª edición, mayo 2026 · ISBN 978-631-01-5312-4

---

## Descargar

[![📄 Descargar PDF](https://img.shields.io/github/v/release/dperalta86/Libro-Sistemas-Operativos?label=Descargar%20PDF&style=for-the-badge&color=blue)](https://github.com/dperalta86/Libro-Sistemas-Operativos/releases/latest/download/Introduccion_a_los_Sistemas_Operativos.pdf)

El libro es **gratuito y libre**. La descarga no requiere registro ni suscripción.  
Sitio web del libro: [dperalta.com.ar/pages/introduccion-a-los-sistemas-operativos.html](https://www.dperalta.com.ar/pages/introduccion-a-los-sistemas-operativos.html)

---

## Sobre el libro

Este material nace en el contexto de la materia **Sistemas Operativos** de la carrera de
Ingeniería en Sistemas de Información (UTN-FRBA), con el objetivo de cubrir un vacío real:
libros de referencia en inglés o apuntes fragmentados, pero poco material en español que
combine teoría rigurosa, código funcional y preparación concreta para evaluaciones.

> **Nota:** Este es un material de elaboración independiente. No constituye material oficial
> de la cátedra ni de la Universidad Tecnológica Nacional — FRBA.

**Qué encontrás en el libro:**

- Conceptos explicados desde lo concreto hacia lo abstracto
- Código C funcional y comentado — compilable, ejecutable, experimentable
- Syscalls de Unix/Linux explicadas línea por línea
- Ejercicios tipo parcial resueltos paso a paso
- Síntesis al final de cada capítulo para conectar los temas

**Datos editoriales:**

| | |
|---|---|
| Autor | Daniel Isaías Peralta |
| Edición | 1ª ed. — Longchamps, 2026 |
| ISBN | 978-631-01-5312-4 |
| Licencia contenido | CC BY-SA 4.0 |
| Licencia código | MIT |
| Formato | Libro digital, PDF |

---

## Contenido

- [Capítulo 1 — Repaso Arquitectura de Computadores](src/capitulo-01.md)
- [Capítulo 2 — Fundamentos de los Sistemas Operativos](src/capitulo-02.md)
- [Capítulo 3 — Procesos](src/capitulo-03.md)
- [Capítulo 4 — Planificación de Procesos](src/capitulo-04.md)
- [Capítulo 5 — Hilos (Threads)](src/capitulo-05.md)
- [Capítulo 6 — Sincronización](src/capitulo-06.md)
- [Capítulo 7 — Interbloqueo (Deadlock)](src/capitulo-07.md)
- [Capítulo 8 — Gestión de Memoria Real](src/capitulo-08.md)
- [Capítulo 9 — Gestión de Memoria Virtual](src/capitulo-09.md)
- [Capítulo 10 — Sistema de Archivos (File System)](src/capitulo-10.md)
- [Capítulo 11 — I/O — Gestión de Dispositivos](src/capitulo-11.md)

---

## Compilación local

```bash
# Ubuntu/Debian — versión digital (A4)
make all

# Versión de imprenta recomendada (B5)
make print

# Todos los formatos
make print-all
```

PDFs generados en `build/`:

- `build/Introduccion_a_los_Sistemas_Operativos-a4.pdf`
- `build/Introduccion_a_los_Sistemas_Operativos-b5.pdf`
- `build/Introduccion_a_los_Sistemas_Operativos-a5.pdf`

Para instalación, dependencias y flujo completo: [LOCAL_DEPLOY.md](LOCAL_DEPLOY.md)

---

## Contribuir

Las contribuciones son bienvenidas. Este es un proyecto colaborativo y abierto.

**Formas de contribuir:**

- **Contenido** — mejorar explicaciones, agregar ejemplos, corregir errores
- **Erratas** — abrir un [issue](https://github.com/dperalta86/Libro-Sistemas-Operativos/issues)
- **Diagramas** — crear o mejorar visualizaciones
- **Ejercicios** — agregar casos resueltos

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para guías de estilo y flujo de trabajo.  
Canal principal de discusión: [GitHub Discussions](https://github.com/dperalta86/Libro-Sistemas-Operativos/discussions)

---

## Licencias

| Componente | Licencia |
|---|---|
| Contenido del libro (textos, ejercicios, diagramas) | [CC BY-SA 4.0](CONTENT_LICENSE) |
| Código del proyecto (scripts, Makefile, configuraciones) | [MIT](LICENSE) |

El contenido puede ser compartido, copiado y adaptado libremente, siempre que se cite al
autor y los trabajos derivados mantengan la misma licencia.

---

## Reconocimientos

**Autor principal:** Daniel Peralta — fundador del proyecto.

**Contribuidores:** ver la lista completa en
[Contributors](https://github.com/dperalta86/Libro-Sistemas-Operativos/graphs/contributors).

**Material de referencia:**

- Stallings, W. — *Operating Systems: Internals and Design Principles*
- Silberschatz, A. — *Operating System Concepts*
- Tanenbaum, A.S. — *Modern Operating Systems*

---

## Estadísticas

![GitHub stars](https://img.shields.io/github/stars/dperalta86/Libro-Sistemas-Operativos?style=social)
![GitHub forks](https://img.shields.io/github/forks/dperalta86/Libro-Sistemas-Operativos?style=social)
![GitHub contributors](https://img.shields.io/github/contributors/dperalta86/Libro-Sistemas-Operativos)
![GitHub last commit](https://img.shields.io/github/last-commit/dperalta86/Libro-Sistemas-Operativos)
![Downloads](https://img.shields.io/github/downloads/dperalta86/Libro-Sistemas-Operativos/total?style=flat-square&label=Descargas%20totales)

---

## Apoyar el proyecto

El libro es y seguirá siendo gratuito. Si te resultó útil:

- ⭐ Dale una estrella al repositorio
- 📢 Compartilo con tus compañeros
- 🤝 Sumate como contribuidor

Si además querés hacer una contribución monetaria voluntaria:

- ☕ [Ko-fi](https://ko-fi.com/dperalta86)
- 💳 [PayPal](https://paypal.me/dperalta86)
- 🇦🇷 Transferencia / Mercado Pago: `dperalta86`

---

<p align="center">
  Hecho con ❤️ por y para la comunidad estudiantil<br>
  <em>¡Esperamos que este libro te ayude a dominar los Sistemas Operativos!</em>
</p>