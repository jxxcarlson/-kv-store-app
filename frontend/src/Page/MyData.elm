module Page.MyData exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Types exposing (..)


view : MyDataModel -> Html Msg
view model =
    div [ class "my-data-page" ]
        [ div [ class "page-header" ]
            [ h2 [] [ text "My Data" ]
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
        , viewEntriesTable model.entries
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
                [ option [ value "txt" ] [ text "txt" ]
                , option [ value "csv" ] [ text "csv" ]
                , option [ value "json" ] [ text "json" ]
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


viewEntriesTable : List DataEntrySummary -> Html Msg
viewEntriesTable entries =
    if List.isEmpty entries then
        p [ class "empty-message" ] [ text "You don't have any data entries yet." ]

    else
        table [ class "data-table" ]
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
            , tbody [] (List.map viewEntryRow entries)
            ]


viewEntryRow : DataEntrySummary -> Html Msg
viewEntryRow entry =
    tr []
        [ td [] [ text entry.key ]
        , td [] [ text entry.dataType ]
        , td [] [ text entry.description ]
        , td [] [ text entry.createdAt ]
        , td [] [ text entry.modifiedAt ]
        , td []
            [ button [ class "btn btn-danger", onClick (DeleteEntry entry.key) ]
                [ text "Delete" ]
            ]
        ]
