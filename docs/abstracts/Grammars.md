The `Grammar` is intended as the primary entry point into this implementation of
Parsing with Zippers (PwZ).

A new `Grammar` is initialized from a dictionary mapping non-terminal production
names to `AbstractGrammar` production descriptions. This can either be done
manually, by calling `Grammar.init(fromAbstractProductions:)`, or it can be done
more conveniently by using a dictionary literal.

Consider the following BNF grammar description of a simple arithmetic language:

```
S      ::= expr
expr   ::= term
         | expr '+' term
         | expr '-' term
term   ::= factor
         | term '*' factor
         | term '/' factor
factor ::= 'int'
         | '-' factor
         | '(' expr ')'
```

We can create a `Grammar` representing this grammar by doing:

```swift
let grammar: Grammar =
[ "START": "expr"
, "expr":
    [ "term"
    , "expr" ++ "+" ++ "term"
    , "expr" ++ "-" ++ "term" ]
, "term":
    [ "factor"
    , "term" ++ "*" ++ "factor"
    , "term" ++ "/" ++ "factor" ]
, "factor":
    [ "int"
    , "-" ++ "factor"
    , "(" ++ "expr" ++ ")" ]
]
```

This makes use of a few convenience features in the `AbstractGrammar` enum,
specifically:

  * String literals are converted into `AbstractGrammar.Symbol(_:)` instances.
  * Array literals are converted into `AbstractGrammar.Alternation(_:)` instances.
  * The `++(_:_:)` operator converts adjacent instances into
    `AbstractGrammar.Concatenation(_:)` instances.

The `AbstractGrammar.Symbol(_:)` instances are assumed to represent top-level
non-terminal production references if their text matches one of the keys of the
dictionary literal. All other instances of `AbstractGrammar.Symbol(_:)` are
assumed to represent terminal productions. Terminals will have `Tag`s generated
for parsing, where each `Tag` is unique to the text of a terminal symbol in the
grammar.

A list of `String`s can be converted into parse-able `Token`s by calling
`Grammar.tokenizeStrings(_:)`. This list of `Token`s can then be passed into
`Grammar.parse(inputTokens:)` to actually parse using PwZ.

### Mapping Multiple Symbols to a Single Tag

The `Grammar` does not support mapping multiple symbols to a single tag. This
would be useful for cases where a terminal production in a grammar actually
represents a class of potential symbols, such as integers or identifiers.

To handle this, I currently recommend either converting all of your symbols to
the terminal literals used by the grammar (which is lossy in the output parse
forest and therefore unideal), or else handling tokenization manually by
accessing the `Grammar.tokenMap` in your own tokenization function. (Actually,
the tags generated are only used for distinguishing terminal/non-terminal
references in the `AbstractGrammar.Symbol(_:)` deconstruction phase and then for
tokenization when that feature is used, so you can just generate an entirely
different set of token tags if that seems easier to you.)
