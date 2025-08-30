# Template de Colores - Libro Técnico

## Configuración LaTeX requerida
Agregar a `header-includes` en metadata.yaml:
```latex
\usepackage{xcolor}
\usepackage{tcolorbox}
```

---

## 1. ÉXITO / VENTAJAS / CORRECTO
**Uso recomendado:** Ventajas, features positivas, ejemplos correctos

### Verde grisáceo oscuro (RECOMENDADO)
\textcolor{green!40!black}{
**Ventajas:**
- Favorece procesos I/O-bound (más interactivos)
- Mejor respuesta que RR puro
- Mantiene fairness de RR
}

### Verde grisáceo medio
\textcolor{green!60!gray}{
**Características positivas:**
- Alta eficiencia energética
- Compatibilidad multiplataforma
- Fácil mantenimiento
}

### Verde azulado (elegante)
\textcolor{teal!60!black}{
**Implementación correcta:**
- Sincronización adecuada
- Manejo de errores robusto
- Performance optimizada
}

---

## 2. ERROR / DESVENTAJAS / INCORRECTO
**Uso recomendado:** Desventajas, problemas, errores comunes

### Rojo grisáceo oscuro (RECOMENDADO)
\textcolor{red!50!black}{
**Desventajas:**
- Mayor complejidad de implementación
- Overhead adicional por doble cola
- Posible starvation en casos extremos
}

### Rojo apagado
\textcolor{red!60!gray}{
**Problemas comunes:**
- Race conditions no controladas
- Deadlocks por mal diseño
- Memory leaks en procesos largos
}

### Marrón rojizo (profesional)
\textcolor{brown!70!black}{
**Errores frecuentes:**
- No verificar códigos de retorno
- Asumir orden de ejecución
- Ignorar casos edge
}

---

## 3. ADVERTENCIA / ATENCIÓN / IMPORTANTE
**Uso recomendado:** Warnings, notas importantes, precauciones

### Naranja grisáceo (RECOMENDADO)
\textcolor{orange!70!black}{
**⚠️ Advertencia:**
- El scheduler puede causar starvation
- Verificar siempre timeout en syscalls
- Considerar priority inversion
}

### Amarillo oscuro
\textcolor{yellow!80!black}{
**Nota importante:**
- Los procesos zombie consumen PID
- Límite del sistema: 32768 procesos
- Monitorear uso de file descriptors
}

### Magenta apagado
\textcolor{magenta!50!black}{
**Consideración especial:**
- En sistemas embebidos limitar threads
- Memory mapping requiere alineación
- Context switch costoso en ARM
}

---

## 4. INFORMACIÓN / NEUTRAL / DEFINICIONES
**Uso recomendado:** Definiciones, conceptos neutrales, explicaciones

### Azul grisáceo (RECOMENDADO)
\textcolor{blue!50!black}{
**Definición:**
El scheduler determina qué proceso ejecutar y cuándo realizar context switches para maximizar la utilización del sistema.
}

### Azul marino
\textcolor{blue!60!gray}{
**Concepto clave:**
La multiprogramación permite que múltiples procesos residan en memoria, alternando el uso de CPU cuando uno hace I/O.
}

### Gris azulado
\textcolor{cyan!40!black}{
**Información técnica:**
PCB (Process Control Block) contiene: PID, estado, registros, punteros de memoria, file descriptors abiertos.
}

---

## 5. CÓDIGO / TÉCNICO / IMPLEMENTACIÓN
**Uso recomendado:** Snippets de código, detalles técnicos, APIs

### Violeta oscuro
\textcolor{violet!60!black}{
**Implementación:**
```c
struct pcb {
    pid_t pid;
    int state;
    void *stack_ptr;
};
```
}

### Índigo grisáceo
\textcolor{blue!40!purple!60!black}{
**API del sistema:**
- `fork()`: Crear proceso hijo
- `exec()`: Reemplazar imagen del proceso  
- `wait()`: Esperar terminación de hijo
}

---

## 6. EJEMPLOS PRÁCTICOS
**Uso recomendado:** Casos de uso, ejemplos del mundo real

### Verde oliva
\textcolor{olive!80!black}{
**Ejemplo práctico:**
Un servidor web usa multiprocesamiento: proceso padre acepta conexiones, procesos hijos manejan requests individuales.
}

### Gris medio
\textcolor{gray!70!black}{
**Caso de estudio:**
Linux usa CFS (Completely Fair Scheduler) que asigna tiempo de CPU proporcionalmente al nice value de cada proceso.
}

---

## 7. FÓRMULAS / MÉTRICAS / CÁLCULOS
**Uso recomendado:** Fórmulas matemáticas, métricas de performance

### Púrpura grisáceo
\textcolor{purple!50!black}{
**Métricas de scheduling:**
- Tiempo de respuesta = Tiempo completado - Tiempo llegada
- Throughput = Procesos completados / Tiempo total
- Utilización CPU = Tiempo CPU ocupado / Tiempo total
}

---

## GUÍA RÁPIDA DE USO:

**✅ Para ventajas/éxito:** `\textcolor{green!40!black}{}`  
**❌ Para desventajas/errores:** `\textcolor{red!50!black}{}`  
**⚠️ Para advertencias:** `\textcolor{orange!70!black}{}`  
**ℹ️ Para información:** `\textcolor{blue!50!black}{}`  
**💻 Para código/técnico:** `\textcolor{violet!60!black}{}`  
**📊 Para métricas:** `\textcolor{purple!50!black}{}`  
**📖 Para ejemplos:** `\textcolor{olive!80!black}{}`