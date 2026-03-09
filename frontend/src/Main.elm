module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)
import Url
import Url.Parser as Parser exposing ((</>))


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        route =
            parseRoute url

        model =
            { key = key
            , url = url
            , page = routeToPage route
            , token = Nothing
            , errorMessage = Nothing
            }
    in
    ( model, Cmd.none )


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
            in
            ( { model | url = url, page = routeToPage route }, Cmd.none )

        _ ->
            ( model, Cmd.none )


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
                    PublicPage _ ->
                        text "Public page (TODO)"

                    LoginPage _ ->
                        text "Login page (TODO)"

                    RegisterPage _ ->
                        text "Register page (TODO)"

                    MyDataPage _ ->
                        text "My Data page (TODO)"

                    GroupsPage _ ->
                        text "Groups page (TODO)"

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
