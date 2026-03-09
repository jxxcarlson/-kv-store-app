{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Api.Group (groupHandlers) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.Text (Text, stripPrefix)
import Database.Persist (Entity(..), entityKey, entityVal)
import Database.Persist.Postgresql (ConnectionPool, fromSqlKey, toSqlKey)
import Servant

import Auth (validateToken)
import Config (AppConfig)
import Db.Schema
import Db.Queries.Group
import Db.Queries.User (getUserById)
import Types

-- | Convert an Entity Group to a GroupResponse
toGroupResponse :: Entity Group -> GroupResponse
toGroupResponse (Entity key grp) = GroupResponse
  { grpId       = fromIntegral (fromSqlKey key)
  , grpOwnerId  = fromIntegral (fromSqlKey (groupOwnerId grp))
  , grpName     = groupName grp
  , grpCanRead  = groupCanRead grp
  , grpCanWrite = groupCanWrite grp
  }

-- | Extract user ID from Authorization header
extractUserId :: AppConfig -> Text -> Handler Int
extractUserId config authHeader = do
  let token = case stripPrefix "Bearer " authHeader of
                Just t  -> t
                Nothing -> authHeader
  result <- liftIO $ validateToken config token
  case result of
    Left _    -> throwError err401 { errBody = "Invalid or expired token" }
    Right uid -> return uid

-- | All group handlers, matching the 5 group endpoints in ProtectedAPI
groupHandlers :: AppConfig -> ConnectionPool -> Text
              -> Handler [GroupResponse]
            :<|> (CreateGroupRequest -> Handler GroupResponse)
            :<|> (Int -> CreateGroupRequest -> Handler GroupResponse)
            :<|> (Int -> AddMemberRequest -> Handler NoContent)
            :<|> (Int -> Int -> Handler NoContent)
groupHandlers config pool authHeader =
       listGroupsH config pool authHeader
  :<|> createGroupH config pool authHeader
  :<|> updateGroupH config pool authHeader
  :<|> addMemberH config pool authHeader
  :<|> removeMemberH config pool authHeader

-- | List groups the current user belongs to
listGroupsH :: AppConfig -> ConnectionPool -> Text -> Handler [GroupResponse]
listGroupsH config pool authHeader = do
  uid <- extractUserId config authHeader
  let userKey = toSqlKey (fromIntegral uid) :: Key User
  mUser <- liftIO $ getUserById pool userKey
  case mUser of
    Nothing -> throwError err404 { errBody = "User not found" }
    Just user -> do
      groups <- liftIO $ listUserGroups pool (userGroupIds user)
      return $ map toGroupResponse groups

-- | Create a new group with the current user as owner
createGroupH :: AppConfig -> ConnectionPool -> Text -> CreateGroupRequest -> Handler GroupResponse
createGroupH config pool authHeader req = do
  uid <- extractUserId config authHeader
  let ownerKey = toSqlKey (fromIntegral uid) :: Key User
  gid <- liftIO $ createGroup pool ownerKey (cgrName req) (cgrCanRead req) (cgrCanWrite req)
  return GroupResponse
    { grpId       = fromIntegral (fromSqlKey gid)
    , grpOwnerId  = uid
    , grpName     = cgrName req
    , grpCanRead  = cgrCanRead req
    , grpCanWrite = cgrCanWrite req
    }

-- | Update a group (only owner allowed)
updateGroupH :: AppConfig -> ConnectionPool -> Text -> Int -> CreateGroupRequest -> Handler GroupResponse
updateGroupH config pool authHeader gidInt req = do
  uid <- extractUserId config authHeader
  let gid = toSqlKey (fromIntegral gidInt) :: Key Group
  mGroup <- liftIO $ getGroupById pool gid
  case mGroup of
    Nothing -> throwError err404 { errBody = "Group not found" }
    Just grp -> do
      when (fromSqlKey (groupOwnerId grp) /= fromIntegral uid) $
        throwError err403 { errBody = "Only the group owner can update the group" }
      liftIO $ updateGroup pool gid (cgrName req) (cgrCanRead req) (cgrCanWrite req)
      return GroupResponse
        { grpId       = gidInt
        , grpOwnerId  = uid
        , grpName     = cgrName req
        , grpCanRead  = cgrCanRead req
        , grpCanWrite = cgrCanWrite req
        }

-- | Add a member to a group (only owner allowed)
addMemberH :: AppConfig -> ConnectionPool -> Text -> Int -> AddMemberRequest -> Handler NoContent
addMemberH config pool authHeader gidInt req = do
  uid <- extractUserId config authHeader
  let gid = toSqlKey (fromIntegral gidInt) :: Key Group
  mGroup <- liftIO $ getGroupById pool gid
  case mGroup of
    Nothing -> throwError err404 { errBody = "Group not found" }
    Just grp -> do
      when (fromSqlKey (groupOwnerId grp) /= fromIntegral uid) $
        throwError err403 { errBody = "Only the group owner can add members" }
      let targetKey = toSqlKey (fromIntegral (amrUserId req)) :: Key User
      liftIO $ addMember pool targetKey gidInt
      return NoContent

-- | Remove a member from a group (only owner allowed)
removeMemberH :: AppConfig -> ConnectionPool -> Text -> Int -> Int -> Handler NoContent
removeMemberH config pool authHeader gidInt targetUidInt = do
  uid <- extractUserId config authHeader
  let gid = toSqlKey (fromIntegral gidInt) :: Key Group
  mGroup <- liftIO $ getGroupById pool gid
  case mGroup of
    Nothing -> throwError err404 { errBody = "Group not found" }
    Just grp -> do
      when (fromSqlKey (groupOwnerId grp) /= fromIntegral uid) $
        throwError err403 { errBody = "Only the group owner can remove members" }
      let targetKey = toSqlKey (fromIntegral targetUidInt) :: Key User
      liftIO $ removeMember pool targetKey gidInt
      return NoContent
