# Introducción

Bienvenido a **Introducción a los Sistemas Operativos**, un libro colaborativo diseñado específicamente para estudiantes de Ingeniería que enfrentan una de las materias más desafiantes y fascinantes de su carrera.  

## ¿Qué vas a encontrar en este libro?

Este no es otro "manual básico" de sistemas operativos. Es un material didáctico creado con un enfoque práctico que busca conectar la teoría rigurosa con la implementación real. A lo largo de estos capítulos, vas a encontrar conceptos explicados desde lo concreto hacia lo abstracto, porque creemos que es más fácil entender una abstracción cuando primero viste cómo funciona en la práctica.

El libro combina rigor académico sin caer en complejidad innecesaria. Cada definición teórica viene acompañada de ejemplos reales, y las conexiones entre teoría y práctica están explícitamente señaladas. No asumimos que "ya lo sabés" ni que "es obvio", porque sabemos que estos temas son densos y merecen explicaciones claras.

Vas a encontrar código C funcional y comentado en detalle. No son pseudocódigos ni ejemplos simplificados que "casi funcionan". Son implementaciones reales que podés compilar, ejecutar y experimentar. Las syscalls de Unix/Linux están explicadas línea por línea, porque creemos que la mejor forma de entender un sistema operativo es viendo cómo se programa contra él.

\begin{infobox}
Este libro también incluye preparación específica para evaluaciones. Los ejercicios tipo parcial están resueltos paso a paso, con casos de estudio basados en evaluaciones reales. Además, señalamos explícitamente los errores comunes que la cátedra ha identificado en años anteriores.
\end{infobox}

El enfoque es iterativo y conectado: cada capítulo se construye sobre los anteriores y prepara el terreno para los siguientes. Al final de cada tema, hay síntesis que te ayudan a conectar lo que acabás de aprender con lo que viene. La idea es que desarrolles una visión integral del sistema operativo como un todo coherente, no como una colección de temas inconexos.

## Metodología de Estudio Sugerida

Cada capítulo está estructurado de forma deliberada para maximizar tu aprendizaje. Te recomendamos seguir este flujo:

Comenzá leyendo los objetivos del capítulo para saber exactamente qué vas a aprender y por qué es importante. Después, entrá al contexto: entender por qué existe un tema, qué problema resuelve, es fundamental para que los detalles técnicos tengan sentido.

Una vez que tenés el panorama general, dominá los conceptos con la base teórica sólida que presentamos. No saltes esta parte pensando que "ya después lo entendés con el código". La teoría te da el marco conceptual que hace que el código sea comprensible.

Luego analizá la técnica: cómo se implementa realmente lo que acabás de aprender en teoría. Acá es donde conectamos conceptos abstractos con decisiones concretas de implementación. Después, programá y experimentá con el código funcional que proporcionamos. No te limites a leerlo; modificalo, rompelo, arreglalo. Esa experimentación activa es donde realmente se consolida el aprendizaje.

Finalmente, practicá con casos reales usando los ejercicios tipo parcial que incluimos, y hacé la síntesis final integrando todo con el panorama completo del sistema operativo.

\begin{excerpt}
\textbt{Licencia y Filosofía Colaborativa}
Este libro se distribuye bajo Creative Commons BY-SA 4.0, lo que significa que es libre de usar, modificar y redistribuir. Es un proyecto creado dentro de la comunidad académica para la comunidad académica. Podés reutilizarlo, modificarlo, distribuirlo sin ningún problema de copyright. Encontrá el detalle de la licencia en: https://creativecommons.org/licenses/by-sa/4.0/
\end{excerpt}

## Introducción a los Sistemas Operativos

### ¿Qué es realmente un Sistema Operativo?

Imagina que acabás de comprar una computadora nueva. La conectás, la prendés y... ¿qué esperás ver? No circuitos ni señales eléctricas, sino una interfaz que te permita ejecutar programas, crear archivos, conectarte a internet. Esa "magia" que transforma el hardware crudo en una máquina útil es el **sistema operativo**.

Pero esta descripción, aunque intuitiva, se queda corta. Un sistema operativo es fundamentalmente un *programa que administra recursos*, pero no es cualquier programa: es el programa más privilegiado de tu computadora, el único con acceso directo al hardware, y el responsable de que todos los demás programas funcionen de manera ordenada y eficiente.

Pensá en el sistema operativo como el gerente de un edificio de oficinas. No hace el trabajo de cada inquilino, pero coordina quién usa qué oficina, cuándo se pueden usar las salas de reuniones, cómo se distribuye la electricidad, y resuelve conflictos cuando dos inquilinos quieren usar el mismo recurso. Sin ese gerente, tendrías el caos: oficinas duplicadas, cortes de luz, reuniones interrumpiéndose mutuamente.

### Los Cuatro Pilares Fundamentales

Todo sistema operativo moderno, desde el que corre en tu teléfono hasta el que controla supercomputadoras, se construye sobre cuatro pilares fundamentales. Entender estos pilares es entender la esencia de lo que hace un sistema operativo.

El primer pilar es la **gestión de procesos**. ¿Cómo puede tu computadora ejecutar el navegador, el reproductor de música y el editor de texto "al mismo tiempo" si solo tiene una CPU? La respuesta está en la capacidad del sistema operativo de crear procesos, programar su ejecución, coordinar su interacción y terminarlos cuando ya no son necesarios. Esta ilusión de simultaneidad es uno de los trucos más elegantes de la computación moderna.

\begin{highlight}
Un proceso es un programa en ejecución. No es solo el código, sino también el estado completo de esa ejecución: variables, memoria asignada, archivos abiertos, posición en el código. El sistema operativo mantiene toda esta información y la restaura cada vez que le toca el turno al proceso.
\end{highlight}

El segundo pilar es la **gestión de memoria**. Con múltiples programas ejecutándose, ¿cómo se decide quién usa qué porción de memoria? ¿Qué pasa cuando se agota? ¿Cómo evitamos que un programa corrupto escriba en la memoria de otro? El sistema operativo debe distribuir este recurso crítico, protegerlo contra accesos indebidos, y optimizar su uso para que el sistema completo funcione eficientemente.

La gestión de memoria no es trivial: involucra crear abstracciones que hagan que cada programa "piense" que tiene toda la memoria para sí mismo, mapear direcciones virtuales a físicas, decidir qué hacer cuando la memoria se agota, y mantener todo esto funcionando a velocidades que no degraden el rendimiento general del sistema.

El tercer pilar es la **gestión de almacenamiento**. Desde guardar un documento hasta instalar un programa, el sistema operativo debe organizar información en dispositivos permanentes como discos duros o SSDs. Pero no solo eso: debe crear abstracciones útiles como "archivos" y "directorios", garantizar la integridad de los datos ante fallos de energía o errores de hardware, y proporcionar mecanismos de control de acceso para que no cualquiera pueda leer tus archivos privados.

\begin{example}
Cuando guardás un archivo de texto de 1KB, el sistema operativo decide en qué sectores del disco físico va a almacenarlo, actualiza las estructuras de metadatos que permiten encontrarlo después, potencialmente lo fragmenta si no hay espacio contiguo, mantiene una caché en memoria para accesos rápidos, y registra toda la operación para poder recuperarse si hay un fallo.
\end{example}

El cuarto pilar es la **gestión de E/S y comunicación**. Tu computadora tiene una increíble diversidad de dispositivos: teclado, mouse, pantalla, red, impresora, cámara, micrófonos. Cada uno funciona de manera diferente, con protocolos distintos y velocidades que varían por órdenes de magnitud. El sistema operativo debe manejar esta heterogeneidad y proporcionar interfaces uniformes que permitan a los programas comunicarse con estos dispositivos sin conocer los detalles de bajo nivel de cada uno.

Además, el sistema operativo facilita la comunicación entre procesos: cuando copiás texto de un programa y lo pegás en otro, cuando un servidor web recibe una petición de un navegador, o cuando dos aplicaciones intercambian datos, es el sistema operativo el que hace posible esta comunicación de manera segura y eficiente.

### ¿Por qué es tan Complejo?

Si los pilares fundamentales suenan razonables y hasta obvios, te preguntarás: ¿por qué los sistemas operativos tienen fama de ser tan complejos? La respuesta está en los desafíos únicos que enfrentan, desafíos que raramente aparecen juntos en otros dominios de la computación.

Primero está el problema de la *concurrencia*. No solo hay múltiples actividades simultáneas, sino que estas actividades pueden interferir entre sí de formas sutiles y difíciles de predecir. Dos procesos que intentan actualizar el mismo archivo, un programa que lee mientras otro escribe, hilos que acceden a estructuras de datos compartidas: estos escenarios crean condiciones de carrera, interbloqueos y otros problemas que pueden ocurrir solo una vez en mil ejecuciones, haciendo que sean particularmente difíciles de detectar y corregir.

\begin{warning}
Los errores de concurrencia son notoriamente difíciles de reproducir y depurar. Un programa puede funcionar perfectamente en pruebas y fallar catastróficamente en producción debido a una condición de carrera que solo ocurre bajo ciertas combinaciones de timing específicas.
\end{warning}

Luego están los *recursos limitados*. A diferencia de los algoritmos que estudiamos en cursos anteriores, donde a menudo podemos asumir memoria infinita o tiempo ilimitado, los sistemas operativos funcionan en un mundo de límites físicos duros. La CPU tiene un número finito de ciclos por segundo, la memoria tiene un tamaño máximo, el ancho de banda de red es limitado, y la batería se agota. Cada decisión del sistema operativo debe considerar estos límites y hacer compromisos (trade-offs) inteligentes.

La *heterogeneidad* es otro desafío fundamental. El sistema operativo debe funcionar con procesadores de diferentes arquitecturas, dispositivos de almacenamiento con características distintas, aplicaciones con necesidades completamente diferentes. Un servidor web tiene prioridades diferentes que un videojuego, que a su vez son diferentes de un sistema de procesamiento de transacciones financieras. El sistema operativo debe adaptarse a todos estos contextos sin favorecer injustamente a ninguno.

La *confiabilidad* es crítica porque un error en el sistema operativo puede afectar todo el sistema. Si tu navegador se cuelga, cerrás ese programa y listo. Pero si el sistema operativo falla, toda la computadora se detiene. Esta responsabilidad requiere niveles de robustez y manejo de errores que van más allá de lo que necesitan la mayoría de las aplicaciones.

La *seguridad* es un requisito transversal: el sistema operativo debe proteger datos y recursos de accesos no autorizados, prevenir que programas maliciosos comprometan el sistema, y garantizar que diferentes usuarios puedan coexistir sin interferirse mutuamente. Y todo esto debe hacerse sin impactar significativamente el rendimiento.

Finalmente está el desafío del *rendimiento*. Los usuarios esperan que sus sistemas sean rápidos, consuman poca energía, y respondan inmediatamente. Pero optimizar para velocidad puede aumentar el consumo energético, priorizar capacidad de respuesta puede reducir el throughput general, y así sucesivamente. El sistema operativo debe equilibrar constantemente estos objetivos contradictorios.

### El Enfoque Unix/Linux

Este libro se centra en sistemas Unix/Linux, no por preferencia ideológica, sino por razones pedagógicas concretas que hacen que estos sistemas sean ideales para aprender cómo funcionan realmente los sistemas operativos.

La primera razón es la *transparencia*. A diferencia de sistemas propietarios donde el funcionamiento interno es opaco, en Unix/Linux el código fuente está disponible para estudiar. Esto significa que cuando decimos "así funciona la planificación de procesos", podés ir al código del kernel y ver exactamente cómo está implementado. Esta capacidad de "ver por dentro" es invaluable para el aprendizaje profundo.

\begin{theory}
Unix fue diseñado en los años 70 con una filosofía específica: "cada cosa hace una cosa bien". Esta simplicidad conceptual, donde funciones complejas se construyen componiendo herramientas simples, hace que sea más fácil entender el sistema como un todo. Muchos sistemas modernos han abandonado esta filosofía en favor de características más complejas, pero Unix/Linux mantiene estos principios en su núcleo.
\end{theory}

Los *estándares abiertos* son otra ventaja. POSIX (Portable Operating System Interface) define interfaces estándar que hacen que el código sea portable entre diferentes sistemas Unix-like. Esto significa que lo que aprendés sobre Linux es aplicable a BSD, macOS, y otros sistemas. Esta estandarización también facilita el aprendizaje porque podés confiar en que ciertos comportamientos son consistentes.

La *relevancia industrial* no puede ignorarse. Unix/Linux domina en servidores (más del 90% de los servidores web corren Linux), sistemas embebidos (desde routers hasta SmartTVs), supercomputadoras (el 100% del Top500 corre Linux), y cada vez más en desktop. Aprender Unix/Linux no es un ejercicio académico: es una habilidad directamente aplicable en la industria.

Finalmente, el *ambiente de desarrollo* en Unix/Linux es excepcional. Las herramientas para programación en C, el lenguaje en que están escritos los sistemas operativos, son nativas y poderosas. Los compiladores, debuggers, profilers, y otras herramientas que necesitás para experimentar con código de sistemas están integrados y bien documentados.

### Resumen y Hoja de Ruta

En este libro recorreremos el sistema operativo desde sus cimientos hasta sus aspectos más sofisticados, construyendo conocimiento de forma incremental y conectada.

Los primeros capítulos establecen los **fundamentos**. Comenzamos con arquitectura de computadores porque para entender cómo funciona un sistema operativo necesitás entender el hardware que gestiona. Después introducimos el concepto de proceso, que es la abstracción fundamental sobre la que se construye todo lo demás.

\begin{infobox}
Estructura del Libro:\\
- Capítulos 1-2: Fundamentos - Arquitectura de computadores y concepto de proceso\\
- Capítulos 3-6: Concurrencia - Planificación, hilos, sincronización e interbloqueos\\
- Capítulos 7-8: Memoria - Gestión de memoria real y virtual\\
- Capítulo 9: Almacenamiento - Sistemas de archivos\\
- Capitulo 10: Dispositivos I/O\\
\end{infobox}

La sección de **concurrencia** es el corazón del libro. Acá estudiamos cómo el sistema operativo crea la ilusión de múltiples actividades simultáneas: cómo planifica qué proceso se ejecuta en cada momento, cómo los hilos permiten paralelismo dentro de un proceso, cómo se sincronizan accesos a recursos compartidos, y cómo se previenen y resuelven interbloqueos. Esta sección es particularmente importante porque los problemas de concurrencia están entre los más sutiles y difíciles de la programación de sistemas.

La **gestión de memoria** empieza con lo básico: cómo se asigna y libera memoria, cómo se protegen los espacios de direcciones de diferentes procesos. Después avanzamos hacia memoria virtual, una de las abstracciones más elegantes de la computación moderna, que hace que cada proceso "vea" su propio espacio de direcciones continuo e independiente, sin importar cómo esté realmente organizada la memoria física.

Finalmente, el capítulo de **sistemas de archivos** cierra el ciclo mostrando cómo toda la información que los procesos manipulan en memoria puede persistirse en almacenamiento permanente. Acá conectamos todos los conceptos anteriores: procesos que acceden a archivos, memoria que se mapea desde archivos, planificación que debe considerar operaciones de I/O, y sincronización para accesos concurrentes al sistema de archivos.

Cada tema se construye deliberadamente sobre los anteriores. No podés entender memoria virtual sin entender procesos, no podés entender sincronización sin entender concurrencia, y no podés entender sistemas de archivos sin entender todas las abstracciones anteriores. Por eso es importante seguir el orden, aunque después puedas volver a capítulos específicos para referencia o repaso.

Al final de este recorrido, vas a tener una comprensión integral de cómo funciona realmente el software más importante de tu computadora: ese conjunto de abstracciones, políticas y mecanismos que transforman metal y silicio en una máquina útil, segura y eficiente.