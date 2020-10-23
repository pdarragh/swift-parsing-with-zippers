fileprivate extension Sequence {
    /**
     Returns the result of combining the elements of the sequence using the
     given closure, but where the elements of the sequence are processed in
     reverse order.

     - Parameters:
         - initialResult: The value to use as the initial accumulating value.
         - updateAccumulatingResult: A closure that updates the accumulating
                                     value with an element of the sequence.
     - Returns: The final accumulated value. If the sequence has no elements,
                the result is `initialResult`.
     */
    func reduceRight<Result>(into initialResult: @autoclosure () -> Result,
                             _ updateAccumulatingResult: (Element, inout Result) throws -> ()) rethrows -> Result {
        var result = initialResult()
        try self.reversed().forEach {
            element in
            try updateAccumulatingResult(element, &result)
        }
        return result
    }
}

/**
 Prepends each of the elements of a list onto each of the lists inside another
 list using in-place mutation.

 - Parameters:
     - xs: The list of elements to prepend.
     - yss: The list of lists to which to prepend each element of `xs`.

 NOTE: The documentation for `Sequence.insert(_:at:)` notes an O(n) complexity
       bound for each call, which means repeated use of
       `prepend(elementsOf:toEach:)` may incur a significant performance
       penalty. Perhaps this should all be restructured by *appending* the
       elements and reversing each sublist in `yss` at the end of computation.
       For the moment, I'm leaving this implementation as it is more faithful to
       the original OCaml code.

 */
fileprivate func prepend<T>(elementsOf xs: [T], toEach yss: inout [[T]]) {
    xs.forEach {
        x in
        (0 ..< yss.count).forEach {
            yss[$0].insert(x, at: 0)
        }
    }
}

fileprivate func render(ast: AST) -> String {
    var texts = [String]()

    func render(ast: AST, withIndentation indentation: Int) {
        let indentationText = String.init(repeating: " ", count: indentation)
        switch (ast) {
        case let .Tok(token):
            texts.append(indentationText + "TOKEN: " + token.symbol)
        case let .Seq(symbol, asts):
            if asts.isEmpty {
                texts.append(indentationText + symbol)
            } else {
                texts.append(indentationText + "(" + symbol)
                asts.forEach { render(ast: $0, withIndentation: indentation + 3) }
                texts.append(texts.removeLast() + ")")
            }
        }
    }

    render(ast: ast, withIndentation: 0)

    return texts.joined(separator: "\n")
}

/// Encodes the AST resulting from processing a parsed grammar expression.
public indirect enum AST: CustomStringConvertible {
    /// An atomic token production.
    case Tok(token: Token)
    /// A named sequence of sub-trees.
    case Seq(symbol: Symbol, children: [AST])

    public var description: String {
        return render(ast: self)
    }
}

/*

e ::= A
    | e e

import PwZ
let grammar: Grammar = [ Grammar.startSymbol: "e"
                       , "e":
                           [ "A"
                           , "e" ++ "e"
                           ]
                       ]
let tokens: [Token] = grammar.tokenizeSymbols(["A", "A", "A", "A"])
let exps = grammar.parse(withInputTokens: tokens)
let asts = exps.flatMap(produceASTsFromExpression)
asts.forEach { print($0) }


OCaml:
#5
  (ee
     (ee
        A
        (ee
           A
           A))
     A)
#3
  (ee
     (ee
        (ee
           A
           A)
        A)
     A)
#1
  (ee
     (ee
        A
        A)
     (ee
        A
        A))
#2
  (ee
     A
     (ee
        A
        (ee
           A
           A)))
#4
  (ee
     A
     (ee
        (ee
           A
           A)
        A))



Swift:
(ee
   (ee
      (ee
         A
         A)
      A)
   (ee
      A
      (ee
         A
         A))
   A)
(ee
   (ee
      A
      A)
   (ee
      A
      A))
(ee
   A
   (ee
      (ee
         A
         A)
      A)
   (ee
      A
      (ee
         A
         A)))


 */

/**
 Returns a list of ASTs that can be represented by the given expression. If the
 original grammar was unambiguous, the returned list should contain either no
 elements (indicating a failed parse) or a single element (representing the
 successful parse tree). Ambiguous grammars can produce additional parse trees.

 - Parameters:
     - expression: The parsed grammar expression.
 - Returns: A list of ASTs representing the parse of the `expression`.
 */
public func produceASTsFromExpression(_ expression: Expression) -> [AST] {
    switch (expression.expressionCase) {
    case let .Tok(token):
        return [.Tok(token: token)]
    case let .Seq(symbol, expressions):
        return expressions.map(produceASTsFromExpression).reduceRight(into: [[]], prepend).map {
            asts in
            .Seq(symbol: symbol, children: asts)
        }
    case let .Alt(expressions):
        return expressions.flatMap(produceASTsFromExpression)
    }
}
