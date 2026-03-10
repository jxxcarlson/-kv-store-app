{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Auth
  ( hashPassword
  , checkPassword
  , createToken
  , validateToken
  ) where

import Control.Exception (SomeException, try)
import Control.Lens (preview, review, set, view)
import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Crypto.JOSE.JWA.JWS (Alg(HS256))
import Crypto.JWT
  ( ClaimsSet
  , JWK
  , JWTError
  , NumericDate(..)
  , SignedJWT
  , claimExp
  , claimIat
  , claimSub
  , decodeCompact
  , defaultJWTValidationSettings
  , emptyClaimsSet
  , encodeCompact
  , fromOctets
  , newJWSHeader
  , runJOSE
  , signClaims
  , string
  , verifyClaims
  )
import Data.ByteString.Lazy (fromStrict, toStrict)
import Data.Text (Text, pack, unpack)
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.Time.Clock (addUTCTime, getCurrentTime)

import Config (AppConfig(..))

-- | Hash a password using bcrypt
hashPassword :: Text -> IO (Maybe Text)
hashPassword plaintext = do
  result <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (encodeUtf8 plaintext)
  return $ fmap decodeUtf8 result

-- | Check a plaintext password against a bcrypt hash
checkPassword :: Text -> Text -> Bool
checkPassword hash plaintext =
  validatePassword (encodeUtf8 hash) (encodeUtf8 plaintext)

-- | Build a JWK from the JWT secret in AppConfig
mkJwk :: AppConfig -> JWK
mkJwk config = fromOctets (encodeUtf8 (pack (configJwtSecret config)))

-- | Create a JWT token with the user ID as the subject claim, 1 hour expiry
createToken :: AppConfig -> Int -> IO (Either SomeException Text)
createToken config userId = try $ do
  now <- getCurrentTime
  let expiry = addUTCTime (4 * 3600) now
      claims = set claimSub (Just (review string (pack (show userId))))
             . set claimIat (Just (NumericDate now))
             . set claimExp (Just (NumericDate expiry))
             $ emptyClaimsSet
      jwk = mkJwk config
      header = newJWSHeader ((), HS256)
  result <- runJOSE (signClaims jwk header claims) :: IO (Either JWTError SignedJWT)
  case result of
    Left e -> error (show e)
    Right signed -> return $ decodeUtf8 (toStrict (encodeCompact signed))

-- | Validate a JWT token and extract the user ID from the subject claim
validateToken :: AppConfig -> Text -> IO (Either SomeException Int)
validateToken config token = try $ do
  let jwk = mkJwk config
      audCheck = const True
      settings = defaultJWTValidationSettings audCheck
      compact = fromStrict (encodeUtf8 token)
  result <- runJOSE $ do
    jwt <- decodeCompact compact
    verifyClaims settings jwk (jwt :: SignedJWT)
    :: IO (Either JWTError ClaimsSet)
  case result of
    Left e -> error (show e)
    Right claims -> do
      case view claimSub claims of
        Nothing -> error "No subject claim in token"
        Just sub -> do
          case preview string sub of
            Nothing -> error "Subject claim is not a string"
            Just subText -> return (read (unpack subText) :: Int)
