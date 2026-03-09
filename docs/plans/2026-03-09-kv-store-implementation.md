# KV Store Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a key-value store with Haskell/Servant backend and Elm frontend, supporting JWT auth, group-based permissions, and public browsing.

**Architecture:** Servant REST API backed by Persistent/PostgreSQL. Elm SPA communicates via JSON. JWT for auth with refresh tokens. Group-based read access, owner-only writes.

**Tech Stack:** Haskell (Stack), Servant, Persistent, PostgreSQL, bcrypt, jose (JWT), Elm 0.19, minimal CSS.

---

### Task 1: Backend Project Scaffolding

**Files:**
- Create: `backend/stack.yaml`
- Create: `backend/package.yaml`
- Create: `backend/app/Main.hs`
- Create: `backend/src/Config.hs`

**Step 1: Initialize Stack project**

```bash
cd /Users/carlson/dev/elm-work/scripta/kv-store
mkdir -p backend
cd backend
stack new kv-store-backend simple --bare
```

**Step 2: Configure package.yaml with dependencies**

Edit `backend/package.yaml` to include:

```yaml
name: kv-store-backend
version: 0.1.0.0

dependencies:
  - base >= 4.7 && < 5
  - aeson
  - bcrypt
  - bytestring
  - esqueleto
  - jose
  - lens
  - monad-logger
  - mtl
  - persistent
  - persistent-postgresql
  - resource-pool
  - servant
  - servant-server
  - text
  - time
  - transformers
  - uuid
  - wai
  - wai-cors
  - warp

library:
  source-dirs: src

executables:
  kv-store-backend:
    main: Main.hs
    source-dirs: app
    dependencies:
      - kv-store-backend

tests:
  kv-store-backend-test:
    main: Spec.hs
    source-dirs: test
    dependencies:
      - kv-store-backend
      - hspec
      - hspec-wai
      - servant-client
      - http-client
```

**Step 3: Write Config.hs**

```haskell
-- backend/src/Config.hs
module Config where

import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)

data AppConfig = AppConfig
  { configDbUrl    :: String
  , configJwtSecret :: String
  , configPort     :: Int
  } deriving (Show)

loadConfig :: IO AppConfig
loadConfig = do
  dbUrl     <- fromMaybe "postgresql://localhost/kvstore" <$> lookupEnv "DATABASE_URL"
  jwtSecret <- fromMaybe "dev-secret-change-me" <$> lookupEnv "JWT_SECRET"
  port      <- maybe 3000 read <$> lookupEnv "PORT"
  return AppConfig
    { configDbUrl    = dbUrl
    , configJwtSecret = jwtSecret
    , configPort     = port
    }
```

**Step 4: Write minimal Main.hs**

```haskell
-- backend/app/Main.hs
module Main where

import Config (loadConfig, configPort)

main :: IO ()
main = do
  config <- loadConfig
  putStrLn $ "KV Store starting on port " ++ show (configPort config)
```

**Step 5: Build to verify setup**

Run: `cd /Users/carlson/dev/elm-work/scripta/kv-store/backend && stack build`
Expected: Compiles successfully.

**Step 6: Commit**

```bash
git add backend/
git commit -m "feat: scaffold backend Stack project with config"
```

---

### Task 2: Database Schema and Migration

**Files:**
- Create: `backend/src/Db/Schema.hs`
- Create: `backend/src/Db.hs`
- Create: `backend/src/Db/Migration.hs`

**Step 1: Write Persistent schema definitions**

```haskell
-- backend/src/Db/Schema.hs
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
    UniqueOwnerKey ownerId key
    deriving Show

RefreshToken sql=refresh_tokens
    userId UserId
    token Text
    expiresAt UTCTime sql=expires_at
    deriving Show
|]
```

**Step 2: Write DB connection pool setup**

```haskell
-- backend/src/Db.hs
{-# LANGUAGE OverloadedStrings #-}

module Db where

import Control.Monad.Logger (runStdoutLoggingT)
import Data.ByteString.Char8 (pack)
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)

import Config (AppConfig(..))

createPool :: AppConfig -> IO ConnectionPool
createPool config =
  runStdoutLoggingT $
    createPostgresqlPool (pack $ configDbUrl config) 10
```

**Step 3: Write migration module**

```haskell
-- backend/src/Db/Migration.hs
module Db.Migration where

import Database.Persist.Postgresql (ConnectionPool, runSqlPool, runMigration)
import Db.Schema (migrateAll)

runMigrations :: ConnectionPool -> IO ()
runMigrations pool =
  runSqlPool (runMigration migrateAll) pool
```

**Step 4: Update Main.hs to run migrations**

```haskell
-- backend/app/Main.hs
module Main where

import Config (loadConfig, configPort)
import Db (createPool)
import Db.Migration (runMigrations)

main :: IO ()
main = do
  config <- loadConfig
  pool <- createPool config
  runMigrations pool
  putStrLn $ "KV Store starting on port " ++ show (configPort config)
```

**Step 5: Create test database and build**

```bash
createdb kvstore
cd /Users/carlson/dev/elm-work/scripta/kv-store/backend && stack build
```

**Step 6: Run to verify migrations**

Run: `stack exec kv-store-backend`
Expected: Prints migration output and "KV Store starting on port 3000".

**Step 7: Commit**

```bash
git add backend/src/Db/ backend/src/Db.hs backend/app/Main.hs
git commit -m "feat: add Persistent schema and auto-migration"
```

---

### Task 3: Servant API Types and Warp Server

**Files:**
- Create: `backend/src/Types.hs`
- Create: `backend/src/Api.hs`
- Modify: `backend/app/Main.hs`

**Step 1: Define shared request/response types**

```haskell
-- backend/src/Types.hs
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
```

**Step 2: Define Servant API type**

```haskell
-- backend/src/Api.hs
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Api where

import Data.Text (Text)
import Servant
import Types

type API = "api" :> (AuthAPI :<|> ProtectedAPI :<|> PublicDataAPI)

-- No auth required
type AuthAPI = "auth" :>
  (    "register" :> ReqBody '[JSON] RegisterRequest  :> Post '[JSON] AuthResponse
  :<|> "login"    :> ReqBody '[JSON] LoginRequest     :> Post '[JSON] AuthResponse
  :<|> "refresh"  :> ReqBody '[JSON] RefreshRequest   :> Post '[JSON] AuthResponse
  )

-- JWT required (Header "Authorization" Text)
type ProtectedAPI = Header' '[Required] "Authorization" Text :>
  (    "data" :> Get '[JSON] [DataEntrySummary]
  :<|> "data" :> Capture "key" Text :> Get '[JSON] DataValueResponse
  :<|> "data" :> ReqBody '[JSON] CreateDataRequest :> Post '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> ReqBody '[JSON] UpdateDataRequest :> Put '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> Delete '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "group" :> ReqBody '[JSON] AssignGroupRequest :> Put '[JSON] NoContent
  :<|> "groups" :> Get '[JSON] [Group]
  :<|> "groups" :> ReqBody '[JSON] CreateGroupRequest :> Post '[JSON] Group
  :<|> "groups" :> Capture "id" Int :> ReqBody '[JSON] CreateGroupRequest :> Put '[JSON] Group
  :<|> "groups" :> Capture "id" Int :> "members" :> ReqBody '[JSON] AddMemberRequest :> Post '[JSON] NoContent
  :<|> "groups" :> Capture "id" Int :> "members" :> Capture "uid" Int :> Delete '[JSON] NoContent
  )

-- Public (no auth)
type PublicDataAPI = "public" :>
  (    QueryParam "search" Text :> QueryParam "sort" Text :> Get '[JSON] [DataEntrySummary]
  )

apiProxy :: Proxy API
apiProxy = Proxy
```

**Step 3: Wire up a stub server in Main.hs**

Update `backend/app/Main.hs` to serve the API with stub handlers that return 501 (Not Implemented). This verifies the API types compile.

```haskell
-- backend/app/Main.hs
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors (simpleCors)
import Servant

import Api (apiProxy, API)
import Config (loadConfig, configPort)
import Db (createPool)
import Db.Migration (runMigrations)

main :: IO ()
main = do
  config <- loadConfig
  pool <- createPool config
  runMigrations pool
  let port = configPort config
  putStrLn $ "KV Store running on port " ++ show port
  run port $ simpleCors $ serve apiProxy stubServer

stubServer :: Server API
stubServer = error "TODO: implement handlers"
```

**Step 4: Build**

Run: `cd /Users/carlson/dev/elm-work/scripta/kv-store/backend && stack build`
Expected: Compiles. (Server will crash if hit, but types are verified.)

**Step 5: Commit**

```bash
git add backend/src/Types.hs backend/src/Api.hs backend/app/Main.hs
git commit -m "feat: define Servant API types and request/response types"
```

---

### Task 4: Auth Module (JWT + bcrypt)

**Files:**
- Create: `backend/src/Auth.hs`
- Create: `backend/src/Db/Queries/User.hs`

**Step 1: Write Auth.hs (JWT creation/validation, password hashing)**

```haskell
-- backend/src/Auth.hs
{-# LANGUAGE OverloadedStrings #-}

module Auth where

import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Crypto.JOSE (JWK, fromOctets)
import Crypto.JWT
import Control.Lens ((&), (.~), (?~))
import Control.Monad.Except (runExceptT)
import Data.ByteString (ByteString)
import Data.ByteString.Char8 (pack)
import Data.Text (Text)
import Data.Text.Encoding (encodeUtf8, decodeUtf8)
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import qualified Data.Aeson as Aeson

import Config (AppConfig(..))

-- Password hashing

hashPassword :: Text -> IO (Maybe Text)
hashPassword pw = do
  mHashed <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (encodeUtf8 pw)
  return $ fmap decodeUtf8 mHashed

checkPassword :: Text -> Text -> Bool
checkPassword hash pw =
  validatePassword (encodeUtf8 hash) (encodeUtf8 pw)

-- JWT

makeJWK :: AppConfig -> JWK
makeJWK config = fromOctets (pack $ configJwtSecret config)

createToken :: AppConfig -> Int -> IO (Either JWTError SignedJWT)
createToken config userId = do
  now <- getCurrentTime
  let claims = emptyClaimsSet
        & claimSub ?~ ("user:" <> fromString (show userId))
        & claimIat ?~ NumericDate now
        & claimExp ?~ NumericDate (addUTCTime 3600 now)  -- 1 hour
      jwk = makeJWK config
  runExceptT $ signClaims jwk (newJWSHeader ((), HS256)) claims

validateToken :: AppConfig -> ByteString -> IO (Either JWTError ClaimsSet)
validateToken config tokenBS = do
  now <- getCurrentTime
  let jwk = makeJWK config
      audCheck _ = True
      config' = defaultJWTValidationSettings audCheck
  runExceptT $ do
    jwt <- decodeCompact (fromStrict tokenBS)
    verifyClaims config' jwk jwt
```

**Step 2: Write user queries**

```haskell
-- backend/src/Db/Queries/User.hs
{-# LANGUAGE OverloadedStrings #-}

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
```

**Step 3: Build**

Run: `stack build`
Expected: Compiles.

**Step 4: Commit**

```bash
git add backend/src/Auth.hs backend/src/Db/Queries/User.hs
git commit -m "feat: add JWT auth and user queries"
```

---

### Task 5: Auth Endpoint Handlers

**Files:**
- Create: `backend/src/Api/Auth.hs`

**Step 1: Implement register, login, refresh handlers**

```haskell
-- backend/src/Api/Auth.hs
{-# LANGUAGE OverloadedStrings #-}

module Api.Auth where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text, pack)
import Data.Text.Encoding (decodeUtf8)
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Time (addUTCTime, getCurrentTime)
import Data.UUID.V4 (nextRandom)
import qualified Data.UUID as UUID
import Database.Persist (Entity(..), fromSqlKey, toSqlKey)
import Database.Persist.Postgresql (ConnectionPool, runSqlPool, insert)
import Servant

import Auth (hashPassword, checkPassword, createToken)
import Config (AppConfig)
import Db.Schema
import Db.Queries.User (createUser, getUserByEmail)
import Types

authHandlers :: AppConfig -> ConnectionPool -> Server AuthAPI
authHandlers config pool = registerH :<|> loginH :<|> refreshH
  where
    registerH req = do
      mHash <- liftIO $ hashPassword (registerPassword req)
      case mHash of
        Nothing -> throwError err500 { errBody = "Failed to hash password" }
        Just hash -> do
          userId <- liftIO $ createUser pool (registerName req) (registerEmail req) hash
          makeAuthResponse config pool userId

    loginH req = do
      mUser <- liftIO $ getUserByEmail pool (loginEmail req)
      case mUser of
        Nothing -> throwError err401 { errBody = "Invalid credentials" }
        Just (Entity uid user) ->
          if checkPassword (userPasswordHash user) (loginPassword req)
          then makeAuthResponse config pool uid
          else throwError err401 { errBody = "Invalid credentials" }

    refreshH _req = throwError err501 { errBody = "TODO: implement refresh" }

makeAuthResponse :: AppConfig -> ConnectionPool -> Key User -> Handler AuthResponse
makeAuthResponse config pool userId = do
  eToken <- liftIO $ createToken config (fromIntegral $ fromSqlKey userId)
  case eToken of
    Left _err -> throwError err500 { errBody = "Failed to create token" }
    Right signed -> do
      uuid <- liftIO nextRandom
      now <- liftIO getCurrentTime
      let refreshTok = pack $ UUID.toString uuid
          expires = addUTCTime (7 * 24 * 3600) now  -- 7 days
      liftIO $ runSqlPool
        (insert $ RefreshToken userId refreshTok expires)
        pool
      return AuthResponse
        { authToken = decodeUtf8 $ BL.toStrict $ encodeCompact signed
        , authRefreshToken = refreshTok
        }
```

*Note: `AuthAPI` type will need to be imported or referenced from Api.hs. Some imports/signatures may need adjustment during implementation — the intent and structure are what matters.*

**Step 2: Build**

Run: `stack build`

**Step 3: Test with curl**

```bash
stack exec kv-store-backend &
# Register
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"registerName":"Test","registerEmail":"test@test.com","registerPassword":"pass123"}'
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"loginEmail":"test@test.com","loginPassword":"pass123"}'
```

Expected: Both return `{"authToken":"...","authRefreshToken":"..."}`.

**Step 4: Commit**

```bash
git add backend/src/Api/Auth.hs
git commit -m "feat: implement auth register and login endpoints"
```

---

### Task 6: Data CRUD Queries and Handlers

**Files:**
- Create: `backend/src/Db/Queries/Data.hs`
- Create: `backend/src/Api/Data.hs`

**Step 1: Write data queries**

```haskell
-- backend/src/Db/Queries/Data.hs
module Db.Queries.Data where

import Data.Text (Text)
import Data.Time (getCurrentTime)
import Database.Persist
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Db.Schema

listUserData :: ConnectionPool -> Key User -> IO [Entity DataEntry]
listUserData pool uid =
  runSqlPool (selectList [DataEntryOwnerId ==. uid] []) pool

getDataByKey :: ConnectionPool -> Key User -> Text -> IO (Maybe (Entity DataEntry))
getDataByKey pool uid key =
  runSqlPool (getBy $ UniqueOwnerKey uid key) pool

createData :: ConnectionPool -> Key User -> Text -> Text -> Text -> Text -> Text -> IO (Key DataEntry)
createData pool uid key dataType props desc val = do
  now <- getCurrentTime
  runSqlPool (insert $ DataEntry uid Nothing key dataType now now props desc val) pool

updateData :: ConnectionPool -> Key DataEntry -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> IO ()
updateData pool entryId mType mProps mDesc mVal = do
  now <- getCurrentTime
  let updates = [DataEntryModifiedAt =. now]
        ++ maybe [] (\t -> [DataEntryDataType =. t]) mType
        ++ maybe [] (\p -> [DataEntryProperties =. p]) mProps
        ++ maybe [] (\d -> [DataEntryDescription =. d]) mDesc
        ++ maybe [] (\v -> [DataEntryValue =. v]) mVal
  runSqlPool (update entryId updates) pool

deleteData :: ConnectionPool -> Key DataEntry -> IO ()
deleteData pool entryId =
  runSqlPool (delete entryId) pool

assignGroup :: ConnectionPool -> Key DataEntry -> Key Group -> IO ()
assignGroup pool entryId gid =
  runSqlPool (update entryId [DataEntryGroupId =. Just gid]) pool

listPublicData :: ConnectionPool -> Key Group -> Maybe Text -> Maybe Text -> IO [Entity DataEntry]
listPublicData pool publicGroupId mSearch mSort =
  runSqlPool (selectList [DataEntryGroupId ==. Just publicGroupId] []) pool
```

**Step 2: Write data handlers (Api/Data.hs)**

Implement handlers that extract the user ID from the JWT in the Authorization header, call the query functions, and return the appropriate responses. Follow the same pattern as Api/Auth.hs.

**Step 3: Build and test with curl**

```bash
stack build
# Create a data entry
TOKEN="<jwt from login>"
curl -X POST http://localhost:3000/api/data \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cdrKey":"test-data","cdrDataType":"txt","cdrProperties":"","cdrDescription":"test","cdrValue":"hello"}'
# List entries
curl http://localhost:3000/api/data -H "Authorization: Bearer $TOKEN"
# Get by key
curl http://localhost:3000/api/data/test-data -H "Authorization: Bearer $TOKEN"
```

**Step 4: Commit**

```bash
git add backend/src/Db/Queries/Data.hs backend/src/Api/Data.hs
git commit -m "feat: implement data CRUD endpoints"
```

---

### Task 7: Group Queries and Handlers

**Files:**
- Create: `backend/src/Db/Queries/Group.hs`
- Create: `backend/src/Api/Group.hs`

**Step 1: Write group queries**

```haskell
-- backend/src/Db/Queries/Group.hs
module Db.Queries.Group where

import Database.Persist
import Database.Persist.Postgresql (ConnectionPool, runSqlPool)
import Data.Text (Text)
import Db.Schema

createGroup :: ConnectionPool -> Key User -> Text -> Bool -> Bool -> IO (Key Group)
createGroup pool uid name canRead canWrite =
  runSqlPool (insert $ Group uid name canRead canWrite) pool

getGroupById :: ConnectionPool -> Key Group -> IO (Maybe Group)
getGroupById pool gid =
  runSqlPool (get gid) pool

updateGroup :: ConnectionPool -> Key Group -> Text -> Bool -> Bool -> IO ()
updateGroup pool gid name canRead canWrite =
  runSqlPool (update gid
    [ GroupName =. name
    , GroupCanRead =. canRead
    , GroupCanWrite =. canWrite
    ]) pool

listUserGroups :: ConnectionPool -> [Int] -> IO [Entity Group]
listUserGroups pool groupIds =
  runSqlPool (selectList [GroupId <-. map (toSqlKey . fromIntegral) groupIds] []) pool

addMember :: ConnectionPool -> Key User -> Int -> IO ()
addMember pool uid groupId = do
  mUser <- runSqlPool (get uid) pool
  case mUser of
    Nothing -> return ()
    Just user ->
      runSqlPool (update uid [UserGroupIds =. (groupId : userGroupIds user)]) pool

removeMember :: ConnectionPool -> Key User -> Int -> IO ()
removeMember pool uid groupId = do
  mUser <- runSqlPool (get uid) pool
  case mUser of
    Nothing -> return ()
    Just user ->
      runSqlPool (update uid [UserGroupIds =. filter (/= groupId) (userGroupIds user)]) pool

seedPublicGroup :: ConnectionPool -> IO ()
seedPublicGroup pool = do
  mGroup <- runSqlPool (getBy $ UniqueGroupName "public") pool
  case mGroup of
    Just _ -> return ()
    Nothing -> do
      -- owner_id 0 = system. We use toSqlKey 0 (no real user).
      _ <- runSqlPool (insert $ Group (toSqlKey 0) "public" True False) pool
      return ()
```

**Step 2: Write group handlers (Api/Group.hs)**

Implement handlers checking ownership for mutations and group membership for reads. Call `seedPublicGroup` from `Db.Migration.runMigrations`.

**Step 3: Build and test with curl**

```bash
stack build
TOKEN="<jwt>"
# Create group
curl -X POST http://localhost:3000/api/groups \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cgrName":"my-group","cgrCanRead":true,"cgrCanWrite":false}'
# List groups
curl http://localhost:3000/api/groups -H "Authorization: Bearer $TOKEN"
```

**Step 4: Commit**

```bash
git add backend/src/Db/Queries/Group.hs backend/src/Api/Group.hs backend/src/Db/Migration.hs
git commit -m "feat: implement group endpoints with public group seeding"
```

---

### Task 8: Public Browsing Endpoint

**Files:**
- Create: `backend/src/Api/Public.hs`

**Step 1: Implement public listing handler**

Handler queries data entries where `group_id` equals the public group's id. Supports optional `search` (ILIKE on key and description) and `sort` query params. Returns `[DataEntrySummary]`.

**Step 2: Build and test**

```bash
stack build
# First assign some data to public group, then:
curl "http://localhost:3000/api/public"
curl "http://localhost:3000/api/public?search=hubble&sort=key"
```

**Step 3: Commit**

```bash
git add backend/src/Api/Public.hs
git commit -m "feat: implement public browsing endpoint with search and sort"
```

---

### Task 9: Wire All Handlers into Main.hs

**Files:**
- Modify: `backend/app/Main.hs`

**Step 1: Replace stubServer with real handlers**

Combine all handler modules into the server, passing `config` and `pool` to each.

**Step 2: Build and run full integration test**

Test the full flow: register → login → create data → assign to public → GET public → search.

**Step 3: Commit**

```bash
git add backend/app/Main.hs
git commit -m "feat: wire all API handlers into server"
```

---

### Task 10: Frontend Scaffolding

**Files:**
- Create: `frontend/elm.json`
- Create: `frontend/src/Main.elm`
- Create: `frontend/src/Types.elm`
- Create: `frontend/index.html`
- Create: `frontend/style.css`

**Step 1: Initialize Elm project**

```bash
cd /Users/carlson/dev/elm-work/scripta/kv-store
mkdir -p frontend/src
cd frontend
elm init
```

**Step 2: Install dependencies**

```bash
elm install elm/http
elm install elm/json
elm install elm/url
elm install elm/browser
elm install elm/time
```

**Step 3: Write Types.elm**

Define `Model`, `Msg`, `Route` types. Model includes: auth token, current page, data entries list, search term, sort column.

**Step 4: Write Main.elm**

`Browser.application` with URL routing:
- `/` → Public page
- `/login` → Login form
- `/register` → Register form
- `/my-data` → Authenticated user's entries
- `/groups` → Group management

**Step 5: Write index.html and style.css**

Minimal HTML host page with Elm embed. Minimal CSS for table, forms, layout.

**Step 6: Build**

Run: `cd /Users/carlson/dev/elm-work/scripta/kv-store/frontend && elm make src/Main.elm --output=elm.js`
Expected: Compiles.

**Step 7: Commit**

```bash
git add frontend/
git commit -m "feat: scaffold Elm frontend with routing"
```

---

### Task 11: Frontend API Module and Auth

**Files:**
- Create: `frontend/src/Api.elm`
- Create: `frontend/src/Auth.elm`

**Step 1: Write Api.elm**

JSON decoders/encoders matching the backend Types.hs. HTTP functions for each endpoint. Token passed via `Http.header "Authorization"`.

**Step 2: Write Auth.elm**

Login and register forms. On success, store JWT in Model (and via port to localStorage). Show/hide UI based on auth state.

**Step 3: Write ports for localStorage**

```elm
port saveToken : String -> Cmd msg
port loadToken : (String -> msg) -> Sub msg
```

Add corresponding JS in index.html.

**Step 4: Build and test**

Verify login/register flow works against running backend.

**Step 5: Commit**

```bash
git add frontend/src/Api.elm frontend/src/Auth.elm frontend/index.html
git commit -m "feat: implement frontend auth with JWT localStorage"
```

---

### Task 12: Frontend Public Page

**Files:**
- Create: `frontend/src/Page/Public.elm`
- Create: `frontend/src/View/Table.elm`
- Create: `frontend/src/View/Search.elm`

**Step 1: Write Table.elm**

Reusable sortable table view. Columns: key, data_type, description, created, modified. Click column header to sort. Takes a list of records and current sort state.

**Step 2: Write Search.elm**

Search input that filters displayed entries by key and description (client-side).

**Step 3: Write Public.elm**

Page that fetches `GET /api/public` on init, displays via Table.elm, with Search.elm above it.

**Step 4: Build and test**

```bash
elm make src/Main.elm --output=elm.js
```

Open in browser, verify public data table shows, sort and search work.

**Step 5: Commit**

```bash
git add frontend/src/Page/Public.elm frontend/src/View/
git commit -m "feat: implement public data browsing page with sort and search"
```

---

### Task 13: Frontend Authenticated Pages

**Files:**
- Create: `frontend/src/Page/MyData.elm`
- Create: `frontend/src/Page/DataDetail.elm`
- Create: `frontend/src/Page/Groups.elm`

**Step 1: Write MyData.elm**

Lists user's own data entries. "New Entry" button opens create form. Each row has edit/delete actions.

**Step 2: Write DataDetail.elm**

View/edit form for a single data entry. Shows all fields. Save button calls PUT. Group assignment dropdown.

**Step 3: Write Groups.elm**

Lists user's groups. Create group form. Manage members.

**Step 4: Build and test full flow**

Register → Login → Create entry → View in MyData → Assign to public → See in Public page.

**Step 5: Commit**

```bash
git add frontend/src/Page/
git commit -m "feat: implement authenticated pages (MyData, DataDetail, Groups)"
```

---

### Task 14: CORS and Final Integration

**Files:**
- Modify: `backend/app/Main.hs` (CORS config)

**Step 1: Configure proper CORS**

Replace `simpleCors` with a policy that allows the frontend origin, Authorization header, and all used methods.

**Step 2: End-to-end test**

Run backend on port 3000, serve frontend on a different port. Test full flow through the browser.

**Step 3: Commit**

```bash
git add backend/app/Main.hs
git commit -m "feat: configure CORS for frontend integration"
```

---

## Summary

| Task | What | Depends On |
|------|------|------------|
| 1 | Backend scaffolding (Stack, config) | — |
| 2 | DB schema + migrations | 1 |
| 3 | Servant API types + Warp stub | 1 |
| 4 | Auth module (JWT, bcrypt) | 1 |
| 5 | Auth endpoint handlers | 2, 3, 4 |
| 6 | Data CRUD queries + handlers | 2, 3, 4 |
| 7 | Group queries + handlers | 2, 3, 4 |
| 8 | Public browsing endpoint | 6, 7 |
| 9 | Wire all handlers into Main | 5, 6, 7, 8 |
| 10 | Frontend scaffolding | — |
| 11 | Frontend API + auth | 10 |
| 12 | Frontend public page | 11 |
| 13 | Frontend authenticated pages | 11 |
| 14 | CORS + integration | 9, 13 |
