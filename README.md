# KV Store

A key-value store with group-based access control. Haskell/Servant backend, Elm frontend, PostgreSQL database.

Users store key-value data entries (text, CSV, JSON, etc.) and control access via groups. Data assigned to the "public" group is readable by anyone without authentication.

## Prerequisites

- [Stack](https://docs.haskellstack.org/) (Haskell build tool)
- [Elm 0.19.1](https://elm-lang.org/)
- PostgreSQL
- libpq (on macOS: `brew install libpq`)

## Setup

### Database

```bash
createdb kvstore
```

Tables are created automatically on first run via Persistent migrations.

### Backend

```bash
cd backend
stack build
```

The first build downloads GHC and all dependencies — this takes a while.

### Frontend

```bash
cd frontend
elm make src/Main.elm --output=elm.js
```

## Running

### Start the backend

```bash
cd backend
stack exec kv-store-backend
```

The server starts on port 3000 by default.

### Serve the frontend

Open `frontend/index.html` in a browser, or serve it with any static file server:

```bash
cd frontend
python3 -m http.server 8080
```

Then visit `http://localhost:8080`.

## Configuration

The backend reads these environment variables (all optional):

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `postgresql://localhost/kvstore` | PostgreSQL connection string |
| `JWT_SECRET` | `dev-secret-change-me` | Secret for signing JWT tokens |
| `PORT` | `3000` | HTTP server port |

## API

See [docs/endpoints.md](docs/endpoints.md) for the full API reference.

### Quick examples

```bash
# Register
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"registerName":"Alice","registerEmail":"alice@example.com","registerPassword":"secret"}'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"loginEmail":"alice@example.com","loginPassword":"secret"}'

# Create a data entry (use the token from login)
curl -X POST http://localhost:3000/api/data \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"cdrKey":"my-data","cdrDataType":"txt","cdrProperties":"","cdrDescription":"A test entry","cdrValue":"Hello, world!"}'

# Browse public entries (no auth required)
curl http://localhost:3000/api/public
```

## Project Structure

```
backend/
  app/Main.hs            -- Entry point, Warp server
  src/
    Api.hs               -- Servant API type definition
    Api/Auth.hs          -- Register, login, refresh handlers
    Api/Data.hs          -- Data CRUD handlers
    Api/Group.hs         -- Group management handlers
    Api/Public.hs        -- Public browsing handler
    Auth.hs              -- JWT and bcrypt utilities
    Config.hs            -- Environment-based configuration
    Db.hs                -- Connection pool
    Db/Schema.hs         -- Persistent model definitions
    Db/Migration.hs      -- Auto-migration + public group seeding
    Db/Queries/           -- Database query functions
    Types.hs             -- Request/response types

frontend/
  src/
    Main.elm             -- SPA entry point with routing
    Types.elm            -- Model, Msg, data types
    Api.elm              -- HTTP requests, JSON codecs
    Auth.elm             -- Login/register forms
    Page/Public.elm      -- Public data browser
    Page/MyData.elm      -- User's data entries
    Page/Groups.elm      -- Group listing
    View/Table.elm       -- Sortable table component
    View/Search.elm      -- Search input component
  index.html
  style.css
```
