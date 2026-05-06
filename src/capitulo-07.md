# Interbloqueo (Deadlock)

## Objetivos de Aprendizaje

Al finalizar este capítulo, el estudiante debe ser capaz de:

- Definir formalmente deadlock e identificar sus cuatro condiciones necesarias
- Diferenciar entre deadlock, inanición (starvation) y livelock
- Aplicar estrategias de prevención rompiendo condiciones necesarias
- Implementar el Algoritmo del Banquero para evasión de deadlocks en sistemas con recursos fijos
- Explicar por qué Windows, Linux y macOS adoptan la estrategia "Do nothing" (Avestruz)
- Contrastar el manejo de deadlocks en sistemas de propósito general vs. sistemas críticos

## Introducción y Contexto

### El problema de la espera circular

Imaginemos un cruce de dos calles en una ciudad sin semáforos. En el mismo instante, llegan cuatro autos, uno por cada esquina. Cada auto necesita cruzar, pero el espacio en la intersección sólo permite que uno pase a la vez. Auto A espera a que B se mueva, B espera a C, C espera a D, y D espera a A. Resultado: *nadie se mueve jamás*. Esto es un deadlock en el mundo real.

En los sistemas operativos, ocurre exactamente lo mismo, pero con **procesos** y **recursos**. Un proceso necesita recursos para ejecutarse (impresoras, archivos, memoria, acceso a bases de datos). Si dos o más procesos se bloquean mutuamente esperando recursos que el otro tiene, y ninguno puede ceder porque necesita el otro para avanzar, tenemos un **interbloqueo** o **deadlock**.

\begin{theory}
\emph{Definición formal:}
Un deadlock es una situación en la que un conjunto de procesos está permanentemente bloqueado porque cada proceso del conjunto espera un recurso que sólo puede ser liberado por otro proceso del mismo conjunto (que también está bloqueado).
\end{theory}

\begin{warning}
Deadlock NO es lo mismo que un programa lento o un sistema sobrecargado. En un deadlock, el sistema no progresa \emph{nunca más} a menos que intervenga un agente externo (el administrador o el SO). El tiempo de espera no es "mucho", es \textbf{infinito.}
\end{warning}

### Problemas relacionados: Starvation y Livelock

Antes de seguir, debemos distinguir deadlock de dos fenómenos que lo rodean pero son fundamentalmente distintos.

**Inanición (Starvation)** ocurre cuando un proceso nunca obtiene el recurso que necesita, no porque esté bloqueado en un ciclo, sino porque el sistema siempre prefiere a otros procesos. El proceso está listo para ejecutarse, pero el planificador (o el asignador de recursos) jamás lo selecciona.

\begin{example}
En una impresora compartida, si el sistema siempre prioriza documentos cortos, un trabajo de 500 páginas podría sufrir \emph{starvation}: nunca se imprime porque siempre llegan trabajos de 1 página antes que él. El proceso existe, está listo, pero nunca progresa.
\end{example}

**Livelock** es más sutil y frecuente en sistemas distribuidos. Los procesos no están bloqueados (como en deadlock), y tampoco están detenidos (como en starvation). Están activos, ejecutando código, *pero no progresan hacia su objetivo* porque responden a eventos externos que los hacen retroceder constantemente.

\begin{example}
Dos personas se encuentran cara a cara en un pasillo angosto. Ambas se corren a la izquierda para dejarse pasar, pero justo cuando una se mueve, la otra también se mueve al mismo lado. Entonces ambas se corren a la derecha, y vuelven a chocar. Siguen moviéndose, pero nunca logran cruzarse. Eso es livelock.
\end{example}

\begin{infobox}
En sistemas operativos, un ejemplo típico de livelock ocurre en protocolos de red: dos nodos intentan enviar un paquete al mismo tiempo, detectan colisión, esperan tiempos aleatorios, y vuelven a transmitir simultáneamente una y otra vez. La red está activa, el CPU no está bloqueado, pero el throughput es cero para esa comunicación.
\end{infobox}

## Condiciones para Deadlock

### Las cuatro condiciones necesarias

Para que ocurra un deadlock en un sistema, **deben cumplirse simultáneamente** cuatro condiciones. Si falta una sola, el deadlock es imposible.

1. **Exclusión mutua (Mutual Exclusion)**: Al menos un recurso debe ser no compartible. Es decir, sólo un proceso puede usar el recurso a la vez. Si otro proceso solicita el mismo recurso, debe esperar hasta que el primero lo libere.

2. **Retención y espera (Hold and Wait)**: Un proceso debe estar reteniendo al menos un recurso mientras espera por otros recursos que están siendo retenidos por otros procesos.

3. **No expropiación (No Preemption)**: Los recursos no pueden ser arrebatados forzosamente a un proceso. El proceso debe liberarlos voluntariamente. (Esto es cierto para la mayoría de los recursos: archivos, impresoras, semáforos. No aplica al CPU o memoria, que sí pueden ser expropiados).

4. **Espera circular (Circular Wait)**: Debe existir una cadena circular de procesos donde cada proceso espera un recurso que el siguiente proceso de la cadena posee.

\begin{theory}
Estas condiciones son necesarias: sin ellas, no hay deadlock. Pero no son \textbf{suficientes}: que se cumplan las cuatro no \emph{garantiza} que haya deadlock, porque quizás los procesos liberen recursos antes de que se forme el ciclo. La condición \textbf{suficiente} para deadlock es \emph{\textbf{espera circular} en un sistema que ya cumple las otras tres}.
\end{theory}

### Representación mediante grafos

Para analizar deadlocks visualmente, usamos el **Grafo de Asignación de Recursos**. Es un grafo dirigido con dos tipos de nodos:

- **Procesos**: dibujados como círculos $P_1, P_2, P_3...$
- **Recursos**: dibujados como cuadrados $R_1, R_2, R_3...$ (cada recurso puede tener $k$ instancias si es múltiple)

Las aristas (flechas) pueden ser:

- **Solicitud**: $P_i \rightarrow R_j$ (el proceso $P_i$ está esperando una instancia de $R_j$)
- **Asignación**: $R_j \rightarrow P_i$ (una instancia de $R_j$ está asignada a $P_i$)

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-07/deadlock.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Grafo de Asignación de recursos. Deadlock.
}
\end{center}

**Teorema del ciclo**: Si el grafo no contiene ciclos, no hay deadlock. Si contiene un ciclo, **puede** haber deadlock:
- Si cada recurso tiene una sola instancia: ciclo $\implies$ deadlock seguro.
- Si algún recurso tiene múltiples instancias: ciclo no garantiza deadlock (podría haber instancias libres que rompan la espera).

\begin{example}
Dos procesos compiten por dos impresoras (mismo tipo de recurso, múltiples instancias). P1 tiene una impresora y pide la otra; P2 tiene la otra y pide una. Grafícamente hay ciclo, pero si hay dos impresoras más libres, el sistema puede asignarlas y romper el ciclo. En cambio, si cada impresora es un recurso distinto (R1 y R2), entonces ciclo implica deadlock.
\end{example}

## Estrategias para manejar Deadlocks

Existen cuatro enfoques principales, ordenados de mayor a menor overhead. La elección depende del tipo de sistema.

| Estrategia | Concepto | Overhead | Riesgo | Aplicación típica |
|------------|----------|----------|--------|-------------------|
| **Prevención** | Romper alguna condición necesaria | Alto | Bajo (deadlock imposible) | Sistemas críticos (aviónica) |
| **Evasión** | Evitar entrar en estado inseguro | Medio-Alto | Bajo (si se conoce futuro) | Sistemas con recursos predecibles |
| **Detección + Recuperación** | Permitir deadlock pero detectarlo y revertirlo | Medio | Medio (ventana de riesgo) | Bases de datos |
| **Ignorar (Ostrich)** | Asumir que deadlock es muy improbable | Cero | Alto (el sistema cuelga) | Windows, Linux, macOS |

### El algoritmo del avestruz: "Do nothing"

La mayoría de los sistemas operativos modernos **no hacen nada** para prevenir, evitar o detectar deadlocks entre procesos de usuario. La filosofía es: "deadlocks son tan raros que es más barato reiniciar la máquina que implementar mecanismos complejos".

\begin{excerpt}
El algoritmo del avestruz consiste en meter la cabeza en la arena y pretender que no pasa nada. En sistemas de propósito general, funciona porque los deadlocks ocurren con una frecuencia menor al 0.001% del tiempo de actividad.
\end{excerpt}

**Estadísticas clave** (datos agregados de centros de cómputo):
- En servidores Windows/Linux típicos, menos de 1 deadlock por cada 1000 años de operación continua.
- En sistemas de bases de datos (que sí implementan detección), la frecuencia sube a 1 deadlock cada meses.
- En sistemas mal diseñados (aplicaciones que adquieren locks en orden arbitrario), pueden ocurrir diariamente.

**¿Por qué es tan raro?**
1. Los procesos usualmente no retienen recursos mientras esperan otros.
2. Las aplicaciones bien escritas usán timeouts o liberan recursos rápidamente.
3. El scheduler preemptivo del CPU no genera deadlock por sí solo (sólo recursos no expropiables).

\begin{warning}
"Ostrich" es válido para tu PC y servidores web. \textbf{No es válido} para:\\
- Sistemas de control de misiles\\
- Marcapasos artificiales\\
- Centrales nucleares\\
- Controladores de trenes de alta velocidad\\
En esos sistemas, el deadlock es inaceptable y se usan prevención o evasión.
\end{warning}

**¿Qué hacen Windows, Linux y macOS realmente?**

| SO | Estrategia principal | Excepciones |
|----|---------------------|-------------|
| **Windows** | Ostrich para recursos de usuario; proporciona **Wait Chain Traversal API** para detección por aplicaciones | El kernel no previene/evita deadlock automáticamente, pero debuggers y aplicaciones (SQL Server) pueden detectarlos |
| **Linux** | Ostrich para procesos de usuario | `lockdep` en kernels de desarrollo (detección estática de posibles deadlocks en código del kernel); en producción, off por defecto |
| **macOS** | Ostrich puro | No hay detector general; se confía en la calidad de las aplicaciones |

Todos asumen que el deadlock es un bug de la aplicación, no del SO. Si ocurre, el usuario force-quits el programa (o reinicia).

## Prevención de Deadlocks

La prevención ataca directamente las cuatro condiciones necesarias. Si rompemos **una sola**, el deadlock se vuelve matemáticamente imposible.

### Rompiendo la exclusión mutua

Consiste en hacer que todos los recursos sean compartibles (spooling). Ejemplo: impresoras virtuales. En lugar de que un proceso tome la impresora física, escribe en un archivo en disco (recurso compartible), y un demonio (spooler) se encarga de imprimir en orden.

\begin{infobox}
Funciona para recursos que pueden ser spooled (impresoras, colas de correo). No funciona para recursos intrínsecamente no compartibles: archivos abiertos en modo exclusivo, buffers de memoria, dispositivos de entrada (teclado/mouse).
\end{infobox}

### Rompiendo retención y espera

Dos aproximaciones:  
1. **Asignación global inicial**: El proceso debe solicitar *todos* los recursos que necesitará antes de comenzar. Si no están todos disponibles, no ejecuta.  
2. **Liberar antes de pedir**: El proceso debe liberar todos sus recursos actuales antes de solicitar nuevos.  

\textcolor{orange!70!black}{\textbf{Desventajas:}\\
- Baja utilización de recursos (proceso retiene recursos que no está usando)\\
- Riesgo de starvation (proceso largo nunca obtiene todos sus recursos simultáneamente)\\
- Imposible si el proceso no sabe de antemano qué recursos necesitará\\
}

### Rompiendo no expropiación

Permitir que el SO expropie recursos. Si un proceso pide un recurso que no está disponible, el SO puede:  
- Tomar el recurso de otro proceso que lo tiene (si ese proceso está esperando otro recurso).  
- Forzar a procesos a liberar recursos voluntariamente (enviándoles una señal).  

Implementación práctica:  
Sólo funciona para recursos cuyo estado puede guardarse y restaurarse fácilmente (CPU, memoria). No funciona para impresoras (no podés "des-imprimir" una página) o archivos en mitad de escritura.

### Rompiendo espera circular

**La solución más práctica**: Imponer un orden global de solicitud de recursos.

\begin{theory}
\emph{Ordenación de recursos:}
Asignar un número único a cada tipo de recurso ($R_1, R_2, ..., R_n$). Todo proceso debe solicitar los recursos en orden estrictamente creciente. Si necesita $R_3$ y $R_5$, debe pedir $R_3$ antes que $R_5$.
\end{theory}

¿Por qué funciona? Si todos los procesos siguen el orden, no puede formarse un ciclo. Para tener ciclo, algún proceso debería pedir un recurso de menor número después de tener uno mayor, lo que está prohibido.

\begin{example}
Recursos: Impresora (I=1), Escáner (E=2), Disco (D=3).\\
Proceso A necesita escáner y luego impresora. Como 2 > 1, debe pedir impresora (1) antes que escáner (2).\\
Proceso B necesita impresora y luego disco: 1 < 3, ok.\\
No hay forma de que A tenga escáner y espere impresora mientras B tiene impresora y espera escáner; el orden lo impide.
\end{example}

\textcolor{teal!60!black}{\textbf{Ventajas:}\\
- Sencillo de implementar (sólo requiere que el SO verifique el orden)\\
- Sin starvation si el orden es justo\\
- Overhead bajo}

\textcolor{red!60!gray}{\textbf{Desventajas:}\\
- Requiere consenso global sobre el orden de recursos (difícil en sistemas heterogéneos)\\
- Algunos programas necesitan recursos en orden natural diferente al impuesto}

## Evasión de Deadlocks (Algoritmo del Banquero)

La evasión es más permisiva que la prevención. Permite que se cumplan las cuatro condiciones, pero el sistema operativo **simula** cada asignación de recursos antes de concederla. Si la asignación llevara a un **estado inseguro** (del cual podría derivarse deadlock), el SO la rechaza y hace esperar al proceso.

### Estado seguro vs. estado inseguro

Un estado es **seguro** si existe al menos una secuencia de ejecución de todos los procesos (una "secuencia segura") que permite que terminen sin deadlock, aunque todos soliciten sus recursos máximos.

\begin{theory}
\emph{Secuencia segura:}
Una ordenación $<P_1, P_2, ..., P_n>$ tal que para cada $P_i$, los recursos que aún puede necesitar pueden ser satisfechos por los recursos disponibles más los recursos retenidos por todos los $P_j$ con $j < i$.
\end{theory}

Si el sistema está en estado seguro → no hay deadlock.  
Si está en estado inseguro → **podría** haber deadlock (no es seguro, pero puede que no ocurra si los procesos liberan antes).

### Estructuras de datos del algoritmo

Para $n$ procesos y $m$ tipos de recursos, el banquero mantiene 4 estructuras:

- **Disponible[1..m]**: Vector de recursos disponibles actualmente. $Disponible[j] = k$ significa que hay $k$ instancias del recurso $R_j$ libres.
- **Máximo[1..n, 1..m]**: Matriz donde $Máximo[i][j]$ es la cantidad máxima de instancias de $R_j$ que el proceso $P_i$ puede solicitar.
- **Asignado[1..n, 1..m]**: Recursos actualmente asignados a cada proceso.
- **Necesidad[1..n, 1..m]**: $Necesidad[i][j] = Máximo[i][j] - Asignado[i][j]$ (lo que $P_i$ *todavía podría pedir*).

### Inicialización y verificación de seguridad

Al iniciar el sistema, todos los procesos declaran su $Máximo$. $Disponible$ inicial tiene todos los recursos. $Asignado$ en cero.

\begin{infobox}
\textbf{Algoritmo de verificación de seguridad (Safety Algorithm):}\\
1. Inicializar Trabajo = Disponible, y Fin[n] = falso para todo proceso.\\
2. Buscar un proceso i tal que: Fin[i] == falso y Necesidad[i] ≤ Trabajo.\\
3. Si existe, agregar sus recursos a Trabajo (Trabajo = Trabajo + Asignado[i]), marcar Fin[i] = verdadero, repetir desde paso 2.\\
4. Si al final Fin[i] == verdadero para todos los procesos, el estado es seguro.
\end{infobox}

### Solicitud de recursos

Cuando $P_i$ pide recursos (vector $Petición[1..m]$):

1. Si $Petición > Necesidad[i]$ → error (pidió más de lo declarado).
2. Si $Petición > Disponible$ → proceso debe esperar.
3. **Simular** la asignación: $Disponible' = Disponible - Petición$, $Asignado'[i] = Asignado[i] + Petición$, $Necesidad'[i] = Necesidad[i] - Petición$.
4. Ejecutar Safety Algorithm con $Disponible'$, $Asignado'$, $Necesidad'$.
5. Si el nuevo estado es seguro → conceder la solicitud (actualizar las matrices reales).
6. Si es inseguro → denegar y hacer esperar a $P_i$, restaurando las matrices originales.

\begin{warning}
\textbf{Limitación fundamental:} El algoritmo del banquero requiere que cada proceso conozca su $Máximo$ de antemano, y que ese máximo nunca cambie. En la práctica, los procesos no saben cuántos recursos necesitarán (ej: un editor de texto puede abrir archivos arbitrarios). Por eso, el algoritmo del banquero es didáctico pero casi no se usa en SO reales.
\end{warning}

\begin{warning}
Limitación adicional: El algoritmo del banquero asume que los procesos son \textbf{independientes} (no se comunican ni sincronizan). Si los procesos cooperan (productor-consumidor, barreras de sincronización), la secuencia segura calculada puede ser incorrecta, porque el orden real de ejecución está limitado por la sincronización, no solo por disponibilidad de recursos.
\end{warning}

### Ejemplo 1: Estado seguro

Sistema con 3 procesos ($P_1, P_2, P_3$) y 3 tipos de recursos ($A, B, C$) con instancias: (10, 5, 7).

Estado actual:  

| Proceso | Asignado (A,B,C) | Máximo (A,B,C) | Necesidad (A,B,C) |
|---------|-----------------|----------------|-------------------|
| $P_1$   | (0,1,0)         | (7,5,3)        | (7,4,3)           |
| $P_2$   | (2,0,0)         | (3,2,2)        | (1,2,2)           |
| $P_3$   | (3,0,2)         | (9,0,2)        | (6,0,0)           |  

\vspace{0.3em}
Disponible = (5,3,2)

**Verificación de seguridad**: 
- Paso 1: Trabajo = (5,3,2), Fin = (falso,falso,falso)  
- $P_1$: Necesidad (7,4,3) > Trabajo (5,3,2) → no  
- $P_2$: Necesidad (1,2,2) ≤ Trabajo (5,3,2) → sí. Trabajo = (5,3,2)+(2,0,0) = (7,3,2), Fin[2]=true  
- $P_3$: Necesidad (6,0,0) ≤ Trabajo (7,3,2) → sí. Trabajo = (7,3,2)+(3,0,2) = (10,3,4), Fin[3]=true  
- $P_1$: Ahora Necesidad (7,4,3) ≤ Trabajo (10,3,4)? NO porque 4 ≤ 3 es falso → $P_1$ no puede ejecutar.  

¡Estado inseguro! Aunque no hay deadlock ahora, el banquero no concedería ninguna petición que lleve a este estado.

### Ejemplo 2: Solicitud que lleva a estado seguro

Partimos del mismo estado anterior pero **sin $P_3$ aún**. $P_2$ pide (1,0,1).

Verificación:  
Disponible actual = (5,3,2)  
$Petición_{P_2} = (1,0,1) ≤ Necesidad_{P_2} = (1,2,2)$ (ok)  
$Petición ≤ Disponible = (5,3,2)$? (1,0,1) ≤ (5,3,2) (ok)  

Simulación:  
Disponible' = (5,3,2) - (1,0,1) = (4,3,1)  
Asignado'_{P_2} = (2,0,0)+(1,0,1) = (3,0,1)  
Necesidad'_{P_2} = (1,2,2)-(1,0,1) = (0,2,1)  
Safety Algorithm con nuevo estado:

Trabajo = (4,3,1)  
$P_2$ necesita (0,2,1) ≤ (4,3,1)? sí. Trabajo = (4,3,1)+(3,0,1) = (7,3,2), Fin[2]=true  
$P_1$ necesita (7,4,3) ≤ (7,3,2)? NO  
$P_3$ necesita (6,0,0) ≤ (7,3,2)? sí. Trabajo = (7,3,2)+(3,0,2) = (10,3,4), Fin[3]=true  
$P_1$ ahora necesita (7,4,3) ≤ (10,3,4)? NO → $P_1$ no puede.  

Sigue siendo inseguro. El banquero **denegaría** la petición de $P_2$, aunque los recursos estuvieran disponibles físicamente.

## Detección y Recuperación

Si el sistema no previene ni evita deadlocks, debe al menos detectarlos cuando ocurren y recuperarse. Esta estrategia es común en sistemas de bases de datos y sistemas transaccionales.

### Algoritmo de detección (similar al Safety Algorithm)

Mantiene:  
- **Disponible[1..m]**: recursos libres.  
- **Asignado[1..n, 1..m]**: recursos asignados.  
- **Petición[1..n, 1..m]**: recursos que cada proceso está *actualmente esperando* (a diferencia de Necesidad, que es el máximo futuro).  

\textbf{Algoritmo de detección}:\\
1. Inicializar Trabajo = Disponible.\\
2. Marcar como "no terminados" todos los procesos con $Asignado$ distinto de cero.\\
3. Buscar un proceso no terminado $P_i$ tal que $Petición[i] ≤ Trabajo$.\\
4. Si existe, agregar sus recursos a Trabajo ($Trabajo += Asignado[i]$), marcarlo terminado, repetir.\\
5. Si al final hay procesos no terminados → están en deadlock.\\

\begin{infobox}
La complejidad es $O(m \times n^2)$ en el peor caso. En sistemas con miles de procesos, se ejecuta periódicamente (ej: cada 5 minutos) o cuando la utilización del CPU cae abruptamente (síntoma de deadlock).
\end{infobox}

\begin{highlight}
Nota: A diferencia del algoritmo del banquero (que usa Necesidad = máximo futuro), aquí usamos Petición = lo que el proceso está *actualmente esperando*. Esto es más realista porque los procesos no necesitan conocer su consumo máximo de antemano.
\end{highlight}

### Recuperación de deadlocks

Una vez detectado, hay que salir del deadlock. Opciones:

1. **Matar procesos** (recuperación drástica):
   - Matar todos los procesos en deadlock: simple pero costoso (pérdida de trabajo).
   - Matar uno por uno hasta romper el ciclo: más fino, pero requiere ejecutar detección cada vez.

2. **Retroceso (Rollback)**:
   - Llevar los procesos a un estado anterior seguro (checkpoint) y reiniciarlos desde allí.
   - El proceso retrocedido puede reintentar la operación que causó el deadlock.
   - Requiere que el sistema guarde checkpoints periódicamente (overhead alto).

3. **Expropiación selectiva**:
   - Forzar a un proceso a liberar un recurso (si es posible salvar estado).
   - El proceso expropiado debe reiniciarse desde un checkpoint.

\begin{excerpt}\textbf{Advertencia práctica:}\\
En sistemas de propósito general (Windows, Linux), la recuperación casi nunca se implementa. Si tu PC entra en deadlock, presionás Ctrl+Alt+Supr o reiniciás. Los administradores de bases de datos sí usan detección + rollback de transacciones.
\end{excerpt}

## Deadlock en Propósito General vs. Sistemas Críticos

La elección de estrategia no es técnica sino **económica y de ingeniería de riesgos**.

### Sistemas de propósito general (PCs, servidores web)

- **Frecuencia de deadlock esperada**: extremadamente baja (menos de 1 vez por año en miles de máquinas).
- **Costo de prevención/evasión**: alto (complejidad extra en el kernel, overhead en cada asignación de recurso).
- **Costo de un deadlock cuando ocurre**: bajo (el usuario reinicia la aplicación o la máquina).
- **Estrategia elegida**: **Ostrich** (ignorar). Incluso si ocurre, el costo de implementar solución supera el costo del problema.

### Sistemas críticos (aeronáutica, medicina, industria)

- **Frecuencia esperada**: debe ser cero por diseño.
- **Costo de deadlock si ocurre**: vidas humanas, daños millonarios.
- **Estrategia elegida**: **Prevención** (rompiendo espera circular mediante orden global de recursos) o **Evasión** (si es posible conocer Máximos).
- **Regulaciones**: DO-178C (aviación), IEC 62304 (software médico) exigen análisis formal de deadlock.

\begin{center}
\includegraphics[width=0.9\linewidth,keepaspectratio]{src/images/capitulo-07/decision-deadlock.png}

\vspace{0.3em}
{\small\itshape\color{gray!65}
Diagrama de Decisión  para el Manejo de Deadlocks
}
\end{center}

## Ejercicios Tipo Parcial

**Ejercicio 1 (Deadlock detection con múltiples instancias)**  
Dado el siguiente estado de recursos (instancias totales: A=4, B=3, C=2):  

| Proceso | Asignado (A,B,C) | Petición (A,B,C) |
|---------|-----------------|------------------|
| P1      | (1,0,1)         | (2,0,1)          |
| P2      | (2,1,0)         | (0,1,1)          |
| P3      | (0,0,1)         | (1,0,0)          |
| P4      | (0,2,0)         | (1,2,0)          |  

\vspace{0.3em}
Disponible = (1,0,0)  

Verificar que la suma de asignados más disponible es igual al total de instancias:
- A: 1+2+0+0+1 = 4 ✓
- B: 0+1+0+2+0 = 3 ✓
- C: 1+0+1+0+0 = 2 ✓

Determinar si hay deadlock. En caso afirmativo, ¿qué procesos están involucrados?

*Solución paso a paso en próxima página...*

**Ejercicio 2 (Algoritmo del banquero - estado seguro)**  
Un sistema tiene 4 procesos y 3 recursos (A:8, B:6, C:5). La matriz Máximo es:
Máximo =
(3,2,2) \\
(4,1,3) \\
(2,3,1) \\
(4,2,2)  

Asignado actual = $[(1,0,0), (2,1,1), (0,1,0), (1,0,1)]$. Calcular Necesidad y Disponible. ¿Hay secuencia segura? Si P3 pide (1,0,0), ¿se la concede el banquero?

**Ejercicio 3 (Prevención - orden de recursos)**  
Un sistema tiene 5 tipos de recursos numerados 1 a 5. Se sabe que los procesos A, B, C siguen las siguientes secuencias de solicitud:
- A: pide 3, luego 5, luego 1
- B: pide 2, luego 4, luego 3  
- C: pide 1, luego 3, luego 2

¿Qué orden global de solicitud (asignación de números a recursos) permitiría evitar deadlock por espera circular? ¿Existe alguna asignación que lo logre?

**Ejercicio 4 (Deadlock vs Starvation vs Livelock)**  
Clasificar cada situación como Deadlock (D), Starvation (S), Livelock (L) o Ninguno (N):
- Dos procesos intentan entrar a una sección crítica. El scheduler siempre elige el mismo proceso, el otro nunca avanza. \_\_\_
- Procesos P1 tiene recurso R1 y espera R2; P2 tiene R2 y espera R3; P3 tiene R3 y espera R1. \_\_\_
- Dos procesos envían paquetes de red, detectan colisión, esperan tiempos aleatorios, colisionan nuevamente una y otra vez sin que ningún paquete llegue a destino. \_\_\_
- Un proceso solicita una impresora. No hay disponible, pero el proceso no se bloquea; en su lugar, reintenta cada 10ms, pero siempre ve la impresora ocupada. **Ninguno (espera activa sin deadlock/starvation/livelock)**

## Síntesis

**Resumen conceptual**:
- Deadlock requiere 4 condiciones: exclusión mutua, retención y espera, no expropiación, espera circular.
- Prevención → rompe una condición (más efectiva: orden de recursos).
- Evasión → algoritmo del banquero (requiere conocer Máximo).
- Detección + recuperación → útil en bases de datos.
- Ostrich → Windows, Linux, macOS (deadlock es bug de aplicación).

**Fórmulas clave**:
- Necesidad[i][j] = Máximo[i][j] - Asignado[i][j]
- Condición de seguridad: $∃$ secuencia $<P_1...P_n>$ tal que $∀i, Necesidad[P_i] ≤ \text{Disponible} + \sum_{k=1}^{i-1} Asignado[P_k]$

**Tips para el parcial**:
1. Grafos de asignación: ciclo + recursos de instancia única → deadlock seguro.
2. Algoritmo del banquero: siempre verificar $Petición ≤ Necesidad$ antes de simular.
3. En ejercicios de prevención por orden, buscá asignar números crecientes según el orden real de uso.
4. Distinguir claramente: deadlock es "todos esperan a todos", starvation es "uno nunca avanza", livelock es "todos avanzan pero no progresan".
