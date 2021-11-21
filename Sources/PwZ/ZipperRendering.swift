public class Node {
    public let type: NodeType
    public var parents: [Node]
    public var children: [Node]
    public let name: String
    public let id: Int

    init(type: NodeType, name: String, parents: [Node] = [], children: [Node] = [], nodeID: Int = -1) {
        self.type = type
        self.parents = parents
        self.children = children
        var myName: String
        switch (self.type) {
        case .zip:
            myName = "<\(name)>"
        case .exp:
            myName = "(\(name))"
        case .cxt:
            myName = "[\(name)]"
        }
        if nodeID != -1 {
            myName += " @ \(nodeID)"
        }
        self.name = myName
        self.id = nodeID
    }

    public enum NodeType {
        case zip
        case exp
        case cxt
    }
}

extension Node: Equatable {
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

/// A dictionary-like struct that uses `ObjectIdentifier`s as keys.
fileprivate struct IdentityDict<T> {
    private var dict = [ObjectIdentifier : T]()

    subscript(_ key: AnyObject) -> T? {
        get { dict[ObjectIdentifier(key)] }
        set (newValue) { dict[ObjectIdentifier(key)] = newValue }
    }

    func contains(_ key: AnyObject) -> Bool {
        if let _ = self[key] {
            return true
        } else {
            return false
        }
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

public class NewGraph: CustomStringConvertible {
    public var nodes = [Node]()
    public var tops = [Node]()

    public init(fromZipper zipper: Zipper) {
        build(fromZipper: zipper)
    }

    public enum WorklistItem {
        case Exp(Expression, Node)
        case Cxt(MemoizationRecord, Node)
    }

    public func build(fromZipper zipper: Zipper) {
        var nodeCount = 0

        func addNode(type: Node.NodeType, name: String, parents: [Node] = [], children: [Node] = []) -> Node {
            let node = Node(type: type, name: name, parents: parents, children: children, nodeID: nodeCount)
            nodeCount += 1
            self.nodes.append(node)
            return node
        }

        var visitedExps = IdentityDict<Node>()
        var visitedMemoRecs = IdentityDict<[Node]>()
        var worklist = [WorklistItem]()

        let zipperNode = addNode(type: .zip, name: "z")

        switch(zipper.expression) {
        case .Tok:
            // Do nothing.
            break
        case let .Seq(_, children):
            children.forEach { worklist.append(.Exp($0, zipperNode)) }
        case let .Alt(children):
            children.forEach { worklist.append(.Exp($0, zipperNode)) }
        }
        worklist.append(.Cxt(zipper.context, zipperNode))

        while !worklist.isEmpty {
            let item = worklist.removeFirst()
            switch (item) {
            case let .Exp(expression, parent):
                if let node = visitedExps[expression] {
                    // This expression has been seen before. Be sure the parent
                    // was added previously as well.
                    if !node.parents.contains(parent) {
                        node.parents.append(parent)
                    }
                } else {
                    // This expression hasn't been seen before.
                    // Build a name.
                    let name: String
                    switch (expression.expressionCase) {
                    case let .Tok(token):
                        name = "Tok \"\(token.symbol)\" [tag: \(token.tag)]"
                    case let .Seq(symbol, _):
                        name = "Seq \"\(symbol)\""
                    case .Alt:
                        name = "Alt"
                    }
                    // Initialize a node.
                    let node = addNode(type: .exp, name: name, parents: [parent])
                    visitedExps[expression] = node
                    parent.children.append(node)
                    // Add to the worklist.
                    worklist.append(.Cxt(expression.memoizationRecord, node))
                    switch (expression.expressionCase) {
                    case .Tok:
                        break
                    case let .Seq(_, children):
                        children.forEach { worklist.append(.Exp($0, node)) }
                    case let .Alt(children):
                        children.forEach { worklist.append(.Exp($0, node)) }
                    }
                }
            case let .Cxt(memoizationRecord, child):
                if let nodes = visitedMemoRecs[memoizationRecord] {
                    // This memoization record has been seen before. Be sure the
                    // child was added previously as well.
                    nodes.forEach {
                        node in
                        if !node.children.contains(child) {
                            node.children.append(child)
                        }
                    }
                } else {
                    // This memoization record hasn't been seen before.
                    // Add an empty list of nodes for tracking.
                    visitedMemoRecs[memoizationRecord] = []
                    // Iterate over its captured contexts.
                    memoizationRecord.parentContexts.forEach {
                        contextCase in
                        // Build a name.
                        let name: String
                        switch (contextCase) {
                        case .TopC:
                            name = "TopC"
                        case let .SeqC(_, symbol, _, _):
                            name = "SeqC \"\(symbol)\""
                        case .AltC:
                            name = "AltC"
                        }
                        // Initialize a node.
                        let node = addNode(type: .cxt, name: name, children: [child])
                        visitedMemoRecs[memoizationRecord]!.append(node)
                        child.parents.append(node)
                        // Add to the worklist.
                        switch (contextCase) {
                        case .TopC:
                            tops.append(node)
                        case let .SeqC(memoRec, _, leftExps, rightExps):
                            worklist.append(.Cxt(memoRec, node))
                            leftExps.forEach { worklist.append(.Exp($0, node)) }
                            rightExps.forEach { worklist.append(.Exp($0, node)) }
                        case let .AltC(memoRec):
                            worklist.append(.Cxt(memoRec, node))
                        }
                    }
                }
                // TODO: resultExpression?
            }
        }
    }

    public func render(node: Node) -> String {
        var texts = [String]()
        var rendered = IdentityDict<Void>()

        func render(node: Node, indent: Int) {
            if rendered.contains(node) {
                texts.append(String(repeating: " ", count: indent) + "... (\(node.name))")
                return
            }
            rendered[node] = ()
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

    public func renderD3Graph() -> String {
        var texts = [String]()

        func removeTrailingComma() {
            var lastString = texts.removeLast()
            lastString.removeLast()
            texts.append(lastString)
        }

        texts.append("{")

        // Specify the tree roots.
        texts.append("  \"roots\": [")
        tops.forEach { texts.append("    \($0.id),") }
        removeTrailingComma()
        texts.append("  ],")

        // List all the nodes.
        texts.append("  \"nodes\": [")
        nodes.forEach {
            node in
            let safeName = String(node.name.map { $0 == "\"" ? "'" : $0} )
            // let safeName = node.name.replacingOccurrences(of: "\"", with: "\\\"", options: .literal, range: nil)
            texts.append("    { \"id\": \(node.id), \"name\": \"\(safeName)\" },")
        }
        removeTrailingComma()
        // End the list of nodes.
        texts.append("  ],")

        // List the links.
        func makeLink(_ source: Int, _ target: Int) {
            texts.append("    { \"source\": \(source), \"target\": \(target) },")
        }
        texts.append("  \"links\": [")
        nodes.forEach {
            node in
            switch (node.type) {
            case .zip:
                // Points up to parents and down to children.
                node.parents.forEach {
                    parent in
                    makeLink(node.id, parent.id)
                }
                node.children.forEach {
                    child in
                    makeLink(node.id, child.id)
                }
            case .exp:
                // Points down to children.
                node.children.forEach {
                    child in
                    makeLink(node.id, child.id)
                }
            case .cxt:
                // Points up to parents.
                node.parents.forEach {
                    parent in
                    makeLink(node.id, parent.id)
                }
            }
        }
        removeTrailingComma()
        // End the list of links.
        texts.append("  ]")

        texts.append("}")
        return texts.joined(separator: "\n")
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
            print("  !!! PROCESSING ZIPPER: \(index)")
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
        if parent.type == .zip {
            print("  ! ZIPPER")
        }
        print("buildDown with parent: \(parent.name)")
        if checkMembership, let node = expressionNodes[expression] {
            node.parents.append(parent)
            print("buildDown return early")
            return
        }
        print("buildDown full")
        // Generate a name for this node.
        let name: String
        switch (expression.expressionCase) {
        case let .Tok(token):
            name = "\"\(token.symbol)\" [tag: \(token.tag)]"
        case let .Seq(symbol, _):
            name = "● \"\(symbol)\""
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
        if child.type == .zip {
            print("  ! ZIPPER")
        }
        print("buildUp with child: \(child.name)")
        if let nodes = memoizationNodes[memoizationRecord] {
            if addChild {
                nodes.forEach { $0.children.append(child) }
            }
            // nodes.forEach { if !$0.children.contains(where: { $0 === child} ) { $0.children.append(child) } }
            print("buildUp return early")
            return
        }
        print("buildUp full")
        memoizationRecord.parentContexts.forEach {
            contextCase in
            // Generate a name for this node.
            let name: String
            switch (contextCase) {
            case .TopC:
                name = "⊤"
            case let .SeqC(_, symbol, _, _):
                name = "● \"\(symbol)\""
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
                print("  ! ADDED TOP")
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
