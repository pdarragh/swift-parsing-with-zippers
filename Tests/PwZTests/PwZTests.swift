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


final class PwZTests: XCTestCase {

    var grammarTests: [GrammarTest] = []

    override func setUp() {
        grammarTests =
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
          , GrammarTest(  // 13
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
    }

    func testDerivations() {
        grammarTests.enumerated().forEach {
            testNumber, grammarTest in
            print("Testing derivatives on Grammar \(testNumber + 1)")
            grammarTest.success.forEach {
                pair in
                let (string, expectedTreeCount) = pair
                print("  Deriving with string: \"\(string)\"")
                let tokenChars = string.map { String($0) }
                let tokens: [PwZ.Token] = try! grammarTest.grammar.tokenizeSymbols(tokenChars)
                let trees = grammarTest.grammar.parse(withInputTokens: tokens)
                if let expectedTreeCount = expectedTreeCount {
                    // We need to check the number of parse trees.
                    let parseTrees = trees.flatMap(produceASTsFromExpression)
                    XCTAssertEqual(parseTrees.count, expectedTreeCount)
                } else {
                    XCTAssertTrue(trees.count > 0)
                }
            }
        }
    }

    static var allTests = [
      ("testDerivations", testDerivations),
      // ("testGrammars", testGrammars)
    ]
}
