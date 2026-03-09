module Auth exposing (viewLogin, viewRegister)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


viewLogin : LoginModel -> Html Msg
viewLogin loginModel =
    div [ class "auth-form" ]
        [ h2 [] [ text "Login" ]
        , div [ class "form-group" ]
            [ label [ for "login-email" ] [ text "Email" ]
            , input
                [ id "login-email"
                , type_ "email"
                , placeholder "Email"
                , value loginModel.email
                , onInput SetLoginEmail
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [ for "login-password" ] [ text "Password" ]
            , input
                [ id "login-password"
                , type_ "password"
                , placeholder "Password"
                , value loginModel.password
                , onInput SetLoginPassword
                ]
                []
            ]
        , button [ onClick SubmitLogin, class "btn" ] [ text "Login" ]
        ]


viewRegister : RegisterModel -> Html Msg
viewRegister registerModel =
    div [ class "auth-form" ]
        [ h2 [] [ text "Register" ]
        , div [ class "form-group" ]
            [ label [ for "register-name" ] [ text "Name" ]
            , input
                [ id "register-name"
                , type_ "text"
                , placeholder "Name"
                , value registerModel.name
                , onInput SetRegisterName
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [ for "register-email" ] [ text "Email" ]
            , input
                [ id "register-email"
                , type_ "email"
                , placeholder "Email"
                , value registerModel.email
                , onInput SetRegisterEmail
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [ for "register-password" ] [ text "Password" ]
            , input
                [ id "register-password"
                , type_ "password"
                , placeholder "Password"
                , value registerModel.password
                , onInput SetRegisterPassword
                ]
                []
            ]
        , button [ onClick SubmitRegister, class "btn" ] [ text "Register" ]
        ]
