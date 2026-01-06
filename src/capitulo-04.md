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

Imaginemos una cafetería con un solo barista y 10 clientes esperando. ¿En qué orden debe atender a los clientes? Esta pregunta, aparentemente simple, esconde un problema de optimización complejo. Podría atender por orden de llegada, lo cual parece justo. O quizás debería priorizar los pedidos más rápidos para maximizar la cantidad de clientes atendidos por hora. Tal vez tenga sentido un sistema de turnos rotativos, o dar prioridad a clientes VIP.  
Cada estrategia tiene ventajas y desventajas, y lo que funciona bien en un contexto puede ser desastroso en otro. Este mismo dilema se presenta en los sistemas operativos cuando deben decidir qué proceso ejecutar en el CPU.

### El problema fundamental

En un sistema con múltiples procesos pero un solo CPU (o pocos núcleos), el sistema operativo enfrenta tres decisiones críticas que debe tomar miles de veces por segundo: qué proceso ejecutar, cuándo cambiar de proceso, y por cuánto tiempo cada proceso debe mantener el control del CPU.

\begin{highlight}
La planificación de procesos es el mecanismo mediante el cual el sistema operativo decide qué proceso de la cola de listos (READY) debe ejecutarse a continuación en el CPU.
\end{highlight}

Estas decisiones impactan directamente en el rendimiento del sistema, la experiencia del usuario y la utilización eficiente de los recursos disponibles. Un algoritmo de planificación mal diseñado puede hacer que aplicaciones interactivas se sientan lentas y poco responsivas, mientras que un algoritmo bien ajustado puede hacer que un sistema parezca mucho más rápido de lo que realmente es.

### Objetivos conflictivos

Los algoritmos de planificación buscan optimizar múltiples métricas que frecuentemente entran en conflicto entre sí. Maximizar el throughput (cantidad de procesos completados por unidad de tiempo) a menudo significa darle prioridad a procesos cortos, lo que puede hacer que procesos largos esperen indefinidamente. Ser absolutamente justo con todos los procesos puede resultar en un sistema menos eficiente globalmente.

\begin{warning}
No existe el algoritmo de planificación "perfecto". Cada algoritmo representa un compromiso entre objetivos en competencia, y la elección apropiada depende del contexto de uso del sistema.
\end{warning}

La clave está en entender estos compromisos y elegir el algoritmo más apropiado para cada situación. Un sistema batch que procesa trabajos científicos tiene prioridades muy diferentes a un smartphone que debe responder instantáneamente a la interacción del usuario.

## Conceptos Fundamentales

### Niveles de Planificación

El sistema operativo no tiene un solo planificador, sino una jerarquía de tres niveles que operan en diferentes escalas de tiempo. Cada nivel se encarga de decisiones distintas, y juntos forman un sistema cohesivo de gestión de procesos.

#### Planificación a Largo Plazo (Job Scheduler)
El *planificador a largo plazo* decide qué programas nuevos ingresan al sistema, controlando la transición de NEW a READY. Esta decisión se toma con poca frecuencia, típicamente cuando un usuario ejecuta un nuevo programa o cuando se inicia un trabajo batch.  

Su función principal es controlar el grado de multiprogramación del sistema, es decir, cuántos procesos pueden coexistir simultáneamente en memoria. Si admite demasiados procesos, el sistema puede saturarse y degradar su rendimiento. Si admite muy pocos, el CPU puede quedarse ocioso esperando trabajo.  

Este nivel de planificación es común en sistemas batch tradicionales, pero muchos sistemas operativos modernos como Linux o Windows prácticamente no tienen un planificador a largo plazo explícito: admiten todos los procesos que el usuario solicita, dejando que otros mecanismos gestionen la carga.

#### Planificación a Mediano Plazo (Memory Scheduler) 
Operando en una escala temporal de segundos, el planificador a mediano plazo decide qué procesos mantener en memoria principal y cuáles mover temporalmente al disco mediante swapping. Cuando la memoria RAM se llena, este planificador puede suspender procesos inactivos, liberando espacio para procesos más activos.  
Este mecanismo es crucial para mantener el balance entre rendimiento y utilización de memoria. Un proceso suspendido no consume RAM, pero reactivarlo requiere traerlo de vuelta desde el disco, una operación costosa en tiempo.

#### Planificación a Corto Plazo (CPU Scheduler)
El planificador a corto plazo (dispatcher) es el corazón del sistema de planificación y el enfoque principal de este capítulo. Opera a velocidades de milisegundos, decidiendo constantemente qué proceso de la cola READY debe ejecutarse en el CPU.
\begin{example}
En un sistema típico, el planificador a corto plazo puede tomar decisiones cada 10-100 milisegundos, mientras que el planificador a largo plazo puede tomar decisiones cada varios segundos o incluso minutos.
\end{example}

### Tipos de Planificación
La distinción más fundamental entre algoritmos de planificación es si son preemptivos o no preemptivos, una característica que define completamente su comportamiento y casos de uso.

#### Planificación No Preemptiva (No Expropiativa)
En un esquema no preemptivo, una vez que un proceso obtiene el CPU, lo mantiene hasta que voluntariamente lo libera, ya sea porque termina su ejecución o porque se bloquea esperando una operación de I/O. El sistema operativo no puede forzar al proceso a ceder el CPU.  

Esta simplicidad tiene ventajas: menor overhead computacional porque hay menos cambios de contexto, y mayor previsibilidad en el tiempo de ejecución. Sin embargo, presenta un problema crítico: un solo proceso mal comportado puede monopolizar el CPU indefinidamente, dejando a todos los demás procesos sin oportunidad de ejecutarse.

#### Planificación Preemptiva (Expropiativa)
Los algoritmos preemptivos otorgan al sistema operativo la capacidad de interrumpir un proceso en ejecución y asignar el CPU a otro proceso. Esta interrupción puede ocurrir por varios motivos: el quantum de tiempo asignado se agotó, llegó un proceso de mayor prioridad, o simplemente el sistema decidió que es momento de darle una oportunidad a otro proceso.

\begin{infobox}
La preemptividad es esencial para sistemas interactivos modernos. Sin ella, un programa que entra en un ciclo infinito podría congelar todo el sistema. Con preemptividad, el sistema operativo mantiene siempre el control final sobre el CPU.
\end{infobox}

El costo de esta flexibilidad es el overhead de los frecuentes cambios de contexto. Cada vez que el sistema operativo quita el CPU a un proceso para dárselo a otro, debe guardar el estado completo del primer proceso y restaurar el estado del segundo, una operación que consume tiempo.

### Métricas de Rendimiento

Para evaluar y comparar algoritmos de planificación necesitamos métricas objetivas. Estas se dividen en dos categorías según su perspectiva.  
Las métricas orientadas al sistema incluyen la utilización del CPU (porcentaje de tiempo que el CPU está ejecutando procesos productivos en lugar de estar ocioso) y el throughput (cantidad de procesos que el sistema completa por unidad de tiempo). Estas métricas interesan principalmente a los administradores de sistemas y diseñadores de algoritmos.  
Las métricas orientadas al usuario capturan la experiencia percibida. El **tiempo de retorno** (turnaround time) mide cuánto tiempo total transcurre desde que un proceso llega al sistema hasta que termina completamente:

  $$
  t_{retorno} = t_{terminacion} - t_{llegada}
  $$
El **tiempo de espera** (waiting time) cuantifica cuánto tiempo un proceso pasó esperando en la cola READY, sin ejecutarse:

  $$
  t_{espera} = t_{retorno} - t_{ejecucion}
  $$

El **tiempo de respuesta** (response time) es particularmente importante en sistemas interactivos, midiendo cuánto tiempo transcurre desde que un proceso llega hasta que comienza su primera ejecución:  

  $$ 
  t_{respuesta} = t_{primera_ejecucion} - t_{llegada}
  $$
\begin{highlight}
Un usuario percibe la velocidad de un sistema principalmente a través del tiempo de respuesta, no del tiempo de retorno. Un proceso que comienza a ejecutarse inmediatamente pero tarda mucho en terminar puede sentirse más responsivo que uno que termina rápido pero tarda en comenzar.
\end{highlight}

### Ráfagas de CPU y I/O

Los procesos no utilizan el CPU de manera continua. En lugar de eso, alternan entre períodos de uso intensivo del CPU (CPU burst) y períodos esperando operaciones de entrada/salida (I/O burst). Esta distinción es fundamental para diseñar algoritmos de planificación efectivos.  

Un proceso CPU-bound se caracteriza por ráfagas de CPU largas y pocas operaciones de I/O. Ejemplos típicos incluyen simulaciones científicas, renderizado de video, o minería de criptomonedas. Estos procesos pueden ejecutarse por segundos o incluso minutos sin bloquearse.  

Por otro lado, un proceso I/O-bound tiene ráfagas de CPU muy cortas, bloqueándose frecuentemente para operaciones de disco, red, o interacción con el usuario. Los editores de texto, navegadores web, y la mayoría de aplicaciones interactivas caen en esta categoría.

\begin{example}
Un editor de texto pasa la mayor parte del tiempo esperando que el usuario presione una tecla. Cuando esto ocurre, procesa la entrada en milisegundos y vuelve a bloquearse. Su ráfaga de CPU típica puede ser de solo 1-10 milisegundos.
\end{example}

Esta clasificación importa porque un buen algoritmo de planificación debería favorecer procesos I/O-bound para mantener la responsividad del sistema, mientras que los procesos CPU-bound pueden tolerar más latencia sin que el usuario lo note.

### Eventos que Provocan Planificación

El planificador no toma decisiones en momentos arbitrarios, sino que se invoca en respuesta a eventos específicos del sistema. Estos eventos tienen diferentes prioridades, lo que determina su orden de procesamiento cuando ocurren simultáneamente.  

La **interrupción de reloj** tiene la prioridad más alta. Ocurre cuando el quantum de tiempo asignado a un proceso se agota en un sistema preemptivo. Esta interrupción garantiza que el sistema operativo retome el control periódicamente, evitando que un proceso monopolice el CPU.  

Las **interrupciones de finalización de I/O** tienen prioridad media. Cuando un proceso bloqueado esperando I/O recibe sus datos, genera una interrupción que puede tener mayor prioridad que el proceso actualmente en ejecución, especialmente si el proceso que estaba esperando es más prioritario.  

Finalmente, las **system calls** representan puntos donde el proceso actual voluntariamente cede el control, generalmente porque necesita bloquearse para I/O. Estas tienen la menor prioridad porque no requieren intervención urgente del sistema operativo.

\begin{warning}
Cuando múltiples procesos llegan simultáneamente a la cola READY, el criterio de desempate estándar es aplicar primero prioridades (si existen) y luego FCFS (primero en llegar, primero en ser servido) entre procesos de igual prioridad.
\end{warning}

## Análisis Técnico

Ahora que establecimos los fundamentos conceptuales, podemos explorar en detalle los algoritmos de planificación más importantes. Cada uno representa diferentes filosofías y compromisos, diseñados para contextos de uso específicos.  

### First-Come First-Served (FCFS)

El algoritmo más simple imaginable: atender los procesos en el orden exacto en que llegan. FCFS mantiene una cola FIFO (First In, First Out) y ejecuta cada proceso hasta que termina o se bloquea voluntariamente, sin ninguna posibilidad de expropiar el CPU.  

Su implementación es trivial: una simple cola enlazada donde nuevos procesos se agregan al final y el planificador siempre toma el proceso del frente. No requiere información sobre duración de procesos ni cálculos complejos de prioridades.  

La característica definitoria de FCFS es su justicia absoluta en términos de orden de llegada. No puede haber starvation (inanición) porque todos los procesos eventualmente llegarán al frente de la cola. El algoritmo es completamente predecible: si conocés el orden de llegada y los tiempos de ejecución, podés calcular exactamente cuándo ejecutará cada proceso.

\begin{theory}
FCFS es óptimo en un sentido limitado: minimiza la varianza del tiempo de espera. Todos los procesos esperan aproximadamente lo mismo (relativo a su posición en la cola), sin favorecimientos ni discriminación.
\end{theory}

Sin embargo, FCFS sufre del **efecto convoy**: un proceso largo puede retener todos los procesos cortos que llegan después, resultando en tiempos de espera promedio pobres. Imaginá una fila de supermercado donde alguien con un carrito lleno está adelante de cinco personas con un solo artículo cada una. El tiempo de espera promedio es terrible, aunque técnicamente sea "justo".  

Además, FCFS desperdicia oportunidades de paralelismo. Mientras el CPU ejecuta un proceso CPU-bound largo, múltiples procesos I/O-bound podrían estar realizando sus operaciones de I/O simultáneamente, pero en cambio esperan en la cola sin hacer nada productivo.

### Shortest Job First (SJF)

SJF adopta un enfoque radicalmente diferente: en lugar de orden de llegada, ejecuta primero el proceso con menor tiempo de CPU estimado. Este simple cambio tiene consecuencias profundas para el rendimiento del sistema.  
Cuando un proceso termina o se bloquea, el planificador examina todos los procesos en la cola READY, identifica el que requiere menos tiempo de CPU, y lo ejecuta hasta su terminación. No hay preemptividad: una vez que un proceso comienza, continúa hasta bloquearse o terminar.

\begin{highlight}
SJF es matemáticamente óptimo para minimizar el tiempo de retorno promedio. Ningún otro algoritmo no preemptivo puede lograr un mejor tiempo de retorno promedio que SJF. Esta es una garantía teórica demostrable.
\end{highlight}

La intuición detrás de esta optimalidad es simple: ejecutar primero trabajos cortos significa que muchos procesos terminan rápidamente, reduciendo el tiempo promedio de espera. Pensá en la fila del supermercado: si las personas con pocos artículos pasan primero, el tiempo de espera promedio disminuye dramáticamente.  
Pero SJF tiene dos problemas fundamentales que limitan su aplicabilidad práctica. Primero, requiere conocer el tiempo de ejecución de cada proceso de antemano, algo imposible en general. El sistema operativo puede estimar tiempos basándose en ráfagas anteriores usando un promedio móvil exponencial:

$$
 τ_{(n+1)} = \alpha × t_{(n)} + (1-\alpha) × τ_{(n)}
$$

donde $τ_{(n+1)}$ es el tiempo estimado para la próxima ráfaga, $t_{(n)}$ fue el tiempo real de la ráfaga anterior, y $\alpha$ controla cuánto peso le damos a la historia reciente versus el pasado lejano.

#### El rol crítico de α en la predicción
El parámetro α determina fundamentalmente el comportamiento del predictor. Su valor, siempre entre 0 y 1, establece un balance delicado entre dos extremos:

Cuando α está cerca de 1 (por ejemplo, α = 0.9), le damos mucho peso a la observación más reciente. El sistema tiene "memoria corta" y reacciona rápidamente a cambios en el comportamiento del proceso. Si un proceso que normalmente usa 10ms de CPU de repente necesita 100ms, la estimación se ajusta rápidamente. Esto es útil para procesos con comportamiento variable, pero hace que el predictor sea volátil y susceptible a ráfagas anómalas individuales.
Por el contrario, cuando α está cerca de 0 (por ejemplo, α = 0.1), privilegiamos la historia acumulada. La estimación cambia lentamente, suavizando fluctuaciones temporales. Esto es ideal para procesos con comportamiento estable y predecible, pero significa que el sistema tarda mucho en adaptarse cuando un proceso genuinamente cambia su patrón de uso de CPU.
El valor α = 0.5 representa un compromiso equilibrado, dando igual peso a la medición reciente y al historial acumulado. Es un punto de partida razonable cuando no conocemos el comportamiento del proceso.

![Comparación entre la duración real de los procesos y la estimación de CPU utilizada por SJF para distintos valores de α, mostrando cómo el parámetro influye en la adaptación del algoritmo al comportamiento reciente.](src/images/capitulo-03/01.jpg){width=0.9\linewidth}

En la práctica, sistemas operativos modernos suelen usar valores de α entre 0.5 y 0.8, favoreciendo levemente la reactividad sobre la estabilidad. Algunos sistemas incluso ajustan α dinámicamente basándose en la variabilidad observada del proceso.

El segundo problema que enfrenta **SJF** es más serio: starvation severa. Un proceso largo puede nunca ejecutarse si constantemente llegan procesos más cortos. En un sistema ocupado, un trabajo de varias horas podría quedar perpetuamente postergado, esperando un momento de calma que nunca llega.
\begin{warning}
SJF sin mecanismo de aging puede resultar en starvation indefinida para procesos largos. En sistemas de producción, siempre debe implementarse algún mecanismo que incremente gradualmente la prioridad de procesos que esperan mucho tiempo.
\end{warning}

### Shortest Remaining Time (SRT)

SRT es la versión preemptiva de SJF, llevando su filosofía al extremo. En lugar de considerar solo el tiempo total de ejecución, SRT examina el tiempo restante de cada proceso y siempre ejecuta el que tiene menos tiempo pendiente.  
La diferencia crucial es que SRT puede expropiar un proceso en ejecución. Si llega un nuevo proceso cuyo tiempo de CPU es menor que el tiempo restante del proceso actual, SRT inmediatamente realiza un context switch para ejecutar el proceso nuevo.

```c
// Pseudocódigo simplificado de SRT
al_llegar_nuevo_proceso(proceso_nuevo):
    if proceso_nuevo.tiempo_restante < proceso_actual.tiempo_restante:
        context_switch(proceso_nuevo)
    else:
        agregar_a_cola(proceso_nuevo)
```

Esta agresividad en la preempción mejora aún más el tiempo de retorno promedio comparado con SJF. Procesos cortos que llegan tarde no necesitan esperar a que termine el proceso largo actualmente en ejecución; pueden apropiarse del CPU inmediatamente.  
Sin embargo, el costo es considerable. El overhead de context switches puede volverse prohibitivo en sistemas con muchos procesos cortos llegando constantemente. Cada cambio de contexto implica guardar registros, actualizar tablas de páginas, invalidar cachés del CPU, y restaurar el estado del nuevo proceso.  
Peor aún, la starvation se vuelve aún más severa que en SJF. Un proceso largo puede iniciarse, ejecutarse unos milisegundos, ser expropiado por un proceso corto, volver a iniciar brevemente, ser expropiado nuevamente, y así sucesivamente sin nunca llegar a completarse.
\begin{example}
En un servidor web procesando miles de requests cortos por segundo, un proceso de backup que requiere 10 minutos de CPU podría ser constantemente expropiado y tomar horas o días en completarse, aunque técnicamente solo necesita 10 minutos de CPU.
\end{example}
El aging es absolutamente crítico en SRT. Sin él, el algoritmo es prácticamente inutilizable en sistemas de producción. Una estrategia común es incrementar artificialmente la prioridad de procesos (o decrementar su "tiempo restante" percibido) en proporción al tiempo que han esperado.

### Round Robin (RR)

Round Robin representa un cambio filosófico completo. En lugar de intentar optimizar el tiempo de retorno, RR prioriza la justicia (*fairness*) y el tiempo de respuesta. La idea es elegante en su simplicidad: cada proceso recibe un turno fijo de tiempo (*quantum*), y cuando termina su turno, va al final de la cola para esperar su próxima oportunidad.    
El algoritmo mantiene una cola circular de procesos READY. El planificador asigna el CPU al proceso al frente de la cola por un máximo de Q unidades de tiempo. Si el proceso termina antes de agotar su quantum, el sistema pasa al siguiente proceso. Si el quantum expira, el proceso actual se mueve al final de la cola y el siguiente proceso obtiene el CPU.

*Algoritmo:*
```
1. Asignar quantum Q a cada proceso
2. Ejecutar proceso por máximo Q unidades de tiempo
3. Si no termina, mover al final de cola READY
4. Si se bloquea antes de Q, no pierde el quantum restante
5. Seleccionar siguiente proceso de la cola
```

La magia de Round Robin está en que garantiza progreso para todos los procesos. No importa cuántos procesos haya en el sistema; cada uno recibirá periódicamente su turno de ejecución. Esto elimina completamente la posibilidad de starvation.

\begin{highlight}
El tiempo de respuesta en Round Robin está acotado: un proceso con $n$ procesos en la cola nunca esperará más de $n × Q$ unidades de tiempo antes de su próxima ejecución. Esta garantía es invaluable para sistemas interactivos.
\end{highlight}

La selección del quantum es un arte sutil que requiere balance cuidadoso. Un quantum demasiado pequeño (por ejemplo, 1 milisegundo) resulta en overhead excesivo: el sistema pasa más tiempo cambiando entre procesos que realmente ejecutándolos. Un quantum demasiado grande (por ejemplo, 1 segundo) degrada Round Robin prácticamente a FCFS: la mayoría de procesos terminarán antes de agotar su quantum.  

La regla práctica tradicional sugiere quantums de 10-100 milisegundos, significativamente mayores que el tiempo de context switch (típicamente 0.1-1 milisegundo en hardware moderno). Esto mantiene el overhead de cambio de contexto bajo 1-10% del tiempo total de CPU.  

Round Robin no es óptimo para tiempo de retorno. De hecho, puede tener uno de los peores tiempos de retorno promedio entre todos los algoritmos. Un proceso que requiere 100 milisegundos de CPU y es el único en el sistema terminará en exactamente 100ms con cualquier algoritmo. Pero con Round Robin compartiendo el CPU con otros 9 procesos (Q=10ms), ese mismo proceso tardará aproximadamente 1 segundo en completarse: 10ms por turno, 10 turnos total, con 90ms de espera entre cada turno.  

Sin embargo, para sistemas interactivos modernos, este compromiso vale la pena. La experiencia del usuario mejora dramáticamente cuando todas las aplicaciones progresan constantemente, incluso si ninguna termina particularmente rápido.  

\begin{excerpt}
\textit{"Atomicidad mata quantum..."}

\hfill --- Ing. Néstor Esquivel
\end{excerpt}

Esta frase, cuando la dijo el profe, sonó casi zen y sin sentido, pero resume un principio crítico que aparece en ejercicios de planificación: **una operación atómica no puede ser interrumpida, ni siquiera cuando expira el quantum**. 

Una operación atómica es indivisible: o se ejecuta completa o no se ejecuta. Para garantizar esta propiedad, el sistema debe deshabilitar interrupciones durante su ejecución. Esto significa que el timer interrupt que normalmente causa un context switch al expirar el quantum simplemente no puede ocurrir mientras la operación atómica está en progreso.

\begin{warning}
En ejercicios de planificación con Round-Robin:

Si un proceso está ejecutando una operación atómica de 15ms y su quantum es de 10ms, el proceso \textbf{NO} será expropiado a los 10ms. Continuará hasta completar los 15ms de la operación atómica, y recién entonces el scheduler podrá actuar. El quantum efectivo en ese caso fue de 15ms, no 10ms.
\end{warning}

Este comportamiento puede parecer una violación del algoritmo RR, pero es necesario para mantener la corrección del sistema. La atomicidad es una garantía de seguridad que tiene prioridad sobre las políticas de planificación.


### Virtual Round Robin (VRR)

Round Robin trata todos los procesos por igual, pero no todos los procesos son iguales. VRR es un refinamiento que reconoce una asimetría fundamental: los procesos I/O-bound generalmente merecen un trato ligeramente preferencial porque responden a interacciones del usuario y liberan el CPU rápidamente.  

La innovación de VRR es simple pero efectiva: mantiene dos colas en lugar de una. La **cola READY** funciona como en Round Robin clásico, conteniendo procesos nuevos y procesos que agotaron su quantum completo. La **cola AUXILIARY** contiene procesos que se bloquearon voluntariamente para I/O antes de agotar su quantum.  

El planificador siempre prefiere la cola AUXILIARY sobre la cola READY. Cuando un proceso de la cola AUXILIARY ejecuta, recibe solo su quantum *restante* (no un quantum completo nuevo). Esto recompensa el comportamiento cooperativo: un proceso que se bloqueó rápidamente puede volver al CPU antes que procesos que intentaron usar todo su tiempo.


```
Estado inicial: Cola READY = [P1, P2, P3], Q=10ms

t=0-8: P1 ejecuta 8ms, se bloquea para I/O → va a AUXILIARY con quantum_restante=2ms
t=8-18: P2 ejecuta 10ms completos → va al final de READY
t=18-20: I/O de P1 termina
t=20-22: P1 (desde AUXILIARY) ejecuta sus 2ms restantes, termina
t=22-32: P3 ejecuta su turno
```

Esta modificación beneficia desproporcionadamente a procesos interactivos y editores de texto que se bloquean frecuentemente esperando input del usuario. Estos procesos obtienen respuesta más rápida sin penalizar significativamente a procesos CPU-bound.

\begin{infobox}
VRR implementa una forma sutil de aging: el quantum restante efectivamente actúa como un boost de prioridad temporal. Procesos que se comportan "bien" bloqueándose voluntariamente reciben trato preferencial la próxima vez que necesiten el CPU.
\end{infobox}

El costo es complejidad de implementación adicional: el sistema operativo debe rastrear quantum restante para cada proceso y gestionar dos colas separadas. En la práctica, el overhead es modesto y el beneficio en responsividad justifica la complejidad extra.

### Highest Response Ratio Next (HRRN)

HRRN intenta capturar lo mejor de SJF y FCFS en un solo algoritmo, balanceando la preferencia por trabajos cortos con un mecanismo de aging automático que previene starvation.  

La métrica central es el *response ratio* (ratio de respuesta), calculado para cada proceso como:
$$
Response Ratio = (t_{espera} + t_{servicio}) / t_{servicio}
$$

El planificador siempre selecciona el proceso con el mayor response ratio. Miremos qué significa esta fórmula. Un proceso que acaba de llegar tiene tiempo de espera cero, entonces su ratio es simplemente 1.0. A medida que espera, el numerador crece linealmente, aumentando su ratio y por lo tanto su prioridad.  

Procesos cortos (Tiempo_servicio pequeño) naturalmente tienen ratios más altos, dándoles preferencia similar a SJF. Pero procesos largos que han esperado mucho tiempo eventualmente tendrán ratios muy altos también, garantizando que eventualmente ejecuten.  

\begin{example}
Proceso A: $t_{servicio} = 5ms, t_{espera} = 10ms -> ratio = (10+5)/5 = 3.0$\\
Proceso B: $t_{servicio} = 20ms, t_{espera} = 40ms -> ratio = (40+20)/20 = 3.0$

Ambos tienen el mismo ratio, aunque B es más largo. El tiempo de espera de B compensa su mayor longitud.
\end{example}

Esta fórmula implementa aging de manera elegante y automática. No requiere parámetros arbitrarios ni ajustes manuales: el balance entre favorecimiento de trabajos cortos y prevención de starvation emerge naturalmente de la matemática.  

HRRN mantiene el enfoque no preemptivo, ejecutando cada proceso seleccionado hasta su terminación o bloqueo. Esto limita su efectividad para sistemas interactivos altamente responsivos, pero lo hace apropiado para sistemas batch que buscan optimizar throughput mientras mantienen fairness razonable.  

El overhead computacional de HRRN es moderado. En cada decisión de planificación, el sistema debe calcular el response ratio para todos los procesos READY. Con cientos de procesos, esto puede volverse costoso. Además, HRRN hereda de SJF la necesidad de estimar tiempos de servicio, lo cual no siempre es preciso.

### Planificación por Prioridades

Los algoritmos de prioridad reconocen explícitamente que no todos los procesos son igualmente importantes. El sistema operativo, el administrador, o el propio diseño del sistema pueden asignar diferentes niveles de prioridad, y el planificador simplemente ejecuta el proceso de mayor prioridad disponible.  

Las **prioridades estáticas** se asignan cuando un proceso inicia y no cambian durante su vida. Esto es simple y eficiente, apropiado cuando las relaciones de importancia entre procesos son claras y estables. Por ejemplo, procesos del sistema operativo podrían tener prioridad 0 (máxima), aplicaciones de usuario prioridad 50, y tareas de mantenimiento prioridad 100.  

Las **prioridades dinámicas** ajustan continuamente basándose en el comportamiento del proceso. Un proceso I/O-bound podría recibir prioridad más alta porque libera el CPU rápidamente. Un proceso que ha esperado mucho tiempo podría ver su prioridad incrementarse gradualmente.  

La planificación por prioridades puede implementarse de manera preemptiva o no preemptiva. En el esquema no preemptivo, un proceso ejecuta hasta terminar o bloquearse incluso si llegan procesos de mayor prioridad. En el esquema preemptivo, la llegada de un proceso de mayor prioridad inmediatamente expulsa al proceso actual.  

\begin{warning}
Planificación por prioridades sin aging sufre de starvation severa. Procesos de baja prioridad pueden literalmente nunca ejecutarse en un sistema moderadamente ocupado. Aging no es opcional, es esencial.
\end{warning}

El aging en sistemas de prioridad típicamente incrementa la prioridad de un proceso en función de su tiempo de espera:
$$
prioridad_{efectiva} = prioridad_{base} + (tiempo_{espera} / factor_{aging})
$$

El `factor_aging` controla qué tan rápido crece la prioridad. Un factor pequeño significa que procesos de baja prioridad rápidamente alcanzan prioridad competitiva. Un factor grande significa que deben esperar mucho tiempo antes de volverse relevantes.  

Los sistemas de prioridades brillan en contextos de tiempo real donde ciertos procesos tienen deadlines estrictos. Un controlador de motor en un auto autónomo debe ejecutarse cada 10ms sin excepción, mientras que la actualización de la pantalla de entretenimiento puede esperar. Las prioridades proporcionan las garantías necesarias para estos escenarios.

### Multilevel Feedback Queue

Multilevel Feedback Queue representa el pináculo de complejidad en planificación de procesos, combinando ideas de múltiples algoritmos en un framework adaptativo sofisticado. El sistema mantiene múltiples colas de prioridad, cada una con su propio algoritmo de planificación, y los procesos pueden moverse dinámicamente entre colas basándose en su comportamiento observado.  

Una configuración típica podría tener tres colas:  

**Cola 0** (prioridad más alta): Round Robin con quantum de 8ms. Todos los procesos nuevos inician aquí. Esta cola captura procesos interactivos y trabajos muy cortos.  

**Cola 1** (prioridad media): Round Robin con quantum de 16ms. Procesos que agotaron su quantum en Cola 0 descienden aquí. El quantum más largo es apropiado para procesos que claramente necesitan más tiempo de CPU.  

**Cola 2** (prioridad más baja): FCFS. Procesos que agotaron su quantum en Cola 1 descienden aquí. Estos son claramente trabajos CPU-bound largos; FCFS minimiza el overhead para ellos.  

La regla de promoción es crucial: si un proceso se bloquea para I/O *antes* de agotar su quantum, mantiene su cola actual o incluso puede ser promovido a una cola de mayor prioridad. Esto recompensa el comportamiento I/O-bound, que generalmente corresponde a procesos interactivos.
```
// Comportamiento adaptativo del sistema
Proceso P inicia → Cola 0
P ejecuta 8ms completos → desciende a Cola 1
P ejecuta 16ms completos → desciende a Cola 2
P se bloquea después de 5ms → mantiene Cola 2
P frecuentemente se bloquea → puede ser promovido a Cola 1

// El sistema aprende qué tipo de proceso es P
```
\begin{theory}
Multilevel Feedback Queue implementa una forma de machine learning primitivo: observa el comportamiento pasado de cada proceso para predecir su comportamiento futuro y ajustar su tratamiento dinámicamente.
\end{theory}
Este enfoque adaptativo es poderoso pero tiene costos. La complejidad de implementación es considerable: el sistema operativo debe rastrear múltiples colas, implementar múltiples algoritmos simultáneamente, aplicar reglas de promoción y demotion, y prevenir starvation mediante aging cuidadoso entre colas.
Tuning el sistema también es un desafío.¿Cuántas colas? ¿Qué quantum para cada una? ¿Cuándo promover procesos? ¿Con qué frecuencia aplicar aging? Cada parámetro afecta el comportamiento global del sistema de maneras a veces contraintuitivas.  
A pesar de esta complejidad, muchos sistemas operativos modernos utilizan variantes de Multilevel Feedback Queue porque, cuando está bien tuneado, proporciona excelente rendimiento para cargas de trabajo heterogéneas. Linux, por ejemplo, utiliza el "Completely Fair Scheduler" (CFS) que incorpora ideas similares.

## Casos de Estudio

### Planificación con Round Robin

Consideremos cuatro procesos con comportamiento heterogéneo, incluyendo múltiples ráfagas de CPU intercaladas con operaciones de I/O. Este escenario refleja sistemas reales donde los procesos raramente ejecutan hasta completarse sin interrupciones.

```
Proceso | Llegada | CPU Burst | I/O Burst | CPU Burst 2
--------|---------|-----------|-----------|------------
P1      |    0    |     5     |     2     |     3
P2      |    1    |     3     |     1     |     2  
P3      |    2    |     4     |     -     |     -
P4      |    3    |     2     |     3     |     1
```

Aplicaremos Round Robin con un quantum de Q=3. La clave está en trackear cuidadosamente el estado de cada proceso: cuánto tiempo de CPU ha consumido en su ráfaga actual, si está bloqueado esperando I/O, y cuándo puede volver a la cola READY.
\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap03-gantt-RR.png}
\end{center}
Desarrollemos el timeline paso a paso. En t=0, P1 es el único proceso en el sistema y comienza a ejecutarse. Usará 3 de sus 5 milisegundos de CPU antes de que su quantum expire. Mientras tanto, P2 y P3 llegan al sistema en t=1 y t=2 respectivamente, ingresando a la cola READY.  
En t=3, P1 ha agotado su quantum habiendo ejecutado solo 3 de sus 5ms necesarios. Va al final de la cola READY con 2ms de CPU pendientes. P2, que ha estado esperando desde t=1, ahora obtiene el CPU. Simultáneamente, P4 llega y se agrega a la cola.  
P2 completa su primera ráfaga de CPU (3ms) en t=6, justo agotando su quantum. Se bloquea inmediatamente para realizar I/O durante 1ms. P3 ahora obtiene su turno, ejecutando durante 3ms de su ráfaga de 4ms total.  
En t=7, P2 completa su I/O y vuelve a la cola READY, pero debe esperar su turno detrás de P1 y P4. P3 continúa ejecutando hasta t=9, cuando agota su quantum con 1ms de CPU aún pendiente.  
Este patrón continúa: procesos ejecutan por su quantum o hasta bloquearse, nuevos procesos completan I/O y vuelven a la cola, y el planificador rota sistemáticamente entre todos los procesos READY.  
Calculemos las métricas finales. Los tiempos de terminación son: P1 termina en t=18, P2 en t=14, P3 en t=15, y P4 en t=19.

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

Observá cómo el tiempo de respuesta promedio es excelente (solo 3ms), confirmando que Round Robin proporciona buena responsividad. Sin embargo, el tiempo de retorno promedio (15ms) es relativamente alto porque los procesos se turnan el CPU en lugar de completarse rápidamente.

### Caso de Estudio: Planificación con SJF

Ahora analicemos el mismo conjunto de procesos usando SJF no preemptivo. Este algoritmo tomará decisiones completamente diferentes, priorizando la minimización del tiempo de retorno promedio sobre la justicia y la responsividad.

\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap03-gantt-SJF.png}
\end{center}

En t=0, P1 es el único proceso disponible y ejecuta sus 5ms completos, terminando su primera ráfaga en t=5 y bloqueándose para I/O. Durante este tiempo, P2, P3 y P4 han llegado y están esperando.  
Aquí está la primera decisión interesante de SJF. En t=5, tenemos tres procesos en la cola READY con las siguientes ráfagas de CPU pendientes: P2 necesita 3ms, P3 necesita 4ms, y P4 necesita 2ms. SJF selecciona P4 porque tiene la ráfaga más corta.  
Pero hay un problema: P1 aún está usando el recurso de I/O. Dependiendo de la implementación del sistema, esto puede o no bloquear a P4. Asumiendo que el I/O es independiente, P4 ejecuta sus 2ms y se bloquea para su propio I/O en t=7.  
En t=7, P1 ha completado su I/O y tiene una segunda ráfaga de CPU de 3ms pendiente. La cola READY ahora contiene: P1 (3ms), P2 (3ms), P3 (4ms). Con dos procesos empatados en tiempo más corto, SJF aplica FCFS como criterio de desempate: P2 llegó antes que P1 volvió de I/O, entonces P2 ejecuta.
P2 completa su primera ráfaga en t=10, va a I/O brevemente, y vuelve en t=11 con su segunda ráfaga de 2ms. Mientras tanto, P3 finalmente obtiene su oportunidad en t=12, ejecutando sus 4ms completos y terminando en t=16.  
En este punto las colas se reordenan constantemente basándose en las ráfagas restantes. P4 completa su I/O y tiene una ráfaga final de 1ms (la más corta), P2 necesita 2ms, y P1 necesita 3ms. El orden de ejecución final es P4, luego P2, finalmente P1.

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
Comparado con Round Robin, SJF logra mejor tiempo de retorno promedio (14.75 vs 15) y mejor tiempo de espera promedio (9.75 vs 10), confirmando su optimalidad teórica. Sin embargo, el tiempo de respuesta promedio es significativamente peor (4.5 vs 3), y notá cómo P3 tiene un tiempo de respuesta terrible de 10ms porque llegó cuando había procesos más cortos esperando.

### Manejo de Prioridades en Eventos Simultáneos
Un aspecto sutil pero crítico de la planificación es cómo manejar múltiples eventos que ocurren en el mismo instante. Este escenario aparece frecuentemente en sistemas reales debido a la granularidad finita del reloj del sistema.  
Imaginá la situación en t=10 donde tres eventos convergen simultáneamente:  
- Interrupción de reloj: P1 agota su quantum  
- Finalización de I/O: P2 completa su operación de disco y vuelve a READY  
- System call: P3 se bloquea voluntariamente esperando red  

El orden en que el sistema operativo procesa estos eventos determina qué proceso ejecuta a continuación. El orden de prioridad estándar es:
\begin{highlight}

Interrupción de reloj (prioridad más alta)\\
Finalización de I/O (prioridad media)\\
System call / transición voluntaria (prioridad más baja)
\end{highlight}

Este ordenamiento no es arbitrario. Las interrupciones de reloj deben procesarse inmediatamente para mantener la integridad del sistema de tiempo. Las finalizaciones de I/O tienen prioridad sobre system calls porque representan eventos externos que el sistema debe reconocer rápidamente.
Una vez procesados todos los eventos, el planificador evalúa la nueva configuración. Si P2 (que volvió de I/O) tiene mayor prioridad que P1 (que fue expropiado), entonces P2 ejecutará. Si tienen igual prioridad, generalmente continúa P1 porque ya estaba en posesión del CPU, minimizando context switches innecesarios.
\begin{infobox}
El criterio de desempate cuando múltiples procesos tienen igual prioridad y están READY simultáneamente suele ser FCFS basado en el instante en que cada proceso originalmente se volvió READY, no en el instante del desempate actual.
\end{infobox}

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
t_retorno = t_terminacion - t_llegada
t_espera = t_retorno - t_CPU-total
t_respuesta = t_primera-ejecucion - t_llegada

HRRN: Response Ratio = (t_espera + t_servicio) / t_servicio
Aging: Nueva Prioridad = prioridad-base + (t_espera / factor-aging)
```

Cuando resuelvas ejercicios de planificación, seguí esta metodología sistemática:  
Primero, dibujá un timeline mostrando todas las llegadas y eventos importantes. Marcá claramente cuándo cada proceso llega, cuándo comienzan y terminan las ráfagas de CPU, y cuándo ocurren los I/O.  
Segundo, identificá todas las interrupciones y sus prioridades relativas. Esto es especialmente importante cuando múltiples eventos ocurren simultáneamente.  
Tercero, aplicá el algoritmo de planificación respetando estrictamente sus reglas de preemptividad. No asumas comportamientos: si el algoritmo es no preemptivo, un proceso ejecuta hasta bloquearse o terminar sin excepciones.  
Cuarto, manejá las operaciones de I/O correctamente. Un proceso en I/O no está en la cola READY y no puede ser seleccionado para ejecución. Cuando completa su I/O, debe explícitamente retornar a READY antes de ser considerado.  
Finalmente, calculá todas las métricas solicitadas para cada proceso individualmente, luego promedialas. Verificá que los números tengan sentido: el tiempo de espera nunca puede ser negativo, y el tiempo de retorno debe ser al menos igual al tiempo de CPU total.

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
Este código muestra todos los detalles sutiles de una implementación real: gestión de la cola circular, tracking del tiempo restante de cada proceso, cálculo preciso de todas las métricas, y manejo correcto de procesos que terminan antes de agotar su quantum.  

Cuando estudies para el parcial, no solo memorices algoritmos; entendé por qué toman las decisiones que toman. ¿Por qué SJF minimiza el tiempo de retorno? Porque ejecutar trabajos cortos primero minimiza el tiempo total que todos los procesos pasan en el sistema. ¿Por qué Round Robin garantiza responsividad? Porque ningún proceso espera más de n × Q unidades de tiempo, sin importar cuán largo sea.


**Tips para parcial:**

1. Diagramas de Gantt son esenciales - Mostrar CPU e I/O separadamente
2. Marcar eventos importantes - Interrupciones, llegadas, cambios de estado
3. Verificar cálculos - Tiempo total debe ser consistente
4. Considerar overhead - Context switches tienen costo
5. Justificar decisiones - Explicar por qué se eligió cada proceso

### Decisiones de Diseño

La elección del algoritmo apropiado depende fundamentalmente del contexto de uso del sistema. No existe una respuesta universal porque diferentes entornos priorizan diferentes objetivos.  
Para **sistemas batch** que procesan trabajos largos sin intervención humana, algoritmos como SJF, HRRN o FCFS son apropiados. El objetivo principal es maximizar throughput (trabajos completados por hora) y utilizar eficientemente los recursos. La responsividad individual de cada proceso es menos importante porque no hay usuarios esperando resultados inmediatos. La starvation es menos crítica porque eventualmente el sistema procesará todos los trabajos durante la noche o el fin de semana.  

Los **sistemas interactivos** como laptops, smartphones, o estaciones de trabajo tienen prioridades completamente diferentes. El tiempo de respuesta es crítico porque los usuarios perciben demoras de más de 100-200ms como lentitud frustrante. Algoritmos como Round Robin, VRR, o Multilevel Feedback Queue son ideales porque garantizan que todas las aplicaciones progresen constantemente. Un usuario puede tener 20 aplicaciones abiertas; todas deben sentirse responsivas aunque ninguna esté usando el CPU intensivamente.  

**Sistemas de tiempo real** enfrentan restricciones más estrictas aún: ciertos procesos deben completarse antes de deadlines absolutos. Perder un deadline puede resultar en fallas catastróficas (considerá un controlador de airbag que debe activarse en 10ms). Estos sistemas requieren planificación por prioridades con garantías matemáticamente verificables. La justicia es irrelevant; lo único que importa es cumplir deadlines.

\begin{excerpt}
Los sistemas de propósito general modernos como Linux o Windows enfrentan el desafío más complejo: deben manejar simultáneamente procesos batch de larga duración, aplicaciones interactivas que requieren respuesta instantánea, y componentes de tiempo real del sistema operativo. La solución es típicamente alguna variante de Multilevel Feedback Queue que se adapta dinámicamente a patrones de carga heterogéneos.
\end{excerpt}

Finalmente, recordá que la planificación de CPU es solo una pieza del rompecabezas de rendimiento del sistema. La gestión de memoria, el sistema de I/O, y el diseño de las aplicaciones mismas frecuentemente tienen mayor impacto en la experiencia del usuario que el algoritmo de planificación específico. Un algoritmo de planificación brillante no puede compensar aplicaciones mal diseñadas que bloquean la interfaz de usuario o realizan I/O ineficientemente.

---

**Próximo capítulo**: Hilos - Explorando la concurrencia dentro de los procesos y desafíos de planificación multinivel.