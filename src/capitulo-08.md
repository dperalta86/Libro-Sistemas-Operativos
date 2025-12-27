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

Imaginemos que estamos desarrollando un sistema operativo en 1960. Tenemos:
- Memoria RAM: 64 KB (¡muy cara!)
- Programas que necesitan: 128 KB, 256 KB o más
- Múltiples procesos que queremos ejecutar simultáneamente

**¿Cómo ejecutamos un programa más grande que la RAM disponible?**

Las primeras soluciones fueron manuales y dolorosas:

\textcolor{red!60!gray}{\textbf{Overlays (década de 1960):}\\
- El programador dividía manualmente el código en secciones\\
- Solo una sección se cargaba en memoria a la vez\\
- El programador escribía código para cargar/descargar secciones\\
- Extremadamente tedioso y propenso a errores\\
- Ejemplo: "Cuando termino la fase de input, cargo la fase de procesamiento"\\
}

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

**La solución moderna: Memoria Virtual**

\begin{excerpt}
\emph{Memoria Virtual:}
Técnica que permite ejecutar procesos cuyo espacio de direcciones total excede la memoria física disponible, mediante la ilusión de que cada proceso tiene acceso a un espacio de direcciones enorme y contiguo, gestionado automáticamente por el hardware y el sistema operativo.
\end{excerpt}

\textcolor{teal!60!black}{\textbf{Ventajas revolucionarias:}\\
- Transparente al programador (¡no más overlays!)\\
- Cada proceso cree que tiene toda la memoria para sí\\
- Permite ejecutar programas más grandes que la RAM\\
- Protección automática entre procesos\\
- Compartición eficiente de código\\
- Simplifica la programación enormemente\\
}

### ¿Cómo es posible?

La clave está en dos conceptos:
1. **No todo el programa necesita estar en RAM simultáneamente** (principio de localidad)
2. **Podemos usar el disco como extensión de la RAM** (con traducción automática)

```
Programa de 1 GB:
┌─────────────────────────┐
│   Código (100 MB)       │ ← Solo 10 MB activos ahora
├─────────────────────────┤
│   Datos (200 MB)        │ ← Solo 5 MB activos ahora
├─────────────────────────┤
│   Heap (300 MB)         │ ← Solo 20 MB activos ahora
├─────────────────────────┤
│   Stack (400 MB)        │ ← Solo 2 MB activos ahora
└─────────────────────────┘
Total en RAM: ~37 MB de 1 GB
Resto en disco (swap)
```

## Recap: Conceptos del Capítulo 7

Antes de continuar, repasemos brevemente los conceptos de paginación que vimos en el Capítulo 7, ya que son la base de la memoria virtual.

### Paginación Básica (Recap)

En el Capítulo 7 aprendimos que:

- El **espacio lógico** se divide en páginas de tamaño fijo (típicamente 4 KB)
- La **memoria física** se divide en marcos del mismo tamaño
- Una **tabla de páginas** mapea páginas lógicas a marcos físicos
- La **MMU** traduce direcciones automáticamente en hardware

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

El **Translation Lookaside Buffer** es una caché hardware que acelera la traducción:
- Almacena traducciones recientes (64-512 entradas)
- Acceso < 1 ns (vs ~100 ns si hay que buscar en tabla de páginas)
- Hit rate típico: 98-99%

**Esto es crítico en memoria virtual, donde cada acceso requiere traducción.**

### Lo Nuevo en Memoria Virtual

En el Capítulo 7, **todas las páginas del proceso estaban en RAM**. Ahora, en memoria virtual:
- **No todas las páginas están en RAM simultáneamente**
- Algunas páginas están en disco (swap space)
- El bit **presencia** en la tabla de páginas indica dónde está la página
- Se producen **page faults** cuando se accede a una página no presente

\textcolor{orange!70!black}{\textbf{Diferencia clave:}\\
Cap 7: Tabla de páginas mapea TODAS las páginas a marcos\\
Cap 8: Tabla de páginas puede indicar "esta página NO está en RAM"\\
}

Para más detalles sobre paginación básica, tablas multinivel, TLB y segmentación, consultar el Capítulo 7.

## Conceptos Fundamentales

### Espacio de Direcciones Virtual vs Físico

\begin{excerpt}
\emph{Espacio de Direcciones Virtual:}
El rango completo de direcciones que un proceso puede generar, independiente de la cantidad de memoria física disponible. En un sistema de 32 bits: 0 a 4 GB, en 64 bits: 0 a 16 EB (exabytes).
\end{excerpt}

**Ejemplo práctico:**

```c
#include <stdio.h>
#include <stdlib.h>

int main() {
    // En un sistema de 64 bits, este proceso "ve" un espacio
    // de direcciones de ~16 exabytes, aunque la máquina
    // solo tenga 8 GB de RAM física
    
    void *ptr = malloc(1024 * 1024 * 1024); // 1 GB
    printf("Dirección virtual: %p\n", ptr);
    
    // Esta dirección es VIRTUAL
    // Puede ser 0x7f8a3c000000 (ejemplo)
    // Pero físicamente puede estar en marco 2847 de RAM
    // O ni siquiera estar en RAM (en disco)
    
    free(ptr);
    return 0;
}
```

**Separación completa:**

```
Proceso A:                    Proceso B:
Espacio Virtual (4 GB)        Espacio Virtual (4 GB)
┌─────────────────┐          ┌─────────────────┐
│ 0xFFFFFFFF      │          │ 0xFFFFFFFF      │
│                 │          │                 │
│   Stack         │          │   Stack         │
│      ↓          │          │      ↓          │
├─────────────────┤          ├─────────────────┤
│                 │          │                 │
│      ↑          │          │      ↑          │
│   Heap          │          │   Heap          │
│                 │          │                 │
├─────────────────┤          ├─────────────────┤
│   Datos         │          │   Datos         │
├─────────────────┤          ├─────────────────┤
│   Código        │          │   Código        │
│ 0x00000000      │          │ 0x00000000      │
└─────────────────┘          └─────────────────┘
       ↓                            ↓
       └────────────┬───────────────┘
                    ↓
         Memoria Física (RAM)
         ┌─────────────────┐
         │ Marco N         │ ← Proceso B, página 5
         ├─────────────────┤
         │ Marco N-1       │ ← Proceso A, página 2
         ├─────────────────┤
         │ Marco N-2       │ ← SO
         ├─────────────────┤
         │ ...             │
         └─────────────────┘
```

\textcolor{blue!50!black}{\textbf{Consecuencias importantes:}\\
- Ambos procesos pueden usar la misma dirección virtual 0x1000\\
- Se mapean a marcos físicos diferentes\\
- Protección automática: un proceso no puede acceder al marco de otro\\
- Simplifica la programación: cada proceso empieza en 0x0\\
}

### El Bit presencia: El Héroe de Memoria Virtual

En el Capítulo 7, cada entrada de tabla de páginas era simplemente un número de marco. Ahora, agregamos información crucial:

```
Entrada de Tabla de Páginas (expandida):
┌────────────┬───┬───┬───┬───┬───────────┐
│ Marco (20) │ P │ U │ M │ X │ Protec.   │
└────────────┴───┴───┴───┴───┴───────────┘
              ↑
              Bit presencia (P)
```

\begin{excerpt}
\emph{Bit presencia (P):}
Indica si la página está presente en memoria RAM (P=1) o está en disco/swap (P=0). Es la base del mecanismo de memoria virtual.
\end{excerpt}

**Estados posibles:**

| P | U | M | Significado |
|---|---|---|-------------|
| 1 | 0 | 0 | En RAM, no accedida recientemente, no modificada |
| 1 | 1 | 0 | En RAM, accedida recientemente, no modificada |
| 1 | 1 | 1 | En RAM, accedida y modificada (dirty) |
| 0 | - | - | NO en RAM, está en disco (swap) |

**Ejemplo de tabla de páginas con memoria virtual:**

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
Proceso usa 8 * 4 KB = 32 KB virtual
Pero solo 4 * 4 KB = 16 KB físicos
```

\textcolor{teal!60!black}{\textbf{Ventaja crítica:}\\
Un proceso de 1 GB puede ejecutarse con solo 50 MB en RAM\\
El resto permanece en disco hasta que se necesite\\
}

### Page Fault: Evento Normal, NO Error

Este es un punto que genera mucha confusión en estudiantes. Aclaremos:

\begin{excerpt}
\emph{Page Fault:}
Interrupción generada por la MMU cuando el CPU intenta acceder a una página cuyo bit presencia está en 0 (página no presente en RAM). Es un mecanismo normal y esperado del sistema de memoria virtual, NO un error de programación.
\end{excerpt}

\textcolor{orange!70!black}{\textbf{¡IMPORTANTE!}\\
Page Fault ≠ Segmentation Fault\\
- Page Fault: Normal, el SO lo maneja transparentemente\\
- Segmentation Fault: Error, acceso a memoria inválida\\
}

**Comparación:**

| Evento | Causa | Manejo | Visible al Proceso |
|--------|-------|--------|--------------------|
| Page Fault | Acceso a página P=0 | SO carga página, continúa | NO (transparente) |
| Segmentation Fault | Acceso fuera del espacio válido | SO mata proceso | SÍ (señal SIGSEGV) |


### Swap Space (Backing Store)

\begin{excerpt}
\emph{Swap Space:}
Área del disco duro reservada para almacenar páginas que no están en RAM. Actúa como extensión de la memoria física.
\end{excerpt}

**Configuración típica en Linux:**

```bash
$ swapon --show
NAME       TYPE      SIZE   USED
/dev/sda2  partition  8G    1.2G
/swapfile  file       4G    512M
```

**Estructura:**

```
Disco Duro:
┌─────────────────────────────────┐
│ Partición 1: Sistema de Archivos│
├─────────────────────────────────┤
│ Partición 2: Swap (8 GB)        │ ← Páginas no en RAM
│   ┌─────────────────────────┐   │
│   │ Bloque 0-99:   Proceso A│   │
│   │ Bloque 100-199:Proceso B│   │
│   │ Bloque 200-299:Proceso C│   │
│   │ ...                     │   │
│   └─────────────────────────┘   │
└─────────────────────────────────┘
```

\textcolor{blue!50!black}{\textbf{Datos importantes:}\\
- Swap es ~1000x más lento que RAM (HDD)\\
- Con SSD: ~100x más lento que RAM\\
- Por eso es crítico minimizar page faults\\
- El SO intenta mantener páginas "calientes" en RAM\\
}

**Relación tamaño RAM vs Swap:**

```
Configuración típica:
RAM: 8 GB  → Swap: 8-16 GB
RAM: 16 GB → Swap: 8-16 GB
RAM: 32 GB → Swap: 4-8 GB (o menos)

Razón: Con más RAM, menos page faults → menos swap necesario
```

## Page Fault: Anatomía Completa

Ahora veamos el flujo detallado de lo que sucede cuando ocurre un page fault.

### Flujo Paso a Paso

```
1. CPU ejecuta: MOV R1, [0x2000]
   ↓
2. MMU traduce 0x2000 → página 2
   ↓
3. MMU consulta tabla de páginas: página 2, bit P=0
   ↓
4. MMU genera TRAP (interrupción page fault)
   ↓
5. Hardware guarda estado del proceso (registros, PC)
   ↓
6. Control pasa al SO (handler de page fault)
   ↓
7. SO verifica: ¿es acceso válido?
   ├─→ NO: enviar SIGSEGV (Segmentation Fault)
   └─→ SÍ: continuar
   ↓
8. SO busca marco libre en RAM
   ├─→ HAY marco libre: usar directamente
   └─→ NO hay marco libre: ejecutar algoritmo de reemplazo
   ↓
9. Si se reemplaza página "dirty" (M=1):
   - Escribir página víctima a disco (~5-10 ms)
   ↓
10. SO lee página desde disco (~5-10 ms)
    ↓
11. SO carga página en marco seleccionado
    ↓
12. SO actualiza tabla de páginas:
    - Página 2: marco=X, P=1, U=0, M=0
    ↓
13. SO invalida entrada TLB anterior (si existía)
    ↓
14. SO retorna de la interrupción
    ↓
15. Hardware restaura registros del proceso
    ↓
16. CPU reintenta la instrucción: MOV R1, [0x2000]
    ↓
17. Ahora P=1 → traducción exitosa → acceso a RAM
```

### Tiempos Aproximados (Validados)

Los siguientes tiempos están basados en mediciones de sistemas reales y literatura técnica (Silberschatz, Tanenbaum):

\textcolor{blue!50!black}{\textbf{Tiempos típicos de page fault:}\\
- Detección hardware (MMU): ~1 ns\\
- Context switch a handler SO: ~1-5 μs\\
- Búsqueda marco libre / algoritmo reemplazo: ~1-10 μs\\
- Escritura página dirty a disco (HDD): ~5-10 ms\\
- Lectura página desde disco (HDD): ~5-10 ms\\
- Escritura página dirty a disco (SSD): ~0.1-0.5 ms\\
- Lectura página desde disco (SSD): ~0.1-0.5 ms\\
- Actualización estructuras SO: ~1-5 μs\\
- Context switch de vuelta a proceso: ~1-5 μs\\
\textbf{Total (HDD): 10-20 ms}\\
\textbf{Total (SSD): 0.2-1 ms}\\
}

**Comparación con acceso normal a RAM:**

```
Acceso con TLB hit:  ~10 ns   (0.00001 ms)
Acceso con TLB miss: ~100 ns  (0.0001 ms)
Page fault (SSD):    ~500 μs  (0.5 ms)     → ~5,000x más lento
Page fault (HDD):    ~10 ms                → ~1,000,000x más lento
```

\textcolor{red!60!gray}{\textbf{Consecuencia crítica:}\\
Un page fault equivale a ~100,000 accesos normales a RAM\\
Por eso el principio de localidad es fundamental\\
Minimizar page faults es esencial para rendimiento\\
}

### Casos Especiales

#### Caso 1: Primera Referencia (Demand Paging)

```
Proceso recién creado:
- Todas las páginas tienen P=0
- Primera referencia a página 0 (código)
  → Page fault
  → SO carga página 0 desde ejecutable
- Primera referencia a página 1
  → Page fault
  → SO carga página 1
- ...

Las páginas se cargan SOLO cuando se necesitan
(de ahí "demand paging" = paginación bajo demanda)
```

#### Caso 2: Copy-on-Write (Adelanto)

```c
pid_t pid = fork();
// Antes del fork: proceso padre tiene 100 páginas en RAM

// Después del fork:
// - Hijo NO copia las 100 páginas inmediatamente
// - Ambos procesos comparten las mismas páginas (P=1, pero R/O)
// - Si hijo ESCRIBE en página X:
//   → Page fault (intento de escritura en R/O)
//   → SO copia la página
//   → Ahora cada proceso tiene su propia copia
```

#### Caso 3: Memory-Mapped Files

```c
int fd = open("archivo.dat", O_RDWR);
void *addr = mmap(NULL, 1024*1024, PROT_READ|PROT_WRITE, 
                  MAP_SHARED, fd, 0);
// mmap() NO carga el archivo completo
// Solo mapea direcciones virtuales al archivo

// Primera lectura de addr[0]:
// → Page fault
// → SO carga página desde archivo (no swap)

// Escritura en addr[100]:
// → Si página no está en RAM: page fault
// → Página marcada como dirty (M=1)
// → SO escribirá cambios al archivo eventualmente
```

### Diagrama Mermaid: Flujo de Page Fault

Este diagrama muestra el flujo completo con decisiones y tiempos:

```
[Insertar aquí: cap08-pageFaultFlow.mmd]
```

El diagrama debe incluir:
- Detección por MMU
- Verificación de validez
- Búsqueda de marco libre
- Algoritmo de reemplazo si es necesario
- Lectura/escritura a disco
- Actualización de estructuras
- Retry de instrucción

## Principio de Localidad

El principio de localidad es **LA RAZÓN** por la cual la memoria virtual funciona eficientemente. Sin él, cada proceso necesitaría todas sus páginas en RAM todo el tiempo.

### ¿Qué es el Principio de Localidad?

\begin{excerpt}
\emph{Principio de Localidad:}
Observación empírica de que los programas tienden a acceder un subconjunto relativamente pequeño de su espacio de direcciones en cualquier intervalo de tiempo dado. Se divide en dos tipos: localidad temporal y localidad espacial.
\end{excerpt}

\textcolor{orange!70!black}{\textbf{¿Por qué es crítico para memoria virtual?}\\
Si un proceso de 1 GB necesitara acceder aleatoriamente\\
todas sus páginas constantemente, tendríamos:\\
- Page faults continuos\\
- Disco trabajando sin parar\\
- Rendimiento catastrófico\\
\\
Pero GRACIAS a la localidad, el proceso solo accede\\
~50 MB activamente, permitiendo que funcione con poca RAM.\\
}

### Localidad Temporal

\begin{excerpt}
\emph{Localidad Temporal:}
Si se referencia una ubicación de memoria en el tiempo t, es muy probable que se referencie nuevamente en un futuro cercano (t + Δt).
\end{excerpt}

**Ejemplo clásico: Variables en un bucle**

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

**¿Qué está pasando?**

```
Páginas del proceso:
┌─────────────────┐
│ Pág 0: Código   │ ← Instrucciones del bucle (acceso repetido)
├─────────────────┤
│ Pág 1: Stack    │ ← Variables suma y contador (acceso repetido)
├─────────────────┤
│ Pág 2-N: Heap   │ ← No se usa en este ejemplo
└─────────────────┘

Durante el bucle:
- Se accede página 0 (código) 1,000,000 de veces
- Se accede página 1 (stack) 1,000,000 de veces
- Total: 2 páginas activas de quizás 100 páginas totales
```

**Otros ejemplos de localidad temporal:**
- Funciones llamadas frecuentemente
- Variables globales usadas en múltiples funciones
- Código en bucles internos (hot loops)

### Localidad Espacial

\begin{excerpt}
\emph{Localidad Espacial:}
Si se referencia una ubicación de memoria en la dirección X, es muy probable que se referencien ubicaciones cercanas (X ± δ) en un futuro próximo.
\end{excerpt}

**Ejemplo clásico: Recorrido de array**

```c
#include <stdio.h>
#define SIZE 1000000

int main() {
    int array[SIZE];  // 4 MB en heap
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

**¿Qué está pasando con las páginas?**

```
Array de 4 MB con páginas de 4 KB:
array[0..1023]    → Página 0   ┐
array[1024..2047] → Página 1   │ Cuando accedemos array[0],
array[2048..3071] → Página 2   │ es MUY probable que luego
...                             │ accedamos array[1], array[2]...
                                │ que están en la MISMA página
                                ↓
Si accedo array[0], traigo página 0 (con array[0..1023])
Próximos 1023 accesos: ¡SIN page fault! (misma página)
```

**Impacto en page faults:**

```
Array de 1,000,000 elementos (int):
- Tamaño: 4 MB
- Páginas necesarias: 4 MB / 4 KB = 1024 páginas

Acceso secuencial (CON localidad espacial):
- Page faults: 1024 (uno por página, la primera vez)
- Accesos sin PF: 1,000,000 - 1024 = 998,976

Acceso aleatorio (SIN localidad espacial):
- Cada acceso potencialmente a página diferente
- Page faults: potencialmente cientos de miles
- Rendimiento: desastroso
```

### Localidad en Programas Reales

**Ejemplo: Navegador web**

```
Código del navegador: 50 MB
Datos/páginas web: 500 MB
Total: 550 MB

En cualquier momento de 10 segundos:
- Código activo: ~5 MB (render engine, JavaScript VM)
- Datos activos: ~20 MB (página actual, imágenes visibles)
- Total activo: ~25 MB

Ratio: 25/550 = 4.5% del espacio en uso activo
→ Localidad hace viable ejecutar con poca RAM
```

### Working Set

\begin{excerpt}
\emph{Working Set (Conjunto de Trabajo):}
El conjunto de páginas que un proceso está usando activamente en un intervalo de tiempo dado. Es el "tamaño mínimo de RAM" que el proceso necesita para ejecutar eficientemente.
\end{excerpt}

```
Working set de un proceso:
t = 0-5s:   {páginas 0,1,2,5,7}     → 5 páginas
t = 5-10s:  {páginas 0,1,2,3,8}     → 5 páginas
t = 10-15s: {páginas 0,1,10,11,12}  → 5 páginas

Si le damos < 5 páginas de RAM:
→ Page faults continuos (thrashing)

Si le damos ≥ 5 páginas de RAM:
→ Funciona bien
```

\textcolor{teal!60!black}{\textbf{Importancia del working set:}\\
- El SO intenta estimar el working set de cada proceso\\
- Asigna suficientes marcos para cubrirlo\\
- Si no puede: suspende procesos (prevenir thrashing)\\
- Algoritmos como Working Set y PFF se basan en esto\\
}

### ¿Por Qué Funciona en Práctica?

**Razones del principio de localidad:**

1. **Estructura de programas:**
   - Código organizado en funciones (localidad temporal de funciones activas)
   - Datos en arrays/estructuras (localidad espacial)

2. **Bucles:**
   - Las instrucciones del bucle se ejecutan repetidamente
   - Variables del bucle se acceden repetidamente

3. **Llamadas a funciones:**
   - Una función activa usa su stack frame repetidamente
   - Retorno a caller → vuelve a código anterior

4. **Acceso secuencial:**
   - Archivos se leen/escriben secuencialmente
   - Arrays se procesan elemento por elemento

5. **Organización de datos:**
   - Structs agrupan datos relacionados
   - Objetos relacionados se alocan cerca en memoria

**Contraejemplo: Programa SIN localidad**

```c
// Programa patológico: acceso completamente aleatorio
#include <stdlib.h>
#include <time.h>

#define PAGES 10000

int main() {
    int *huge_array = malloc(PAGES * 4096);  // 40 MB
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

Este programa tendría un rendimiento ~1000x peor que uno con acceso secuencial.

## Demand Paging vs Prepaging

Cuando se carga un proceso en memoria, ¿cargamos todas sus páginas inmediatamente o esperamos a que se necesiten?

### Demand Paging (Paginación Bajo Demanda)

\begin{excerpt}
\emph{Demand Paging:}
Política donde las páginas se cargan en memoria SOLO cuando se referencian por primera vez, generando un page fault. Es la estrategia más común en sistemas modernos.
\end{excerpt}

**Funcionamiento:**

```
Proceso recién creado:
┌─────────────────────────┐
│ Tabla de Páginas        │
├────┬───────┬───┬────────┤
│Pág │ Marco │ P │ Estado │
├────┼───────┼───┼────────┤
│ 0  │   -   │ 0 │ No cargada│
│ 1  │   -   │ 0 │ No cargada│
│ 2  │   -   │ 0 │ No cargada│
│... │   -   │ 0 │ No cargada│
└────┴───────┴───┴────────┘
TODAS las páginas P=0 al inicio

Primera instrucción: acceso a página 0
→ Page fault → SO carga página 0
→ P=1

Acceso a datos: acceso a página 1
→ Page fault → SO carga página 1
→ P=1

...y así sucesivamente
```

\textcolor{teal!60!black}{\textbf{Ventajas de demand paging:}\\
- Solo se cargan páginas realmente necesarias\\
- Startup rápido (no espera a cargar todo)\\
- Ahorro de memoria (páginas no usadas nunca se cargan)\\
- Permite ejecutar programas más grandes que RAM\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Muchos page faults al inicio (cold start)\\
- Latencia impredecible en primera referencia\\
- Overhead por cada página nueva\\
}

**Ejemplo práctico:**

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

### Prepaging (Paginación Anticipada)

\begin{excerpt}
\emph{Prepaging:}
Política donde el SO intenta predecir qué páginas se necesitarán pronto y las carga anticipadamente, antes de que se generen page faults.
\end{excerpt}

**Estrategias de prepaging:**

1. **Cargar páginas contiguas:**
   ```
   Se accede página 5
   → Page fault
   → SO carga página 5
   → SO también carga páginas 6, 7, 8 (anticipando acceso secuencial)
   ```

2. **Histórico de acceso:**
   ```
   El proceso siempre accede páginas: 0 → 1 → 5 → 10
   → Al cargar, traer ese conjunto completo
   ```

3. **Working set previo:**
   ```
   Proceso se suspende con páginas {0,1,2,5,7} en RAM
   → Al reanudar, cargar ese working set completo
   ```

\textcolor{teal!60!black}{\textbf{Ventajas de prepaging:}\\
- Reduce page faults si la predicción es correcta\\
- Mejor rendimiento para patrones predecibles\\
- Útil al reanudar procesos suspendidos\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Si la predicción falla: desperdicio de I/O y memoria\\
- Más complejo de implementar\\
- Puede cargar páginas que nunca se usan\\
}

### Comparación

| Aspecto | Demand Paging | Prepaging |
|---------|---------------|-----------|
| Carga inicial | Nada | Conjunto predicho |
| Page faults | Más frecuentes | Menos (si predicción OK) |
| Uso de memoria | Óptimo | Puede desperdiciar |
| Complejidad | Simple | Compleja |
| Uso en SO reales | Mayoritario | Casos específicos |

**Uso en sistemas reales:**

- **Linux:** Principalmente demand paging, con prepaging limitado
  - Readahead para archivos secuenciales
  - Cargar páginas de código contiguas

- **Windows:** Similar, demand paging + prefetch
  - Almacena patrones de inicio de aplicaciones
  - Precarga páginas según histórico

\textcolor{orange!70!black}{\textbf{Trade-off fundamental:}\\
Prepaging apuesta: "el costo de cargar páginas extra\\
es menor que el costo de múltiples page faults"\\
\\
Solo vale la pena si la predicción es correcta > 80\\% del tiempo.\\
}

## Shared Pages y Técnicas Avanzadas

### Copy-on-Write (COW)

Copy-on-Write es una optimización crucial que hace viable la operación `fork()` en sistemas Unix/Linux.

\begin{excerpt}
\emph{Copy-on-Write (COW):}
Técnica donde múltiples procesos comparten las mismas páginas físicas de memoria mientras sean solo lectura. Al intentar escribir, se crea una copia privada de la página para ese proceso.
\end{excerpt}

**Problema sin COW:**

```c
pid_t pid = fork();

// Sin COW: fork() debe copiar TODAS las páginas del padre
// Padre tiene 100 MB en RAM
// → Copiar 100 MB toma ~100 ms
// → Desperdicio si el hijo hace exec() inmediatamente
```

**Solución con COW:**

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

**¿Qué pasa cuando el hijo escribe?**

```c
// Proceso hijo
int main() {
    int x = 10;  // Variable en página 1 (marco 8)
    x = 20;      // INTENTO DE ESCRITURA
    
    // → Page fault (intento de escritura en página R/O)
    // → SO detecta que es COW
    // → SO asigna nuevo marco (ej: marco 12)
    // → SO copia contenido de marco 8 → marco 12
    // → Actualiza tabla hijo: página 1 → marco 12, W=1
    // → Retry: escritura exitosa en nuevo marco privado
    
    return 0;
}
```

**Estado después de la escritura:**

```
Proceso Padre:              Proceso Hijo:
┌────┬───────┬───┬───┬───┐ ┌────┬───────┬───┬───┬───┐
│Pág │ Marco │ P │ R │ W │ │Pág │ Marco │ P │ R │ W │
├────┼───────┼───┼───┼───┤ ├────┼───────┼───┼───┼───┤
│ 0  │   5   │ 1 │ 1 │ 0 │ │ 0  │   5   │ 1 │ 1 │ 0 │  Aún compartida
│ 1  │   8   │ 1 │ 1 │ 0 │ │ 1  │  12   │ 1 │ 1 │ 1 │  Ahora privada!
└────┴───────┴───┴───┴───┘ └────┴───────┴───┴───┴───┘
```

\textcolor{teal!60!black}{\textbf{Ventajas de COW:}\\
- fork() es casi instantáneo (no copia memoria)\\
- Ahorra memoria si procesos no modifican páginas\\
- Típico: hijo hace exec() → nunca copia nada\\
- Solo se copian páginas realmente modificadas\\
}

**Estadísticas reales:**

```
fork() seguido de exec() (caso común):
- Sin COW: copiar 100 MB → ~100 ms
- Con COW: copiar 0 MB → ~1 ms (solo estructuras SO)

fork() donde hijo modifica 10% de páginas:
- Sin COW: copiar 100 MB → ~100 ms
- Con COW: copiar 10 MB bajo demanda → ~10 ms total
```

### Memory-Mapped Files

\begin{excerpt}
\emph{Memory-Mapped Files:}
Técnica que mapea un archivo del disco directamente al espacio de direcciones virtual de un proceso, permitiendo acceder al archivo como si fuera un array en memoria.
\end{excerpt}

**Syscall principal: `mmap()`**

```c
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    // Abrir archivo
    int fd = open("datos.bin", O_RDWR);
    
    // Mapear archivo a memoria (1 MB)
    void *addr = mmap(
        NULL,                   // SO elige dirección
        1024*1024,              // 1 MB
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

**¿Qué pasa internamente?**

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

\textcolor{teal!60!black}{\textbf{Ventajas de memory-mapped files:}\\
- I/O simplificado: archivos como arrays\\
- Compartición fácil entre procesos (MAP\_SHARED)\\
- SO maneja caché automáticamente\\
- Evita copias entre user space y kernel space\\
}

**Casos de uso:**

1. **Bases de datos:**
   ```c
   // Mapear archivo de BD completo
   // Acceder registros directamente sin read/write
   ```

2. **Librerías compartidas (.so, .dll):**
   ```
   Múltiples procesos mapean libc.so
   → Código compartido en RAM
   → Ahorro masivo de memoria
   ```

3. **IPC (Inter-Process Communication):**
   ```c
   // Proceso A y B mapean mismo archivo
   // Ambos ven cambios del otro (MAP_SHARED)
   ```

### Shared Libraries

Las librerías compartidas son un caso especial de shared pages.

```
3 procesos ejecutando programas que usan libc:

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

\textcolor{blue!50!black}{\textbf{Ahorro de memoria:}\\
Sin compartición: 3 procesos × 2 MB libc = 6 MB\\
Con compartición: 3 procesos × 1 copia = 2 MB\\
Ahorro: 4 MB (66\\%)\\
\\
En servidor con 100 procesos: ahorro de ~200 MB\\
}

### TLB Reach (Comentario Breve)

\begin{excerpt}
\emph{TLB Reach:}
Cantidad de memoria que puede ser mapeada por todas las entradas del TLB. Se calcula como: TLB Reach = (número de entradas TLB) × (tamaño de página).
\end{excerpt}

**Ejemplo:**

```
TLB con 64 entradas, páginas de 4 KB:
TLB Reach = 64 × 4 KB = 256 KB

Significado: si el working set del proceso es < 256 KB,
todas las traducciones estarán en TLB (hit rate ~100%)
```

**Optimización:**

```
Problema: working set = 1 MB, TLB reach = 256 KB
→ Muchos TLB misses
→ Rendimiento degradado

Solución: usar páginas más grandes
Con páginas de 2 MB (huge pages):
TLB Reach = 64 × 2 MB = 128 MB
→ Working set completo cabe en TLB
→ Hit rate aumenta dramáticamente
```

\textcolor{blue!50!black}{\textbf{Uso en sistemas reales:}\\
- Bases de datos usan huge pages (2 MB o 1 GB)\\
- VMs usan páginas grandes para EPT (Extended Page Tables)\\
- HPC (computación científica) usa páginas de 1 GB\\
}

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
Sistema con 1 GB RAM, 10 procesos:
Cada proceso necesita working set de 150 MB
Total necesario: 10 × 150 MB = 1500 MB
Disponible: 1000 MB

Déficit: 500 MB

¿Qué pasa?
→ Solo ~6 procesos caben cómodamente (6 × 150 = 900 MB)
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
   Ej: con 8 GB RAM, límite de 20 procesos
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