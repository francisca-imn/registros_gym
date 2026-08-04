# 🧠 Cómo está hecha esta app (para aprender a programarla)

Este documento explica `app.R` de punta a punta, pensado para alguien que recién está aprendiendo R/Shiny. La idea es que después de leerlo puedas modificar la app con confianza — agregar un tipo de actividad nuevo, un campo, un gráfico, etc.

---

## 1. ¿Qué es Shiny?

Shiny es un framework de R para construir aplicaciones web **sin tener que escribir HTML/JavaScript a mano**. Una app Shiny siempre tiene dos partes:

- **`ui`** (interfaz): describe qué se ve en pantalla — botones, campos de texto, pestañas, gráficos. Es "declarativa": tú describes el layout, Shiny lo traduce a HTML.
- **`server`** (lógica): describe qué pasa cuando el usuario interactúa — al hacer clic en un botón, escribir en un campo, etc. Es donde ocurren los cálculos y el guardado de datos.

Al final del archivo, `shinyApp(ui, server)` conecta ambas partes y arranca la aplicación.

```r
ui <- fluidPage( ... )       # define el "qué se ve"
server <- function(input, output, session) { ... }  # define el "qué hace"
shinyApp(ui, server)
```

## 2. El concepto clave: reactividad

Shiny no funciona como un script normal que corre de arriba a abajo una vez. Funciona con **reactividad**: cada `input$algo` (lo que el usuario escribe/selecciona) puede disparar recálculos automáticos de cualquier `output$algo` que lo use, sin que tú tengas que decir explícitamente "ahora recalcula esto".

Los tres bloques reactivos que vas a ver una y otra vez en este archivo:

| Bloque | Para qué sirve | Ejemplo en la app |
|---|---|---|
| `renderUI({...})` | Generar **interfaz** dinámicamente según el estado actual | `opciones_dinamicas`: muestra campos distintos según el tipo de actividad elegido |
| `observeEvent(input$x, {...})` | Ejecutar una **acción** cuando pasa algo puntual (un clic) | `observeEvent(input$guardar, {...})`: guarda el entrenamiento al hacer clic |
| `renderPlotly({...})` / `renderTable({...})` | Generar una **salida** (gráfico, tabla) que se recalcula sola cuando cambian sus datos de entrada | `grafico_semanal`, `tabla_carreras` |

Una forma simple de pensarlo: `render*` = "dibuja esto, y redibújalo solo si algo de lo que uso cambia". `observeEvent` = "cuando pase X, haz Y una vez".

## 3. `reactiveValues`: el "estado" de la app

```r
v <- reactiveValues(data = obtener_datos_iniciales())   # entrenamientos
r <- reactiveValues(carreras = obtener_carreras_iniciales())  # carreras/metas
b <- reactiveValues(data = obtener_cuerpo_inicial())     # peso/talla
```

`v`, `r` y `b` son como tres "cajas" que guardan el estado actual de la app en memoria mientras está abierta (cada una guarda un `data.frame`, la estructura tabular estándar de R — piensa en ella como una hoja de Excel). Cuando algo cambia esa caja (por ejemplo `v$data <- rbind(v$data, nueva_fila)`), **todo lo que dependa de `v$data` se vuelve a calcular solo**: la tabla, el gráfico, etc. Esa es toda la magia de Shiny.

## 4. Persistencia: por qué los datos no se pierden al cerrar la app

Cada vez que guardas algo, pasan dos cosas:

1. Se actualiza la "caja" en memoria (`v$data <- rbind(...)`) — esto es lo que hace que la interfaz se actualice al instante.
2. Se escribe a disco con `write.csv(v$data, DATA_FILE, row.names = FALSE)` — esto es lo que hace que sobreviva a cerrar la app.

Al volver a abrir la app, `obtener_datos_iniciales()` (y sus equivalentes `obtener_carreras_iniciales()` / `obtener_cuerpo_inicial()`) leen esos CSV con `read.csv()` y reconstruyen la caja en memoria. Por eso hay **tres archivos CSV** junto a `app.R`:

- `gym_data_fran.csv` — entrenamientos diarios
- `carreras_fran.csv` — resultados y metas de carreras
- `cuerpo_fran.csv` — peso y talla en el tiempo

> ⚠️ Esto funciona de forma 100% confiable cuando corres la app **localmente** (RStudio, `Rscript`). Si la usas desplegada en shinyapps.io (plan gratuito), el disco de la app no tiene garantía de persistencia entre reinicios o nuevos despliegues — por eso la pestaña "Historial & Copia de Seguridad" tiene botones de exportar/restaurar CSV como respaldo manual.

## 5. Recorrido por la UI (`ui <- page_navbar(...)`, con `bslib`)

La app usa **`bslib`**, el paquete oficial de Posit para construir interfaces Shiny sobre **Bootstrap 5** en vez del Bootstrap 3 que trae Shiny por defecto. Es la diferencia entre "una app de R con estilos encima" y una app que de verdad se ve como un dashboard moderno (tarjetas con sombra sutil, tipografía Inter, formularios prolijos) sin tener que reinventar CSS desde cero.

- **`tema_app <- bs_theme(...)`**: define el "sistema de diseño" completo de la app en un solo lugar — color primario (`primary = "#4F46E5"`), color de peligro (`danger`), tipografía (`base_font = font_google("Inter")`), radios de borde, etc. Todo lo que uses después (`class = "btn-primary"`, `class = "text-danger"`, un `card()`) hereda automáticamente estos colores. Si un día quieres cambiar el color principal de toda la app, se cambia **una sola línea** acá — no hay que perseguir cada botón.
- **`bs_add_rules("...")`**: el CSS "de escape" para lo poco que Bootstrap 5 no cubre por sí solo (por ejemplo, el borde de color en los sliders, o las clases `.activity-block` / `.danger-block` que uso para los recuadros de detalle de cada actividad). La regla general: si algo se puede lograr con una clase de Bootstrap (`class = "text-primary"`, `class = "bg-danger-subtle"`, `class = "w-100"`), se usa esa clase directamente en el R en vez de escribir CSS nuevo.
- **`page_navbar(title = ..., theme = tema_app, sidebar = sidebar(...), nav_panel(...), nav_panel(...), ...)`**: la estructura general de la app. `page_navbar` dibuja la barra de navegación superior; `sidebar = sidebar(...)` engancha una barra lateral que queda visible sin importar en qué pestaña estés (ahí vive el formulario de "Registrar hoy"); cada `nav_panel("Nombre", ...)` es una pestaña — agregar una pestaña nueva es agregar un `nav_panel(...)` más a la lista.
- **`card(card_header("Título"), ...)`**: la unidad visual básica de la app — un bloque blanco con borde y sombra sutil. Casi todo el contenido de cada pestaña vive dentro de uno o más `card()`.
- **`layout_columns(col_widths = c(4, 8), ...)`** y **`layout_column_wrap(width = "220px", ...)`**: ayudan a poner varias tarjetas en fila de forma responsiva (se reacomodan solas en pantallas angostas), sin tener que calcular anchos a mano como con `fluidRow()`/`column()`.
- **`value_box(title = ..., value = ..., p(...), theme = "text-primary")`**: el componente que arma las tarjetas de estadística — las cuentas regresivas de carreras y el resumen de peso/IMC en "Progreso Físico" son `value_box()`, no `div()` hechos a mano. Es el tipo de componente que un dashboard "profesional" trae de fábrica.
- **`uiOutput("algo")`**: un "hueco" en la interfaz que el `server` va a rellenar dinámicamente con `renderUI`. Búscalo en `server` por el mismo nombre (`output$algo <- renderUI({...})`) para ver qué lo llena. Esto no cambió respecto a antes — sigue siendo la forma de mostrar interfaz que depende de datos (el formulario de carrera, los paneles de borrado, etc.).

## 6. Recorrido por el `server`

### 6.1 Carga inicial y restauración

`obtener_datos_iniciales()`, `obtener_carreras_iniciales()`, `obtener_cuerpo_inicial()` siguen el mismo patrón: si el archivo CSV existe, lo lee; si no, devuelve una tabla vacía con las columnas correctas. Este patrón evita que la app se caiga la primera vez que se ejecuta (cuando todavía no existen los CSV).

### 6.2 El formulario dinámico de "Registrar Hoy"

Esta es la parte más "avanzada" del código, vale la pena entenderla bien:

```r
output$opciones_dinamicas <- renderUI({
  req(input$tipo)               # no hagas nada si no hay tipo elegido
  ui_elements <- list()         # lista vacía donde vamos acumulando campos

  if ("Running/Trote" %in% input$tipo) {
    ui_elements <- c(ui_elements, list( ... campos de running ... ))
  }
  if ("Crossfit" %in% input$tipo) {
    ui_elements <- c(ui_elements, list( ... campos de crossfit ... ))
  }
  # ...

  do.call(tagList, ui_elements)  # convierte la lista en HTML real
})
```

`input$tipo` es un vector (porque el selector permite elegir varias actividades a la vez). Por cada tipo que esté seleccionado, se agrega un bloque de campos específico a `ui_elements`. Al final, `do.call(tagList, ui_elements)` junta todos esos bloques en un solo pedazo de interfaz. **Este es el patrón a copiar si quieres agregar un tipo de actividad nuevo** (ver sección 8).

### 6.3 Guardar un entrenamiento

`observeEvent(input$guardar, {...})` se dispara al hacer clic en "Guardar Entrenamiento". Por cada tipo de actividad seleccionado, arma dos textos:

- `detalles_lista`: texto corto para la tabla (columna "Detalles")
- `tooltip_lista`: texto con formato HTML (`<br>`) para el tooltip del gráfico

Al final arma `nueva_fila` (un `data.frame` de una sola fila) y la pega abajo del histórico con `rbind()`, luego lo guarda a disco.

`RPE_Prom` es el esfuerzo percibido promedio de la sesión (si registraste running + crossfit el mismo día, por ejemplo, promedia el RPE de ambos). Es informativo, no afecta el cálculo de `Carga` (que sigue siendo "cuántos tipos de actividad hiciste ese día", igual que en la versión original de la app).

### 6.4 Los tres módulos de datos

La app tiene tres "familias" de outputs que se repiten con la misma estructura, solo que aplicada a datos distintos:

| Módulo | Caja de datos | Formulario | Gráfico | Tabla | Borrado |
|---|---|---|---|---|---|
| Entrenamientos | `v$data` | Sidebar | `grafico_semanal`, `grafico_mensual` | `tabla_semana`, `historial_completo` | `ui_panel_borrar` |
| Carreras/Metas | `r$carreras` | `ui_form_carrera` | `grafico_carreras` | `tabla_carreras` | `ui_panel_borrar_carrera` |
| Progreso Físico | `b$data` | `ui_form_cuerpo` | `grafico_peso` | `tabla_cuerpo` | `ui_panel_borrar_cuerpo` |

Si entiendes uno, entiendes los tres — están escritos deliberadamente en paralelo para que sea fácil comparar y copiar el patrón.

### 6.5 El "candado" con clave

```r
PASS <- Sys.getenv("GYM_APP_PASS", unset = "fran123")
```

La clave para poder guardar/borrar datos no está pensada como seguridad real (cualquiera que vea el código fuente la puede leer) — es solo para evitar que alguien toque tus datos por accidente si comparte el link. `Sys.getenv(...)` permite definir la clave real como variable de entorno (por ejemplo en la configuración de shinyapps.io) en vez de dejarla escrita en el código; si no defines esa variable, usa `"fran123"` por defecto.

Cada formulario protegido sigue el mismo patrón:

```r
output$ui_form_x <- renderUI({
  if (input$pass != PASS) return(p("Ingresa tu clave..."))
  tagList(... los inputs del formulario real ...)
})
```

### 6.6 Funciones auxiliares de tiempo/ritmo

Al principio del archivo:

- `parse_tiempo("1:14:15")` → segundos totales (número)
- `formatear_segundos(4455)` → `"1:14:15"` (texto)
- `calcular_ritmo(tiempo_seg, distancia_km)` → ritmo en min/km, como texto (`"7:26"`)
- `ritmo_a_minutos("7:26")` → `7.43` (número decimal, útil solo para graficar)

Son funciones puras (mismo input → mismo output, sin efectos secundarios), así que se pueden probar sueltas en la consola de R para entender qué hacen:

```r
parse_tiempo("1:14:15")        # 4455
calcular_ritmo(4455, 10)       # "7:26"
```

### 6.7 Gráficos con `ggplot2` + `plotly`

El patrón en toda la app es: primero armar el gráfico "estático" con `ggplot()`, y al final envolverlo en `ggplotly(g, tooltip = "text")` para que se vuelva interactivo (zoom, tooltips al pasar el mouse). El truco del tooltip es el argumento `text = paste0(...)` dentro de `aes()`: ese texto (que puede incluir HTML) es lo que se muestra al pasar el mouse sobre cada punto o barra.

### 6.8 Las pestañas de "Plan 21K" y "Plan Alimentación"

```r
tabPanel("🏃‍♀️ Plan 21K", br(), div(class = "plan-doc", includeMarkdown("PLAN_ENTRENAMIENTO_21K.md")))
```

`includeMarkdown()` lee un archivo `.md` y lo convierte a HTML directamente dentro de la UI. Esto significa que **para editar el plan de entrenamiento o de alimentación no hace falta tocar `app.R` en absoluto** — basta con editar esos archivos `.md` como texto plano.

## 7. Los archivos del proyecto, de un vistazo

```
app.R                        # toda la lógica de la app (UI + server)
gym_data_fran.csv            # datos: entrenamientos diarios
carreras_fran.csv            # datos: resultados y metas de carreras
cuerpo_fran.csv              # datos: peso / talla en el tiempo
PLAN_ENTRENAMIENTO_21K.md    # contenido del plan de running (se lee, no se ejecuta)
PLAN_ALIMENTACION.md         # contenido del plan de alimentación (se lee, no se ejecuta)
CODIGO_EXPLICADO.md          # este documento
README.md                    # documentación general del proyecto
```

## 8. Cómo agregar tú misma un tipo de actividad nuevo (ejercicio guiado)

Digamos que quieres agregar "Pilates". Necesitas tocar 3 lugares:

1. **La lista de opciones**, cerca del inicio del archivo:
   ```r
   tipos_actividad <- c(..., "Solo Cardio", "Otro", "Pilates")
   ```

2. **El formulario dinámico** (`output$opciones_dinamicas`), agregando un bloque nuevo copiando el patrón de "Tenis" o "Escalada":
   ```r
   if ("Pilates" %in% input$tipo) {
     ui_elements <- c(ui_elements, list(
       div(class = "activity-block",
           div(class = "block-title", "Detalles de Pilates"),
           numericInput("pil_duracion", "Duración (min):", value = 50, min = 0),
           sliderInput("pil_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 4)
       )
     ))
   }
   ```

3. **El guardado** (`observeEvent(input$guardar, {...})`), agregando el bloque que arma el texto y suma el RPE:
   ```r
   if ("Pilates" %in% input$tipo) {
     detalles_lista <- c(detalles_lista, paste0("Pilates (", input$pil_duracion, " min)"))
     tooltip_lista <- c(tooltip_lista, paste0("• Pilates (", input$pil_duracion, " min)"))
     rpe_vals <- c(rpe_vals, input$pil_rpe)
   }
   ```

Con eso ya tendrías Pilates funcionando igual que Tenis o Escalada — mismo patrón, datos nuevos.

## 9. Cómo probar cambios sin miedo a romper nada

- Antes de tocar nada, puedes revisar que el archivo no tenga errores de sintaxis sin correr la app completa:
  ```r
  parse("app.R")
  ```
- Para correr la app localmente (por ejemplo desde RStudio, con el botón "Run App", o desde la terminal):
  ```r
  shiny::runApp("app.R")
  ```
- Como los tres CSV son tus datos reales, si quieres probar algo "peligroso" (borrar registros, restaurar un archivo), hazte una copia primero:
  ```r
  file.copy("gym_data_fran.csv", "gym_data_fran_backup.csv")
  ```
