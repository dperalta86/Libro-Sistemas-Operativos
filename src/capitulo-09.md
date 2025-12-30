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

Imaginemos por un momento que no existieran los sistemas de archivos. Cada vez que queremos guardar información en el disco duro, tendríamos que recordar exactamente en qué sectores físicos guardamos cada dato. Si queremos un documento de texto, necesitaríamos saber que está en los sectores 1024 al 1536 del cilindro 45, cabeza 2. Si queremos una foto, debemos recordar que ocupa los sectores 8192 al 12288 del cilindro 103.

Este escenario es completamente impracticable por varias razones:

\textcolor{red!60!gray}{\textbf{Problemas sin File System:}\\
- Los usuarios no pueden recordar direcciones físicas de miles de archivos\\
- No hay forma de dar nombres significativos a los datos\\
- Imposible organizar información jerárquicamente\\
- Riesgo altísimo de sobrescribir datos accidentalmente\\
- No existe control de acceso o permisos\\
- Pérdida total de datos si se corrompe una pequeña región del disco\\
}

\begin{theory}
\emph{Sistema de Archivos (File System):}
Componente del sistema operativo que proporciona mecanismos para el almacenamiento, organización, manipulación, recuperación y administración de información en dispositivos de almacenamiento secundario.
\end{theory}

### Objetivos del File System

El sistema de archivos surge como una **capa de abstracción** entre el hardware de almacenamiento y el usuario/aplicaciones. Sus objetivos principales son:

1. **Abstracción:** Transformar el disco (conjunto lineal de sectores físicos) en una estructura lógica organizada
2. **Naming:** Permitir dar nombres significativos a conjuntos de datos
3. **Organización:** Estructurar archivos en jerarquías (directorios y subdirectorios)
4. **Protección:** Controlar quién puede acceder a qué información (permisos)
5. **Persistencia:** Garantizar que los datos sobrevivan al apagado del sistema
6. **Eficiencia:** Optimizar el uso del espacio disponible y velocidad de acceso
7. **Confiabilidad:** Garantizar integridad de datos ante fallas

\begin{center}
agregar diagrama...
%%\includegraphics[width=0.7\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-jerarquiaAlmacenamiento.png}
\end{center}

## Archivos: Abstracción de Usuario

### Concepto de Archivo

En bases de datos y sistemas de información, existe una jerarquía conceptual:

**Campo:** Unidad mínima de información con significado. Ejemplo: "nombre", "edad", "dirección".

**Registro:** Colección de campos relacionados que describen una entidad. Ejemplo: un registro de estudiante contiene campos nombre, legajo, carrera, email.

**Archivo:** Colección de registros del mismo tipo. Ejemplo: archivo "estudiantes.dat" contiene todos los registros de estudiantes.

\begin{theory}
\emph{Archivo (desde la perspectiva del SO):}
Secuencia nombrada de bytes almacenada en dispositivo de almacenamiento secundario. El sistema operativo NO interpreta el contenido del archivo; esa es responsabilidad de las aplicaciones.
\end{theory}

### Atributos de un Archivo

Cada archivo posee **metadatos** que el sistema operativo almacena y gestiona:

| Atributo | Descripción |
|----------|-------------|
| **Nombre** | Identificador legible por humanos |
| **Tipo** | Regular, directorio, enlace simbólico, dispositivo, etc. |
| **Ubicación** | Punteros a los bloques de datos en disco |
| **Tamaño** | Cantidad de bytes que ocupa el archivo |
| **Permisos** | Lectura, escritura, ejecución (owner/group/others) |
| **Timestamps** | Creación (ctime), modificación (mtime), acceso (atime) |
| **Propietario** | UID (User ID) del usuario dueño |
| **Grupo** | GID (Group ID) asociado |
| **Contador de enlaces** | Cantidad de hard links apuntando al archivo |

### File Control Block (FCB)

\begin{theory}
\emph{File Control Block (FCB):}
Estructura de datos que almacena todos los metadatos de un archivo. En sistemas Unix se denomina \textbf{inodo (inode)}. En FAT, la entrada de directorio cumple esta función.
\end{theory}

El FCB es fundamental porque separa la **identidad del archivo** (sus metadatos) de su **contenido** (los datos en bloques). Un archivo puede tener múltiples nombres (hard links) pero un solo FCB.

### Operaciones sobre Archivos

El sistema operativo provee syscalls para manipular archivos:

#### Operaciones Básicas

**create(nombre):** Crea un archivo nuevo
- Asigna un FCB/inodo
- Crea entrada en el directorio padre
- Inicializa metadatos (permisos, timestamps, tamaño=0)

**open(nombre, modo):** Abre un archivo para operaciones
- Busca el archivo en el directorio
- Verifica permisos de acceso
- Carga FCB en memoria
- Retorna file descriptor

**read(fd, buffer, cantidad):** Lee bytes del archivo
- Usa el file descriptor para ubicar el archivo
- Copia datos desde bloques del disco al buffer en memoria
- Actualiza puntero de lectura/escritura

**write(fd, buffer, cantidad):** Escribe bytes al archivo
- Asigna bloques nuevos si es necesario
- Copia datos desde buffer a bloques en disco
- Actualiza tamaño del archivo y timestamps

**seek(fd, offset, whence):** Mueve el puntero de lectura/escritura
- SEEK_SET: desde inicio del archivo
- SEEK_CUR: desde posición actual
- SEEK_END: desde final del archivo

**close(fd):** Cierra el archivo
- Libera estructuras en memoria
- Escribe buffers pendientes (flush)
- Actualiza metadatos en disco

**delete(nombre):** Elimina un archivo
- Decrementa contador de enlaces
- Si llega a 0, libera bloques de datos y FCB
- Elimina entrada del directorio

#### Operaciones Adicionales

**rename(viejo, nuevo):** Cambia el nombre del archivo
**truncate(nombre, tamaño):** Reduce el tamaño del archivo
**stat(nombre):** Obtiene metadatos sin abrir el archivo
**chmod(nombre, permisos):** Cambia permisos
**chown(nombre, uid, gid):** Cambia propietario

### Métodos de Acceso

\begin{theory}
\emph{Método de Acceso:}
Forma en que los procesos leen y escriben datos en un archivo. Define el orden y la forma de acceso a la información.
\end{theory}

#### Acceso Secuencial

Los bytes se leen/escriben uno después del otro, desde el inicio hasta el final.

```c
// Lectura secuencial
int fd = open("datos.txt", O_RDONLY);
char buffer[1024];
while (read(fd, buffer, 1024) > 0) {
    // Procesar buffer
}
close(fd);
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Simple de implementar\\
- Óptimo para procesar archivos completos\\
- Aprovecha prefetching y cache del SO\\
}

**Uso típico:** Logs, archivos de texto, procesamiento por lotes

#### Acceso Directo (Random Access)

Se puede leer/escribir cualquier byte del archivo sin recorrer los anteriores.

```c
// Acceso directo
int fd = open("base_datos.dat", O_RDWR);
// Leer registro 100 (cada registro = 256 bytes)
lseek(fd, 100 * 256, SEEK_SET);
read(fd, &registro, 256);
close(fd);
```

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Acceso instantáneo a cualquier posición\\
- Ideal para bases de datos y estructuras indexadas\\
- No requiere recorrer todo el archivo\\
}

**Uso típico:** Bases de datos, archivos de índices, estructuras complejas

#### Acceso Indexado

Se mantiene un índice separado que mapea claves a posiciones en el archivo de datos.

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

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Búsquedas muy rápidas por clave\\
- Permite múltiples índices sobre el mismo archivo\\
- Soporta consultas complejas\\
}

**Uso típico:** Sistemas de bases de datos, bibliotecas digitales

## Directorios: Organización Jerárquica

### Concepto de Directorio

\begin{theory}
\emph{Directorio:}
Archivo especial que contiene una tabla de entradas, donde cada entrada asocia un nombre de archivo con su FCB/inodo. Permite organización jerárquica del file system.
\end{theory}

Un directorio es simplemente una lista de pares (nombre, referencia_a_FCB):

```c
struct directory_entry {
    char name[256];        // Nombre del archivo
    uint32_t inode_number; // Referencia al FCB (en Unix)
    uint8_t file_type;     // Regular, directorio, link, etc.
};
```

### Estructuras de Directorios

#### Directorio de Un Nivel (Single-Level)

Todos los archivos en un solo directorio. Sistema más simple pero impracticable:

```
/ (raíz)
  ├── programa1.c
  ├── programa2.c
  ├── datos.txt
  └── imagen.jpg
```

\textcolor{red!60!gray}{\textbf{Problemas:}\\
- Imposible organizar archivos por categorías\\
- Conflictos de nombres entre usuarios\\
- No escalable para miles de archivos\\
}

#### Directorio de Dos Niveles

Cada usuario tiene su propio directorio:

```
/
  ├── user1/
  │   ├── programa.c
  │   └── datos.txt
  └── user2/
      ├── programa.c  (mismo nombre, diferente archivo)
      └── imagen.jpg
```

Mejor, pero sigue limitado: no permite subdivisiones dentro del espacio del usuario.

#### Estructura Jerárquica (Árbol)

La solución moderna: directorios pueden contener subdirectorios, formando un árbol:

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

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Organización lógica e intuitiva\\
- Namespaces separados por directorio\\
- Escalable a millones de archivos\\
- Permite permisos por directorio\\
}

#### Grafo Acíclico Dirigido (con Links)

Cuando se permiten hard links y soft links, la estructura deja de ser árbol puro:

```
/home/alumno/
  ├── proyecto/
  │   └── datos.txt  (inodo 1234)
  └── backup/
      └── datos_respaldo.txt  (hard link a inodo 1234)
```

Ambos nombres apuntan al mismo archivo físico. Forma un grafo porque hay múltiples caminos para llegar al mismo nodo.

\textcolor{orange!70!black}{\textbf{Advertencia:}\\
Hard links a directorios NO se permiten (excepto . y ..) porque crearían ciclos imposibles de gestionar en operaciones como eliminación recursiva.\\
}

### Rutas: Absolutas y Relativas

#### Ruta Absoluta

\begin{theory}
\emph{Ruta Absoluta:}
Especifica la ubicación de un archivo desde el directorio raíz. Siempre comienza con \texttt{/} en Unix o \texttt{C:\textbackslash} en Windows.
\end{theory}

**Ejemplos:**
```
/home/alumno/documentos/apuntes.txt
/etc/passwd
/var/log/syslog
```

La ruta absoluta es **inequívoca**: identifica el archivo sin importar el directorio actual.

#### Ruta Relativa

\begin{theory}
\emph{Ruta Relativa:}
Especifica la ubicación desde el directorio de trabajo actual. No comienza con \texttt{/}.
\end{theory}

**Símbolos especiales:**
- `.` (punto): Directorio actual
- `..` (punto-punto): Directorio padre
- `~` (tilde): Directorio home del usuario (expansión del shell)

**Ejemplos:**
```bash
# Si estoy en /home/alumno/proyectos/
./datos.txt              # /home/alumno/proyectos/datos.txt
../documentos/apuntes.txt   # /home/alumno/documentos/apuntes.txt
../../profesor/examen.txt   # /home/profesor/examen.txt
```

### Operaciones sobre Directorios

**mkdir(nombre):** Crea un directorio nuevo
- Crea un FCB de tipo directorio
- Inicializa con entradas `.` (self) y `..` (parent)
- Añade entrada en directorio padre

**rmdir(nombre):** Elimina un directorio
- Solo si está vacío (excepto `.` y `..`)
- Elimina entrada del directorio padre
- Libera FCB del directorio

**opendir(nombre):** Abre un directorio para lectura
**readdir(dir):** Lee la siguiente entrada del directorio
**closedir(dir):** Cierra el directorio

**chdir(nombre):** Cambia el directorio de trabajo actual del proceso

## Estructuras Administrativas del SO

El sistema operativo mantiene varias estructuras en memoria para gestionar archivos abiertos eficientemente.

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

Cada proceso tiene su propia tabla de descriptores de archivo:

```c
struct file_descriptor_table {
    struct file *entries[OPEN_MAX];  // Típicamente 1024 entradas
};
```

- **Índice:** El file descriptor (número entero que retorna `open()`)
- **Valor:** Puntero a entrada en Open File Table
- **Alcance:** Privado del proceso (no compartido)

**File descriptors estándar:**
- 0: stdin (entrada estándar)
- 1: stdout (salida estándar)
- 2: stderr (error estándar)

### Nivel 2: Open File Table (system-wide)

Tabla global del sistema que mantiene información de **todos los archivos abiertos**:

```c
struct open_file_entry {
    int mode;              // O_RDONLY, O_WRONLY, O_RDWR
    off_t offset;          // Posición actual de lectura/escritura
    int ref_count;         // Cantidad de descriptores apuntando aquí
    struct inode *inode;   // Puntero al inodo del archivo
    int flags;             // O_APPEND, O_NONBLOCK, etc.
};
```

\textcolor{blue!50!black}{\textbf{Información técnica:}\\
Múltiples procesos pueden compartir la misma entrada en Open File Table si se hizo \texttt{fork()} después de abrir el archivo, o si se pasó el descriptor via \texttt{dup()} o sockets UNIX.\\
}

**¿Por qué este nivel intermedio?**
- Permite que múltiples procesos compartan el **mismo offset** (padre e hijo después de fork)
- Cada proceso puede abrir el mismo archivo con **diferentes modos y offsets**

### Nivel 3: Inode Table

Tabla de inodos en memoria (cache de los inodos en disco):

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

- **Alcance:** Global, un inodo por archivo en el sistema
- **Cache:** El SO mantiene en memoria los inodos de archivos abiertos
- **Persistencia:** Los cambios se escriben eventualmente a disco

### Ejemplo de Interacción

```c
// Proceso A
int fd1 = open("/home/alumno/datos.txt", O_RDONLY);  // fd1 = 3
read(fd1, buffer, 100);  // offset avanza a 100

// Proceso B (independiente)
int fd2 = open("/home/alumno/datos.txt", O_RDONLY);  // fd2 = 3
read(fd2, buffer, 50);   // offset avanza a 50 (INDEPENDIENTE de A)

// Proceso A hace fork()
pid_t pid = fork();
if (pid == 0) {
    // Hijo: heredó fd1, pero COMPARTE el offset con el padre
    read(fd1, buffer, 50);  // Lee desde byte 100, offset ahora en 150
}
// Padre: el offset también está en 150 (compartido)
```

### File Locking: Sincronización de Acceso

Cuando múltiples procesos acceden al mismo archivo, puede haber **race conditions**. El SO provee mecanismos de locking:

#### Advisory Locking (flock)

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

\textcolor{orange!70!black}{\textbf{Advertencia - Advisory:}\\
Este tipo de lock es "cooperativo". Un proceso malicioso puede IGNORAR el lock y escribir igual. Se confía en que todos los procesos respeten el protocolo.\\
}

#### Mandatory Locking (fcntl)

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

**Tipos de locks:**
- **Shared lock (F_RDLCK):** Múltiples procesos pueden leer simultáneamente
- **Exclusive lock (F_WRLCK):** Solo un proceso puede escribir, bloquea lecturas también

\textcolor{blue!50!black}{\textbf{Uso típico:}\\
- Bases de datos: lockear registros específicos\\
- Archivos de configuración: evitar escrituras concurrentes\\
- Logs: coordinar appends de múltiples procesos\\
}

## Protección y Permisos

### Modelo de Permisos Unix

Unix implementa un modelo simple pero efectivo de control de acceso basado en 9 bits:

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

**Representación numérica (octal):**

| Owner | Group | Others | Octal |
|-------|-------|--------|-------|
| rwx | rwx | rwx | 777 |
| rwx | r-x | r-- | 754 |
| rw- | r-- | r-- | 644 |
| rwx | --- | --- | 700 |

#### Significado de los Permisos

**Para archivos regulares:**
- **r (read):** Lectura del contenido del archivo
- **w (write):** Modificación del contenido (no implica poder eliminarlo)
- **x (execute):** Ejecución como programa

**Para directorios:**
- **r (read):** Listar contenido del directorio (readdir)
- **w (write):** Crear/eliminar archivos en el directorio
- **x (execute):** Atravesar el directorio (acceder a archivos dentro)

\textcolor{orange!70!black}{\textbf{Advertencia importante:}\\
Para eliminar un archivo, NO se necesita permiso de escritura sobre el archivo, sino sobre el DIRECTORIO que lo contiene. El directorio es quien mantiene la lista de nombres.\\
}

### Verificación de Permisos

Cuando un proceso intenta abrir un archivo, el kernel ejecuta:

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

\textcolor{blue!50!black}{\textbf{Nota sobre root:}\\
El usuario root (UID 0) bypasea todas las verificaciones de permisos. Puede leer, escribir y ejecutar cualquier archivo del sistema.\\
}

### Umask: Permisos por Defecto

Cuando se crea un archivo, ¿qué permisos recibe?

\begin{theory}
\emph{Umask:}
Máscara que especifica qué permisos NO otorgar al crear archivos nuevos. Se resta de los permisos solicitados.
\end{theory}

```c
// Si umask = 0022 (octal)
// Permisos solicitados: 0666 (rw-rw-rw-)
// Permisos finales: 0666 & ~0022 = 0644 (rw-r--r--)

int fd = open("nuevo.txt", O_CREAT | O_WRONLY, 0666);
// El archivo se crea con permisos 0644 debido al umask
```

**Umask típicos:**
- **0022:** Usuario puede escribir, grupo y otros solo leer → archivos 644, dirs 755
- **0002:** Usuario y grupo pueden escribir, otros solo leer → archivos 664, dirs 775
- **0077:** Solo el usuario tiene acceso → archivos 600, dirs 700

### Cambio de Permisos

```c
#include <sys/stat.h>

// Cambiar permisos de un archivo
chmod("archivo.txt", 0644);  // rw-r--r--

// Cambiar propietario (requiere privilegios)
chown("archivo.txt", 1000, 1000);  // UID 1000, GID 1000
```

**Desde la shell:**
```bash
chmod 755 script.sh        # rwxr-xr-x
chmod u+x programa.c       # Agregar ejecución para owner
chmod go-w archivo.txt     # Quitar escritura a group y others
chown alumno:estudiantes datos.txt
```
## Implementación Física: Disco

Hasta ahora vimos la **abstracción** de archivos y directorios. Ahora bajamos al nivel físico: ¿cómo se almacenan realmente en el disco?

### Hardware: Sectores vs Bloques

#### Sectores (Físico)

\begin{theory}
\emph{Sector:}
Unidad mínima de transferencia de datos en el hardware del disco. Es una característica física impuesta por la controladora.
\end{theory}

**Tamaños históricos:**
- **512 bytes:** Estándar de 1980s-2010s (discos HDD tradicionales)
- **4096 bytes (4 KiB):** Advanced Format, estándar desde ~2011 (discos modernos y SSD)

El disco **solo puede leer o escribir sectores completos**. No es posible acceder a un byte individual sin leer todo el sector.

#### Bloques (Lógico)

\begin{theory}
\emph{Bloque (o Cluster):}
Unidad mínima de asignación utilizada por el file system. Agrupa uno o más sectores consecutivos. Es una abstracción del software.
\end{theory}

**Relación bloque-sector:**
```
Si sector = 512 bytes y bloque = 4 KiB:
1 bloque = 4096 / 512 = 8 sectores

Si sector = 4 KiB y bloque = 4 KiB:
1 bloque = 1 sector
```

**Comparación:**

| Aspecto | Sector | Bloque |
|---------|--------|--------|
| Naturaleza | Física (hardware) | Lógica (software) |
| Tamaño | Fijo por el disco (512B, 4KB) | Configurable al formatear |
| Usado por | Controladora de disco | Sistema de archivos |
| Granularidad | Operaciones de bajo nivel | Asignación de archivos |

### ¿Por qué usar bloques en vez de sectores directamente?

\textcolor{teal!60!black}{\textbf{Ventajas de los bloques:}\\
- Reduce fragmentación al trabajar con unidades más grandes\\
- Disminuye cantidad de entradas en estructuras administrativas\\
- Mejora rendimiento al leer/escribir múltiples sectores juntos\\
- Simplifica la gestión de espacio libre\\
}

**Ejemplo numérico:**

Archivo de 100 KiB con bloques de 4 KiB:
```
Bloques necesarios = ⌈100 / 4⌉ = 25 bloques
```

Si usáramos sectores de 512 bytes:
```
Sectores necesarios = ⌈100 × 1024 / 512⌉ = 200 sectores
```

El sistema debe mantener 25 punteros en vez de 200 → menos overhead.

### Fragmentación Interna

\textcolor{orange!70!black}{\textbf{Problema - Fragmentación Interna:}\\
Si un archivo ocupa 5 KiB pero los bloques son de 4 KiB, se asignan 2 bloques (8 KiB), desperdiciando 3 KiB. Este espacio no puede ser usado por otros archivos.\\
}

**Desperdicio promedio:** La mitad del tamaño del bloque por archivo

```
Con bloques de 4 KiB:
- Archivo de 1 byte → desperdicia ~4095 bytes
- Archivo de 4097 bytes → desperdicia ~4095 bytes
- Promedio: ~2 KiB de desperdicio por archivo
```

**Trade-off en tamaño de bloque:**

| Tamaño | Fragmentación interna | Overhead metadatos | Rendimiento |
|--------|----------------------|-------------------|-------------|
| 1 KiB | Baja | Alto (muchos punteros) | Bajo |
| 4 KiB | Media | Medio | Medio |
| 8 KiB | Alta | Bajo | Alto (archivos grandes) |
| 64 KiB | Muy alta | Muy bajo | Muy alto (streaming) |

**Elección típica:** 4 KiB es un buen balance para uso general

## Métodos de Asignación de Espacio

El file system debe decidir cómo asignar bloques del disco a los archivos. Tres enfoques principales:

### Método 1: Asignación Contigua

**Concepto:** Los bloques de un archivo se almacenan en posiciones consecutivas del disco.

```
Disco:
+----+----+----+----+----+----+----+----+
| A  | A  | A  | A  | libre | B  | B  | B  |
+----+----+----+----+----+----+----+----+
  100  101  102  103   104    105  106  107

Archivo A: bloque inicial = 100, longitud = 4
Archivo B: bloque inicial = 105, longitud = 3
```

**Metadatos necesarios:**
- Bloque inicial
- Cantidad de bloques

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Acceso secuencial extremadamente rápido\\
- Simple de implementar\\
- Mínima información de ubicación (2 números)\\
- Excelente para dispositivos de acceso secuencial\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Fragmentación externa severa con el tiempo\\
- Difícil hacer crecer archivos (puede requerir mover TODO el archivo)\\
- Necesidad de compactación periódica del disco\\
- Requiere conocer tamaño final del archivo al crearlo\\
}

**Uso actual:** CD-ROM, DVD (medios de solo lectura)

### Método 2: Asignación Enlazada

**Concepto:** Cada bloque contiene datos y un puntero al siguiente bloque, formando una lista enlazada.

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

**Metadatos necesarios:**
- Bloque inicial (el resto se sigue por los punteros)

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- No hay fragmentación externa\\
- Archivos pueden crecer dinámicamente\\
- No requiere conocer tamaño final\\
- Solo se necesita guardar el primer bloque\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Acceso aleatorio muy lento (debe recorrer toda la lista)\\
- Pérdida de un puntero puede corromper el resto del archivo\\
- Parte del bloque se usa para el puntero (overhead)\\
- Pobre localidad espacial (bloques dispersos)\\
}

**Ejemplo de acceso:**

Para leer el byte 10.000 de un archivo con bloques de 4 KiB:
```
Bloque objetivo = 10.000 / 4096 = bloque #2
Necesito: leer bloque 45 → seguir a 78 → seguir a 12 → leer datos
Accesos: 3 (ineficiente)
```

#### Mejora: FAT (File Allocation Table)

En vez de poner punteros dentro de los bloques de datos, se crea una **tabla centralizada** en memoria:

```
Tabla FAT:
Índice  Valor
  45  →  78
  78  →  12
  12  → EOF
```

\textcolor{teal!60!black}{\textbf{Mejoras de FAT:}\\
- Los bloques de datos quedan completos (sin punteros)\\
- La tabla se cachea en memoria (acceso rápido)\\
- Pérdida de puntero solo afecta a la tabla, no a los datos\\
- Más fácil de recuperar ante corrupción\\
}

Este es el método usado por el File System FAT (que veremos en detalle más adelante).

### Método 3: Asignación Indexada

**Concepto:** Se usa un bloque especial (bloque de índice) que contiene punteros a todos los bloques de datos del archivo.

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

**Metadatos necesarios:**
- Número del bloque índice

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Acceso aleatorio eficiente (cálculo directo)\\
- No hay fragmentación externa\\
- Toda la información de ubicación en un solo lugar\\
- Soporte para archivos dinámicos\\
}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Overhead del bloque de índice (desperdicio en archivos pequeños)\\
- Tamaño máximo de archivo limitado por punteros en el bloque índice\\
- Requiere al menos 2 accesos a disco: índice + datos\\
}

**Ejemplo de acceso:**

Para leer el byte 10.000 con bloques de 4 KiB:
```
Bloque objetivo = 10.000 / 4096 = 2
1. Leer bloque índice 500
2. Obtener puntero[2] = 789
3. Leer bloque de datos 789
Accesos: 2 (eficiente)
```

#### Límite de Tamaño

Si bloque = 4 KiB y puntero = 4 bytes:
```
Punteros por bloque = 4096 / 4 = 1024
Tamaño máximo = 1024 × 4 KiB = 4 MiB
```

Para archivos más grandes: **índices multinivel** (Unix/EXT2 usa esta técnica).

### Comparación de Métodos

\begin{center}
agregar diagrama
%%\includegraphics[width=0.9\linewidth,height=\textheight,keepaspectratio]{src/diagrams/cap09-metodosAsignacion.png}
\end{center}

| Aspecto | Contigua | Enlazada (FAT) | Indexada |
|---------|----------|----------------|----------|
| Fragmentación externa | Alta | Ninguna | Ninguna |
| Tamaño dinámico | No | Sí | Sí |
| Acceso secuencial | Excelente | Bueno | Bueno |
| Acceso aleatorio | Excelente | Muy malo | Excelente |
| Overhead metadatos | Mínimo | Medio (tabla FAT) | Alto (bloques índice) |
| Confiabilidad | Alta | Media | Alta |
| Complejidad | Muy simple | Simple | Moderada |

## Manejo de Espacio Libre

El file system debe rastrear qué bloques del disco están libres para asignarlos a archivos nuevos.

### Método 1: Bitmap de Bloques

Un array de bits donde cada bit representa un bloque:

```
Bitmap (1 = ocupado, 0 = libre):
[1 1 1 1 0 0 0 1 1 0 1 1 1 0 0 0 ...]
 0 1 2 3 4 5 6 7 8 9...

Bloque 0: ocupado
Bloque 4: libre
Bloque 5: libre
```

**Operaciones:**

**Buscar bloque libre:**
```c
// Buscar primer bit en 0
for (int i = 0; i < total_bloques; i++) {
    if (bitmap[i / 8] & (1 << (i % 8)) == 0) {
        // Bloque i está libre
        bitmap[i / 8] |= (1 << (i % 8));  // Marcar como ocupado
        return i;
    }
}
```

**Liberar bloque:**
```c
bitmap[bloque / 8] &= ~(1 << (bloque % 8));
```

\textcolor{teal!60!black}{\textbf{Ventajas del bitmap:}\\
- Muy compacto (1 bit por bloque)\\
- Búsqueda de bloques contiguos relativamente fácil\\
- Operaciones simples de set/clear\\
}

**Tamaño del bitmap:**
```
Para un disco de 500 GB con bloques de 4 KiB:
Total bloques = 500 × 1024 × 1024 / 4 = 131.072.000 bloques
Tamaño bitmap = 131.072.000 bits / 8 = ~16 MB
```

### Método 2: Lista Enlazada de Bloques Libres

Los bloques libres forman una lista enlazada:

```
Head → Bloque 45 → Bloque 78 → Bloque 12 → NULL
```

Cada bloque libre contiene el número del siguiente bloque libre.

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Ineficiente para encontrar bloques contiguos\\
- Requiere acceso a disco para explorar la lista\\
- Se desperdicia espacio en bloques libres (para el puntero)\\
}

**Uso:** Sistemas antiguos, ahora obsoleto

### Método 3: Agrupamiento

Combina bitmap y lista: cada entrada de la lista apunta a un **grupo de bloques contiguos**:

```
Head → [45-48] → [78-82] → [100-103] → NULL
```

Reduce cantidad de punteros necesarios.

### Método Usado en Práctica

- **EXT2/3/4:** Bitmap de bloques (eficiente y simple)
- **FAT:** Tabla FAT misma (valor 0x0000 = libre)
- **NTFS:** Bitmap + MFT (Master File Table)

## Seguridad y Recuperación

### Journaling: Registro de Transacciones

\begin{theory}
\emph{Journaling:}
Técnica que registra cambios ANTES de aplicarlos al file system. Si ocurre un fallo, el sistema puede usar el journal para completar o deshacer operaciones incompletas.
\end{theory}

**Problema que resuelve:**

Sin journaling, si el sistema se apaga durante una operación (ej: escribir archivo):
1. Se actualizó el bitmap (bloque marcado como usado)
2. **CRASH** (corte de luz)
3. Se perdió: escritura del inodo, escritura de datos, actualización del directorio

Resultado: inconsistencia (bloque marcado usado pero no referenciado por nadie)

**Cómo funciona journaling:**

```
ANTES del crash:
1. Journal: "Voy a asignar bloque 500 a inodo 1234, actualizar directorio /home/user"
2. Journal: COMMIT (operación lista para aplicar)
3. Aplicar cambios reales: bitmap, inodo, directorio, datos
4. Journal: CLEANUP (operación completada)

DESPUÉS del crash en paso 3:
- Al bootear, el SO lee el journal
- Ve que hay operación COMMIT pero no CLEANUP
- Vuelve a aplicar los cambios (idempotente)
- Sistema queda consistente
```

**Niveles de journaling:**

| Modo | Qué registra | Rendimiento | Seguridad |
|------|-------------|-------------|-----------|
| **Metadata only** | Solo cambios en inodos, directorios, bitmaps | Alto | Media |
| **Ordered** | Metadata, pero escribe datos ANTES de commit | Medio | Alta |
| **Full (Data)** | Metadata Y contenido de archivos | Bajo | Muy alta |

\textcolor{teal!60!black}{\textbf{Ventaja principal:}\\
Recuperación casi instantánea después de un crash: solo replay del journal (segundos) en vez de escanear todo el disco con fsck (horas).\\
}

**Sistemas con journaling:** EXT3, EXT4, XFS, NTFS, HFS+, Btrfs

### fsck / chkdsk: File System Check

\begin{theory}
\emph{fsck (File System Consistency Check):}
Herramienta que verifica y repara inconsistencias en un file system NO montado. Escanea inodos, directorios, bitmaps y bloques de datos.
\end{theory}

**Cuándo se ejecuta:**
- Después de un apagado incorrecto (sin journaling)
- Periódicamente (cada N montajes o M días)
- Manualmente si se detecta corrupción

**Fases de fsck en EXT2:**

1. **Fase 1 - Verificar inodos:**
   - Estructura del inodo válida
   - Bloques referenciados están dentro del rango del disco
   - Tipo de archivo válido

2. **Fase 2 - Verificar directorios:**
   - Entradas de directorio apuntan a inodos válidos
   - No hay ciclos en la estructura de directorios
   - Cada directorio tiene `.` y `..` válidos

3. **Fase 3 - Verificar conectividad:**
   - Todos los inodos usados son accesibles desde raíz
   - Inodos huérfanos se mueven a `/lost+found`

4. **Fase 4 - Verificar contadores:**
   - `links_count` de cada inodo coincide con cantidad real de entradas de directorio
   - Si no coincide, se corrige

5. **Fase 5 - Verificar bitmaps:**
   - Bitmap de bloques coincide con bloques realmente usados
   - Bitmap de inodos coincide con inodos realmente usados
   - Contadores de libres en superbloque son correctos

**Problemas comunes que detecta:**

```
- "Bloque X reclamado por múltiples inodos" → duplicado, hay que elegir
- "Inodo Y no tiene entrada de directorio" → mover a /lost+found
- "Directorio Z referencia inodo inexistente" → eliminar entrada
- "links_count incorrecto en inodo W" → corregir contador
- "Bloques marcados como libres pero en uso" → corregir bitmap
```

\textcolor{red!60!gray}{\textbf{Desventajas de fsck:}\\
- En discos grandes (varios TB) puede tardar HORAS\\
- Debe desmontar el file system (offline)\\
- Solo detecta inconsistencias, no recupera datos perdidos\\
}

**Equivalente en Windows:** `chkdsk` (Check Disk)

```bash
# Linux
fsck /dev/sda1         # Verificar partición
fsck -y /dev/sda1      # Auto-reparar sin preguntar

# Windows
chkdsk C:              # Verificar
chkdsk C: /F           # Reparar
```

## Caso de Estudio 1: FAT (File Allocation Table)

FAT es uno de los sistemas de archivos más simples y ampliamente soportados. Fue creado por Microsoft para MS-DOS (1977-1980) y sigue siendo el estándar en dispositivos portátiles.

### Características Generales

\textcolor{violet!60!black}{\textbf{Diferencia conceptual clave:}\\
En FAT NO existe el concepto de FCB/inodo como estructura separada. La entrada del directorio contiene DIRECTAMENTE todos los metadatos del archivo (nombre, tamaño, primer cluster, atributos, timestamps). La tabla FAT solo contiene información de enlazamiento entre clusters.\\
}

### Componentes de FAT

```
Estructura del volumen FAT:
+----------------+
| Boot Sector    |  Sector 0: parámetros del FS
+----------------+
| FAT #1         |  Tabla de asignación principal
+----------------+
| FAT #2         |  Copia de respaldo
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

Primer sector del volumen, contiene:
- Bytes por sector (típicamente 512 o 4096)
- Sectores por cluster (potencia de 2)
- Cantidad de FATs (típicamente 2)
- Tamaño de las FATs
- Tipo de FAT (12, 16 o 32)

#### 2. Tabla FAT

Array de entradas donde cada índice representa un cluster del disco:

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

**Valores especiales:**

\textcolor{blue!50!black}{\textbf{Valores en tabla FAT:}\\
- \texttt{0x0000}: Cluster libre\\
- \texttt{0x0002} a \texttt{0xFFEF}: Puntero al siguiente cluster del archivo\\
- \texttt{0xFFF7}: Bad cluster (sector defectuoso, no usar)\\
- \texttt{0xFFF8} a \texttt{0xFFFF}: End of chain (último cluster del archivo)\\
}

#### 3. Entrada de Directorio

Cada archivo/subdirectorio tiene una entrada de **32 bytes** en el directorio padre:

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

**Atributos (1 byte):**

| Bit | Nombre | Significado |
|-----|--------|-------------|
| 0 | READ_ONLY | Archivo de solo lectura |
| 1 | HIDDEN | Archivo oculto |
| 2 | SYSTEM | Archivo de sistema |
| 3 | VOLUME_LABEL | Etiqueta del volumen (no es archivo) |
| 4 | DIRECTORY | Es un subdirectorio |
| 5 | ARCHIVE | Modificado desde último backup |

**Limitación 8.3:**

Nombres limitados a 8 caracteres + 3 de extensión:
```
"documento.txt"  → "DOCUMEN~1.TXT"
"mi archivo largo.doc" → "MIARCH~1.DOC"
```

\textcolor{orange!70!black}{\textbf{Nota histórica:}\\
FAT32 y extensiones (VFAT) agregaron soporte para nombres largos usando entradas especiales adicionales, pero internamente sigue siendo 8.3.\\
}

### Concepto de Cluster

\begin{theory}
\emph{Cluster (en FAT):}
Unidad mínima de asignación. Agrupa varios sectores consecutivos. El tamaño del cluster depende del tamaño de la partición.
\end{theory}

**Ejemplo:**
```
Sector = 512 bytes
Cluster = 4 KiB = 8 sectores
```

### FAT12, FAT16, FAT32: Evolución

La diferencia principal es el **tamaño de las entradas en la tabla FAT**:

| Versión | Bits/entrada | Clusters máximos | Tamaño máx partición |
|---------|--------------|------------------|----------------------|
| FAT12 | 12 bits | 4.096 (2¹²) | ~32 MiB (clusters de 8 KiB) |
| FAT16 | 16 bits | 65.536 (2¹⁶) | ~2 GiB (clusters de 32 KiB) |
| FAT32 | 32 bits (28 usados) | ~268 millones | ~2 TiB (clusters de 32 KiB) |

**Uso histórico:**
- **FAT12:** Disquetes de 1.44 MiB (1980s-1990s)
- **FAT16:** Discos duros pequeños hasta 2 GiB (MS-DOS, Windows 95)
- **FAT32:** Windows 95 OSR2 (1996), aún estándar en pendrives y SD cards

\textcolor{orange!70!black}{\textbf{Limitación crítica de FAT32:}\\
Aunque la partición puede ser de 2 TB, FAT32 NO puede almacenar archivos individuales mayores a 4 GiB debido al límite de \texttt{uint32\_t file\_size} (32 bits) en la entrada de directorio.\\
}

### Ejemplo de Operación: Lectura de Archivo

**Escenario:**
- Archivo "documento.txt" de 12 KiB
- Clusters de 4 KiB
- Primer cluster = 245

**Pasos:**

1. **Buscar en directorio:**
   - Leer directorio padre
   - Encontrar entrada con name="DOCUMEN~1" extension="TXT"
   - Obtener first_cluster = 245

2. **Leer primer cluster (4 KiB):**
   - Acceder a cluster 245 en área de datos
   - Copiar 4 KiB a memoria

3. **Consultar tabla FAT:**
   - FAT[245] = 246 → hay más datos

4. **Leer segundo cluster (4 KiB):**
   - Acceder a cluster 246
   - Acumulado: 8 KiB

5. **Consultar tabla FAT:**
   - FAT[246] = 247 → hay más datos

6. **Leer tercer cluster (4 KiB):**
   - Acceder a cluster 247
   - Total: 12 KiB (archivo completo)

7. **Consultar tabla FAT:**
   - FAT[247] = 0xFFFF → EOF, terminar

**Accesos totales:**
- 1 lectura de directorio
- 3 lecturas de clusters de datos
- 3 consultas a tabla FAT (típicamente cacheada en RAM)

**Accesos reales a disco:** ~4 (directorio + 3 clusters), las consultas FAT son en memoria

## Caso de Estudio 2: EXT2 / UFS (Unix File System)

EXT2 (Second Extended File System) es el sistema de archivos clásico de Linux, basado en UFS de BSD Unix. Representa una evolución significativa sobre FAT.

### Filosofía de Diseño

A diferencia de FAT donde metadatos están en el directorio, EXT2 separa claramente:
- **Inodos:** Almacenan TODOS los metadatos del archivo (excepto el nombre)
- **Directorios:** Solo almacenan pares (nombre, número_de_inodo)

Esta separación permite:
- Hard links (múltiples nombres para un inodo)
- Permisos robustos (owner, group, others)
- Información extendida sin cambiar entradas de directorio

### Estructura General: Block Groups

EXT2 divide el volumen en **grupos de bloques** para mejorar localidad:

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

**¿Por qué block groups?**

\textcolor{teal!60!black}{\textbf{Ventajas de block groups:}\\
- Mejora localidad: inodo y sus bloques de datos suelen estar en el mismo grupo\\
- Escalabilidad: estructura repetida permite volúmenes enormes\\
- Confiabilidad: superbloque replicado en múltiples grupos\\
- Reduce fragmentación: archivos de un directorio suelen estar juntos\\
}

### Componentes de un Block Group

Cada grupo contiene:

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
Estructura crítica que contiene metadatos globales del file system. Se replica en varios block groups para redundancia.
\end{theory}

**Campos importantes:**

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

**Magic number 0xEF53:** Identifica inequívocamente un volumen EXT2

**Replicación:** El superbloque se copia en los grupos 0, 1 y potencias de 3, 5, 7 para redundancia

#### 2. Group Descriptor Table (GDT)

Array que describe cada block group:

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

**Block Bitmap:** 1 bit por bloque del grupo (1 = ocupado, 0 = libre)

```
Ejemplo: [1 1 1 1 0 0 0 1 1 0 1 1 1 0 0 0]
         Bloques 0-3: ocupados
         Bloques 4-6: libres
         Bloque 7: ocupado
```

**Inode Bitmap:** 1 bit por inodo del grupo (1 = ocupado, 0 = libre)

**Operaciones:**
- **Buscar libre:** Scan del bitmap hasta encontrar bit en 0
- **Asignar:** Set bit a 1, decrementar contador en superbloque/GDT
- **Liberar:** Clear bit a 0, incrementar contador

#### 4. Inode Table

Array de estructuras inodo. Cada grupo tiene su propia tabla con `inodes_per_group` entradas.

**Tamaño típico de inode:** 128 bytes o 256 bytes (configurable)

#### 5. Data Blocks

El resto del grupo: bloques donde realmente se almacena el contenido de archivos y directorios.

### El Inodo: Corazón de EXT2

\begin{theory}
\emph{Inodo (Index Node):}
Estructura de datos que almacena todos los metadatos de un archivo EXCEPTO su nombre. Contiene permisos, tamaños, timestamps y punteros a los bloques de datos.
\end{theory}

**Estructura completa:**

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

### Cálculo de Tamaño Máximo Teórico

**Parámetros del sistema:**
- Tamaño de bloque: 4 KiB = 4096 bytes
- Tamaño de puntero: 4 bytes (direcciones de 32 bits)
- Punteros por bloque: 4096 / 4 = 1024 punteros

**Capacidad por nivel:**

**1. Bloques directos (12):**
```
12 × 4 KiB = 48 KiB
```

**2. Indirecto simple (1):**
```
1024 punteros × 4 KiB = 4 MiB
```

**3. Indirecto doble (1):**
```
1024 bloques ind. simples × 1024 punteros × 4 KiB 
= 1024² × 4 KiB 
= 4 GiB
```

**4. Indirecto triple (1):**
```
1024 bloques ind. dobles × 1024 bloques ind. simples × 1024 punteros × 4 KiB
= 1024³ × 4 KiB 
= 4 TiB
```

**Tamaño máximo teórico:**
```
48 KiB + 4 MiB + 4 GiB + 4 TiB ≈ 4 TiB
```

\textcolor{orange!70!black}{\textbf{Advertencia - Tamaño máximo REAL:}\\
EXT2 usa un campo \texttt{i\_size} de 32 bits para el tamaño del archivo. Por lo tanto, el límite REAL es $2^{32} bytes = 4 GiB$, independientemente de que la estructura de punteros podría soportar 4 TiB. EXT4 corrige esta limitación usando 64 bits.\\
}

**Análisis con disco de 512 GB:**

Si tenemos un disco de 512 GiB con bloques de 4 KiB:
```
Total de bloques = (512 × 1024 × 1024 KiB) / 4 KiB = 134.217.728 bloques
```

Cada puntero de 4 bytes puede direccionar hasta $2³² = 4.294.967.296$ bloques posibles, lo cual es más que suficiente para nuestro disco de 134 millones de bloques.

**Conclusión:** El límite sigue siendo el campo `i_size` de 32 bits → **4 GiB máximo por archivo**

### Ejemplo de Acceso a Archivo en EXT2

**Caso 1: Archivo pequeño (40 KiB) - Solo bloques directos**

El archivo ocupa 10 bloques ($40 KiB / 4 KiB = 10 bloques$).

Para leer los primeros 8 KiB:
1. **Leer inodo:** 1 acceso (obtener `i_block[0]` y `i_block[1]`)
2. **Leer i_block[0]:** 1 acceso (primeros 4 KiB)
3. **Leer i_block[1]:** 1 acceso (segundos 4 KiB)

**Total: 3 accesos a disco**

**Caso 2: Archivo mediano (5 MiB) - Requiere indirecto simple**

El archivo ocupa 1280 bloques (5 MiB / 4 KiB = 1280).
- Primeros 12 bloques en punteros directos (48 KiB)
- Restantes 1268 bloques en indirecto simple

Para leer desde el byte 200.000:
```
Bloque objetivo = 200.000 / 4096 = bloque #48
```

Como 48 > 11 (fuera de los directos):
```
Posición en ind. simple = 48 - 12 = índice 36
```

Pasos:
1. **Leer inodo:** 1 acceso (obtener i_block[12])
2. **Leer bloque indirecto simple:** 1 acceso (obtener puntero en índice 36)
3. **Leer bloque de datos:** 1 acceso (los datos reales)

**Total: 3 accesos a disco**

## Comparación: FAT vs EXT2

| Característica | FAT | EXT2/UFS |
|----------------|-----|----------|
| **Separación metadatos/nombre** | No (todo en entrada dir.) | Sí (inodo separado) |
| **Método de asignación** | Lista enlazada (tabla FAT) | Indexación multinivel |
| **Hard links** | No soporta | Soportado (contador links_count) |
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

\textcolor{teal!60!black}{\textbf{¿Por qué FAT sigue usándose?}\\
- Compatibilidad universal: todos los SO lo soportan nativamente\\
- Simplicidad: implementación ligera, ideal para dispositivos embebidos\\
- No requiere permisos complejos en dispositivos portátiles compartidos\\
- Menor overhead en dispositivos pequeños\\
}

\textcolor{teal!60!black}{\textbf{¿Por qué EXT2 es mejor para sistemas?}\\
- Soporte robusto de permisos y usuarios múltiples\\
- Hard links permiten estructura más flexible\\
- Acceso aleatorio eficiente crítico para bases de datos\\
- Escalabilidad a volúmenes grandes\\
}

## Links: Hard Links y Soft Links

Ahora que entendemos cómo funcionan FAT (sin inodos) y EXT2 (con inodos), podemos comprender los links.

### Hard Links

\begin{theory}
\emph{Hard Link:}
Entrada de directorio adicional que apunta al MISMO inodo de un archivo existente. Ambos nombres son completamente equivalentes, no hay "original" ni "copia".
\end{theory}

**Ejemplo:**

```bash
$ ls -li archivo.txt
1234567 -rw-r--r-- 1 alumno alumno 5000 Dec 29 10:00 archivo.txt

$ ln archivo.txt copia.txt

$ ls -li
1234567 -rw-r--r-- 2 alumno alumno 5000 Dec 29 10:00 archivo.txt
1234567 -rw-r--r-- 2 alumno alumno 5000 Dec 29 10:00 copia.txt
```

**Observaciones clave:**
- **Mismo número de inodo:** 1234567 (ambos apuntan al mismo inodo)
- **`links_count` = 2:** El inodo sabe que tiene 2 nombres
- Modificar por cualquier nombre afecta al mismo archivo
- **Eliminar un nombre NO elimina el archivo** hasta que `links_count = 0`

**Estructura interna:**

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

\textcolor{orange!70!black}{\textbf{Limitaciones de hard links:}\\
1. No pueden cruzar file systems (cada FS tiene su propia tabla de inodos)\\
2. No pueden apuntar a directorios (excepto \texttt{.} y \texttt{..}) para evitar ciclos\\
3. Solo funcionan en sistemas con inodos (no en FAT)\\
}

**¿Cuándo se elimina el archivo?**

```bash
$ rm archivo.txt    # links_count: 2 → 1 (archivo SIGUE existiendo)
$ rm copia.txt      # links_count: 1 → 0 (AHORA se liberan los bloques)
```

### Soft Links (Symbolic Links)

\begin{theory}
\emph{Soft Link (Symbolic Link):}
Archivo especial cuyo contenido es la RUTA (path) a otro archivo. Es una redirección a nivel de nombres, no de inodos.
\end{theory}

**Ejemplo:**

```bash
$ ln -s /home/alumno/proyecto/datos.txt acceso_datos.txt

$ ls -l
lrwxrwxrwx 1 alumno alumno 30 Dec 29 10:05 acceso_datos.txt -> /home/alumno/proyecto/datos.txt
-rw-r--r-- 1 alumno alumno 5000 Dec 29 10:00 datos.txt
```

**Observaciones clave:**
- El soft link tiene su **PROPIO inodo** (diferente al archivo original)
- El primer carácter es `l` (link type)
- Permisos aparecen como `rwxrwxrwx` (el control está en el archivo destino)
- El "contenido" del soft link es el path: "/home/alumno/proyecto/datos.txt"

**Estructura interna:**

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

**Si se elimina el archivo original:**

```bash
$ rm /home/alumno/proyecto/datos.txt
$ cat acceso_datos.txt
cat: acceso_datos.txt: No such file or directory
```

El soft link queda **roto (dangling link)** pero sigue existiendo. Si luego se crea un archivo nuevo con el mismo nombre, el link vuelve a funcionar.

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

**Caso de uso - Hard links:**
```bash
# Sistema de backups incrementales
# Archivos sin cambios se hard-linkean en vez de copiar
backup/2024-12-01/archivo.txt  ← Inodo 12345
backup/2024-12-02/archivo.txt  ← Inodo 12345 (mismo, no usa espacio)
backup/2024-12-03/archivo.txt  ← Inodo 67890 (cambió, nueva copia)
```

**Caso de uso - Soft links:**
```bash
# Versiones de software
/usr/bin/python3 -> /usr/bin/python3.11  (soft link)
# Actualizar solo requiere cambiar el link, no recompilar programas
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

**Indirecto doble #1:**
```
Capacidad = N × N × B = 1.024 × 1.024 × 8 KiB = 8 GiB = 8.589.934.592 bytes
Rango de bytes: 8.486.912 a 17.076.846.503
```

**Indirecto doble #2:**
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

**¿Indirecto doble #1? (rango: bloque 1.036 a 1.049.611)**
```
Primer bloque = 1.036
Último bloque = 1.036 + (1.024 × 1.024) - 1 = 1.049.611

Rango solicitado [800, 1.053.710]:
- Inicio (800) NO está aquí
- Final (1.053.710) SÍ cruza este rango

Bloques usados = 1.049.611 - 1.036 + 1 = 1.048.576 bloques (TODO el ind. doble #1)
```

**¿Indirecto doble #2? (rango: bloque 1.049.612 a 2.098.187)**
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

**Indirecto doble #1:**
```
Necesitamos TODO el indirecto doble #1 (1.048.576 bloques de datos).

Cantidad de bloques indirectos simples = 1.048.576 / 1.024 = 1.024 bloques

Accesos = 1 (bloque ind. doble raíz) + 1.024 (bloques ind. simples) = 1.025 accesos
```

**Indirecto doble #2:**
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
   - ✅ Acceso secuencial rápido, simple
   - ❌ Fragmentación externa, archivos estáticos
   - Uso: CD-ROM, DVD

10. **Enlazada (FAT)**
    - ✅ Sin fragmentación externa, archivos dinámicos
    - ❌ Acceso aleatorio lento
    - Mejora: tabla FAT centralizada en memoria

11. **Indexada (Unix)**
    - ✅ Acceso aleatorio eficiente
    - ❌ Overhead en archivos pequeños
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
    - Archivo persiste hasta links_count = 0

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

❌ **Error 1:** Olvidar contar el acceso al bloque indirecto raíz
```
Ind. doble NO es solo los simples, es: 1 + simples
```

❌ **Error 2:** Confundir bloques de datos con bloques de punteros
```
Un bloque ind. simple NO es un bloque de datos
```

❌ **Error 3:** No considerar que los bloques directos ocupan las primeras posiciones
```
Bloque 0-11: directos
Bloque 12+: comienza indirecto simple
```

❌ **Error 4:** Usar capacidad teórica cuando hay límite real
```
EXT2: capacidad teórica 4 TiB, pero límite REAL 4 GiB (i_size de 32 bits)
```

❌ **Error 5:** No diferenciar entre FAT (no tiene inodo) y EXT2 (sí tiene inodo)
```
FAT: metadatos en directorio
EXT2: metadatos en inodo separado
```

❌ **Error 6:** Calcular mal los bloques indirectos simples necesarios en un indirecto doble
```
Si necesito 5.000 bloques de datos:
Bloques ind. simples = ⌈5.000 / 1.024⌉ = 5 (NO 4)
Siempre usar techo (ceiling)
```

\texttt{❌} **Error 7:** Olvidar que para eliminar un archivo se necesita permiso de escritura en el DIRECTORIO, no en el archivo
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