# Sistema de Archivos

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante será capaz de:

- Comprender la necesidad y función de los sistemas de archivos en un sistema operativo
- Distinguir entre las abstracciones de archivo y directorio desde la perspectiva del usuario
- Identificar las operaciones básicas sobre archivos y directorios
- Comprender las estructuras administrativas del SO para gestión de archivos (tablas, locks)
- Analizar el modelo de permisos y protección de Unix
- Diferenciar bloques lógicos de sectores físicos en el nivel de hardware
- Identificar y comparar los métodos de asignación de espacio en disco
- Analizar la estructura y funcionamiento del sistema de archivos FAT (12/16/32)
- Comprender en profundidad la estructura de EXT2/UFS, especialmente el concepto de inodo
- Calcular accesos a disco en operaciones de lectura y escritura considerando bloques de datos y punteros
- Diferenciar entre hard links y soft links
- Resolver ejercicios tipo parcial sobre estructuras de file systems


## File System: Definición y Objetivos

### ¿Por qué necesitamos File Systems?

Imaginemos por un momento que no existieran los sistemas de archivos. Cada vez que queremos guardar información en el disco duro, tendríamos que recordar exactamente en qué sectores físicos guardamos cada dato. Si queremos acceder a un documento de texto, necesitaríamos saber que está almacenado en los sectores 1024 al 1536 del cilindro 45, cabeza 2. Para recuperar una foto, deberíamos recordar que ocupa los sectores 8192 al 12288 del cilindro 103.  

Este escenario es completamente impracticable. Los usuarios no pueden recordar direcciones físicas de miles de archivos, ni existe forma de dar nombres significativos a los datos. Sería imposible organizar la información de manera jerárquica, y el riesgo de sobrescribir datos accidentalmente sería altísimo. Sin un mecanismo de control, no existiría forma de implementar permisos o restricciones de acceso. Además, la pérdida de datos ante la corrupción de una pequeña región del disco sería total y catastrófica.
\begin{theory}
\emph{Sistema de Archivos (File System):}
Componente del sistema operativo que proporciona mecanismos para el almacenamiento, organización, manipulación, recuperación y administración de información en dispositivos de almacenamiento secundario.
\end{theory}

### Objetivos del File System

El sistema de archivos surge como una capa de abstracción entre el hardware de almacenamiento y el usuario o las aplicaciones. Esta capa de abstracción transforma el disco —que en realidad es solo un conjunto lineal de sectores físicos— en una estructura lógica organizada que podemos entender y manipular de forma intuitiva.  

El primer objetivo fundamental es el *naming*: permitir dar nombres significativos a conjuntos de datos. En lugar de recordar "sectores 1024-1536", podemos simplemente referirnos a "informe_final.pdf". Este concepto aparentemente simple revoluciona la forma en que interactuamos con el almacenamiento.  

La *organización* es otro pilar esencial. Los archivos se estructuran en jerarquías mediante directorios y subdirectorios, lo que nos permite agrupar información relacionada de manera lógica. Esta organización jerárquica refleja naturalmente cómo pensamos sobre nuestros datos.  

La *protección* garantiza que podamos controlar quién puede acceder a qué información. Mediante sistemas de permisos, establecemos barreras de seguridad que protegen datos sensibles y previenen modificaciones no autorizadas.  

La *persistencia* asegura que los datos sobrevivan al apagado del sistema. A diferencia de la memoria RAM, el almacenamiento secundario mantiene la información incluso sin energía eléctrica. El file system gestiona esta persistencia de manera transparente.  

La eficiencia optimiza tanto el uso del espacio disponible como la velocidad de acceso. El sistema debe minimizar el desperdicio de espacio y maximizar la velocidad con la que podemos leer y escribir información.  

Finalmente, la confiabilidad garantiza la *integridad de los datos ante fallas*. Mecanismos como journaling y verificaciones de consistencia protegen contra corrupción y pérdidas de información.
\begin{center}
agregar diagrama...
%%\includegraphics[width=0.7\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-jerarquiaAlmacenamiento.png}
\end{center}
## Archivos: Abstracción de Usuario

### Concepto de Archivo

En bases de datos y sistemas de información, existe una jerarquía conceptual bien definida. En el nivel más bajo encontramos el **campo**: una unidad mínima de información con significado propio, como "nombre", "edad" o "dirección". Un conjunto de campos relacionados que describen una entidad forma un **registro**. Por ejemplo, un registro de estudiante contiene campos como nombre, legajo, carrera y email. Finalmente, un **archivo** es una colección de registros del mismo tipo —el archivo "estudiantes.dat" contiene todos los registros de estudiantes de la institución.  

\begin{theory}
\emph{Archivo (desde la perspectiva del SO):}
Secuencia nombrada de bytes almacenada en dispositivo de almacenamiento secundario. El sistema operativo NO interpreta el contenido del archivo; esa es responsabilidad de las aplicaciones.
\end{theory}

Esta definición es crucial: para el sistema operativo, un archivo es simplemente una secuencia de bytes sin estructura interna. No existe diferencia entre un documento de texto, una imagen o un ejecutable a nivel del SO. La interpretación y estructura del contenido es responsabilidad exclusiva de las aplicaciones que usan esos archivos.

### Atributos de un Archivo

Cada archivo posee **metadatos** que el sistema operativo almacena y gestiona. Estos metadatos son información sobre el archivo, no el contenido del archivo en sí. El *nombre* es el identificador legible por humanos que usamos para referirnos al archivo. El *tipo* indica si es un archivo regular, un directorio, un enlace simbólico o un dispositivo. La *ubicación* contiene punteros a los bloques de datos físicos en el disco donde realmente se almacena el contenido.  
El *tamaño* registra la cantidad de bytes que ocupa el archivo. Los *permisos* especifican quién puede leer, escribir o ejecutar el archivo, divididos entre propietario, grupo y otros usuarios. Los *timestamps* mantienen tres marcas temporales: la creación (ctime), la última modificación del contenido (mtime) y el último acceso de lectura (atime).
El *propietario* se identifica mediante el UID (User ID) del usuario dueño del archivo, mientras que el *grupo* se identifica con el GID (Group ID) asociado. Finalmente, *el contador de enlaces* registra cuántos hard links apuntan al mismo archivo físico —concepto que exploraremos en detalle más adelante.

### File Control Block (FCB)

\begin{theory}
\emph{File Control Block (FCB):}
Estructura de datos que almacena todos los metadatos de un archivo. En sistemas Unix se denomina \textbf{inodo (inode)}. En FAT, la entrada de directorio cumple esta función.
\end{theory}
El FCB es fundamental porque separa la *identidad del archivo* —sus metadatos— de su *contenido* —los datos en bloques físicos. Esta separación permite que un archivo pueda tener múltiples nombres (hard links) pero mantener un solo FCB. Cuando creamos un segundo nombre para un archivo existente, no duplicamos sus datos ni sus metadatos completos; simplemente creamos otra entrada de directorio que apunta al mismo FCB.

### Operaciones sobre Archivos

El sistema operativo provee system calls para manipular archivos. Estas operaciones constituyen la interfaz entre las aplicaciones y el file system.

#### Operaciones Básicas

La operación `create(nombre)` crea un archivo nuevo. Internamente, asigna un FCB o inodo, crea una entrada en el directorio padre y inicializa los metadatos con valores por defecto: permisos según el umask, timestamps con la hora actual y tamaño igual a cero.  

Para trabajar con un archivo, primero debemos abrirlo mediante `open(nombre, modo)`. Esta operación busca el archivo en el directorio, verifica que tenemos los permisos necesarios para el modo de acceso solicitado (solo lectura, solo escritura o lectura-escritura), carga el FCB en memoria y retorna un file descriptor —un número entero que usaremos en operaciones posteriores.  

La lectura se realiza con `read(fd, buffer, cantidad)`. El sistema usa el file descriptor para ubicar el archivo abierto, copia los datos desde los bloques del disco al buffer en memoria que le indicamos, y actualiza internamente el puntero de lectura/escritura para que la próxima operación continúe desde donde terminó esta.  

De manera simétrica, `write(fd, buffer, cantidad)` escribe bytes al archivo. Si es necesario, el sistema asigna bloques nuevos para almacenar la información. Los datos se copian desde el buffer en memoria a los bloques en disco, y se actualizan el tamaño del archivo y sus timestamps.  

La operación `seek(fd, offset, whence)` permite mover el puntero de lectura/escritura sin leer ni escribir datos. Podemos posicionarnos desde el inicio del archivo (SEEK_SET), desde la posición actual (SEEK_CUR) o desde el final (SEEK_END). Esta capacidad es esencial para el acceso aleatorio a archivos.  

Cuando terminamos de trabajar con un archivo, `close(fd)` libera las estructuras en memoria asociadas, escribe a disco cualquier buffer pendiente (flush) y actualiza los metadatos finales. Es importante cerrar archivos para evitar pérdida de datos y agotamiento de file descriptors.  

Finalmente, `delete(nombre)` elimina un archivo. Más precisamente, decrementa el contador de enlaces. Solo cuando este contador llega a cero —cuando no quedan nombres apuntando al archivo— se liberan los bloques de datos y el FCB, y se elimina la entrada del directorio.

#### Operaciones Adicionales
Existen operaciones complementarias que permiten manipular archivos sin modificar su contenido.

`rename(viejo, nuevo)`: Cambia el nombre del archivo
`truncate(nombre, tamaño)`: Reduce el tamaño del archivo
`stat(nombre)`: Obtiene metadatos sin abrir el archivo
`chmod(nombre, permisos)`: Cambia permisos
`chown(nombre, uid, gid)`: Cambia propietario

### Métodos de Acceso

\begin{theory}
\emph{Método de Acceso:}
Forma en que los procesos leen y escriben datos en un archivo. Define el orden y la forma de acceso a la información.
\end{theory}
El método de acceso determina cómo una aplicación interactúa con el contenido del archivo. La elección del método correcto puede impactar dramáticamente el rendimiento.

#### Acceso Secuencial

En el acceso secuencial, los bytes se leen o escriben uno después del otro, desde el inicio hasta el final del archivo. Este patrón es simple de implementar y óptimo cuando necesitamos procesar archivos completos. El sistema operativo puede anticiparse a nuestras necesidades mediante prefetching, cargando bloques adicionales en caché antes de que los solicitemos explícitamente.

```c
// Lectura secuencial
int fd = open("datos.txt", O_RDONLY);
char buffer[1024];
while (read(fd, buffer, 1024) > 0) {
    // Procesar buffer
}
close(fd);
```
Los archivos de log, los archivos de texto y el procesamiento por lotes son candidatos ideales para acceso secuencial. La localidad temporal y espacial de este patrón permite al sistema optimizar agresivamente las operaciones de I/O.

#### Acceso Directo (Random Access)

El acceso directo permite leer o escribir cualquier byte del archivo sin recorrer los bytes anteriores. Simplemente calculamos la posición deseada y nos movemos allí con `seek()`.

```c
// Acceso directo
int fd = open("base_datos.dat", O_RDWR);
// Leer registro 100 (cada registro = 256 bytes)
lseek(fd, 100 * 256, SEEK_SET);
read(fd, &registro, 256);
close(fd);
```
Este patrón es ideal para bases de datos y estructuras indexadas donde necesitamos acceso instantáneo a registros específicos sin procesar todo el archivo. No hay penalidad por "saltar" a posiciones arbitrarias.

#### Acceso Indexado

El acceso indexado mantiene un índice separado que mapea claves lógicas a posiciones físicas en el archivo de datos. El índice actúa como un directorio que nos dice exactamente dónde buscar.

```
Archivo de índice:
  "Juan" → byte 0
  "María" → byte 256
  "Pedro" → byte 512

Archivo de datos:
  byte 0-255: datos de Juan
  byte 256-511: datos de María
  byte 512-767: datos de Pedro
```

Las búsquedas por clave son extremadamente rápidas. Podemos mantener múltiples índices sobre el mismo archivo —por ejemplo, uno por nombre y otro por ID— permitiendo consultas flexibles y eficientes.   Este método es la base de los sistemas de bases de datos modernos y las bibliotecas digitales.

## Directorios: Organización Jerárquica

### Concepto de Directorio

\begin{theory}
\emph{Directorio:}
Archivo especial que contiene una tabla de entradas, donde cada entrada asocia un nombre de archivo con su FCB/inodo. Permite organización jerárquica del file system.
\end{theory}

Aunque los directorios aparecen como carpetas en nuestra interfaz gráfica, en realidad son archivos con un propósito especial: contienen una tabla que mapea nombres a referencias de FCB. Cada entrada en un directorio es simplemente un par (nombre, referencia_a_FCB).

```c
struct directory_entry {
    char name[256];        // Nombre del archivo
    uint32_t inode_number; // Referencia al FCB (en Unix)
    uint8_t file_type;     // Regular, directorio, link, etc.
};
```

Esta estructura tan simple permite construir jerarquías complejas. Un directorio puede contener referencias a archivos regulares y a otros directorios, formando un árbol de organización.

### Estructuras de Directorios

#### Directorio de Un Nivel (Single-Level)

La estructura más simple coloca todos los archivos en un solo directorio raíz. No hay subdirectorios ni organización alguna.


```
/ (raíz)
  ├── programa1.c
  ├── programa2.c
  ├── datos.txt
  └── imagen.jpg
```

Este diseño es impracticable para sistemas reales. Sin capacidad de organizar archivos por categorías, los conflictos de nombres entre usuarios son inevitables. La estructura no escala cuando tenemos miles de archivos, y encontrar un archivo específico se convierte en una tarea imposible.

#### Directorio de Dos Niveles

Una mejora asigna a cada usuario su propio directorio personal. Esto resuelve los conflictos de nombres, ya que dos usuarios pueden tener archivos con el mismo nombre en sus espacios separados.

```
/
  ├── user1/
  │   ├── programa.c
  │   └── datos.txt
  └── user2/
      ├── programa.c  (mismo nombre, diferente archivo)
      └── imagen.jpg
```
Sin embargo, sigue siendo limitado: no permite subdivisiones dentro del espacio de cada usuario. No podemos crear una estructura lógica de proyectos, documentos y código dentro de nuestro directorio personal.

#### Estructura Jerárquica (Árbol)

La solución moderna permite que los directorios contengan otros directorios, formando un árbol jerárquico arbitrariamente profundo. Esta estructura refleja naturalmente cómo organizamos información en el mundo real.

```
/
├── home/
│   ├── alumno/
│   │   ├── documentos/
│   │   │   ├── apuntes.txt
│   │   │   └── ejercicios.pdf
│   │   └── proyectos/
│   │       └── tp1.c
│   └── profesor/
│       └── examen.txt
├── etc/
│   └── config.cfg
└── tmp/
    └── temporal.dat
```

Esta organización es intuitiva, escalable a millones de archivos, y permite aplicar permisos de manera jerárquica. Los namespaces quedan naturalmente separados por directorio, evitando conflictos de nombres.

#### Grafo Acíclico Dirigido (con Links)

Cuando permitimos hard links y soft links, la estructura deja de ser un árbol puro y se convierte en un grafo acíclico dirigido. Un mismo archivo puede ser accesible desde múltiples ubicaciones con diferentes nombres.

```
/home/alumno/
  ├── proyecto/
  │   └── datos.txt  (inodo 1234)
  └── backup/
      └── datos_respaldo.txt  (hard link a inodo 1234)
```

Ambos nombres apuntan al mismo archivo físico —mismo inodo, mismos bloques de datos. No hay duplicación, simplemente múltiples caminos para llegar al mismo contenido.

\begin{warning}
Los hard links a directorios NO se permiten (excepto . y ..) porque crearían ciclos en el grafo. Un ciclo haría imposible realizar operaciones como eliminación recursiva, que quedarían atrapadas en un bucle infinito.
\end{warning}

### Rutas: Absolutas y Relativas

#### Ruta Absoluta

\begin{theory}
\emph{Ruta Absoluta:}
Especifica la ubicación de un archivo desde el directorio raíz. Siempre comienza con \texttt{/} en Unix o \texttt{C:\textbackslash} en Windows.
\end{theory}

Una ruta absoluta es inequívoca: identifica exactamente un archivo sin importar desde dónde la invoquemos. `/home/alumno/documentos/apuntes.txt` siempre se refiere al mismo archivo, independientemente del directorio de trabajo actual.

*Ejemplos:*
```
/home/alumno/documentos/apuntes.txt
/etc/passwd
/var/log/syslog
```
Las rutas absolutas son esenciales en scripts y programas que pueden ejecutarse desde cualquier ubicación, donde no podemos asumir un directorio de trabajo específico.

#### Ruta Relativa

\begin{theory}
\emph{Ruta Relativa:}
Especifica la ubicación desde el directorio de trabajo actual. No comienza con \texttt{/}.
\end{theory}
Las rutas relativas son más convenientes para trabajo interactivo. En lugar de escribir la ruta completa, nos movemos relativamente a nuestra posición actual. El símbolo `.` representa el directorio actual, `..` representa el directorio padre, y `~` (expandido por el shell) representa nuestro directorio home.

*Ejemplos:*
```bash
# Si estoy en /home/alumno/proyectos/
./datos.txt              # /home/alumno/proyectos/datos.txt
../documentos/apuntes.txt   # /home/alumno/documentos/apuntes.txt
../../profesor/examen.txt   # /home/profesor/examen.txt
```

Notar cómo `..` nos permite "subir" en la jerarquía. Podemos encadenar múltiples `..` para navegar a directorios ancestros más lejanos.

### Operaciones sobre Directorios

Las operaciones sobre directorios son análogas a las de archivos, pero con semántica específica. `mkdir(nombre)` crea un directorio nuevo: asigna un FCB de tipo directorio, lo inicializa con las entradas especiales `.` (referencia a sí mismo) y `..` (referencia al padre), y añade una entrada en el directorio padre.

La operación `rmdir(nombre)` elimina un directorio, pero solo si está vacío —es decir, solo contiene `.` y `..`. Esta restricción previene la pérdida accidental de contenido. Para eliminar directorios con contenido, debemos hacerlo recursivamente, eliminando primero todos los archivos y subdirectorios.

Para leer el contenido de un directorio, usamos `opendir(nombre)`, `readdir(dir)` para obtener cada entrada sucesivamente, y `closedir(dir)` para finalizar. Finalmente, `chdir(nombre)` cambia el directorio de trabajo actual del proceso, afectando cómo se resuelven las rutas relativas.

## Estructuras Administrativas del SO

El sistema operativo mantiene varias estructuras en memoria para gestionar archivos abiertos eficientemente. Estas estructuras forman una jerarquía de tres niveles que separa las preocupaciones de cada proceso de las preocupaciones globales del sistema.

### Arquitectura de Tres Niveles

```
Proceso A                          Proceso B
+-----------------+                +-----------------+
| File Descriptor |                | File Descriptor |
| Table           |                | Table           |
|  0: stdin       |                |  0: stdin       |
|  1: stdout      |                |  1: stdout      |
|  2: stderr      |                |  2: stderr      |
|  3: -------+    |                |  3: -------+    |
|  4: ----+  |    |                |  4: ----+  |    |
+---------|--+----+                +---------|--+----+
          |  |                               |  |
          |  +-------------------+           |  |
          |                      |           |  |
          v                      v           v  v
    +---------------------------------------------+
    |    Open File Table (System-Wide)           |
    +---------------------------------------------+
    | Entry 0:                                    |
    |   - Modo: O_RDONLY                          |
    |   - Offset: 1024                            |
    |   - Ref count: 1                            |
    |   - Ptr a inodo: -----> Inodo 5678          |
    | Entry 1:                                    |
    |   - Modo: O_RDWR                            |
    |   - Offset: 0                               |
    |   - Ref count: 2  (compartido por A y B)    |
    |   - Ptr a inodo: -----> Inodo 1234          |
    +---------------------------------------------+
                                  |
                                  v
                        +-------------------+
                        |   Inode Table     |
                        +-------------------+
                        | Inodo 1234:       |
                        |   - Permisos      |
                        |   - Tamaño        |
                        |   - Bloques       |
                        | Inodo 5678:       |
                        |   - ...           |
                        +-------------------+
```

### Nivel 1: File Descriptor Table (por proceso)

Cada proceso mantiene su propia tabla de descriptores de archivo. Esta tabla es privada —no compartida con otros procesos— y contiene típicamente 1024 entradas, aunque este límite puede configurarse.

```c
struct file_descriptor_table {
    struct file *entries[OPEN_MAX];  // Típicamente 1024 entradas
};
```

El índice en esta tabla es el file descriptor: el número entero que retorna `open()` y que usamos en operaciones posteriores. Cada entrada apunta a una posición en la Open File Table global. Los primeros tres descriptores están reservados: 0 para stdin (entrada estándar), 1 para stdout (salida estándar) y 2 para stderr (error estándar). Estos descriptores preconfigurados permiten que los programas lean de la consola y escriban mensajes sin necesidad de abrir archivos explícitamente.

### Nivel 2: Open File Table (system-wide)

La Open File Table es una estructura global del sistema que mantiene información de todos los archivos abiertos por todos los procesos. A diferencia de la File Descriptor Table, esta tabla es compartida.

```c
struct open_file_entry {
    int mode;              // O_RDONLY, O_WRONLY, O_RDWR
    off_t offset;          // Posición actual de lectura/escritura
    int ref_count;         // Cantidad de descriptores apuntando aquí
    struct inode *inode;   // Puntero al inodo del archivo
    int flags;             // O_APPEND, O_NONBLOCK, etc.
};
```
Cada entrada mantiene el modo de apertura, el offset actual de lectura/escritura, un contador de referencias que indica cuántos file descriptors apuntan a esta entrada, y un puntero al inodo del archivo. Este nivel intermedio es crucial porque permite que múltiples procesos compartan el mismo offset —algo que ocurre cuando un proceso hace `fork()` después de abrir un archivo, heredando el file descriptor y compartiendo el offset con el padre. Sin embargo, diferentes procesos pueden abrir el mismo archivo con diferentes modos y offsets independientes simplemente creando entradas separadas en esta tabla.
\begin{infobox}
Múltiples procesos pueden compartir la misma entrada en Open File Table si se hizo \texttt{fork()} después de abrir el archivo, o si se pasó el descriptor via \texttt{dup()} o sockets UNIX. En estos casos, el offset es verdaderamente compartido: cuando un proceso lee, el offset avanza para todos los procesos que comparten la entrada.
\end{infobox}

### Nivel 3: Inode Table

La Inode Table es una caché en memoria de los inodos almacenados en disco. El sistema operativo mantiene aquí los inodos de todos los archivos actualmente abiertos.

```c
struct inode {
    mode_t mode;           // Tipo y permisos
    uid_t uid;             // Propietario
    gid_t gid;             // Grupo
    off_t size;            // Tamaño en bytes
    time_t atime, mtime, ctime;  // Timestamps
    blkcnt_t blocks;       // Bloques asignados
    uint32_t block_ptrs[15];  // Punteros a bloques
    int ref_count;         // Cantidad de open file entries
    // ... más campos
};
```

Este nivel es global: existe un solo inodo en memoria por cada archivo, sin importar cuántos procesos lo tengan abierto o cuántas entradas existan en la Open File Table. El inodo contiene todos los metadatos persistentes del archivo y los punteros a sus bloques de datos. Los cambios en el inodo —como actualizaciones de tamaño o timestamps— eventualmente se escriben de vuelta al disco.

### Ejemplo de Interacción
Veamos cómo interactúan estos tres niveles en un escenario concreto:

```c
// Proceso A
int fd1 = open("/home/alumno/datos.txt", O_RDONLY);  // fd1 = 3
read(fd1, buffer, 100);  // offset avanza a 100

// Proceso B (independiente)
int fd2 = open("/home/alumno/datos.txt", O_RDONLY);  // fd2 = 3
read(fd2, buffer, 50);   // offset avanza a 50 (INDEPENDIENTE de A)
```
Aquí, ambos procesos abrieron el mismo archivo, pero sus offsets son independientes. Cada proceso tiene su propia entrada en la Open File Table, aunque ambas entradas apuntan al mismo inodo. El proceso A puede estar leyendo desde el byte 100 mientras el proceso B lee desde el byte 50.  
Ahora consideremos un escenario diferente:

```c
// Proceso A hace fork()
pid_t pid = fork();
if (pid == 0) {
    // Hijo: heredó fd1, pero COMPARTE el offset con el padre
    read(fd1, buffer, 50);  // Lee desde byte 100, offset ahora en 150
}
// Padre: el offset también está en 150 (compartido)
```
Después del `fork()`, tanto el padre como el hijo tienen un file descriptor 3 que apunta a la misma entrada en la Open File Table. Por lo tanto, comparten el offset. Cuando el hijo lee 50 bytes, el offset avanza a 150, y el padre ve este cambio porque están mirando la misma estructura.

### File Locking: Sincronización de Acceso

Cuando múltiples procesos acceden al mismo archivo, pueden ocurrir race conditions. Si dos procesos intentan escribir simultáneamente en la misma posición, los datos podrían corromperse. El sistema operativo provee mecanismos de locking para coordinar el acceso.

#### Advisory Locking (flock)
El advisory locking es un mecanismo cooperativo. Los procesos voluntariamente solicitan locks antes de acceder al archivo.

```c
#include <sys/file.h>

int fd = open("archivo.dat", O_RDWR);

// Adquirir lock exclusivo
if (flock(fd, LOCK_EX) == 0) {
    // Sección crítica: solo este proceso puede escribir
    write(fd, datos, tamaño);
    flock(fd, LOCK_UN);  // Liberar lock
}
```

\begin{warning}
Este tipo de lock es "cooperativo". Un proceso malicioso o mal programado puede IGNORAR el lock y escribir sin solicitarlo. Se confía en que todos los procesos respeten el protocolo. Es responsabilidad de los desarrolladores usar estos locks consistentemente.
\end{warning}

#### Mandatory Locking (fcntl)
El mandatory locking es más robusto: el kernel impone los locks, bloqueando operaciones que violen restricciones activas.

```c
#include <fcntl.h>

struct flock lock;
lock.l_type = F_WRLCK;     // Write lock
lock.l_whence = SEEK_SET;
lock.l_start = 0;          // Desde byte 0
lock.l_len = 1024;         // Lockear 1024 bytes

// Intentar adquirir lock
if (fcntl(fd, F_SETLK, &lock) == -1) {
    perror("No se pudo obtener lock");
} else {
    // Tenemos el lock, trabajar con el archivo
    write(fd, datos, 1024);
    
    // Liberar
    lock.l_type = F_UNLCK;
    fcntl(fd, F_SETLK, &lock);
}
```

Existen dos tipos de locks: shared locks (F_RDLCK) permiten que múltiples procesos lean simultáneamente, mientras que exclusive locks (F_WRLCK) garantizan acceso exclusivo para escritura, bloqueando tanto lecturas como escrituras de otros procesos.
\begin{example}
Los locks son esenciales en sistemas de bases de datos para lockear registros específicos, en archivos de configuración para evitar escrituras concurrentes que podrían dejar el archivo en estado inconsistente, y en logs para coordinar appends de múltiples procesos sin sobrescribir datos.
\end{example}

## Protección y Permisos

### Modelo de Permisos Unix

Unix implementa un modelo simple pero efectivo de control de acceso basado en 9 bits que especifican permisos para tres categorías de usuarios: el propietario (owner), el grupo (group) y todos los demás (others).

```
-rwxr-xr--
│││││││││└─ Others: execute
││││││││└── Others: write
│││││││└─── Others: read
││││││└──── Group: execute
│││││└───── Group: write
││││└────── Group: read
│││└─────── Owner: execute
││└──────── Owner: write
│└───────── Owner: read
└────────── Tipo (- regular, d directorio, l link)
```

Los permisos también pueden expresarse en notación octal, donde cada grupo de tres bits forma un dígito:

| Owner | Group | Others | Octal |
|-------|-------|--------|-------|
| rwx | rwx | rwx | 777 |
| rwx | r-x | r-- | 754 |
| rw- | r-- | r-- | 644 |
| rwx | --- | --- | 700 |

#### Significado de los Permisos

Para archivos regulares, el permiso *read* permite leer el contenido, *write* permite modificar el contenido (pero no necesariamente eliminar el archivo), y *execute* permite ejecutar el archivo como programa.

Para directorios, la semántica es diferente. El permiso *read* permite listar el contenido del directorio mediante `readdir()`, pero no acceder a los archivos dentro. El permiso *write* permite crear o eliminar archivos en el directorio —esta es una distinción crucial. El permiso *execute* permite "atravesar" el directorio, es decir, acceder a archivos dentro de él aunque no podamos listar el contenido.

\begin{warning}
Para eliminar un archivo, NO se necesita permiso de escritura sobre el archivo mismo, sino sobre el DIRECTORIO que lo contiene. El directorio es quien mantiene la lista de nombres, y eliminar un archivo es simplemente remover su entrada de esa lista.
\end{warning}

### Verificación de Permisos

Cuando un proceso intenta abrir un archivo, el kernel ejecuta un algoritmo de verificación que considera la identidad del proceso (UID y GID efectivos) y los permisos del archivo.

La verificación procede en orden: primero se verifica si el proceso es el propietario del archivo. Si lo es, se evalúan únicamente los bits de permiso del owner, ignorando los bits de group y others. Si el proceso no es el propietario pero pertenece al grupo del archivo, se evalúan únicamente los bits de group. Finalmente, si el proceso no es owner ni miembro del group, se evalúan los bits de others.
```c
// Pseudocódigo simplificado
int check_permission(struct inode *inode, int operation) {
    uid_t process_uid = current->uid;
    gid_t process_gid = current->gid;
    
    // 1. ¿El proceso es el owner?
    if (process_uid == inode->uid) {
        if (operation == READ && (inode->mode & 0400)) return OK;
        if (operation == WRITE && (inode->mode & 0200)) return OK;
        if (operation == EXEC && (inode->mode & 0100)) return OK;
        return -EACCES;  // Owner pero sin permiso específico
    }
    
    // 2. ¿El proceso pertenece al group?
    if (process_gid == inode->gid) {
        if (operation == READ && (inode->mode & 0040)) return OK;
        if (operation == WRITE && (inode->mode & 0020)) return OK;
        if (operation == EXEC && (inode->mode & 0010)) return OK;
        return -EACCES;
    }
    
    // 3. Verificar permisos de others
    if (operation == READ && (inode->mode & 0004)) return OK;
    if (operation == WRITE && (inode->mode & 0002)) return OK;
    if (operation == EXEC && (inode->mode & 0001)) return OK;
    
    return -EACCES;  // Sin permisos
}
```

Es importante notar que esta verificación es en cascada: si somos owner, los permisos de group y others no importan. Esto puede crear situaciones contraintuitivas donde ser el propietario de un archivo nos da *menos* acceso que si fuéramos un usuario cualquiera, si configuramos los permisos de manera inadecuada.

\begin{infobox}
El usuario root (UID 0) bypasea todas las verificaciones de permisos. Root puede leer, escribir y ejecutar cualquier archivo del sistema, sin importar los permisos configurados. Esta es una de las razones por las que trabajar como root es peligroso: no hay red de seguridad que prevenga errores.
\end{infobox}

### Umask: Permisos por Defecto

Cuando creamos un archivo nuevo, el sistema debe decidir qué permisos asignarle. Aquí entra en juego el **umask**.

\begin{theory}
\emph{Umask:}
Máscara que especifica qué permisos NO otorgar al crear archivos nuevos. Se resta de los permisos solicitados mediante una operación AND con el complemento.
\end{theory}
```c
// Si umask = 0022 (octal)
// Permisos solicitados: 0666 (rw-rw-rw-)
// Permisos finales: 0666 & ~0022 = 0644 (rw-r--r--)

int fd = open("nuevo.txt", O_CREAT | O_WRONLY, 0666);
// El archivo se crea con permisos 0644 debido al umask
```

Los umask típicos son 0022 (usuario puede escribir, grupo y others solo leer, resultando en archivos 644 y directorios 755), 0002 (usuario y grupo pueden escribir, others solo leer, resultando en archivos 664 y directorios 775), y 0077 (solo el usuario tiene acceso, resultando en archivos 600 y directorios 700, máxima privacidad).

### Cambio de Permisos

Los permisos pueden modificarse después de crear un archivo mediante las system calls `chmod()` y `chown()`.
```c
#include <sys/stat.h>

// Cambiar permisos de un archivo
chmod("archivo.txt", 0644);  // rw-r--r--

// Cambiar propietario (requiere privilegios)
chown("archivo.txt", 1000, 1000);  // UID 1000, GID 1000
```

Desde la shell, estos comandos tienen sintaxis conveniente:
```bash
chmod 755 script.sh        # rwxr-xr-x
chmod u+x programa.c       # Agregar ejecución para owner
chmod go-w archivo.txt     # Quitar escritura a group y others
chown alumno:estudiantes datos.txt
```

La notación simbólica (`u+x`, `go-w`) es más legible para cambios incrementales, mientras que la notación octal (`755`) es más directa para configurar permisos completos de una vez.

## Implementación Física: Disco

Hasta ahora vimos la abstracción lógica de archivos y directorios. Ahora bajamos al nivel físico para entender cómo se almacenan realmente los datos en el disco y cómo el file system traduce operaciones lógicas en accesos físicos.

### Hardware: Sectores vs Bloques

#### Sectores (Físico)

\begin{theory}
\emph{Sector:}
Unidad mínima de transferencia de datos en el hardware del disco. Es una característica física impuesta por la controladora, no por el software.
\end{theory}

Los discos históricos usaban sectores de 512 bytes, un estándar que dominó desde los años 1980 hasta 2010. Los discos modernos y SSD han migrado al formato Advanced Format con sectores de 4096 bytes (4 KiB), mejorando eficiencia y reduciendo overhead.

El hardware del disco solo puede leer o escribir sectores completos. No existe forma de acceder a un byte individual sin leer todo el sector que lo contiene. Esta es una restricción fundamental del hardware que el file system debe manejar.

#### Bloques (Lógico)

\begin{theory}
\emph{Bloque (o Cluster):}
Unidad mínima de asignación utilizada por el file system. Agrupa uno o más sectores consecutivos. Es una abstracción del software, configurable al formatear el disco.
\end{theory}

El tamaño del bloque se elige al formatear el sistema de archivos. Si tenemos sectores de 512 bytes y elegimos bloques de 4 KiB, cada bloque agrupa 8 sectores consecutivos. Si tenemos sectores de 4 KiB y elegimos bloques de 4 KiB, hay correspondencia uno a uno.

| Aspecto | Sector | Bloque |
|---------|--------|--------|
| Naturaleza | Física (hardware) | Lógica (software) |
| Tamaño | Fijo por el disco | Configurable al formatear |
| Usado por | Controladora de disco | Sistema de archivos |
| Granularidad | Operaciones de bajo nivel | Asignación de archivos |

### ¿Por qué usar bloques en vez de sectores directamente?

La abstracción de bloques ofrece varias ventajas. Reduce la fragmentación al trabajar con unidades más grandes, disminuye la cantidad de entradas en estructuras administrativas (menos punteros que mantener), mejora el rendimiento al leer o escribir múltiples sectores de una sola vez, y simplifica la gestión de espacio libre.

\begin{example}
Un archivo de 100 KiB con bloques de 4 KiB requiere ⌈100 / 4⌉ = 25 bloques. Si usáramos sectores de 512 bytes directamente, necesitaríamos ⌈100 × 1024 / 512⌉ = 200 sectores. El sistema debe mantener 25 punteros en vez de 200, reduciendo significativamente el overhead de metadatos.
\end{example}

### Fragmentación Interna

El uso de bloques introduce un problema conocido como fragmentación interna. Si un archivo ocupa 5 KiB pero los bloques son de 4 KiB, debemos asignar 2 bloques completos (8 KiB), desperdiciando 3 KiB que no pueden ser usados por otros archivos. Este espacio queda atrapado dentro del bloque asignado.

\begin{warning}
El desperdicio promedio es la mitad del tamaño del bloque por archivo. Con bloques de 4 KiB, un archivo de 1 byte desperdicia aproximadamente 4095 bytes, y un archivo de 4097 bytes también desperdicia aproximadamente 4095 bytes. En promedio, cada archivo desperdicia unos 2 KiB.
\end{warning}

Existe un trade-off fundamental en la elección del tamaño de bloque:

| Tamaño | Fragmentación interna | Overhead metadatos | Rendimiento |
|--------|----------------------|-------------------|-------------|
| 1 KiB | Baja | Alto (muchos punteros) | Bajo |
| 4 KiB | Media | Medio | Medio |
| 8 KiB | Alta | Bajo | Alto (archivos grandes) |
| 64 KiB | Muy alta | Muy bajo | Muy alto (streaming) |

La elección típica de 4 KiB representa un buen balance para uso general, alineándose además con el tamaño de página de memoria en arquitecturas modernas.

## Métodos de Asignación de Espacio

El file system debe decidir cómo asignar bloques físicos del disco a los archivos lógicos. Esta decisión afecta el rendimiento, la fragmentación y la complejidad del sistema. Existen tres enfoques principales, cada uno con sus ventajas y desventajas.

### Método 1: Asignación Contigua

En la asignación contigua, todos los bloques de un archivo se almacenan en posiciones consecutivas del disco, uno detrás del otro sin interrupciones.

```
Disco:
+----+----+----+----+----+----+----+----+
| A  | A  | A  | A  | libre | B  | B  | B  |
+----+----+----+----+----+----+----+----+
  100  101  102  103   104    105  106  107

Archivo A: bloque inicial = 100, longitud = 4
Archivo B: bloque inicial = 105, longitud = 3
```

Para representar un archivo solo necesitamos dos números: el bloque inicial y la cantidad de bloques. Esta simplicidad es atractiva y hace que el acceso secuencial sea extremadamente rápido —el brazo del disco puede leer todos los bloques sin moverse. El acceso aleatorio también es eficiente porque podemos calcular directamente la posición física de cualquier byte.

Sin embargo, los problemas aparecen con el uso. La fragmentación externa se vuelve severa con el tiempo: después de crear y eliminar muchos archivos, el disco queda lleno de huecos pequeños que no pueden utilizarse eficientemente. Hacer crecer un archivo es difícil o imposible si no hay espacio contiguo después del último bloque —podríamos necesitar mover TODO el archivo a otra ubicación. Esto requiere compactación periódica del disco, una operación costosa que mueve archivos para eliminar los huecos.

\begin{infobox}
La asignación contigua es ideal para medios de solo lectura como CD-ROM y DVD, donde los archivos nunca crecen ni se eliminan. En estos contextos, sus ventajas de rendimiento brillan sin sufrir sus desventajas de fragmentación.
\end{infobox}

### Método 2: Asignación Enlazada

En la asignación enlazada, cada bloque contiene datos y un puntero al siguiente bloque, formando una lista enlazada dispersa por el disco.

```
Archivo A: primer bloque = 45
+--------+--------+
| Datos  | ptr=78 |  Bloque 45
+--------+--------+
              |
              v
+--------+--------+
| Datos  | ptr=12 |  Bloque 78
+--------+--------+
              |
              v
+--------+--------+
| Datos  | NULL   |  Bloque 12 (último)
+--------+--------+
```
Este método elimina completamente la fragmentación externa —cualquier bloque libre puede ser usado— y los archivos pueden crecer dinámicamente sin necesidad de mover datos existentes. Solo necesitamos guardar el bloque inicial en los metadatos del archivo; el resto de la información de ubicación está distribuida en los punteros.

Los problemas surgen con el acceso aleatorio. Para leer el byte 10,000 de un archivo con bloques de 4 KiB, debemos calcular que está en el bloque número 2 (10,000 / 4096). Pero para llegar al bloque 2, debemos leer el bloque 0, seguir su puntero al bloque 1, seguir ese puntero al bloque 2, y finalmente leer los datos. Son 3 accesos a disco en vez de 1. La pérdida de un puntero puede corromper el resto del archivo, y parte del espacio de cada bloque se desperdicia almacenando el puntero en vez de datos.

#### Mejora: FAT (File Allocation Table)

FAT mejora la asignación enlazada moviendo todos los punteros a una tabla centralizada en memoria.

```
Tabla FAT:
Índice  Valor
  45  →  78
  78  →  12
  12  → EOF
```

Ahora los bloques de datos quedan completos —no contienen punteros— y la tabla FAT se cachea en memoria para acceso rápido. La pérdida de datos en un bloque solo afecta su contenido, no la cadena de punteros completa. La recuperación ante corrupción es más fácil porque la estructura crítica está separada de los datos.

Este es el método usado por el File System FAT de Microsoft, que veremos en detalle en secciones posteriores.

### Método 3: Asignación Indexada

La asignación indexada usa un bloque especial (bloque de índice) que contiene punteros a todos los bloques de datos del archivo.

```
Archivo A: bloque índice = 500

Bloque Índice 500:
+------+------+------+------+
| 123  | 456  | 789  | 234  |
+------+------+------+------+
   |      |      |      |
   v      v      v      v
 Datos  Datos  Datos  Datos
 (123)  (456)  (789)  (234)
```

El acceso aleatorio es eficiente: para leer el byte 10,000 con bloques de 4 KiB, calculamos que está en el bloque 2, leemos el bloque de índice, obtenemos el puntero en la posición 2 (que es 789), y leemos el bloque 789. Son solo 2 accesos a disco. No hay fragmentación externa, y toda la información de ubicación está consolidada en un solo lugar, facilitando operaciones como truncar o eliminar el archivo.

El costo es el overhead del bloque de índice —archivos pequeños desperdician la mayor parte de este bloque— y el tamaño máximo de archivo está limitado por cuántos punteros caben en un bloque. Con bloques de 4 KiB y punteros de 4 bytes, caben 1024 punteros, limitando el tamaño máximo a 1024 × 4 KiB = 4 MiB. Para archivos más grandes, se usan índices multinivel, una técnica que veremos al estudiar EXT2.

### Comparación de Métodos

| Aspecto | Contigua | Enlazada (FAT) | Indexada |
|---------|----------|----------------|----------|
| Fragmentación externa | Alta | Ninguna | Ninguna |
| Tamaño dinámico | No | Sí | Sí |
| Acceso secuencial | Excelente | Bueno | Bueno |
| Acceso aleatorio | Excelente | Muy malo | Excelente |
| Overhead metadatos | Mínimo | Medio (tabla FAT) | Alto (bloques índice) |
| Confiabilidad | Alta | Media | Alta |
| Complejidad | Muy simple | Simple | Moderada |

\begin{center}
agregar diagrama
%%\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-metodosAsignacion.png}
\end{center}

## Manejo de Espacio Libre

Además de rastrear qué bloques pertenecen a qué archivos, el file system debe mantener información sobre qué bloques están libres y disponibles para asignación. La eficiencia de esta estructura impacta directamente el rendimiento de creación de archivos y escrituras que requieren bloques adicionales.

### Método 1: Bitmap de Bloques

Un bitmap es un array de bits donde cada bit representa un bloque del disco. Si el bit está en 1, el bloque está ocupado; si está en 0, está libre.

```
Bitmap (1 = ocupado, 0 = libre):
[1 1 1 1 0 0 0 1 1 0 1 1 1 0 0 0 ...]
 0 1 2 3 4 5 6 7 8 9...

Bloque 0: ocupado
Bloque 4: libre
Bloque 5: libre
```
Para buscar un bloque libre, recorremos el bitmap buscando el primer bit en 0. Cuando lo encontramos, lo cambiamos a 1 para marcarlo como ocupado. Para liberar un bloque, simplemente cambiamos su bit a 0.

```c
// Buscar primer bit en 0
for (int i = 0; i < total_bloques; i++) {
    if (bitmap[i / 8] & (1 << (i % 8)) == 0) {
        // Bloque i está libre
        bitmap[i / 8] |= (1 << (i % 8));  // Marcar como ocupado
        return i;
    }
}

// Liberar bloque
bitmap[bloque / 8] &= ~(1 << (bloque % 8));
```

El bitmap es extremadamente compacto —solo 1 bit por bloque— y buscar bloques contiguos es relativamente fácil (buscamos secuencias de bits en 0). Para un disco de 500 GB con bloques de 4 KiB, tenemos 131.072.000 bloques, y el bitmap ocupa aproximadamente 16 MB. Este overhead es razonable y el bitmap típicamente se mantiene cacheado en memoria.

### Método 2: Lista Enlazada de Bloques Libres

En este método, los bloques libres forman una lista enlazada donde cada bloque libre contiene el número del siguiente bloque libre.

```
Head → Bloque 45 → Bloque 78 → Bloque 12 → NULL
```

Este enfoque es ineficiente para encontrar bloques contiguos y requiere accesos a disco para explorar la lista. Parte del espacio en los bloques libres se desperdicia almacenando punteros. Este método era común en sistemas antiguos pero ha sido mayormente abandonado en favor de bitmaps.

### Método 3: Agrupamiento

El agrupamiento combina ideas de bitmap y lista: cada entrada de la lista apunta a un grupo de bloques contiguos.

```
Head → [45-48] → [78-82] → [100-103] → NULL
```
Esto reduce la cantidad de punteros necesarios y facilita encontrar bloques contiguos cuando los necesitamos.

### Método Usado en Práctica

Los file systems modernos han convergido en soluciones eficientes. EXT2/3/4 usa bitmap de bloques por su simplicidad y eficiencia. FAT reutiliza la misma tabla FAT (una entrada con valor 0x0000 indica bloque libre). NTFS usa bitmap de bloques junto con su Master File Table (MFT).

## Seguridad y Recuperación

### Journaling: Registro de Transacciones

\begin{theory}
\emph{Journaling:}
Técnica que registra cambios ANTES de aplicarlos al file system. Si ocurre un fallo durante una operación, el sistema puede usar el journal para completar o deshacer operaciones incompletas, manteniendo consistencia.
\end{theory}

Sin journaling, un corte de energía durante una operación puede dejar el file system en estado inconsistente. Supongamos que estamos escribiendo un archivo nuevo. El proceso requiere actualizar el bitmap (marcar bloques como usados), crear o actualizar el inodo, actualizar el directorio padre y escribir los datos. Si el sistema se apaga después de actualizar el bitmap pero antes de escribir el inodo, tenemos bloques marcados como usados que no pertenecen a ningún archivo —espacio perdido que ni siquiera podemos recuperar fácilmente.

El journaling resuelve este problema registrando nuestras intenciones antes de ejecutarlas. Primero escribimos al journal: "Voy a asignar bloque 500 a inodo 1234, actualizar directorio /home/user". Luego marcamos esta operación como COMMIT —lista para aplicar. Después aplicamos los cambios reales al bitmap, inodo, directorio y datos. Finalmente, marcamos la operación como CLEANUP —completada exitosamente.

Si el sistema se apaga durante el paso de aplicar cambios, al reiniciar el sistema operativo lee el journal. Ve que hay una operación con COMMIT pero sin CLEANUP, lo que indica que comenzó pero no terminó. El sistema vuelve a aplicar los cambios —las operaciones son idempotentes, aplicarlas dos veces produce el mismo resultado que una vez. El file system queda consistente sin pérdida de datos.

Existen diferentes niveles de journaling con diferentes garantías de seguridad y costos de rendimiento. El modo *metadata only* solo registra cambios en inodos, directorios y bitmaps, ofreciendo alto rendimiento pero protección media. El modo *ordered* registra metadata y además garantiza que los datos se escriben ANTES del commit, evitando que un archivo con tamaño actualizado contenga basura en los bloques recién asignados. El modo *full data* registra tanto metadata como el contenido completo de los archivos, ofreciendo máxima seguridad a costa de rendimiento significativamente menor.

\begin{highlight}
La ventaja principal del journaling es la recuperación casi instantánea después de un crash. En lugar de escanear todo el disco con fsck (lo que puede tardar horas en discos grandes), simplemente reproducimos las entradas del journal (operación que toma segundos).
\end{highlight}

Los file systems modernos implementan journaling: EXT3, EXT4, XFS, NTFS, HFS+ y Btrfs todos proveen esta protección.

### fsck / chkdsk: File System Consistency Check

\begin{theory}
\emph{fsck (File System Consistency Check):}
Herramienta que verifica y repara inconsistencias en un file system NO montado. Escanea inodos, directorios, bitmaps y bloques de datos buscando y corrigiendo errores estructurales.
\end{theory}

`fsck` se ejecuta después de un apagado incorrecto en sistemas sin journaling, periódicamente cada N montajes o M días como mantenimiento preventivo, o manualmente cuando se detecta corrupción. La herramienta debe ejecutarse con el file system desmontado para evitar modificaciones durante la verificación.

La operación de `fsck` en EXT2 procede en cinco fases. La Fase 1 verifica inodos: que la estructura de cada inodo sea válida, que los bloques referenciados estén dentro del rango del disco, y que el tipo de archivo sea válido. La Fase 2 verifica directorios: que las entradas apunten a inodos válidos, que no existan ciclos en la estructura, y que cada directorio tenga las entradas especiales `.` y `..` correctas.

La Fase 3 verifica conectividad: todos los inodos marcados como usados deben ser accesibles desde el directorio raíz. Los inodos huérfanos —que existen pero no tienen entrada de directorio— se mueven a `/lost+found` donde el usuario puede inspeccionarlos. La Fase 4 verifica contadores: el campo `links_count` de cada inodo debe coincidir con la cantidad real de entradas de directorio que apuntan a él. Si no coincide, se corrige.

Finalmente, la Fase 5 verifica bitmaps: el bitmap de bloques debe coincidir exactamente con qué bloques están realmente en uso, el bitmap de inodos debe coincidir con qué inodos están usados, y los contadores de espacio libre en el superbloque deben ser correctos.

\begin{example}
Problemas comunes que fsck detecta y repara:

- "Bloque X reclamado por múltiples inodos" → hay que elegir a cuál pertenece
- "Inodo Y no tiene entrada de directorio" → mover a /lost+found
- "Directorio Z referencia inodo inexistente" → eliminar entrada corrupta
- "links\_count incorrecto en inodo W" -> corregir contador
- "Bloques marcados como libres pero en uso" → corregir bitmap
\end{example}

\begin{warning}
Las desventajas de fsck son significativas. En discos grandes de varios terabytes, la verificación completa puede tardar HORAS. El file system debe desmontarse durante la operación, dejándolo offline. Además, fsck solo detecta y repara inconsistencias estructurales; no puede recuperar datos que se perdieron físicamente.
\end{warning}

En Windows, el equivalente es `chkdsk` (Check Disk):
```bash
# Linux
fsck /dev/sda1         # Verificar partición
fsck -y /dev/sda1      # Auto-reparar sin preguntar

# Windows
chkdsk C:              # Verificar
chkdsk C: /F           # Reparar
```

## Caso de Estudio 1: FAT (File Allocation Table)

FAT es uno de los sistemas de archivos más simples y ampliamente soportados. Creado por Microsoft para MS-DOS entre 1977 y 1980, sigue siendo el estándar de facto en dispositivos portátiles como pendrives y tarjetas SD.

### Características Generales

Antes de sumergirnos en los detalles técnicos, es crucial entender una diferencia conceptual fundamental que distingue a FAT de sistemas más sofisticados como EXT2.
\begin{warning}
En FAT NO existe el concepto de FCB/inodo como estructura separada. La entrada del directorio contiene DIRECTAMENTE todos los metadatos del archivo: nombre, tamaño, primer cluster, atributos y timestamps. La tabla FAT solo contiene información de enlazamiento entre clusters, no metadatos completos.
\end{warning}
Esta arquitectura unificada hace que FAT sea más simple de implementar, pero también más limitado en funcionalidad. No hay separación entre la identidad del archivo y su ubicación en el directorio, lo que imposibilita características como hard links.

### Componentes de FAT
El volumen FAT se estructura en cinco regiones distintas, cada una con un propósito específico:

```
Estructura del volumen FAT:
+----------------+
| Boot Sector    |  Sector 0: parámetros del FS
+----------------+
| FAT 1         |  Tabla de asignación principal
+----------------+
| FAT 2         |  Copia de respaldo
+----------------+
| Root Directory |  Solo en FAT12/16 (ubicación fija)
+----------------+
| Data Area      |  Clusters de datos (numerados desde 2)
+----------------+
```

\begin{center}
agregar diagrama
%%\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-estructuraFAT.png}
\end{center}

#### 1. Boot Sector

El primer sector del volumen contiene los parámetros fundamentales del file system. Aquí se especifican los bytes por sector (típicamente 512 o 4096), los sectores por cluster (siempre una potencia de 2), la cantidad de tablas FAT (típicamente 2 para redundancia), el tamaño de las tablas FAT y el tipo específico de FAT (12, 16 o 32 bits).

#### 2. Tabla FAT

La tabla FAT es esencialmente un array de entradas donde cada índice representa un cluster del disco.  
Esta tabla implementa el método de asignación enlazada que estudiamos anteriormente.

```
Índice     Valor        Significado
--------------------------------------
0          Reservado    Media descriptor
1          Reservado    Marcador de limpieza
2          0x0003       Cluster 2 apunta a cluster 3
3          0x0004       Cluster 3 apunta a cluster 4
4          0xFFFF       Fin de cadena (último cluster)
5          0x0000       Cluster libre
6          0x0008       Cluster 6 apunta a cluster 8
7          0xFFF7       Bad cluster (sector defectuoso)
8          0xFFFF       Fin de cadena
```

Los valores en la tabla tienen significados específicos. El valor `0x0000` indica un cluster libre disponible para asignación. Valores entre `0x0002` y `0xFFEF` son punteros que indican el siguiente cluster del archivo. El valor `0xFFF7` marca un bad cluster —un sector físicamente defectuoso que debe evitarse— y valores entre `0xFFF8` y `0xFFFF` marcan el final de una cadena de clusters.
\begin{infobox}
La tabla FAT se mantiene duplicada (FAT 1 y FAT 2) para proporcionar redundancia básica. Si la primera copia se corrompe, el sistema puede recuperar usando la segunda. Esta es una de las pocas características de confiabilidad de FAT.
\end{infobox}

#### 3. Entrada de Directorio

Cada archivo o subdirectorio tiene una entrada de exactamente 32 bytes en su directorio padre. Esta estructura compacta contiene toda la información necesaria para acceder al archivo.

```c
struct fat_directory_entry {
    char name[8];              // Nombre (sin extensión)
    char extension[3];         // Extensión (sin el punto)
    uint8_t attributes;        // Ver atributos abajo
    uint8_t reserved[10];      // Reservado (case, timestamps extendidos)
    uint16_t time;             // Hora de última modificación
    uint16_t date;             // Fecha de última modificación
    uint16_t first_cluster;    // Número del primer cluster (FAT16)
    uint32_t file_size;        // Tamaño en bytes
};  // Total: 32 bytes
```

El campo `attributes` es un byte de flags donde cada bit tiene un significado específico:

| Bit | Nombre | Significado |
|-----|--------|-------------|
| 0 | READ_ONLY | Archivo de solo lectura |
| 1 | HIDDEN | Archivo oculto |
| 2 | SYSTEM | Archivo de sistema |
| 3 | VOLUME_LABEL | Etiqueta del volumen (no es archivo) |
| 4 | DIRECTORY | Es un subdirectorio |
| 5 | ARCHIVE | Modificado desde último backup |

La limitación histórica más notoria de FAT es el esquema de nombres 8.3: ocho caracteres para el nombre más tres para la extensión. Nombres más largos se truncan usando una notación con tilde: "documento.txt" se convierte en "DOCUMEN~1.TXT", y "mi archivo largo.doc" en "MIARCH~1.DOC".

\begin{infobox}
FAT32 y las extensiones VFAT agregaron soporte para nombres largos usando entradas de directorio adicionales especialmente codificadas. Sin embargo, internamente el sistema sigue siendo 8.3, y cada nombre largo requiere múltiples entradas de 32 bytes encadenadas.
\end{infobox}

### Concepto de Cluster

\begin{theory}
\emph{Cluster (en FAT):}
Unidad mínima de asignación. Agrupa varios sectores consecutivos. El tamaño del cluster depende del tamaño de la partición y se elige al formatear.
\end{theory}

Por ejemplo, si los sectores son de 512 bytes y elegimos clusters de 4 KiB, cada cluster agrupa 8 sectores consecutivos. Esta agrupación reduce el overhead de la tabla FAT —menos entradas que mantener— pero aumenta la fragmentación interna, especialmente en archivos pequeños.

### FAT12, FAT16, FAT32: Evolución

Las tres variantes de FAT difieren principalmente en el tamaño de las entradas de la tabla FAT, lo que determina cuántos clusters pueden direccionar:

| Versión | Bits/entrada | Clusters máximos | Tamaño máx partición |
|---------|--------------|------------------|----------------------|
| FAT12 | 12 bits | 4.096 (2¹²) | ~32 MiB (clusters de 8 KiB) |
| FAT16 | 16 bits | 65.536 (2¹⁶) | ~2 GiB (clusters de 32 KiB) |
| FAT32 | 32 bits (28 usados) | ~268 millones | ~2 TiB (clusters de 32 KiB) |

FAT12 dominó la era de los disquetes de 1.44 MiB en los años 1980 y 1990. FAT16 fue el estándar para discos duros pequeños hasta 2 GiB en MS-DOS y Windows 95. FAT32, introducido con Windows 95 OSR2 en 1996, sigue siendo el estándar actual en pendrives y tarjetas SD por su compatibilidad universal.

\begin{warning}
Aunque una partición FAT32 puede ser de 2 TB, el sistema NO puede almacenar archivos individuales mayores a 4 GiB. Esta limitación proviene del campo \texttt{file\_size} de 32 bits en la entrada de directorio: $2^{32}$ bytes = 4 GiB exactos. Intentar copiar un archivo de 5 GiB a un pendrive FAT32 fallará, independientemente del espacio libre disponible.
\end{warning}

### Ejemplo de Operación: Lectura de Archivo

Veamos paso a paso cómo FAT lee un archivo, siguiendo la cadena de clusters. Consideremos un archivo "documento.txt" de 12 KiB, con clusters de 4 KiB y primer cluster en la posición 245.

El proceso comienza buscando en el directorio padre. Leemos el directorio, encontramos la entrada con `name="DOCUMEN~1"` y `extension="TXT"`, y obtenemos `first_cluster = 245`.

Ahora leemos el primer cluster de 4 KiB accediendo al cluster 245 en el área de datos y copiando 4 KiB a memoria. Consultamos la tabla FAT: `FAT[245] = 246`, lo que indica que hay más datos en el cluster 246.

Leemos el segundo cluster accediendo al cluster 246, acumulando 8 KiB. Consultamos nuevamente: `FAT[246] = 247`, todavía hay más datos.

Leemos el tercer cluster en la posición 247, completando los 12 KiB del archivo. La consulta final `FAT[247] = 0xFFFF` indica EOF (end of file), señalando que hemos llegado al final.

El costo total es aproximadamente 4 accesos reales a disco: uno para el directorio más tres para los clusters de datos. Las tres consultas a la tabla FAT típicamente se resuelven desde memoria, ya que el sistema operativo mantiene la tabla FAT cacheada en RAM para mejorar el rendimiento.

\begin{example}
Para un archivo de 100 KiB con clusters de 4 KiB, necesitaríamos seguir 25 punteros en la tabla FAT. Si todos estos punteros están en memoria (lo cual es típico), el costo es solo 25 lecturas de clusters de datos, no 50 operaciones de I/O.
\end{example}

## Caso de Estudio 2: EXT2 / UFS (Unix File System)

EXT2 (Second Extended File System) es el sistema de archivos clásico de Linux, basado conceptualmente en UFS de BSD Unix. Representa una evolución significativa sobre FAT, introduciendo características que soportan entornos multiusuario robustos y archivos de gran tamaño.

### Filosofía de Diseño

La diferencia arquitectural fundamental con FAT es la separación clara entre metadatos y nombres. Los **inodos** almacenan todos los metadatos del archivo excepto su nombre: permisos, propietario, tamaños, timestamps y punteros a bloques de datos. Los **directorios** solo almacenan pares simples de (nombre, número_de_inodo).

Esta separación elegante permite funcionalidades que FAT no puede ofrecer. Los hard links se vuelven triviales: múltiples nombres en diferentes directorios pueden referenciar el mismo número de inodo. Los permisos robustos de Unix (owner, group, others con lectura, escritura y ejecución) se almacenan naturalmente en el inodo. La información extendida puede agregarse al inodo sin modificar las entradas de directorio, manteniendo compatibilidad hacia atrás.

### Estructura General: Block Groups

EXT2 divide el volumen completo en **grupos de bloques** (block groups) para mejorar la localidad de los datos.
```
+-------------+------------------+------------------+-----+
| Boot Block  | Block Group 0    | Block Group 1    | ... |
| (1024 bytes)|                  |                  |     |
+-------------+------------------+------------------+-----+
```

\begin{center}
agregar diagrama
%%\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-estructuraEXT2.png}
\end{center}

La organización en block groups no es arbitraria. Esta estructura mejora la localidad manteniendo el inodo de un archivo y sus bloques de datos cerca físicamente, típicamente en el mismo grupo. Proporciona escalabilidad mediante una estructura repetida que permite volúmenes enormes sin overhead excesivo. Aumenta la confiabilidad replicando el superbloque crítico en múltiples grupos. Y reduce la fragmentación manteniendo juntos los archivos de un mismo directorio.

### Componentes de un Block Group

Cada grupo de bloques contiene una estructura idéntica con cinco componentes:
```
+------------+-----+----------+----------+-------------+--------------+
| Superblock | GDT | Bitmaps  | Bitmaps  | Inode Table | Data Blocks  |
| (1 block)  |(var)| Bloques  | Inodos   | (var blocks)| (resto)      |
|            |     | (1 block)| (1 block)|             |              |
+------------+-----+----------+----------+-------------+--------------+
```

#### 1. Superbloque

\begin{theory}
\emph{Superbloque:}
Estructura crítica que contiene metadatos globales del file system. Se replica en varios block groups para redundancia, permitiendo recuperación si el superbloque principal se corrompe.
\end{theory}
La estructura del superbloque mantiene información esencial del sistema de archivos:

```c
struct ext2_superblock {
    uint32_t s_inodes_count;      // Total de inodos
    uint32_t s_blocks_count;      // Total de bloques
    uint32_t s_free_blocks_count; // Bloques libres
    uint32_t s_free_inodes_count; // Inodos libres
    uint32_t s_first_data_block;  // Primer bloque de datos (0 o 1)
    uint32_t s_log_block_size;    // Tamaño de bloque (log2(size) - 10)
    uint32_t s_blocks_per_group;  // Bloques por grupo
    uint32_t s_inodes_per_group;  // Inodos por grupo
    uint16_t s_magic;             // Magic number: 0xEF53
    // ... más campos (mtime, state, creator_os, etc.)
};
```

El magic number `0xEF53` identifica inequívocamente un volumen EXT2, permitiendo al sistema operativo detectar el tipo de file system al montar. El superbloque se copia estratégicamente en los grupos 0, 1 y en grupos cuyo número es potencia de 3, 5 o 7, balanceando redundancia con overhead de espacio.

#### 2. Group Descriptor Table (GDT)

La GDT es un array que describe cada block group del sistema. Cada entrada contiene punteros a las estructuras administrativas del grupo:

```c
struct ext2_group_desc {
    uint32_t bg_block_bitmap;       // Bloque que contiene bitmap de bloques
    uint32_t bg_inode_bitmap;       // Bloque que contiene bitmap de inodos
    uint32_t bg_inode_table;        // Primer bloque de la inode table
    uint16_t bg_free_blocks_count;  // Bloques libres en este grupo
    uint16_t bg_free_inodes_count;  // Inodos libres en este grupo
    uint16_t bg_used_dirs_count;    // Cantidad de directorios en el grupo
    uint16_t bg_pad;                // Padding para alineación
};
```

#### 3. Bitmaps

EXT2 usa bitmaps para rastrear espacio libre, una técnica eficiente que vimos anteriormente. El **block bitmap** dedica 1 bit por bloque del grupo: 1 indica ocupado, 0 indica libre. El **inode bitmap** usa la misma técnica para los inodos del grupo.

```
Ejemplo: [1 1 1 1 0 0 0 1 1 0 1 1 1 0 0 0]
         Bloques 0-3: ocupados
         Bloques 4-6: libres
         Bloque 7: ocupado
```

Las operaciones son simples y eficientes. Para buscar un bloque o inodo libre, escaneamos el bitmap hasta encontrar un bit en 0. Para asignar, cambiamos el bit a 1 y decrementamos el contador correspondiente en el superbloque y el GDT. Para liberar, cambiamos el bit a 0 e incrementamos los contadores.

#### 4. Inode Table

La tabla de inodos es un array de estructuras inodo. Cada grupo tiene su propia tabla con `inodes_per_group` entradas. El tamaño típico de cada inodo es 128 bytes, aunque puede configurarse a 256 bytes para soportar características extendidas.

#### 5. Data Blocks

El resto del grupo está dedicado a data blocks: los bloques donde realmente se almacena el contenido de archivos y directorios. Esta es la porción más grande de cada grupo, representando la mayor parte del espacio utilizable.

### El Inodo: Corazón de EXT2

\begin{theory}
\emph{Inodo (Index Node):}
Estructura de datos que almacena todos los metadatos de un archivo EXCEPTO su nombre. Contiene permisos, tamaños, timestamps y los punteros cruciales a los bloques de datos.
\end{theory}
La estructura completa del inodo es:

```c
struct ext2_inode {
    uint16_t i_mode;          // Tipo de archivo y permisos
    uint16_t i_uid;           // User ID del propietario
    uint32_t i_size;          // Tamaño en bytes (límite 4 GB en EXT2)
    uint32_t i_atime;         // Tiempo de último acceso
    uint32_t i_ctime;         // Tiempo de creación/cambio de metadatos
    uint32_t i_mtime;         // Tiempo de última modificación de datos
    uint32_t i_dtime;         // Tiempo de eliminación
    uint16_t i_gid;           // Group ID
    uint16_t i_links_count;   // Cantidad de hard links
    uint32_t i_blocks;        // Cantidad de bloques (en unidades de 512 bytes)
    uint32_t i_flags;         // Flags del archivo
    
    // Punteros a bloques de datos (15 punteros)
    uint32_t i_block[15];     // [0-11] directos, [12] ind. simple, 
                              // [13] ind. doble, [14] ind. triple
    
    uint32_t i_generation;    // Número de versión (para NFS)
    uint32_t i_file_acl;      // Access Control List extendida
    uint32_t i_dir_acl;       // (EXT2) o i_size_high (EXT4)
    // ... más campos
};  // Total: 128 bytes típicamente
```

### Esquema de Punteros del Inodo

El inodo contiene **15 punteros** que permiten acceder a los bloques de datos:

```
INODO
+------------------+
| Metadatos        |
| (mode, uid, size)|
+------------------+
| i_block[0]   ----|----> Bloque de datos directo (4 KiB)
| i_block[1]   ----|----> Bloque de datos directo (4 KiB)
| i_block[2]   ----|----> Bloque de datos directo (4 KiB)
| ...              |
| i_block[11]  ----|----> Bloque de datos directo (4 KiB)  [12 × 4 KiB = 48 KiB]
+------------------+
| i_block[12]  ----|----> Bloque indirecto simple
|                  |         |
|                  |         +---> [ptr0 | ptr1 | ... | ptr1023]
|                  |                  |      |            |
|                  |                  v      v            v
|                  |               Datos  Datos        Datos
+------------------+
| i_block[13]  ----|----> Bloque indirecto doble
|                  |         |
|                  |         +---> [ptr0 | ptr1 | ... | ptr1023]
|                  |                  |      |            |
|                  |                  v      v            v
|                  |            [Ind. Simple] [Ind. Simple] ...
|                  |                  |           |
|                  |                  v           v
|                  |               Datos       Datos
+------------------+
| i_block[14]  ----|----> Bloque indirecto triple
|                  |         |
|                  |         +---> [ptrs] ---> [Ind. Dobles] ---> [Ind. Simples] ---> Datos
+------------------+
```

\begin{center}
agregar diagrama
%%\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-estructuraInodo.png}
\end{center}

Los primeros 12 punteros son directos: apuntan inmediatamente a bloques de datos. Esto hace que archivos pequeños (hasta 48 KiB con bloques de 4 KiB) sean extremadamente eficientes —solo se necesita leer el inodo y luego directamente los bloques de datos.  
El puntero 13 (indirecto simple) apunta a un bloque que contiene punteros. Con bloques de 4 KiB y punteros de 4 bytes, caben 1024 punteros, lo que permite direccionar $1024 × 4 KiB = 4 MiB$ adicionales.  
El puntero 14 (indirecto doble) apunta a un bloque de punteros a bloques de punteros. Esto permite $1024 × 1024 × 4 KiB = 4 GiB$ adicionales.  
El puntero 15 (indirecto triple) agrega un nivel más de indirección, permitiendo teóricamente $1024 × 1024 × 1024 × 4 KiB = 4 TiB$.

### Cálculo de Tamaño Máximo Teórico

Consideremos un sistema con bloques de 4 KiB y punteros de 4 bytes. El número de punteros por bloque es $4096 / 4 = 1024$.  
Los 12 bloques directos proporcionan $12 × 4 KiB = 48 KiB$. El indirecto simple agrega $1024 × 4 KiB = 4 MiB$. El indirecto doble contribuye $1024² × 4 KiB = 4 GiB$. El indirecto triple permitiría $1024³ × 4 KiB = 4 TiB$.  
Sumando todo: $48 KiB + 4 MiB + 4 GiB + 4 TiB ≈ 4 TiB$ de capacidad teórica.
\begin{warning}
EXT2 usa un campo \texttt{i\_size} de 32 bits para el tamaño del archivo. Por lo tanto, el límite REAL es $2^{32} bytes = 4 GiB$, independientemente de que la estructura de punteros podría soportar 4 TiB. Esta es una limitación del diseño original que EXT4 corrige usando 64 bits para el tamaño.
\end{warning}

Si tenemos un disco de 512 GiB con bloques de 4 KiB, tenemos $(512 × 1024 × 1024) / 4 = 134.217.728$ bloques totales. Cada puntero de 4 bytes puede direccionar hasta $2^{32} = 4.294.967.296$ bloques posibles, más que suficiente. El límite real sigue siendo el campo
`i_size` de 32 bits: 4 GiB máximo por archivo.

### Ejemplo de Acceso a Archivo en EXT2
Veamos dos casos que ilustran la eficiencia del esquema de punteros.

*Caso 1:* Archivo pequeño (40 KiB) - Solo bloques directos

El archivo ocupa 10 bloques ($40 KiB / 4 KiB = 10 bloques$).  
Para leer los primeros 8 KiB necesitamos leer el inodo (1 acceso) para obtener `i_block[0]` e `i_block[1]`, luego leer el bloque de datos apuntado por `i_block[0]` (1 acceso) y el bloque apuntado por `i_block[1]` (1 acceso).
Total: 3 accesos a disco, sin ningún bloque de punteros intermedio.

*Caso 2:* Archivo mediano (5 MiB) - Requiere indirecto simple

El archivo ocupa 1280 bloques (5 MiB / 4 KiB = 1280).
- Primeros 12 bloques en punteros directos (48 KiB)
- Restantes 1268 bloques en indirecto simple

Para leer desde el byte 200.000, primero calculamos el bloque objetivo: $200.000 / 4096 = bloque 48$. Como $48 > 11$, está fuera de los punteros directos. Su posición en el indirecto simple es $48 - 12 = índice 36$.  
Los pasos son: leer el inodo (1 acceso) para obtener `i_block[12]`, leer el bloque indirecto simple (1 acceso) para obtener el puntero en el índice 36, y finalmente leer el bloque de datos (1 acceso).  

Total: 3 accesos a disco, comparable al caso anterior a pesar de que el archivo es 128 veces más grande.

## Comparación: FAT vs EXT2

| Característica | FAT | EXT2/UFS |
|----------------|-----|----------|
| **Separación metadatos/nombre** | No (todo en entrada dir.) | Sí (inodo separado) |
| **Método de asignación** | Lista enlazada (tabla FAT) | Indexación multinivel |
| **Hard links** | No soporta | Soportado (contador links\_count) |
| **Permisos** | Atributos básicos (R/O, hidden) | Completo (owner/group/others, rwx) |
| **Acceso aleatorio** | Lento (recorrer cadena FAT) | Rápido (cálculo directo) |
| **Tamaño máx archivo** | 4 GiB (FAT32) | 4 GiB (por i_size de 32 bits) |
| **Tamaño máx volumen** | 2 TiB (FAT32) | 32 TiB (en práctica) |
| **Fragmentación** | Alta (clusters dispersos) | Baja (block groups, localidad) |
| **Confiabilidad** | Baja (tabla FAT es punto único de falla) | Alta (superbloque replicado) |
| **Journaling** | No (exFAT añade algo básico) | No en EXT2, sí en EXT3/4 |
| **Complejidad** | Muy simple | Moderada |
| **Overhead metadatos** | Bajo | Medio (inodos preasignados) |
| **Compatibilidad** | Universal (todos los SO) | Linux nativo, soportado en otros |
| **Uso típico** | Pendrives, SD cards, cámaras | Discos Linux, servidores |

\begin{highlight}
FAT sigue usándose porque ofrece compatibilidad universal—todos los sistemas operativos lo soportan nativamente sin drivers adicionales. Su simplicidad hace que sea ideal para dispositivos embebidos con recursos limitados. No requiere el overhead de permisos complejos en dispositivos portátiles que se comparten entre múltiples usuarios y sistemas. Y tiene menor overhead de metadatos en dispositivos pequeños donde cada byte cuenta.
\end{highlight}
\begin{highlight}
EXT2 es superior para sistemas operativos porque proporciona soporte robusto de permisos necesario en entornos multiusuario. Los hard links permiten una estructura de directorios más flexible y eficiente. El acceso aleatorio eficiente es crítico para bases de datos y aplicaciones que requieren seek frecuente. Y la escalabilidad a volúmenes grandes lo hace apropiado para servidores y estaciones de trabajo modernas.
\end{highlight}

## Links: Hard Links y Soft Links

Ahora que entendemos cómo funcionan FAT (sin inodos) y EXT2 (con inodos), podemos comprender los links.

### Hard Links

\begin{theory}
\emph{Hard Link:}
Entrada de directorio adicional que apunta al MISMO inodo de un archivo existente. Ambos nombres son completamente equivalentes—no existe concepto de "original" versus "copia".
\end{theory}
Veamos un ejemplo práctico:

```bash
$ ls -li archivo.txt
1234567 -rw-r--r-- 1 alumno alumno 5000 Dec 29 10:00 archivo.txt

$ ln archivo.txt copia.txt

$ ls -li
1234567 -rw-r--r-- 2 alumno alumno 5000 Dec 29 10:00 archivo.txt
1234567 -rw-r--r-- 2 alumno alumno 5000 Dec 29 10:00 copia.txt
```

Observemos los detalles: ambos archivos muestran el mismo número de inodo (1234567), confirmando que apuntan a la misma estructura. El contador `links_count` ha incrementado a 2, indicando que el inodo tiene dos nombres. Cualquier modificación por cualquier nombre afecta al mismo contenido físico. Y eliminar un nombre no elimina el archivo mientras `links_count` sea mayor que cero.

La estructura interna es reveladora:

```
Directorio /home/alumno/:
+------------------+-------+
| Nombre           | Inodo |
+------------------+-------+
| archivo.txt      | 1234567 |
| copia.txt        | 1234567 |  ← Mismo inodo
+------------------+-------+

Inodo 1234567:
- i_links_count = 2
- i_size = 5000
- i_block[0] = 8945  ← Datos reales
```

\begin{warning}
Los hard links tienen tres limitaciones fundamentales. Primero, no pueden cruzar file systems—cada FS tiene su propia tabla de inodos numerada independientemente. Segundo, no pueden apuntar a directorios (excepto las entradas especiales \texttt{.} y \texttt{..}) porque permitirlo crearía ciclos que romperían algoritmos de traversal recursivo. Tercero, solo funcionan en sistemas con inodos, lo que excluye a FAT.
\end{warning}
El archivo se elimina realmente solo cuando el último nombre desaparece:

```bash
$ rm archivo.txt    # links_count: 2 → 1 (archivo SIGUE existiendo)
$ rm copia.txt      # links_count: 1 → 0 (AHORA se liberan los bloques)
```

### Soft Links (Symbolic Links)

\begin{theory}
\emph{Soft Link (Symbolic Link):}
Archivo especial cuyo contenido es la RUTA (path) textual a otro archivo. Es una redirección a nivel de nombres, no de inodos—el sistema operativo debe "seguir" el link para llegar al destino.
\end{theory}

Un ejemplo ilustrativo:
```bash
$ ln -s /home/alumno/proyecto/datos.txt acceso_datos.txt

$ ls -l
lrwxrwxrwx 1 alumno alumno 30 Dec 29 10:05 acceso_datos.txt -> /home/alumno/proyecto/datos.txt
-rw-r--r-- 1 alumno alumno 5000 Dec 29 10:00 datos.txt
```

El soft link tiene su propio inodo, completamente separado del archivo destino. El primer carácter `l` en los permisos indica que es un link. Los permisos aparecen como `rwxrwxrwx` pero son ignorados—el control de acceso real está en el archivo destino. El "contenido" del soft link es simplemente el path como string: "/home/alumno/proyecto/datos.txt".

La estructura interna muestra la separación:

```
Directorio /home/alumno/:
+------------------+-------+
| Nombre           | Inodo |
+------------------+-------+
| acceso_datos.txt | 9876543 |  ← Inodo del LINK

Inodo 9876543 (el soft link):
- i_mode = S_IFLNK | 0777  (tipo = link)
- i_size = 30  (longitud del path)
- contenido: "/home/alumno/proyecto/datos.txt"

Directorio /home/alumno/proyecto/:
+------------------+-------+
| Nombre           | Inodo |
+------------------+-------+
| datos.txt        | 1234567 |  ← Inodo del ARCHIVO REAL

Inodo 1234567 (el archivo):
- i_mode = S_IFREG | 0644
- i_size = 5000
- i_block[0] = datos reales
```

Si eliminamos el archivo original, el soft link queda "roto" (dangling link):

```bash
$ rm /home/alumno/proyecto/datos.txt
$ cat acceso_datos.txt
cat: acceso_datos.txt: No such file or directory
```

El link sigue existiendo pero apunta a un archivo inexistente. Interesantemente, si luego creamos un archivo nuevo con el mismo nombre y ubicación, el link vuelve a funcionar automáticamente.

### Comparación Hard Link vs Soft Link

\begin{center}
agregar diagrama
%%\includegraphics[width=0.8\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-hardVsSoftLink.png}
\end{center}

| Aspecto | Hard Link | Soft Link |
|---------|-----------|-----------|
| **Inodo** | Mismo que el original | Propio inodo |
| **Contenido** | Apunta directamente a datos | Contiene path como string |
| **Si se borra original** | Datos siguen accesibles | Link queda roto (dangling) |
| **Cruza file systems** | No | Sí |
| **Apunta a directorios** | No (excepto . y ..) | Sí |
| **Overhead** | Mínimo (solo entrada dir.) | Un inodo extra |
| **Transparencia** | Totalmente transparente | Se nota que es link |
| **Uso típico** | Backups, deduplicación | Atajos, referencias flexibles |

\begin{example}
Los hard links son ideales para sistemas de backups incrementales. Los archivos sin cambios se hard-linkean en vez de copiarse, ahorrando espacio masivamente:
\end{example}
```bash
backup/2024-12-01/archivo.txt  ← Inodo 12345
backup/2024-12-02/archivo.txt  ← Inodo 12345 (mismo, no usa espacio)
backup/2024-12-03/archivo.txt  ← Inodo 67890 (cambió, nueva copia)
```
\begin{example}
Los soft links son perfectos para gestión de versiones de software:  
\end{example}
```bash
/usr/bin/python3 -> /usr/bin/python3.11  (soft link)
# Actualizar Python solo requiere cambiar el link, no recompilar programas
```


## Ejercicios Integradores

### Ejercicio 1: Lectura Simple en EXT2

**Enunciado:**

Se tiene un sistema EXT2 con las siguientes características:
- Tamaño de bloque: 4 KiB
- Tamaño de puntero: 4 bytes

Un archivo ocupa 20 KiB y está almacenado completamente en la zona de punteros directos del inodo.

Se desea **leer el archivo completo** desde el byte 0 hasta el byte 20.479.

**¿Cuántos accesos a disco se requieren? Diferenciar entre accesos a bloques de datos y accesos a bloques de punteros.**

---

**Solución Detallada:**

**Paso 1: Calcular cantidad de bloques necesarios**

```
Tamaño archivo = 20 KiB = 20.480 bytes
Tamaño bloque = 4 KiB = 4.096 bytes
Bloques necesarios = ⌈20.480 / 4.096⌉ = 5 bloques
```

**Paso 2: Verificar si usa solo bloques directos**

El inodo EXT2 tiene 12 punteros directos.
```
5 bloques < 12 bloques directos → SÍ, solo usa punteros directos
```

**Paso 3: Identificar accesos necesarios**

Para leer el archivo completo necesitamos:

1. **Acceso al inodo:** Leer la estructura del inodo para obtener los punteros i_block[0] a i_block[4]
2. **Acceso a bloque 0:** Leer i_block[0] (bytes 0-4095)
3. **Acceso a bloque 1:** Leer i_block[1] (bytes 4096-8191)
4. **Acceso a bloque 2:** Leer i_block[2] (bytes 8192-12287)
5. **Acceso a bloque 3:** Leer i_block[3] (bytes 12288-16383)
6. **Acceso a bloque 4:** Leer i_block[4] (bytes 16384-20479)

**Paso 4: Clasificar accesos**

- **Accesos a bloques de punteros:** 0 (los punteros directos están EN el inodo mismo)
- **Accesos a bloques de datos:** 5 (los bloques con contenido del archivo)
- **Acceso al inodo:** 1 (estructura de metadatos)

**Respuesta Final:**

\textcolor{blue!50!black}{\textbf{Respuesta:}\\
- \textbf{Accesos a bloques de datos:} 5\\
- \textbf{Accesos a bloques de punteros:} 0 (punteros directos están en el inodo)\\
- \textbf{Total de accesos a disco:} 6 (1 inodo + 5 datos)\\
}

---

### Ejercicio 2: Escritura Compleja en EXT2 (Integrador)

**Enunciado:**

Se tiene un sistema que utiliza EXT2 como File System con **bloques de 8 KiB** y **punteros de 64 bits**. A su vez, cada inodo está conformado por **12 punteros directos**, **1 indirecto simple** y **2 indirectos dobles**.

Se pide determinar la cantidad de accesos a bloques necesaria para **leer un archivo desde el byte nro 6.553.600 hasta el byte nro 8.631.975.936**. Diferenciar entre accesos a bloques de datos y accesos a bloques de punteros.

**Solución Detallada:**

#### Paso 1: Calcular parámetros del sistema

```
Tamaño de bloque (B) = 8 KiB = 8.192 bytes
Tamaño de puntero (P) = 64 bits = 8 bytes

Punteros por bloque (N) = B / P = 8.192 / 8 = 1.024 punteros
```

#### Paso 2: Calcular capacidad de cada nivel de punteros

**Bloques directos (12):**
```
Capacidad = 12 × 8 KiB = 96 KiB = 98.304 bytes
Rango de bytes: 0 a 98.303
```

**Indirecto simple (1):**
```
Capacidad = N × B = 1.024 × 8 KiB = 8 MiB = 8.388.608 bytes
Rango de bytes: 98.304 a 8.486.911
```

**Indirecto doble 1:**
```
Capacidad = N × N × B = 1.024 × 1.024 × 8 KiB = 8 GiB = 8.589.934.592 bytes
Rango de bytes: 8.486.912 a 17.076.846.503
```

**Indirecto doble 2:**
```
Capacidad = N × N × B = 8 GiB = 8.589.934.592 bytes
Rango de bytes: 17.076.846.504 a 25.666.781.095
```

#### Paso 3: Determinar qué bloques cubren el rango solicitado

**Byte inicial:** 6.553.600  
**Byte final:** 8.631.975.936

**Calcular bloque inicial:**
```
Bloque inicial = ⌊6.553.600 / 8.192⌋ = 800
```

**Calcular bloque final:**
```
Bloque final = ⌊8.631.975.936 / 8.192⌋ = 1.053.710
```

**Total de bloques a leer:**
```
Bloques = 1.053.710 - 800 + 1 = 1.052.911 bloques
```

#### Paso 4: Clasificar bloques por nivel de indirección

**¿Bloques directos? (rango: bloque 0-11)**
```
Bloque inicial = 800 → NO está en bloques directos
```

**¿Indirecto simple? (rango: bloque 12 a 1.035)**
```
Primer bloque del ind. simple = 12
Último bloque del ind. simple = 12 + 1.024 - 1 = 1.035

¿800 está en [12, 1.035]? SÍ
¿1.053.710 está en [12, 1.035]? NO

Bloques usados del ind. simple = 1.035 - 800 + 1 = 236 bloques
```

**¿Indirecto doble 1? (rango: bloque 1.036 a 1.049.611)**
```
Primer bloque = 1.036
Último bloque = 1.036 + (1.024 × 1.024) - 1 = 1.049.611

Rango solicitado [800, 1.053.710]:
- Inicio (800) NO está aquí
- Final (1.053.710) SÍ cruza este rango

Bloques usados = 1.049.611 - 1.036 + 1 = 1.048.576 bloques (TODO el ind. doble #1)
```

**¿Indirecto doble 2? (rango: bloque 1.049.612 a 2.098.187)**
```
Primer bloque = 1.049.612
Último bloque = 1.049.612 + (1.024 × 1.024) - 1 = 2.098.187

¿1.053.710 está en [1.049.612, 2.098.187]? SÍ

Bloques usados = 1.053.710 - 1.049.612 + 1 = 4.099 bloques
```

**Verificación:**
```
236 (ind. simple) + 1.048.576 (ind. doble #1) + 4.099 (ind. doble #2) = 1.052.911 ✓
```

#### Paso 5: Calcular accesos a bloques de punteros

**Indirecto simple:**
```
Necesitamos 236 bloques de datos del ind. simple.
Todos están en UN SOLO bloque de punteros.

Accesos = 1 (el bloque indirecto simple contiene los 1.024 punteros)
```

**Indirecto doble 1:**
```
Necesitamos TODO el indirecto doble #1 (1.048.576 bloques de datos).

Cantidad de bloques indirectos simples = 1.048.576 / 1.024 = 1.024 bloques

Accesos = 1 (bloque ind. doble raíz) + 1.024 (bloques ind. simples) = 1.025 accesos
```

**Indirecto doble 2:**
```
Necesitamos 4.099 bloques de datos del segundo indirecto doble.

Bloques indirectos simples necesarios = ⌈4.099 / 1.024⌉ = 5 bloques

Accesos = 1 (bloque ind. doble raíz) + 5 (bloques ind. simples) = 6 accesos
```

**Total accesos a bloques de punteros:**
```
1 (ind. simple) + 1.025 (ind. doble #1) + 6 (ind. doble #2) = 1.032 accesos
```

#### Paso 6: Calcular accesos a bloques de datos

```
Total bloques de datos a leer = 1.052.911 accesos
```

#### Paso 7: Respuesta Final

\textcolor{blue!50!black}{\textbf{Respuesta:}\\
- \textbf{Accesos a bloques de datos:} 1.052.911\\
- \textbf{Accesos a bloques de punteros:} 1.032\\
- \textbf{Total de accesos a disco:} 1.053.943 (sin contar el acceso inicial al inodo)\\
}

\textcolor{orange!70!black}{\textbf{Nota importante para parcial:}\\
En la práctica, el SO cachea bloques de punteros en memoria, por lo que accesos subsecuentes al mismo archivo serían mucho más rápidos. Pero en el análisis teórico contamos TODOS los accesos.\\
}

## Otros Sistemas de Archivos (Mención Breve)

En la cátedra se enfocan en FAT y EXT2, pero es importante conocer la existencia de otros file systems modernos:

### EXT3 (Third Extended File System)

**Año:** 2001  
**Mejora principal:** Agrega **journaling** a EXT2

\textcolor{teal!60!black}{\textbf{Características:}\\
- Compatibilidad hacia atrás: se puede montar EXT2 como EXT3\\
- Tres modos de journaling: journal (más lento, más seguro), ordered (default), writeback (más rápido)\\
- Recuperación rápida después de crashes\\
- Mismo formato de inodos y estructura que EXT2\\
}

**Sistema operativo:** Linux (estándar en distribuciones 2001-2008)

### EXT4 (Fourth Extended File System)

**Año:** 2008  
**Mejoras significativas:**

- **Extents:** En vez de lista de bloques individuales, se usan rangos contiguos → reduce fragmentación
- **Soporte de archivos hasta 16 TiB** (usa 64 bits para tamaño)
- **Volúmenes hasta 1 EiB** (exabyte)
- **Delayed allocation:** Asigna bloques justo antes de escribir a disco → mejor decisión de ubicación
- **Multiblock allocation:** Asigna múltiples bloques de una vez → reduce fragmentación

**Sistema operativo:** Linux (estándar actual en la mayoría de distribuciones)

### NTFS (New Technology File System)

**Año:** 1993  
**Creador:** Microsoft

\textcolor{teal!60!black}{\textbf{Características:}\\
- Sistema de archivos principal de Windows desde NT 4.0\\
- Journaling completo (incluye datos y metadatos)\\
- Soporte de ACL (Access Control Lists) más complejas que Unix\\
- Streams alternativos: un archivo puede tener múltiples contenidos\\
- Compresión y encriptación a nivel de file system\\
}

**Límites:**
- Archivos hasta 16 EiB
- Volúmenes hasta 256 TiB (en práctica)

**Sistema operativo:** Windows (NT, 2000, XP, Vista, 7, 8, 10, 11)

### exFAT (Extended File Allocation Table)

**Año:** 2006  
**Creador:** Microsoft

Creado para dispositivos de almacenamiento flash de gran capacidad (SD cards >32 GB, pendrives grandes).

\textcolor{teal!60!black}{\textbf{Mejoras sobre FAT32:}\\
- Elimina límite de 4 GiB para archivos individuales (usa 64 bits)\\
- Soporte de volúmenes hasta 128 PiB teóricos\\
- Menos overhead que NTFS\\
- Mejor para flash (menos escrituras que NTFS)\\
}

**Uso típico:** Tarjetas SD de >32 GB, discos externos USB

**Sistema operativo:** Windows (Vista SP1+), macOS (10.6.5+), Linux (con driver)

### APFS (Apple File System)

**Año:** 2017  
**Creador:** Apple

Sistema moderno que reemplaza HFS+ en dispositivos Apple.

\textcolor{teal!60!black}{\textbf{Características:}\\
- Copy-on-write: nunca sobrescribe datos in-place\\
- Snapshots instantáneos (sin costo de espacio hasta que se modifica)\\
- Encriptación nativa (por archivo o por volumen)\\
- Optimizado para almacenamiento SSD/flash\\
}

**Sistema operativo:** macOS (High Sierra+), iOS, watchOS, tvOS

### XFS

**Año:** 1994 (SGI), 2001 (Linux)

Sistema de alto rendimiento creado originalmente para servidores IRIX de Silicon Graphics.

\textcolor{teal!60!black}{\textbf{Características:}\\
- Excelente para archivos muy grandes (video, científicos)\\
- Alto throughput en I/O paralelo\\
- Journaling de metadatos\\
- Allocation groups similares a block groups de EXT\\
}

**Uso típico:** Servidores, sistemas de almacenamiento masivo, edición de video

**Sistema operativo:** Linux (default en RHEL/CentOS desde v7)

### Btrfs (B-tree File System)

**Año:** 2009

Sistema moderno de Linux con características avanzadas.

\textcolor{teal!60!black}{\textbf{Características:}\\
- Copy-on-write\\
- Snapshots y clones instantáneos\\
- Checksums de datos y metadatos (detecta corrupción)\\
- Compresión transparente\\
- RAID integrado a nivel de file system\\
}

**Sistema operativo:** Linux (usado en SUSE, Fedora como opción)

### ZFS (Zettabyte File System)

**Año:** 2005  
**Creador:** Sun Microsystems (ahora Oracle)

Uno de los file systems más avanzados, diseñado para servidores enterprise.

\textcolor{teal!60!black}{\textbf{Características:}\\
- Copy-on-write y snapshots\\
- Checksums end-to-end (detecta y corrige bit rot)\\
- RAID integrado (RAID-Z)\\
- Compresión y deduplicación\\
- Límites masivos: 256 trillones de zettabytes\\
}

**Sistema operativo:** Solaris, FreeBSD, Linux (OpenZFS)

### Resumen Comparativo

| File System | Año | Journaling | Max File | Max Volume | Uso Principal |
|-------------|-----|------------|----------|------------|---------------|
| FAT32 | 1996 | No | 4 GiB | 2 TiB | Dispositivos portátiles |
| EXT2 | 1993 | No | 4 GiB | 32 TiB | Linux legacy |
| EXT3 | 2001 | Sí | 4 GiB | 32 TiB | Linux (histórico) |
| EXT4 | 2008 | Sí | 16 TiB | 1 EiB | Linux (actual) |
| NTFS | 1993 | Sí | 16 EiB | 256 TiB | Windows |
| exFAT | 2006 | Básico | 16 EiB | 128 PiB | Flash grande |
| APFS | 2017 | Sí (CoW) | 8 EiB | 8 EiB | macOS/iOS |
| XFS | 1994 | Sí | 8 EiB | 8 EiB | Servidores Linux |
| Btrfs | 2009 | Sí (CoW) | 16 EiB | 16 EiB | Linux avanzado |
| ZFS | 2005 | Sí (CoW) | 16 EiB | 256 ZiB | Enterprise |

## Síntesis y Puntos Clave

### Conceptos Fundamentales

1. **File System = Abstracción**
   - Transforma sectores físicos en archivos y directorios organizados
   - Proporciona naming, organización, protección, persistencia

2. **Archivo = Secuencia de bytes con nombre**
   - El SO no interpreta el contenido
   - Metadatos separados del contenido (excepto en FAT)

3. **Directorio = Archivo especial con tabla de nombres**
   - Permite organización jerárquica
   - En Unix: solo almacena (nombre, inodo)

4. **Sectores vs Bloques**
   - Sector: unidad física del hardware (512B, 4KB)
   - Bloque: unidad lógica del file system (configurable)
   - Trade-off: bloques grandes → menos overhead, más fragmentación interna

5. **FCB/Inodo**
   - Estructura que almacena metadatos (TODO excepto el nombre)
   - En Unix: separado del directorio
   - En FAT: integrado en entrada de directorio

### Operaciones y Estructuras del SO

6. **Arquitectura de 3 niveles para archivos abiertos**
   - File Descriptor Table (por proceso)
   - Open File Table (system-wide, offset compartible)
   - Inode Table (metadatos del archivo)

7. **File Locking**
   - Advisory: cooperativo, puede ignorarse
   - Mandatory: forzado por el SO (fcntl)
   - Shared (lectura) vs Exclusive (escritura)

8. **Permisos Unix: 9 bits**
   - Owner (rwx) + Group (rwx) + Others (rwx)
   - Para archivos: r=leer, w=escribir, x=ejecutar
   - Para directorios: r=listar, w=crear/borrar, x=atravesar

### Métodos de Asignación

9. **Contigua**
   - Acceso secuencial rápido, simple
   - Fragmentación externa, archivos estáticos
   - Uso: CD-ROM, DVD

10. **Enlazada (FAT)**
    - Sin fragmentación externa, archivos dinámicos
    - Acceso aleatorio lento
    - Mejora: tabla FAT centralizada en memoria

11. **Indexada (Unix)**
    - Acceso aleatorio eficiente
    - Overhead en archivos pequeños
    - Multinivel: directos + indirectos (simple, doble, triple)

### Comparación FAT vs EXT2

| Aspecto | FAT | EXT2 |
|---------|-----|------|
| Metadatos | En entrada de directorio | Inodo separado |
| Asignación | Lista enlazada | Indexada multinivel |
| Hard links | No | Sí |
| Permisos | Básicos | Completos (rwx) |
| Acceso aleatorio | Lento | Rápido |
| Complejidad | Muy simple | Moderada |

12. **FAT: Simplicidad universal**
    - Tabla FAT: array donde FAT[i] = siguiente cluster
    - FAT12/16/32: tamaño de entradas (4K, 64K, 268M clusters)
    - Límite: 4 GiB por archivo (uint32_t file_size)
    - Uso: Pendrives, SD cards

13. **EXT2: Robustez y escalabilidad**
    - Block groups: localidad de inodos y datos
    - Inodo: 12 directos + 1 ind. simple + 2 ind. dobles
    - Capacidad teórica: 4 TiB (pero límite real 4 GiB por i_size)
    - Superbloque replicado para confiabilidad

### Links

14. **Hard Link**
    - Múltiples nombres → mismo inodo
    - No cruza file systems
    - Archivo persiste hasta links\_count = 0

15. **Soft Link**
    - Archivo especial con path como contenido
    - Propio inodo, puede quedar roto
    - Cruza file systems, puede apuntar a directorios

### Seguridad y Recuperación

16. **Journaling**
    - Registra operaciones ANTES de ejecutarlas
    - Recuperación rápida después de crash
    - Metadata-only vs Full data journaling

17. **fsck/chkdsk**
    - Escaneo completo del file system
    - 5 fases: inodos, directorios, conectividad, contadores, bitmaps
    - Lento en discos grandes (horas)

### Fórmulas y Cálculos Clave

18. **Punteros por bloque:**
    ```
    N = tamaño_bloque / tamaño_puntero
    ```

19. **Capacidad por nivel (EXT2):**
    ```
    Directos:         12 × B
    Ind. simple:      N × B
    Ind. doble:       N² × B
    Ind. triple:      N³ × B
    ```

20. **Fragmentación interna promedio:**
    ```
    aprox tamaño_bloque / 2 por archivo
    ```

## Preparación para Parcial

### Temas de Alta Probabilidad

1. **Definiciones conceptuales:**
   - Diferencia entre sector y bloque
   - Qué es un FCB/inodo
   - Hard link vs soft link
   - Journaling

2. **Comparaciones:**
   - Métodos de asignación (tabla completa)
   - FAT vs EXT2 (ventajas/desventajas)
   - Hard link vs soft link (cuándo usar cada uno)

3. **Estructuras de datos:**
   - Entrada de directorio en FAT (32 bytes)
   - Estructura de inodo en EXT2 (15 punteros)
   - Tabla de archivos abiertos (3 niveles)

4. **Ejercicios numéricos:**
   - Cálculo de capacidades por nivel (directos, indirectos)
   - Accesos a disco en lectura/escritura
   - Diferenciar accesos a datos vs punteros

5. **Permisos Unix:**
   - Interpretación de rwxr-xr-- (notación octal)
   - Verificación de permisos (owner, group, others)
   - Umask y permisos por defecto

### Estrategia para Ejercicios Numéricos

**Paso 1:** Escribir parámetros dados
```
B = tamaño de bloque
P = tamaño de puntero
N = B / P (punteros por bloque)
```

**Paso 2:** Calcular capacidades de cada nivel
```
Directos (D):       D × B
Ind. simple (IS):   N × B
Ind. doble (ID):    N² × B
Ind. triple (IT):   N³ × B
```

**Paso 3:** Calcular rangos de bytes
```
Directos:    [0, D×B - 1]
Ind. simple: [D×B, D×B + N×B - 1]
Ind. doble:  [D×B + N×B, D×B + N×B + N²×B - 1]
```

**Paso 4:** Determinar qué bloques se necesitan
```
Bloque inicial = byte_inicial / B
Bloque final = byte_final / B
Total bloques = bloque_final - bloque_inicial + 1
```

**Paso 5:** Clasificar por nivel y contar accesos
- Bloques de datos: todos los bloques a leer
- Bloques de punteros: 
  - Ind. simple: 1 acceso
  - Ind. doble: 1 (raíz) + ⌈bloques_datos / N⌉ (simples)
  - Ind. triple: aplicar recursivamente

**Paso 6:** Verificar respuesta
- ¿Suma de bloques por nivel = total bloques? ✓
- ¿Tiene sentido el número de accesos? ✓

### Errores Comunes a Evitar

**Error 1:** Olvidar contar el acceso al bloque indirecto raíz
```
Ind. doble NO es solo los simples, es: 1 + simples
```

**Error 2:** Confundir bloques de datos con bloques de punteros
```
Un bloque ind. simple NO es un bloque de datos
```

**Error 3:** No considerar que los bloques directos ocupan las primeras posiciones
```
Bloque 0-11: directos
Bloque 12+: comienza indirecto simple
```

**Error 4:** Usar capacidad teórica cuando hay límite real
```
EXT2: capacidad teórica 4 TiB, pero límite REAL 4 GiB (i_size de 32 bits)
```

**Error 5:** No diferenciar entre FAT (no tiene inodo) y EXT2 (sí tiene inodo)
```
FAT: metadatos en directorio
EXT2: metadatos en inodo separado
```

**Error 6:** Calcular mal los bloques indirectos simples necesarios en un indirecto doble
```
Si necesito 5.000 bloques de datos:
Bloques ind. simples = ⌈5.000 / 1.024⌉ = 5 (NO 4)
Siempre usar techo (ceiling)
```

**Error 7:** Olvidar que para eliminar un archivo se necesita permiso de escritura en el DIRECTORIO, no en el archivo
```
chmod 000 archivo.txt  # Sin permisos en el archivo
rm archivo.txt         # ¡Se puede borrar igual si tengo 'w' en el directorio!
```

### Checklist Pre-Examen

- [ ] Sé definir: archivo, directorio, FCB/inodo, sector, bloque
- [ ] Puedo comparar los 3 métodos de asignación (ventajas/desventajas)
- [ ] Entiendo la estructura de FAT (tabla + entrada de directorio)
- [ ] Entiendo la estructura de EXT2 (block groups, inodo, punteros)
- [ ] Sé calcular capacidades por nivel dados B y P
- [ ] Puedo resolver ejercicio de accesos a disco paso a paso
- [ ] Entiendo diferencia entre hard link y soft link
- [ ] Conozco permisos Unix (rwx, octal, verificación)
- [ ] Sé explicar journaling y fsck brevemente
- [ ] Entiendo las 3 tablas de archivos abiertos (FD, Open File, Inode)
- [ ] Sé qué pasa con offsets después de fork() vs open() independiente

### Tips Finales

**Para ejercicios de accesos a disco:**
- Dibuja un esquema visual del inodo con sus niveles
- Marca claramente qué bloques caen en qué nivel
- Cuenta los accesos por separado: primero punteros, después datos
- Verifica que la suma de bloques por nivel sea correcta

**Para permisos:**
- Memoriza: 4=r, 2=w, 1=x
- Practica conversión octal ↔ rwx mentalmente
- Recuerda que para directorios 'x' es crítico para acceder

**Para comparaciones:**
- Arma tablas mentales: FAT vs EXT2, Contigua vs Enlazada vs Indexada
- Identifica trade-offs: simplicidad vs funcionalidad, velocidad vs overhead

## Conexiones con Otros Capítulos

### Capítulo 2: Procesos
- Cada proceso tiene tabla de file descriptors
- `fork()` hereda descriptores (comparten offset en Open File Table)
- Archivos ejecutables se cargan desde el file system

### Capítulo 5: Sincronización
- File locking previene race conditions en archivos compartidos
- Operaciones read/write pueden requerir locks
- Directorios compartidos necesitan sincronización

### Capítulo 6: Interbloqueo
- Procesos pueden entrar en deadlock por locks de archivos
- Ejemplo: P1 lockea A y pide B, P2 lockea B y pide A

### Capítulo 7-8: Gestión de Memoria
- Buffer cache: bloques de disco cacheados en RAM
- Memory-mapped files: archivo mapeado a espacio de direcciones
- Page cache vs buffer cache (unificados en Linux moderno)

### Capítulo 1: Interrupciones e I/O
- Operaciones de file system generan operaciones de I/O al disco
- Drivers de disco interactúan con file system para transferencias
- DMA usado para transferir bloques sin CPU

---

Este capítulo cubrió desde los conceptos fundamentales de archivos y directorios, pasando por los métodos de asignación de espacio, hasta el análisis detallado de FAT y EXT2, los dos sistemas de archivos que estudiamos en profundidad en la cátedra. Los ejercicios integradores te preparan para resolver problemas numéricos típicos de parcial.