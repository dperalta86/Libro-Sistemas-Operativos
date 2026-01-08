# Gestión de Memoria Virtual

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Comprender la diferencia entre espacio de direcciones virtual y físico
- Explicar el concepto de page fault como evento normal del sistema
- Describir el flujo completo de manejo de un page fault
- Entender el principio de localidad y su importancia crítica
- Diferenciar entre demand paging y prepaging
- Explicar Copy-on-Write y memory-mapped files
- Analizar y comparar algoritmos de reemplazo de páginas
- Identificar thrashing y sus causas
- Aplicar algoritmos FIFO, LRU, Clock y Clock-M a secuencias de referencias
- Implementar un simulador de algoritmo de reemplazo
- Evaluar el rendimiento de diferentes políticas de reemplazo

## Introducción y Contexto

### El Problema Fundamental

Imaginemos que estamos desarrollando un sistema operativo en 1960. La situación es desafiante: tenemos apenas 64 KiB de memoria RAM (extremadamente cara en esa época), pero nuestros programas necesitan 128 KiB, 256 KiB o incluso más. Para empeorar las cosas, queremos ejecutar múltiples procesos simultáneamente.

La pregunta fundamental es inevitable: *¿cómo ejecutamos un programa más grande que la RAM disponible?*

Las primeras soluciones fueron manuales y requirieron un esfuerzo considerable por parte de los programadores. La técnica dominante en la década de 1960 se llamaba **overlays**, y era tan tediosa como efectiva.

\begin{warning}
\textbf{Overlays (década de 1960):}

El programador debía dividir manualmente el código en secciones. Solo una sección se cargaba en memoria a la vez, y el programador tenía que escribir código explícito para cargar y descargar secciones según fuera necesario. Este enfoque era extremadamente tedioso y propenso a errores. Por ejemplo, al terminar la fase de input, el programador debía escribir código para cargar la fase de procesamiento.
\end{warning}

Un ejemplo conceptual de overlays muestra cómo el programador manejaba esto:

```c
// Ejemplo conceptual de overlays (código del programador)
void fase1_input() {
    // ... leer datos ...
    // Termina fase 1, descargar de memoria
}

void cargar_fase2() {
    // Cargar manualmente fase2 desde disco
    read_from_disk("fase2.code", memoria);
}

void fase2_procesamiento() {
    // ... procesar datos ...
}
```
Esta carga manual de código era frustrante y limitaba severamente la productividad del desarrollo de software. Necesitábamos una solución mejor.

**La solución moderna: Memoria Virtual**

La memoria virtual representa uno de los avances más significativos en el diseño de sistemas operativos. Es una técnica que permite ejecutar procesos cuyo espacio de direcciones total excede la memoria física disponible, creando la ilusión de que cada proceso tiene acceso a un espacio de direcciones enorme y contiguo. Todo esto se gestiona automáticamente por el hardware y el sistema operativo, sin intervención del programador.

\begin{highlight}
La memoria virtual permite ejecutar procesos cuyo espacio de direcciones total excede la memoria física disponible, mediante la ilusión de que cada proceso tiene acceso a un espacio de direcciones enorme y contiguo, gestionado automáticamente por el hardware y el sistema operativo.
\end{highlight}

Las ventajas de este enfoque fueron revolucionarias. Primero, es completamente transparente al programador: no más overlays manuales. Cada proceso opera bajo la creencia de que tiene toda la memoria para sí, lo que simplifica enormemente la programación. Podemos ejecutar programas más grandes que la RAM disponible, y obtenemos protección automática entre procesos. Además, el código puede compartirse eficientemente entre múltiples procesos.

### ¿Cómo es posible?

La viabilidad de la memoria virtual se basa en dos observaciones fundamentales. Primero, no todo el programa necesita estar en RAM simultáneamente (esto se conoce como el *principio de localidad*). Segundo, podemos usar el disco como extensión de la RAM, con traducción automática de direcciones.

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-08/01.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Un proceso de 1 GiB puede correr con aprox. 37 MiB en RAM, y el resto en almacenamiento secundario (swap).
}
\end{center}

## Recap: Conceptos del Capítulo 7

Antes de sumergirnos en los detalles de la memoria virtual, necesitamos repasar brevemente los conceptos de paginación que estudiamos en el Capítulo 7. Estos conceptos son la base sobre la cual construiremos nuestra comprensión de la memoria virtual.

### Paginación Básica (Recap)

En el Capítulo 7 aprendimos que el espacio lógico se divide en *páginas* de tamaño fijo (típicamente 4 KiB), mientras que la memoria física se divide en *marcos* del mismo tamaño. Una tabla de páginas mapea páginas lógicas a marcos físicos, y la MMU (Memory Management Unit) traduce direcciones automáticamente en hardware.

```
Dirección Lógica:
┌────────────────┬─────────────────────┐
│ Número Página  │      Offset         │
│     (p)        │       (d)           │
└────────────────┴─────────────────────┘
       ↓                    ↓
[Tabla de Páginas]          │
       ↓                    │
┌────────────────┬─────────────────────┐
│ Número Marco   │      Offset         │
└────────────────┴─────────────────────┘
    Dirección Física
```

### TLB (Recap)

El Translation Lookaside Buffer es una caché hardware que acelera dramáticamente la traducción de direcciones. Almacena traducciones recientes (típicamente entre 64 y 512 entradas) y puede accederlas en menos de 1 nanosegundo, comparado con aproximadamente 100 nanosegundos si hay que buscar en la tabla de páginas. El hit rate típico es de 98-99%, lo que hace que este mecanismo sea extremadamente efectivo.

\begin{infobox}
El TLB es crítico en memoria virtual, donde cada acceso requiere traducción. Sin él, el overhead de traducción de direcciones sería inaceptable.
\end{infobox}

### Lo Nuevo en Memoria Virtual

En el Capítulo 7, todas las páginas del proceso estaban en RAM. Esta es la diferencia fundamental con memoria virtual: ahora, no todas las páginas están en RAM simultáneamente. Algunas páginas residen en disco (en el swap space), y el *bit presencia* en la tabla de páginas indica dónde está cada página. Cuando se intenta acceder a una página no presente, se produce un **page fault**.

\begin{warning}
\textbf{Diferencia clave:}

Capítulo 7: La tabla de páginas mapea TODAS las páginas a marcos físicos.

Capítulo 8: La tabla de páginas puede indicar "esta página NO está en RAM".
\end{warning}

Para más detalles sobre paginación básica, tablas multinivel, TLB y segmentación, podés consultar el Capítulo 7.

## Conceptos Fundamentales

### Espacio de Direcciones Virtual vs Físico

El espacio de direcciones virtual es el rango completo de direcciones que un proceso puede generar, completamente independiente de la cantidad de memoria física disponible. En un sistema de 32 bits, este espacio va de 0 a 4 GiB. En sistemas de 64 bits, el rango teórico es de 0 a 16 exabytes, aunque en la práctica se usa un subconjunto más pequeño.

\begin{highlight}
El espacio de direcciones virtual es el rango completo de direcciones que un proceso puede generar, independiente de la cantidad de memoria física disponible.
\end{highlight}

Veamos un ejemplo práctico de cómo funciona esto:

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
    // En un sistema de 64 bits, este proceso "ve" un espacio
    // de direcciones de ~16 exabytes, aunque la máquina
    // solo tenga 8 GiB de RAM física
    
    void *ptr = malloc(1024 * 1024 * 1024); // 1 GiB
    printf("Dirección virtual: %p\n", ptr);
    
    // Esta dirección es VIRTUAL
    // Puede ser 0x7f8a3c000000 (ejemplo)
    // Pero físicamente puede estar en marco 2847 de RAM
    // O ni siquiera estar en RAM (en disco)
    
    free(ptr);
    return 0;
}
```

Este programa ilustra un punto crucial: la dirección que vemos (como `0x7f8a3c000000`) es completamente virtual. Físicamente, esos datos pueden estar en el marco 2847 de RAM, o incluso no estar en RAM en absoluto, sino en disco.

La separación entre espacios virtual y físico tiene consecuencias profundas. Ambos procesos pueden usar la misma dirección virtual (digamos, `0x1000`), pero estas se mapean a marcos físicos completamente diferentes. Esto proporciona protección automática: un proceso no puede acceder al marco de otro. Además, simplifica enormemente la programación, ya que cada proceso comienza en `0x0` y el programador no tiene que preocuparse de dónde están otros procesos en memoria.

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-08/02.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Ambos procesos pueden usar la misma dirección virtual 0x1000, se mapean a marcos físicos diferentes.
}
\end{center}

### El Bit Presencia: El Héroe de Memoria Virtual

En el Capítulo 7, cada entrada de tabla de páginas era simplemente un número de marco. Ahora, agregamos información crucial que hace posible la memoria virtual. La estructura expandida incluye varios bits de control, siendo el más importante el *bit presencia*.

```
Entrada de Tabla de Páginas (expandida):
┌────────────┬───┬───┬───┬───┬───────────┐
│ Marco (20) │ P │ U │ M │ X │ Protec.   │
└────────────┴───┴───┴───┴───┴───────────┘
              ↑
              Bit presencia (P)
```

\begin{highlight}
El bit presencia (P) indica si la página está presente en memoria RAM (P=1) o está en disco/swap (P=0). Es la base del mecanismo de memoria virtual.
\end{highlight}

Los bits de control tienen diferentes significados según el estado de la página. Cuando P=1, la página está en RAM, y los otros bits indican si fue accedida recientemente (U=1), si fue modificada (M=1, también llamada *dirty*), y permisos de ejecución (X). Cuando P=0, la página no está en RAM y reside en disco, haciendo que los otros bits sean irrelevantes en ese momento.

Consideremos un ejemplo concreto de una tabla de páginas con memoria virtual:

```
Proceso con 8 páginas:
┌────┬───────┬───┬───┬───┬──────────────┐
│Pág │ Marco │ P │ U │ M │ Ubicación    │
├────┼───────┼───┼───┼───┼──────────────┤
│ 0  │   5   │ 1 │ 1 │ 0 │ RAM (marco 5)│
│ 1  │   -   │ 0 │ - │ - │ Disco blq 10 │
│ 2  │   8   │ 1 │ 0 │ 1 │ RAM (marco 8)│
│ 3  │   -   │ 0 │ - │ - │ Disco blq 15 │
│ 4  │   2   │ 1 │ 1 │ 1 │ RAM (marco 2)│
│ 5  │   -   │ 0 │ - │ - │ Disco blq 20 │
│ 6  │   -   │ 0 │ - │ - │ Nunca usada  │
│ 7  │   1   │ 1 │ 0 │ 0 │ RAM (marco 1)│
└────┴───────┴───┴───┴───┴──────────────┘

Solo 4 de 8 páginas en RAM
Proceso usa 8 × 4 KiB = 32 KiB virtual
Pero solo 4 × 4 KiB = 16 KiB físicos
```

La ventaja es crítica: un proceso de 1 GiB puede ejecutarse con solo 50 MiB en RAM. El resto permanece en disco hasta que se necesite, permitiendo una utilización mucho más eficiente de la memoria física.

### Page Fault: Evento Normal, NO Error

Este es un punto que genera mucha confusión en estudiantes, y es importante aclararlo desde el principio. Un page fault es una interrupción generada por la MMU cuando el CPU intenta acceder a una página cuyo bit presencia está en 0 (página no presente en RAM). Contrario a lo que el nombre podría sugerir, es un mecanismo normal y esperado del sistema de memoria virtual, no un error de programación.

\begin{highlight}
Un page fault es una interrupción generada por la MMU cuando el CPU intenta acceder a una página cuyo bit presencia está en 0. Es un mecanismo normal y esperado del sistema de memoria virtual, NO un error de programación.
\end{highlight}

\begin{warning}
\textbf{¡IMPORTANTE!}

Page Fault ≠ Segmentation Fault

- Page Fault: Evento normal que el SO maneja transparentemente\\
- Segmentation Fault: Error de acceso a memoria inválida
\end{warning}

La distinción es crucial. Un page fault ocurre cuando se accede a una página con P=0, y el SO lo maneja transparentemente cargando la página desde disco. El proceso ni siquiera se entera de que ocurrió. Por otro lado, un segmentation fault es un acceso fuera del espacio válido del proceso, lo que causa que el SO termine el proceso enviando la señal SIGSEGV.

### Swap Space (Backing Store)

El swap space es el área del disco duro reservada para almacenar páginas que no están en RAM. Actúa como una extensión de la memoria física, permitiendo que el sistema ejecute más procesos o procesos más grandes de lo que la RAM física permitiría por sí sola.

\begin{highlight}
El swap space es el área del disco duro reservada para almacenar páginas que no están en RAM. Actúa como extensión de la memoria física.
\end{highlight}

En Linux, podemos ver la configuración del swap con el comando `swapon --show`. Una configuración típica podría mostrar una partición de 8 GiB y un archivo de swap de 4 GiB. El swap puede implementarse tanto como una partición dedicada como un archivo regular en el sistema de archivos.

La estructura del disco duro típicamente incluye una o más particiones para el sistema de archivos, y una partición o archivo dedicado al swap. Esta área almacena las páginas que no están actualmente en RAM, organizadas en bloques que corresponden a las páginas de los diferentes procesos.

\begin{warning}
El swap es aproximadamente 1000 veces más lento que la RAM cuando se usa un disco duro tradicional (HDD). Con SSDs, la diferencia se reduce a unas 100 veces, pero sigue siendo significativa. Por eso es crítico minimizar los page faults. El sistema operativo intenta mantener las páginas "calientes" (frecuentemente accedidas) en RAM.
\end{warning}

La relación entre el tamaño de la RAM y el swap ha evolucionado con el tiempo. En sistemas con 8 GiB de RAM, es común configurar entre 8 y 16 GiB de swap. Con 16 GiB de RAM, típicamente se usa entre 8 y 16 GiB de swap. En sistemas con 32 GiB o más de RAM, el swap puede ser de solo 4 a 8 GiB, o incluso menos. La razón es simple: con más RAM disponible, hay menos page faults y, por lo tanto, se necesita menos espacio de swap.

## Page Fault: Anatomía Completa

Ahora que entendemos qué es un page fault y por qué es necesario, veamos en detalle el flujo completo de lo que sucede cuando ocurre uno. Este proceso involucra una coordinación compleja entre el hardware y el sistema operativo.

### Flujo Paso a Paso

El proceso comienza cuando el CPU ejecuta una instrucción como `MOV R1, [0x2000]`. La MMU intenta traducir la dirección virtual `0x2000` a una dirección física, determinando que corresponde a la página 2. Al consultar la tabla de páginas, descubre que el bit presencia está en 0, lo que indica que la página no está en RAM.

En este punto, la MMU genera una interrupción especial llamada *trap*, específicamente un trap de page fault. El hardware automáticamente guarda el estado completo del proceso, incluyendo todos los registros y el contador de programa (PC). El control pasa entonces al sistema operativo, específicamente al manejador de page faults.

El sistema operativo tiene varias responsabilidades críticas. Primero, debe verificar si el acceso es válido. Si el acceso es a una dirección completamente fuera del espacio válido del proceso, el SO envía una señal SIGSEGV (segmentation fault) y termina el proceso. Si el acceso es válido, el proceso continúa.

\begin{theory}
El manejador de page faults debe distinguir entre tres situaciones:

1. Acceso válido a página que está en disco (page fault normal)\\
2. Acceso a página que nunca ha sido asignada (primer acceso)\\
3. Acceso inválido a memoria fuera del espacio del proceso (segmentation fault)
\end{theory}

Solo en el tercer caso se termina el proceso. Los primeros dos son situaciones normales que el SO maneja transparentemente.


El siguiente paso es buscar un marco libre en RAM. Si hay un marco disponible, se usa directamente. Si no hay marcos libres, el SO debe ejecutar un algoritmo de reemplazo para seleccionar una página víctima que será desalojada. Si esta página víctima tiene el bit modificado (M=1), lo que significa que fue modificada desde que se cargó, debe escribirse a disco antes de ser reemplazada. Esta escritura toma entre 5 y 10 milisegundos en un disco duro tradicional.

Una vez que tenemos un marco disponible (ya sea porque estaba libre o porque desalojamos una página), el SO lee la página necesaria desde disco. Esta operación también toma entre 5 y 10 milisegundos en HDD. Después de cargar la página en el marco seleccionado, el SO actualiza la tabla de páginas, estableciendo el número de marco, poniendo P=1, y reiniciando los bits U y M a 0.

Un detalle importante es la invalidación del TLB. Si existía una entrada anterior para esta página en el TLB (por ejemplo, de cuando la página estaba en RAM anteriormente), debe invalidarse para forzar una nueva traducción que use la tabla de páginas actualizada.

Finalmente, el SO retorna de la interrupción. El hardware restaura automáticamente los registros del proceso, y el CPU reintenta la instrucción `MOV R1, [0x2000]`. Esta vez, como P=1, la traducción es exitosa y el acceso a RAM se completa normalmente.

### Tiempos Aproximados

Los tiempos involucrados en un page fault son significativos y vale la pena analizarlos en detalle. Estos valores están basados en mediciones de sistemas reales y literatura técnica estándar.

\begin{infobox}
\textbf{Tiempos típicos de page fault (validados):}

La detección por hardware (MMU) toma aproximadamente 1 nanosegundo. El context switch al manejador del SO requiere entre 1 y 5 microsegundos. La búsqueda de marco libre o ejecución del algoritmo de reemplazo toma entre 1 y 10 microsegundos.

Las operaciones de disco son las más costosas. La escritura de una página dirty a disco HDD toma entre 5 y 10 milisegundos, mientras que la lectura desde disco HDD también requiere 5 a 10 milisegundos. Con SSDs, estos tiempos se reducen dramáticamente: entre 0.1 y 0.5 milisegundos para escritura, y entre 0.1 y 0.5 milisegundos para lectura.

La actualización de estructuras del SO requiere entre 1 y 5 microsegundos, y el context switch de vuelta al proceso toma otros 1 a 5 microsegundos.

Total con HDD: 10-20 milisegundos\\
Total con SSD: 0.2-1 milisegundo
\end{infobox}

Para poner estos números en perspectiva, comparémoslos con un acceso normal a RAM. Un acceso con TLB hit toma aproximadamente 10 nanosegundos (0.00001 ms). Un acceso con TLB miss requiere unos 100 nanosegundos (0.0001 ms). Un page fault con SSD toma alrededor de 500 microsegundos (0.5 ms), lo que es aproximadamente 50,000 veces más lento. Un page fault con HDD toma unos 10 milisegundos, lo que es aproximadamente 1,000,000 veces más lento que un acceso normal a RAM.

\begin{warning}
\textbf{Consecuencia crítica:}

Un solo page fault equivale a aproximadamente 100,000 accesos normales a RAM. Por eso el principio de localidad es fundamental para el rendimiento del sistema. Minimizar page faults es esencial para mantener un rendimiento aceptable.
\end{warning}

\begin{warning}
En un CPU de 3 GHz, un ciclo de reloj dura aproximadamente 0.33 ns.\\
Un acceso a RAM de 10 ns equivale a unos 30 ciclos de CPU, mientras que un page fault con SSD puede costar más de 1.5 millones de ciclos, y con HDD más de \textbf{30 millones de ciclos.}
\end{warning}

### Casos Especiales

Existen varios casos especiales de page faults que vale la pena examinar, cada uno con características únicas.

#### Caso 1: Primera Referencia (Demand Paging)

Cuando se crea un proceso nuevo, todas sus páginas tienen inicialmente el bit presencia en 0. La primera referencia a la página 0 (típicamente código) genera un page fault, y el SO carga esa página desde el archivo ejecutable. La primera referencia a la página 1 genera otro page fault, y así sucesivamente.

Este enfoque se llama *demand paging* (paginación bajo demanda) porque las páginas se cargan solo cuando se necesitan. Es fundamentalmente diferente de cargar todo el programa en memoria antes de ejecutarlo, lo que sería más lento y desperdiciaría memoria en páginas que nunca se usan.

#### Caso 2: Copy-on-Write

Copy-on-Write es una optimización elegante que exploraremos en detalle más adelante. Cuando un proceso hace `fork()`, el proceso hijo no copia inmediatamente todas las páginas del padre. En su lugar, ambos procesos comparten las mismas páginas físicas, pero marcadas como solo lectura.

Si el hijo intenta escribir en una página compartida, se genera un page fault (por intento de escritura en una página de solo lectura). El SO detecta que es un caso de Copy-on-Write, copia la página a un nuevo marco, y actualiza la tabla del hijo para apuntar a esta copia privada. Ahora el hijo puede escribir en su propia copia sin afectar al padre.

#### Caso 3: Memory-Mapped Files

Los archivos mapeados en memoria son otro caso especial fascinante. Cuando llamamos a `mmap()` para mapear un archivo de 1 MiB, la llamada no carga el archivo completo inmediatamente. Solo mapea direcciones virtuales al archivo.

La primera lectura de la dirección mapeada genera un page fault. El SO carga la página correspondiente desde el archivo (no desde el swap). Si escribimos en esta dirección y la página no está en RAM, también habrá un page fault. Una vez en RAM, la página se marca como dirty (M=1), y el SO eventualmente escribirá los cambios de vuelta al archivo.

### Diagrama de Flujo

El diagrama completo del flujo de un page fault muestra todas estas decisiones y transiciones:

```
[Insertar aquí: cap08-pageFaultFlow.mmd]
```

Este diagrama incluye la detección por MMU, verificación de validez del acceso, búsqueda de marco libre, ejecución del algoritmo de reemplazo si es necesario, operaciones de lectura y escritura a disco, actualización de todas las estructuras relevantes, y finalmente el retry de la instrucción original.

## Principio de Localidad

El principio de localidad es la razón fundamental por la cual la memoria virtual funciona eficientemente. Sin este principio, cada proceso necesitaría todas sus páginas en RAM todo el tiempo, haciendo que la memoria virtual fuera impráctica.

### ¿Qué es el Principio de Localidad?

El principio de localidad es una observación empírica sobre el comportamiento de los programas. Los programas tienden a acceder un subconjunto relativamente pequeño de su espacio de direcciones en cualquier intervalo de tiempo dado. Este principio se divide en dos tipos fundamentales: localidad temporal y localidad espacial.

\begin{highlight}
El principio de localidad es la observación de que los programas tienden a acceder un subconjunto relativamente pequeño de su espacio de direcciones en cualquier intervalo de tiempo dado. Se divide en localidad temporal y localidad espacial.
\end{highlight}

La importancia de este principio para la memoria virtual no puede subestimarse. Si un proceso de 1 GiB necesitara acceder aleatoriamente todas sus páginas constantemente, tendríamos page faults continuos, el disco trabajando sin parar, y un rendimiento catastrófico. Pero gracias a la localidad, el proceso típicamente solo accede activamente a unos 50 MiB en cualquier momento, permitiendo que funcione eficientemente con poca RAM física.

### Localidad Temporal

\begin{highlight}
La localidad temporal se refiere al fenómeno de que si se referencia una ubicación de memoria en el tiempo $t$, es muy probable que se referencie nuevamente en un futuro cercano $(t + Δt)$.
\end{highlight}

El ejemplo clásico de localidad temporal son las variables en un bucle:

```c
#include <stdio.h>

int main() {
    int suma = 0;        // Variable local en stack
    int contador = 0;    // Variable local en stack
    
    // Estas dos variables se acceden repetidamente
    // en cada iteración del bucle
    for (contador = 0; contador < 1000000; contador++) {
        suma += contador;
        // 'suma' y 'contador' se referencian una y otra vez
        // → Localidad temporal
        // → Muy probable que estén en caché y en RAM
    }
    
    printf("Suma: %d\n", suma);
    return 0;
}
```

¿Qué está pasando con las páginas en este ejemplo? El proceso tiene la página 0 conteniendo el código (las instrucciones del bucle), y la página 1 conteniendo el stack (las variables `suma` y `contador`). Durante la ejecución del bucle, se accede a la página 0 un millón de veces, y a la página 1 otro millón de veces. En total, solo 2 páginas están activas de quizás 100 páginas totales del proceso.

Otros ejemplos comunes de localidad temporal incluyen funciones que se llaman frecuentemente (permanecen "calientes" en memoria), variables globales usadas en múltiples funciones, y especialmente código en bucles internos (*hot loops*) que se ejecutan millones de veces.

### Localidad Espacial

\begin{highlight}
La localidad espacial describe el fenómeno de que si se referencia una ubicación de memoria en la dirección $X$, es muy probable que se referencien ubicaciones cercanas $(X ± δ)$ en un futuro próximo.
\end{highlight}

El ejemplo clásico es el recorrido secuencial de un array:

```c
#include <stdio.h>
#define SIZE 1000000

int main() {
    int array[SIZE];  // 4 MiB en heap
    int suma = 0;
    
    // Inicializar array
    for (int i = 0; i < SIZE; i++) {
        array[i] = i;
        // Acceso secuencial: array[0], array[1], array[2], ...
        // → Localidad espacial
    }
    
    // Sumar elementos
    for (int i = 0; i < SIZE; i++) {
        suma += array[i];
        // Nuevamente acceso secuencial
        // → Localidad espacial
    }
    
    printf("Suma: %d\n", suma);
    return 0;
}
```

Para entender el impacto, consideremos cómo se organizan estos datos en páginas. Un array de 4 MiB con páginas de 4 KiB significa que los elementos `array[0..1023]` están en la página 0, `array[1024..2047]` en la página 1, y así sucesivamente.

Cuando accedemos `array[0]`, traemos la página 0 completa (que contiene `array[0..1023]`). Los próximos 1023 accesos no generan page faults porque todos esos elementos ya están en RAM, en la misma página.

El impacto en page faults es dramático. Para un array de 1,000,000 elementos (4 MiB total), necesitamos 1024 páginas. Con acceso secuencial (que tiene localidad espacial), tenemos exactamente 1024 page faults: uno por página, la primera vez que la accedemos. Los restantes 998,976 accesos no generan page faults.

Con acceso aleatorio (sin localidad espacial), cada acceso potencialmente va a una página diferente. Podríamos tener cientos de miles de page faults, resultando en un rendimiento desastroso.

\begin{example}
\textbf{Impacto medible de la localidad espacial:}

Array de 1,000,000 elementos (int):
- Tamaño: 4 MiB
- Páginas necesarias: 1024 páginas

Acceso secuencial:
- Page faults: 1024 (uno por página)
- Accesos sin PF: 998,976
- Tiempo: ~10 ms + tiempo de procesamiento

Acceso aleatorio:
- Page faults: potencialmente cientos de miles
- Rendimiento: 100-1000 veces peor
\end{example}

### Localidad en Programas Reales

Para ver cómo el principio de localidad funciona en la práctica, consideremos un navegador web real. El código del navegador puede ocupar 50 MiB, y las páginas web cargadas otros 500 MiB, para un total de 550 MiB de espacio de direcciones virtual.

Sin embargo, en cualquier momento de 10 segundos, solo está activo aproximadamente 5 MiB de código (el motor de renderizado, la máquina virtual de JavaScript) y unos 20 MiB de datos (la página web actual y las imágenes visibles). El total activo es de solo 25 MiB.

El ratio es revelador: 25/550 = 4.5% del espacio total está en uso activo. La localidad hace viable ejecutar este navegador con mucha menos RAM de la que su tamaño total sugeriría.

### Working Set

Este concepto de "conjunto activo" se formaliza en la noción de *working set*.

\begin{highlight}
El \textbf{working set} (conjunto de trabajo) es el conjunto de páginas que un proceso está usando activamente en un intervalo de tiempo dado. Representa el "tamaño mínimo de RAM" que el proceso necesita para ejecutar eficientemente.
\end{highlight}

El working set cambia con el tiempo a medida que el proceso pasa por diferentes fases de ejecución. Por ejemplo, en los primeros 5 segundos, un proceso podría tener un working set de las páginas {0,1,2,5,7}. En los siguientes 5 segundos, el working set podría ser {0,1,2,3,8}. Y en los siguientes 5 segundos, {0,1,10,11,12}.

La clave está en el tamaño del working set. Si le damos al proceso menos páginas de RAM que su working set, tendremos page faults continuos, una condición conocida como *thrashing* que estudiaremos más adelante. Si le damos al proceso suficientes páginas para cubrir su working set (en este ejemplo, 5 páginas o más), funcionará eficientemente.

\begin{infobox}
\textbf{Importancia del working set:}

El sistema operativo intenta estimar continuamente el working set de cada proceso. Asigna suficientes marcos de RAM para cubrirlo, permitiendo que el proceso ejecute sin thrashing. Si el sistema no puede satisfacer los working sets de todos los procesos activos, debe suspender algunos procesos temporalmente para prevenir el colapso del rendimiento. Algoritmos avanzados como Working Set y PFF (Page Fault Frequency) se basan explícitamente en esta idea.
\end{infobox}

### ¿Por Qué Funciona en Práctica?

El principio de localidad no es un accidente: surge naturalmente de cómo escribimos y estructuramos programas. Existen varias razones fundamentales por las cuales los programas exhiben localidad.

Primero, la estructura misma de los programas promueve localidad. El código se organiza en funciones, y las funciones activas en cualquier momento dado son relativamente pocas (localidad temporal de funciones). Los datos se organizan en arrays y estructuras, promoviendo accesos cercanos en memoria (localidad espacial).

Los bucles son particularmente importantes para la localidad. Las instrucciones dentro del bucle se ejecutan repetidamente, permaneciendo "calientes" en las cachés y en RAM. Las variables utilizadas en el bucle se acceden miles o millones de veces sin moverse de su ubicación en memoria.

Las llamadas a funciones también contribuyen a la localidad. Mientras una función está activa, usa repetidamente su stack frame, que permanece en la misma región de memoria. Cuando la función retorna al caller, volvemos a código que ya estaba en memoria.

El acceso secuencial a datos es omnipresente en programación. Los archivos típicamente se leen o escriben secuencialmente, y los arrays se procesan elemento por elemento. La organización natural de datos también ayuda: las estructuras agrupan datos relacionados que se acceden juntos, y objetos relacionados tienden a alocarse cerca en memoria.

#### Contraejemplo: Programa SIN localidad

Consideremos un programa patológico que accede memoria completamente al azar:

```c
// Programa patológico: acceso completamente aleatorio
#include <stdlib.h>
#include <time.h>

#define PAGES 10000

int main() {
    int *huge_array = malloc(PAGES * 4096);  // 40 MiB
    srand(time(NULL));
    
    // Acceso completamente aleatorio a páginas
    for (int i = 0; i < 1000000; i++) {
        int random_page = rand() % PAGES;
        int random_offset = rand() % 1024;
        int index = random_page * 1024 + random_offset;
        huge_array[index] = i;
        // → NO hay localidad
        // → Page faults constantes
        // → Rendimiento terrible
    }
    
    free(huge_array);
    return 0;
}
```

Este programa tendría un rendimiento ~1000 veces peor que uno con acceso secuencial, porque viola completamente el principio de localidad. Cada acceso aleatorio tiene alta probabilidad de ir a una página diferente, generando page faults constantes.

## Demand Paging vs Prepaging

Ahora que entendemos el principio de localidad, podemos explorar las estrategias que usa el sistema operativo para decidir cuándo cargar páginas en memoria. La pregunta fundamental es: cuando se carga un proceso, ¿cargamos todas sus páginas inmediatamente o esperamos a que se necesiten?

### Demand Paging (Paginación Bajo Demanda)

La estrategia más común en sistemas modernos es *demand paging*, donde las páginas se cargan en memoria solo cuando se referencian por primera vez, generando un page fault.

\begin{highlight}
En demand paging, las páginas se cargan en memoria SOLO cuando se referencian por primera vez, generando un page fault. Es la estrategia más común en sistemas modernos.
\end{highlight}

Cuando se crea un proceso nuevo, su tabla de páginas se inicializa con todas las entradas marcadas como no presentes (P=0). Ninguna página está en RAM inicialmente. La primera instrucción del programa intentará acceder a la página 0 (código), generando un page fault. El sistema operativo maneja este fault cargando la página 0 desde el archivo ejecutable y marcándola como presente (P=1).

A medida que el programa continúa ejecutando, cada nueva página que accede genera su propio page fault inicial. El acceso a datos genera page faults para las páginas del heap y el stack. Gradualmente, el working set del proceso se carga en memoria, pero solo las páginas realmente necesarias.

Las ventajas de demand paging son significativas. Solo se cargan páginas realmente necesarias, ahorrando tanto memoria como tiempo de I/O. El startup es rápido porque no esperamos a cargar todo el programa. Las páginas que nunca se usan (como código de manejo de errores raros) nunca se cargan, ahorrando recursos valiosos. Esto permite ejecutar programas más grandes que la RAM disponible.

\begin{warning}
\textbf{Desventajas de demand paging:}

El inicio del programa genera muchos page faults (cold start), causando latencia inicial. La latencia en la primera referencia a cada página es impredecible, lo que puede ser problemático para aplicaciones de tiempo real. Cada página nueva implica el overhead completo de un page fault, incluyendo la interrupción, el context switch, y la I/O de disco.
\end{warning}

Un ejemplo práctico ilustra cómo funciona esto.
```c
// Programa de 100 páginas
int main() {
    // Al iniciar: 0 páginas en RAM
    
    funcion_principal();  // Carga páginas 0-5 (código)
    // Ahora: 6 páginas en RAM
    
    if (condicion_rara) {
        // Este código casi nunca se ejecuta
        funcion_rara();   // Páginas 50-55 nunca se cargan
    }
    
    // Final: solo ~10-20 páginas cargadas de 100 totales
    return 0;
}
```
Cuando comienza a ejecutar, llama a `funcion_principal()`, lo que carga las páginas 0-5 de código. Ahora tenemos 6 páginas en RAM. Si hay un `if (condicion_rara)` que casi nunca se evalúa como verdadero, las páginas 50-55 que contienen `funcion_rara()` nunca se cargan. Al final de la ejecución, solo unas 10-20 páginas fueron cargadas de las 100 totales.

### Prepaging (Paginación Anticipada)

Una alternativa es *prepaging*, donde el sistema operativo intenta predecir qué páginas se necesitarán pronto y las carga anticipadamente, antes de que se generen page faults.

\begin{highlight}
En prepaging, el SO intenta predecir qué páginas se necesitarán pronto y las carga anticipadamente, antes de que se generen page faults.
\end{highlight}

Existen varias estrategias de prepaging. Una es cargar páginas contiguas: cuando se accede a la página 5 y se genera un page fault, el SO carga no solo la página 5 sino también las páginas 6, 7 y 8, anticipando acceso secuencial debido a la localidad espacial.

Otra estrategia usa el histórico de acceso. Si el SO observa que un proceso siempre accede las páginas en el orden 0 → 1 → 5 → 10, al cargar el proceso puede traer ese conjunto completo desde el principio.

Una tercera estrategia aprovecha el working set previo. Cuando un proceso se suspende con las páginas {0,1,2,5,7} en RAM, al reanudarlo el SO puede cargar ese working set completo, asumiendo que será necesario nuevamente.

Las ventajas de prepaging son claras cuando la predicción es correcta. Se reducen los page faults durante la ejecución, mejorando el rendimiento para patrones predecibles. Es particularmente útil al reanudar procesos que fueron suspendidos, ya que podemos restaurar su working set previo.

\begin{warning}
\textbf{Desventajas de prepaging:}

Si la predicción falla, desperdiciamos I/O y memoria cargando páginas que nunca se usan. La implementación es más compleja que demand paging simple, requiriendo mantener estadísticas y hacer predicciones. El trade-off fundamental es: prepaging solo vale la pena si la predicción es correcta más del 80\% del tiempo.
\end{warning}

En sistemas operativos reales, vemos mayormente demand paging con prepaging limitado en casos específicos. Linux usa principalmente demand paging, pero implementa *readahead* para archivos que se acceden secuencialmente, y carga páginas de código contiguas cuando detecta ejecución secuencial. Windows es similar, usando demand paging como base pero con un sistema de *prefetch* que almacena patrones de inicio de aplicaciones y precarga páginas según el histórico de arranques previos.

## Shared Pages y Técnicas Avanzadas

Hasta ahora hemos considerado principalmente las páginas como recursos privados de cada proceso. Sin embargo, algunos de los usos más poderosos de la memoria virtual involucran compartir páginas entre múltiples procesos de manera eficiente y segura.

### Copy-on-Write (COW)

Copy-on-Write es una optimización crucial que hace viable la operación `fork()` en sistemas Unix/Linux. Sin esta técnica, crear un proceso hijo sería prohibitivamente costoso.

\begin{highlight}
Copy-on-Write (COW) es una técnica donde múltiples procesos comparten las mismas páginas físicas de memoria mientras sean solo lectura. Al intentar escribir, se crea una copia privada de la página para ese proceso.
\end{highlight}

Para entender el problema que resuelve COW, consideremos qué pasaría sin esta optimización.

```c
pid_t pid = fork();

// Sin COW: fork() debe copiar TODAS las páginas del padre
// Padre tiene 100 MiB en RAM
// → Copiar 100 MiB toma ~100 ms
// → Desperdicio si el hijo hace exec() inmediatamente
```

Cuando un proceso hace `fork()`, el sistema operativo tendría que copiar todas las páginas del padre. Si el padre tiene 100 MiB en RAM, copiar todo tomaría aproximadamente 100 milisegundos. Esto sería un desperdicio enorme, especialmente considerando que el caso más común es que el hijo haga `exec()` inmediatamente, reemplazando todo su espacio de direcciones.

La solución con COW es elegante. Antes del `fork()`, el proceso padre tiene sus páginas marcadas como lectura-escritura (RW). Después del `fork()`, tanto el padre como el hijo tienen tablas de páginas que apuntan a los mismos marcos físicos, pero ahora marcados como solo lectura (R/O). Ambos procesos comparten la memoria física sin copiarla.

```
ANTES del fork():
Proceso Padre:
┌────┬───────┬───┬───┬───┐
│Pág │ Marco │ P │ R │ W │
├────┼───────┼───┼───┼───┤
│ 0  │   5   │ 1 │ 1 │ 1 │  RW (read-write)
│ 1  │   8   │ 1 │ 1 │ 1 │  RW
└────┴───────┴───┴───┴───┘

DESPUÉS del fork():
Proceso Padre:              Proceso Hijo:
┌────┬───────┬───┬───┬───┐ ┌────┬───────┬───┬───┬───┐
│Pág │ Marco │ P │ R │ W │ │Pág │ Marco │ P │ R │ W │
├────┼───────┼───┼───┼───┤ ├────┼───────┼───┼───┼───┤
│ 0  │   5   │ 1 │ 1 │ 0 │ │ 0  │   5   │ 1 │ 1 │ 0 │  Mismo marco!
│ 1  │   8   │ 1 │ 1 │ 0 │ │ 1  │   8   │ 1 │ 1 │ 0 │  Mismo marco!
└────┴───────┴───┴───┴───┘ └────┴───────┴───┴───┴───┘
     ↑ W=0 (ahora R/O)          ↑ W=0 (ahora R/O)
     
Ambos comparten marcos 5 y 8 (pero en modo solo lectura)
```

El momento crítico ocurre cuando uno de los procesos intenta escribir. Supongamos que el hijo ejecuta `x = 20`, intentando modificar una variable.

```c
// Proceso hijo
int main() {
    int x = 10;  // Variable en página 1 (marco 8)
    x = 20;      // INTENTO DE ESCRITURA
    
    // → Page fault (intento de escritura en página R/O)
    
    return 0;
}
```
Esto genera un page fault porque la página está marcada como solo lectura. El sistema operativo detecta que no es un error sino un caso de COW. En respuesta, asigna un nuevo marco (digamos, el marco 12), copia el contenido del marco compartido a este nuevo marco, actualiza la tabla del hijo para apuntar al nuevo marco con permisos de escritura, y finalmente reintenta la instrucción, que ahora tiene éxito.

```
Proceso Padre:              Proceso Hijo:
┌────┬───────┬───┬───┬───┐ ┌────┬───────┬───┬───┬───┐
│Pág │ Marco │ P │ R │ W │ │Pág │ Marco │ P │ R │ W │
├────┼───────┼───┼───┼───┤ ├────┼───────┼───┼───┼───┤
│ 0  │   5   │ 1 │ 1 │ 0 │ │ 0  │   5   │ 1 │ 1 │ 0 │  Aún compartida
│ 1  │   8   │ 1 │ 1 │ 0 │ │ 1  │  12   │ 1 │ 1 │ 1 │  Ahora privada!
└────┴───────┴───┴───┴───┘ └────┴───────┴───┴───┴───┘
```
\begin{example}
\textbf{Estadísticas reales de COW:}

En el caso común de `fork()` seguido de `exec()`:
- Sin COW: copiar 100 MiB → ~100 ms
- Con COW: copiar 0 MiB → ~1 ms (solo estructuras del SO)

Cuando el hijo modifica el 10% de las páginas:
- Sin COW: copiar 100 MiB → ~100 ms
- Con COW: copiar 10 MiB bajo demanda → ~10 ms total

El ahorro es dramático en ambos casos.
\end{example}

### Memory-Mapped Files

Memory-mapped files representan otra técnica poderosa que aprovecha la memoria virtual para simplificar el I/O y la compartición de datos.

\begin{highlight}
Memory-mapped files mapean un archivo del disco directamente al espacio de direcciones virtual de un proceso, permitiendo acceder al archivo como si fuera un array en memoria.
\end{highlight}

La syscall principal es `mmap()`. Cuando mapeamos un archivo de 1 MiB, la llamada no carga el archivo completo inmediatamente. Solo configura las estructuras del sistema operativo para que las direcciones virtuales correspondan a bloques del archivo. Es otra forma de demand paging, pero usando el archivo como backing store en lugar del swap.


```c
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    // Abrir archivo
    int fd = open("datos.bin", O_RDWR);
    
    // Mapear archivo a memoria (1 MiB)
    void *addr = mmap(
        NULL,                   // SO elige dirección
        1024*1024,              // 1 MiB
        PROT_READ | PROT_WRITE, // Permisos
        MAP_SHARED,             // Cambios visibles en archivo
        fd,                     // File descriptor
        0                       // Offset en archivo
    );
    
    // Ahora 'addr' apunta a las páginas mapeadas
    // NO se cargó nada en RAM todavía (demand paging)
    
    // Primera lectura
    char c = ((char*)addr)[0];
    // → Page fault
    // → SO carga página desde archivo (no desde swap)
    // → Ahora página está en RAM
    
    // Escritura
    ((char*)addr)[100] = 'X';
    // → Marca página como dirty (M=1)
    // → Cambio se escribirá al archivo eventualmente
    
    // Deshacer mapeo
    munmap(addr, 1024*1024);
    close(fd);
    
    return 0;
}
```

Internamente, después de `mmap()`, la tabla de páginas tiene todas las entradas con P=0, pero en lugar de apuntar al swap, cada entrada indica qué offset del archivo contiene los datos para esa página.

```
Estado inicial (después de mmap):
┌────┬───────┬───┬─────────────┐
│Pág │ Marco │ P │ Backing     │
├────┼───────┼───┼─────────────┤
│ 0  │   -   │ 0 │ datos.bin:0 │  No en RAM
│ 1  │   -   │ 0 │ datos.bin:4K│  No en RAM
│ 2  │   -   │ 0 │ datos.bin:8K│  No en RAM
└────┴───────┴───┴─────────────┘

Primera lectura de página 0:
→ Page fault
→ SO lee bloque 0 de datos.bin → marco 5
┌────┬───────┬───┬─────────────┐
│ 0  │   5   │ 1 │ datos.bin:0 │  EN RAM
│ 1  │   -   │ 0 │ datos.bin:4K│
│ 2  │   -   │ 0 │ datos.bin:8K│
└────┴───────┴───┴─────────────┘

Escritura en página 0:
→ Marca M=1 (dirty)
→ Eventualmente SO escribe marco 5 → datos.bin:0
```
Las ventajas de memory-mapped files son sustanciales. El I/O se simplifica dramáticamente: los archivos se tratan como arrays en memoria, eliminando las llamadas explícitas a `read()` y `write()`. La compartición entre procesos es fácil usando `MAP_SHARED`. El sistema operativo maneja el caché automáticamente, y se evitan copias entre user space y kernel space, mejorando el rendimiento.

\begin{example}
\textbf{Casos de uso de memory-mapped files:}

Bases de datos: Mapean el archivo de BD completo y acceden a registros directamente sin `read/write`, permitiendo índices eficientes y acceso aleatorio rápido.

Librerías compartidas (.so, .dll): Múltiples procesos mapean `libc.so`, compartiendo el código en RAM y ahorrando masivamente memoria.

IPC (Inter-Process Communication): El proceso A y B mapean el mismo archivo con \texttt{MAP\_SHARED}, permitiendo que ambos vean los cambios del otro en tiempo real.
\end{example}

### Shared Libraries

Las librerías compartidas son un caso especial particularmente importante de shared pages. Cuando tres procesos ejecutan programas que usan `libc`, sin compartición necesitaríamos tres copias completas de la librería en RAM. Con shared pages, los tres procesos apuntan a los mismos marcos físicos para el código de la librería.

```
Proceso A:                Proceso B:                Proceso C:
Tabla de Páginas         Tabla de Páginas         Tabla de Páginas
┌────┬───────┬───┐       ┌────┬───────┬───┐       ┌────┬───────┬───┐
│Pág │ Marco │ W │       │Pág │ Marco │ W │       │Pág │ Marco │ W │
├────┼───────┼───┤       ├────┼───────┼───┤       ├────┼───────┼───┤
│ 0  │  100  │ 0 │ ──┐   │ 0  │  200  │ 0 │       │ 0  │  300  │ 0 │
│... │  ...  │...│   │   │... │  ...  │...│       │... │  ...  │...│
│ 10 │   50  │ 0 │ ──┼──→│ 5  │   50  │ 0 │ ──┐   │ 8  │   50  │ 0 │
│ 11 │   51  │ 0 │ ──┼──→│ 6  │   51  │ 0 │ ──┼──→│ 9  │   51  │ 0 │
└────┴───────┴───┘   │   └────┴───────┴───┘   │   └────┴───────┴───┘
                     └───────────────────────┘
                     
Marcos 50-51: código de libc (compartido, R/O)
Marcos 100,200,300: código privado de cada proceso
```
Cada proceso tiene su propia tabla de páginas. Las páginas que contienen código privado del proceso apuntan a marcos únicos. Pero las páginas que contienen código de `libc` (marcadas como solo lectura) apuntan a los mismos marcos compartidos. Los marcos 50-51, por ejemplo, contienen código de `libc` y son compartidos por todos los procesos.

El ahorro de memoria es considerable. Sin compartición, tres procesos cada uno usando 2 MiB de `libc` consumirían 6 MiB de RAM. Con compartición, los tres procesos comparten una sola copia de 2 MiB, ahorrando 4 MiB (66%). En un servidor con 100 procesos, el ahorro puede alcanzar varios cientos de megabytes.

### TLB Reach

Un último concepto relacionado con el rendimiento de la memoria virtual es el *TLB reach*.

\begin{highlight}
El TLB reach es la cantidad de memoria que puede ser mapeada por todas las entradas del TLB. Se calcula como: TLB Reach = (número de entradas TLB) × (tamaño de página).
\end{highlight}

Un TLB con 64 entradas y páginas de 4 KiB tiene un reach de 256 KiB. Esto significa que si el working set del proceso es menor a 256 KiB, todas las traducciones estarán en el TLB con un hit rate cercano al 100%.

El problema surge cuando el working set excede el TLB reach. Un proceso con working set de 1 MiB pero TLB reach de solo 256 KiB experimentará muchos TLB misses, degradando el rendimiento. La solución es usar páginas más grandes. Con páginas de 2 MiB (llamadas *huge pages*), el mismo TLB de 64 entradas tiene un reach de 128 MiB, suficiente para que el working set completo quepa en el TLB.

\begin{infobox}
\textbf{Uso en sistemas reales:}

Las bases de datos modernas usan huge pages de 2 MiB o 1 GiB para reducir la presión sobre el TLB. Las máquinas virtuales usan páginas grandes para las Extended Page Tables (EPT), reduciendo el overhead de virtualización anidada. La computación de alto rendimiento (HPC) frecuentemente usa páginas de 1 GiB para grandes datasets científicos.
\end{infobox}

## Algoritmos de Reemplazo de Páginas

Cuando ocurre un page fault y no hay marcos libres, el SO debe seleccionar una página "víctima" para reemplazar. El algoritmo de reemplazo determina QUÉ página sacar de RAM.

### Objetivo del Algoritmo de Reemplazo

\begin{excerpt}
\emph{Algoritmo de Reemplazo:}
Política que selecciona cuál página residente en RAM será reemplazada cuando se necesita cargar una nueva página y no hay marcos libres. El objetivo es minimizar la tasa de page faults.
\end{excerpt}

**Métrica clave: Page Fault Rate**

```
Page Fault Rate = (Número de page faults) / (Número total de referencias)

Ejemplo:
Secuencia de 20 referencias, 5 page faults
PF Rate = 5/20 = 0.25 = 25%
```

### FIFO (First-In-First-Out)

El algoritmo más simple: reemplazar la página que lleva más tiempo en memoria.

**Implementación:** Cola circular, la página más antigua está al frente.

```
Estructura:
┌─────┬─────┬─────┬─────┐
│ Pág │ Pág │ Pág │ Pág │
│  5  │  2  │  9  │  1  │
└─────┴─────┴─────┴─────┘
  ↑                   ↑
Oldest              Newest
(víctima)
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Muy simple de implementar\\
- Complejidad O(1) para encontrar víctima\\
- Bajo overhead\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- No considera frecuencia de uso\\
- Puede reemplazar páginas muy usadas\\
- Sufre de anomalía de Belady (¡más marcos → más PF!)\\
}

### Óptimo (OPT o MIN)

Algoritmo teórico propuesto por Belady: reemplazar la página que NO se usará por más tiempo en el futuro.

\begin{excerpt}
\emph{Algoritmo Óptimo:}
Selecciona como víctima la página cuya próxima referencia está más lejana en el futuro, o que nunca será referenciada nuevamente.
\end{excerpt}

\textcolor{orange!70!black}{\textbf{¿Por qué no se usa en la práctica?}\\
Requiere conocer el futuro (secuencia completa de referencias)\\
→ Imposible en sistemas reales\\
\\
¿Entonces para qué sirve?\\
→ Como REFERENCIA para comparar otros algoritmos\\
→ "¿Cuán cerca está mi algoritmo del óptimo?"\\
}

**Propiedad:** OPT garantiza la menor cantidad posible de page faults para una secuencia dada.

### LRU (Least Recently Used)

Aproximación práctica al óptimo: reemplazar la página que NO se ha usado por más tiempo en el pasado.

\begin{excerpt}
\emph{LRU (Least Recently Used):}
Selecciona como víctima la página cuyo último acceso fue el más lejano en el pasado. Se basa en la observación de que páginas recientemente usadas probablemente se usarán pronto (localidad temporal).
\end{excerpt}

**Implementación ideal:** Timestamp en cada acceso

```
Marcos en RAM:
┌────┬────────────────┐
│Pág │ Último acceso  │
├────┼────────────────┤
│ 5  │ t=100          │ ← Víctima (acceso más antiguo)
│ 2  │ t=250          │
│ 9  │ t=180          │
│ 1  │ t=300          │ ← Más reciente
└────┴────────────────┘
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Buen rendimiento en práctica\\
- Explota localidad temporal\\
- Cercano al óptimo en muchos casos\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Costoso: actualizar timestamp en CADA acceso a memoria\\
- Buscar mínimo: O(n) donde n = número de marcos\\
- Implementación exacta es impráctica\\
}

**Problema de implementación exacta:**

```
Cada acceso a memoria requiere:
1. Traducir dirección (MMU) ← OK, es hardware
2. Actualizar timestamp  ← PROBLEMA: requiere escribir a RAM
3. Acceder dato real      ← el acceso original

→ CADA acceso a memoria genera un WRITE adicional
→ Duplica el tráfico de memoria
→ Inaceptable
```

Por eso se usan **aproximaciones** de LRU: Clock y Clock-M.

### Clock (Second Chance)

Aproximación eficiente de LRU usando un bit de referencia.

**Estructura:** Los marcos se organizan en un anillo circular con un puntero ("manecilla del reloj").

```
        ┌──────┐
    ┌───│ P=5  │───┐
    │   │ U=1  │   │
┌───┴──┐└──────┘┌──┴───┐
│ P=1  │        │ P=2  │
│ U=0  │  ↑     │ U=1  │
└───┬──┘ puntero└──┬───┘
    │   (clock)    │
    │   ┌──────┐   │
    └───│ P=9  │───┘
        │ U=0  │
        └──────┘
```

**Algoritmo:**

```
Al buscar víctima:
1. Examinar página actual (donde apunta el puntero)
2. Si U=1:
   - Dar "segunda oportunidad": U=0
   - Avanzar puntero
   - Continuar
3. Si U=0:
   - Esta es la víctima
   - Reemplazar
   - Avanzar puntero
```

**El bit U "uso" (R - Referenced):**
- Hardware lo pone en 1 cada vez que se accede la página
- El algoritmo lo pone en 0 al dar segunda oportunidad

\textcolor{blue!50!black}{\textbf{Intuición:}\\
- U=1: "He sido usada recientemente, dame otra chance"\\
- U=0: "No he sido usada desde la última inspección"\\
→ Aproxima LRU: páginas no usadas se eliminan primero\\
}

### Clock-M (Clock Mejorado / Enhanced Second Chance)

Versión mejorada de Clock que considera tanto el bit U (Referenced) como el bit M (Modified/Dirty).

\begin{excerpt}
\emph{Clock-M (Clock Mejorado):}
Extensión del algoritmo Clock que usa los bits U y M para clasificar páginas en 4 categorías de prioridad para reemplazo. Prefiere reemplazar páginas no modificadas para evitar escrituras a disco.
\end{excerpt}

**Clasificación de páginas:**

| Clase | U | M | Descripción | Prioridad Reemplazo |
|-------|---|---|-------------|---------------------|
| 0     | 0 | 0 | No usada, no modificada | Mejor víctima |
| 1     | 0 | 1 | No usada, modificada | Segunda opción |
| 2     | 1 | 0 | Usada, no modificada | Tercera opción |
| 3     | 1 | 1 | Usada y modificada | Peor víctima |

**¿Por qué considerar M?**

\textcolor{orange!70!black}{\textbf{Costo de reemplazar página dirty (M=1):}\\
1. Escribir página a disco (~10 ms con HDD)\\
2. Leer nueva página de disco (~10 ms)\\
Total: ~20 ms\\
\\
Costo de reemplazar página clean (M=0):\\
1. Descartar página (no escribir nada)\\
2. Leer nueva página (~10 ms)\\
Total: ~10 ms\\
→ 50\\% más rápido\\
}

**Algoritmo Clock-M (las 4 vueltas):**

```
Búsqueda de víctima (hasta 4 pasadas):

Vuelta 1: Buscar clase 0 (U=0, M=0)
- Examinar páginas sin modificar U
- Si encuentra (U=0, M=0): ¡víctima encontrada!
- Si no: continuar vuelta 2

Vuelta 2: Buscar clase 1 (U=0, M=1)
- Examinar páginas sin modificar U
- Si encuentra (U=0, M=1): víctima encontrada
- Si no: continuar vuelta 3

Vuelta 3: Buscar clase 0 nuevamente (U=0, M=0)
- Ahora SÍ modificar U: U=1 → U=0
- Si encuentra (U=0, M=0): víctima encontrada
- Si no: continuar vuelta 4

Vuelta 4: Buscar clase 1 (U=0, M=1)
- Modificar U: U=1 → U=0
- Tomar la primera página (U=0, M=1) que encuentre
```

\textcolor{blue!50!black}{\textbf{Lógica de las 4 vueltas:}\\
Vueltas 1-2: Intentar encontrar víctima sin dar segundas oportunidades\\
→ Si existe página clase 0 o 1, la encontrará rápido\\
\\
Vueltas 3-4: Dar segundas oportunidades (resetear U)\\
→ Si todas las páginas tenían U=1, ahora tendrán U=0\\
→ Garantiza encontrar víctima eventualmente\\
}

### Ejercicio Comparativo de Algoritmos

Analicemos una secuencia de referencias con diferentes algoritmos.

**Configuración:**
- Marcos disponibles: 3
- Secuencia de referencias: `7, 0, 1, 2, 0, 3, 0, 4, 2, 3, 0, 3, 2, 1, 2, 0, 1, 7, 0, 1`

#### Algoritmo FIFO

```
Referencia │ 7 │ 0 │ 1 │ 2 │ 0 │ 3 │ 0 │ 4 │ 2 │ 3 │ 0 │ 3 │ 2 │ 1 │ 2 │ 0 │ 1 │ 7 │ 0 │ 1 │
───────────┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
Marco 0    │ 7 │ 7 │ 7 │ 2 │ 2 │ 2 │ 2 │ 4 │ 4 │ 4 │ 0 │ 0 │ 0 │ 1 │ 1 │ 1 │ 1 │ 7 │ 7 │ 7 │
Marco 1    │   │ 0 │ 0 │ 0 │ 0 │ 3 │ 3 │ 3 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 0 │ 0 │ 0 │ 0 │ 0 │
Marco 2    │   │   │ 1 │ 1 │ 1 │ 1 │ 1 │ 1 │ 1 │ 3 │ 3 │ 3 │ 3 │ 3 │ 3 │ 3 │ 1 │ 1 │ 1 │ 1 │
───────────┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
PF         │ F │ F │ F │ F │   │ F │   │ F │ F │ F │ F │   │   │ F │   │ F │ F │ F │   │   │
───────────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
Total Page Faults: 15
```

#### Algoritmo Óptimo (OPT)

```
Referencia │ 7 │ 0 │ 1 │ 2 │ 0 │ 3 │ 0 │ 4 │ 2 │ 3 │ 0 │ 3 │ 2 │ 1 │ 2 │ 0 │ 1 │ 7 │ 0 │ 1 │
───────────┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
Marco 0    │ 7 │ 7 │ 7 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 2 │ 7 │ 7 │ 7 │
Marco 1    │   │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │ 0 │
Marco 2    │   │   │ 1 │ 1 │ 1 │ 3 │ 3 │ 4 │ 4 │ 3 │ 3 │ 3 │ 3 │ 1 │ 1 │ 1 │ 1 │ 1 │ 1 │ 1 │
───────────┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
PF         │ F │ F │ F │ F │   │ F │   │ F │   │ F │   │   │   │ F │   │   │   │ F │   │   │
───────────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
Total Page Faults: 9
```

**Decisiones clave de OPT:**
- En ref 6 (pág 3): reemplaza 7 (próxima ref en pos 18, muy lejana)
- En ref 8 (pág 4): reemplaza 1 (próxima ref en pos 14)
- En ref 10 (pág 3): reemplaza 4 (nunca se vuelve a usar)

#### Algoritmo Clock-M (Detallado)

Ahora veamos Clock-M con detalle de los bits U y M.

**Supuestos:**
- Páginas cargadas desde disco inician con U=0, M=0
- Al acceder una página: U=1
- Al escribir una página: M=1
- Secuencia incluye algunas escrituras (las marcaremos)

**Secuencia extendida:** 
`7R, 0R, 1W, 2R, 0R, 3W, 0W, 4R, 2W, 3R, 0R, 3R, 2R, 1R, 2W, 0R, 1R, 7W, 0R, 1R`
(R=Read, W=Write)

```
Estado inicial: 3 marcos vacíos
Puntero Clock en marco 0

───────────────────────────────────────────────────
Ref 1: Acceso 7 (lectura)
- Page fault, cargar en marco 0
- Marcos: [7(0,0)] [ ] [ ]
- Puntero: marco 1
PF: 1

Ref 2: Acceso 0 (lectura)
- Page fault, cargar en marco 1
- Marcos: [7(0,0)] [0(0,0)] [ ]
- Puntero: marco 2
PF: 2

Ref 3: Acceso 1 (escritura)
- Page fault, cargar en marco 2
- Marcos: [7(0,0)] [0(0,0)] [1(0,1)]  ← M=1 por escritura
- Puntero: marco 0
PF: 3

Ref 4: Acceso 2 (lectura)
- Page fault, necesita reemplazar
- Puntero en marco 0: [7(0,0)] ← U=0,M=0 (clase 0)
  → Víctima encontrada en vuelta 1
  → Reemplazar 7 por 2
- Marcos: [2(0,0)] [0(0,0)] [1(0,1)]
- Puntero: marco 1
PF: 4

Ref 5: Acceso 0 (lectura)
- Hit, marcar U=1
- Marcos: [2(0,0)] [0(1,0)] [1(0,1)]
PF: 4

Ref 6: Acceso 3 (escritura)
- Page fault, necesita reemplazar
- Estado actual: [2(0,0)] [0(1,0)] [1(0,1)]
- Puntero en marco 1:
  
  Vuelta 1: Buscar (U=0,M=0)
  - Marco 1: [0(1,0)] → U=1, siguiente
  - Marco 2: [1(0,1)] → M=1, siguiente
  - Marco 0: [2(0,0)] → U=0,M=0 - Víctima!
  
- Reemplazar pág 2 por pág 3, marcar M=1
- Marcos: [3(0,1)] [0(1,0)] [1(0,1)]
- Puntero: marco 1
PF: 5

Ref 7: Acceso 0 (escritura)
- Hit, marcar M=1
- Marcos: [3(0,1)] [0(1,1)] [1(0,1)]
PF: 5

Ref 8: Acceso 4 (lectura)
- Page fault, necesita reemplazar
- Estado actual: [3(0,1)] [0(1,1)] [1(0,1)]
- Puntero en marco 1:
  
  Vuelta 1: Buscar (U=0,M=0)
  - Marco 1: [0(1,1)] → U=1, siguiente
  - Marco 2: [1(0,1)] → M=1, siguiente
  - Marco 0: [3(0,1)] → M=1, siguiente
  - Vuelve a marco 1, ninguna clase 0 encontrada
  
  Vuelta 2: Buscar (U=0,M=1)
  - Marco 1: [0(1,1)] → U=1, siguiente
  - Marco 2: [1(0,1)] → U=0,M=1 - Víctima!
  
- Reemplazar pág 1 por pág 4
- Marcos: [3(0,1)] [0(1,1)] [4(0,0)]
- Puntero: marco 0
- (Nota: hay que escribir pág 1 a disco antes)
PF: 6

[Resto de referencias siguiendo la misma lógica]

Refs 9-20: (formato compacto)
─────────────────────────────────────
Ref 9: Acceso 2 (escritura) → PF
  Víctima: pág 3 (estado: 01)
  Marcos: [2(0,1)] [0(1,1)] [4(0,0)]
PF: 7

Ref 10: Acceso 3 (lectura) → PF
  Víctima: pág 4 (estado: 00)
  Marcos: [2(0,1)] [0(1,1)] [3(0,0)]
PF: 8

Refs 11-13: Hits (0,3,2)
PF: 8

Ref 14: Acceso 1 (lectura) → PF
  Víctima: pág 3 (estado: 10)
  Marcos: [2(0,1)] [0(1,1)] [1(0,0)]
PF: 9

Ref 15: Acceso 2 (escritura) → Hit
  Marcos: [2(1,1)] [0(1,1)] [1(0,0)]
PF: 9

Refs 16-20: (0,1,7,0,1)
  Ref 18: Acceso 7 → PF (víctima: pág 2)
  Resto: Hits
PF: 10

───────────────────────────────────────────────────
Total Page Faults Clock-M: 10
```

\textcolor{blue!50!black}{\textbf{Observaciones clave del ejercicio:}\\
- Clock-M dio 2 vueltas completas en ref 6 y ref 8\\
- En ref 8, no encontró clase 0 en vuelta 1, buscó clase 1 en vuelta 2\\
- Escrituras aumentan M, lo que puede hacer a una página menos deseable\\
- El algoritmo evitó escribir páginas dirty cuando pudo\\
}

### Comparación Final

```
Algoritmo    │ Page Faults │ Complejidad │ Hardware Req
─────────────┼─────────────┼─────────────┼──────────────
FIFO         │     15      │    O(1)     │ Ninguno
Óptimo (OPT) │      9      │    O(n)     │ Conocer futuro
LRU          │     12      │    O(n)     │ Timestamp
Clock        │     11      │    O(n)     │ Bit U
Clock-M      │     10      │    O(n)     │ Bits U y M
```

\textcolor{teal!60!black}{\textbf{Conclusiones:}\\
- Óptimo es inalcanzable pero da cota inferior\\
- Clock-M se acerca bastante a óptimo (10 vs 9)\\
- FIFO es el peor (15 page faults, 67\\% más que óptimo)\\
- El bit M ayuda: Clock-M mejor que Clock\\
}

## Thrashing

### ¿Qué es Thrashing?

\begin{excerpt}
\emph{Thrashing:}
Estado del sistema donde se dedica más tiempo a manejar page faults (cargar/descargar páginas) que a ejecutar instrucciones útiles. Ocurre cuando la suma de los working sets de todos los procesos excede la memoria física disponible.
\end{excerpt}

**Síntomas de thrashing:**
- CPU utilization muy baja (< 20%)
- Disco trabajando constantemente (I/O al 100%)
- Procesos avanzan muy lentamente
- Sistema prácticamente inutilizable

**Ejemplo numérico:**

```
Sistema con 1 GiB RAM, 10 procesos:
Cada proceso necesita working set de 150 MiB
Total necesario: 10 × 150 MiB = 1500 MiB
Disponible: 1000 MiB

Déficit: 500 MiB

¿Qué pasa?
→ Solo ~6 procesos caben cómodamente (6 × 150 = 900 MiB)
→ Los otros 4 procesos generan page faults constantemente
→ Al cargar páginas de proceso A, se quitan de proceso B
→ Proceso B genera page fault, quita páginas de proceso C
→ Proceso C genera page fault, quita páginas de proceso A
→ CICLO VICIOSO sin fin
```

**Medición de thrashing:**

```
Sin thrashing (normal):
- CPU: 80% utilization
- Disk I/O: 20% utilization
- Tiempo por instrucción: 10 ns (promedio)

Con thrashing:
- CPU: 5% utilization
- Disk I/O: 95% utilization
- Tiempo por instrucción: ~10 ms (promedio)
→ 1,000,000x más lento!
```

### ¿Por Qué Ocurre?

**Causa fundamental:** Sobrecarga de multiprogramación

```
Grado de multiprogramación vs Throughput:

Throughput
    ^
    │     ┌───────┐ Punto óptimo
    │    ╱         ╲
    │   ╱           ╲
    │  ╱             ╲_____ Thrashing!
    │ ╱                     ╲
    │╱                       ╲___
    └────────────────────────────> Grado multiprog.
    0  2  4  6  8 10 12 14 16

Explicación:
- Pocos procesos (0-6): CPU subutilizada
- Punto óptimo (6-8): máximo throughput
- Demasiados procesos (>10): thrashing
```

**El ciclo del thrashing:**

```
1. Sistema con poca carga → CPU idle
2. SO agrega más procesos (aumentar utilization)
3. Memoria se llena, procesos generan page faults
4. Procesos se bloquean esperando I/O de disco
5. CPU ve procesos bloqueados → parece que hay poca carga
6. SO agrega AÚN MÁS procesos
7. Más page faults, menos memoria por proceso
8. THRASHING: disco saturado, CPU idle
```

\textcolor{red!60!gray}{\textbf{Paradoja del thrashing:}\\
Baja utilización de CPU → SO agrega procesos\\
→ Empeora thrashing → CPU aún más baja\\
→ SO agrega más procesos → muerte del sistema\\
}

### Detección de Thrashing

**Métricas para detectar thrashing:**

1. **Page Fault Rate:**
   ```
   Si PF rate > umbral (ej: 10 PF/segundo por proceso)
   → Señal de thrashing
   ```

2. **Relación CPU/Disco:**
   ```
   Si (Disk I/O %) / (CPU %) > 5
   → Thrashing probable
   
   Normal: Disk 20%, CPU 80% → ratio 0.25
   Thrashing: Disk 95%, CPU 5% → ratio 19
   ```

3. **Tiempo de servicio de page faults:**
   ```
   Si avg_PF_service_time > 50 ms
   → Señal de que el disco no da abasto
   ```

### Prevención y Recuperación

**Estrategias de prevención:**

1. **Working Set Model:**
   ```
   - Estimar working set de cada proceso
   - Solo ejecutar proceso si:
     Suma_working_sets ≤ RAM_disponible
   - Si no: suspender procesos
   ```

2. **Page Fault Frequency (PFF):**
   ```
   Para cada proceso:
   - Si PF_rate > umbral_alto:
     → Darle más marcos
   - Si PF_rate < umbral_bajo:
     → Quitarle marcos
   - Si no hay marcos disponibles:
     → Suspender proceso
   ```

3. **Limitar grado de multiprogramación:**
   ```
   Establecer máximo de procesos activos
   Ej: con 8 GiB RAM, límite de 20 procesos
   ```

**Estrategias de recuperación:**

```
Si se detecta thrashing:

1. Suspender procesos:
   - Swapear proceso completo a disco
   - Liberar TODA su memoria
   - Reducir grado de multiprogramación

2. Priorizar procesos críticos:
   - Garantizar working set a procesos importantes
   - Suspender procesos de baja prioridad

3. Aumentar memoria:
   - Agregar RAM física (obviamente)
   - Reducir memory footprint de procesos
```

### Preguntas Típicas de Parcial

**Pregunta 1:** *Si un sistema está en thrashing, ¿mejora el rendimiento agregando más procesos?*

\textcolor{red!60!gray}{\textbf{Respuesta: NO}\\
Agregar más procesos EMPEORA el thrashing.\\
Causa: menos memoria por proceso → más page faults\\
→ más I/O de disco → peor rendimiento\\
\\
Solución: REDUCIR procesos, no agregar.\\
}

**Pregunta 2:** *¿Agregar más RAM siempre soluciona thrashing?*

\textcolor{orange!70!black}{\textbf{Respuesta: Depende del contexto}\\
- Si thrashing por falta de RAM real: SÍ ayuda\\
- Si thrashing por procesos con working sets enormes: ayuda parcialmente\\
- Si thrashing por algoritmo de reemplazo malo: NO ayuda\\
- Si SO sigue agregando procesos sin límite: NO ayuda (problema de diseño)\\
}

**Pregunta 3:** *Sistema tiene 20% CPU, 90% Disk I/O. ¿Thrashing? ¿Qué hacer?*

\textcolor{teal!60!black}{\textbf{Respuesta: SÍ, thrashing claro}\\
Ratio Disk/CPU = 90/20 = 4.5 (muy alto)\\
\\
Acciones inmediatas:\\
1. Identificar procesos con alto PF rate\\
2. Suspender procesos menos críticos\\
3. Verificar working sets vs RAM disponible\\
4. NO agregar más procesos\\
}

**Pregunta 4:** *¿Thrashing puede ocurrir con mucha RAM libre?*

\textcolor{blue!50!black}{\textbf{Respuesta: SÍ, en casos raros}\\
Ejemplo: algoritmo de reemplazo muy malo\\
- FIFO puede reemplazar páginas constantemente usadas\\
- Si todas las páginas del working set son "viejas" en FIFO\\
- Resultado: page faults continuos pese a RAM libre\\
\\
Pero es muy poco común; thrashing típico es por falta de RAM.\\
}

## Código en C: Simulador de Clock-M

Este simulador implementa el algoritmo Clock-M (Clock Mejorado) y permite visualizar el proceso de reemplazo paso a paso.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>

// Configuración del sistema
#define NUM_FRAMES 4        // Número de marcos en RAM
#define MAX_REFS 50         // Máximo de referencias a simular

// Estructura de un marco
typedef struct {
    int page;               // Número de página (-1 si vacío)
    bool referenced;        // Bit U (referenced)
    bool modified;          // Bit M (modified)
} Frame;

// Estado del sistema
typedef struct {
    Frame frames[NUM_FRAMES];
    int clock_hand;         // Puntero del reloj
    int page_faults;        // Contador de page faults
} SystemState;

// Tipo de acceso
typedef enum {
    ACCESS_READ,
    ACCESS_WRITE
} AccessType;

// Inicializar sistema
void init_system(SystemState *sys) {
    for (int i = 0; i < NUM_FRAMES; i++) {
        sys->frames[i].page = -1;        // Marco vacío
        sys->frames[i].referenced = false;
        sys->frames[i].modified = false;
    }
    sys->clock_hand = 0;
    sys->page_faults = 0;
}

// Imprimir estado de marcos
void print_frames(SystemState *sys) {
    printf("Marcos: ");
    for (int i = 0; i < NUM_FRAMES; i++) {
        if (sys->frames[i].page == -1) {
            printf("[  -  ] ");
        } else {
            printf("[%d(%d,%d)] ", 
                   sys->frames[i].page,
                   sys->frames[i].referenced ? 1 : 0,
                   sys->frames[i].modified ? 1 : 0);
        }
    }
    printf(" Clock→%d\n", sys->clock_hand);
}

// Buscar página en marcos
int find_page(SystemState *sys, int page) {
    for (int i = 0; i < NUM_FRAMES; i++) {
        if (sys->frames[i].page == page) {
            return i;  // Encontrada
        }
    }
    return -1;  // No encontrada
}

// Buscar marco vacío
int find_empty_frame(SystemState *sys) {
    for (int i = 0; i < NUM_FRAMES; i++) {
        if (sys->frames[i].page == -1) {
            return i;
        }
    }
    return -1;  // No hay marcos vacíos
}

// Algoritmo Clock-M: buscar víctima
// Retorna índice del marco a reemplazar
int clock_m_find_victim(SystemState *sys) {
    printf("  Buscando víctima con Clock-M...\n");
    
    int start = sys->clock_hand;
    int victim = -1;
    
    // Vuelta 1: Buscar clase 0 (U=0, M=0) sin modificar bits
    printf("  Vuelta 1: Buscando (U=0, M=0)\n");
    for (int i = 0; i < NUM_FRAMES; i++) {
        int idx = (start + i) % NUM_FRAMES;
        Frame *f = &sys->frames[idx];
        
        printf("    Marco %d: pág %d (U=%d, M=%d) → ",
               idx, f->page, f->referenced, f->modified);
        
        if (!f->referenced && !f->modified) {
            printf("Clase 0 - Víctima encontrada!\n");
            victim = idx;
            sys->clock_hand = (idx + 1) % NUM_FRAMES;
            return victim;
        }
        printf("Siguiente\n");
    }
    
    // Vuelta 2: Buscar clase 1 (U=0, M=1) sin modificar bits
    printf("  Vuelta 2: Buscando (U=0, M=1)\n");
    for (int i = 0; i < NUM_FRAMES; i++) {
        int idx = (start + i) % NUM_FRAMES;
        Frame *f = &sys->frames[idx];
        
        printf("    Marco %d: pág %d (U=%d, M=%d) → ",
               idx, f->page, f->referenced, f->modified);
        
        if (!f->referenced && f->modified) {
            printf("Clase 1 - Víctima encontrada!\n");
            victim = idx;
            sys->clock_hand = (idx + 1) % NUM_FRAMES;
            return victim;
        }
        printf("Siguiente\n");
    }
    
    // Vuelta 3: Buscar clase 0 (U=0, M=0) reseteando U
    printf("  Vuelta 3: Buscando (U=0, M=0) y reseteando U\n");
    for (int i = 0; i < NUM_FRAMES; i++) {
        int idx = (start + i) % NUM_FRAMES;
        Frame *f = &sys->frames[idx];
        
        printf("    Marco %d: pág %d (U=%d, M=%d) → ",
               idx, f->page, f->referenced, f->modified);
        
        if (f->referenced) {
            printf("Resetear U=0, ");
            f->referenced = false;
        }
        
        if (!f->referenced && !f->modified) {
            printf("Clase 0 - Víctima encontrada!\n");
            victim = idx;
            sys->clock_hand = (idx + 1) % NUM_FRAMES;
            return victim;
        }
        printf("Siguiente\n");
    }
    
    // Vuelta 4: Buscar clase 1 (U=0, M=1) con U ya reseteado
    printf("  Vuelta 4: Buscando (U=0, M=1)\n");
    for (int i = 0; i < NUM_FRAMES; i++) {
        int idx = (start + i) % NUM_FRAMES;
        Frame *f = &sys->frames[idx];
        
        printf("    Marco %d: pág %d (U=%d, M=%d) → ",
               idx, f->page, f->referenced, f->modified);
        
        if (!f->referenced && f->modified) {
            printf("Clase 1 - Víctima encontrada!\n");
            victim = idx;
            sys->clock_hand = (idx + 1) % NUM_FRAMES;
            return victim;
        }
        printf("Siguiente\n");
    }
    
    // No debería llegar aquí (al menos una página debe ser víctima)
    // En caso extremo, tomar la primera
    printf("  [ERROR] No se encontró víctima, tomando marco 0\n");
    return 0;
}

// Acceder a una página
void access_page(SystemState *sys, int page, AccessType type) {
    char *access_str = (type == ACCESS_READ) ? "LECTURA" : "ESCRITURA";
    
    printf("\n─────────────────────────────────────────\n");
    printf("Acceso %d: Página %d (%s)\n", 
           sys->page_faults + 1, page, access_str);
    
    // Buscar página en marcos
    int frame_idx = find_page(sys, page);
    
    if (frame_idx != -1) {
        // HIT: página ya está en RAM
        printf("  - HIT: Página %d en marco %d\n", page, frame_idx);
        sys->frames[frame_idx].referenced = true;
        if (type == ACCESS_WRITE) {
            sys->frames[frame_idx].modified = true;
        }
    } else {
        // MISS: page fault
        printf("PAGE FAULT: Página %d no está en RAM\n", page);
        sys->page_faults++;
        
        // Buscar marco vacío
        frame_idx = find_empty_frame(sys);
        
        if (frame_idx != -1) {
            // Hay marco vacío, cargar directamente
            printf("  Marco %d está vacío, cargar página %d\n", 
                   frame_idx, page);
        } else {
            // No hay marcos vacíos, ejecutar algoritmo de reemplazo
            printf("  No hay marcos vacíos, ejecutar Clock-M\n");
            frame_idx = clock_m_find_victim(sys);
            
            Frame *victim = &sys->frames[frame_idx];
            printf("  Reemplazar página %d (en marco %d)\n", 
                   victim->page, frame_idx);
            
            // Si la víctima está modificada, hay que escribirla a disco
            if (victim->modified) {
                printf("  [I/O] Escribir página %d a disco (dirty)\n", 
                       victim->page);
            }
        }
        
        // Cargar nueva página
        printf("  [I/O] Leer página %d desde disco\n", page);
        sys->frames[frame_idx].page = page;
        sys->frames[frame_idx].referenced = false;  // Recién cargada
        sys->frames[frame_idx].modified = (type == ACCESS_WRITE);
    }
    
    print_frames(sys);
}

// Función principal
int main() {
    SystemState sys;
    init_system(&sys);
    
    printf("═══════════════════════════════════════════\n");
    printf("  SIMULADOR DE CLOCK-M (Clock Mejorado)\n");
    printf("═══════════════════════════════════════════\n");
    printf("Configuración: %d marcos en RAM\n", NUM_FRAMES);
    printf("Formato: [pág(U,M)] donde U=Referenced, M=Modified\n\n");
    
    // Secuencia de referencias (página, tipo de acceso)
    // R = READ, W = WRITE
    typedef struct {
        int page;
        AccessType type;
    } Reference;
    
    Reference refs[] = {
        {7, ACCESS_READ},   // 1
        {0, ACCESS_READ},   // 2
        {1, ACCESS_WRITE},  // 3
        {2, ACCESS_READ},   // 4
        {0, ACCESS_READ},   // 5
        {3, ACCESS_WRITE},  // 6
        {0, ACCESS_WRITE},  // 7
        {4, ACCESS_READ},   // 8
        {2, ACCESS_WRITE},  // 9
        {3, ACCESS_READ},   // 10
        {0, ACCESS_READ},   // 11
        {3, ACCESS_READ},   // 12
        {2, ACCESS_READ},   // 13
        {1, ACCESS_READ},   // 14
        {2, ACCESS_WRITE},  // 15
    };
    
    int num_refs = sizeof(refs) / sizeof(refs[0]);
    
    // Ejecutar simulación
    for (int i = 0; i < num_refs; i++) {
        access_page(&sys, refs[i].page, refs[i].type);
    }
    
    // Resumen final
    printf("\n═══════════════════════════════════════════\n");
    printf("  RESUMEN FINAL\n");
    printf("═══════════════════════════════════════════\n");
    printf("Total de referencias: %d\n", num_refs);
    printf("Total de page faults: %d\n", sys.page_faults);
    printf("Hit rate: %.2f%%\n", 
           ((num_refs - sys.page_faults) * 100.0) / num_refs);
    printf("Page fault rate: %.2f%%\n", 
           (sys.page_faults * 100.0) / num_refs);
    
    printf("\nEstado final de marcos:\n");
    print_frames(&sys);
    
    return 0;
}
```

**Compilación y ejecución:**

```bash
gcc -o clock_m_sim clock_m_sim.c -Wall -std=c99
./clock_m_sim
```

**Salida esperada (parcial):**

```
═══════════════════════════════════════════
  SIMULADOR DE CLOCK-M (Clock Mejorado)
═══════════════════════════════════════════
Configuración: 4 marcos en RAM
Formato: [pág(U,M)] donde U=Referenced, M=Modified

─────────────────────────────────────────
Acceso 1: Página 7 (LECTURA)
  PAGE FAULT: Página 7 no está en RAM
  Marco 0 está vacío, cargar página 7
  [I/O] Leer página 7 desde disco
Marcos: [7(0,0)] [  -  ] [  -  ] [  -  ]  Clock→1

─────────────────────────────────────────
Acceso 2: Página 0 (LECTURA)
  PAGE FAULT: Página 0 no está en RAM
  Marco 1 está vacío, cargar página 0
  [I/O] Leer página 0 desde disco
Marcos: [7(0,0)] [0(0,0)] [  -  ] [  -  ]  Clock→2

[...]

─────────────────────────────────────────
Acceso 8: Página 4 (LECTURA)
  PAGE FAULT: Página 4 no está en RAM
  No hay marcos vacíos, ejecutar Clock-M
  Buscando víctima con Clock-M...
  Vuelta 1: Buscando (U=0, M=0)
    Marco 0: pág 7 (U=0, M=0) → Clase 0 - Víctima encontrada!
  Reemplazar página 7 (en marco 0)
  [I/O] Leer página 4 desde disco
Marcos: [4(0,0)] [0(1,1)] [1(0,1)] [3(0,1)]  Clock→1

[...]

═══════════════════════════════════════════
  RESUMEN FINAL
═══════════════════════════════════════════
Total de referencias: 15
Total de page faults: 9
Hit rate: 40.00%
Page fault rate: 60.00%

Estado final de marcos:
Marcos: [2(1,1)] [0(1,0)] [1(0,0)] [3(1,0)]  Clock→2
```

\textcolor{blue!50!black}{\textbf{Conceptos demostrados en el código:}\\
- Estructura de marcos con bits U y M\\
- Puntero circular (clock hand)\\
- Las 4 vueltas del algoritmo Clock-M\\
- Detección de páginas dirty (requieren escritura)\\
- Diferencia entre hits y page faults\\
- Contadores de rendimiento\\
}