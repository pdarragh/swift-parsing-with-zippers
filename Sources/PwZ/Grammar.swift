/// Errors related to the creation of grammars of expressions.
public enum GrammarError: Error {
    /// Thrown when no start symbol is present in a grammar.
    case NoStartSymbol(symbol: Symbol)
    /// Thrown when attempting to initialize a grammar with symbols at the top
    /// level of expressions.
    case IllegalSymbolAlias(symbol: Symbol, target: Symbol)
    /// Thrown when attempting to tokenize a symbol that has no matching token
    /// in a given grammar.
    case NoTagForSymbol(symbol: Symbol)
    /// Thrown when attempting to parse a grammar given an invalid start symbol.
    case InvalidStartSymbol(symbol: Symbol)
}

/// We extend basic Dictionaries to support query containment for simplicity.
fileprivate extension Dictionary {
    /// Checks whether a key is present in the dictionary.
    func contains(_ key: Key) -> Bool {
        if let _ = self[key] {
            return true
        } else {
            return false
        }
    }
}

/**
 A `Grammar` is a collection of productions. A basic knowledge of formal
 grammars is assumed. See the [Wikipedia article](https://en.wikipedia.org/wiki/Formal_grammar)
 for more information.

 Once built, a `Grammar` can be used for parsing by using the
 `Grammar.parse(withInputTokens:)` function.
 */
public struct Grammar {
    /// All `Grammar`s must contain a top-level start symbol to indicate the
    /// root of the grammar. An error will be thrown if this is not satisfied.
    public static let startSymbol = "START"

    /// The specifications to which the grammar was originally built. This can
    /// be useful for getting a list of valid top-level rule names to use with
    /// `Grammar.parse(withInputTokens:startingAtRule:)`.
    public let abstractProductions: [Symbol : AbstractGrammar]

    /// The actual expression grammar created from the
    /// `Grammar.abstractProductions` specification.
    public let actualProductions: [Symbol : Expression]

    /// The designated start symbol for this grammar.
    public let startSymbol: Symbol

    /// The designated root of the grammar.
    public var root: Expression { actualProductions[startSymbol]! }

    /// A map of token symbols to generated tags. This is useful for producing
    /// input strings of tokens for the PwZ algorithm.
    public private(set) var tokenMap: [Symbol : Tag]

    /**
     Initializes a new grammar from a dictionary mapping production names to
     productions. The productions cannot be symbols.

     - Parameters:
         - abstractProductions: A dictionary mapping non-terminal production
                                names to `AbstractGrammar` production
                                descriptions.
         - startSymbol: The symbol from which parses should originate. If you
                        want to have multiple top-level expressions, create a
                        higher-level alternate case that encapsulates them.
     - Throws: `GrammarError.NoStartSymbol` if the indicated start symbol is not
               present in the dictionary of abstract productions or
               `GrammarError.IllegalSymbolAlias` if there is a top-level symbol.
     */
    public init(fromAbstractProductions newAbstractProductions: [Symbol : AbstractGrammar],
                withStartSymbol newStartSymbol: Symbol = Grammar.startSymbol) throws {
        // Verify that the start symbol is actually present in the productions.
        guard newAbstractProductions.contains(newStartSymbol) else {
            throw GrammarError.NoStartSymbol(symbol: newStartSymbol)
        }
        // Verify that there are no top-level symbols.
        try newAbstractProductions.forEach {
            symbol, subgrammar in
            if case let .Symbol(target) = subgrammar {
                throw GrammarError.IllegalSymbolAlias(symbol: symbol, target: target)
            }
        }

        // We perform a reduction over the top-level non-terminals, allocating
        // placeholder `Expression`s for them, which we will later use for
        // constructing the complete grammar.
        let productions = newAbstractProductions.keys.reduce(into: [Symbol : Expression]()) {
            (productions, symbol) in
            productions[symbol] = Expression(memoizationRecord: Sentinel.of(MemoizationRecord.self),
                                             expressionCase: .Tok(token: Sentinel.of(Token.self)))
        }

        // Initialize the instance properties.
        abstractProductions = newAbstractProductions
        actualProductions = productions
        startSymbol = newStartSymbol

        // Next, we traverse the abstract grammar. From this, we create all of
        // the expressions in the grammar, while also allocating tags for any
        // tokens encountered along the way.

        // We prepare a token map, which will map symbols to the appropriate
        // tags used in parsing.
        tokenMap = [Symbol : Tag]()
        var nextTokenTag: Tag = 0

        /**
         Recursively builds an `Expression` from a given `AbstractGrammar`. The
         top-level productions must have names supplied by the
         `abstractProductions` dictionary, but child expressions are named
         automatically. Terminal symbols take their matching string literal as
         their name.

         - Parameters
             - subgrammar: The `AbstractGrammar` being processed right now.
             - symbol: The name given to the `subgrammar` (if needed) based on
                       the shape of its parent.
         - Returns: An `Expression` corresponding to the description given by
                    the `subgrammar`.
         */
        func processSubgrammar(_ subgrammar: AbstractGrammar, withSymbol symbol: Symbol) -> Expression {
            switch (subgrammar) {
            case .Epsilon:
                // An epsilon production is encoded as an empty sequence.
                return Expression(expressionCase: .Seq(symbol: symbol + "ε",
                                                       expressions: []))
            case let .Symbol(symbol):
                // Symbols can represent either a reference to another
                // expression (i.e., a non-terminal production) or a token
                // (i.e., a terminal production).
                if let expression = productions[symbol] {
                    // This is just a reference lookup.
                    return expression
                } else {
                    // The symbol corresponds to a token. Check if we've seen it
                    // before.
                    if !tokenMap.contains(symbol) {
                        // It's a new token. Allocate a tag!
                        tokenMap[symbol] = nextTokenTag
                        nextTokenTag += 1
                    }
                    // Generate a new token expression with the correct tag.
                    let tag = tokenMap[symbol]!
                    return Expression(expressionCase: .Tok(token: (tag, symbol)))
                }
            case let .Concatenation(components):
                // Concatenations represent sequences of grammar expressions
                // that must be handled in-order.
                let expressions = components.enumerated().map {
                    (i, subgrammar) in
                    processSubgrammar(subgrammar, withSymbol: "\(symbol)_seq_\(i)")
                }
                return Expression(expressionCase: .Seq(symbol: symbol,
                                                       expressions: expressions))
            case let .Alternation(components):
                // Alternations represent alternate choices among a set of
                // grammar expressions, which should be handled
                // non-deterministically.
                let expressions = components.enumerated().map {
                    (i, subgrammar) in
                    processSubgrammar(subgrammar, withSymbol: "\(symbol)_alt_\(i)")
                }
                return Expression(expressionCase: .Alt(expressions: ReferenceArray(expressions)))
            }
        }

        // Process the abstract production descriptions to generate the real
        // `Expression` grammar.
        productions.forEach {
            (symbol, expression) in
            let subgrammar = abstractProductions[symbol]!
            expression.expressionCase = processSubgrammar(subgrammar, withSymbol: symbol).expressionCase
        }
    }

    /**
     Converts a sequence of strings into `Token`s for parsing.

     - Parameters:
         - strings: An array of strings representing token symbols.
     - Returns: An array of `Token`s.
     - Throws: `GrammarError.NoTagForSymbol` if any of the given strings do not
               match any terminal symbols in the grammar.
     */
    public func tokenizeSymbols(_ symbols: [Symbol]) throws -> [Token] {
        return try tokenizeSymbols(symbols).map { try $0.get() }
    }

    /**
     Converts a sequence of `Symbol`s into `Token`s for parsing. The result is a
     list of `Result<Token, GrammarError>` items so individual failing cases can
     be addressed as needed.

     - Parameters:
         - symbols: An array of `Symbol`s to be tokenized.
     - Returns: An array of potential tokens (or errors, when a string does not
                correspond to a tag in the grammar).
     */
    public func tokenizeSymbols(_ symbols: [Symbol]) -> [Result<Token, GrammarError>] {
        return symbols.map {
            symbol in
            if let tag = tokenMap[symbol] {
                return .success((tag, symbol))
            } else {
                return .failure(GrammarError.NoTagForSymbol(symbol: symbol))
            }
        }
    }

    /**
     Parses the grammar using the given input tokens, starting at the given
     start symbol.

     - Parameters:
         - tokens: An array of `Token`s to parse.
         - ruleName: The `Symbol` representing the top-level production to start
                     the parse from.
     - Returns: A list of resulting `Expression`s.
     - Throws: `GrammarError.InvalidStartSymbol` if given an invalid start
               symbol. Don't do that. Use `Grammar.abstractProductions` to get a
               list of valid start symbols.
     */
    public func parse(withInputTokens tokens: [Token], startingAtRule ruleName: Symbol) throws -> [Expression] {
        wipeMemoizationRecords()
        guard let expression = actualProductions[ruleName] else {
            throw GrammarError.InvalidStartSymbol(symbol: ruleName)
        }
        return PwZ.parse(expression: expression, withInputTokens: tokens)
    }

    /**
     Parses the grammar using the given input tokens, starting at the start
     symbol designated during instance initialization.

     - Parameters:
         - tokens: An array of `Token`s to parse.
     - Returns: A list of resulting `Expression`s.
     */
    public func parse(withInputTokens tokens: [Token]) -> [Expression] {
        return try! parse(withInputTokens: tokens, startingAtRule: startSymbol)
    }

    /**
     Traverses the expression grammar, resetting all of the `MemoizationRecord`s
     to an empty state. This is done to prevent issues of stale records
     interfering with parses.

     FIXME: Specifically, this function was rendered necessary by attempts to
            parse empty strings on grammars that should accept them. See Issue
            #1 for more information.
     */
    private func wipeMemoizationRecords() {
        var queue: [Expression] = Array(actualProductions.values)
        while !queue.isEmpty {
            let expression = queue.removeFirst()
            if expression.memoizationRecord === Sentinel.of(MemoizationRecord.self) {
                continue
            }
            expression.memoizationRecord = Sentinel.of(MemoizationRecord.self)
            switch (expression.expressionCase) {
            case .Tok:
                continue
            case let .Seq(_, expressions):
                queue.append(contentsOf: expressions)
            case let .Alt(expressions):
                queue.append(contentsOf: expressions)
            }
        }
    }
}

/// For convenience, we extend the `Grammar` to be expressible as a dictionary
/// literal.
extension Grammar: ExpressibleByDictionaryLiteral {
    /**
     Initializes a `Grammar` from a dictionary literal. Together with the
     convenience initializers and operators for `AbstractGrammar`s, this allows
     for a convenient way to create a new `Grammar` from scratch.

     If the grammar described is somehow invalid, a fatal error occurs. I
     recommend not writing invalid grammar literals.

     - Parameters:
         - elements: A sequence of `Symbol`-`AbstractGrammar` pairs from which
                     to create a `Grammar`.
     */
    public init(dictionaryLiteral elements: (Symbol, AbstractGrammar)...) {
        var abstractProductions = Dictionary.init(elements, uniquingKeysWith: {
                                                                (lv, rv) in
                                                                fatalError("Duplicate non-terminal name in grammar: \(rv)")
                                                            })
        // The default Grammar.startSymbol must be present in the dictionary
        // literal to declare the grammar's starting point.
        guard let startSymbolGrammar = abstractProductions[Grammar.startSymbol] else {
            fatalError("invalid Grammar literal: no start symbol found")
        }
        // The encoded start symbol must be a symbol.
        guard case let .Symbol(startSymbol) = startSymbolGrammar else {
            fatalError("invalid Grammar literal: start symbol must be instance of AbstractGrammar.Symbol")
        }
        // The encoded start symbol must correspond to a top-level production
        // name in the dictionary literal.
        guard abstractProductions.contains(startSymbol) else {
            fatalError("invalid Grammar literal: start symbol must correspond to a top-level symbol")
        }
        // If the start symbol is correctly defined, we proceed by removing the
        // placeholder start symbol from the dictionary.
        abstractProductions.removeValue(forKey: Grammar.startSymbol)
        // Top-level `Symbol`s are actually not permitted. Instead, we wrap them
        // in `Concatenation`s.
        abstractProductions.forEach {
            symbol, subgrammar in
            if case .Symbol = subgrammar {
                abstractProductions[symbol] = .Concatenation([subgrammar])
            }
        }
        // Lastly, we call the initializer.
        try! self.init(fromAbstractProductions: abstractProductions,
                       withStartSymbol: startSymbol)
    }
}

/// A simplified grammar specification language.
public indirect enum AbstractGrammar {
    /// An empty production.
    case Epsilon
    /// Either a terminal or non-terminal symbol.
    case Symbol(Symbol)
    /// A sequence of expressions that must be considered in-order.
    case Concatenation([AbstractGrammar])
    /// A collection of non-deterministic expressions.
    case Alternation([AbstractGrammar])
}

/// Allow `AbstractGrammar.Symbol`s to be created from string literals for
/// convenience.
extension AbstractGrammar: ExpressibleByStringLiteral {
    /// Creates an `AbstractGrammar` from a string literal. An empty string
    /// becomes `AbstractGrammar.Epsilon`, and other strings become instances of
    /// `AbstractGrammar.Symbol`.
    public init(stringLiteral string: String) {
        if string == "" {
            self = .Epsilon
        } else {
            self = .Symbol(string)!
        }
    }
}

/// Allow `AbstractGrammar.Alternation`s to be created from array literals.
extension AbstractGrammar: ExpressibleByArrayLiteral {
    /// Creates an `AbstractGrammar.Alternation` from an array of
    /// `AbstractGrammar`s. If the array only contains one element, it will be
    /// used as the sole production (i.e., no alternate is created).
    public init (arrayLiteral elements: AbstractGrammar...) {
        if elements.isEmpty {
            self = .Alternation([])
        } else if elements.count == 1 {
            self = elements.first!
        } else {
            self = .Alternation(elements)
        }
    }
}

/// Use ++ for creating sequences of grammar expressions.
infix operator ++ : AdditionPrecedence

/// Concatenates two `AbstractGrammar`s into a single
/// `AbstractGrammar.Concatenation`.
public func ++ (lhs: AbstractGrammar, rhs: AbstractGrammar) -> AbstractGrammar {
    switch (lhs, rhs) {
    case let (.Concatenation(lcs), .Concatenation(rcs)):
        return .Concatenation(lcs + rcs)
    case let (.Concatenation(lcs), _):
        return .Concatenation(lcs + [rhs])
    case let (_, .Concatenation(rcs)):
        return .Concatenation([lhs] + rcs)
    case (_, _):
        return .Concatenation([lhs, rhs])
    }
}
