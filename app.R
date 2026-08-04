library(shiny)
library(bslib)
library(ggplot2)
library(dplyr)
library(lubridate)
library(plotly)

# =========================================================================
# CONFIGURACIÓN GENERAL
# =========================================================================

# Clave de acceso: se puede sobreescribir con la variable de entorno
# GYM_APP_PASS (por ejemplo en shinyapps.io > Settings > Environment Variables)
# para no dejarla fija en el código fuente.
PASS <- Sys.getenv("GYM_APP_PASS", unset = "fran123")

# --- Listados de rutinas (gimnasio) ---
clases_mindfit <- c("Functional Training", "Indoor Cycling", "Full Core", "Body Stronger", "Cardio HIIT")

rutina_superior <- c("Band Pull Apart", "Band Rear Delt", "Band Front Raise", "Plank",
                     "Face Pull", "Chest Press (Bench)", "Machine Incline Press",
                     "Low Row", "Pulldown", "Trote/Run", "Vario (Elíptica)")

rutina_inferior <- c("Calf Machine (Pantorrilla)", "Abductor/Adductor Machine", "Multipower Squat (Sentadilla)",
                     "Horizontal Leg Press", "Machine Hip Thrust", "Seated Hamstring Curl",
                     "Leg Extension", "Mobility 90-90", "Ankle Dorsiflexion", "Deadlift (Peso Muerto)",
                     "Trote/Run", "Vario (Elíptica)")

tipos_actividad <- c("Clase Dirigida", "Rutina Tren Superior", "Rutina Tren Inferior",
                     "Running/Trote", "Crossfit", "Hyrox", "Tenis", "Escalada",
                     "Solo Cardio", "Otro")

tipos_sesion_running <- c("Rodaje suave", "Tempo", "Series/Intervalos", "Fartlek", "Rodaje largo", "Carrera oficial")

lugares_disponibles <- c("MindFit La Florida", "Box CrossFit/Hyrox", "Cancha de Tenis",
                         "Muro de Escalada", "Ruta/Calle (running)", "Otro/Casa")

# Paleta categórica (validada: contraste, banda de luminosidad y separación
# por daltonismo — ver referencia en CODIGO_EXPLICADO.md)
colores_lugares <- c(
  "MindFit La Florida" = "#2A78D6",   # azul
  "Box CrossFit/Hyrox" = "#EB6834",   # naranjo
  "Cancha de Tenis" = "#1BAF7A",      # aqua
  "Muro de Escalada" = "#EDA100",     # amarillo
  "Ruta/Calle (running)" = "#E87BA4", # magenta
  "Otro/Casa" = "#008300"             # verde
)
PALETA_CATEGORICA <- unname(colores_lugares)

# Colores de marca (deben calzar con los de bs_theme() más abajo)
COL_PRIMARY <- "#4F46E5"
COL_TEXT <- "#0F172A"
COL_TEXT_MUTED <- "#64748B"

ALTURA_M <- 1.64  # estatura de referencia, usada solo para el IMC informativo

# --- Archivos de persistencia local (CSV) ---
DATA_FILE <- "gym_data_fran.csv"
RACES_FILE <- "carreras_fran.csv"
BODY_FILE <- "cuerpo_fran.csv"

# =========================================================================
# FUNCIONES AUXILIARES (tiempos y ritmos)
# =========================================================================

# Convierte "hh:mm:ss" o "mm:ss" a segundos. Devuelve NA si no es válido.
parse_tiempo <- function(t) {
  if (is.null(t) || !nzchar(trimws(t))) return(NA_real_)
  partes <- suppressWarnings(as.numeric(strsplit(trimws(t), ":")[[1]]))
  if (any(is.na(partes))) return(NA_real_)
  if (length(partes) == 3) return(partes[1] * 3600 + partes[2] * 60 + partes[3])
  if (length(partes) == 2) return(partes[1] * 60 + partes[2])
  NA_real_
}

# Convierte segundos a un texto "h:mm:ss" o "m:ss"
formatear_segundos <- function(seg) {
  if (is.na(seg)) return(NA_character_)
  seg <- round(seg)
  h <- seg %/% 3600
  m <- (seg %% 3600) %/% 60
  s <- seg %% 60
  if (h > 0) sprintf("%d:%02d:%02d", h, m, s) else sprintf("%d:%02d", m, s)
}

# Ritmo en min/km a partir del tiempo (seg) y la distancia (km)
calcular_ritmo <- function(tiempo_seg, distancia_km) {
  if (is.na(tiempo_seg) || is.na(distancia_km) || distancia_km <= 0) return(NA_character_)
  formatear_segundos(tiempo_seg / distancia_km)
}

# Convierte un ritmo "m:ss" a minutos decimales, para graficar
ritmo_a_minutos <- function(ritmo_str) {
  if (is.na(ritmo_str) || !nzchar(ritmo_str)) return(NA_real_)
  partes <- suppressWarnings(as.numeric(strsplit(ritmo_str, ":")[[1]]))
  if (any(is.na(partes)) || length(partes) != 2) return(NA_real_)
  partes[1] + partes[2] / 60
}

# =========================================================================
# TEMA (bslib / Bootstrap 5)
# =========================================================================
tema_app <- bs_theme(
  version = 5,
  bg = "#F7F8FA",
  fg = COL_TEXT,
  primary = COL_PRIMARY,
  secondary = COL_TEXT_MUTED,
  success = "#059669",
  danger = "#DC2626",
  warning = "#D97706",
  info = "#0EA5E9",
  base_font = font_google("Inter"),
  heading_font = font_google("Inter", wght = 650),
  "body-color" = COL_TEXT,
  "border-radius" = "0.6rem",
  "border-radius-sm" = "0.45rem",
  "border-radius-lg" = "0.85rem"
) |>
  bs_add_rules("
    body { letter-spacing: -0.01em; }
    .navbar-brand { font-weight: 700; letter-spacing: -0.02em; }
    .card { box-shadow: 0 1px 2px rgba(15,23,42,.04), 0 1px 8px rgba(15,23,42,.05); border-color: #E5E7EB; }
    .card-header { background-color: #FFFFFF; font-weight: 600; font-size: .92rem; border-bottom: 1px solid #EEF0F3; }
    .bslib-sidebar-layout > .sidebar { background-color: #FFFFFF; border-right: 1px solid #E5E7EB; }
    label, .control-label { font-weight: 600; font-size: .78rem; color: #475569; text-transform: uppercase; letter-spacing: .02em; }
    .form-control:focus, .form-select:focus { border-color: var(--bs-primary); box-shadow: 0 0 0 .2rem rgba(79,70,229,.12); }
    .btn { font-weight: 600; }
    .irs-bar, .irs-bar-edge, .irs-single, .irs-from, .irs-to { background: var(--bs-primary) !important; border-color: var(--bs-primary) !important; }
    .irs-single:before, .irs-from:before, .irs-to:before { border-top-color: var(--bs-primary) !important; }
    .selectize-dropdown-content .option.active, .selectize-dropdown-content .option:hover { background: #EEF0FF !important; }
    .selectize-input > div { background: #EEF0FF !important; color: var(--bs-primary) !important; border-radius: .3rem; font-weight: 600; }
    .activity-block { border-left: 3px solid var(--bs-primary); background: #FAFAFC; border-radius: .45rem; padding: 14px 16px; margin-bottom: 12px; }
    .activity-block .block-title { font-weight: 700; color: var(--bs-primary); font-size: .85rem; text-transform: none; letter-spacing: 0; }
    .danger-block { border-left: 3px solid var(--bs-danger); background: #FEF2F2; border-radius: .45rem; padding: 14px 16px; margin-top: 16px; }
    table.table th { font-size: .74rem; text-transform: uppercase; letter-spacing: .03em; color: #64748B; border-bottom-width: 2px; }
    table.table td { font-size: .87rem; vertical-align: middle; }
    .markdown-plan h1, .markdown-plan h2, .markdown-plan h3 { color: var(--bs-primary); font-weight: 700; }
    .markdown-plan table { width: 100%; border-collapse: collapse; margin-bottom: 1.25rem; }
    .markdown-plan th, .markdown-plan td { border: 1px solid #E5E7EB; padding: 7px 11px; font-size: .87rem; text-align: left; }
    .markdown-plan th { background: #F5F5FF; color: var(--bs-primary); }
    .markdown-plan blockquote { border-left: 3px solid var(--bs-primary); padding-left: 14px; color: #475569; margin-left: 0; }
  ")

# =========================================================================
# INTERFAZ DE USUARIO
# =========================================================================
ui <- page_navbar(
  title = "Registros Gym & Running",
  id = "nav_principal",
  theme = tema_app,
  fillable = TRUE,
  sidebar = sidebar(
    width = 360,
    passwordInput("pass", "Clave de acceso", placeholder = "••••••••"),
    hr(),
    tags$p(class = "text-uppercase fw-bold small text-secondary mb-2", "Registrar hoy"),
    dateInput("fecha", "Fecha", value = Sys.Date(), language = "es"),
    selectInput("lugar", "Lugar", choices = lugares_disponibles),
    selectizeInput("tipo", "Tipo de actividad",
                   choices = tipos_actividad,
                   multiple = TRUE, options = list(placeholder = "Selecciona tus actividades...")),
    uiOutput("opciones_dinamicas"),
    uiOutput("series_pesos_dinamicos"),
    textAreaInput("comentario", "Notas adicionales", placeholder = "Ej: Fui con mi outfit favorito, me sentí súper fuerte..."),
    uiOutput("ui_boton_guardar"),
    uiOutput("ui_panel_borrar")
  ),

  nav_panel(
    "Resumen semanal",
    card(full_screen = TRUE,
         card_header("Volumen de actividad — últimos 7 días"),
         plotlyOutput("grafico_semanal", height = "380px")),
    card(card_header("Detalle de la semana"), tableOutput("tabla_semana"))
  ),

  nav_panel(
    "Vista mensual",
    card(full_screen = TRUE,
         card_header("Volumen consolidado mensual"),
         plotlyOutput("grafico_mensual", height = "440px"))
  ),

  nav_panel(
    "Carreras & metas",
    uiOutput("countdown_carreras"),
    layout_columns(
      col_widths = c(4, 8),
      card(card_header("Registrar carrera o meta"), uiOutput("ui_form_carrera")),
      card(full_screen = TRUE, card_header("Evolución de tu ritmo"), plotlyOutput("grafico_carreras", height = "340px"))
    ),
    card(card_header("Historial de carreras y metas"), tableOutput("tabla_carreras"), uiOutput("ui_panel_borrar_carrera"))
  ),

  nav_panel(
    "Progreso físico",
    uiOutput("resumen_cuerpo"),
    layout_columns(
      col_widths = c(4, 8),
      card(card_header("Registrar peso / talla"), uiOutput("ui_form_cuerpo")),
      card(full_screen = TRUE, card_header("Evolución de tu peso"), plotlyOutput("grafico_peso", height = "340px"))
    ),
    card(card_header("Historial"), tableOutput("tabla_cuerpo"), uiOutput("ui_panel_borrar_cuerpo"))
  ),

  nav_panel(
    "Plan 21K",
    card(class = "markdown-plan p-2", includeMarkdown("PLAN_ENTRENAMIENTO_21K.md"))
  ),

  nav_panel(
    "Plan alimentación",
    card(class = "markdown-plan p-2", includeMarkdown("PLAN_ALIMENTACION.md"))
  ),

  nav_panel(
    "Historial & respaldo",
    card(class = "border-warning-subtle bg-warning-subtle mb-1",
         card_body(class = "py-2",
                    tags$strong("Importante: "),
                    "si usas la app desplegada en shinyapps.io (plan gratuito), el disco no está 100% garantizado entre reinicios o nuevos despliegues. Descarga respaldos seguido, o usa la app localmente en RStudio para tu registro diario.")),
    layout_columns(
      col_widths = c(4, 4, 4),
      card(card_header("Entrenamientos"),
           downloadButton("descargar_data", "Exportar CSV", class = "btn-outline-primary w-100 mb-3"),
           fileInput("subir_data", "Restaurar desde CSV", accept = ".csv")),
      card(card_header("Carreras y metas"),
           downloadButton("descargar_carreras", "Exportar CSV", class = "btn-outline-primary w-100 mb-3"),
           fileInput("subir_carreras", "Restaurar desde CSV", accept = ".csv")),
      card(card_header("Progreso físico"),
           downloadButton("descargar_cuerpo", "Exportar CSV", class = "btn-outline-primary w-100 mb-3"),
           fileInput("subir_cuerpo", "Restaurar desde CSV", accept = ".csv"))
    ),
    card(card_header("Historial completo de entrenamientos"), tableOutput("historial_completo"))
  )
)

# =========================================================================
# LÓGICA DEL SERVIDOR
# =========================================================================
server <- function(input, output, session) {

  # -----------------------------------------------------------------------
  # Carga inicial de datos desde CSV (persistencia local)
  # -----------------------------------------------------------------------
  obtener_datos_iniciales <- function() {
    vacio <- data.frame(Fecha = as.Date(character()), Lugar = character(), Actividades = character(),
                         Detalles = character(), Notas = character(), Carga = numeric(),
                         RPE_Prom = numeric(), stringsAsFactors = FALSE)
    if (!file.exists(DATA_FILE)) return(vacio)
    tryCatch({
      df <- read.csv(DATA_FILE, stringsAsFactors = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      if (!"RPE_Prom" %in% names(df)) df$RPE_Prom <- NA_real_
      df
    }, error = function(e) vacio)
  }

  obtener_carreras_iniciales <- function() {
    vacio <- data.frame(Fecha = as.Date(character()), Nombre = character(), Distancia_km = numeric(),
                         Tiempo = character(), Ritmo_min_km = character(), Tipo = character(),
                         Notas = character(), stringsAsFactors = FALSE)
    if (!file.exists(RACES_FILE)) return(vacio)
    tryCatch({
      df <- read.csv(RACES_FILE, stringsAsFactors = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      df
    }, error = function(e) vacio)
  }

  obtener_cuerpo_inicial <- function() {
    vacio <- data.frame(Fecha = as.Date(character()), Peso_kg = numeric(), Talla_Pantalon = numeric(),
                         Notas = character(), stringsAsFactors = FALSE)
    if (!file.exists(BODY_FILE)) return(vacio)
    tryCatch({
      df <- read.csv(BODY_FILE, stringsAsFactors = FALSE)
      df$Fecha <- as.Date(df$Fecha)
      df
    }, error = function(e) vacio)
  }

  v <- reactiveValues(data = obtener_datos_iniciales())
  r <- reactiveValues(carreras = obtener_carreras_iniciales())
  b <- reactiveValues(data = obtener_cuerpo_inicial())

  # -----------------------------------------------------------------------
  # Restaurar desde CSV subido manualmente
  # -----------------------------------------------------------------------
  observeEvent(input$subir_data, {
    req(input$subir_data)
    df <- read.csv(input$subir_data$datapath, stringsAsFactors = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    if (!"RPE_Prom" %in% names(df)) df$RPE_Prom <- NA_real_
    v$data <- df
    write.csv(v$data, DATA_FILE, row.names = FALSE)
    showNotification("Historial de entrenamientos restaurado y guardado permanentemente", type = "message")
  })

  observeEvent(input$subir_carreras, {
    req(input$subir_carreras)
    df <- read.csv(input$subir_carreras$datapath, stringsAsFactors = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    r$carreras <- df
    write.csv(r$carreras, RACES_FILE, row.names = FALSE)
    showNotification("Historial de carreras restaurado y guardado permanentemente", type = "message")
  })

  observeEvent(input$subir_cuerpo, {
    req(input$subir_cuerpo)
    df <- read.csv(input$subir_cuerpo$datapath, stringsAsFactors = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    b$data <- df
    write.csv(b$data, BODY_FILE, row.names = FALSE)
    showNotification("Progreso físico restaurado y guardado permanentemente", type = "message")
  })

  # =======================================================================
  # ENTRENAMIENTO DIARIO
  # =======================================================================

  output$opciones_dinamicas <- renderUI({
    req(input$tipo)
    ui_elements <- list()

    if ("Clase Dirigida" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(selectInput("clase_sel", "Clase MindFit realizada:", choices = clases_mindfit)))
    }
    if ("Rutina Tren Superior" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(checkboxGroupInput("sup_sel", "Marcar ejercicios de Tren Superior hechos:", choices = rutina_superior)))
    }
    if ("Rutina Tren Inferior" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(checkboxGroupInput("inf_sel", "Marcar ejercicios de Tren Inferior hechos:", choices = rutina_inferior)))
    }
    if ("Running/Trote" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Detalles del running"),
            selectInput("run_tipo_sesion", "Tipo de sesión:", choices = tipos_sesion_running),
            numericInput("run_distancia", "Distancia (km):", value = 5, min = 0, step = 0.1),
            textInput("run_tiempo", "Tiempo (hh:mm:ss o mm:ss):", placeholder = "ej: 45:30"),
            sliderInput("run_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 6),
            textAreaInput("run_notas", "Sensaciones / molestias digestivas:", placeholder = "Ej: piernas pesadas, buen ritmo...")
        )
      ))
    }
    if ("Crossfit" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Detalles del crossfit"),
            textInput("cf_wod", "WOD / ejercicios principales:", placeholder = "Ej: Fran, 21-15-9 thrusters/pull-ups..."),
            numericInput("cf_duracion", "Duración (min):", value = 45, min = 0),
            sliderInput("cf_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 7)
        )
      ))
    }
    if ("Hyrox" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Detalles del hyrox"),
            textInput("hx_estaciones", "Estaciones trabajadas:", placeholder = "Ej: SkiErg, Sled Push, Burpee Broad Jump..."),
            numericInput("hx_duracion", "Duración (min):", value = 45, min = 0),
            sliderInput("hx_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 7)
        )
      ))
    }
    if ("Tenis" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Detalles del tenis"),
            selectInput("tenis_modalidad", "Modalidad:", choices = c("Individual", "Dobles", "Clase/Entrenamiento")),
            numericInput("tenis_duracion", "Duración (min):", value = 60, min = 0),
            sliderInput("tenis_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 5)
        )
      ))
    }
    if ("Escalada" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Detalles de escalada"),
            selectInput("esc_tipo", "Tipo:", choices = c("Boulder", "Vía/Cuerda", "Muro velocidad")),
            textInput("esc_nivel", "Nivel/grado máximo:", placeholder = "Ej: V3, 6a..."),
            numericInput("esc_duracion", "Duración (min):", value = 60, min = 0),
            sliderInput("esc_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 6)
        )
      ))
    }
    if ("Otro" %in% input$tipo) {
      ui_elements <- c(ui_elements, list(
        div(class = "activity-block",
            div(class = "block-title", "Otra actividad"),
            textInput("otro_desc", "Descripción:", placeholder = "Ej: Pilates, natación..."),
            numericInput("otro_duracion", "Duración (min):", value = 30, min = 0),
            sliderInput("otro_rpe", "Esfuerzo percibido (RPE 1-10):", min = 1, max = 10, value = 5)
        )
      ))
    }
    do.call(tagList, ui_elements)
  })

  output$series_pesos_dinamicos <- renderUI({
    ejercicios_seleccionados <- c()
    if ("Rutina Tren Superior" %in% input$tipo) ejercicios_seleccionados <- c(ejercicios_seleccionados, input$sup_sel)
    if ("Rutina Tren Inferior" %in% input$tipo) ejercicios_seleccionados <- c(ejercicios_seleccionados, input$inf_sel)

    req(length(ejercicios_seleccionados) > 0)

    inputs_ejercicios <- lapply(ejercicios_seleccionados, function(ex) {
      id_safe <- gsub("[^[:alnum:]]", "_", ex)
      num_series_id <- paste0("num_series_", id_safe)
      current_series_val <- if (!is.null(input[[num_series_id]])) input[[num_series_id]] else 4

      filas_series <- lapply(1:current_series_val, function(i) {
        fluidRow(
          column(2, div(p(paste0("S", i)), class = "text-secondary fw-bold", style = "margin-top: 25px;")),
          column(5, numericInput(paste0("reps_", id_safe, "_s", i), "Reps:", value = 10, min = 1)),
          column(5, numericInput(paste0("peso_", id_safe, "_s", i), "Peso (kg):", value = 0, min = 0, step = 0.5))
        )
      })

      div(class = "activity-block",
          div(class = "block-title", ex),
          numericInput(num_series_id, "Número de series:", value = current_series_val, min = 1, max = 10),
          hr(),
          do.call(tagList, filas_series)
      )
    })
    do.call(tagList, inputs_ejercicios)
  })

  output$ui_boton_guardar <- renderUI({
    if (input$pass == PASS) {
      actionButton("guardar", "Guardar entrenamiento", class = "btn-primary w-100")
    } else {
      p(class = "text-secondary fst-italic small", "Ingresa tu clave para registrar datos.")
    }
  })

  output$ui_panel_borrar <- renderUI({
    req(input$pass == PASS)
    req(nrow(v$data) > 0)

    div(class = "danger-block",
        h6(class = "text-danger fw-bold", "Modificar historial"),
        dateInput("fecha_borrar", "1. Elige la fecha a corregir:", value = Sys.Date(), language = "es"),
        uiOutput("ui_selector_registro_borrar"),
        uiOutput("ui_boton_eliminar_accion")
    )
  })

  output$ui_selector_registro_borrar <- renderUI({
    req(input$fecha_borrar)
    registros_dia <- v$data %>% filter(Fecha == input$fecha_borrar)

    if (nrow(registros_dia) == 0) {
      return(p(class = "small text-secondary fst-italic", "No hay registros en esta fecha."))
    }

    opciones <- setNames(1:nrow(registros_dia), paste0(registros_dia$Lugar, " -> ", registros_dia$Actividades))
    selectInput("indice_borrar", "2. Selecciona la sesión:", choices = opciones)
  })

  output$ui_boton_eliminar_accion <- renderUI({
    req(input$fecha_borrar)
    registros_dia <- v$data %>% filter(Fecha == input$fecha_borrar)
    req(nrow(registros_dia) > 0)

    actionButton("eliminar_btn", "Eliminar registro seleccionado", class = "btn-danger w-100")
  })

  observeEvent(input$eliminar_btn, {
    req(input$fecha_borrar, input$indice_borrar)

    data_otros_dias <- v$data %>% filter(Fecha != input$fecha_borrar)
    data_este_dia <- v$data %>% filter(Fecha == input$fecha_borrar)

    idx <- as.numeric(input$indice_borrar)

    if (idx <= nrow(data_este_dia)) {
      data_este_dia <- data_este_dia[-idx, ]
      v$data <- rbind(data_otros_dias, data_este_dia)
      write.csv(v$data, DATA_FILE, row.names = FALSE)
      showNotification("Registro eliminado del historial y del CSV.", type = "warning")
    }
  })

  observeEvent(input$guardar, {
    req(input$tipo)
    detalles_lista <- c()
    tooltip_lista <- c()
    rpe_vals <- c()

    if ("Clase Dirigida" %in% input$tipo && !is.null(input$clase_sel)) {
      detalles_lista <- c(detalles_lista, paste0("Clase: ", input$clase_sel))
      tooltip_lista <- c(tooltip_lista, paste0("• Clase: ", input$clase_sel))
    }

    procesar_ejercicios <- function(lista_ejercicios) {
      if (is.null(lista_ejercicios)) return(list(texto = "", html = ""))
      txt_list <- c()
      html_list <- c()
      for (ex in lista_ejercicios) {
        id_safe <- gsub("[^[:alnum:]]", "_", ex)
        num_series <- input[[paste0("num_series_", id_safe)]]
        series_info <- sapply(1:num_series, function(i) {
          rr <- input[[paste0("reps_", id_safe, "_s", i)]]
          ww <- input[[paste0("peso_", id_safe, "_s", i)]]
          paste0(rr, "x", ww, "kg")
        })
        txt_list <- c(txt_list, paste0(ex, " [", paste(series_info, collapse = " | "), "]"))
        html_list <- c(html_list, paste0("  - ", ex, ": ", paste(series_info, collapse = ", ")))
      }
      list(texto = paste(txt_list, collapse = ", "), html = paste(html_list, collapse = "<br>"))
    }

    if ("Rutina Tren Superior" %in% input$tipo) {
      res_sup <- procesar_ejercicios(input$sup_sel)
      if (res_sup$texto != "") {
        detalles_lista <- c(detalles_lista, paste0("Superior: (", res_sup$texto, ")"))
        tooltip_lista <- c(tooltip_lista, paste0("• Tren Superior:<br>", res_sup$html))
      }
    }

    if ("Rutina Tren Inferior" %in% input$tipo) {
      res_inf <- procesar_ejercicios(input$inf_sel)
      if (res_inf$texto != "") {
        detalles_lista <- c(detalles_lista, paste0("Inferior: (", res_inf$texto, ")"))
        tooltip_lista <- c(tooltip_lista, paste0("• Tren Inferior:<br>", res_inf$html))
      }
    }

    if ("Running/Trote" %in% input$tipo) {
      tiempo_seg <- parse_tiempo(input$run_tiempo)
      ritmo <- calcular_ritmo(tiempo_seg, input$run_distancia)
      sufijo <- if (!is.na(ritmo)) paste0(" [", ritmo, " min/km]") else ""
      detalles_lista <- c(detalles_lista, paste0("Running (", input$run_tipo_sesion, "): ", input$run_distancia, "km en ", input$run_tiempo, sufijo))
      nota_extra <- if (nzchar(input$run_notas)) paste0("<br>  Notas: ", input$run_notas) else ""
      tooltip_lista <- c(tooltip_lista, paste0("• Running: ", input$run_tipo_sesion, " — ", input$run_distancia, "km en ", input$run_tiempo, sufijo, nota_extra))
      rpe_vals <- c(rpe_vals, input$run_rpe)
    }

    if ("Crossfit" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, paste0("Crossfit (", input$cf_duracion, " min): ", input$cf_wod))
      tooltip_lista <- c(tooltip_lista, paste0("• Crossfit: ", input$cf_wod, " (", input$cf_duracion, " min)"))
      rpe_vals <- c(rpe_vals, input$cf_rpe)
    }

    if ("Hyrox" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, paste0("Hyrox (", input$hx_duracion, " min): ", input$hx_estaciones))
      tooltip_lista <- c(tooltip_lista, paste0("• Hyrox: ", input$hx_estaciones, " (", input$hx_duracion, " min)"))
      rpe_vals <- c(rpe_vals, input$hx_rpe)
    }

    if ("Tenis" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, paste0("Tenis (", input$tenis_modalidad, ", ", input$tenis_duracion, " min)"))
      tooltip_lista <- c(tooltip_lista, paste0("• Tenis: ", input$tenis_modalidad, " (", input$tenis_duracion, " min)"))
      rpe_vals <- c(rpe_vals, input$tenis_rpe)
    }

    if ("Escalada" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, paste0("Escalada (", input$esc_tipo, ", nivel ", input$esc_nivel, ", ", input$esc_duracion, " min)"))
      tooltip_lista <- c(tooltip_lista, paste0("• Escalada: ", input$esc_tipo, " — nivel ", input$esc_nivel, " (", input$esc_duracion, " min)"))
      rpe_vals <- c(rpe_vals, input$esc_rpe)
    }

    if ("Otro" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, paste0("Otro (", input$otro_duracion, " min): ", input$otro_desc))
      tooltip_lista <- c(tooltip_lista, paste0("• Otro: ", input$otro_desc, " (", input$otro_duracion, " min)"))
      rpe_vals <- c(rpe_vals, input$otro_rpe)
    }

    if ("Solo Cardio" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, "Cardio")
      tooltip_lista <- c(tooltip_lista, "• Cardio")
    }

    carga_calculada <- length(input$tipo)
    rpe_prom <- if (length(rpe_vals) > 0) round(mean(rpe_vals), 1) else NA_real_

    nueva_fila <- data.frame(
      Fecha = input$fecha,
      Lugar = input$lugar,
      Actividades = paste(input$tipo, collapse = " + "),
      Detalles = paste(detalles_lista, collapse = " // "),
      Notas = paste(tooltip_lista, collapse = "<br>"),
      Carga = carga_calculada,
      RPE_Prom = rpe_prom,
      stringsAsFactors = FALSE
    )

    v$data <- rbind(v$data, nueva_fila)
    write.csv(v$data, DATA_FILE, row.names = FALSE)

    showNotification("Entrenamiento guardado.", type = "message")
    updateTextAreaInput(session, "comentario", value = "")
  })

  # --- Gráficos de entrenamiento ---
  output$grafico_semanal <- renderPlotly({
    req(nrow(v$data) > 0)
    datos_semana <- v$data %>% filter(Fecha >= (Sys.Date() - 7))
    req(nrow(datos_semana) > 0)

    g <- ggplot(datos_semana, aes(x = factor(Fecha), y = Carga, fill = Lugar,
                                  text = paste0("<b>Fecha: </b>", Fecha, "<br>",
                                                "<b>Lugar: </b>", Lugar, "<br>",
                                                "<b>Esfuerzo: </b>", Carga, " act.<br><br>",
                                                Notas))) +
      geom_bar(width = 0.4, stat = "identity") +
      scale_fill_manual(values = colores_lugares) +
      theme_minimal(base_family = "") +
      labs(title = NULL, x = "Fecha", y = "Intensidad (N° de actividades)") +
      theme(panel.grid.major.x = element_blank(), text = element_text(color = COL_TEXT))

    ggplotly(g, tooltip = "text")
  })

  output$grafico_mensual <- renderPlotly({
    req(nrow(v$data) > 0)
    datos_mes <- v$data %>%
      mutate(Mes = format(Fecha, "%b %Y")) %>%
      group_by(Mes, Lugar) %>%
      summarise(TotalCarga = sum(Carga), .groups = 'drop')

    g <- ggplot(datos_mes, aes(x = Mes, y = TotalCarga, fill = Lugar, text = paste("Mes:", Mes, "<br>Volumen Total:", TotalCarga))) +
      geom_bar(width = 0.5, stat = "identity") +
      scale_fill_manual(values = colores_lugares) +
      theme_minimal(base_family = "") +
      labs(title = NULL, x = "Mes", y = "Volumen acumulado") +
      theme(text = element_text(color = COL_TEXT))

    ggplotly(g, tooltip = "text")
  })

  output$tabla_semana <- renderTable({
    req(nrow(v$data) > 0)
    v$data %>%
      filter(Fecha >= (Sys.Date() - 7)) %>%
      select(Fecha, Lugar, Actividades, Detalles, RPE_Prom) %>%
      arrange(desc(Fecha)) %>%
      mutate(Fecha = as.character(Fecha))
  })

  output$historial_completo <- renderTable({
    req(nrow(v$data) > 0)
    v$data %>%
      select(Fecha, Lugar, Actividades, Detalles, RPE_Prom) %>%
      arrange(desc(Fecha)) %>%
      mutate(Fecha = as.character(Fecha))
  })

  output$descargar_data <- downloadHandler(
    filename = function() paste("Gym_Backup_Fran_", Sys.Date(), ".csv", sep = ""),
    content = function(file) write.csv(v$data, file, row.names = FALSE)
  )

  # =======================================================================
  # CARRERAS Y METAS
  # =======================================================================

  output$countdown_carreras <- renderUI({
    req(nrow(r$carreras) > 0)
    objetivos <- r$carreras %>% filter(Tipo == "Objetivo", Fecha >= Sys.Date()) %>% arrange(Fecha)
    if (nrow(objetivos) == 0) return(p(class = "text-secondary fst-italic", "No hay metas futuras registradas."))

    cajas <- lapply(seq_len(nrow(objetivos)), function(i) {
      dias <- as.numeric(objetivos$Fecha[i] - Sys.Date())
      value_box(
        title = objetivos$Nombre[i],
        value = paste0(dias, " días"),
        p(paste0(objetivos$Distancia_km[i], " km — ", format(objetivos$Fecha[i], "%d %b %Y"))),
        theme = "text-primary",
        showcase = NULL
      )
    })
    do.call(layout_column_wrap, c(list(width = "220px", fill = FALSE), cajas))
  })

  output$ui_form_carrera <- renderUI({
    if (input$pass != PASS) {
      return(p(class = "text-secondary fst-italic small", "Ingresa tu clave en la barra lateral para registrar carreras y metas."))
    }
    tagList(
        textInput("carrera_nombre", "Nombre de la carrera:", placeholder = "Ej: 10K Parque..."),
        dateInput("carrera_fecha", "Fecha:", value = Sys.Date(), language = "es"),
        numericInput("carrera_distancia", "Distancia (km):", value = 10, min = 1, step = 0.1),
        selectInput("carrera_tipo", "Tipo de registro:",
                    choices = c("Resultado (ya corrida)" = "Resultado", "Objetivo (futura)" = "Objetivo")),
        textInput("carrera_tiempo", "Tiempo (hh:mm:ss) — vacío si es una meta futura:", placeholder = "ej: 1:10:00"),
        textAreaInput("carrera_notas", "Notas:", placeholder = "Sensaciones, clima, meta de ritmo..."),
        actionButton("guardar_carrera", "Guardar carrera / meta", class = "btn-primary w-100")
    )
  })

  observeEvent(input$guardar_carrera, {
    req(input$pass == PASS, input$carrera_nombre, input$carrera_fecha)

    tiempo_seg <- parse_tiempo(input$carrera_tiempo)
    ritmo <- calcular_ritmo(tiempo_seg, input$carrera_distancia)

    nueva <- data.frame(
      Fecha = input$carrera_fecha,
      Nombre = input$carrera_nombre,
      Distancia_km = input$carrera_distancia,
      Tiempo = ifelse(nzchar(trimws(input$carrera_tiempo)), input$carrera_tiempo, ""),
      Ritmo_min_km = ifelse(is.na(ritmo), "", ritmo),
      Tipo = input$carrera_tipo,
      Notas = input$carrera_notas,
      stringsAsFactors = FALSE
    )

    r$carreras <- rbind(r$carreras, nueva) %>% arrange(Fecha)
    write.csv(r$carreras, RACES_FILE, row.names = FALSE)

    showNotification("Carrera / meta guardada.", type = "message")
    updateTextInput(session, "carrera_nombre", value = "")
    updateTextInput(session, "carrera_tiempo", value = "")
    updateTextAreaInput(session, "carrera_notas", value = "")
  })

  output$grafico_carreras <- renderPlotly({
    datos <- r$carreras %>% filter(Tipo == "Resultado", nzchar(Ritmo_min_km))
    req(nrow(datos) > 0)
    datos$RitmoDecimal <- sapply(datos$Ritmo_min_km, ritmo_a_minutos)

    g <- ggplot(datos, aes(x = Fecha, y = RitmoDecimal, color = factor(Distancia_km), group = factor(Distancia_km),
                           text = paste0("<b>", Nombre, "</b><br>Fecha: ", Fecha, "<br>Tiempo: ", Tiempo, "<br>Ritmo: ", Ritmo_min_km, " min/km"))) +
      geom_line() +
      geom_point(size = 3) +
      scale_y_reverse() +
      scale_color_manual(values = PALETA_CATEGORICA) +
      theme_minimal(base_family = "") +
      labs(title = NULL, x = "Fecha", y = "Ritmo (min/km)", color = "Distancia (km)") +
      theme(text = element_text(color = COL_TEXT))

    ggplotly(g, tooltip = "text")
  })

  output$tabla_carreras <- renderTable({
    req(nrow(r$carreras) > 0)
    r$carreras %>%
      mutate(`Días restantes` = ifelse(Tipo == "Objetivo" & Fecha >= Sys.Date(), as.character(as.numeric(Fecha - Sys.Date())), "")) %>%
      arrange(desc(Fecha)) %>%
      mutate(Fecha = as.character(Fecha))
  })

  output$ui_panel_borrar_carrera <- renderUI({
    req(input$pass == PASS, nrow(r$carreras) > 0)
    opciones <- setNames(seq_len(nrow(r$carreras)),
                         paste0(format(r$carreras$Fecha, "%d-%m-%Y"), " — ", r$carreras$Nombre, " (", r$carreras$Tipo, ")"))
    div(class = "danger-block",
        h6(class = "text-danger fw-bold", "Eliminar registro de carrera"),
        selectInput("carrera_borrar_idx", "Selecciona el registro:", choices = opciones),
        actionButton("btn_borrar_carrera", "Eliminar", class = "btn-danger w-100")
    )
  })

  observeEvent(input$btn_borrar_carrera, {
    req(input$carrera_borrar_idx)
    idx <- as.numeric(input$carrera_borrar_idx)
    r$carreras <- r$carreras[-idx, ]
    write.csv(r$carreras, RACES_FILE, row.names = FALSE)
    showNotification("Registro de carrera eliminado.", type = "warning")
  })

  output$descargar_carreras <- downloadHandler(
    filename = function() paste("Carreras_Backup_Fran_", Sys.Date(), ".csv", sep = ""),
    content = function(file) write.csv(r$carreras, file, row.names = FALSE)
  )

  # =======================================================================
  # PROGRESO FÍSICO (peso / talla)
  # =======================================================================

  output$ui_form_cuerpo <- renderUI({
    if (input$pass != PASS) {
      return(p(class = "text-secondary fst-italic small", "Ingresa tu clave en la barra lateral para registrar tu progreso físico."))
    }
    tagList(
        dateInput("cuerpo_fecha", "Fecha:", value = Sys.Date(), language = "es"),
        numericInput("cuerpo_peso", "Peso (kg):", value = 72, min = 30, step = 0.1),
        selectInput("cuerpo_talla", "Talla de pantalón:", choices = c(36, 38, 40, 42, 44, 46), selected = 42),
        textAreaInput("cuerpo_notas", "Notas:", placeholder = "Medidas, cómo te sientes, ropa que te queda mejor..."),
        actionButton("guardar_cuerpo", "Guardar registro", class = "btn-primary w-100")
    )
  })

  observeEvent(input$guardar_cuerpo, {
    req(input$pass == PASS, input$cuerpo_fecha, input$cuerpo_peso)

    nueva <- data.frame(
      Fecha = input$cuerpo_fecha,
      Peso_kg = input$cuerpo_peso,
      Talla_Pantalon = as.numeric(input$cuerpo_talla),
      Notas = input$cuerpo_notas,
      stringsAsFactors = FALSE
    )

    b$data <- rbind(b$data, nueva) %>% arrange(Fecha)
    write.csv(b$data, BODY_FILE, row.names = FALSE)

    showNotification("Registro de progreso físico guardado.", type = "message")
    updateTextAreaInput(session, "cuerpo_notas", value = "")
  })

  output$resumen_cuerpo <- renderUI({
    req(nrow(b$data) > 0)
    datos <- b$data %>% arrange(Fecha)
    ultimo <- tail(datos, 1)
    primero <- head(datos, 1)
    diferencia <- round(ultimo$Peso_kg - primero$Peso_kg, 1)
    imc <- round(ultimo$Peso_kg / (ALTURA_M^2), 1)
    signo <- if (diferencia > 0) "+" else ""

    layout_column_wrap(
      width = "260px", fill = FALSE,
      value_box(
        title = "Peso actual",
        value = paste0(ultimo$Peso_kg, " kg"),
        p(paste0("Talla ", ultimo$Talla_Pantalon, " · ", signo, diferencia, " kg desde el ", format(primero$Fecha, "%d-%m-%Y"))),
        theme = "text-primary"
      ),
      value_box(
        title = "IMC referencial",
        value = as.character(imc),
        p(class = "text-secondary", "Dato informativo — lo relevante es tu tonificación y tu talla."),
        theme = "text-secondary"
      )
    )
  })

  output$grafico_peso <- renderPlotly({
    req(nrow(b$data) > 0)
    datos <- b$data %>% arrange(Fecha)

    g <- ggplot(datos, aes(x = Fecha, y = Peso_kg,
                           text = paste0("Fecha: ", Fecha, "<br>Peso: ", Peso_kg, " kg<br>Talla: ", Talla_Pantalon))) +
      geom_line(color = COL_PRIMARY) +
      geom_point(size = 3, color = COL_PRIMARY) +
      theme_minimal(base_family = "") +
      labs(title = NULL, x = "Fecha", y = "Peso (kg)") +
      theme(text = element_text(color = COL_TEXT))

    ggplotly(g, tooltip = "text")
  })

  output$tabla_cuerpo <- renderTable({
    req(nrow(b$data) > 0)
    b$data %>% arrange(desc(Fecha)) %>% mutate(Fecha = as.character(Fecha))
  })

  output$ui_panel_borrar_cuerpo <- renderUI({
    req(input$pass == PASS, nrow(b$data) > 0)
    opciones <- setNames(seq_len(nrow(b$data)),
                         paste0(format(b$data$Fecha, "%d-%m-%Y"), " — ", b$data$Peso_kg, " kg"))
    div(class = "danger-block",
        h6(class = "text-danger fw-bold", "Eliminar registro"),
        selectInput("cuerpo_borrar_idx", "Selecciona el registro:", choices = opciones),
        actionButton("btn_borrar_cuerpo", "Eliminar", class = "btn-danger w-100")
    )
  })

  observeEvent(input$btn_borrar_cuerpo, {
    req(input$cuerpo_borrar_idx)
    idx <- as.numeric(input$cuerpo_borrar_idx)
    b$data <- b$data[-idx, ]
    write.csv(b$data, BODY_FILE, row.names = FALSE)
    showNotification("Registro eliminado.", type = "warning")
  })

  output$descargar_cuerpo <- downloadHandler(
    filename = function() paste("Cuerpo_Backup_Fran_", Sys.Date(), ".csv", sep = ""),
    content = function(file) write.csv(b$data, file, row.names = FALSE)
  )
}

shinyApp(ui, server)
