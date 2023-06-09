# carga de librerias
library(shiny)
library(shinydashboard)
library( shinyWidgets )
library(dplyr)
library(sf)
library(terra)
library(raster)
library(rgdal)
library(DT)
library(plotly)
library(leaflet)
library(leaflet.extras)
library(leafem)
library(ggplot2)
library(graphics)
library(tidyverse)
library(RColorBrewer)
#library(spData)
#library(spDataLarge)


#Lectura datos zonas
zonas <-
  st_read("https://raw.githubusercontent.com/mauguemu/prueba_tablero/master/Datos/capas/zonas_delimitadas.geojson",
          quiet = TRUE
  )

# Transformación del CRS del objeto zonas
zonas <-
  zonas %>%
  st_transform(4326)

#Lectura datos cuadrantes
cuadrantes <-
  st_read("https://raw.githubusercontent.com/mauguemu/prueba_tablero/master/Datos/capas/cuadrantes.geojson",
          quiet = TRUE
  )

# Transformación del CRS de cuadrantes 
cuadrantes <-
  cuadrantes %>%
  st_transform(4326)

#Lectura datos recursos patrimoniales  
recursos_patrimoniales <-
  st_read("https://raw.githubusercontent.com/mauguemu/prueba_tablero/master/Datos/capas/datos_mapa_inmaterial.geojson",
          quiet = TRUE
  )

# Transformación del CRS de recursos patrimoniales

recursos_patrimoniales <-
  recursos_patrimoniales %>%
  st_transform(4326)

# Lista ordenada de periodicidad + "Todos"
lista_periodicidad <- unique(recursos_patrimoniales$periodicidad)
lista_periodicidad <- sort(lista_periodicidad)
lista_periodicidad <- c("Todas", lista_periodicidad)

# Lista ordenada de subcategorias + "Todas"
lista_subcategorias <- unique(recursos_patrimoniales$subcategoria)
lista_subcategorias <- sort(lista_subcategorias)
lista_subcategorias <- c("Todas", lista_subcategorias)

#lectura patrimonio_inmaterial
patrimonio_inmaterial <-
  st_read(
    "/vsicurl/https://raw.githubusercontent.com/mauguemu/prueba_tablero/master/Datos/tablas/recursos_patrimonio_inmat.csv",
    quiet = TRUE
  )

# 1° operación espacial

# Cruce espacial de recursos_patrimoniales con cuadrantes para extraer el campo del cuadrante

# se presenta un error en la geometría y se resulve con el siguiente comando
sf::sf_use_s2(FALSE)

cuadrantes_recursos <- 
  recursos_patrimoniales %>%
  st_join(cuadrantes["id_cuadrante"])

# 2° operación espacial 

#selección de recursos del casco histórico

# Selección del casco histórico
casco_hist <- zonas[zonas$id_zona == "Z1-Li",]

# Selección de los recursos del casco histórico
recursos_casco <- cuadrantes_recursos[casco_hist, , op = st_within]

# Componentes de la aplicación Shiny
# Definición del objeto ui

ui <- dashboardPage(skin = "yellow",
                    
                    #tabsetPanel(
                    #  tabPanel(
                    
                    dashboardHeader(title ="Patrimonio inmaterial"),
                    
                    dashboardSidebar(sidebarMenu(
                      menuItem(
                        text = "Filtros",
                        selectInput(
                          inputId = "periodicidad",
                          label = "Periodicidad",
                          choices = lista_periodicidad,
                          selected = "Todas"
                        ),
                        selectInput(
                          inputId = "subcategoria",
                          label = "Subcategoría",
                          choices = lista_subcategorias,
                          selected = "Todas"
                        ),
                        numericRangeInput(
                          inputId = "valor_ponderado",
                          label = "Evaluación multicriterio",
                          value = c(3, 6.5),
                          width = NULL,
                          separator = " a ",
                          min = 3,
                          max = 6.5,
                          step = NA
                        ),
                        menuSubItem(text = "Mapa patrimonio inmaterial", tabName = "mapa_inmaterial"),
                        menuSubItem(text = "Tabla patrimonio inmaterial", tabName = "tabla_inmaterial"),
                        menuSubItem(text = "Gráfico patrimonio inmaterial", tabName = "grafico_inmaterial"),
                        menuSubItem(text = "Página principal",href="https://rpubs.com/mauguemu/1050387"),
                        
                        startExpanded = TRUE
                      )
                    )),
                    dashboardBody(tabItems(
                      tabItem(
                        tabName = "mapa_inmaterial",
                        box(
                          title = "Mapa recursos del patrimonio inmaterial", solidHeader = TRUE,status = "danger",
                          leafletOutput(outputId = "mapa",width="100%", height = 800),
                          width = 12
                          
                        )
                      ),
                      
                      
                      
                      tabItem(
                        tabName = "tabla_inmaterial",
                        fluidRow(
                          box(
                            title = "Recursos del patrimonio inmaterial",  solidHeader = TRUE, status = "info",
                            DTOutput(outputId = "tabla",width="100%", height = 800),
                            width = 12
                          )
                        )),
                      tabItem(
                        tabName = "grafico_inmaterial", 
                        fluidRow(
                          box(
                            title = "Valoración de los recursos del patrimonio inmaterial", solidHeader = TRUE,status = "success",
                            plotlyOutput(outputId = "grafico_evaluacion",width="100%", height = 800),
                            width = 12
                          ))))
                    ))


server <- function(input, output, session) {
  
  filtrarRegistros <- reactive({
    # Remoción de geometrías y selección de columnas
    patrimonio_filtrado <-
      recursos_patrimoniales %>%
      dplyr::select(codigo,denominacion,subcategoria,periodicidad,economico,disponibilidad,identidad_territorial,condicion,valor_ponderado,fotografia,ficha,id_recurso)
    
    # Filtrado por rango
    patrimonio_filtrado <-
      patrimonio_filtrado %>%
      filter(
        valor_ponderado >= input$valor_ponderado[1] &
          valor_ponderado <= input$valor_ponderado[2]
      )
    # Filtrado de registros por periodicidad
    if (input$periodicidad != "Todas") {
      patrimonio_filtrado <-
        patrimonio_filtrado %>%
        filter(periodicidad == input$periodicidad)
    }
    # Filtrado de registros por subcategoría
    if (input$subcategoria != "Todas") {
      patrimonio_filtrado <-
        patrimonio_filtrado %>%
        filter(subcategoria == input$subcategoria)
    }
    
    return(patrimonio_filtrado)
  })  
  
  output$tabla <- renderDT({
    registros <- filtrarRegistros()
    
    registros %>%
      st_drop_geometry() %>%
      dplyr::select(codigo,denominacion, subcategoria, periodicidad,valor_ponderado)%>%
      datatable(registros, options = list(language = list(url = '//cdn.datatables.net/plug-ins/1.11.3/i18n/es_es.json'), pageLength = 20))
  }) 
  
  
  output$mapa <- renderLeaflet({
    registros <-
      filtrarRegistros()
    
    colores <- c('red', 'orange', 'yellow')
    
    c_zona <- levels(as.factor(zonas$id_zona))
    
    paleta <- colorFactor(palette = colores, domain = c_zona)
    
    # Mapa leaflet básico con capas de zonas y recursos patrimoniales 
    leaflet() %>%
      addTiles() %>%
      setView(-83.0232, 9.9952, 15) %>%
      
      addProviderTiles(
        providers$CartoDB.Positron, group = "Mapa base Carto_DB") %>%
      addProviderTiles(
        providers$Esri.WorldImagery, group = "Maba base Esri") %>%
      
      addPolygons(
        data = zonas,
        color = ~paleta(id_zona),
        smoothFactor = 0.3,
        fillOpacity = 0.3,
        popup =  ~nombre,
        label= ~id_zona,
        stroke = TRUE,
        weight = 2.0,
        group = "Zonas delimitadas"
      )  %>%
      
      addPolygons(
        data = cuadrantes,
        color = "black",
        smoothFactor = 0.3,
        stroke = TRUE,
        weight = 1.0,
        group = "Cuadrantes"
      ) %>%
      
      addCircleMarkers(
        data = registros,
        stroke = F,
        radius = 4,
        popup = paste0("<strong>Recurso: </strong>",
                       registros$denominacion,
                       "<br>",
                       "<strong>Subcategoría: </strong>",
                       registros$subcategoria,
                       "<br>",
                       "<strong>Periodicidad: </strong>",
                       registros$periodicidad,
                       "<br>",
                       "<img src='",registros$fotografia,"","'width='200'/>",
                       "<br>",
                       "<a href='",registros$ficha,"", "'>Ficha</a>"),
        label = ~codigo,
        fillColor = 'orange',
        fillOpacity = 1,
        group = "Recursos patrimoniales"
      )%>%
      addSearchOSM()%>%
      addResetMapButton()%>%
      addMouseCoordinates()%>%
      addLayersControl(
        baseGroups = c("Mapa base Carto_DB","Mapa base Esri"),
        overlayGroups = c("Zonas delimitadas","Cuadrantes", "Recursos patrimoniales"),
        options = layersControlOptions(collapsed = T)
      )
  })
  
  
  
  output$grafico_evaluacion <- renderPlotly({
    registros <- filtrarRegistros()
    
    registros %>%
      st_drop_geometry() %>%
      plotly::select(denominacion,economico,disponibilidad,identidad_territorial,condicion)%>%
      pivot_longer(c("economico","disponibilidad","identidad_territorial","condicion"), names_to = "criterio",values_to = "valoracion")%>%
      ggplot(aes(x = valoracion, y = denominacion, fill = criterio)) +
      ggtitle("Valoración de los recursos patrimoniales") +
      ylab("Recurso") +
      xlab("Valoración multicriterio") +
      scale_fill_manual(values=brewer.pal(n = 5, name = "Greens"))+
      geom_col()%>%
      config(locale = "es")
    
  })
  
  
}


shinyApp(ui, server)
