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

Imaginen una computadora de los años 1950: un solo programa ejecutándose, ocupando toda la memoria y el procesador hasta terminar. Si querían ejecutar otro programa, debían esperar. Si el programa se colgaba, reiniciaban toda la máquina.

Los **procesos** nacieron como la solución a un problema fundamental: **¿Cómo hacer que múltiples programas compartan eficientemente los recursos de una sola computadora?**

Un proceso es mucho más que un programa ejecutándose. Es una **abstracción** que el SO crea para:

1. **Aislar programas**: Un proceso no puede corromper la memoria de otro
2. **Compartir recursos**: CPU, memoria, archivos de manera controlada
3. **Facilitar la concurrencia**: Múltiples tareas "simultáneas"
4. **Permitir comunicación**: Entre programas de manera segura

## Conceptos Fundamentales

### Programa vs Proceso: La Diferencia Esencial  

**Programa (Entidad Estática):** Archivo ejecutable almacenado en disco. Código fuente compilado en instrucciones de máquina y secuencia pasiva de instrucciones. No consume recursos del sistema hasta ejecutarse.  
- Ejemplo: `/bin/ls`, `notepad.exe`

**Proceso (Entidad Dinámica):** Instancia de un programa en ejecución, incluye código + datos + contexto de ejecución. Entidad activa que puede realizar acciones y consume memoria, CPU, archivos, etc.  
- Ejemplo: El programa `ls` ejecutándose como PID 1234


### Evolución de los Sistemas de Procesamiento

**Monoprogramación:**  
- **Un solo programa** ejecutándose a la vez  
- CPU idle durante operaciones de I/O  
- **Utilización de CPU muy baja** (5-10%)  
- Sistemas batch simples de los años 1950  

\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-02/sequential.png}
\end{center}


**Multiprocesamiento (Multiprocessing):**
- **Múltiples CPUs** físicos en una máquina  
- Verdadero paralelismo hardware  
- Cada CPU puede ejecutar un proceso diferente  
- Sistemas SMP (Symmetric Multiprocessing)  

**Multiprogramación (Multiprogramming):**  
- **Múltiples programas cargados** en memoria simultáneamente  
- **Una sola CPU** alterna entre ellos  
- Cuando un proceso hace I/O, otro usa la CPU  
- **Objetivo**: Maximizar utilización de CPU  

\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/images/capitulo-02/pipelined.png}
\end{center}

**Multitarea (Multitasking):**  
- **Extensión de multiprogramación** con time-sharing  
- **Preemptive scheduling**: SO puede interrumpir procesos  
- **Time slices**: Cada proceso recibe quantum de CPU  
- **Interactividad**: Respuesta rápida al usuario  

### Grado de Multiprogramación

**Definición**: Número de procesos que residen simultáneamente en memoria principal.

**Factores que lo limitan:**
- **Memoria disponible**: Más procesos → menos memoria por proceso
- **Recursos del sistema**: File descriptors, sockets, etc.
- **Overhead del SO**: PCBs, tablas de páginas, context switching


### Estructuras de Control del Sistema Operativo

El SO mantiene varias tablas para gestionar todos los recursos:

**Tabla de Memoria:**
- **Asignación de memoria** a cada proceso  
- **Memoria libre** disponible  
- **Atributos de protección** (read, write, execute)  
- **Información de memoria virtual** (páginas, segmentos)  

**Tabla de I/O:**
- **Estado de dispositivos** (libre, ocupado, error)  
- **Colas de operaciones** pendientes por dispositivo  
- **Buffers** asociados a cada operación  
- **Controladores** de dispositivos activos  

**Tabla de Archivos:**
- **Archivos abiertos** en el sistema  
- **Ubicación** de archivos en almacenamiento  
- **Estado de acceso** (lectura, escritura, compartido)  
- **Locks** y permisos por archivo  

**Tabla de Procesos:**
- **Entry point** hacia todas las demás tablas  
- **Un PCB por cada proceso** en el sistema  
- **Referencias cruzadas** a memoria, I/O, archivos del proceso  
- **Información de estado y control** del proceso  


### Imagen de un Proceso

La **imagen del proceso** es la representación completa de un proceso en memoria:

**Segmentos de la Imagen:**

\begin{center}
\begin{minipage}{0.55\linewidth}
\textbf{Text Segment (Código):} \\
Instrucciones ejecutables del programa → Read-only, compartible entre procesos del mismo programa → Cargado desde el archivo ejecutable. \\[2mm]

\textbf{Data Segment:} \\
\textbf{Initialized Data}: Variables globales con valor inicial → \textbf{BSS (Block Started by Symbol)}: Variables globales no inicializadas → Read-write, específico por proceso. \\[2mm]

\textbf{Heap:} \\
Memoria dinámica (malloc, new) → Crece hacia direcciones altas → Gestionado por el proceso. \\[2mm]

\textbf{Stack:} \\
Variables locales, parámetros de funciones → Return addresses, frame pointers → Crece hacia direcciones bajas.
\end{minipage}%
\hspace{0.05\linewidth}%
\begin{minipage}{0.35\linewidth}
    \includegraphics[width=\linewidth,keepaspectratio]{src/images/capitulo-02/layout-memoria.jpg}
\end{minipage}
\end{center}


### Process Control Block (PCB)  

>
> El PCB es la **estructura de datos más importante** para el manejo de procesos.
>

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

**Funciones del PCB:**  
- **Context Switching**: Guardar/restaurar estado completo  
- **Scheduling**: Información para decidir próximo proceso  
- **Seguridad**: Permisos y propietario del proceso  
- **Resource Management**: Qué recursos usa el proceso  

### Diagramas de Estado de Procesos

**Diagrama de 5 Estados (Modelo Básico):**  

\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap02-cincoEstadosProcesos.png}
\end{center}



**Estados:**
- **NEW**: Proceso creado pero no admitido al pool de ejecutables
- **READY**: Listo para ejecutar, esperando asignación de CPU
- **RUNNING**: Ejecutándose actualmente en el CPU
- **BLOCKED**: Esperando un evento (I/O, señal, recurso)
- **TERMINATED**: Proceso terminado, liberando recursos

**Transiciones:**
1. **Admit**: NEW → READY (SO admite el proceso)
2. **Dispatch**: READY → RUNNING (scheduler asigna CPU)
3. **Preempt**: RUNNING → READY (quantum agotado/mayor prioridad)
4. **Block**: RUNNING → BLOCKED (syscall bloqueante)
5. **Wakeup**: BLOCKED → READY (evento completado)
6. **Exit**: RUNNING → TERMINATED (proceso termina)

**El Dispatcher:**
Componente del SO que ejecuta el **context switch**:

```c
void dispatcher() {
    while (sistema_activo) {
        proceso_actual = scheduler();  // Seleccionar próximo proceso
        context_switch(proceso_anterior, proceso_actual);
        // Al retornar aquí, proceso_actual ha ejecutado
    }
}
```

**Diagrama de 7 Estados (Con Swapping):**  
\begin{center}
\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap02-sieteEstadosProcesos.png}
\end{center}



**Estados Adicionales:**
- **READY/SUSPENDED**: Proceso listo pero swappeado a disco
- **BLOCKED/SUSPENDED**: Proceso bloqueado y swappeado

**Razones para Swapping:**
- **Memoria insuficiente**: Hacer espacio para otros procesos
- **Proceso inactivo**: No ha ejecutado por mucho tiempo
- **Decisión del SO**: Balancear carga del sistema


**Tres Niveles de Planificación:**

1. **Long-Term Scheduler (Job Scheduler):**
   - Controla **grado de multiprogramación**
   - Decide qué procesos **admitir** desde NEW
   - Ejecuta **cada varios segundos**
   - Balance entre procesos **CPU-bound y I/O-bound**

2. **Medium-Term Scheduler (Swapper):**
   - Decide qué procesos **swap in/out**
   - Gestiona **memoria virtual activa**
   - Ejecuta **cada varios segundos**
   - **Suspende procesos** que no usan CPU

3. **Short-Term Scheduler (CPU Scheduler):**
   - Decide **qué proceso ejecutar** de la ready queue
   - Ejecuta **cada 10-100 ms** (muy frecuente)
   - **Algoritmos**: FIFO, SJF, RR, Priority, etc.

### Procesos Zombie y Huérfanos

**Procesos Zombie:**
- **Definición**: Proceso que terminó pero su PCB permanece en el sistema
- **Causa**: Proceso padre no ha llamado `wait()` para leer el exit status
- **Estado**: "defunct" o "zombie" en `ps`
- **Problema**: Consumen entradas en la tabla de procesos
- **Solución**: Padre debe hacer `wait()` o configurar handler para SIGCHLD

**Ejemplo de Zombie:**
```c
if (fork() == 0) {
    // Hijo termina rápidamente
    exit(42);
}
// Padre NO hace wait() y continúa ejecutando
sleep(60);  // Hijo queda zombie por 1 minuto
```

**Procesos Huérfanos:**
- **Definición**: Proceso cuyo padre murió antes que él
- **Adopción**: Automáticamente adoptado por el proceso `init` (PID 1)
- **Comportamiento**: Continúa ejecutándose normalmente
- **Cleanup**: `init` hace `wait()` automáticamente cuando terminan

**Ejemplo de Huérfano:**
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


## Análisis Técnico

### Creación de Procesos en Unix/Linux

En Unix, los procesos se crean mediante la syscall `fork()`:

**Características de fork():**
- Crea una **copia exacta** del proceso padre
- Ambos procesos continúan desde el punto del fork()
- **Valor de retorno diferente** permite distinguirlos
- **Copy-on-Write**: Optimización que copia páginas solo cuando se modifican

**Algoritmo simplificado de fork():**
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

### Carga de Programas: exec()

La familia `exec()` **reemplaza** la imagen del proceso actual:

**Pasos de exec():**
1. Verificar permisos del archivo ejecutable
2. Leer headers (ELF en Linux)
3. Liberar memoria anterior del proceso
4. Cargar nuevos segmentos (text, data)
5. Inicializar stack con argumentos
6. Transferir control al punto de entrada

**Importante**: `exec()` NO crea nuevo proceso, transforma el actual.

### Terminación de Procesos

**Terminación normal:**
- `exit(status)`: Termina proceso con código de salida
- `return` en main(): Equivale a `exit(return_value)`

**Terminación anormal:**
- Señales: SIGKILL, SIGSEGV, etc.
- Abort: `abort()` envía SIGABRT

**Estados post-mortem:**
- **Zombie**: Proceso terminado pero PCB mantenido hasta que padre lea exit status
- **Orphan**: Proceso cuyo padre murió (adoptado por init)


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

**Análisis línea por línea:**

- **Línea 10**: `getpid()` retorna el PID del proceso actual
- **Línea 13**: `fork()` crea el proceso hijo
- **Líneas 15-18**: Manejo de error (fork retorna -1)
- **Líneas 19-26**: Código que SOLO ejecuta el hijo (pid == 0)
- **Líneas 27-38**: Código que SOLO ejecuta el padre (pid > 0)
- **Línea 32**: `wait()` bloquea al padre hasta que termine el hijo
- **Líneas 35-37**: Macros para analizar el status de terminación

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

**Puntos clave:**
- **Línea 18**: `execl()` reemplaza la imagen del proceso hijo
- **Líneas 20-22**: Código que nunca se ejecuta si exec es exitoso
- El PID del proceso hijo NO cambia después de exec
- El padre puede esperar al hijo normalmente con `wait()`

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


## Casos de Estudio

### Caso de Estudio 1: Análisis de fork() múltiple

**Ejercicio típico de parcial:**
¿Cuántos procesos crea el siguiente código y qué imprime?

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

**Resolución paso a paso:**

1. **Estado inicial**: 1 proceso, x = 5

2. **Primer fork()**: 
   - Proceso padre (original)
   - Proceso hijo A
   - Total: 2 procesos

3. **Segundo fork()**:
   - El padre hace fork() → crea hijo B
   - El hijo A hace fork() → crea hijo C
   - Total: 4 procesos

4. **Incremento x++**:
   - Cada proceso incrementa su propia copia de x
   - x pasa de 5 a 6 en todos los procesos

5. **Salida**:
   ```
   PID: 1234, x = 6
   PID: 1235, x = 6  
   PID: 1236, x = 6
   PID: 1237, x = 6
   ```
   (Los PIDs serán diferentes en cada ejecución)

**Fórmula general**: Con n fork() secuenciales se crean 2^n procesos.

### Caso de Estudio 2: Simulación de shell simple

**Ejercicio de parcial:**
Implementar un shell simple que ejecute comandos en procesos hijos.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define MAX_CMD 100

// Función para parsear comando en argumentos
void parse_command(char *cmd, char **args) {
    int i = 0;
    char *token = strtok(cmd, " \n");
    
    while (token != NULL && i < 10) {
        args[i++] = token;
        token = strtok(NULL, " \n");
    }
    args[i] = NULL;  // Terminar array con NULL
}

int main() {
    char comando[MAX_CMD];
    char *args[11];  // Máximo 10 argumentos + NULL
    pid_t pid;
    int status;
    
    while (1) {
        printf("simple_shell> ");
        fflush(stdout);
        
        // Leer comando
        if (fgets(comando, sizeof(comando), stdin) == NULL) {
            break;  // EOF (Ctrl+D)
        }
        
        // Comando vacío
        if (strlen(comando) <= 1) continue;
        
        // Comando "exit"
        if (strncmp(comando, "exit", 4) == 0) {
            break;
        }
        
        // Parsear comando
        parse_command(comando, args);
        
        // Crear proceso hijo para ejecutar comando
        pid = fork();
        
        if (pid == -1) {
            perror("fork");
            continue;
        }
        else if (pid == 0) {
            // HIJO: ejecutar comando
            if (execvp(args[0], args) == -1) {
                perror("exec");
                exit(1);
            }
        }
        else {
            // PADRE: esperar al hijo
            wait(&status);
            
            if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
                printf("Comando terminó con error: %d\n", 
                       WEXITSTATUS(status));
            }
        }
    }
    
    printf("Shell terminando...\n");
    return 0;
}
```

**Análisis del comportamiento:**
- **Shell en loop infinito** hasta comando "exit"
- **Cada comando se ejecuta en proceso hijo** (aislamiento)
- **execvp()** busca el ejecutable en PATH
- **Padre espera** a que termine cada comando antes de mostrar prompt
- **Manejo de errores** para comandos inexistentes

### Caso de Estudio 3: Problema de procesos zombie

**Problema típico:**
¿Qué sucede si el padre no hace wait() de sus hijos?

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

**Problema**: Los 5 hijos se convierten en **zombies**
- Terminan su ejecución pero sus PCBs permanecen
- Consumen entradas en la tabla de procesos
- Aparecen como `<defunct>` en ps

**Solución 1**: wait() explícito
```c
// Después del bucle
for (i = 0; i < 5; i++) {
    wait(NULL);
}
```

**Solución 2**: Ignorar SIGCHLD
```c
#include <signal.h>

int main() {
    signal(SIGCHLD, SIG_IGN);  // Auto-reaping de hijos
    // ... resto del código
}
```


## Síntesis

### Puntos Clave para Parcial

**Definiciones esenciales:**
- **Proceso vs Programa**: Proceso = programa + contexto de ejecución
- **PCB**: Estructura que mantiene estado del proceso
- **Estados**: NEW, READY, RUNNING, BLOCKED, TERMINATED
- **fork()**: Retorna PID del hijo al padre, 0 al hijo, -1 en error
- **exec()**: Reemplaza imagen del proceso (mismo PID)
- **wait()**: Padre espera terminación de hijo, evita zombies

**Diferencias de Sistemas:**
- **Monoprogramación**: Un programa por vez, CPU idle en I/O
- **Multiprogramación**: Múltiples programas en memoria, maximiza CPU
- **Multitarea**: Multiprogramación + time-sharing preemptivo
- **Multiprocesamiento**: Múltiples CPUs físicos

**Estructuras del SO:**
- **Tablas**: Memoria, I/O, Archivos, Procesos (referencia cruzada)
- **Imagen del proceso**: Text, Data, BSS, Heap, Stack
- **PCB**: Contexto completo para context switching

**Diagramas de Estado:**
- **3 estados**: Modelo básico para entender transiciones
- **5 estados**: Incluye swapping (suspended states)
- **7 estados**: Tres niveles de planificación

**Syscalls fundamentales:**
```c
pid_t fork(void);                    // Crear proceso
int execl(path, arg0, arg1, ..., NULL); // Cargar programa  
void exit(int status);               // Terminar proceso
pid_t wait(int *status);            // Esperar hijo
pid_t getpid(void);                 // Obtener PID propio
pid_t getppid(void);                // Obtener PID del padre
```

### Errores Comunes y Tips

**❌ Errores frecuentes:**

1. **No verificar retorno de fork()**
   ```c
   // MAL
   fork();
   if (...)  // ¿Quién ejecuta qué?
   ```

2. **No cerrar extremos no usados de pipes**
   ```c
   // MAL: bloqueo indefinido
   pipe(pipefd);
   // No cerrar extremos innecesarios
   ```

3. **No hacer wait() de los hijos**
   ```c
   // MAL: crea zombies
   if (fork() == 0) {
       exit(0);  // Hijo termina
   }
   // Padre continúa sin wait()
   ```

4. **Asumir orden de ejecución**
   ```c
   // MAL: padre e hijo pueden ejecutar en cualquier orden
   if (fork() == 0) {
       printf("Hijo\n");
   } else {
       printf("Padre\n");  // ¿Quién imprime primero?
   }
   ```

5. **Confundir grado de multiprogramación con multiprocesamiento**
   ```c
   // MAL: "4 CPUs = grado 4"
   // BIEN: Grado = procesos en memoria simultáneamente
   ```

6. **No distinguir entre estados suspended y blocked**
   ```c
   // BLOCKED: Esperando I/O, en memoria
   // BLOCKED/SUSPENDED: Esperando I/O, swappeado a disco
   ```


### Conexión con Próximos Temas

Los procesos son la base para entender:

**Planificación (Capítulo 3):**
- Los estados READY → RUNNING → READY son la base del scheduling
- Los tres planificadores (long, medium, short-term) deciden flujo de procesos
- Algoritmos de scheduling determinan qué proceso de READY queue ejecutar

**Hilos (Capítulo 4):**
- Múltiples flujos de ejecución **dentro de un proceso**
- Comparten mismo espacio de direcciones pero tienen stacks separados
- Permiten paralelismo real en sistemas multiprocesador

**Sincronización (Capítulo 5):**
- Procesos/hilos que comparten recursos necesitan coordinarse
- Race conditions surgen cuando múltiples procesos acceden datos compartidos
- Semáforos, mutexes, monitores resuelven problemas de sincronización

**Interbloqueo (Capítulo 6):**
- Procesos pueden bloquearse mutuamente esperando recursos
- Condiciones necesarias y algoritmos de prevención/detección

**Gestión de Memoria (Capítulos 7-8):**
- Cada proceso tiene su espacio de direcciones virtual
- PCB mantiene información de memory management (page tables, segments)
- Swapping mueve procesos entre memoria y disco

**Sistema de Archivos (Capítulo 9):**
- Procesos acceden archivos mediante file descriptors
- PCB mantiene tabla de archivos abiertos por proceso
- Herencia de file descriptors en fork(), reemplazo en exec()

### Preguntas de Reflexión

1. **¿Por qué fork() + exec() en lugar de una sola syscall "create_process()"?**
   - Flexibilidad: permite configurar hijo antes de exec()
   - Filosofía Unix: separar funciones (crear vs cargar)
   - Permite shells, redirección, pipes

2. **¿Qué pasaría si no existieran los niveles de privilegio (modo kernel/usuario)?**
   - Cualquier programa podría acceder a hardware directamente
   - No habría aislamiento entre procesos
   - Sistema vulnerable e inestable

3. **¿Por qué el SO mantiene procesos zombie en lugar de eliminarlos inmediatamente?**
   - Padre necesita poder leer exit status del hijo
   - Información de accounting (tiempo de CPU usado, etc.)
   - Consistencia del modelo padre-hijo

4. **¿Cuál es la ventaja real de la multiprogramación si solo hay una CPU?**
   - CPU puede trabajar mientras otros procesos hacen I/O
   - Mejor tiempo de respuesta percibido por usuarios
   - Utilización óptima de recursos del sistema

**Pregunta de reflexión final**: Si entendiste este capítulo, deberías poder explicar por qué cuando terminas un programa con Ctrl+C en la terminal, no se "rompe" el resto del sistema. ¿Cuál es el mecanismo de aislamiento?

**Respuesta**: Cada programa ejecuta en un proceso separado con su propio espacio de direcciones protegido. Ctrl+C envía SIGINT solo al proceso en foreground, no afecta otros procesos ni al kernel. El SO mantiene aislamiento mediante hardware (MMU) y software (PCBs separados).

---

**Próximo capítulo**: Planificación de Procesos - ¿Cómo decide el SO cuál proceso ejecutar y por cuánto tiempo? Algoritmos, métricas de rendimiento y casos reales de scheduling.