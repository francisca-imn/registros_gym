library(shiny)
library(shinythemes)
library(ggplot2)
library(dplyr)
library(lubridate)
library(plotly)

# --- CONFIGURACIÓN DE LISTADOS (Basado en tus fotos) ---
clases_mindfit <- c("Functional Training", "Indoor Cycling", "Full Core", "Body Stronger", "Cardio HIIT")

rutina_superior <- c("Band Pull Apart", "Band Rear Delt", "Band Front Raise", "Plank", 
                     "Face Pull", "Chest Press (Bench)", "Machine Incline Press", 
                     "Low Row", "Pulldown", "Trote/Run", "Vario (Elíptica)")

rutina_inferior <- c("Calf Machine (Pantorrilla)", "Abductor/Adductor Machine", "Multipower Squat (Sentadilla)", 
                     "Horizontal Leg Press", "Machine Hip Thrust", "Seated Hamstring Curl", 
                     "Leg Extension", "Mobility 90-90", "Ankle Dorsiflexion", "Deadlift (Peso Muerto)", 
                     "Trote/Run", "Vario (Elíptica)")

# Archivo de persistencia local
DATA_FILE <- "gym_data_fran.csv"

# --- INTERFAZ DE USUARIO ---
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background-color: #FAFAFA; color: #4A4A4A; font-family: 'Inter', sans-serif; }
      .well { background-color: #FFFFFF; border: 1px solid #EFEFEF; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }
      .btn-primary { background-color: #F3C6D1; border-color: #F3C6D1; color: #4A4A4A; border-radius: 8px; font-weight: 500; }
      .btn-primary:hover { background-color: #E8A8B8; border-color: #E8A8B8; color: #4A4A4A; }
      .btn-danger { background-color: #EFA7A7; border-color: #EFA7A7; color: #4A4A4A; border-radius: 8px; font-weight: 500; }
      .btn-danger:hover { background-color: #DE8F8F; border-color: #DE8F8F; color: #FFFFFF; }
      h1, h2, h3 { color: #D88396; font-weight: 600; letter-spacing: -0.5px; }
      .nav-tabs > li > a { color: #8A8A8A; font-weight: 500; border: none !important; }
      .nav-tabs > li.active > a { background-color: transparent !important; color: #D88396 !important; border-bottom: 2px solid #D88396 !important; }
      .exercise-box { background-color: #FFFDFE; border: 1px solid #FAD6DF; padding: 15px; margin-bottom: 12px; border-radius: 8px; }
      .delete-box { background-color: #FFF9F9; border: 1px solid #FAD6D6; padding: 15px; margin-top: 20px; border-radius: 12px; }
      .serie-row { margin-bottom: 5px; }
    "))
  ),
  
  titlePanel(div("✨ Registros Gym - Fran M.", style = "text-align: center; margin-top: 20px; margin-bottom: 30px; font-weight: 400;")),
  
  sidebarLayout(
    sidebarPanel(
      passwordInput("pass", "🔑 Clave de acceso:", placeholder = "Introduce tu clave..."),
      hr(),
      
      h3("Registrar Hoy ✨"),
      dateInput("fecha", "Fecha:", value = Sys.Date(), language = "es"),
      
      selectInput("lugar", "Lugar:", choices = c("MindFit La Florida", "CrossFit Box (Futuro)", "Otro/Casa")),
      
      selectizeInput("tipo", "Tipo de actividad (puedes elegir varias):", 
                     choices = c("Clase Dirigida", "Rutina Tren Superior", "Rutina Tren Inferior", "Solo Cardio"),
                     multiple = TRUE, options = list(placeholder = 'Selecciona tus actividades...')),
      
      uiOutput("opciones_dinamicas"),
      uiOutput("series_pesos_dinamicos"),
      
      br(),
      textAreaInput("comentario", "Notas adicionales:", placeholder = "Ej: Fui con mi outfit favorito, me sentí súper fuerte..."),
      
      uiOutput("ui_boton_guardar"),
      
      # NUEVA SECCIÓN: PANEL DE ELIMINACIÓN
      uiOutput("ui_panel_borrar")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("📊 Resumen Semanal", 
                 br(),
                 plotlyOutput("grafico_semanal"),
                 br(),
                 h4("Detalle de la semana:"),
                 tableOutput("tabla_semana")),
        
        tabPanel("📅 Vista Mensual", 
                 br(),
                 plotlyOutput("grafico_mensual")),
        
        tabPanel("📋 Historial & Copia de Seguridad", 
                 br(),
                 p("💡 Sincronización automática activada. Usa estos botones como respaldo extra en la nube."),
                 downloadButton("descargar_data", "Exportar Todo a CSV", class = "btn-default"),
                 hr(),
                 fileInput("subir_data", "Restaurar / Reemplazar desde CSV", accept = ".csv"),
                 br(),
                 h4("Historial Completo:"),
                 tableOutput("historial_completo"))
      )
    )
  )
)

# --- LÓGICA DEL SERVIDOR ---
server <- function(input, output, session) {
  
  # Cargar datos iniciales automáticamente si el archivo existe
  obtener_datos_iniciales <- function() {
    if (file.exists(DATA_FILE)) {
      tryCatch({
        df <- read.csv(DATA_FILE, stringsAsFactors = FALSE)
        df$Fecha <- as.Date(df$Fecha)
        return(df)
      }, error = function(e) {
        return(data.frame(Fecha = as.Date(character()), Lugar = character(), Actividades = character(), Detalles = character(), Notas = character(), Carga = numeric(), stringsAsFactors = FALSE))
      })
    } else {
      return(data.frame(Fecha = as.Date(character()), Lugar = character(), Actividades = character(), Detalles = character(), Notas = character(), Carga = numeric(), stringsAsFactors = FALSE))
    }
  }
  
  v <- reactiveValues(data = obtener_datos_iniciales())
  
  # Carga manual de archivo
  observeEvent(input$subir_data, {
    req(input$subir_data)
    df <- read.csv(input$subir_data$datapath, stringsAsFactors = FALSE)
    df$Fecha <- as.Date(df$Fecha)
    v$data <- df
    write.csv(v$data, DATA_FILE, row.names = FALSE)
    showNotification("Historial restaurado y guardado permanentemente 🌸", type = "message")
  })
  
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
          class = "serie-row",
          column(2, div(p(paste0("S", i)), style="margin-top: 25px; font-weight: bold; color: #8A8A8A;")),
          column(5, numericInput(paste0("reps_", id_safe, "_s", i), "Reps:", value = 10, min = 1)),
          column(5, numericInput(paste0("peso_", id_safe, "_s", i), "Peso (kg):", value = 0, min = 0, step = 0.5))
        )
      })
      
      div(class = "exercise-box",
          strong(ex, style = "color: #D88396; font-size: 14px;"),
          numericInput(num_series_id, "Número de series:", value = current_series_val, min = 1, max = 10),
          hr(style = "margin-top: 10px; margin-bottom: 10px;"),
          do.call(tagList, filas_series)
      )
    })
    do.call(tagList, inputs_ejercicios)
  })
  
  # Botón Guardar Seguro
  output$ui_boton_guardar <- renderUI({
    if (input$pass == "fran123") {
      actionButton("guardar", "Guardar Entrenamiento", class = "btn-primary", width = "100%")
    } else {
      p("Por favor ingresa tu clave para registrar datos.", style="color: #BA7A8A; font-style: italic; font-size: 12px;")
    }
  })
  
  # --- PANEL DE BORRADO INTEGRADO EN LA SIDEBAR (Solo si la clave es correcta) ---
  output$ui_panel_borrar <- renderUI({
    req(input$pass == "fran123")
    req(nrow(v$data) > 0)
    
    div(class = "delete-box",
        h4("Modificar Historial 🗑️", style = "color: #C76A7E; font-size: 14px; margin-top: 0;"),
        dateInput("fecha_borrar", "1. Elige la fecha a corregir:", value = Sys.Date(), language = "es"),
        uiOutput("ui_selector_registro_borrar"),
        uiOutput("ui_boton_eliminar_accion")
    )
  })
  
  # Selector dinámico interno para elegir qué sesión borrar de ese día específico
  output$ui_selector_registro_borrar <- renderUI({
    req(input$fecha_borrar)
    registros_dia <- v$data %>% filter(Fecha == input$fecha_borrar)
    
    if(nrow(registros_dia) == 0) {
      return(p("No hay registros en esta fecha.", style = "font-size: 12px; color: #9A9A9A; font-style: italic;"))
    }
    
    opciones <- setNames(1:nrow(registros_dia), paste0(registros_dia$Lugar, " -> ", registros_dia$Actividades))
    selectInput("indice_borrar", "2. Selecciona la sesión:", choices = opciones)
  })
  
  output$ui_boton_eliminar_accion <- renderUI({
    req(input$fecha_borrar)
    registros_dia <- v$data %>% filter(Fecha == input$fecha_borrar)
    req(nrow(registros_dia) > 0)
    
    actionButton("eliminar_btn", "Eliminar Registro Seleccionado", class = "btn-danger", width = "100%")
  })
  
  # --- ACCIÓN DE ELIMINAR Y ACTUALIZAR EXCEL ---
  observeEvent(input$eliminar_btn, {
    req(input$fecha_borrar, input$indice_borrar)
    
    # Separamos las filas que no corresponden al día
    data_otros_dias <- v$data %>% filter(Fecha != input$fecha_borrar)
    # Tomamos las del día que estamos editando
    data_este_dia <- v$data %>% filter(Fecha == input$fecha_borrar)
    
    idx <- as.numeric(input$indice_borrar)
    
    if(idx <= nrow(data_este_dia)) {
      # Removemos la fila seleccionada de ese subconjunto
      data_este_dia <- data_este_dia[-idx, ]
      # Volvemos a unir todo el dataframe histórico limpio
      v$data <- rbind(data_otros_dias, data_este_dia)
      
      # GUARDADO AUTOMÁTICO ACTUALIZADO EN EL EXCEL (.CSV)
      write.csv(v$data, DATA_FILE, row.names = FALSE)
      
      showNotification("Registro eliminado del historial y del Excel. 📑", type = "warning")
    }
  })
  
  # Acción de Guardar Nuevo
  observeEvent(input$guardar, {
    req(input$tipo)
    detalles_lista <- c()
    tooltip_lista <- c()
    
    if ("Clase Dirigida" %in% input$tipo && !is.null(input$clase_sel)) {
      detalles_lista <- c(detalles_lista, paste0("Clase: ", input$clase_sel))
      tooltip_lista <- c(tooltip_lista, paste0("• Clase: ", input$clase_sel))
    }
    
    procesar_ejercicios <- function(lista_ejercicios) {
      if (is.null(lista_ejercicios)) return(list(texto="", html=""))
      txt_list <- c()
      html_list <- c()
      for(ex in lista_ejercicios) {
        id_safe <- gsub("[^[:alnum:]]", "_", ex)
        num_series <- input[[paste0("num_series_", id_safe)]]
        series_info <- sapply(1:num_series, function(i) {
          r <- input[[paste0("reps_", id_safe, "_s", i)]]
          w <- input[[paste0("peso_", id_safe, "_s", i)]]
          paste0(r, "x", w, "kg")
        })
        txt_list <- c(txt_list, paste0(ex, " [", paste(series_info, collapse = " | "), "]"))
        html_list <- c(html_list, paste0("  - ", ex, ": ", paste(series_info, collapse = ", ")))
      }
      return(list(texto=paste(txt_list, collapse = ", "), html=paste(html_list, collapse = "<br>")))
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
    
    if ("Solo Cardio" %in% input$tipo) {
      detalles_lista <- c(detalles_lista, "Cardio")
      tooltip_lista <- c(tooltip_lista, "• Cardio 🏃‍♀️")
    }
    
    carga_calculada <- length(input$tipo)
    
    nueva_fila <- data.frame(
      Fecha = input$fecha,
      Lugar = input$lugar,
      Actividades = paste(input$tipo, collapse = " + "),
      Detalles = paste(detalles_lista, collapse = " // "),
      Notas = paste(tooltip_lista, collapse = "<br>"),
      Carga = carga_calculada,
      stringsAsFactors = FALSE
    )
    
    v$data <- rbind(v$data, nueva_fila)
    
    # GUARDADO AUTOMÁTICO EN DISCO
    write.csv(v$data, DATA_FILE, row.names = FALSE)
    
    showNotification("¡Entrenamiento guardado automáticamente! ✨", type = "message")
    updateTextAreaInput(session, "comentario", value = "")
  })
  
  # --- GRÁFICOS INTERACTIVOS ---
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
      scale_fill_manual(values = c("MindFit La Florida" = "#F3C6D1", "CrossFit Box (Futuro)" = "#DDA7A5", "Otro/Casa" = "#E0E0E0")) +
      theme_minimal() +
      labs(title = "Volumen de Actividad de la Semana", x = "Fecha", y = "Intensidad (N° de Actividades)") +
      theme(plot.title = element_text(size = 14, face = "bold", color = "#4A4A4A"), panel.grid.major.x = element_blank())
    
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
      scale_fill_manual(values = c("MindFit La Florida" = "#F3C6D1", "CrossFit Box (Futuro)" = "#DDA7A5", "Otro/Casa" = "#E0E0E0")) +
      theme_minimal() +
      labs(title = "Volumen Consolidado Mensual", x = "Mes", y = "Volumen Acumulado")
    
    ggplotly(g, tooltip = "text")
  })
  
  output$tabla_semana <- renderTable({
    req(nrow(v$data) > 0)
    v$data %>% 
      filter(Fecha >= (Sys.Date() - 7)) %>%
      select(Fecha, Lugar, Actividades, Detalles) %>%
      arrange(desc(Fecha)) %>%
      mutate(Fecha = as.character(Fecha))
  })
  
  output$historial_completo <- renderTable({
    req(nrow(v$data) > 0)
    v$data %>% 
      select(Fecha, Lugar, Actividades, Detalles) %>% 
      arrange(desc(Fecha)) %>% 
      mutate(Fecha = as.character(Fecha))
  })
  
  output$descargar_data <- downloadHandler(
    filename = function() { paste("Gym_Backup_Fran_", Sys.Date(), ".csv", sep="") },
    content = function(file) { write.csv(v$data, file, row.names = FALSE) }
  )
}

shinyApp(ui, server)