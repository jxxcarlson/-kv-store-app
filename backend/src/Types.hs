{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Types where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- Auth
data RegisterRequest = RegisterRequest
  { registerName     :: Text
  , registerEmail    :: Text
  , registerPassword :: Text
  } deriving (Show, Generic)
instance FromJSON RegisterRequest
instance ToJSON RegisterRequest

data LoginRequest = LoginRequest
  { loginEmail    :: Text
  , loginPassword :: Text
  } deriving (Show, Generic)
instance FromJSON LoginRequest
instance ToJSON LoginRequest

data AuthResponse = AuthResponse
  { authToken        :: Text
  , authRefreshToken :: Text
  } deriving (Show, Generic)
instance FromJSON AuthResponse
instance ToJSON AuthResponse

data RefreshRequest = RefreshRequest
  { refreshToken :: Text
  } deriving (Show, Generic)
instance FromJSON RefreshRequest
instance ToJSON RefreshRequest

-- Data entries
data DataEntrySummary = DataEntrySummary
  { desKey         :: Text
  , desDataType    :: Text
  , desDescription :: Text
  , desCreatedAt   :: UTCTime
  , desModifiedAt  :: UTCTime
  , desIsPublic    :: Bool
  } deriving (Show, Generic)
instance FromJSON DataEntrySummary
instance ToJSON DataEntrySummary

data CreateDataRequest = CreateDataRequest
  { cdrKey         :: Text
  , cdrDataType    :: Text
  , cdrProperties  :: Text
  , cdrDescription :: Text
  , cdrValue       :: Text
  } deriving (Show, Generic)
instance FromJSON CreateDataRequest
instance ToJSON CreateDataRequest

data UpdateDataRequest = UpdateDataRequest
  { udrDataType    :: Maybe Text
  , udrProperties  :: Maybe Text
  , udrDescription :: Maybe Text
  , udrValue       :: Maybe Text
  } deriving (Show, Generic)
instance FromJSON UpdateDataRequest
instance ToJSON UpdateDataRequest

data AssignGroupRequest = AssignGroupRequest
  { agrGroupId :: Int
  } deriving (Show, Generic)
instance FromJSON AssignGroupRequest
instance ToJSON AssignGroupRequest

-- Groups
data CreateGroupRequest = CreateGroupRequest
  { cgrName     :: Text
  , cgrCanRead  :: Bool
  , cgrCanWrite :: Bool
  } deriving (Show, Generic)
instance FromJSON CreateGroupRequest
instance ToJSON CreateGroupRequest

data GroupResponse = GroupResponse
  { grpId       :: Int
  , grpOwnerId  :: Int
  , grpName     :: Text
  , grpCanRead  :: Bool
  , grpCanWrite :: Bool
  } deriving (Show, Generic)
instance FromJSON GroupResponse
instance ToJSON GroupResponse

data AddMemberRequest = AddMemberRequest
  { amrUserId :: Int
  } deriving (Show, Generic)
instance FromJSON AddMemberRequest
instance ToJSON AddMemberRequest

data DataValueResponse = DataValueResponse
  { dvrKey      :: Text
  , dvrDataType :: Text
  , dvrValue    :: Text
  } deriving (Show, Generic)
instance FromJSON DataValueResponse
instance ToJSON DataValueResponse
