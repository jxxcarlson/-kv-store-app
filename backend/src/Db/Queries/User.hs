module Db.Queries.User where

import Data.Text (Text)
import Database.Persist
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Db.Schema

createUser :: ConnectionPool -> Text -> Text -> Text -> IO (Key User)
createUser pool name email passwordHash =
  runSqlPool (insert $ User name email passwordHash []) pool

getUserByEmail :: ConnectionPool -> Text -> IO (Maybe (Entity User))
getUserByEmail pool email =
  runSqlPool (getBy $ UniqueEmail email) pool

getUserById :: ConnectionPool -> Key User -> IO (Maybe User)
getUserById pool uid =
  runSqlPool (get uid) pool
