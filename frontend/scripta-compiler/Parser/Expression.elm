module Parser.Expression exposing (parse)

{-|

    > import Types exposing(..)
    > import Parser.Expression exposing(parse)

    > parse 0 "hello"
    [Text "hello" { begin = 0, end = 4, index = 0, id = "e-0.0" }]

    > parse 0 "This is [b important]"
    [Text "This is " ..., Fun "b" [Text "important" ...] ...]

    > parse 0 "I like $a^2 + b^2 = c^2$"
    [Text "I like " ..., VFun "math" "a^2 + b^2 = c^2" ...]

-}

import List.Extra
import Parser.Match as M
import Parser.Symbol as Symbol exposing (Symbol(..))
import Parser.Tokenizer as Token exposing (Token, TokenType(..), Token_(..))
import Tools.Loop exposing (Step(..), loop)
import V3.Types exposing (Expr(..), ExprMeta, Expression)


type alias State =
    { step : Int
    , tokens : List Token
    , numberOfTokens : Int
    , tokenIndex : Int
    , committed : List Expression
    , stack : List Token
    , messages : List String
    , lineNumber : Int
    }


parse : Int -> String -> List Expression
parse lineNumber str =
    let
        state =
            parseToState lineNumber str
    in
    state.committed |> fixup


fixup : List Expression -> List Expression
fixup input =
    case input of
        (Fun name exprList meta) :: rest ->
            let
                newExprlist =
                    case exprList of
                        (Text str meta_) :: tail ->
                            Text (String.trim str) meta_ :: tail

                        _ ->
                            exprList
            in
            Fun name newExprlist meta :: fixup rest

        other :: rest ->
            other :: fixup rest

        [] ->
            []


parseToState : Int -> String -> State
parseToState lineNumber str =
    str
        |> Token.run
        |> parseTokenListToState lineNumber


parseTokenListToState : Int -> List Token -> State
parseTokenListToState lineNumber tokens =
    tokens |> initWithTokens lineNumber |> run


initWithTokens : Int -> List Token -> State
initWithTokens lineNumber tokens =
    { step = 0
    , tokens = List.reverse tokens
    , numberOfTokens = List.length tokens
    , tokenIndex = 0
    , committed = []
    , stack = []
    , messages = []
    , lineNumber = lineNumber
    }


run : State -> State
run state =
    loop state nextStep
        |> (\state_ -> { state_ | committed = List.reverse state_.committed })


nextStep : State -> Step State State
nextStep state =
    case getToken state of
        Nothing ->
            if stackIsEmpty state then
                Done state

            else
                recoverFromError state

        Just token ->
            state
                |> advanceTokenIndex
                |> pushOrCommit token
                |> reduceState
                |> (\st -> { st | step = st.step + 1 })
                |> Loop


advanceTokenIndex : State -> State
advanceTokenIndex state =
    { state | tokenIndex = state.tokenIndex + 1 }


getToken : State -> Maybe Token
getToken state =
    List.Extra.getAt state.tokenIndex state.tokens


stackIsEmpty : State -> Bool
stackIsEmpty state =
    List.isEmpty state.stack


pushOrCommit : Token -> State -> State
pushOrCommit token state =
    case token of
        S _ _ ->
            pushOrCommit_ token state

        W _ _ ->
            pushOrCommit_ token state

        MathToken _ ->
            pushOnStack_ token state

        CodeToken _ ->
            pushOnStack_ token state

        LB _ ->
            pushOnStack_ token state

        RB _ ->
            pushOnStack_ token state

        TokenError _ _ ->
            pushOnStack_ token state


pushOnStack_ : Token -> State -> State
pushOnStack_ token state =
    { state | stack = token :: state.stack }


pushOrCommit_ : Token -> State -> State
pushOrCommit_ token state =
    if List.isEmpty state.stack then
        commit token state

    else
        push token state


push : Token -> State -> State
push token state =
    { state | stack = token :: state.stack }


commit : Token -> State -> State
commit token state =
    case stringTokenToExpr state.lineNumber token of
        Nothing ->
            state

        Just expr ->
            { state | committed = expr :: state.committed }


stringTokenToExpr : Int -> Token -> Maybe Expression
stringTokenToExpr lineNumber token =
    case token of
        S str loc ->
            Just (Text str (boostMeta lineNumber (Token.indexOf token) loc))

        W str loc ->
            Just (Text str (boostMeta lineNumber (Token.indexOf token) loc))

        _ ->
            Nothing


reduceState : State -> State
reduceState state =
    if tokensAreReducible state then
        { state | stack = [], committed = reduceStack state ++ state.committed }

    else
        state


tokensAreReducible : State -> Bool
tokensAreReducible state =
    M.isReducible (state.stack |> Symbol.toSymbols |> List.reverse)


reduceStack : State -> List Expression
reduceStack state =
    reduceTokens state.lineNumber (state.stack |> List.reverse)


reduceTokens : Int -> List Token -> List Expression
reduceTokens lineNumber tokens =
    if isExpr tokens then
        let
            args =
                unbracket tokens
        in
        case args of
            (S name meta) :: rest ->
                if List.member name verbatimFunctionNames then
                    -- For verbatim functions like [m ...], [math ...], [chem ...],
                    -- collect all remaining tokens as a single string
                    let
                        content =
                            rest
                                |> List.filterMap tokenToString
                                |> String.join ""
                                |> String.trim
                    in
                    [ VFun name content (boostMeta lineNumber meta.index meta) ]

                else
                    [ Fun name (reduceRestOfTokens lineNumber (List.drop 1 args)) (boostMeta lineNumber meta.index meta) ]

            _ ->
                [ errorMessage "[????]" ]

    else
        case tokens of
            (MathToken meta) :: (S str _) :: (MathToken _) :: rest ->
                VFun "math" str (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber rest

            (MathToken meta) :: rest ->
                -- Multi-token math content: collect everything up to closing MathToken
                let
                    inner =
                        List.Extra.takeWhile (not << isMathToken) rest

                    after =
                        List.drop (List.length inner + 1) rest

                    content =
                        inner
                            |> List.filterMap tokenToString
                            |> String.join ""
                in
                VFun "math" content (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber after

            (CodeToken meta) :: (S str _) :: (CodeToken _) :: rest ->
                VFun "code" str (boostMeta lineNumber meta.index meta) :: reduceRestOfTokens lineNumber rest

            _ ->
                [ errorMessage "[????]" ]


reduceRestOfTokens : Int -> List Token -> List Expression
reduceRestOfTokens lineNumber tokens =
    case tokens of
        (LB _) :: _ ->
            case splitTokens tokens of
                Nothing ->
                    [ Text "error on match" dummyLocWithId ]

                Just ( a, b ) ->
                    reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (MathToken _) :: _ ->
            let
                ( a, b ) =
                    splitTokensWithSegment tokens
            in
            reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (CodeToken _) :: _ ->
            let
                ( a, b ) =
                    splitTokensWithSegment tokens
            in
            reduceTokens lineNumber a ++ reduceRestOfTokens lineNumber b

        (S str meta) :: _ ->
            Text str (boostMeta lineNumber (Token.indexOf (S str meta)) meta) :: reduceRestOfTokens lineNumber (List.drop 1 tokens)

        token :: _ ->
            case stringTokenToExpr lineNumber token of
                Just expr ->
                    expr :: reduceRestOfTokens lineNumber (List.drop 1 tokens)

                Nothing ->
                    [ Text "error converting Token" dummyLocWithId ]

        _ ->
            []


recoverFromError : State -> Step State State
recoverFromError state =
    case List.reverse state.stack of
        (LB _) :: (RB meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "[?]" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = prependMessage state.lineNumber "Brackets must enclose something" state.messages
                }

        (LB _) :: (S fName meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage ("[" ++ fName ++ "]?") :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = prependMessage state.lineNumber "Missing right bracket" state.messages
                }

        (LB _) :: (W " " meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "[ - can't have space after the bracket " :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = prependMessage state.lineNumber "Can't have space after left bracket" state.messages
                }

        (LB _) :: [] ->
            Done
                { state
                    | committed = errorMessage "[...?" :: state.committed
                    , stack = []
                    , tokenIndex = 0
                    , numberOfTokens = 0
                    , messages = prependMessage state.lineNumber "That left bracket needs something after it" state.messages
                }

        (RB meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage " extra ]?" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , messages = prependMessage state.lineNumber "Extra right bracket(s)" state.messages
                }

        (MathToken meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "$?$" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , numberOfTokens = 0
                    , messages = prependMessage state.lineNumber "opening dollar sign needs to be matched" state.messages
                }

        (CodeToken meta) :: _ ->
            Loop
                { state
                    | committed = errorMessage "`?`" :: state.committed
                    , stack = []
                    , tokenIndex = meta.index + 1
                    , numberOfTokens = 0
                    , messages = prependMessage state.lineNumber "opening backtick needs to be matched" state.messages
                }

        _ ->
            Done
                { state
                    | committed = errorMessage " ?!? " :: state.committed
                    , messages = prependMessage state.lineNumber "Unknown error" state.messages
                }



-- HELPERS


unbracket : List a -> List a
unbracket list =
    List.drop 1 (List.take (List.length list - 1) list)


isExpr : List Token -> Bool
isExpr tokens =
    List.map Token.type_ (List.take 1 tokens)
        == [ TLB ]
        && List.map Token.type_ (List.take 1 (List.reverse tokens))
        == [ TRB ]


boostMeta : Int -> Int -> { begin : Int, end : Int, index : Int } -> ExprMeta
boostMeta lineNumber tokenIndex { begin, end, index } =
    { begin = begin, end = end, index = index, id = makeId lineNumber tokenIndex }


splitTokens : List Token -> Maybe ( List Token, List Token )
splitTokens tokens =
    case M.match (Symbol.toSymbols tokens) of
        Nothing ->
            Nothing

        Just k ->
            Just (M.splitAt (k + 1) tokens)


splitTokensWithSegment : List Token -> ( List Token, List Token )
splitTokensWithSegment tokens =
    M.splitAt (segLength tokens + 1) tokens


segLength : List Token -> Int
segLength tokens =
    M.getSegment M (tokens |> Symbol.toSymbols) |> List.length


makeId : Int -> Int -> String
makeId lineNumber tokenIndex =
    "e-" ++ String.fromInt lineNumber ++ "." ++ String.fromInt tokenIndex


dummyTokenIndex : Int
dummyTokenIndex =
    0


dummyLocWithId : ExprMeta
dummyLocWithId =
    { begin = 0, end = 0, index = dummyTokenIndex, id = "dummy" }


errorMessage : String -> Expression
errorMessage message =
    Fun "errorHighlight" [ Text message dummyLocWithId ] dummyLocWithId


prependMessage : Int -> String -> List String -> List String
prependMessage lineNumber message messages =
    (message ++ " (line " ++ String.fromInt lineNumber ++ ")") :: List.take 2 messages


{-| List of function names that should be parsed as VFun (verbatim functions).
These functions receive their content as a raw string rather than parsed expressions.
-}
verbatimFunctionNames : List String
verbatimFunctionNames =
    [ "m", "math", "chem", "code" ]


isMathToken : Token -> Bool
isMathToken token =
    case token of
        MathToken _ ->
            True

        _ ->
            False


{-| Convert a token to its string representation for verbatim functions.
-}
tokenToString : Token -> Maybe String
tokenToString token =
    case token of
        S str _ ->
            Just str

        W str _ ->
            Just str

        LB _ ->
            Just "["

        RB _ ->
            Just "]"

        _ ->
            Nothing
