{-# LANGUAGE OverloadedStrings #-}

module Db.Queries.Group where

import Control.Monad.Reader (ReaderT)
import Data.Text (Text)
import Database.Persist
import Database.Persist.Postgresql (ConnectionPool, SqlBackend, runSqlPool, toSqlKey, fromSqlKey)
import Db.Schema

createGroup :: ConnectionPool -> Key User -> Text -> Bool -> Bool -> IO (Key Group)
createGroup pool ownerId name canRead canWrite =
  runSqlPool (insert $ Group ownerId name canRead canWrite) pool

getGroupById :: ConnectionPool -> Key Group -> IO (Maybe Group)
getGroupById pool gid =
  runSqlPool (get gid) pool

updateGroup :: ConnectionPool -> Key Group -> Text -> Bool -> Bool -> IO ()
updateGroup pool gid name canRead canWrite =
  runSqlPool (update gid [ GroupName =. name
                         , GroupCanRead =. canRead
                         , GroupCanWrite =. canWrite
                         ]) pool

listUserGroups :: ConnectionPool -> [Int] -> IO [Entity Group]
listUserGroups pool gids =
  let keys = map (toSqlKey . fromIntegral) gids :: [Key Group]
  in  runSqlPool (selectList [GroupId <-. keys] []) pool

addMember :: ConnectionPool -> Key User -> Int -> IO ()
addMember pool uid gid = runSqlPool go pool
  where
    go :: ReaderT SqlBackend IO ()
    go = do
      mUser <- get uid
      case mUser of
        Nothing -> return ()
        Just user ->
          let current = userGroupIds user
          in  if gid `elem` current
                then return ()
                else update uid [UserGroupIds =. (current ++ [gid])]

removeMember :: ConnectionPool -> Key User -> Int -> IO ()
removeMember pool uid gid = runSqlPool go pool
  where
    go :: ReaderT SqlBackend IO ()
    go = do
      mUser <- get uid
      case mUser of
        Nothing -> return ()
        Just user ->
          let current = userGroupIds user
          in  update uid [UserGroupIds =. filter (/= gid) current]

seedPublicGroup :: ConnectionPool -> IO ()
seedPublicGroup pool = runSqlPool go pool
  where
    go :: ReaderT SqlBackend IO ()
    go = do
      let publicKey = toSqlKey 1 :: Key Group
      mGroup <- get publicKey
      case mGroup of
        Just _  -> return ()
        Nothing -> do
          let systemUser = toSqlKey 0 :: Key User
          insertKey publicKey (Group systemUser "public" True False)
