module Page.Public exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)
import View.Search
import View.Table


view : PublicModel -> Html Msg
view publicModel =
    let
        filtered =
            View.Search.filterEntries publicModel.searchTerm publicModel.entries
    in
    div [ class "public-page" ]
        [ div [ class "page-header" ]
            [ h2 [] [ text "Public Data" ]
            , View.Search.viewSearch publicModel.searchTerm
            ]
        , View.Table.viewTable publicModel.sortBy publicModel.sortDirection publicModel.expandedEntry publicModel.displayMode filtered
        ]
