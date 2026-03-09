module Db.Migration where

import Database.Persist.Postgresql (ConnectionPool, runSqlPool, runMigration)
import Db.Schema (migrateAll)
import Db.Queries.Group (seedPublicGroup)

runMigrations :: ConnectionPool -> IO ()
runMigrations pool = do
  runSqlPool (runMigration migrateAll) pool
  seedPublicGroup pool
