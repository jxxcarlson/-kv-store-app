# Frontend

## Architecture

  frontend/                                                                                                                                                  
    src/
      Main.elm                -- Entry point, Browser.application                                                                                            
      Types.elm               -- Model, Msg, Route          
      Api.elm                 -- HTTP requests, JSON decoders/encoders
      Auth.elm                -- Login/register forms, JWT token storage
      Page/
        Public.elm            -- Public data listing (search, sort)
        MyData.elm            -- Authenticated user's data entries
        DataDetail.elm        -- View/edit a single data entry
        Groups.elm            -- Group management
      View/
        Table.elm             -- Reusable sortable table
        Search.elm            -- Search input component
    elm.json
    index.html
    style.css                 -- Minimal custom CSS

## Key decisions:

  - SPA with Browser.application — URL-based routing for pages
  - JWT stored in localStorage — sent via Authorization header on requests
  - No ports needed initially — localStorage access via a small JS interop for token persistence is the only port
  - Table view shows: key, data_type, description, created, modified
  - Sort by clicking column headers (key, created, modified)
  - Search filters on key and description client-side (the dataset from any single API call should be small enough)
