/**
 The SentinelStruct exists only to produce a singleton from which sentinel
 values for various parsing-related types can be drawn. See the documentation
 for the `Sentinel` singleton value.
 */
public struct SentinelStruct {
    fileprivate let integer: Int = -1  // Both Position and Tag will use this value.
    fileprivate let symbol: Symbol = "<s_bottom>"
    fileprivate let token: Token
    /*
     The `expression` and `memoizationRecord` fields must be initialized
     dynamically because Swift does not allow mutually recursive references to
     be instantiated at the top level. Actually, that's the whole reason this
     struct exists... In a language like OCaml, these could simply be created at
     the top level with a `let rec`. Sigh.
     */
    fileprivate let expression: Expression
    fileprivate let memoizationRecord: MemoizationRecord

    fileprivate init() {
        self.token = (self.integer, "<t_eof>")
        self.memoizationRecord = MemoizationRecord(startPosition: self.integer,
                                                   endPosition: self.integer,
                                                   parentContexts: [],
                                                   resultExpression: nil)
        self.expression = Expression(memoizationRecord: self.memoizationRecord,
                                     expressionCase: .Alt(expressions: []))
        self.memoizationRecord.resultExpression = self.expression
    }

    /// Create a sentinel for any `Int` type.
    public func of(_: Int.Type) -> Int { return self.integer }

    /// Create a sentinel for a `Symbol`.
    public func of(_: Symbol.Type) -> Symbol { return self.symbol }

    /// Create a sentinel for a `Token`.
    public func of(_: Token.Type) -> Token { return self.token }

    /// Create a sentinel for an `Expression`.
    public func of(_: Expression.Type) -> Expression { return self.expression }

    /// Create a sentinel for a `MemoizationRecord`.
    public func of(_: MemoizationRecord.Type) -> MemoizationRecord { return self.memoizationRecord }
}

/**
 The Sentinel singleton allows for using the sentinel values of any of the
 parsing-related types. To use it, you call the `of` method with the desired
 type as an argument. For example, to get the sentinel for `Expression`s, do:

     Sentinel.of(Expression.self)

 Note the use of `.self` on the type, which passes the type as a value directly.
 The `Sentinel.of` method supports the following types:

   - `Position`
   - `Symbol`
   - `Tag`
   - `Token`
   - `Expression`
   - `MemoizationRecord`
 */
public let Sentinel = SentinelStruct()
