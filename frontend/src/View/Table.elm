module View.Table exposing (viewTable)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


viewTable : SortField -> SortDirection -> List DataEntrySummary -> Html Msg
viewTable sortField sortDirection entries =
    let
        sortedEntries =
            sortEntries sortField sortDirection entries
    in
    table [ class "data-table" ]
        [ thead []
            [ tr []
                [ sortableHeader "Key" SortByKey sortField sortDirection
                , th [] [ text "Type" ]
                , th [] [ text "Description" ]
                , sortableHeader "Created" SortByCreated sortField sortDirection
                , sortableHeader "Modified" SortByModified sortField sortDirection
                ]
            ]
        , tbody []
            (List.map viewRow sortedEntries)
        ]


sortableHeader : String -> SortField -> SortField -> SortDirection -> Html Msg
sortableHeader label field activeField direction =
    let
        indicator =
            if field == activeField then
                case direction of
                    Ascending ->
                        " \u{25B2}"

                    Descending ->
                        " \u{25BC}"

            else
                ""
    in
    th [ onClick (SetSort field), style "cursor" "pointer" ]
        [ text (label ++ indicator) ]


viewRow : DataEntrySummary -> Html Msg
viewRow entry =
    tr []
        [ td [] [ text entry.key ]
        , td [] [ text entry.dataType ]
        , td [] [ text entry.description ]
        , td [] [ text entry.createdAt ]
        , td [] [ text entry.modifiedAt ]
        ]


sortEntries : SortField -> SortDirection -> List DataEntrySummary -> List DataEntrySummary
sortEntries field direction entries =
    let
        selector =
            case field of
                SortByKey ->
                    .key

                SortByCreated ->
                    .createdAt

                SortByModified ->
                    .modifiedAt

        sorted =
            List.sortBy selector entries
    in
    case direction of
        Ascending ->
            sorted

        Descending ->
            List.reverse sorted
