# ✨ Registros Gym — Fran M.

> ### 🚀 **¡Prueba la aplicación en vivo aquí!**
> ### 🔗 [fnf7b4-francisca0imn.shinyapps.io/registros_gym/](https://fnf7b4-francisca0imn.shinyapps.io/registros_gym/)
> _Nota: Recuerda ingresar tu clave de acceso en la barra lateral para registrar o modificar datos._

---

Una aplicación web interactiva diseñada en **R Shiny** para llevar un control estético, preciso y minimalista del progreso diario en el gimnasio (*Clean Girl Aesthetic*). 

Este panel centraliza el registro de clases dirigidas, rutinas específicas con desglose serie por serie y visualizaciones dinámicas de volumen de entrenamiento.

---

## 🌸 Características Principales

* **Doble Enfoque de Actividades:** Permite registrar clases grupales (MindFit) y rutinas musculares en una sola sesión diaria.
* **Seguimiento Detallado por Series:** Al registrar entrenamientos de tren superior o inferior, se desplegan campos dinámicos para anotar las **repeticiones** y el **peso específico** de cada serie de forma independiente.
* **Gráficos Interactivos Proporcionales (Plotly):** Las barras semanales y mensuales escalan según el volumen real de esfuerzo (a más actividades acumuladas en el día, más alta la barra). Al pasar el mouse, un cuadro flotante (*tooltip*) muestra de manera estructurada las marcas del día.
* **Persistencia de Datos Local Automática:** Cada entrenamiento guardado se escribe de inmediato en un archivo estructurado `gym_data_fran.csv`, permitiendo cerrar la aplicación sin perder el progreso.
* **Panel de Modificaciones Seguro (🗑️):** Incluye un módulo protegido por clave para eliminar o corregir registros específicos directamente desde la interfaz.

---

## 🚀 Cómo Ejecutar la Aplicación Localmente

### 1. Prerrequisitos
Asegúrate de tener instalado [R](https://www.r-project.org/) y [RStudio](https://posit.co/download/rstudio-desktop/). Luego, instala las librerías necesarias ejecutando en la consola de R:

```r
install.packages(c("shiny", "shinythemes", "ggplot2", "dplyr", "lubridate", "plotly"))