# Introducción y Arquitectura de Computadores

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante será capaz de:

- **Identificar** los componentes principales de la arquitectura de von Neumann y su relación con el sistema operativo
- **Explicar** la diferencia entre modo kernel y modo usuario, y por qué es fundamental para el SO
- **Describir** el proceso de arranque (boot) y cómo se carga el sistema operativo
- **Analizar** los mecanismos de interrupciones y llamadas al sistema (syscalls)
- **Relacionar** la arquitectura del hardware con las funciones básicas del sistema operativo

## Introducción y Contexto

### ¿Por qué necesitamos entender la arquitectura?

Imaginá que querés entender cómo funciona un auto. Podrías aprender a manejarlo sin saber nada del motor, pero si quieres ser mecánico, necesitas entender pistones, válvulas, y transmisión. 

Con los sistemas operativos pasa lo mismo. Puedes usar una computadora sin entender qué hay "debajo del capó", pero **para diseñar, optimizar o debuggear un SO, necesitas entender el hardware que administra**.

### Los problemas que resuelve esta arquitectura

**Problema 1: ¿Cómo puede software controlar hardware?**
- El procesador solo entiende instrucciones binarias
- Los dispositivos tienen interfaces completamente diferentes
- Se necesita un "traductor" entre programas y circuitos

**Problema 2: ¿Cómo proteger el sistema de programas maliciosos?**
- Un programa bugueado podría crashear toda la máquina
- Múltiples programas compiten por los mismos recursos
- Se necesitan "niveles de privilegio" y protección

**Problema 3: ¿Cómo manejar eventos impredecibles?**
- El usuario presiona una tecla en cualquier momento
- Llegan datos por la red de forma asincrónica
- Se necesita un mecanismo para "interrumpir" la ejecución normal  


## Conceptos Fundamentales

### Arquitectura de von Neumann

La arquitectura básica de casi todas las computadoras modernas:

**Componentes principales:**
- **CPU (Unidad Central de Procesamiento)**
  - Unidad de Control (CU): decodifica y ejecuta instrucciones
  - Unidad Aritmético-Lógica (ALU): realiza operaciones matemáticas
  - Registros: almacenamiento ultrarrápido dentro del procesador

- **Memoria Principal (RAM)**
  - Almacena programas y datos temporalmente
  - Acceso directo y aleatorio
  - Volátil (se pierde al apagar)

- **Almacenamiento Secundario**
  - Discos duros, SSD, etc.
  - Persistente pero más lento
  - Mayor capacidad

- **Dispositivos de E/S**
  - Teclado, mouse, pantalla, red, etc.
  - Interfaces para interactuar con el mundo exterior

![Diagrama de un Computador](src/images/capitulo-01/01.png){ width=350 height=265 style="display: block; margin: auto;" }



### Buses de Comunicación

Los **buses** son las "autopistas" que conectan los componentes del sistema. Sin ellos, CPU, memoria y dispositivos estarían aislados.

**Tipos de Buses:**

1. **Bus de Datos**
   - Transporta la información real (instrucciones, datos)
   - Ancho determina cantidad de bits transferidos simultáneamente
   - Ejemplo: bus de 64 bits puede transferir 8 bytes por ciclo

2. **Bus de Direcciones**
   - Especifica la ubicación de memoria a acceder
   - Ancho determina máximo espacio de direcciones
   - Ejemplo: 32 bits = 4GB máximo, 64 bits = 16 exabytes

3. **Bus de Control**
   - Coordina las operaciones (lectura, escritura, interrupciones)
   - Señales como: READ, WRITE, IRQ, RESET
   - Sincroniza transferencias entre componentes


### Registros del Procesador

Los registros son la memoria más rápida y cara del sistema. Están físicamente dentro de la CPU.

**Registros Visibles al Usuario (Modo Usuario):**

- **Registros de Propósito General**
  - EAX, EBX, ECX, EDX (x86-32)
  - RAX, RBX, RCX, RDX, etc. (x86-64)
  - Usados para cálculos y almacenamiento temporal

- **Registros de Índice**
  - ESI (Source Index), EDI (Destination Index)
  - Útiles para operaciones con strings y arrays

- **Registro Puntero de Stack (ESP/RSP)**
  - Apunta al tope del stack actual
  - Crítico para manejo de funciones y variables locales

- **Registro Base del Stack (EBP/RBP)**
  - Frame pointer para acceso a parámetros y variables locales

**Registros Privilegiados (Solo Modo Kernel):**

- **Registro de Control (CR0, CR2, CR3, CR4)**
  - CR0: Control de características del procesador
  - CR2: Dirección que causó page fault
  - CR3: Directorio de páginas actual (MMU)

- **Registros de Segmento en Modo Kernel**
  - CS (Code Segment), DS (Data Segment), SS (Stack Segment)
  - Críticos para protección de memoria

### Program Status Word (PSW)

El **PSW** (también llamado FLAGS register) contiene información sobre el estado actual del procesador:

**Flags de Condición:**  
- **Zero Flag (ZF)**: Se activa si el resultado de una operación es cero  
- **Carry Flag (CF)**: Indica acarreo en operaciones aritméticas  
- **Sign Flag (SF)**: Indica si el resultado es negativo  
- **Overflow Flag (OF)**: Desbordamiento en aritmética con signo  

**Flags de Control:**  
- **Interrupt Enable Flag (IF)**: Habilita/deshabilita interrupciones enmascarables  
- **Direction Flag (DF)**: Dirección para operaciones de string  
- **Trap Flag (TF)**: Modo single-step para debugging  

**Flags de Sistema:**  
- **I/O Privilege Level (IOPL)**: Nivel de privilegio para operaciones de E/S  
- **Nested Task Flag (NT)**: Indica tarea anidada  
- **Resume Flag (RF)**: Control de debugging  

### Ciclo de Instrucción

\begin{center}
\begin{minipage}{0.55\linewidth}
    \includegraphics[width=0.8\linewidth,keepaspectratio]{src/diagrams/cap01-cicloInstruccion.png}
\end{minipage}%
\hspace{0.05\linewidth}%
\begin{minipage}{0.35\linewidth}
\textbf{Fase 1: FETCH} \\
PC apunta a próxima instrucción → se carga en IR → PC se incrementa automáticamente. \\[2mm]

\textbf{Fase 2: DECODE} \\
Unidad de Control interpreta la instrucción → determina operación y operandos → prepara rutas de datos. \\[2mm]

\textbf{Fase 3: OPERAND FETCH} \\
Si la instrucción requiere datos: dirección en bus → dato desde memoria → carga en registro temporal/ALU. \\[2mm]

\textbf{Fase 4: EXECUTE} \\
ALU ejecuta la operación → actualización de registros y flags → resultados a memoria si aplica. \\[2mm]

\textbf{Fase 5: WRITE BACK} \\
Resultados transferidos a registro destino → PSW actualizado → CPU lista para nuevo ciclo. \\[2mm]

\textbf{Fase 0: CHECK INTERRUPT} \\
Se verifica interrupción → si hay ISR: guarda contexto, salta a rutina de servicio → al terminar, retorno al ciclo normal.
\end{minipage}
\end{center}

## Sistema de Interrupciones

Las interrupciones son el mecanismo fundamental que permite al SO mantener control sobre el hardware y gestionar múltiples tareas de manera eficiente.

\begin{definitionbox}
\emph{Definición:}  


Mecanismo hardware que permite detener temporalmente la ejecución normal del procesador para atender un evento urgente.
\end{definitionbox}

**Tipos de Interrupciones:**

1. **Interrupciones de Hardware:**
   - Generadas por dispositivos externos
   - Ejemplos: teclado, timer, red
   - Asincrónicas (impredecibles)

2. **Interrupciones de Software:**
   - Generadas por instrucciones del programa
   - Ejemplos: syscalls, excepciones
   - Sincrónicas (predecibles)

3. **Excepciones:**
   - Errores durante la ejecución
   - Ejemplos: división por cero, acceso a memoria inválida

\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-01/bloque-interrupciones.png}
\end{center}

### Interrupciones Enmascarables (Maskable Interrupts)  

Pueden ser temporalmente deshabilitadas por software mediante el control del bit IF (Interrupt Flag) en el registro de estado del procesador (PSW/EFLAGS).
\end{definitionbox}


**Control**: 
- **CLI** (Clear Interrupt Flag): Deshabilita interrupciones  
- **STI** (Set Interrupt Flag): Habilita interrupciones  

**Ejemplos**:  
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

### Interrupciones No Enmascarables (NMI - Non-Maskable Interrupts)

**Definición**: NO pueden ser deshabilitadas por software, tienen prioridad absoluta y se ejecutan inmediatamente.

**Propósito**: Eventos críticos que requieren atención inmediata del sistema.

**Ejemplos**:
- Errores de paridad en memoria RAM
- Fallas críticas de hardware (sobrecalentamiento)
- Watchdog timer (detecta sistema colgado)
- Errores del bus del sistema
- Fallos de alimentación inminentes

**Prioridad**: Máxima - pueden interrumpir incluso al kernel en secciones críticas.

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

## Interrupt Handlers (Manejadores de Interrupción)

### Estructura de un Handler

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

### Interrupciones Anidadas

**Concepto**: Capacidad de que una interrupción de mayor prioridad interrumpa el procesamiento de una de menor prioridad.

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

### Características de Interrupciones Anidadas

**Ventajas**:
- Mejor tiempo de respuesta para eventos críticos
- Priorización automática de eventos
- Maximiza el rendimiento del sistema

**Desafíos**:
- Complejidad en la gestión del stack
- Posibles deadlocks si no se maneja correctamente
- Overflow del stack en cascadas profundas

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

### Disable/Enable a Nivel de Sistema

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

### Disable/Enable por IRQ Específico

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

Este sistema de interrupciones es fundamental para:  
- **Multitasking preemptivo**: Timer interrupts permiten cambios de contexto  
- **Manejo de E/S**: Respuesta eficiente a dispositivos  
- **Gestión de memoria**: Page faults y gestión de memoria virtual  
- **Comunicación inter-procesos**: Señales y sincronización  
- **Detección de errores**: Excepciones y fallos de hardware  
### Modos de Operación del Procesador

**Modo Kernel (Supervisor/Privilegiado):**
- Acceso completo a todas las instrucciones del procesador
- Puede modificar registros críticos del sistema
- Puede acceder directamente a hardware
- Solo el SO ejecuta en este modo

**Modo Usuario (User Mode):**
- Subconjunto restringido de instrucciones
- No puede acceder directamente a hardware
- No puede modificar configuraciones críticas
- Aplicaciones ejecutan en este modo


\textcolor{blue!50!black}{\textbf{¿Por qué es importante?}\\
Esta separación es la base de la seguridad y estabilidad del sistema. Sin ella, cualquier programa podría crashear la máquina o acceder a datos privados. Más adelante se verá como se las arreglan las aplicaciones de usuario para realizar tareas "privilegiadas".
}

### Cambio de Procesos
Cuándo por algún motivo existe un cambio de proceso en ejecución (los motivos se verán en detalle mas adelante), se realizan varias tareas que son "transparentes" para el usuario final.  

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

\textcolor{blue!50!black}{\textbf{Fase Inicial - Ejecución Normal:}\\
\textbf{0.} P₀ ejecuta en modo usuario → Estado normal usando su espacio de direcciones y time slice vigente.\\[2mm]
}

\textcolor{orange!70!black}{\textbf{Detección del Evento [Hardware]:}\\
\textbf{1.} Se dispara evento → Timer interrupt, IRQ de E/S o trap por syscall/exception\\
\textbf{2.} Cambio automático a modo kernel → CPU guarda PC y PSW/EFLAGS, cambia a stack de kernel\\
\textbf{3.} Búsqueda en vector/IDT → Hardware obtiene dirección del handler apropiado\\[2mm]
}

\textcolor{violet!60!black}{\textbf{Guardar Estado [Software]:}\\
\textbf{4.} Prólogo del handler → Kernel salva registros volátiles, arma frame de interrupción\\
\textbf{5.} Decisión de reschedule → Marca need\_resched según tipo de evento\\
\textbf{6.} Guardar contexto de P₀ → Registros GPR, SP, FP, TLS; FPU/SIMD en forma lazy\\
\textbf{7.} Contabilidad y señales → Actualiza uso de CPU, entrega señales pendientes\\[2mm]
}

\textcolor{teal!60!black}{\textbf{Selección y Carga [Software]:}\\
\textbf{8.} Actualizar colas y estado → Mueve P₀ de running → ready/blocked; ajusta prioridad\\
\textbf{9.} Scheduler elige P₁ → Aplica política de planificación (CFS, prioridades, afinidad CPU)\\
\textbf{10.} Preparar espacio de P₁ → Carga CR3/tablas de páginas; puede requerir TLB flush\\
\textbf{11.} Recargar contexto de P₁ → Restaura registros, SP, FP, TLS, stack de usuario\\[2mm]
}
\end{minipage}%
\hspace{0.04\linewidth}%
\begin{minipage}{0.42\linewidth}
    \includegraphics[width=\linewidth,keepaspectratio]{src/diagrams/cap01-cambioDeProcesosCompleto.jpeg}
\end{minipage}
\end{center}

\vspace{2mm}

\textcolor{green!40!black}{\textbf{\\Retorno a Ejecución [Hardware]:}\\
\textbf{12.} Epílogo y retorno → Prepara iret/sysret, re-habilita interrupciones\\
\textbf{13.} Kernel → modo usuario → CPU restaura PSW/EFLAGS y PC, salta a P₁\\
\textbf{14.} P₁ ejecuta en modo usuario → Continúa hasta el próximo evento\\[2mm]
}

\textcolor{red!60!gray}{\textbf{Overhead inevitable:}\\
Acceso a memoria para guardar/restaurar registros → Invalidación de TLB y caches → Lógica extra del planificador → Sistemas I/O-bound generan más context switches que CPU-bound.\\
}


### Introducción a los Sistemas Operativos

Ahora que entendemos el hardware, podemos definir qué es realmente un sistema operativo.
  
\begin{definitionbox}
\emph{Definición:}  


Un Sistema Operativo es un conjunto de rutinas y procedimientos manuales y automáticos que permiten la operatoria en un sistema de computación, es un \textbf{programa de control.}
\end{definitionbox}  


Sus principales tareas son:  
1. **IPL** Se encarga de lanzar el Init Program Loader  
2. **Gestiona los recursos** del hardware de manera eficiente  
3. **Proporciona servicios** a los programas de aplicación  
4. **Actúa como intermediario** entre usuarios y hardware (gestión de usuarios)  
5. **Mantiene la seguridad e integridad** del sistema  

### Principales Tareas del Sistema Operativo

**1. Gestión de Procesos**
- Crear, planificar y terminar procesos
- Proporcionar mecanismos de comunicación entre procesos
- Manejar la sincronización y evitar deadlocks

**2. Gestión de Memoria**
- Asignar y liberar memoria a procesos
- Implementar memoria virtual
- Proteger espacios de memoria entre procesos

**3. Gestión de Almacenamiento**
- Organizar archivos en sistemas de archivos
- Controlar acceso a dispositivos de almacenamiento
- Implementar políticas de respaldo y recuperación

**4. Gestión de E/S**
- Controlar todos los dispositivos del sistema
- Proporcionar interfaz uniforme para acceso a dispositivos
- Buffering, caching y spooling

**5. Seguridad y Protección**
- Autenticación de usuarios
- Control de acceso a recursos
- Protección entre procesos y del sistema

**6. Interfaz de Usuario**
- Command Line Interface (CLI)
- Graphical User Interface (GUI)
- APIs para programadores

### System Calls (Llamadas al Sistema)

\begin{definitionbox}
\emph{Definición:}  


Las System Calls son un mecanismo mediante el cual los programas solicitan servicios al SO (acceso a hardware, creación de procesos, etc.)
\end{definitionbox}

**¿Por qué existen?**
- **Protección**: Impiden acceso directo no controlado al hardware  
- **Abstracción**: Proporcionan interfaz uniforme independiente del hardware específico  
- **Eficiencia**: Centralizan funciones comunes del sistema  
- **Portabilidad**: La misma API funciona en diferentes hardware  

**Mecanismo Tradicional:**
```
1. Programa prepara parámetros
2. Ejecuta instrucción INT (interrupt)
3. CPU cambia a modo kernel
4. Kernel identifica syscall solicitada
5. Kernel ejecuta función correspondiente
6. Kernel retorna resultado
7. CPU vuelve a modo usuario
```

**Ejemplo en Linux (x86):**
```assembly
mov eax, 4          ; syscall number para sys_write
mov ebx, 1          ; file descriptor (stdout)
mov ecx, msg        ; puntero al mensaje
mov edx, len        ; longitud del mensaje
int 0x80            ; interrupción de software
```

### Fast System Calls

**Problema con syscalls tradicionales:**
Las interrupciones de software (INT) son relativamente lentas porque:
- Deben guardar todo el contexto del procesador
- Requieren consultar tabla de vectores de interrupción
- Overhead de cambio de modo es considerable. (Overhead no es "sobre cabeza" cuack!. Es el tiempo que el CPU "pierde" realizando tareas que no son propias de los procesos).

**Solución: Fast System Calls**

**SYSENTER/SYSEXIT (Intel):**
```assembly
; Preparar registros específicos
mov eax, syscall_number
mov edx, return_address
mov ecx, user_stack
sysenter            ; Entrada rápida al kernel
; ... kernel ejecuta syscall ...
sysexit             ; Retorno rápido a usuario
```

**SYSCALL/SYSRET (AMD/Intel x86-64):**
```assembly
mov rax, syscall_number
mov rdi, arg1
mov rsi, arg2
syscall             ; Entrada directa al kernel
; Resultado en RAX al retornar
```

**Ventajas de Fast Syscalls:**
- **50-70% más rápidas** que INT tradicional
- Menos overhead de cambio de contexto
- Registros específicos en lugar de stack
- Transición directa sin consultar vectores

**Uso en Linux Moderno:**
- **x86-32**: SYSENTER es el método preferido
- **x86-64**: SYSCALL es el estándar
- **ARM**: SVC (Supervisor Call) instruction
- Biblioteca glibc automáticamente elige el método más eficiente

### Arquitecturas de Kernel

La organización interna del kernel afecta directamente el rendimiento, seguridad y mantenibilidad del SO.

**Kernel Monolítico:**

*Características:*  
- **Todo el SO ejecuta en modo kernel**  
- Drivers, filesystem, network stack en un solo espacio de direcciones  
- Comunicación interna mediante llamadas a función directas  
- Un solo binario grande del kernel  

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Rendimiento superior: Sin overhead de comunicación entre componentes\\
- Acceso directo: Todos los subsistemas pueden llamarse entre sí\\
- Eficiencia: Menos cambios de contexto\\
- Simplicidad de debugging: Todo está en un lugar\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Menor estabilidad: Un bug en cualquier driver puede crashear todo el sistema\\
- Seguridad: Todo código tiene privilegios máximos\\
- Tamaño: Kernel grande consume más memoria\\
- Mantenimiento: Más difícil modificar sin afectar otros componentes\\
}

*Ejemplos:* Linux, Unix tradicional, Windows (parcialmente)

**Microkernel:**

*Características:*  
- **Kernel mínimo** solo con funciones esenciales  
- Drivers y servicios ejecutan como procesos separados en modo usuario  
- Comunicación mediante paso de mensajes (IPC)  
- Kernel solo maneja: scheduling, IPC, memoria básica  

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- **Mayor estabilidad**: Falla de driver no afecta al kernel\\
- **Seguridad mejorada**: Servicios con privilegios mínimos necesarios\\
- **Modularidad**: Fácil agregar/quitar componentes\\
- **Debugging**: Aislamiento facilita encontrar problemas\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- **Rendimiento menor**: Overhead de IPC entre componentes\\
- **Complejidad**: Más difícil de diseñar y implementar\\
- **Latencia**: Múltiples cambios de contexto para operaciones simples\\
}

*Ejemplos:* Minix, QNX, seL4, Hurd (GNU)

**Comparación Práctica:**  

![Comparacion distintos kernel](src/images/capitulo-01/02.png){ width=440px height=260px }  

| Aspecto | Monolítico | Microkernel |
|---------|------------|-------------|
| Rendimiento | Excelente | Bueno |
| Estabilidad | Regular | Excelente |
| Seguridad | Regular | Excelente |
| Simplicidad | Alta | Baja |
| Tiempo de desarrollo | Menor | Mayor |

**Enfoques Híbridos:**
Muchos SO modernos combinan ambos enfoques:  
- **Windows NT**: Microkernel modificado con algunos servicios en kernel  
- **macOS**: Mach microkernel + BSD kernel monolítico  
- **Linux**: Principalmente monolítico pero con módulos cargables  


## Análisis Técnico (Leelo sólo por curiosidad...)

### Proceso de Arranque (Bootstrap)

**Secuencia de Arranque:**

1. **Power-On Self Test (POST)**
   - Verificación básica de hardware
   - Ejecutado por firmware (BIOS/UEFI)

2. **Carga del Bootloader**
   - Programa pequeño que sabe cómo cargar el SO
   - Ubicado en Master Boot Record (MBR) o partición EFI

3. **Carga del Kernel**
   - Bootloader lee el kernel del disco a memoria
   - Transfiere control al kernel

4. **Inicialización del Kernel**
   - Detección e inicialización de hardware
   - Configuración de estructuras de datos internas
   - Arranque del primer proceso (init)

### Manejo de Interrupciones

**Vector de Interrupciones:**
Tabla que mapea cada tipo de interrupción a su rutina de manejo correspondiente.

**Proceso de Manejo:**  
1. **Ocurre Interrupción** → Hardware detiene ejecución actual  
2. **Guardar Contexto** → Estado actual se guarda en stack  
3. **Identificar Tipo** → Consultar vector de interrupciones  
4. **Ejecutar Handler** → Rutina específica en modo kernel  
5. **Restaurar Contexto** → Volver al estado anterior  
6. **Continuar Ejecución** → Resumir programa interrumpido  

### Jerarquía de Memoria

**Pirámide de Memoria (velocidad vs capacidad):**
```
Registros CPU (1 ciclo, bytes)
    ↓
Cache L1 (2-4 ciclos, KB)
    ↓  
Cache L2 (10-20 ciclos, MB)
    ↓
Memoria Principal RAM (100-300 ciclos, GB)
    ↓
Almacenamiento Secundario (millones de ciclos, TB)
```

**Implicaciones para el SO:**  
- Gestión de cache es crítica para rendimiento  
- Necesidad de memoria virtual cuando RAM es insuficiente  
- Algoritmos de reemplazo para optimizar accesos  


## Código en C

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

**Análisis línea por línea:**  
- `#include <sys/utsname.h>`: Header para la estructura utsname  
- `uname(&system_info)`: **Syscall** que obtiene info del sistema  
- `getpid()`, `getppid()`, `getuid()`: **Syscalls** para IDs de proceso y usuario  
- Cada función provoca una **transición modo usuario → modo kernel**

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

**Conceptos demostrados:**  
- **Señales**: Mecanismo de comunicación asincrónica  
- **signal()**: Syscall para registrar manejadores  
- **Interrupción de software**: Ctrl+C genera SIGINT  
- **Context switching**: El SO interrumpe el programa para ejecutar el handler  


## Casos de Estudio

### Caso 1: Análisis de una Syscall

**Enunciado:** Analice qué sucede cuando un programa ejecuta `printf("Hola mundo\n");` desde las perspectivas de hardware y sistema operativo.

**Resolución Paso a Paso:**

1. **Análisis del Código:**
   - `printf()` es una función de biblioteca (libc)
   - Internamente llama a la syscall `write()`
   - Debe escribir en stdout (file descriptor 1)

2. **Secuencia de Ejecución:**
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

3. **Cambios de Contexto:**
   - **Usuario → Kernel**: Se guardan registros, se cambia stack
   - **Kernel → Usuario**: Se restauran registros, se retorna valor

4. **Puntos Clave para Parcial:**
   - printf() NO es una syscall directa
   - Hay cambio de modo de operación
   - El kernel valida permisos antes de escribir
   - File descriptor 1 representa stdout por convención



## Síntesis

### Puntos Clave del Capítulo

1. **La arquitectura hardware determina las capacidades del SO**
   - Von Neumann establece el modelo básico
   - Modos de operación permiten protección
   - Interrupciones habilitan multitasking

2. **El SO es el intermediario entre software y hardware**
   - Syscalls proporcionan servicios controlados
   - Abstrae complejidades del hardware
   - Mantiene seguridad y estabilidad

3. **Rendimiento depende de entender la jerarquía de memoria**
   - Localidad temporal y espacial
   - Cache management es crítico
   - Accesos a disco son el cuello de botella

### Conexiones con Próximos Capítulos

- **Procesos (Cap. 2)**: Los modos de operación y syscalls son fundamentales para entender cómo el SO crea y gestiona procesos
- **Planificación (Cap. 3)**: Las interrupciones de timer permiten al SO implementar multitasking preemptivo
- **Memoria (Caps. 7-8)**: La jerarquía de memoria y la MMU (Memory Management Unit) son la base de la gestión de memoria

### Errores Comunes en Parciales

**"printf() es una syscall"** 
printf() usa la syscall write() internamente

**"Las interrupciones solo vienen del hardware"**
También existen interrupciones de software (syscalls, excepciones)

**"El modo kernel es más rápido"**
El modo kernel tiene más privilegios, no necesariamente más velocidad


---

**Próximo Capítulo:** Procesos - donde veremos cómo el SO usa estos mecanismos fundamentales para crear la abstracción de "programa en ejecución".