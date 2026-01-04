# Introducción y Arquitectura de Computadores

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante será capaz de:

- Identificar los componentes principales de la arquitectura de von Neumann y su relación con el sistema operativo
- Explicar la diferencia entre modo kernel y modo usuario, y por qué es fundamental para el SO
- Describir el proceso de arranque (boot) y cómo se carga el sistema operativo
- Analizar los mecanismos de interrupciones y llamadas al sistema (syscalls)
- Relacionar la arquitectura del hardware con las funciones básicas del sistema operativo

## Introducción y Contexto
### ¿Por qué necesitamos entender la arquitectura?
Imaginá que querés entender cómo funciona un auto. Podrías aprender a manejarlo sin saber nada del motor, pero si quieres ser mecánico, necesitas entender pistones, válvulas, y transmisión.
Con los sistemas operativos pasa lo mismo. Podés usar una computadora sin entender qué hay "debajo del capó", pero para diseñar, optimizar o debuggear un SO, necesitas entender el hardware que administra. 
Esta comprensión no es opcional: es el fundamento sobre el cual se construyen todos los conceptos posteriores.  

### Los problemas que resuelve esta arquitectura  

Todo sistema operativo moderno enfrenta tres desafíos fundamentales que la arquitectura de hardware debe resolver. Veamos cada uno:  
El primer desafío es la comunicación entre software y hardware. El procesador solo entiende instrucciones binarias, mientras que los dispositivos tienen interfaces completamente diferentes. Se necesita un "traductor" capaz de convertir las intenciones de alto nivel de un programa en señales eléctricas específicas que cada componente pueda comprender.  
El segundo desafío es la protección del sistema. Sin mecanismos de seguridad, un programa con errores podría crashear toda la máquina, o peor aún, múltiples programas competirían por los mismos recursos sin ningún tipo de arbitraje. La arquitectura debe proporcionar "niveles de privilegio" que limiten lo que cada programa puede hacer.  
El tercer desafío es el manejo de eventos impredecibles. El usuario puede presionar una tecla en cualquier momento, los datos pueden llegar por la red de forma asincrónica, un proceso puede solicitar un archivo mientras otro está escribiendo en disco. El sistema necesita un mecanismo para "interrumpir" la ejecución normal y atender estos eventos de manera ordenada y eficiente.


## Conceptos Fundamentales
### Arquitectura de von Neumann
La arquitectura de von Neumann es el modelo fundamental sobre el cual se construyen prácticamente todas las computadoras modernas. Aunque han surgido variaciones y optimizaciones, los principios básicos permanecen intactos desde su concepción en la década de 1940.


\begin{theory}
La característica distintiva de la arquitectura de von Neumann es que \textit{programa y datos comparten el mismo espacio de memoria}. Esto permite que los programas sean tratados como datos, habilitando conceptos como compiladores, intérpretes y sistemas operativos que pueden cargar y ejecutar otros programas dinámicamente.
\end{theory}


Esta arquitectura se compone de cuatro subsistemas principales que trabajan en conjunto. La **CPU** (Unidad Central de Procesamiento) es el cerebro del sistema, conteniendo la Unidad de Control que decodifica y ejecuta instrucciones, la Unidad Aritmético-Lógica que realiza operaciones matemáticas y lógicas, y un conjunto de registros que proporcionan almacenamiento ultrarrápido dentro del procesador mismo.  
La **Memoria Principal** (RAM) almacena tanto programas como datos de forma temporal. Su característica de acceso directo y aleatorio significa que cualquier ubicación puede ser accedida en tiempo constante, pero su naturaleza volátil implica que todo su contenido se pierde al apagar el sistema.  
El **Almacenamiento Secundario** complementa a la RAM proporcionando persistencia. Los discos duros, SSD y otros medios de almacenamiento son significativamente más lentos que la RAM, pero mantienen la información incluso sin energía eléctrica y ofrecen capacidades mucho mayores.
Los **Dispositivos de E/S** son las interfaces que permiten al sistema interactuar con el mundo exterior: teclado, mouse, pantalla, tarjetas de red, y una variedad de periféricos especializados. 
\vfill
\newpage 

![Diagrama de la arquitectura básica de una computadora, basado en el modelo de von Neumann, donde se muestran los principales componentes del sistema y su interconexión: CPU, memoria principal y dispositivos de entrada/salida.](src/images/capitulo-01/01.png){style="display: block; margin: auto;" }

## Buses de Comunicación
Los componentes de la arquitectura de von Neumann no pueden funcionar de forma aislada. Los **buses** son las "autopistas" que permiten la comunicación entre CPU, memoria y dispositivos. Sin ellos, tendríamos componentes poderosos pero incapaces de colaborar.  
El sistema de buses se divide en tres tipos especializados, cada uno con una función específica:  
El **Bus de Datos** transporta la información real entre componentes. Su ancho, medido en bits, determina cuánta información puede transferirse simultáneamente. Un bus de 64 bits, por ejemplo, puede mover 8 bytes en cada ciclo de reloj, lo que impacta directamente en el rendimiento del sistema.  
El **Bus de Direcciones** especifica la ubicación de memoria que se desea acceder. Su ancho determina el espacio máximo de direcciones que el sistema puede manejar. Con 32 bits podemos direccionar hasta 4GiB de memoria, mientras que con 64 bits ese límite se extiende hasta 16 exabytes, una cantidad astronómica para estándares actuales.  
El **Bus de Control** coordina todas las operaciones mediante señales especializadas. Señales como READ, WRITE, IRQ y RESET sincronizan las transferencias entre componentes y aseguran que cada operación se complete correctamente antes de iniciar la siguiente.  

## Registros del Procesador
Los registros son la forma más rápida de memoria disponible en un sistema de cómputo. Están físicamente integrados en el chip del procesador, lo que los hace extremadamente veloces pero también extremadamente caros. Por esta razón, su número es limitado y cada uno tiene propósitos específicos.  

\begin{infobox}
La jerarquía de velocidad de memoria va desde los registros (1 ciclo de CPU) hasta el almacenamiento secundario (millones de ciclos). Esta diferencia de velocidad determina muchas de las decisiones de diseño de un sistema operativo.
\end{infobox}


Los registros se dividen en dos categorías principales según su nivel de privilegio:
Los **Registros Visibles al Usuario** pueden ser utilizados por programas en modo usuario. Entre ellos encontramos los registros de propósito general como EAX, EBX, ECX y EDX en arquitecturas x86-32, o sus equivalentes de 64 bits RAX, RBX, RCX y RDX. Estos registros son la memoria de trabajo del procesador, almacenando valores temporales durante cálculos y operaciones.  

Los registros de índice ESI (Source Index) y EDI (Destination Index) están optimizados para operaciones con strings y arrays, facilitando copias y comparaciones de bloques de memoria. El registro ESP/RSP actúa como puntero de stack, apuntando siempre al tope de la pila actual, mientras que EBP/RBP sirve como frame pointer, facilitando el acceso a parámetros y variables locales de funciones.  

Los **Registros Privilegiados** solo pueden ser accedidos en modo kernel. Los registros de control CR0 a CR4 configuran características fundamentales del procesador. CR0 controla modos de operación básicos, CR2 almacena la dirección que causó el último page fault (crucial para memoria virtual), CR3 contiene el directorio de páginas actual para la MMU, y CR4 habilita extensiones modernas del procesador.
Los registros de segmento en modo kernel (CS, DS, SS) son críticos para la protección de memoria, especificando qué regiones de memoria puede acceder cada proceso y con qué privilegios.  

## Program Status Word (PSW)
El **PSW**, también conocido como registro FLAGS, es un registro especial que contiene información sobre el estado actual del procesador. Cada bit en este registro tiene un significado específico y afecta cómo se ejecutan las instrucciones subsiguientes.  

Los flags de condición reflejan el resultado de operaciones aritméticas y lógicas. El Zero Flag (ZF) se activa cuando una operación produce resultado cero, el Carry Flag (CF) indica acarreo en operaciones aritméticas, el Sign Flag (SF) señala si el resultado es negativo, y el Overflow Flag (OF) detecta desbordamientos en aritmética con signo.  

Los flags de control modifican el comportamiento del procesador. El Interrupt Enable Flag (IF) determina si las interrupciones enmascarables están habilitadas, el Direction Flag (DF) controla la dirección de operaciones con strings, y el Trap Flag (TF) activa el modo single-step para debugging.
Los flags de sistema controlan aspectos avanzados de la ejecución. El I/O Privilege Level (IOPL) especifica el nivel de privilegio necesario para operaciones de E/S, el Nested Task Flag (NT) indica si estamos en una tarea anidada, y el Resume Flag (RF) ayuda en el control de debugging.  

\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap01-psw_register.png}
\end{center}  
\vfill
\newpage

### Ciclo de Instrucción

\begin{center}
\begin{minipage}{0.45\linewidth}
    \includegraphics[width=0.8\linewidth,keepaspectratio]{src/diagrams/cap01-cicloInstruccion.png}
\end{minipage}%
\hspace{0.05\linewidth}%
\begin{minipage}{0.45\linewidth}
\textbf{Fase 1: FETCH} \\
PC apunta a próxima instrucción → se carga en IR → PC se incrementa automáticamente. \\[2mm]

\textbf{Fase 2: DECODE} \\
Unidad de Control interpreta la instrucción → determina operación y operandos → prepara rutas de datos. \\[2mm]

\textbf{Fase 3: OPERAND FETCH} \\
Si la instrucción requiere datos: dirección en bus → dato desde memoria → carga en registro temporal/ALU. \\[2mm]

\textbf{Fase 4: EXECUTE} \\
ALU ejecuta la operación → actualización de registros y flags → resultados a memoria si aplica. \\[2mm]

\end{minipage}
\end{center}
\textbf{Fase 5: WRITE BACK} \\
Resultados transferidos a registro destino → PSW actualizado → CPU lista para nuevo ciclo. \\[2mm]

\textbf{Fase 0: CHECK INTERRUPT} \\
Se verifica interrupción → si hay ISR: guarda contexto, salta a rutina de servicio → al terminar, retorno al ciclo normal.

## Sistema de Interrupciones
Las interrupciones son posiblemente el mecanismo de hardware más importante para un sistema operativo. Sin ellas, el SO no podría mantener control sobre el sistema ni implementar multitasking efectivo.  

\begin{excerpt}
\emph{Definición:}
Una interrupción es un mecanismo hardware que permite detener temporalmente la ejecución normal del procesador para atender un evento urgente, sea este generado por hardware externo, por software, o por condiciones excepcionales durante la ejecución.
\end{excerpt}

Existen tres categorías principales de interrupciones, cada una con características y propósitos distintos. Las interrupciones de hardware son generadas por dispositivos externos al procesador, como el teclado cuando se presiona una tecla, el timer del sistema que marca intervalos regulares, o la tarjeta de red al recibir paquetes. Estas interrupciones son asincrónicas: pueden ocurrir en cualquier momento, independientemente de lo que esté ejecutando el procesador.  

Las interrupciones de software son generadas explícitamente por instrucciones del programa. Las system calls, por ejemplo, son interrupciones de software que solicitan servicios al sistema operativo. A diferencia de las interrupciones de hardware, estas son sincrónicas: ocurren en puntos predecibles del programa.  

Las excepciones son eventos síncronos generados por condiciones de error durante la ejecución. Una división por cero, un acceso a memoria inválida, o una instrucción ilegal generan excepciones que deben ser manejadas inmediatamente.  

\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-01/bloque-interrupciones.png}
\end{center}

### Interrupciones Enmascarables (Maskable Interrupts)
Pueden ser temporalmente deshabilitadas por software mediante el control del bit IF (Interrupt Flag) en el registro de estado del procesador (PSW/EFLAGS).


Control:  
- **CLI** (Clear Interrupt Flag): Deshabilita interrupciones  
- **STI** (Set Interrupt Flag): Habilita interrupciones  

Ejemplos:  
- Timer del sistema (IRQ0 - genera multitasking preemptivo)  
- Teclado (IRQ1) y mouse (IRQ12)  
- Tarjeta de red (IRQ variable)  
- Controladores de disco (IRQ14, IRQ15)  
- Puertos serie (IRQ3, IRQ4)  

```c
// Pseudocódigo de sección crítica
cli();              // Deshabilitar interrupciones
// ... código crítico que no debe ser interrumpido ...
// Ejemplo: manipulación de estructuras del kernel
update_process_table();
modify_memory_mapping();
sti();              // Rehabilitar interrupciones
```

\begin{warning}
Deshabilitar interrupciones por períodos prolongados puede causar pérdida de eventos y afectar la responsividad del sistema. Las secciones críticas deben ser lo más breves posible.
\end{warning}


### Interrupciones No Enmascarables (NMI - Non-Maskable Interrupts)

Algunas situaciones son tan críticas que no pueden esperar. Las interrupciones no enmascarables tienen prioridad absoluta y no pueden ser deshabilitadas por software, ni siquiera por el kernel. Estas interrupciones se reservan para eventos que requieren atención inmediata del sistema.  

Los eventos que generan NMI típicamente indican condiciones catastróficas: errores de paridad en memoria RAM que podrían corromper datos, fallas críticas de hardware como sobrecalentamiento extremo, watchdog timers que detectan que el sistema está completamente colgado, errores en el bus del sistema, o fallos de alimentación eléctrica inminentes.  

\begin{infobox}
Las NMI pueden interrumpir incluso al kernel en medio de secciones críticas. Esto significa que el handler de NMI debe ser extremadamente cuidadoso y no puede asumir que las estructuras del kernel están en estado consistente.
\end{infobox}


## Jerarquía de Prioridades

```
NMI (Prioridad 0 - más alta)
  ↓
Interrupciones de Hardware IRQ0-IRQ15 (Prioridad por IRQ)
  ↓
Excepciones del Procesador (Divide by zero, Page Fault)
  ↓
Interrupciones de Software (INT 0x80, syscalls)
  ↓
Trampas y Breakpoints (más baja)
```

## IRQ (Interrupt Request Lines)

### Controlador PIC (Programmable Interrupt Controller)

**PIC Primario (IRQ0-7)**:
```
IRQ 0  → Timer del sistema (8253/8254)
IRQ 1  → Teclado PS/2
IRQ 2  → Cascade a PIC secundario
IRQ 3  → Puerto serie COM2/COM4
IRQ 4  → Puerto serie COM1/COM3
IRQ 5  → Tarjeta de sonido/LPT2
IRQ 6  → Controlador de disquete
IRQ 7  → Puerto paralelo LPT1
```

**PIC Secundario (IRQ8-15)** - conectado via IRQ2:
```
IRQ 8  → Reloj de tiempo real (CMOS)
IRQ 9  → Redireccionado desde IRQ2
IRQ 10 → Libre (tarjetas de red)
IRQ 11 → Libre (USB, tarjetas PCI)
IRQ 12 → Mouse PS/2
IRQ 13 → Coprocesador matemático
IRQ 14 → Controlador IDE primario
IRQ 15 → Controlador IDE secundario
```
\begin{infobox}
En sistemas modernos con APIC, el número de IRQs disponibles se extiende hasta 256, y múltiples procesadores pueden recibir interrupciones simultáneamente. Sin embargo, el modelo conceptual permanece similar.
\end{infobox}


## Interrupt Handlers (Manejadores de Interrupción)
Cada tipo de interrupción debe tener asociado un handler: una rutina de código que sabe cómo responder a ese evento específico. Los handlers son las piezas de código más críticas del sistema operativo, y deben seguir reglas estrictas.  

### Estructura de un Handler
Un handler de interrupción debe ser eficiente y predecible. La estructura típica sigue este patrón:  

```c
// Prototipo genérico de handler
void interrupt_handler(int irq_number, struct pt_regs *regs) {
    // 1. Guardar contexto (automático en entrada)
    // 2. Identificar fuente de interrupción
    // 3. Ejecutar lógica específica
    // 4. Enviar EOI (End of Interrupt)
    // 5. Restaurar contexto (automático en salida)
}

// Ejemplo: Handler del timer del sistema
void timer_interrupt_handler(int irq, struct pt_regs *regs) {
    // Incrementar jiffies (contador global de tiempo)
    jiffies++;
    
    // Actualizar estadísticas del proceso actual
    current->utime++;
    
    // Verificar si el quantum del proceso expiró
    if (--current->time_slice <= 0) {
        current->need_resched = 1;  // Marcar para replanificación
    }
    
    // Ejecutar timers pendientes
    run_timer_list();
    
    // EOI al controlador de interrupciones
    send_eoi(IRQ_TIMER);
}
```
Este ejemplo muestra el handler del timer del sistema, una de las interrupciones más importantes. Cada "tick" del timer permite al sistema operativo mantener noción del tiempo transcurrido y decidir si es momento de cambiar al siguiente proceso.  

### Interrupciones Anidadas

Una característica avanzada de muchos sistemas es la capacidad de permitir que una interrupción de mayor prioridad interrumpa el procesamiento de una de menor prioridad. Esto se conoce como **anidamiento de interrupciones.**

```c
// Ejemplo de manejo de interrupciones anidadas
void high_priority_handler(int irq, struct pt_regs *regs) {
    // Esta interrupción puede ser interrumpida por NMI
    disable_interrupts();  // Opcional: crear sección crítica
    
    // Procesar evento crítico
    handle_critical_event();
    
    enable_interrupts();   // Permitir interrupciones anidadas
    
    // Continuar con procesamiento menos crítico
    handle_normal_processing();
}
```
El anidamiento ofrece ventajas significativas: mejor tiempo de respuesta para eventos críticos, priorización automática, y maximización del throughput del sistema. Sin embargo, introduce desafíos de complejidad en la gestión del stack, posibles deadlocks si no se maneja correctamente, y riesgo de overflow del stack si las interrupciones se anidan demasiado profundamente.  

```c
// Control de profundidad de anidamiento
#define MAX_NESTED_INTERRUPTS 8
static int nested_count = 0;

void generic_handler(int irq, struct pt_regs *regs) {
    if (++nested_count > MAX_NESTED_INTERRUPTS) {
        panic("Interrupt nesting overflow");
    }
    
    // ... lógica del handler ...
    
    --nested_count;
}
```

## Estados de Interrupciones
El sistema operativo necesita control fino sobre cuándo las interrupciones pueden ocurrir. Esto se logra mediante mecanismos que permiten habilitar y deshabilitar interrupciones a diferentes niveles de granularidad.  

### Disable/Enable a Nivel de Sistema
El control global de interrupciones se realiza mediante instrucciones que afectan el flag IF del procesador:  

```c
// Macros comunes en kernels Unix
#define local_irq_disable()     asm volatile("cli" ::: "memory")
#define local_irq_enable()      asm volatile("sti" ::: "memory")

// Con salvado y restauración de estado
unsigned long flags;
local_irq_save(flags);      // Guarda estado actual y deshabilita
// ... sección crítica ...
local_irq_restore(flags);   // Restaura estado previo
```
La variante con salvado y restauración es preferible porque no asume que las interrupciones estaban habilitadas antes de entrar a la sección crítica.  

### Disable/Enable por IRQ Específico
En ocasiones es necesario deshabilitar solo una fuente de interrupciones específica, sin afectar a las demás:  

```c
// Deshabilitar IRQ específico en PIC
void disable_irq(int irq) {
    uint16_t port;
    uint8_t value;
    
    if (irq < 8) {
        port = 0x21;    // PIC primario
    } else {
        port = 0xA1;    // PIC secundario
        irq -= 8;
    }
    
    value = inb(port) | (1 << irq);
    outb(port, value);
}
```

Este nivel de control permite, por ejemplo, deshabilitar el IRQ del teclado durante una actualización crítica de las estructuras de entrada, sin afectar el timer del sistema o la red.
\begin{theory}
El sistema de interrupciones es fundamental para implementar:
\begin{itemize}
\item \textbf{Multitasking preemptivo}: Timer interrupts permiten cambios de contexto forzados
\item \textbf{Manejo eficiente de E/S}: Los dispositivos notifican al CPU cuando tienen datos
\item \textbf{Gestión de memoria virtual}: Page faults son excepciones que permiten demand paging
\item \textbf{Comunicación inter-procesos}: Señales se implementan sobre el sistema de interrupciones
\item \textbf{Detección de errores}: Excepciones capturan condiciones anómalas inmediatamente
\end{itemize}
\end{theory}

### Modos de Operación del Procesador
La arquitectura moderna del procesador distingue entre dos modos de operación fundamentales que son la base de toda la seguridad y estabilidad del sistema.  

En **Modo Kernel** (también llamado Supervisor o modo privilegiado), el procesador tiene acceso sin restricciones. Puede ejecutar cualquier instrucción, modificar registros críticos del sistema, acceder directamente a cualquier dispositivo hardware, y reconfigurar aspectos fundamentales de la operación del procesador. Este modo es extremadamente poderoso, pero también extremadamente peligroso: un error en modo kernel puede crashear todo el sistema. Por esta razón, solo el código del sistema operativo ejecuta en este modo.  

En **Modo Usuario** (user mode), el procesador opera con un subconjunto restringido de instrucciones. No puede acceder directamente a hardware, no puede modificar configuraciones críticas del sistema, y no puede acceder a memoria que no le pertenece. Todas las aplicaciones de usuario ejecutan en este modo, lo que las aísla tanto del hardware como entre ellas.  

\begin{infobox}
Esta separación de modos es la base de la seguridad y estabilidad del sistema. Sin ella, cualquier programa podría crashear la máquina o acceder a datos privados de otros procesos. Es la razón por la que un navegador web con errores puede cerrarse sin afectar al resto del sistema.
\end{infobox} 

### Cambio de Procesos
Cuándo por algún motivo existe un cambio de proceso en ejecución (los motivos se verán en detalle mas adelante), se realizan varias tareas que son "transparentes" para el usuario final.  

![Diagrama del cambio de contexto entre procesos, donde el sistema operativo guarda el estado del proceso en ejecución en su PCB y restaura el estado de otro proceso para continuar su ejecución.](src/images/capitulo-01/03.png){style="display: block; margin: auto;" }

\begin{center}
\begin{minipage}{0.45\linewidth}
\textbf{Cambio de procesos en sistemas Unix} \\
Cuando el sistema operativo interrumpe la ejecución de un proceso y decide continuar con otro, se produce un cambio de contexto. Este mecanismo implica la intervención tanto del hardware como del software (kernel). \\[2mm]

\textbf{Rol del Hardware:} \\
El hardware se encarga de detectar la interrupción (timer, E/S o syscall), cambiar automáticamente a modo kernel y guardar información mínima como el contador de programa y los flags. Luego transfiere el control al vector de interrupción correspondiente. \\[2mm]

\textbf{Rol del Software (Kernel):} \\
A partir de allí, el software del kernel toma el control: guarda el estado completo del proceso en su PCB, actualiza las estructuras del planificador y contabiliza uso de CPU y señales pendientes. El scheduler selecciona el nuevo proceso a ejecutar y el kernel restaura su estado desde el PCB.
\end{minipage}%
\hspace{0.05\linewidth}%
\begin{minipage}{0.45\linewidth}
    \includegraphics[width=\linewidth,keepaspectratio]{src/diagrams/cap01-cambioDeProcesos.png}
\end{minipage}
\end{center}

\vspace{3mm}

\begin{center}
\begin{minipage}{\linewidth}
\textbf{Finalización del Proceso:} \\
Antes de retornar al usuario, se actualiza el espacio de direcciones (MMU/TLB) y se realiza el cambio de modo kernel → usuario. \\[2mm]

\textbf{Consideraciones de Performance:} \\
Este procedimiento asegura la correcta continuidad de los procesos, pero introduce un overhead inevitable: acceso a memoria para guardar/restaurar registros, invalidación de TLB y caches, y lógica extra del planificador. Por este motivo, sistemas I/O-bound suelen generar más cambios de contexto que los CPU-bound, y su rendimiento depende en gran medida de la eficiencia del scheduler y de las optimizaciones del hardware.
\end{minipage}
\end{center}  


\begin{center}
\begin{minipage}{0.52\linewidth}
\textbf{Fases del Context Switch en Sistemas Unix} \\[2mm]

\textbf{Fase Inicial - Ejecución Normal:}\\
\textbf{0.} P₀ ejecuta en modo usuario → Estado normal usando su espacio de direcciones y time slice vigente.\\[1mm]

\textcolor{orange!70!black}{\textbf{Detección del Evento [Hardware]:}\\
\textbf{1.} Se dispara evento → Timer interrupt, IRQ de E/S o trap por syscall/exception\\
\textbf{2.} Cambio automático a modo kernel → CPU guarda PC y PSW/EFLAGS, cambia a stack de kernel\\
\textbf{3.} Búsqueda en vector/IDT → Hardware obtiene dirección del handler apropiado\\[1mm]
}

\textcolor{blue!50!black}{\textbf{Guardar Estado [Software]:}\\
\textbf{4.} Prólogo del handler → Kernel salva registros volátiles, arma frame de interrupción\\
\textbf{5.} Decisión de reschedule → Marca need\_resched según tipo de evento\\
\textbf{6.} Guardar contexto de P₀ → Registros GPR, SP, FP, TLS; FPU/SIMD en forma lazy\\
\textbf{7.} Contabilidad y señales → Actualiza uso de CPU, entrega señales pendientes\\[1mm]
}

\textcolor{blue!50!black}{\textbf{Selección y Carga [Software]:}\\
\textbf{8.} Actualizar colas y estado → Mueve P₀ de running → ready/blocked; ajusta prioridad\\
\textbf{9.} Scheduler elige P₁ → Aplica política de planificación (CFS, prioridades, afinidad CPU)\\
\textbf{10.} Preparar espacio de P₁ → Carga CR3/tablas de páginas; puede requerir TLB flush\\
\textbf{11.} Recargar contexto de P₁ → Restaura registros, SP, FP, TLS, stack de usuario\\[1mm]
}
\end{minipage}%
\hspace{0.04\linewidth}%
\begin{minipage}{0.42\linewidth}
    \includegraphics[width=\linewidth,keepaspectratio]{src/diagrams/cap01-cambioDeProcesosCompleto.jpeg}
\end{minipage}
\end{center}

\vspace{2mm}

\textcolor{orange!70!black}{\textbf{Retorno a Ejecución [Hardware]:}\\
\textbf{12.} Epílogo y retorno → Prepara iret/sysret, re-habilita interrupciones\\
\textbf{13.} Kernel → modo usuario → CPU restaura PSW/EFLAGS y PC, salta a P₁\\
\textbf{14.} P₁ ejecuta en modo usuario → Continúa hasta el próximo evento\\[2mm]
}

\begin{warning}
\textbf{Overhead: }\emph{El costo inevitable del cambio de contexto}\\
Cada cambio de contexto tiene un precio en rendimiento que no podemos evitar. Primero está el acceso a memoria para guardar y restaurar todos los registros del procesador, una operación que, aunque rápida, no es instantánea. Pero el impacto va más allá: cuando cambiamos de proceso, la TLB (Translation Lookaside Buffer) y las cachés del procesador quedan invalidadas porque contienen datos del proceso anterior, forzando al nuevo proceso a "cargar" estas estructuras nuevamente desde cero.
\end{warning}
A esto se suma la lógica del planificador mismo: decidir qué proceso ejecutar siguiente, actualizar estadísticas, verificar prioridades. Todo esto consume ciclos de CPU que podrían estar haciendo trabajo útil.
Particularmente crítico es entender que los sistemas I/O-bound (que pasan mucho tiempo esperando entrada/salida) generan significativamente más cambios de contexto que los sistemas CPU-bound (que hacen cálculos intensivos). Esto es porque cada operación de I/O típicamente bloquea el proceso, forzando un context switch. Un servidor web manejando miles de conexiones puede estar cambiando de contexto miles de veces por segundo.


### Introducción a los Sistemas Operativos

Ahora que comprendemos la arquitectura de hardware sobre la cual operan, podemos finalmente definir con precisión qué es un sistema operativo.  

\begin{excerpt}
\emph{Definición:}
Un Sistema Operativo es un conjunto de rutinas y procedimientos manuales y automáticos que permiten la operatoria en un sistema de computación. Es, fundamentalmente, un \textbf{programa de control} que media entre el hardware y los programas de aplicación.
\end{excerpt}  

El sistema operativo no es un programa más: es el programa que hace posible que existan todos los demás programas. Sus responsabilidades abarcan desde el momento en que se enciende la computadora hasta que se apaga, y cada milisegundo de ese tiempo está dedicado a alguna tarea crítica.  
Sus principales tareas incluyen lanzar el Init Program Loader durante el arranque, gestionar todos los recursos del hardware de manera eficiente y justa, proporcionar servicios estandarizados a los programas de aplicación, actuar como intermediario entre usuarios y el hardware bruto, y mantener la seguridad e integridad de todo el sistema. 

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

![Comparación de las principales arquitecturas de núcleo de un sistema operativo: kernel monolítico, microkernel y kernel multicapa, destacando la organización de sus componentes y su relación con el hardware.](src/images/capitulo-01/02.png){style="display: block; margin: auto;" }

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

---

**Próximo Capítulo:** Procesos - donde veremos cómo el SO usa estos mecanismos fundamentales para crear la abstracción de "programa en ejecución", completa con su propio espacio de memoria, registros, y estado.