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
        filtered =
            View.Search.filterEntries model.searchTerm model.entries
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
        , viewEntriesTable model.expandedEntry model.displayMode model.editingValue filtered
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
                , option [ value "pdf" ] [ text "pdf" ]
                , option [ value "jpg" ] [ text "jpg" ]
                , option [ value "png" ] [ text "png" ]
                , option [ value "jpeg" ] [ text "jpeg" ]
                , option [ value "webp" ] [ text "webp" ]
                , option [ value "mp3" ] [ text "mp3" ]
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
        , if List.member form.dataType [ "pdf", "jpg", "jpeg", "png", "webp", "mp3" ] then
            div [ class "form-group" ]
                [ label [] [ text "File" ]
                , input [ type_ "file", id "blob-file-input" ] []
                ]

          else
            div [ class "form-group" ]
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


viewEntriesTable : Maybe ExpandedEntry -> DisplayMode -> Maybe String -> List DataEntrySummary -> Html Msg
viewEntriesTable expandedEntry displayMode editingValue entries =
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
            , myDataExpandedPanel expandedEntry displayMode editingValue
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


isTextType : String -> Bool
isTextType dt =
    List.member dt [ "md", "tex", "scripta", "json", "txt", "html" ]


myDataExpandedPanel : Maybe ExpandedEntry -> DisplayMode -> Maybe String -> Html Msg
myDataExpandedPanel expandedEntry displayMode editingValue =
    case expandedEntry of
        Just ex ->
            let
                extraClass =
                    if ex.dataType == "html" && displayMode == Rendered then
                        " expanded-content-noscroll"

                    else
                        ""
            in
            case editingValue of
                Just val ->
                    div [ class "expanded-content" ]
                        [ div [ class "edit-controls" ]
                            [ button [ class "btn btn-primary", onClick SaveEdit ] [ text "Save" ]
                            , button [ class "btn", onClick CancelEdit ] [ text "Cancel" ]
                            ]
                        , textarea
                            [ class "edit-textarea"
                            , value val
                            , onInput SetEditValue
                            , style "width" "100%"
                            , style "height" "calc(100vh - 320px)"
                            , style "font-family" "monospace"
                            , style "font-size" "14px"
                            , style "padding" "8px"
                            , style "resize" "vertical"
                            ]
                            []
                        ]

                Nothing ->
                    div [ class ("expanded-content" ++ extraClass) ]
                        [ div [ class "content-toolbar" ]
                            [ if ex.dataType == "scripta" && displayMode == Rendered then
                                text ""
                              else
                                View.Table.displayModeToggle ex.dataType displayMode
                            , if isTextType ex.dataType then
                                button [ class "btn btn-small", onClick (StartEditing ex.value) ] [ text "Edit" ]
                              else
                                text ""
                            ]
                        , View.Table.display ex.dataType displayMode ex.value ex.blobObjectUrl
                        ]

        Nothing ->
            text ""
