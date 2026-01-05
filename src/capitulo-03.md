# Procesos  

## Objetivos de Aprendizaje  

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Definir qué es un proceso y diferenciarlo de un programa
- Explicar las diferencias entre monoprogramación, multiprocesamiento, multiprogramación y multitarea
- Describir las estructuras de control del SO para gestionar procesos
- Analizar la imagen de un proceso y la estructura del PCB
- Interpretar los diagramas de estados (3, 5 y 7 estados) y sus transiciones
- Identificar el rol del dispatcher y los diferentes planificadores
- Implementar operaciones básicas con procesos usando syscalls de Unix/Linux
- Resolver ejercicios sobre creación, comunicación y terminación de procesos
- Manejar correctamente procesos zombie y huérfanos  

## Introducción y Contexto  

### ¿Por qué existen los procesos?  

Imaginate una computadora de los años 1950: un solo programa ejecutándose, ocupando toda la memoria y el procesador hasta terminar. Si querías ejecutar otro programa, debías esperar. Si el programa se colgaba, reiniciabas toda la máquina. Este escenario, aunque funcional, era profundamente ineficiente.
Los procesos nacieron como respuesta a una pregunta fundamental que revolucionó la computación: ¿cómo hacer que múltiples programas compartan eficientemente los recursos de una sola computadora? La respuesta transformó no solo la arquitectura de los sistemas operativos, sino la manera misma en que pensamos sobre la ejecución de software.  

Un *proceso* es mucho más que un programa ejecutándose. Es una abstracción sofisticada que el sistema operativo construye para lograr cuatro objetivos críticos. Primero, aisla programas entre sí, de modo que un proceso no puede corromper la memoria de otro, garantizando estabilidad y seguridad. Segundo, permite compartir recursos como CPU, memoria y archivos de manera controlada y justa. Tercero, facilita la concurrencia, dando la ilusión de que múltiples tareas se ejecutan simultáneamente incluso en sistemas con una sola CPU. Finalmente, establece mecanismos seguros de comunicación entre programas, permitiendo que colaboren sin comprometer la integridad del sistema.  

\begin{theory}
La abstracción del proceso representa uno de los conceptos más fundamentales en sistemas operativos. Sin ella, la computación moderna tal como la conocemos sería imposible: no podríamos ejecutar múltiples aplicaciones simultáneamente, no tendríamos protección entre programas, y un error en cualquier software colapsaría todo el sistema.
\end{theory}

## Conceptos Fundamentales

### Programa vs Proceso: La Diferencia Esencial  

La distinción entre programa y proceso es sutil pero crucial. Un programa es una entidad completamente estática: un archivo ejecutable almacenado en disco que contiene código fuente compilado en instrucciones de máquina. Es una secuencia pasiva de instrucciones que no consume ningún recurso del sistema hasta el momento de su ejecución. Ejemplos típicos incluyen archivos como `/bin/ls` en Linux o `notepad.exe` en Windows.  

Un proceso, en contraste, es una entidad dinámica y viva. Representa una instancia específica de un programa en ejecución, y abarca no solo el código sino también los datos, el contexto de ejecución completo, y todos los recursos asignados. Es una entidad activa que puede realizar acciones, tomar decisiones, y consume recursos del sistema como memoria, tiempo de CPU, y descriptores de archivos. Por ejemplo, cuando ejecutás el comando `ls` en tu terminal, el sistema operativo crea un proceso con un identificador único (PID 1234, digamos) que ejecuta ese programa.

\begin{example}
Podés pensar en un programa como una receta de cocina escrita en un libro: contiene todas las instrucciones, pero no produce ningún resultado por sí misma. Un proceso es como un cocinero siguiendo esa receta en tiempo real: usa ingredientes (datos), ocupa un espacio en la cocina (memoria), y produce resultados concretos. Además, varios cocineros (procesos) pueden estar siguiendo la misma receta (programa) simultáneamente, cada uno en su propia estación de trabajo.
\end{example}


### Evolución de los Sistemas de Procesamiento

Para entender realmente qué son los procesos y por qué existen, necesitamos recorrer la evolución histórica de cómo las computadoras manejan programas. Esta evolución no fue arbitraria, sino una respuesta a limitaciones concretas que cada generación de sistemas enfrentó.  

La monoprogramación representa el modelo más primitivo. En estos sistemas, un solo programa se ejecutaba a la vez, monopolizando completamente todos los recursos. El problema fundamental era evidente: cuando el programa realizaba operaciones de entrada/salida (como leer del disco), la CPU quedaba completamente ociosa, esperando. Esta ineficiencia era catastrófica: la utilización de CPU raramente superaba el 5-10%. Los sistemas batch simples de los años 1950 operaban bajo este modelo, donde los programas se procesaban uno tras otro en secuencia estricta.

![Diagrama de instrucciones secuenciales.](src/images/capitulo-02/sequential.jpg){width=570px,height=210px}  

La multiprogramación atacó el problema de la ociosidad de manera elegante. En lugar de esperar que un programa termine, estos sistemas mantienen múltiples programas cargados en memoria simultáneamente. Una sola CPU alterna entre ellos de manera inteligente: cuando un proceso hace una operación de I/O y queda bloqueado, otro proceso usa la CPU. El objetivo central es maximizar la utilización de CPU, transformando el tiempo muerto en tiempo productivo.  

![Diagrama de ejecución pipeline, donde las etapas de una instrucción (fetch, decode, execute y writeback) se superponen en distintos ciclos de reloj para mejorar el rendimiento.](src/images/capitulo-02/pipelined.jpg){width=570px,height=px} 

El multiprocesamiento tomó un camino diferente: en lugar de mejorar cómo se usa una CPU, agregó múltiples CPUs físicos a la misma máquina. Esto permitió verdadero paralelismo a nivel hardware, donde cada CPU puede ejecutar un proceso completamente diferente al mismo tiempo. Los sistemas SMP (Symmetric Multiprocessing) democratizaron este enfoque, permitiendo que cualquier CPU ejecute cualquier proceso sin restricciones especiales.  
La multitarea extendió la multiprogramación con un concepto revolucionario: time-sharing. No solo los procesos comparten la CPU durante operaciones de I/O, sino que el sistema operativo puede interrumpir forzosamente un proceso en ejecución (preemptive scheduling) para darle turno a otro. Cada proceso recibe pequeños intervalos de tiempo llamados quantum o time slices, típicamente de 10-100 milisegundos. Esta rapidez en el cambio crea la ilusión de que todos los programas se ejecutan simultáneamente, logrando la interactividad que esperamos de los sistemas modernos.
\begin{warning}
Es común confundir multiprogramación con multitarea. La diferencia clave está en la preemption: en multiprogramación pura, un proceso solo cede la CPU voluntariamente (al hacer I/O). En multitarea, el sistema operativo puede quitarle la CPU a un proceso en cualquier momento, garantizando que ningún proceso monopolice el sistema.
\end{warning}

### Grado de Multiprogramación

El grado de multiprogramación es una métrica fundamental que define cuántos procesos residen simultáneamente en memoria principal. No se trata de cuántos procesos existen en total, ni cuántos están en ejecución en un momento dado, sino específicamente cuántos están cargados en RAM al mismo tiempo.  

Este número está limitado por varios factores críticos. El más obvio es la memoria disponible: más procesos en memoria significa menos memoria disponible por proceso, lo que puede forzar el uso de memoria virtual y degradar el rendimiento. Los recursos del sistema también imponen límites, como la cantidad de file descriptors, sockets, o conexiones de red que el sistema puede mantener. Finalmente, existe un overhead del sistema operativo: cada proceso adicional requiere estructuras de datos (PCBs, tablas de páginas), y el costo del cambio de contexto aumenta con más procesos compitiendo por CPU.

\begin{infobox}
En sistemas modernos, el grado de multiprogramación puede ser de cientos o incluso miles de procesos. Linux, por ejemplo, puede manejar fácilmente 10,000 procesos en hardware adecuado. Sin embargo, solo unos pocos estarán realmente activos en cualquier momento dado, el resto estará bloqueado esperando eventos.
\end{infobox}


### Estructuras de Control del Sistema Operativo

Para gestionar eficientemente todos estos procesos, el sistema operativo mantiene un conjunto sofisticado de tablas interconectadas. Estas estructuras forman la columna vertebral del manejo de recursos.  

La **tabla de procesos** actúa como punto de entrada hacia todas las demás tablas. Contiene un PCB (Process Control Block) por cada proceso en el sistema, y cada PCB mantiene referencias cruzadas hacia las entradas correspondientes en las tablas de memoria, I/O y archivos. Esta estructura centralizada permite al sistema operativo localizar rápidamente toda la información relacionada con cualquier proceso.  
\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap02-processTable.png}
\end{center}

La **tabla de memoria** rastrea cómo se asigna la memoria del sistema. Registra qué bloques de memoria están asignados a cada proceso, qué memoria está libre y disponible, los atributos de protección de cada región (lectura, escritura, ejecución), y toda la información necesaria para memoria virtual, como tablas de páginas y segmentos.  

\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap02-memoryTable.png}
\end{center}

La **tabla de I/O** gestiona los dispositivos del sistema. Mantiene el estado actual de cada dispositivo (libre, ocupado, error), las colas de operaciones pendientes por dispositivo, los buffers asociados a cada operación en curso, y referencias a los controladores de dispositivos activos. Esta tabla es crucial para la multiprogramación: cuando un proceso se bloquea esperando I/O, el sistema necesita saber exactamente qué está esperando.
\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap02-ioTable.png}
\end{center}

La **tabla de archivos** coordina el acceso al sistema de archivos. Registra todos los archivos abiertos en el sistema, la ubicación de cada archivo en el almacenamiento, el estado de acceso actual (lectura, escritura, compartido), y los locks y permisos por archivo. Un mismo archivo puede estar abierto por múltiples procesos, y esta tabla asegura que las operaciones concurrentes se manejen correctamente.
\begin{center}
\includegraphics[width=\linewidth,height=\textheight,keepaspectratio]{src/tables/cap02-fileTable.png}
\end{center}


### Imagen de un Proceso

La imagen del proceso representa la huella completa que un proceso deja en memoria. No es simplemente el código ejecutable, sino una estructura compleja dividida en segmentos especializados, cada uno con un propósito específico.  
El \textbf{text segment} contiene las instrucciones ejecutables del programa. Este segmento es read-only para prevenir modificaciones accidentales del código, y puede ser compartido entre múltiples procesos que ejecutan el mismo programa. Se carga directamente desde el archivo ejecutable al iniciar el proceso.  

El \textbf{data segment} se divide en dos regiones. La sección de datos inicializados contiene variables globales y estáticas que tienen un valor inicial definido en el código fuente. La sección BSS (\textit{Block Started by Symbol}) contiene variables globales y estáticas no inicializadas, que el sistema operativo inicializa automáticamente a cero. Este segmento es read-write y específico para cada proceso.  
\begin{center}
\begin{minipage}{0.55\linewidth}  

El \textbf{heap} es donde vive la memoria dinámica solicitada por el proceso mediante funciones como \texttt{malloc()} o el operador \texttt{new}. Crece hacia direcciones de memoria altas según el proceso solicita más memoria, y es completamente gestionado por el proceso (y las bibliotecas de manejo de memoria).  

El \textbf{stack} contiene variables locales de funciones, parámetros pasados a funciones, direcciones de retorno, y frame pointers. Crece hacia direcciones de memoria bajas, en dirección opuesta al heap. Esta organización permite que heap y stack compartan el espacio disponible de manera flexible.
\end{minipage}%
\hspace{0.05\linewidth}%
\begin{minipage}{0.35\linewidth}
\includegraphics[width=\linewidth,keepaspectratio]{src/images/capitulo-02/layout-memoria.jpg}
\end{minipage}
\end{center}
\begin{warning}
La separación entre heap y stack creciendo en direcciones opuestas no es arbitraria. Si crecieran en la misma dirección, sería necesario decidir de antemano cuánto espacio asignar a cada uno. Con este diseño, heap y stack pueden crecer dinámicamente hasta encontrarse, maximizando el uso eficiente de la memoria disponible.
\end{warning}

### Process Control Block (PCB)  

El PCB es, sin exageración, la estructura de datos más importante para el manejo de procesos en cualquier sistema operativo. Es el "documento de identidad completo" de cada proceso, conteniendo absolutamente toda la información que el sistema operativo necesita para gestionar ese proceso.  

\begin{theory}
El PCB existe porque el sistema operativo debe ser capaz de suspender un proceso en ejecución en cualquier momento y luego reanudarlo exactamente donde quedó, como si nunca hubiera sido interrumpido. Para lograr esta ilusión de ejecución continua, el PCB debe capturar el estado completo del proceso con precisión absoluta.
\end{theory}

```c
struct process_control_block {
    // Identificación del proceso
    pid_t pid;                    // Process ID único
    pid_t ppid;                   // Parent Process ID
    uid_t uid;                    // User ID del propietario
    gid_t gid;                    // Group ID
    
    // Estado del proceso
    int state;                    // NEW, READY, RUNNING, etc.
    int priority;                 // Prioridad de scheduling
    
    // Contexto del procesador
    struct cpu_context {
        unsigned long regs[16];   // Registros de propósito general
        unsigned long pc;         // Program Counter
        unsigned long sp;         // Stack Pointer
        unsigned long psw;        // Program Status Word
    } context;
    
    // Información de memoria
    struct memory_map {
        unsigned long code_start, code_end;
        unsigned long data_start, data_end;
        unsigned long heap_start, heap_end;
        unsigned long stack_start, stack_end;
        struct page_table *pgd;   // Page Global Directory
    } mm;
    
    // Información de archivos
    struct files_struct {
        int max_fds;              // Máximo file descriptors
        struct file **fd_array;   // Array de archivos abiertos
    } files;
    
    // Manejo de señales
    struct signal_struct {
        unsigned long pending;    // Señales pendientes
        struct sigaction actions[32]; // Handlers por señal
    } signals;
    
    // Información de scheduling
    int time_slice;               // Quantum restante
    unsigned long cpu_time_used;  // Tiempo de CPU acumulado
    
    // Enlaces en listas del SO
    struct list_head run_list;    // Lista de procesos READY
    struct list_head children;    // Lista de procesos hijos
    struct pcb *parent;           // Puntero al proceso padre
};
```

Esta estructura, aunque simplificada, revela los componentes esenciales. La sección de identificación del proceso incluye el PID único del proceso, el PPID de su proceso padre, y los identificadores de usuario y grupo del propietario. La sección de estado del proceso mantiene el estado actual (NEW, READY, RUNNING, etc.) y la prioridad de scheduling.  

El contexto del procesador es quizás la parte más crítica: contiene todos los registros de propósito general, el program counter (PC) que indica la próxima instrucción a ejecutar, el stack pointer (SP), y el program status word (PSW) con flags y modos del procesador. Esta información es exactamente lo que se guarda y restaura durante un context switch.  

La información de memoria describe el mapa de memoria del proceso: dónde comienzan y terminan los segmentos de código, datos, heap y stack, y punteros a las estructuras de memoria virtual como la tabla de páginas. La sección de archivos mantiene la tabla de file descriptors abiertos por el proceso.
El manejo de señales registra qué señales están pendientes de entrega y los handlers definidos para cada señal. Finalmente, la información de scheduling incluye el quantum restante del proceso, el tiempo de CPU acumulado, y enlaces a las diferentes listas del sistema operativo (ready queue, wait queues, lista de hijos, etc.).  

\begin{example}
Cuando presionás Ctrl+Z en tu terminal para suspender un programa, el sistema operativo guarda el estado completo del proceso en su PCB y lo mueve a una lista de procesos suspendidos. Cuando después ejecutás \texttt{fg} para continuarlo, el sistema restaura ese estado desde el PCB, y el programa continúa exactamente donde lo dejaste, completamente inconsciente de que estuvo suspendido.
\end{example}

### Diagramas de Estado de Procesos
\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap02-cincoEstadosProcesos.png}
\end{center}
El modelo de cinco estados representa el comportamiento fundamental de los procesos. Un proceso comienza su vida en el estado NEW, recién creado pero aún no admitido al pool de procesos ejecutables.  
Una vez que el sistema operativo lo admite (transición admit), pasa al estado READY, donde está listo para ejecutarse y simplemente espera que el scheduler le asigne tiempo de CPU.  

Cuando el dispatcher selecciona el proceso (transición dispatch), entra al estado RUNNING, donde sus instrucciones se ejecutan activamente en la CPU. Desde este estado, pueden ocurrir tres cosas. Si el proceso realiza una operación bloqueante como una syscall de I/O (transición block), pasa al estado BLOCKED, donde espera que el evento se complete. Si su quantum de tiempo expira o llega un proceso de mayor prioridad (transición preempt), vuelve a READY para esperar su próximo turno. Finalmente, cuando el proceso completa su ejecución o es terminado (transición exit), alcanza el estado EXIT o terminal.
Cuando un proceso en estado BLOCKED recibe la notificación de que su evento se completó (transición wakeup), no vuelve inmediatamente a RUNNING, sino que pasa a READY. Esto es crucial: el proceso debe esperar su turno como cualquier otro proceso, evitando que operaciones de I/O den prioridad injusta.

\begin{excerpt}
La razón por la cual BLOCKED va a READY y no directamente a RUNNING es fundamental para la justicia del sistema: un proceso que completa su I/O no debe "saltarse la fila" de procesos que ya estaban esperando pacientemente en la ready queue.
\end{excerpt}

**El Dispatcher** es el componente del sistema operativo responsable de ejecutar el context switch. Su lógica es conceptualmente simple pero técnicamente compleja:

```c
void dispatcher() {
    while (sistema_activo) {
        proceso_actual = scheduler();  // Seleccionar próximo proceso
        context_switch(proceso_anterior, proceso_actual);
        // Al retornar aquí, proceso_actual ha ejecutado
    }
}
```

Este loop nunca termina mientras el sistema esté activo. Llama al scheduler para seleccionar el próximo proceso, ejecuta el cambio de contexto completo, y cuando ese proceso eventualmente cede la CPU (por preemption, bloqueo, o terminación), el dispatcher retoma el control y el ciclo continúa.


**Diagrama de 7 Estados (Con Swapping):**  
\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap02-sieteEstadosProcesos.png}
\end{center}


El modelo de siete estados extiende el modelo básico para incorporar *swapping*, la capacidad del sistema operativo de mover procesos entre memoria principal y disco para gestionar escasez de memoria. Esto agrega dos estados nuevos: **READY/SUSPENDED**, donde un proceso está listo para ejecutar pero ha sido swappeado a disco, y **BLOCKED/SUSPENDED**, donde el proceso está esperando un evento y también ha sido movido a disco.  

Las razones para hacer swapping son pragmáticas. Cuando la memoria es insuficiente para mantener todos los procesos activos, el sistema debe liberar espacio moviendo algunos procesos a disco. Los procesos que llevan mucho tiempo inactivos son candidatos naturales. El sistema operativo también puede decidir hacer swapping para balancear la carga del sistema, priorizando procesos más importantes o con mayor actividad.  

\begin{warning}
El swapping introduce latencia significativa. Mover un proceso de disco a memoria puede tomar milisegundos, una eternidad en términos de CPU. Por eso, los sistemas operativos modernos intentan minimizar el swapping mediante algoritmos sofisticados de manejo de memoria y predicción de comportamiento de procesos.
\end{warning}


**Tres Niveles de Planificación:**

Los sistemas operativos modernos emplean tres niveles de planificación, cada uno operando en escalas de tiempo diferentes y con objetivos distintos.

El **Long-Term Scheduler** (también llamado *job scheduler* o *admission scheduler*) controla el grado de multiprogramación decidiendo qué procesos admitir desde el estado NEW a READY. Ejecuta con poca frecuencia, típicamente cada varios segundos, y su objetivo es mantener un balance saludable entre procesos CPU-bound (que usan intensivamente el procesador) y procesos I/O-bound (que pasan mucho tiempo esperando operaciones de entrada/salida).  

El **Medium-Term Scheduler** (o *swapper*) decide qué procesos mover entre memoria y disco. Opera en una escala de tiempo intermedia, ejecutando cada varios segundos, y gestiona qué procesos deben permanecer en memoria activa. Típicamente suspende procesos que no están usando la CPU activamente o que llevan mucho tiempo bloqueados.  

El **Short-Term Scheduler** (o *CPU scheduler* o *dispatcher*) es el más frecuente y crítico. Ejecuta cada 10-100 milisegundos y decide qué proceso de la ready queue debe recibir la CPU en cada momento. Implementa los algoritmos de scheduling como FIFO, Shortest Job First, Round Robin, scheduling por prioridades, etc.  

\begin{infobox}
La frecuencia de ejecución del short-term scheduler explica por qué debe ser extremadamente eficiente. Si el scheduler tarda 1 ms en tomar una decisión y otorga quanta de 10 ms, entonces el 10\% del tiempo de CPU se desperdicia en overhead de scheduling. Esta es la razón por la cual los algoritmos de scheduling deben ser no solo justos y eficientes, sino también computacionalmente baratos.
\end{infobox}


## Análisis Técnico

### Creación de Procesos en Unix/Linux

En Unix y sistemas derivados como Linux, los procesos se crean mediante una syscall peculiar y elegante llamada `fork()`. Su comportamiento es único en la historia de las interfaces de programación: crea una copia casi exacta del proceso que la invoca.  

Las características de `fork()` son fascinantes. Cuando un proceso llama a `fork()`, el sistema operativo crea un nuevo proceso hijo que es una copia exacta del padre. Ambos procesos continúan ejecutándose desde el punto inmediatamente después del llamado a `fork()`, pero el valor de retorno es diferente en cada uno, permitiendo que ambos identifiquen su rol. En el proceso padre, `fork()` retorna el PID del hijo recién creado. En el proceso hijo, `fork()` retorna 0. Si ocurre un error, `fork()` retorna -1.  

Una optimización crucial en implementaciones modernas es *Copy-on-Write* (CoW). En lugar de copiar inmediatamente todas las páginas de memoria del padre al hijo, ambos procesos inicialmente comparten las mismas páginas físicas marcadas como read-only. Solo cuando alguno intenta modificar una página, el sistema operativo hace una copia real de esa página. Esto hace que `fork()` sea extremadamente eficiente, especialmente cuando el hijo inmediatamente ejecuta un `exec()`.  

El algoritmo simplificado de `fork()` revela su funcionamiento interno:
```
1. Asignar nuevo PID al proceso hijo
2. Copiar PCB del padre al hijo
3. Copiar espacio de direcciones (CoW)
4. Agregar hijo a la tabla de procesos
5. Retornar:
   - En el padre: PID del hijo (> 0)
   - En el hijo: 0
   - Error: -1
```

\begin{theory}
El diseño de \texttt{fork()} refleja la filosofía Unix de "hacer una cosa y hacerla bien". Separa la creación del proceso de la carga de un nuevo programa, dando flexibilidad máxima. Entre el \texttt{fork()} y un eventual \texttt{exec()}, el proceso hijo puede configurar su entorno, redireccionar archivos, cerrar descriptores, cambiar su directorio de trabajo, etc.
\end{theory}

### Carga de Programas: exec()

Mientras `fork()` crea procesos, la familia de funciones `exec()` transforma procesos existentes cargando un nuevo programa. Esta separación de responsabilidades es un diseño brillante que habilita capacidades poderosas.  

Los pasos de `exec()` son sistemáticos y destructivos para el proceso que lo invoca. Primero, verifica que el archivo ejecutable existe y que el proceso tiene permisos para ejecutarlo. Luego, lee los headers del archivo (formato ELF en Linux, Mach-O en macOS, PE en Windows) para entender su estructura. A continuación, libera toda la memoria anterior del proceso, destruyendo completamente el código, datos, heap y stack previos. Carga los nuevos segmentos del programa (text, data, bss) en memoria e inicializa un nuevo stack con los argumentos proporcionados. Finalmente, transfiere el control al punto de entrada del nuevo programa.  

Un detalle crítico: `exec()` NO crea un nuevo proceso, transforma el proceso actual. El PID permanece igual, el PPID permanece igual, y muchos atributos del proceso se conservan (como file descriptors que no tienen el flag `FD_CLOEXEC`). El único cambio drástico es que el código en ejecución es completamente diferente.
\begin{example}
Cuando ejecutás un comando en tu shell como ls -l, el shell primero hace \texttt{fork()} para crear un proceso hijo, y luego ese hijo hace exec("/bin/ls", "ls", "-l", NULL) para transformarse en el comando ls. El shell (proceso padre) espera con \texttt{wait()} a que el hijo termine. Esta es la mecánica fundamental de cómo funciona cualquier shell Unix.
\end{example}

### Terminación de Procesos

Los procesos pueden terminar de dos maneras fundamentalmente diferentes: normalmente o anormalmente. Cada una tiene implicaciones distintas para el sistema.  
La **terminación normal** ocurre cuando un proceso completa su tarea exitosamente. Puede llamar explícitamente a `exit(status)` con un código de salida que indica el resultado de su ejecución, o puede simplemente ejecutar un return en la función `main()`, que el compilador traduce automáticamente a una llamada a `exit()` con el valor retornado.  
La **terminación anormal** sucede cuando algo sale mal. Las señales son el mecanismo principal: SIGKILL termina el proceso inmediatamente sin posibilidad de cleanup, `SIGSEGV` indica un acceso inválido a memoria, `SIGABRT` es enviada cuando el programa llama a `abort()`, etc. Estas terminaciones a menudo indican errores de programación o condiciones excepcionales.  
Después de la terminación, el proceso entra en estados especiales que merecen atención particular. Un **proceso zombie** es aquel que ha terminado completamente su ejecución pero cuyo PCB permanece en el sistema porque el proceso padre aún no ha leído su código de salida mediante `wait()`. **Un proceso huérfano** es aquel cuyo padre murió antes que él, dejándolo sin supervisor.  

### Procesos Zombies y Huérfanos

Estos dos estados especiales representan casos extremos en el ciclo de vida de los procesos, y entenderlos es crucial para programación de sistemas robusta.  

Un **proceso zombie** se define formalmente como un proceso que ha completado su ejecución pero cuyo PCB permanece en la tabla de procesos. La causa es simple pero tiene consecuencias: el proceso padre no ha llamado a `wait()` para leer el exit status del hijo. En el output de comandos como `ps`, estos procesos aparecen como "defunct" o con estado "Z". El problema con los zombies es que consumen entradas en la tabla de procesos, un recurso finito. Si un programa crea muchos hijos sin hacer `wait()`, eventualmente puede agotar este recurso.

*Ejemplo de Zombie:*
```c
if (fork() == 0) {
    // Hijo termina rápidamente
    exit(42);
}
// Padre NO hace wait() y continúa ejecutando
sleep(60);  // Hijo queda zombie por 1 minuto
```

La solución a los zombies tiene dos enfoques principales. El padre debe llamar a `wait()` o `waitpid()` oportunamente para leer el estado de terminación de sus hijos. Alternativamente, puede configurar un handler para la señal `SIGCHLD` que haga el cleanup automáticamente. Es importante notar que ejecutar kill sobre un proceso zombie no tiene efecto: ya está muerto, solo esperando que su padre lea su estado final.
\begin{warning}
Un proceso zombie no consume memoria ni CPU, solo una entrada en la tabla de procesos. Sin embargo, en un sistema con miles de procesos, esta puede ser una fuga de recursos significativa. Los zombies son síntoma de programación descuidada, no un bug del sistema operativo.
\end{warning}

Un **proceso huérfano** tiene una historia diferente. Ocurre cuando el padre de un proceso muere antes que el hijo, dejándolo sin supervisor. El sistema operativo no permite esta orfandad permanente: automáticamente reasigna el proceso huérfano como hijo del proceso `init` (PID 1, o systemd en sistemas modernos). Este proceso especial adopta a todos los huérfanos del sistema. El comportamiento del huérfano no cambia; continúa ejecutándose normalmente. Cuando eventualmente termina, `init` hace `wait()` automáticamente, evitando que se convierta en zombie.

*Ejemplo de Huérfano:*
```c
if (fork() == 0) {
    // Hijo duerme por mucho tiempo
    sleep(300);  
    exit(0);
}
// Padre termina inmediatamente
exit(0);
// Hijo queda huérfano, adoptado por init
```
Los procesos huérfanos son en realidad inofensivos e incluso útiles. Los daemons (servicios que corren en segundo plano) a menudo se vuelven huérfanos deliberadamente: el proceso inicial hace `fork()`, configura el hijo como daemon, y termina, dejando al daemon como huérfano que `init` adopta.

## Código en C

### Creación Básica de Procesos

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
    pid_t pid;
    int status;
    
    printf("Antes del fork - PID: %d\n", getpid());
    
    // Crear proceso hijo
    pid = fork();
    
    if (pid == -1) {
        // Error en fork()
        perror("fork failed");
        exit(1);
    }
    else if (pid == 0) {
        // Código del HIJO
        printf("Soy el hijo - PID: %d, PPID: %d\n", 
               getpid(), getppid());
        
        // Simular trabajo
        sleep(2);
        printf("Hijo terminando...\n");
        exit(42);  // Código de salida
    }
    else {
        // Código del PADRE
        printf("Soy el padre - PID: %d, hijo PID: %d\n", 
               getpid(), pid);
        
        // Esperar al hijo
        wait(&status);
        
        // Analizar cómo terminó el hijo
        if (WIFEXITED(status)) {
            printf("Hijo terminó normalmente con código: %d\n", 
                   WEXITSTATUS(status));
        }
    }
    
    printf("Proceso %d terminando\n", getpid());
    return 0;
}
```
Este ejemplo demuestra todos los elementos fundamentales del uso de `fork()`. La línea con `getpid()` muestra el PID del proceso antes del fork, estableciendo un punto de referencia. El llamado a `fork()` es el momento crucial donde un proceso se convierte en dos.  

El manejo de errores en las líneas 15-18 es esencial: `fork()` puede fallar si el sistema ha alcanzado límites de procesos o si no hay recursos disponibles. Las líneas 19-26 contienen código que SOLO ejecuta el proceso hijo, identificado porque `fork()` retornó 0. El hijo puede llamar a `getppid()` para obtener el PID de su padre, confirmando la relación padre-hijo.  

El código del padre en las líneas 27-38 es igualmente importante. La llamada a `wait(&status)` es bloqueante: el padre se suspende hasta que el hijo termine. Las macros `WIFEXITED()` y `WEXITSTATUS()` extraen información del status: si el hijo terminó normalmente y cuál fue su código de salida.
\begin{example}
La última línea printf("Proceso \%d terminando", \texttt{getpid()}) se ejecutará dos veces: una por el padre y otra por el hijo. Sin embargo, verás que la línea del hijo aparece antes de que el padre imprima el análisis del status, porque el padre estaba bloqueado en \texttt{wait()}.
\end{example}

### Usando exec() para cargar programas

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main() {
    pid_t pid;
    
    pid = fork();
    
    if (pid == -1) {
        perror("fork");
        exit(1);
    }
    else if (pid == 0) {
        // HIJO: ejecutar comando "ls -l"
        printf("Hijo antes de exec - PID: %d\n", getpid());
        
        // execl: último parámetro debe ser NULL
        execl("/bin/ls", "ls", "-l", NULL);
        
        // Si llegamos aquí, exec falló
        perror("exec failed");
        exit(1);
    }
    else {
        // PADRE: esperar al hijo
        int status;
        wait(&status);
        
        printf("Comando terminó con status: %d\n", 
               WEXITSTATUS(status));
    }
    
    return 0;
}
```

Este código ilustra el patrón clásico fork-exec que todos los shells utilizan. El proceso padre hace `fork()` para crear un hijo que se sacrificará transformándose en otro programa. En la línea 18, antes del `exec()`, imprimimos el PID del hijo, demostrando que existe como proceso independiente.  

La llamada a `execl()` en la línea 20 es el momento de transformación. El primer argumento es el path completo al ejecutable, el segundo es el `argv[0]` que el programa verá (por convención, el nombre del programa), seguido de los argumentos reales, y terminando obligatoriamente con `NULL`.  

Las líneas 22-24 son código que idealmente nunca se ejecuta. Si `exec()` tiene éxito, el proceso se transforma completamente y este código deja de existir. Solo si `exec()` falla (archivo no encontrado, sin permisos, formato inválido) se ejecutarán estas líneas para reportar el error.  

El padre espera pacientemente con `wait()`, y cuando el comando termina, examina su código de salida. Es notable que el padre puede esperar al hijo con `wait()` incluso después de que hizo `exec()`: el PID del hijo no cambió, solo su contenido.

### Manejo de múltiples hijos

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#define NUM_HIJOS 3

int main() {
    pid_t hijos[NUM_HIJOS];
    int i, status;
    
    // Crear múltiples hijos
    for (i = 0; i < NUM_HIJOS; i++) {
        hijos[i] = fork();
        
        if (hijos[i] == -1) {
            perror("fork");
            exit(1);
        }
        else if (hijos[i] == 0) {
            // Código del hijo
            printf("Hijo %d - PID: %d iniciando\n", i, getpid());
            
            // Simular trabajo variable
            sleep(i + 1);
            
            printf("Hijo %d terminando\n", i);
            exit(i);  // Cada hijo retorna su número
        }
        // El padre continúa el loop
    }
    
    // Padre espera a TODOS los hijos
    printf("Padre esperando a %d hijos...\n", NUM_HIJOS);
    
    for (i = 0; i < NUM_HIJOS; i++) {
        pid_t pid_terminado = wait(&status);
        
        printf("Hijo PID %d terminó con código %d\n", 
               pid_terminado, WEXITSTATUS(status));
    }
    
    printf("Todos los hijos terminaron\n");
    return 0;
}
```

Este ejemplo demuestra cómo manejar varios hijos simultáneamente, un escenario común en servidores y aplicaciones paralelas. El loop en las líneas 13-30 crea tres hijos secuencialmente, pero hay un detalle sutil: después de cada `fork()`, AMBOS procesos (padre e hijo) continúan ejecutando el loop. Sin embargo, el hijo encuentra `hijos[i] == 0` e inmediatamente ejecuta su código y termina, evitando crear sus propios hijos.  

Cada hijo simula trabajo diferente (línea 25) durmiendo por `i + 1` segundos, lo que significa que terminarán en orden diferente al que fueron creados. Esto es crucial para el siguiente punto.  

El segundo loop (líneas 36-41) es donde el padre recolecta a sus hijos. Nota que usa `wait()` sin especificar qué hijo esperar, lo que significa que `wait()` retorna para el primer hijo que termine, sin importar su orden de creación. La variable `pid_terminado` contiene el PID del hijo que terminó, permitiendo al padre identificarlo.
\begin{infobox}
Si necesitás esperar a un hijo específico, usá waitpid(pid, \&status, 0) en lugar de wait(\&status). Esto bloquea hasta que el hijo específico con ese PID termine, ignorando otros hijos que pudieran terminar antes.
\end{infobox}

### Comunicación entre procesos: pipes

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>

int main() {
    int pipefd[2];  // pipefd[0] = read, pipefd[1] = write
    pid_t pid;
    char buffer[100];
    
    // Crear pipe antes del fork
    if (pipe(pipefd) == -1) {
        perror("pipe");
        exit(1);
    }
    
    pid = fork();
    
    if (pid == -1) {
        perror("fork");
        exit(1);
    }
    else if (pid == 0) {
        // HIJO: escritor del pipe
        close(pipefd[0]);  // Cerrar extremo de lectura
        
        char *mensaje = "Hola desde el hijo!";
        write(pipefd[1], mensaje, strlen(mensaje) + 1);
        
        close(pipefd[1]);  // Cerrar extremo de escritura
        exit(0);
    }
    else {
        // PADRE: lector del pipe
        close(pipefd[1]);  // Cerrar extremo de escritura
        
        // Leer mensaje del hijo
        ssize_t bytes_leidos = read(pipefd[0], buffer, sizeof(buffer));
        
        if (bytes_leidos > 0) {
            printf("Padre recibió: %s\n", buffer);
        }
        
        close(pipefd[0]);  // Cerrar extremo de lectura
        wait(NULL);        // Esperar al hijo
    }
    
    return 0;
}
```
Los pipes son el mecanismo más simple de IPC (Inter-Process Communication) en Unix, perfecto para comunicación unidireccional entre procesos relacionados. Este ejemplo muestra el flujo completo.
La llamada a `pipe(pipefd)` en la línea 13 crea el pipe ANTES del fork, lo cual es esencial. Esto asegura que tanto padre como hijo tengan acceso a los mismos file descriptors del pipe. El array pipefd recibe dos descriptores: `pipefd[0]` es el extremo de lectura, `pipefd[1]` es el extremo de escritura.  

Después del fork, cada proceso cierra el extremo que no va a usar (líneas 25 y 35). Esto no es opcional: es crítico para el correcto funcionamiento. Si el hijo no cierra `pipefd[0]`, el pipe nunca indicará EOF cuando el escritor termine. Si el padre no cierra `pipefd[1]`, podría bloquearse indefinidamente esperando datos que nunca llegarán.  

El hijo escribe su mensaje (línea 28) y cierra su extremo de escritura (línea 30). El padre lee del pipe (línea 38) y el sistema garantiza que recibirá exactamente los bytes que el hijo escribió, en orden. La llamada a `read()` es bloqueante: si no hay datos disponibles, el padre espera.
\begin{warning}
Los pipes tienen un buffer limitado (típicamente 4KB-64KB). Si un proceso escribe más datos de los que el buffer puede contener sin que nadie los lea, \texttt{write()} se bloqueará. Esto puede causar deadlocks si no se maneja correctamente la comunicación bidireccional.
\end{warning}

## Casos de Estudio

### Caso de Estudio 1: Análisis de fork() múltiple

Este tipo de ejercicio aparece frecuentemente en exámenes porque revela comprensión profunda de cómo opera `fork()`. El desafío es rastrear mentalmente la multiplicación de procesos.

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int x = 5;
    
    fork();
    fork();
    x++;
    
    printf("PID: %d, x = %d\n", getpid(), x);
    return 0;
}
```

La resolución requiere seguir la ejecución paso a paso, prestando atención a que cada proceso continúa ejecutando el código secuencialmente. Comenzamos con un solo proceso donde `x = 5`. El primer `fork()` crea un hijo, resultando en dos procesos ejecutando la misma instrucción siguiente. Cuando ambos ejecutan el segundo `fork()`, cada uno crea su propio hijo, llevando el total a cuatro procesos.  

El incremento `x++` ocurre en cada uno de los cuatro procesos independientemente. Recordá que después de un `fork()`, padre e hijo tienen copias separadas de todas las variables. Modificar x en un proceso no afecta a los otros. Cada proceso incrementa su propia copia de x de 5 a 6.  

El `printf()` final se ejecuta cuatro veces, una por cada proceso, mostrando cuatro PIDs diferentes pero el mismo valor de `x = 6`. Los PIDs serán asignados por el sistema operativo y variarán en cada ejecución.  

La fórmula general 2^n procesos con n forks secuenciales funciona porque cada fork dobla el número de procesos existentes. Con 0 forks hay 1 proceso. Con 1 fork hay 2 procesos. Con 2 forks hay 4 procesos. Con 3 forks hay 8 procesos, y así sucesivamente.  
\begin{example}
Un error común es pensar que el segundo \texttt{fork()} solo lo ejecuta el padre original. En realidad, después del primer \texttt{fork()}, HAY DOS PROCESOS ejecutando el código, y ambos llegan al segundo \texttt{fork()} y lo ejecutan.
\end{example}

### Caso de Estudio 2: Problema de procesos zombie

Este caso ilustra un anti-patrón común: crear procesos y olvidarse de ellos. Es un bug de recursos que puede degradar seriamente un sistema con el tiempo.

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main() {
    int i;
    
    for (i = 0; i < 5; i++) {
        if (fork() == 0) {
            // Hijo termina rápidamente
            printf("Hijo %d terminando\n", i);
            exit(0);
        }
    }
    
    // Padre NO hace wait()
    printf("Padre durmiendo 30 segundos...\n");
    sleep(30);  // Mientras tanto, ejecutar: ps aux | grep Z
    
    return 0;
}
```

El problema es evidente pero sutil. El loop crea cinco hijos rápidamente. Cada hijo imprime un mensaje y termina inmediatamente con `exit(0)`. Mientras tanto, el padre no hace ningún `wait()`, sino que simplemente duerme por 30 segundos. Durante esos 30 segundos, los cinco hijos están muertos pero sus PCBs permanecen en la tabla de procesos como zombies.  

Podés verificar esto ejecutando el programa y, mientras el padre duerme, usar `ps aux | grep Z` en otra terminal. Verás cinco procesos con estado "Z" o "defunct". Estos procesos no consumen memoria ni CPU, pero ocupan slots en la tabla de procesos.  

La Solución 1 es directa: después del loop de creación, agregar un loop que haga `wait()` cinco veces. Esto bloqueará al padre hasta que los cinco hijos terminen, pero asegura que sus recursos se liberen correctamente.

```c
// Después del bucle
for (i = 0; i < 5; i++) {
    wait(NULL);
}
```

La Solución 2 usa un enfoque más elegante para procesos que no necesitan conocer el exit status de sus hijos. Al establecer el handler de `SIGCHLD` a `SIG_IGN`, le decimos al kernel que automáticamente limpie los hijos terminados sin crear zombies. Esto se llama "auto-reaping".  

```c
#include <signal.h>

int main() {
    signal(SIGCHLD, SIG_IGN);  // Auto-reaping de hijos
    // ... resto del código
}
```

\begin{warning}
Ignorar \texttt{SIGCHLD} no es equivalente a no hacer nada. El comportamiento default de \texttt{SIGCHLD} es \textit{ser ignorado} (no terminar el proceso), pero eso NO previene zombies. Solo establecer explícitamente \texttt{$signal(SIGCHLD, SIG_IGN)$} activa el auto-reaping. Esta distinción confunde a muchos programadores.
\end{warning}


## Síntesis

### Puntos Clave para Parcial

Esta sección destila los conceptos que más frecuentemente aparecen en exámenes y que forman la base conceptual del capítulo.  
La diferencia entre *proceso y programa* es fundamental: un programa es código estático en disco, mientras que un proceso es esa código ejecutándose con contexto completo (registros, memoria, archivos abiertos, etc.). El PCB es la estructura de datos que materializa esta diferencia, conteniendo absolutamente todo lo que el sistema operativo necesita saber sobre un proceso.  

Los *estados de un proceso* no son arbitrarios sino que reflejan las realidades del hardware y la concurrencia: NEW cuando está siendo creado, READY cuando está listo pero esperando CPU, RUNNING cuando está ejecutándose, BLOCKED cuando espera un evento externo, y TERMINATED cuando ha finalizado. Los modelos extendidos agregan estados SUSPENDED para manejar swapping.  

Las *syscalls* fundamentales tienen comportamientos que debés memorizar. `fork()` retorna el PID del hijo al padre, 0 al hijo, y -1 en caso de error. `exec()` reemplaza completamente la imagen del proceso pero mantiene el mismo PID. `wait()` bloquea al padre hasta que un hijo termine, evitando procesos zombie. `getpid()` y `getppid()` permiten a un proceso conocer su identidad y ascendencia.  

Las diferencias entre modelos de procesamiento se prestan a preguntas de opción múltiple. La monoprogramación ejecuta un programa por vez, desperdiciando CPU durante I/O. La multiprogramación mantiene múltiples programas en memoria, alternando entre ellos para maximizar uso de CPU. La multitarea extiende esto con preemption, permitiendo interrumpir procesos arbitrariamente. El multiprocesamiento agrega múltiples CPUs físicos para verdadero paralelismo.  

Las *estructuras del SO* son interconectadas: la tabla de procesos es el punto de entrada que referencia a las tablas de memoria, I/O, y archivos. La imagen del proceso en memoria se divide en segmentos especializados: text (código read-only), data (variables globales), BSS (datos no inicializados), heap (memoria dinámica creciendo hacia arriba), y stack (variables locales creciendo hacia abajo).
Los diagramas de estado formalizan las transiciones posibles. El modelo de 5 estados incluye: admit (NEW→READY), dispatch (READY→RUNNING), timeout/preempt (RUNNING→READY), block (RUNNING→BLOCKED), wakeup (BLOCKED→READY), y exit (RUNNING→TERMINATED). El modelo de 7 estados agrega estados suspended y transiciones de swapping.

### Errores Comunes y Tips
Identificar errores típicos ayuda a evitarlos en código propio y reconocerlos en exámenes.
No verificar el retorno de `fork()` es el error más básico pero sorprendentemente común. Sin verificación, el código del padre y del hijo se mezcla indistinguiblemente.  

No cerrar extremos no usados de pipes causa bloqueos sutiles. Si el proceso que lee no cierra el extremo de escritura, `read()` nunca retornará EOF. Si el escritor no cierra el extremo de lectura, desperdicia recursos y puede causar condiciones de carrera.  

No hacer `wait()` de los hijos crea zombies que acumulan recursos. En un sistema de producción, esto puede eventualmente agotar la tabla de procesos, causando que `fork()` falle para todos los usuarios.
Asumir orden de ejecución entre padre e hijo es un error conceptual profundo. Después de un `fork()`, el orden de ejecución es completamente no determinístico. Nunca escribas código que dependa de que el padre o el hijo ejecute primero.  

Confundir grado de multiprogramación con multiprocesamiento revela falta de comprensión terminológica. Grado de multiprogramación = número de procesos en memoria. Multiprocesamiento = número de CPUs físicos. Son conceptos ortogonales: *podés tener multiprogramación en una sola CPU, o multiprocesamiento con bajo grado de multiprogramación.*  

No distinguir entre estados blocked y suspended es otro error conceptual. Un proceso BLOCKED está en memoria, esperando un evento. Un proceso BLOCKED/SUSPENDED está en disco, esperando un evento. La diferencia afecta dramáticamente el tiempo de respuesta cuando el evento ocurre.

\begin{example}
Un ejercicio mental útil: imaginá un proceso que hace \texttt{read()} de un socket de red. Si está en BLOCKED, cuando lleguen los datos puede comenzar a ejecutarse en milisegundos. Si está en BLOCKED/SUSPENDED, primero debe ser swappeado de vuelta a memoria, lo que puede tomar decenas o cientos de milisegundos adicionales.
\end{example}


### Conexión con Próximos Temas

Los procesos no son un tema aislado sino la fundación sobre la cual se construyen todos los conceptos subsiguientes del curso.  
El capítulo de **Planificación** explora en profundidad las transiciones READY → RUNNING → READY que apenas tocamos aquí. Los tres niveles de planificadores (long-term, medium-term, short-term) deciden el flujo de procesos a través del sistema, y los algoritmos de scheduling (FIFO, SJF, Round Robin, prioridades) determinan qué proceso de la ready queue ejecutar y por cuánto tiempo.  

Los **Hilos** representan múltiples flujos de ejecución dentro de un solo proceso. Comparten el mismo espacio de direcciones (segmentos text, data, heap) pero tienen stacks separados, permitiendo paralelismo real en sistemas multiprocesador sin el overhead de procesos completos.  

La **Sincronización** se vuelve necesaria cuando procesos o hilos comparten recursos. Las race conditions surgen cuando múltiples flujos de ejecución acceden datos compartidos concurrentemente sin coordinación. Semáforos, mutexes, y monitores son las herramientas para resolver estos problemas.  

El **Interbloqueo** es un problema exclusivo de sistemas concurrentes: procesos pueden bloquearse mutuamente esperando recursos que otros poseen. Las cuatro condiciones necesarias (exclusión mutua, hold-and-wait, no preemption, espera circular) y los algoritmos de prevención/detección se estudian en detalle.  

La **Gestión de Memoria** profundiza en cómo cada proceso obtiene su espacio de direcciones virtual aparentemente privado. El PCB mantiene información crucial de memory management (page tables, segmentos), y el swapping de estados SUSPENDED mueve procesos entre memoria y disco según políticas complejas.  

El **Sistema de Archivos** se conecta porque los procesos acceden archivos mediante file descriptors mantenidos en el PCB. La herencia de descriptores en `fork()` y su cierre/preservación en `exec()` habilitan patrones poderosos como redirección de I/O en shells.


### Preguntas de Reflexión
Estas preguntas van más allá de la memorización, requiriendo síntesis de múltiples conceptos.  

¿Por qué `fork()` + `exec()` en lugar de una sola syscall "`create_process()`"? Esta separación proporciona flexibilidad extraordinaria. Entre el `fork()` y el `exec()`, el proceso hijo puede configurar su entorno: cambiar su working directory, modificar variables de entorno, redirigir stdin/stdout/stderr, cerrar file descriptors innecesarios, cambiar su user/group ID, etc. Esta flexibilidad habilita shells sofisticados, pipes, redirección, y job control. Además, refleja la filosofía Unix de herramientas pequeñas con funciones únicas que se combinan poderosamente.  

¿Qué pasaría si no existieran los niveles de privilegio (modo kernel/usuario)? El sistema sería fundamentalmente inseguro e inestable. Cualquier programa podría acceder directamente a hardware, corromper memoria de otros procesos, leer archivos de otros usuarios, o incluso modificar el código del sistema operativo. No habría aislamiento, protección, ni garantías de seguridad. Un solo bug en cualquier programa podría colapsar todo el sistema.  

¿Por qué el SO mantiene procesos zombie en lugar de eliminarlos inmediatamente? El padre necesita poder leer el exit status del hijo para conocer el resultado de su ejecución. Además, el sistema operativo mantiene información de accounting (tiempo de CPU usado, memoria máxima, etc.) que el padre puede necesitar. Eliminar inmediatamente el proceso destruiría esta información. Finalmente, mantener la consistencia del modelo padre-hijo: el padre debe poder hacer `wait()` en cualquier momento después de que el hijo termine, sin condiciones de carrera.  

¿Cuál es la ventaja real de la multiprogramación si solo hay una CPU? Aunque parezca que dividir el tiempo de CPU entre múltiples programas simplemente hace que todos vayan más lentos, la realidad es diferente. Los programas típicamente pasan la mayoría de su tiempo esperando I/O (teclado, red, disco). Con multiprogramación, mientras un proceso espera I/O, otro puede usar la CPU productivamente. Esto puede aumentar la utilización de CPU del 5-10% (monoprogramación) al 70-90% (multiprogramación), y mejora dramáticamente el tiempo de respuesta percibido por usuarios en sistemas interactivos.

\begin{excerpt}
\textbf{Pregunta de reflexión final}: Si entendiste este capítulo, deberías poder explicar por qué cuando terminás un programa con Ctrl+C en la terminal, no se "rompe" el resto del sistema. ¿Cuál es el mecanismo de aislamiento?
\end{excerpt}
Respuesta: Cada programa ejecuta en un proceso separado con su propio espacio de direcciones protegido por la MMU (Memory Management Unit). Ctrl+C envía la señal SIGINT solo al proceso en foreground del terminal, no afecta otros procesos ni al kernel. El sistema operativo mantiene aislamiento estricto mediante protección de memoria por hardware (cada proceso solo puede acceder a su propio espacio de direcciones) y separación de PCBs (el estado de cada proceso está completamente independiente). Incluso si el proceso mata termina de manera anormal (segmentation fault, abort), solo ese proceso muere, el resto del sistema continúa normalmente.

---


Próximo capítulo: Planificación de Procesos - ¿Cómo decide el SO cuál proceso ejecutar y por cuánto tiempo? Exploraremos algoritmos de scheduling, métricas de rendimiento como tiempo de respuesta y throughput, y casos reales de scheduling en sistemas operativos modernos.