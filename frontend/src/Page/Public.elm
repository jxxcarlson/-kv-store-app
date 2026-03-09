module Page.Public exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)
import View.Search
import View.Table


view : PublicModel -> Html Msg
view publicModel =
    let
        term =
            String.toLower publicModel.searchTerm

        filtered =
            if String.isEmpty term then
                publicModel.entries

            else
                List.filter
                    (\entry ->
                        String.contains term (String.toLower entry.key)
                            || String.contains term (String.toLower entry.description)
                    )
                    publicModel.entries
    in
    div [ class "public-page" ]
        [ h2 [] [ text "Public Data" ]
        , View.Search.viewSearch publicModel.searchTerm
        , View.Table.viewTable publicModel.sortBy publicModel.sortDirection filtered
        ]
