The Zipper is a data structure introduced by Huet in 1997. Essentially, it
allows for the efficient navigation of tree-like structures with the added bonus
of being able to *suspend* a navigation in-progress and resume it at a later
time. The `Zipper` is, of course, a key component of the Parsing with Zippers
(PwZ) algorithm.

In this algorithm, we use the zipper to suspend the derivation of a grammar at
certain points, which allows for the efficient continuation of an in-progress
derivation. This produces a significant improvement over previous derivative
parsers.

The `Zipper` consists of an `ExpressionCase` and a `MemoizationRecord`.
