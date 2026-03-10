module Types exposing (..)

import Browser
import Browser.Navigation as Nav
import Http
import Url exposing (Url)


type alias Model =
    { key : Nav.Key
    , url : Url
    , page : Page
    , token : Maybe String
    , errorMessage : Maybe String
    }


type Page
    = PublicPage PublicModel
    | LoginPage LoginModel
    | RegisterPage RegisterModel
    | MyDataPage MyDataModel
    | GroupsPage GroupsModel
    | NotFoundPage


type alias PublicModel =
    { entries : List DataEntrySummary
    , searchTerm : String
    , sortBy : SortField
    , sortDirection : SortDirection
    , expandedEntry : Maybe ExpandedEntry
    , displayMode : DisplayMode
    }


type alias LoginModel =
    { email : String
    , password : String
    }


type alias RegisterModel =
    { name : String
    , email : String
    , password : String
    }


type alias MyDataModel =
    { entries : List DataEntrySummary
    , showCreateForm : Bool
    , createForm : CreateDataForm
    , expandedEntry : Maybe ExpandedEntry
    , displayMode : DisplayMode
    , searchTerm : String
    }


type alias GroupsModel =
    { groups : List GroupInfo
    }


type alias CreateDataForm =
    { key : String
    , dataType : String
    , properties : String
    , description : String
    , value : String
    }


emptyCreateForm : CreateDataForm
emptyCreateForm =
    { key = ""
    , dataType = "txt"
    , properties = ""
    , description = ""
    , value = ""
    }


type alias DataEntrySummary =
    { key : String
    , dataType : String
    , description : String
    , createdAt : String
    , modifiedAt : String
    , isPublic : Bool
    }


type alias ExpandedEntry =
    { key : String
    , dataType : String
    , value : String
    }


type DisplayMode
    = Raw
    | Rendered


type alias GroupInfo =
    { id : Int
    , ownerId : Int
    , name : String
    , canRead : Bool
    , canWrite : Bool
    }


type SortField
    = SortByKey
    | SortByCreated
    | SortByModified


type SortDirection
    = Ascending
    | Descending


type Route
    = PublicRoute
    | LoginRoute
    | RegisterRoute
    | MyDataRoute
    | GroupsRoute
    | NotFoundRoute


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | NoOp
      -- Auth
    | SetLoginEmail String
    | SetLoginPassword String
    | SubmitLogin
    | SetRegisterName String
    | SetRegisterEmail String
    | SetRegisterPassword String
    | SubmitRegister
    | GotAuthResponse (Result Http.Error AuthResponse)
    | Logout
      -- Public
    | SetSearchTerm String
    | SetSort SortField
    | GotPublicEntries (Result Http.Error (List DataEntrySummary))
      -- My Data
    | GotMyEntries (Result Http.Error (List DataEntrySummary))
    | ToggleCreateForm
    | SetCreateField String String
    | SubmitCreateData
    | GotCreateResponse (Result Http.Error DataEntrySummary)
    | DeleteEntry String
    | GotDeleteResponse (Result Http.Error ())
    | MakePublic String
    | MakePrivate String
    | GotMakePublicResponse (Result Http.Error ())
    | ToggleExpandEntry String
    | GotEntryValue (Result Http.Error ExpandedEntry)
    | ToggleDisplayMode
      -- Groups
    | GotGroups (Result Http.Error (List GroupInfo))


type alias AuthResponse =
    { token : String
    , refreshToken : String
    }
