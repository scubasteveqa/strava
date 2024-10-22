import requests
import pandas as pd
import plotly.express as px
from dash import Dash, html, dcc, Output, Input
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

# Environment variables for Strava API
client_id = os.getenv("STRAVA_CLIENT_ID")
client_secret = os.getenv("STRAVA_CLIENT_SECRET")
refresh_token = os.getenv("STRAVA_REFRESH_TOKEN")

# Function to get an access token
def get_access_token():
    auth_url = "https://www.strava.com/oauth/token"
    auth_data = {
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token"
    }
    auth_response = requests.post(auth_url, data=auth_data)
    return auth_response.json()["access_token"]

# Initialize Dash app
app = Dash(__name__)

# App layout
app.layout = html.Div([
    html.H1("Strava Ride Visualization"),
    dcc.Graph(id='distance-bar-chart'),
    dcc.Graph(id='elevation-bar-chart'),
])

# Callback to update graphs
@app.callback(
    Output('distance-bar-chart', 'figure'),
    Output('elevation-bar-chart', 'figure'),
)
def update_graphs():
    # Get access token and fetch activities
    access_token = get_access_token()
    activities_url = "https://www.strava.com/api/v3/athlete/activities"
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(activities_url, headers=headers)
    activities = response.json()

    # Convert the activities to a DataFrame
    df = pd.DataFrame(activities)

    # Filter for rides and create summary stats
    rides_df = df[df['type'] == 'Ride']
    rides_df['start_date'] = pd.to_datetime(rides_df['start_date'])
    rides_df['year'] = rides_df['start_date'].dt.year
    rides_df['distance_km'] = rides_df['distance'] / 1000  # Convert distance to km

    summary = rides_df.groupby('year').agg(
        total_rides=('id', 'count'),
        total_distance_km=('distance_km', 'sum'),
        total_elevation_gain=('total_elevation_gain', 'sum')
    ).reset_index()

    # Create figures
    distance_fig = px.bar(summary, x='year', y='total_distance_km', 
                           title='Total Distance by Year', 
                           labels={'total_distance_km': 'Total Distance (km)'})
    
    elevation_fig = px.bar(summary, x='year', y='total_elevation_gain', 
                            title='Total Elevation Gain by Year', 
                            labels={'total_elevation_gain': 'Total Elevation Gain (m)'})
    
    return distance_fig, elevation_fig

# Run the app
if __name__ == '__main__':
    app.run_server(debug=True)
