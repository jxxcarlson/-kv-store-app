module Page.Groups exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)


view : GroupsModel -> Html Msg
view model =
    div [ class "groups-page" ]
        [ h2 [] [ text "My Groups" ]
        , if List.isEmpty model.groups then
            p [ class "empty-message" ] [ text "You don't belong to any groups yet." ]

          else
            viewGroupsTable model.groups
        ]


viewGroupsTable : List GroupInfo -> Html Msg
viewGroupsTable groups =
    table [ class "data-table" ]
        [ thead []
            [ tr []
                [ th [] [ text "Name" ]
                , th [] [ text "Read" ]
                , th [] [ text "Write" ]
                , th [] [ text "Owner ID" ]
                ]
            ]
        , tbody [] (List.map viewGroupRow groups)
        ]


viewGroupRow : GroupInfo -> Html Msg
viewGroupRow group =
    tr []
        [ td [] [ text group.name ]
        , td []
            [ text
                (if group.canRead then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td []
            [ text
                (if group.canWrite then
                    "Yes"

                 else
                    "No"
                )
            ]
        , td [] [ text (String.fromInt group.ownerId) ]
        ]
