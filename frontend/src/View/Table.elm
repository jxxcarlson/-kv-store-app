module View.Table exposing (display, displayModeToggle, formatTimestamp, hasRenderedView, isBinaryType, viewTable)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Markdown
import MiniLatex.EditSimple
import String
import Types exposing (..)
import V3.Compiler
import V3.Types exposing (Filter(..), Theme(..))
import V3.Types as VT


viewTable : SortField -> SortDirection -> Maybe ExpandedEntry -> DisplayMode -> List DataEntrySummary -> Html Msg
viewTable sortField sortDirection expandedEntry displayMode entries =
    let
        sortedEntries =
            sortEntries sortField sortDirection entries

        visibleEntries =
            case expandedEntry of
                Just ex ->
                    List.filter (\e -> e.key == ex.key) sortedEntries

                Nothing ->
                    sortedEntries
    in
    div []
        [ table [ class "data-table" ]
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
                (List.map (viewRow expandedEntry) visibleEntries)
            ]
        , expandedPanel expandedEntry displayMode
        ]


viewRow : Maybe ExpandedEntry -> DataEntrySummary -> Html Msg
viewRow expandedEntry entry =
    tr [ onClick (ToggleExpandEntry entry.key), style "cursor" "pointer" ]
        [ td [] [ text entry.key ]
        , td [] [ text entry.dataType ]
        , td [] [ text entry.description ]
        , td [] [ text (formatTimestamp entry.createdAt) ]
        , td [] [ text (formatTimestamp entry.modifiedAt) ]
        ]


expandedPanel : Maybe ExpandedEntry -> DisplayMode -> Html Msg
expandedPanel expandedEntry displayMode =
    case expandedEntry of
        Just ex ->
            let
                extraClass =
                    if ex.dataType == "html" && displayMode == Rendered then
                        " expanded-content-noscroll"

                    else
                        ""
            in
            div [ class ("expanded-content" ++ extraClass) ]
                [ if ex.dataType == "scripta" && displayMode == Rendered then
                    text ""
                  else
                    displayModeToggle ex.dataType displayMode
                , display ex.dataType displayMode ex.value ex.blobObjectUrl
                ]

        Nothing ->
            text ""


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


hasRenderedView : String -> Bool
hasRenderedView dataType =
    List.member dataType [ "md", "html", "scripta", "tex" ]


isBinaryType : String -> Bool
isBinaryType dt =
    List.member dt [ "pdf", "jpg", "jpeg", "png", "webp", "mp3" ]


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


display : String -> DisplayMode -> String -> Maybe String -> Html Msg
display dataType mode content maybeBlobUrl =
    case ( dataType, mode ) of
        ( "pdf", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content iframe-content" ]
                        [ div [ style "margin-bottom" "4px" ]
                            [ a [ href url, target "_blank", class "btn btn-small" ] [ text "expand" ] ]
                        , iframe [ src url, style "width" "100%", style "height" "calc(100vh - 280px)", style "border" "none" ] []
                        ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "jpg", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content" ]
                        [ img [ src url, style "max-width" "100%" ] [] ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "png", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content" ]
                        [ img [ src url, style "max-width" "100%" ] [] ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "jpeg", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content" ]
                        [ img [ src url, style "max-width" "100%" ] [] ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "webp", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content" ]
                        [ img [ src url, style "max-width" "100%" ] [] ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "mp3", _ ) ->
            case maybeBlobUrl of
                Just url ->
                    div [ class "content-display rendered-content" ]
                        [ audio [ src url, attribute "controls" "" ] [] ]

                Nothing ->
                    div [ class "content-display" ] [ text "Loading..." ]

        ( "md", Rendered ) ->
            div [ class "content-display rendered-content" ]
                (Markdown.toHtml Nothing content)

        ( "html", Rendered ) ->
            div [ class "content-display rendered-content iframe-content" ]
                [ iframe
                    [ attribute "srcdoc" content
                    , style "width" "100%"
                    , style "height" "calc(100vh - 280px)"
                    , style "border" "none"
                    ]
                    []
                ]

        ( "tex", Rendered ) ->
            div [ class "content-display rendered-content" ]
                (MiniLatex.EditSimple.render content
                    |> List.map (Html.map (\_ -> NoOp))
                )

        ( "scripta", Rendered ) ->
            let
                params =
                    { filter = NoFilter
                    , windowWidth = 600
                    , theme = Light
                    , editCount = 0
                    , width = 500
                    , showTOC = True
                    , sizing = V3.Types.defaultSizingConfig
                    , maxLevel = 4
                    }

                output =
                    V3.Compiler.compile params (String.lines content)

                mapMsg =
                    Html.map
                        (\compilerMsg ->
                            case compilerMsg of
                                VT.SelectId id_ ->
                                    ScrollToId id_

                                VT.FootnoteClick { targetId } ->
                                    ScrollToId targetId

                                VT.CitationClick { targetId } ->
                                    ScrollToId targetId

                                _ ->
                                    NoOp
                        )
            in
            div []
                [ div [ class "scripta-header" ]
                    [ displayModeToggle dataType mode
                    , div [ class "scripta-title" ] [ mapMsg output.title ]
                    ]
                , div [ class "scripta-layout" ]
                    [ div [ class "content-display rendered-content", id "scripta-content" ]
                        (List.map mapMsg output.body)
                    , div
                        [ class "toc-panel"
                        , preventDefaultOn "click" (Json.Decode.succeed ( NoOp, True ))
                        ]
                        (List.map mapMsg output.toc)
                    ]
                ]

        _ ->
            div [ class "content-display source-content" ]
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
