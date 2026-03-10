{-# LANGUAGE OverloadedStrings #-}

module Db.Queries.Data
  ( listUserData
  , getDataByKey
  , createData
  , updateData
  , deleteData
  , assignGroup
  , unassignGroup
  ) where

import Data.Text (Text)
import Data.Time.Clock (getCurrentTime)
import Database.Persist
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)

import Db.Schema
import Types (UpdateDataRequest(..))

listUserData :: ConnectionPool -> Key User -> IO [Entity DataEntry]
listUserData pool uid =
  runSqlPool (selectList [DataEntryOwnerId ==. uid] []) pool

getDataByKey :: ConnectionPool -> Key User -> Text -> IO (Maybe (Entity DataEntry))
getDataByKey pool uid key =
  runSqlPool (getBy $ UniqueOwnerKey uid key) pool

createData :: ConnectionPool -> Key User -> Text -> Text -> Text -> Text -> Text -> IO (Key DataEntry)
createData pool uid key dataType properties description value = do
  now <- getCurrentTime
  runSqlPool (insert $ DataEntry uid Nothing key dataType now now properties description value) pool

updateData :: ConnectionPool -> Key DataEntry -> UpdateDataRequest -> IO ()
updateData pool entryId req = do
  now <- getCurrentTime
  let updates = [DataEntryModifiedAt =. now]
        ++ maybe [] (\v -> [DataEntryDataType =. v]) (udrDataType req)
        ++ maybe [] (\v -> [DataEntryProperties =. v]) (udrProperties req)
        ++ maybe [] (\v -> [DataEntryDescription =. v]) (udrDescription req)
        ++ maybe [] (\v -> [DataEntryValue =. v]) (udrValue req)
  runSqlPool (update entryId updates) pool

deleteData :: ConnectionPool -> Key DataEntry -> IO ()
deleteData pool entryId =
  runSqlPool (delete entryId) pool

assignGroup :: ConnectionPool -> Key DataEntry -> Key Group -> IO ()
assignGroup pool entryId groupId =
  runSqlPool (update entryId [DataEntryGroupId =. Just groupId]) pool

unassignGroup :: ConnectionPool -> Key DataEntry -> IO ()
unassignGroup pool entryId =
  runSqlPool (update entryId [DataEntryGroupId =. Nothing]) pool
