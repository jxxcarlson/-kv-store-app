{-# LANGUAGE OverloadedStrings #-}

module Api.Public (publicHandlers) where

import Control.Monad.IO.Class (liftIO)
import Data.List (sortBy)
import Data.Ord (comparing, Down(..))
import Data.Text (Text, toCaseFold, isInfixOf)
import Database.Persist (Entity(..), entityVal, (==.), selectList)
import Database.Persist.Postgresql (ConnectionPool, runSqlPool, toSqlKey)
import Servant

import Api (PublicDataAPI)
import Db.Schema
import Types (DataEntrySummary(..), DataValueResponse(..))

publicHandlers :: ConnectionPool -> ServerT PublicDataAPI Handler
publicHandlers pool = listPublicHandler pool :<|> getPublicValueHandler pool

listPublicHandler :: ConnectionPool -> Maybe Text -> Maybe Text -> Handler [DataEntrySummary]
listPublicHandler pool mSearch mSort = do
  let publicGroupKey = toSqlKey 1 :: Key Group
  entries <- liftIO $ runSqlPool
    (selectList [DataEntryGroupId ==. Just publicGroupKey] [])
    pool
  let vals = map entityVal entries
      filtered = case mSearch of
        Nothing   -> vals
        Just term ->
          let lowerTerm = toCaseFold term
          in  filter (\e -> lowerTerm `isInfixOf` toCaseFold (dataEntryKey e)
                         || lowerTerm `isInfixOf` toCaseFold (dataEntryDescription e))
                     vals
      sorted = case mSort of
        Just "created"  -> sortBy (comparing dataEntryCreatedAt) filtered
        Just "modified" -> sortBy (comparing dataEntryModifiedAt) filtered
        _               -> sortBy (comparing dataEntryKey) filtered
  return $ map toSummary sorted

getPublicValueHandler :: ConnectionPool -> Text -> Handler DataValueResponse
getPublicValueHandler pool key = do
  let publicGroupKey = toSqlKey 1 :: Key Group
  entries <- liftIO $ runSqlPool
    (selectList [DataEntryGroupId ==. Just publicGroupKey, DataEntryKey ==. key] [])
    pool
  case entries of
    [Entity _ entry] ->
      return $ DataValueResponse
        { dvrKey      = dataEntryKey entry
        , dvrDataType = dataEntryDataType entry
        , dvrValue    = dataEntryValue entry
        }
    _ -> throwError err404 { errBody = "Public entry not found" }

toSummary :: DataEntry -> DataEntrySummary
toSummary entry = DataEntrySummary
  { desKey         = dataEntryKey entry
  , desDataType    = dataEntryDataType entry
  , desDescription = dataEntryDescription entry
  , desCreatedAt   = dataEntryCreatedAt entry
  , desModifiedAt  = dataEntryModifiedAt entry
  }
