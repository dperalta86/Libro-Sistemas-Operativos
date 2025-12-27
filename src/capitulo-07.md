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

Imaginemos una biblioteca con espacio limitado para libros. Si cada estudiante llega y toma el espacio que necesita sin control alguno, pronto tendremos:

- Espacios desaprovechados entre libros
- Imposibilidad de ubicar libros nuevos aunque haya espacio total suficiente
- Estudiantes accediendo a libros que no les pertenecen
- Caos al intentar encontrar un libro específico

Lo mismo sucede con la memoria RAM en un sistema operativo multiprogramado. Con múltiples procesos ejecutándose simultáneamente, el SO debe:

1. Asignar memoria de manera eficiente
2. Proteger la memoria de cada proceso
3. Permitir compartir memoria cuando sea apropiado
4. Traducir direcciones para que cada proceso "crea" que tiene toda la memoria

### El problema fundamental

En los primeros sistemas, un programa accedía directamente a direcciones físicas de memoria. Esto presentaba problemas críticos:

\textcolor{red!60!gray}{\textbf{Problemas de direccionamiento directo:}\\
- Un proceso podía sobrescribir memoria del SO\\
- Imposible reubicar un programa una vez cargado\\
- No se podía ejecutar más de un programa simultáneamente\\
- Errores de programación podían corromper todo el sistema\\
}

La solución fue introducir una capa de abstracción: el concepto de **espacio de direcciones lógicas**.

### Evolución histórica

La gestión de memoria ha evolucionado siguiendo un patrón de "problema -> solución -> nuevo problema":

1. **Memoria compartida sin protección** -> Un programa podía destruir todo el sistema
2. **Particiones fijas** -> Desperdicio de memoria (fragmentación interna)
3. **Particiones dinámicas** -> Fragmentación externa severa
4. **Paginación** -> Resuelve fragmentación externa pero agrega overhead
5. **Segmentación** -> Mejor modelo lógico pero más complejo
6. **Híbridos** -> Combinan ventajas pero aumentan complejidad

Este capítulo recorre esta evolución para entender por qué los sistemas modernos usan las técnicas actuales.

## Conceptos Fundamentales

### Espacios de Direcciones

\begin{excerpt}
\emph{Espacio de Direcciones:}
Conjunto de direcciones que una entidad puede usar para referenciar memoria. Existen tres tipos fundamentales.
\end{excerpt}

#### Dirección Lógica (Virtual)

Generada por el CPU durante la ejecución de un programa. Es la dirección que "ve" el proceso. Por ejemplo, cuando un programa en C hace:

```c
int x = 42;
printf("Dirección de x: %p\n", &x);
```

La dirección mostrada es una **dirección lógica**. El proceso no sabe (ni le importa) dónde está físicamente en RAM.

\textcolor{blue!50!black}{\textbf{Características:}\\
- Independiente de la ubicación física\\
- Permite reubicación del proceso\\
- Cada proceso tiene su propio espacio lógico\\
- Rango: 0 hasta límite del proceso\\
}

#### Dirección Relativa

Es una dirección expresada como desplazamiento desde un punto de referencia (típicamente el inicio del programa).

**Ejemplo:** Si un programa se compila y la variable `x` está en el offset 100 desde el inicio del código, su dirección relativa es 100, sin importar dónde se cargue el programa en memoria.

#### Dirección Física (Real)

Es la dirección real en los módulos de RAM. El hardware usa estas direcciones para acceder a la memoria física.

\textcolor{orange!70!black}{\textbf{Importante:}\\
- El proceso NUNCA ve direcciones físicas\\
- La traducción la hace el hardware (MMU)\\
- El SO configura los parámetros de traducción\\
}

### Binding de Direcciones

El **binding** es el proceso de asignar direcciones de programa a direcciones reales de memoria. Puede ocurrir en tres momentos diferentes:

#### En Tiempo de Compilación

El compilador genera direcciones físicas absolutas.

```c
// El compilador coloca 'x' en la dirección física 0x1000
int x = 10;  // Compilado como: MOV [0x1000], 10
```

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- El programa solo funciona en esa ubicación de memoria\\
- Imposible ejecutar múltiples instancias\\
- No hay protección entre procesos\\
- Recompilar si se cambia ubicación\\
}

**Uso histórico:** Sistemas embebidos antiguos, programas únicos en memoria.

#### En Tiempo de Carga

El loader (cargador) ajusta las direcciones cuando carga el programa en memoria.

```c
// El compilador genera código reubicable
int x = 10;  // Compilado como: MOV [BASE+100], 10
// El loader determina BASE al cargar
```

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Una vez cargado, no se puede mover el proceso\\
- El tiempo de carga aumenta (hay que ajustar todas las direcciones)\\
- No permite compactación de memoria\\
}

**Uso histórico:** Sistemas batch, overlays.

#### En Tiempo de Ejecución
Las direcciones se traducen dinámicamente durante la ejecución usando hardware especial (MMU).

```c
// El compilador genera direcciones lógicas
int x = 10;  // Genera: MOV [100], 10 (dirección lógica)
// La MMU traduce 100 -> dirección física en cada acceso
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- El proceso puede moverse en memoria (compactación)\\
- Protección automática entre procesos\\
- Soporte para memoria virtual\\
- Permite compartir memoria entre procesos\\
}

\textcolor{orange!70!black}{\textbf{¿Por qué se usa en tiempo de ejecución en sistemas modernos?}\\
Es la ÚNICA forma de soportar:\\
- Multiprogramación con protección\\
- Memoria virtual (swap)\\
- Compactación dinámica\\
- Espacios de direcciones independientes\\
Sin binding dinámico, no existirían los SO modernos.\\
}

### Componentes Hardware

#### Memory Management Unit (MMU)

\begin{excerpt}
\emph{MMU (Memory Management Unit):}
Circuito hardware que traduce direcciones lógicas a físicas en tiempo de ejecución. Opera a velocidad del CPU sin intervención del SO.
\end{excerpt}

**Funcionamiento básico:**

```
CPU genera: Dirección Lógica (DL)
    ↓
MMU calcula: Dirección Física (DF) = f(DL, parámetros)
    ↓
RAM recibe: Dirección Física
```

El SO configura los **parámetros** (registros base/límite, tablas de páginas), pero la **traducción** es 100% hardware.

\textcolor{blue!50!black}{\textbf{¿Por qué es hardware y no software?}\\
- Se ejecuta en CADA acceso a memoria\\
- Un programa hace millones de accesos por segundo\\
- Si fuera software, el sistema sería inutilizable\\
- El overhead debe ser menor a 10 ns por traducción\\
}

#### Translation Lookaside Buffer (TLB)

La MMU necesita consultar tablas de páginas en RAM para traducir direcciones. Como esto es lento (100+ ns), existe una caché especial dentro del CPU:

\begin{excerpt}
\emph{TLB (Translation Lookaside Buffer):}
Caché hardware de alta velocidad que almacena traducciones recientes de páginas. Típicamente 64-512 entradas, tiempo de acceso < 1 ns.
\end{excerpt}

**Proceso de traducción con TLB:**

1. CPU genera dirección lógica
2. MMU busca en TLB (< 1 ns)
   - **TLB hit**: Usa traducción cacheada -> RAM (total: ~10 ns)
   - **TLB miss**: Busca en tabla de páginas en RAM (total: ~100 ns)
3. Si fue miss, la entrada se cachea en TLB para futuros accesos

\textcolor{teal!60!black}{\textbf{Efectividad de TLB:}\\
- Hit rate típico: 98-99 porciento\\
- Localidad espacial: procesos acceden memoria cercana\\
- Localidad temporal: mismas páginas repetidamente\\
- Una aplicación bien escrita tiene hit rate mayor a 99 porciento\\
}

#### Registros Base y Límite

En los esquemas más simples de gestión de memoria, la MMU usa dos registros:

- **Registro Base**: Dirección física donde comienza el proceso
- **Registro Límite**: Tamaño máximo del espacio del proceso

**Traducción:**
```
Dirección Física = Dirección Lógica + Base

Si (Dirección Lógica >= Límite):
    Generar TRAP (Segmentation Fault)
```

\textcolor{orange!70!black}{\textbf{Verificación de límites:}\\
- La verificación es en HARDWARE (circuito comparador)\\
- El SO carga Base y Límite al hacer context switch\\
- Si un proceso intenta acceder fuera de su espacio -> TRAP\\
- El SO maneja el TRAP (típicamente: matar el proceso)\\
}

### Fragmentación

La fragmentación es el desperdicio de memoria que no puede usarse eficientemente.

#### Fragmentación Interna

\begin{excerpt}
\emph{Fragmentación Interna:}
Memoria desperdiciada DENTRO de una región asignada. Ocurre cuando se asigna más memoria de la necesitada.
\end{excerpt}

**Ejemplo:** Un proceso necesita 19 KB pero el sistema asigna bloques de 4 KB. Se asignan 5 bloques (20 KB), desperdiciando 1 KB.

```
Bloque asignado: [===================·] 
                  ← 19 KB usados ->  ← 1 KB desperdiciado
                  ← 20 KB totales ->
```

\textcolor{red!60!gray}{\textbf{Causas:}\\
- Asignación en bloques de tamaño fijo\\
- Políticas de alineación de memoria\\
- Overhead de estructuras administrativas\\
}

**Dónde ocurre:**
- Particiones fijas
- Paginación (desperdicio en última página)
- Buddy System

#### Fragmentación Externa

\begin{excerpt}
\emph{Fragmentación Externa:}
Memoria desperdiciada ENTRE regiones asignadas. Hay suficiente memoria libre total, pero no es contigua.
\end{excerpt}

**Ejemplo:** Memoria total: 100 KB, Libres: 40 KB, pero en bloques de 10 KB cada uno. No se puede asignar un proceso de 30 KB.

```
Memoria: [P1][··][P2][····][P3][······][P4]
          ← libre -> ← libre ->  ← libre ->
         10 KB    15 KB      15 KB
         Total libre: 40 KB, pero no contiguos
         No se puede asignar proceso de 30 KB
```

\textcolor{red!60!gray}{\textbf{Causas:}\\
- Asignación y liberación de bloques de tamaño variable\\
- Procesos que terminan dejan huecos\\
- Con el tiempo, la memoria se "perfora" (swiss cheese)\\
}

**Dónde ocurre:**
- Particiones dinámicas
- Segmentación
- Cualquier esquema de asignación variable

**Solución:** Compactación (mover procesos para consolidar memoria libre), pero es costosa.

## Técnicas de Asignación Contigua

Las primeras técnicas de gestión de memoria asignaban espacios **contiguos** a cada proceso.

### Particiones Fijas

En los primeros sistemas multiprogramados, la memoria se dividía en particiones de tamaño fijo al inicio del sistema.

**Esquema de memoria con particiones fijas:**

```
Memoria física:
┌─────────────────┐ 0 KB
│   SO (64 KB)    │
├─────────────────┤ 64 KB
│ Partición 1     │
│   (128 KB)      │
├─────────────────┤ 192 KB
│ Partición 2     │
│   (256 KB)      │
├─────────────────┤ 448 KB
│ Partición 3     │
│   (512 KB)      │
├─────────────────┤ 960 KB
│ Partición 4     │
│   (64 KB)       │
└─────────────────┘ 1024 KB
```

**Mecanismo de asignación:**

1. Cuando llega un proceso, se busca una partición libre que lo contenga
2. El proceso ocupa toda la partición (aunque no la use completamente)
3. Al terminar, la partición queda libre para el próximo proceso

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Implementación extremadamente simple\\
- Asignación y liberación en O(1)\\
- Sin fragmentación externa\\
- Protección fácil (cada partición tiene base y límite fijos)\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación interna severa\\
- Número limitado de procesos (fijado al inicio)\\
- Procesos grandes pueden no caber\\
- Memoria desaprovechada si hay particiones vacías\\
}

**Problema crítico:** Un proceso de 50 KB en una partición de 256 KB desperdicia 206 KB (80% de fragmentación interna).

### Particiones Dinámicas

Para resolver la fragmentación interna de las particiones fijas, se desarrollaron las **particiones dinámicas**: cada proceso recibe exactamente la cantidad de memoria que necesita.

**Evolución de la memoria con particiones dinámicas:**

```
t=0: Sistema arranca
┌──────────┐
│    SO    │ 64 KB
├──────────┤
│  Libre   │ 960 KB
└──────────┘

t=1: Llega P1 (100 KB)
┌──────────┐
│    SO    │
├──────────┤
│    P1    │ 100 KB
├──────────┤
│  Libre   │ 860 KB
└──────────┘

t=2: Llegan P2 (200 KB) y P3 (150 KB)
┌──────────┐
│    SO    │
├──────────┤
│    P1    │
├──────────┤
│    P2    │ 200 KB
├──────────┤
│    P3    │ 150 KB
├──────────┤
│  Libre   │ 510 KB
└──────────┘

t=3: P1 termina
┌──────────┐
│    SO    │
├──────────┤
│  Libre   │ 100 KB (hueco)
├──────────┤
│    P2    │
├──────────┤
│    P3    │
├──────────┤
│  Libre   │ 510 KB
└──────────┘

t=4: P2 termina
┌──────────┐
│    SO    │
├──────────┤
│  Libre   │ 100 KB
├──────────┤
│  Libre   │ 200 KB (otro hueco)
├──────────┤
│    P3    │
├──────────┤
│  Libre   │ 510 KB
└──────────┘

Total libre: 810 KB, pero fragmentado en 3 bloques
Un proceso de 400 KB no cabe (aunque hay 810 KB libres)
-> Fragmentación externa
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Sin fragmentación interna\\
- Número dinámico de procesos\\
- Uso eficiente de memoria inicialmente\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación externa severa con el tiempo\\
- Algoritmo de asignación más complejo\\
- Requiere compactación periódica (costosa)\\
- Estructuras de datos para rastrear bloques libres\\
}

### Algoritmos de Asignación

Cuando llega un proceso que necesita memoria, el SO debe decidir **en qué bloque libre ubicarlo**. Existen varios algoritmos:

#### First Fit (Primer Ajuste)

**Algoritmo:** Busca secuencialmente en la lista de bloques libres y asigna el **primer bloque** suficientemente grande.

**Ejemplo:**
```
Bloques libres: [50 KB] [200 KB] [80 KB] [300 KB]
Proceso necesita: 70 KB

First Fit asigna: Bloque de 200 KB (primero que encontró >= 70 KB)
Resultado: [50 KB] [70 KB usado|130 KB libre] [80 KB] [300 KB]
```

\textcolor{blue!50!black}{\textbf{Características:}\\
- Complejidad: O(n) en el peor caso\\
- Rápido en promedio\\
- Tiende a dejar bloques pequeños al inicio de la lista\\
}

#### Best Fit (Mejor Ajuste)

**Algoritmo:** Busca en **toda** la lista de bloques libres y asigna el **bloque más pequeño** que sea suficiente.

**Ejemplo:**
```
Bloques libres: [50 KB] [200 KB] [80 KB] [300 KB]
Proceso necesita: 70 KB

Best Fit asigna: Bloque de 80 KB (el menor >= 70 KB)
Resultado: [50 KB] [200 KB] [70 KB usado|10 KB libre] [300 KB]
```

\textcolor{blue!50!black}{\textbf{Características:}\\
- Complejidad: O(n) siempre (debe recorrer toda la lista)\\
- Minimiza desperdicio por asignación\\
- Pero genera muchos bloques muy pequeños (inútiles)\\
}

#### Worst Fit (Peor Ajuste)

**Algoritmo:** Busca en toda la lista y asigna el **bloque más grande** disponible.

**Ejemplo:**
```
Bloques libres: [50 KB] [200 KB] [80 KB] [300 KB]
Proceso necesita: 70 KB

Worst Fit asigna: Bloque de 300 KB
Resultado: [50 KB] [200 KB] [80 KB] [70 KB usado|230 KB libre]
```

\textcolor{blue!50!black}{\textbf{Características:}\\
- Complejidad: O(n) siempre\\
- Deja bloques grandes (más útiles que los pequeños)\\
- Mejor rendimiento en simulaciones\\
}

#### Next Fit (Siguiente Ajuste)

**Algoritmo:** Similar a First Fit, pero continúa la búsqueda desde donde terminó la última asignación (búsqueda circular).

\textcolor{blue!50!black}{\textbf{Características:}\\
- Complejidad: O(n) en el peor caso\\
- Distribuye asignaciones más uniformemente\\
- Evita concentración de bloques pequeños al inicio\\
}

#### Comparación y Análisis

\textcolor{orange!70!black}{\textbf{Pregunta para reflexionar:}\\
¿Cuál algoritmo elegirías para un sistema de tiempo real? ¿Y para un servidor de aplicaciones? ¿Por qué?\\
}

**Análisis de fragmentación:**

En estudios de simulación, **Worst Fit** genera menos fragmentación severa que Best Fit, aunque suene contraintuitivo.

\textcolor{teal!60!black}{\textbf{¿Por qué Worst Fit es más eficiente?}\\
- Best Fit genera muchos bloques MUY pequeños (inútiles)\\
- Worst Fit deja bloques grandes (más probabilidad de ser útiles)\\
- Ejemplo: Best Fit deja 50 bloques de 1-5 KB (desperdicios)\\
- Worst Fit deja 10 bloques de 30-50 KB (pueden usarse)\\
}

**En la práctica:** Sistemas modernos usan variantes de First Fit con optimizaciones (listas ordenadas, segregación por tamaño).

## Paginación Simple

La paginación fue un avance revolucionario que resolvió el problema de fragmentación externa.

### Concepto y Motivación

**Idea central:** Dividir el espacio de direcciones lógicas y la memoria física en bloques de **tamaño fijo** llamados páginas y marcos (frames).

\begin{excerpt}
\emph{Paginación:}
Técnica de gestión de memoria que divide el espacio lógico en páginas de tamaño fijo y la memoria física en marcos del mismo tamaño. Las páginas se mapean a marcos de forma no contigua.
\end{excerpt}

**Conceptos clave:**

- **Página**: Bloque de memoria lógica (típicamente 4 KB)
- **Marco (Frame)**: Bloque de memoria física del mismo tamaño que una página
- **Tabla de páginas**: Estructura que mapea páginas a marcos

**Ventaja fundamental:** Las páginas de un proceso NO necesitan estar contiguas en memoria física.

```
Espacio lógico del proceso:    Memoria física:
┌──────────┐                   ┌──────────┐ Marco 0
│ Página 0 │ ────────────────-> │    P2    │
├──────────┤                   ├──────────┤ Marco 1
│ Página 1 │ ─────────┐        │    P0    │
├──────────┤          │        ├──────────┤ Marco 2
│ Página 2 │ ─┐       └──────-> │    P1    │
├──────────┤  │                ├──────────┤ Marco 3
│ Página 3 │  └──────────────-> │  Libre   │
└──────────┘                   ├──────────┤ Marco 4
                                │    P3    │
                                └──────────┘
```

\textcolor{teal!60!black}{\textbf{Ventajas de paginación:}\\
- Elimina fragmentación externa\\
- Asignación y liberación simple\\
- Permite compartir páginas entre procesos\\
- Facilita implementación de memoria virtual\\
- Protección a nivel de página\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación interna en última página\\
- Overhead de tabla de páginas\\
- Acceso a memoria requiere traducción\\
- Complejidad adicional en hardware\\
}

### Formato de Dirección Lógica

Una dirección lógica en paginación se divide en dos campos:

```
┌─────────────────┬──────────────────┐
│ Número de Página│     Offset       │
│       (p)       │       (d)        │
└─────────────────┴──────────────────┘
```

\begin{excerpt}
\emph{Formato de Dirección Lógica:}
Si el tamaño de página es $2^d$ bytes y el espacio lógico es $2^m$ bytes, entonces una dirección lógica tiene m bits divididos en: p = m - d bits para número de página, d bits para offset dentro de la página.
\end{excerpt}

**Ejemplo:** Espacio de 64 KB con páginas de 4 KB

- Espacio lógico: $2^{16}$ bytes (64 KB) -> 16 bits de dirección
- Tamaño de página: $2^{12}$ bytes (4 KB) -> 12 bits de offset
- Bits para número de página: 16 - 12 = 4 bits
- Número de páginas: $2^4$ = 16 páginas

```
Dirección lógica de 16 bits:
┌────────┬────────────────────┐
│ 4 bits │     12 bits        │
│  (p)   │      (d)           │
└────────┴────────────────────┘
Rango páginas: 0-15
Rango offset: 0-4095
```

### Traducción de Direcciones

El proceso de traducción usa la **tabla de páginas** del proceso:

**Algoritmo de traducción:**

1. Extraer número de página `p` de los bits más significativos
2. Extraer offset `d` de los bits menos significativos
3. Buscar en tabla de páginas: `marco = tabla_paginas[p]`
4. Calcular dirección física: `DF = marco * tamaño_pagina + d`

**Ejemplo numérico:**

```
Configuración:
- Tamaño de página: 1 KB (1024 bytes = 2^10)
- Espacio lógico: 8 KB (8192 bytes = 2^13)
- Bits de dirección: 13 bits
- Bits de página: 13 - 10 = 3 bits (8 páginas)
- Bits de offset: 10 bits (1024 posiciones)

Tabla de páginas del proceso:
┌────────┬────────┐
│ Página │ Marco  │
├────────┼────────┤
│   0    │   5    │
│   1    │   2    │
│   2    │   7    │
│   3    │   0    │
└────────┴────────┘

Traducir dirección lógica: 2500

Paso 1: Convertir a binario
2500₁₀ = 100111000100₂ (13 bits)

Paso 2: Separar p y d
┌───────┬──────────────┐
│ 100   │ 111000100    │
│ (p=4) │  (d=452)     │
└───────┴──────────────┘
Pero página 4 no existe en la tabla -> Segmentation Fault

Corregimos: 1300
1300₁₀ = 10100010100₂
┌───────┬──────────────┐
│ 001   │ 0100010100   │
│ (p=1) │  (d=276)     │
└───────┴──────────────┘

Paso 3: Consultar tabla
tabla[1] = marco 2

Paso 4: Calcular dirección física
DF = 2 * 1024 + 276 = 2048 + 276 = 2324
```

**Diagrama de traducción:**

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

\begin{excerpt}
\emph{Tabla de Páginas:}
Estructura de datos mantenida por el SO que mapea números de página lógica a números de marco físico. Cada proceso tiene su propia tabla de páginas.
\end{excerpt}

**Contenido de una entrada de tabla de páginas (PTE):**

```
┌────────────┬─────┬─────┬─────┬─────┬──────────┐
│ Marco (n)  │  V  │  R  │  W  │  X  │  Otros   │
└────────────┴─────┴─────┴─────┴─────┴──────────┘
    20 bits   1 bit 1 bit 1 bit 1 bit   8 bits
```

**Campos de la entrada:**

- **Marco**: Número de marco físico donde está la página
- **V (Valid)**: Indica si la página está en memoria (1) o en disco (0)
- **R (Referenced)**: Bit de acceso, para algoritmos de reemplazo
- **W (Written/Dirty)**: Indica si la página fue modificada
- **X (Execute)**: Permiso de ejecución
- **Otros**: Protección, compartición, etc.

**Ubicación de la tabla de páginas:**

La tabla de páginas está en **memoria RAM** (no en registros del CPU, son demasiadas entradas).

- El SO mantiene un registro especial: **PTBR (Page Table Base Register)** que apunta al inicio de la tabla
- En cada context switch, el SO actualiza el PTBR con la tabla del nuevo proceso

\textcolor{orange!70!black}{\textbf{Problema de rendimiento:}\\
- Cada acceso a memoria requiere 2 accesos reales:\\
  1. Leer entrada de tabla de páginas (en RAM)\\
  2. Leer dato solicitado (en RAM)\\
- Se duplica el tiempo de acceso a memoria\\
- Solución: TLB (caché de traducciones)\\
}

### Fragmentación Interna en Paginación

Aunque paginación elimina fragmentación externa, tiene fragmentación interna en la **última página** de cada proceso.

**Ejemplo:**

```
Proceso necesita: 13.5 KB
Tamaño de página: 4 KB
Páginas asignadas: 4 páginas (16 KB)
Fragmentación interna: 16 - 13.5 = 2.5 KB (15.6%)

┌──────────┐
│ Página 0 │ 4 KB (completa)
├──────────┤
│ Página 1 │ 4 KB (completa)
├──────────┤
│ Página 2 │ 4 KB (completa)
├──────────┤
│ Página 3 │ 1.5 KB usado
│  ········│ 2.5 KB desperdiciado
└──────────┘
```

\textcolor{blue!50!black}{\textbf{Fragmentación promedio:}\\
- En promedio: 0.5 páginas por proceso\\
- Si página = 4 KB: desperdicio promedio = 2 KB por proceso\\
- Con 100 procesos: 200 KB desperdiciados\\
- Trade-off: páginas más pequeñas -> menos fragmentación pero más overhead\\
}

## Segmentación

La paginación resuelve problemas técnicos pero no refleja la estructura lógica del programa. La segmentación aborda esto.

### Concepto y Motivación

**Perspectiva del programador:** Un programa NO es un arreglo lineal de bytes, sino una colección de unidades lógicas:

- Segmento de código (instrucciones)
- Segmento de datos globales
- Segmento de heap (memoria dinámica)
- Segmento de stack (variables locales)
- Segmentos de librerías compartidas

\begin{excerpt}
\emph{Segmentación:}
Técnica de gestión de memoria que divide el espacio de direcciones en segmentos de tamaño variable, donde cada segmento representa una unidad lógica del programa.
\end{excerpt}

**Diferencia clave con paginación:**

| Aspecto | Paginación | Segmentación |
|---------|-----------|--------------|
| División | Tamaño fijo (4 KB) | Tamaño variable |
| Criterio | Técnico (hardware) | Lógico (programador) |
| Visible al programador | No | Sí |
| Fragmentación | Interna | Externa |
| Protección | Por página | Por segmento (más natural) |
| Compartición | Complicada | Natural |

**Ejemplo de espacio segmentado:**

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

### Formato de Dirección Lógica en Segmentación

Una dirección lógica es un par: `(s, d)` donde:
- `s` = número de segmento
- `d` = desplazamiento dentro del segmento

**Traducción de dirección:**

1. Extraer `s` y `d` de la dirección lógica
2. Consultar tabla de segmentos: `entrada = tabla_segmentos[s]`
3. Verificar: `si d >= entrada.limite -> Segmentation Fault`
4. Calcular: `DF = entrada.base + d`

**Ejemplo:**

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

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Refleja estructura lógica del programa\\
- Protección natural (cada segmento tiene permisos)\\
- Compartición fácil (código compartido = mismo segmento)\\
- Crecimiento dinámico de segmentos (heap, stack)\\
- Facilita modularidad y librerías compartidas\\
}

**Ejemplo de compartición:**

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

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación externa (como particiones dinámicas)\\
- Complejidad de asignación (algoritmos First/Best/Worst Fit)\\
- Requiere compactación eventualmente\\
- Tabla de segmentos más compleja que tabla de páginas\\
}

### Segmentación con Paginación

Los sistemas modernos combinan ambas técnicas para obtener ventajas de cada una:

\begin{excerpt}
\emph{Segmentación Paginada:}
Cada segmento se divide en páginas. El espacio lógico está segmentado, pero cada segmento se implementa con paginación.
\end{excerpt}

**Proceso de traducción en dos niveles:**

```
Dirección lógica: (s, p, d)
- s = número de segmento
- p = número de página dentro del segmento
- d = offset dentro de la página

1. Consultar tabla de segmentos -> obtener tabla de páginas del segmento
2. Consultar tabla de páginas del segmento -> obtener marco
3. Calcular dirección física: marco * tamaño_página + d
```

**Ejemplo: Intel x86 (arquitectura IA-32):**

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

\textcolor{teal!60!black}{\textbf{Ventajas del esquema híbrido:}\\
- Protección y compartición de segmentación\\
- Sin fragmentación externa de paginación\\
- Segmentos pueden crecer (agregando páginas)\\
- Mejor uso de memoria que segmentación pura\\
}

## Técnicas Avanzadas

### Buddy System

El Buddy System es un algoritmo de asignación que busca balancear la velocidad de asignación con la fragmentación.

\begin{excerpt}
\emph{Buddy System:}
Algoritmo de asignación de memoria que divide bloques en potencias de 2. Cuando se libera un bloque, se intenta fusionar con su "buddy" (compañero) para formar bloques más grandes.
\end{excerpt}

**Funcionamiento:**

1. La memoria total es una potencia de 2 (ejemplo: 256 KB)
2. Cuando se solicita memoria, se busca el bloque más pequeño (potencia de 2) que lo contenga
3. Si no existe, se divide un bloque mayor recursivamente (splitting)
4. Al liberar, se intenta fusionar con el buddy si también está libre (coalescing)

**Regla del buddy:** Dos bloques de tamaño $2^k$ en direcciones `addr1` y `addr2` son buddies si:
```
addr1 XOR addr2 == 2^k
```

**Ejemplo de operación:**

```
Estado inicial: 256 KB libre
┌─────────────────────────────────┐
│           256 KB                │
└─────────────────────────────────┘

Solicitud: 40 KB
-> Necesita bloque de 64 KB (2^6)
-> Dividir 256 -> 128 + 128
-> Dividir 128 -> 64 + 64
-> Asignar primer 64 KB

Estado después de asignar 40 KB:
┌───────────┬───────────┬─────────────────┐
│ 64 (usado)│ 64 (libre)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Solicitud: 35 KB
-> Necesita bloque de 64 KB
-> Ya hay uno libre, asignar

┌───────────┬───────────┬─────────────────┐
│ 64 (usado)│ 64 (usado)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Liberar primer bloque (64 KB):
-> Su buddy (segundo 64 KB) está ocupado
-> No se puede fusionar

┌───────────┬───────────┬─────────────────┐
│ 64 (libre)│ 64 (usado)│   128 (libre)   │
└───────────┴───────────┴─────────────────┘

Liberar segundo bloque (64 KB):
-> Su buddy (primer 64 KB) está libre
-> Fusionar en 128 KB
-> El nuevo 128 tiene buddy libre (otro 128)
-> Fusionar en 256 KB

┌─────────────────────────────────┐
│           256 KB (libre)        │
└─────────────────────────────────┘
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Asignación y liberación rápidas: O(log n)\\
- Coalescing automático sin escanear toda la memoria\\
- Reduce fragmentación externa comparado con particiones dinámicas\\
- Implementación simple con listas por tamaño\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación interna (siempre se asigna potencia de 2)\\
- Un proceso de 65 KB recibe 128 KB (desperdicio 63 KB)\\
- No tan eficiente como paginación pura\\
}

**Uso en sistemas reales:** Linux usa una variante del Buddy System para asignar páginas físicas en el kernel (hasta orden 11, o sea, bloques de hasta 2^11 páginas).

### Paginación Multinivel

Cuando el espacio de direcciones es muy grande, la tabla de páginas se vuelve enorme.

**Problema:** En un sistema de 32 bits con páginas de 4 KB:
- Direcciones posibles: $2^{32}$ = 4 GB
- Páginas posibles: $2^{32} / 2^{12}$ = $2^{20}$ = 1 millón de páginas
- Entrada de tabla: 4 bytes
- **Tamaño de tabla: 4 MB por proceso**

Si hay 100 procesos: 400 MB solo en tablas de páginas (inaceptable).

**Solución:** Paginación multinivel, paginar la tabla de páginas misma.

#### Paginación de Dos Niveles

\begin{excerpt}
\emph{Paginación de Dos Niveles:}
La tabla de páginas se divide en páginas. Se mantiene un directorio de páginas que apunta a las tablas de páginas de segundo nivel.
\end{excerpt}

**Formato de dirección lógica:**

```
┌──────────────┬──────────────┬──────────────┐
│  Directorio  │    Página    │    Offset    │
│     (p1)     │     (p2)     │     (d)      │
└──────────────┴──────────────┴──────────────┘
```

**Proceso de traducción:**

1. Usar `p1` para indexar el **directorio de páginas** -> obtener tabla de nivel 2
2. Usar `p2` para indexar la **tabla de nivel 2** -> obtener marco
3. Usar `d` como offset dentro del marco

**Ventaja:** Si un proceso no usa ciertas regiones de memoria, las tablas de nivel 2 correspondientes NO se crean (ahorro de memoria).

**Ejemplo numérico (32 bits, página 4 KB):**

```
Dirección de 32 bits:
┌────────┬────────┬──────────────┐
│ 10 bits│ 10 bits│   12 bits    │
│  (p1)  │  (p2)  │     (d)      │
└────────┴────────┴──────────────┘

Directorio: 2^10 = 1024 entradas
Cada tabla nivel 2: 2^10 = 1024 entradas
Offset: 2^12 = 4096 bytes (4 KB)

Si proceso usa solo 4 MB:
- Requiere 1 entrada en directorio
- Requiere 1 tabla de nivel 2 (1024 entradas)
- Total: (1024 + 1024) * 4 bytes = 8 KB
- vs 4 MB en tabla plana
```

#### Paginación de Tres Niveles

Para espacios de direcciones de 64 bits, se requieren más niveles.

```
┌────────┬────────┬────────┬──────────────┐
│  (p1)  │  (p2)  │  (p3)  │     (d)      │
└────────┴────────┴────────┴──────────────┘
```

**Ejemplo: x86-64 con páginas de 4 KB:**

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

\textcolor{orange!70!black}{\textbf{Costo de traducción:}\\
- 3 niveles = 4 accesos a memoria (3 niveles + dato)\\
- Sin TLB sería devastador para rendimiento\\
- TLB es crítica: hit rate del 99 porciento es esencial\\
}

### Tabla de Páginas Invertida

Un enfoque radicalmente diferente: en lugar de una tabla por proceso, **una tabla global** para todo el sistema.

\begin{excerpt}
\emph{Tabla de Páginas Invertida:}
Una tabla única que tiene una entrada por cada marco físico (no por página lógica). Cada entrada indica qué proceso y qué página está en ese marco.
\end{excerpt}

**Estructura:**

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

**Traducción de dirección:**

1. Extraer `p` (página) y `d` (offset) de dirección lógica
2. Buscar en tabla invertida: entrada donde `(PID == actual) AND (Página == p)`
3. El índice de esa entrada es el **marco**
4. Calcular: `DF = marco * tamaño_página + d`

\textcolor{red!60!gray}{\textbf{Problema crítico:}\\
- La búsqueda es O(n) donde n = cantidad de marcos\\
- Cada acceso a memoria requiere escanear toda la tabla\\
- INACEPTABLE sin optimización\\
}

**Solución:** Usar una **tabla hash** para acelerar la búsqueda.

```
Hash(PID, página) -> índice en tabla hash -> cadena de colisiones -> entrada
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Tamaño de tabla proporcional a memoria física (no a lógica)\\
- Un sistema con 4 GB de RAM y páginas de 4 KB:\\
  -> 1M marcos -> 1M entradas (vs millones por proceso)\\
- Ahorro masivo en sistemas con muchos procesos\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Búsqueda más lenta (incluso con hash)\\
- Compartición de páginas complicada\\
- No compatible con memoria virtual tradicional\\
}

**Uso real:** PowerPC, IA-64 (Itanium), algunas versiones de AIX.

## Compactación y Defragmentación

La compactación es el proceso de mover procesos en memoria para consolidar los espacios libres.

\begin{excerpt}
\emph{Compactación:}
Técnica que reorganiza la memoria moviendo procesos activos para eliminar fragmentación externa, creando un único bloque contiguo de memoria libre.
\end{excerpt}

**Proceso de compactación:**

```
Antes de compactación:
┌──────┐ 0 KB
│  SO  │
├──────┤ 64 KB
│  P1  │ (50 KB)
├──────┤ 114 KB
│ Libre│ (30 KB)
├──────┤ 144 KB
│  P2  │ (80 KB)
├──────┤ 224 KB
│ Libre│ (40 KB)
├──────┤ 264 KB
│  P3  │ (60 KB)
├──────┤ 324 KB
│ Libre│ (700 KB)
└──────┘ 1024 KB

Total libre: 770 KB (fragmentado)

Después de compactación:
┌──────┐ 0 KB
│  SO  │
├──────┤ 64 KB
│  P1  │ (50 KB)
├──────┤ 114 KB
│  P2  │ (80 KB)
├──────┤ 194 KB
│  P3  │ (60 KB)
├──────┤ 254 KB
│ Libre│ (770 KB)
└──────┘ 1024 KB

Total libre: 770 KB (contiguo)
```

**Algoritmo de compactación:**

1. Identificar todos los bloques libres
2. Mover procesos hacia direcciones bajas
3. Actualizar tablas de asignación
4. **Actualizar todas las referencias** (registros, punteros, tablas de páginas)

\textcolor{red!60!gray}{\textbf{Costos de compactación:}\\
- Copiar todos los procesos en memoria (muy lento)\\
- Detener ejecución durante compactación\\
- Actualizar estructuras del SO\\
- En un sistema con 1 GB ocupado: varios segundos\\
}

\textcolor{orange!70!black}{\textbf{¿Cuándo es factible la compactación?}\\
SOLO si se usa binding en tiempo de ejecución.\\
- Con binding en compilación/carga: imposible mover procesos\\
- Con registros base/límite o paginación: solo actualizar registros\\
- La MMU hace transparente el movimiento para el proceso\\
}

**Estrategias de compactación:**

1. **Compactación completa:** Todos los procesos al inicio, todo el espacio libre al final
2. **Compactación parcial:** Solo eliminar huecos más pequeños que cierto umbral
3. **Compactación selectiva:** Solo mover procesos que no están ejecutando

**En paginación:** No se necesita compactación tradicional, pero se puede hacer "defragmentación" moviendo páginas para mejorar localidad (raro en práctica).

## Protección y Compartición

### Mecanismos de Protección

Los sistemas de gestión de memoria incluyen mecanismos de protección para:

1. Evitar que un proceso acceda memoria de otro
2. Evitar que un proceso acceda memoria del SO
3. Controlar operaciones permitidas (lectura, escritura, ejecución)

**Bits de protección en tabla de páginas:**

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

**Verificación por hardware:**

Cuando el CPU intenta acceder a una página, la MMU verifica automáticamente:

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

\textcolor{teal!60!black}{\textbf{Importancia de NX (No-eXecute):}\\
- Previene ataques de buffer overflow\\
- Stack y heap NO deben ser ejecutables\\
- Si un atacante inyecta código en stack, el CPU rechaza ejecutarlo\\
- Mecanismo fundamental de seguridad moderna\\
}

### Compartición de Memoria

Los sistemas modernos permiten que múltiples procesos compartan páginas de memoria.

**Casos de uso:**

1. **Código compartido:** Múltiples procesos ejecutando el mismo programa
2. **Librerías compartidas:** libc.so, libpthread.so, etc.
3. **Comunicación entre procesos:** Shared memory segments

**Ejemplo de código compartido:**

```
Proceso A (PID=100):          Proceso B (PID=200):
Tabla de páginas:             Tabla de páginas:
┌────────┬────────┐           ┌────────┬────────┐
│ Pág 0  │ Marco 5│ ← Código │ Pág 0  │ Marco 5│ Mismo marco
│ Pág 1  │ Marco 8│ ← Datos  │ Pág 1  │ Marco 9│ Datos privados
│ Pág 2  │ Marco 7│ ← Stack  │ Pág 2  │ Marco 6│ Stack privado
└────────┴────────┘           └────────┴────────┘
```

\textcolor{blue!50!black}{\textbf{Ahorro de memoria:}\\
- 100 procesos ejecutando bash (1 MB de código)\\
- Sin compartición: 100 MB de código en RAM\\
- Con compartición: 1 MB de código + 100 MB de datos privados\\
- Ahorro: 99 MB\\
}

**Requisitos para compartir código:**

1. El código debe ser **reentrante** (no se modifica a sí mismo)
2. Las páginas compartidas deben tener permisos **R-X** (no escribibles)
3. Cada proceso tiene sus propios datos y stack

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

**Salida típica:**
```
Valor de x: 42
Dirección de x: 0x7ffd8c5e3a9c
Valor de ptr: 0x7ffd8c5e3a9c
Valor apuntado: 42
Nuevo valor de x: 100
```

\textcolor{blue!50!black}{\textbf{Nota importante:}\\
- La dirección mostrada (0x7ffd8c5e3a9c) es una dirección LÓGICA\\
- La MMU la traduce a una dirección física que el programa nunca ve\\
- El programa opera completamente en su espacio virtual\\
}

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

\textcolor{orange!70!black}{\textbf{Cuidado:}\\
- ptr++ avanza sizeof(tipo) bytes, no 1 byte\\
- int* avanza 4 bytes, char* avanza 1 byte, double* avanza 8 bytes\\
- El compilador maneja esto automáticamente\\
}

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

\textcolor{orange!70!black}{\textbf{Errores comunes en malloc:}\\
- No verificar si malloc devuelve NULL\\
- Olvidar liberar memoria (memory leak)\\
- Usar memoria después de free (use-after-free)\\
- Doble free (undefined behavior)\\
- Buffer overflow (escribir fuera del bloque asignado)\\
}

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

**Ventajas de mmap:**

\textcolor{teal!60!black}{\textbf{Beneficios:}\\
- Control fino de protecciones de memoria\\
- Mapeo de archivos eficiente (I/O mapeado a memoria)\\
- Memoria compartida entre procesos (MAP\_SHARED)\\
- Asignación de grandes bloques sin fragmentar heap\\
}

### Ejemplo Integrador: Simulación de Tabla de Páginas

Este ejemplo muestra cómo simular una tabla de páginas simple en C.

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#define PAGE_SIZE 1024      // 1 KB por página
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
    uint32_t logical_size = 3500;  // Proceso necesita 3.5 KB
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

**Compilación y ejecución:**
```bash
gcc -o page_table_sim page_table_sim.c -Wall
./page_table_sim
```

**Salida esperada:**
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
  ✓ Traducción exitosa

Dirección lógica: 0x500
  -> Página: 1, Offset: 256
  -> Marco: 8
  -> Dirección física: 0x2100
  ✓ Traducción exitosa

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

\textcolor{blue!50!black}{\textbf{Conceptos demostrados:}\\
- Estructura de tabla de páginas\\
- Traducción de direcciones (extracción de página y offset)\\
- Verificación de permisos (R/W/X)\\
- Manejo de Page Fault y Protection Fault\\
- Cálculo de fragmentación interna\\
}

## Casos de Estudio

### Ejercicio Simple: Traducción de Dirección Lógica

**Enunciado:**

Un sistema usa paginación simple con las siguientes características:
- Tamaño de memoria lógica: 32 KB
- Tamaño de página: 2 KB

Tabla de páginas del proceso:
```
Página 0 -> Marco 3
Página 1 -> Marco 7
Página 2 -> Marco 1
Página 3 -> Marco 4
```

**Preguntas:**
1. ¿Cuántos bits se usan para el número de página?
2. ¿Cuántos bits se usan para el offset?
3. Traducir la dirección lógica 5000 a dirección física

**Solución:**

**Parte 1: Bits para número de página**

```
Memoria lógica: 32 KB = 32 * 1024 = 32768 bytes = 2^15 bytes
-> Se necesitan 15 bits para direccionar toda la memoria lógica

Tamaño de página: 2 KB = 2 * 1024 = 2048 bytes = 2^11 bytes
-> Se necesitan 11 bits para el offset

Bits para página = Bits totales - Bits de offset
                 = 15 - 11 = 4 bits

Número de páginas = 2^4 = 16 páginas (0-15)
```

**Parte 2: Formato de dirección**

```
Dirección lógica de 15 bits:
┌────────────┬───────────────────────┐
│  4 bits    │       11 bits         │
│  (página)  │      (offset)         │
└────────────┴───────────────────────┘
Rango página: 0-15
Rango offset: 0-2047
```

**Parte 3: Traducción de 5000**

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
- Página: 0010₂ = 2₁₀ ✓
- Offset: 01110001000₂ = 904₁₀ ✓
- Total: 2 * 2048 + 904 = 4096 + 904 = 5000 ✓

Paso 3: Consultar tabla de páginas
tabla[2] = marco 1

Paso 4: Calcular dirección física
DF = marco * tamaño_página + offset
DF = 1 * 2048 + 904
DF = 2048 + 904
DF = 2952 bytes
```

**Verificación adicional:**

```
Marco 1 ocupa direcciones físicas: [2048, 4095]
Dirección calculada: 2952
¿2048 ≤ 2952 ≤ 4095? SÍ ✓

En binario:
DF = 2952₁₀ = 101110001000₂
┌────────────┬───────────────────────┐
│ 00001      │ 01110001000           │
│ (marco=1)  │ (offset=904)          │
└────────────┴───────────────────────┘
```

**Respuestas finales:**
1. Bits para página: **4 bits**
2. Bits para offset: **11 bits**
3. Dirección física: **2952 bytes**

### Ejercicio Complejo: Deducción y Traducción

**Enunciado:**

Un sistema de paginación tiene las siguientes características:
- Se sabe que la dirección lógica 12345 se traduce a la dirección física 28729
- La tabla de páginas indica que la página donde está 12345 se mapea al marco 7

**Preguntas:**
1. ¿Cuál es el tamaño de página del sistema?
2. ¿Cuántos bits se usan para el número de página si el espacio lógico es de 64 KB?
3. ¿A qué dirección física se traduce la dirección lógica 15000 sabiendo que su página se mapea al marco 5?

**Solución:**

**Parte 1: Deducir tamaño de página**

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
Pero DF real = 28729 ✗

Hipótesis 2: tamaño_página = 2048 bytes (2^11)
DL = 12345 = 6 * 2048 + 57
    página = 6, offset = 57
DF debería ser = 7 * 2048 + 57 = 14336 + 57 = 14393
Pero DF real = 28729 ✗

Hipótesis 3: tamaño_página = 4096 bytes (2^12)
DL = 12345 = 3 * 4096 + 57
    página = 3, offset = 57
DF debería ser = 7 * 4096 + 57 = 28672 + 57 = 28729 ✓

¡Coincide!
```

**Verificación:**
```
Tamaño de página = 4096 bytes = 4 KB = 2^12 bytes

DL = 12345
  = 12345 ÷ 4096 = 3 con resto 57
  = página 3, offset 57

DF = 7 * 4096 + 57 = 28672 + 57 = 28729 ✓
```

**Parte 2: Bits para número de página**

```
Espacio lógico: 64 KB = 65536 bytes = 2^16 bytes
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

**Parte 3: Traducir dirección lógica 15000**

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

**Verificación en binario:**

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

**Respuestas finales:**
1. Tamaño de página: **4096 bytes (4 KB)**
2. Bits para número de página: **4 bits** (permite 16 páginas)
3. Dirección física de 15000: **23192 bytes**

**Diagrama resumen del ejercicio:**

```
Sistema con páginas de 4 KB:

Espacio Lógico (64 KB):        Memoria Física:
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

**Evolución de las técnicas de gestión de memoria:**

1. **Particiones Fijas** -> Simple pero con fragmentación interna severa
2. **Particiones Dinámicas** -> Eliminó fragmentación interna, creó fragmentación externa
3. **Paginación** -> Eliminó fragmentación externa, overhead de traducción
4. **Segmentación** -> Mejor modelo lógico, vuelve fragmentación externa
5. **Paginación + Segmentación** -> Combina ventajas de ambos

**Conceptos fundamentales que debes dominar:**

\textcolor{blue!50!black}{\textbf{Para el parcial:}\\
- Diferencia entre dirección lógica, relativa y física\\
- Por qué el binding en tiempo de ejecución es esencial\\
- Cómo calcular bits de página y offset dado tamaño de página\\
- Proceso de traducción: página -> tabla -> marco -> dirección física\\
- Fragmentación interna vs externa (cuándo ocurre cada una)\\
- Ventajas y desventajas de cada técnica\\
- Rol de MMU, TLB y registros base/límite\\
}

**Tabla comparativa de técnicas:**

| Técnica | Fragm. Interna | Fragm. Externa | Overhead | Complejidad |
|---------|----------------|----------------|----------|-------------|
| Particiones Fijas | Alta | No | Mínimo | Baja |
| Particiones Dinámicas | No | Alta | Medio | Media |
| Paginación Simple | Baja | No | Medio | Media |
| Segmentación | No | Alta | Medio | Alta |
| Seg. + Paginación | Baja | No | Alto | Alta |
| Buddy System | Media | Media | Medio | Media |

**Algoritmos de asignación:**

```
First Fit:  Rápido, genera pequeños bloques al inicio
Best Fit:   Minimiza desperdicio, genera bloques muy pequeños
Worst Fit:  Deja bloques grandes utilizables (mejor en simulaciones)
Next Fit:   Distribuye asignaciones uniformemente
```

### Conexiones con Otros Temas

**Relación con Procesos (Capítulo 2):**
- El PCB contiene puntero a tabla de páginas del proceso
- En context switch, se actualiza PTBR con tabla del nuevo proceso
- La memoria de un proceso incluye: código, datos, heap, stack

**Relación con Planificación (Capítulo 4):**
- Un proceso puede bloquearse por Page Fault (carga desde disco)
- El scheduler debe considerar procesos bloqueados por I/O de paginación
- Algoritmos NUMA-aware consideran localidad de memoria

**Preparación para Memoria Virtual (Capítulo 8):**
- Todo lo visto aquí es base para memoria virtual
- Memoria virtual = paginación + disco como extensión de RAM
- El bit V (válido) indica si página está en RAM o en disco
- Page Fault manejado por SO para traer página desde disco

**Preparación para Sistema de Archivos (Capítulo 9):**
- mmap() permite mapear archivos a memoria
- I/O mapeado a memoria usa las mismas técnicas
- Cache de bloques del FS usa páginas de memoria

### Errores Comunes en Parciales

\textcolor{red!60!gray}{\textbf{Errores frecuentes:}\\
- Confundir bits de página con número de páginas\\
- Olvidar que offset se mantiene igual en traducción\\
- Sumar mal: DF ≠ página * tamaño + offset (es marco, no página)\\
- No verificar que dirección calculada sea válida\\
- Confundir fragmentación interna con externa\\
- Decir que paginación tiene fragmentación externa\\
- No considerar que tabla de páginas está en RAM (no en CPU)\\
}

**Checklist para ejercicios de traducción:**

```
□ Identificar tamaño de página (dato o deducir)
□ Calcular bits de offset: log2(tamaño_página)
□ Calcular bits de página: bits_totales - bits_offset
□ Extraer página de dirección lógica: DL >> bits_offset
□ Extraer offset: DL & ((1 << bits_offset) - 1)
□ Buscar marco en tabla de páginas
□ Calcular DF: marco * tamaño_página + offset
□ Verificar que DF esté en rango válido
```

### Preguntas de Reflexión

1. ¿Por qué los sistemas modernos NO usan particiones dinámicas a pesar de no tener fragmentación interna?

2. Si paginación elimina fragmentación externa, ¿por qué no se usa siempre páginas de 256 bytes para minimizar fragmentación interna?

3. ¿Cómo afecta el tamaño de página al rendimiento del TLB?

4. ¿Por qué la tabla de páginas invertida no se popularizó a pesar de ahorrar memoria?

5. En un sistema con 100 procesos, ¿cuál es más eficiente: 100 tablas de páginas o una tabla invertida con hash?

### Ejercicios Propuestos

**Ejercicio 1:** Un sistema tiene páginas de 8 KB y espacio lógico de 256 KB. Si la dirección lógica 50000 se traduce a la dirección física 90000, ¿en qué marco está mapeada la página correspondiente?

**Ejercicio 2:** Calcular la fragmentación interna promedio en un sistema con páginas de 4 KB si los procesos tienen tamaños aleatorios uniformemente distribuidos entre 1 KB y 100 KB.

**Ejercicio 3:** Comparar el overhead de memoria para tablas de páginas en:
- Paginación simple de 1 nivel
- Paginación de 2 niveles
- Tabla invertida
Asume espacio lógico de 4 GB, páginas de 4 KB, entrada de tabla de 4 bytes.

**Ejercicio 4:** Diseñar la estructura de una tabla de páginas que soporte:
- Protección R/W/X
- Páginas compartidas entre procesos
- Copy-on-write
- Páginas en disco (memoria virtual)

### Material para Profundizar

**Lecturas recomendadas:**
- Silberschatz, Capítulo 8: "Memory Management"
- Stallings, Capítulo 7: "Memory Management"
- Tanenbaum, Capítulo 3: "Memory Management"

**Papers clásicos:**
- Denning, P. J. (1970). "Virtual Memory". ACM Computing Surveys
- Corbató, F. J. et al. (1962). "An Experimental Time-Sharing System" (primer sistema con memoria virtual)

**Documentación de sistemas reales:**
- Linux: `Documentation/vm/` en el kernel source tree
- Intel: "Intel 64 and IA-32 Architectures Software Developer's Manual, Volume 3A" (paginación en x86)
- ARM: "ARM Architecture Reference Manual" (paginación en ARM)

**Herramientas para experimentar:**
- `pmap` - Ver mapeo de memoria de un proceso
- `valgrind` - Detectar errores de memoria
- `/proc/[pid]/maps` - Ver regiones de memoria de un proceso
- `gdb` con comandos `info proc mappings`

---

**Este capítulo ha cubierto los fundamentos de la gestión de memoria real. El próximo paso es entender cómo estos mecanismos se extienden para soportar memoria virtual, permitiendo ejecutar programas más grandes que la RAM física disponible.**