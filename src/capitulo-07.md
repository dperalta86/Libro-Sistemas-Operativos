# Gestión de Memoria Real

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Distinguir entre direcciones lógicas, relativas y físicas
- Explicar los momentos de binding de direcciones (compilación, carga, ejecución)
- Identificar fragmentación interna vs externa y sus causas
- Analizar ventajas y desventajas de particiones fijas y dinámicas
- Aplicar algoritmos de asignación: First Fit, Best Fit, Worst Fit, Next Fit
- Calcular direcciones físicas a partir de direcciones lógicas en paginación
- Determinar el formato de dirección lógica (bits de página y offset)
- Explicar el funcionamiento de MMU, TLB y registros base/límite
- Comparar paginación simple, multinivel y segmentación
- Resolver ejercicios de traducción de direcciones con tablas de páginas
- Comprender el rol del Buddy System en asignación de memoria
- Evaluar cuándo aplicar compactación y sus costos

## Introducción y Contexto

### ¿Por qué necesitamos gestionar la memoria?

Imaginemos una biblioteca con espacio limitado para libros. Si cada estudiante llega y toma el espacio que necesita sin control alguno, pronto tendremos espacios desaprovechados entre libros, imposibilidad de ubicar libros nuevos aunque haya espacio total suficiente, estudiantes accediendo a libros que no les pertenecen, y caos al intentar encontrar un libro específico.  
Lo mismo sucede con la memoria RAM en un sistema operativo multiprogramado. Con múltiples procesos ejecutándose simultáneamente, el SO debe asignar memoria de manera eficiente, proteger la memoria de cada proceso, permitir compartir memoria cuando sea apropiado, y traducir direcciones para que cada proceso "crea" que tiene toda la memoria disponible.

### El problema fundamental

En los primeros sistemas, un programa accedía directamente a direcciones físicas de memoria. Esto presentaba problemas críticos: un proceso podía sobrescribir memoria del SO, era imposible reubicar un programa una vez cargado, no se podía ejecutar más de un programa simultáneamente, y errores de programación podían corromper todo el sistema.

\begin{warning}
El direccionamiento directo a memoria física es incompatible con sistemas multiprogramados seguros. Sin una capa de abstracción, cualquier error de programación puede destruir el sistema completo.
\end{warning}

La solución fue introducir una capa de abstracción: el concepto de espacio de direcciones lógicas. Esta abstracción permite que cada proceso opere en su propio espacio virtual, completamente aislado de otros procesos y del sistema operativo.

### Evolución histórica

La gestión de memoria ha evolucionado siguiendo un patrón de "problema → solución → nuevo problema". La memoria compartida sin protección permitía que un programa destruyera todo el sistema, lo que llevó a las particiones fijas. Estas eliminaron el caos pero introdujeron desperdicio de memoria por fragmentación interna. Las particiones dinámicas resolvieron este problema, pero generaron fragmentación externa severa. La paginación eliminó la fragmentación externa al costo de agregar overhead de traducción. La segmentación ofreció un mejor modelo lógico pero con mayor complejidad. Finalmente, los sistemas híbridos combinaron ventajas de múltiples técnicas, aunque con complejidad adicional.
\begin{infobox}
Este capítulo recorre esta evolución histórica no solo por interés académico, sino porque entender por qué cada técnica surgió nos ayuda a comprender las decisiones de diseño de los sistemas modernos.
\end{infobox}

## Conceptos Fundamentales

### Espacios de Direcciones

Un espacio de direcciones es el conjunto de direcciones que una entidad puede usar para referenciar memoria. Existen tres tipos fundamentales, cada uno con su propósito específico en la jerarquía de traducción de direcciones.

#### Dirección Lógica (Virtual)

La dirección lógica es generada por el CPU durante la ejecución de un programa. Es la dirección que "ve" el proceso. Por ejemplo, cuando un programa en C hace:

```c
int x = 42;
printf("Dirección de x: %p\n", &x);
```

La dirección mostrada es una dirección lógica. El proceso no sabe (ni le importa) dónde está físicamente en RAM. Esta independencia es fundamental: permite que el sistema operativo reubique el proceso en memoria sin que este se entere, facilita la protección entre procesos, y hace posible la memoria virtual.  

Las direcciones lógicas son independientes de la ubicación física, permiten reubicación del proceso, cada proceso tiene su propio espacio lógico aislado, y típicamente van desde 0 hasta el límite del proceso.

#### Dirección Relativa

Es una dirección expresada como desplazamiento desde un punto de referencia, típicamente el inicio del programa. Si un programa se compila y la variable `x` está en el offset 100 desde el inicio del código, su dirección relativa es 100, sin importar dónde se cargue el programa en memoria. Este concepto es clave para generar código reubicable.

#### Dirección Física (Real)

Es la dirección real en los módulos de RAM. El hardware usa estas direcciones para acceder a la memoria física. Hay algo crucial que debés entender: el proceso NUNCA ve direcciones físicas. La traducción la hace el hardware (MMU) de forma transparente, y el SO solo configura los parámetros de traducción.
\begin{highlight}
La separación entre direcciones lógicas y físicas es el fundamento de todos los sistemas operativos modernos. Sin esta abstracción, no existirían la multiprogramación segura, la memoria virtual, ni la protección entre procesos.
\end{highlight}

### Binding de Direcciones

El binding es el proceso de asignar direcciones de programa a direcciones reales de memoria. El momento en que esto ocurre tiene implicaciones profundas en la flexibilidad y eficiencia del sistema. Puede ocurrir en tres momentos diferentes, cada uno con sus ventajas y limitaciones.

#### En Tiempo de Compilación

El compilador genera direcciones físicas absolutas directamente en el código ejecutable.

```c
// El compilador coloca 'x' en la dirección física 0x1000
int x = 10;  // Compilado como: MOV [0x1000], 10
```

Este enfoque tiene desventajas severas: el programa solo funciona en esa ubicación específica de memoria, es imposible ejecutar múltiples instancias del mismo programa, no hay protección entre procesos, y hay que recompilar si se cambia la ubicación. Su uso histórico se limitó a sistemas embebidos antiguos y programas únicos en memoria.

#### En Tiempo de Carga

El loader (cargador) ajusta las direcciones cuando carga el programa en memoria. El compilador genera código reubicable, y el loader determina la base al momento de cargar.

```c
// El compilador genera código reubicable
int x = 10;  // Compilado como: MOV [BASE+100], 10
// El loader determina BASE al cargar
```

Aunque mejor que el binding en compilación, tiene limitaciones importantes: una vez cargado, no se puede mover el proceso en memoria, el tiempo de carga aumenta porque hay que ajustar todas las direcciones, y no permite compactación de memoria. Se usó históricamente en sistemas batch y con overlays.

#### En Tiempo de Ejecución
Las direcciones se traducen dinámicamente durante la ejecución usando hardware especial (MMU). El compilador genera direcciones lógicas, y la MMU traduce cada acceso a memoria en tiempo real.

```c
// El compilador genera direcciones lógicas
int x = 10;  // Genera: MOV [100], 10 (dirección lógica)
// La MMU traduce 100 -> dirección física en cada acceso
```

Esta técnica ofrece ventajas fundamentales: el proceso puede moverse en memoria mediante compactación, la protección entre procesos es automática, soporta memoria virtual con swap, y permite compartir memoria entre procesos de forma controlada.

\begin{theory}
El binding dinámico es la ÚNICA forma de soportar multiprogramación con protección, memoria virtual, compactación dinámica y espacios de direcciones independientes. Sin binding dinámico, no existirían los sistemas operativos modernos tal como los conocemos.
\end{theory}

### Componentes Hardware

#### Memory Management Unit (MMU)

La MMU es un circuito hardware que traduce direcciones lógicas a físicas en tiempo de ejecución. Opera a velocidad del CPU sin intervención del SO, lo cual es absolutamente necesario para mantener el rendimiento del sistema.

El funcionamiento básico es simple en concepto pero crítico en implementación: el CPU genera una dirección lógica, la MMU calcula la dirección física aplicando una función con ciertos parámetros, y la RAM recibe la dirección física resultante. El SO configura los parámetros (registros base/límite, tablas de páginas), pero la traducción es 100% hardware.

\begin{example}
¿Por qué la MMU debe ser hardware y no software? La respuesta está en los números: se ejecuta en CADA acceso a memoria, un programa hace millones de accesos por segundo, si fuera software el sistema sería inutilizable, y el overhead debe ser menor a 10 nanosegundos por traducción. A esa velocidad, solo el hardware puede operar.
\end{example}

#### Translation Lookaside Buffer (TLB)

La MMU necesita consultar tablas de páginas en RAM para traducir direcciones. Como esto es lento (más de 100 nanosegundos), existe una caché especial dentro del CPU llamada TLB.

El TLB es una caché hardware de alta velocidad que almacena traducciones recientes de páginas. Típicamente contiene entre 64 y 512 entradas, con tiempo de acceso menor a 1 nanosegundo. El proceso de traducción con TLB funciona así: el CPU genera una dirección lógica, la MMU busca en TLB en menos de 1 nanosegundo. Si hay un *TLB hit*, usa la traducción cacheada y el acceso total toma alrededor de 10 nanosegundos. Si hay un *TLB miss*, busca en la tabla de páginas en RAM, lo que toma alrededor de 100 nanosegundos. Si fue miss, la entrada se cachea en TLB para futuros accesos.

La efectividad del TLB es impresionante: el hit rate típico es de 98-99%, gracias a la localidad espacial (los procesos acceden memoria cercana) y temporal (mismas páginas repetidamente). Una aplicación bien escrita puede tener un hit rate mayor al 99%, lo que hace que el overhead de traducción sea casi imperceptible.

#### Registros Base y Límite

En los esquemas más simples de gestión de memoria, la MMU usa solo dos registros especiales. El **registro base** contiene la dirección física donde comienza el proceso, y el **registro límite** especifica el tamaño máximo del espacio del proceso.

La traducción es directa: `Dirección Física = Dirección Lógica + Base`. Pero hay una verificación crítica: `Si (Dirección Lógica >= Límite): Generar TRAP (Segmentation Fault)`.

\begin{warning}
La verificación de límites ocurre en HARDWARE mediante un circuito comparador. El SO carga Base y Límite al hacer context switch. Si un proceso intenta acceder fuera de su espacio, el hardware genera un TRAP automáticamente, y el SO maneja el TRAP (típicamente matando el proceso).
\end{warning}

### Fragmentación

La fragmentación es el desperdicio de memoria que no puede usarse eficientemente. Entender la diferencia entre sus dos tipos es fundamental para comprender las ventajas y desventajas de cada técnica de gestión de memoria.

#### Fragmentación Interna

La fragmentación interna es memoria desperdiciada DENTRO de una región asignada. Ocurre cuando se asigna más memoria de la necesitada. Imaginá que un proceso necesita 19 KiB pero el sistema asigna bloques de 4 KiB. Se asignan 5 bloques (20 KiB), desperdiciando 1 KiB.

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-07/01.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
El último "bloque" asignado queda con un sector inutilizable, en el ejemplo 1kiB.
}
\end{center}

Las causas principales son la asignación en bloques de tamaño fijo, políticas de alineación de memoria, y overhead de estructuras administrativas. Ocurre típicamente en particiones fijas, paginación (desperdicio en última página), y Buddy System.

#### Fragmentación Externa

La fragmentación externa es memoria desperdiciada ENTRE regiones asignadas. Hay suficiente memoria libre total, pero no es contigua. Por ejemplo, si tenés memoria total de 64 MiB con 16 MiB libres, pero en distintos bloques no contiguos, no podés asignar un proceso de 10 MiB a pesar de tener espacio suficiente.

Las causas son la asignación y liberación de bloques de tamaño variable, los procesos que terminan dejan huecos, y con el tiempo la memoria se "perfora". Ocurre en particiones dinámicas, segmentación, y cualquier esquema de asignación variable. La solución es la compactación (mover procesos para consolidar memoria libre), pero es costosa.  

\begin{highlight}
La fragmentación externa es uno de los problemas más insidiosos en gestión de memoria. Puede hacer que un sistema con 50\% de memoria libre sea incapaz de asignar nuevos procesos. La paginación fue inventada específicamente para resolver este problema.
\end{highlight}

## Técnicas de Asignación Contigua

Las primeras técnicas de gestión de memoria asignaban espacios contiguos a cada proceso. Aunque simples, estas técnicas nos enseñan lecciones importantes sobre los trade-offs en diseño de sistemas.

### Particiones Fijas

En los primeros sistemas multiprogramados, la memoria se dividía en particiones de tamaño fijo al inicio del sistema. Esta decisión de diseño priorizaba la simplicidad sobre la eficiencia.
Imaginá un esquema de memoria con particiones fijas donde después del SO hay varias particiones de diferentes tamaños: 128 KiB, 256 KiB, 512 KiB, y 64 KiB, ocupando todo el espacio hasta 1024 KiB.  

El mecanismo de asignación es extremadamente simple: cuando llega un proceso, se busca una partición libre que lo contenga, el proceso ocupa toda la partición aunque no la use completamente, y al terminar, la partición queda libre para el próximo proceso.
Las ventajas son tentadoras: implementación extremadamente simple, asignación y liberación en O(1), sin fragmentación externa, y protección fácil porque cada partición tiene base y límite fijos. Sin embargo, las desventajas son severas: fragmentación interna que puede ser brutal, número limitado de procesos fijado al inicio del sistema, procesos grandes pueden simplemente no caber, y memoria desaprovechada si hay particiones vacías.
\begin{example}
El problema crítico es evidente con un ejemplo: un proceso de 50 KiB en una partición de 256 KiB desperdicia 206 KiB (lo que representa un 80%). En un sistema real, este desperdicio es inaceptable.
\end{example}

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-07/04.png}
\end{center}

### Particiones Dinámicas

Para resolver la fragmentación interna de las particiones fijas, se desarrollaron las particiones dinámicas: cada proceso recibe exactamente la cantidad de memoria que necesita. Esto parece la solución perfecta, pero como veremos, introduce nuevos problemas.  

La evolución de la memoria con particiones dinámicas muestra el problema claramente. Al inicio, el sistema arranca con todo el espacio libre. Cuando llega el primer proceso (P1 de 100 KiB), se le asigna exactamente ese espacio. Luego llegan P2 (200 KiB) y P3 (150 KiB), ocupando sus espacios precisos. Hasta acá todo perfecto: no hay desperdicio.  

El problema aparece cuando P1 termina. Queda un hueco de 100 KiB entre el SO y P2. Luego P2 termina, dejando otro hueco de 200 KiB. Ahora tenemos memoria libre total de 810 KiB, pero fragmentada en tres bloques separados. Un proceso que necesite 400 KiB no puede ejecutarse, a pesar de que hay 810 KiB libres en total. Esta es la esencia de la fragmentación externa.  
Las ventajas iniciales son claras: sin fragmentación interna, número dinámico de procesos, y uso eficiente de memoria al principio. Pero las desventajas son significativas: fragmentación externa severa con el tiempo, algoritmo de asignación más complejo, requiere compactación periódica que es costosa, y estructuras de datos para rastrear bloques libres.
\\vfill

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-07/02.jpg}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Debido a la fragmentación externa, existe la posibilidad de no poder alocar un proceso aún contando con memoria disponible.
}
\end{center}

\begin{warning}
La fragmentación externa es progresiva: empeora con el tiempo de ejecución del sistema. Un sistema que funciona bien al arrancar puede volverse ineficiente después de horas de operación.
\end{warning}

### Algoritmos de Asignación

Cuando llega un proceso que necesita memoria, el SO debe decidir en qué bloque libre ubicarlo. Esta decisión aparentemente simple tiene implicaciones profundas en el rendimiento del sistema. Existen varios algoritmos, cada uno con diferentes trade-offs.

#### First Fit (Primer Ajuste)

El algoritmo busca secuencialmente en la lista de bloques libres y asigna el primer bloque suficientemente grande. Por ejemplo, con bloques libres de [50 KiB] [200 KiB] [80 KiB] [300 KiB], si un proceso necesita 70 KiB, First Fit asigna el bloque de 200 KiB, dejando [50 KiB] [70 KiB usado | 130 KiB libre] [80 KiB] [300 KiB].  
La complejidad es O(n) en el peor caso, pero rápido en promedio. Tiende a dejar bloques pequeños al inicio de la lista, lo que puede ser problemático con el tiempo.

```
Bloques libres: [50 KiB] [200 KiB] [80 KiB] [300 KiB]
Proceso necesita: 70 KiB

First Fit asigna: Bloque de 200 KiB (primero que encontró >= 70 KiB)
Resultado: [50 KiB] [70 KiB usado|130 KiB libre] [80 KiB] [300 KiB]
```

#### Best Fit (Mejor Ajuste)

Este algoritmo busca en toda la lista de bloques libres y asigna el bloque más pequeño que sea suficiente. Con los mismos bloques del ejemplo anterior y un proceso de 70 KiB, Best Fit asigna el bloque de 80 KiB, dejando [50 KiB] [200 KiB] [70 KiB usado | 10 KiB libre] [300 KiB].  

La complejidad es O(n) siempre porque debe recorrer toda la lista. Minimiza el desperdicio por asignación individual, pero genera muchos bloques muy pequeños que terminan siendo inútiles.
```
Bloques libres: [50 KiB] [200 KiB] [80 KiB] [300 KiB]
Proceso necesita: 70 KiB

Best Fit asigna: Bloque de 80 KiB (el menor >= 70 KiB)
Resultado: [50 KiB] [200 KiB] [70 KiB usado|10 KiB libre] [300 KiB]
```

#### Worst Fit (Peor Ajuste)

Contraintuitivamente, este algoritmo busca en toda la lista y asigna el bloque más grande disponible. En nuestro ejemplo, Worst Fit asignaría el bloque de 300 KiB, dejando [50 KiB] [200 KiB] [80 KiB] [70 KiB usado | 230 KiB libre].  
La complejidad es O(n) siempre, pero deja bloques grandes que son más útiles que los pequeños. En simulaciones, suele tener mejor rendimiento que Best Fit.
```
Bloques libres: [50 KiB] [200 KiB] [80 KiB] [300 KiB]
Proceso necesita: 70 KiB

Worst Fit asigna: Bloque de 300 KiB
Resultado: [50 KiB] [200 KiB] [80 KiB] [70 KiB usado|230 KiB libre]
```

#### Next Fit (Siguiente Ajuste)

Similar a First Fit, pero continúa la búsqueda desde donde terminó la última asignación en forma circular. Tiene complejidad O(n) en el peor caso, distribuye asignaciones más uniformemente, y evita la concentración de bloques pequeños al inicio de la memoria.
\begin{theory}
¿Por qué Worst Fit puede ser más eficiente que Best Fit? Best Fit genera muchos bloques MUY pequeños (1-5 KiB) que son prácticamente inútiles. Worst Fit deja bloques grandes (30-50 KiB) que tienen más probabilidad de ser utilizables para procesos futuros. Esto demuestra que la intuición puede fallar en sistemas complejos.
\end{theory}
En la práctica, los sistemas modernos usan variantes de First Fit con optimizaciones como listas ordenadas y segregación por tamaño. La elección del algoritmo depende del patrón de uso esperado del sistema.


## Paginación Simple

La idea central de la paginación es dividir el espacio de direcciones lógicas y la memoria física en bloques de tamaño fijo llamados páginas y marcos (frames). Una página es un bloque de memoria lógica, típicamente de 4 KiB. Un marco es un bloque de memoria física del mismo tamaño que una página. La tabla de páginas es la estructura que mapea páginas a marcos.  

La ventaja fundamental es que las páginas de un proceso NO necesitan estar contiguas en memoria física. Esto resuelve completamente el problema de fragmentación externa.
Imaginá el espacio lógico de un proceso con páginas 0, 1, 2 y 3. En memoria física, la página 0 puede estar en el marco 5, la página 1 en el marco 2, la página 2 en el marco 7, y la página 3 en el marco 4. No importa que estén dispersas: la MMU traduce cada acceso correctamente.  

Las ventajas de la paginación son significativas: elimina fragmentación externa completamente, la asignación y liberación es simple (solo buscar marcos libres), permite compartir páginas entre procesos, facilita la implementación de memoria virtual, y ofrece protección a nivel de página. Las desventajas incluyen fragmentación interna en la última página, overhead de la tabla de páginas, cada acceso a memoria requiere traducción, y complejidad adicional en hardware.
\begin{highlight}
La paginación es el fundamento de prácticamente todos los sistemas operativos modernos. Aunque tiene costos, los beneficios en términos de flexibilidad y protección son indispensables.
\end{highlight}

\begin{center}
\includegraphics[width=0.6\linewidth,keepaspectratio]{src/images/capitulo-07/03.png}
\end{center}

### Formato de Dirección Lógica

Una dirección lógica en paginación se divide en dos campos: número de página y offset dentro de la página. Si el tamaño de página es $2^d bytes$ y el espacio lógico es $2^m bytes$, entonces una dirección lógica tiene $m bits$ divididos en: $p = m - d bits$ para número de página, y $d bits$ para offset dentro de la página.

Veamos un ejemplo concreto. Con un espacio de 64 KiB con páginas de 4 KiB, tenemos espacio lógico de $2^{16} bytes$ (64 KiB) requiriendo 16 bits de dirección.
- Espacio lógico: $2^{16}$ bytes (64 KiB) -> 16 bits de dirección
- Tamaño de página: $2^{12}$ bytes (4 KiB) -> 12 bits de offset
- Bits para número de página: 16 - 12 = 4 bits
- Número de páginas: $2^4$ = 16 páginas  

El formato de dirección de 16 bits se divide en 4 bits para el número de página (permitiendo páginas 0-15) y 12 bits para el offset (permitiendo offset 0-4095).

```
Dirección lógica de 16 bits:
┌────────┬────────────────────┐
│ 4 bits │     12 bits        │
│  (p)   │      (d)           │
└────────┴────────────────────┘
Rango páginas: 0-15
Rango offset: 0-4095
```

\begin{excerpt}
\emph{Formato de Dirección Lógica:}
Si el tamaño de página es $2^d$ bytes y el espacio lógico es $2^m$ bytes, entonces una dirección lógica tiene m bits divididos en: p = m - d bits para número de página, d bits para offset dentro de la página.
\end{excerpt}

### Traducción de Direcciones

El proceso de traducción usa la tabla de páginas del proceso. El algoritmo es directo: extraés el número de página p de los bits más significativos, extraés el offset d de los bits menos significativos, buscás en la tabla de páginas $marco = tabla\_paginas[p]$, y calculás la dirección física como $DF = marco * tamaño\_pagina + d$.  

Veamos un ejemplo numérico completo. Con tamaño de página de 1 KiB ($1024 bytes = 2^{10}$), espacio lógico de 8 KiB ($8192 bytes = 2^{13}$), tenemos 13 bits de dirección total, 3 bits de página (8 páginas), y 10 bits de offset (1024 posiciones).  
```
Configuración:
- Tamaño de página: 1 KiB (1024 bytes = 2^10)
- Espacio lógico: 8 KiB (8192 bytes = 2^13)
- Bits de dirección: 13 bits
- Bits de página: 13 - 10 = 3 bits (8 páginas)
- Bits de offset: 10 bits (1024 posiciones)
```

Supongamos una tabla donde la página 0 mapea al marco 5, la página 1 al marco 2, la página 2 al marco 7, y la página 3 al marco 0.
```
┌────────┬────────┐
│ Página │ Marco  │
├────────┼────────┤
│   0    │   5    │
│   1    │   2    │
│   2    │   7    │
│   3    │   0    │
└────────┴────────┘
```

Para traducir la dirección lógica 1300, primero la convertimos a binario: 1300₁₀ = 10100010100₂. Separamos en página (001 = 1) y offset (0100010100 = 276). 
```
┌───────┬──────────────┐
│ 001   │ 0100010100   │
│ (p=1) │  (d=276)     │
└───────┴──────────────┘
```

Consultar tabla: $tabla[1] = marco 2$  

Finalmente calculamos la dirección física:
$$
DF = 2 * 1024 + 276 = 2048 + 276 = 2324
$$

\begin{example}
El proceso de traducción es completamente transparente para el proceso. El programa genera la dirección lógica 1300, pero el hardware accede a la dirección física 2324. El proceso nunca sabe dónde está realmente en memoria.
\end{example}

```
CPU genera DL=1300
       ↓
┌──────────────┐
│ p=1 │ d=276  │
└──────────────┘
       ↓
 [Tabla de Páginas]
  p=1 -> marco=2
       ↓
DF = 2*1024 + 276 = 2324
       ↓
   Acceso a RAM[2324]
```

### Tabla de Páginas

La tabla de páginas es una estructura de datos mantenida por el SO que mapea números de página lógica a números de marco físico. Cada proceso tiene su propia tabla de páginas independiente.  
Cada entrada de la tabla (PTE - Page Table Entry) contiene más que solo el número de marco. Incluye el marco (número de marco físico donde está la página), el bit V (Valid, indica si la página está en memoria o en disco), el bit R (Referenced, para algoritmos de reemplazo), el bit W (Written/Dirty, indica si la página fue modificada), el bit X (Execute, permiso de ejecución), y otros campos para protección, compartición, etc.

```
┌────────────┬─────┬─────┬─────┬─────┬──────────┐
│ Marco (n)  │  V  │  R  │  W  │  X  │  Otros   │
└────────────┴─────┴─────┴─────┴─────┴──────────┘
    20 bits   1 bit 1 bit 1 bit 1 bit   8 bits
```

Un aspecto crucial es la ubicación: la tabla de páginas está en memoria RAM, no en registros del CPU (son demasiadas entradas). El SO mantiene un registro especial llamado PTBR (Page Table Base Register) que apunta al inicio de la tabla. En cada context switch, el SO actualiza el PTBR con la tabla del nuevo proceso.
\begin{warning}
Esto introduce un problema de rendimiento: cada acceso a memoria requiere 2 accesos reales. Primero hay que leer la entrada de tabla de páginas (en RAM), luego leer el dato solicitado (en RAM). Esto duplica el tiempo de acceso a memoria. La solución es el TLB, una caché de traducciones.
\end{warning}

### Fragmentación Interna en Paginación

Aunque la paginación elimina fragmentación externa, tiene fragmentación interna en la última página de cada proceso. Si un proceso necesita 13.5 KiB con páginas de 4 KiB, se le asignan 4 páginas (16 KiB), desperdiciando 2.5 KiB (15.6\% de fragmentación interna).  

```
Proceso necesita: 13.5 KiB
Tamaño de página: 4 KiB
Páginas asignadas: 4 páginas (16 KiB)
Fragmentación interna: 16 - 13.5 = 2.5 KiB (15.6%)

┌──────────┐
│ Página 0 │ 4 KiB (completa)
├──────────┤
│ Página 1 │ 4 KiB (completa)
├──────────┤
│ Página 2 │ 4 KiB (completa)
├──────────┤
│ Página 3 │ 1.5 KiB usado
│  ········│ 2.5 KiB desperdiciado
└──────────┘
```

La fragmentación promedio es de 0.5 páginas por proceso. Si la página es de 4 KiB, el desperdicio promedio es 2 KiB por proceso. Con 100 procesos, se desperdician 200 KiB. Existe un trade-off: páginas más pequeñas reducen fragmentación interna pero aumentan el overhead de las tablas.

## Segmentación

La paginación resuelve problemas técnicos brillantemente, pero no refleja la estructura lógica del programa. La segmentación aborda este aspecto desde una perspectiva completamente diferente.

### Concepto y Motivación

Desde la perspectiva del programador, un programa NO es un arreglo lineal de bytes, sino una colección de unidades lógicas: segmento de código (instrucciones), segmento de datos globales, segmento de heap (memoria dinámica), segmento de stack (variables locales), y segmentos de librerías compartidas.  

La segmentación divide el espacio de direcciones en segmentos de tamaño variable, donde cada segmento representa una unidad lógica del programa. La diferencia clave con paginación es fundamental: la paginación divide por tamaño fijo usando un criterio técnico (hardware), mientras que la segmentación divide por tamaño variable usando un criterio lógico (programador). La paginación es invisible al programador, la segmentación es visible. La paginación genera fragmentación interna, la segmentación genera fragmentación externa. La protección en paginación es por página, en segmentación es por segmento (más natural). La compartición en paginación es complicada, en segmentación es natural.  

Un proceso puede tener un segmento 0 de código (2000 bytes) con base en 1000 y límite 2000, un segmento 1 de datos (500 bytes) con base en 5000 y límite 500, y un segmento 2 de stack (1000 bytes) con base en 8000 y límite 1000. Cada segmento puede estar en cualquier parte de la memoria física.
```
Espacio lógico del proceso:
┌──────────────────┐ Segmento 0
│      Código      │ Base: 1000, Límite: 2000
│   (2000 bytes)   │
├──────────────────┤ Segmento 1
│      Datos       │ Base: 5000, Límite: 500
│   (500 bytes)    │
├──────────────────┤ Segmento 2
│      Stack       │ Base: 8000, Límite: 1000
│   (1000 bytes)   │
└──────────────────┘

Dirección lógica: (segmento, offset)
Ejemplo: (1, 250) -> segmento 1, offset 250
```

*Diferencia clave con paginación:*

| Aspecto | Paginación | Segmentación |
|---------|-----------|--------------|
| División | Tamaño fijo (4 KiB) | Tamaño variable |
| Criterio | Técnico (hardware) | Lógico (programador) |
| Visible al programador | No | Sí |
| Fragmentación | Interna | Externa |
| Protección | Por página | Por segmento (más natural) |
| Compartición | Complicada | Natural |


### Formato de Dirección Lógica en Segmentación

Una dirección lógica es un par (s, d) donde s es el número de segmento y d es el desplazamiento dentro del segmento. La traducción sigue estos pasos: extraés s y d de la dirección lógica, consultás la tabla de segmentos $entrada = tabla\_ segmentos[s]$, verificás si $d >= entrada.limite$ -> `Segmentation Fault`, y calculás $DF = entrada.base + d$.  

Con una tabla donde el segmento 0 tiene base 1000 y límite 2000, el segmento 1 tiene base 5000 y límite 500, y el segmento 2 tiene base 8000 y límite 1000, la dirección (1, 250) se traduce así: $s=1, d=250, base=5000, límite=500$. Como $250 < 500$ es válido, calculamos $DF = 5000 + 250 = 5250$.
Si intentamos traducir (1, 600), como 600 no es menor que 500, el hardware genera un `TRAP`(Segmentation Fault).

```
Tabla de segmentos:
┌─────────┬──────┬────────┐
│ Segmento│ Base │ Límite │
├─────────┼──────┼────────┤
│    0    │ 1000 │  2000  │
│    1    │ 5000 │   500  │
│    2    │ 8000 │  1000  │
└─────────┴──────┴────────┘

Traducir: (1, 250)
1. s=1, d=250
2. Base=5000, Límite=500
3. ¿250 < 500? Sí -> válido
4. DF = 5000 + 250 = 5250

Traducir: (1, 600)
1. s=1, d=600
2. Base=5000, Límite=500
3. ¿600 < 500? No -> TRAP (Segmentation Fault)
```

### Ventajas de Segmentación

La segmentación refleja la estructura lógica del programa naturalmente, ofrece protección natural (cada segmento tiene sus propios permisos), facilita la compartición (código compartido = mismo segmento), permite crecimiento dinámico de segmentos (heap, stack), y facilita modularidad y librerías compartidas.
\begin{example}
La compartición de código es elegante en segmentación. Si los procesos A y B ejecutan el mismo programa, ambos pueden apuntar al mismo segmento 0 de código (read-only y compartido), mientras mantienen sus propios segmentos 1 de datos privados. Esto es conceptualmente simple y eficiente.
\end{example}
Las desventajas son que vuelve a aparecer la fragmentación externa (como en particiones dinámicas), la complejidad de asignación requiere algoritmos First/Best/Worst Fit, eventualmente requiere compactación, y la tabla de segmentos es más compleja que la tabla de páginas.

```
Proceso A y B ejecutan el mismo programa:
┌─────────────────┐
│ Seg 0: Código   │ ← Ambos procesos apuntan aquí
│   (compartido)  │    (read-only)
└─────────────────┘

Proceso A:                Proceso B:
┌──────────────┐          ┌──────────────┐
│ Seg 1: Datos │          │ Seg 1: Datos │
│   (privado)  │          │   (privado)  │
└──────────────┘          └──────────────┘
```

### Segmentación con Paginación

Los sistemas modernos combinan ambas técnicas para obtener ventajas de cada una. En la segmentación paginada, cada segmento se divide en páginas. El espacio lógico está segmentado (perspectiva lógica), pero cada segmento se implementa con paginación (evitando fragmentación externa).  

El proceso de traducción ocurre en dos niveles. Una dirección lógica es (s, p, d) donde s es el número de segmento, p es el número de página dentro del segmento, y d es el offset dentro de la página. Primero consultás la tabla de segmentos para obtener la tabla de páginas del segmento, luego consultás la tabla de páginas del segmento para obtener el marco, y finalmente calculás la dirección física como marco * tamaño_página + d.  
```
Dirección lógica: (s, p, d)
- s = número de segmento
- p = número de página dentro del segmento
- d = offset dentro de la página

1. Consultar tabla de segmentos -> obtener tabla de páginas del segmento
2. Consultar tabla de páginas del segmento -> obtener marco
3. Calcular dirección física: marco * tamaño_página + d
```

Intel x86 (arquitectura IA-32) implementa este esquema. Una dirección tiene un selector de segmento de 16 bits que incluye un índice en la GDT (Global Descriptor Table) y un offset. El descriptor de segmento en GDT/LDT proporciona la base del segmento. Esto se combina con el offset que contiene el número de página y el offset dentro de la página. La tabla de páginas del segmento mapea a marcos físicos.  
```
┌──────────────────────────────┐
│  Selector de Segmento (16b)  │ Dirección lógica
├─────────────┬────────────────┤
│ Índice GDT  │    Offset      │
└─────────────┴────────────────┘
       ↓              ↓
   [GDT/LDT]      ┌───────┬────┐
   Descriptor  ->  │ Página│ Off│
   de Segmento    └───────┴────┘
       ↓              ↓
   Base + Límite  [Tabla Páginas]
       ↓              ↓
   Dirección      Marco físico
   lineal             ↓
                  Dirección física
```

Las ventajas del esquema híbrido son claras: combina la protección y compartición natural de segmentación con la ausencia de fragmentación externa de paginación. Los segmentos pueden crecer dinámicamente agregando páginas, y el uso de memoria es mejor que segmentación pura.

## Técnicas Avanzadas

### Buddy System

El Buddy System es un algoritmo de asignación que busca balancear la velocidad de asignación con la fragmentación. Su elegancia está en su simplicidad.  

El sistema funciona así: la memoria total es una potencia de 2 (por ejemplo, 256 KiB). Cuando se solicita memoria, se busca el bloque más pequeño (potencia de 2) que lo contenga. Si no existe ese tamaño, se divide un bloque mayor recursivamente (splitting). Al liberar, se intenta fusionar con el buddy si también está libre (coalescing).  

La regla del buddy es matemática, dos bloques de tamanio $2^k$ en direcciones addr1 y addr2 son buddies si:
$$
addr1 XOR addr2 == 2^k
$$

Veamos la operación completa.  
```
Estado inicial: 256 KiB libre
┌─────────────────────────────────┐
│           256 KiB                │
└─────────────────────────────────┘

Solicitud: 40 KiB
-> Necesita bloque de 64 KiB (2^6)
-> Dividir 256 -> 128 + 128
-> Dividir 128 -> 64 + 64
-> Asignar primer 64 KiB

Estado después de asignar 40 KiB:
┌───────────┬───────────┬─────────────────┐
│ 64 (usado)│ 64 (libre)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Solicitud: 35 KiB
-> Necesita bloque de 64 KiB
-> Ya hay uno libre, asignar

┌───────────┬───────────┬─────────────────┐
│ 64 (usado)│ 64 (usado)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Liberar primer bloque (64 KiB):
-> Su buddy (segundo 64 KiB) está ocupado
-> No se puede fusionar

┌───────────┬───────────┬─────────────────┐
│ 64 (libre)│ 64 (usado)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Liberar segundo bloque (64 KiB):
-> Su buddy (primer 64 KiB) está libre
-> Fusionar en 128 KiB
-> El nuevo 128 tiene buddy libre (otro 128)
-> Fusionar en 256 KiB

┌─────────────────────────────────┐
│           256 KiB (libre)        │
└─────────────────────────────────┘
```

Las ventajas son asignación y liberación rápidas en O(log n), coalescing automático sin escanear toda la memoria, reduce fragmentación externa comparado con particiones dinámicas, e implementación simple con listas por tamaño. Las desventajas son la fragmentación interna (siempre se asigna potencia de 2), por ejemplo un proceso de 65 KiB recibe 128 KiB desperdiciando 63 KiB, y no es tan eficiente como paginación pura.
\begin{infobox}
Linux usa una variante del Buddy System para asignar páginas físicas en el kernel, con bloques de hasta orden 11 (es decir, $2^{11} paginas$). Es un buen balance entre eficiencia y complejidad.
\end{infobox}

### Paginación Multinivel

Cuando el espacio de direcciones es muy grande, la tabla de páginas se vuelve enorme. Este es un problema serio en sistemas modernos.  

En un sistema de 32 bits con páginas de 4 KiB, hay $2^{32} = 4 GiB$ de direcciones posibles, lo que significa $2^{32} / 2^{12} = 2^{20}$ 1 millón de páginas posibles. Si cada entrada ocupa 4 bytes, el tamaño de la tabla es 4 MiB por proceso. Con 100 procesos, necesitaríamos 400 MiB solo en tablas de páginas, lo cual es inaceptable.  

La solución es paginar la tabla de páginas misma, creando una jerarquía de múltiples niveles.

#### Paginación de Dos Niveles

En paginación de dos niveles, la tabla de páginas se divide en páginas. Se mantiene un directorio de páginas que apunta a las tablas de páginas de segundo nivel.  

El formato de dirección lógica se divide en tres partes: directorio (p1), página (p2), y offset (d). La traducción ocurre así: usás p1 para indexar el directorio de páginas y obtener la tabla de nivel 2, usás p2 para indexar la tabla de nivel 2 y obtener el marco, y usás d como offset dentro del marco.
La ventaja es enorme: si un proceso no usa ciertas regiones de memoria, las tablas de nivel 2 correspondientes NO se crean, ahorrando memoria significativamente.

```
┌──────────────┬──────────────┬──────────────┐
│  Directorio  │    Página    │    Offset    │
│     (p1)     │     (p2)     │     (d)      │
└──────────────┴──────────────┴──────────────┘
```

En un sistema de 32 bits con páginas de 4 KiB, podés usar 10 bits para directorio (1024 entradas), 10 bits para página (1024 entradas por tabla nivel 2), y 12 bits para offset (4096 bytes). Si un proceso usa solo 4 MiB, requiere 1 entrada en directorio y 1 tabla de nivel 2 (1024 entradas), totalizando $(1024 + 1024) * 4 bytes = 8 KiB$, versus 4 MiB en tabla plana.

```
Dirección de 32 bits:
┌────────┬────────┬──────────────┐
│ 10 bits│ 10 bits│   12 bits    │
│  (p1)  │  (p2)  │     (d)      │
└────────┴────────┴──────────────┘

Directorio: 2^10 = 1024 entradas
Cada tabla nivel 2: 2^10 = 1024 entradas
Offset: 2^12 = 4096 bytes (4 KiB)
```

#### Paginación de Tres Niveles

Para espacios de direcciones de 64 bits, se requieren más niveles. La dirección se divide en p1, p2, p3, y offset.  
```
┌────────┬────────┬────────┬──────────────┐
│  (p1)  │  (p2)  │  (p3)  │     (d)      │
└────────┴────────┴────────┴──────────────┘
```
Por ejemplo, x86-64 con páginas de 4 KiB usa direcciones de 48 bits (no se usan los 64 completos), divididas en 9 bits para cada uno de cuatro niveles (PML4, PDPT, PD, PT), más 12 bits de offset. Esto crea cuatro niveles de traducción: Page Map Level 4 (PML4), Page Directory Pointer Table (PDPT), Page Directory (PD), y Page Table (PT).

```
Dirección de 48 bits (no se usan los 64 completos):
┌────────┬────────┬────────┬────────┬──────────────┐
│ 9 bits │ 9 bits │ 9 bits │ 9 bits │   12 bits    │
│  PML4  │  PDPT  │   PD   │   PT   │   Offset     │
└────────┴────────┴────────┴────────┴──────────────┘

4 niveles de traducción:
1. Page Map Level 4 (PML4)
2. Page Directory Pointer Table (PDPT)
3. Page Directory (PD)
4. Page Table (PT)
```
\begin{warning}
El costo de traducción es significativo: con 3 niveles se necesitan 4 accesos a memoria (3 niveles más el dato). Sin TLB esto sería devastador para el rendimiento. Un hit rate del TLB del 99\% es esencial para mantener el sistema usable.
\end{warning}

### Tabla de Páginas Invertida

Un enfoque radicalmente diferente: en lugar de una tabla por proceso, una tabla global única para todo el sistema. La tabla de páginas invertida tiene una entrada por cada marco físico (no por página lógica). Cada entrada indica qué proceso y qué página está en ese marco.  

La estructura tiene una entrada por marco físico, conteniendo el PID del proceso dueño, el número de página lógica, y flags de protección y estado. La traducción requiere extraer página p y offset d de la dirección lógica, buscar en la tabla invertida la entrada donde `(PID == actual) AND (Página == p)`, usar el índice de esa entrada como el marco, y calcular `DF = marco * tamaño_página + d`.

```
Tabla Invertida (una para todo el sistema):
┌───────┬──────────┬─────────┬──────────┐
│ Marco │ PID      │ Página  │ Flags    │
├───────┼──────────┼─────────┼──────────┤
│   0   │   42     │   7     │ R-X      │
│   1   │  103     │   2     │ RW-      │
│   2   │   42     │   15    │ RW-      │
│  ...  │  ...     │  ...    │ ...      │
│   n   │  256     │   0     │ R--      │
└───────┴──────────┴─────────┴──────────┘
```
El problema crítico es que la búsqueda es O(n) donde n es la cantidad de marcos. Cada acceso a memoria requiere escanear toda la tabla, lo cual es INACEPTABLE sin optimización. La solución es usar una tabla hash para acelerar la búsqueda:  
```
Hash(PID, página) -> índice en tabla hash -> cadena de colisiones -> entrada
```
Las ventajas son que el tamaño de tabla es proporcional a memoria física (no a lógica). Un sistema con 4 GiB de RAM y páginas de 4 KiB tiene 1M marcos, entonces 1M entradas, versus potencialmente millones por proceso. Es un ahorro masivo en sistemas con muchos procesos. Las desventajas son que la búsqueda es más lenta incluso con hash, la compartición de páginas es complicada, y no es totalmente compatible con memoria virtual tradicional.  

Este esquema se usó en PowerPC, IA-64 (Itanium), y algunas versiones de AIX.

## Compactación y Defragmentación

La compactación es el proceso de mover procesos en memoria para consolidar los espacios libres. Es una solución directa a la fragmentación externa, pero con costos significativos.  

El proceso reorganiza la memoria moviendo procesos activos para eliminar fragmentación externa, creando un único bloque contiguo de memoria libre. Antes de compactación, la memoria puede estar fragmentada con procesos y huecos libres intercalados. Después de compactación, todos los procesos están juntos y hay un único bloque libre grande al final.  

El algoritmo implica identificar todos los bloques libres, mover procesos hacia direcciones bajas, actualizar tablas de asignación, y actualizar todas las referencias (registros, punteros, tablas de páginas).

```
Antes de compactación:
┌──────┐ 0 KiB
│  SO  │
├──────┤ 64 KiB
│  P1  │ (50 KiB)
├──────┤ 114 KiB
│ Libre│ (30 KiB)
├──────┤ 144 KiB
│  P2  │ (80 KiB)
├──────┤ 224 KiB
│ Libre│ (40 KiB)
├──────┤ 264 KiB
│  P3  │ (60 KiB)
├──────┤ 324 KiB
│ Libre│ (700 KiB)
└──────┘ 1024 KiB

Total libre: 770 KiB (fragmentado)

Después de compactación:
┌──────┐ 0 KiB
│  SO  │
├──────┤ 64 KiB
│  P1  │ (50 KiB)
├──────┤ 114 KiB
│  P2  │ (80 KiB)
├──────┤ 194 KiB
│  P3  │ (60 KiB)
├──────┤ 254 KiB
│ Libre│ (770 KiB)
└──────┘ 1024 KiB

Total libre: 770 KiB (contiguo)
```

Los costos son considerables: copiar todos los procesos en memoria es muy lento, hay que detener la ejecución durante la compactación, actualizar estructuras del SO, y en un sistema con 1 GiB ocupado, esto puede tomar varios segundos.
\begin{warning}
La compactación solo es factible si se usa binding en tiempo de ejecución. Con binding en compilación o carga, es imposible mover procesos. Con registros base/límite o paginación, solo hay que actualizar los registros y la MMU hace transparente el movimiento para el proceso.
\end{warning}

Las estrategias varían: compactación completa mueve todos los procesos al inicio dejando todo el espacio libre al final, compactación parcial solo elimina huecos más pequeños que cierto umbral, y compactación selectiva solo mueve procesos que no están ejecutando activamente.  
En paginación, no se necesita compactación tradicional, pero ocasionalmente se hace "defragmentación" moviendo páginas para mejorar localidad, aunque esto es raro en la práctica.

## Protección y Compartición

### Mecanismos de Protección

Los sistemas de gestión de memoria incluyen mecanismos de protección para evitar que un proceso acceda memoria de otro, evitar que un proceso acceda memoria del SO, y controlar operaciones permitidas (lectura, escritura, ejecución).  
Los bits de protección en la tabla de páginas incluyen `R` (Read, página legible), `W` (Write, página escribible), y `X` (Execute, página ejecutable). Las combinaciones típicas son `R--` para solo lectura (constantes, código compartido), `RW-` para lectura/escritura (datos, heap, stack), `R-X` para solo lectura y ejecución (código), y `RWX` que es peligroso porque permite ataques de data execution.

```
┌────────┬────┬────┬────┬────────┐
│ Marco  │ R  │ W  │ X  │ Otros  │
└────────┴────┴────┴────┴────────┘

R (Read):    Página legible
W (Write):   Página escribible
X (Execute): Página ejecutable

Combinaciones típicas:
R--: Solo lectura (constantes, código compartido)
RW-: Lectura/escritura (datos, heap, stack)
R-X: Solo lectura y ejecución (código)
RWX: Peligroso (permite data execution attacks)
```

*Verificación por hardware:* Cuando el CPU intenta acceder a una página, la MMU verifica automáticamente: ¿la página es válida (bit V=1)? Si no, genera Page Fault. ¿El acceso es de lectura y bit R=1? Si no, genera Protection Fault. ¿El acceso es de escritura y bit W=1? Si no, genera Protection Fault. ¿El acceso es de ejecución y bit X=1? Si no, genera Protection Fault. Si todo está bien, permite el acceso.

```
1. ¿La página es válida (bit V=1)?
   NO -> Page Fault (TRAP al SO)
   
2. ¿El acceso es de lectura y bit R=1?
   NO -> Protection Fault (TRAP al SO)
   
3. ¿El acceso es de escritura y bit W=1?
   NO -> Protection Fault (TRAP al SO)
   
4. ¿El acceso es de ejecución y bit X=1?
   NO -> Protection Fault (TRAP al SO)
   
5. Todo OK -> Permitir acceso
```

\begin{highlight}
El bit NX (No-eXecute) es fundamental para seguridad moderna. Previene ataques de buffer overflow porque el stack y heap NO deben ser ejecutables. Si un atacante inyecta código en el stack, el CPU rechaza ejecutarlo automáticamente. Este mecanismo es una defensa crítica en sistemas actuales.
\end{highlight}

### Compartición de Memoria

Los sistemas modernos permiten que múltiples procesos compartan páginas de memoria para código compartido (múltiples procesos ejecutando el mismo programa), librerías compartidas (libc.so, libpthread.so, etc.), y comunicación entre procesos mediante segmentos de memoria compartida.  
En código compartido, dos procesos ejecutando el mismo programa pueden apuntar al mismo marco físico para su segmento de código (con permisos read-only), mientras mantienen datos y stack privados en marcos separados. Si 100 procesos ejecutan bash (1 MiB de código), sin compartición se necesitarían 100 MiB de código en RAM. Con compartición, se necesita 1 MiB de código más 100 MiB de datos privados, ahorrando 99 MiB.

```
Proceso A (PID=100):          Proceso B (PID=200):
Tabla de páginas:             Tabla de páginas:
┌────────┬────────┐           ┌────────┬────────┐
│ Pág 0  │ Marco 5│ ← Código │ Pág 0  │ Marco 5│ Mismo marco
│ Pág 1  │ Marco 8│ ← Datos  │ Pág 1  │ Marco 9│ Datos privados
│ Pág 2  │ Marco 7│ ← Stack  │ Pág 2  │ Marco 6│ Stack privado
└────────┴────────┘           └────────┴────────┘
```

Los requisitos para compartir código son que el código debe ser reentrante (no se modifica a sí mismo), las páginas compartidas deben tener permisos R-X (no escribibles), y cada proceso tiene sus propios datos y stack privados.

## Código en C

### Conceptos Básicos de Memoria y Punteros (Bonus)

Los punteros son la herramienta fundamental para trabajar con memoria en C.

```c
#include <stdio.h>

int main() {
    int x = 42;          // Variable en stack
    int *ptr = &x;       // ptr apunta a x
    
    printf("Valor de x: %d\n", x);           // 42
    printf("Dirección de x: %p\n", &x);      // Dirección lógica
    printf("Valor de ptr: %p\n", ptr);       // Igual que &x
    printf("Valor apuntado: %d\n", *ptr);    // 42
    
    *ptr = 100;          // Modificar x a través del puntero
    printf("Nuevo valor de x: %d\n", x);     // 100
    
    return 0;
}
```

*Salida típica:*
```
Valor de x: 42
Dirección de x: 0x7ffd8c5e3a9c
Valor de ptr: 0x7ffd8c5e3a9c
Valor apuntado: 42
Nuevo valor de x: 100
```

La dirección mostrada es una dirección LÓGICA. La MMU la traduce a una dirección física que el programa nunca ve. El programa opera completamente en su espacio virtual.

### Aritmética de Punteros

```c
#include <stdio.h>

int main() {
    int arr[] = {10, 20, 30, 40, 50};
    int *ptr = arr;  // ptr apunta al primer elemento
    
    printf("ptr apunta a: %p, valor: %d\n", ptr, *ptr);
    // ptr = dirección base, *ptr = 10
    
    ptr++;  // Avanza sizeof(int) bytes
    printf("Después de ptr++: %p, valor: %d\n", ptr, *ptr);
    // ptr = base + 4, *ptr = 20
    
    ptr += 2;  // Avanza 2 * sizeof(int) bytes
    printf("Después de ptr+=2: %p, valor: %d\n", ptr, *ptr);
    // ptr = base + 12, *ptr = 40
    
    // Acceso con índice (equivalente a aritmética)
    int *base = arr;
    printf("base[3] = %d\n", base[3]);  // 40
    printf("*(base + 3) = %d\n", *(base + 3));  // 40 (equivalente)
    
    return 0;
}
```

Un punto crítico es que `ptr++` avanza `sizeof(tipo)` bytes, no 1 byte. `int*` avanza 4 bytes, `char*` avanza 1 byte, `double*` avanza 8 bytes. El compilador maneja esto automáticamente.

###  Asignación Dinámica con malloc

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    // Asignar memoria para 5 enteros
    int *arr = (int *)malloc(5 * sizeof(int));
    
    if (arr == NULL) {
        fprintf(stderr, "Error: malloc falló\n");
        return 1;
    }
    
    // Inicializar el arreglo
    for (int i = 0; i < 5; i++) {
        arr[i] = i * 10;
    }
    
    // Imprimir valores
    printf("Valores: ");
    for (int i = 0; i < 5; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
    
    // Redimensionar con realloc
    arr = (int *)realloc(arr, 10 * sizeof(int));
    
    if (arr == NULL) {
        fprintf(stderr, "Error: realloc falló\n");
        return 1;
    }
    
    // Inicializar nuevos elementos
    for (int i = 5; i < 10; i++) {
        arr[i] = i * 10;
    }
    
    // Liberar memoria
    free(arr);
    arr = NULL;  // Buena práctica: evitar dangling pointer
    
    return 0;
}
```

Los errores comunes incluyen no verificar si malloc devuelve NULL, olvidar liberar memoria (memory leak), usar memoria después de free (use-after-free), doble free (undefined behavior), y buffer overflow (escribir fuera del bloque asignado).

### Mapeo de Memoria con mmap

`mmap()` es una syscall que mapea archivos o memoria directamente al espacio de direcciones del proceso.

```c
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

int main() {
    // Crear memoria anónima compartida
    size_t size = 4096;  // 1 página
    
    void *addr = mmap(
        NULL,                   // Dirección (NULL = el SO elige)
        size,                   // Tamaño
        PROT_READ | PROT_WRITE, // Protección
        MAP_ANONYMOUS | MAP_PRIVATE, // Flags
        -1,                     // File descriptor (no hay archivo)
        0                       // Offset
    );
    
    if (addr == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    
    printf("Memoria mapeada en: %p\n", addr);
    
    // Usar la memoria como un array
    int *data = (int *)addr;
    for (int i = 0; i < 10; i++) {
        data[i] = i * i;
    }
    
    // Verificar
    printf("Valores: ");
    for (int i = 0; i < 10; i++) {
        printf("%d ", data[i]);
    }
    printf("\n");
    
    // Liberar memoria
    if (munmap(addr, size) == -1) {
        perror("munmap");
        return 1;
    }
    
    return 0;
}
```

Las *ventajas de mmap* son control fino de protecciones de memoria, mapeo de archivos eficiente (I/O mapeado a memoria), memoria compartida entre procesos (MAP_SHARED), y asignación de grandes bloques sin fragmentar heap.

### Ejemplo Integrador: Simulación de Tabla de Páginas

Este ejemplo muestra cómo simular una tabla de páginas simple en C.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#define PAGE_SIZE 1024      // 1 KiB por página
#define PAGE_BITS 10        // log2(1024) = 10 bits
#define NUM_PAGES 16        // 16 páginas lógicas
#define NUM_FRAMES 32       // 32 marcos físicos

// Entrada de tabla de páginas
typedef struct {
    uint32_t frame;         // Número de marco físico
    bool valid;             // ¿Página en memoria?
    bool read;              // Permiso de lectura
    bool write;             // Permiso de escritura
    bool execute;           // Permiso de ejecución
} PageTableEntry;

// Tabla de páginas
typedef struct {
    PageTableEntry entries[NUM_PAGES];
    uint32_t pid;           // ID del proceso
} PageTable;

// Memoria física simulada
uint8_t physical_memory[NUM_FRAMES * PAGE_SIZE];

// Crear tabla de páginas vacía
PageTable* create_page_table(uint32_t pid) {
    PageTable *pt = (PageTable *)malloc(sizeof(PageTable));
    pt->pid = pid;
    
    // Inicializar todas las entradas como inválidas
    for (int i = 0; i < NUM_PAGES; i++) {
        pt->entries[i].valid = false;
        pt->entries[i].read = false;
        pt->entries[i].write = false;
        pt->entries[i].execute = false;
        pt->entries[i].frame = 0;
    }
    
    return pt;
}

// Mapear una página a un marco
void map_page(PageTable *pt, uint32_t page, uint32_t frame,
              bool r, bool w, bool x) {
    if (page >= NUM_PAGES || frame >= NUM_FRAMES) {
        fprintf(stderr, "Error: página o marco fuera de rango\n");
        return;
    }
    
    pt->entries[page].frame = frame;
    pt->entries[page].valid = true;
    pt->entries[page].read = r;
    pt->entries[page].write = w;
    pt->entries[page].execute = x;
    
    printf("Mapeada página %u -> marco %u (R:%d W:%d X:%d)\n",
           page, frame, r, w, x);
}

// Traducir dirección lógica a física
int translate_address(PageTable *pt, uint32_t logical_addr,
                      uint32_t *physical_addr, bool is_write) {
    // Extraer número de página y offset
    uint32_t page = logical_addr >> PAGE_BITS;
    uint32_t offset = logical_addr & ((1 << PAGE_BITS) - 1);
    
    printf("Dirección lógica: 0x%X\n", logical_addr);
    printf("  -> Página: %u, Offset: %u\n", page, offset);
    
    // Verificar que la página existe
    if (page >= NUM_PAGES) {
        fprintf(stderr, "ERROR: Página %u fuera de rango\n", page);
        return -1;
    }
    
    // Verificar que la página es válida
    if (!pt->entries[page].valid) {
        fprintf(stderr, "ERROR: Page Fault - página %u no válida\n", page);
        return -2;
    }
    
    // Verificar permisos
    if (is_write && !pt->entries[page].write) {
        fprintf(stderr, "ERROR: Protection Fault - página %u no escribible\n",
                page);
        return -3;
    }
    
    if (!is_write && !pt->entries[page].read) {
        fprintf(stderr, "ERROR: Protection Fault - página %u no legible\n",
                page);
        return -4;
    }
    
    // Calcular dirección física
    uint32_t frame = pt->entries[page].frame;
    *physical_addr = (frame << PAGE_BITS) | offset;
    
    printf("  -> Marco: %u\n", frame);
    printf("  -> Dirección física: 0x%X\n", *physical_addr);
    
    return 0;  // Éxito
}

// Función principal de demostración
int main() {
    printf("=== Simulador de Tabla de Páginas ===\n");
    printf("Tamaño de página: %d bytes\n", PAGE_SIZE);
    printf("Número de páginas: %d\n", NUM_PAGES);
    printf("Número de marcos: %d\n\n", NUM_FRAMES);
    
    // Crear tabla de páginas para proceso 42
    PageTable *pt = create_page_table(42);
    
    // Mapear algunas páginas
    printf("--- Configurando mapeos ---\n");
    map_page(pt, 0, 5, true, false, true);   // Código: R-X
    map_page(pt, 1, 8, true, true, false);   // Datos: RW-
    map_page(pt, 2, 3, true, true, false);   // Stack: RW-
    map_page(pt, 5, 12, true, false, false); // Constantes: R--
    printf("\n");
    
    // Probar traducciones
    printf("--- Probando traducciones ---\n");
    uint32_t phys_addr;
    int result;
    
    // Traducción exitosa (lectura en página 0)
    result = translate_address(pt, 0x0100, &phys_addr, false);
    if (result == 0) {
        printf("  ✓ Traducción exitosa\n");
    }
    printf("\n");
    
    // Traducción exitosa (escritura en página 1)
    result = translate_address(pt, 0x0500, &phys_addr, true);
    if (result == 0) {
        printf("  ✓ Traducción exitosa\n");
    }
    printf("\n");
    
    // Page Fault (página 3 no mapeada)
    printf("Intentando acceder página no mapeada:\n");
    result = translate_address(pt, 0x0C00, &phys_addr, false);
    printf("\n");
    
    // Protection Fault (intento de escritura en código)
    printf("Intentando escribir en página de código:\n");
    result = translate_address(pt, 0x0100, &phys_addr, true);
    printf("\n");
    
    // Calcular fragmentación interna
    printf("--- Análisis de fragmentación ---\n");
    uint32_t logical_size = 3500;  // Proceso necesita 3.5 KiB
    uint32_t pages_needed = (logical_size + PAGE_SIZE - 1) / PAGE_SIZE;
    uint32_t allocated = pages_needed * PAGE_SIZE;
    uint32_t internal_frag = allocated - logical_size;
    
    printf("Tamaño lógico del proceso: %u bytes\n", logical_size);
    printf("Páginas necesarias: %u\n", pages_needed);
    printf("Memoria asignada: %u bytes\n", allocated);
    printf("Fragmentación interna: %u bytes (%.1f%%)\n",
           internal_frag, (internal_frag * 100.0) / allocated);
    
    // Liberar memoria
    free(pt);
    
    return 0;
}
```

*Compilación y ejecución:*
```bash
gcc -o page_table_sim page_table_sim.c -Wall
./page_table_sim
```

*Salida esperada:*
```
=== Simulador de Tabla de Páginas ===
Tamaño de página: 1024 bytes
Número de páginas: 16
Número de marcos: 32

--- Configurando mapeos ---
Mapeada página 0 -> marco 5 (R:1 W:0 X:1)
Mapeada página 1 -> marco 8 (R:1 W:1 X:0)
Mapeada página 2 -> marco 3 (R:1 W:1 X:0)
Mapeada página 5 -> marco 12 (R:1 W:0 X:0)

--- Probando traducciones ---
Dirección lógica: 0x100
  -> Página: 0, Offset: 256
  -> Marco: 5
  -> Dirección física: 0x1500
   Traducción exitosa

Dirección lógica: 0x500
  -> Página: 1, Offset: 256
  -> Marco: 8
  -> Dirección física: 0x2100
   Traducción exitosa

Intentando acceder página no mapeada:
Dirección lógica: 0xC00
  -> Página: 3, Offset: 0
ERROR: Page Fault - página 3 no válida

Intentando escribir en página de código:
Dirección lógica: 0x100
  -> Página: 0, Offset: 256
ERROR: Protection Fault - página 0 no escribible

--- Análisis de fragmentación ---
Tamaño lógico del proceso: 3500 bytes
Páginas necesarias: 4
Memoria asignada: 4096 bytes
Fragmentación interna: 596 bytes (14.6%)
```

Este ejemplo demuestra la estructura de tabla de páginas, la traducción de direcciones (extracción de página y offset), verificación de permisos (R/W/X), manejo de Page Fault y Protection Fault, y cálculo de fragmentación interna.

## Casos de Estudio

### Ejercicio Simple: Traducción de Dirección Lógica

Un sistema usa paginación simple con las siguientes características:
- Tamaño de memoria lógica: 32 KiB
- Tamaño de página: 2 KiB

Tabla de páginas del proceso:
```
Página 0 -> Marco 3
Página 1 -> Marco 7
Página 2 -> Marco 1
Página 3 -> Marco 4
```

*Preguntas:*
1. ¿Cuántos bits se usan para el número de página?
2. ¿Cuántos bits se usan para el offset?
3. Traducir la dirección lógica 5000 a dirección física

*Solución:*

Calculamos la cantidad de bits

```
Memoria lógica: 32 KiB = 32 * 1024 = 32768 bytes = 2^15 bytes
-> Se necesitan 15 bits para direccionar toda la memoria lógica

Tamaño de página: 2 KiB = 2 * 1024 = 2048 bytes = 2^11 bytes
-> Se necesitan 11 bits para el offset

Bits para página = Bits totales - Bits de offset
                 = 15 - 11 = 4 bits

Número de páginas = 2^4 = 16 páginas (0-15)
```

El formato de dirección de 15 bits se divide en 4 bits para página (permitiendo páginas 0-15) y 11 bits para offset (permitiendo offset 0-2047).

```
Dirección lógica de 15 bits:
┌────────────┬───────────────────────┐
│  4 bits    │       11 bits         │
│  (página)  │      (offset)         │
└────────────┴───────────────────────┘
Rango página: 0-15
Rango offset: 0-2047
```

Para la traducción de 5000:

```
Paso 1: Convertir 5000 a binario
5000₁₀ = 1001110001000₂ (necesitamos 15 bits)
5000₁₀ = 001001110001000₂ (padding con ceros)

Paso 2: Separar página y offset
┌────────────┬───────────────────────┐
│ 0010       │ 01110001000           │
│ (p = 2)    │ (d = 904)             │
└────────────┴───────────────────────┘

Verificación:
- Página: 0010₂ = 2₁₀
- Offset: 01110001000₂ = 904₁₀
- Total: 2 * 2048 + 904 = 4096 + 904 = 5000

Paso 3: Consultar tabla de páginas
tabla[2] = marco 1

Paso 4: Calcular dirección física
DF = marco * tamaño_página + offset
DF = 1 * 2048 + 904
DF = 2048 + 904
DF = 2952 bytes
```

\begin{example}
La verificación adicional muestra que el marco 1 ocupa direcciones físicas [2048, 4095], y la dirección calculada 2952 está efectivamente en ese rango. Esta verificación es importante para confirmar que la traducción es correcta.
\end{example}

```
Marco 1 ocupa direcciones físicas: [2048, 4095]
Dirección calculada: 2952
¿2048 ≤ 2952 ≤ 4095? SÍ

En binario:
DF = 2952₁₀ = 101110001000₂
┌────────────┬───────────────────────┐
│ 00001      │ 01110001000           │
│ (marco=1)  │ (offset=904)          │
└────────────┴───────────────────────┘
```

*Respuestas finales:*
1. Bits para página: 4 bits
2. Bits para offset: 11 bits
3. Dirección física: 2952 bytes

### Ejercicio Complejo: Deducción y Traducción

Se sabe que la dirección lógica 12345 se traduce a la dirección física 28729, y que la página donde está 12345 se mapea al marco 7.  
1. ¿Cuál es el tamaño de página del sistema?
2. ¿Cuántos bits se usan para el número de página si el espacio lógico es de 64 KiB?
3. ¿A qué dirección física se traduce la dirección lógica 15000 sabiendo que su página se mapea al marco 5?

*Solución:*

Parte 1: Deducir tamaño de página

Sabemos que:
- Dirección lógica (DL) = 12345
- Dirección física (DF) = 28729
- Marco = 7

La fórmula de traducción es:
```
DF = marco * tamaño_página + offset
```

donde `offset` es el mismo en DL y DF (los bits menos significativos).

Si dividimos DL por el tamaño de página:
```
DL = número_página * tamaño_página + offset
```

Probemos con diferentes tamaños de página (potencias de 2):

```
Hipótesis 1: tamaño_página = 1024 bytes (2^10)
DL = 12345 = 12 * 1024 + 57
    página = 12, offset = 57
DF debería ser = 7 * 1024 + 57 = 7168 + 57 = 7225
Pero DF real = 28729 X

Hipótesis 2: tamaño_página = 2048 bytes (2^11)
DL = 12345 = 6 * 2048 + 57
    página = 6, offset = 57
DF debería ser = 7 * 2048 + 57 = 14336 + 57 = 14393
Pero DF real = 28729 X

Hipótesis 3: tamaño_página = 4096 bytes (2^12)
DL = 12345 = 3 * 4096 + 57
    página = 3, offset = 57
DF debería ser = 7 * 4096 + 57 = 28672 + 57 = 28729 ok!

¡Coincide!
```

*Verificación:*
```
Tamaño de página = 4096 bytes = 4 KiB = 2^12 bytes

DL = 12345
  = 12345 ÷ 4096 = 3 con resto 57
  = página 3, offset 57

DF = 7 * 4096 + 57 = 28672 + 57 = 28729
```

*Parte 2: Bits para número de página*

```
Espacio lógico: 64 KiB = 65536 bytes = 2^16 bytes
-> Se necesitan 16 bits de dirección total

Tamaño de página: 4096 bytes = 2^12 bytes
-> Se necesitan 12 bits para offset

Bits para página = 16 - 12 = 4 bits
Número de páginas = 2^4 = 16 páginas (0-15)

Formato de dirección:
┌────────────┬───────────────────────┐
│  4 bits    │       12 bits         │
│  (página)  │      (offset)         │
└────────────┴───────────────────────┘
```

*Parte 3: Traducir dirección lógica 15000*

```
Paso 1: Extraer página y offset
15000 ÷ 4096 = 3 con resto 2616
-> página = 3, offset = 2616

Verificación: 3 * 4096 + 2616 = 12288 + 2616 = 14904
Hay un error, recalculemos:

15000 ÷ 4096 = 3.66...
3 * 4096 = 12288
15000 - 12288 = 2712 (este es el offset correcto)

-> página = 3, offset = 2712

Paso 2: Consultar tabla de páginas
Se nos dice que esta página se mapea al marco 5

Paso 3: Calcular dirección física
DF = marco * tamaño_página + offset
DF = 5 * 4096 + 2712
DF = 20480 + 2712
DF = 23192 bytes
```

*Verificación en binario:*

```
DL = 15000₁₀ = 11101010011000₂ (necesitamos 16 bits)
DL = 0011101010011000₂

┌────────────┬───────────────────────┐
│ 0011       │ 101010011000          │
│ (p = 3)    │ (d = 2712)            │
└────────────┴───────────────────────┘

Página: 0011₂ = 3₁₀ ✓
Offset: 101010011000₂ = 2712₁₀ ✓

DF = 23192₁₀ = 101101010011000₂

┌─────────────┬───────────────────────┐
│ 0101        │ 101010011000          │
│ (marco = 5) │ (offset = 2712)       │
└─────────────┴───────────────────────┘
```

*Respuestas finales:*
1. Tamaño de página: 4096 bytes (4 KiB)
2. Bits para número de página: 4 bits (permite 16 páginas)
3. Dirección física de 15000: 23192 bytes

*Diagrama resumen del ejercicio:*

```
Sistema con páginas de 4 KiB:

Espacio Lógico (64 KiB):        Memoria Física:
┌──────────────┐ Página 0      ┌──────────────┐ Marco 0
│              │                │              │
├──────────────┤ Página 1      ├──────────────┤ Marco 1
│              │                │              │
├──────────────┤ Página 2      ├──────────────┤ Marco 2
│              │                │              │
├──────────────┤ Página 3      ├──────────────┤ Marco 3
│ DL=12345     │ ──────────┐   │              │
│ offset=57    │           │   ├──────────────┤ Marco 4
├──────────────┤ Página 4  │   │              │
│              │           │   ├──────────────┤ Marco 5
├──────────────┤ Página 5  │   │ DL=15000     │ ← traduce aquí
│              │           │   │ offset=2712  │
├──────────────┤ ...       │   ├──────────────┤ Marco 6
│              │           │   │              │
├──────────────┤ Página 15 │   ├──────────────┤ Marco 7
│              │           └──->│ DF=28729     │ ← traduce aquí
└──────────────┘               │ offset=57    │
                                └──────────────┘
```

## Síntesis

### Puntos Clave del Capítulo

La evolución de las técnicas de gestión de memoria muestra una progresión clara. Las particiones fijas eran simples pero con fragmentación interna severa. Las particiones dinámicas eliminaron la fragmentación interna pero crearon fragmentación externa. La paginación eliminó la fragmentación externa pero agregó overhead de traducción. La segmentación ofreció mejor modelo lógico pero volvió a introducir fragmentación externa. Finalmente, los sistemas híbridos de paginación más segmentación combinan ventajas de ambos enfoques.  
| Técnica | Fragm. Interna | Fragm. Externa | Overhead | Complejidad |
|---------|----------------|----------------|----------|-------------|
| Particiones Fijas | Alta | No | Mínimo | Baja |
| Particiones Dinámicas | No | Alta | Medio | Media |
| Paginación Simple | Baja | No | Medio | Media |
| Segmentación | No | Alta | Medio | Alta |
| Seg. + Paginación | Baja | No | Alto | Alta |
| Buddy System | Media | Media | Medio | Media |  

\begin{highlight}
Para dominar este capítulo, debés entender la diferencia entre dirección lógica, relativa y física, por qué el binding en tiempo de ejecución es esencial para sistemas modernos, cómo calcular bits de página y offset dado el tamaño de página, el proceso completo de traducción (página → tabla → marco → dirección física), cuándo ocurre fragmentación interna versus externa, las ventajas y desventajas de cada técnica, y el rol fundamental de MMU, TLB y registros base/límite.
\end{highlight}

Los algoritmos de asignación tienen características distintivas.  
```
First Fit:  Rápido, genera pequeños bloques al inicio
Best Fit:   Minimiza desperdicio, genera bloques muy pequeños
Worst Fit:  Deja bloques grandes utilizables (mejor en simulaciones)
Next Fit:   Distribuye asignaciones uniformemente
```

### Conexiones con Otros Temas
Este capítulo se conecta profundamente con otros aspectos del sistema operativo. En relación con procesos, el PCB contiene el puntero a la tabla de páginas del proceso, en cada context switch se actualiza el PTBR con la tabla del nuevo proceso, y la memoria de un proceso incluye código, datos, heap y stack.  
La conexión con *planificación* es directa: un proceso puede bloquearse por Page Fault esperando carga desde disco, el scheduler debe considerar procesos bloqueados por I/O de paginación, y los algoritmos NUMA-aware consideran la localidad de memoria.  
Este capítulo prepara el terreno para *memoria virtual*. Todo lo visto aquí es base para memoria virtual, que combina paginación con disco como extensión de RAM. El bit V (válido) indica si la página está en RAM o en disco, y el Page Fault es manejado por el SO para traer páginas desde disco.  

También se relaciona con el *sistema de archivos*. La función mmap() permite mapear archivos a memoria, el I/O mapeado a memoria usa las mismas técnicas de traducción, y la caché de bloques del filesystem usa páginas de memoria.  

### Errores Comunes en Parciales
Los errores frecuentes incluyen confundir bits de página con número de páginas (son conceptos diferentes), olvidar que el offset se mantiene igual en la traducción, sumar mal la fórmula (DF = marco * tamaño + offset, no página), no verificar que la dirección calculada sea válida, confundir fragmentación interna con externa, decir que la paginación tiene fragmentación externa (no la tiene), y no considerar que la tabla de páginas está en RAM, no en el CPU.
\begin{warning}
Un checklist para ejercicios de traducción debe incluir: identificar el tamaño de página (dato o deducir), calcular bits de offset (log₂ del tamaño de página), calcular bits de página (bits totales menos bits de offset), extraer página de dirección lógica, extraer offset, buscar marco en tabla de páginas, calcular DF $marco * tamaño_página + offset$, y verificar que DF esté en rango válido.
\end{warning}

### Preguntas de Reflexión
Algunas preguntas para profundizar tu comprensión: ¿Por qué los sistemas modernos NO usan particiones dinámicas a pesar de no tener fragmentación interna? Si la paginación elimina fragmentación externa, ¿por qué no se usan siempre páginas de 256 bytes para minimizar fragmentación interna? ¿Cómo afecta el tamaño de página al rendimiento del TLB? ¿Por qué la tabla de páginas invertida no se popularizó a pesar de ahorrar memoria? En un sistema con 100 procesos, ¿cuál es más eficiente: 100 tablas de páginas o una tabla invertida con hash?  

### Ejercicios Propuestos
Ejercicio 1: Un sistema tiene páginas de 8 KiB y espacio lógico de 256 KiB. Si la dirección lógica 50000 se traduce a la dirección física 90000, ¿en qué marco está mapeada la página correspondiente?  

Ejercicio 2: Calculá la fragmentación interna promedio en un sistema con páginas de 4 KiB si los procesos tienen tamaños aleatorios uniformemente distribuidos entre 1 KiB y 100 KiB.  

Ejercicio 3: Compará el overhead de memoria para tablas de páginas en paginación simple de 1 nivel, paginación de 2 niveles, y tabla invertida. Asumí espacio lógico de 4 GiB, páginas de 4 KiB, y entrada de tabla de 4 bytes.  

Ejercicio 4: Diseñá la estructura de una tabla de páginas que soporte protección R/W/X, páginas compartidas entre procesos, copy-on-write, y páginas en disco (memoria virtual).  

### Material para Profundizar
Las lecturas recomendadas incluyen Silberschatz (Capítulo 8: "Memory Management"), Stallings (Capítulo 7: "Memory Management"), y Tanenbaum (Capítulo 3: "Memory Management").
Entre los papers clásicos están Denning, P. J. (1970) sobre "Virtual Memory" en ACM Computing Surveys, y Corbató, F. J. et al. (1962) sobre "An Experimental Time-Sharing System", el primer sistema con memoria virtual.

\begin{infobox}
Para experimentar con estos conceptos, podés usar herramientas como pmap para ver el mapeo de memoria de un proceso, valgrind para detectar errores de memoria, /proc/[pid]/maps para ver regiones de memoria de un proceso, y gdb con comandos info proc mappings. La documentación del kernel de Linux en Documentation/vm/ es invaluable para entender implementaciones reales.
\end{infobox}

---

*Este capítulo ha cubierto los fundamentos de la gestión de memoria real. El próximo paso es entender cómo estos mecanismos se extienden para soportar memoria virtual, permitiendo ejecutar programas más grandes que la RAM física disponible.*