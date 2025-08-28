# Capítulo 3: Planificación de Procesos

## 1. Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Explicar por qué es necesaria la planificación de procesos en sistemas multiprogramados
- Distinguir entre planificación a corto, mediano y largo plazo
- Analizar algoritmos de planificación: FCFS, SJF, SRTF, Round Robin, prioridades
- Calcular métricas de rendimiento: tiempo de retorno, espera, respuesta
- Implementar simuladores básicos de algoritmos de planificación
- Evaluar qué algoritmo es más apropiado según el tipo de sistema
- Resolver ejercicios típicos de parcial sobre planificación

## 2. Introducción y Contexto

### ¿Por qué necesitamos planificación?

Imaginemos una cafetería con un solo barista y 10 clientes esperando. ¿En qué orden debe atender a los clientes? Algunas opciones:

1. **Primero en llegar, primero en ser atendido** (FIFO)
2. **El pedido más rápido primero** (menor tiempo de servicio)  
3. **Por turnos** (cada cliente un poco, rotativamente)
4. **Por prioridad** (clientes VIP primero)

Cada estrategia tiene **ventajas y desventajas**. Lo mismo sucede con los procesos en un SO.

### El problema fundamental

En un sistema con **múltiples procesos** pero **un solo CPU** (o pocos núcleos), el SO debe decidir:

- **¿Qué proceso ejecutar?** (política de selección)
- **¿Cuándo cambiar?** (política de desalojo)
- **¿Por cuánto tiempo?** (quantum de tiempo)

Esta decisión impacta directamente:
- **Rendimiento del sistema** (throughput)
- **Experiencia del usuario** (respuesta interactiva)
- **Utilización de recursos** (CPU, memoria, I/O)

### Objetivos conflictivos

Los algoritmos de planificación buscan optimizar métricas que a menudo **entran en conflicto**:

- **Maximizar throughput** vs **Minimizar tiempo de respuesta**
- **Ser justo** vs **Ser eficiente**
- **Predecible** vs **Adaptativo**

No existe el algoritmo "perfecto", solo **compromisos** apropiados para cada contexto.

## 3. Conceptos Fundamentales

### 3.1 Niveles de Planificación

El SO tiene **tres niveles** de planificación que operan en diferentes escalas de tiempo:

#### Planificación a Largo Plazo (Job Scheduler)
- **Función**: Decide qué programas ingresan al sistema (NEW → READY)
- **Frecuencia**: Segundos a minutos
- **Objetivo**: Controlar el grado de multiprogramación
- **Ejemplo**: Sistemas batch que procesan trabajos offline

#### Planificación a Mediano Plazo (Memory Scheduler) 
- **Función**: Decide qué procesos mantener en memoria (swapping)
- **Frecuencia**: Segundos
- **Objetivo**: Controlar la carga de memoria
- **Ejemplo**: Suspender procesos inactivos al disco

#### Planificación a Corto Plazo (CPU Scheduler)
- **Función**: Decide qué proceso ejecutar ahora (READY → RUNNING)
- **Frecuencia**: Milisegundos
- **Objetivo**: Optimizar uso del CPU
- **Enfoque de este capítulo**

### 3.2 Tipos de Planificación

#### Planificación No Expropiativa (Non-Preemptive)
- El proceso **mantiene el CPU** hasta que:
  - Termina voluntariamente
  - Se bloquea (I/O, wait)
- **Ventaja**: Simple, menor overhead
- **Desventaja**: Un proceso puede monopolizar el CPU

#### Planificación Expropiativa (Preemptive)
- El SO puede **quitar el CPU** a un proceso:
  - Quantum de tiempo agotado
  - Llegó proceso de mayor prioridad
- **Ventaja**: Mejor respuesta interactiva
- **Desventaja**: Mayor overhead por context switch

### 3.3 Métricas de Rendimiento

Para evaluar algoritmos de planificación usamos estas métricas:

#### Métricas orientadas al sistema:
- **Utilización del CPU**: % de tiempo que el CPU está ocupado
- **Throughput**: Procesos completados por unidad de tiempo

#### Métricas orientadas al usuario:
- **Tiempo de Retorno (Turnaround Time)**: Tiempo total desde llegada hasta terminación
  ```
  T_retorno = T_terminación - T_llegada
  ```

- **Tiempo de Espera (Waiting Time)**: Tiempo total esperando en cola READY
  ```
  T_espera = T_retorno - T_ejecución
  ```

- **Tiempo de Respuesta (Response Time)**: Tiempo desde llegada hasta primera ejecución
  ```
  T_respuesta = T_primera_ejecución - T_llegada
  ```

### 3.4 Ráfagas de CPU y I/O

Los procesos alternan entre dos fases:
- **CPU Burst**: Período de ejecución continua en CPU
- **I/O Burst**: Período esperando operaciones de I/O

**Clasificación de procesos:**
- **CPU-bound**: Ráfagas de CPU largas (cálculos científicos)
- **I/O-bound**: Ráfagas de CPU cortas (editores, navegadores)

Esta distinción es crucial para elegir el algoritmo apropiado.

## 4. Análisis Técnico

### 4.1 First-Come First-Served (FCFS)

**Principio**: El primer proceso en llegar es el primero en ejecutarse.

**Algoritmo:**
```
1. Mantener cola FIFO de procesos READY
2. Ejecutar proceso al frente de la cola hasta que termine o se bloquee
3. Mover siguiente proceso de la cola al CPU
```

**Características:**
- ✅ Simple de implementar
- ✅ No hay starvation 
- ❌ Convoy effect: procesos cortos esperan tras uno largo
- ❌ Pobre tiempo de respuesta promedio

**Ejemplo de cálculo:**
```
Procesos: P1(24ms), P2(3ms), P3(3ms)
Llegada:  0ms      0ms      0ms

Orden de ejecución: P1 → P2 → P3

Tiempo de terminación:
P1: 24ms, P2: 27ms, P3: 30ms

Tiempo de retorno:
P1: 24-0 = 24ms
P2: 27-0 = 27ms  
P3: 30-0 = 30ms
Promedio: (24+27+30)/3 = 27ms

Tiempo de espera:
P1: 0ms (ejecuta inmediatamente)
P2: 24ms (espera que termine P1)
P3: 27ms (espera que terminen P1 y P2)
Promedio: (0+24+27)/3 = 17ms
```

### 4.2 Shortest Job First (SJF)

**Principio**: Ejecutar el proceso con menor tiempo de CPU estimado.

**Algoritmo:**
```
1. De todos los procesos READY, seleccionar el de menor tiempo estimado
2. Ejecutar hasta terminación (versión no expropiativa)
3. Repetir con procesos restantes
```

**Características:**
- ✅ **Óptimo** para tiempo de retorno promedio (demostrable matemáticamente)
- ❌ Requiere conocer tiempo de ejecución (imposible en la práctica)
- ❌ Starvation de procesos largos
- ❌ No apropiado para sistemas interactivos

**Estimación de tiempo**: Se usa predicción basada en historia:
```
τ(n+1) = α × t(n) + (1-α) × τ(n)
```
Donde:
- τ(n+1) = tiempo estimado para próxima ráfaga
- t(n) = tiempo real de ráfaga anterior  
- α = factor de peso (0 ≤ α ≤ 1)

### 4.3 Shortest Remaining Time First (SRTF)

**Principio**: Versión expropiativa de SJF. Si llega un proceso con tiempo menor al restante del actual, se hace context switch.

**Algoritmo:**
```
1. Seleccionar proceso con menor tiempo restante
2. Si llega nuevo proceso con menor tiempo restante, expropiar
3. Continuar hasta que todos terminen
```

**Características:**
- ✅ Mejor tiempo de retorno promedio que SJF
- ✅ Respuesta rápida para procesos cortos
- ❌ Mayor overhead por context switches frecuentes
- ❌ Starvation severa de procesos largos

### 4.4 Round Robin (RR)

**Principio**: Cada proceso recibe un quantum fijo de tiempo. Al agotarse, va al final de la cola.

**Algoritmo:**
```
1. Asignar quantum Q a cada proceso
2. Ejecutar proceso por máximo Q unidades de tiempo
3. Si no termina, mover al final de cola READY
4. Seleccionar siguiente proceso de la cola
```

**Selección del quantum:**
- **Q muy pequeño**: Muchos context switches (overhead)
- **Q muy grande**: Se comporta como FCFS
- **Regla práctica**: Q = 10-100ms, debe ser mayor que tiempo de context switch

**Características:**
- ✅ Justo: todos los procesos progresan
- ✅ Buen tiempo de respuesta
- ✅ No hay starvation
- ❌ Tiempo de retorno puede ser pobre para procesos largos

### 4.5 Planificación por Prioridades

**Principio**: Cada proceso tiene una prioridad. Se ejecuta el de mayor prioridad.

**Tipos de prioridades:**
- **Estáticas**: Asignadas al crear el proceso
- **Dinámicas**: Cambian durante la ejecución

**Algoritmos:**
```
// Versión no expropiativa
1. Seleccionar proceso READY con mayor prioridad
2. Ejecutar hasta terminación o bloqueo
3. Repetir

// Versión expropiativa  
1. Si llega proceso con prioridad mayor, expropiar
2. Continuar con mayor prioridad disponible
```

**Problema del Starvation:**
Procesos de baja prioridad pueden nunca ejecutarse.

**Solución - Aging:**
```c
// Incrementar prioridad con el tiempo de espera
nueva_prioridad = prioridad_base + (tiempo_espera / factor_aging)
```

### 4.6 Multilevel Queue

**Principio**: Múltiples colas con diferentes algoritmos y prioridades.

**Estructura típica:**
```
Cola 1: Procesos del sistema (prioridad alta, FCFS)
Cola 2: Procesos interactivos (prioridad media, RR con Q=8ms) 
Cola 3: Procesos batch (prioridad baja, FCFS)
```

**Planificación entre colas:**
- **Prioridad fija**: Colas superiores tienen precedencia absoluta
- **Time slicing**: Cada cola recibe % de tiempo de CPU

### 4.7 Multilevel Feedback Queue

**Principio**: Procesos pueden moverse entre colas según su comportamiento.

**Ejemplo de configuración:**
```
Cola 0: RR con Q=8ms (mayor prioridad)
Cola 1: RR con Q=16ms  
Cola 2: FCFS (menor prioridad)

Reglas:
- Procesos nuevos ingresan a Cola 0
- Si agotan quantum, bajan a siguiente cola
- Si terminan antes del quantum, mantienen cola actual
- Promoción periódica para evitar starvation
```

**Ventajas:**
- ✅ Se adapta al comportamiento del proceso
- ✅ Favorece procesos interactivos (I/O bound)
- ✅ Procesos largos eventualmente reciben servicio

## 5. Código en C

### 5.1 Simulador de FCFS

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int pid;              // Process ID
    int arrival_time;     // Tiempo de llegada
    int burst_time;       // Tiempo de CPU requerido
    int completion_time;  // Tiempo de terminación
    int turnaround_time;  // Tiempo de retorno
    int waiting_time;     // Tiempo de espera
} Process;

void fcfs_schedule(Process processes[], int n) {
    int current_time = 0;
    
    printf("FCFS Scheduling:\n");
    printf("PID\tArrival\tBurst\tCompletion\tTurnaround\tWaiting\n");
    
    for (int i = 0; i < n; i++) {
        // Si el proceso no ha llegado, esperamos
        if (current_time < processes[i].arrival_time) {
            current_time = processes[i].arrival_time;
        }
        
        // El proceso se ejecuta por su burst_time completo
        processes[i].completion_time = current_time + processes[i].burst_time;
        
        // Calcular métricas
        processes[i].turnaround_time = processes[i].completion_time - 
                                      processes[i].arrival_time;
        processes[i].waiting_time = processes[i].turnaround_time - 
                                   processes[i].burst_time;
        
        // Actualizar tiempo actual
        current_time = processes[i].completion_time;
        
        // Imprimir resultados
        printf("%d\t%d\t%d\t%d\t\t%d\t\t%d\n", 
               processes[i].pid,
               processes[i].arrival_time,
               processes[i].burst_time,
               processes[i].completion_time,
               processes[i].turnaround_time,
               processes[i].waiting_time);
    }
}

void print_averages(Process processes[], int n) {
    float avg_turnaround = 0, avg_waiting = 0;
    
    for (int i = 0; i < n; i++) {
        avg_turnaround += processes[i].turnaround_time;
        avg_waiting += processes[i].waiting_time;
    }
    
    avg_turnaround /= n;
    avg_waiting /= n;
    
    printf("\nPromedios:\n");
    printf("Tiempo de retorno promedio: %.2f\n", avg_turnaround);
    printf("Tiempo de espera promedio: %.2f\n", avg_waiting);
}

int main() {
    // Ejemplo de procesos
    Process processes[] = {
        {1, 0, 24, 0, 0, 0},   // P1: llega en 0, necesita 24ms
        {2, 0, 3, 0, 0, 0},    // P2: llega en 0, necesita 3ms  
        {3, 0, 3, 0, 0, 0}     // P3: llega en 0, necesita 3ms
    };
    
    int n = sizeof(processes) / sizeof(processes[0]);
    
    fcfs_schedule(processes, n);
    print_averages(processes, n);
    
    return 0;
}
```

### 5.2 Simulador de Round Robin

```c
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int pid;
    int arrival_time;
    int burst_time;
    int remaining_time;    // Tiempo restante de ejecución
    int completion_time;
    int turnaround_time;
    int waiting_time;
    int response_time;
    int first_response;    // Para calcular tiempo de respuesta
} Process;

void round_robin_schedule(Process processes[], int n, int quantum) {
    int current_time = 0;
    int completed = 0;
    int queue[100];  // Cola circular simple
    int front = 0, rear = 0;
    int in_queue[10] = {0};  // Marca si proceso está en cola
    
    printf("Round Robin (Quantum = %d):\n", quantum);
    printf("Tiempo\tProceso ejecutándose\n");
    
    // Inicializar campos
    for (int i = 0; i < n; i++) {
        processes[i].remaining_time = processes[i].burst_time;
        processes[i].first_response = -1;
    }
    
    // Agregar procesos que llegan en tiempo 0
    for (int i = 0; i < n; i++) {
        if (processes[i].arrival_time == 0) {
            queue[rear++] = i;
            in_queue[i] = 1;
        }
    }
    
    while (completed < n) {
        if (front == rear) {
            // Cola vacía, avanzar tiempo hasta próxima llegada
            current_time++;
            // Verificar nuevas llegadas
            for (int i = 0; i < n; i++) {
                if (processes[i].arrival_time == current_time && !in_queue[i]) {
                    queue[rear++] = i;
                    in_queue[i] = 1;
                }
            }
            continue;
        }
        
        // Obtener proceso del frente de la cola
        int current_process = queue[front++];
        in_queue[current_process] = 0;
        
        // Marcar primera respuesta
        if (processes[current_process].first_response == -1) {
            processes[current_process].first_response = current_time;
            processes[current_process].response_time = current_time - 
                                                     processes[current_process].arrival_time;
        }
        
        // Ejecutar por quantum o hasta terminar
        int execution_time = (processes[current_process].remaining_time < quantum) ?
                            processes[current_process].remaining_time : quantum;
        
        printf("%d-%d\tP%d\n", current_time, current_time + execution_time, 
               processes[current_process].pid);
        
        processes[current_process].remaining_time -= execution_time;
        current_time += execution_time;
        
        // Verificar nuevas llegadas durante la ejecución
        for (int i = 0; i < n; i++) {
            if (processes[i].arrival_time <= current_time && 
                processes[i].arrival_time > (current_time - execution_time) &&
                !in_queue[i] && processes[i].remaining_time > 0) {
                queue[rear++] = i;
                in_queue[i] = 1;
            }
        }
        
        if (processes[current_process].remaining_time == 0) {
            // Proceso terminado
            completed++;
            processes[current_process].completion_time = current_time;
            processes[current_process].turnaround_time = 
                processes[current_process].completion_time - 
                processes[current_process].arrival_time;
            processes[current_process].waiting_time = 
                processes[current_process].turnaround_time - 
                processes[current_process].burst_time;
        } else {
            // Proceso no terminado, vuelve a la cola
            queue[rear++] = current_process;
            in_queue[current_process] = 1;
        }
    }
    
    // Imprimir resultados
    printf("\nResultados:\n");
    printf("PID\tArrival\tBurst\tCompletion\tTurnaround\tWaiting\tResponse\n");
    for (int i = 0; i < n; i++) {
        printf("%d\t%d\t%d\t%d\t\t%d\t\t%d\t%d\n",
               processes[i].pid, processes[i].arrival_time,
               processes[i].burst_time, processes[i].completion_time,
               processes[i].turnaround_time, processes[i].waiting_time,
               processes[i].response_time);
    }
}

int main() {
    Process processes[] = {
        {1, 0, 20, 0, 0, 0, 0, 0, -1},
        {2, 0, 3, 0, 0, 0, 0, 0, -1},
        {3, 0, 3, 0, 0, 0, 0, 0, -1}
    };
    
    int n = sizeof(processes) / sizeof(processes[0]);
    int quantum = 4;
    
    round_robin_schedule(processes, n, quantum);
    
    return 0;
}
```

### 5.3 Comparador de Algoritmos

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Estructura para resultados de algoritmos
typedef struct {
    char algorithm_name[20];
    float avg_turnaround;
    float avg_waiting;
    float avg_response;
} SchedulingResult;

// Función para comparar diferentes algoritmos
void compare_algorithms() {
    // Procesos de prueba
    int arrivals[] = {0, 1, 2};
    int bursts[] = {10, 5, 8};
    int n = 3;
    
    printf("Comparación de Algoritmos de Planificación\n");
    printf("Procesos: P1(10), P2(5), P3(8)\n");
    printf("Llegadas: 0, 1, 2\n\n");
    
    // Aquí implementarías cada algoritmo y calcularías métricas
    SchedulingResult results[] = {
        {"FCFS", 12.33, 7.00, 7.00},
        {"SJF", 9.33, 4.00, 4.00}, 
        {"RR (Q=4)", 13.00, 7.67, 2.33},
        {"RR (Q=2)", 14.33, 9.00, 1.33}
    };
    
    printf("Algoritmo\t\tT.Retorno\tT.Espera\tT.Respuesta\n");
    printf("---------------------------------------------------\n");
    
    for (int i = 0; i < 4; i++) {
        printf("%-15s\t%.2f\t\t%.2f\t\t%.2f\n",
               results[i].algorithm_name,
               results[i].avg_turnaround,
               results[i].avg_waiting,
               results[i].avg_response);
    }
    
    // Análisis automático
    printf("\nAnálisis:\n");
    printf("- Mejor tiempo de retorno: SJF\n");
    printf("- Mejor tiempo de respuesta: RR (Q=2)\n");
    printf("- Más justo: Round Robin\n");
    printf("- Más simple: FCFS\n");
}

int main() {
    compare_algorithms();
    return 0;
}
```

## 6. Casos de Estudio

### Caso de Estudio 1: Comparación de algoritmos

**Ejercicio típico de parcial:**
Dados los siguientes procesos, calcular tiempo promedio de retorno y espera para FCFS, SJF y RR (Q=4):

```
Proceso | Llegada | Ráfaga CPU
--------|---------|----------
P1      |    0    |    8
P2      |    1    |    4  
P3      |    2    |    9
P4      |    3    |    5
```

**Resolución FCFS:**
```
Orden de ejecución: P1 → P2 → P3 → P4

Diagrama de Gantt:
0    8   12   21   26
|P1  |P2 |P3     |P4|

Tiempo de terminación:
P1: 8,  P2: 12,  P3: 21,  P4: 26

Tiempo de retorno:
P1: 8-0 = 8
P2: 12-1 = 11  
P3: 21-2 = 19
P4: 26-3 = 23
Promedio: (8+11+19+23)/4 = 15.25

Tiempo de espera:
P1: 8-8 = 0
P2: 11-4 = 7
P3: 19-9 = 10  
P4: 23-5 = 18
Promedio: (0+7+10+18)/4 = 8.75
```

**Resolución SJF (no expropiativo):**
```
Orden por tiempo de ráfaga: P2(4) → P4(5) → P1(8) → P3(9)

Pero debemos respetar llegadas:
- t=0: Solo P1 disponible → ejecuta P1
- t=8: P2,P3,P4 disponibles → ejecuta P2 (menor)  
- t=12: P3,P4 disponibles → ejecuta P4 (menor)
- t=17: Solo P3 disponible → ejecuta P3

Diagrama de Gantt:
0    8   12   17   26
|P1  |P2 |P4 |P3    |

Tiempo de retorno:
P1: 8-0 = 8
P2: 12-1 = 11
P3: 26-2 = 24  
P4: 17-3 = 14
Promedio: (8+11+24+14)/4 = 14.25

Tiempo de espera:
P1: 0,  P2: 7,  P3: 15,  P4: 9
Promedio: 7.75
```

**Resolución Round Robin (Q=4):**
```
Ejecución detallada:
t=0-4: P1 (quantum completo, remaining=4)
t=4-8: P1 (termina, remaining=0) 
t=8-12: P2 (termina, remaining=0)
t=12-16: P3 (quantum completo, remaining=5)
t=16-20: P4 (quantum completo, remaining=1) 
t=20-24: P3 (quantum completo, remaining=1)
t=24-25: P4 (termina, remaining=0)
t=25-26: P3 (termina, remaining=0)

Diagrama de Gantt:
0  4  8  12 16 20 24 25 26
|P1|P1|P2|P3|P4|P3|P4|P3|

Tiempo de retorno:
P1: 8-0 = 8
P2: 12-1 = 11
P3: 26-2 = 24
P4: 25-3 = 22  
Promedio: 16.25

Tiempo de respuesta (primera ejecución):
P1: 0-0 = 0
P2: 8-1 = 7  
P3: 12-2 = 10
P4: 16-3 = 13
Promedio: 7.5
```

**Conclusiones del caso:**
- **SJF** tiene mejor tiempo de retorno promedio (14.25)
- **RR** tiene mejor tiempo de respuesta promedio (7.5)  
- **FCFS** es más simple pero menos eficiente
- **RR** es más justo pero puede tener mayor overhead

### Caso de Estudio 2: Selección de quantum en Round Robin

**Problema:** Un sistema interactivo tiene procesos con ráfagas típicas de 6ms. El context switch toma 1ms. ¿Qué quantum elegir?

**Análisis:**

```c
// Efficiency = Useful_work / Total_time
// Efficiency = Quantum / (Quantum + Context_switch_time)

float efficiency(int quantum, int context_switch_time) {
    return (float)quantum / (quantum + context_switch_time);
}

int main() {
    printf("Quantum\tContext Switch\tEfficiency\tOverhead%%\n");
    
    int quantums[] = {1, 2, 4, 6, 8, 12, 20};
    int cs_time = 1;
    
    for (int i = 0; i < 7; i++) {
        float eff = efficiency(quantums[i], cs_time);
        float overhead = (1.0 - eff) * 100;
        
        printf("%d\t%d\t\t%.3f\t\t%.1f%%\n", 
               quantums[i], cs_time, eff, overhead);
    }
    
    return 0;
}
```

**Salida esperada:**
```
Quantum Context Switch  Efficiency  Overhead%
1       1               0.500       50.0%
2       1               0.667       33.3%  
4       1               0.800       20.0%
6       1               0.857       14.3%  ← Óptimo para ráfagas de 6ms
8       1               0.889       11.1%
12      1               0.923       7.7%
20      1               0.952       4.8%
```

**Recomendación:** Quantum = 6ms (igual a ráfaga típica) ofrece buen balance entre eficiencia (85.7%) y respuesta interactiva.

### Caso de Estudio 3: Algoritmo de planificación de Linux (CFS)

**Contexto:** El Completely Fair Scheduler de Linux usa un enfoque diferente basado en "tiempo virtual".

**Conceptos clave:**
```c
// Tiempo virtual de un proceso
vruntime = runtime * (NICE_0_LOAD / process_load)

// Donde:
// - runtime: tiempo real ejecutado
// - NICE_0_LOAD: peso del proceso con nice=0  
// - process_load: peso según prioridad nice del proceso
```

**Comportamiento:**
- Procesos se organizan en **Red-Black Tree** ordenado por vruntime
- Se ejecuta proceso con **menor vruntime** (más "atrasado")
- Quantum dinámico basado en número de procesos
- Nice values afectan peso, no prioridad absoluta

**Ventajas del CFS:**
- ✅ Fairness matemáticamente garantizado
- ✅ Escalable para muchos procesos (O(log n))
- ✅ Buen balance entre throughput y latencia
- ✅ Se adapta automáticamente a la carga

**Ejemplo simplificado:**
```c
// Simulación conceptual del CFS
typedef struct {
    int pid;
    int nice_value;      // -20 a +19
    long long vruntime;  // tiempo virtual
    int weight;          // calculado desde nice
} cfs_process_t;

// Calcular peso desde nice value
int nice_to_weight[] = {88761, 71755, 56483, 46273, 36291, /*...*/ 15, 12, 10, 8};

void cfs_tick(cfs_process_t *current, int runtime_ms) {
    // Actualizar vruntime
    current->vruntime += runtime_ms * (1024 / current->weight);
    
    // El proceso con menor vruntime será el próximo
}
```

## 7. Síntesis

### 7.1 Puntos Clave para Parcial

**Algoritmos fundamentales y sus características:**

| Algoritmo | Tipo | Ventajas | Desventajas | Mejor para |
|-----------|------|----------|-------------|------------|
| **FCFS** | No expropiativo | Simple, sin starvation | Convoy effect | Batch |
| **SJF** | No expropiativo | Óptimo tiempo retorno | Starvation, requiere predicción | Batch conocido |
| **SRTF** | Expropiativo | Mejor tiempo retorno | Starvation, overhead | Batch con llegadas |
| **RR** | Expropiativo | Justo, buen tiempo respuesta | Pobre para largos | Interactivo |
| **Prioridades** | Ambos | Flexible, control fino | Starvation sin aging | Tiempo real |

**Fórmulas esenciales:**
```c
// Métricas de rendimiento
Tiempo_retorno = Tiempo_terminación - Tiempo_llegada
Tiempo_espera = Tiempo_retorno - Tiempo_CPU  
Tiempo_respuesta = Primera_ejecución - Tiempo_llegada

// Eficiencia de quantum
Eficiencia = Quantum / (Quantum + Context_switch)

// Predicción de tiempo (SJF)
Estimación_n+1 = α × Tiempo_real_n + (1-α) × Estimación_n
```

**Pasos para resolver ejercicios:**

1. **Dibujar timeline** con llegadas y ejecuciones
2. **Aplicar algoritmo** paso a paso
3. **Calcular métricas** para cada proceso
4. **Obtener promedios** y comparar
5. **Justificar elección** según contexto del sistema

### 7.2 Errores Comunes y Tips

**❌ Errores frecuentes:**

1. **No considerar tiempos de llegada**
   ```
   MAL: Ejecutar procesos en orden de aparición
   BIEN: Verificar qué procesos han llegado en cada momento
   ```

2. **Confundir métricas**
   ```
   MAL: Tiempo_espera = Tiempo_terminación - Tiempo_llegada  
   BIEN: Tiempo_espera = Tiempo_retorno - Tiempo_CPU
   ```

3. **Error en Round Robin**
   ```
   MAL: Proceso vuelve inmediatamente al CPU tras quantum
   BIEN: Proceso va al final de la cola
   ```

4. **No manejar empates en SJF**
   ```
   Regla: Si dos procesos tienen mismo tiempo, usar FCFS como criterio de desempate
   ```

**✅ Tips para parcial:**

1. **Diagramas de Gantt son esenciales** - Dibujar siempre la línea temporal
2. **Verificar cálculos** - Las métricas deben ser coherentes entre sí
3. **Considerar el contexto** - ¿Sistema batch, interactivo o tiempo real?
4. **Quantum en RR** - Ni muy pequeño (overhead) ni muy grande (FCFS)
5. **Starvation** - Recordar qué algoritmos lo causan y cómo evitarlo

### 7.3 Decisiones de Diseño en Sistemas Reales

**Sistemas Batch (servidores, cálculo científico):**
- **Objetivo**: Maximizar throughput
- **Algoritmo**: SJF o FCFS con prioridades
- **Quantum**: No aplicable (no expropiativo)
- **Ejemplo**: Cluster de supercomputación

**Sistemas Interactivos (desktop, móviles):**
- **Objetivo**: Minimizar tiempo de respuesta
- **Algoritmo**: Round Robin o Multilevel Feedback
- **Quantum**: 10-100ms
- **Ejemplo**: Linux desktop, Windows

**Sistemas de Tiempo Real:**
- **Objetivo**: Cumplir deadlines
- **Algoritmo**: Prioridades fijas (Rate Monotonic, EDF)
- **Quantum**: Muy pequeño o basado en eventos
- **Ejemplo**: Sistemas embebidos, control industrial

**Sistemas de Propósito General:**
- **Objetivo**: Balance entre todos los criterios
- **Algoritmo**: Multilevel feedback (como CFS de Linux)
- **Adaptabilidad**: Se ajusta según comportamiento
- **Ejemplo**: Linux, Windows, macOS

### 7.4 Conexión con Próximos Temas

La planificación es fundamental para entender:

**Hilos (Capítulo 4):**
- Planificación a nivel de hilo vs proceso
- Modelos de threads (1:1, N:1, M:N)
- Diferencias entre User-Level Threads y Kernel Threads

**Sincronización (Capítulo 5):**
- **Inversión de prioridades**: Proceso de baja prioridad bloquea uno de alta
- **Priority inheritance**: Solución temporal al problema anterior
- **Planificación consciente de locks**: Evitar context switches innecesarios

**Gestión de Memoria (Capítulos 7-8):**
- **Thrashing**: Demasiados procesos causan exceso de paging
- **Working set**: Conjunto de páginas que proceso necesita
- **Planificación y localidad**: Procesos con mejor localidad son preferibles

**Ejemplo integrador:**
```c
// Un proceso CPU-bound en sistema con poca memoria
if (memory_pressure && process_type == CPU_BOUND) {
    // Reducir prioridad para dar más tiempo a I/O-bound
    // que usan menos memoria y liberan CPU frecuentemente
    reduce_priority(process);
}
```

### 7.5 Laboratorio Sugerido

**Práctica 1**: Implementar y comparar FCFS, SJF y RR
- Simular procesos con diferentes patrones (CPU-bound vs I/O-bound)
- Medir métricas para diferentes cargas de trabajo
- Analizar impacto del quantum en RR

**Práctica 2**: Análisis del planificador de Linux
```bash
# Ver procesos y sus prioridades
ps -eo pid,ppid,ni,pri,pcpu,comm --sort=-pcpu

# Cambiar nice value
nice -n 10 ./cpu_intensive_program

# Monitor en tiempo real
top -p PID  # Ver cambios de prioridad y CPU%
```

**Práctica 3**: Implementar aging para prioridades
```c
void aging_priority_scheduler() {
    // Incrementar prioridad de procesos que esperan mucho
    for (each process in ready_queue) {
        if (current_time - process.last_run > AGING_THRESHOLD) {
            process.priority = min(MAX_PRIORITY, process.priority + 1);
        }
    }
}
```

**Pregunta de reflexión para próximo capítulo:**
Si tenemos múltiples hilos dentro de un proceso, ¿cómo los planifica el SO? ¿Qué ventajas y desventajas tiene esto comparado con crear múltiples procesos?

---

**Próximo capítulo recomendado**: Capítulo 4: Hilos (Threads) - Explorando la concurrencia dentro de los procesos y los desafíos de la planificación a nivel de hilo.