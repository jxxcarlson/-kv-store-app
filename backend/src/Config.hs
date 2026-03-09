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
