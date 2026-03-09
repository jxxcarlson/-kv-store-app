# KV Store App — Design Document

2026-03-09

## Overview

A key-value store with a Haskell/Postgres backend (Servant + Persistent) and an Elm frontend. Supports user authentication (JWT), group-based access control, and public browsing.

## Tech Stack

- **Backend**: Haskell, Servant, Persistent/Esqueleto, PostgreSQL, Stack
- **Frontend**: Elm (Browser.application SPA), minimal custom CSS
- **Auth**: JWT (access + refresh tokens), bcrypt password hashing
- **Config**: Environment variables (`DATABASE_URL`, `JWT_SECRET`, `PORT`)
- **Deployment**: Self-hosted VPS

## Data Model

See `data/spec2.md`. Four tables: users, groups, data, refresh_tokens. User-group membership via `INTEGER[]` column on users.

Key constraints:
- `(owner_id, key)` unique on data table
- Group names unique
- User emails unique

## API

See `docs/endpoints.md`. Auth, Data CRUD, Group management, Public browsing.

Public group data readable without auth. All writes require auth + ownership.

## Authorization

See `docs/auth.md`. Public reads, owner-only writes, group-based read access.

## Backend Structure

```
backend/
  app/Main.hs
  src/
    Api.hs
    Api/Auth.hs, Data.hs, Group.hs, Public.hs
    Db.hs, Db/Schema.hs, Db/Migration.hs
    Db/Queries/Data.hs, User.hs, Group.hs
    Auth.hs, Config.hs, Types.hs
  kv-store-backend.cabal
  stack.yaml
```

## Frontend Structure

```
frontend/
  src/
    Main.elm, Types.elm, Api.elm, Auth.elm
    Page/Public.elm, MyData.elm, DataDetail.elm, Groups.elm
    View/Table.elm, Search.elm
  elm.json, index.html, style.css
```

## Build Priority

Backend-first: get the API working and testable with curl, then build the Elm frontend against it.
