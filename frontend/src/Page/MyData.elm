module Page.MyData exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)
import View.Search
import View.Table


view : MyDataModel -> Html Msg
view model =
    let
        term =
            String.toLower model.searchTerm

        filtered =
            if String.isEmpty term then
                model.entries

            else
                List.filter
                    (\entry ->
                        String.contains term (String.toLower entry.key)
                            || String.contains term (String.toLower entry.description)
                    )
                    model.entries
    in
    div [ class "my-data-page" ]
        [ div [ class "page-header" ]
            [ h2 [] [ text "My Data" ]
            , View.Search.viewSearch model.searchTerm
            , button [ class "btn btn-primary", onClick ToggleCreateForm ]
                [ text
                    (if model.showCreateForm then
                        "Cancel"

                     else
                        "New Entry"
                    )
                ]
            ]
        , if model.showCreateForm then
            viewCreateForm model.createForm

          else
            text ""
        , viewEntriesTable model.expandedEntry model.displayMode filtered
        ]


viewCreateForm : CreateDataForm -> Html Msg
viewCreateForm form =
    div [ class "create-form" ]
        [ h3 [] [ text "Create New Entry" ]
        , div [ class "form-group" ]
            [ label [] [ text "Key" ]
            , input
                [ type_ "text"
                , value form.key
                , onInput (SetCreateField "key")
                , placeholder "Entry key"
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Data Type" ]
            , select
                [ onInput (SetCreateField "dataType")
                , value form.dataType
                ]
                [ option [ value "csv" ] [ text "csv" ]
                , option [ value "txt" ] [ text "txt" ]
                , option [ value "md" ] [ text "md" ]
                , option [ value "tex" ] [ text "tex" ]
                , option [ value "scripta" ] [ text "scripta" ]
                , option [ value "json" ] [ text "json" ]
                , option [ value "html" ] [ text "html" ]
                ]
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Properties" ]
            , input
                [ type_ "text"
                , value form.properties
                , onInput (SetCreateField "properties")
                , placeholder "Properties"
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Description" ]
            , input
                [ type_ "text"
                , value form.description
                , onInput (SetCreateField "description")
                , placeholder "Description"
                ]
                []
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Value" ]
            , textarea
                [ value form.value
                , onInput (SetCreateField "value")
                , placeholder "Entry value"
                , rows 6
                ]
                []
            ]
        , button [ class "btn btn-primary", onClick SubmitCreateData ]
            [ text "Create" ]
        ]


viewEntriesTable : Maybe ExpandedEntry -> DisplayMode -> List DataEntrySummary -> Html Msg
viewEntriesTable expandedEntry displayMode entries =
    if List.isEmpty entries then
        p [ class "empty-message" ] [ text "You don't have any data entries yet." ]

    else
        let
            visibleEntries =
                case expandedEntry of
                    Just ex ->
                        List.filter (\e -> e.key == ex.key) entries

                    Nothing ->
                        entries
        in
        div []
            [ table [ class "data-table" ]
                [ thead []
                    [ tr []
                        [ th [] [ text "Key" ]
                        , th [] [ text "Type" ]
                        , th [] [ text "Description" ]
                        , th [] [ text "Created" ]
                        , th [] [ text "Modified" ]
                        , th [] [ text "Actions" ]
                        ]
                    ]
                , tbody [] (List.map (viewEntryRow expandedEntry) visibleEntries)
                ]
            , myDataExpandedPanel expandedEntry displayMode
            ]


viewEntryRow : Maybe ExpandedEntry -> DataEntrySummary -> Html Msg
viewEntryRow expandedEntry entry =
    tr [ onClick (ToggleExpandEntry entry.key), style "cursor" "pointer" ]
        [ td [] [ text entry.key ]
        , td [] [ text entry.dataType ]
        , td [] [ text entry.description ]
        , td [] [ text (View.Table.formatTimestamp entry.createdAt) ]
        , td [] [ text (View.Table.formatTimestamp entry.modifiedAt) ]
        , td [ class "actions" ]
            [ if entry.isPublic then
                button [ class "btn", onClick (MakePrivate entry.key) ]
                    [ text "Unpublish" ]

              else
                button [ class "btn", onClick (MakePublic entry.key) ]
                    [ text "Publish" ]
            , button [ class "btn btn-danger", onClick (DeleteEntry entry.key) ]
                [ text "Delete" ]
            ]
        ]


myDataExpandedPanel : Maybe ExpandedEntry -> DisplayMode -> Html Msg
myDataExpandedPanel expandedEntry displayMode =
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
                    View.Table.displayModeToggle ex.dataType displayMode
                , View.Table.display ex.dataType displayMode ex.value
                ]

        Nothing ->
            text ""
