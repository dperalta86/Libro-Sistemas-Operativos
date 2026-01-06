# Hilos (Threads)

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

Los procesos tradicionales resuelven la multiprogramación, pero presentan limitaciones importantes en aplicaciones modernas. La creación de un proceso mediante `fork()` implica copiar todo el espacio de direcciones, lo cual resulta costoso en términos de tiempo y memoria. El cambio de contexto entre procesos requiere actualizar el mapa de memoria completo, invalidar caches y la TLB (Translation Lookaside Buffer), operaciones que consumen cientos o miles de ciclos de CPU. La comunicación entre procesos necesita mecanismos especiales como IPC, pipes o memoria compartida, añadiendo complejidad al diseño del sistema. Además, el aislamiento de recursos, aunque beneficioso para la seguridad, dificulta compartir datos eficientemente entre tareas relacionadas.
\begin{example}
Consideremos un navegador web moderno. Durante la carga de una página se ejecutan simultáneamente múltiples tareas: descarga de HTML, procesamiento y renderizado, descarga de imágenes, ejecución de JavaScript y manejo de eventos del usuario. Si estas tareas fueran procesos separados, el overhead de comunicación y context switching sería prohibitivo. Los hilos permiten que todas estas actividades compartan memoria y se comuniquen de forma directa, reduciendo la latencia y mejorando la experiencia del usuario.
\end{example}

### La solución: hilos como procesos livianos

\begin{excerpt}
\emph{Hilo (Thread):} Unidad básica de utilización del CPU dentro de un proceso, caracterizada por tener su propio flujo de ejecución independiente pero compartiendo el espacio de direcciones con otros hilos del mismo proceso.
\end{excerpt}

Los hilos representan una abstracción fundamental que separa dos conceptos previamente unidos en los procesos: el espacio de direcciones y el flujo de ejecución. Mientras que los procesos tradicionales combinan ambos aspectos de forma inseparable, los hilos permiten múltiples flujos de ejecución dentro del mismo espacio de direcciones.  

Esta separación tiene profundas implicaciones. Los hilos dentro de un proceso comparten el código ejecutable, las variables globales, el heap dinámico, los archivos abiertos y otros recursos del sistema. Sin embargo, cada hilo mantiene elementos privados esenciales para su ejecución independiente: su propio identificador (TID), el conjunto completo de registros del procesador incluyendo el program counter y stack pointer, un stack privado para variables locales y llamadas a funciones, y su propio estado de planificación.  

La compartición del espacio de direcciones significa que las variables globales y la memoria dinámica son accesibles directamente por todos los hilos, sin necesidad de mecanismos complejos de IPC. Esta característica simplifica enormemente la comunicación entre hilos, aunque introduce nuevos desafíos relacionados con la sincronización que exploraremos en profundidad en capítulos posteriores.

## Estructura y Definiciones Fundamentales

### Anatomía de un hilo

Cada hilo mantiene una estructura de control que el sistema operativo utiliza para gestionar su ejecución. Esta estructura, típicamente llamada Thread Control Block (TCB), contiene toda la información necesaria para suspender y reanudar el hilo:

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

El TID (Thread ID) identifica únicamente al hilo dentro de su proceso. El estado refleja su situación actual en el sistema: ready cuando está listo para ejecutar, running cuando tiene asignado un CPU, blocked cuando espera por algún recurso, o terminated cuando ha finalizado. Los punteros `stack_pointer` y `program_counter` capturan exactamente dónde se encuentra el hilo en su ejecución. El campo `registers` preserva el estado completo de los registros del procesador, permitiendo que el hilo retome su ejecución exactamente donde la dejó después de un cambio de contexto.

\begin{warning}
La información del stack es crítica. Cada hilo necesita su propio stack para almacenar variables locales, parámetros de funciones y direcciones de retorno. Un stack insuficiente causará stack overflow, mientras que stacks muy grandes desperdiciarán memoria. La mayoría de implementaciones usan stacks de 2-8MB por hilo, aunque sistemas embebidos pueden usar apenas 1-2KB.
\end{warning}

### Modelo de memoria con hilos
La organización del espacio de direcciones de un proceso multihilo revela claramente qué recursos son compartidos y cuáles son privados:  
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-04/01.png}
En la parte baja de la memoria encontramos el segmento de texto (código ejecutable), idéntico para todos los hilos. Inmediatamente después está el segmento de datos inicializados y el BSS (datos no inicializados), también compartidos. El heap dinámico, gestionado por malloc() y free(), crece hacia direcciones más altas y es accesible por todos los hilos del proceso.  
La parte alta de la memoria se reserva para los stacks individuales de cada hilo. Estos crecen hacia direcciones más bajas y están separados por regiones de guarda (guard pages) que detectan desbordamientos. Esta separación física de los stacks garantiza que las variables locales de un hilo no interfieran con las de otro.

\begin{infobox}
Las variables globales y el heap son compartidos entre hilos, lo que requiere sincronización explícita para evitar race conditions. En contraste, las variables locales declaradas dentro de funciones son automáticamente privadas de cada hilo, ya que residen en su stack individual. Esta distinción es fundamental para razonar sobre la corrección de programas multihilo.
\end{infobox}

## User-Level Threads vs Kernel-Level Threads
La implementación de hilos puede realizarse en dos niveles fundamentalmente diferentes del sistema: en espacio de usuario o en espacio de kernel. Esta decisión arquitectural tiene profundas implicaciones en el rendimiento, el paralelismo y la complejidad del sistema.

### User-Level Threads (ULT)

\begin{excerpt}
\emph{User-Level Threads (ULT):} Hilos implementados completamente en espacio de usuario mediante bibliotecas especializadas, donde el kernel del sistema operativo no tiene conocimiento de los hilos individuales.
\end{excerpt}
En el modelo ULT, desde la perspectiva del kernel existe únicamente un proceso con un solo hilo de ejecución. Una biblioteca especializada en espacio de usuario (como GNU Portable Threads o las bibliotecas de fibras) implementa toda la gestión de hilos: creación, destrucción, planificación y cambios de contexto.  
El cambio de contexto entre ULT es extremadamente eficiente porque no requiere transición al modo kernel. La biblioteca simplemente guarda los registros del hilo actual en su TCB y restaura los del siguiente hilo a ejecutar. Esto puede realizarse en apenas 20-50 instrucciones, comparado con las miles de instrucciones necesarias para un cambio de contexto completo que involucre al kernel.

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

Esta implementación ilustra la simplicidad fundamental de los ULT. Las funciones `setjmp()` y `longjmp()` de la biblioteca estándar de C capturan y restauran el estado de ejecución, permitiendo "saltar" entre diferentes puntos del programa. El scheduler de usuario simplemente decide qué hilo debe ejecutar a continuación y realiza el salto correspondiente.  

La planificación de ULT típicamente sigue un modelo cooperativo. Cada hilo debe voluntariamente ceder el control, ya sea llamando explícitamente a una función de yield o al realizar operaciones de I/O. Esto elimina la necesidad de interrupciones de timer, pero introduce el riesgo de que un hilo monopolice el CPU si no coopera adecuadamente.

\begin{theory}
Las ventajas de los ULT incluyen cambios de contexto extremadamente rápidos (del orden de microsegundos), ausencia de overhead de system calls, la posibilidad de implementar políticas de planificación especializadas para cada aplicación, y soporte en sistemas operativos que no implementan hilos nativamente a nivel kernel.
Sin embargo, presentan limitaciones significativas. No pueden aprovechar el paralelismo real en sistemas multicore, ya que el kernel ve un solo hilo de ejecución y lo asigna a un único procesador. Si un hilo realiza una operación de I/O bloqueante, todo el proceso se bloquea, ya que el kernel suspende el único "hilo" que conoce. La planificación cooperativa puede llevar a problemas de starvation si algunos hilos no ceden el control apropiadamente.
\end{theory}

### Kernel-Level Threads (KLT)

\begin{excerpt}
\emph{Kernel-Level Threads (KLT):} Hilos implementados y gestionados directamente por el kernel del sistema operativo, donde cada hilo es una entidad de planificación independiente conocida por el SO.
\end{excerpt}

En contraste con los ULT, los hilos a nivel kernel son entidades de primera clase en el sistema operativo. Cada KLT tiene su propia entrada en las tablas de planificación del kernel y es gestionado exactamente como un proceso ligero. El kernel mantiene un TCB completo para cada hilo y realiza todos los cambios de contexto.

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

Este pseudocódigo revela la complejidad adicional del cambio de contexto a nivel kernel. Además de guardar y restaurar los registros generales, el kernel debe preservar el estado de la unidad de punto flotante, actualizar las colas de planificación, y potencialmente cambiar el espacio de direcciones completo si los hilos pertenecen a procesos diferentes. El flush de la TLB después de cambiar el espacio de direcciones es particularmente costoso, pudiendo tomar cientos de ciclos.  
La planificación de KLT es preventiva. El kernel puede suspender un hilo en cualquier momento mediante interrupciones de timer, garantizando que ningún hilo monopolice el CPU. Esta planificación justa viene al costo de mayor overhead, pero proporciona mejor respuesta interactiva y aprovecha automáticamente sistemas multicore.

\begin{theory}
Los KLT ofrecen paralelismo real en sistemas multiprocesador o multicore. El kernel puede asignar diferentes hilos del mismo proceso a diferentes CPUs, permitiendo ejecución verdaderamente simultánea. Cuando un hilo se bloquea en I/O, solo ese hilo se suspende; otros hilos del mismo proceso continúan ejecutando. La planificación preventiva del kernel garantiza fairness entre hilos y permite prioridades sofisticadas.  
Las desventajas incluyen cambios de contexto significativamente más lentos (típicamente 500-2000 instrucciones), overhead de system calls para todas las operaciones de gestión de hilos, limitaciones en el número máximo de hilos determinadas por recursos del kernel, y mayor consumo de memoria en espacio kernel para mantener las estructuras de control.
\end{theory}

### Modelos de mapeo
La relación entre hilos de usuario y kernel puede estructurarse de varias formas, cada una con sus propias características de rendimiento y complejidad.

#### Modelo Many-to-One (N:1)
Múltiples hilos de usuario mapean a un solo hilo kernel. Este es el modelo clásico de ULT puro:  
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-04/02.png}
Este modelo maximiza la eficiencia del context switch y minimiza el uso de recursos del kernel, pero sacrifica completamente el paralelismo. Toda la aplicación se ejecuta como un único hilo desde la perspectiva del sistema operativo.

#### Modelo One-to-One (1:1)
Cada hilo de usuario mapea a un hilo kernel dedicado. Este es el modelo más común en sistemas operativos modernos:  
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-04/03.png}
Este modelo maximiza el paralelismo y permite que el kernel gestione directamente todos los hilos, pero incrementa el overhead de cada operación. Linux, Windows y la mayoría de sistemas UNIX modernos utilizan este modelo para sus implementaciones de hilos POSIX (pthreads).

#### Modelo Many-to-Many (M:N)
M hilos de usuario mapean a N hilos kernel, donde M > N. Este modelo híbrido intenta combinar las ventajas de ambos enfoques:  
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-04/04.png}
\begin{infobox}
El modelo M:N requiere un scheduler de dos niveles: uno en espacio de usuario que gestiona los hilos de usuario, y otro en el kernel que gestiona los hilos kernel. La biblioteca de hilos debe coordinar con el kernel para optimizar el mapeo dinámico, asignando hilos de usuario activos a los hilos kernel disponibles. Este modelo fue implementado en Solaris (como threads M:N) y en algunas versiones tempranas de Go, aunque la complejidad adicional ha llevado a muchos sistemas a preferir el modelo 1:1 más simple.
\end{infobox}

## Implementación en C con pthreads
La biblioteca POSIX Threads (pthreads) proporciona una API estándar para programación multihilo en sistemas UNIX y Linux. Esta interfaz ha sido adoptada ampliamente y representa el estándar de facto para programación concurrente en C.

### Creación básica de hilos
Vamos a explorar un ejemplo completo que ilustra los conceptos fundamentales de la programación con pthreads:

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

*Compilación:*
```bash
gcc -o hilos_basico hilos_basico.c -lpthread
```

Este programa demuestra varios aspectos cruciales de la programación multihilo. Primero, notemos que todos los hilos comparten el mismo PID (Process ID), confirmando que son parte del mismo proceso. Sin embargo, cada hilo tiene su propio TID (Thread ID) único, obtenido mediante `pthread_self()`.  
La función `thread_function()` acepta un puntero genérico `void*` como argumento, permitiendo pasar cualquier tipo de dato. En este caso, pasamos una estructura `thread_args_t` que contiene múltiples parámetros. Esta técnica es común cuando necesitamos proporcionar más de un valor al hilo.  
El valor de retorno del hilo también es un `void*`, permitiendo retornar cualquier tipo de dato. Aquí asignamos dinámicamente un entero con `malloc()`, lo asignamos y lo retornamos. El hilo principal recupera este valor mediante `pthread_join()` y debe recordar liberar la memoria asignada.
\begin{warning}
Es crítico entender el ciclo de vida de los datos pasados a los hilos. Las estructuras \texttt{thread\_args\[i\]} deben permanecer válidas hasta que cada hilo las haya leído completamente. Por eso las declaramos como un array en la función principal en lugar de variables locales de un bucle. Si pasáramos la dirección de una variable local que cambia en cada iteración, todos los hilos podrían ver el mismo valor (el último) debido a una race condition.
\end{warning}

### Diferencias clave respecto a procesos

La programación con hilos difiere fundamentalmente de la programación con procesos en varios aspectos. La creación de un hilo mediante `pthread_create()` es órdenes de magnitud más rápida que `fork()` porque solo necesita asignar un nuevo stack y copiar los registros iniciales, sin duplicar el espacio de direcciones completo. El cambio de contexto entre hilos del mismo proceso requiere únicamente actualizar registros y cambiar al nuevo stack, mientras que entre procesos diferentes implica además cambiar el mapa completo de memoria y purgar la TLB.  

La comunicación entre hilos es directa a través de variables globales y memoria compartida, sin necesidad de mecanismos especiales de IPC. Sin embargo, esta facilidad viene acompañada de la responsabilidad de sincronizar correctamente los accesos concurrentes para evitar race conditions.
El aislamiento entre procesos proporciona seguridad: un error en un proceso no puede corromper directamente la memoria de otro. Con hilos, un error en cualquier hilo (como escribir fuera de los límites de un array) puede corromper el estado compartido y afectar a todos los hilos del proceso. Esta falta de aislamiento hace el debugging más complejo pero permite mayor eficiencia.
\begin{example}
Consideremos una aplicación de procesamiento de imágenes. Si implementamos cada filtro (blur, sharpen, edge detection) como un proceso separado, necesitaremos copiar la imagen entre procesos o usar memoria compartida explícita. Con hilos, todos los filtros pueden acceder directamente a los mismos buffers de imagen, coordinando sus accesos mediante mutexes cuando sea necesario. Esto reduce dramáticamente el overhead de datos y simplifica la arquitectura del código.
\end{example}

| Aspecto | Procesos | Hilos |
|---------|----------|-------|
| **Creación** | fork() copia memoria completa | pthread_create() solo crea stack |
| **Memoria** | Espacios separados | Espacio compartido |
| **Comunicación** | IPC, pipes, señales | Variables globales, heap |
| **Context Switch** | Cambio completo de MM | Solo registros y stack |
| **Overhead** | Alto (1-10ms) | Bajo (10-100μs) |
| **Aislamiento** | Total | Ninguno |


## Gestión avanzada de hilos

### Workers y pool de hilos

Un patrón arquitectural fundamental en aplicaciones de alto rendimiento es el pool de hilos trabajadores. En lugar de crear y destruir hilos dinámicamente para cada tarea, mantenemos un conjunto fijo de hilos que esperan trabajo en una cola compartida.

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

El pool de hilos resuelve varios problemas importantes. Primero, elimina el overhead de creación y destrucción repetida de hilos. Aunque crear un hilo es más barato que crear un proceso, aún requiere asignar memoria para el stack (típicamente 2-8MB), inicializar estructuras kernel, y potencialmente interactuar con el scheduler. En aplicaciones que manejan miles de tareas cortas por segundo, este overhead se vuelve significativo.  

Segundo, el pool controla el nivel de concurrencia. Sin un pool, una aplicación podría crear tantos hilos como tareas pendientes haya, potencialmente sobrecargando el sistema. Con un pool de tamaño fijo, limitamos el máximo número de tareas ejecutándose simultáneamente, previniendo sobrecargas y mejorando la previsibilidad del rendimiento.  

La implementación usa un mutex para proteger la cola de tareas y una variable de condición para notificar a los workers cuando hay trabajo disponible. Los hilos esperan en `pthread_cond_wait()`, que atómicamente libera el mutex y suspende el hilo hasta recibir una señal. Cuando llega una nueva tarea, `pthread_cond_signal()` despierta un worker que la procesa.
\begin{infobox}
Los pools de hilos son ubicuos en infraestructura moderna. Servidores web como Apache (Worker MPM) y Nginx usan pools para manejar conexiones. Bases de datos como PostgreSQL y MySQL mantienen pools de hilos para procesar queries. Frameworks como Java's ThreadPoolExecutor y Python's concurrent.futures proporcionan implementaciones robustas y configurables de este patrón.
\end{infobox}

## Planificación de hilos
La planificación de hilos presenta desafíos únicos dependiendo de si están implementados a nivel usuario o kernel. Entender estas diferencias es crucial para diseñar sistemas concurrentes eficientes.

### Planificación de ULT

Con hilos a nivel usuario, la biblioteca de hilos implementa su propio scheduler sin intervención del kernel. Este scheduler típicamente funciona de forma cooperativa:

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
Este scheduler Round Robin mantiene un quantum para el hilo actual y rota entre hilos ready cuando el quantum expira o el hilo actual se bloquea. La función `ult_context_switch()` realiza el cambio de contexto en espacio de usuario, sin ningún system call.  

El desafío principal de la planificación ULT es el problema del bloqueo. Si un hilo llama a una operación de I/O bloqueante como `read()`, el kernel bloquea todo el proceso (porque solo ve un hilo), suspendiendo incluso hilos ULT que podrían continuar ejecutando. Las bibliotecas ULT sofisticadas resuelven esto usando I/O no bloqueante y multiplexando manualmente las operaciones, añadiendo complejidad considerable.

### Planificación de KLT

Con hilos a nivel kernel, el sistema operativo planifica cada hilo como una entidad independiente. Esto tiene una implicación importante pero a menudo pasada por alto:

\begin{warning}
En planificación fair entre hilos individuales, un proceso con muchos hilos puede monopolizar el CPU. Consideremos dos procesos: Proceso A con 10 hilos y Proceso B con 1 hilo. Si el scheduler distribuye tiempo equitativamente entre los 11 hilos totales, el Proceso A recibe 10/11 ≈ 91% del tiempo de CPU mientras el Proceso B recibe solo 1/11 ≈ 9%.
\end{warning}

Algunos sistemas operativos modernos implementan planificación consciente de procesos para mitigar este problema. El Completely Fair Scheduler (CFS) de Linux, por ejemplo, puede configurarse para distribuir tiempo de CPU entre grupos de hilos (cgroups) en lugar de hilos individuales, proporcionando fairness a nivel de proceso.

## Ejercicio práctico completo

Vamos a trabajar un ejercicio complejo que integra todos los conceptos vistos: planificación Round Robin, hilos KLT, hilos ULT con scheduler interno, y operaciones de I/O.

### Enunciado del problema

Un sistema con planificador Round Robin (quantum Q=3ms) debe ejecutar tres procesos con diferentes configuraciones de hilos:

*Proceso P1* tiene un único hilo KLT:
- P1-T1: Llega en t=0ms, requiere 6ms de CPU total, realiza I/O después de 4ms de uso de CPU durante 3ms

*Proceso P2* tiene dos hilos KLT independientes:
- P2-T1: Llega en t=1ms, requiere 3ms de CPU
- P2-T2: Llega en t=3ms, requiere 6ms de CPU, realiza I/O después de 5ms de uso de CPU durante 2ms

*Proceso P3* tiene arquitectura híbrida: un KLT que contiene dos ULT con scheduler interno FIFO:
- P3-T1 (KLT): Llega en t=2ms, requiere 10ms de CPU total para ejecutar sus ULT
- P3-T2 (ULT1): Llega en t=4ms, requiere 6ms de CPU
- P3-T3 (ULT2): Llega en t=2ms, requiere 4ms de CPU

El aspecto más interesante de este ejercicio es P3. Los hilos ULT (P3-T2 y P3-T3) solo pueden ejecutar cuando su KLT contenedor (P3-T1) tiene asignado el CPU. El scheduler interno FIFO significa que P3-T2 debe completarse completamente antes de que P3-T3 pueda comenzar.

### Análisis de la planificación con combinación de KLT y ULT

Analicemos la ejecución del sistema considerando que el planificador del kernel utiliza **Round Robin con quantum Q = 3ms**, y que los procesos presentan distintas arquitecturas de hilos.

En *t = 0ms*, solo el hilo **P1-T1 (KLT)** está presente en el sistema, por lo que comienza a ejecutarse inmediatamente. Durante este primer intervalo, se producen nuevas llegadas: **P2-T1** en *t = 1ms*, **P3-T1 (KLT)** en *t = 2ms*, y **P2-T2** en *t = 3ms*. Todos estos hilos son agregados a la cola *READY* mientras P1-T1 consume su quantum.

A partir de este punto, la planificación continúa siguiendo el esquema Round Robin clásico, alternando entre los distintos **KLT visibles para el sistema operativo**. En el caso de **P2**, cada uno de sus hilos (P2-T1 y P2-T2) es tratado como una entidad independiente por el kernel, pudiendo ser planificados y bloqueados por I/O de manera separada.

La situación más interesante ocurre cuando **P3-T1 obtiene el CPU**. Desde la perspectiva del sistema operativo, P3-T1 es un único hilo KLT. Sin embargo, internamente contiene dos **ULT**, gestionados por un scheduler en espacio de usuario con política FIFO. Cuando P3-T1 comienza a ejecutarse, su scheduler interno selecciona al ULT que llegó primero (**P3-ULT2**), que consume tiempo de CPU **dentro del quantum asignado al KLT**.

Durante este intervalo, el kernel no tiene visibilidad ni control sobre qué ULT está ejecutando. Para el sistema operativo, simplemente P3-T1 está usando CPU. Cuando el quantum del KLT se agota, el kernel desaloja a P3-T1, suspendiendo implícitamente la ejecución del ULT activo, aunque este no haya finalizado su trabajo.

Este comportamiento se repite cada vez que P3-T1 es planificado: el kernel decide *cuándo* ejecuta el KLT, mientras que el scheduler en espacio de usuario decide *qué ULT* se ejecuta dentro de ese intervalo. Recién cuando el primer ULT completa totalmente su ejecución, el scheduler interno permite que el siguiente ULT comience a ejecutarse.

\begin{infobox}
Los ULT dependen completamente de su KLT contenedor. Desde el punto de vista del kernel, solo existen los KLT; la planificación interna de ULT es invisible para el sistema operativo. Esto permite una planificación más liviana y flexible, pero también implica que un bloqueo o desalojo del KLT afecta a todos los ULT asociados.
\end{infobox}  

Los diagramas muestran visualmente la ejecución completa del sistema:  

![Observemos particularmente las secciones donde P3-T1 está activo. El diagrama puede mostrar internamente qué ULT está ejecutando, pero desde la perspectiva del scheduler del SO, solo P3-T1 está usando el CPU.](src/tables/cap05-gantt-RR.png)

#### Consejo para encarar ejercicios con KLT y ULT

En ejercicios que combinan hilos a nivel kernel (KLT) y hilos a nivel usuario (ULT), resulta muy útil separar el análisis en **dos etapas**, evitando mezclar niveles de planificación desde el inicio.

Una estrategia recomendable es la siguiente:

1. **Planificar primero solo los KLT**, ignorando momentáneamente la existencia de ULT.
   - El kernel únicamente planifica KLT.
   - En esta etapa se construye el diagrama de Gantt considerando llegadas, bloqueos por I/O y quantum del scheduler del sistema operativo.

2. **Una vez obtenido el Gantt de KLT**, agregar las filas correspondientes a los ULT.
   - Para cada KLT que contiene ULT, se analiza cómo su scheduler interno distribuye el tiempo de CPU recibido.
   - Los ULT consumen tiempo *dentro del quantum del KLT*, siguiendo su política interna (FIFO, en este caso).

Este enfoque puede pensarse como una **planificación anidada**:  
el kernel decide *cuándo* ejecuta cada KLT, y cada KLT decide *qué ULT* ejecuta durante ese intervalo.

Adoptar este método ayuda a:
- evitar errores conceptuales,
- mantener claro qué decisiones toma el sistema operativo y cuáles no,
- y entender mejor las limitaciones y ventajas de los ULT frente a los KLT.


## Análisis comparativo y casos de uso
Habiendo explorado los fundamentos técnicos, consideremos ahora cuándo usar cada tipo de hilo en la práctica. Esta decisión arquitectural puede determinar el éxito o fracaso de un sistema concurrente.

### Overhead de implementaciones

*Métricas de rendimiento típicas:*

| Operación | ULT | KLT | Proceso |
|-----------|-----|-----|---------|
| Creación | 1-10 μs | 50-200 μs | 1-10 ms |
| Context Switch | 0.1-1 μs | 5-50 μs | 100-1000 μs |
| Memoria por entidad | 2-8 KiB | 8-16 KiB | 4-8 MiB |
| Sincronización | Variables | Mutex/Sem | IPC |

Estas métricas revelan que los ULT son 50-100x más rápidos que los KLT para context switch, y los KLT son 10-20x más rápidos que los procesos. Sin embargo, recordemos que velocidad no es el único criterio: el paralelismo real en multicore frecuentemente vale más que la velocidad de context switch.

### Casos de uso recomendados

#### Usar ULT cuando necesitemos control fino y muchos context switches

Los ULT brillan en aplicaciones con tareas cortas y cooperativas que necesitan cambiar de contexto frecuentemente. Sistemas de eventos, servidores de juegos en tiempo real, y simulaciones con muchas entidades son candidatos ideales:

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
Este patrón funciona bien con ULT porque cada conexión de jugador representa una tarea relativamente independiente que puede ceder el control voluntariamente en puntos bien definidos. El scheduler de usuario puede implementar políticas especializadas, como priorizar jugadores con mejor latencia o dar tiempo extra a sesiones importantes.

#### Usar KLT cuando necesitemos paralelismo real

Las aplicaciones que realizan cómputo intensivo y pueden dividirse en subtareas independientes deben usar KLT para aprovechar múltiples cores:
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
Aquí, cada hilo procesa una región diferente de la imagen de forma completamente independiente. Con KLT, el kernel puede asignar cada hilo a un core diferente, logrando speedup casi lineal (si hay suficientes cores disponibles). Con ULT, todos los hilos compartirían un solo core, negando cualquier beneficio de paralelismo.

#### Usar pool de hilos para controlar recursos

Los pools son especialmente valiosos en servidores que enfrentan carga variable e impredecible:
\begin{infobox}
Un servidor web puede recibir 10 requests por segundo durante horas, luego súbitamente enfrentar 10,000 requests por segundo cuando un artículo se vuelve viral. Sin un pool, el servidor intentaría crear 10,000 hilos simultáneos, agotando memoria y provocando thrashing. Con un pool de, digamos, 200 hilos, el servidor mantiene latencia predecible procesando requests en cola, degradando gracefully bajo carga extrema en lugar de colapsar.
\end{infobox}

## Problemas comunes y debugging
La programación multihilo introduce nuevas clases de errores que no existen en código secuencial. Entender estos problemas y sus soluciones es fundamental para escribir código correcto.

### Race conditions y datos compartidos

Una race condition ocurre cuando el resultado de un programa depende del timing específico de múltiples hilos. Consideremos un ejemplo clásico:
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
Este código parece correcto a primera vista, pero contiene un bug sutil y peligroso. El problema está en la secuencia LOAD-CHECK-STORE que no es atómica:

```
Estado inicial: account_balance = 1000

Timeline paralelo:
T=0:  Hilo 1 lee account_balance → current = 1000
T=1:  Hilo 2 lee account_balance → current = 1000
T=2:  Hilo 1 verifica: 1000 >= 800 ✓
T=3:  Hilo 2 verifica: 1000 >= 600 ✓
T=4:  Hilo 1 duerme (simulando procesamiento)
T=5:  Hilo 2 duerme (simulando procesamiento)
T=6:  Hilo 1 escribe: balance = 1000 - 800 = 200
T=7:  Hilo 2 escribe: balance = 1000 - 600 = 400

Resultado final: balance = 400 (¡el último en escribir gana!)
Correcto sería: rechazar el segundo retiro (fondos insuficientes)
```
\begin{warning}
Este tipo de bug es particularmente insidioso porque puede no manifestarse durante testing. Si los hilos ejecutan con timings ligeramente diferentes, el código funciona correctamente. El bug solo aparece con ciertos timings específicos, haciéndolo difícil de reproducir y diagnosticar. Esto es un Heisenbug: un error que cambia su comportamiento cuando intentas observarlo.
\end{warning}
La solución requiere hacer la secuencia completa CHECK-STORE atómica usando un mutex:

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
El mutex garantiza que solo un hilo puede ejecutar la sección crítica a la vez. Cuando un hilo llama `pthread_mutex_lock()`, adquiere el lock si está disponible, o se bloquea esperando si otro hilo lo posee. Solo cuando el hilo llama `pthread_mutex_unlock()` otro hilo puede entrar.

### Herramientas de debugging

Los errores de concurrencia son notoriamente difíciles de detectar con testing tradicional. Afortunadamente, existen herramientas especializadas:  

**ThreadSanitizer** es un detector de race conditions incluido en GCC y Clang. Instrumenta el código para rastrear todos los accesos a memoria y detectar patrones de acceso concurrente peligrosos:

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

ThreadSanitizer reporta exactamente qué líneas de código accedieron al mismo dato de forma no sincronizada, facilitando enormemente la localización del bug.  

**GDB** también soporta debugging multihilo. Podemos listar todos los hilos activos, cambiar entre ellos, y examinar el stack de cada uno:

```bash
gdb ./programa

(gdb) run
(gdb) info threads         # Listar todos los hilos
(gdb) thread 2             # Cambiar al hilo 2
(gdb) bt                   # Backtrace del hilo actual
(gdb) thread apply all bt  # Backtrace de todos los hilos
```
Esta última funcionalidad es invaluable para diagnosticar deadlocks, donde múltiples hilos están bloqueados esperándose mutuamente.

### Patterns de sincronización básicos

Algunos problemas de concurrencia aparecen tan frecuentemente que tienen soluciones establecidas. El patrón Producer-Consumer es fundamental:

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
Este patrón usa dos semáforos para coordinar productores y consumidores. El semáforo `empty` cuenta los espacios libres en el buffer, mientras `full` cuenta los items disponibles. Los productores esperan en `empty` antes de producir (asegurando hay espacio), luego señalan `full` después de producir (indicando hay un nuevo item). Los consumidores hacen lo opuesto.  

El `mutex buffer_mutex` protege el acceso al buffer compartido, garantizando que solo un hilo modifique las variables `in` y `out` a la vez. Esta combinación de semáforos (para coordinación) y mutex (para exclusión mutua) es un patrón ubicuo en programación concurrente.

## Tendencias y tecnologías modernas
El campo de la concurrencia continúa evolucionando. Lenguajes y sistemas modernos exploran nuevos modelos de programación que simplifican o evitan completamente algunos problemas tradicionales de hilos.

### Green threads y corrutinas

**Go** introdujo las goroutines, una implementación sofisticada del modelo M:N. Miles de goroutines (esencialmente ULT) se multiplexan sobre un número pequeño de threads OS usando un scheduler preemptive con work-stealing. El scheduler de Go puede migrar goroutines entre threads, balanceando carga automáticamente. Cada goroutine comienza con un stack de solo 2KB que crece dinámicamente si es necesario, permitiendo millones de goroutines concurrentes.  

**Rust** toma un enfoque diferente. En lugar de hilos, Rust promueve futures y async/await para concurrencia. Una función async retorna un future que representa computación pendiente. El runtime (como Tokio) ejecuta múltiples futures concurrentemente en un pool de threads, pero sin el overhead de context switch entre hilos. Crucialmente, el sistema de ownership de Rust previene race conditions en tiempo de compilación: el compilador rechaza código que podría causar data races.

\begin{theory}
Estos modelos representan un cambio filosófico. Los hilos tradicionales son preemptive: el scheduler puede suspenderlos en cualquier momento. Las goroutines y corrutinas son cooperativas en la superficie pero preemptive internamente: ceden el control en puntos bien definidos (llamadas a funciones async, operaciones de I/O), pero el runtime puede preemptarlas en esos puntos. Esto combina la eficiencia de la cooperación con las garantías de progreso de la preemption.
\end{theory}

### Thread affinity y NUMA

En sistemas con múltiples procesadores o muchos cores, mantener un hilo ejecutando en el mismo core puede mejorar dramáticamente el rendimiento. Esto se debe a la jerarquía de caches: cada core tiene caches L1 y L2 privadas que contienen los datos que el hilo usó recientemente. Si el scheduler migra el hilo a otro core, esas caches se pierden y deben reconstruirse.

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

La función `pthread_setaffinity_np()` restringe un hilo a ejecutar solo en cores específicos. Esto es especialmente importante en arquitecturas NUMA (Non-Uniform Memory Access), donde cada procesador tiene memoria local rápida y puede acceder memoria de otros procesadores más lentamente. Asignando hilos a cores específicos y asegurando que usen memoria local, podemos reducir la latencia de acceso a memoria significativamente.
\begin{infobox}
Las bases de datos modernas usan thread affinity agresivamente. Por ejemplo, PostgreSQL puede configurarse para dedicar cores específicos a diferentes tipos de trabajos: algunos cores manejan queries transaccionales cortos, otros manejan analíticas largas, y otros gestionan I/O y checkpointing. Esta segregación previene que cargas de trabajo diferentes compitan por recursos de cache.
\end{infobox}

## Síntesis y conexiones
Hemos recorrido un camino desde los conceptos fundamentales de hilos hasta implementaciones prácticas y desafíos reales. Es momento de consolidar las ideas clave y preparar el terreno para el siguiente capítulo.

### Puntos clave para evaluación

La distinción entre ULT y KLT no es meramente académica: representa diferentes trade-offs fundamentales en el diseño de sistemas. Los ULT ofrecen eficiencia extrema a costa de paralelismo, mientras los KLT sacrifican algo de eficiencia para ganar paralelismo real y mejor integración con el sistema operativo. El modelo M:N intenta lo mejor de ambos mundos pero añade complejidad significativa.
La problemática de planificación mixta, ilustrada en nuestro ejercicio detallado, revela cómo los hilos ULT están fundamentalmente limitados por el quantum asignado a su KLT contenedor. Este constraint debe considerarse cuidadosamente al diseñar sistemas que mezclan ambos tipos de hilos.
Las APIs de pthreads proporcionan los building blocks para programación concurrente, pero usar estos bloques correctamente requiere entender profundamente el modelo de memoria compartida y los peligros de las race conditions. El ciclo completo `create -> join/detach` y la gestión cuidadosa de la sincronización no son opcionales sino absolutamente esenciales para código correcto.

### Errores conceptuales frecuentes

Algunas misconcepciones comunes pueden llevar a diseños fundamentalmente incorrectos:
\begin{warning}
\textit{Más hilos siempre significa mejor rendimiento:} Falso. Cada hilo adicional añade overhead de context switch y competencia por recursos compartidos. Más allá de cierto punto (típicamente relacionado con el número de cores disponibles), agregar hilos degrada el rendimiento debido a thrashing y contention.
\end{warning}
\begin{warning}
\textit{Las variables locales son automáticamente thread-safe}: Solo parcialmente cierto. Las variables locales en el stack son privadas de cada hilo, pero si un hilo pasa un puntero a su variable local a otro hilo (o almacena el puntero en una estructura compartida), esa variable se vuelve compartida y requiere sincronización.
\end{warning}
\begin{warning}
\textit{Los ULT son más simples que los KLT}: Paradójicamente falso. Aunque el context switch ULT es más simple, implementar un scheduler completo de ULT con todas sus estructuras de datos y políticas es significativamente más complejo que usar la API de pthreads que delega la complejidad al kernel.
\end{warning}

### Preparación para próximos capítulos

Los hilos introducen la necesidad crítica de sincronización. Hemos visto glimpses de esta problemática con nuestro ejemplo de race condition en retiros bancarios, pero apenas rasguñamos la superficie. El siguiente capítulo explorará sistemáticamente los mecanismos que permiten a hilos coordinarse de forma segura y eficiente.  

Veremos mutexes para exclusión mutua, permitiendo que solo un hilo acceda a una sección crítica a la vez. Exploraremos semáforos, una primitiva más general que puede resolver problemas de sincronización complejos. Las condition variables nos permitirán implementar espera eficiente sin busy-waiting. Y los read-write locks optimizarán el caso común donde múltiples hilos pueden leer simultáneamente pero las escrituras requieren acceso exclusivo.

```c
// Problema que veremos en el próximo capítulo
pthread_mutex_t resource_mutex;
pthread_cond_t resource_available;
int shared_resource_count = 0;

// ¿Cómo coordinamos múltiples hilos que compiten por recursos limitados?
// ¿Cómo evitamos deadlock cuando un hilo necesita múltiples recursos?
// ¿Cómo implementamos fairness entre hilos productores y consumidores?
```
También enfrentaremos problemas clásicos de concurrencia como el productor-consumidor con buffer limitado, lectores-escritores con diferentes políticas de prioridad, y el famoso problema de los filósofos comensales que ilustra deadlock y su prevención. Estos problemas no son meramente ejercicios académicos: representan patrones que aparecen constantemente en sistemas reales.

### Laboratorio propuesto

Para consolidar tu comprensión, considera estas prácticas:  

**Práctica 1: Benchmark ULT vs KLT** - Implementa una simulación simple de ULT usando `setjmp/longjmp` y compárala con pthreads. Mide context switches por segundo variando el trabajo realizado en cada switch. Grafica cómo el overhead relativo cambia con diferentes duraciones de quantum.  

**Práctica 2: Pool de hilos configurable** - Extiende nuestro ejemplo de pool para que pueda manejar diferentes tipos de tareas con prioridades. Implementa métricas como latencia promedio de procesamiento, utilización de hilos, y tamaño de cola. Experimenta con diferentes tamaños de pool bajo cargas variables.  

**Práctica 3: Simulador de planificación mixta** - Crea un simulador que reproduzca ejercicios como nuestro Gantt chart. Permite configurar procesos con diferentes números de KLT y ULT, schedulers internos (FIFO, Round Robin), y operaciones de I/O. Visualiza la ejecución y calcula métricas automáticamente.  

La comprensión profunda de los hilos es fundamental para el diseño de sistemas concurrentes eficientes. En aplicaciones modernas, la elección correcta entre ULT, KLT o modelos híbridos, junto con una arquitectura de pool bien diseñada, puede determinar la diferencia entre un sistema que escala gracefully y uno que colapsa bajo carga. Armado con este conocimiento, estás preparado para explorar los mecanismos de sincronización que hacen posible la coordinación segura entre hilos.