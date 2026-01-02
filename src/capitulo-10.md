# I/O - Gestión de Dispositivos

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante será capaz de:

- Comprender la complejidad del subsistema de I/O y sus desafíos
- Identificar los diferentes tipos de dispositivos y sus características
- Comparar las técnicas de I/O: programado (polling), por interrupciones y DMA
- Analizar la estructura física de los discos magnéticos
- Calcular tiempos de acceso a disco (seek, latencia rotacional, transferencia)
- Aplicar y comparar algoritmos de scheduling de disco (FCFS, SSTF, SCAN, C-SCAN, LOOK, C-LOOK, FSCAN, N-STEP-SCAN)
- Comprender los niveles básicos de RAID (0, 1, 5) y calcular capacidades
- Explicar el rol de buffering y caching en el subsistema de I/O
- Resolver ejercicios tipo parcial sobre scheduling de disco y tiempos de acceso

---

## 1. Introducción: ¿Por qué es complejo el I/O?

En los capítulos anteriores estudiamos la gestión de procesos, memoria y file systems. Todos estos componentes **dependen críticamente** del subsistema de entrada/salida para funcionar: los procesos necesitan leer datos del disco, la memoria virtual requiere swap a disco, y los file systems almacenan archivos en dispositivos físicos.

### Desafíos del I/O

El subsistema de I/O es uno de los componentes más complejos de un sistema operativo por varias razones:

\textcolor{red!60!gray}{\textbf{Complejidad del I/O:}\\
- Enorme variedad de dispositivos: discos, teclados, impresoras, tarjetas de red, GPUs, sensores\\
- Cada dispositivo tiene interfaces y protocolos diferentes\\
- Rangos de velocidad extremadamente amplios: teclado (10 bytes/seg) vs SSD NVMe (7 GiB/seg)\\
- Necesidad de sincronización entre CPU y dispositivos lentos\\
- Confiabilidad crítica: pérdida de datos en disco es catastrófica\\
- Compatibilidad: drivers para múltiples dispositivos y versiones\\
}

**Ejemplo de diversidad:**
```
Dispositivo         Velocidad típica      Características
---------------------------------------------------------
Teclado             10-100 bytes/seg      Interactivo, impredecible
Mouse               100 bytes/seg         Interactivo, streams
Disco HDD           100-200 MiB/seg        Bloques, latencia alta
SSD SATA            500-600 MiB/seg        Bloques, latencia media
SSD NVMe            3-7 GiB/seg            Bloques, latencia baja
Tarjeta de red      100 Mbps - 100 Gbps   Paquetes, tiempo real
GPU                 100+ GiB/seg           Paralelo masivo
```

### Objetivos del Subsistema de I/O

\begin{infobox}
\emph{Subsistema de I/O:}
Conjunto de componentes del sistema operativo responsables de gestionar la comunicación entre el CPU/memoria y los dispositivos periféricos, proporcionando abstracción, eficiencia y confiabilidad.
\end{infobox}

**Objetivos principales:**

1. **Abstracción (Device Independence):** Ocultar diferencias entre dispositivos mediante interfaces uniformes
2. **Eficiencia:** Maximizar throughput y minimizar latencia
3. **Compartición:** Permitir acceso concurrente a dispositivos compartibles
4. **Protección:** Prevenir acceso no autorizado a dispositivos
5. **Manejo de errores:** Detectar y recuperarse de fallos de hardware

---

## 2. Hardware de I/O

### Tipos de Dispositivos

Los dispositivos de I/O se clasifican según varias dimensiones:

#### Por Unidad de Transferencia

**Dispositivos de Bloque:**
- Transfieren datos en bloques de tamaño fijo (típicamente 512 bytes - 4 KiB)
- Soportan acceso aleatorio (seek a cualquier bloque)
- Direccionables: cada bloque tiene una dirección
- **Ejemplos:** Discos duros (HDD), SSDs, CD-ROMs, cintas magnéticas

**Dispositivos de Carácter:**
- Transfieren datos como stream de caracteres
- Generalmente no soportan seek (solo secuencial)
- **Ejemplos:** Teclados, mice, puertos serie, impresoras

**Dispositivos de Red:**
- Categoría especial: transfieren paquetes
- No son estrictamente de bloque ni de carácter
- **Ejemplos:** Tarjetas Ethernet, WiFi, módems

#### Por Modo de Acceso

**Compartibles (Sharable):**
- Pueden ser usados por múltiples procesos concurrentemente
- Requieren sincronización
- **Ejemplos:** Discos, tarjetas de red

**Dedicados (Dedicated):**
- Solo un proceso a la vez
- **Ejemplos:** Impresoras (sin spooling), cintas magnéticas

### Controladores de Dispositivo

\begin{infobox}
\emph{Controlador de Dispositivo (Device Controller):}
Componente de hardware que actúa como interfaz entre el bus del sistema y el dispositivo físico. Contiene registros y lógica para controlar el dispositivo.
\end{infobox}

**Arquitectura típica:**

```
CPU/Memoria <---> Bus del Sistema <---> Controlador <---> Dispositivo
                                        (Controller)       (Device)
```

El controlador contiene:
- **Registros de control:** CPU escribe comandos aquí
- **Registros de estado:** CPU lee el estado del dispositivo
- **Registros de datos:** Buffers para transferencia de datos
- **Lógica interna:** Ejecuta operaciones del dispositivo

**Ejemplo - Controlador de disco:**
```
Registro de Control:  [READ|WRITE|SEEK] comando
Registro de Estado:   [BUSY|READY|ERROR] flags
Registro de Datos:    Buffer de sector (512 bytes)
Registro de Dirección: LBA (Logical Block Address)
```

\textcolor{blue!50!black}{\textbf{Nota importante:}\\
El sistema operativo NO interactúa directamente con el dispositivo físico, sino con el controlador. El driver del SO habla con el controlador mediante lectura/escritura de sus registros.\\
}

### Interfaces de I/O

**Memory-Mapped I/O:**
- Los registros del controlador se mapean a direcciones de memoria
- CPU usa instrucciones normales de memoria (LOAD/STORE)
- No requiere instrucciones especiales de I/O

**Port-Mapped I/O (I/O Aislado):**
- Espacio de direcciones separado para I/O
- CPU usa instrucciones especiales (IN/OUT en x86)
- Arquitecturas antiguas

La mayoría de los sistemas modernos usan **Memory-Mapped I/O** por simplicidad y eficiencia.

---

## 3. Técnicas de I/O

El sistema operativo puede gestionar las operaciones de I/O de tres formas principales, con trade-offs significativos en eficiencia, complejidad y uso de CPU.

### Técnica 1: I/O Programado (Polling)

**Concepto:** La CPU ejecuta un bucle que constantemente verifica el estado del dispositivo hasta que esté listo.

```c
// Pseudocódigo de I/O programado
void write_data(char *data, int size) {
    for (int i = 0; i < size; i++) {
        // Busy-wait: esperar hasta que dispositivo esté listo
        while (status_register & BUSY) {
            // Hacer nada, solo esperar (polling)
        }
        
        // Escribir el byte
        data_register = data[i];
        
        // Enviar comando de escritura
        control_register = WRITE_COMMAND;
    }
}
```

**Flujo de operación:**
1. CPU escribe comando en registro de control
2. CPU entra en bucle de polling del registro de estado
3. Cuando dispositivo está listo, CPU lee/escribe datos
4. Repetir hasta completar transferencia

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Muy simple de implementar\\
- No requiere hardware especial (interrupciones)\\
- Latencia baja para dispositivos muy rápidos\\
- Útil en sistemas embebidos simples\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- CPU completamente ocupada durante I/O (busy-waiting)\\
- Desperdicio enorme de ciclos de CPU\\
- No puede hacer multitasking mientras espera\\
- Ineficiente para dispositivos lentos\\
}

**Uso actual:** Sistemas embebidos muy simples, polling ocasional en drivers cuando se espera respuesta inmediata

### Técnica 2: I/O por Interrupciones

**Concepto:** El dispositivo interrumpe a la CPU cuando completa una operación, permitiendo que la CPU haga otras cosas mientras espera.

```c
// Pseudocódigo de I/O por interrupciones

// Función principal
void write_data_interrupt(char *data, int size) {
    buffer = data;
    count = size;
    index = 0;
    
    // Iniciar primera escritura
    data_register = buffer[index++];
    control_register = WRITE_COMMAND;
    
    // CPU retorna y puede hacer otras cosas
    // El resto lo maneja el interrupt handler
}

// Interrupt Service Routine (ISR)
void disk_interrupt_handler() {
    if (index < count) {
        // Escribir siguiente byte
        data_register = buffer[index++];
        control_register = WRITE_COMMAND;
    } else {
        // Operación completada
        signal_completion();
    }
}
```

**Flujo de operación:**
1. CPU inicia operación y retorna (no espera)
2. CPU ejecuta otros procesos
3. Dispositivo completa operación y genera interrupción
4. CPU suspende proceso actual, ejecuta ISR
5. ISR maneja el evento (leer datos, iniciar siguiente transferencia, etc.)
6. CPU retorna al proceso interrumpido

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- CPU libre para otras tareas durante I/O\\
- Eficiente para dispositivos de velocidad media\\
- Mejor utilización de CPU que polling\\
- Permite multitasking efectivo\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Overhead de context switch por cada interrupción\\
- Problemas con interrupciones de alta frecuencia (interrupt storm)\\
- CPU aún involucrada en transferencia de datos\\
- Ineficiente para transferencias grandes\\
}

**Uso actual:** Dispositivos de carácter (teclado, mouse), eventos de dispositivos de bloque (completación de comando)

### Técnica 3: DMA (Direct Memory Access)

\begin{infobox}
\emph{DMA (Direct Memory Access):}
Técnica que permite al controlador de dispositivo transferir datos directamente entre el dispositivo y la memoria RAM sin intervención de la CPU.
\end{infobox}

**Concepto:** Un controlador especializado (DMA controller) gestiona la transferencia completa de bloques de datos, liberando completamente a la CPU.

**Arquitectura con DMA:**

```
CPU <---> Bus <---> Memoria RAM
            ^
            |
            v
      DMA Controller <---> Device Controller <---> Dispositivo
```

**Flujo de operación:**

1. **CPU configura DMA:**
   - Dirección de memoria origen/destino
   - Cantidad de bytes a transferir
   - Dirección del dispositivo
   - Dirección de control (read/write)

2. **DMA ejecuta transferencia:**
   - DMA "roba" ciclos del bus (cycle stealing)
   - Transfiere datos directamente entre dispositivo y RAM
   - Incrementa punteros automáticamente

3. **DMA genera interrupción:**
   - Al completar transferencia completa
   - CPU recibe UNA interrupción (no una por byte)

**Ejemplo de uso de DMA:**

```c
// Pseudocódigo de lectura con DMA
void read_disk_dma(char *buffer, int sector, int count) {
    // Configurar DMA
    dma_source_address = DISK_DATA_REGISTER;
    dma_dest_address = buffer;
    dma_byte_count = count * SECTOR_SIZE;
    dma_mode = DEVICE_TO_MEMORY;
    
    // Configurar controlador de disco
    disk_sector = sector;
    disk_command = READ;
    
    // Iniciar DMA (retorna inmediatamente)
    dma_control = START;
    
    // CPU está libre, hacer otras cosas
    // Cuando termine, llegará una interrupción
}

// ISR cuando DMA completa
void dma_complete_interrupt() {
    // Transferencia completa
    // buffer ahora contiene los datos del disco
    wake_up_process_waiting_for_io();
}
```

**Cycle Stealing:**

\begin{infobox}
\emph{Cycle Stealing:}
Técnica donde el DMA controller temporalmente "roba" el control del bus de sistema para realizar transferencias, mientras la CPU ejecuta desde cache o espera brevemente.
\end{infobox}

```
Timeline del bus durante DMA:
CPU  CPU  DMA  CPU  CPU  DMA  CPU  DMA  DMA  CPU
|    |    |    |    |    |    |    |    |    |
└────┴────┴────┴────┴────┴────┴────┴────┴────┴──> tiempo

CPU ejecuta cuando puede acceder al bus
DMA "roba" ciclos periódicamente para transferir datos
```

\textcolor{teal!60!black}{\textbf{Ventajas de DMA:}\\
- CPU completamente libre durante transferencia\\
- Óptimo para transferencias grandes (bloques de disco)\\
- Solo UNA interrupción por operación completa\\
- Throughput muy alto\\
- Esencial para dispositivos de alta velocidad\\
}

\textcolor{red!60!gray}{\textbf{Desventajas de DMA:}\\
- Requiere hardware especializado (DMA controller)\\
- Configuración más compleja\\
- Cycle stealing puede ralentizar ligeramente la CPU\\
- No útil para transferencias muy pequeñas (overhead de setup)\\
}

**Uso actual:** Virtualmente todos los dispositivos de bloque modernos (discos, SSDs, tarjetas de red, GPUs)

### Comparación de Técnicas

| Aspecto | Polling | Interrupciones | DMA |
|---------|---------|----------------|-----|
| **CPU durante I/O** | 100% ocupada | Interrumpida por evento | Libre |
| **Interrupciones** | Ninguna | Una por transferencia | Una por bloque |
| **Overhead** | Bajo (simple) | Medio (context switch) | Alto (setup), bajo (ejecución) |
| **Throughput** | Bajo | Medio | Alto |
| **Uso de CPU** | Muy alto | Medio | Muy bajo |
| **Mejor para** | Dispositivos rápidos | Eventos y chars | Transferencias grandes |
| **Escalabilidad** | Muy mala | Media | Excelente |

**Regla práctica:**
- **Polling:** Útil si el dispositivo responde en < 100 ciclos de CPU
- **Interrupciones:** Útil para eventos y transferencias pequeñas (< 1 KiB)
- **DMA:** Obligatorio para transferencias > 1 KiB o dispositivos rápidos

---

## 4. Discos Magnéticos: Estructura y Rendimiento

Los discos duros (HDD) siguen siendo ampliamente usados para almacenamiento masivo. Comprender su estructura física es esencial para entender el rendimiento del I/O.

### Geometría del Disco

**Componentes físicos:**

```
Vista superior del disco:
        
         Brazo del actuador
              |
              v
        +----------+
        |   Head   |  (Cabeza de lectura/escritura)
        +----------+
             ||
      ===================
     |  Plato (Platter) |
     |                   |
     |    +---------+    |
     |    |  Pistas |    |  (Tracks: círculos concéntricos)
     |    +---------+    |
     |                   |
      ===================
             ||
           Motor
```

\begin{infobox}
\emph{Componentes del disco:}\\
\textbf{Plato (Platter):} Disco circular recubierto de material magnético. Un disco tiene múltiples platos.\\
\textbf{Pista (Track):} Círculo concéntrico en la superficie del plato donde se almacenan datos.\\
\textbf{Sector:} Subdivisión de una pista, unidad mínima de transferencia (típicamente 512 bytes o 4 KiB).\\
\textbf{Cilindro (Cylinder):} Conjunto de pistas en la misma posición radial en todos los platos.\\
\textbf{Cabeza (Head):} Dispositivo que lee/escribe datos magnéticamente. Hay una por superficie.\\
\end{infobox}

**Vista lateral (múltiples platos):**

```
Cabezas (Heads)
    |                    |
    v                    v
  ========================================  Plato 0, superficie 0
    Pistas alineadas = 1 Cilindro
  ========================================  Plato 0, superficie 1
    
  ========================================  Plato 1, superficie 0
  
  ========================================  Plato 1, superficie 1
    |                    |
    +----- Brazo --------+
         (se mueve todo junto)
```

**Numeración de sectores:**

Cada sector se puede direccionar por:
- **CHS (Cylinder-Head-Sector):** (cilindro, cabeza, sector) - método antiguo
- **LBA (Logical Block Addressing):** Número secuencial - método moderno

```
Ejemplo de disco:
- 1000 cilindros
- 4 cabezas (2 platos, 2 superficies c/u)
- 100 sectores por pista
- 512 bytes por sector

Capacidad total = 1000 × 4 × 100 × 512 = 204.800.000 bytes ≈ 195 MiB
```

### Tiempos de Acceso a Disco

El tiempo total para leer/escribir datos de disco se compone de tres partes:

\begin{infobox}
\emph{Tiempo de acceso total:}\\
\textbf{T\_total = T\_seek + T\_rotacional + T\_transferencia}
\end{infobox}

#### 1. Tiempo de Seek (Búsqueda)

**Definición:** Tiempo que tarda el brazo en mover las cabezas desde su posición actual hasta el cilindro destino.

```
T_seek depende de la distancia en cilindros

Valores típicos para HDD:
- Track-to-track (1 cilindro): 0.2 - 0.5 ms
- Seek promedio: 8 - 12 ms
- Full stroke (máximo): 15 - 20 ms
```

**Modelos de seek time:**
- **Lineal:** $T_{seek} = a + b \times distancia$
- **Más realista:** $T_{seek} = a + b \times \sqrt{distancia}$ (aceleración)

**Para cálculos simples:** Se suele usar el **seek promedio** (~9 ms en HDD 7200 RPM)

#### 2. Latencia Rotacional

**Definición:** Tiempo que tarda el sector deseado en rotar bajo la cabeza después del seek.

```
Un disco gira a velocidad constante (RPM = Revolutions Per Minute)

T_rotacion_completa = 60 / RPM segundos

Latencia rotacional promedio = T_rotacion_completa / 2
```

**Valores típicos:**

| RPM | Revolución completa | Latencia promedio |
|-----|---------------------|-------------------|
| 5400 | 11.1 ms | 5.55 ms |
| 7200 | 8.33 ms | 4.17 ms |
| 10000 | 6.0 ms | 3.0 ms |
| 15000 | 4.0 ms | 2.0 ms |

\textcolor{orange!70!black}{\textbf{Nota importante:}\\
La latencia rotacional NO se puede mejorar con algoritmos de scheduling. Es una limitación física del disco. Solo se puede reducir con discos más rápidos.\\
}

#### 3. Tiempo de Transferencia

**Definición:** Tiempo que tarda en transferirse los datos entre el disco y el controlador.

```
T_transferencia = (bytes a transferir) / (tasa de transferencia)

Tasa de transferencia típica:
- HDD interno SATA: 100 - 200 MiB/s
- HDD externo USB 3.0: 80 - 120 MiB/s
- SSD SATA: 500 - 600 MiB/s
- SSD NVMe: 3000 - 7000 MiB/s
```

**Ejemplo de cálculo:**

Transferir 4 KiB (un bloque) en HDD a 150 MiB/s:
```
T_transferencia = 4096 bytes / (150 × 10^6 bytes/seg)
                = 0.0000273 seg
                = 0.027 ms
```

**Observación crítica:** Para HDDs, el tiempo de transferencia es DESPRECIABLE comparado con seek y rotación.

### Ejercicio: Cálculo de Tiempo de Acceso

**Enunciado:**

Se tiene un disco duro con las siguientes características:
- Velocidad de rotación: 7200 RPM
- Seek time promedio: 9 ms
- Tasa de transferencia: 150 MiB/s
- Tamaño de sector: 4 KiB

Calcular el tiempo total para leer:

**a)** Un sector aleatorio del disco

**b)** 10 sectores consecutivos en la misma pista

**c)** 10 sectores dispersos aleatoriamente en el disco

---

**Solución:**

**Paso 1: Calcular componentes base**

```
Latencia rotacional promedio:
T_rot = (60 / 7200) / 2 = 0.00833 / 2 = 0.00417 seg = 4.17 ms

Tiempo de transferencia por sector:
T_trans_sector = 4096 bytes / (150 × 10^6 bytes/seg) = 0.000027 seg ≈ 0.027 ms
```

**a) Un sector aleatorio:**

```
T_total = T_seek + T_rot + T_trans
        = 9 ms + 4.17 ms + 0.027 ms
        = 13.197 ms ≈ 13.2 ms
```

**b) 10 sectores consecutivos en la misma pista:**

Después del primer seek, los sectores están contiguos:
```
T_total = T_seek + T_rot + (10 × T_trans_sector)
        = 9 ms + 4.17 ms + (10 × 0.027 ms)
        = 9 ms + 4.17 ms + 0.27 ms
        = 13.44 ms
```

\textcolor{blue!50!black}{\textbf{Observación:}\\
Leer 10 sectores consecutivos es apenas más lento que leer 1 sector (13.44 ms vs 13.2 ms) porque el seek y la rotación dominan completamente.\\
}

**c) 10 sectores dispersos aleatoriamente:**

Cada sector requiere seek + rotación + transferencia:
```
T_total = 10 × (T_seek + T_rot + T_trans_sector)
        = 10 × 13.2 ms
        = 132 ms
```

**Resumen comparativo:**

| Operación | Tiempo total |
|-----------|--------------|
| 1 sector aleatorio | 13.2 ms |
| 10 sectores consecutivos | 13.44 ms (1.02× más lento) |
| 10 sectores dispersos | 132 ms (10× más lento) |

\textcolor{teal!60!black}{\textbf{Conclusión crítica:}\\
La localidad espacial es FUNDAMENTAL para el rendimiento de discos. Leer bloques consecutivos es órdenes de magnitud más rápido que accesos aleatorios.\\
}

---

## 5. Scheduling de I/O: Algoritmos de Disco

Los sistemas operativos mantienen una **cola de solicitudes de I/O** pendientes. El orden en que se atienden estas solicitudes impacta dramáticamente el rendimiento.

\begin{infobox}
\emph{Disk Scheduling:}
Algoritmos que determinan el orden en que se atienden las solicitudes de I/O a disco, con el objetivo de minimizar el seek time total y maximizar el throughput.
\end{infobox}

**Escenario típico:**

```
Cola de solicitudes pendientes: [98, 183, 37, 122, 14, 124, 65, 67]
Posición actual de la cabeza: cilindro 53
Rango del disco: 0 - 199 cilindros
```

El objetivo es minimizar el **movimiento total del brazo** (suma de distancias recorridas).

### Algoritmo 1: FCFS (First-Come, First-Served)

**Concepto:** Atender las solicitudes en el orden de llegada (FIFO).

**Secuencia:**
```
Orden: 53 → 98 → 183 → 37 → 122 → 14 → 124 → 65 → 67

Movimiento total:
|98-53| + |183-98| + |37-183| + |122-37| + |14-122| + |124-14| + |65-124| + |67-65|
= 45 + 85 + 146 + 85 + 108 + 110 + 59 + 2
= 640 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Muy simple de implementar (cola FIFO)\\
- Justo: todas las solicitudes se atienden en orden\\
- No hay starvation\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- No optimiza el movimiento del brazo\\
- Movimiento total muy alto (ida y vuelta constante)\\
- Rendimiento muy pobre\\
}

**Uso:** Casi nunca en sistemas reales

### Algoritmo 2: SSTF (Shortest Seek Time First)

**Concepto:** Atender primero la solicitud más cercana a la posición actual (greedy).

**Secuencia:**
```
Inicio en 53:
  Más cercano: 65 (distancia 12)
Desde 65:
  Más cercano: 67 (distancia 2)
Desde 67:
  Más cercano: 37 (distancia 30)
Desde 37:
  Más cercano: 14 (distancia 23)
Desde 14:
  Más cercano: 98 (distancia 84)
Desde 98:
  Más cercano: 122 (distancia 24)
Desde 122:
  Más cercano: 124 (distancia 2)
Desde 124:
  Más cercano: 183 (distancia 59)

Orden: 53 → 65 → 67 → 37 → 14 → 98 → 122 → 124 → 183

Movimiento total:
12 + 2 + 30 + 23 + 84 + 24 + 2 + 59 = 236 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Reduce significativamente el movimiento total\\
- Throughput mejor que FCFS\\
- Intuitivo y fácil de implementar\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- PUEDE causar starvation: solicitudes en extremos pueden esperar indefinidamente\\
- Si llegan solicitudes constantemente en el centro, las de los extremos nunca se atienden\\
- No es óptimo globalmente (greedy local)\\
}

**Uso:** Común en sistemas con baja carga de I/O

### Algoritmo 3: SCAN (Elevator Algorithm)

**Concepto:** El brazo se mueve en una dirección hasta el final, atendiendo todas las solicitudes en el camino, luego invierte la dirección.

**Secuencia (asumiendo dirección inicial hacia arriba):**
```
Inicio en 53, dirección UP:
  Atender: 65, 67, 98, 122, 124, 183
  Llegar al final (199)
  Cambiar dirección a DOWN:
  Atender: 37, 14

Orden: 53 → 65 → 67 → 98 → 122 → 124 → 183 → 199 → 37 → 14

Movimiento total:
|65-53| + |67-65| + |98-67| + |122-98| + |124-122| + |183-124| + |199-183| + |37-199| + |14-37|
= 12 + 2 + 31 + 24 + 2 + 59 + 16 + 162 + 23
= 331 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- No hay starvation: eventualmente pasa por todos los cilindros\\
- Movimiento más predecible que SSTF\\
- Buen throughput\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Movimiento innecesario hasta el final del disco\\
- Latencia no uniforme: solicitudes recién llegadas en dirección opuesta esperan más\\
}

**Uso:** Ascensores reales, algunos sistemas operativos antiguos

### Algoritmo 4: C-SCAN (Circular SCAN)

**Concepto:** Como SCAN, pero al llegar al final, salta inmediatamente al inicio sin atender solicitudes en el camino de vuelta.

**Secuencia:**
```
Inicio en 53, dirección UP:
  Atender: 65, 67, 98, 122, 124, 183
  Llegar al final (199)
  Saltar al inicio (0) sin atender
  Continuar UP:
  Atender: 14, 37

Orden: 53 → 65 → 67 → 98 → 122 → 124 → 183 → 199 → 0 → 14 → 37

Movimiento total:
|65-53| + |67-65| + |98-67| + |122-98| + |124-122| + |183-124| + |199-183| + |199-0| + |14-0| + |37-14|
= 12 + 2 + 31 + 24 + 2 + 59 + 16 + 199 + 14 + 23
= 382 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Latencia más uniforme que SCAN\\
- Trata a todos los cilindros más equitativamente\\
- No hay starvation\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Movimiento total mayor que SCAN\\
- Salto al inicio es desperdicio de movimiento\\
}

**Uso:** Sistemas con alta carga de I/O donde se prioriza fairness

### Algoritmo 5: LOOK

**Concepto:** Como SCAN, pero solo va hasta la última solicitud en esa dirección (no hasta el final del disco).

**Secuencia:**
```
Inicio en 53, dirección UP:
  Atender: 65, 67, 98, 122, 124, 183
  (183 es la última solicitud UP, no ir hasta 199)
  Cambiar dirección a DOWN:
  Atender: 37, 14

Orden: 53 → 65 → 67 → 98 → 122 → 124 → 183 → 37 → 14

Movimiento total:
12 + 2 + 31 + 24 + 2 + 59 + 146 + 23 = 299 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Elimina movimiento innecesario de SCAN\\
- Mejor throughput que SCAN\\
- Sigue sin starvation\\
}

**Uso:** Versión mejorada de SCAN, más usado en práctica

### Algoritmo 6: C-LOOK (Circular LOOK)

**Concepto:** Como C-SCAN, pero solo va hasta la última solicitud y salta a la primera solicitud (no a los extremos absolutos).

**Secuencia:**
```
Inicio en 53, dirección UP:
  Atender: 65, 67, 98, 122, 124, 183
  (183 es la última UP)
  Saltar a la primera solicitud pendiente: 14
  Continuar UP:
  Atender: 14, 37

Orden: 53 → 65 → 67 → 98 → 122 → 124 → 183 → 14 → 37

Movimiento total:
12 + 2 + 31 + 24 + 2 + 59 + 169 + 23 = 322 cilindros
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Combina ventajas de C-SCAN y LOOK\\
- Latencia uniforme\\
- Sin movimiento innecesario\\
}

**Uso:** Variante popular en sistemas Linux

### Algoritmo 7: FSCAN (Freeze SCAN)

**Concepto:** Divide la cola en dos sublistas. Procesa una lista con SCAN mientras congela (freeze) las nuevas solicitudes en la segunda lista.

**Funcionamiento:**
```
1. Al inicio: todas las solicitudes actuales van a Queue1
2. Ejecutar SCAN sobre Queue1
3. Nuevas solicitudes que llegan durante SCAN van a Queue2 (congeladas)
4. Al terminar Queue1, intercambiar: Queue2 se vuelve Queue1
5. Repetir
```

**Ejemplo:**
```
Queue1 inicial: [98, 183, 37, 122, 14, 124, 65, 67]
Ejecutar SCAN sobre Queue1: 53 → 65 → 67 → 98 → ... → 183 → 37 → 14

Durante este SCAN, llegan solicitudes [50, 175, 80]
Estas van a Queue2 (esperan al siguiente ciclo)

Al terminar Queue1:
  Queue2 se vuelve Queue1: [50, 175, 80]
  Ejecutar SCAN sobre estos
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Previene starvation de solicitudes lejanas\\
- Tiempo de espera acotado: máximo 2 ciclos de SCAN\\
- Mejor fairness que SCAN simple\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Más complejo de implementar (dos colas)\\
- Latencia puede ser mayor para solicitudes nuevas\\
}

**Uso:** Sistemas que requieren garantías de tiempo de respuesta

### Algoritmo 8: N-STEP-SCAN

**Concepto:** Similar a FSCAN, pero la cola se divide en sublistas de máximo N solicitudes.

**Funcionamiento:**
```
1. Cola actual tiene solicitudes: [r1, r2, r3, ..., rK]
2. Dividir en grupos de máximo N:
   - Grupo1: [r1, ..., rN]
   - Grupo2: [rN+1, ..., r2N]
   - ...
3. Ejecutar SCAN sobre Grupo1
4. Nuevas solicitudes van a cola futura
5. Al terminar Grupo1, procesar Grupo2
6. Repetir
```

**Ejemplo con N=5:**
```
Cola: [98, 183, 37, 122, 14, 124, 65, 67, 50, 175]

Grupo1: [98, 183, 37, 122, 14]  → Ejecutar SCAN
Grupo2: [124, 65, 67, 50, 175]  → Espera

Al terminar Grupo1, procesar Grupo2
Nuevas solicitudes forman Grupo3
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Limita el tamaño del batch (N)\\
- Tiempo de espera más predecible que FSCAN\\
- Configurable: N pequeño = más responsive, N grande = más throughput\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Requiere tuning del parámetro N\\
- Implementación compleja\\
}

**Uso:** Sistemas de tiempo real donde se necesita acotar latencias

### Comparación de Algoritmos

| Algoritmo | Movimiento (ejemplo) | Starvation | Fairness | Complejidad |
|-----------|---------------------|------------|----------|-------------|
| FCFS | 640 | No | Perfecta | Muy baja |
| SSTF | 236 | Sí (posible) | Mala | Baja |
| SCAN | 331 | No | Media | Media |
| C-SCAN | 382 | No | Buena | Media |
| LOOK | 299 | No | Media | Media |
| C-LOOK | 322 | No | Buena | Media |
| FSCAN | ~300 | No | Buena | Alta |
| N-STEP | ~300 | No | Muy buena | Alta |

**Recomendaciones:**
- **SSTF:** Sistemas con baja carga, prioridad en throughput
- **LOOK/C-LOOK:** Default en muchos sistemas modernos (buen balance)
- **FSCAN/N-STEP:** Sistemas de tiempo real o con garantías de latencia

---

## 6. Ejercicio Integrador: Scheduling de Disco

**Enunciado:**

Un disco tiene 200 cilindros (0-199). La cola de solicitudes contiene:
```
Solicitudes: [95, 180, 34, 119, 11, 123, 62, 64]
Posición actual de la cabeza: 50
Dirección inicial: hacia arriba (UP)
```

Calcular el **movimiento total del brazo** para cada algoritmo:

a) FCFS
b) SSTF
c) SCAN
d) C-SCAN
e) LOOK
f) C-LOOK

**Indicar también cuál algoritmo es más eficiente en este caso.**

---

**Solución:**

**a) FCFS:**

```
Secuencia: 50 → 95 → 180 → 34 → 119 → 11 → 123 → 62 → 64

Movimiento:
|95-50| + |180-95| + |34-180| + |119-34| + |11-119| + |123-11| + |62-123| + |64-62|
= 45 + 85 + 146 + 85 + 108 + 112 + 61 + 2
= 644 cilindros
```

**b) SSTF:**

```
Desde 50, elegir más cercano:
50 → 62 (12) → 64 (2) → 34 (30) → 11 (23) → 95 (84) → 119 (24) → 123 (4) → 180 (57)

Movimiento total:
12 + 2 + 30 + 23 + 84 + 24 + 4 + 57 = 236 cilindros
```

**c) SCAN:**

```
Desde 50, dirección UP, atender todas hasta el final, luego DOWN:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 199 (fin) → 34 → 11

Movimiento:
|62-50| + |64-62| + |95-64| + |119-95| + |123-119| + |180-123| + |199-180| + |34-199| + |11-34|
= 12 + 2 + 31 + 24 + 4 + 57 + 19 + 165 + 23
= 337 cilindros
```

**d) C-SCAN:**

```
Desde 50, UP hasta el final, saltar al inicio, continuar UP:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 199 → 0 (salto) → 11 → 34

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 19 + 199 + 11 + 23 = 382 cilindros
```

**e) LOOK:**

```
Desde 50, UP hasta última solicitud (180), luego DOWN:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 34 → 11

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 146 + 23 = 299 cilindros
```

**f) C-LOOK:**

```
Desde 50, UP hasta 180, saltar a primera solicitud pendiente (11), continuar UP:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 11 (salto) → 34

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 169 + 23 = 322 cilindros
```

**Resumen:**

| Algoritmo | Movimiento total |
|-----------|------------------|
| FCFS | 644 |
| SSTF | 236 ⭐ |
| SCAN | 337 |
| C-SCAN | 382 |
| LOOK | 299 |
| C-LOOK | 322 |

\textcolor{blue!50!black}{\textbf{Respuesta:}\\
El algoritmo más eficiente en este caso es \textbf{SSTF} con 236 cilindros de movimiento. Sin embargo, SSTF puede causar starvation. El mejor balance eficiencia/fairness lo ofrece \textbf{LOOK} con 299 cilindros.\\
}

---

## 7. RAID (Redundant Array of Independent Disks)

RAID es una técnica que combina múltiples discos físicos en una unidad lógica para mejorar rendimiento, confiabilidad, o ambos.

\begin{infobox}
\emph{RAID:}
Tecnología que utiliza múltiples discos trabajando en conjunto para proporcionar mayor rendimiento (mediante paralelismo) y/o mayor confiabilidad (mediante redundancia).
\end{infobox}

### RAID 0: Striping (sin redundancia)

**Concepto:** Los datos se dividen en bloques que se distribuyen (stripe) entre todos los discos.

```
Archivo dividido en bloques: A1, A2, A3, A4, A5, A6

Disco 0: [A1] [A3] [A5]
Disco 1: [A2] [A4] [A6]

Lectura/escritura en paralelo
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Rendimiento máximo: throughput se multiplica por N discos\\
- Capacidad total = suma de todos los discos\\
- Simple de implementar\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- CERO redundancia: falla de un disco = pérdida total de datos\\
- Menos confiable que un disco individual\\
}

**Cálculos:**
```
N discos de C capacidad cada uno:
Capacidad útil = N × C
Rendimiento lectura/escritura = N × velocidad_disco
```

**Ejemplo:**
- 4 discos de 1 TiB cada uno
- Capacidad útil: 4 TiB
- Si 1 disco falla: pérdida total

**Uso:** Aplicaciones que requieren máximo rendimiento y tienen backups externos (edición de video, caches)

### RAID 1: Mirroring (espejo completo)

**Concepto:** Cada dato se duplica completamente en dos (o más) discos.

```
Archivo: A1, A2, A3, A4

Disco 0: [A1] [A2] [A3] [A4]
Disco 1: [A1] [A2] [A3] [A4]  (copia exacta)
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Confiabilidad alta: tolera falla de N-1 discos\\
- Rendimiento de lectura mejorado (leer de cualquier disco)\\
- Recuperación simple: disco espejo es copia exacta\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Capacidad útil = 50 por ciento (mitad se usa para espejo)\\
- Costo alto: necesitas el doble de discos\\
- Escritura no más rápida (debe escribir en ambos)\\
}

**Cálculos:**
```
N discos de C capacidad cada uno (N par):
Capacidad útil = (N / 2) × C = C (con 2 discos)
Tolerancia a fallos = N/2 discos pueden fallar
```

**Ejemplo:**
- 2 discos de 1 TiB cada uno
- Capacidad útil: 1 TiB
- Si 1 disco falla: datos siguen accesibles

**Uso:** Datos críticos (bases de datos, servidores), donde la confiabilidad es prioritaria

### RAID 5: Striping con Paridad Distribuida

**Concepto:** Los datos y la paridad se distribuyen entre todos los discos. La paridad permite reconstruir datos si falla un disco.

```
4 discos, bloques A1-A6:

Disco 0: [A1] [A4] [Parity(A5,A6)]
Disco 1: [A2] [Parity(A3,A4)] [A6]
Disco 2: [A3] [A5] [Parity(A1,A2)]
Disco 3: [Parity(A1,A2,A3)] [A6] [...]

Paridad se calcula con XOR
```

**Cálculo de Paridad con XOR:**

\begin{infobox}
\emph{XOR (Exclusive OR):}
Operación bit a bit donde el resultado es 1 si los bits son diferentes, 0 si son iguales.
\end{infobox}

```
Ejemplo simple:
Bloque A1 = 10110101
Bloque A2 = 11001100
Bloque A3 = 01010011

Paridad = A1 XOR A2 XOR A3
        = 10110101 XOR 11001100 XOR 01010011
        = 00101110

Si falla disco con A2, recuperar:
A2 = A1 XOR A3 XOR Paridad
   = 10110101 XOR 01010011 XOR 00101110
   = 11001100 ✓ (recuperado)
```

**Propiedad clave del XOR:** `A XOR B XOR C XOR ... XOR Parity = 0`, por lo tanto cualquier elemento puede recuperarse.

**Tabla de verdad XOR:**
```
A | B | A XOR B
--|---|-------
0 | 0 |   0
0 | 1 |   1
1 | 0 |   1
1 | 1 |   0
```

**Ejemplo numérico completo:**

Supongamos 3 discos de datos en RAID 5:
```
Disco 0: 11010110
Disco 1: 10100101
Disco 2: 01110011

Calcular paridad:
Paridad = D0 XOR D1 XOR D2
        = 11010110 XOR 10100101 XOR 01110011
        
Paso a paso:
  11010110
XOR 10100101
-----------
  01110011
XOR 01110011
-----------
  00000000  ← Paridad (Disco 3)

Si falla Disco 1, recuperar:
D1 = D0 XOR D2 XOR Paridad
   = 11010110 XOR 01110011 XOR 00000000
   = 10100101 ✓
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Buena capacidad: (N-1)/N de espacio útil\\
- Tolerancia a fallos: 1 disco puede fallar\\
- Rendimiento de lectura excelente (paralelismo)\\
- Más eficiente que RAID 1 en espacio\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Escritura más lenta (debe calcular y actualizar paridad)\\
- Recuperación lenta ante falla\\
- NO tolera falla de 2 discos simultáneos\\
}

**Cálculos:**
```
N discos de C capacidad cada uno (N ≥ 3):
Capacidad útil = (N - 1) × C
Espacio para paridad = 1 × C (distribuido)
Tolerancia a fallos = 1 disco
```

**Ejemplo:**
- 4 discos de 1 TiB cada uno
- Capacidad útil: 3 TiB (75%)
- Espacio de paridad: 1 TiB
- Si 1 disco falla: datos recuperables
- Si 2 discos fallan: pérdida total

**Uso:** Servidores, NAS, almacenamiento empresarial (balance entre rendimiento, capacidad y confiabilidad)

### Comparación de RAID

| Nivel | Discos mín | Capacidad útil | Tolerancia fallos | Rendimiento lectura | Rendimiento escritura | Uso típico |
|-------|-----------|----------------|-------------------|---------------------|----------------------|------------|
| RAID 0 | 2 | N × C | 0 | Excelente (N×) | Excelente (N×) | Edición video, cache |
| RAID 1 | 2 | C (50%) | N-1 | Bueno (N×) | Normal (1×) | Datos críticos |
| RAID 5 | 3 | (N-1) × C | 1 | Excelente | Medio (paridad) | Servidores, NAS |

**Nota sobre RAID 6:**  
RAID 6 es similar a RAID 5 pero con doble paridad (P y Q), tolerando falla de 2 discos.  
$Capacidad útil = (N-2) × C$. Más lento en escritura pero más seguro.  
Uso: almacenamiento empresarial crítico.

---

## 8. Buffering y Caching

### Buffering

\begin{infobox}
\emph{Buffer:}
Área de memoria temporal usada para almacenar datos durante transferencias entre componentes de diferente velocidad o cuando hay desincronización temporal.
\end{infobox}

**Tipos de buffering:**

**1. Simple Buffer:**
```
Productor → [Buffer] → Consumidor

Mientras Productor llena el buffer, Consumidor espera
Cuando buffer está lleno, Productor espera mientras Consumidor procesa
```

**Problema:** Solo uno puede trabajar a la vez (no hay concurrencia)

**2. Double Buffering:**
```
Productor → [Buffer 1] ⟷ Consumidor
              [Buffer 2]

Mientras Consumidor procesa Buffer 1,
Productor llena Buffer 2

Luego intercambian (swap)
```

\textcolor{teal!60!black}{\textbf{Ventaja:}\\
Permite overlap: Productor y Consumidor trabajan en paralelo, mejorando throughput significativamente\\
}

**Ejemplo numérico:**
```
Con simple buffer:
  Tiempo_llenar = 10ms
  Tiempo_procesar = 15ms
  Tiempo_total_por_buffer = 25ms
  
Con double buffer:
  Ambos trabajan en paralelo
  Tiempo_total = max(10ms, 15ms) = 15ms por buffer
  Mejora = 25/15 = 1.67× más rápido
```

**3. Circular Buffer (Ring Buffer):**
```
   [B0] → [B1] → [B2] → [B3]
     ↑                     ↓
   [B7] ← [B6] ← [B5] ← [B4]

Producer escribe en write_ptr
Consumer lee desde read_ptr
Ambos avanzan circularmente
```

**Gestión del ring buffer:**
```c
#define BUFFER_SIZE 8
char buffer[BUFFER_SIZE];
int write_ptr = 0;
int read_ptr = 0;
int count = 0;  // Elementos en buffer

// Productor escribe
void produce(char data) {
    while (count == BUFFER_SIZE);  // Buffer lleno, esperar
    buffer[write_ptr] = data;
    write_ptr = (write_ptr + 1) % BUFFER_SIZE;
    count++;
}

// Consumidor lee
char consume() {
    while (count == 0);  // Buffer vacío, esperar
    char data = buffer[read_ptr];
    read_ptr = (read_ptr + 1) % BUFFER_SIZE;
    count--;
    return data;
}
```

\textcolor{teal!60!black}{\textbf{Ventajas del ring buffer:}\\
- Múltiples buffers permiten mayor concurrencia\\
- Suaviza ráfagas (bursts) de datos\\
- Usado extensivamente en drivers de red y audio\\
}

**Uso de buffering:**

Disco → memoria (buffer cache)
Tarjeta de red → memoria (ring buffers para paquetes)
Teclado → aplicación (input buffer)
Audio/video streaming (evita stuttering)

### Caching
\begin{infobox}
\emph{Cache:}
Copia de datos frecuentemente accedidos almacenada en un medio más rápido para acelerar accesos futuros.
\end{infobox}

### Diferencia buffer vs cache:

Buffer: Almacenamiento temporal durante transferencia (datos en tránsito, una sola copia)  
Cache: Copia de datos para acceso rápido (datos duplicados, permanecen en origen)  

### Ejemplo - Buffer cache del SO:
```
Aplicación solicita read(fd, buffer, 4096)

1. SO verifica buffer cache:
   - ¿Bloque ya en cache? → Retornar inmediatamente (cache hit)
   - ¿No en cache? → Leer de disco y cachear (cache miss)

2. Al escribir write(fd, buffer, 4096):
   - Escribir en cache (write-back)
   - Marcar como "dirty"
   - Eventualmente flush a disco (asíncrono)
```

**Beneficios del buffer cache:**

- Reduce accesos a disco (órdenes de magnitud más rápido)\
- Permite write coalescing: múltiples escrituras pequeñas se agrupan\
- Mejora throughput general del sistema\
- Hit rate típico: 85-95 por ciento en sistemas con suficiente RAM\


### Políticas de reemplazo de cache:

- LRU (Least Recently Used): Reemplazar bloque menos usado recientemente
- LFU (Least Frequently Used): Reemplazar bloque menos usado en total
- Clock: Aproximación eficiente de LRU

### Spooling
\begin{infobox}
\emph{Spooling (Simultaneous Peripheral Operations On-Line):}
Técnica donde se almacena la salida de varios procesos en disco antes de enviarla a un dispositivo lento (como impresora).
\end{infobox}

### Ejemplo - Print spooler:
```
Proceso 1 --→ |
Proceso 2 --→ | Spool Directory (disco) → Print Daemon → Impresora
Proceso 3 --→ |

Cada proceso escribe su documento al spool inmediatamente (rápido)
Print daemon envía a impresora secuencialmente (lento)
```

**Ventaja:** Los procesos no esperan a que termine la impresión (pueden continuar inmediatamente)
**Ubicación típica en Linux:** /var/spool/cups/ para impresoras

## Caso de Estudio: I/O en Linux
### Arquitectura de I/O en Linux
Linux implementa un subsistema de I/O en capas:
```
Aplicación
    |
  syscall (read, write, ioctl)
    |
VFS (Virtual File System)
    |
File System Driver (ext4, FAT, etc.)
    |
Block Layer / Page Cache
    |
Device Driver (SCSI, SATA, NVMe)
    |
Hardware Controller
    |
Dispositivo Físico
```

### Archivos Especiales en /dev
Linux representa dispositivos como archivos especiales en `/dev`:
```
$ ls -l /dev/
brw-rw---- 1 root disk 8,  0 Dec 30 10:00 sda   # Disco completo
brw-rw---- 1 root disk 8,  1 Dec 30 10:00 sda1  # Partición 1
brw-rw---- 1 root disk 8,  2 Dec 30 10:00 sda2  # Partición 2
crw-rw-rw- 1 root tty  5,  0 Dec 30 10:00 tty   # Terminal
crw------- 1 root root 10, 1 Dec 30 10:00 psaux # Mouse PS/2
```

**Tipos de archivos especiales:**
- `b` (block): Dispositivos de bloque (discos, particiones)
- `c` (character): Dispositivos de carácter (terminales, puertos serie)

**Major y Minor numbers:**
```
brw-rw---- 1 root disk 8, 1 Dec 30 10:00 sda1
                         ^  ^
                         |  |
                    Major  Minor

Major number: identifica el driver (8 = SCSI/SATA disk)
Minor number: identifica el dispositivo específico (1 = primera partición)
```
### Schedulers de I/O en Linux

Linux provee varios schedulers de disco que se pueden cambiar dinámicamente:

**CFQ (Completely Fair Queuing):**
- Default en kernels antiguos
- Similar a round-robin entre procesos
- Busca fairness

**Deadline:**
- Garantiza tiempo máximo de espera
- Usa read deadline y write deadline
- Bueno para sistemas de tiempo real

**Noop (No Operation):**
- Solo merge de requests consecutivos
- Mínimo overhead
- Óptimo para SSDs (que no tienen seek time)

**mq-deadline / BFQ / Kyber:**
- Schedulers modernos para dispositivos multi-cola (NVMe)
- Aprovechan paralelismo de SSDs modernos

```bash
# Ver scheduler actual
$ cat /sys/block/sda/queue/scheduler
[mq-deadline] kyber bfq none

# Cambiar scheduler
$ echo bfq > /sys/block/sda/queue/scheduler
```

### ioctl: Operaciones Específicas de Dispositivo

\begin{infobox}
\emph{ioctl (Input/Output Control):}
Syscall que permite ejecutar operaciones específicas de un dispositivo que no son read/write estándar.
\end{infobox}

**Ejemplo conceptual:**
```c
#include <sys/ioctl.h>

int fd = open("/dev/sda", O_RDONLY);

// Obtener tamaño del disco
unsigned long long size;
ioctl(fd, BLKGETSIZE64, &size);
printf("Disk size: %llu bytes\n", size);

// Obtener tamaño de bloque
int block_size;
ioctl(fd, BLKBSZGET, &block_size);
printf("Block size: %d bytes\n", block_size);

close(fd);
```

**Uso típico de ioctl:**
- Configurar baudrate en puerto serie
- Cambiar resolución de terminal
- Obtener información de geometría de disco
- Controlar dispositivos especializados

---

## 10. Síntesis y Puntos Clave

### Conceptos Fundamentales

1. **Complejidad del I/O**
   - Enorme diversidad de dispositivos (velocidades, interfaces, protocolos)
   - Rangos de velocidad: 6 órdenes de magnitud (teclado vs SSD NVMe)
   - Necesidad de abstracción (device independence)

2. **Clasificación de dispositivos**
   - **Por transferencia:** Bloque, Carácter, Red
   - **Por acceso:** Compartibles, Dedicados
   - **Controladores:** Interfaz entre bus y dispositivo físico

3. **Técnicas de I/O**
   - **Polling:** CPU espera activamente (busy-wait) → simple pero ineficiente
   - **Interrupciones:** Dispositivo avisa cuando termina → mejor uso de CPU
   - **DMA:** Transferencia directa sin CPU → óptimo para bloques grandes

### Estructura del Disco

4. **Geometría física**
   - **Plato → Pista → Sector** (512B o 4KiB)
   - **Cilindro:** Pistas alineadas verticalmente
   - **Cabeza:** Una por superficie (se mueven juntas)

5. **Tiempo de acceso = Seek + Rotacional + Transferencia**
   ```
   T_seek:         8-12 ms (promedio en HDD)
   T_rotacional:   4.17 ms (promedio a 7200 RPM)
   T_transferencia: ~0.03 ms por sector (despreciable)
   
   Conclusión: Seek y rotación DOMINAN el tiempo
   ```

6. **Localidad espacial es crítica**
   - Leer 10 sectores consecutivos: ~13 ms
   - Leer 10 sectores dispersos: ~130 ms (10× más lento)

### Scheduling de Disco

7. **Objetivo:** Minimizar movimiento del brazo (seek time)

8. **Algoritmos básicos:**
   - **FCFS:** Simple, justo, pero ineficiente (no optimiza movimiento)
   - **SSTF:** Greedy, mejor throughput, pero puede causar starvation

9. **Algoritmos tipo SCAN:**
   - **SCAN:** Elevator, va hasta el final y vuelve
   - **C-SCAN:** Circular, más fair (vuelve al inicio sin atender)
   - **LOOK:** Solo hasta última solicitud (no hasta extremo)
   - **C-LOOK:** Combinación óptima en práctica

10. **Algoritmos avanzados:**
    - **FSCAN:** Congela cola durante SCAN → previene starvation
    - **N-STEP-SCAN:** Procesa máximo N solicitudes por vez → latencia acotada

### Fórmulas Clave

11. **Latencia rotacional promedio:**
    ```
    T_rot_avg = (60 / RPM) / 2 segundos
    
    7200 RPM: 4.17 ms
    10000 RPM: 3.0 ms
    ```

12. **Movimiento en algoritmos:**
    - Sumar distancias absolutas entre cilindros consecutivos
    - SSTF típicamente da 60-70% del movimiento de FCFS
    - LOOK es 10-20% mejor que SCAN

### RAID

13. **RAID 0 (Striping):**
    ```
    Capacidad: N × C
    Tolerancia: 0 discos
    Uso: Máximo rendimiento, datos no críticos
    ```

14. **RAID 1 (Mirroring):**
    ```
    Capacidad: C (50%)
    Tolerancia: N-1 discos
    Uso: Datos críticos, alta confiabilidad
    ```

15. **RAID 5 (Paridad distribuida):**
    ```
    Capacidad: (N-1) × C
    Tolerancia: 1 disco
    Paridad: XOR permite reconstrucción
    Uso: Balance rendimiento/capacidad/confiabilidad
    ```

16. **Propiedad XOR para recuperación:**
    ```
    Si A XOR B XOR C = Paridad
    Entonces: A = B XOR C XOR Paridad
    ```

### Software de I/O

17. **Buffering:**
    - **Simple:** Un buffer, productor/consumidor se bloquean
    - **Doble:** Overlap, uno se llena mientras otro se procesa
    - **Circular:** N buffers en anillo, máximo throughput

18. **Caching vs Buffering:**
    - **Buffer:** Datos en tránsito (temporal)
    - **Cache:** Copia para acceso rápido (duplicado)
    - **Buffer cache del SO:** Mejora dramáticamente rendimiento de disco

19. **Device Independence:**
    - Aplicación usa interfaz uniforme (read/write)
    - Driver específico maneja hardware particular
    - VFS en Linux abstrae diferentes file systems

20. **Capas del subsistema I/O:**  

  ```
  Aplicación
    | syscall
  File System
    |
  Block Layer / Cache
    |
  Device Driver
    |
  Hardware Controller
    |
  Dispositivo
  ```


## 11. Preparación para Parcial

### Temas de Alta Probabilidad

1. **Comparación de técnicas de I/O:**
   - Polling vs Interrupciones vs DMA
   - Ventajas/desventajas de cada una
   - Cuándo usar cada técnica

2. **Cálculo de tiempos de acceso:**
   - Dado RPM, seek time, calcular tiempo total
   - Diferencia entre acceso secuencial vs aleatorio
   - Impacto de localidad espacial

3. **Ejercicio de scheduling de disco:**
   - Aplicar 4-6 algoritmos a una cola dada
   - Calcular movimiento total del brazo
   - Comparar eficiencia y fairness

4. **RAID:**
   - Calcular capacidad útil dados N discos
   - Tolerancia a fallos de cada nivel
   - Ventajas/desventajas de RAID 0, 1, 5

5. **Conceptos teóricos:**
   - Definir: buffer, cache, spooling, DMA, cylinder
   - Diferencia bloque vs carácter
   - Por qué I/O es complejo

### Estrategia para Ejercicios de Scheduling

**Paso 1:** Escribir datos del problema
```
Cola: [solicitudes]
Posición inicial: X
Dirección inicial (si aplica): UP/DOWN
Rango disco: [0, MAX]
```

**Paso 2:** Para cada algoritmo, dibujar la secuencia
```
Ejemplo SSTF desde 50:
50 → 62 (más cercano) → 64 → ...

Anotar distancia en cada salto
```

**Paso 3:** Sumar distancias
```
Movimiento = |A-B| + |B-C| + |C-D| + ...
```

**Paso 4:** Comparar resultados
- Identificar algoritmo más eficiente (menor movimiento)
- Identificar algoritmo más fair (sin starvation)
- Balance: LOOK/C-LOOK suelen ser óptimos

### Errores Comunes a Evitar

- Confundir seek time con latencia rotacional
```
Seek = movimiento del brazo (cambia cilindros)
Rotacional = espera a que pase el sector (fijo por RPM)
```

- En SCAN/C-SCAN, olvidar ir hasta el extremo
```
SCAN va hasta 199 (o 0), no hasta última solicitud
LOOK va solo hasta última solicitud
```

- En C-SCAN/C-LOOK, no contar el salto al inicio
```
C-SCAN: movimiento incluye |MAX-pos| + |MAX-0| + |primera_solicitud-0|
El salto de MAX a 0 SÍ cuenta como movimiento
```

- Calcular mal capacidad en RAID 5
```
Correcto: (N-1) × C
Incorrecto: N × C (olvidan el disco de paridad)
```

- Confundir buffer con cache
```
Buffer: temporal durante transferencia (tránsito)
Cache: copia para acceso rápido (duplicado)
```

- No considerar que DMA usa cycle stealing
```
DMA "roba" ciclos del bus periódicamente
CPU puede ralentizarse ligeramente (pero sigue siendo mejor que interrupciones)
```

- Pensar que SSTF es siempre óptimo
```
SSTF puede causar starvation
LOOK/C-LOOK son mejor balance en la práctica
```

### Tips para Ejercicios Numéricos

**Cálculo de tiempos:**
1. Separar claramente: seek, rotacional, transferencia
2. Usar unidades consistentes (ms típicamente)
3. Recordar: transferencia suele ser despreciable en HDD
4. Para múltiples sectores consecutivos: solo 1 seek + 1 rotacional

**Scheduling:**
1. Dibujar timeline visual con las posiciones
2. Para SCAN/C-SCAN: marcar claramente dirección inicial
3. Verificar que todas las solicitudes se atiendan
4. Revisar si hay starvation posible (SSTF)

**RAID:**
1. Identificar qué se pregunta: capacidad, tolerancia, o ambos
2. Fórmulas clave:
   ```
   RAID 0: N × C
   RAID 1: C (con 2 discos)
   RAID 5: (N-1) × C
   ```
3. Para paridad XOR: aplicar bit a bit, recordar propiedad asociativa

### Checklist Pre-Examen

- [ ] Sé explicar polling, interrupciones y DMA
- [ ] Conozco ventajas/desventajas de cada técnica de I/O
- [ ] Entiendo estructura física del disco (platos, pistas, cilindros, sectores)
- [ ] Puedo calcular tiempo de acceso (seek + rotacional + transferencia)
- [ ] Sé aplicar los 8 algoritmos de scheduling de disco
- [ ] Puedo calcular movimiento total del brazo para cada algoritmo
- [ ] Entiendo cuándo usar SSTF vs LOOK vs C-LOOK
- [ ] Conozco RAID 0, 1, 5 (capacidad, tolerancia, uso)
- [ ] Sé calcular paridad con XOR y cómo recuperar datos
- [ ] Entiendo diferencia entre buffer, cache y spooling
- [ ] Conozco capas del subsistema de I/O

---

## 12. Conexiones con Otros Capítulos

### Capítulo 1: Introducción
- Interrupciones (mencionadas en intro) se usan extensivamente en I/O
- DMA es un caso especial de hardware especializado
- Modos de operación (kernel/user) críticos para I/O protegido

### Capítulo 2: Procesos
- Procesos se bloquean esperando I/O (estado BLOCKED)
- Context switch ocurre cuando proceso espera disco
- Syscalls read/write interactúan con scheduler de procesos

### Capítulo 3: Planificación
- I/O-bound vs CPU-bound processes
- Algoritmos de scheduling de CPU consideran I/O burst
- Prioridad mayor para procesos interactivos (mucho I/O)

### Capítulo 5: Sincronización
- Drivers usan locks para proteger estructuras compartidas
- Race conditions posibles en cola de I/O
- Interrupt handlers deben ser thread-safe

### Capítulo 7-8: Memoria
- Buffer cache reside en memoria RAM
- Page cache unificado con buffer cache en Linux
- Memory-mapped I/O usa espacio de direcciones virtual
- Swap es I/O a disco para memoria virtual

### Capítulo 9: File Systems
- File systems dependen completamente del subsistema de I/O
- Bloques del FS se mapean a sectores del disco
- Algoritmos de scheduling afectan rendimiento del FS
- RAID implementado bajo el FS (block device layer)

**Ejemplo integrador:**

```
Aplicación llama read(fd, buf, 4096):
1. [Cap 9] VFS traduce fd a inodo
2. [Cap 9] File system (EXT4) determina qué bloque leer
3. [Cap 8] Verificar si bloque está en buffer cache (memoria)
4. Si no: [Cap 10] Generar solicitud de I/O a disco
5. [Cap 10] Scheduler de disco ordena la solicitud (LOOK)
6. [Cap 10] DMA transfiere datos disco → RAM
7. [Cap 10] Interrupción notifica completación
8. [Cap 2] Proceso despierta (BLOCKED → READY)
9. [Cap 3] Scheduler de CPU lo ejecuta eventualmente
10. [Cap 8] Copiar datos de buffer cache a espacio usuario
```

---

## 13. Ejercicios Adicionales (Práctica)

### Ejercicio 1: Técnicas de I/O

**Pregunta:** Un dispositivo de red recibe paquetes de 1500 bytes a una tasa de 100 Mbps. ¿Qué técnica de I/O recomendarías: polling, interrupciones o DMA? Justificar.

**Respuesta esperada:**
- Calcular frecuencia de paquetes: ~8333 paquetes/seg
- Polling: CPU 100% ocupada verificando → inviable
- Interrupciones: ~8333 interrupciones/seg → overhead alto
- **DMA es óptimo:** Transfiere cada paquete sin CPU, solo 1 interrupción por paquete
- Plus: Ring buffers para batch de paquetes → aún mejor

### Ejercicio 2: Tiempos de Acceso

**Pregunta:** Disco de 10000 RPM, seek promedio 6 ms, transferencia 200 MiB/s. Calcular tiempo para leer 100 sectores de 512 bytes:

a) Consecutivos en la misma pista
b) Dispersos aleatoriamente

**Respuesta:**
```
Latencia rotacional = (60/10000)/2 = 3 ms

a) Consecutivos:
   T = 6 ms (seek) + 3 ms (rot) + (100×512)/(200×10^6) = 9.25 ms

b) Dispersos:
   T = 100 × (6 + 3 + 0.0025) = 900.25 ms
   
   ~97× más lento!
```

### Ejercicio 3: RAID Capacity

**Pregunta:** Tienes 6 discos de 2 TiB cada uno. Calcular capacidad útil para:

a) RAID 0
b) RAID 1
c) RAID 5

**Respuesta:**
```
a) RAID 0: 6 × 2 TiB = 12 TiB (sin redundancia)

b) RAID 1: 3 × 2 TiB = 6 TiB (3 pares espejo)

c) RAID 5: (6-1) × 2 TiB = 10 TiB (1 disco de paridad distribuida)
```

### Ejercicio 4: Scheduling Avanzado

**Pregunta:** Cola: [25, 179, 58, 120, 77, 190, 13, 85], posición: 100, dirección: DOWN, disco [0-199]. Calcular movimiento para LOOK y C-LOOK.

**Respuesta:**
```
LOOK (DOWN luego UP):
100 → 85 → 77 → 58 → 25 → 13 (fin de DOWN) → 120 → 179 → 190
Movimiento: 15+8+19+33+12+107+59+11 = 264

C-LOOK (DOWN hasta fin, saltar a máximo, continuar DOWN):
100 → 85 → 77 → 58 → 25 → 13 → 190 (salto) → 179 → 120
Movimiento: 15+8+19+33+12+177+11+59 = 334
```

---

Este capítulo completó la visión integral del sistema operativo: gestión de procesos, memoria, file systems, y ahora I/O. Entender cómo el SO coordina la CPU, RAM y dispositivos periféricos es esencial para comprender el funcionamiento completo de un sistema de computación moderno.

El próximo paso natural sería profundizar en temas avanzados como virtualización, contenedores, o sistemas distribuidos, pero con estos 10 capítulos ya tenemos una base sólida en los fundamentos de sistemas operativos a nivel de ingeniería.