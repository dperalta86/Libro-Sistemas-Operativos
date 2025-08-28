# Capítulo 4: Hilos (Threads)

## 1. Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Explicar qué son los hilos y por qué son necesarios en sistemas modernos
- Distinguir entre User-Level Threads (ULT) y Kernel-Level Threads (KLT)
- Analizar los modelos de mapeo: 1:1, N:1, M:N
- Implementar programas multihilo usando pthreads en C
- Resolver ejercicios de planificación combinando procesos e hilos
- Identificar problemas de concurrencia y sus soluciones básicas
- Evaluar cuándo usar hilos vs procesos según el contexto
- Analizar el overhead y beneficios de diferentes implementaciones de hilos

## 2. Introducción y Contexto

### ¿Por qué necesitamos hilos?

Imaginemos un navegador web moderno. Mientras cargas una página:
- **Hilo 1**: Descarga HTML del servidor
- **Hilo 2**: Procesa y renderiza el HTML ya descargado
- **Hilo 3**: Descarga imágenes en paralelo
- **Hilo 4**: Ejecuta JavaScript
- **Hilo 5**: Maneja eventos del usuario (clicks, scroll)

Si fuera un **solo proceso secuencial**, tendrías que esperar que termine cada tarea antes de comenzar la siguiente. ¡Tu navegador sería inutilizable!

### El problema de los procesos "pesados"

Los procesos resuelven la multiprogramación, pero tienen **limitaciones**:

1. **Creación costosa**: fork() copia todo el espacio de direcciones
2. **Context switch lento**: Cambiar mapa de memoria, caches, TLB
3. **Comunicación compleja**: IPC, pipes, memory compartida
4. **Recursos aislados**: No pueden compartir fácilmente datos

### La solución: Hilos como "procesos livianos"

Los **hilos** (threads) son **flujos de ejecución independientes** que comparten:
- **Mismo espacio de direcciones** (memory layout)
- **Mismo PID** (para el SO son parte del mismo proceso)
- **Archivos abiertos, señales, working directory**

Pero cada hilo tiene **su propio**:
- **Stack** (variables locales, parámetros, dirección de retorno)
- **Registros del CPU** (PC, SP, registros generales)
- **Estado de planificación** (prioridad, estado READY/RUNNING/BLOCKED)

### La analogía del equipo de trabajo

Piensen en una empresa:
- **Proceso** = Departamento completo (Recursos Humanos)
- **Hilos** = Empleados dentro del departamento
- **Recursos compartidos** = Oficina, archivos, presupuesto
- **Recursos individuales** = Escritorio, agenda personal, tareas asignadas

Los empleados pueden trabajar en paralelo, compartir información fácilmente, pero cada uno tiene sus propias responsabilidades y estado de trabajo.

## 3. Conceptos Fundamentales

### 3.1 Definición Formal de Hilo

**Hilo (Thread)**: Unidad básica de utilización del CPU dentro de un proceso, caracterizada por:
- **Thread ID (TID)**: Identificador único dentro del proceso
- **Program Counter (PC)**: Próxima instrucción a ejecutar
- **Stack pointer (SP)**: Tope de la pila del hilo
- **Registros**: Estado completo del procesador
- **Stack**: Espacio para variables locales y llamadas
- **Estado**: READY, RUNNING, BLOCKED (como los procesos)

### 3.2 Modelo de Memoria de Hilos

```
Proceso con múltiples hilos:
┌─────────────────────────────────────┐
│          TEXT (código)              │ ← Compartido
├─────────────────────────────────────┤
│          DATA (globales)            │ ← Compartido
├─────────────────────────────────────┤
│          HEAP (malloc)              │ ← Compartido
├─────────────────────────────────────┤
│          Stack Hilo 1               │ ← Individual
├─────────────────────────────────────┤
│          Stack Hilo 2               │ ← Individual  
├─────────────────────────────────────┤
│          Stack Hilo N               │ ← Individual
└─────────────────────────────────────┘
```

**Implicaciones críticas:**
- **Variables globales**: Compartidas entre hilos (requiere sincronización)
- **Variables locales**: Privadas de cada hilo (automáticamente aisladas)
- **Heap**: Compartido (malloc/free requiere cuidado)
- **Registros y PC**: Privados (permiten ejecución independiente)

### 3.3 User-Level Threads (ULT) vs Kernel-Level Threads (KLT)

#### User-Level Threads (ULT)
**Definición**: Hilos implementados completamente en espacio de usuario por bibliotecas (como GNU Portable Threads).

**Características:**
- El **kernel no conoce** los hilos individuales
- Para el SO, existe solo **un proceso** con **un hilo kernel**
- **Biblioteca de hilos** maneja creación, planificación y context switch
- **Planificación cooperativa** o por timer de usuario

**Estructura:**
```
Kernel Space:    [Proceso] ← Solo ve uno
                     |
User Space:     [Hilo1][Hilo2][Hilo3] ← Gestionados por biblioteca
```

#### Kernel-Level Threads (KLT)
**Definición**: Hilos implementados directamente por el kernel del SO.

**Características:**
- El **kernel conoce** cada hilo individualmente
- Cada hilo tiene **entrada en tabla de procesos**
- **SO planifica** hilos independientemente
- **Planificación preventiva** real

**Estructura:**
```
Kernel Space:    [KLT1][KLT2][KLT3] ← Cada uno conocido por kernel
                    |     |     |
User Space:     [Hilo1][Hilo2][Hilo3] ← Mapeo 1:1
```

### 3.4 Modelos de Implementación

#### Modelo Many-to-One (N:1) - ULT Puro
```
N hilos de usuario → 1 hilo kernel

[ULT1][ULT2][ULT3] → [KLT] → CPU
```

**Ventajas:**
- ✅ Context switch muy rápido (solo cambio de registros)
- ✅ Sin syscalls para gestión de hilos
- ✅ Planificación específica por aplicación

**Desventajas:**
- ❌ No hay paralelismo real (solo un CPU core)
- ❌ Si un hilo se bloquea, bloquea todo el proceso
- ❌ No aprovecha sistemas SMP/multicore

#### Modelo One-to-One (1:1) - KLT Puro
```
1 hilo de usuario → 1 hilo kernel

[ULT1] → [KLT1] → CPU1
[ULT2] → [KLT2] → CPU2  
[ULT3] → [KLT3] → CPU3
```

**Ventajas:**
- ✅ Paralelismo real en sistemas multicore
- ✅ Si un hilo se bloquea, otros continúan
- ✅ Planificación justa por el SO

**Desventajas:**
- ❌ Context switch más lento (syscall al kernel)
- ❌ Limitado por recursos del kernel
- ❌ Overhead de creación mayor

#### Modelo Many-to-Many (M:N) - Híbrido
```
M hilos de usuario → N hilos kernel (donde M > N)

[ULT1][ULT2][ULT3][ULT4] → [KLT1][KLT2] → CPU1,CPU2
```

**Ventajas:**
- ✅ Combina ventajas de ambos modelos
- ✅ Paralelismo real + eficiencia de ULT
- ✅ Adaptable a recursos disponibles

**Desventajas:**
- ❌ Complejidad de implementación muy alta
- ❌ Scheduler de dos niveles
- ❌ Debugging más difícil

## 4. Análisis Técnico

### 4.1 Ciclo de Vida de un Hilo

Los hilos pasan por estados similares a los procesos, pero con diferencias:

```
Diagrama de estados de hilo:

    [spawn]
       ↓
   [NASCENT] ──→ [READY] ──→ [RUNNING] ──→ [TERMINATED]
       ↑            ↑           ↓              ↓
       │            └─────── [BLOCKED] ────→ [join/detach]
       │                        ↑
       └────── [SUSPENDED] ─────┘
```

**Estados específicos de hilos:**

1. **NASCENT**: Hilo creado pero aún no listo para ejecución
2. **READY**: En cola de hilos listos para ejecutar  
3. **RUNNING**: Ejecutándose en un CPU core
4. **BLOCKED**: Esperando recurso (mutex, I/O, condition variable)
5. **SUSPENDED**: Suspendido por debugger o control de flujo
6. **TERMINATED**: Terminado, esperando join() o detached

### 4.2 Context Switch entre Hilos

#### Context Switch ULT (rápido):
```c
// Pseudocódigo de context switch ULT
void uthread_context_switch(uthread_t *from, uthread_t *to) {
    // 1. Guardar registros del hilo actual
    save_registers(&from->cpu_state);
    
    // 2. Cambiar stack pointer
    from->stack_pointer = current_sp;
    current_sp = to->stack_pointer;
    
    // 3. Restaurar registros del nuevo hilo  
    restore_registers(&to->cpu_state);
    
    // 4. Saltar a la nueva ubicación
    jump_to(to->program_counter);
    
    // Total: ~20-50 instrucciones, sin syscalls
}
```

#### Context Switch KLT (más lento):
```c
// Pseudocódigo de context switch KLT  
void kthread_context_switch(kthread_t *from, kthread_t *to) {
    // 1. Syscall al kernel
    enter_kernel_mode();
    
    // 2. Guardar estado completo en PCB
    save_full_context(&from->pcb);
    
    // 3. Cambiar espacio de direcciones si es otro proceso
    if (from->process != to->process) {
        switch_memory_context(to->process->mm);
        flush_tlb();
    }
    
    // 4. Cargar estado del nuevo hilo
    load_full_context(&to->pcb);
    
    // 5. Return from syscall
    return_to_user_mode();
    
    // Total: ~200-1000 instrucciones, con syscalls
}
```

**Diferencia de rendimiento**: ULT puede ser **10-50x más rápido** que KLT para context switch.

### 4.3 Planificación en Sistemas con Hilos

#### Planificación ULT:
```c
// Planificador de biblioteca de hilos (ejemplo Round Robin)
void uthread_scheduler() {
    static int current_thread = 0;
    static int time_slice = 0;
    
    // Increment time (called by timer interrupt or cooperative yield)
    time_slice++;
    
    // Time quantum expired?
    if (time_slice >= QUANTUM) {
        time_slice = 0;
        
        // Find next ready thread
        do {
            current_thread = (current_thread + 1) % MAX_THREADS;
        } while (threads[current_thread].state != READY);
        
        // Context switch to next thread
        uthread_context_switch(&threads[old], &threads[current_thread]);
    }
}
```

#### Planificación KLT:
El kernel planifica hilos como entidades independientes, sin conocer que pertenecen al mismo proceso.

**Problema de planificación desbalanceada:**
```
Proceso A: 10 hilos    Proceso B: 1 hilo

Con round-robin justo entre hilos:
A1 → B1 → A2 → A3 → A4 → A5 → A6 → A7 → A8 → A9 → A10 → A1...

Resultado: Proceso A recibe 91% del CPU, Proceso B solo 9%
```

**Solución**: Planificación consciente de procesos (process-aware scheduling).

### 4.4 Problemas Específicos de Hilos

#### 1. Compartición No Deseada
```c
// PROBLEMA: Variable global compartida
int global_counter = 0;

void* thread_function(void* arg) {
    for (int i = 0; i < 1000000; i++) {
        global_counter++;  // RACE CONDITION!
    }
    return NULL;
}

// Si dos hilos ejecutan esto, resultado final es impredecible
```

#### 2. Stack Overflow
```c
// PROBLEMA: Stack por defecto suele ser 8MB
void recursive_function(int depth) {
    char large_array[10000];  // 10KB por llamada
    
    if (depth < 1000) {
        recursive_function(depth + 1);  // Puede explotar el stack
    }
}
```

#### 3. Memory Leaks en Hilos
```c
// PROBLEMA: Hilo terminado sin join() o detach()
pthread_t thread;
pthread_create(&thread, NULL, worker_function, NULL);
// Sin pthread_join() o pthread_detach(), el hilo se vuelve zombie
```

## 5. Código en C

### 5.1 Creación Básica de Hilos con pthreads

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

// Función que ejecutará el hilo
void* thread_function(void* arg) {
    int thread_id = *(int*)arg;  // Convertir argumento
    
    printf("Hilo %d iniciado - TID: %lu\n", thread_id, pthread_self());
    
    // Simular trabajo
    for (int i = 0; i < 5; i++) {
        printf("Hilo %d trabajando... iteración %d\n", thread_id, i + 1);
        sleep(1);  // Simular trabajo de 1 segundo
    }
    
    printf("Hilo %d terminando\n", thread_id);
    
    // Valor de retorno del hilo
    int* result = malloc(sizeof(int));
    *result = thread_id * 100;  // Resultado ficticio
    
    return result;  // pthread_join() puede obtener este valor
}

int main() {
    const int NUM_THREADS = 3;
    pthread_t threads[NUM_THREADS];
    int thread_ids[NUM_THREADS];
    int* thread_results[NUM_THREADS];
    
    printf("Proceso principal - PID: %d\n", getpid());
    
    // Crear hilos
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i + 1;
        
        int result = pthread_create(&threads[i],      // pthread_t handle
                                   NULL,              // atributos (default)
                                   thread_function,   // función a ejecutar
                                   &thread_ids[i]);   // argumento
        
        if (result != 0) {
            perror("Error creando hilo");
            exit(1);
        }
        
        printf("Hilo %d creado exitosamente\n", i + 1);
    }
    
    // Esperar que terminen todos los hilos
    printf("Proceso principal esperando hilos...\n");
    
    for (int i = 0; i < NUM_THREADS; i++) {
        void* thread_return_value;
        
        int result = pthread_join(threads[i], &thread_return_value);
        
        if (result != 0) {
            perror("Error en pthread_join");
            exit(1);
        }
        
        thread_results[i] = (int*)thread_return_value;
        printf("Hilo %d terminado con resultado: %d\n", 
               i + 1, *thread_results[i]);
        
        // Liberar memoria del resultado
        free(thread_results[i]);
    }
    
    printf("Todos los hilos terminados. Proceso principal terminando.\n");
    return 0;
}
```

**Compilación y ejecución:**
```bash
gcc -o threads_basic threads_basic.c -lpthread
./threads_basic
```

**Análisis línea por línea:**

- **Línea 8**: Función que ejecutará cada hilo, recibe `void*` y retorna `void*`
- **Línea 9**: Cast del argumento genérico a tipo específico
- **Línea 11**: `pthread_self()` retorna Thread ID del hilo actual
- **Líneas 23-24**: Alocar memoria para valor de retorno (importante!)
- **Línea 37**: `pthread_create()` crea el hilo con función y argumento
- **Línea 49**: `pthread_join()` espera terminación y obtiene valor de retorno
- **Línea 57**: Liberar memoria del resultado (evitar memory leak)

### 5.2 Hilos con Datos Compartidos y Sincronización

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

// Datos compartidos entre hilos
typedef struct {
    int shared_counter;
    pthread_mutex_t mutex;    // Protege el contador
    int total_iterations;
} shared_data_t;

// Función del hilo trabajador
void* worker_thread(void* arg) {
    shared_data_t* data = (shared_data_t*)arg;
    int local_work = 0;
    
    for (int i = 0; i < data->total_iterations; i++) {
        // Trabajo local (sin sincronización)
        local_work++;
        
        // Acceso a dato compartido (requiere mutex)
        pthread_mutex_lock(&data->mutex);
        data->shared_counter++;
        printf("Hilo %lu: contador = %d, trabajo local = %d\n", 
               pthread_self() % 10000, data->shared_counter, local_work);
        pthread_mutex_unlock(&data->mutex);
        
        // Simular trabajo variable
        usleep(rand() % 100000);  // 0-100ms random
    }
    
    // Retornar trabajo realizado por este hilo
    int* result = malloc(sizeof(int));
    *result = local_work;
    return result;
}

int main() {
    const int NUM_THREADS = 4;
    const int ITERATIONS_PER_THREAD = 5;
    
    pthread_t threads[NUM_THREADS];
    shared_data_t shared_data;
    
    // Inicializar datos compartidos
    shared_data.shared_counter = 0;
    shared_data.total_iterations = ITERATIONS_PER_THREAD;
    
    // Inicializar mutex
    if (pthread_mutex_init(&shared_data.mutex, NULL) != 0) {
        perror("Error inicializando mutex");
        exit(1);
    }
    
    printf("Creando %d hilos, %d iteraciones cada uno\n", 
           NUM_THREADS, ITERATIONS_PER_THREAD);
    
    // Crear hilos trabajadores
    for (int i = 0; i < NUM_THREADS; i++) {
        if (pthread_create(&threads[i], NULL, worker_thread, &shared_data) != 0) {
            perror("Error creando hilo");
            exit(1);
        }
    }
    
    // Esperar todos los hilos
    int total_work = 0;
    
    for (int i = 0; i < NUM_THREADS; i++) {
        int* thread_work;
        pthread_join(threads[i], (void**)&thread_work);
        
        total_work += *thread_work;
        printf("Hilo %d completó %d unidades de trabajo\n", i + 1, *thread_work);
        free(thread_work);
    }
    
    // Verificar resultados
    printf("\nResultados finales:\n");
    printf("Contador compartido: %d (esperado: %d)\n", 
           shared_data.shared_counter, NUM_THREADS * ITERATIONS_PER_THREAD);
    printf("Trabajo total: %d\n", total_work);
    
    // Limpiar mutex
    pthread_mutex_destroy(&shared_data.mutex);
    
    return 0;
}
```

### 5.3 Simulación de User-Level Threads

```c
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <setjmp.h>
#include <unistd.h>

#define MAX_THREADS 10
#define STACK_SIZE 32768
#define TIME_QUANTUM 3  // segundos

// Estados de ULT
typedef enum {
    ULT_NASCENT,
    ULT_READY, 
    ULT_RUNNING,
    ULT_BLOCKED,
    ULT_TERMINATED
} ult_state_t;

// Estructura de User-Level Thread
typedef struct {
    int tid;                    // Thread ID
    ult_state_t state;         // Estado actual
    jmp_buf context;           // Contexto (registros salvados)
    char* stack;               // Stack privado
    void* (*start_routine)(void*);  // Función inicial
    void* arg;                 // Argumento
    void* return_value;        // Valor de retorno
} ult_t;

// Scheduler de ULT
static ult_t threads[MAX_THREADS];
static int current_thread = -1;
static int num_threads = 0;
static int scheduler_initialized = 0;

// Handler del timer para planificación preventiva
void timer_handler(int sig) {
    if (!scheduler_initialized || current_thread == -1) return;
    
    printf("Timer: Quantum agotado, cambiando hilo...\n");
    ult_yield();  // Forzar cambio de contexto
}

// Crear User-Level Thread
int ult_create(void* (*start_routine)(void*), void* arg) {
    if (num_threads >= MAX_THREADS) return -1;
    
    int tid = num_threads++;
    
    threads[tid].tid = tid;
    threads[tid].state = ULT_NASCENT;
    threads[tid].stack = malloc(STACK_SIZE);
    threads[tid].start_routine = start_routine;
    threads[tid].arg = arg;
    threads[tid].return_value = NULL;
    
    // Configurar stack y contexto inicial
    if (setjmp(threads[tid].context) == 0) {
        // Configurar stack pointer (arquitectura específica)
        // Esto es simplificado - en realidad requiere assembly
        threads[tid].state = ULT_READY;
        printf("ULT %d creado\n", tid);
    }
    
    return tid;
}

// Scheduler Round Robin para ULT
void ult_schedule() {
    int next_thread = -1;
    
    // Buscar próximo hilo READY
    for (int i = 0; i < num_threads; i++) {
        int candidate = (current_thread + 1 + i) % num_threads;
        
        if (threads[candidate].state == ULT_READY) {
            next_thread = candidate;
            break;
        }
    }
    
    if (next_thread == -1) {
        printf("Scheduler: No hay hilos READY\n");
        return;
    }
    
    // Context switch
    int old_thread = current_thread;
    current_thread = next_thread;
    
    if (old_thread != -1 && threads[old_thread].state == ULT_RUNNING) {
        threads[old_thread].state = ULT_READY;
    }
    
    threads[current_thread].state = ULT_RUNNING;
    
    printf("Scheduler: Cambiando de ULT %d a ULT %d\n", 
           old_thread, current_thread);
    
    // Configurar nuevo quantum
    alarm(TIME_QUANTUM);
    
    // Saltar al nuevo hilo (simplificado)
    if (setjmp(old_thread >= 0 ? threads[old_thread].context : threads[0].context) == 0) {
        longjmp(threads[current_thread].context, 1);
    }
}

// Yield voluntario
void ult_yield() {
    ult_schedule();
}

// Función wrapper que ejecuta la función del hilo
void ult_thread_wrapper() {
    int tid = current_thread;
    
    printf("ULT %d iniciando ejecución\n", tid);
    
    // Ejecutar función del hilo
    threads[tid].return_value = threads[tid].start_routine(threads[tid].arg);
    
    // Marcar como terminado
    threads[tid].state = ULT_TERMINATED;
    printf("ULT %d terminado\n", tid);
    
    // Buscar próximo hilo
    ult_schedule();
}

// Inicializar scheduler
void ult_init() {
    // Configurar handler de timer
    signal(SIGALRM, timer_handler);
    scheduler_initialized = 1;
    
    printf("ULT Scheduler inicializado\n");
}

// Funciones de prueba para hilos
void* test_function_1(void* arg) {
    int id = *(int*)arg;
    
    for (int i = 0; i < 10; i++) {
        printf("  ULT %d: iteración %d\n", id, i + 1);
        sleep(1);  // Simular trabajo
        
        if (i % 3 == 0) {
            printf("  ULT %d: yield voluntario\n", id);
            ult_yield();
        }
    }
    
    return NULL;
}

void* test_function_2(void* arg) {
    int id = *(int*)arg;
    
    for (int i = 0; i < 8; i++) {
        printf("  ULT %d: procesando tarea %d\n", id, i + 1);
        sleep(1);
    }
    
    return NULL;
}

int main() {
    printf("=== Simulación de User-Level Threads ===\n");
    
    ult_init();
    
    // Crear algunos ULT
    int id1 = 1, id2 = 2;
    
    ult_create(test_function_1, &id1);
    ult_create(test_function_2, &id2);
    
    printf("ULTs creados, iniciando scheduler...\n");
    
    // Iniciar ejecución
    current_thread = 0;
    threads[0].state = ULT_RUNNING;
    alarm(TIME_QUANTUM);
    
    // Simular ejecución (simplificado)
    // En implementación real, esto sería más complejo
    printf("Simulación ejecutándose por 30 segundos...\n");
    sleep(30);
    
    printf("Simulación terminada\n");
    
    // Cleanup
    for (int i = 0; i < num_threads; i++) {
        free(threads[i].stack);
    }
    
    return 0;
}
```

### 5.4 Comparación de Rendimiento ULT vs KLT

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>

#define NUM_SWITCHES 1000000

// Variables globales para test
volatile int switch_count = 0;
pthread_t test_threads[2];
pthread_mutex_t switch_mutex = PTHREAD_MUTEX_INITIALIZER;

// Función para medir tiempo
double get_time_diff(struct timespec start, struct timespec end) {
    return (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
}

// Test de context switch con KLT (pthreads)
void* klt_context_switch_test(void* arg) {
    int thread_id = *(int*)arg;
    
    for (int i = 0; i < NUM_SWITCHES / 2; i++) {
        pthread_mutex_lock(&switch_mutex);
        
        switch_count++;
        
        // Forzar yield al otro hilo
        pthread_mutex_unlock(&switch_mutex);
        sched_yield();  // Syscall para yield
    }
    
    return NULL;
}

// Simular ULT context switch (sin syscalls)
void ult_context_switch_simulation() {
    struct timespec start, end;
    
    printf("Simulando %d context switches ULT...\n", NUM_SWITCHES);
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    // Simular context switches sin syscalls
    for (int i = 0; i < NUM_SWITCHES; i++) {
        // Simular guardar/restaurar registros (operaciones rápidas)
        volatile int dummy_registers[10];
        for (int j = 0; j < 10; j++) {
            dummy_registers[j] = i + j;  // Simular save
        }
        // No hay syscalls, no cambio de privilegio
    }
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double time_taken = get_time_diff(start, end);
    double switches_per_second = NUM_SWITCHES / time_taken;
    double nanoseconds_per_switch = (time_taken * 1e9) / NUM_SWITCHES;
    
    printf("ULT Resultados:\n");
    printf("  Tiempo total: %.3f segundos\n", time_taken);
    printf("  Context switches por segundo: %.0f\n", switches_per_second);
    printf("  Nanosegundos por switch: %.1f ns\n", nanoseconds_per_switch);
}

// Test completo de rendimiento
void performance_comparison() {
    struct timespec start, end;
    int thread_ids[2] = {1, 2};
    
    printf("=== Comparación de Rendimiento ULT vs KLT ===\n\n");
    
    // Test ULT (simulado)
    ult_context_switch_simulation();
    
    printf("\n");
    
    // Test KLT (pthreads reales)
    printf("Ejecutando %d context switches KLT...\n", NUM_SWITCHES);
    switch_count = 0;
    
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    // Crear dos hilos que alternarán constantemente
    pthread_create(&test_threads[0], NULL, klt_context_switch_test, &thread_ids[0]);
    pthread_create(&test_threads[1], NULL, klt_context_switch_test, &thread_ids[1]);
    
    // Esperar que terminen
    pthread_join(test_threads[0], NULL);
    pthread_join(test_threads[1], NULL);
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    double time_taken = get_time_diff(start, end);
    double switches_per_second = switch_count / time_taken;
    double nanoseconds_per_switch = (time_taken * 1e9) / switch_count;
    
    printf("KLT Resultados:\n");
    printf("  Tiempo total: %.3f segundos\n", time_taken);
    printf("  Context switches realizados: %d\n", switch_count);
    printf("  Context switches por segundo: %.0f\n", switches_per_second);
    printf("  Nanosegundos por switch: %.1f ns\n", nanoseconds_per_switch);
    
    printf("\n=== Análisis ===\n");
    printf("ULT es aproximadamente %.1fx más rápido que KLT\n", 
           (NUM_SWITCHES / time_taken) / switches_per_second);
}

int main() {
    performance_comparison();
    return 0;
}
```

## 6. Casos de Estudio

### Caso de Estudio 1: Planificación Combinada Procesos-Hilos

**Ejercicio típico de parcial:**
Un sistema tiene 2 procesos, cada uno con múltiples hilos KLT. El planificador del SO usa Round Robin con Q=4ms entre todos los hilos.

```
Proceso A:
- Hilo A1: Llegada=0, CPU=12ms
- Hilo A2: Llegada=2, CPU=8ms

Proceso B: 
- Hilo B1: Llegada=1, CPU=6ms
- Hilo B2: Llegada=3, CPU=10ms
```

**Calcular tiempo promedio de retorno y analizar fairness entre procesos.**

**Resolución paso a paso:**

```
Timeline de llegadas:
t=0: A1 llega
t=1: B1 llega  
t=2: A2 llega
t=3: B2 llega

Planificación RR con Q=4ms:

t=0-4:   A1 ejecuta (remaining=8ms)
t=4-8:   B1 ejecuta (remaining=2ms)  
t=8-12:  A2 ejecuta (remaining=4ms)
t=12-16: B2 ejecuta (remaining=6ms)
t=16-20: A1 ejecuta (remaining=4ms)  
t=20-22: B1 ejecuta (termina, remaining=0ms)
t=22-26: A2 ejecuta (termina, remaining=0ms)
t=26-30: B2 ejecuta (remaining=2ms)
t=30-34: A1 ejecuta (termina, remaining=0ms)
t=34-36: B2 ejecuta (termina, remaining=0ms)

Diagrama de Gantt:
0   4   8   12  16  20 22 26  30  34 36
|A1 |B1 |A2 |B2 |A1 |B1|A2|B2 |A1 |B2|
```

**Cálculos de métricas:**

```
Tiempos de terminación:
A1: 34ms, A2: 26ms, B1: 22ms, B2: 36ms

Tiempos de retorno:
A1: 34-0 = 34ms
A2: 26-2 = 24ms  
B1: 22-1 = 21ms
B2: 36-3 = 33ms
Promedio: (34+24+21+33)/4 = 28ms

Análisis de fairness por proceso:
Proceso A: CPU total = 20ms, tiempo total = 34ms
Proceso B: CPU total = 16ms, tiempo total = 35ms

Porcentaje de CPU:
Proceso A: 20/36 = 55.6%
Proceso B: 16/36 = 44.4%

¡Relativamente justo considerando que A tiene más trabajo total!
```

**Comparación con planificación por procesos:**
Si el SO planificara por procesos (no hilos), cada proceso recibiría 50% del tiempo, independiente del número de hilos.

### Caso de Estudio 2: Problema del Servidor Web Multihilo

**Problema real:** Un servidor web debe manejar múltiples conexiones concurrentes. ¿Cuándo usar hilos vs procesos?

**Escenario:** 1000 conexiones simultáneas, cada una requiere:
- Leer request HTTP (I/O bound)
- Procesar request (CPU bound moderado)
- Acceder base de datos (I/O bound)
- Enviar response (I/O bound)

**Análisis de alternativas:**

#### Alternativa 1: Un proceso por conexión
```c
// Modelo fork() por conexión
for each connection {
    if (fork() == 0) {
        handle_connection(conn);  // Proceso hijo maneja conexión
        exit(0);
    }
}
```

**Recursos:**
- Memoria: 1000 procesos × 8MB = 8GB RAM
- Context switches: Costosos (flush TLB, cambio MM)
- Creación: ~1ms por fork()

#### Alternativa 2: Un hilo por conexión  
```c
// Modelo pthread por conexión
for each connection {
    pthread_create(&thread, NULL, handle_connection, conn);
}
```

**Recursos:**
- Memoria: 1 proceso + (1000 hilos × 8KB stack) = ~8MB RAM
- Context switches: Rápidos (mismo espacio de direcciones)
- Creación: ~50μs por pthread_create()

#### Alternativa 3: Pool de hilos
```c
// Pool fijo de hilos trabajadores
#define WORKER_THREADS 50
pthread_t workers[WORKER_THREADS];
queue_t connection_queue;

void* worker_thread(void* arg) {
    while (true) {
        connection_t* conn = queue_dequeue(&connection_queue);
        if (conn) {
            handle_connection(conn);
        }
    }
}
```

**Recursos:**
- Memoria: 1 proceso + (50 hilos × 8KB) = ~400KB RAM
- No overhead de creación/destrucción
- Controla concurrencia (evita overload)

**Recomendación:** Pool de hilos para servidores de alto rendimiento.

### Caso de Estudio 3: Debugging de Problemas de Hilos

**Problema típico:** Race condition en contador compartido

```c
#include <stdio.h>
#include <pthread.h>

int global_counter = 0;  // Variable compartida

void* increment_thread(void* arg) {
    int iterations = *(int*)arg;
    
    for (int i = 0; i < iterations; i++) {
        // PROBLEMA: Esta operación NO es atómica
        global_counter++;
        
        // En assembly se traduce a:
        // 1. LOAD global_counter → register
        // 2. INCREMENT register  
        // 3. STORE register → global_counter
        // 
        // Entre cualquiera de estos pasos puede haber context switch!
    }
    
    return NULL;
}

int main() {
    pthread_t threads[2];
    int iterations = 1000000;
    
    // Crear dos hilos que incrementan el mismo contador
    pthread_create(&threads[0], NULL, increment_thread, &iterations);
    pthread_create(&threads[1], NULL, increment_thread, &iterations);
    
    pthread_join(threads[0], NULL);
    pthread_join(threads[1], NULL);
    
    printf("Resultado: %d (esperado: %d)\n", global_counter, iterations * 2);
    
    // Resultado típico: 1,234,567 (¡NO 2,000,000!)
    return 0;
}
```

**Diagnóstico con herramientas:**

```bash
# Compilar con información de debug
gcc -g -pthread -o race_condition race_condition.c

# Detectar race conditions con ThreadSanitizer
gcc -g -pthread -fsanitize=thread -o race_condition race_condition.c
./race_condition

# Salida de ThreadSanitizer:
# WARNING: ThreadSanitizer: data race (pid=1234)
# Write of size 4 at 0x7f8b4c000000 by thread T1:
#   #0 increment_thread race_condition.c:12
# Previous write of size 4 at 0x7f8b4c000000 by thread T2:
#   #0 increment_thread race_condition.c:12
```

**Solución con mutex:**
```c
pthread_mutex_t counter_mutex = PTHREAD_MUTEX_INITIALIZER;

void* increment_thread_safe(void* arg) {
    int iterations = *(int*)arg;
    
    for (int i = 0; i < iterations; i++) {
        pthread_mutex_lock(&counter_mutex);
        global_counter++;  // Ahora es thread-safe
        pthread_mutex_unlock(&counter_mutex);
    }
    
    return NULL;
}
```

**Análisis de rendimiento de la solución:**
```c
// Medir overhead del mutex
struct timespec start, end;

clock_gettime(CLOCK_MONOTONIC, &start);
// ... ejecutar versión con mutex ...
clock_gettime(CLOCK_MONOTONIC, &end);

// Típico: versión con mutex es 10-50x más lenta
// Pero produce resultado correcto
```

## 7. Síntesis

### 7.1 Puntos Clave para Parcial

**Diferencias fundamentales ULT vs KLT:**

| Aspecto | User-Level Threads (ULT) | Kernel-Level Threads (KLT) |
|---------|--------------------------|----------------------------|
| **Visibilidad** | Solo biblioteca los conoce | Kernel los planifica individualmente |
| **Context Switch** | 50-200 instrucciones | 500-2000 instrucciones |
| **Creación** | ~1-10 μs | ~50-200 μs |
| **Paralelismo** | No (1 KLT subyacente) | Sí (múltiples CPUs) |
| **Bloqueo** | Si uno se bloquea, todos se bloquean | Solo se bloquea el hilo específico |
| **Planificación** | Cooperativa o por biblioteca | Preventiva por SO |

**Modelos de mapeo:**

```
N:1 (Many-to-One)
[ULT1][ULT2][ULT3] → [KLT1] 
✅ Context switch rápido
❌ No paralelismo real

1:1 (One-to-One)  
[ULT1] → [KLT1]
[ULT2] → [KLT2]
✅ Paralelismo total
❌ Overhead alto

M:N (Many-to-Many)
[ULT1][ULT2][ULT3][ULT4] → [KLT1][KLT2]
✅ Balance de ventajas
❌ Complejidad alta
```

**APIs esenciales de pthreads:**
```c
// Gestión de hilos
pthread_create(thread, attr, start_routine, arg);
pthread_join(thread, retval);
pthread_detach(thread);
pthread_exit(retval);

// Sincronización básica
pthread_mutex_init(mutex, attr);
pthread_mutex_lock(mutex);
pthread_mutex_unlock(mutex);
pthread_mutex_destroy(mutex);

// Información del hilo
pthread_self();      // Obtener TID
pthread_equal(t1, t2);  // Comparar TIDs
```

### 7.2 Errores Comunes y Tips

**❌ Errores frecuentes:**

1. **No hacer join() o detach()**
   ```c
   // MAL: Hilo zombie
   pthread_create(&thread, NULL, func, NULL);
   // Sin pthread_join() ni pthread_detach()
   ```

2. **Race conditions en datos compartidos**
   ```c
   // MAL: Sin protección
   global_var++;  // No atómico!
   
   // BIEN: Con mutex
   pthread_mutex_lock(&mutex);
   global_var++;
   pthread_mutex_unlock(&mutex);
   ```

3. **Retornar punteros a variables locales**
   ```c
   // MAL: Variable local desaparece
   void* thread_func(void* arg) {
       int result = 42;
       return &result;  // ¡Puntero inválido!
   }
   
   // BIEN: Memoria dinámica
   void* thread_func(void* arg) {
       int* result = malloc(sizeof(int));
       *result = 42;
       return result;  // Caller debe hacer free()
   }
   ```

4. **Deadlock con múltiples mutex**
   ```c
   // MAL: Orden inconsistente
   Thread 1: lock(A); lock(B);
   Thread 2: lock(B); lock(A);  // ¡Deadlock!
   
   // BIEN: Orden consistente
   Thread 1: lock(A); lock(B);
   Thread 2: lock(A); lock(B);
   ```

**✅ Tips para parcial:**

1. **Dibujar diagramas de timeline** para problemas de planificación
2. **Identificar qué se comparte** entre hilos (heap) y qué no (stack)
3. **Calcular overhead**: ULT ~10-50x más rápido para context switch
4. **Reconocer cuándo usar cada modelo**: 
   - ULT: Aplicaciones cooperativas, muchos hilos cortos
   - KLT: Aplicaciones paralelas, sistemas multicore
5. **Siempre considerar sincronización** cuando hay datos compartidos

### 7.3 Decisiones de Diseño en Aplicaciones Reales

**Cuándo usar hilos vs procesos:**

| Criterio | Usar Hilos | Usar Procesos |
|----------|------------|---------------|
| **Compartir datos** | Mucho | Poco/Nada |
| **Aislamiento** | No crítico | Esencial |
| **Rendimiento** | Context switch rápido | Aislamiento vale overhead |
| **Debugging** | Más difícil | Más fácil |
| **Escalabilidad** | Limitada por GIL (Python) | Mejor para CPU-bound |

**Ejemplos por dominio:**

**Servidores web:**
- **Apache prefork**: 1 proceso por request (aislamiento máximo)
- **Apache worker**: Pool de hilos (balance performance/aislamiento)
- **Nginx**: Event-driven + threads (alta concurrencia)

**Bases de datos:**
- **PostgreSQL**: 1 proceso por conexión (aislamiento)
- **MySQL**: Pool de hilos (compartir buffers)

**Navegadores:**
- **Chrome**: 1 proceso por tab (aislamiento de seguridad)
- **Firefox**: Múltiples procesos + hilos por proceso

### 7.4 Conexión con Próximos Temas

Los hilos son fundamentales para entender:

**Sincronización (Capítulo 5):**
- **Mutex, semáforos, condition variables**
- **Problemas clásicos**: Productor-Consumidor, Lectores-Escritores
- **Deadlock, livelock, starvation**

**Interbloqueo (Capítulo 6):**
- **Hilos compiten por múltiples recursos**
- **Algoritmos de prevención y detección**
- **Banker's algorithm con hilos**

**Gestión de Memoria (Capítulos 7-8):**
- **Stacks de hilos en memoria virtual**
- **Thread-local storage (TLS)**  
- **Memory models y coherencia de cache**

**Ejemplo integrador:**
```c
// Problema que combina hilos + memoria + sincronización
typedef struct {
    pthread_t tid;
    char* private_stack;     // Memoria privada
    shared_buffer_t* shared; // Memoria compartida (requiere sync)
    int cpu_affinity;        // Planificación (siguiente tema)
} thread_context_t;
```

### 7.5 Laboratorio Sugerido

**Práctica 1**: Comparar rendimiento ULT vs KLT
```c
// Implementar benchmark de context switches
// Medir overhead con diferentes números de hilos
// Analizar escalabilidad en sistemas multicore
```

**Práctica 2**: Servidor echo multihilo
```c
// Crear servidor TCP que atienda múltiples clientes
// Comparar: 1 hilo por cliente vs pool de hilos
// Medir latencia y throughput bajo carga
```

**Práctica 3**: Debugging con herramientas
```bash
# Usar Valgrind para detectar race conditions
valgrind --tool=helgrind ./programa

# Usar GDB con soporte multithread  
gdb ./programa
(gdb) info threads
(gdb) thread 2
(gdb) bt
```

**Pregunta de reflexión para próximo capítulo:**
Ahora que tenemos múltiples hilos ejecutándose concurrentemente y compartiendo datos, ¿cómo podemos asegurar que accedan a los recursos compartidos de manera segura y eficiente? ¿Qué problemas pueden surgir y cómo los resolvemos?

---

**Próximo capítulo recomendado**: Capítulo 5: Sincronización - Coordinación segura entre hilos y procesos concurrentes.