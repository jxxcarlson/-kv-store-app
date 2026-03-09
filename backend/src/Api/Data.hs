{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Api.Data (dataHandlers) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text, stripPrefix)
import Database.Persist (Entity(..), entityKey, entityVal)
import Database.Persist.Postgresql (ConnectionPool, toSqlKey, fromSqlKey)
import Servant

import Auth (validateToken)
import Config (AppConfig)
import Db.Schema
import qualified Db.Queries.Data as Q
import Types

-- | Extract and validate the user ID from the Authorization header
extractUserId :: AppConfig -> Text -> Handler (Key User)
extractUserId config authHeader = do
  let mToken = stripPrefix "Bearer " authHeader
  token <- case mToken of
    Nothing -> throwError err401 { errBody = "Missing Bearer prefix" }
    Just t  -> return t
  result <- liftIO $ validateToken config token
  case result of
    Left _    -> throwError err401 { errBody = "Invalid token" }
    Right uid -> return $ toSqlKey (fromIntegral uid)

-- | All data CRUD handlers, matching the 6 data endpoints in ProtectedAPI
dataHandlers :: AppConfig -> ConnectionPool -> Text -> ServerT DataAPI Handler
dataHandlers config pool authHeader =
       listDataHandler config pool authHeader
  :<|> getDataHandler config pool authHeader
  :<|> createDataHandler config pool authHeader
  :<|> updateDataHandler config pool authHeader
  :<|> deleteDataHandler config pool authHeader
  :<|> assignGroupHandler config pool authHeader

-- | The data portion of the ProtectedAPI
type DataAPI =
       "data" :> Get '[JSON] [DataEntrySummary]
  :<|> "data" :> Capture "key" Text :> Get '[JSON] DataValueResponse
  :<|> "data" :> ReqBody '[JSON] CreateDataRequest :> Post '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> ReqBody '[JSON] UpdateDataRequest :> Put '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> Delete '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "group" :> ReqBody '[JSON] AssignGroupRequest :> Put '[JSON] NoContent

-- | List all data entries for the authenticated user
listDataHandler :: AppConfig -> ConnectionPool -> Text -> Handler [DataEntrySummary]
listDataHandler config pool authHeader = do
  userId <- extractUserId config authHeader
  entries <- liftIO $ Q.listUserData pool userId
  return $ map (toSummary . entityVal) entries

-- | Get a single data entry's value by key
getDataHandler :: AppConfig -> ConnectionPool -> Text -> Text -> Handler DataValueResponse
getDataHandler config pool authHeader key = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity _ entry) ->
      return $ DataValueResponse
        { dvrKey      = dataEntryKey entry
        , dvrDataType = dataEntryDataType entry
        , dvrValue    = dataEntryValue entry
        }

-- | Create a new data entry
createDataHandler :: AppConfig -> ConnectionPool -> Text -> CreateDataRequest -> Handler DataEntrySummary
createDataHandler config pool authHeader req = do
  userId <- extractUserId config authHeader
  _ <- liftIO $ Q.createData pool userId
    (cdrKey req) (cdrDataType req) (cdrProperties req) (cdrDescription req) (cdrValue req)
  -- Fetch the created entry to return accurate timestamps
  mEntry <- liftIO $ Q.getDataByKey pool userId (cdrKey req)
  case mEntry of
    Nothing -> throwError err500 { errBody = "Failed to retrieve created entry" }
    Just (Entity _ entry) -> return $ toSummary entry

-- | Update an existing data entry
updateDataHandler :: AppConfig -> ConnectionPool -> Text -> Text -> UpdateDataRequest -> Handler DataEntrySummary
updateDataHandler config pool authHeader key req = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity entryId _) -> do
      liftIO $ Q.updateData pool entryId req
      -- Fetch updated entry
      mUpdated <- liftIO $ Q.getDataByKey pool userId key
      case mUpdated of
        Nothing -> throwError err500 { errBody = "Failed to retrieve updated entry" }
        Just (Entity _ updated) -> return $ toSummary updated

-- | Delete a data entry
deleteDataHandler :: AppConfig -> ConnectionPool -> Text -> Text -> Handler NoContent
deleteDataHandler config pool authHeader key = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity entryId _) -> do
      liftIO $ Q.deleteData pool entryId
      return NoContent

-- | Assign a group to a data entry
assignGroupHandler :: AppConfig -> ConnectionPool -> Text -> Text -> AssignGroupRequest -> Handler NoContent
assignGroupHandler config pool authHeader key req = do
  userId <- extractUserId config authHeader
  mEntry <- liftIO $ Q.getDataByKey pool userId key
  case mEntry of
    Nothing -> throwError err404 { errBody = "Data entry not found" }
    Just (Entity entryId _) -> do
      let groupKey = toSqlKey (fromIntegral (agrGroupId req)) :: Key Group
      liftIO $ Q.assignGroup pool entryId groupKey
      return NoContent

-- | Convert a DataEntry to a DataEntrySummary
toSummary :: DataEntry -> DataEntrySummary
toSummary entry = DataEntrySummary
  { desKey         = dataEntryKey entry
  , desDataType    = dataEntryDataType entry
  , desDescription = dataEntryDescription entry
  , desCreatedAt   = dataEntryCreatedAt entry
  , desModifiedAt  = dataEntryModifiedAt entry
  }
