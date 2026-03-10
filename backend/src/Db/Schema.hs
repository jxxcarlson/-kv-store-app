{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Db.Schema where

import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Time (UTCTime)
import Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
User sql=users
    name Text
    email Text
    passwordHash Text
    groupIds [Int] default='{}' sql=group_ids
    UniqueEmail email
    deriving Show

Group sql=groups
    ownerId UserId
    name Text
    canRead Bool default=True sql=can_read
    canWrite Bool default=False sql=can_write
    UniqueGroupName name
    deriving Show

DataEntry sql=data
    ownerId UserId
    groupId GroupId Maybe
    key Text
    dataType Text sql=data_type
    createdAt UTCTime sql=created_at
    modifiedAt UTCTime sql=modified_at
    properties Text default=''
    description Text default=''
    value Text default=''
    blobValue ByteString Maybe sql=blob_value
    UniqueOwnerKey ownerId key
    deriving Show

RefreshToken sql=refresh_tokens
    userId UserId
    token Text
    expiresAt UTCTime sql=expires_at
    deriving Show
|]
