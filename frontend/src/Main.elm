port module Main exposing (main)

import Api
import Auth
import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Page.Groups
import Page.MyData
import Page.Public
import Types exposing (..)
import Url
import Url.Parser as Parser exposing ((</>))


port saveToken : String -> Cmd msg


port removeToken : () -> Cmd msg


type alias Flags =
    Maybe String


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        token =
            case flags of
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
            }

        cmd =
            cmdForRoute route token
    in
    ( model, cmd )


cmdForRoute : Route -> Maybe String -> Cmd Msg
cmdForRoute route token =
    case route of
        PublicRoute ->
            Api.fetchPublicEntries Nothing Nothing

        MyDataRoute ->
            case token of
                Just t ->
                    Api.fetchMyEntries t

                Nothing ->
                    Cmd.none

        GroupsRoute ->
            case token of
                Just t ->
                    Api.fetchGroups t

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
            PublicPage { entries = [], searchTerm = "", sortBy = SortByKey, sortDirection = Ascending }

        LoginRoute ->
            LoginPage { email = "", password = "" }

        RegisterRoute ->
            RegisterPage { name = "", email = "", password = "" }

        MyDataRoute ->
            MyDataPage { entries = [], showCreateForm = False, createForm = emptyCreateForm }

        GroupsRoute ->
            GroupsPage { groups = [] }

        NotFoundRoute ->
            NotFoundPage


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                route =
                    parseRoute url

                cmd =
                    cmdForRoute route model.token
            in
            ( { model | url = url, page = routeToPage route, errorMessage = Nothing }, cmd )

        NoOp ->
            ( model, Cmd.none )

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
                    ( { model | errorMessage = Nothing }, Api.login loginModel )

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
                    ( { model | errorMessage = Nothing }, Api.register registerModel )

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

                Err _ ->
                    ( { model | errorMessage = Just "Failed to load your entries." }, Cmd.none )

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
                    ( model, Api.createDataEntry token myDataModel.createForm )

                _ ->
                    ( model, Cmd.none )

        GotCreateResponse result ->
            case result of
                Ok newEntry ->
                    case model.page of
                        MyDataPage myDataModel ->
                            ( { model
                                | page =
                                    MyDataPage
                                        { myDataModel
                                            | entries = myDataModel.entries ++ [ newEntry ]
                                            , showCreateForm = False
                                            , createForm = emptyCreateForm
                                        }
                              }
                            , Cmd.none
                            )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    ( { model | errorMessage = Just "Failed to create entry." }, Cmd.none )

        DeleteEntry key ->
            case model.token of
                Just token ->
                    ( model, Api.deleteDataEntry token key )

                Nothing ->
                    ( model, Cmd.none )

        GotDeleteResponse result ->
            case result of
                Ok _ ->
                    case ( model.page, model.token ) of
                        ( MyDataPage _, Just token ) ->
                            ( model, Api.fetchMyEntries token )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    ( { model | errorMessage = Just "Failed to delete entry." }, Cmd.none )

        -- Groups
        GotGroups result ->
            case result of
                Ok groups ->
                    case model.page of
                        GroupsPage _ ->
                            ( { model | page = GroupsPage { groups = groups } }, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Err _ ->
                    ( { model | errorMessage = Just "Failed to load groups." }, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "KV Store"
    , body =
        [ div [ class "app" ]
            [ nav [ class "navbar" ]
                [ a [ href "/" ] [ text "KV Store" ]
                , div [ class "nav-links" ]
                    [ a [ href "/" ] [ text "Public" ]
                    , case model.token of
                        Nothing ->
                            span []
                                [ a [ href "/login" ] [ text "Login" ]
                                , a [ href "/register" ] [ text "Register" ]
                                ]

                        Just _ ->
                            span []
                                [ a [ href "/my-data" ] [ text "My Data" ]
                                , a [ href "/groups" ] [ text "Groups" ]
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
