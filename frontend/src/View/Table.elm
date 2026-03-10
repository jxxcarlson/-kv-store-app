module View.Table exposing (display, displayModeToggle, formatTimestamp, viewTable)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Markdown
import String
import Types exposing (..)


viewTable : SortField -> SortDirection -> Maybe ExpandedEntry -> DisplayMode -> List DataEntrySummary -> Html Msg
viewTable sortField sortDirection expandedEntry displayMode entries =
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
            (List.concatMap (viewRowWithExpansion expandedEntry displayMode) sortedEntries)
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


viewRowWithExpansion : Maybe ExpandedEntry -> DisplayMode -> DataEntrySummary -> List (Html Msg)
viewRowWithExpansion expandedEntry displayMode entry =
    let
        isExpanded =
            case expandedEntry of
                Just ex ->
                    ex.key == entry.key

                Nothing ->
                    False

        dataRow =
            tr []
                [ td [ onClick (ToggleExpandEntry entry.key), style "cursor" "pointer" ] [ text entry.key ]
                , td [] [ text entry.dataType ]
                , td [ onClick (ToggleExpandEntry entry.key), style "cursor" "pointer" ] [ text entry.description ]
                , td [] [ text (formatTimestamp entry.createdAt) ]
                , td [] [ text (formatTimestamp entry.modifiedAt) ]
                ]
    in
    if isExpanded then
        case expandedEntry of
            Just ex ->
                [ dataRow
                , tr [ class "expanded-row" ]
                    [ td [ colspan 5, class "expanded-content" ]
                        [ displayModeToggle ex.dataType displayMode
                        , display ex.dataType displayMode ex.value
                        ]
                    ]
                ]

            Nothing ->
                [ dataRow ]

    else
        [ dataRow ]


hasRenderedView : String -> Bool
hasRenderedView dataType =
    List.member dataType [ "md", "html" ]


displayModeToggle : String -> DisplayMode -> Html Msg
displayModeToggle dataType mode =
    if hasRenderedView dataType then
        let
            label =
                case mode of
                    Raw ->
                        "Source"

                    Rendered ->
                        "Rendered"
        in
        div [ class "display-mode-toggle" ]
            [ button [ onClick ToggleDisplayMode, class "btn btn-small" ] [ text label ]
            ]

    else
        text ""


display : String -> DisplayMode -> String -> Html Msg
display dataType mode content =
    case ( dataType, mode ) of
        ( "md", Rendered ) ->
            div [ class "content-display rendered-content" ]
                (Markdown.toHtml Nothing content)

        ( "html", Rendered ) ->
            div [ class "content-display rendered-content" ]
                [ iframe
                    [ attribute "srcdoc" content
                    , style "width" "100%"
                    , style "border" "none"
                    , style "min-height" "200px"
                    ]
                    []
                ]

        _ ->
            div [ class "content-display" ]
                [ text content ]


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


formatTimestamp : String -> String
formatTimestamp iso =
    case String.split "T" iso of
        [ date, timepart ] ->
            let
                time =
                    timepart
                        |> String.split ":"
                        |> List.take 2
                        |> String.join ":"
            in
            date ++ ", " ++ time

        _ ->
            iso