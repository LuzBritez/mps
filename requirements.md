# Documento de Requerimientos

## Introducción

Maps es un Módulo de trazabilidad eléctrica para la provincia de Formosa, Argentina, que se integra como extensión funcional dentro de una Aplicación Principal preexistente. El Módulo no es una entidad aislada: reside dentro del ecosistema de la Aplicación Principal, de la cual recibe el contexto del usuario autenticado y a la cual reporta el estado de las operaciones de campo.

El Módulo permite gestionar alarmas, despachar tareas georreferenciadas, monitorear cuadrillas en tiempo real y registrar incidencias tipificadas sobre la red eléctrica de media tensión.

---

## Glosario

- **Aplicación Principal**: Aplicación Flutter preexistente que contiene e inicializa al Módulo, gestiona la autenticación y provee el contexto del usuario.
- **Módulo**: Componente funcional encapsulado que implementa la trazabilidad eléctrica de campo, integrado dentro de la Aplicación Principal.
- **Contexto de Usuario**: Información del usuario autenticado (identidad y rol) provista por la Aplicación Principal al Módulo en el momento de su inicialización.
- **Coordinador**: Usuario con rol administrativo que gestiona alarmas, despacha tareas y monitorea operarios desde la App_Campo, con vistas diferenciadas según su rol.
- **Operario**: Usuario de campo que recibe tareas asignadas, navega rutas y registra incidencias desde la App_Campo.
- **Cuadrilla**: Grupo de uno o más operarios asignados a una tarea de campo.
- **Alarma**: Evento registrado en el sistema que indica una falla en la red eléctrica, vinculado a una línea o zona específica.
- **Tarea**: Unidad de trabajo asignada a un Operario o Cuadrilla, con una geometría (ruta o punto) y un estado de ciclo de vida.
- **Incidencia**: Hallazgo georreferenciado reportado por un Operario sobre un elemento de la red (Línea o Nodo), que requiere atención o seguimiento.
- **Distribuidor**: Alimentador principal de media tensión que parte de una Estación Transformadora y suministra energía a una o varias Setas. Es la unidad lógica superior de agrupación para las líneas.
- **LMT (Línea de Media Tensión)**: Segmento de red eléctrica de media tensión.
- **Seta**: Centro de transformación o subestación eléctrica.
- **Nodo**: Punto de inspección sobre una ruta asignada.
- **App_Campo**: Componente móvil del Módulo utilizado tanto por el Coordinador como por el Operario, con vistas diferenciadas según el rol del usuario autenticado.

---

## Alcance del Módulo

### Fuera de Scope

- **Autenticación y autorización**: El login, la gestión de sesión y los tokens de acceso son responsabilidad exclusiva de la Aplicación Principal. El Módulo asume que el usuario ya está autenticado y recibe su identidad y rol como datos de entrada.

### En Scope

- Visualización del mapa de la red eléctrica de Formosa.
- Gestión de alarmas y despacho de tareas geolocalizadas.
- Navegación de rutas de inspección con seguimiento de nodos.
- Registro de incidencias tipificadas con soporte offline.
- Sincronización del estado de campo en tiempo real.

---

## Requerimientos

Los requerimientos están ordenados según la secuencia de construcción del MVP: cada requerimiento habilita al siguiente, siguiendo el flujo operativo completo del sistema.

---

### Requerimiento 1: Mapa Interactivo de Campo

**User Story:** Como Operario, quiero visualizar un mapa interactivo centrado en Formosa con las capas de la red eléctrica, para orientarme durante las tareas de campo.

#### Criterios de Aceptación

1. THE App_Campo SHALL mostrar un mapa centrado en la provincia de Formosa (coordenadas aproximadas: latitud -24.89, longitud -59.98) al iniciar la sesión.
2. THE App_Campo SHALL soportar gestos de desplazamiento (pan) y zoom mediante pellizco (pinch-to-zoom) con niveles de zoom entre 5 y 18 inclusive.
3. IF el nivel de zoom solicitado es menor a 5 o mayor a 18, THEN THE App_Campo SHALL limitar el zoom al valor mínimo o máximo correspondiente sin mostrar error al Operario.
4. THE App_Campo SHALL renderizar las LMT como polilíneas con color diferenciado según el nivel de tensión.
5. THE App_Campo SHALL renderizar las Setas como marcadores con iconos diferenciados según el tipo de estructura.
6. THE App_Campo SHALL renderizar los Barrios como polígonos semitransparentes para referencia de ubicación urbana.

---

### Requerimiento 2: Control de Capas Independiente

**User Story:** Como Operario, quiero activar o desactivar capas del mapa de forma independiente, para enfocarme en la información relevante durante la inspección.

#### Criterios de Aceptación

1. THE App_Campo SHALL proveer controles independientes para alternar la visibilidad de cada capa: LMT, Setas y Barrios.
2. WHEN el Operario desactiva una capa, THE App_Campo SHALL ocultar todos los elementos de esa capa del mapa sin recargar las demás capas.
3. WHEN el Operario activa una capa previamente desactivada, THE App_Campo SHALL mostrar nuevamente todos los elementos de esa capa en el mapa.
4. WHILE una capa está desactivada, THE App_Campo SHALL mantener los datos de esa capa en memoria para reactivarla sin nueva consulta al sistema.
5. THE App_Campo SHALL persistir el estado de visibilidad de cada capa entre sesiones del Operario.

---

### Requerimiento 3: Gestión de Alarmas

**User Story:** Como Coordinador, quiero activar y gestionar alarmas ante fallas en la red, para vincularlas a líneas o zonas específicas e iniciar el proceso de atención.

#### Criterios de Aceptación

1. WHEN el Coordinador activa una Alarma, THE App_Campo SHALL registrar la Alarma con marca de tiempo, identificador único, identificador de la LMT o zona afectada, y estado inicial `activa`.
2. WHEN el Coordinador vincula una Alarma a una LMT, THE App_Campo SHALL validar que el identificador de LMT exista antes de confirmar el vínculo.
3. IF el identificador de LMT proporcionado no existe, THEN THE App_Campo SHALL mostrar un mensaje de error descriptivo e impedir el registro de la Alarma.
4. WHEN el Coordinador cierra una Alarma, THE App_Campo SHALL actualizar el estado de la Alarma a `cerrada` y registrar la marca de tiempo de cierre.
5. THE App_Campo SHALL listar todas las Alarmas activas ordenadas por marca de tiempo de creación descendente.

---

### Requerimiento 4: Despacho de Tareas

**User Story:** Como Coordinador, quiero despachar tareas a Operarios o Cuadrillas con rutas definidas sobre el mapa, para organizar la atención de incidencias en campo.

#### Criterios de Aceptación

1. WHEN el Coordinador crea una Tarea, THE App_Campo SHALL asociar la Tarea a un Operario o Cuadrilla, una geometría de ruta (secuencia de Nodos sobre LMT), y una Alarma de origen, registrando el estado inicial `pendiente`.
2. WHEN el Coordinador asigna una ruta a una Tarea, THE Módulo SHALL calcular y mostrar la secuencia de Nodos óptima sobre la red.
3. IF la geometría de ruta proporcionada no intersecta ninguna LMT, THEN THE App_Campo SHALL mostrar un mensaje de error e impedir la creación de la Tarea.
4. THE App_Campo SHALL permitir al Coordinador visualizar la ruta asignada sobre el mapa antes de confirmar el despacho.
5. WHEN la Tarea es despachada, THE Módulo SHALL notificar al Operario asignado con los datos de la Tarea.
6. WHEN la Aplicación Principal invoca al Módulo con una Tarea específica como punto de entrada, THE Módulo SHALL presentar esa Tarea directamente sin requerir selección manual por parte del usuario.

---

### Requerimiento 5: Navegación de Ruta Asignada

**User Story:** Como Operario, quiero visualizar y navegar la ruta asignada con la lista de nodos a inspeccionar, para completar la tarea de campo de forma ordenada.

#### Criterios de Aceptación

1. WHEN el Operario abre una Tarea asignada, THE App_Campo SHALL resaltar visualmente el tramo de LMT correspondiente a la ruta asignada sobre el mapa.
2. THE App_Campo SHALL mostrar una lista ordenada de Nodos a inspeccionar, con el identificador y las coordenadas de cada Nodo.
3. WHEN el Operario marca un Nodo como inspeccionado, THE App_Campo SHALL actualizar el estado del Nodo en la lista y registrar el avance en el sistema.
4. WHEN todos los Nodos de una Tarea han sido marcados como inspeccionados, THE App_Campo SHALL proponer al Operario marcar la Tarea como `completada`.
5. WHEN el Operario completa todos los Nodos de una Tarea, THE App_Campo SHALL permitir marcar la Tarea como `completada` y registrar el estado final en el sistema.
6. THE Módulo SHALL utilizar el Contexto de Usuario provisto por la Aplicación Principal para identificar al Operario en todas las acciones de campo, sin solicitarle sus credenciales.

---

### Requerimiento 6: Registro de Incidencias Tipificadas

**User Story:** Como Operario, quiero reportar hallazgos georreferenciados sobre elementos de la red, para documentar el estado de la infraestructura durante la inspección.

#### Criterios de Aceptación

1. WHEN el Operario selecciona un elemento de la red (LMT o Seta) en el mapa, THE App_Campo SHALL habilitar la opción de registrar una Incidencia sobre ese elemento.
2. THE App_Campo SHALL presentar las siguientes categorías de Incidencia para selección obligatoria: `arbol_caido`, `rama_tocando_cable`, `poste_caido`, `cable_cortado`, `cable_chispeando`, `nota_mantenimiento`, `daño_visible`.
3. THE App_Campo SHALL requerir un texto descriptivo no vacío antes de permitir el envío de una Incidencia.
4. WHEN el Operario envía una Incidencia, THE App_Campo SHALL incluir en el registro: marca de tiempo UTC, identidad del Operario (del Contexto de Usuario), identificador de la Tarea activa, categoría seleccionada, texto descriptivo, y coordenadas geográficas del elemento afectado.
5. WHEN el sistema recibe una Incidencia, THE Módulo SHALL persistir el registro y retornar el identificador único asignado.
6. THE App_Campo SHALL solicitar permiso de acceso a la cámara del dispositivo al Operario antes de intentar capturar una imagen, siguiendo las convenciones de permisos en tiempo de ejecución de Android e iOS.
7. IF el Operario deniega el permiso de cámara, THEN THE App_Campo SHALL informar al Operario que la captura de imagen no estará disponible, pero SHALL permitir continuar con el registro de la Incidencia sin imagen.
8. WHEN el Operario registra una Incidencia, THE App_Campo SHALL ofrecer la opción de adjuntar una imagen capturada con la cámara del dispositivo (campo opcional).
9. WHEN el Operario envía una Incidencia con imagen adjunta, THE App_Campo SHALL incluir la imagen en el registro junto con los demás atributos.
10. WHEN el sistema recibe una Incidencia con imagen, THE Módulo SHALL almacenar la imagen y asociarla al registro de la Incidencia, retornando su referencia junto con el identificador único.

---

### Requerimiento 7: Registro de Incidencias en Modo Offline

**User Story:** Como Operario, quiero poder registrar incidencias aunque no tenga conexión a internet, para no interrumpir mi trabajo de campo por falta de señal.

#### Criterios de Aceptación

1. WHEN el Operario registra una Incidencia sin conectividad, THE App_Campo SHALL almacenarla localmente en el dispositivo con todos sus atributos (categoría, descripción, coordenadas, imagen opcional, marca de tiempo UTC).
2. WHEN el Módulo detecta que la conectividad se restablece, THE App_Campo SHALL sincronizar automáticamente todas las Incidencias pendientes sin requerir acción del Operario.
3. THE App_Campo SHALL indicar visualmente al Operario cuántas Incidencias están pendientes de sincronización.
4. IF la sincronización de una Incidencia falla luego de recuperar conectividad, THE App_Campo SHALL reintentar la sincronización y notificar al Operario si el fallo persiste.
5. WHILE el Módulo está sin conectividad, THE App_Campo SHALL permitir continuar navegando el mapa y marcando Nodos inspeccionados con los datos ya cargados en memoria.

---

### Requerimiento 8: Trazabilidad Temporal Fidedigna

**User Story:** Como Coordinador, quiero que cada registro del sistema tenga una marca de tiempo confiable e independiente del reloj del dispositivo, para garantizar la integridad temporal de la trazabilidad incluso cuando el Operario opera en modo offline.

#### Criterios de Aceptación

1. WHEN el Módulo establece conectividad con un servidor NTP confiable, THE Reloj_NTP SHALL calcular y almacenar un offset temporal como la diferencia entre el tiempo del servidor NTP y el uptime del dispositivo.
2. THE Reloj_NTP SHALL utilizar el paquete `ntp` de pub.dev para obtener el tiempo de referencia del servidor NTP.
3. WHEN el Reloj_NTP calcula el tiempo verdadero, THE Reloj_NTP SHALL derivarlo sumando el offset almacenado al uptime actual del dispositivo, sin consultar `DateTime.now()` del sistema operativo.
4. WHILE el Módulo opera en modo offline, THE Reloj_NTP SHALL continuar calculando el tiempo verdadero usando el último offset sincronizado y el uptime del dispositivo.
5. IF el Módulo nunca ha sincronizado con un servidor NTP en la sesión actual, THEN THE Reloj_NTP SHALL marcar los registros generados como `tiempo_no_verificado` hasta que se complete la primera sincronización.
6. WHEN el Operario registra una Incidencia (Requerimientos 6 y 7), THE App_Campo SHALL persistir dos campos de tiempo en el registro: `tiempo_verdadero` calculado por el Reloj_NTP, y `tiempo_dispositivo` obtenido de `DateTime.now()` del sistema operativo.
7. WHEN el Operario marca un Nodo como inspeccionado (Requerimiento 5), THE App_Campo SHALL persistir `tiempo_verdadero` y `tiempo_dispositivo` en el registro del Nodo.
8. WHEN el Coordinador crea una Alarma (Requerimiento 3), THE App_Campo SHALL persistir `tiempo_verdadero` y `tiempo_dispositivo` en el registro de la Alarma.
9. WHEN el Coordinador crea una Tarea (Requerimiento 4), THE App_Campo SHALL persistir `tiempo_verdadero` y `tiempo_dispositivo` en el registro de la Tarea.
10. THE Módulo SHALL exponer `tiempo_verdadero` y `tiempo_dispositivo` en todos los registros sincronizados al backend, para permitir auditorías de manipulación de reloj.
11. IF la diferencia entre `tiempo_verdadero` y `tiempo_dispositivo` supera los 5 minutos en un registro, THEN THE Módulo SHALL marcar ese registro con un indicador `posible_manipulacion_reloj` para revisión del Coordinador.

---

### Requerimiento 9: Rendimiento del Mapa en Dispositivos de Gama Baja

**User Story:** Como Operario que usa un dispositivo de gama baja, quiero que el mapa responda de forma fluida y consuma poca memoria, para poder trabajar en campo sin que la aplicación se congele o se cierre por falta de recursos.

> Este requerimiento afecta transversalmente a: Requerimiento 1 (Mapa Interactivo), Requerimiento 2 (Control de Capas), Requerimiento 4 (Despacho — trazado de rutas) y Requerimiento 7 (Offline).

#### Criterios de Aceptación

1. THE App_Campo SHALL utilizar MapLibre GL como motor de renderizado del mapa, delegando el dibujo de geometrías a la GPU mediante WebGL para reducir la carga sobre la CPU.
2. THE App_Campo SHALL servir la cartografía base y la red eléctrica como Vector Tiles en formato `.pbf`, cargando únicamente los tiles correspondientes al viewport visible en cada momento.
3. WHEN el Operario desplaza o hace zoom en el mapa, THE App_Campo SHALL descartar los tiles fuera del viewport visible y liberar la memoria asociada a esos tiles.
4. WHEN la densidad de puntos (Postes o Setas) en el viewport supera los 50 elementos, THE App_Campo SHALL agrupar los puntos en clusters y mostrar el conteo del grupo en lugar de los marcadores individuales.
5. WHEN el nivel de zoom es suficiente para distinguir elementos individuales (zoom ≥ 14), THE App_Campo SHALL desagrupar los clusters y mostrar los marcadores individuales.
6. WHEN el Módulo carga líneas de alta o media tensión para el viewport visible, THE App_Campo SHALL aplicar el algoritmo Douglas-Peucker con una tolerancia adecuada al nivel de zoom actual para reducir el número de vértices renderizados.
7. THE App_Campo SHALL mantener el uso de RAM del proceso del Módulo por debajo de 150 MB durante la navegación normal del mapa en dispositivos con 2 GB de RAM total.
8. THE App_Campo SHALL utilizar una capa Canvas ligera independiente del motor de tiles para las operaciones de edición geométrica, de modo que los trazos del Operario no fuercen la recarga de los tiles subyacentes.
9. WHEN el Operario realiza una edición geométrica en la capa Canvas, THE App_Campo SHALL persistir el cambio en la base de datos local SQLite/SpatiaLite antes de intentar sincronizarlo con el backend.
10. IF el dispositivo reporta memoria disponible inferior a 200 MB, THEN THE App_Campo SHALL reducir el número máximo de tiles en caché a la mitad del valor configurado por defecto para liberar recursos.
11. WHILE el Módulo opera en modo offline (Requerimiento 7), THE App_Campo SHALL mantener en caché local los tiles del área de trabajo del Operario para permitir la navegación del mapa sin conectividad.
