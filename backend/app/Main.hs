module Main where

import Config (loadConfig, configPort)

main :: IO ()
main = do
  config <- loadConfig
  putStrLn $ "KV Store starting on port " ++ show (configPort config)
