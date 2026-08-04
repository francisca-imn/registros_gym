# ✨ Registros Gym & Running — Fran M.

> ### 🚀 **¡Prueba la aplicación en vivo aquí!**
> ### 🔗 [fnf7b4-francisca0imn.shinyapps.io/registros_gym/](https://fnf7b4-francisca0imn.shinyapps.io/registros_gym/)
> _Nota: Recuerda ingresar tu clave de acceso en la barra lateral para registrar o modificar datos._

---

Aplicación web interactiva en **R Shiny**, con un diseño tipo dashboard moderno (Bootstrap 5 vía `bslib`, tipografía Inter), para llevar un control estético, preciso y completo de mi actividad física: gimnasio, running, crossfit, hyrox, tenis y escalada — además del seguimiento de mis carreras, mi progreso físico, mi plan de entrenamiento hacia los 21K y mi plan de alimentación.

Este proyecto también es mi espacio para aprender a programar aplicaciones: en [`CODIGO_EXPLICADO.md`](CODIGO_EXPLICADO.md) documento cómo funciona cada parte del código, pensado para volver a leerlo cuando quiera entender o modificar algo.

---

## 🌸 Características principales

- **Registro diario multi-deporte:** clases dirigidas, rutinas de gimnasio con series/reps/peso, running (con distancia, tiempo y cálculo automático de ritmo), crossfit, hyrox, tenis, escalada y una categoría libre ("Otro"), todo en una sola sesión diaria si corresponde.
- **🏁 Carreras & Metas:** registro de resultados de carreras (con cálculo automático de ritmo) y de metas futuras, con cuenta regresiva y gráfico de evolución del ritmo en el tiempo.
- **📈 Progreso Físico:** seguimiento de peso y talla de pantalón en el tiempo, con gráfico y resumen de cambio desde el primer registro.
- **🏃‍♀️ Plan 21K:** plan de entrenamiento de 17 semanas hacia una media maratón, editable como texto plano en [`PLAN_ENTRENAMIENTO_21K.md`](PLAN_ENTRENAMIENTO_21K.md).
- **🥗 Plan Alimentación:** guía nutricional (indicación profesional, adaptada a colitis ulcerosa en remisión) editable en [`PLAN_ALIMENTACION.md`](PLAN_ALIMENTACION.md).
- **Gráficos interactivos (Plotly):** volumen de entrenamiento semanal/mensual, evolución de ritmo en carreras y evolución de peso, todos con tooltips detallados.
- **Persistencia local automática:** cada registro se guarda de inmediato en CSV (`gym_data_fran.csv`, `carreras_fran.csv`, `cuerpo_fran.csv`), así que cerrar la app no hace perder nada — ver la nota de persistencia más abajo.
- **Panel de modificaciones seguro (🗑️):** módulo protegido por clave para eliminar o corregir registros en cada uno de los tres módulos de datos.

---

## ⚠️ Nota importante sobre persistencia de datos

Los tres CSV se guardan en disco cada vez que registras algo, así que **usando la app localmente (RStudio o `Rscript`), tus datos nunca se pierden al cerrarla**.

Si usas la versión desplegada en **shinyapps.io (plan gratuito)**, el almacenamiento no tiene garantía de persistir entre reinicios de la instancia o nuevos despliegues de la app. Recomendaciones:

- Usa la app localmente para tu registro diario "en serio", y la versión en la nube más para consultar/mostrar.
- Descarga respaldos seguido desde la pestaña **📋 Historial & Copia de Seguridad** (hay un botón de exportar CSV por cada módulo).
- Si haces un cambio grande, considera hacer commit de los CSV al repositorio como respaldo adicional.

---

## 🚀 Cómo ejecutar la aplicación localmente

### 1. Prerrequisitos

Instala [R](https://www.r-project.org/) y [RStudio](https://posit.co/download/rstudio-desktop/). Luego, instala las librerías necesarias desde la consola de R:

```r
install.packages(c("shiny", "bslib", "ggplot2", "dplyr", "lubridate", "plotly", "markdown"))
```

### 2. Ejecutar

Abre `app.R` en RStudio y presiona "Run App", o desde la terminal:

```r
Rscript -e "shiny::runApp('app.R')"
```

### 3. Clave de acceso

Por defecto la clave para registrar/eliminar datos es `fran123`. Puedes cambiarla sin tocar el código definiendo la variable de entorno `GYM_APP_PASS` (por ejemplo, en shinyapps.io: *Settings → Environment Variables*).

---

## 📁 Estructura del proyecto

```
app.R                        # UI + lógica de la app (Shiny)
gym_data_fran.csv            # datos: entrenamientos diarios
carreras_fran.csv            # datos: resultados y metas de carreras
cuerpo_fran.csv              # datos: peso / talla en el tiempo
PLAN_ENTRENAMIENTO_21K.md    # plan de entrenamiento hacia los 21K (se muestra dentro de la app)
PLAN_ALIMENTACION.md         # plan de alimentación (se muestra dentro de la app)
CODIGO_EXPLICADO.md          # explicación del código, para aprender a modificarlo
README.md                    # este archivo
```

---

## 🎯 Metas actuales

- **10K:** 1:14:15 (2 de agosto de 2026) → mejorar en las carreras del 14 y 27 de septiembre.
- **21K:** terminar bajo 3:00:00 el 29 de noviembre de 2026.
- **Composición corporal:** bajar de peso / tonificar, desde talla 42 hacia talla 38–40.

Todo el detalle de cómo se aborda cada meta está en las pestañas **🏁 Carreras & Metas**, **📈 Progreso Físico**, **🏃‍♀️ Plan 21K** y **🥗 Plan Alimentación** dentro de la app.
