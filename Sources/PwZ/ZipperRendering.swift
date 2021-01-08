public class Node {
    public let type: NodeType
    public var parents: [Node]
    public var children: [Node]
    public let name: String

    init(type: NodeType, name: String, parents: [Node] = [], children: [Node] = []) {
        self.type = type
        self.parents = parents
        self.children = children
        switch (self.type) {
        case .zip:
            self.name = "<\(name)>"
        case .exp:
            self.name = "(\(name))"
        case .cxt:
            self.name = "[\(name)]"
        }
    }

    public enum NodeType {
        case zip
        case exp
        case cxt
    }
}

/// A dictionary-like struct that uses `ObjectIdentifier`s as keys.
fileprivate struct IdentityDict<T> {
    private var dict = [ObjectIdentifier : T]()

    subscript(_ key: AnyObject) -> T? {
        get { dict[ObjectIdentifier(key)] }
        set (newValue) { dict[ObjectIdentifier(key)] = newValue }
    }
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

public class Graph: CustomStringConvertible {
    fileprivate var expressionNodes = IdentityDict<Node>()
    fileprivate var memoizationNodes = IdentityDict<[Node]>()

    public var tops = [Node]()

    public var nodeCount = 0

    public init(fromZippers zippers: [Zipper]) {
        zippers.enumerated().forEach {
            index, zipper in
            let zipperNode = Node(type: .zip, name: "z\(index)")
            buildUp(fromMemoizationRecord: zipper.context, withChildNode: zipperNode, addChild: true)
            buildDown(fromExpression: Expression(expressionCase: zipper.expression), withParentNode: zipperNode, checkMembership: false)
        }
    }

    public convenience init(fromExpressions expressions: [Expression]) {
        let memRec = Sentinel.of(MemoizationRecord.self)
        memRec.parentContexts.append(.TopC)
        let zippers = expressions.map { ($0.expressionCase, memRec) }
        self.init(fromZippers: zippers)
    }

    func buildDown(fromExpression expression: Expression, withParentNode parent: Node, checkMembership: Bool = true) {
        if checkMembership, let node = expressionNodes[expression] {
            node.parents.append(parent)
            return
        }
        // Generate a name for this node.
        let name: String
        switch (expression.expressionCase) {
        case let .Tok(token):
            name = "\"\(token.symbol)\" [tag: \(token.tag)]"
        case let .Seq(symbol, _):
            name = "× \"\(symbol)\""
        case .Alt:
            name = "+"
        }
        // Instantiate the node.
        let node = Node(type: .exp, name: name, parents: [parent])
        // Register the new node with the graph and with its parent.
        if checkMembership {
            expressionNodes[expression] = node
        }
        parent.children.append(node)
        // Process other potential parents.
        buildUp(fromMemoizationRecord: expression.memoizationRecord, withChildNode: node)
        // If this node has children, process them.
        switch (expression.expressionCase) {
        case .Tok:
            break
        case let .Seq(_, children):
            children.forEach { buildDown(fromExpression: $0, withParentNode: node) }
        case let .Alt(children):
            children.forEach { buildDown(fromExpression: $0, withParentNode: node) }
        }
    }

    func buildUp(fromMemoizationRecord memoizationRecord: MemoizationRecord, withChildNode child: Node, addChild: Bool = false) {
        if let nodes = memoizationNodes[memoizationRecord] {
            if addChild {
                nodes.forEach { $0.children.append(child) }
            }
            // nodes.forEach { if !$0.children.contains(where: { $0 === child} ) { $0.children.append(child) } }
            return
        }
        memoizationRecord.parentContexts.forEach {
            contextCase in
            // Generate a name for this node.
            let name: String
            switch (contextCase) {
            case .TopC:
                name = "⊤"
            case let .SeqC(_, symbol, _, _):
                name = "× \"\(symbol)\""
            case .AltC:
                name = "+"
            }
            // Instantiate the node.
            let node = Node(type: .cxt, name: name, children: [child])
            // Register the new node with the graph and with its child.
            memoizationNodes[memoizationRecord] = (memoizationNodes[memoizationRecord] ?? []) + [node]
            child.parents.append(node)
            // If this node has parents, process them.
            switch (contextCase) {
            case .TopC:
                tops.append(node)
            case let .SeqC(memoizationRecord, _, leftChildren, rightChildren):
                buildUp(fromMemoizationRecord: memoizationRecord, withChildNode: node)
                leftChildren.forEach { buildDown(fromExpression: $0, withParentNode: node) }
                rightChildren.forEach { buildDown(fromExpression: $0, withParentNode: node) }
            case let .AltC(memoizationRecord):
                buildUp(fromMemoizationRecord: memoizationRecord, withChildNode: node)
            }
        }
    }

    public func render(node: Node) -> String {
        var texts = [String]()

        func render(node: Node, indent: Int) {
            texts.append(String(repeating: " ", count: indent) + node.name)
            node.children.forEach { render(node: $0, indent: indent + 2) }
        }

        render(node: node, indent: 0)

        return texts.joined(separator: "\n")
    }

    public var description: String {
        let renderings = tops.map(render)
        return renderings.joined(separator: "\n")
    }
}
