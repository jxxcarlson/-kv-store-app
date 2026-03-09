{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Cors (simpleCors)
import Servant

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

server :: AppConfig -> ConnectionPool -> Server API
server config pool =
  authHandlers config pool
  :<|> (\authHeader -> dataHandlers config pool authHeader :<|> groupHandlers config pool authHeader)
  :<|> publicHandlers pool

app :: AppConfig -> ConnectionPool -> Application
app config pool = simpleCors $ serve apiProxy (server config pool)

main :: IO ()
main = do
  config <- loadConfig
  pool <- createPool config
  runMigrations pool
  putStrLn $ "KV Store starting on port " ++ show (configPort config)
  run (configPort config) (app config pool)
