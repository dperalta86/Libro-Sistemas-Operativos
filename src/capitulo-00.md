# Introducción

Bienvenido a **Introducción a los Sistemas Operativos**, un libro colaborativo diseñado específicamente para estudiantes de Ingeniería que enfrentan una de las materias más desafiantes y fascinantes de su carrera.


### ¿Qué vas a encontrar en este libro?

Este no es otro "manual básico" de sistemas operativos. Es un material didáctico creado con un enfoque práctico que combina:

**Rigor Académico sin Complejidad Innecesaria**
- Conceptos explicados desde lo concreto hacia lo abstracto
- Definiciones teóricas con ejemplos reales
- Conexiones claras entre teoría y práctica

**Código C Funcional y Comentado**
- Implementaciones reales de conceptos teóricos
- Syscalls de Unix/Linux explicadas línea por línea
- Ejemplos que puedes compilar y ejecutar

**Preparación Específica para Evaluaciones**
- Ejercicios tipo parcial resueltos paso a paso
- Casos de estudio basados en evaluaciones reales
- Tips y errores comunes identificados por la cátedra

**Enfoque Iterativo y Conectado**
- Cada capítulo se conecta con los anteriores y posteriores
- Síntesis que preparan para temas siguientes
- Visión integral del sistema operativo como un todo

### Metodología de Estudio Sugerida

Cada capítulo sigue una estructura pensada para maximizar tu aprendizaje:

1. **Lee los Objetivos** - Para saber exactamente qué vas a aprender
2. **Entiende el Contexto** - Por qué existe este tema, qué problema resuelve
3. **Domina los Conceptos** - Base teórica sólida
4. **Analiza la Técnica** - Cómo se implementa realmente
5. **Programa y Experimenta** - Código funcional para probar
6. **Practica con Casos Reales** - Ejercicios tipo parcial
7. **Sintetiza y Conecta** - Integra con el panorama completo


> **Licencia y Filosofía Colaborativa**
> 
> Este libro se distribuye bajo **Creative Commons BY-SA 4.0**, lo que significa que es libre de usar, modificar y redistribuir. Es un proyecto creado dentro de la comunidad académica para la comunidad académica.
Podés reutilizarlo, modificarlo, distribuirlo sin ningún problea de copy. Encontrá el detalle de la licencia en: https://creativecommons.org/licenses/by-sa/4.0/
<br>

## Introducción a los Sistemas Operativos

### ¿Qué es realmente un Sistema Operativo?

Imagina que acabas de comprar una computadora nueva. La conectas, la prendes y... ¿qué esperas ver? No circuitos ni señales eléctricas, sino una interfaz que te permita ejecutar programas, crear archivos, conectarte a internet. Esa "magia" que transforma el hardware crudo en una máquina útil es el **sistema operativo**.

Un sistema operativo es, fundamentalmente, un **programa que administra recursos**. Pero no es cualquier programa: es el programa más privilegiado de tu computadora, el único con acceso directo al hardware, y el responsable de que todos los demás programas funcionen de manera ordenada y eficiente.

### Los Cuatro Pilares Fundamentales

Todo sistema operativo moderno se construye sobre cuatro pilares fundamentales:

**1. Gestión de Procesos**
¿Cómo puede tu computadora ejecutar el navegador, el reproductor de música y el editor de texto "al mismo tiempo" si solo tiene una CPU? La respuesta está en la gestión de procesos: crear, programar, coordinar y terminar los programas en ejecución.

**2. Gestión de Memoria** 
Con múltiples programas ejecutándose, ¿cómo se decide quién usa qué porción de memoria? ¿Qué pasa cuando se agota? El SO debe distribuir, proteger y optimizar el uso de este recurso crítico.

**3. Gestión de Almacenamiento**
Desde guardar un documento hasta instalar un programa, el SO debe organizar información en dispositivos permanentes, crear abstracciones como "archivos" y "directorios", y garantizar la integridad de los datos.

**4. Gestión de E/S y Comunicación**
Teclado, mouse, pantalla, red, impresora... El SO debe manejar la increíble diversidad de dispositivos y permitir que los programas se comuniquen entre sí y con el mundo exterior.

### ¿Por qué es tan Complejo?

Los sistemas operativos enfrentan desafíos únicos en la computación:

**Concurrencia**: Múltiples actividades simultáneas que pueden interferir entre sí  
**Recursos Limitados**: CPU, memoria, almacenamiento, ancho de banda tienen límites físicos  
**Heterogeneidad**: Hardware diverso, aplicaciones con necesidades diferentes  
**Confiabilidad**: Un error puede afectar todo el sistema  
**Seguridad**: Proteger datos y recursos de accesos no autorizados  
**Rendimiento**: Optimizar para velocidad, eficiencia energética, capacidad de respuesta  

### El Enfoque Unix/Linux

Este libro se centra en sistemas Unix/Linux, no por preferencia ideológica, sino por razones pedagógicas:

- **Transparencia**: El código fuente está disponible para estudiar
- **Simplicidad Conceptual**: Filosofía "cada cosa hace una cosa bien"
- **Estándares Abiertos**: POSIX, System V, BSD proporcionan marcos de referencia
- **Relevancia Industrial**: Domina servidores, sistemas embebidos, supercomputadoras
- **Herramientas de Desarrollo**: Ambiente ideal para programación en C

### Resumen y Hoja de Ruta

En este libro recorreremos el sistema operativo desde sus cimientos hasta sus aspectos más sofisticados:

**Fundamentos (Caps. 1-2)**: Arquitectura de computadores, concepto de proceso
**Concurrencia (Caps. 3-6)**: Planificación, hilos, sincronización, interbloqueos  
**Memoria (Caps. 7-8)**: Gestión de memoria real y virtual  
**Almacenamiento (Cap. 9)**: Sistemas de archivos  

Cada tema se construye sobre los anteriores, formando una comprensión integral de cómo funciona realmente el software más importante de tu computadora.
