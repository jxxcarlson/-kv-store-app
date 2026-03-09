module Db.Migration where

import Database.Persist.Postgresql (ConnectionPool, runSqlPool, runMigration)
import Db.Schema (migrateAll)

runMigrations :: ConnectionPool -> IO ()
runMigrations pool =
  runSqlPool (runMigration migrateAll) pool
