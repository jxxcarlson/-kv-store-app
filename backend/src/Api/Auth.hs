{-# LANGUAGE OverloadedStrings #-}

module Api.Auth (authHandlers) where

import Control.Monad.IO.Class (liftIO)
import Data.Text (Text, pack)
import Data.Time.Clock (addUTCTime, getCurrentTime)
import Data.UUID (toText)
import Data.UUID.V4 (nextRandom)
import Database.Persist (entityKey, entityVal, insert_)
import Database.Persist.Postgresql (ConnectionPool, fromSqlKey, runSqlPool, toSqlKey)
import Database.Persist.Sql (selectFirst, (==.))
import Servant

import Api (AuthAPI)
import Auth (checkPassword, createToken, hashPassword)
import Config (AppConfig)
import Db.Schema
import Db.Queries.User (createUser, getUserByEmail)
import Types

authHandlers :: AppConfig -> ConnectionPool -> ServerT AuthAPI Handler
authHandlers config pool =
       registerHandler config pool
  :<|> loginHandler config pool
  :<|> refreshHandler config pool

-- | Register a new user, return JWT + refresh token
registerHandler :: AppConfig -> ConnectionPool -> RegisterRequest -> Handler AuthResponse
registerHandler config pool req = do
  mHash <- liftIO $ hashPassword (registerPassword req)
  passHash <- case mHash of
    Nothing -> throwError err500 { errBody = "Failed to hash password" }
    Just h  -> return h
  userId <- liftIO $ createUser pool (registerName req) (registerEmail req) passHash
  makeAuthResponse config pool (fromIntegral (fromSqlKey userId))

-- | Log in an existing user by email + password
loginHandler :: AppConfig -> ConnectionPool -> LoginRequest -> Handler AuthResponse
loginHandler config pool req = do
  mUser <- liftIO $ getUserByEmail pool (loginEmail req)
  case mUser of
    Nothing -> throwError err401 { errBody = "Invalid email or password" }
    Just entity -> do
      let user = entityVal entity
      if checkPassword (userPasswordHash user) (loginPassword req)
        then makeAuthResponse config pool (fromIntegral (fromSqlKey (entityKey entity)))
        else throwError err401 { errBody = "Invalid email or password" }

-- | Exchange a valid refresh token for a new JWT
refreshHandler :: AppConfig -> ConnectionPool -> RefreshRequest -> Handler AuthResponse
refreshHandler config pool req = do
  now <- liftIO getCurrentTime
  mToken <- liftIO $ runSqlPool
    (selectFirst [ RefreshTokenToken ==. refreshToken req ] [])
    pool
  case mToken of
    Nothing -> throwError err401 { errBody = "Invalid refresh token" }
    Just entity -> do
      let rt = entityVal entity
      if refreshTokenExpiresAt rt < now
        then throwError err401 { errBody = "Refresh token expired" }
        else do
          let uid = fromIntegral (fromSqlKey (refreshTokenUserId rt)) :: Int
          eToken <- liftIO $ createToken config uid
          case eToken of
            Left _  -> throwError err500 { errBody = "Failed to create token" }
            Right jwt -> return $ AuthResponse jwt (refreshToken req)

-- | Helper: create a JWT and a new refresh token, store it, return AuthResponse
makeAuthResponse :: AppConfig -> ConnectionPool -> Int -> Handler AuthResponse
makeAuthResponse config pool userId = do
  eToken <- liftIO $ createToken config userId
  jwt <- case eToken of
    Left _  -> throwError err500 { errBody = "Failed to create token" }
    Right t -> return t
  uuid <- liftIO nextRandom
  now  <- liftIO getCurrentTime
  let refreshTok = toText uuid
      expiresAt  = addUTCTime (7 * 24 * 3600) now
      userKey    = toSqlKey (fromIntegral userId)
  liftIO $ runSqlPool (insert_ $ RefreshToken userKey refreshTok expiresAt) pool
  return $ AuthResponse jwt refreshTok
