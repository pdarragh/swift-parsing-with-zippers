import XCTest
@testable import PwZ

func print(_ string: String) {
    if let data = (string + "\n").data(using: .utf8) {
        FileHandle.standardOutput.write(data)
    }
}

struct GrammarTest {
    let grammar: Grammar
    let success: [(String, Int?)]
    let failure: [String]
}

let grammarTests: [GrammarTest] =
  [ GrammarTest(  // 1
      grammar:
        [ Grammar.startSymbol: "e"
        , "e": "e"
        ],
      success: [],
      failure: ["", "A", "AB", "BB", "ABA"]
    )
  , GrammarTest(  // 2
      grammar:
        [ Grammar.startSymbol: "e"
        , "e": "A" ++ "e"
        ],
      success: [],
      failure: ["", "A", "AA", "AAAAAAAAAAAAAAAAAAAAAAA"]
    )
  , GrammarTest(  // 3
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "A" ++ "e"
            , "e" ++ "A"
            ]
        ],
      success: [],
      failure: ["", "A", "AA", "AAA", "AAAA"]
    )
  , GrammarTest(  // 4
      grammar:
        [ Grammar.startSymbol: "e"
        , "e": "A" ++ "e" ++ "A"
        ],
      success: [],
      failure: ["", "A", "AA", "AAA", "AAAA"]
    )
  , GrammarTest(  // 5
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "e"
            , "A" ++ "e"
            , ""
            ]
        ],
      success: [("", nil), ("A", nil), ("AA", nil), ("AAA", nil)],
      failure: []
    )
  , GrammarTest(  // 6
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "e"
            , "e" ++ "A"
            , ""
            ]
        ],
      success: [("", nil), ("A", nil), ("AA", nil), ("AAA", nil)],
      failure: []
    )
  , GrammarTest(  // 7
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "A" ++ "e" ++ "A"
            , "B" ++ "e" ++ "B"
            , ""
            ]
        ],
      success: [("", 1), ("AA", 1), ("BB", 1), ("ABBA", 1), ("ABBBBA", 1), ("ABBAABBA", 1)],
      failure: ["A", "B", "ABA", "ABA"]
    )
  , GrammarTest(  // 8
      grammar:
        [ Grammar.startSymbol: "e1"
        , "e1":
            [ "e2" ++ "A"
            , ""
            ]
        , "e2": "e1"
        ],
      success: [("", 1), ("A", 1), ("AA", 1), ("AAA", 1)],
      failure: []
    )
  , GrammarTest(  // 9
      grammar:
        [ Grammar.startSymbol: "e1"
        , "e1":
            [ "A" ++ "e2"
            , ""
            ]
        , "e2": "e1"
        ],
      success: [("", 1), ("A", 1), ("AA", 1), ("AAA", 1)],
      failure: []
    )
  , GrammarTest(  // 10
      grammar:
        [ Grammar.startSymbol: "e1"
        , "e1": "e2"
        , "e2": "e1"
        ],
      success: [],
      failure: ["", "A", "AA"]
    )
  , GrammarTest(  // 11
      grammar:
        [ Grammar.startSymbol: "e1"
        , "e1":
            [ "e2"
            , "A"
            ]
        , "e2": "e1"
        ],
      success: [("A", nil)],
      failure: ["", "AA", "AAA"]
    )
  , GrammarTest(  // 12
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "A"
            , "e" ++ "B" ++ "e"
            ]
        ],
      success: [("A", 1), ("ABA", 1), ("ABABA", 2), ("ABABABABABABABA", 429)],
      failure: [""]
    )
  , GrammarTest(  // 13d
      grammar:
        [ Grammar.startSymbol: "e"
        , "e":
            [ "A"
            , "e" ++ "e"
            ]
        ],
      success: [("A", 1), ("AA", 1), ("AAA", 2), ("AAAA", 5)],
      failure: [""]
    )
  ]

final class PwZTests: XCTestCase {
    func testGrammars() {
        grammarTests.forEach {
            grammarTest in
            grammarTest.success.forEach {
                pair in
                let (string, expectedTreeCount) = pair
                let trees = grammarTest.grammar.parse(inputTokens: try! grammarTest.grammar.tokenizeStrings(string.map { String($0) } ))
                print(grammarTest.grammar.root)
                print(trees)
                if let expectedTreeCount = expectedTreeCount {
                    XCTAssertEqual(trees.count, expectedTreeCount)
                }
            }
        }
    }

    static var allTests = [
        ("testGrammars", testGrammars),
    ]
}
