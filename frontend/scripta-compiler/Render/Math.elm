module Render.Math exposing
    ( DisplayMode(..)
    , mathText
    )

{-| Math rendering using math-text custom web component.

Adapted from V2 Render.Math module.

-}

import Html exposing (Html)
import Html.Attributes as HA
import Html.Keyed
import Json.Encode


type DisplayMode
    = InlineMathMode
    | DisplayMathMode


{-| Render math using the math-text custom element.

The generation parameter ensures KaTeX re-renders on content changes.
Uses Html.Keyed to force re-render when generation changes.

-}
mathText : Int -> String -> DisplayMode -> String -> Html msg
mathText generation id displayMode content =
    Html.Keyed.node "span"
        [ HA.style "padding-top" "0px"
        , HA.style "padding-bottom" "0px"
        , HA.id id
        ]
        [ ( String.fromInt generation, mathText_ displayMode content )
        ]


{-| Create the math-text custom element node.
-}
mathText_ : DisplayMode -> String -> Html msg
mathText_ displayMode content =
    Html.node "math-text"
        [ HA.property "display" (Json.Encode.bool (isDisplayMathMode displayMode))
        , HA.property "content" (Json.Encode.string content)
        ]
        []


{-| Convert DisplayMode to bool for the custom element.
-}
isDisplayMathMode : DisplayMode -> Bool
isDisplayMathMode displayMode =
    case displayMode of
        InlineMathMode ->
            False

        DisplayMathMode ->
            True
