# Repaso Arquitectura de Computadores
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

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/arquitectura-de-computadores/01.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Diagrama de la arquitectura básica de una computadora, basado en el modelo de von Neumann, donde se muestran los principales componentes del sistema y su interconexión: CPU, memoria principal y dispositivos de entrada/salida.
}
\end{center}

Esta arquitectura se compone de cuatro subsistemas principales que trabajan en conjunto. La **CPU** (Unidad Central de Procesamiento) es el cerebro del sistema, conteniendo la Unidad de Control que decodifica y ejecuta instrucciones, la Unidad Aritmético-Lógica que realiza operaciones matemáticas y lógicas, y un conjunto de registros que proporcionan almacenamiento ultrarrápido dentro del procesador mismo.  
La **Memoria Principal** (RAM) almacena tanto programas como datos de forma temporal. Su característica de acceso directo y aleatorio significa que cualquier ubicación puede ser accedida en tiempo constante, pero su naturaleza volátil implica que todo su contenido se pierde al apagar el sistema.  
El **Almacenamiento Secundario** complementa a la RAM proporcionando persistencia. Los discos duros, SSD y otros medios de almacenamiento son significativamente más lentos que la RAM, pero mantienen la información incluso sin energía eléctrica y ofrecen capacidades mucho mayores.
Los **Dispositivos de E/S** son las interfaces que permiten al sistema interactuar con el mundo exterior: teclado, mouse, pantalla, tarjetas de red, y una variedad de periféricos especializados. 

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
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/images/tables/cap01-psw_register.png}
\end{center}  

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
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/arquitectura-de-computadores/bloque-interrupciones.png}
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

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/arquitectura-de-computadores/03.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Diagrama del cambio de contexto entre procesos, donde el sistema operativo guarda el estado del proceso en ejecución en su PCB y restaura el estado de otro proceso para continuar su ejecución.
}
\end{center}

<!-- 
![Diagrama del cambio de contexto entre procesos, donde el sistema operativo guarda el estado del proceso en ejecución en su PCB y restaura el estado de otro proceso para continuar su ejecución.](src/images/arquitectura-de-computadores/03.png){ width=0.8\linewidth height=370px style="display: block; margin: auto;" }
 -->
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

### Resumen y Hoja de Ruta

En este libro recorreremos el sistema operativo desde sus cimientos hasta sus aspectos más sofisticados, construyendo conocimiento de forma incremental y conectada.

Los primeros capítulos establecen los **fundamentos**. Comenzamos con arquitectura de computadores porque para entender cómo funciona un sistema operativo necesitás entender el hardware que gestiona. Después introducimos el concepto de proceso, que es la abstracción fundamental sobre la que se construye todo lo demás.

\begin{infobox}
Estructura del Libro:\\
- Capítulos 1-2: Fundamentos - Arquitectura de computadores y concepto de proceso\\
- Capítulos 3-7: Concurrencia - Planificación, hilos, sincronización e interbloqueos\\
- Capítulos 8-9: Memoria - Gestión de memoria real y virtual\\
- Capítulo 10: Almacenamiento - Sistemas de archivos\\
- Capitulo 11: I/O - Gestión de Dispositivos\\
\end{infobox}

La sección de **concurrencia** es el corazón del libro. Acá estudiamos cómo el sistema operativo crea la ilusión de múltiples actividades simultáneas: cómo planifica qué proceso se ejecuta en cada momento, cómo los hilos permiten paralelismo dentro de un proceso, cómo se sincronizan accesos a recursos compartidos, y cómo se previenen y resuelven interbloqueos. Esta sección es particularmente importante porque los problemas de concurrencia están entre los más sutiles y difíciles de la programación de sistemas.

La **gestión de memoria** empieza con lo básico: cómo se asigna y libera memoria, cómo se protegen los espacios de direcciones de diferentes procesos. Después avanzamos hacia memoria virtual, una de las abstracciones más elegantes de la computación moderna, que hace que cada proceso "vea" su propio espacio de direcciones continuo e independiente, sin importar cómo esté realmente organizada la memoria física.

El capítulo de **sistemas de archivos** muestra cómo toda la información que los procesos manipulan en memoria puede persistirse en almacenamiento permanente. Acá conectamos muchos conceptos anteriores: procesos que acceden a archivos, memoria que se mapea desde archivos, y sincronización para accesos concurrentes al sistema de archivos.  

Finalmente, la **gestión de I/O y dispositivos** cierra el círculo completando el cuarto pilar fundamental. Este capítulo integra todo lo anterior: procesos que esperan por operaciones de entrada/salida, planificación que debe considerar dispositivos lentos vs. rápidos, memoria que se usa como buffer para I/O, y la compleja interacción entre el sistema operativo y el hardware heterogéneo. Entender I/O es entender cómo el sistema operativo realmente se comunica con el mundo exterior.  

Cada tema se construye deliberadamente sobre los anteriores. No podés entender memoria virtual sin entender procesos, no podés entender sincronización sin entender concurrencia, no podés entender sistemas de archivos sin entender gestión de memoria, y no podés entender I/O sin comprender cómo todos estos subsistemas interactúan. Por eso es importante seguir el orden, aunque después puedas volver a capítulos específicos para referencia o repaso.  

Al final de este recorrido, vas a tener una comprensión integral de cómo funciona realmente el software más importante de tu computadora: ese conjunto de abstracciones, políticas y mecanismos que transforman metal y silicio en una máquina útil, segura y eficiente.