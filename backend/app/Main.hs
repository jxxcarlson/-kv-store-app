{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Network.Wai (Middleware, pathInfo, requestMethod, responseLBS)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors (cors, simpleCorsResourcePolicy, CorsResourcePolicy(..))
import Network.HTTP.Types (status200)
import Servant
import qualified Data.ByteString.Lazy.Char8 as LBS

import Api (API, apiProxy)
import Api.Auth (authHandlers)
import Api.Data (dataHandlers)
import Api.Group (groupHandlers)
import Api.Public (publicHandlers)
import Config (AppConfig, loadConfig, configPort)
import Db (createPool)
import Db.Migration (runMigrations)
import Database.Persist.Postgresql (ConnectionPool)
import Data.Text (Text)

corsPolicy :: CorsResourcePolicy
corsPolicy = simpleCorsResourcePolicy
  { corsOrigins = Nothing  -- allow all origins
  , corsMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  , corsRequestHeaders = ["Authorization", "Content-Type"]
  }

server :: AppConfig -> ConnectionPool -> Server API
server config pool =
  authHandlers config pool
  :<|> (\authHeader -> dataHandlers config pool authHeader :<|> groupHandlers config pool authHeader)
  :<|> publicHandlers pool

faviconMiddleware :: Middleware
faviconMiddleware nextApp req respond =
  if requestMethod req == "GET" && pathInfo req == ["favicon.ico"]
    then respond $ responseLBS status200
           [("Content-Type", "image/svg+xml")]
           (LBS.pack "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'><text x='50%' y='50%' dominant-baseline='central' text-anchor='middle' font-family='sans-serif' font-size='28' font-weight='bold' fill='yellow'>KS</text></svg>")
    else nextApp req respond

app :: AppConfig -> ConnectionPool -> Application
app config pool = faviconMiddleware $ cors (const $ Just corsPolicy) $ serve apiProxy (server config pool)

main :: IO ()
main = do
  config <- loadConfig
  pool <- createPool config
  runMigrations pool
  putStrLn $ "KV Store starting on port " ++ show (configPort config)
  run (configPort config) (app config pool)
