# Capítulo 4: Hilos (Threads)

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Explicar qué son los hilos y por qué son necesarios en sistemas modernos
- Distinguir entre User-Level Threads (ULT) y Kernel-Level Threads (KLT)
- Analizar los modelos de mapeo entre hilos de usuario y kernel
- Implementar programas multihilo usando pthreads en C
- Resolver ejercicios de planificación combinando procesos e hilos
- Identificar problemas de concurrencia y sus soluciones básicas
- Evaluar cuándo usar hilos vs procesos según el contexto

## Introducción y Motivación

### El problema de los procesos pesados

Los procesos tradicionales resuelven la multiprogramación, pero presentan limitaciones importantes en aplicaciones modernas:

\textcolor{red!60!gray}{\textbf{Limitaciones de los procesos:}\\
- Creación costosa: fork() copia todo el espacio de direcciones\\
- Context switch lento: cambio de mapa de memoria, flush de caches y TLB\\
- Comunicación compleja: requiere IPC, pipes o memoria compartida\\
- Recursos aislados: dificultad para compartir datos eficientemente\\
}

Consideremos un navegador web moderno. Durante la carga de una página se ejecutan simultáneamente múltiples tareas: descarga de HTML, procesamiento y renderizado, descarga de imágenes, ejecución de JavaScript y manejo de eventos del usuario. Si estas tareas fueran procesos separados, el overhead de comunicación y context switching sería prohibitivo.

### La solución: hilos como procesos livianos

\begin{definitionbox}
\emph{Hilo (Thread):} Unidad básica de utilización del CPU dentro de un proceso, caracterizada por tener su propio flujo de ejecución independiente pero compartiendo el espacio de direcciones con otros hilos del mismo proceso.
\end{definitionbox}

Los hilos comparten recursos del proceso padre pero mantienen elementos privados:

**Recursos compartidos entre hilos:**
- Espacio de direcciones (código, datos, heap)
- Archivos abiertos y descriptores
- Señales y handlers
- PID y PPID
- Working directory

**Recursos privados de cada hilo:**
- Thread ID (TID)
- Registros del procesador (PC, SP, registros generales)
- Stack privado para variables locales
- Estado de planificación individual

## Estructura y Definiciones Fundamentales

### Anatomía de un hilo

Cada hilo mantiene la siguiente información de control:

```c
typedef struct thread_control_block {
    int tid;                    // Thread ID único dentro del proceso
    int state;                  // READY, RUNNING, BLOCKED, TERMINATED
    void* stack_pointer;        // Puntero al tope del stack privado
    void* program_counter;      // Próxima instrucción a ejecutar
    register_set_t registers;   // Estado completo de registros
    void* stack_base;          // Base del stack (para cleanup)
    size_t stack_size;         // Tamaño del stack
    int priority;              // Prioridad de planificación
    struct thread_control_block* next;  // Lista enlazada de hilos
} tcb_t;
```

### Modelo de memoria con hilos

El espacio de direcciones de un proceso multihilo se organiza de la siguiente manera:

```
Proceso con múltiples hilos:
┌─────────────────────────────────────┐
│          TEXT (código)              │ ← Compartido entre hilos
├─────────────────────────────────────┤
│          DATA (globales)            │ ← Compartido entre hilos
├─────────────────────────────────────┤
│          HEAP (malloc/free)         │ ← Compartido entre hilos
├─────────────────────────────────────┤
│          Stack Hilo 1               │ ← Privado del hilo 1
├─────────────────────────────────────┤
│          Stack Hilo 2               │ ← Privado del hilo 2
├─────────────────────────────────────┤
│          Stack Hilo N               │ ← Privado del hilo N
└─────────────────────────────────────┘
```

\textcolor{orange!70!black}{\textbf{Advertencia:}\\
Las variables globales y el heap son compartidos entre hilos, lo que requiere sincronización para evitar race conditions. Las variables locales (en el stack) son automáticamente privadas de cada hilo.\\
}

## User-Level Threads vs Kernel-Level Threads

### User-Level Threads (ULT)

\begin{definitionbox}
\emph{User-Level Threads (ULT):} Hilos implementados completamente en espacio de usuario mediante bibliotecas especializadas, donde el kernel del sistema operativo no tiene conocimiento de los hilos individuales.
\end{definitionbox}

En el modelo ULT, el kernel ve únicamente un proceso con un solo hilo de ejecución. La biblioteca de hilos en espacio de usuario maneja toda la gestión:

**Características técnicas:**
- Gestión completa por biblioteca (GNU Portable Threads, Fiber libraries)
- Context switch sin syscalls (solo cambio de registros)
- Planificación cooperativa o por timer de usuario
- Mapeo N:1 (muchos ULT a un solo KLT)

**Implementación del context switch ULT:**

```c
// Pseudocódigo simplificado de context switch ULT
void ult_context_switch(ult_t *from, ult_t *to) {
    // 1. Guardar estado de registros en TCB
    if (setjmp(from->context) == 0) {
        // 2. Cambiar hilo actual en scheduler
        current_ult = to;
        
        // 3. Restaurar estado del nuevo hilo
        longjmp(to->context, 1);
    }
    // Ejecución continúa aquí cuando este hilo vuelva a ejecutar
}
```

\textcolor{teal!60!black}{\textbf{Ventajas ULT:}\\
- Context switch extremadamente rápido (20-50 instrucciones)\\
- Sin overhead de syscalls\\
- Planificación especializada por aplicación\\
- Soporte en SO que no implementan KLT nativamente\\
}

\textcolor{red!60!gray}{\textbf{Desventajas ULT:}\\
- No hay paralelismo real en sistemas multicore\\
- Si un hilo hace I/O, bloquea todo el proceso\\
- No aprovecha planificación preventiva del SO\\
- Scheduling starvation si hilos no cooperan\\
}

### Kernel-Level Threads (KLT)

\begin{definitionbox}
\emph{Kernel-Level Threads (KLT):} Hilos implementados y gestionados directamente por el kernel del sistema operativo, donde cada hilo es una entidad de planificación independiente conocida por el SO.
\end{definitionbox}

En el modelo KLT, cada hilo tiene entrada propia en las tablas del kernel y es planificado independientemente:

**Características técnicas:**
- Cada hilo tiene PCB (Process Control Block) o TCB en kernel
- Context switch requiere syscall y cambio de modo
- Planificación preventiva por el SO
- Mapeo 1:1 (un ULT por cada KLT)

**Estructura del context switch KLT:**

```c
// Context switch KLT (ejecutado por kernel)
void klt_context_switch(tcb_t *from, tcb_t *to) {
    // 1. Guardar estado completo en kernel
    save_processor_state(&from->cpu_state);
    save_fpu_state(&from->fpu_state);
    
    // 2. Actualizar planificador
    update_scheduler_queues(from, to);
    
    // 3. Cambiar contexto de memoria si es necesario
    if (from->process_id != to->process_id) {
        switch_address_space(to->process_id);
        flush_tlb();
    }
    
    // 4. Restaurar estado del nuevo hilo
    restore_processor_state(&to->cpu_state);
    restore_fpu_state(&to->fpu_state);
    
    // 5. Continuar ejecución
    jump_to_thread(to);
}
```

\textcolor{teal!60!black}{\textbf{Ventajas KLT:}\\
- Paralelismo real en sistemas SMP/multicore\\
- Si un hilo se bloquea, otros continúan ejecutando\\
- Planificación justa y preventiva por el SO\\
- Mejor integración con servicios del kernel\\
}

\textcolor{red!60!gray}{\textbf{Desventajas KLT:}\\
- Context switch más lento (500-2000 instrucciones)\\
- Overhead de syscalls para gestión de hilos\\
- Limitado por recursos del kernel (max threads)\\
- Mayor consumo de memoria kernel\\
}

### Modelos de mapeo

#### Modelo Many-to-One (N:1)
Múltiples hilos de usuario mapean a un solo hilo kernel:

```
Aplicación:  [ULT1] [ULT2] [ULT3] [ULT4]
                  \    |    |    /
                   \   |    |   /
Kernel:             [    KLT1     ]
                         |
CPU:                  [Core1]
```

Este modelo maximiza la eficiencia del context switch pero sacrifica paralelismo.

#### Modelo One-to-One (1:1)
Cada hilo de usuario mapea a un hilo kernel dedicado:

```
Aplicación:  [ULT1] [ULT2] [ULT3] [ULT4]
                |      |      |      |
Kernel:      [KLT1] [KLT2] [KLT3] [KLT4]
                |      |      |      |
CPU:         [Core1][Core2][Core3][Core4]
```

Este modelo maximiza paralelismo pero incrementa overhead.

#### Modelo Many-to-Many (M:N)
M hilos de usuario mapean a N hilos kernel (donde M > N):

```
Aplicación:  [ULT1] [ULT2] [ULT3] [ULT4] [ULT5]
                \      |      |      /      /
                 \     |      |     /      /
Kernel:           [KLT1]   [KLT2]   [KLT3]
                     |        |        |
CPU:              [Core1]  [Core2]  [Core3]
```

\textcolor{blue!50!black}{\textbf{Información técnica:}\\
El modelo M:N requiere scheduler de dos niveles: uno en espacio de usuario (ULT) y otro en kernel (KLT). La biblioteca de hilos debe coordinar con el kernel para optimizar el mapeo dinámico.\\
}

## Implementación en C con pthreads

### Creación básica de hilos

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

// Estructura para pasar múltiples argumentos al hilo
typedef struct {
    int thread_id;
    int iterations;
    char* message;
} thread_args_t;

// Función que ejecutará cada hilo
void* thread_function(void* arg) {
    thread_args_t* args = (thread_args_t*)arg;
    
    printf("Hilo %d iniciado - TID: %lu, PID: %d\n", 
           args->thread_id, pthread_self(), getpid());
    
    // Trabajo del hilo
    for (int i = 0; i < args->iterations; i++) {
        printf("Hilo %d: %s - iteración %d\n", 
               args->thread_id, args->message, i + 1);
        sleep(1);
    }
    
    // Preparar valor de retorno
    int* result = malloc(sizeof(int));
    *result = args->iterations * args->thread_id;
    
    printf("Hilo %d terminando con resultado %d\n", args->thread_id, *result);
    return result;
}

int main() {
    const int NUM_THREADS = 3;
    pthread_t threads[NUM_THREADS];
    thread_args_t thread_args[NUM_THREADS];
    
    printf("Proceso principal - PID: %d\n", getpid());
    
    // Configurar argumentos y crear hilos
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_args[i].thread_id = i + 1;
        thread_args[i].iterations = 3 + i;  // 3, 4, 5 iteraciones
        thread_args[i].message = "Trabajando";
        
        int result = pthread_create(&threads[i], NULL, 
                                   thread_function, &thread_args[i]);
        
        if (result != 0) {
            fprintf(stderr, "Error creando hilo %d\n", i + 1);
            exit(1);
        }
    }
    
    // Esperar terminación y recolectar resultados
    printf("\nEsperando que terminen todos los hilos...\n");
    
    for (int i = 0; i < NUM_THREADS; i++) {
        void* thread_result;
        pthread_join(threads[i], &thread_result);
        
        int* result_value = (int*)thread_result;
        printf("Hilo %d retornó: %d\n", i + 1, *result_value);
        
        free(result_value);  // Importante: liberar memoria
    }
    
    printf("Proceso principal terminando\n");
    return 0;
}
```

**Compilación:**
```bash
gcc -o hilos_basico hilos_basico.c -lpthread
```

### Diferencias clave respecto a procesos

| Aspecto | Procesos | Hilos |
|---------|----------|-------|
| **Creación** | fork() copia memoria completa | pthread_create() solo crea stack |
| **Memoria** | Espacios separados | Espacio compartido |
| **Comunicación** | IPC, pipes, señales | Variables globales, heap |
| **Context Switch** | Cambio completo de MM | Solo registros y stack |
| **Overhead** | Alto (1-10ms) | Bajo (10-100μs) |
| **Aislamiento** | Total | Ninguno |

\textcolor{teal!60!black}{\textbf{Ventajas de hilos sobre procesos:}\\
- Creación y destrucción 10-100x más rápida\\
- Context switch 10-50x más rápido\\
- Comunicación directa a través de memoria compartida\\
- Menor consumo de memoria del sistema\\
}

\textcolor{red!60!gray}{\textbf{Desventajas de hilos vs procesos:}\\
- Error en un hilo puede afectar todo el proceso\\
- Sin aislamiento de memoria (problemas de seguridad)\\
- Debugging más complejo\\
- Requiere sincronización explícita\\
}

## Gestión avanzada de hilos

### Workers y pool de hilos

Un patrón común en aplicaciones de alto rendimiento es el pool de hilos trabajadores:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

#define POOL_SIZE 4
#define QUEUE_SIZE 100

// Estructura para tareas en cola
typedef struct task {
    void (*function)(void*);
    void* argument;
    struct task* next;
} task_t;

// Pool de hilos
typedef struct {
    pthread_t workers[POOL_SIZE];
    task_t* task_queue;
    task_t* queue_tail;
    pthread_mutex_t queue_mutex;
    pthread_cond_t queue_condition;
    int shutdown;
} thread_pool_t;

thread_pool_t pool;

// Función del hilo trabajador
void* worker_thread(void* arg) {
    printf("Worker iniciado - TID: %lu\n", pthread_self());
    
    while (1) {
        pthread_mutex_lock(&pool.queue_mutex);
        
        // Esperar hasta que haya tareas o shutdown
        while (pool.task_queue == NULL && !pool.shutdown) {
            pthread_cond_wait(&pool.queue_condition, &pool.queue_mutex);
        }
        
        // Verificar shutdown
        if (pool.shutdown) {
            pthread_mutex_unlock(&pool.queue_mutex);
            break;
        }
        
        // Tomar tarea de la cola
        task_t* task = pool.task_queue;
        pool.task_queue = task->next;
        if (pool.task_queue == NULL) {
            pool.queue_tail = NULL;
        }
        
        pthread_mutex_unlock(&pool.queue_mutex);
        
        // Ejecutar tarea
        printf("Worker %lu ejecutando tarea\n", pthread_self() % 10000);
        task->function(task->argument);
        free(task);
    }
    
    printf("Worker %lu terminando\n", pthread_self() % 10000);
    return NULL;
}

// Agregar tarea al pool
void pool_add_task(void (*function)(void*), void* argument) {
    task_t* new_task = malloc(sizeof(task_t));
    new_task->function = function;
    new_task->argument = argument;
    new_task->next = NULL;
    
    pthread_mutex_lock(&pool.queue_mutex);
    
    if (pool.queue_tail == NULL) {
        pool.task_queue = pool.queue_tail = new_task;
    } else {
        pool.queue_tail->next = new_task;
        pool.queue_tail = new_task;
    }
    
    pthread_cond_signal(&pool.queue_condition);
    pthread_mutex_unlock(&pool.queue_mutex);
}

// Inicializar pool
void pool_init() {
    pool.task_queue = NULL;
    pool.queue_tail = NULL;
    pool.shutdown = 0;
    
    pthread_mutex_init(&pool.queue_mutex, NULL);
    pthread_cond_init(&pool.queue_condition, NULL);
    
    // Crear workers
    for (int i = 0; i < POOL_SIZE; i++) {
        pthread_create(&pool.workers[i], NULL, worker_thread, NULL);
    }
    
    printf("Pool de %d workers inicializado\n", POOL_SIZE);
}

// Tarea de ejemplo
void example_task(void* arg) {
    int task_id = *(int*)arg;
    printf("  Ejecutando tarea %d...\n", task_id);
    sleep(2);  // Simular trabajo
    printf("  Tarea %d completada\n", task_id);
}

int main() {
    pool_init();
    
    // Agregar tareas al pool
    int task_ids[10];
    for (int i = 0; i < 10; i++) {
        task_ids[i] = i + 1;
        pool_add_task(example_task, &task_ids[i]);
        printf("Tarea %d agregada al pool\n", i + 1);
    }
    
    // Esperar que se procesen todas las tareas
    sleep(8);
    
    // Shutdown del pool
    pthread_mutex_lock(&pool.queue_mutex);
    pool.shutdown = 1;
    pthread_cond_broadcast(&pool.queue_condition);
    pthread_mutex_unlock(&pool.queue_mutex);
    
    // Esperar workers
    for (int i = 0; i < POOL_SIZE; i++) {
        pthread_join(pool.workers[i], NULL);
    }
    
    printf("Pool terminado\n");
    return 0;
}
```

\textcolor{blue!50!black}{\textbf{Información técnica:}\\
Los pools de hilos eliminan el overhead de creación/destrucción y controlan la concurrencia. Son fundamentales en servidores web (Apache Worker MPM) y bases de datos (connection pooling).\\
}

## Planificación de hilos

### Planificación de ULT

La biblioteca de hilos implementa su propio scheduler, típicamente cooperativo:

```c
// Scheduler Round Robin para ULT
void ult_scheduler() {
    static int current = 0;
    static int quantum_remaining = QUANTUM;
    
    quantum_remaining--;
    
    if (quantum_remaining <= 0 || threads[current].state != ULT_RUNNING) {
        // Buscar próximo hilo READY
        int next = current;
        do {
            next = (next + 1) % MAX_THREADS;
        } while (threads[next].state != ULT_READY && next != current);
        
        if (threads[next].state == ULT_READY) {
            // Context switch
            threads[current].state = ULT_READY;
            threads[next].state = ULT_RUNNING;
            ult_context_switch(&threads[current], &threads[next]);
            current = next;
            quantum_remaining = QUANTUM;
        }
    }
}
```

### Planificación de KLT

El kernel planifica hilos como entidades independientes, sin considerar que pertenecen al mismo proceso:

\textcolor{orange!70!black}{\textbf{Advertencia:}\\
En planificación fair entre hilos individuales, un proceso con muchos hilos puede monopolizar el CPU. Por ejemplo: Proceso A (10 hilos) vs Proceso B (1 hilo) resulta en 91\% vs 9\% de tiempo de CPU.\\
}

**Solución: Planificación consciente de procesos**
Algunos SO implementan planificación jerárquica:
1. Distribuir tiempo entre procesos
2. Cada proceso distribuye su tiempo entre sus hilos

## Ejercicio práctico completo

### Enunciado del problema

Un sistema con planificador Round Robin (Q=4ms) debe ejecutar:

- **Proceso P1**: 1 hilo KLT
  - P1-T1: Llegada=0ms, CPU=14ms, I/O en t=6ms por 3ms
- **Proceso P2**: 2 hilos KLT  
  - P2-T1: Llegada=1ms, CPU=10ms
  - P2-T2: Llegada=3ms, CPU=8ms, I/O en t=5ms por 2ms
- **Proceso P3**: 1 KLT + 2 ULT (planificador interno FIFO)
  - P3-T1 (KLT): Llegada=2ms, CPU=12ms
  - P3-T2 (ULT): Llegada=4ms, CPU=6ms  
  - P3-T3 (ULT): Llegada=5ms, CPU=4ms

**Nota**: Los ULT de P3 son planificados internamente por FIFO cuando P3-T1 tiene el CPU.

### Resolución paso a paso

**Estado inicial del sistema:**
```
t=0: P1-T1 llega (READY)
t=1: P2-T1 llega (READY)  
t=2: P3-T1 llega (READY)
t=3: P2-T2 llega (READY)
t=4: P3-T2 llega (cola interna ULT de P3)
t=5: P3-T3 llega (cola interna ULT de P3)
```

**Timeline de ejecución:**

```
t=0-4ms: P1-T1 ejecuta (quantum completo)
         Remaining: P1-T1=10ms
         Ready queue: [P2-T1, P3-T1, P2-T2]

t=4-6ms: P2-T1 ejecuta (2ms de 4ms quantum)
         I/O de P1-T1 termina en t=6ms → P1-T1 vuelve a READY
         Ready queue: [P3-T1, P2-T2, P1-T1]

t=6-8ms: P2-T1 continúa (completa quantum)
         Remaining: P2-T1=8ms
         Ready queue: [P3-T1, P2-T2, P1-T1, P2-T1]

t=8-10ms: P3-T1 ejecuta (2ms de 4ms quantum)
          ULT scheduler interno: P3-T2 comienza (FIFO)
          Ready queue: [P2-T2, P1-T1, P2-T1]

t=10-12ms: P3-T1 continúa ejecutando P3-T2 (ULT)
           Remaining: P3-T2=4ms
           Ready queue: [P2-T2, P1-T1, P2-T1, P3-T1]

t=12-14ms: P2-T2 ejecuta (2ms de 4ms quantum)
           
t=14-15ms: P2-T2 hace I/O (1ms ejecutado)
           P2-T2 se bloquea
           Ready queue: [P1-T1, P2-T1, P3-T1]

t=14-16ms: P1-T1 ejecuta (2ms de quantum)

t=16-18ms: P1-T1 continúa (completa quantum)
           Remaining: P1-T1=6ms
           Ready queue: [P2-T1, P3-T1, P1-T1]

t=17ms: I/O de P2-T2 termina → P2-T2 vuelve a READY

t=18-22ms: P2-T1 ejecuta (quantum completo)
           Remaining: P2-T1=4ms
           Ready queue: [P3-T1, P1-T1, P2-T2, P2-T1]

t=22-26ms: P3-T1 ejecuta P3-T2 (ULT, remaining 4ms)
           P3-T2 termina, ULT scheduler activa P3-T3
           Ready queue: [P1-T1, P2-T2, P2-T1, P3-T1]

t=26-30ms: P1-T1 ejecuta (quantum completo)
           Remaining: P1-T1=2ms
           Ready queue: [P2-T2, P2-T1, P3-T1, P1-T1]

t=30-34ms: P2-T2 ejecuta (quantum completo)
           Remaining: P2-T2=3ms
           Ready queue: [P2-T1, P3-T1, P1-T1, P2-T2]

t=34-38ms: P2-T1 ejecuta (remaining 4ms, termina)
           Ready queue: [P3-T1, P1-T1, P2-T2]

t=38-42ms: P3-T1 ejecuta P3-T3 (ULT, 4ms termina)
           Remaining: P3-T1=4ms
           Ready queue: [P1-T1, P2-T2, P3-T1]

t=42-44ms: P1-T1 ejecuta (remaining 2ms, termina)
           Ready queue: [P2-T2, P3-T1]

t=44-47ms: P2-T2 ejecuta (remaining 3ms, termina)
           Ready queue: [P3-T1]

t=47-51ms: P3-T1 ejecuta (remaining 4ms, termina)
           Ready queue: []
```

### Diagrama de Gantt

\begin{center}
\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap04-gantt-hilos-mixto-1.png}
\end{center}
\begin{center}
\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap04-gantt-hilos-mixto-2.png}
\end{center}
\begin{center}
\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap04-gantt-hilos-mixto-3.png}
\end{center}


### Cálculos de métricas

**Tiempos de terminación:**
- P1-T1: 44ms
- P2-T1: 38ms  
- P2-T2: 47ms
- P3-T1: 51ms
- P3-T2: 26ms (ULT, termina cuando P3-T1 lo ejecuta)
- P3-T3: 42ms (ULT, termina cuando P3-T1 lo ejecuta)

**Tiempo promedio de retorno:**
```
Tiempo de retorno = Tiempo de terminación - Tiempo de llegada

P1-T1: 44 - 0 = 44ms
P2-T1: 38 - 1 = 37ms
P2-T2: 47 - 3 = 44ms
P3-T1: 51 - 2 = 49ms
P3-T2: 26 - 4 = 22ms
P3-T3: 42 - 5 = 37ms

Promedio: (44 + 37 + 44 + 49 + 22 + 37) / 6 = 38.8ms
```

\textcolor{blue!50!black}{\textbf{Información técnica:}\\
Los ULT de P3 solo pueden ejecutar cuando P3-T1 tiene asignado el CPU. Su planificación interna FIFO significa que P3-T2 debe terminar completamente antes de que P3-T3 pueda comenzar.\\
}

## Análisis comparativo y casos de uso

### Overhead de implementaciones

**Métricas de rendimiento típicas:**

| Operación | ULT | KLT | Proceso |
|-----------|-----|-----|---------|
| **Creación** | 1-10 μs | 50-200 μs | 1-10 ms |
| **Context Switch** | 0.1-1 μs | 5-50 μs | 100-1000 μs |
| **Memoria por entidad** | 2-8 KB | 8-16 KB | 4-8 MB |
| **Sincronización** | Variables | Mutex/Sem | IPC |

### Casos de uso recomendados

#### Usar ULT cuando:
- **Aplicaciones cooperativas** con many short tasks
- **I/O intensivo** con muchas operaciones asíncronas  
- **Context switching frecuente** entre tareas relacionadas
- **Control fino** sobre scheduling policy
- **Sistemas embebidos** con recursos limitados

**Ejemplo: Servidor de juegos en tiempo real**
```c
// ULT para manejar múltiples conexiones de jugadores
void* game_connection_handler(void* player_data) {
    while (player_connected) {
        process_player_input();     // CPU burst corto
        update_game_state();        // CPU burst corto  
        ult_yield();               // Cooperativo
        send_updates_to_player();   // I/O burst
        ult_yield();               // Dar oportunidad a otros
    }
}
```

#### Usar KLT cuando:
- **Aplicaciones paralelas** en sistemas multicore
- **CPU-intensive tasks** que se benefician de paralelismo real
- **Aplicaciones críticas** donde el bloqueo de un hilo no debe afectar otros
- **Integración** con servicios del SO (signals, timers)

**Ejemplo: Procesamiento de imágenes paralelo**
```c
// KLT para aprovechar múltiples cores
void* image_processor_thread(void* args) {
    image_region_t* region = (image_region_t*)args;
    
    // Cada hilo procesa una región diferente de la imagen
    for (int y = region->start_y; y < region->end_y; y++) {
        for (int x = region->start_x; x < region->end_x; x++) {
            apply_filter(image, x, y);  // CPU intensivo
        }
    }
    return NULL;
}
```

#### Usar pool de hilos cuando:
- **Servidores web/aplicaciones** con carga variable
- **Procesamiento batch** de tareas independientes
- **Control de recursos** para evitar oversubscription
- **Latencia predecible** vs throughput máximo

## Problemas comunes y debugging

### Race conditions y datos compartidos

**Problema típico:**
```c
// Variable global compartida entre hilos
int account_balance = 1000;

void* withdraw_money(void* amount_ptr) {
    int amount = *(int*)amount_ptr;
    
    // PROBLEMA: Esta secuencia NO es atómica
    int current_balance = account_balance;    // LOAD
    if (current_balance >= amount) {          // CHECK
        sleep(1);  // Simular procesamiento
        account_balance = current_balance - amount;  // STORE
        printf("Retiro exitoso: $%d\n", amount);
    } else {
        printf("Fondos insuficientes\n");
    }
    
    return NULL;
}
```

**Escenario de race condition:**
```
Estado inicial: account_balance = 1000

Hilo 1 (retira $800):        Hilo 2 (retira $600):
current = 1000               current = 1000
if (1000 >= 800) ✓          if (1000 >= 600) ✓
  sleep(1)                    sleep(1)
  balance = 1000 - 800 = 200  balance = 1000 - 600 = 400

Resultado final: balance = 400 (¡el último en escribir gana!)
Correcto sería: balance = -400 (fondos insuficientes)
```

**Solución con sincronización:**
```c
pthread_mutex_t balance_mutex = PTHREAD_MUTEX_INITIALIZER;

void* withdraw_money_safe(void* amount_ptr) {
    int amount = *(int*)amount_ptr;
    
    pthread_mutex_lock(&balance_mutex);  // Sección crítica
    
    int current_balance = account_balance;
    if (current_balance >= amount) {
        account_balance = current_balance - amount;
        printf("Retiro exitoso: $%d, balance: $%d\n", amount, account_balance);
    } else {
        printf("Fondos insuficientes para $%d\n", amount);
    }
    
    pthread_mutex_unlock(&balance_mutex);
    
    return NULL;
}
```

### Herramientas de debugging

**Detectar race conditions con ThreadSanitizer:**
```bash
# Compilar con ThreadSanitizer
gcc -g -fsanitize=thread -o programa programa.c -lpthread

# Ejecutar
./programa

# Salida típica:
# WARNING: ThreadSanitizer: data race
# Write of size 4 at 0x7fff8b2c4020 by thread T2:
#   #0 withdraw_money programa.c:15
# Previous write of size 4 at 0x7fff8b2c4020 by thread T1:
#   #0 withdraw_money programa.c:15
```

**Debugging con GDB multihilo:**
```bash
gdb ./programa

(gdb) run
(gdb) info threads         # Listar todos los hilos
(gdb) thread 2             # Cambiar al hilo 2
(gdb) bt                   # Backtrace del hilo actual
(gdb) thread apply all bt  # Backtrace de todos los hilos
```

### Patterns de sincronización básicos

#### Producer-Consumer con hilos
```c
#include <pthread.h>
#include <semaphore.h>

#define BUFFER_SIZE 10

int buffer[BUFFER_SIZE];
int in = 0, out = 0;

sem_t empty, full;
pthread_mutex_t buffer_mutex;

void* producer(void* arg) {
    int item = 1;
    
    while (1) {
        sem_wait(&empty);                    // Esperar espacio libre
        pthread_mutex_lock(&buffer_mutex);   // Acceso exclusivo al buffer
        
        buffer[in] = item++;
        printf("Producido: %d en posición %d\n", buffer[in], in);
        in = (in + 1) % BUFFER_SIZE;
        
        pthread_mutex_unlock(&buffer_mutex);
        sem_post(&full);                     // Señalar item disponible
        
        sleep(rand() % 3);  // Simular tiempo de producción variable
    }
}

void* consumer(void* arg) {
    int consumer_id = *(int*)arg;
    
    while (1) {
        sem_wait(&full);                     // Esperar item disponible
        pthread_mutex_lock(&buffer_mutex);   // Acceso exclusivo al buffer
        
        int item = buffer[out];
        printf("Consumidor %d tomó: %d de posición %d\n", 
               consumer_id, item, out);
        out = (out + 1) % BUFFER_SIZE;
        
        pthread_mutex_unlock(&buffer_mutex);
        sem_post(&empty);                    // Señalar espacio libre
        
        sleep(rand() % 2);  // Simular tiempo de consumo
    }
}
```

## Tendencias y tecnologías modernas

### Green threads y corrutinas

**Go language (goroutines):**
- Modelo M:N optimizado con work-stealing scheduler
- Stack segmentado que crece dinámicamente (inicia con 2KB)
- Multiplexing de miles de goroutines sobre pocos threads OS

**Rust (async/await):**
- Concurrencia sin threads mediante futures y async runtime
- Zero-cost abstractions para I/O asíncrono
- Ownership model previene race conditions en tiempo de compilación

### Thread affinity y NUMA

En sistemas modernos con múltiples cores y arquitectura NUMA:

```c
#include <sched.h>

// Configurar affinity de CPU para un hilo
void set_thread_affinity(pthread_t thread, int cpu_core) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_core, &cpuset);
    
    int result = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpuset);
    if (result != 0) {
        perror("pthread_setaffinity_np");
    }
}

// Ejemplo de uso para optimizar cache locality
void create_affine_threads() {
    pthread_t threads[4];
    
    for (int i = 0; i < 4; i++) {
        pthread_create(&threads[i], NULL, worker_function, &i);
        set_thread_affinity(threads[i], i);  // Cada hilo en core específico
    }
}
```

\textcolor{blue!50!black}{\textbf{Información técnica:}\\
Thread affinity mejora rendimiento manteniendo datos en cache L1/L2 del core específico. En sistemas NUMA, también reduce latencia de acceso a memoria local del nodo.\\
}

## Síntesis y conexiones

### Puntos clave para evaluación

**Conceptos fundamentales para dominar:**

1. **Diferencias estructurales ULT vs KLT**
   - ULT: N hilos usuario → 1 hilo kernel (biblioteca gestiona)
   - KLT: 1 hilo usuario → 1 hilo kernel (SO gestiona)

2. **Implicaciones de performance**
   - ULT: Context switch ~100x más rápido, sin paralelismo real
   - KLT: Context switch más lento, paralelismo completo

3. **Problemática de planificación mixta**
   - ULT dependen del quantum asignado a su KLT contenedor
   - Scheduler interno vs scheduler del SO

4. **APIs críticas de pthreads**
   - Ciclo completo: create → join/detach
   - Sincronización básica: mutex lock/unlock
   - Gestión de memoria en valores de retorno

### Errores conceptuales frecuentes

\textcolor{red!60!gray}{\textbf{Misconcepciones comunes:}\\
- "ULT son más simples": Requieren biblioteca de scheduling compleja\\
- "KLT siempre son mejores": Overhead prohibitivo para muchas aplicaciones\\
- "Más hilos = mejor rendimiento": Contention y overhead pueden degradar performance\\
- "Variables locales son thread-safe": Solo en el stack, no en el heap\\
}

### Preparación para próximos capítulos

Los hilos introducen la necesidad crítica de **sincronización y coordinación**. En el siguiente capítulo exploraremos:

**Mecanismos de sincronización:**
- Mutex y semáforos para exclusión mutua
- Condition variables para coordinación
- Read-write locks para optimizar lectores múltiples

**Problemas clásicos:**
- Productor-consumidor con buffer limitado
- Lectores-escritores con prioridades
- Filósofos comensales y prevención de deadlock

**Ejemplo de transición:**
```c
// Problema que veremos en el próximo capítulo
pthread_mutex_t resource_mutex;
pthread_cond_t resource_available;
int shared_resource_count = 0;

// ¿Cómo coordinamos múltiples hilos que compiten por recursos limitados?
// ¿Cómo evitamos deadlock cuando un hilo necesita múltiples recursos?
// ¿Cómo implementamos fairness entre hilos productores y consumidores?
```

### Laboratorio propuesto

**Práctica 1: Benchmark ULT vs KLT**
Implementar un programa que compare el overhead de context switches entre una simulación de ULT y pthreads reales, midiendo switches por segundo.

**Práctica 2: Pool de hilos configurable**
Desarrollar un pool de threads con tamaño variable que pueda manejar diferentes tipos de tareas y medir su rendimiento bajo diferentes cargas.

**Práctica 3: Análisis de planificación mixta**
Implementar un simulador que reproduzca el ejercicio del Gantt chart, permitiendo modificar parámetros (quantum, número de hilos, duración de I/O) y visualizar el impacto en las métricas de rendimiento.

La comprensión profunda de los hilos es fundamental para el diseño de sistemas concurrentes eficientes. En aplicaciones modernas, la elección correcta entre ULT, KLT o modelos híbridos puede determinar la diferencia entre un sistema que escala y uno que colapsa bajo carga.