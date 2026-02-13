# ============================================================
# PHASE 5: INTERACTIVE SCOUTING DASHBOARD (WITH ACTION BUTTONS)
# ============================================================

library(shiny)
library(tidyverse)
library(DT)
library(plotly)

# Load Data
project_dir <- getwd() 
scout_data <- readRDS(file.path(project_dir, "scout_report.rds"))

# Define UI
ui <- fluidPage(
  titlePanel("BPL Death Bowling Scout"),
  
  sidebarLayout(
    sidebarPanel(
      # --- NEW: INSIGHT BUTTONS ---
      h4("Quick Strategies"),
      actionButton("btn_anchors", "1. Find Anchors (Safe)", class = "btn-primary"),
      actionButton("btn_strike", "2. Find Wicket Takers", class = "btn-success"),
      actionButton("btn_gems", "3. Find Hidden Gems", class = "btn-warning"),
      hr(),
      
      h4("Manual Filters"),
      # Filter by Reliability
      checkboxGroupInput("reliability_filter", 
                         "Reliability:", 
                         choices = unique(scout_data$reliability),
                         selected = unique(scout_data$reliability)),
      br(),
      # Filter by Minimum Balls
      sliderInput("min_balls", 
                  "Minimum Balls Bowled:", 
                  min = 30, max = 200, value = 30),
      br(),
      # Filter by Max Economy
      sliderInput("max_econ", 
                  "Max Economy Rate:", 
                  min = 5, max = 12, value = 12),
      br(),
      # NEW: Filter by Wicket %
      sliderInput("min_q_wicket", 
                  "Min Quality Wicket %:", 
                  min = 0, max = 100, value = 0),
      br(),
      hr(),
      # Export Button
      strong("Export Data:"),
      downloadButton("downloadData", "Download CSV for Excel"),
      hr(),
      
      strong("Scout's Guide:"),
      p("Target bowlers with Low Economy & High Quality Wicket %."),
      p("Color Legend:"),
      tags$ul(
        tags$li("Green = High Reliability (Safe Pick)"),
        tags$li("Orange = Medium Reliability"),
        tags$li("Red = Low Reliability (Risky Pick)")
      )
    ),
    
    mainPanel(
      h3("Bowler Performance Matrix"),
      # Interactive Plot
      plotlyOutput("scatterPlot"),
      hr(),
      h3("Detailed Statistics"),
      # Data Table
      DT::dataTableOutput("dataTable")
    )
  )
)

# Define Server Logic
server <- function(input, output, session) { # Added 'session' argument
  
  # --- NEW: OBSERVE EVENTS FOR BUTTONS ---
  
  # 1. Anchor Strategy Button
  observeEvent(input$btn_anchors, {
    updateCheckboxGroupInput(session, "reliability_filter", selected = "High (10+ inns)")
    updateSliderInput(session, "max_econ", value = 7.5)
    updateSliderInput(session, "min_q_wicket", value = 0)
    updateSliderInput(session, "min_balls", value = 50)
  })
  
  # 2. Strike Force Strategy Button
  observeEvent(input$btn_strike, {
    updateCheckboxGroupInput(session, "reliability_filter", 
                             selected = c("High (10+ inns)", "Medium (5-9 inns)"))
    updateSliderInput(session, "min_q_wicket", value = 40)
    updateSliderInput(session, "max_econ", value = 12) # Reset economy to wide
    updateSliderInput(session, "min_balls", value = 30)
  })
  
  # 3. Hidden Gems Strategy Button
  observeEvent(input$btn_gems, {
    updateCheckboxGroupInput(session, "reliability_filter", selected = "Low (1-4 inns)")
    updateSliderInput(session, "max_econ", value = 7.0)
    updateSliderInput(session, "min_q_wicket", value = 0)
    updateSliderInput(session, "min_balls", value = 30)
  })
  
  # Reactive Data Filter
  filtered_data <- reactive({
    scout_data %>%
      filter(reliability %in% input$reliability_filter,
             balls_bowled >= input$min_balls,
             economy_rate <= input$max_econ,
             quality_wicket_pct >= input$min_q_wicket) # Added new filter
  })
  
  # 1. Scatter Plot
  output$scatterPlot <- renderPlotly({
    d <- filtered_data()
    
    # Set color palette for reliability
    pal <- c("High (10+ inns)" = "green", 
             "Medium (5-9 inns)" = "orange", 
             "Low (1-4 inns)" = "red")
    
    p <- ggplot(d, aes(x = economy_rate, y = quality_wicket_pct, 
                       text = paste("Bowler:", bowler,
                                    "<br>Economy:", round(economy_rate, 2),
                                    "<br>Quality Wickets:", round(quality_wicket_pct, 1), "%"),
                       color = reliability)) +
      geom_point(size = 3, alpha = 0.7) +
      scale_color_manual(values = pal) +
      geom_vline(xintercept = mean(d$economy_rate), linetype="dashed", color = "gray") +
      labs(title = "Death Bowling: Efficiency vs Impact",
           x = "Economy Rate (Lower is Better)",
           y = "Quality Wicket % (Higher is Better)",
           color = "Reliability") +
      theme_minimal() +
      theme(legend.position = "bottom")
    
    ggplotly(p, tooltip = "text")
  })
  
  # 2. Data Table
  output$dataTable <- DT::renderDataTable({
    datatable(filtered_data() %>% 
                select(bowler, economy_rate, quality_wicket_pct, 
                       total_wickets, relative_economy, reliability) %>% 
                arrange(economy_rate),
              options = list(pageLength = 10),
              rownames = FALSE)
  })
  
  # 3. Download Handler
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("BPL_Scout_Report_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
}

# Run the application 
shinyApp(ui = ui, server = server)