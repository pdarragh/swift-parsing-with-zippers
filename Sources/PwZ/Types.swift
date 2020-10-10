////////////////////////////////////////
//
// Basic Types
//

/// Positions are the indices of tokens within the input string being parsed.
public typealias Position = Int

/// Symbols are the names given to productions within a grammar.
public typealias Symbol = String

/// Tags uniquely identify token types.
public typealias Tag = Int

/// Tokens are pairs consisting of a tag (identifying the type of the token) and
/// a symbol (identify the token's text).
public typealias Token = (tag: Tag, symbol: Symbol)


////////////////////////////////////////
//
// Core Types
//

/**
 Expressions form trees in a grammar. We use a class instead of a struct to
 preserve reference semantics because grammars may have duplicate references to
 the same expression multiple times.
 */
public class Expression: Equatable {
    /// Memoization records are pushed into expressions for efficiency.
    var memoizationRecord: MemoizationRecord
    /// The specific case of expression being represented in this `Expression`.
    var expressionCase: ExpressionCase

    /// Initializes a new `Expression` from a `MemoizationRecord` and internal
    /// `ExpressionCase`.
    public init(memoizationRecord memRec: MemoizationRecord,
                expressionCase expCase: ExpressionCase) {
        self.memoizationRecord = memRec
        self.expressionCase = expCase
    }

    /// `Expression`s are trivially `Equatable` from their components.
    public static func == (lhs: Expression, rhs: Expression) -> Bool {
        return
          lhs.memoizationRecord == rhs.memoizationRecord &&
          lhs.expressionCase == rhs.expressionCase
    }
}

/// ExpressionCases encode the particular type of `Expression` being dealt with.
public indirect enum ExpressionCase: Equatable {
    /// Tokens are trivial constructions.
    case Tok(token: Token)
    /// Sequences consist of a `Symbol` (naming the production represented by
    /// the sequence) and a sequence of `Expression`s.
    case Seq(symbol: Symbol, expressions: [Expression])
    /**
     Alternates are not named. They contain a collection of child `Expression`s.

     NOTE: The parsing implementation requires that this array can be updated
           in-place, so we use a `ReferenceArray` instead of a simple array.
     */
    case Alt(expressions: ReferenceArray<Expression>)

    /// `ExpressionCase`s are trivially `Equatable` from their components.
    public static func == (lhs: ExpressionCase, rhs: ExpressionCase) -> Bool {
        switch (lhs, rhs) {
        case let (.Tok(t1),      .Tok(t2)):      return t1 == t2
        case let (.Seq(s1, es1), .Seq(s2, es2)): return s1 == s2 && es1 == es2
        case let (.Alt(es1),     .Alt(es2)):     return es1 == es2
        default:                                 return false
        }
    }
}

/// ContextCases represent the context of a zipper's focused-on expression.
public indirect enum ContextCase: Equatable {
    /// The special case for the root of the grammar.
    case TopC
    /**
     Contexts for `Seq`, consisting of a `MemoizationRecord`, the sequence's
     production name, and two lists of `Expression`s representing the left and
     right siblings of the current focused-on expression in the zipper.
     */
    case SeqC(memoizationRecord: MemoizationRecord,
              symbol: Symbol,
              leftExpressions: [Expression],
              rightExpressions: [Expression])
    /// Contexts for `Alt`, which contains only a `MemoizationRecord`.
    case AltC(memoizationRecord: MemoizationRecord)

    /// `ContextCase`s are trivially `Equatable` from their components.
    public static func == (lhs: ContextCase, rhs: ContextCase) -> Bool {
        switch (lhs, rhs) {
        case     (.TopC,                     .TopC):                     return true
        case let (.SeqC(m1, s1, les1, res1), .SeqC(m2, s2, les2, res2)): return s1 == s2 && m1 == m2 && les1 == les2 && res1 == res2
        case let (.AltC(m1),                 .AltC(m2)):                 return m1 == m2
        default:                                                         return false
        }
    }
}

/// Memoization records are used to fix recursion, cycles, and duplication in
/// certain kinds of grammar traversals.
public class MemoizationRecord: Equatable {
    /// The position of the first token in the input to which this memoization
    /// record corresponds.
    let startPosition: Position
    /// The position of the last token in the input to which this memoization
    /// record corresponds.
    var endPosition: Position
    /// Parent contexts to which this memoization record shall report its
    /// result when needed.
    var parentContexts: [ContextCase]
    /// The expression resulting from the parse over the indicated region.
    var resultExpression: Expression {
        get { return _resultExpression! }
        set { self._resultExpression = newValue }
    }

    /// The internal representation of the expression.
    private var _resultExpression: Expression?

    /// Initializes a new `MemoizationRecord` from the necessary components.
    public init(startPosition: Position, endPosition: Position, parentContexts: [ContextCase], resultExpression: Expression?) {
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.parentContexts = parentContexts
        self._resultExpression = resultExpression
    }

    /// `MemoizationRecords` are trivially `Equatable` from their components.
    public static func == (lhs: MemoizationRecord, rhs: MemoizationRecord) -> Bool {
        return
          lhs.startPosition == rhs.startPosition &&
          lhs.endPosition == rhs.endPosition &&
          lhs.parentContexts == rhs.parentContexts &&
          lhs.resultExpression == rhs.resultExpression
    }
}


////////////////////////////////////////
//
// Zippers
//

/**
 A Zipper is a pair of an expression with its parent context, allowing for
 efficient traversal of tree-like objects. We have adjusted the traditional
 zipper to support alternates (representing non-determinisim) as well as cycles.
 */
public typealias Zipper = (expression: ExpressionCase, context: MemoizationRecord)
