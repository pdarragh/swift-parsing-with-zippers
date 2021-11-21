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

    func _testDerivations() {
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

    func testGrammars() {
        print("BUILDING GRAMMAR:")
        let grammar: Grammar =
          [ Grammar.startSymbol: "e"
          , "e":
              [ "A"
              , "e" ++ "e"
              ]
          ]
        let inputString = "AAAA"
        let inputTokens: [PwZ.Token] = try! grammar.tokenizeSymbols(inputString.map { (c: Character) in String(c) })
        let exps = grammar.parse(withInputTokens: inputTokens)
        let asts = exps.flatMap(PwZ.produceASTsFromExpression)
        XCTAssertEqual(asts.count, 5)
    }

    // func testDeriveGrammar1

    static var allTests = [
//      ("testDerivations", testDerivations),
       ("testGrammars", testGrammars)
    ]
}
/*

import PwZ
func extractState(_ parse: Parse) -> IncompleteParseState? {
  if case let .Incomplete(state) = parse {
    return state
  } else {
    return nil
  }
}
let grammar: Grammar = [ Grammar.startSymbol: "e"
                       , "e":
                           [ "A"
                           , "e" ++ "e"
                           ]
                       ]

let tokens: [Token] = [(0, "A1"), (0, "A2"), (0, "A3"), (0, "A4")]
let seq = constructIncompleteParseSequence(parsingExpression: grammar.root, withRespectTo: tokens)
grammar.wipeMemoizationRecords()
let graphs = seq.map { Graph(fromZippers: extractState($0)!.worklist) }


graphs.enumerated().forEach { print("Graph \($0)"); print($1); print("") }



let g = Graph(fromExpressions: [extractState(seq[4])!.tops[0]])




print(g.render(node: g4.tops[0]))



let pts = seq[5].extractParseTrees()
let asts = pts.flatMap(produceASTsFromExpression)

asts.forEach { print($0) }


let seq0 = constructParseSequence(parsingExpression: grammar.root, withRespectTo: tokens)
grammar.wipeMemoizationRecords()
let ext0 = seq0.last!.extractParseTrees()
let pts0 = ext0.flatMap(produceASTsFromExpression)
let seq1 = constructParseSequence(parsingExpression: grammar.root, withRespectTo: [])
grammar.wipeMemoizationRecords()
let ext1 = seq1.last!.extractParseTrees()
let pts1 = ext1.flatMap(produceASTsFromExpression)
let seq2 = constructParseSequence(parsingExpression: grammar.root, withRespectTo: tokens)
grammar.wipeMemoizationRecords()
let ext2 = seq2.last!.extractParseTrees()
let pts2 = ext2.flatMap(produceASTsFromExpression)

let ar0 = grammar.parse(withInputTokens: tokens)
let ap0 = ar0.flatMap(produceASTsFromExpression)
let ar1 = grammar.parse(withInputTokens: [])
let ap1 = ar1.flatMap(produceASTsFromExpression)
let ar2 = grammar.parse(withInputTokens: tokens)
let ap2 = ar2.flatMap(produceASTsFromExpression)

 */
