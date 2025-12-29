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

Los sistemas concurrentes son como una orquesta: múltiples instrumentos tocando simultáneamente pueden crear una sinfonía hermosa o un desastre. La diferencia está en la coordinación. En los sistemas operativos modernos, donde múltiples procesos e hilos compiten por recursos compartidos, la sincronización es el director de orquesta que mantiene todo en armonía.  
Imaginemos un supermercado en hora pico. Tenemos 20 cajas funcionando independientemente, un empleado que debe ordenar las filas (pero solo puede estar en un lugar a la vez), un sistema de promociones que solo permite una aplicación simultánea, y clientes que llegan aleatoriamente eligiendo cajas según su conveniencia. Este escenario, aparentemente simple, está plagado de problemas potenciales de concurrencia.  
\begin{warning}
Sin una coordinación adecuada, pueden ocurrir los siguientes problemas:

Race condition: Dos cajeros intentan usar el sistema de promociones simultáneamente, corrompiendo la base de datos  
Starvation: Una caja siempre tiene fila larga porque el empleado nunca la atiende  
Deadlock: El empleado espera que se libere una caja para ordenarla, pero el cajero espera que el empleado termine de ordenar para continuar  
Inconsistencia: El contador total de ventas se pierde cuando dos cajas lo actualizan al mismo tiempo
\end{warning}

Esta analogía del supermercado nos permite mapear conceptos abstractos de sincronización a situaciones cotidianas. Las cajas registradoras representan un array de recursos limitados, el sistema de promociones es un recurso de exclusión mutua, el empleado ordenador funciona como un recurso único móvil, y el contador de ventas ejemplifica una variable compartida crítica. Los cajeros y clientes actúan como threads que acceden concurrentemente a estos recursos, mientras que la cola de clientes por caja implementa el clásico patrón productor-consumidor.

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

Una race condition ocurre cuando el resultado de una operación depende del orden específico de ejecución de múltiples operaciones concurrentes sobre datos compartidos. El término "race" (carrera) es apropiado: los procesos compiten entre sí, y el ganador determina el resultado final, haciendo que el comportamiento del sistema sea impredecible.  
Consideremos un ejemplo concreto: dos cajeros actualizando el contador de ventas totales. A nivel de código de alto nivel, parece simple:
```c
// Dos cajeros actualizando ventas totales
int ventas_totales = 0;

// Cajero 1                    // Cajero 2
ventas_totales += 100;        ventas_totales += 200;
```

Sin embargo, lo que parece una operación atómica en C en realidad se traduce a múltiples instrucciones de lenguaje de máquina. Cuando observamos el assembly generado, vemos la verdadera complejidad:  
```assembly
; Cajero 1                    ; Cajero 2
LOAD R1, [ventas_totales]     LOAD R2, [ventas_totales]
ADD  R1, 100                  ADD  R2, 200
STORE [ventas_totales], R1    STORE [ventas_totales], R2
```

\begin{theory}
El problema surge porque la operación $ventas\_totales += valor$ no es atómica. En realidad, consiste en tres operaciones distintas:  

- Cargar el valor actual de memoria a un registro  
- Incrementar el valor en el registro  
- Almacenar el nuevo valor de vuelta en memoria  

Si dos threads ejecutan estas operaciones intercaladamente, el resultado final puede ser incorrecto, perdiendo una o ambas actualizaciones.  
\end{theory}
Los resultados posibles varían desde el correcto ($ventas\_totales = 300$) hasta completamente incorrectos donde se pierde la venta de uno u otro cajero ($ventas\_totales = 100 o 200$). Esta impredecibilidad es lo que hace a las race conditions tan peligrosas y difíciles de depurar: el bug puede no manifestarse en pruebas, apareciendo solo bajo condiciones específicas de carga en producción.

## Sección Crítica y Condiciones de Bernstein

### Sección Crítica

Cada programa concurrente tiene porciones de código donde accede a recursos compartidos. Estas porciones se denominan secciones críticas, y deben ejecutarse de manera atómica, es decir, sin interrupciones que permitan que otro proceso acceda simultáneamente al mismo recurso.  

La estructura general de un programa con sección crítica sigue un patrón bien definido:
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

Para que una solución al problema de la sección crítica sea correcta, debe satisfacer cuatro requisitos fundamentales. Primero, debe garantizar exclusión mutua: solo un proceso puede estar en su sección crítica a la vez. Segundo, debe asegurar progreso: si ningún proceso está en su sección crítica, la decisión de quién entrará no puede posponerse indefinidamente. Tercero, debe proporcionar espera acotada: existe un límite en el número de veces que otros procesos pueden entrar a su sección crítica antes de que un proceso en espera pueda hacerlo. Finalmente, la solución no debe asumir nada sobre las velocidades relativas de los procesos.

### Condiciones de Bernstein

Antes de aplicar mecanismos de sincronización, es útil determinar si dos procesos realmente necesitan sincronizarse. Las Condiciones de Bernstein proporcionan un criterio matemático para esta decisión.
\begin{theory}
Para que dos procesos P₁ y P₂ puedan ejecutarse concurrentemente de manera segura, deben cumplirse tres condiciones simultáneamente:
Sean R₁ y R₂ los conjuntos de variables que leen los procesos respectivamente, y W₁ y W₂ los conjuntos de variables que escriben. Entonces:
$$
R₁ ∩ W₂ = ∅ (P₁ no lee lo que P₂ escribe)
$$
$$
W₁ ∩ R₂ = ∅ (P₁ no escribe lo que P₂ lee)
$$
$$
W₁ ∩ W₂ = ∅ (P₁ y P₂ no escriben las mismas variables)
$$
\end{theory}

Consideremos un ejemplo donde estas condiciones se violan:

```c
// Proceso 1: R₁ = {x}, W₁ = {y}
y = x + 10;

// Proceso 2: R₂ = {y}, W₂ = {x}
x = y * 2;
```

En este caso, hay violaciones claras: $W₁ ∩ R₂ = {y}$ porque el Proceso 1 escribe y que el Proceso 2 lee, y $R₁ ∩ W₂ = {x}$ porque el Proceso 1 lee x que el Proceso 2 escribe. Por tanto, estos procesos no pueden ejecutarse concurrentemente sin sincronización, ya que el resultado dependerá del orden de ejecución.

## Soluciones a Nivel Software

### Evolución Histórica de las Soluciones
La historia de la sincronización en sistemas operativos es una historia de intentos, fallas y mejoras incrementales. Cada solución fallida nos enseñó algo sobre la complejidad del problema y nos acercó a soluciones correctas.

#### Primeras Aproximaciones: Variables de Control

Los primeros intentos de resolver el problema de la sección crítica usaron variables compartidas simples para coordinar el acceso. Aunque intuitivos, revelaron sutilezas inesperadas.
El primer intento, el turno simple, usaba una variable compartida que indicaba qué proceso podía entrar:
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

Esta solución garantiza exclusión mutua: solo el proceso cuyo turno corresponde puede entrar. Sin embargo, viola gravemente la condición de progreso. Si un proceso termina de usar su sección crítica y no quiere volver a entrar inmediatamente, el otro proceso queda bloqueado indefinidamente esperando su turno, incluso si nadie más está usando el recurso. Es como tener dos personas compartiendo un baño, donde cada una solo puede usarlo en turnos estrictos, incluso si la otra persona está durmiendo.  
El segundo intento mejoró la situación usando *flags* independientes:

```c
bool flag[2] = {false, false};

// Proceso i
flag[i] = true;
while (flag[j]);  // j = 1-i
// Sección crítica
flag[i] = false;
```

Aquí, cada proceso indica su intención de entrar levantando su flag, luego verifica si el otro proceso también está interesado. El problema es una race condition clásica: ambos procesos pueden leer el flag del otro como `false` antes de que cualquiera lo establezca en `true`, resultando en que ambos entren simultáneamente a la sección crítica. La exclusión mutua se viola.  
El tercer intento intentó ser más cortés, haciendo que los procesos cedan ante conflictos:
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

\begin{warning}
Esta solución introduce un nuevo problema: livelock. Ambos procesos pueden entrar en un ciclo donde continuamente bajan y levantan sus flags, cada uno cediendo cortésmente al otro, pero ninguno progresando nunca. Es como dos personas en un pasillo estrecho, cada una haciéndose a un lado para que pase la otra, resultando en que ambas se mueven en la misma dirección indefinidamente.
\end{warning}

### Solución de Peterson (1981)

Gary Peterson finalmente resolvió el problema en 1981 con una solución elegante que combina ideas de los intentos anteriores. La solución de Peterson es la *primera solución correcta* puramente de software para dos procesos:

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

La brillantez de Peterson está en cómo combina el flag de intención con la cesión de turno. Cuando un proceso quiere entrar, primero levanta su flag mostrando interés, luego cede el turno al otro proceso. Solo espera si el otro proceso también está interesado y tiene el turno. Esta combinación garantiza las cuatro propiedades necesarias.  

\begin{theory}
La corrección de Peterson se puede demostrar formalmente:
Exclusión Mutua: Si ambos procesos están en el while, uno debe tener turn = i y el otro turn = j. Como turn es una variable única compartida, esto es imposible. Por tanto, al menos uno saldrá del while.\\
Progreso: Si un proceso no está interesado (flag[j] = false), el otro puede entrar inmediatamente sin importar el valor de turn.\\
Espera Acotada: El proceso que ejecutó turn = j más recientemente cederá el turno, garantizando que el otro proceso pueda entrar después de a lo sumo una espera.
\end{theory}
Sin embargo, la solución de Peterson tiene limitaciones importantes. Funciona solo para dos procesos, requiere busy waiting que desperdicia ciclos de CPU, y asume orden secuencial de memoria. En procesadores modernos con reordenamiento de instrucciones y cachés múltiples, puede fallar sin barreras de memoria explícitas.

## Soluciones a Nivel Hardware
Las limitaciones de las soluciones puramente de software llevaron al desarrollo de primitivas atómicas implementadas directamente en hardware. Estas instrucciones ejecutan múltiples operaciones como una unidad indivisible, proporcionando los bloques fundamentales para construir mecanismos de sincronización más eficientes.

### Primitivos Atómicos

Una operación atómica es aquella que se ejecuta completamente sin posibilidad de interrupción. Desde la perspectiva de otros procesos, la operación ocurre instantáneamente.

#### Test-and-Set (Hardware)
La instrucción Test-and-Set lee un valor, lo cambia a true, y retorna el valor original, todo en una operación atómica:
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

Este primitivo permite implementar spin locks de manera correcta. Un proceso intenta adquirir el lock repetidamente con test-and-set hasta que tiene éxito. Cuando obtiene el lock (test-and-set retorna false), puede entrar a su sección crítica. Al salir, simplemente establece el lock en false.
\begin{infobox}
Ventajas y desventajas de Test-and-Set
La simplicidad de test-and-set lo hace fácil de implementar en hardware y funciona para cualquier número de procesos, garantizando exclusión mutua. Sin embargo, sufre de busy waiting: un proceso bloqueado continúa consumiendo ciclos de CPU chequeando el lock repetidamente. Además, no garantiza espera acotada, lo que puede causar starvation donde un proceso espera indefinidamente mientras otros continuamente obtienen el lock.
\end{infobox}

#### Compare-and-Swap (CAS)
Compare-and-Swap es más flexible que test-and-set, permitiendo actualizar un valor solo si tiene un valor esperado específico:

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
CAS es la base de muchas estructuras de datos lock-free modernas. En el ejemplo, incrementamos un contador atómicamente: leemos el valor actual, calculamos el nuevo valor, y usamos CAS para actualizarlo solo si no cambió entre la lectura y la actualización. Si falló (otro thread lo cambió), reintentamos.

#### Fetch-and-Add
Fetch-and-Add retorna el valor anterior de una variable y le suma un valor dado, todo atómicamente:

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
Este primitivo permite implementar ticket locks, que garantizan espera acotada similar a un sistema de turnos en un banco. Cada proceso que llega obtiene un número de ticket con fetch-and-add, luego espera hasta que su número sea el turno actual. Esto garantiza fairness: los procesos entran en el orden que llegaron.

## Soluciones del Sistema Operativo: Semáforos
Los primitivos de hardware resolvieron el problema de la atomicidad, pero dejaron el problema del busy waiting. Los sistemas operativos necesitaban un mecanismo de más alto nivel que bloqueara procesos eficientemente en lugar de desperdiciar CPU. *Edsger Dijkstra* inventó los semáforos en 1965, revolucionando la sincronización en sistemas operativos.

### Definición y Operaciones

Un semáforo es esencialmente un contador entero no negativo con dos operaciones atómicas. A diferencia de los spin locks, un semáforo puede bloquear un proceso, poniéndolo a dormir hasta que el recurso esté disponible.

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
La operación `sem_wait()` (también llamada P, por el holandés "proberen" = probar) decrementa el contador. Si el resultado es negativo, el proceso se bloquea y se agrega a una cola de espera. La operación `sem_post()` (también llamada V, por "verhogen" = incrementar) incrementa el contador. Si hay procesos esperando (valor ≤ 0), despierta uno de ellos.
\begin{theory}
La semántica del valor del semáforo es crucial para entender su funcionamiento:\\

- Valor positivo: número de recursos disponibles\\
- Valor cero: no hay recursos disponibles, pero tampoco procesos esperando\\
- Valor negativo: su valor absoluto indica el número de procesos esperando\\

Esta interpretación explica por qué post despierta un proceso cuando el valor es ≤ 0: un valor no positivo implica que hay procesos bloqueados esperando el recurso.
\end{theory}

### Tipos de Semáforos
Los semáforos vienen en dos variedades principales, cada una optimizada para casos de uso específicos.

#### Semáforo Binario (Mutex)

Un semáforo binario, también llamado mutex (mutual exclusion), solo puede tener valores 0 o 1. Se usa principalmente para proteger secciones críticas:

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
Cuando el mutex vale 1, el recurso está disponible. El primer proceso que ejecuta `sem_wait()` decrementa el mutex a 0 y entra. Cualquier otro proceso que intente entrar se bloquea hasta que el primer proceso ejecute `sem_post()`, incrementando el mutex de vuelta a 1.

#### Semáforo Contador

Un semáforo contador puede tener cualquier valor no negativo, representando múltiples instancias de un recurso:

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
Este patrón es ideal para administrar pools de recursos limitados. Un servidor web con 5 conexiones de base de datos usa un semáforo inicializado en 5. Cada cliente que obtiene una conexión ejecuta `sem_wait()`, decrementando el contador. Cuando las 5 conexiones están en uso, nuevos clientes se bloquean hasta que alguien libere una conexión con `sem_post()`.

### Usos Principales de Semáforos

Los semáforos son herramientas versátiles que pueden resolver múltiples problemas de sincronización. Veamos sus patrones de uso más comunes.  
Para *exclusión mutua*, un semáforo binario inicializado en 1 protege la sección crítica:

```c
semaphore_t mutex = 1;

void proceso() {
    sem_wait(&mutex);    // Entrar a sección crítica
    // Sección crítica
    sem_post(&mutex);    // Salir de sección crítica
}
```

Para *limitar acceso a N instancias* de un recurso, un semáforo contador inicializado en N controla cuántos procesos pueden usar el recurso simultáneamente:

```c
semaphore_t recursos = N;

void usar_recurso() {
    sem_wait(&recursos);  // Obtener uno de N recursos
    // Usar recurso
    sem_post(&recursos);  // Liberar recurso
}
```

Para *ordenar ejecución entre procesos*, un semáforo inicializado en 0 actúa como señal de sincronización:

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

Aquí, el proceso B no puede comenzar hasta que A termine. El semáforo en 0 garantiza que B se bloqueará en wait hasta que A señale completitud con post.  

El patrón más complejo y útil es el problema *productor-consumidor*, que requiere tres semáforos trabajando en conjunto:
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
\begin{example}
En este patrón, \texttt{empty} cuenta espacios vacíos disponibles (inicia en BUFFER\_SIZE), full cuenta elementos disponibles para consumir (inicia en 0), y \texttt{mutex} protege el acceso al buffer compartido (inicia en 1).
El productor primero espera un espacio vacío (wait empty), luego obtiene exclusión mutua (wait mutex), agrega su elemento, libera el mutex (post mutex), y finalmente señala un nuevo elemento disponible (post full).
El consumidor hace lo inverso: espera un elemento (wait full), obtiene el mutex (wait mutex), extrae el elemento, libera el mutex (post mutex), y señala un espacio vacío (post empty).
El orden de las operaciones es crítico. Si el productor obtuviera el mutex antes de verificar empty, podría quedarse bloqueado sosteniendo el mutex, impidiendo que el consumidor libere espacio, causando deadlock.
\end{example}

## Ejemplo Práctico: Control de Cochera
Ahora que entendemos los semáforos, apliquémoslos a un problema realista. Vamos a diseñar el sistema de control para una cochera automatizada, un escenario que involucra múltiples recursos compartidos y diferentes patrones de sincronización.

### Planteamiento del Problema

Una cochera tienev**20 espacios** para autos, **1 entrada** (con barrera), **2 salidas** (con barreras) y un **Sistema de control** que debe llevar cuenta de espacios ocupados.

*Requerimientos:*
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
    
    printf("Cochera inicializada: %d espacios disponibles\n", CAPACIDAD_COCHERA);
}

void* auto_entrando(void* arg) {
    int auto_id = *(int*)arg;
    
    printf("Auto %d llegó a la cochera\n", auto_id);
    
    // 1. Verificar si hay espacio disponible
    printf("Auto %d esperando espacio...\n", auto_id);
    sem_wait(&cochera.espacios_disponibles);  // Bloquea si cochera llena
    
    // 2. Hay espacio garantizado, obtener acceso exclusivo a entrada
    printf("Auto %d esperando acceso a entrada...\n", auto_id);
    sem_wait(&cochera.mutex_entrada);
    
    // 3. SECCIÓN CRÍTICA: Procesar entrada
    printf("Auto %d entrando a cochera\n", auto_id);
    
    // Simular tiempo de entrada (abrir barrera, validar ticket, etc.)
    sleep(1);
    
    // Actualizar contador global de manera thread-safe
    sem_wait(&cochera.mutex_contador);
    cochera.autos_dentro++;
    cochera.total_entradas++;
    printf("Auto %d dentro. Total en cochera: %d/%d\n", 
           auto_id, cochera.autos_dentro, CAPACIDAD_COCHERA);
    sem_post(&cochera.mutex_contador);
    
    // 4. Liberar acceso a entrada
    sem_post(&cochera.mutex_entrada);
    
    printf("Auto %d estacionado exitosamente\n", auto_id);
    
    // Simular tiempo estacionado
    sleep(2 + (rand() % 5));  // 2-6 segundos estacionado
    
    // Ahora el auto quiere salir
    return NULL;
}

void* auto_saliendo(void* arg) {
    int auto_id = *(int*)arg;
    
    printf("Auto %d quiere salir\n", auto_id);
    
    // Elegir salida aleatoriamente (load balancing simple)
    int salida = (rand() % 2) + 1;
    sem_t* mutex_salida = (salida == 1) ? &cochera.mutex_salida1 : &cochera.mutex_salida2;
    
    // 1. Obtener acceso exclusivo a la salida elegida
    printf("Auto %d esperando acceso a salida %d...\n", auto_id, salida);
    sem_wait(mutex_salida);
    
    // 2. SECCIÓN CRÍTICA: Procesar salida
    printf("Auto %d saliendo por salida %d\n", auto_id, salida);
    
    // Simular tiempo de salida (validar pago, abrir barrera, etc.)
    sleep(1);
    
    // Actualizar contador global
    sem_wait(&cochera.mutex_contador);
    cochera.autos_dentro--;
    cochera.total_salidas++;
    printf("Auto %d salió. Total en cochera: %d/%d\n", 
           auto_id, cochera.autos_dentro, CAPACIDAD_COCHERA);
    sem_post(&cochera.mutex_contador);
    
    // 3. Liberar acceso a salida
    sem_post(mutex_salida);
    
    // 4. IMPORTANTE: Señalar que hay un espacio más disponible
    sem_post(&cochera.espacios_disponibles);
    
    printf("Auto %d salió exitosamente por salida %d\n", auto_id, salida);
    
    return NULL;
}

void mostrar_estadisticas() {
    sem_wait(&cochera.mutex_contador);
    
    printf("\n ESTADÍSTICAS DE LA COCHERA:\n");
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
    
    printf("Iniciando simulación: %d autos intentarán usar la cochera\n\n", NUM_AUTOS);
    
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
    
    printf("\nSimulación terminada\n");
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
La solución usa cinco semáforos coordinados. `espacios_disponibles` es un semáforo contador inicializado en 20 que representa los espacios libres. Cuando un auto quiere entrar, primero ejecuta wait en este semáforo, bloqueándose si la cochera está llena. Los tres mutex (`mutex_entrada`, `mutex_salida1`, `mutex_salida2`) garantizan acceso exclusivo a cada barrera. Finalmente, `mutex_contador` protege las variables de estadísticas compartidas.  

La función `auto_entrando()` sigue un protocolo cuidadoso. Primero espera un espacio disponible (wait espacios_disponibles), lo que garantiza que solo entre si hay lugar. Luego obtiene acceso exclusivo a la entrada (wait mutex_entrada), simula el proceso de entrada, actualiza el contador de manera thread-safe, y libera la entrada (post mutex_entrada) para el siguiente auto. Notar que el auto retiene su espacio reservado (no hace post en espacios_disponibles) porque está ocupando ese espacio.  

La función `auto_saliendo()` implementa load balancing simple eligiendo aleatoriamente entre las dos salidas. Obtiene acceso exclusivo a la salida elegida (wait mutex_salida), procesa la salida, actualiza el contador, libera la salida (post mutex_salida), y crucialmente, señala que hay un espacio más disponible (post espacios_disponibles). Este último post es fundamental: permite que autos esperando en la entrada puedan proceder.
\begin{infobox}
El orden de las operaciones en \texttt{auto\_entrando()} previene deadlock. Si esperáramos el mutex\_entrada antes de verificar espacios\_disponibles, un auto podría obtener acceso a la entrada pero luego bloquearse esperando espacio, manteniendo el mutex y bloqueando todos los demás autos indefinidamente.
\end{infobox}

## Uso de Arrays de Semáforos
A medida que los sistemas se vuelven más complejos, a menudo necesitamos múltiples recursos del mismo tipo pero con características ligeramente diferentes. Los arrays de semáforos permiten modelar estos escenarios de manera elegante.

### Problema: Múltiples Recursos del Mismo Tipo

Consideremos un servidor web con un pool de 10 threads worker, donde cada request necesita exactamente un worker. Sin embargo, algunos requests requieren workers especializados: algunos workers son expertos en consultas de base de datos, otros en procesamiento de imágenes, otros en llamadas API. Necesitamos un mecanismo para asignar el worker correcto a cada tipo de request.

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
    
    printf("Request %d necesita worker tipo %d\n", request_id, tipo_necesario);
    
    // Obtener worker
    int worker_id = obtener_worker(tipo_necesario);
    if (worker_id == -1) {
        printf("Request %d: Error obteniendo worker\n", request_id);
        return NULL;
    }
    
    printf("Request %d asignado a worker %d (tipo %d)\n", 
           request_id, worker_id, tipo_necesario);
    
    // Simular procesamiento
    sleep(1 + (rand() % 3));
    
    // Liberar worker
    liberar_worker(worker_id);
    
    printf("Request %d completado por worker %d\n", request_id, worker_id);
    
    return NULL;
}
```
En esta implementación, usamos un array de semáforos workers[4] donde cada elemento representa un tipo diferente de worker. Los semáforos se inicializan según la distribución: 4 workers generales, 3 especializados en bases de datos, 2 en procesamiento de imágenes, y 1 en APIs.  
Cuando llega un request, primero ejecuta wait en el semáforo correspondiente al tipo de worker que necesita. Esto garantiza que solo procederá si hay un worker de ese tipo disponible. Luego busca el worker específico dentro de ese tipo, usa mutex individuales por worker para evitar race conditions en la asignación, y marca el worker como ocupado.  
Este patrón permite balanceo de carga automático: requests de diferentes tipos no compiten entre sí por workers, pero requests del mismo tipo se encolan apropiadamente. Si todos los workers de base de datos están ocupados, nuevos requests de DB se bloquean sin afectar requests de procesamiento de imágenes que puedan usar sus workers especializados.

### Problema Clásico: Productor-Consumidor
El problema productor-consumidor es uno de los problemas de sincronización más estudiados en sistemas operativos. Aparece en casi cualquier sistema que procese datos asincrónicamente: pipelines de procesamiento, sistemas de mensajería, buffers de red, colas de impresión, y más.

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
    
    printf("Buffer inicializado (tamaño: %d)\n", BUFFER_SIZE);
}

void* productor(void* arg) {
    int prod_id = *(int*)arg;
    
    for (int i = 0; i < NUM_ITEMS; i++) {
        // Producir elemento
        int item = (prod_id * 100) + i;
        
        printf("Productor %d creó item %d\n", prod_id, item);
        
        // PASO 1: Esperar espacio vacío
        printf("Productor %d esperando espacio...\n", prod_id);
        sem_wait(&shared_buffer.empty);
        
        // PASO 2: Obtener exclusión mutua sobre buffer
        pthread_mutex_lock(&shared_buffer.mutex);
        
        // PASO 3: SECCIÓN CRÍTICA - Insertar en buffer
        shared_buffer.buffer[shared_buffer.in] = item;
        printf("Item %d insertado en posición %d\n", 
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
    
    printf("Productor %d terminó\n", prod_id);
    return NULL;
}

void* consumidor(void* arg) {
    int cons_id = *(int*)arg;
    
    for (int i = 0; i < NUM_ITEMS; i++) {
        // PASO 1: Esperar elemento disponible
        printf("Consumidor %d esperando elemento...\n", cons_id);
        sem_wait(&shared_buffer.full);
        
        // PASO 2: Obtener exclusión mutua sobre buffer
        pthread_mutex_lock(&shared_buffer.mutex);
        
        // PASO 3: SECCIÓN CRÍTICA - Extraer del buffer
        int item = shared_buffer.buffer[shared_buffer.out];
        printf("Item %d extraído de posición %d por consumidor %d\n", 
               item, shared_buffer.out, cons_id);
        
        shared_buffer.out = (shared_buffer.out + 1) % BUFFER_SIZE;
        shared_buffer.items_consumed++;
        
        // PASO 4: Liberar exclusión mutua
        pthread_mutex_unlock(&shared_buffer.mutex);
        
        // PASO 5: Señalar espacio vacío
        sem_post(&shared_buffer.empty);
        
        // Consumir elemento
        printf("Consumidor %d procesando item %d\n", cons_id, item);
        usleep(300000 + (rand() % 400000));  // 300-700ms
    }
    
    printf("Consumidor %d terminó\n", cons_id);
    return NULL;
}

void mostrar_estado_buffer() {
    pthread_mutex_lock(&shared_buffer.mutex);
    
    printf("\nESTADO DEL BUFFER:\n");
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
    
    printf("Iniciando Productor-Consumidor\n\n");
    
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
    
    printf("\nSimulación terminada\n");
    mostrar_estado_buffer();
    
    // Cleanup
    sem_destroy(&shared_buffer.empty);
    sem_destroy(&shared_buffer.full);
    pthread_mutex_destroy(&shared_buffer.mutex);
    
    return 0;
}
```
Notar como en esta solución tres semáforos trabajan juntos para garantizar corrección. El semáforo `empty` (inicializado en BUFFER_SIZE) cuenta espacios vacíos disponibles, `full` (inicializado en 0) cuenta elementos listos para consumir, y `mutex` (inicializado en 1) protege el acceso concurrente al buffer.  
El productor sigue un protocolo de cuatro pasos. Primero, espera un espacio vacío (wait empty), bloqueándose si el buffer está lleno. Segundo, obtiene exclusión mutua (lock mutex) para acceder al buffer de manera segura. Tercero, inserta el elemento en el buffer circular, actualiza el índice `in` con aritmética módulo para wrap-around, e incrementa las estadísticas. Cuarto, libera el mutex (unlock mutex) y señala un elemento disponible (post full) para despertar consumidores en espera.  
El consumidor ejecuta el protocolo inverso: espera un elemento (wait full), obtiene el mutex, extrae el elemento actualizando el índice out, libera el mutex, y señala un espacio vacío (post empty). Este último paso es crucial: permite que productores bloqueados puedan continuar agregando elementos.
\begin{warning}
El orden de las operaciones de semáforos es crítico para evitar deadlock. El productor debe verificar empty antes de obtener el mutex. Si obtuviera el mutex primero, podría bloquearse esperando espacio mientras sostiene el mutex, impidiendo que el consumidor libere espacio. Similarmente, el consumidor debe verificar full antes del mutex.
La regla general: siempre esperar semáforos de recursos (empty, full) antes de obtener mutex de exclusión mutua.
\end{warning}

### Problema Lectores-Escritores
El problema lectores-escritores modela situaciones donde múltiples threads quieren leer un recurso compartido, pero las escrituras requieren acceso exclusivo. Bases de datos, cachés, y estructuras de datos compartidas enfrentan este desafío.

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
    
    printf("Recurso compartido inicializado\n");
}

void* lector(void* arg) {
    int reader_id = *(int*)arg;
    
    for (int i = 0; i < 5; i++) {
        printf("Lector %d quiere leer\n", reader_id);
        
        // PROTOCOLO DE ENTRADA - LECTORES
        pthread_mutex_lock(&resource.mutex);
        
        resource.reader_count++;
        
        // El primer lector bloquea escritores
        if (resource.reader_count == 1) {
            printf("Primer lector %d bloqueando escritores\n", reader_id);
            sem_wait(&resource.write_lock);
        }
        
        pthread_mutex_unlock(&resource.mutex);
        
        // SECCIÓN CRÍTICA - LECTURA
        printf("Lector %d leyendo: valor = %d\n", 
               reader_id, resource.shared_data);
        resource.total_reads++;
        
        // Simular tiempo de lectura
        usleep(100000 + (rand() % 200000));  // 100-300ms
        
        // PROTOCOLO DE SALIDA - LECTORES
        pthread_mutex_lock(&resource.mutex);
        
        resource.reader_count--;
        
        // El último lector desbloquea escritores
        if (resource.reader_count == 0) {
            printf("Último lector %d desbloqueando escritores\n", reader_id);
            sem_post(&resource.write_lock);
        }
        
        pthread_mutex_unlock(&resource.mutex);
        
        printf("Lector %d terminó lectura %d\n", reader_id, i + 1);
        
        // Tiempo entre lecturas
        usleep(500000 + (rand() % 1000000));  // 0.5-1.5s
    }
    
    printf("Lector %d terminó todas las lecturas\n", reader_id);
    return NULL;
}

void* escritor(void* arg) {
    int writer_id = *(int*)arg;
    
    for (int i = 0; i < 3; i++) {
        printf("Escritor %d quiere escribir\n", writer_id);
        
        // PROTOCOLO DE ENTRADA - ESCRITORES
        // Esperar acceso exclusivo (bloquea otros escritores y lectores)
        sem_wait(&resource.write_lock);
        
        // SECCIÓN CRÍTICA - ESCRITURA
        int new_value = (writer_id * 1000) + i;
        printf("Escritor %d escribiendo: %d → %d\n", 
               writer_id, resource.shared_data, new_value);
        
        resource.shared_data = new_value;
        resource.total_writes++;
        
        // Simular tiempo de escritura
        usleep(300000 + (rand() % 400000));  // 300-700ms
        
        // PROTOCOLO DE SALIDA - ESCRITORES
        sem_post(&resource.write_lock);
        
        printf("Escritor %d terminó escritura %d\n", writer_id, i + 1);
        
        // Tiempo entre escrituras
        usleep(800000 + (rand() % 1200000));  // 0.8-2.0s
    }
    
    printf("Escritor %d terminó todas las escrituras\n", writer_id);
    return NULL;
}

void mostrar_estadisticas() {
    pthread_mutex_lock(&resource.mutex);
    
    printf("\nESTADÍSTICAS:\n");
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
    
    printf("Iniciando Lectores-Escritores\n\n");
    
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
    
    printf("\nSimulación terminada\n");
    mostrar_estadisticas();
    
    // Cleanup
    pthread_mutex_destroy(&resource.mutex);
    sem_destroy(&resource.write_lock);
    
    return 0;
}
```

La solución permite múltiples lectores simultáneos (ya que leer no modifica datos), pero garantiza que escritores tengan acceso exclusivo. El `write_lock` semáforo controla el acceso exclusivo: un escritor esperando en este semáforo bloquea tanto a otros escritores como eventualmente a nuevos lectores.  

El protocolo de lectores es sofisticado. Cuando un lector quiere entrar, obtiene el mutex que protege `reader_count`, incrementa el contador, y si es el primer lector (count == 1), ejecuta wait en `write_lock` para bloquear escritores. Libera el mutex rápidamente para permitir que otros lectores entren concurrentemente. Múltiples lectores pueden estar leyendo simultáneamente porque solo el primero esperó el `write_lock`.  

Al salir, el lector nuevamente obtiene el mutex, decrementa el contador, y si es el último lector (count == 0), ejecuta post en `write_lock` para permitir que escritores procedan. Este diseño garantiza que escritores esperan hasta que todos los lectores terminen.  

Los escritores tienen un protocolo más simple: simplemente esperan acceso exclusivo (wait `write_lock`), realizan su escritura, y liberan (post `write_lock`). El semáforo garantiza que solo un escritor puede estar activo, y que escritores esperan hasta que todos los lectores salgan.
\begin{infobox}
Esta solución favorece a los lectores: mientras lleguen lectores nuevos, los escritores esperarán indefinidamente (starvation de escritores). Existen variantes que dan prioridad a escritores o implementan fairness, cada una con diferentes trade-offs. La elección depende del patrón de acceso esperado: sistemas con lecturas frecuentes y escrituras raras favorecen esta implementación, mientras sistemas con muchas escrituras necesitan variantes con prioridad de escritor.
\end{infobox}

## Síntesis
Hemos recorrido un largo camino desde las race conditions hasta soluciones sofisticadas con semáforos. La sincronización es fundamental en sistemas modernos: sin ella, el multithreading y la concurrencia simplemente no funcionarían de manera confiable.  

Los puntos clave que debemos recordar son que las race conditions son la causa raíz de la mayoría de los bugs en programas concurrentes, difíciles de reproducir y depurar porque dependen del timing. La sección crítica debe protegerse con primitivas de sincronización apropiadas, eligiendo la herramienta correcta para cada problema. Los semáforos emergieron como la herramienta más versátil, permitiendo exclusión mutua, limitación de recursos, y sincronización de eventos con un único mecanismo. Finalmente, el overhead de sincronización debe balancearse cuidadosamente con las necesidades de concurrencia: demasiada sincronización serializa el programa innecesariamente, muy poca causa race conditions.  

La sincronización conecta con prácticamente todos los temas del sistema operativo. El scheduling interactúa con sincronización cuando procesos bloqueados en semáforos van a colas de espera, cambiando su estado de running a blocked. El deadlock puede prevenirse con diseño cuidadoso del orden de adquisición de recursos, tema que exploraremos en profundidad en el próximo capítulo. Memory management requiere sincronización para mantener coherencia de caché cuando múltiples cores acceden a memoria compartida. Los sistemas de archivos usan sincronización para controlar acceso concurrente a archivos y directorios. Finalmente, las redes requieren sincronización tanto a nivel local (acceso a sockets) como en sistemas distribuidos donde procesos en diferentes máquinas deben coordinarse.  

Con este fundamento sólido en sincronización, estamos preparados para enfrentar el próximo gran desafío: detectar, prevenir y recuperarnos de deadlocks, donde la sincronización mal aplicada puede llevar al sistema a un estado de bloqueo permanente.

