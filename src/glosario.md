# Glosario de Términos

Este glosario recopila los términos técnicos más importantes utilizados a lo largo del libro. Se mantiene la nomenclatura en inglés seguida de su traducción al español cuando corresponde.

---

## A

**Address Space** (Espacio de direcciones): Conjunto de direcciones de memoria que un proceso puede utilizar. En sistemas con memoria virtual, cada proceso tiene su propio espacio de direcciones virtual independiente.

**Aging** (Envejecimiento): Técnica utilizada en algoritmos de planificación para prevenir *starvation*. Incrementa gradualmente la prioridad de procesos que llevan mucho tiempo esperando.

**Atomic Operation** (Operación atómica): Operación que se ejecuta completamente o no se ejecuta en absoluto, sin estados intermedios visibles. No puede ser interrumpida y es indivisible desde el punto de vista de otros procesos o hilos.

## B

**Backing Store**: Área de almacenamiento secundario (generalmente disco) utilizada para mantener páginas que fueron removidas de memoria principal en sistemas de memoria virtual.

**Blocking** (Bloqueo): Estado en el que un proceso o hilo no puede continuar su ejecución hasta que ocurra algún evento específico (I/O, señal, liberación de recurso).

**Busy Waiting** (Espera activa): Técnica de sincronización donde un proceso o hilo consume ciclos de CPU activamente verificando una condición en un loop hasta que se cumpla. Ineficiente pero útil en contextos específicos.

**Burst**: Período continuo de actividad. *CPU burst* es el tiempo que un proceso usa la CPU antes de bloquearse, *I/O burst* es el tiempo dedicado a operaciones de entrada/salida.

## C

**Cache**: Memoria pequeña y rápida que almacena copias de datos frecuentemente accedidos para reducir el tiempo de acceso promedio.

**Context Switch** (Cambio de contexto): Proceso de guardar el estado de un proceso o hilo y restaurar el estado de otro. Incluye registros de CPU, contador de programa, puntero de pila y otra información de estado.

**Critical Section** (Sección crítica): Segmento de código que accede a recursos compartidos y que no debe ser ejecutado concurrentemente por más de un hilo o proceso.

**CPU-bound**: Proceso que pasa la mayor parte de su tiempo usando la CPU, realizando cálculos intensivos. Contrasta con *I/O-bound*.

## D

**Daemon** (Demonio): Proceso que corre en background, típicamente iniciado al arranque del sistema, que proporciona servicios sin interacción directa del usuario.

**Deadlock** (Interbloqueo, Abrazo mortal): Situación donde dos o más procesos están esperando indefinidamente por recursos que están siendo retenidos por otros procesos del mismo conjunto.

**Device Driver** (Controlador de dispositivo): Software que proporciona una interfaz entre el sistema operativo y un dispositivo de hardware específico.

**DMA (Direct Memory Access)**: Característica que permite a ciertos subsistemas de hardware acceder a memoria del sistema independientemente de la CPU, reduciendo la carga de procesamiento para operaciones de I/O.

## F

**File Descriptor** (Descriptor de archivo): Entero que identifica un archivo abierto en un proceso. En Unix/Linux, los descriptores 0, 1 y 2 son stdin, stdout y stderr respectivamente.

**Fork**: Syscall en Unix/Linux que crea un nuevo proceso (hijo) duplicando el proceso actual (padre). El proceso hijo es una copia casi exacta del padre.

**Fragmentation** (Fragmentación): Desperdicio de espacio de memoria o almacenamiento. *Externa*: espacios libres no contiguos que no pueden usarse. *Interna*: espacio desperdiciado dentro de bloques asignados.

**Frame**: Unidad física de memoria. En memoria virtual, la memoria física se divide en frames de tamaño fijo (típicamente 4KB) donde se cargan las páginas.

## I

**I/O-bound**: Proceso que pasa la mayor parte de su tiempo esperando operaciones de entrada/salida. Genera muchos *context switches*.

**Interrupt** (Interrupción): Señal al procesador indicando que un evento requiere atención inmediata. Causa que el procesador suspenda su ejecución actual y ejecute un *interrupt handler*.

**IPC (Inter-Process Communication)**: Mecanismos que permiten a procesos intercambiar datos y sincronizar sus acciones. Incluyen pipes, sockets, memoria compartida, colas de mensajes, etc.

**IRQ (Interrupt Request)**: Línea de hardware utilizada por dispositivos para señalar al procesador que requieren atención.

## K

**Kernel** (Núcleo): Componente central del sistema operativo que tiene control completo sobre el hardware y opera en modo privilegiado (*kernel mode*).

**Kernel Mode** (Modo núcleo, Modo supervisor): Modo de operación de la CPU que permite ejecución de todas las instrucciones y acceso a todo el hardware. Opuesto a *user mode*.

**Kernel Space**: Área de memoria reservada para el kernel del sistema operativo, inaccesible directamente desde *user space*.

## L

**Latency** (Latencia): Tiempo de retardo entre el inicio de una solicitud y el comienzo de su respuesta. Diferente de *throughput*.

**Livelock**: Situación similar a *deadlock* donde procesos cambian constantemente su estado en respuesta a otros procesos sin hacer progreso real.

**Lock** (Cerrojo, Candado): Mecanismo de sincronización que previene el acceso simultáneo a un recurso compartido. Puede ser *mutex* (mutual exclusion) o *read-write lock*.

## M

**Memory Leak** (Fuga de memoria): Error de programación donde memoria asignada dinámicamente no es liberada cuando ya no es necesaria, causando pérdida gradual de memoria disponible.

**MMU (Memory Management Unit)**: Componente de hardware responsable de traducir direcciones virtuales a direcciones físicas y hacer cumplir las protecciones de memoria.

**Mutex** (Mutual Exclusion): Mecanismo de sincronización que permite a un solo hilo acceder a un recurso compartido a la vez. Ver *lock*.

## O

**Overhead** (Sobrecarga): Trabajo adicional o recursos consumidos por el sistema operativo para gestionar recursos, que no contribuye directamente al trabajo útil de las aplicaciones. Por ejemplo, el tiempo de *context switch*.

## P

**Page** (Página): Unidad lógica de memoria en sistemas de memoria virtual. Los espacios de direcciones de procesos se dividen en páginas de tamaño fijo.

**Page Fault** (Fallo de página): Excepción que ocurre cuando un proceso intenta acceder a una página que no está actualmente en memoria física. El sistema operativo debe cargarla desde *backing store*.

**Page Table** (Tabla de páginas): Estructura de datos que mantiene el mapeo entre direcciones virtuales (páginas) y direcciones físicas (frames).

**PCB (Process Control Block)**: Estructura de datos en el kernel que contiene toda la información necesaria para gestionar un proceso (PID, estado, registros, prioridad, etc.).

**PID (Process ID)**: Identificador numérico único asignado a cada proceso por el sistema operativo.

**Pipe** (Tubería): Mecanismo de IPC que permite comunicación unidireccional entre procesos, típicamente entre proceso padre e hijo.

**Polling**: Técnica donde el procesador verifica repetidamente el estado de un dispositivo para determinar si está listo. Alternativa a *interrupts*.

**Preemption** (Apropiación, Desalojo): Acción del planificador de interrumpir un proceso en ejecución para dar la CPU a otro proceso de mayor prioridad o porque expiró su quantum.

**Priority Inversion** (Inversión de prioridad): Situación donde un proceso de baja prioridad retiene un recurso necesitado por uno de alta prioridad, efectivamente invirtiendo sus prioridades.

**Process** (Proceso): Programa en ejecución. Incluye el código del programa, datos, pila, heap, y estado de ejecución.

## Q

**Quantum** (Cuanto de tiempo, Time slice): Período de tiempo asignado a un proceso en algoritmos de planificación por turnos (*round-robin*). Al expirar, ocurre un *context switch*.

**Queue** (Cola): Estructura de datos FIFO utilizada por el planificador para organizar procesos. Existen ready queue, wait queue, etc.

## R

**Race Condition** (Condición de carrera): Situación donde el resultado de una operación depende del timing o secuencia de eventos incontrolables. Ocurre cuando múltiples hilos/procesos acceden concurrentemente a recursos compartidos.

**Real-time System** (Sistema de tiempo real): Sistema donde la corrección no solo depende del resultado lógico sino también del tiempo en que se produce. *Hard real-time*: deadlines estrictos. *Soft real-time*: deadlines flexibles.

**Reentrant Code** (Código reentrante): Código que puede ser ejecutado concurrentemente por múltiples hilos sin causar resultados incorrectos. No usa variables globales ni estáticas.

**Response Time** (Tiempo de respuesta): Tiempo desde que se hace una solicitud hasta que se recibe la primera respuesta (no la respuesta completa).

## S

**Scheduler** (Planificador): Componente del sistema operativo que decide qué proceso ejecutar siguiente y durante cuánto tiempo.

**Semaphore** (Semáforo): Mecanismo de sincronización que controla el acceso a recursos compartidos mediante un contador. *Binary semaphore* (similar a mutex), *Counting semaphore* (permite N accesos simultáneos).

**Signal** (Señal): Mecanismo de notificación asíncrona en Unix/Linux. Permite comunicar eventos a procesos (ej: SIGKILL, SIGTERM, SIGUSR1).

**Socket**: Endpoint de comunicación de red. Abstracción que permite comunicación entre procesos en diferentes máquinas.

**Spinlock**: Tipo de *lock* que usa *busy waiting*. El hilo que intenta adquirir el lock "gira" en un loop verificando constantemente. Eficiente para períodos cortos de espera.

**Starvation** (Inanición): Situación donde un proceso nunca obtiene los recursos que necesita porque otros procesos son constantemente favorecidos.

**Swapping**: Técnica de gestión de memoria donde procesos completos se mueven entre memoria principal y *backing store*.

**Syscall (System Call)** (Llamada al sistema): Interfaz programática que permite a programas en *user mode* solicitar servicios del kernel. Ejemplos: `open()`, `read()`, `fork()`, `exec()`.

## T

**Thrashing**: Situación donde el sistema pasa más tiempo manejando *page faults* (paginando) que ejecutando procesos útiles. Indica memoria insuficiente.

**Thread** (Hilo): Unidad básica de ejecución dentro de un proceso. Múltiples hilos en un proceso comparten el mismo espacio de direcciones pero tienen sus propias pilas y registros.

**Throughput** (Rendimiento, Capacidad de procesamiento): Cantidad de trabajo completado por unidad de tiempo. Por ejemplo, procesos completados por segundo.

**TLB (Translation Lookaside Buffer)**: Caché de hardware que almacena traducciones recientes de direcciones virtuales a físicas para acelerar el acceso a memoria.

**Turnaround Time** (Tiempo de retorno): Tiempo total desde que un proceso es enviado hasta que completa su ejecución. Incluye tiempo de espera, tiempo de CPU y tiempo de I/O.

## U

**User Mode** (Modo usuario): Modo de operación de la CPU con privilegios restringidos. Los programas de usuario ejecutan en este modo y deben usar *syscalls* para acceder al hardware.

**User Space**: Área de memoria donde ejecutan los programas de usuario, separada y protegida del *kernel space*.

## V

**Virtual Memory** (Memoria virtual): Técnica que permite ejecutar programas que son más grandes que la memoria física disponible. Crea la abstracción de un espacio de direcciones grande y contiguo para cada proceso.

**Virtual Address**: Dirección de memoria generada por la CPU, que debe ser traducida a una dirección física por la MMU antes de acceder a memoria.

## W

**Wait Queue**: Cola donde procesos/hilos esperan por un evento específico (disponibilidad de recurso, completitud de I/O, etc.).

**Working Set**: Conjunto de páginas que un proceso está usando activamente en un período de tiempo dado. Importante para políticas de reemplazo de páginas.

## Z

**Zombie Process** (Proceso zombi): Proceso que ha terminado su ejecución pero su entrada en la tabla de procesos no ha sido removida porque su proceso padre no ha leído su estado de salida con `wait()`.

---

## Referencias

Los términos en este glosario son utilizados conforme a las definiciones estándar en la literatura de sistemas operativos, particularmente:
- Silberschatz, Galvin, Gagne. *Operating System Concepts*
- Tanenbaum, Bos. *Modern Operating Systems*
- Stevens, Rago. *Advanced Programming in the UNIX Environment*