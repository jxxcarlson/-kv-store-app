port module Main exposing (main)

import Api
import Auth
import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode
import Page.Groups
import Page.MyData
import Page.Public
import Types exposing (..)
import View.Table
import Url
import Url.Parser as Parser exposing ((</>))


port saveToken : String -> Cmd msg


port removeToken : () -> Cmd msg


port scrollToElement : String -> Cmd msg


port uploadBlob : { key : String, token : String } -> Cmd msg


port blobUploaded : (Bool -> msg) -> Sub msg


port fetchBlob : { url : String, token : String } -> Cmd msg


port gotBlobUrl : (String -> msg) -> Sub msg


type alias Flags =
    { token : Maybe String
    , apiBase : String
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions =
            \_ ->
                Sub.batch
                    [ blobUploaded GotBlobUpload
                    , gotBlobUrl GotBlobUrl
                    ]
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        token =
            case flags.token of
                Just t ->
                    if String.isEmpty t then
                        Nothing

                    else
                        Just t

                Nothing ->
                    Nothing

        route =
            parseRoute url

        model =
            { key = key
            , url = url
            , page = routeToPage route
            , token = token
            , errorMessage = Nothing
            , apiBase = flags.apiBase
            }

        cmd =
            cmdForRoute flags.apiBase route token
    in
    ( model, cmd )


cmdForRoute : String -> Route -> Maybe String -> Cmd Msg
cmdForRoute apiBase route token =
    case route of
        PublicRoute ->
            Api.fetchPublicEntries apiBase Nothing Nothing

        MyDataRoute ->
            case token of
                Just t ->
                    Api.fetchMyEntries apiBase t

                Nothing ->
                    Cmd.none

        GroupsRoute ->
            case token of
                Just t ->
                    Api.fetchGroups apiBase t

                Nothing ->
                    Cmd.none

        _ ->
            Cmd.none


parseRoute : Url.Url -> Route
parseRoute url =
    Maybe.withDefault NotFoundRoute (Parser.parse routeParser url)


routeParser : Parser.Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map PublicRoute Parser.top
        , Parser.map LoginRoute (Parser.s "login")
        , Parser.map RegisterRoute (Parser.s "register")
        , Parser.map MyDataRoute (Parser.s "my-data")
        , Parser.map GroupsRoute (Parser.s "groups")
        ]


routeToPage : Route -> Page
routeToPage route =
    case route of
        PublicRoute ->
            PublicPage { entries = [], searchTerm = "", sortBy = SortByKey, sortDirection = Ascending, expandedEntry = Nothing, displayMode = Raw }

        LoginRoute ->
            LoginPage { email = "", password = "" }

        RegisterRoute ->
            RegisterPage { name = "", email = "", password = "" }

        MyDataRoute ->
            MyDataPage { entries = [], showCreateForm = False, createForm = emptyCreateForm, expandedEntry = Nothing, displayMode = Raw, searchTerm = "", editingValue = Nothing }

        GroupsRoute ->
            GroupsPage { groups = [] }

        NotFoundRoute ->
            NotFoundPage


isPage : Page -> Route -> Bool
isPage page route =
    case ( page, route ) of
        ( PublicPage _, PublicRoute ) -> True
        ( LoginPage _, LoginRoute ) -> True
        ( RegisterPage _, RegisterRoute ) -> True
        ( MyDataPage _, MyDataRoute ) -> True
        ( GroupsPage _, GroupsRoute ) -> True
        _ -> False


handleAuthError : Model -> String -> Http.Error -> ( Model, Cmd Msg )
handleAuthError model fallbackMsg error =
    case error of
        Http.BadStatus 401 ->
            ( { model | token = Nothing, errorMessage = Nothing }
            , Cmd.batch
                [ removeToken ()
                , Nav.pushUrl model.key "/"
                ]
            )

        _ ->
            ( { model | errorMessage = Just fallbackMsg }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    if url.path == model.url.path then
                        -- Fragment-only change (e.g. TOC links) — don't navigate away
                        ( model, Cmd.none )

                    else
                        ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    parseRoute url

                cmd =
                    cmdForRoute model.apiBase route model.token
            in
            ( { model | url = url, page = routeToPage route, errorMessage = Nothing }, cmd )

        NoOp ->
            ( model, Cmd.none )

        ScrollToId id ->
            ( model, scrollToElement id )

        -- Auth: Login form
        SetLoginEmail email ->
            case model.page of
                LoginPage loginModel ->
                    ( { model | page = LoginPage { loginModel | email = email } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetLoginPassword password ->
            case model.page of
                LoginPage loginModel ->
                    ( { model | page = LoginPage { loginModel | password = password } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SubmitLogin ->
            case model.page of
                LoginPage loginModel ->
                    ( { model | errorMessage = Nothing }, Api.login model.apiBase loginModel )

                _ ->
                    ( model, Cmd.none )

        -- Auth: Register form
        SetRegisterName name ->
            case model.page of
                RegisterPage registerModel ->
                    ( { model | page = RegisterPage { registerModel | name = name } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetRegisterEmail email ->
            case model.page of
                RegisterPage registerModel ->
                    ( { model | page = RegisterPage { registerModel | email = email } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetRegisterPassword password ->
            case model.page of
                RegisterPage registerModel ->
                    ( { model | page = RegisterPage { registerModel | password = password } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SubmitRegister ->
            case model.page of
                RegisterPage registerModel ->
                    ( { model | errorMessage = Nothing }, Api.register model.apiBase registerModel )

                _ ->
                    ( model, Cmd.none )

        -- Auth: Response
        GotAuthResponse result ->
            case result of
                Ok response ->
                    ( { model | token = Just response.token, errorMessage = Nothing }
                    , Cmd.batch
                        [ saveToken response.token
                        , Nav.pushUrl model.key "/my-data"
                        ]
                    )

                Err _ ->
                    ( { model | errorMessage = Just "Authentication failed. Please check your credentials." }
                    , Cmd.none
                    )

        Logout ->
            ( { model | token = Nothing, errorMessage = Nothing }
            , Cmd.batch
                [ removeToken ()
                , Nav.pushUrl model.key "/"
                ]
            )

        -- Public
        SetSearchTerm term ->
            case model.page of
                PublicPage publicModel ->
                    ( { model | page = PublicPage { publicModel | searchTerm = term } }, Cmd.none )

                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | searchTerm = term } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetSort field ->
            case model.page of
                PublicPage publicModel ->
                    ( { model | page = PublicPage { publicModel | sortBy = field } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotPublicEntries result ->
            case result of
                Ok entries ->
                    case model.page of
                        PublicPage publicModel ->
                            ( { model | page = PublicPage { publicModel | entries = entries } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    ( { model | errorMessage = Just "Failed to load public entries." }, Cmd.none )

        -- My Data
        GotMyEntries result ->
            case result of
                Ok entries ->
                    case model.page of
                        MyDataPage myDataModel ->
                            ( { model | page = MyDataPage { myDataModel | entries = entries } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to load your entries." err

        ToggleCreateForm ->
            case model.page of
                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | showCreateForm = not myDataModel.showCreateForm } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetCreateField fieldName fieldValue ->
            case model.page of
                MyDataPage myDataModel ->
                    let
                        form =
                            myDataModel.createForm

                        updatedForm =
                            case fieldName of
                                "key" ->
                                    { form | key = fieldValue }

                                "dataType" ->
                                    { form | dataType = fieldValue }

                                "properties" ->
                                    { form | properties = fieldValue }

                                "description" ->
                                    { form | description = fieldValue }

                                "value" ->
                                    { form | value = fieldValue }

                                _ ->
                                    form
                    in
                    ( { model | page = MyDataPage { myDataModel | createForm = updatedForm } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SubmitCreateData ->
            case ( model.page, model.token ) of
                ( MyDataPage myDataModel, Just token ) ->
                    ( model, Api.createDataEntry model.apiBase token myDataModel.createForm )

                _ ->
                    ( model, Cmd.none )

        GotCreateResponse result ->
            case result of
                Ok newEntry ->
                    case model.page of
                        MyDataPage myDataModel ->
                            let
                                uploadCmd =
                                    if List.member newEntry.dataType [ "pdf", "jpg", "jpeg", "png", "webp", "mp3" ] then
                                        case model.token of
                                            Just token ->
                                                uploadBlob { key = newEntry.key, token = token }

                                            Nothing ->
                                                Cmd.none

                                    else
                                        Cmd.none
                            in
                            ( { model
                                | page =
                                    MyDataPage
                                        { myDataModel
                                            | entries = myDataModel.entries ++ [ newEntry ]
                                            , showCreateForm = False
                                            , createForm = emptyCreateForm
                                        }
                              }
                            , uploadCmd
                            )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to create entry." err

        DeleteEntry key ->
            case model.token of
                Just token ->
                    ( model, Api.deleteDataEntry model.apiBase token key )

                Nothing ->
                    ( model, Cmd.none )

        GotDeleteResponse result ->
            case result of
                Ok _ ->
                    case ( model.page, model.token ) of
                        ( MyDataPage _, Just token ) ->
                            ( model, Api.fetchMyEntries model.apiBase token )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to delete entry." err

        MakePublic key ->
            case model.token of
                Just token ->
                    ( model, Api.assignToPublicGroup model.apiBase token key )

                Nothing ->
                    ( model, Cmd.none )

        MakePrivate key ->
            case model.token of
                Just token ->
                    ( model, Api.removeFromPublicGroup model.apiBase token key )

                Nothing ->
                    ( model, Cmd.none )

        GotMakePublicResponse result ->
            case result of
                Ok _ ->
                    case ( model.page, model.token ) of
                        ( MyDataPage _, Just token ) ->
                            ( { model | errorMessage = Nothing }, Api.fetchMyEntries model.apiBase token )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to update entry visibility." err

        -- Expand entry
        ToggleExpandEntry key ->
            case model.page of
                PublicPage publicModel ->
                    case publicModel.expandedEntry of
                        Just ex ->
                            if ex.key == key then
                                ( { model | page = PublicPage { publicModel | expandedEntry = Nothing } }, Cmd.none )

                            else
                                ( model, Api.fetchPublicEntryValue model.apiBase key )

                        Nothing ->
                            ( model, Api.fetchPublicEntryValue model.apiBase key )

                MyDataPage myDataModel ->
                    case myDataModel.expandedEntry of
                        Just ex ->
                            if ex.key == key then
                                ( { model | page = MyDataPage { myDataModel | expandedEntry = Nothing } }, Cmd.none )

                            else
                                case model.token of
                                    Just token ->
                                        ( model, Api.fetchEntryValue model.apiBase token key )

                                    Nothing ->
                                        ( model, Cmd.none )

                        Nothing ->
                            case model.token of
                                Just token ->
                                    ( model, Api.fetchEntryValue model.apiBase token key )

                                Nothing ->
                                    ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotEntryValue result ->
            case result of
                Ok entry ->
                    let
                        defaultMode =
                            if View.Table.hasRenderedView entry.dataType then
                                Rendered

                            else
                                Raw

                        binaryCmd =
                            if View.Table.isBinaryType entry.dataType then
                                case model.token of
                                    Just token ->
                                        fetchBlob { url = model.apiBase ++ "/api/data/" ++ entry.key ++ "/blob", token = token }

                                    Nothing ->
                                        Cmd.none

                            else
                                Cmd.none
                    in
                    case model.page of
                        PublicPage publicModel ->
                            let
                                publicBlobUrl =
                                    if View.Table.isBinaryType entry.dataType then
                                        Just (model.apiBase ++ "/api/public/" ++ entry.key ++ "/blob")

                                    else
                                        Nothing

                                updatedEntry =
                                    { entry | blobObjectUrl = publicBlobUrl }
                            in
                            ( { model | page = PublicPage { publicModel | expandedEntry = Just updatedEntry, displayMode = defaultMode } }, Cmd.none )

                        MyDataPage myDataModel ->
                            ( { model | page = MyDataPage { myDataModel | expandedEntry = Just entry, displayMode = defaultMode } }, binaryCmd )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to load entry value." err

        ToggleDisplayMode ->
            let
                toggle mode =
                    case mode of
                        Raw ->
                            Rendered

                        Rendered ->
                            Raw
            in
            case model.page of
                PublicPage publicModel ->
                    ( { model | page = PublicPage { publicModel | displayMode = toggle publicModel.displayMode } }, Cmd.none )

                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | displayMode = toggle myDataModel.displayMode } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        -- Groups
        GotGroups result ->
            case result of
                Ok groups ->
                    case model.page of
                        GroupsPage _ ->
                            ( { model | page = GroupsPage { groups = groups } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err err ->
                    handleAuthError model "Failed to load groups." err

        GotBlobUpload success ->
            if success then
                case ( model.page, model.token ) of
                    ( MyDataPage _, Just token ) ->
                        ( model, Api.fetchMyEntries model.apiBase token )

                    _ ->
                        ( model, Cmd.none )

            else
                ( { model | errorMessage = Just "Failed to upload file." }, Cmd.none )

        GotBlobUrl url ->
            if String.isEmpty url then
                ( { model | errorMessage = Just "Failed to load file." }, Cmd.none )

            else
                case model.page of
                    PublicPage publicModel ->
                        case publicModel.expandedEntry of
                            Just ex ->
                                ( { model | page = PublicPage { publicModel | expandedEntry = Just { ex | blobObjectUrl = Just url } } }, Cmd.none )

                            Nothing ->
                                ( model, Cmd.none )

                    MyDataPage myDataModel ->
                        case myDataModel.expandedEntry of
                            Just ex ->
                                ( { model | page = MyDataPage { myDataModel | expandedEntry = Just { ex | blobObjectUrl = Just url } } }, Cmd.none )

                            Nothing ->
                                ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )

        StartEditing currentValue ->
            case model.page of
                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | editingValue = Just currentValue } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SetEditValue val ->
            case model.page of
                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | editingValue = Just val } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CancelEdit ->
            case model.page of
                MyDataPage myDataModel ->
                    ( { model | page = MyDataPage { myDataModel | editingValue = Nothing } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SaveEdit ->
            case ( model.page, model.token ) of
                ( MyDataPage myDataModel, Just token ) ->
                    case ( myDataModel.expandedEntry, myDataModel.editingValue ) of
                        ( Just entry, Just newValue ) ->
                            ( model, Api.updateDataEntry model.apiBase token entry.key newValue )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotSaveResponse result ->
            case ( model.page, model.token ) of
                ( MyDataPage myDataModel, Just token ) ->
                    case result of
                        Ok _ ->
                            case myDataModel.expandedEntry of
                                Just entry ->
                                    ( { model | page = MyDataPage { myDataModel | editingValue = Nothing } }
                                    , Api.fetchEntryValue model.apiBase token entry.key
                                    )

                                Nothing ->
                                    ( { model | page = MyDataPage { myDataModel | editingValue = Nothing } }, Cmd.none )

                        Err _ ->
                            ( { model | errorMessage = Just "Failed to save changes." }, Cmd.none )

                _ ->
                    ( model, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "Key-Value Store"
    , body =
        [ div [ class "app" ]
            [ nav [ class "navbar" ]
                [ a [ href "/" ] [ text "Key-Value Store" ]
                , div [ class "nav-links" ]
                    [ a [ href "/", classList [ ( "nav-active", isPage model.page PublicRoute ) ] ] [ text "Public" ]
                    , case model.token of
                        Nothing ->
                            span []
                                [ a [ href "/login", classList [ ( "nav-active", isPage model.page LoginRoute ) ] ] [ text "Login" ]
                                , a [ href "/register", classList [ ( "nav-active", isPage model.page RegisterRoute ) ] ] [ text "Register" ]
                                ]

                        Just _ ->
                            span []
                                [ a [ href "/my-data", classList [ ( "nav-active", isPage model.page MyDataRoute ) ] ] [ text "My Data" ]
                                , a [ href "/groups", classList [ ( "nav-active", isPage model.page GroupsRoute ) ] ] [ text "Groups" ]
                                , button [ onClick Logout ] [ text "Logout" ]
                                ]
                    ]
                ]
            , div [ class "content" ]
                [ case model.page of
                    PublicPage publicModel ->
                        Page.Public.view publicModel

                    LoginPage loginModel ->
                        Auth.viewLogin loginModel

                    RegisterPage registerModel ->
                        Auth.viewRegister registerModel

                    MyDataPage myDataModel ->
                        Page.MyData.view myDataModel

                    GroupsPage groupsModel ->
                        Page.Groups.view groupsModel

                    NotFoundPage ->
                        text "Page not found"
                ]
            , case model.errorMessage of
                Nothing ->
                    text ""

                Just err ->
                    div [ class "error" ] [ text err ]
            ]
        ]
    }
