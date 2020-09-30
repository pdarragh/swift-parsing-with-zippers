The fundamental building blocks of the Parsing with Zippers (PwZ) algorithm are
the grammar types, which together allow for the construction of grammar
expressions and their zippers.

A grammar expression might look like:

    Expression(
      memoizationRecord: Sentinel.of(MemoizationRecord.self),
      expressionCase: .Alt(expressions: [
        Expression(
          memoizationRecord: Sentinel.of(MemoizationRecord.self),
          expressionCase: .Seq(
            symbol: "seq_1",
            expressions: [
              Expression(
                memoizationRecord: Sentinel.of(MemoizationRecord.self),
                expressionCase: .Tok(token: (1, "a"))),
              Expression(
                memoizationRecord: Sentinel.of(MemoizationRecord.self),
                expressionCase: .Tok(token: (2, "b")))])),
        Expression(
          memoizationRecord: Sentinel.of(MemoizationRecord.self),
          expressionCase: .Tok(token: (3, "c")))]))

This corresponds to the grammar:

    S     ::= seq_1 | 'c'
    seq_1 ::= 'a' 'b'

Note that only tokens and sequences are labeled with symbols; alternates are not
labeled.

During execution of the PwZ algorithm, the (potentially recursive) tree of
`Expression`s is navigated until a `Token` is found. During this navigation down
the tree, the upward part of the tree is referenced as a *context*, encoded in
the `ContextCase` type. This is stored in a `MemoizationRecord`.

To better explain the (admittedly somewhat confusing) structure of these
grammars, I'll provide some ASCII diagrams.

Let's consider a very simple grammar consisting of a sequence (labeled "seq")
containing one token (labeled "a"). (This is a contrived example but should show
what's going on.)

    seq
     |
     a

Before any derivation commences, the actual layout of the types is something
like this. (Enumeration types, such as `ExpressionCase`, are abbreviated using
only their case name. The `MemoizationRecord` instances are labeled for later
use.)

```
                    Expression
                        |
                 +------|---------+
                 |                |
                 v                v
            .Seq("seq")    MemoizationRecord(m1)
                 |
                 |
                 v
             Expression
                 |
        +--------|--------+
        |                 |
        v                 v
    .Tok("a")      MemoizationRecord(m2)
```

If during navigation we find the `Zipper` positioned between the sequence node and
its child token node, the structure would look like this:

```
    MemoizationRecord(m1)
             ^
             |
        .SeqC("seq")
             ^
             |
    MemoizationRecord(m2)
             ^
             |
           Zipper
             |
             v
         .Tok("a")
```

The `Zipper` is formed from a pair of an `ExpressionCase` with a
`MemoizationRecord`. For more information, read the documentation on
[zippers](Zippers.html) or the Parsing with Zippers paper.
