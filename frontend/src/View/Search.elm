module View.Search exposing (viewSearch)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


viewSearch : String -> Html Msg
viewSearch searchTerm =
    div [ class "search-bar" ]
        [ input
            [ type_ "text"
            , placeholder "Search by key or description..."
            , value searchTerm
            , onInput SetSearchTerm
            ]
            []
        ]
