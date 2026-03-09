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
