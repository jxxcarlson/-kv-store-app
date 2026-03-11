module Parser.Symbol exposing (Symbol(..), toSymbols, value)

import Parser.Tokenizer exposing (Token, Token_(..))


type Symbol
    = L -- LB, [
    | R -- RB, ]
    | ST -- S String (string)
    | M -- $
    | C -- `
    | WS -- W String (whitespace)
    | E -- Token error


value : Symbol -> Int
value symbol =
    case symbol of
        L ->
            1

        R ->
            -1

        ST ->
            0

        WS ->
            0

        M ->
            0

        C ->
            0

        E ->
            0


toSymbols : List Token -> List Symbol
toSymbols tokens =
    List.map toSymbol tokens


toSymbol : Token -> Symbol
toSymbol token =
    case token of
        LB _ ->
            L

        RB _ ->
            R

        S _ _ ->
            ST

        W _ _ ->
            WS

        MathToken _ ->
            M

        CodeToken _ ->
            C

        TokenError _ _ ->
            E
