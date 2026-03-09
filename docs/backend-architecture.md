  backend/                                                  
    app/Main.hs              -- Entry point, warp server
    src/
      Api.hs                  -- Servant API type definition (combined API)
      Api/Auth.hs             -- Auth endpoints + JWT logic
      Api/Data.hs             -- Data CRUD handlers
      Api/Group.hs            -- Group CRUD handlers
      Api/Public.hs           -- Public browsing handlers
      Db.hs                   -- Connection pool setup
      Db/Schema.hs            -- Persistent model definitions (TH)
      Db/Migration.hs         -- Auto-migration on startup
      Db/Queries/Data.hs      -- Data queries
      Db/Queries/User.hs      -- User queries
      Db/Queries/Group.hs     -- Group queries
      Auth.hs                 -- JWT creation/validation, password hashing
      Config.hs               -- Env-based config (DB url, JWT secret, port)
      Types.hs                -- Shared request/response types
    kv-store-backend.cabal
    stack.yaml                -- or cabal.project

  Key decisions:
  - Stack vs Cabal: Stack for reproducible builds
  - Config via environment variables: DATABASE_URL, JWT_SECRET, PORT
  - Connection pooling: persistent-postgresql handles this
  - Auto-migration on startup in dev; manual migrations in production
