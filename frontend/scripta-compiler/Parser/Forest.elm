module Parser.Forest exposing (parse, parseToForestWithAccumulator)

{-| Parse source lines into a forest of ExpressionBlocks.

    import Parser.Forest

    lines
        |> Parser.Forest.parse
        --> Forest ExpressionBlock

    params
        |> Parser.Forest.parseToForestWithAccumulator lines
        --> ( Accumulator, Forest ExpressionBlock )

-}

import Generic.Acc
import Generic.BlockUtilities
import Generic.ForestTransform
import Parser.Pipeline
import Parser.PrimitiveBlock
import RoseTree.Tree as Tree exposing (Tree)
import V3.Types exposing (Accumulator, CompilerParameters, ExpressionBlock, Filter(..), PrimitiveBlock)


{-| Parse source lines into a forest of expression blocks.

Pipeline:

1.  Parse lines into PrimitiveBlocks
2.  Build forest structure based on indentation
3.  Convert each PrimitiveBlock to ExpressionBlock

-}
parse : List String -> List (Tree ExpressionBlock)
parse lines =
    lines
        |> Parser.PrimitiveBlock.parse
        |> Generic.ForestTransform.forestFromBlocks .indent
        |> mapForest Parser.Pipeline.toExpressionBlock


{-| Parse source lines into a forest with accumulator.

Pipeline:

1.  Parse lines into forest of ExpressionBlocks
2.  Filter forest based on CompilerParameters
3.  Transform with accumulator (numbering, references, etc.)

-}
parseToForestWithAccumulator : CompilerParameters -> List String -> ( Accumulator, List (Tree ExpressionBlock) )
parseToForestWithAccumulator params lines =
    let
        initialData_ =
            Generic.Acc.initialData

        initialData =
            { initialData_ | maxLevel = initialData_.maxLevel }
    in
    lines
        |> parse
        |> filterForest params.filter
        |> Generic.Acc.transformAccumulate initialData


{-| Filter the forest based on filter settings.
-}
filterForest : Filter -> List (Tree ExpressionBlock) -> List (Tree ExpressionBlock)
filterForest filter forest =
    case filter of
        NoFilter ->
            forest

        SuppressDocumentBlocks ->
            forest
                |> filterForestOnName (\name -> name /= Just "document")
                |> filterForestOnName (\name -> name /= Just "title")


{-| Filter forest by block name predicate.
-}
filterForestOnName : (Maybe String -> Bool) -> List (Tree ExpressionBlock) -> List (Tree ExpressionBlock)
filterForestOnName predicate forest =
    List.filter (\tree -> predicate (Generic.BlockUtilities.getExpressionBlockName (Tree.value tree))) forest


{-| Map a function over all values in a forest.
-}
mapForest : (a -> b) -> List (Tree a) -> List (Tree b)
mapForest f forest =
    List.map (Tree.mapValues f) forest
