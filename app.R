library(shiny)
library(httr)
library(jsonlite)
library(dplyr)
library(ggplot2)

# Strava API credentials
client_id <- "your_client_id"
client_secret <- "your_client_secret"
redirect_uri <- "http://localhost:8100/"  # This should match your registered Strava redirect URI

# OAuth 2.0 setup for Strava
oauth_endpoint <- oauth_endpoint(
  authorize = "https://www.strava.com/oauth/authorize",
  access = "https://www.strava.com/oauth/token"
)

strava_app <- oauth_app(
  "strava",
  key = client_id,
  secret = client_secret
)

# UI
ui <- fluidPage(
  titlePanel("Strava Ride Data Visualization"),
  sidebarLayout(
    sidebarPanel(
      p("This app shows your rides grouped by year, including the total number of rides, total distance ridden, and total elevation gain."),
      actionButton("login", "Login to Strava")
    ),
    mainPanel(
      h3("Ride Summary by Year"),
      tableOutput("ride_table"),
      h3("Total Distance by Year"),
      plotOutput("distance_plot"),
      h3("Total Elevation Gain by Year"),
      plotOutput("elevation_plot")
    )
  )
)

# Server
server <- function(input, output, session) {
  
  observeEvent(input$login, {
    # OAuth flow to get the access token
    auth_url <- oauth2.0_authorize_url(oauth_endpoint, strava_app, redirect_uri = redirect_uri, scope = "activity:read_all")
    browseURL(auth_url)
  })
  
  # Reactive function to get the access token after user login
  access_token <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query$code)) {
      token <- oauth2.0_access_token(oauth_endpoint, strava_app, code = query$code, redirect_uri = redirect_uri)
      return(token$credentials$access_token)
    }
    return(NULL)
  })
  
  observe({
    token <- access_token()
    
    if (!is.null(token)) {
      # Call the Strava API to fetch activities
      url_activities <- "https://www.strava.com/api/v3/athlete/activities"
      response_activities <- GET(url_activities, add_headers(Authorization = paste("Bearer", token)))
      activities <- fromJSON(content(response_activities, "text"))
      
      # Filter ride data
      rides_df <- activities %>%
        filter(type == "Ride") %>%
        mutate(
          start_date = as.Date(start_date),
          distance = distance / 1000,  # Convert distance from meters to kilometers
          year = format(start_date, "%Y")
        )
      
      # Summarize by year
      rides_summary <- rides_df %>%
        group_by(year) %>%
        summarise(
          total_rides = n(),
          total_distance = sum(distance),
          total_elevation = sum(total_elevation_gain)
        )
      
      # Update UI with data
      output$ride_table <- renderTable({ rides_summary })
      
      output$distance_plot <- renderPlot({
        ggplot(rides_summary, aes(x = year, y = total_distance)) +
          geom_bar(stat = "identity", fill = "steelblue") +
          labs(title = "Total Distance by Year", x = "Year", y = "Total Distance (km)")
      })
      
      output$elevation_plot <- renderPlot({
        ggplot(rides_summary, aes(x = year, y = total_elevation)) +
          geom_bar(stat = "identity", fill = "forestgreen") +
          labs(title = "Total Elevation Gain by Year", x = "Year", y = "Total Elevation (m)")
      })
    }
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
