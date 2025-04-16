# edge-functions
Edge functions in NodeJS for the Mediverse sync layer

Clone this repo into the same folder as your Supabase compose.yml file
Then combine the two compose.yml files
Then run docker compose --build up -d
The functions will now run locally and can be called from inside postgres functions like they are local (zero latency)
