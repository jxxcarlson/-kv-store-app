{-# LANGUAGE OverloadedStrings #-}

module Db.Migration where

import Database.Persist.Sql (rawExecute)
import Database.Persist.Postgresql (ConnectionPool, runSqlPool, runMigration)
import Db.Schema (migrateAll)
import Db.Queries.Group (seedPublicGroup)

runMigrations :: ConnectionPool -> IO ()
runMigrations pool = do
  runSqlPool (runMigration migrateAll) pool
  seedPublicGroup pool
  -- Advance sequences past manually inserted IDs (DO block returns no rows)
  runSqlPool (rawExecute "DO $$ BEGIN PERFORM setval('users_id_seq', (SELECT COALESCE(MAX(id),1) FROM users)); END $$" []) pool
  runSqlPool (rawExecute "DO $$ BEGIN PERFORM setval('groups_id_seq', (SELECT COALESCE(MAX(id),1) FROM groups)); END $$" []) pool
