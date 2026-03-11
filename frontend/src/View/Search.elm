module View.Search exposing (filterEntries, viewSearch)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


viewSearch : String -> Html Msg
viewSearch searchTerm =
    div [ class "search-bar" ]
        [ input
            [ type_ "text"
            , placeholder "Search by key, description, or :type..."
            , value searchTerm
            , onInput SetSearchTerm
            ]
            []
        ]


filterEntries : String -> List DataEntrySummary -> List DataEntrySummary
filterEntries searchTerm entries =
    let
        term =
            String.toLower (String.trim searchTerm)
    in
    if String.isEmpty term then
        entries

    else
        case specialFilter term of
            Just typeMatcher ->
                List.filter (\entry -> typeMatcher (String.toLower entry.dataType)) entries

            Nothing ->
                List.filter
                    (\entry ->
                        String.contains term (String.toLower entry.key)
                            || String.contains term (String.toLower entry.description)
                    )
                    entries


specialFilter : String -> Maybe (String -> Bool)
specialFilter term =
    case term of
        ":image" ->
            Just (\dt -> List.member dt [ "jpg", "jpeg", "png", "webp" ])

        ":md" ->
            Just (\dt -> dt == "md")

        ":tex" ->
            Just (\dt -> dt == "tex")

        ":scripta" ->
            Just (\dt -> dt == "scripta")

        ":pdf" ->
            Just (\dt -> dt == "pdf")

        ":mp3" ->
            Just (\dt -> dt == "mp3")

        ":json" ->
            Just (\dt -> dt == "json")

        ":html" ->
            Just (\dt -> dt == "html")

        ":txt" ->
            Just (\dt -> dt == "txt")

        ":binary" ->
            Just (\dt -> List.member dt [ "pdf", "jpg", "jpeg", "png", "webp", "mp3" ])

        _ ->
            Nothing
