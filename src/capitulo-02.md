# Fundamentos de los Sistemas Operativos

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante será capaz de:

- Identificar los componentes principales de la arquitectura de von Neumann y su relación con el sistema operativo
- Explicar la diferencia entre modo kernel y modo usuario, y por qué es fundamental para el SO
- Describir el proceso de arranque (boot) y cómo se carga el sistema operativo
- Analizar los mecanismos de interrupciones y llamadas al sistema (syscalls)
- Relacionar la arquitectura del hardware con las funciones básicas del sistema operativo

## Introducción a los Sistemas Operativos

Ahora que comprendemos la arquitectura de hardware sobre la cual operan, podemos finalmente definir con precisión qué es un sistema operativo.  

\begin{excerpt}
\emph{Definición:}
Un Sistema Operativo es un conjunto de rutinas y procedimientos manuales y automáticos que permiten la operatoria en un sistema de computación. Es, fundamentalmente, un \textbf{programa de control} que media entre el hardware y los programas de aplicación.
\end{excerpt}  

El sistema operativo no es un programa más: es el programa que hace posible que existan todos los demás programas. Sus responsabilidades abarcan desde el momento en que se enciende la computadora hasta que se apaga, y cada milisegundo de ese tiempo está dedicado a alguna tarea crítica.  
Sus principales tareas incluyen lanzar el Init Program Loader durante el arranque, gestionar todos los recursos del hardware de manera eficiente y justa, proporcionar servicios estandarizados a los programas de aplicación, actuar como intermediario entre usuarios y el hardware bruto, y mantener la seguridad e integridad de todo el sistema. 

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
Cuando guardás un archivo de texto de 1KiB, el sistema operativo decide en qué sectores del disco físico va a almacenarlo, actualiza las estructuras de metadatos que permiten encontrarlo después, potencialmente lo fragmenta si no hay espacio contiguo, mantiene una caché en memoria para accesos rápidos, y registra toda la operación para poder recuperarse si hay un fallo.
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


### Principales Tareas del Sistema Operativo

El sistema operativo moderno es un software extraordinariamente complejo que debe manejar múltiples responsabilidades simultáneamente. Veamos cada una de sus áreas principales:  
La **gestión de procesos** involucra crear nuevos procesos cuando un programa necesita ejecutarse, planificar cuál proceso debe usar la CPU en cada momento, y terminar procesos de manera ordenada cuando finalizan. Además, debe proporcionar mecanismos de comunicación entre procesos que los permitan colaborar, y manejar la sincronización para evitar condiciones de carrera y deadlocks.  

La **gestión de memoria** requiere asignar bloques de memoria a procesos cuando la necesitan y liberarla cuando ya no la usan. Para maximizar el uso de la RAM limitada, implementa memoria virtual que permite usar disco como extensión de la RAM, y protege los espacios de memoria de cada proceso para que uno no pueda corromper accidentalmente (o maliciosamente) la memoria de otro.  

La **gestión de almacenamiento** organiza los archivos en sistemas de archivos jerárquicos, controla el acceso a dispositivos de almacenamiento físico como discos y SSDs, e implementa políticas de respaldo y recuperación para proteger contra pérdida de datos.  

La **gestión de E/S** debe controlar la enorme variedad de dispositivos que pueden conectarse al sistema, desde teclados y ratones hasta impresoras 3D y sensores especializados. Proporciona una interfaz uniforme que abstrae las diferencias entre dispositivos, y implementa técnicas como buffering, caching y spooling para maximizar la eficiencia.  

Los aspectos de **seguridad y protección** incluyen autenticar usuarios para verificar identidades, controlar qué usuarios pueden acceder a qué recursos y con qué privilegios, y proteger procesos entre sí y proteger al sistema operativo mismo de procesos maliciosos.  

Finalmente, **la interfaz de usuario** puede tomar la forma de una línea de comandos (CLI) para usuarios avanzados, interfaces gráficas (GUI) para usuarios generales, o APIs bien diseñadas para programadores que necesitan acceder a servicios del sistema.

### System Calls (Llamadas al Sistema)

Aquí llegamos a uno de los conceptos más fundamentales en sistemas operativos: el mecanismo mediante el cual programas en modo usuario pueden solicitar servicios del kernel sin comprometer la seguridad del sistema.  

\begin{excerpt}
\emph{Definición:}
Las System Calls son el mecanismo controlado mediante el cual los programas en modo usuario pueden solicitar servicios al sistema operativo, como acceso a hardware, creación de procesos, o manipulación de archivos.
\end{excerpt}

Las system calls existen por razones fundamentales de protección, abstracción, eficiencia y portabilidad. Sin ellas, cada programa necesitaría incluir código específico para cada modelo de disco duro, cada tarjeta de red, cada tipo de pantalla. Además, cualquier programa podría acceder directamente al hardware de otros procesos, robando datos o causando crashes.  

El *mecanismo tradicional* de system calls en arquitecturas x86 sigue estos pasos: el programa prepara los parámetros en registros o stack, ejecuta una instrucción INT (interrupt de software), la CPU cambia automáticamente a modo kernel, el kernel identifica qué syscall fue solicitada consultando una tabla, ejecuta la función correspondiente en modo privilegiado, y finalmente retorna el resultado y devuelve control al programa en modo usuario.

Mecanismo Tradicional:
```
1. Programa prepara parámetros
2. Ejecuta instrucción INT (interrupt)
3. CPU cambia a modo kernel
4. Kernel identifica syscall solicitada
5. Kernel ejecuta función correspondiente
6. Kernel retorna resultado
7. CPU vuelve a modo usuario
```

\begin{example}
\emph{Ejemplo en Linux (x86):}
En Linux x86, una syscall tradicional se ve así:  
Cada línea tiene un propósito específico: EAX identifica qué syscall queremos, EBX-EDX contienen los argumentos, y la instrucción INT 0x80 es el portal al kernel.
\end{example}  

```assembly
mov eax, 4          ; syscall number para sys_write
mov ebx, 1          ; file descriptor (stdout)
mov ecx, msg        ; puntero al mensaje
mov edx, len        ; longitud del mensaje
int 0x80            ; interrupción de software
```


### Fast System Calls

El mecanismo tradicional de syscalls mediante interrupciones de software, aunque funcional, tiene un problema de rendimiento significativo. Las interrupciones requieren guardar todo el contexto del procesador, consultar la tabla de vectores de interrupción, y manejar overhead considerable en el cambio de modo. Para un sistema que realiza millones de syscalls por segundo, esta ineficiencia se vuelve crítica.  

Los procesadores modernos introducen instrucciones especializadas para hacer syscalls más rápidas. Intel desarrolló SYSENTER/SYSEXIT, mientras que AMD (posteriormente adoptado también por Intel en x86-64) creó SYSCALL/SYSRET.  


```assembly
; SYSENTER/SYSEXIT (Intel)
mov eax, syscall_number
mov edx, return_address
mov ecx, user_stack
sysenter            ; Entrada rápida al kernel
; ... kernel ejecuta syscall ...
sysexit             ; Retorno rápido a usuario
```

```assembly
; SYSCALL/SYSRET (AMD/Intel x86-64)
mov rax, syscall_number
mov rdi, arg1
mov rsi, arg2
syscall             ; Entrada directa al kernel
; Resultado en RAX al retornar
```

Estas instrucciones especializadas son *50-70% más rápidas* que INT tradicional. Logran esto reduciendo el overhead de cambio de contexto, usando registros especializados en lugar de stack, y proporcionando transición directa sin necesidad de consultar vectores de interrupción.  

\begin{infobox}
En Linux moderno, la biblioteca glibc automáticamente elige el método más eficiente disponible en el procesador. El programador simplemente llama a funciones como \texttt{write()} o \texttt{read()}, y glibc se encarga de usar SYSCALL en x86-64, SYSENTER en x86-32, o SVC en ARM, según corresponda.
\end{infobox}

### Arquitecturas de Kernel

La forma en que se organiza internamente el código del sistema operativo tiene profundas implicaciones en rendimiento, seguridad y mantenibilidad. Existen dos filosofías principales que representan extremos opuestos en el espectro de diseño.  

**Kernel Monolítico:**

En un kernel monolítico, todo el sistema operativo ejecuta en modo kernel como un solo programa grande. Los drivers de dispositivos, el sistema de archivos, el stack de red, y todos los subsistemas comparten un único espacio de direcciones. La comunicación entre componentes se realiza mediante llamadas a función directas, como en cualquier programa normal.  

\begin{highlight}
\textbf{Ventajas del enfoque monolítico:}

El rendimiento es superior porque no hay overhead de comunicación entre componentes. Un driver puede llamar directamente a una función del filesystem sin cambios de contexto ni paso de mensajes. Esta eficiencia es la razón por la cual Linux, siendo monolítico, puede competir en rendimiento con sistemas diseñados específicamente para alta performance.

La simplicidad de debugging también es notable: cuando algo falla, todo está en un solo lugar. Las herramientas de debugging pueden seguir el flujo de ejecución sin saltar entre diferentes espacios de direcciones.
\end{highlight}

\begin{warning}
\textbf{Desventajas del enfoque monolítico:}

La menor estabilidad es el precio que se paga por la eficiencia. Un bug en cualquier driver, por obscuro que sea, puede crashear todo el sistema porque todo comparte el mismo espacio de direcciones. Un error de puntero en el driver de una webcam puede corromper las estructuras del scheduler.

La seguridad también sufre: todo el código tiene privilegios máximos. No hay aislamiento entre un driver de red y el código que maneja contraseñas. El tamaño del kernel es considerable, y cada línea de código es un potencial punto de fallo.
\end{warning}

*Ejemplos:* Linux, Unix tradicional, y parcialmente Windows (que combina elementos monolíticos con diseño en capas)

**Microkernel:**

La filosofía del microkernel es radicalmente diferente: mantener el kernel lo más pequeño posible, implementando solo las funciones absolutamente esenciales. Todo lo demás ejecuta como procesos separados en modo usuario.  

El kernel mínimo se limita a scheduling de procesos básico, comunicación inter-procesos (IPC), y manejo elemental de memoria. Los drivers de dispositivos, sistemas de archivos, y servicios de red ejecutan como procesos normales que se comunican mediante paso de mensajes.  

\begin{highlight}
\textbf{Ventajas del enfoque microkernel:}

La estabilidad mejora dramáticamente: si un driver falla, es solo un proceso más que terminó. El sistema puede reiniciar el driver sin afectar al resto. La seguridad se beneficia de que cada servicio puede ejecutar con solo los privilegios mínimos necesarios.

La modularidad facilita agregar, quitar, o actualizar componentes. Querer probar un nuevo filesystem no requiere recompilar el kernel, solo lanzar un nuevo proceso servidor. El debugging se simplifica porque los componentes están aislados.
\end{highlight}

\begin{warning}
\textbf{Desventajas del enfoque microkernel:}

El rendimiento sufre debido al overhead de IPC entre componentes. Una operación simple puede requerir múltiples cambios de contexto y múltiples mensajes. La complejidad de diseño e implementación es considerablemente mayor: diseñar un buen sistema de IPC eficiente es extremadamente difícil.
\end{warning}

*Ejemplos:* Minix (el sistema usado para enseñar sistemas operativos), QNX (usado en sistemas embebidos críticos), seL4 (kernel formalmente verificado), y GNU Hurd (aún en desarrollo después de décadas).  

*Enfoques Híbridos:*
La realidad es que la mayoría de sistemas operativos modernos no son puramente monolíticos ni microkernels puros, sino que combinan elementos de ambos enfoques según convenga. Windows NT usa un microkernel modificado pero mueve algunos servicios críticos de performance al kernel. macOS combina el microkernel Mach con componentes monolíticos de BSD. Linux, aunque principalmente monolítico, usa módulos cargables que pueden agregarse y removerse dinámicamente.  

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-01/02.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Comparación de las principales arquitecturas de núcleo de un sistema operativo: kernel monolítico, microkernel y kernel multicapa, destacando la organización de sus componentes y su relación con el hardware.
}
\end{center}

<!-- ![Comparación de las principales arquitecturas de núcleo de un sistema operativo: kernel monolítico, microkernel y kernel multicapa, destacando la organización de sus componentes y su relación con el hardware.](src/images/capitulo-01/02.png){width=0.9\linewidth}
 -->


| Aspecto | Monolítico | Microkernel |
|---------|------------|-------------|
| Rendimiento | Excelente | Bueno |
| Estabilidad | Regular | Excelente |
| Seguridad | Regular | Excelente |
| Simplicidad | Alta | Baja |
| Tiempo de desarrollo | Menor | Mayor |


## Análisis Técnico (Leelo sólo por curiosidad...)
Esta sección profundiza en aspectos más técnicos que, si bien no son esenciales para un primer entendimiento, te darán una apreciación más profunda de la complejidad involucrada. Podés leerla por curiosidad o saltearla y volver más adelante.  

### Proceso de Arranque (Bootstrap)

El proceso de arranque es fascinante porque debe resolver un problema aparentemente imposible: ¿cómo puede una computadora apagada comenzar a ejecutar software si el software mismo necesita estar ejecutándose para cargar software? La respuesta involucra una cuidadosa secuencia de etapas, cada una más compleja que la anterior.  

La secuencia comienza con el *Power-On Self Test* (POST), un programa pequeño almacenado en firmware (BIOS o UEFI) que ejecuta verificaciones básicas de hardware. Verifica que la RAM funcione, que haya dispositivos de boot disponibles, y que los componentes críticos respondan.  

Una vez que POST completa exitosamente, se carga el *bootloader*, un programa pequeño que sabe cómo cargar el sistema operativo. Este programa típicamente reside en el Master Boot Record (MBR) en sistemas BIOS legacy, o en una partición EFI en sistemas modernos UEFI.  

El bootloader lee el kernel del sistema operativo desde disco y lo carga en memoria. Luego transfiere control al punto de entrada del kernel, que comienza su propia fase de inicialización: detecta e inicializa todo el hardware disponible, configura estructuras de datos internas como tablas de procesos y sistemas de archivos, y finalmente arranca el primer proceso (tradicionalmente llamado `init`).  


### Manejo de Interrupciones

El manejo de interrupciones involucra una estructura de datos crítica llamada *vector de interrupciones* o *Interrupt Descriptor Table* (IDT) en x86. Esta tabla mapea cada número de interrupción a la dirección de memoria de su handler correspondiente.  

Cuando ocurre una interrupción, el proceso completo se desarrolla así: el hardware detiene la ejecución actual y guarda el contexto mínimo (PC y PSW) en el stack. Consulta el vector de interrupciones para encontrar la dirección del handler apropiado. El procesador cambia a modo kernel si no estaba ya en ese modo. El handler ejecuta, realizando las acciones necesarias para atender la interrupción. Al completar, se restaura el contexto guardado y se retorna al punto donde fue interrumpido, como si nada hubiera pasado.  

\begin{theory}
Esta capacidad de interrumpir transparentemente la ejecución, atender un evento, y continuar como si nada hubiera pasado es fundamental para la ilusión de que múltiples cosas están ocurriendo simultáneamente en un procesador que solo puede ejecutar una instrucción a la vez.
\end{theory}

### Jerarquía de Memoria

Los diferentes niveles de memoria en un sistema moderno forman una pirámide donde velocidad y capacidad están inversamente relacionados:  

```
Registros CPU (1 ciclo, bytes)
    ↓
Cache L1 (2-4 ciclos, KiB)
    ↓  
Cache L2 (10-20 ciclos, MiB)
    ↓
Memoria Principal RAM (100-300 ciclos, GiB)
    ↓
Almacenamiento Secundario (millones de ciclos, TiB)
```

Las implicaciones para el sistema operativo son profundas. La gestión eficiente de cache es crítica para rendimiento, ya que la diferencia entre un cache hit y un cache miss puede ser de dos órdenes de magnitud en latencia. La memoria virtual se vuelve necesaria cuando la RAM es insuficiente para todos los procesos activos. Los algoritmos de reemplazo deben optimizar para minimizar accesos al nivel más lento.  

## Código en C
Veamos cómo estos conceptos se traducen en código real. Los siguientes ejemplos te permitirán experimentar directamente con system calls y manejo de señales.

### Ejemplo: Información del Sistema

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/utsname.h>

int main() {
    struct utsname system_info;
    
    // Syscall para obtener información del sistema
    if (uname(&system_info) == -1) {
        perror("uname failed");
        return 1;
    }
    
    printf("Sistema Operativo: %s\n", system_info.sysname);
    printf("Nombre del Host: %s\n", system_info.nodename);  
    printf("Release: %s\n", system_info.release);
    printf("Versión: %s\n", system_info.version);
    printf("Arquitectura: %s\n", system_info.machine);
    
    // Otras syscalls útiles
    printf("Process ID: %d\n", getpid());
    printf("Parent Process ID: %d\n", getppid());
    printf("User ID: %d\n", getuid());
    
    return 0;
}
```

Este programa demuestra varias system calls en acción. La función `uname()` es una syscall que obtiene información del sistema operativo. Cada llamada provoca una transición de modo usuario a modo kernel, donde el kernel recopila la información solicitada y la retorna de manera segura. Las funciones `getpid()`, `getppid()` y `getuid()` son syscalls adicionales que obtienen identificadores del proceso actual, su proceso padre, y el usuario que lo ejecuta.  

### Ejemplo: Manejo Básico de Señales

```c
#include <stdio.h>
#include <signal.h>
#include <unistd.h>

// Handler para la señal SIGINT (Ctrl+C)
void signal_handler(int sig) {
    printf("\n¡Recibida señal %d! Pero no me voy a cerrar...\n", sig);
    printf("Presiona Ctrl+\\ para terminar realmente.\n");
}

int main() {
    // Registrar nuestro handler para SIGINT
    signal(SIGINT, signal_handler);
    
    printf("Programa ejecutándose... Presiona Ctrl+C para probar.\n");
    printf("PID: %d\n", getpid());
    
    // Loop infinito para demostrar el manejo de señales
    while(1) {
        printf("Trabajando...\n");
        sleep(2);  // Syscall que suspende ejecución por 2 segundos
    }
    
    return 0;
}
```

Este ejemplo ilustra el manejo de señales, un mecanismo de comunicación asincrónica fundamental. Cuando presionás Ctrl+C, el terminal envía la señal SIGINT al proceso. Normalmente esto terminaría el programa, pero como registramos nuestro propio handler, nuestro código ejecuta en su lugar.  

\begin{example}
Las señales son un caso fascinante de cómo el sistema operativo puede interrumpir un proceso para entregarle información. El handler se ejecuta en el contexto del proceso interrumpido, pero fue invocado por el kernel. Es un ejemplo perfecto de cómo hardware (la tecla Ctrl+C), kernel (detección y entrega de señal), y proceso de usuario (handler) colaboran.
\end{example}


## Casos de Estudio

### Caso 1: Análisis de una Syscall

**Enunciado:** Analice qué sucede cuando un programa ejecuta `printf("Hola mundo\n");` desde las perspectivas de hardware y sistema operativo.

**Resolución Paso a Paso:**

Comencemos analizando el código. La función `printf()` es parte de la biblioteca estándar de C (libc), no del kernel. Internamente, `printf()` formatea el string y luego llama a la syscall `write()`, que sí es parte del kernel. Esta syscall debe escribir en stdout, representado por el file descriptor 1.  

La secuencia de ejecución completa es:  

```
Programa (modo usuario) 
→ printf() 
→ write(1, "Hola mundo\n", 11)
→ Interrupción de software (trap)
→ Modo kernel
→ sys_write() en el kernel
→ Driver de terminal
→ Hardware de pantalla
→ Retorno a modo usuario
```

Durante la transición de usuario a kernel, se guardan todos los registros del proceso en su kernel stack. Se cambia el puntero de stack para usar el stack del kernel. El modo de operación del procesador cambia a supervisor/kernel. En la transición inversa, se restauran los registros desde el kernel stack, se cambia de vuelta al stack de usuario, y el valor de retorno de la syscall se coloca en el registro apropiado (típicamente EAX/RAX).  

\begin{warning}
\textbf{Puntos clave para recordar:}
\begin{itemize}
\item \texttt{printf()} NO es una syscall directa, es una función de biblioteca
\item Hay cambio de modo de operación (usuario → kernel → usuario)
\item El kernel valida permisos antes de permitir la escritura
\item El file descriptor 1 representa stdout por convención POSIX
\item Todo el proceso es transparente para el programador
\end{itemize}
\end{warning}


## Síntesis

### Puntos Clave del Capítulo

Hemos recorrido un largo camino desde los componentes básicos del hardware hasta los conceptos fundamentales del sistema operativo. Tres ideas principales deben quedar cristalinas:  
Primero, la arquitectura hardware no es un detalle de implementación irrelevante: determina las capacidades fundamentales del sistema operativo. La arquitectura de von Neumann establece el modelo básico de cómo funcionan las computadoras. Los modos de operación permiten la protección necesaria para la estabilidad del sistema. Las interrupciones son el mecanismo que habilita el multitasking y la respuesta a eventos externos.  

Segundo, el sistema operativo es el intermediario esencial entre software y hardware. Las system calls proporcionan servicios controlados y seguros. El SO abstrae las complejidades del hardware, permitiendo que los programadores se concentren en la lógica de sus aplicaciones. Mantiene la seguridad y estabilidad que damos por sentada.  

Tercero, el rendimiento de un sistema depende críticamente de entender la jerarquía de memoria. Los principios de localidad temporal y espacial son fundamentales para el diseño de algoritmos eficientes. La gestión de cache puede hacer la diferencia entre un sistema lento y uno rápido. Los accesos a disco son inevitablemente el cuello de botella principal en muchos sistemas.  

### Conexiones con Próximos Capítulos

Los conceptos que hemos explorado aquí forman la base sobre la cual construiremos todo lo que sigue. En el próximo capítulo sobre Procesos, veremos cómo los modos de operación y las syscalls permiten al SO crear y gestionar la abstracción fundamental de "programa en ejecución".  
Cuando estudiemos Planificación, las interrupciones de timer que apenas mencionamos aquí se volverán centrales: son el mecanismo que permite al SO implementar multitasking preemptivo, quitándole la CPU a un proceso que se está ejecutando para darle turno a otro.  

En los capítulos sobre Gestión de Memoria, la jerarquía de memoria y la MMU (Memory Management Unit) que solo tocamos superficialmente se convertirán en protagonistas, permitiéndonos entender cómo un sistema puede hacer que múltiples procesos crean que tienen toda la memoria para ellos solos.


### Errores Comunes en Parciales
Terminemos identificando algunos malentendidos frecuentes que aparecen en exámenes:
\begin{warning}
\textbf{Error común:} ``printf() es una syscall''
\textbf{Realidad:} printf() es una función de biblioteca (libc) que \textit{usa} la syscall write() internamente. Esta distinción es importante: la biblioteca proporciona conveniencia (formateo de strings), mientras que la syscall proporciona funcionalidad fundamental (escribir bytes a un file descriptor).
\end{warning}
\begin{warning}
\textbf{Error común:} ``Las interrupciones solo vienen del hardware''
\textbf{Realidad:} También existen interrupciones de software (syscalls, excepciones). De hecho, las syscalls son típicamente implementadas como interrupciones de software. Las excepciones, como división por cero o acceso a memoria inválida, también son formas de interrupción.
\end{warning}
\begin{warning}
\textbf{Error común:} ``El modo kernel es más rápido''
\textbf{Realidad:} El modo kernel tiene más privilegios, no necesariamente más velocidad. De hecho, el cambio de modo usuario a kernel tiene overhead. Lo que hace que el kernel parezca rápido es que puede acceder directamente a hardware sin pasar por capas de abstracción.
\end{warning}
