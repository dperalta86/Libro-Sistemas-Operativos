# Planificación de Procesos

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Explicar por qué es necesaria la planificación de procesos en sistemas multiprogramados
- Distinguir entre planificación a corto, mediano y largo plazo
- Analizar algoritmos de planificación: FCFS, SJF, SRT, Round Robin, VRR, HRRN, prioridades y feedback
- Determinar las características de cada algoritmo: preemptivo/no preemptivo, overhead, starvation, aging
- Calcular métricas de rendimiento: tiempo de espera y tiempo de respuesta
- Resolver ejercicios con diagramas de Gantt considerando interrupciones y prioridades
- Evaluar qué algoritmo es más apropiado según el tipo de sistema
- Aplicar criterios de desempate cuando múltiples procesos compiten simultáneamente

## Introducción y Contexto

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

## Conceptos Fundamentales

### Niveles de Planificación

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

### Tipos de Planificación

#### Planificación No Preemptiva (No Expropiativa)
- El proceso **mantiene el CPU** hasta que:
  - Termina voluntariamente
  - Se bloquea (I/O, wait)
- **Ventaja**: Simple, menor overhead
- **Desventaja**: Un proceso puede monopolizar el CPU

#### Planificación Preemptiva (Expropiativa)
- El SO puede **quitar el CPU** a un proceso:
  - Quantum de tiempo agotado
  - Llegó proceso de mayor prioridad
  - Interrupción de reloj
- **Ventaja**: Mejor respuesta interactiva
- **Desventaja**: Mayor overhead por context switch

### Métricas de Rendimiento

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

### Ráfagas de CPU y I/O

Los procesos alternan entre dos fases:
- **CPU Burst**: Período de ejecución continua en CPU
- **I/O Burst**: Período esperando operaciones de I/O

**Clasificación de procesos:**
- **CPU-bound**: Ráfagas de CPU largas (cálculos científicos)
- **I/O-bound**: Ráfagas de CPU cortas (editores, navegadores)

Esta distinción es crucial para elegir el algoritmo apropiado.

### Eventos que Provocan Planificación

La planificación puede ser invocada por diferentes eventos, con **prioridades específicas**:

1. **Interrupción de reloj** (Mayor prioridad)
   - Quantum agotado en algoritmos preemptivos
   - Permite que el SO retome control

2. **Interrupción de finalización de I/O** (Media prioridad)
   - Un proceso bloqueado se vuelve READY
   - Puede tener mayor prioridad que el proceso actual

3. **System call** (Menor prioridad)
   - Proceso actual se bloquea voluntariamente
   - El SO debe elegir el próximo proceso

**Criterio de desempate**: Si múltiples procesos llegan simultáneamente a READY, se aplica:
- Primero los de mayor prioridad
- En caso de empate: FCFS (orden de llegada)

## Análisis Técnico

### First-Come First-Served (FCFS)

**Principio**: El primer proceso en llegar es el primero en ejecutarse.

**Características:**
- **Tipo**: No preemptivo  
- **Overhead**: Mínimo  
- **Starvation**: No (todos eventualmente ejecutan)  

**Algoritmo:**
```
1. Mantener cola FIFO de procesos READY
2. Ejecutar proceso al frente de la cola hasta que termine o se bloquee
3. Mover siguiente proceso de la cola al CPU
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Simple de implementar\\
- No hay starvation\\
- Predecible\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Convoy effect: procesos cortos esperan tras uno largo\\
- Pobre tiempo de respuesta promedio\\
- No aprovecha paralelismo I/O-CPU\\
}

### Shortest Job First (SJF)

**Principio**: Ejecutar el proceso con menor tiempo de CPU estimado.

**Características:**
- **Tipo**: No preemptivo (versión básica)  
- **Overhead**: Bajo  
- **Starvation**: Sí (procesos largos pueden nunca ejecutar)  
- **Aging**: Necesario para evitar starvation  

**Algoritmo:**
```
1. De todos los procesos READY, seleccionar el de menor tiempo estimado
2. Ejecutar hasta terminación (versión no preemptiva)
3. Repetir con procesos restantes
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Óptimo para tiempo de retorno promedio (demostrable matemáticamente)\\
- Minimiza tiempo de espera promedio\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Requiere conocer tiempo de ejecución (imposible en la práctica)\\
- Starvation de procesos largos\\
- No apropiado para sistemas interactivos\\
}

**Estimación de tiempo**: Se usa predicción basada en historia:
```
τ(n+1) = α × t(n) + (1-α) × τ(n)
```
Donde:
- τ(n+1) = tiempo estimado para próxima ráfaga  
- t(n) = tiempo real de ráfaga anterior  
- α = factor de peso (0 ≤ α ≤ 1)  

### Shortest Remaining Time (SRT)

**Principio**: Versión preemptiva de SJF. Si llega un proceso con tiempo menor al restante del actual, se hace context switch.

**Características:**
- **Tipo**: Preemptivo  
- **Overhead**: Alto (muchos context switches)  
- **Starvation**: Severa (peor que SJF)  
- **Aging**: Crítico para funcionar  

**Algoritmo:**
```
1. Seleccionar proceso con menor tiempo restante
2. Si llega nuevo proceso con menor tiempo restante, expropiar
3. Actualizar tiempo restante del proceso expropiado
4. Continuar hasta que todos terminen
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Mejor tiempo de retorno promedio que SJF\\
- Respuesta rápida para procesos cortos que llegan tarde\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Mayor overhead por context switches frecuentes\\
- Starvation severa de procesos largos\\
- Impredecible para procesos largos\\
}

### Round Robin (RR)

**Principio**: Cada proceso recibe un quantum fijo de tiempo. Al agotarse, va al final de la cola.

**Características:**
- **Tipo**: Preemptivo (por quantum)  
- **Overhead**: Medio (depende del quantum)  
- **Starvation**: No  
- **Aging**: No necesario  

**Algoritmo:**
```
1. Asignar quantum Q a cada proceso
2. Ejecutar proceso por máximo Q unidades de tiempo
3. Si no termina, mover al final de cola READY
4. Si se bloquea antes de Q, no pierde el quantum restante
5. Seleccionar siguiente proceso de la cola
```

**Selección del quantum:**
- **Q muy pequeño**: Muchos context switches (overhead alto)  
- **Q muy grande**: Se comporta como FCFS  
- **Regla práctica**: Q = 10-100ms, debe ser mayor que tiempo de context switch  

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Justo: todos los procesos progresan\\
- Buen tiempo de respuesta\\
- No hay starvation\\
- Predecible\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Tiempo de retorno puede ser pobre para procesos largos\\
- Overhead de context switch\\
- No favorece procesos interactivos\\
}

### Virtual Round Robin (VRR)

**Principio**: Round Robin mejorado que da prioridad a procesos que se bloquearon antes de agotar su quantum.

**Características:**
- **Tipo**: Preemptivo con dos colas  
- **Overhead**: Medio-alto  
- **Starvation**: No  
- **Aging**: Implícito

**Algoritmo:**
```
1. Mantener dos colas: READY y AUXILIARY
2. Procesos nuevos y que agotaron quantum van a READY
3. Procesos que se bloquearon antes del quantum van a AUXILIARY
4. AUXILIARY tiene prioridad sobre READY
5. Procesos de AUXILIARY ejecutan con quantum restante
```
\textcolor{teal!60!black}{\textbf{Ventajas:\\}
 - Favorece procesos I/O-bound (más interactivos)\\
 - Mejor respuesta que RR puro\\
 - Mantiene fairness de RR\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Mayor complejidad de implementación\\
- Overhead adicional por doble cola\\
}

### Highest Response Ratio Next (HRRN)

**Principio**: Selecciona el proceso con mayor ratio de respuesta, balanceando tiempo de espera y tiempo de servicio.

**Características:**
- **Tipo**: No preemptivo  
- **Overhead**: Medio (cálculo de ratios)  
- **Starvation**: No (aging automático)  
- **Aging**: Incorporado en la fórmula  

**Algoritmo:**
```
1. Para cada proceso READY, calcular:
   Response Ratio = (Tiempo_espera + Tiempo_servicio) / Tiempo_servicio
2. Seleccionar proceso con mayor ratio
3. Ejecutar hasta terminación o bloqueo
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Combina ventajas de SJF y FCFS\\
- Aging automático previene starvation\\  
- Favorece trabajos cortos pero no ignora largos\\
}  

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Requiere estimar tiempo de servicio\\
- Cálculo adicional en cada decisión\\
- No preemptivo\\
}

### Planificación por Prioridades

**Principio**: Cada proceso tiene una prioridad. Se ejecuta el de mayor prioridad disponible.

**Características:**
- **Tipo**: Puede ser preemptivo o no preemptivo  
- **Overhead**: Bajo-medio  
- **Starvation**: Sí (sin aging)  
- **Aging**: Esencial para funcionamiento práctico  

**Tipos de prioridades:**
- **Estáticas**: Asignadas al crear el proceso  
- **Dinámicas**: Cambian durante la ejecución  

**Algoritmos:**
```
// Versión no preemptiva
1. Seleccionar proceso READY con mayor prioridad
2. Ejecutar hasta terminación o bloqueo
3. Repetir

// Versión preemptiva  
1. Si llega proceso con prioridad mayor, expropiar
2. Continuar con mayor prioridad disponible
```

**Problema del Starvation**: Procesos de baja prioridad pueden nunca ejecutarse.

**Solución - Aging**: Incrementar prioridad gradualmente
```
nueva_prioridad = prioridad_base + (tiempo_espera / factor_aging)
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Flexible y configurable\\
- Apropiado para tiempo real\\
- Control fino del sistema\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Starvation sin aging\\
- Dificultad para asignar prioridades apropiadas\\
- Puede ser unfair\\
}

### Multilevel Feedback Queue

**Principio**: Múltiples colas con diferentes algoritmos y prioridades. Los procesos pueden moverse entre colas según su comportamiento.

**Características:**
- **Tipo**: Preemptivo con múltiples niveles  
- **Overhead**: Alto  
- **Starvation**: Posible sin aging  
- **Aging**: Necesario (promoción entre colas)  

**Ejemplo de configuración:**
```
Cola 0: RR con Q=8ms (mayor prioridad) - Procesos nuevos
Cola 1: RR con Q=16ms                  - Procesos que agotaron Q en Cola 0  
Cola 2: FCFS (menor prioridad)         - Procesos que agotaron Q en Cola 1

Reglas:
- Procesos nuevos ingresan a Cola 0
- Si agotan quantum, bajan a siguiente cola
- Si se bloquean antes del quantum, mantienen cola actual
- Promoción periódica para evitar starvation
```

\textcolor{teal!60!black}{\textbf{Ventajas:\\}
- Se adapta al comportamiento del proceso\\
- Favorece procesos interactivos (I/O bound)\\
- Procesos largos eventualmente reciben servicio\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Complejidad alta de implementación\\
- Difícil de tunear parámetros\\
- Overhead considerable\\
}

## Casos de Estudio

### Caso de Estudio: Planificación con Round Robin

**Problema**: Dados 4 procesos con las siguientes características, realizar planificación con Round Robin (Q=3) y calcular tiempo promedio de espera y respuesta.

```
Proceso | Llegada | CPU Burst | I/O Burst | CPU Burst 2
--------|---------|-----------|-----------|------------
P1      |    0    |     5     |     2     |     3
P2      |    1    |     3     |     1     |     2  
P3      |    2    |     4     |     -     |     -
P4      |    3    |     2     |     3     |     1
```

**Solución con Round Robin (Q=3):**

\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap03-gantt-RR.png}
\end{center}


**Desarrollo paso a paso:**

```
t=0: P1 llega, inicia ejecución (Q=3)
t=1: P2 llega, se agrega a cola READY [P2]
t=2: P3 llega, cola READY [P2,P3]
t=3: P1 agota quantum (ejecutó 3/5), cola READY [P2,P3,P1], P2 inicia
t=3: P4 llega, cola READY [P3,P1,P4]
t=6: P2 termina ráfaga CPU (3/3), va a I/O, P3 inicia
t=7: P2 termina I/O, cola READY [P1,P4,P2]
t=9: P3 agota quantum (ejecutó 3/4), P4 inicia, cola READY [P1,P2,P3]
t=11: P4 termina ráfaga CPU (2/2), va a I/O, P1 inicia
t=13: P1 termina ráfaga restante (2/2), va a I/O, P2 inicia
t=14: P1 y P4 terminan I/O, P2 ejecuta último burst (1ms)
t=14: P2 termina completamente
t=15: P3 termina ráfaga restante (1ms), termina completamente
t=15: P1 inicia ráfaga final (3ms)  
t=17: P1 agota quantum (ejecutó 2/3), P4 inicia
t=18: P1 termina completamente
t=19: P4 termina ráfaga final (1ms), termina completamente
```

**Cálculos de métricas:**

```
Tiempos de terminación:
P1: 18, P2: 14, P3: 15, P4: 19

Tiempos de retorno:
P1: 18-0 = 18
P2: 14-1 = 13
P3: 15-2 = 13  
P4: 19-3 = 16
Promedio: (18+13+13+16)/4 = 15

Tiempos de espera:
P1: 18-(5+3) = 10
P2: 13-(3+2) = 8
P3: 13-4 = 9
P4: 16-(2+1) = 13
Promedio: (10+8+9+13)/4 = 10

Tiempo de respuesta (primera ejecución):
P1: 0-0 = 0
P2: 3-1 = 2
P3: 6-2 = 4
P4: 9-3 = 6
Promedio: (0+2+4+6)/4 = 3
```

### Caso de Estudio: Planificación con SJF

**Mismo conjunto de procesos con SJF no preemptivo:**

**Solución con SJF:**

\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap03-gantt-SJF.png}
\end{center}

**Desarrollo paso a paso:**

```
t=0: P1 llega, ejecuta (burst=5, menor disponible)
t=1: P2 llega, espera
t=2: P3 llega, espera  
t=3: P4 llega, espera
t=5: P1 termina ráfaga, va a I/O

Procesos disponibles en t=5:
- P2: burst=3
- P3: burst=4  
- P4: burst=2 ← MENOR, ejecuta primero

t=5: P4 ejecuta (no puede, P1 aún usa I/O)
t=7: P1 termina I/O, P2 ejecuta (burst=3, menor entre P2,P3,P4)
t=10: P2 termina ráfaga, va a I/O, P4 ejecuta (burst=2)
t=11: P2 termina I/O, disponible para segunda ráfaga
t=12: P4 termina ráfaga, va a I/O, P3 ejecuta (burst=4, único disponible)
t=15: P4 termina I/O, disponible
t=16: P3 termina completamente

Procesos disponibles:
- P1: burst=3
- P2: burst=2 ← MENOR
- P4: burst=1 ← MENOR

P4 ejecuta primero, luego P2, finalmente P1.
```

**Cálculos para SJF:**

```
Tiempos de terminación:
P1: 20, P2: 13, P3: 16, P4: 16

Tiempos de retorno:
P1: 20-0 = 20
P2: 13-1 = 12
P3: 16-2 = 14
P4: 16-3 = 13
Promedio: (20+12+14+13)/4 = 14.75

Tiempos de espera:
P1: 20-(5+3) = 12
P2: 12-(3+2) = 7  
P3: 14-4 = 10
P4: 13-(2+1) = 10
Promedio: (12+7+10+10)/4 = 9.75

Tiempo de respuesta:
P1: 0-0 = 0
P2: 7-1 = 6
P3: 12-2 = 10
P4: 5-3 = 2 (ejecuta cuando P1 va a I/O)
Promedio: (0+6+10+2)/4 = 4.5
```

### Manejo de Prioridades en Eventos Simultáneos

**Escenario**: Múltiples eventos ocurren simultáneamente en t=10:
- Interrupción de reloj (P1 agota quantum)
- Finalización de I/O (P2 se vuelve READY)  
- System call (P3 se bloquea)

**Orden de procesamiento**:
1. **Interrupción de reloj**: P1 → READY (final de cola)
2. **Finalización de I/O**: P2 → READY (puede tener prioridad alta)
3. **System call**: P3 → BLOCKED

**Decisión de planificación**:
- Si P2 tiene mayor prioridad → P2 ejecuta
- Si P2 tiene igual prioridad → P4 ejecuta (ya estaba en READY)
- Aplicar algoritmo de planificación con nueva configuración

## Síntesis

### Puntos Clave para Parcial

**Resumen de algoritmos:**

| Algoritmo | Preemptivo | Overhead | Starvation | Aging | Mejor para |
|-----------|------------|----------|------------|-------|------------|
| **FCFS** | No | Mínimo | No | No necesario | Batch simple |
| **SJF** | No | Bajo | Sí | Necesario | Batch conocido |
| **SRT** | Sí | Alto | Sí (severo) | Crítico | Trabajos cortos |
| **RR** | Sí | Medio | No | No necesario | Interactivo |
| **VRR** | Sí | Medio-Alto | No | Implícito | I/O intensivo |
| **HRRN** | No | Medio | No | Incorporado | Balanceado |
| **Prioridades** | Ambos | Bajo-Medio | Sí | Esencial | Tiempo real |
| **Multilevel** | Sí | Alto | Posible | Necesario | Propósito general |

**Fórmulas esenciales:**
```
Tiempo_retorno = Tiempo_terminación - Tiempo_llegada
Tiempo_espera = Tiempo_retorno - Tiempo_CPU_total
Tiempo_respuesta = Primera_ejecución - Tiempo_llegada

HRRN: Response_Ratio = (Tiempo_espera + Tiempo_servicio) / Tiempo_servicio
Aging: Nueva_prioridad = Prioridad_base + (Tiempo_espera / Factor_aging)
```

**Criterios para resolver ejercicios:**
1. **Dibujar timeline** con llegadas y eventos
2. **Identificar interrupciones** y sus prioridades
3. **Aplicar algoritmo** respetando preemptividad
4. **Manejar I/O** correctamente (tiempos de bloqueo)
5. **Calcular métricas** para cada proceso

### Ejemplo simulación Round Robin


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



**Tips para parcial:**

1. **Diagramas de Gantt son esenciales** - Mostrar CPU e I/O separadamente
2. **Marcar eventos importantes** - Interrupciones, llegadas, cambios de estado
3. **Verificar cálculos** - Tiempo total debe ser consistente
4. **Considerar overhead** - Context switches tienen costo
5. **Justificar decisiones** - Explicar por qué se eligió cada proceso

### Decisiones de Diseño

**Sistemas Batch**: SJF, HRRN, FCFS
- Optimizar throughput sobre respuesta
- Starvation menos crítico

**Sistemas Interactivos**: RR, VRR, Multilevel
- Tiempo de respuesta crítico
- Fairness importante

**Sistemas de Tiempo Real**: Prioridades fijas
- Deadlines deben cumplirse
- Predecibilidad esencial

**Sistemas de Propósito General**: Multilevel feedback
- Balance entre todos los objetivos
- Adaptabilidad a diferentes cargas

---

**Próximo capítulo**: Hilos - Explorando la concurrencia dentro de los procesos y desafíos de planificación multinivel.