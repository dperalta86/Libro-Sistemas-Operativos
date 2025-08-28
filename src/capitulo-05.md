# Capítulo 5: Sincronización

## 1. Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Identificar problemas de concurrencia: race conditions, deadlock, starvation
- Explicar qué son las operaciones atómicas y por qué son necesarias
- Implementar soluciones usando mutex, semáforos y variables de condición
- Resolver problemas clásicos: Productor-Consumidor, Lectores-Escritores
- Aplicar sincronización en escenarios reales usando analogías cotidianas
- Analizar y prevenir deadlocks usando técnicas formales
- Programar soluciones thread-safe en C usando pthreads
- Evaluar el overhead de diferentes primitivas de sincronización

## 2. Introducción y Contexto

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

### El problema fundamental: Race Conditions

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

## 3. Conceptos Fundamentales

### 3.1 Sección Crítica

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

### 3.2 Primitivos Atómicos

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

### 3.3 Mutex (Mutual Exclusion)

**Definición**: Objeto de sincronización que permite exclusión mutua sobre un recurso.

**Estados del mutex:**
- **Unlocked**: Disponible para ser tomado
- **Locked**: Ocupado por un hilo, otros deben esperar

**Operaciones básicas:**
```c
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

// Bloquear (tomar el mutex)
pthread_mutex_lock(&mutex);    // Bloquea si ya está ocupado

// Intentar bloquear sin esperar  
if (pthread_mutex_trylock(&mutex) == 0) {
    // Obtuve el mutex
} else {
    // Mutex ocupado, continuar sin bloquear
}

// Liberar mutex
pthread_mutex_unlock(&mutex);  // Despertar hilos esperando
```

### 3.4 Semáforos

**Definición**: Contador entero que permite controlar acceso a recursos limitados.

**Inventado por Dijkstra (1965)** para resolver problemas de sincronización general.

**Operaciones atómicas:**
```c
// P() o wait() - Decrementar y posiblemente bloquear
void sem_wait(sem_t* sem) {
    // Atomicamente:
    if (sem->value > 0) {
        sem->value--;
        return;  // Continuar ejecución
    } else {
        // Bloquear hilo hasta que sem->value > 0
        block_thread_on_semaphore(sem);
    }
}

// V() o signal() - Incrementar y despertar
void sem_post(sem_t* sem) {
    // Atomicamente:  
    sem->value++;
    if (threads_waiting_on(sem) > 0) {
        wake_up_one_thread(sem);
    }
}
```

**Tipos de semáforos:**

#### Semáforo Binario (0 o 1)
- Equivalente a mutex
- Usado para exclusión mutua

#### Semáforo Contador (0 a N)
- Controla acceso a N recursos idénticos
- Ejemplo: Pool de conexiones de BD

### 3.5 Variables de Condición

**Definición**: Permite que hilos esperen hasta que se cumpla una condición específica.

**Problema que resuelven**: 
- Evitar **busy waiting** (polling constante)
- Sincronización basada en **estado** no solo en **recursos**

**Patrón típico:**
```c
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t condition = PTHREAD_COND_INITIALIZER;
bool condition_met = false;

// Hilo que espera condición
void wait_for_condition() {
    pthread_mutex_lock(&mutex);
    
    while (!condition_met) {
        // Liberar mutex y esperar señal atomicamente
        pthread_cond_wait(&condition, &mutex);
        // Al despertar, mutex está tomado automáticamente
    }
    
    // Usar recurso protegido por la condición
    
    pthread_mutex_unlock(&mutex);
}

// Hilo que señala condición
void signal_condition() {
    pthread_mutex_lock(&mutex);
    
    condition_met = true;
    
    // Despertar UN hilo esperando
    pthread_cond_signal(&condition);
    // O despertar TODOS: pthread_cond_broadcast(&condition);
    
    pthread_mutex_unlock(&mutex);
}
```

## 4. Análisis Técnico

### 4.1 El Supermercado: Modelado Completo

Vamos a modelar nuestro supermercado con todos los elementos de sincronización:

```c
<stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

// CONFIGURACIÓN DEL SUPERMERCADO
#define NUM_CAJAS 20
#define NUM_CAJEROS 20  
#define NUM_CLIENTES 100
#define CAPACIDAD_COLA_POR_CAJA 10

// RECURSOS COMPARTIDOS DEL SUPERMERCADO
typedef struct {
    // Sistema de promociones (recurso exclusivo)
    pthread_mutex_t sistema_promociones;
    bool promociones_activas;
    
    // Cajas registradoras (array de semáforos)
    sem_t cajas_disponibles;           // Contador: cuántas cajas libres
    pthread_mutex_t estado_cajas[NUM_CAJAS];  // Mutex por cada caja
    bool caja_ocupada[NUM_CAJAS];
    int clientes_en_caja[NUM_CAJAS];
    
    // Empleado que ordena filas (recurso único móvil)
    sem_t empleado_disponible;         // 0 o 1
    pthread_mutex_t empleado_trabajando;
    int caja_siendo_ordenada;
    
    // Contador global de ventas (variable compartida crítica)
    pthread_mutex_t mutex_ventas;
    long long ventas_totales;
    int transacciones_totales;
    
    // Colas por caja (productor-consumidor)
    sem_t cola_caja_llena[NUM_CAJAS];    // Cuántos clientes esperando
    sem_t cola_caja_vacia[NUM_CAJAS];    // Cuántos espacios libres
    pthread_mutex_t mutex_cola[NUM_CAJAS];
    int cola_clientes[NUM_CAJAS][CAPACIDAD_COLA_POR_CAJA];
    int frente_cola[NUM_CAJAS];
    int final_cola[NUM_CAJAS];
    
} supermercado_t;

supermercado_t super;
```

### 4.2 Inicialización del Sistema

```c
void inicializar_supermercado() {
    // Sistema de promociones (mutex simple)
    pthread_mutex_init(&super.sistema_promociones, NULL);
    super.promociones_activas = false;
    
    // Cajas registradoras
    sem_init(&super.cajas_disponibles, 0, NUM_CAJAS);  // 20 cajas inicialmente
    
    for (int i = 0; i < NUM_CAJAS; i++) {
        pthread_mutex_init(&super.estado_cajas[i], NULL);
        super.caja_ocupada[i] = false;
        super.clientes_en_caja[i] = 0;
        
        // Colas por caja
        sem_init(&super.cola_caja_llena[i], 0, 0);  // Sin clientes inicialmente
        sem_init(&super.cola_caja_vacia[i], 0, CAPACIDAD_COLA_POR_CAJA);
        pthread_mutex_init(&super.mutex_cola[i], NULL);
        super.frente_cola[i] = 0;
        super.final_cola[i] = 0;
    }
    
    // Empleado ordenador
    sem_init(&super.empleado_disponible, 0, 1);  // 1 empleado disponible
    pthread_mutex_init(&super.empleado_trabajando, NULL);
    super.caja_siendo_ordenada = -1;
    
    // Contador de ventas
    pthread_mutex_init(&super.mutex_ventas, NULL);
    super.ventas_totales = 0;
    super.transacciones_totales = 0;
    
    printf("🏪 Supermercado inicializado: %d cajas, 1 empleado, sistema listo\n", NUM_CAJAS);
}
```

### 4.3 Implementación de los Actores

#### El Cliente (Productor)
```c
typedef struct {
    int id;
    int monto_compra;
    bool necesita_promocion;
    int items_carrito;
} cliente_t;

void* cliente_thread(void* arg) {
    cliente_t* cliente = (cliente_t*)arg;
    
    printf("🛒 Cliente %d llegó (compra: $%d, %d items)\n", 
           cliente->id, cliente->monto_compra, cliente->items_carrito);
    
    // 1. Elegir caja (estrategia: menor cola)
    int caja_elegida = elegir_mejor_caja();
    
    // 2. Hacer cola en la caja elegida
    hacer_cola_en_caja(cliente, caja_elegida);
    
    return NULL;
}

int elegir_mejor_caja() {
    int mejor_caja = 0;
    int menor_cola = CAPACIDAD_COLA_POR_CAJA + 1;
    
    for (int i = 0; i < NUM_CAJAS; i++) {
        pthread_mutex_lock(&super.mutex_cola[i]);
        
        int tamaño_cola = (super.final_cola[i] - super.frente_cola[i] + CAPACIDAD_COLA_POR_CAJA) 
                         % CAPACIDAD_COLA_POR_CAJA;
        
        if (tamaño_cola < menor_cola) {
            menor_cola = tamaño_cola;
            mejor_caja = i;
        }
        
        pthread_mutex_unlock(&super.mutex_cola[i]);
    }
    
    return mejor_caja;
}

void hacer_cola_en_caja(cliente_t* cliente, int caja) {
    printf("🚶 Cliente %d haciendo cola en caja %d\n", cliente->id, caja);
    
    // Esperar espacio en la cola (semáforo vació)
    sem_wait(&super.cola_caja_vacia[caja]);
    
    // Acceso exclusivo a la estructura de la cola
    pthread_mutex_lock(&super.mutex_cola[caja]);
    
    // Agregar cliente al final de la cola
    super.cola_clientes[caja][super.final_cola[caja]] = cliente->id;
    super.final_cola[caja] = (super.final_cola[caja] + 1) % CAPACIDAD_COLA_POR_CAJA;
    
    pthread_mutex_unlock(&super.mutex_cola[caja]);
    
    // Señalar que hay un cliente más esperando
    sem_post(&super.cola_caja_llena[caja]);
    
    printf("✅ Cliente %d en cola de caja %d\n", cliente->id, caja);
}
```

#### El Cajero (Consumidor)
```c
typedef struct {
    int id;
    int caja_asignada;
    int clientes_atendidos;
    long long ventas_realizadas;
} cajero_t;

void* cajero_thread(void* arg) {
    cajero_t* cajero = (cajero_t*)arg;
    
    printf("👨‍💼 Cajero %d iniciando en caja %d\n", cajero->id, cajero->caja_asignada);
    
    while (true) {
        // 1. Esperar cliente en su cola
        int cliente_id = esperar_cliente_en_cola(cajero->caja_asignada);
        
        if (cliente_id == -1) break;  // Supermercado cerrando
        
        // 2. Atender cliente
        atender_cliente(cajero, cliente_id);
        
        // 3. Cada cierto tiempo, solicitar orden de la fila
        if (cajero->clientes_atendidos % 10 == 0) {
            solicitar_empleado_ordenador(cajero->caja_asignada);
        }
    }
    
    return NULL;
}

int esperar_cliente_en_cola(int caja) {
    // Esperar que haya al menos un cliente (semáforo lleno)
    sem_wait(&super.cola_caja_llena[caja]);
    
    // Acceso exclusivo a la cola
    pthread_mutex_lock(&super.mutex_cola[caja]);
    
    // Obtener cliente del frente de la cola
    int cliente_id = super.cola_clientes[caja][super.frente_cola[caja]];
    super.frente_cola[caja] = (super.frente_cola[caja] + 1) % CAPACIDAD_COLA_POR_CAJA;
    
    pthread_mutex_unlock(&super.mutex_cola[caja]);
    
    // Señalar que hay un espacio libre más
    sem_post(&super.cola_caja_vacia[caja]);
    
    return cliente_id;
}

void atender_cliente(cajero_t* cajero, int cliente_id) {
    printf("💰 Cajero %d atendiendo cliente %d en caja %d\n", 
           cajero->id, cliente_id, cajero->caja_asignada);
    
    // Simular tiempo de atención (aleatorio)
    int tiempo_atencion = 1 + (rand() % 3);  // 1-3 segundos
    sleep(tiempo_atencion);
    
    // Generar venta aleatoria
    int monto_venta = 50 + (rand() % 200);  // $50-$250
    bool necesita_promocion = (rand() % 4) == 0;  // 25% de probabilidad
    
    // Aplicar promoción si es necesario (recurso exclusivo)
    if (necesita_promocion) {
        if (aplicar_promocion(cajero->id, cliente_id, &monto_venta)) {
            printf("🎉 Promoción aplicada a cliente %d: descuento en caja %d\n", 
                   cliente_id, cajero->caja_asignada);
        }
    }
    
    // Actualizar ventas totales (variable compartida crítica)
    actualizar_ventas_totales(monto_venta);
    
    cajero->clientes_atendidos++;
    cajero->ventas_realizadas += monto_venta;
    
    printf("✅ Cliente %d atendido: $%d (Total cajero %d: $%lld)\n", 
           cliente_id, monto_venta, cajero->id, cajero->ventas_realizadas);
}

bool aplicar_promocion(int cajero_id, int cliente_id, int* monto) {
    printf("🔄 Cajero %d intentando acceder sistema promociones...\n", cajero_id);
    
    // Intentar obtener acceso exclusivo al sistema de promociones
    if (pthread_mutex_trylock(&super.sistema_promociones) != 0) {
        printf("⏳ Sistema promociones ocupado, cliente %d sin descuento\n", cliente_id);
        return false;  // Sistema ocupado, no aplicar promoción
    }
    
    // SECCIÓN CRÍTICA: Solo un cajero puede usar promociones
    printf("🎯 Cajero %d usando sistema promociones para cliente %d\n", cajero_id, cliente_id);
    
    super.promociones_activas = true;
    
    // Simular tiempo de procesamiento del sistema (crítico)
    sleep(1);  // El sistema es lento y no puede paralelizarse
    
    // Calcular descuento
    int descuento = (*monto) * 0.15;  // 15% descuento
    *monto -= descuento;
    
    super.promociones_activas = false;
    
    // Liberar sistema de promociones
    pthread_mutex_unlock(&super.sistema_promociones);
    
    printf("💸 Descuento de $%d aplicado por cajero %d\n", descuento, cajero_id);
    return true;
}

void actualizar_ventas_totales(int monto_venta) {
    // Sección crítica: actualizar contador global
    pthread_mutex_lock(&super.mutex_ventas);
    
    super.ventas_totales += monto_venta;
    super.transacciones_totales++;
    
    // Cada 100 transacciones, mostrar total
    if (super.transacciones_totales % 100 == 0) {
        printf("📊 VENTAS TOTALES: $%lld (%d transacciones)\n", 
               super.ventas_totales, super.transacciones_totales);
    }
    
    pthread_mutex_unlock(&super.mutex_ventas);
}
```

#### El Empleado Ordenador (Recurso Único Móvil)
```c
void* empleado_ordenador_thread(void* arg) {
    printf("👷 Empleado ordenador iniciando trabajo\n");
    
    while (true) {
        // Esperar a ser solicitado
        sem_wait(&super.empleado_disponible);
        
        // Encontrar caja que más necesita orden
        int caja_a_ordenar = encontrar_caja_desordenada();
        
        if (caja_a_ordenar == -1) {
            // No hay trabajo, volver a disponible
            sem_post(&super.empleado_disponible);
            sleep(5);  // Descansar un poco
            continue;
        }
        
        // Ordenar la caja elegida
        ordenar_caja(caja_a_ordenar);
        
        // Volver a estar disponible
        sem_post(&super.empleado_disponible);
    }
    
    return NULL;
}

int encontrar_caja_desordenada() {
    int peor_caja = -1;
    int max_clientes = 0;
    
    for (int i = 0; i < NUM_CAJAS; i++) {
        pthread_mutex_lock(&super.mutex_cola[i]);
        
        int tamaño_cola = (super.final_cola[i] - super.frente_cola[i] + CAPACIDAD_COLA_POR_CAJA) 
                         % CAPACIDAD_COLA_POR_CAJA;
        
        if (tamaño_cola > max_clientes) {
            max_clientes = tamaño_cola;
            peor_caja = i;
        }
        
        pthread_mutex_unlock(&super.mutex_cola[i]);
    }
    
    // Solo trabajar si hay al menos 5 clientes esperando
    return (max_clientes >= 5) ? peor_caja : -1;
}

void ordenar_caja(int caja) {
    printf("🔧 Empleado ordenando caja %d\n", caja);
    
    // Marcar caja como siendo ordenada
    pthread_mutex_lock(&super.empleado_trabajando);
    super.caja_siendo_ordenada = caja;
    pthread_mutex_unlock(&super.empleado_trabajando);
    
    // Simular tiempo de ordenar (requiere coordinar con cajero)
    sleep(3);  // 3 segundos organizando la fila
    
    printf("✨ Caja %d ordenada por empleado\n", caja);
    
    // Marcar trabajo terminado
    pthread_mutex_lock(&super.empleado_trabajando);
    super.caja_siendo_ordenada = -1;
    pthread_mutex_unlock(&super.empleado_trabajando);
}

void solicitar_empleado_ordenador(int caja) {
    printf("📞 Caja %d solicitando empleado ordenador\n", caja);
    
    // Esta función NO bloquea - solo hace una solicitud
    // El empleado decidirá si atiende basado en prioridades
}
```

## 5. Código en C

### 5.1 Demostración de Race Condition

```c
#include <stdio.h>
#include <pthread.h>
#include <stdlib.h>

#define NUM_THREADS 4
#define INCREMENTOS_POR_THREAD 250000

// Variable global compartida (¡PELIGRO!)
volatile long long contador_inseguro = 0;
long long contador_seguro = 0;

// Mutex para proteger contador seguro
pthread_mutex_t mutex_contador = PTHREAD_MUTEX_INITIALIZER;

void* incrementar_inseguro(void* arg) {
    int thread_id = *(int*)arg;
    
    printf("Thread %d: iniciando incrementos inseguros\n", thread_id);
    
    for (int i = 0; i < INCREMENTOS_POR_THREAD; i++) {
        // RACE CONDITION: Esta operación NO es atómica
        contador_inseguro++;
        
        // En assembly se traduce aproximadamente a:
        // 1. LOAD  registro, [contador_inseguro]    ← Lectura
        // 2. INC   registro                         ← Incremento  
        // 3. STORE [contador_inseguro], registro    ← Escritura
        //
        // Entre cualquiera de estos pasos puede ocurrir context switch!
    }
    
    printf("Thread %d: terminó incrementos inseguros\n", thread_id);
    return NULL;
}

void* incrementar_seguro(void* arg) {
    int thread_id = *(int*)arg;
    
    printf("Thread %d: iniciando incrementos seguros\n", thread_id);
    
    for (int i = 0; i < INCREMENTOS_POR_THREAD; i++) {
        // SECCIÓN CRÍTICA protegida por mutex
        pthread_mutex_lock(&mutex_contador);
        
        contador_seguro++;  // Ahora es thread-safe
        
        pthread_mutex_unlock(&mutex_contador);
    }
    
    printf("Thread %d: terminó incrementos seguros\n", thread_id);
    return NULL;
}

void demostrar_race_condition() {
    pthread_t threads[NUM_THREADS];
    int thread_ids[NUM_THREADS];
    
    printf("=== DEMOSTRACIÓN DE RACE CONDITION ===\n");
    printf("Creando %d threads, cada uno incrementa %d veces\n", NUM_THREADS, INCREMENTOS_POR_THREAD);
    printf("Resultado esperado: %lld\n\n", (long long)NUM_THREADS * INCREMENTOS_POR_THREAD);
    
    // Resetear contadores
    contador_inseguro = 0;
    contador_seguro = 0;
    
    // TEST 1: Incrementos inseguros (race condition)
    printf("--- Test 1: Sin protección (race condition) ---\n");
    
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, incrementar_inseguro, &thread_ids[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }
    
    printf("Resultado inseguro: %lld", contador_inseguro);
    if (contador_inseguro == (long long)NUM_THREADS * INCREMENTOS_POR_THREAD) {
        printf(" ✅ (¡Suerte! Pero no es confiable)\n");
    } else {
        printf(" ❌ (Race condition detectada)\n");
    }
    
    // TEST 2: Incrementos seguros (con mutex)
    printf("\n--- Test 2: Con mutex (thread-safe) ---\n");
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_create(&threads[i], NULL, incrementar_seguro, &thread_ids[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }
    
    printf("Resultado seguro: %lld", contador_seguro);
    if (contador_seguro == (long long)NUM_THREADS * INCREMENTOS_POR_THREAD) {
        printf(" ✅ (Correcto y confiable)\n");
    } else {
        printf(" ❌ (Error inesperado)\n");
    }
    
    printf("\n=== ANÁLISIS ===\n");
    long long perdidos = ((long long)NUM_THREADS * INCREMENTOS_POR_THREAD) - contador_inseguro;
    printf("Incrementos perdidos por race condition: %lld (%.2f%%)\n", 
           perdidos, (perdidos * 100.0) / ((long long)NUM_THREADS * INCREMENTOS_POR_THREAD));
}

int main() {
    demostrar_race_condition();
    return 0;
}
```

### 5.2 Implementación de Semáforos para el Supermercado

```c
#include <stdio.h>
#include 