/**
 The `ReferenceArray` is a wrapper around the standard `Array` that provides
 reference semantics for mutable array objects.

 Only the necessary methods are implemented.
 */
public class ReferenceArray<Element: Equatable>: ExpressibleByArrayLiteral {
    /// The internal array that the class provides a reference to.
    fileprivate var items: [Element] = []

    /// Initializes the array from an existing sequence of values.
    public init<S: Sequence>(_ sequence: S)
      where S.Iterator.Element == Element {
        for element in sequence {
            append(element)
        }
    }

    /**
     Initializes the array from an array literal. This means that you can write
     code such as:

         let ref: ReferenceArray<Int> = [0, 1, 2]

     Alternatively, type inference can remove the need to write the reference
     array's type at call sites:

         func foo(_ ref: ReferenceArray<Int>) {
             ...
         }

         foo([2, 4, 8])
     */
    public required convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    /// Adds a new element to the array at the end position.
    public func append(_ element: Element) {
        items.append(element)
    }

    /// Adds a new element to the array at a specific position.
    public func insert(_ element: Element, at position: Int) {
        items.insert(element, at: position)
    }

    /// Adds a new element to the array at the start position.
    public func insert(_ element: Element) {
        insert(element, at: 0)
    }
}

extension ReferenceArray: Sequence {
    /// Iterators over the `ReferenceArray` are generic.
    public typealias Iterator = AnyIterator<Element>

    /// Creates a new iterator for the `ReferenceArray`, wrapped as an
    /// `AnyIterator` to keep it generic.
    public func makeIterator() -> Iterator {
        var iterator = items.makeIterator()

        return AnyIterator {
            return iterator.next()
        }
    }
}

extension ReferenceArray: Collection {
    /// The type of indices into the `ReferenceArray`.
    public typealias Index = Int

    /// The start index of the collection.
    public var startIndex: Index {
        return items.startIndex
    }

    /// The end index of the collection.
    public var endIndex: Index {
        return items.endIndex
    }

    /**
     `ReferenceArray`s can be accessed by subscript, e.g.:

         let ref: ReferenceArray<Int> = [1, 2, 3]
         let firstValue = ref[0]
     */
    public subscript(position: Index) -> Iterator.Element {
        precondition((startIndex ..< endIndex).contains(position), "out of bounds")
        let element = items[position]
        return element
    }

    /// Produces the index immediately after the given index.
    public func index(after i: Index) -> Index {
        return i + 1
    }
}

extension ReferenceArray: Equatable where Element: Equatable {
    /// When the elements of a `ReferenceArray` are `Equatable`, the
    /// `ReferenceArray` itself is `Equatable`.
    public static func == (lhs: ReferenceArray<Element>, rhs: ReferenceArray<Element>) -> Bool {
        return lhs.items == rhs.items
    }
}
