/**
 Derives the grammar with respect to the given token, returning an
 `IncompleteParseState` representing the algorithm's state after this derivative
 is taken. A position is used to index `MemoizationRecord`s so we know when old
 records have gone stale.

 The implementation is divided into four sub-functions, which can be separated
 into two categories: two functions moving the current position *down* the
 grammar, and two functions moving the current position *up* the grammar.

 The theory of the procedure is given in the paper. This particular
 implementation is more verbose than the paper's version. The hope is that this
 version may be easier to read for those who prefer descriptive names. Comments
 have been added in a few places to explain the general principles at play, but
 a more thorough discussion is, of course, left to the paper.

 - Parameters:
     - zipper: A representation of the "current point" in the grammar.
     - token: The `Token` that we are taking the derivative with respect to. In
              other words, we are attempting to see if one of the next available
              atomic `Tok` positions in the grammar matches this token, in which
              case the derivative is successful.
     - position: The current index into the list of input `Token`s. This is used
                 to ensure we don't use stale memoization records.
     - worklist: An array where to-be-resumed `Zipper`s will be stored. Existing
                 values are not looked at in calls to `derive`; the list is only
                 appended to. This is given as `inout` because parallel
                 (non-deterministic) derivatives should contribute to the same
                 worklist.
     - tops: An array where potentially complete parses will be stored. This
             array is used similarly to `worklist`.
 */
func derive(_ zipper: Zipper,
            withRespectTo token: Token,
            atPosition position: Position,
            suspendingZippersTo worklist: inout [Zipper],
            recordingTopExpressionsTo tops: inout [Expression]) {
    // Destructure the pairs.
    let (tag, symbol) = token
    let (expressionCase, memoizationRecord) = zipper

    func deriveDown(fromContext context: ContextCase, toExpression expression: Expression) {
        // Check if the expression's memoization record is current.
        if position == expression.memoizationRecord.startPosition {
            // The record is current, so we add the parent context to the
            // recorded list of contexts.
            expression.memoizationRecord.parentContexts.insert(context, at: 0)
            // Check if the expression's memoization record has been derived
            // *up* over during this step of derivation.
            if position == expression.memoizationRecord.endPosition {
                // If the memoization record's end position aligns with the
                // current input position, then it must already have a result
                // expression associated with it. Therefore, we continue the
                // derivation upwards through that expression.
                deriveUp(fromExpression: expression.memoizationRecord.resultExpression,
                         toContext: context)
            }
        } else {
            // The record is stale, so we replace it with a new one.
            let memoizationRecord = MemoizationRecord(startPosition: position,
                                                      endPosition: Sentinel.of(Position.self),
                                                      parentContexts: [context],
                                                      resultExpression: Sentinel.of(Expression.self))
            expression.memoizationRecord = memoizationRecord
            // Then, we derive downwards over the expression's case using the
            // new memoization record as a parent.
            deriveDown(fromMemoizationRecord: memoizationRecord,
                       toExpressionCase: expression.expressionCase)
        }
    }

    func deriveDown(fromMemoizationRecord memoizationRecord: MemoizationRecord, toExpressionCase expressionCase: ExpressionCase) {
        switch (expressionCase) {
        case let .Tok(token: (tokenTag, _)):
            // Deriving down over an atomic token is the last step in a
            // derivation pass.
            if tokenTag == tag {
                // When the tags match, we've had a successful parse. Leave a
                // labeled (but empty!) `Seq` behind in its place.
                //
                // NOTE: We use the `symbol` that we're deriving with instead of
                //       the symbol of the tag on purpose. If the grammar's
                //       tokens are meant to be generic (i.e., not literals;
                //       e.g., the grammar may contain an INT token that
                //       represents all integers instead of a specific one),
                //       then we want to use the symbol from the input stream
                //       (the current instance) instead of the symbol from the
                //       token definition (the generic representation).
                print("matched symbol: \(symbol)")  // XXX
                worklist.insert((.Seq(symbol: symbol, expressions: []), memoizationRecord), at: 0)
            } else {
                // When the tags don't match, the parse fails, so we do nothing.
            }
        case let .Seq(symbol, expressions):
            if expressions.isEmpty {
                // An empty `Seq` indicates a previously successful parse. Just
                // go back up!
                deriveUp(fromExpressionCase: expressionCase, toMemoizationRecord: memoizationRecord)
            } else {
                // A non-empty `Seq` indicates a sequence of expressions we
                // should derive over in-order. We pop the first one off,
                // establish a trail to move back up, then continue down.
                //
                // NOTE: A curious thing happens here: we leave behind an `AltC`
                //       context instead of a `SeqC`. This is because the first
                //       expression in the sequence may be *nullable*, in which
                //       case it would be permissible to parse over the *second*
                //       expression in the sequence instead. Creating an `AltC`
                //       parent context here handles this non-determinism.
                let (expression, expressions) = (expressions[0], Array(expressions[1...]))
                let memoizationRecord = MemoizationRecord(startPosition: memoizationRecord.startPosition,
                                                          endPosition: Sentinel.of(Position.self),
                                                          parentContexts: [.AltC(memoizationRecord: memoizationRecord)],
                                                          resultExpression: Sentinel.of(Expression.self))
                deriveDown(fromContext: .SeqC(memoizationRecord: memoizationRecord,
                                              symbol: symbol,
                                              leftExpressions: [],
                                              rightExpressions: expressions),
                           toExpression: expression)
            }
        case let .Alt(expressions):
            // An `Alt` simply represents a non-determinism in the grammar, so
            // we continue the derivation downwards over each of the children
            // expressions.
            expressions.forEach { deriveDown(fromContext: .AltC(memoizationRecord: memoizationRecord), toExpression: $0) }
        }
    }

    func deriveUp(fromExpressionCase expressionCase: ExpressionCase, toMemoizationRecord memoizationRecord: MemoizationRecord) {
        // We construct a new parent `Expression` for the `ExpressionCase` with
        // its own fresh `MemoizationRecord`.
        let expression = Expression(expressionCase: expressionCase)
        // Then, we update the parent memoization record we came in with to
        // point to our new `Expression`, noting that the record is now
        // considered complete (i.e., its result is marked as corresponding only
        // to the current input position).
        memoizationRecord.endPosition = position
        memoizationRecord.resultExpression = expression
        // Now, we continue the upwards derivation over each saved parent
        // context in the original memoization record.
        memoizationRecord.parentContexts.forEach { deriveUp(fromExpression: expression, toContext: $0) }
    }

    func deriveUp(fromExpression expression: Expression, toContext context: ContextCase) {
        switch (context) {
        case .TopC:
            // Attempting to derive up over a `.TopC` really means we've
            // completed our parse. Woohoo!
            print("derived up over TopC with expression:")
            print(expression)
            print("")
            tops.insert(expression, at: 0)
        case let .SeqC(memoizationRecord, symbol, leftExpressions, rightExpressions):
            if rightExpressions.isEmpty {
                // When there are no more expressions to the right, we have
                // completed our parse of the sequence. We continue to go
                // upwards in our derivation.
                deriveUp(fromExpressionCase: .Seq(symbol: symbol, expressions: ([expression] + leftExpressions).reversed()),
                         toMemoizationRecord: memoizationRecord)
            } else {
                // If there are still right siblings of the current
                // expression, we have to try deriving over them (due to the
                // potential of nullability in each of them). We will continue
                // our derivation downwards over the next sibling.
                let (rightExpression, rightExpressions) = (rightExpressions[0], Array(rightExpressions[1...]))
                deriveDown(fromContext: .SeqC(memoizationRecord: memoizationRecord,
                                              symbol: symbol,
                                              leftExpressions: [expression] + leftExpressions,
                                              rightExpressions: rightExpressions),
                           toExpression: rightExpression)
            }
        case let .AltC(memoizationRecord):
            // Check whether the context's memoization record has a result
            // recorded.
            if position == memoizationRecord.endPosition {
                // There's a result, so it should correspond to an alternate and
                // we should be able to add the current expression to its list
                // of successfully parsed expressions.
                if case let .Alt(expressions) = memoizationRecord.resultExpression.expressionCase {
                    expressions.insert(expression, at: 0)
                } else {
                    // Clearly, something went wrong.
                    fatalError("Expected Alt while deriving upwards.")
                }
            } else {
                // No result is recorded. It'll be produced in the next step up.
                deriveUp(fromExpressionCase: .Alt(expressions: [expression]),
                         toMemoizationRecord: memoizationRecord)
            }
        }
    }

    // The start of a derivation goes upwards.
    //
    // This is because in most cases, we're resuming from a position just after
    // an atomic `Tok` has been parsed. The only exception is when beginning a
    // new parse from the root of the grammar, which is why the
    // `initializeZipper(fromExpression:)` function must be called to properly
    // get us started.
    deriveUp(fromExpressionCase: expressionCase, toMemoizationRecord: memoizationRecord)
}

public struct IncompleteParseState {
    public let worklist: [Zipper]
    public let tops: [Expression]
    public let position: Position
    public let token: Token?
}

public enum Parse {
    case Incomplete(state: IncompleteParseState)
    case Complete(parseTrees: [Expression])

    public init(_ root: Expression) {
        let topMemoizationRecord = MemoizationRecord(startPosition: Sentinel.of(Position.self),
                                                     endPosition: Sentinel.of(Position.self),
                                                     parentContexts: [.TopC],
                                                     resultExpression: Sentinel.of(Expression.self))
        let seqMemoizationRecord = MemoizationRecord(startPosition: Sentinel.of(Position.self),
                                                     endPosition: Sentinel.of(Position.self),
                                                     parentContexts: [.SeqC(memoizationRecord: topMemoizationRecord,
                                                                            symbol: Sentinel.of(Symbol.self),
                                                                            leftExpressions: [],
                                                                            rightExpressions: [root])],
                                                     resultExpression: Sentinel.of(Expression.self))
        let initialZipper: Zipper = (.Seq(symbol: Sentinel.of(Symbol.self), expressions: []), seqMemoizationRecord)
        let initialState = IncompleteParseState(worklist: [initialZipper], tops: [Expression](), position: -1, token: nil)
        self = .Incomplete(state: initialState)
    }

    public func parse(withToken token: Token) -> Parse {
        switch (self) {
        case let .Incomplete(state):
            let nextPosition = state.position + 1
            var nextWorklist = [Zipper]()
            var nextTopExpressions = [Expression]()
            state.worklist.forEach {
                zipper in
                // print("parsing zipper")
                // print(zipper)
                // print("with respect to: \(token.symbol)")
                print("parsing with respect to: \(token.symbol)")
                derive(zipper,
                       withRespectTo: token,
                       atPosition: nextPosition,
                       suspendingZippersTo: &nextWorklist,
                       recordingTopExpressionsTo: &nextTopExpressions)
            }
            let resultState = IncompleteParseState(worklist: nextWorklist, tops: nextTopExpressions, position: nextPosition, token: token)
            return .Incomplete(state: resultState)
        case .Complete:
            // TODO: This should raise an error?
            return self
        }
    }

    public func finish() -> Parse {
        switch (self) {
        case .Incomplete:
            let nextParse = self.parse(withToken: Sentinel.of(Token.self))
            guard case let .Incomplete(state) = nextParse else {
                fatalError("this shouldn't happen")
            }
            return .Complete(parseTrees: state.tops.map {
                                 expression -> Expression in
                                 switch (expression.expressionCase) {
                                 case let .Seq(_, expressions) where expressions.count >= 2:
                                     // TODO: Why do we throw away the first expression? This is done in
                                     //       the OCaml code as well, but I don't recall the reason.
                                     return expressions[1]
                                 default:
                                     fatalError("Encountered unexpected case when unwrapping top expression.")
                                 }
                             })
        case .Complete:
            return self
        }
    }

    public func extractParseTrees() -> [Expression] {
        print("extracting parse trees")
        switch (self) {
        case .Incomplete:
            return self.finish().extractParseTrees()
        case let .Complete(parseTrees):
            return parseTrees
        }
    }

    public func extractState() -> IncompleteParseState? {
        if case let .Incomplete(state) = self {
            return state
        } else {
            return nil
        }
    }
}

public func incompletelyParse(expression: Expression, withRespectTo tokens: [Token]) -> Parse {
    return tokens.reduce(Parse(expression)) { $0.parse(withToken: $1) }
}

public func fullyParse(expression: Expression, withRespectTo tokens: [Token]) -> [Expression] {
    return incompletelyParse(expression: expression, withRespectTo: tokens).extractParseTrees()
}

public func constructIncompleteParseSequence(parsingExpression expression: Expression, withRespectTo tokens: [Token]) -> [Parse] {
    return tokens.reduce(into: [Parse(expression)]) {
        sequence, token in
        sequence.append(sequence.last!.parse(withToken: token))
    }
}

public func constructCompleteParseSequence(parsingExpression expression: Expression, withRespectTo tokens: [Token]) -> [Parse] {
    var sequence = constructIncompleteParseSequence(parsingExpression: expression, withRespectTo: tokens)
    sequence.append(sequence.last!.finish())
    return sequence
}
