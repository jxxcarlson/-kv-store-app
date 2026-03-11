module Render.Utility exposing (blockIdAndStyle, getArg, idAttr, rlBlockSync, rlQBlockSync, rlSync)

{-| Utility functions for rendering.
-}

import Dict
import Html exposing (Attribute)
import Html.Attributes as HA
import Html.Events as HE
import Json.Decode as Decode
import List.Extra
import V3.Types exposing (ExpressionBlock, Msg)


rlSync : V3.Types.ExprMeta -> List (Html.Attribute V3.Types.Msg)
rlSync meta =
    [ HA.id meta.id
    , HA.attribute "data-begin" (String.fromInt meta.begin)
    , HA.attribute "data-end" (String.fromInt meta.end)
    ]


rlBlockSync : V3.Types.BlockMeta -> List (Html.Attribute V3.Types.Msg)
rlBlockSync blockMeta =
    [ HA.attribute "data-begin" "0"
    , HA.attribute "data-end" "0"
    ]


{-| Click handler for Q blocks: sends HighlightId for the paired answer block
instead of SendBlockMeta, so clicking toggles visibility rather than opening the editor.
-}
rlQBlockSync : String -> List (Html.Attribute V3.Types.Msg)
rlQBlockSync answerId =
    [ HE.stopPropagationOn "click"
        (Decode.succeed ( V3.Types.HighlightId answerId, True ))
    ]


{-| Create an id attribute from block id.
-}
idAttr : String -> Attribute msg
idAttr id =
    HA.id id


{-| Make an ID string from components.
-}
makeId : String -> String -> String
makeId prefix suffix =
    prefix ++ "-" ++ suffix


{-| Compute the DOM id and CSS class for a block.

If the block has a `mark` property, use its value as the DOM id
and add a "scripta-mark" class for CSS-based highlighting.
Otherwise, fall back to the block's meta id.

Selection highlighting is handled via a dynamic <style> element
in the host app, not inline styles.

-}
blockIdAndStyle : ExpressionBlock -> List (Attribute Msg)
blockIdAndStyle block =
    case Dict.get "mark" block.properties of
        Just markId ->
            [ HA.id markId, HA.class "scripta-mark" ]

        Nothing ->
            [ HA.id block.meta.id ]


getArg : String -> Int -> List String -> String
getArg default index args =
    case List.Extra.getAt index args of
        Nothing ->
            default

        Just a ->
            a
