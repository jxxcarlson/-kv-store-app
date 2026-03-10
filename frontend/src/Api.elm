module Api exposing (..)

import Http
import Json.Decode as D
import Json.Encode as E
import Types exposing (..)


apiBase : String
apiBase =
    "http://localhost:3000"



-- DECODERS


decodeAuthResponse : D.Decoder AuthResponse
decodeAuthResponse =
    D.map2 AuthResponse
        (D.field "authToken" D.string)
        (D.field "authRefreshToken" D.string)


decodeDataEntrySummary : D.Decoder DataEntrySummary
decodeDataEntrySummary =
    D.map6 DataEntrySummary
        (D.field "desKey" D.string)
        (D.field "desDataType" D.string)
        (D.field "desDescription" D.string)
        (D.field "desCreatedAt" D.string)
        (D.field "desModifiedAt" D.string)
        (D.field "desIsPublic" D.bool)


decodeExpandedEntry : D.Decoder ExpandedEntry
decodeExpandedEntry =
    D.map3 ExpandedEntry
        (D.field "dvrKey" D.string)
        (D.field "dvrDataType" D.string)
        (D.field "dvrValue" D.string)


decodeGroupInfo : D.Decoder GroupInfo
decodeGroupInfo =
    D.map5 GroupInfo
        (D.field "grpId" D.int)
        (D.field "grpOwnerId" D.int)
        (D.field "grpName" D.string)
        (D.field "grpCanRead" D.bool)
        (D.field "grpCanWrite" D.bool)



-- ENCODERS


encodeLogin : LoginModel -> E.Value
encodeLogin loginModel =
    E.object
        [ ( "loginEmail", E.string loginModel.email )
        , ( "loginPassword", E.string loginModel.password )
        ]


encodeRegister : RegisterModel -> E.Value
encodeRegister registerModel =
    E.object
        [ ( "registerName", E.string registerModel.name )
        , ( "registerEmail", E.string registerModel.email )
        , ( "registerPassword", E.string registerModel.password )
        ]


encodeCreateData : CreateDataForm -> E.Value
encodeCreateData form =
    E.object
        [ ( "cdrKey", E.string form.key )
        , ( "cdrDataType", E.string form.dataType )
        , ( "cdrProperties", E.string form.properties )
        , ( "cdrDescription", E.string form.description )
        , ( "cdrValue", E.string form.value )
        ]



-- AUTH HELPERS


authHeader : String -> Http.Header
authHeader token =
    Http.header "Authorization" ("Bearer " ++ token)



-- HTTP REQUESTS


login : LoginModel -> Cmd Msg
login loginModel =
    Http.post
        { url = apiBase ++ "/api/auth/login"
        , body = Http.jsonBody (encodeLogin loginModel)
        , expect = Http.expectJson GotAuthResponse decodeAuthResponse
        }


register : RegisterModel -> Cmd Msg
register registerModel =
    Http.post
        { url = apiBase ++ "/api/auth/register"
        , body = Http.jsonBody (encodeRegister registerModel)
        , expect = Http.expectJson GotAuthResponse decodeAuthResponse
        }


fetchPublicEntries : Maybe String -> Maybe String -> Cmd Msg
fetchPublicEntries maybeSearch maybeSort =
    let
        searchParam =
            case maybeSearch of
                Just s ->
                    if String.isEmpty s then
                        ""

                    else
                        "search=" ++ s

                Nothing ->
                    ""

        sortParam =
            case maybeSort of
                Just s ->
                    "sort=" ++ s

                Nothing ->
                    ""

        params =
            [ searchParam, sortParam ]
                |> List.filter (not << String.isEmpty)
                |> String.join "&"

        queryString =
            if String.isEmpty params then
                ""

            else
                "?" ++ params
    in
    Http.get
        { url = apiBase ++ "/api/public" ++ queryString
        , expect = Http.expectJson GotPublicEntries (D.list decodeDataEntrySummary)
        }


fetchMyEntries : String -> Cmd Msg
fetchMyEntries token =
    Http.request
        { method = "GET"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data"
        , body = Http.emptyBody
        , expect = Http.expectJson GotMyEntries (D.list decodeDataEntrySummary)
        , timeout = Nothing
        , tracker = Nothing
        }


createDataEntry : String -> CreateDataForm -> Cmd Msg
createDataEntry token form =
    Http.request
        { method = "POST"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data"
        , body = Http.jsonBody (encodeCreateData form)
        , expect = Http.expectJson GotCreateResponse decodeDataEntrySummary
        , timeout = Nothing
        , tracker = Nothing
        }


deleteDataEntry : String -> String -> Cmd Msg
deleteDataEntry token key =
    Http.request
        { method = "DELETE"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data/" ++ key
        , body = Http.emptyBody
        , expect = Http.expectWhatever GotDeleteResponse
        , timeout = Nothing
        , tracker = Nothing
        }


assignToPublicGroup : String -> String -> Cmd Msg
assignToPublicGroup token key =
    Http.request
        { method = "PUT"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data/" ++ key ++ "/group"
        , body = Http.jsonBody (E.object [ ( "agrGroupId", E.int 1 ) ])
        , expect = Http.expectWhatever GotMakePublicResponse
        , timeout = Nothing
        , tracker = Nothing
        }


removeFromPublicGroup : String -> String -> Cmd Msg
removeFromPublicGroup token key =
    Http.request
        { method = "PUT"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data/" ++ key ++ "/group"
        , body = Http.jsonBody (E.object [ ( "agrGroupId", E.int 0 ) ])
        , expect = Http.expectWhatever GotMakePublicResponse
        , timeout = Nothing
        , tracker = Nothing
        }


fetchGroups : String -> Cmd Msg
fetchGroups token =
    Http.request
        { method = "GET"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/groups"
        , body = Http.emptyBody
        , expect = Http.expectJson GotGroups (D.list decodeGroupInfo)
        , timeout = Nothing
        , tracker = Nothing
        }


fetchPublicEntryValue : String -> Cmd Msg
fetchPublicEntryValue key =
    Http.get
        { url = apiBase ++ "/api/public/" ++ key
        , expect = Http.expectJson GotEntryValue decodeExpandedEntry
        }


fetchEntryValue : String -> String -> Cmd Msg
fetchEntryValue token key =
    Http.request
        { method = "GET"
        , headers = [ authHeader token ]
        , url = apiBase ++ "/api/data/" ++ key
        , body = Http.emptyBody
        , expect = Http.expectJson GotEntryValue decodeExpandedEntry
        , timeout = Nothing
        , tracker = Nothing
        }
