/// A dictionary-like struct that uses `ObjectIdentifier`s as keys.
fileprivate struct IdentityDict<T> {
    private var dict = [ObjectIdentifier : T]()

    subscript(_ key: AnyObject) -> T? {
        get { dict[ObjectIdentifier(key)] }
        set (newValue) { dict[ObjectIdentifier(key)] = newValue }
    }
}

/// This protocol allows us to use built-in arrays alongside the custom
/// `ReferenceArray` using the same code. This could be thrown away if I were
/// okay with more code duplication, but I'm extra, so too bad.
fileprivate protocol SplitableCollection: Collection {
    /// Get the first element of a collection, if the collection is not empty.
    var first: Element? { get }
    /// Get a slice of the collection containing all but the first element.
    var rest: ArraySlice<Element> { get }
}

/// Give built-in arrays the `rest` property.
extension Array: SplitableCollection {
    var rest: ArraySlice<Element> { self[1...] }
}

/// Give `ReferenceArray`s the `first` and `rest` properties.
extension ReferenceArray: SplitableCollection {
    var first: Element? { self.items.first }
    var rest: ArraySlice<Element> { self.items[1...] }
}

/**
 Renders an `Expression` to a string ready for printing. Recursive references to
 expressions will be abbreviated and the referred-to expressions annotated with
 the abbreviation for reference.

 NOTE: This function will not follow recursive references, but it still iterates
       over the entire grammar structure a few times to produce a pretty output.
       It is recommended that the function is not run often if performance is a
       concern.

 - Parameters:
     - expression: The root expression of a grammar to render for printing.
 - Returns: A string representing the given expression.
 */
fileprivate func render(expression root: Expression) -> String {
    // Expressions are assigned reference numbers to handle recursion.
    var expressionNumbers = IdentityDict<Int>()
    var nextExpressionNumber = 0
    // The depth-print map tracks whether, at a given tree depth, a given
    // expression ought to be printed (true) or abbreviated (false).
    var depthPrintMap = [Int : IdentityDict<Bool>]()

    // Initialize a queue for breadth-first traversal starting at the root. The
    // integer component of the pair is the depth of the paired expression.
    var queue = [(root, 0)]
    // Begin a breadth-first traversal.
    while !queue.isEmpty {
        let (expression, depth) = queue.removeFirst()
        // We ensure the depth-print map is initialized for the current depth.
        if depthPrintMap[depth] == nil {
            depthPrintMap[depth] = IdentityDict<Bool>()
        }
        // Check if the expression is a token. We will always print tokens.
        if case .Tok = expression.expressionCase {
            depthPrintMap[depth]![expression] = true
        }
        // Otherwise, we check if the current expression already has a reference
        // number assigned.
        if let _ = expressionNumbers[expression] {
            // If a reference number exists, it's because we've already visited
            // this expression. That means at this point in the tree, we should
            // abbreviate the output.
            //
            // NOTE: This behavior assumes that the grammar does not have both
            //       a first appearance of an expression as well as a reference
            //       to that expression at the same depth. It is impossible to
            //       write such a grammar using the exposed grammar construction
            //       API, but it is possible to construct such a grammar using
            //       the `Expression` et al. types manually.
            //
            // FIXME: Address this problem in a more principled manner.
            depthPrintMap[depth]![expression] = false
        } else {
            // No reference number exists, so we need to process the expression.
            // First, we know we'll need to print this expression in the output.
            depthPrintMap[depth]![expression] = true
            // We also assign it a reference number so we abbreviate any
            // references to this expression later in the grammar.
            expressionNumbers[expression] = nextExpressionNumber
            nextExpressionNumber += 1
            // Lastly, we iterate over the expression's children (if any),
            // incrementing the depth value appropriately.
            switch (expression.expressionCase) {
            case .Tok:
                break  // Tokens were already handled above, so ignore here.
            case let .Seq(_, expressions):
                expressions.forEach { queue.append(($0, depth + 1)) }
            case let .Alt(expressions):
                expressions.forEach { queue.append(($0, depth + 1)) }
            }
        }
    }

    // We will build the output procedurally, storing the parts in an array.
    var texts = [String]()

    /**
     Renders a collection of child `Expression`s, adding output text to the
     `texts` array.

     - Parameters:
         - childExpressions: The collection of child expressions to render.
         - number: The reference number of the parent expression.
         - depth: The children's tree depth, used for rendering the children.
         - indentation: The leading indentation of the parent expression.
         - startingText: Text used for rendering the parent.
     */
    func render<T: SplitableCollection>(childExpressions: T,
                                       ofExpressionNumber number: Int,
                                       atDepth depth: Int,
                                       withIndentation indentation: Int,
                                       withStartingText startingText: String)
      where T.Element == Expression {
        // "Child" strings should start indented at least as far as the given
        // starting text. We then add the starting text to `texts`.
        let startingIndentation = indentation + startingText.count
        texts.append(startingText + "expressions: ")
        if childExpressions.isEmpty {
            // If there are actually no children, we just output the reference
            // number for the parent expression.
            texts.append("[])  // e\(number)")
        } else {
            // If there are children, we first output the parent expression's
            // reference number.
            texts.append("  // e\(number)")
            // Then, we print the children. However, the first child is handled
            // specially.
            let firstChildExpression = childExpressions.first!
            texts.append("\n" + String(repeating: " ", count: startingIndentation + 2) + "[ ")
            render(expression: firstChildExpression, withIndentation: startingIndentation + 4, atDepth: depth)
            // The subsequent child expressions are then rendered.
            childExpressions.rest.forEach {
                childExpression in
                texts.append("\n" + String(repeating: " ", count: startingIndentation + 2) + ", ")
                render(expression: childExpression, withIndentation: startingIndentation + 4, atDepth: depth)
            }
            // We cap off the parent expression.
            texts.append(" ])")
        }
    }

    /**
     Renders an `Expression`, adding output text to the `texts` array.

     - Parameters
         - expression: The expression to render.
         - indentation: The leading indentation of the expression.
         - depth: The tree depth of the expression.
     */
    func render(expression: Expression, withIndentation indentation: Int, atDepth depth: Int) {
        // Get the reference number of the current expression.
        let number = expressionNumbers[expression]!
        // Check whether we should render the expression.
        if depthPrintMap[depth]![expression]! {
            // We need to render the expression, so figure out what it is!
            switch (expression.expressionCase) {
            case let .Tok(token):
                // Tokens are rendered directly.
                texts.append(".Tok(token: \(token))  // e\(number)")
            case let .Seq(symbol, expressions):
                // Sequences are rendered recursively.
                render(childExpressions: expressions,
                       ofExpressionNumber: number,
                       atDepth: depth + 1,
                       withIndentation: indentation,
                       withStartingText: ".Seq(symbol: \"\(symbol)\", ")
            case let .Alt(expressions):
                // Alternates are also rendered recursively.
                render(childExpressions: expressions,
                       ofExpressionNumber: number,
                       atDepth: depth + 1,
                       withIndentation: indentation,
                       withStartingText: ".Alt(")
            }
        } else {
            // Use the abbreviation instead of rendering.
            texts.append("e\(number)")
        }
    }

    // Actually render the given grammar, starting at the root expression.
    render(expression: root, withIndentation: 0, atDepth: 0)

    // The result string is built by combining the collected text fragments.
    return texts.joined()
}

/// We extend the `Expression` to be printable as a string.
extension Expression: CustomStringConvertible {
    /// A rendering of the `Expression` to a string. Potentially expensive to
    /// compute, so avoid overuse.
    public var description: String {
        return render(expression: self)
    }
}
