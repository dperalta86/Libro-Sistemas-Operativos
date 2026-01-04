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

## Introducción: ¿Por qué es complejo el I/O?

En los capítulos anteriores estudiamos la gestión de procesos, memoria y file systems. Todos estos componentes dependen críticamente del subsistema de entrada/salida para funcionar: los procesos necesitan leer datos del disco, la memoria virtual requiere swap a disco, y los file systems almacenan archivos en dispositivos físicos. Ahora llegamos a uno de los componentes más fascinantes y complejos del sistema operativo.  
El subsistema de I/O enfrenta un desafío único: debe coordinar la comunicación entre la CPU (que opera a gigahertz) y dispositivos que van desde teclados lentos hasta SSDs ultrarrápidos. Esta brecha de velocidad puede ser de seis órdenes de magnitud. Imaginate tratar de coordinar una conversación donde una persona habla a velocidad normal y la otra tarda un año en responder cada palabra.

### Desafíos del I/O

\begin{warning}
\textbf{Complejidad del I/O:}
El subsistema de I/O debe manejar una enorme variedad de dispositivos: discos, teclados, impresoras, tarjetas de red, GPUs, sensores. Cada uno tiene interfaces y protocolos diferentes, con rangos de velocidad extremadamente amplios (desde 10 bytes/seg de un teclado hasta 7 GB/seg de un SSD NVMe). Además, necesita sincronización precisa entre CPU y dispositivos lentos, confiabilidad crítica (la pérdida de datos en disco es catastrófica), y compatibilidad con múltiples dispositivos y versiones de drivers.
\end{warning}
Para ilustrar esta diversidad, considerá la siguiente tabla de dispositivos típicos:
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
La diferencia entre un teclado y un SSD NVMe es la misma que existe entre caminar (5 km/h) y viajar a 30.000 km/h. El sistema operativo debe hacer que todos estos dispositivos funcionen juntos de manera coordinada.

### Objetivos del Subsistema de I/O

\begin{infobox}
\emph{Subsistema de I/O:}
Conjunto de componentes del sistema operativo responsables de gestionar la comunicación entre el CPU/memoria y los dispositivos periféricos, proporcionando abstracción, eficiencia y confiabilidad.
\end{infobox}
El subsistema de I/O persigue cinco objetivos principales. Primero, la abstracción o independencia de dispositivo: ocultar las diferencias entre dispositivos mediante interfaces uniformes, para que tu programa pueda usar `read()` tanto con un archivo en disco como con datos de red. Segundo, la eficiencia: maximizar el throughput y minimizar la latencia, aprovechando al máximo las capacidades del hardware. Tercero, la compartición: permitir que múltiples procesos accedan concurrentemente a dispositivos compartibles de manera segura y coordinada.  
El cuarto objetivo es la protección: prevenir que procesos no autorizados accedan directamente a dispositivos críticos (imaginate si cualquier programa pudiera leer o escribir arbitrariamente en tu disco). Finalmente, el manejo de errores: detectar y recuperarse de fallos de hardware, que son inevitables en dispositivos mecánicos y electrónicos.

## Hardware de I/O
Antes de entender cómo el sistema operativo gestiona el I/O, necesitamos comprender el hardware subyacente. Los dispositivos no son todos iguales, y sus diferencias fundamentales determinan cómo el SO debe interactuar con ellos.

### Tipos de Dispositivos

Los dispositivos de I/O se clasifican según varias dimensiones, siendo las más importantes la unidad de transferencia y el modo de acceso.

#### Por Unidad de Transferencia

Los dispositivos de bloque transfieren datos en bloques de tamaño fijo, típicamente entre 512 bytes y 4 KiB. Estos dispositivos soportan acceso aleatorio mediante seek: podés saltar a cualquier bloque sin tener que leer todos los anteriores. Cada bloque tiene una dirección única, lo que permite el direccionamiento directo. Los ejemplos clásicos son discos duros (HDD), SSDs, CD-ROMs y cintas magnéticas. Estos dispositivos son los que típicamente asociamos con "almacenamiento persistente".  

En contraste, los **dispositivos de carácter** transfieren datos como un flujo continuo de bytes individuales. Generalmente no soportan seek, solo acceso secuencial: los datos llegan en orden y deben procesarse en ese orden. Pensá en ellos como un río de información que fluye constantemente. 

Ejemplos incluyen teclados, mice, puertos serie e impresoras. Cuando presionás una tecla, ese carácter llega inmediatamente y no tiene sentido "buscar" la tecla anterior.  

Existe una categoría especial: los dispositivos de red. Estos no son estrictamente de bloque ni de carácter, sino que transfieren paquetes de tamaño variable. Cada paquete es una unidad independiente con headers, datos y checksums. Las tarjetas Ethernet, WiFi y módems caen en esta categoría.

#### Por Modo de Acceso

Los **dispositivos compartibles (sharables)** pueden ser usados por múltiples procesos concurrentemente, aunque requieren sincronización cuidadosa para evitar condiciones de carrera. Los discos son el ejemplo paradigmático: cientos de procesos pueden leer y escribir simultáneamente, y el sistema operativo coordina estos accesos mediante locks y colas. Las tarjetas de red también son compartibles, multiplexando paquetes de diferentes conexiones.  

Los dispositivos dedicados solo permiten un proceso a la vez. Las impresoras (sin spooling) son el ejemplo clásico: si un proceso está imprimiendo, los demás deben esperar. Las cintas magnéticas también requieren acceso exclusivo, ya que son inherentemente secuenciales.

### Controladores de Dispositivo

\begin{infobox}
\emph{Controlador de Dispositivo (Device Controller):}
Componente de hardware que actúa como interfaz entre el bus del sistema y el dispositivo físico. Contiene registros y lógica para controlar el dispositivo.
\end{infobox}
Un concepto crucial que a menudo se malentiende: el sistema operativo no interactúa directamente con el dispositivo físico, sino con su controlador. El controlador es un chip especializado que habla dos idiomas: por un lado, entiende el protocolo del bus del sistema (PCIe, SATA, USB), y por otro, sabe cómo manejar las peculiaridades electrónicas del dispositivo específico.  
La arquitectura típica se ve así:

```
CPU/Memoria <---> Bus del Sistema <---> Controlador <---> Dispositivo
                                        (Controller)       (Device)
```

El controlador contiene varios componentes esenciales. Los registros de control son donde la CPU escribe comandos: "leer sector 1234", "mover cabeza al cilindro 500", etc. Los registros de estado permiten que la CPU consulte el estado actual: ¿está ocupado el dispositivo? ¿hubo algún error? ¿completó la operación? Los registros de datos funcionan como buffers temporales para la transferencia de datos entre el dispositivo y la memoria. Finalmente, la lógica interna ejecuta las operaciones específicas del dispositivo, traduciendo comandos de alto nivel en secuencias de señales eléctricas.  
Un ejemplo concreto de controlador de disco podría tener:
```
Registro de Control:  [READ|WRITE|SEEK] comando
Registro de Estado:   [BUSY|READY|ERROR] flags
Registro de Datos:    Buffer de sector (512 bytes)
Registro de Dirección: LBA (Logical Block Address)
```

\begin{highlight}
El driver del sistema operativo habla con el controlador mediante lectura y escritura de sus registros, no con el dispositivo directamente. Esta abstracción permite que el mismo driver funcione con diferentes dispositivos que usan el mismo tipo de controlador.
\end{highlight}

### Interfaces de I/O

Existen dos formas principales de que la CPU acceda a los registros del controlador. En **Memory-Mapped I/O**, los registros del controlador se mapean a direcciones específicas del espacio de memoria física.  
La CPU usa instrucciones normales de memoria (LOAD/STORE) para interactuar con ellos. Por ejemplo, escribir a la dirección `0xF0000000` podría estar escribiendo al registro de control del controlador de disco. Esta técnica no requiere instrucciones especiales y es la dominante en sistemas modernos por su simplicidad.  

En **Port-Mapped I/O** (o I/O Aislado), existe un espacio de direcciones separado específico para I/O. La CPU usa instrucciones especiales como `IN` y `OUT` (en arquitectura x86) para acceder a estos puertos. Esta arquitectura era común en sistemas antiguos pero ha caído en desuso.  

La mayoría de los sistemas modernos usan exclusivamente Memory-Mapped I/O porque permite usar toda la potencia del caché de CPU y las optimizaciones del pipeline para accesos a dispositivos.

## Técnicas de I/O

Ahora que entendemos el hardware, podemos explorar cómo el sistema operativo gestiona las operaciones de I/O. Existen tres técnicas principales, cada una con trade-offs significativos en eficiencia, complejidad y uso de CPU. La evolución histórica de estas técnicas refleja la búsqueda constante por minimizar el desperdicio de ciclos de CPU.  

### Técnica 1: I/O Programado (Polling)
La técnica más simple es el I/O programado o polling. La idea es directa: la CPU ejecuta un bucle que constantemente verifica el estado del dispositivo hasta que esté listo. Es como preguntarle repetidamente a alguien "¿ya terminaste? ¿ya terminaste? ¿ya terminaste?" hasta que responda que sí.

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

El flujo es simple: la CPU escribe un comando en el registro de control, luego entra en un bucle verificando constantemente el registro de estado. Cuando el dispositivo finalmente está listo, la CPU lee o escribe los datos. Este ciclo se repite hasta completar la transferencia completa.
\begin{example}
La ventaja del polling es su simplicidad extrema: no requiere hardware especial para interrupciones, es fácil de depurar, y tiene latencia muy baja para dispositivos que responden inmediatamente. En sistemas embebidos simples donde la CPU no tiene nada más que hacer, puede ser la solución correcta.
\end{example}
\begin{warning}
Sin embargo, el polling tiene un problema fundamental: la CPU está completamente ocupada durante todo el I/O. Es un desperdicio catastrófico de ciclos de CPU. Mientras esperás que el disco complete una operación de 10 ms, la CPU podría haber ejecutado millones de instrucciones útiles. Además, no puede hacer multitasking: está atrapada en ese bucle de polling.
\end{warning}
El polling solo tiene sentido en escenarios muy específicos: cuando el dispositivo responde en menos de 100 ciclos de CPU, o en sistemas embebidos sin sistema operativo donde la CPU está dedicada a una sola tarea. En sistemas de propósito general modernos, el polling es prácticamente inexistente.

### Técnica 2: I/O por Interrupciones

La segunda técnica resuelve el problema del busy-waiting: en lugar de que la CPU pregunte constantemente, el dispositivo le avisa cuando termina mediante una interrupción. Es como darle a alguien tu número de teléfono en vez de llamarlo cada 5 segundos.

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
El flujo cambia fundamentalmente. La CPU inicia la operación escribiendo al controlador, pero inmediatamente retorna y puede ejecutar otros procesos. Cuando el dispositivo completa la operación, genera una interrupción de hardware. Esta interrupción fuerza a la CPU a suspender el proceso actual, ejecutar el *Interrupt Service Routine* (ISR) que maneja el evento, y luego retornar al proceso que fue interrumpido.

\begin{theory}
Las interrupciones son el mecanismo fundamental que permite multitasking efectivo en presencia de I/O. Sin ellas, la CPU estaría constantemente atrapada esperando dispositivos lentos, desperdiciando su capacidad de procesamiento.
\end{theory}

Las ventajas son claras: la CPU queda libre para ejecutar otros procesos durante el I/O, la utilización de CPU es mucho mejor que con polling, y permite multitasking real. Un sistema puede tener docenas de operaciones de I/O en progreso simultáneamente, con la CPU alternando entre procesos productivos.

Sin embargo, las interrupciones introducen su propio overhead. Cada interrupción requiere un *context switch*: guardar el estado del proceso actual, cambiar al kernel, ejecutar el ISR, y restaurar el proceso. Este overhead es típicamente de cientos a miles de ciclos. Si las interrupciones llegan muy frecuentemente (por ejemplo, en dispositivos de red de alta velocidad recibiendo miles de paquetes por segundo), puede ocurrir una *interrupt storm* donde la CPU pasa más tiempo manejando interrupciones que ejecutando código útil.

Además, aunque mejor que polling, la CPU sigue involucrada en cada transferencia de datos. Para transferencias grandes (como leer un archivo de varios megabytes), esto significa miles de interrupciones, cada una con su overhead asociado.

Las interrupciones son ideales para dispositivos de velocidad media, eventos esporádicos (como teclas presionadas), y transferencias pequeñas. Son el estándar para teclados, mice, y para señalizar la completación de operaciones de disco.

### Técnica 3: DMA (Direct Memory Access)

La tercera técnica lleva la eficiencia al siguiente nivel. Con DMA, un controlador especializado maneja la transferencia completa de datos entre el dispositivo y la memoria, sin que la CPU toque ningún byte individual.

\begin{infobox}
\emph{DMA (Direct Memory Access):}
Técnica que permite al controlador de dispositivo transferir datos directamente entre el dispositivo y la memoria RAM sin intervención de la CPU.
\end{infobox}

La arquitectura con DMA introduce un nuevo componente:
```
CPU <---> Bus <---> Memoria RAM
            ^
            |
            v
      DMA Controller <---> Device Controller <---> Dispositivo
```

El flujo de operación es elegante. Primero, la CPU configura el DMA controller: le indica la dirección de memoria origen o destino, la cantidad de bytes a transferir, la dirección del dispositivo, y la dirección de control (read/write). Luego, el DMA controller ejecuta la transferencia completa de manera autónoma: "roba" ciclos del bus según necesita (cycle stealing), transfiere datos directamente entre dispositivo y RAM byte por byte o palabra por palabra, e incrementa punteros automáticamente. Finalmente, cuando completa la transferencia completa, el DMA genera una única interrupción para notificar a la CPU.
Ejemplo de código:

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
Un concepto importante es el *cycle stealing*. El DMA controller necesita acceso al bus para transferir datos, pero la CPU también necesita el bus para ejecutar instrucciones. La solución es que el DMA "roba" temporalmente el control del bus cuando lo necesita. Si la CPU puede ejecutar desde caché (sin acceder a RAM), ni siquiera nota el robo. Si necesita el bus simultáneamente, debe esperar unos pocos ciclos.

\begin{infobox}
\emph{Cycle Stealing:}
Técnica donde el DMA controller temporalmente "roba" el control del bus de sistema para realizar transferencias, mientras la CPU ejecuta desde cache o espera brevemente.
\end{infobox}

Un timeline típico del bus durante DMA se ve así:

```
Timeline del bus durante DMA:
CPU  CPU  DMA  CPU  CPU  DMA  CPU  DMA  DMA  CPU
|    |    |    |    |    |    |    |    |    |
└────┴────┴────┴────┴────┴────┴────┴────┴────┴──> tiempo

CPU ejecuta cuando puede acceder al bus
DMA "roba" ciclos periódicamente para transferir datos
```
\begin{highlight}
Las ventajas de DMA son dramáticas: la CPU queda completamente libre durante la transferencia, el throughput es muy alto (limitado solo por la velocidad del dispositivo y el bus), solo hay una interrupción por operación completa (no una por byte), y es esencial para dispositivos de alta velocidad como SSDs modernos que transfieren gigabytes por segundo.
\end{highlight}

Las desventajas son menores en comparación: requiere hardware especializado (que ya viene incluido en todas las computadoras modernas), la configuración es más compleja que con interrupciones simples, el cycle stealing puede ralentizar ligeramente a la CPU (típicamente 1-5%), y para transferencias muy pequeñas (unos pocos bytes) el overhead de configuración puede ser mayor que simplemente copiar los datos con la CPU.

En sistemas modernos, virtualmente todos los dispositivos de bloque (discos, SSDs, tarjetas de red, GPUs) usan DMA. Es la técnica dominante para cualquier transferencia mayor a 1 KiB.

### Comparación de Técnicas

Resumamos las tres técnicas en una tabla comparativa:

| Aspecto | Polling | Interrupciones | DMA |
|---------|---------|----------------|-----|
| **CPU durante I/O** | 100% ocupada | Interrumpida por evento | Libre |
| **Interrupciones** | Ninguna | Una por transferencia | Una por bloque |
| **Overhead** | Bajo (simple) | Medio (context switch) | Alto (setup), bajo (ejecución) |
| **Throughput** | Bajo | Medio | Alto |
| **Uso de CPU** | Muy alto | Medio | Muy bajo |
| **Mejor para** | Dispositivos rápidos | Eventos y chars | Transferencias grandes |
| **Escalabilidad** | Muy mala | Media | Excelente |

\begin{excerpt}
Regla práctica para elegir técnica de I/O:

Usá polling si el dispositivo responde en menos de 100 ciclos de CPU (rarísimo en la práctica).

Usá interrupciones para eventos esporádicos y transferencias pequeñas (menos de 1 KiB).

Usá DMA para transferencias mayores a 1 KiB o dispositivos rápidos. Es obligatorio para discos y redes modernas.
\end{excerpt}

## Discos Magnéticos: Estructura y Rendimiento

Aunque los SSDs han ganado popularidad, los discos duros (HDD) siguen siendo ampliamente usados para almacenamiento masivo debido a su bajo costo por gigabyte. Más importante aún, comprender su estructura física es esencial para entender el rendimiento del I/O y por qué los algoritmos de scheduling de disco son necesarios.

### Geometría del Disco

Un disco duro es una maravilla de ingeniería mecánica de precisión. Imaginalo como un tocadiscos moderno pero con múltiples discos girando a miles de revoluciones por minuto.


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
\emph{Componentes del disco:}
\textbf{Plato (Platter):} Disco circular recubierto de material magnético. Un disco tiene múltiples platos apilados verticalmente.\\
\textbf{Pista (Track):} Círculo concéntrico en la superficie del plato donde se almacenan datos magnéticamente.\\
\textbf{Sector:} Subdivisión de una pista, unidad mínima de transferencia (típicamente 512 bytes o 4 KiB).\\
\textbf{Cilindro (Cylinder):} Conjunto de pistas en la misma posición radial en todos los platos.\\
\textbf{Cabeza (Head):} Dispositivo que lee/escribe datos magnéticamente flotando a nanómetros de la superficie. Hay una cabeza por superficie de plato.
\end{infobox}

La vista lateral de un disco con múltiples platos revela su estructura tridimensional:

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

Un detalle crucial: todas las cabezas están montadas en el mismo brazo actuador y se mueven juntas. No pueden moverse independientemente. Esto significa que cuando el brazo se mueve a un cilindro específico, todas las cabezas quedan posicionadas sobre la misma posición radial en sus respectivos platos.

Históricamente, los sectores se direccionaban usando CHS (*Cylinder-Head-Sector*): especificabas exactamente en qué cilindro, qué cabeza, y qué sector querías acceder. Los sistemas modernos usan LBA (*Logical Block Addressing*): cada sector tiene un número secuencial único, y el controlador del disco se encarga de traducirlo a la geometría física. Esto simplifica enormemente la vida del sistema operativo.

Un ejemplo concreto ayuda a visualizar las capacidades. Considerá un disco con 1000 cilindros, 4 cabezas (2 platos con dos superficies cada uno), 100 sectores por pista, y 512 bytes por sector:

```
Ejemplo de disco:
- 1000 cilindros
- 4 cabezas (2 platos, 2 superficies c/u)
- 100 sectores por pista
- 512 bytes por sector

Capacidad total = 1000 × 4 × 100 × 512 = 204.800.000 bytes ≈ 195 MiB
```
Este sería un disco muy antiguo, por supuesto. Los discos modernos tienen cientos de miles de cilindros y capacidades de terabytes.

### Tiempos de Acceso a Disco

El tiempo total para leer o escribir datos de un disco mecánico se descompone en tres componentes fundamentales. Esta descomposición es crítica para entender el rendimiento de I/O.  

Tiempo de acceso total:
$$
T_{total} = T_{seek} + T_{rotacional} + T_{transferencia}
$$

#### Tiempo de Seek (Búsqueda)

El seek time es el tiempo que tarda el brazo actuador en mover las cabezas desde su posición actual hasta el cilindro destino. Es una operación mecánica: el brazo debe acelerar, recorrer la distancia, y decelerar precisamente en el cilindro correcto.  

```
T_seek depende de la distancia en cilindros

Valores típicos para HDD:
- Track-to-track (1 cilindro): 0.2 - 0.5 ms
- Seek promedio: 8 - 12 ms
- Full stroke (máximo): 15 - 20 ms
```

Los modelos físicos del seek time son interesantes. Un modelo simple lineal sería $T_{seek} = a + b \times distancia$, pero la realidad es más compleja debido a la aceleración. Un modelo más realista usa $T_{seek} = a + b \times \sqrt{distancia}$, reflejando que el brazo pasa la mayor parte del tiempo acelerando y frenando.

Para cálculos en este libro, utilizaremos el seek promedio simplificado de aproximadamente 9 ms en discos de 7200 RPM, a menos que el problema especifique otra cosa.

#### Latencia Rotacional

Una vez que las cabezas están posicionadas en el cilindro correcto, debemos esperar a que el sector deseado rote bajo la cabeza. Los platos giran a velocidad constante, medida en RPM (revoluciones por minuto).
El tiempo para una revolución completa es simplemente:
$$
T_{rotacional_promedio}​=T_{revolucion} / 2
$$

**Valores típicos:**

| RPM | Revolución completa | Latencia promedio |
|-----|---------------------|-------------------|
| 5400 | 11.1 ms | 5.55 ms |
| 7200 | 8.33 ms | 4.17 ms |
| 10000 | 6.0 ms | 3.0 ms |
| 15000 | 4.0 ms | 2.0 ms |

\begin{warning}
La latencia rotacional es una limitación física fundamental del disco. No puede mejorarse con algoritmos inteligentes de scheduling. Es simplemente una consecuencia de la velocidad de rotación del motor. La única forma de reducirla es comprar un disco más rápido (o usar un SSD, que no tiene partes móviles y por tanto no tiene latencia rotacional).
\end{warning}

#### Tiempo de Transferencia

Una vez que el sector está bajo la cabeza, los datos deben transferirse entre el disco y el controlador. Este tiempo depende de la tasa de transferencia del disco y la cantidad de datos:

$$
T_{transferencia} = (bytes a transferir) / (tasa de transferencia)
$$

Tasa de transferencia típica:
```
- HDD interno SATA: 100 - 200 MiB/s
- HDD externo USB 3.0: 80 - 120 MiB/s
- SSD SATA: 500 - 600 MiB/s
- SSD NVMe: 3000 - 7000 MiB/s
```

*Ejemplo de cálculo:*

Transferir 4 KiB (un bloque) en HDD a 150 MiB/s:
```
T_transferencia = 4096 bytes / (150 × 10^6 bytes/seg)
                = 0.0000273 seg
                = 0.027 ms
```

\begin{theory}
Una observación crítica: para discos duros, el tiempo de transferencia es completamente despreciable comparado con seek y rotación. Transferir 4 KiB toma 0.027 ms, mientras que seek + rotación combinados toman ~13 ms. El tiempo de transferencia es menos del 0.2% del total.
Esta es la razón fundamental por la que la localidad espacial es tan importante para el rendimiento de discos: el costo está en llegar al dato, no en transferirlo una vez que lo encontraste.
\end{theory}

### Ejercicio: Cálculo de Tiempo de Acceso

**Enunciado:**

Se tiene un disco duro con las siguientes características:
- Velocidad de rotación: 7200 RPM
- Seek time promedio: 9 ms
- Tasa de transferencia: 150 MiB/s
- Tamaño de sector: 4 KiB

Calcular el tiempo total para leer:

a) Un sector aleatorio del disco

b) 10 sectores consecutivos en la misma pista

c) 10 sectores dispersos aleatoriamente en el disco


**Solución:**

Primero, calculemos los componentes base que usaremos repetidamente:

```
Latencia rotacional promedio:
T_rot = (60 / 7200) / 2 = 0.00833 / 2 = 0.00417 seg = 4.17 ms

Tiempo de transferencia por sector:
T_trans_sector = 4096 bytes / (150 × 10^6 bytes/seg) = 0.000027 seg ≈ 0.027 ms
```

*a) Un sector aleatorio:*

```
T_total = T_seek + T_rot + T_trans
        = 9 ms + 4.17 ms + 0.027 ms
        = 13.197 ms ≈ 13.2 ms
```

*b) 10 sectores consecutivos en la misma pista:*

Aquí está la parte interesante. Los sectores están contiguos en la misma pista, así que después del primer seek y la espera rotacional inicial, los siguientes 9 sectores pasan bajo la cabeza inmediatamente. Solo pagamos el costo de transferencia para cada uno:
```
T_total = T_seek + T_rot + (10 × T_trans_sector)
        = 9 ms + 4.17 ms + (10 × 0.027 ms)
        = 9 ms + 4.17 ms + 0.27 ms
        = 13.44 ms
```

\begin{excerpt}
Observación sorprendente: leer 10 sectores consecutivos toma apenas 0.24 ms más que leer 1 sector (13.44 ms vs 13.2 ms). ¿Por qué? Porque el seek y la rotación dominan completamente. Una vez que llegaste al lugar correcto, leer más datos es casi gratis.\\
Esta es la razón por la que los sistemas operativos modernos implementan prefetching: cuando pedís leer un bloque, el SO aprovecha y lee los bloques siguientes también, porque el costo marginal es despreciable.
\end{excerpt}

*c) 10 sectores dispersos aleatoriamente:*

Cada sector requiere su propio seek completo, rotación completa, y transferencia:
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

\begin{warning}
Conclusión crítica para el diseño de sistemas:
La localidad espacial es fundamental para el rendimiento de discos magnéticos. Leer bloques consecutivos es órdenes de magnitud más rápido que accesos aleatorios dispersos. Los algoritmos de scheduling de disco existen precisamente para maximizar esta localidad.
\end{warning}

## Scheduling de I/O: Algoritmos de Disco

Los sistemas operativos mantienen una cola de solicitudes de I/O pendientes. En un sistema activo, pueden llegar docenas o cientos de solicitudes por segundo. El orden en que se atienden estas solicitudes tiene un impacto dramático en el rendimiento total del sistema.
\begin{infobox}
\emph{Disk Scheduling:}
Algoritmos que determinan el orden en que se atienden las solicitudes de I/O a disco, con el objetivo de minimizar el seek time total y maximizar el throughput.
\end{infobox}
Consideremos un escenario típico que usaremos para todos nuestros ejemplos:

```
Cola de solicitudes pendientes: [98, 183, 37, 122, 14, 124, 65, 67]
Posición actual de la cabeza: cilindro 53
Rango del disco: 0 - 199 cilindros
```

Nuestro objetivo es simple pero crucial: minimizar el movimiento total del brazo, que es la suma de todas las distancias recorridas en cilindros. ¿Por qué? Porque el seek time es el componente dominante del tiempo de acceso, como vimos en la sección anterior.

### Algoritmo 1: FCFS (First-Come, First-Served)

El algoritmo más simple: atender las solicitudes en el orden exacto de llegada, como una cola FIFO en el supermercado.

**Secuencia:**
```
Orden: 53 → 98 → 183 → 37 → 122 → 14 → 124 → 65 → 67

Movimiento total:
|98-53| + |183-98| + |37-183| + |122-37| + |14-122| + |124-14| + |65-124| + |67-65|
= 45 + 85 + 146 + 85 + 108 + 110 + 59 + 2
= 640 cilindros
```

Observá cómo el brazo salta de un lado al otro del disco constantemente: 53→98 (derecha), 98→183 (más derecha), 183→37 (salto enorme a la izquierda), 37→122 (derecha otra vez). Es un movimiento caótico e ineficiente.  
La ventaja de FCFS es su simplicidad: implementación trivial con una cola FIFO, es perfectamente justo (todas las solicitudes se atienden en orden), y no hay riesgo de starvation (inanición, donde una solicitud espera indefinidamente).  
Sin embargo, las desventajas son severas: no optimiza el movimiento del brazo en absoluto, el movimiento total es muy alto con ese zigzag constante, y el rendimiento es pobre comparado con algoritmos más inteligentes. FCFS casi nunca se usa en sistemas reales.

### Algoritmo 2: SSTF (Shortest Seek Time First)

Un enfoque greedy: siempre atender la solicitud más cercana a la posición actual. Es el equivalente a optimizar localmente en cada decisión.

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

SSTF reduce el movimiento de 640 a 236 cilindros (63% de reducción). El throughput mejora significativamente, y la implementación sigue siendo relativamente simple: solo necesitás una lista ordenada o un heap.
\begin{warning}
Sin embargo, SSTF tiene un problema serio: puede causar starvation. Imaginá que constantemente llegan solicitudes en el centro del disco (cilindro 100). Una solicitud en el cilindro 5 podría esperar indefinidamente, porque siempre habrá solicitudes más cercanas a la posición actual.
Este no es un problema teórico. En sistemas con mucha carga de I/O, las solicitudes en los extremos del disco pueden experimentar latencias muy altas o incluso nunca ser atendidas.
\end{warning}
SSTF es común en sistemas con baja o media carga de I/O, donde la probabilidad de starvation es baja y se prioriza el throughput.

### Algoritmo 3: SCAN (Elevator Algorithm)

SCAN resuelve el problema de starvation de SSTF usando una estrategia inspirada en ascensores: el brazo se mueve en una dirección hasta el final del disco, atendiendo todas las solicitudes en el camino, luego invierte la dirección y hace lo mismo.

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

El nombre "Elevator Algorithm" es perfecto: pensá en cómo funciona un ascensor moderno. No va inmediatamente al piso que pediste; primero completa todos los pedidos en su dirección actual, luego da la vuelta.
\begin{highlight}
Las ventajas de SCAN son importantes: no hay starvation porque eventualmente el brazo pasa por todos los cilindros, el movimiento es más predecible que SSTF, y el throughput sigue siendo bueno. Es un buen balance entre eficiencia y fairness.
\end{highlight}
La desventaja es que hay movimiento innecesario hasta el extremo del disco. En nuestro ejemplo, no había ninguna solicitud entre 183 y 199, pero el brazo se movió hasta allí de todos modos. Además, las solicitudes que acaban de llegar en la dirección opuesta deben esperar todo un barrido completo del disco.  
SCAN era usado en ascensores reales y en algunos sistemas operativos antiguos. Las variantes modernas (LOOK y C-LOOK) mejoran sobre esta idea básica.

### Algoritmo 4: C-SCAN (Circular SCAN)

C-SCAN mejora la fairness de SCAN tratando al disco como una estructura circular: al llegar al final, el brazo salta inmediatamente al inicio sin atender solicitudes en el camino de vuelta, luego continúa en la dirección original.

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
La idea clave es que C-SCAN trata a todos los cilindros más uniformemente. Las solicitudes en el extremo inferior no tienen que esperar todo el viaje de ida y vuelta; el brazo regresa rápidamente al inicio y las atiende. Esto proporciona una latencia más uniforme y predecible que SCAN.  

El costo es que el movimiento total es mayor que SCAN (382 vs 331), porque ese salto de 199 a 0 cuenta como movimiento completo del disco. Sin embargo, en sistemas con alta carga de I/O distribuida uniformemente, esta desventaja se compensa con la mejor fairness.  
C-SCAN es usado en sistemas donde se prioriza la consistencia de latencia sobre el throughput puro.

### Algoritmo 5: LOOK

LOOK es una optimización obvia de SCAN: ¿para qué ir hasta el extremo del disco si no hay solicitudes ahí? El brazo solo va hasta la última solicitud en esa dirección, luego invierte.

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

La mejora sobre SCAN es clara: 299 cilindros vs 331, una reducción del 10%. Eliminamos ese movimiento desperdiciado de 183 a 199. El brazo "mira" (look) hacia adelante, ve que no hay más solicitudes, y da la vuelta inteligentemente.  
LOOK mantiene todas las ventajas de SCAN (sin starvation, predecible, buen throughput) y elimina su principal desventaja (movimiento innecesario). Es generalmente superior a SCAN en todos los aspectos y es una de las opciones más populares en sistemas operativos modernos.

### Algoritmo 6: C-LOOK (Circular LOOK)

C-LOOK combina las ideas de C-SCAN y LOOK: solo va hasta la última solicitud en la dirección actual, luego salta a la primera solicitud pendiente (no necesariamente al extremo del disco), y continúa en la dirección original.

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

C-LOOK ofrece un excelente balance. Combina la latencia uniforme de C-SCAN con la eliminación de movimiento innecesario de LOOK. Es más eficiente que C-SCAN (322 vs 382 cilindros) pero mantiene su fairness superior a SCAN/LOOK.  
Este algoritmo es una variante muy popular en sistemas Linux modernos, a menudo implementado como parte del scheduler mq-deadline.

### Algoritmo 7: FSCAN (Freeze SCAN)

FSCAN introduce un concepto nuevo: divide la cola en dos sublistas y las procesa por separado. Esto previene que solicitudes nuevas "se cuelen" y retrasen solicitudes antiguas.

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

\begin{theory}
La idea detrás de FSCAN es prevenir starvation de una manera diferente a SCAN. En SCAN puro, si constantemente llegan nuevas solicitudes, algunas solicitudes antiguas podrían ser "empujadas" continuamente. FSCAN garantiza que cada solicitud se procesa dentro de dos ciclos de SCAN como máximo: en el peor caso, llegás justo después de que tu Queue comenzó a procesarse, así que esperás ese ciclo completo más el siguiente.
\end{theory}
Las ventajas son claras: previene starvation de solicitudes lejanas, el tiempo de espera está acotado (máximo 2 ciclos), y ofrece mejor fairness que SCAN simple. Las desventajas son la mayor complejidad de implementación (dos colas a mantener) y potencialmente mayor latencia para solicitudes nuevas (deben esperar al siguiente ciclo incluso si están cerca de la posición actual).  
FSCAN es usado en sistemas que requieren garantías de tiempo de respuesta, como sistemas de tiempo real.

### Algoritmo 8: N-STEP-SCAN

N-STEP-SCAN es similar a FSCAN pero más granular: la cola se divide en sublistas de máximo N solicitudes cada una.

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

El parámetro N permite un trade-off configurable. Con N pequeño (por ejemplo, N=10), el sistema es más responsive: cada batch se procesa rápidamente, pero puede haber más movimiento del brazo porque los grupos son pequeños. Con N grande (por ejemplo, N=100), hay más oportunidad de optimizar el movimiento dentro de cada batch, mejorando throughput, pero las solicitudes pueden esperar más porque los batches son grandes.
\begin{highlight}
Las ventajas incluyen tiempo de espera predecible (máximo ceil(K/N) ciclos para K solicitudes), el parámetro N es configurable según las necesidades del sistema, y ofrece un balance ajustable entre responsiveness y throughput. Las desventajas son que requiere tuning del parámetro N para cada sistema específico, y la implementación es más compleja que algoritmos simples.
\end{highlight}
N-STEP-SCAN es usado en sistemas de tiempo real donde se necesita acotar las latencias máximas con precisión.

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

\begin{excerpt}
Recomendaciones prácticas:\\
SSTF: Sistemas con baja carga de I/O donde la prioridad es throughput puro y starvation es improbable.\\
LOOK/C-LOOK: Default en muchos sistemas modernos. Ofrecen el mejor balance entre throughput, fairness y complejidad de implementación.\\
FSCAN/N-STEP: Sistemas de tiempo real o con garantías estrictas de latencia máxima.\\
FCFS: Prácticamente nunca en la práctica, excepto como componente interno de algoritmos más complejos.
\end{excerpt}

## Ejercicio Integrador: Scheduling de Disco

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

Indicar también cuál algoritmo es más eficiente en este caso.

**Solución:**

a) FCFS:

```
Secuencia: 50 → 95 → 180 → 34 → 119 → 11 → 123 → 62 → 64

Movimiento:
|95-50| + |180-95| + |34-180| + |119-34| + |11-119| + |123-11| + |62-123| + |64-62|
= 45 + 85 + 146 + 85 + 108 + 112 + 61 + 2
= 644 cilindros
```

b) SSTF:

```
Desde 50, elegir más cercano:
50 → 62 (12) → 64 (2) → 34 (30) → 11 (23) → 95 (84) → 119 (24) → 123 (4) → 180 (57)

Movimiento total:
12 + 2 + 30 + 23 + 84 + 24 + 4 + 57 = 236 cilindros
```

c) SCAN:

```
Desde 50, dirección UP, atender todas hasta el final, luego DOWN:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 199 (fin) → 34 → 11

Movimiento:
|62-50| + |64-62| + |95-64| + |119-95| + |123-119| + |180-123| + |199-180| + |34-199| + |11-34|
= 12 + 2 + 31 + 24 + 4 + 57 + 19 + 165 + 23
= 337 cilindros
```

d) C-SCAN:

```
Desde 50, UP hasta el final, saltar al inicio, continuar UP:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 199 → 0 (salto) → 11 → 34

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 19 + 199 + 11 + 23 = 382 cilindros
```

e) LOOK:

```
Desde 50, UP hasta última solicitud (180), luego DOWN:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 34 → 11

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 146 + 23 = 299 cilindros
```

f) C-LOOK:

```
Desde 50, UP hasta 180, saltar a primera solicitud pendiente (11), continuar UP:
50 → 62 → 64 → 95 → 119 → 123 → 180 → 11 (salto) → 34

Movimiento:
12 + 2 + 31 + 24 + 4 + 57 + 169 + 23 = 322 cilindros
```

**Resumen:**

| Algoritmo | Movimiento total | Observaciones |
|-----------|------------------|---------------|
| FCFS | 644 | Peor caso |
| SSTF | 236 | Minimo movimiento |
| SCAN | 337 | |
| C-SCAN | 382 | |
| LOOK | 299 | Buen balance |
| C-LOOK | 322 | |

\begin{highlight}
Respuesta:\\
El algoritmo más eficiente en términos de movimiento puro es SSTF con 236 cilindros. Sin embargo, debemos recordar que SSTF puede causar starvation en sistemas con alta carga.\\
El mejor balance entre eficiencia y fairness lo ofrece LOOK con 299 cilindros: solo 27% más movimiento que SSTF, pero con garantía de no starvation y comportamiento más predecible.\\
En un sistema real de producción, típicamente elegiríamos LOOK o C-LOOK sobre SSTF.
\end{highlight}

## RAID (Redundant Array of Independent Disks)

RAID es una tecnología fascinante que surgió de una pregunta simple: ¿qué pasa si combinamos múltiples discos baratos para crear algo mejor que un disco caro? La respuesta resultó ser compleja y multifacética.
\begin{infobox}
\emph{RAID:}
Tecnología que utiliza múltiples discos trabajando en conjunto para proporcionar mayor rendimiento (mediante paralelismo) y/o mayor confiabilidad (mediante redundancia).
\end{infobox}
La idea central es que múltiples discos operando en paralelo pueden superar las limitaciones de un disco individual. RAID puede mejorar el rendimiento (leyendo/escribiendo en paralelo), mejorar la confiabilidad (duplicando datos), o ambas cosas. Sin embargo, diferentes "niveles" de RAID hacen diferentes trade-offs.

### RAID 0: Striping (sin redundancia)

RAID 0 es el más simple: los datos se dividen en bloques que se distribuyen (stripe) uniformemente entre todos los discos. Es como repartir un mazo de cartas entre varios jugadores.
```
Archivo dividido en bloques: A1, A2, A3, A4, A5, A6

Disco 0: [A1] [A3] [A5]
Disco 1: [A2] [A4] [A6]

Lectura/escritura en paralelo
```

Las ventajas de RAID 0 son impresionantes para ciertas aplicaciones:  

- Rendimiento máximo: el throughput se multiplica por N discos (en el caso ideal)  
- Capacidad total = suma de todos los discos (no se desperdicia nada)  
- Implementación simple y eficiente
- Latencia reducida para archivos grandes

Para edición de video 4K o rendering 3D, donde necesitás throughput sostenido de varios GiB/s, RAID 0 es ideal.  
\begin{warning}
Sin embargo, RAID 0 tiene una desventaja catastrófica: cero redundancia. Si cualquier disco falla, perdés todos los datos del array completo. Peor aún, la probabilidad de fallo aumenta: si cada disco tiene 1% de probabilidad de fallar en un año, con 4 discos en RAID 0, la probabilidad de que al menos uno falle es aproximadamente 4%.
RAID 0 hace que tu sistema sea menos confiable que un disco individual. El nombre "RAID" es casi irónico aquí, ya que no hay redundancia en absoluto.
\end{warning}

Cálculos para RAID 0
```
N discos de C capacidad cada uno:
Capacidad útil = N × C
Rendimiento lectura/escritura = N × velocidad_disco
```

Ejemplo práctico:  
- 4 discos de 1 TiB cada uno
- Capacidad útil: 4 TiB
- Si 1 disco falla: pérdida total

**Uso típico:** Aplicaciones que requieren máximo rendimiento y tienen backups robustos externos: edición de video profesional, rendering 3D, caches de alto rendimiento, ambientes de desarrollo donde los datos no son críticos.

### RAID 1: Mirroring (espejo completo)

RAID 1 toma el enfoque opuesto: cada dato se duplica completamente en dos (o más) discos. Es la técnica más antigua de redundancia: simplemente mantener dos copias idénticas.

```
Archivo: A1, A2, A3, A4

Disco 0: [A1] [A2] [A3] [A4]
Disco 1: [A1] [A2] [A3] [A4]  (copia exacta)
```

Cada escritura va a ambos discos síncronamente. Las lecturas pueden venir de cualquier disco, lo que permite balance de carga.  
Las ventajas de RAID 1 son claras para datos críticos:

- Confiabilidad alta: tolera la falla de N-1 discos (con 2 discos, tolerás 1 falla).  
- Rendimiento de lectura mejorado: podés leer de cualquier disco, efectivamente duplicando el throughput de lectura.  
- Recuperación trivial: el disco espejo es una copia exacta, simplemente copiás y listo.  
- Sin cálculos complejos: no hay overhead de paridad o reconstrucción  
Para bases de datos críticas o servidores de producción, RAID 1 ofrece la máxima tranquilidad.  
Las desventajas son económicas: capacidad útil = 50% (la mitad se usa para el espejo), costo alto (necesitás el doble de discos para la misma capacidad útil), y la escritura no es más rápida (debe completarse en ambos discos, aunque en paralelo).

Cálculos:
```
N discos de C capacidad cada uno (N par):
Capacidad útil = (N / 2) × C = C (con 2 discos)
Tolerancia a fallos = N/2 discos pueden fallar
```

Ejemplo:  
- 2 discos de 1 TiB cada uno  
- Capacidad útil: 1 TiB  
- Si 1 disco falla: datos siguen accesibles  

**Uso típico:** Datos críticos donde la pérdida sería catastrófica: bases de datos transaccionales, servidores de archivos corporativos, sistemas operativos de servidores de producción, cualquier escenario donde la confiabilidad es más importante que el costo.

### RAID 5: Striping con Paridad Distribuida

RAID 5 es el nivel más interesante conceptualmente: combina el rendimiento de RAID 0 con redundancia, pero de manera más eficiente que RAID 1. Los datos y la paridad se distribuyen entre todos los discos.

```
4 discos, bloques A1-A6:

Disco 0: [A1] [A4] [Parity(A5,A6)]
Disco 1: [A2] [Parity(A3,A4)] [A6]
Disco 2: [A3] [A5] [Parity(A1,A2)]
Disco 3: [Parity(A1,A2,A3)] [A6] [...]

Paridad se calcula con XOR
```
La clave está en cómo se calcula la paridad usando la operación XOR (Exclusive OR).

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

Propiedad clave del XOR: `A XOR B XOR C XOR ... XOR Parity = 0`, por lo tanto cualquier elemento puede recuperarse.  

Tabla de verdad XOR:
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
Este cálculo se hace a nivel de bloque completo (típicamente 512 bytes o 4 KiB). Cada bit de la paridad protege la posición correspondiente en todos los bloques de datos.  
\begin{theory}
La ventaja de RAID 5 es que distribuye la paridad. A diferencia de tener un disco dedicado solo a paridad (lo que crearía un cuello de botella), la paridad se esparce entre todos los discos. Esto significa que todas las escrituras se distribuyen uniformemente, evitando que un disco se desgaste más rápido que los otros.
\end{theory}


\begin{highlight}
Las ventajas de RAID 5 crean un balance excelente:\\
- Buena capacidad: (N-1)/N de espacio útil (75% con 4 discos, 80% con 5 discos)\\
- Tolerancia a fallos: cualquier disco puede fallar sin pérdida de datos\\
- Rendimiento de lectura excelente: N discos leyendo en paralelo\\
- Costo/beneficio superior a RAID 1: más capacidad útil con la misma protección\\
\\
Para servidores de archivos o NAS domésticos/empresariales, RAID 5 es a menudo la elección óptima.
\end{highlight}
\begin{warning}
Las desventajas de RAID 5 son sutiles pero importantes:\\
- Escritura más lenta: cada escritura requiere: (1) leer bloques viejos, (2) calcular nueva paridad, (3) escribir datos y paridad. Esto se llama "write penalty" y típicamente hace que escrituras sean 4× operaciones en vez de 1×.\\
- Recuperación lenta: reconstruir un disco requiere leer todos los otros discos y calcular cada bloque faltante con XOR.\\
- Vulnerable durante reconstrucción: si un segundo disco falla mientras estás reconstruyendo el primero, perdés todo. Con discos grandes (multi-TB), la reconstrucción puede tomar días.\\
NO tolera fallas simultáneas de 2+ discos
\end{warning}

Cálculos:
```
N discos de C capacidad cada uno (N ≥ 3):
Capacidad útil = (N - 1) × C
Espacio para paridad = 1 × C (distribuido)
Tolerancia a fallos = 1 disco
```

Ejemplo práctico:  
- 4 discos de 1 TiB cada uno  
- Capacidad útil: 3 TiB (75%)  
- Espacio de paridad: 1 TiB  
- Si 1 disco falla: datos recuperables  
- Si 2 discos fallan: pérdida total  

**Uso típico:** NAS (Network Attached Storage) domésticos y empresariales, servidores de archivos, almacenamiento general donde se busca balance entre rendimiento, capacidad y confiabilidad. Es el "sweet spot" para muchas aplicaciones.

### Comparación de RAID

| Nivel | Discos mín | Capacidad útil | Tolerancia fallos | Rendimiento lectura | Rendimiento escritura | Uso típico |
|-------|-----------|----------------|-------------------|---------------------|----------------------|------------|
| RAID 0 | 2 | N × C | 0 | Excelente (N×) | Excelente (N×) | Edición video, cache |
| RAID 1 | 2 | C (50%) | N-1 | Bueno (N×) | Normal (1×) | Datos críticos |
| RAID 5 | 3 | (N-1) × C | 1 | Excelente | Medio (paridad) | Servidores, NAS |

\begin{excerpt}
\textbf{Nota sobre RAID 6:}\\
RAID 6 extiende RAID 5 con doble paridad (bloques P y Q usando diferentes algoritmos matemáticos). Capacidad útil = (N-2) × C. Tolera la falla de 2 discos simultáneos, lo que es crítico con discos modernos de múltiples TB donde la reconstrucción puede tomar días.\\
El costo es mayor write penalty (6 operaciones por escritura en vez de 4) y mayor complejidad de cálculo de paridad Q (usa aritmética de campos de Galois en vez de simple XOR).\\
Uso: Almacenamiento empresarial crítico, arrays grandes (8+ discos) donde la probabilidad de fallo doble durante reconstrucción es significativa.
\end{excerpt}

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