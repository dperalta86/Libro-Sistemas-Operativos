# Sincronización

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Identificar problemas de concurrencia: race conditions, deadlock, starvation
- Explicar qué son las operaciones atómicas y por qué son necesarias
- Comprender las condiciones de Bernstein para la ejecución concurrente
- Analizar soluciones de sincronización a nivel software y hardware
- Implementar soluciones usando mutex, semáforos y variables de condición
- Resolver problemas clásicos: Productor-Consumidor, Lectores-Escritores
- Aplicar sincronización en escenarios reales usando analogías cotidianas
- Analizar y prevenir deadlocks usando técnicas formales
- Programar soluciones thread-safe en C usando pthreads
- Evaluar el overhead de diferentes primitivas de sincronización

## Introducción y Contexto

### ¿Por qué necesitamos sincronización?

Imaginemos un supermercado en hora pico:

**Sin coordinación:**
- **20 cajas** funcionando independientemente
- **1 empleado** que debe ordenar las filas, pero puede estar en cualquier lugar
- **1 sistema de promociones** que solo permite una aplicación a la vez
- **Clientes** que llegan aleatoriamente y eligen cajas

**¿Qué problemas pueden ocurrir?**

1. **Race condition**: Dos cajeros intentan usar el sistema de promociones simultáneamente → se corrompe la base de datos
2. **Starvation**: Una caja siempre tiene fila larga porque el empleado nunca la atiende
3. **Deadlock**: El empleado espera que se libere una caja para ordenarla, pero el cajero espera que el empleado termine de ordenar para continuar
4. **Inconsistencia**: El contador total de ventas se pierde cuando dos cajas lo actualizan al mismo tiempo

### La analogía completa del supermercado

```
RECURSOS DEL SUPERMERCADO (Variables compartidas):
- Cajas registradoras (20)     ← Array de recursos limitados
- Sistema de promociones (1)    ← Recurso exclusivo mutuo
- Empleado ordenador (1)       ← Recurso único móvil
- Contador total de ventas     ← Variable compartida crítica
- Cola de clientes por caja    ← Buffer productor-consumidor

PROCESOS/HILOS:
- Cajeros (threads)            ← Acceden a recursos concurrentemente
- Clientes (threads)           ← Productores de trabajo
- Sistema de facturación       ← Consumidor de transacciones
- Empleado (thread especial)   ← Administrador de recursos
```

## El Problema Fundamental: Race Conditions

Una **race condition** ocurre cuando el resultado depende del orden de ejecución de operaciones concurrentes sobre datos compartidos.

**Ejemplo concreto:**
```c
// Dos cajeros actualizando ventas totales
int ventas_totales = 0;

// Cajero 1                    // Cajero 2
ventas_totales += 100;        ventas_totales += 200;
```

**En assembly:**
```assembly
; Cajero 1                    ; Cajero 2
LOAD R1, [ventas_totales]     LOAD R2, [ventas_totales]
ADD  R1, 100                  ADD  R2, 200
STORE [ventas_totales], R1    STORE [ventas_totales], R2
```

**Posibles resultados:**
- **Correcto**: ventas_totales = 300
- **Incorrecto**: ventas_totales = 100 (se perdió la venta del cajero 2)
- **Incorrecto**: ventas_totales = 200 (se perdió la venta del cajero 1)

## Sección Crítica y Condiciones de Bernstein

### Sección Crítica

**Definición**: Porción de código que accede a recursos compartidos y debe ejecutarse atómicamente (sin interrupciones).

**Estructura general:**
```c
do {
    // Protocolo de entrada
    entrada_seccion_critica();
    
    // SECCIÓN CRÍTICA
    // Acceso a recursos compartidos
    
    // Protocolo de salida  
    salida_seccion_critica();
    
    // Sección no crítica
    hacer_trabajo_local();
    
} while (true);
```

**Requisitos para la solución:**

1. **Exclusión Mutua**: Solo un proceso en sección crítica a la vez
2. **Progreso**: Si nadie está en sección crítica, alguien debe poder entrar
3. **Espera Acotada**: Un proceso no puede esperar indefinidamente
4. **Sin Asumir Velocidades**: No depender de velocidades relativas de procesos

### Condiciones de Bernstein

Para que dos procesos puedan ejecutarse concurrentemente de manera segura, deben cumplirse las **Condiciones de Bernstein**:

Sean P₁ y P₂ dos procesos con:
- **R₁, R₂**: Conjuntos de variables que leen
- **W₁, W₂**: Conjuntos de variables que escriben

**Condiciones necesarias:**
1. **R₁ ∩ W₂ = ∅** (P₁ no lee lo que P₂ escribe)
2. **W₁ ∩ R₂ = ∅** (P₁ no escribe lo que P₂ lee)  
3. **W₁ ∩ W₂ = ∅** (P₁ y P₂ no escriben las mismas variables)

**Ejemplo de violación:**
```c
// Proceso 1: R₁ = {x}, W₁ = {y}
y = x + 10;

// Proceso 2: R₂ = {y}, W₂ = {x}
x = y * 2;
```

**Violaciones:**
- W₁ ∩ R₂ = {y} ≠ ∅ (P₁ escribe y, P₂ lee y)
- R₁ ∩ W₂ = {x} ≠ ∅ (P₁ lee x, P₂ escribe x)

Por tanto, **NO pueden ejecutarse concurrentemente** sin sincronización.

## Soluciones a Nivel Software

### Evolución Histórica de las Soluciones

#### Primeras Aproximaciones: Variables de Control

**Intento 1: Turno Simple**
```c
int turno = 1;

// Proceso 1
while (turno != 1);
// Sección crítica
turno = 2;

// Proceso 2  
while (turno != 2);
// Sección crítica
turno = 1;
```

**Problema**: Viola la condición de **progreso**. Si un proceso no quiere entrar, el otro queda bloqueado permanentemente.

**Intento 2: Flags Independientes**
```c
bool flag[2] = {false, false};

// Proceso i
flag[i] = true;
while (flag[j]);  // j = 1-i
// Sección crítica
flag[i] = false;
```

**Problema**: **Race condition** en el chequeo de flags. Ambos pueden ver flag[j] = false al mismo tiempo y entrar juntos.

**Intento 3: Flags con Cortesía**
```c
bool flag[2] = {false, false};

// Proceso i
flag[i] = true;
while (flag[j]) {
    flag[i] = false;
    // Esperar tiempo aleatorio
    flag[i] = true;
}
// Sección crítica
flag[i] = false;
```

**Problema**: Posible **livelock** - ambos procesos pueden quedar cediendo indefinidamente.

### Solución de Peterson (1981)

**La primera solución correcta para 2 procesos:**

```c
bool flag[2] = {false, false};
int turn = 0;

// Proceso i (donde j = 1-i)
void peterson_enter(int i) {
    flag[i] = true;      // Mostrar interés
    turn = j;            // Ceder el turno al otro
    while (flag[j] && turn == j);  // Esperar si el otro está interesado y tiene turno
}

void peterson_exit(int i) {
    flag[i] = false;     // No tengo más interés
}

// Uso completo
void proceso_i() {
    while (true) {
        peterson_enter(i);
        
        // SECCIÓN CRÍTICA
        seccion_critica();
        
        peterson_exit(i);
        
        // Sección no crítica
        seccion_no_critica();
    }
}
```

**¿Por qué funciona Peterson?**

1. **Exclusión Mutua**: Si ambos procesos están en while, uno tiene turn = i y el otro turn = j. Como turn es única, solo uno puede tener turn ≠ j.

2. **Progreso**: Si nadie quiere entrar (flag[j] = false), el proceso entra inmediatamente.

3. **Espera Acotada**: El proceso que llegó segundo pone turn = j, garantizando que el primero entre primero.

**Limitaciones de Peterson:**
- Solo funciona para **2 procesos**
- Requiere **busy waiting** (uso intensivo de CPU)
- Asume **orden secuencial de memoria** (problemas en CPUs modernas)

## Soluciones a Nivel Hardware

### Primitivos Atómicos

**Operación Atómica**: Ejecución indivisible, sin interrupciones posibles.

#### Test-and-Set (Hardware)
```c
// Implementada en hardware - ATÓMICA
bool test_and_set(bool* target) {
    bool old_value = *target;
    *target = true;
    return old_value;
}

// Uso para mutex
bool lock = false;  // false = libre, true = ocupado

void acquire_lock() {
    while (test_and_set(&lock)) {
        // Busy waiting (spin lock)
        // Continuar intentando hasta obtener el lock
    }
}

void release_lock() {
    lock = false;
}
```

**Ventajas:**
- Simple de implementar
- Funciona para N procesos
- Garantiza exclusión mutua

**Desventajas:**
- Busy waiting (desperdicia CPU)
- No garantiza espera acotada
- Puede causar starvation

#### Compare-and-Swap (CAS)

```c
// Más flexible que test-and-set
bool compare_and_swap(int* ptr, int expected, int new_value) {
    if (*ptr == expected) {
        *ptr = new_value;
        return true;
    }
    return false;
}

// Implementar contador atómico
void atomic_increment(int* counter) {
    int old_value, new_value;
    do {
        old_value = *counter;
        new_value = old_value + 1;
    } while (!compare_and_swap(counter, old_value, new_value));
}
```

#### Fetch-and-Add
```c
// Retorna valor anterior y suma atomicamente
int fetch_and_add(int* ptr, int value) {
    int old_value = *ptr;
    *ptr += value;
    return old_value;
}

// Implementar ticket lock (espera acotada)
typedef struct {
    int ticket;
    int turn;
} ticket_lock_t;

void ticket_acquire(ticket_lock_t* lock) {
    int my_ticket = fetch_and_add(&lock->ticket, 1);
    while (lock->turn != my_ticket);  // Esperar mi turno
}

void ticket_release(ticket_lock_t* lock) {
    lock->turn++;  // Dar turno al siguiente
}
```

## Soluciones del Sistema Operativo: Semáforos

### Definición y Operaciones

**Semáforo**: Inventado por **Dijkstra (1965)**, es un contador entero no negativo con dos operaciones atómicas.

```c
typedef struct {
    int value;
    queue_t waiting_queue;
} semaphore_t;

// P() o wait() - Decrementar y posiblemente bloquear
void sem_wait(semaphore_t* sem) {
    sem->value--;
    if (sem->value < 0) {
        // Bloquear proceso y agregarlo a la cola
        add_to_queue(&sem->waiting_queue, current_process);
        block_current_process();
    }
}

// V() o signal() - Incrementar y despertar
void sem_post(semaphore_t* sem) {
    sem->value++;
    if (sem->value <= 0) {
        // Hay procesos esperando, despertar uno
        process_t* p = remove_from_queue(&sem->waiting_queue);
        wakeup_process(p);
    }
}
```

### Tipos de Semáforos

#### Semáforo Binario (Mutex)

**Valores posibles**: 0 o 1
- **1**: Recurso disponible
- **0**: Recurso ocupado

```c
semaphore_t mutex;
sem_init(&mutex, 1);  // Inicializar en 1 (disponible)

void critical_section() {
    sem_wait(&mutex);   // P(mutex) - Obtener exclusión mutua
    
    // SECCIÓN CRÍTICA
    // Solo un proceso puede estar aquí
    
    sem_post(&mutex);   // V(mutex) - Liberar exclusión mutua
}
```

#### Semáforo Contador

**Valores posibles**: 0 a N
- **N**: Máximo número de recursos disponibles
- **0**: Todos los recursos ocupados

```c
#define POOL_SIZE 5
semaphore_t connection_pool;
sem_init(&connection_pool, POOL_SIZE);

void use_connection() {
    sem_wait(&connection_pool);  // Obtener conexión
    
    // Usar conexión de base de datos
    execute_query();
    
    sem_post(&connection_pool);  // Liberar conexión
}
```

### Usos Principales de Semáforos

#### Exclusión Mutua
```c
semaphore_t mutex = 1;

void proceso() {
    sem_wait(&mutex);    // Entrar a sección crítica
    // Sección crítica
    sem_post(&mutex);    // Salir de sección crítica
}
```

#### Limitar Acceso a N Instancias
```c
semaphore_t recursos = N;

void usar_recurso() {
    sem_wait(&recursos);  // Obtener uno de N recursos
    // Usar recurso
    sem_post(&recursos);  // Liberar recurso
}
```

#### Ordenar Ejecución (Sincronización)
```c
semaphore_t sincronizacion = 0;

void proceso_A() {
    // Hacer trabajo A
    trabajo_A();
    sem_post(&sincronizacion);  // Señalar que A terminó
}

void proceso_B() {
    sem_wait(&sincronizacion);  // Esperar que A termine
    // Hacer trabajo B (que depende de A)
    trabajo_B();
}
```

#### Problema Productor-Consumidor
```c
#define BUFFER_SIZE 10

semaphore_t empty = BUFFER_SIZE;    // Espacios vacíos
semaphore_t full = 0;               // Elementos llenos  
semaphore_t mutex = 1;              // Exclusión mutua

void productor() {
    while (true) {
        // Producir elemento
        item = produce_item();
        
        sem_wait(&empty);    // Esperar espacio vacío
        sem_wait(&mutex);    // Obtener acceso al buffer
        
        add_to_buffer(item); // Agregar al buffer
        
        sem_post(&mutex);    // Liberar acceso al buffer
        sem_post(&full);     // Señalar elemento disponible
    }
}

void consumidor() {
    while (true) {
        sem_wait(&full);     // Esperar elemento disponible
        sem_wait(&mutex);    // Obtener acceso al buffer
        
        item = remove_from_buffer();  // Quitar del buffer
        
        sem_post(&mutex);    // Liberar acceso al buffer
        sem_post(&empty);    // Señalar espacio vacío
        
        consume_item(item);  // Consumir elemento
    }
}
```

## Ejemplo Práctico: Control de Cochera

### Planteamiento del Problema

Una cochera tiene:
- **20 espacios** para autos
- **1 entrada** (con barrera)
- **2 salidas** (con barreras)
- **Sistema de control** que debe llevar cuenta de espacios ocupados

**Requerimientos:**
1. No permitir entrada si cochera está llena
2. Controlar acceso exclusivo a entrada y salidas
3. Mantener contador preciso de autos
4. Evitar deadlock entre entrada y salidas

### Solución con Semáforos

```c
#include <stdio.h>
#include <semaphore.h>
#include <pthread.h>

#define CAPACIDAD_COCHERA 20
#define NUM_AUTOS 100

typedef struct {
    // Semáforo contador para espacios disponibles
    sem_t espacios_disponibles;
    
    // Mutex para acceso exclusivo a entrada
    sem_t mutex_entrada;
    
    // Mutex para acceso exclusivo a cada salida
    sem_t mutex_salida1;
    sem_t mutex_salida2;
    
    // Mutex para el contador global
    sem_t mutex_contador;
    
    // Estado de la cochera
    int autos_dentro;
    int total_entradas;
    int total_salidas;
    
} cochera_t;

cochera_t cochera;

void inicializar_cochera() {
    // Inicializar semáforos
    sem_init(&cochera.espacios_disponibles, 0, CAPACIDAD_COCHERA);
    sem_init(&cochera.mutex_entrada, 0, 1);
    sem_init(&cochera.mutex_salida1, 0, 1);
    sem_init(&cochera.mutex_salida2, 0, 1);
    sem_init(&cochera.mutex_contador, 0, 1);
    
    // Inicializar estado
    cochera.autos_dentro = 0;
    cochera.total_entradas = 0;
    cochera.total_salidas = 0;
    
    printf("🏢 Cochera inicializada: %d espacios disponibles\n", CAPACIDAD_COCHERA);
}

void* auto_entrando(void* arg) {
    int auto_id = *(int*)arg;
    
    printf("🚗 Auto %d llegó a la cochera\n", auto_id);
    
    // 1. Verificar si hay espacio disponible
    printf("⏳ Auto %d esperando espacio...\n", auto_id);
    sem_wait(&cochera.espacios_disponibles);  // Bloquea si cochera llena
    
    // 2. Hay espacio garantizado, obtener acceso exclusivo a entrada
    printf("🚪 Auto %d esperando acceso a entrada...\n", auto_id);
    sem_wait(&cochera.mutex_entrada);
    
    // 3. SECCIÓN CRÍTICA: Procesar entrada
    printf("✅ Auto %d entrando a cochera\n", auto_id);
    
    // Simular tiempo de entrada (abrir barrera, validar ticket, etc.)
    sleep(1);
    
    // Actualizar contador global de manera thread-safe
    sem_wait(&cochera.mutex_contador);
    cochera.autos_dentro++;
    cochera.total_entradas++;
    printf("📊 Auto %d dentro. Total en cochera: %d/%d\n", 
           auto_id, cochera.autos_dentro, CAPACIDAD_COCHERA);
    sem_post(&cochera.mutex_contador);
    
    // 4. Liberar acceso a entrada
    sem_post(&cochera.mutex_entrada);
    
    printf("🅿️ Auto %d estacionado exitosamente\n", auto_id);
    
    // Simular tiempo estacionado
    sleep(2 + (rand() % 5));  // 2-6 segundos estacionado
    
    // Ahora el auto quiere salir
    return NULL;
}

void* auto_saliendo(void* arg) {
    int auto_id = *(int*)arg;
    
    printf("🚗 Auto %d quiere salir\n", auto_id);
    
    // Elegir salida aleatoriamente (load balancing simple)
    int salida = (rand() % 2) + 1;
    sem_t* mutex_salida = (salida == 1) ? &cochera.mutex_salida1 : &cochera.mutex_salida2;
    
    // 1. Obtener acceso exclusivo a la salida elegida
    printf("🚪 Auto %d esperando acceso a salida %d...\n", auto_id, salida);
    sem_wait(mutex_salida);
    
    // 2. SECCIÓN CRÍTICA: Procesar salida
    printf("🚦 Auto %d saliendo por salida %d\n", auto_id, salida);
    
    // Simular tiempo de salida (validar pago, abrir barrera, etc.)
    sleep(1);
    
    // Actualizar contador global
    sem_wait(&cochera.mutex_contador);
    cochera.autos_dentro--;
    cochera.total_salidas++;
    printf("📊 Auto %d salió. Total en cochera: %d/%d\n", 
           auto_id, cochera.autos_dentro, CAPACIDAD_COCHERA);
    sem_post(&cochera.mutex_contador);
    
    // 3. Liberar acceso a salida
    sem_post(mutex_salida);
    
    // 4. IMPORTANTE: Señalar que hay un espacio más disponible
    sem_post(&cochera.espacios_disponibles);
    
    printf("👋 Auto %d salió exitosamente por salida %d\n", auto_id, salida);
    
    return NULL;
}

void mostrar_estadisticas() {
    sem_wait(&cochera.mutex_contador);
    
    printf("\n📈 ESTADÍSTICAS DE LA COCHERA:\n");
    printf("   - Autos dentro: %d/%d\n", cochera.autos_dentro, CAPACIDAD_COCHERA);
    printf("   - Total entradas: %d\n", cochera.total_entradas);
    printf("   - Total salidas: %d\n", cochera.total_salidas);
    printf("   - Espacios libres: %d\n", CAPACIDAD_COCHERA - cochera.autos_dentro);
    
    sem_post(&cochera.mutex_contador);
}

int main() {
    pthread_t hilos_entrada[NUM_AUTOS];
    pthread_t hilos_salida[NUM_AUTOS];
    int auto_ids[NUM_AUTOS];
    
    // Inicializar sistema
    inicializar_cochera();
    srand(time(NULL));
    
    printf("🚦 Iniciando simulación: %d autos intentarán usar la cochera\n\n", NUM_AUTOS);
    
    // Crear hilos de entrada
    for (int i = 0; i < NUM_AUTOS; i++) {
        auto_ids[i] = i + 1;
        pthread_create(&hilos_entrada[i], NULL, auto_entrando, &auto_ids[i]);
        
        // Espaciar llegadas aleatoriamente
        usleep(50000 + (rand() % 100000));  // 50-150ms entre llegadas
    }
    
    // Crear hilos de salida con delay
    sleep(3);  // Esperar que algunos autos entren primero
    
    for (int i = 0; i < NUM_AUTOS; i++) {
        pthread_create(&hilos_salida[i], NULL, auto_saliendo, &auto_ids[i]);
        usleep(100000 + (rand() % 200000));  // 100-300ms entre salidas
    }
    
    // Mostrar estadísticas periódicamente
    for (int i = 0; i < 10; i++) {
        sleep(2);
        mostrar_estadisticas();
    }
    
    // Esperar que todos terminen
    for (int i = 0; i < NUM_AUTOS; i++) {
        pthread_join(hilos_entrada[i], NULL);
        pthread_join(hilos_salida[i], NULL);
    }
    
    printf("\n🏁 Simulación terminada\n");
    mostrar_estadisticas();
    
    // Cleanup
    sem_destroy(&cochera.espacios_disponibles);
    sem_destroy(&cochera.mutex_entrada);
    sem_destroy(&cochera.mutex_salida1);
    sem_destroy(&cochera.mutex_salida2);
    sem_destroy(&cochera.mutex_contador);
    
    return 0;
}
```

## Uso de Arrays de Semáforos

### Problema: Múltiples Recursos del Mismo Tipo

Consideremos un servidor web con **pool de workers**:
- 10 threads worker disponibles
- Cada request necesita exactamente 1 worker
- Algunos requests requieren workers específicos (por expertise)

```c
#define NUM_WORKERS 10
#define NUM_REQUESTS 50

typedef enum {
    WORKER_GENERAL = 0,
    WORKER_DATABASE = 1,
    WORKER_IMAGE = 2,
    WORKER_API = 3
} worker_type_t;

typedef struct {
    sem_t workers[4];          // Array de semáforos por tipo
    pthread_mutex_t worker_mutex[NUM_WORKERS];  // Mutex individual por worker
    worker_type_t worker_types[NUM_WORKERS];    // Tipo de cada worker
    bool worker_busy[NUM_WORKERS];              // Estado de cada worker
} server_pool_t;

server_pool_t server;

void inicializar_server() {
    // Distribuir workers por tipo
    int workers_por_tipo[] = {4, 3, 2, 1};  // General, DB, Image, API
    
    for (int tipo = 0; tipo < 4; tipo++) {
        sem_init(&server.workers[tipo], 0, workers_por_tipo[tipo]);
    }
    
    // Inicializar workers individuales
    int worker_idx = 0;
    for (int tipo = 0; tipo < 4; tipo++) {
        for (int i = 0; i < workers_por_tipo[tipo]; i++) {
            pthread_mutex_init(&server.worker_mutex[worker_idx], NULL);
            server.worker_types[worker_idx] = tipo;
            server.worker_busy[worker_idx] = false;
            worker_idx++;
        }
    }
}

int obtener_worker(worker_type_t tipo_requerido) {
    // 1. Esperar worker del tipo requerido
    sem_wait(&server.workers[tipo_requerido]);
    
    // 2. Encontrar worker específico de ese tipo
    for (int i = 0; i < NUM_WORKERS; i++) {
        if (server.worker_types[i] == tipo_requerido) {
            if (pthread_mutex_trylock(&server.worker_mutex[i]) == 0) {
                if (!server.worker_busy[i]) {
                    server.worker_busy[i] = true;
                    return i;  // Worker encontrado y reservado
                }
                pthread_mutex_unlock(&server.worker_mutex[i]);
            }
        }
    }
    
    // No debería llegar aquí si los semáforos están bien sincronizados
    return -1;
}

void liberar_worker(int worker_id) {
    pthread_mutex_lock(&server.worker_mutex[worker_id]);
    
    server.worker_busy[worker_id] = false;
    worker_type_t tipo = server.worker_types[worker_id];
    
    pthread_mutex_unlock(&server.worker_mutex[worker_id]);
    
    // Señalar que hay un worker más de este tipo disponible
    sem_post(&server.workers[tipo]);
}

void* procesar_request(void* arg) {
    int request_id = *(int*)arg;
    worker_type_t tipo_necesario = rand() % 4;  // Request aleatorio
    
    printf("📥 Request %d necesita worker tipo %d\n", request_id, tipo_necesario);
    
    // Obtener worker
    int worker_id = obtener_worker(tipo_necesario);
    if (worker_id == -1) {
        printf("❌ Request %d: Error obteniendo worker\n", request_id);
        return NULL;
    }
    
    printf("⚡ Request %d asignado a worker %d (tipo %d)\n", 
           request_id, worker_id, tipo_necesario);
    
    // Simular procesamiento
    sleep(1 + (rand() % 3));
    
    // Liberar worker
    liberar_worker(worker_id);
    
    printf("✅ Request %d completado por worker %d\n", request_id, worker_id);
    
    return NULL;
}
```


### Problema Clásico: Productor-Consumidor

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>

#define BUFFER_SIZE 5
#define NUM_ITEMS 20

typedef struct {
    int buffer[BUFFER_SIZE];     // Buffer circular
    int in;                      // Índice de inserción
    int out;                     // Índice de extracción
    
    sem_t empty;                 // Espacios vacíos disponibles
    sem_t full;                  // Elementos disponibles para consumir
    pthread_mutex_t mutex;       // Exclusión mutua para buffer
    
    int items_produced;          // Estadísticas
    int items_consumed;
} buffer_t;

buffer_t shared_buffer;

void init_buffer() {
    shared_buffer.in = 0;
    shared_buffer.out = 0;
    shared_buffer.items_produced = 0;
    shared_buffer.items_consumed = 0;
    
    // empty inicia con BUFFER_SIZE (todos los espacios están vacíos)
    sem_init(&shared_buffer.empty, 0, BUFFER_SIZE);
    
    // full inicia con 0 (no hay elementos para consumir)
    sem_init(&shared_buffer.full, 0, 0);
    
    pthread_mutex_init(&shared_buffer.mutex, NULL);
    
    printf("📦 Buffer inicializado (tamaño: %d)\n", BUFFER_SIZE);
}

void* productor(void* arg) {
    int prod_id = *(int*)arg;
    
    for (int i = 0; i < NUM_ITEMS; i++) {
        // Producir elemento
        int item = (prod_id * 100) + i;
        
        printf("🏭 Productor %d creó item %d\n", prod_id, item);
        
        // PASO 1: Esperar espacio vacío
        printf("⏳ Productor %d esperando espacio...\n", prod_id);
        sem_wait(&shared_buffer.empty);
        
        // PASO 2: Obtener exclusión mutua sobre buffer
        pthread_mutex_lock(&shared_buffer.mutex);
        
        // PASO 3: SECCIÓN CRÍTICA - Insertar en buffer
        shared_buffer.buffer[shared_buffer.in] = item;
        printf("📥 Item %d insertado en posición %d\n", 
               item, shared_buffer.in);
        
        shared_buffer.in = (shared_buffer.in + 1) % BUFFER_SIZE;
        shared_buffer.items_produced++;
        
        // PASO 4: Liberar exclusión mutua
        pthread_mutex_unlock(&shared_buffer.mutex);
        
        // PASO 5: Señalar elemento disponible
        sem_post(&shared_buffer.full);
        
        // Simular tiempo de producción
        usleep(200000 + (rand() % 300000));  // 200-500ms
    }
    
    printf("✅ Productor %d terminó\n", prod_id);
    return NULL;
}

void* consumidor(void* arg) {
    int cons_id = *(int*)arg;
    
    for (int i = 0; i < NUM_ITEMS; i++) {
        // PASO 1: Esperar elemento disponible
        printf("⏳ Consumidor %d esperando elemento...\n", cons_id);
        sem_wait(&shared_buffer.full);
        
        // PASO 2: Obtener exclusión mutua sobre buffer
        pthread_mutex_lock(&shared_buffer.mutex);
        
        // PASO 3: SECCIÓN CRÍTICA - Extraer del buffer
        int item = shared_buffer.buffer[shared_buffer.out];
        printf("📤 Item %d extraído de posición %d por consumidor %d\n", 
               item, shared_buffer.out, cons_id);
        
        shared_buffer.out = (shared_buffer.out + 1) % BUFFER_SIZE;
        shared_buffer.items_consumed++;
        
        // PASO 4: Liberar exclusión mutua
        pthread_mutex_unlock(&shared_buffer.mutex);
        
        // PASO 5: Señalar espacio vacío
        sem_post(&shared_buffer.empty);
        
        // Consumir elemento
        printf("🔄 Consumidor %d procesando item %d\n", cons_id, item);
        usleep(300000 + (rand() % 400000));  // 300-700ms
    }
    
    printf("✅ Consumidor %d terminó\n", cons_id);
    return NULL;
}

void mostrar_estado_buffer() {
    pthread_mutex_lock(&shared_buffer.mutex);
    
    printf("\n📊 ESTADO DEL BUFFER:\n");
    printf("   Producidos: %d | Consumidos: %d\n",
           shared_buffer.items_produced, shared_buffer.items_consumed);
    
    // Mostrar contenido actual
    printf("   Buffer: [");
    for (int i = 0; i < BUFFER_SIZE; i++) {
        if (i >= shared_buffer.out && i < shared_buffer.in) {
            printf("%d", shared_buffer.buffer[i]);
        } else {
            printf("_");
        }
        if (i < BUFFER_SIZE - 1) printf(", ");
    }
    printf("]\n");
    printf("   IN=%d, OUT=%d\n", shared_buffer.in, shared_buffer.out);
    
    pthread_mutex_unlock(&shared_buffer.mutex);
}

int main() {
    pthread_t prod_thread, cons_thread;
    int prod_id = 1, cons_id = 1;
    
    init_buffer();
    srand(time(NULL));
    
    printf("🚀 Iniciando Productor-Consumidor\n\n");
    
    // Crear threads
    pthread_create(&prod_thread, NULL, productor, &prod_id);
    pthread_create(&cons_thread, NULL, consumidor, &cons_id);
    
    // Monitor periódico
    for (int i = 0; i < 10; i++) {
        sleep(2);
        mostrar_estado_buffer();
    }
    
    // Esperar terminación
    pthread_join(prod_thread, NULL);
    pthread_join(cons_thread, NULL);
    
    printf("\n🏁 Simulación terminada\n");
    mostrar_estado_buffer();
    
    // Cleanup
    sem_destroy(&shared_buffer.empty);
    sem_destroy(&shared_buffer.full);
    pthread_mutex_destroy(&shared_buffer.mutex);
    
    return 0;
}
```

### Problema Lectores-Escritores

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>

typedef struct {
    // Datos compartidos
    int shared_data;
    
    // Control de acceso
    pthread_mutex_t mutex;       // Proteger reader_count
    sem_t write_lock;           // Escritores exclusivos
    
    // Estadísticas
    int reader_count;           // Lectores activos
    int total_reads;            // Total operaciones de lectura
    int total_writes;           // Total operaciones de escritura
    
} shared_resource_t;

shared_resource_t resource;

void init_resource() {
    resource.shared_data = 0;
    resource.reader_count = 0;
    resource.total_reads = 0;
    resource.total_writes = 0;
    
    pthread_mutex_init(&resource.mutex, NULL);
    sem_init(&resource.write_lock, 0, 1);  // Un escritor a la vez
    
    printf("📚 Recurso compartido inicializado\n");
}

void* lector(void* arg) {
    int reader_id = *(int*)arg;
    
    for (int i = 0; i < 5; i++) {
        printf("👁️ Lector %d quiere leer\n", reader_id);
        
        // PROTOCOLO DE ENTRADA - LECTORES
        pthread_mutex_lock(&resource.mutex);
        
        resource.reader_count++;
        
        // El primer lector bloquea escritores
        if (resource.reader_count == 1) {
            printf("🚫 Primer lector %d bloqueando escritores\n", reader_id);
            sem_wait(&resource.write_lock);
        }
        
        pthread_mutex_unlock(&resource.mutex);
        
        // SECCIÓN CRÍTICA - LECTURA
        printf("📖 Lector %d leyendo: valor = %d\n", 
               reader_id, resource.shared_data);
        resource.total_reads++;
        
        // Simular tiempo de lectura
        usleep(100000 + (rand() % 200000));  // 100-300ms
        
        // PROTOCOLO DE SALIDA - LECTORES
        pthread_mutex_lock(&resource.mutex);
        
        resource.reader_count--;
        
        // El último lector desbloquea escritores
        if (resource.reader_count == 0) {
            printf("✅ Último lector %d desbloqueando escritores\n", reader_id);
            sem_post(&resource.write_lock);
        }
        
        pthread_mutex_unlock(&resource.mutex);
        
        printf("👁️ Lector %d terminó lectura %d\n", reader_id, i + 1);
        
        // Tiempo entre lecturas
        usleep(500000 + (rand() % 1000000));  // 0.5-1.5s
    }
    
    printf("✅ Lector %d terminó todas las lecturas\n", reader_id);
    return NULL;
}

void* escritor(void* arg) {
    int writer_id = *(int*)arg;
    
    for (int i = 0; i < 3; i++) {
        printf("✏️ Escritor %d quiere escribir\n", writer_id);
        
        // PROTOCOLO DE ENTRADA - ESCRITORES
        // Esperar acceso exclusivo (bloquea otros escritores y lectores)
        sem_wait(&resource.write_lock);
        
        // SECCIÓN CRÍTICA - ESCRITURA
        int new_value = (writer_id * 1000) + i;
        printf("📝 Escritor %d escribiendo: %d → %d\n", 
               writer_id, resource.shared_data, new_value);
        
        resource.shared_data = new_value;
        resource.total_writes++;
        
        // Simular tiempo de escritura
        usleep(300000 + (rand() % 400000));  // 300-700ms
        
        // PROTOCOLO DE SALIDA - ESCRITORES
        sem_post(&resource.write_lock);
        
        printf("✅ Escritor %d terminó escritura %d\n", writer_id, i + 1);
        
        // Tiempo entre escrituras
        usleep(800000 + (rand() % 1200000));  // 0.8-2.0s
    }
    
    printf("✅ Escritor %d terminó todas las escrituras\n", writer_id);
    return NULL;
}

void mostrar_estadisticas() {
    pthread_mutex_lock(&resource.mutex);
    
    printf("\n📊 ESTADÍSTICAS:\n");
    printf("   Valor actual: %d\n", resource.shared_data);
    printf("   Lectores activos: %d\n", resource.reader_count);
    printf("   Total lecturas: %d\n", resource.total_reads);
    printf("   Total escrituras: %d\n", resource.total_writes);
    
    pthread_mutex_unlock(&resource.mutex);
}

int main() {
    #define NUM_READERS 3
    #define NUM_WRITERS 2
    
    pthread_t readers[NUM_READERS];
    pthread_t writers[NUM_WRITERS];
    int reader_ids[NUM_READERS];
    int writer_ids[NUM_WRITERS];
    
    init_resource();
    srand(time(NULL));
    
    printf("🚀 Iniciando Lectores-Escritores\n\n");
    
    // Crear lectores
    for (int i = 0; i < NUM_READERS; i++) {
        reader_ids[i] = i + 1;
        pthread_create(&readers[i], NULL, lector, &reader_ids[i]);
    }
    
    // Crear escritores con pequeño delay
    sleep(1);
    for (int i = 0; i < NUM_WRITERS; i++) {
        writer_ids[i] = i + 1;
        pthread_create(&writers[i], NULL, escritor, &writer_ids[i]);
    }
    
    // Monitor periódico
    for (int i = 0; i < 8; i++) {
        sleep(2);
        mostrar_estadisticas();
    }
    
    // Esperar terminación
    for (int i = 0; i < NUM_READERS; i++) {
        pthread_join(readers[i], NULL);
    }
    for (int i = 0; i < NUM_WRITERS; i++) {
        pthread_join(writers[i], NULL);
    }
    
    printf("\n🏁 Simulación terminada\n");
    mostrar_estadisticas();
    
    // Cleanup
    pthread_mutex_destroy(&resource.mutex);
    sem_destroy(&resource.write_lock);
    
    return 0;
}
```

## Síntesis

### Puntos Clave

1. **Race Conditions** son la causa fundamental de bugs en programas concurrentes
2. **Sección Crítica** debe protegerse con primitivas de sincronización
3. **Semáforos** son la herramienta más versátil para sincronización
5. **Overhead** de sincronización debe balancearse con necesidades de concurrencia

### Conexiones con Otros Temas

- **Scheduling**: Los procesos bloqueados en semáforos van a cola de espera
- **Deadlock** puede prevenirse con diseño cuidadoso del orden de recursos
- **Memory Management**: Variables compartidas requieren coherencia de cache
- **File Systems**: Control de concurrencia en acceso a archivos
- **Networks**: Sincronización en sistemas distribuidos
