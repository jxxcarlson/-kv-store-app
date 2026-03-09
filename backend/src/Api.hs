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

-- JWT required
type ProtectedAPI = Header' '[Required] "Authorization" Text :>
  (DataAPI :<|> GroupAPI)

type DataAPI =
       "data" :> Get '[JSON] [DataEntrySummary]
  :<|> "data" :> Capture "key" Text :> Get '[JSON] DataValueResponse
  :<|> "data" :> ReqBody '[JSON] CreateDataRequest :> Post '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> ReqBody '[JSON] UpdateDataRequest :> Put '[JSON] DataEntrySummary
  :<|> "data" :> Capture "key" Text :> Delete '[JSON] NoContent
  :<|> "data" :> Capture "key" Text :> "group" :> ReqBody '[JSON] AssignGroupRequest :> Put '[JSON] NoContent

type GroupAPI =
       "groups" :> Get '[JSON] [GroupResponse]
  :<|> "groups" :> ReqBody '[JSON] CreateGroupRequest :> Post '[JSON] GroupResponse
  :<|> "groups" :> Capture "id" Int :> ReqBody '[JSON] CreateGroupRequest :> Put '[JSON] GroupResponse
  :<|> "groups" :> Capture "id" Int :> "members" :> ReqBody '[JSON] AddMemberRequest :> Post '[JSON] NoContent
  :<|> "groups" :> Capture "id" Int :> "members" :> Capture "uid" Int :> Delete '[JSON] NoContent

-- Public (no auth)
type PublicDataAPI = "public" :>
  (    QueryParam "search" Text :> QueryParam "sort" Text :> Get '[JSON] [DataEntrySummary]
  )

apiProxy :: Proxy API
apiProxy = Proxy
