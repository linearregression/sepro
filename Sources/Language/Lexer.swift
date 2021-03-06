//
//  Lexer.swift
//  SeproLang
//
//  Created by Stefan Urbanek on 12/12/15.
//  Copyright © 2015 Stefan Urbanek. All rights reserved.
//

//===----------------------------------------------------------------------===//
//
// Lexer interface and simple lexer
//
//===----------------------------------------------------------------------===//

/// Parser Token

import Foundation

public enum TokenKind: Equatable, CustomStringConvertible {
    case empty

    case error(String)

    /// Identifier: first character + rest of identifier characters
    case identifier

    /// Reserved word - same as identifier
    case keyword

    /// Integer
    case intLiteral

    /// Multi-line string containing a piece of documentation
    case stringLiteral

    /// From a list of operators
    case `operator`

    public var description: String {
        switch self {
        case .error: return "unknown"
        case .empty: return "empty"
        case .identifier: return "identifier"
        case .keyword: return "keyword"
        case .intLiteral: return "int"
        case .stringLiteral: return "string"
		case .operator: return "operator"
        }
    }
}

public func ==(left:TokenKind, right:TokenKind) -> Bool {
    switch(left, right){
    case (.empty, .empty): return true
    case (.error(let l), .error(let r)) where l == r: return true
    case (.keyword, .keyword): return true
    case (.identifier, .identifier): return true
    case (.intLiteral, .intLiteral): return true
    case (.stringLiteral, .stringLiteral): return true
    case (.operator, .operator): return true
    default:
        return false
    }
}

public struct Token: CustomStringConvertible, CustomDebugStringConvertible, Equatable  {
    public let pos: TextPosition
    public let kind: TokenKind
    public let text: String

    public init(_ kind: TokenKind, _ text: String="", _ pos: TextPosition?=nil) {
        self.kind = kind
        self.text = text
        self.pos = pos ?? TextPosition()
    }

    public var description: String {
        let str: String
        switch self.kind {
        case .empty: str = "(empty)"
        case .stringLiteral: str = "'\(self.text)'"
        case .error(let message): str = "\(message) around '\(self.text)'"
        default:
            str = self.text
        }
        return "\(str) (\(self.kind)) at \(self.pos)"
    }
    public var debugDescription: String {
        return description
    }

}

public func ==(token: Token, kind: TokenKind) -> Bool {
    return token.kind == kind
}

public func ==(left: Token, right: Token) -> Bool {
    return left.kind == right.kind && left.text == right.text
}

public func ==(left: Token, right: String) -> Bool {
    return left.text == right
}

extension Token: ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String

    public init(stringLiteral value: StringLiteralType){
        self.kind = .keyword
        self.text = value
        self.pos = TextPosition()
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType){
        self.kind = .keyword
        self.text = value
        self.pos = TextPosition()
    }

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType){
        self.kind = .keyword
        self.text = value
        self.pos = TextPosition()
    }
}

extension Token: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.kind = .empty
        self.text = ""
        self.pos = TextPosition()
    }
}

extension Token: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int

    public init(integerLiteral value: IntegerLiteralType) {
        self.kind = .intLiteral
        self.text = String(value)
        self.pos = TextPosition()
    }
}

// Character sets
let WhitespaceCharacterSet = CharacterSet.whitespaces | CharacterSet.newlines
let NewLineCharacterSet = CharacterSet.newlines
let DecimalDigitCharacterSet = CharacterSet.decimalDigits
let LetterCharacterSet = CharacterSet.letters
let SymbolCharacterSet = CharacterSet.symbols
let AlphanumericCharacterSet = CharacterSet.alphanumerics

var IdentifierStart = LetterCharacterSet | "_"
var IdentifierCharacters = AlphanumericCharacterSet | "_"
var OperatorCharacters =  CharacterSet(charactersIn: ".,*=():")

// Single quote: Symbol, Triple quote: Docstring
var CommentStart: UnicodeScalar = "#"
var Numbers = DecimalDigitCharacterSet



/// Line and column text position. Starts at line 1 and column 1.
public struct TextPosition: CustomStringConvertible {
    var line: Int = 1
    var column: Int = 1

	/// Advances the text position. If the character is a new line character,
	/// then line position is increased and column position is reset to 1. 
    mutating func advance(_ char: UnicodeScalar?) {
		if let char = char {
			if NewLineCharacterSet.contains(char) {
				self.column = 1
				self.line += 1
			}
            self.column += 1
		}
    }

    public var description: String {
        return "\(self.line):\(self.column)"
    }
}

/**
 Simple lexer that produces symbols, keywords, integers, operators and
 docstrings. Symbols can be quoted with a back-quote character.
 */

public class Lexer {
	typealias Index = String.UnicodeScalarView.Index

    let keywords: [String]

    let source: String
    let characters: String.UnicodeScalarView
    var index: Index
    var currentChar: UnicodeScalar? = nil

    public var position: TextPosition
    var error: String? = nil
    public var currentToken: Token

    /**
     Initialize the lexer with model source.

     - Parameters:
     - source: source string
     - keywords: list of unquoted symbols to be treated as keywords
     - operators: list of operators composed of operator characters
     */
    public init(source:String, keywords: [String]?=nil) {
        self.source = source

        characters = source.unicodeScalars
        index = characters.startIndex

        if source.isEmpty {
            currentChar = nil
        }
        else {
            currentChar = characters[index]
        }

        position = TextPosition()
        self.keywords = keywords ?? []

        currentToken = nil
    }

    public func parse() -> [Token]{
        var tokens = [Token]()

        loop: while(true) {
            let token = self.nextToken()

            tokens.append(token)

            switch token.kind {
            case .empty, .error:
                break loop
            default:
                break
            }
        }

        return tokens
    }

    /**
     Advance to the next character and set current character.
     */
	@discardableResult
    func advance() {
		// "abcd"
		//     ^---

		index = characters.index(index, offsetBy: 1)
		if index < characters.endIndex {
			currentChar = characters[index]
			position.advance(currentChar)
		}
		else {
			currentChar = nil
		}
    }

    func tokenFrom(_ start: Index, to: Index?=nil) -> String {
        let end = to ?? index

        return String(self.source.unicodeScalars[start..<end])
    }

    /** Accept characters that are equal to the `char` character */
    fileprivate func accept(_ c: UnicodeScalar) -> Bool {
        if self.currentChar == c {
            self.advance()
            return true
        }
        else {
            return false
        }
    }

    /// Accept characters from a character set `set`
    fileprivate func accept(_ set: CharacterSet) -> Bool {
        if self.currentChar != nil && set ~= self.currentChar! {
            self.advance()
            return true
        }
        else {
            return false
        }
    }

    private func scanWhile(_ set: CharacterSet) {
        while(self.currentChar != nil) {
            if !(set ~= self.currentChar!) {
                break
            }
            self.advance()
        }
    }

	@discardableResult
    private func scanUntil(_ set: CharacterSet) -> Bool {
        while(self.currentChar != nil) {
            if set ~= self.currentChar! {
                return true
            }
            self.advance()
        }
        return false
    }

    private func scanUntil(_ char: UnicodeScalar, allowNewline: Bool=true) -> Bool {
        while(self.currentChar != nil) {
            if self.currentChar! == char {
                return true
            }
            else if NewLineCharacterSet ~= self.currentChar! && !allowNewline {
                return false
            }
            self.advance()
        }
        return false
    }

    /// Advance to the next non-whitespace character
    public func skipWhitespace() {
        while(true){
            if self.accept(CommentStart) {
                self.scanUntil(NewLineCharacterSet)
            }
            else if !self.accept(WhitespaceCharacterSet) {
                break
            }
        }
    }

    /**
     - Returns: `true` if the parser is at end
     */
    public func atEnd() -> Bool {
        return self.currentChar == nil
    }

    /**
     Parse next token.

     - Returns: currently parsed SourceToken
     */
    public func nextToken() -> Token {
        let tokenKind: TokenKind
        var value: String? = nil

        self.skipWhitespace()

        guard !self.atEnd() else {
            return nil
        }

        let start = self.index
        let pos = self.position

        if DecimalDigitCharacterSet ~= self {
            self.scanWhile(DecimalDigitCharacterSet)

            if IdentifierStart ~= self {
                let invalid = self.currentChar == nil ? "(nil)" : String(self.currentChar!)
                self.error = "Invalid character \(invalid) in number"
                tokenKind = .error(self.error!)
            }
            else {
                tokenKind = .intLiteral
            }
        }
        else if IdentifierStart ~= self {
            self.scanWhile(IdentifierCharacters)

            value = self.tokenFrom(start)
            let upvalue = value!.uppercased()

            // Case insensitive compare
            if self.keywords.contains(upvalue) {
                tokenKind = .keyword
                value = upvalue
            }
            else {
                tokenKind = .identifier
            }
        }
        else if "\"" ~= self {
            let stringToken = self.scanString()
            tokenKind = stringToken.0
            value = stringToken.1
        }
        else if OperatorCharacters ~= self {
            tokenKind = .operator
        }
        else{
            var message: String
            let value = self.tokenFrom(start)

            if self.currentChar != nil {
                message = "Unexpected character '\(self.currentChar!)'"
            }
            else {
                message = "Unexpected end"
            }
            
            self.error = message + " around \(value)'"
            tokenKind = .error(self.error!)
        }

        self.currentToken = Token(tokenKind, value ?? self.tokenFrom(start), pos)

        return self.currentToken
    }

    func scanString() -> (TokenKind, String) {
        let start: Index
        var end: Index

		// Second quote
        if self.accept("\"") {
            if self.accept("\"") {
                start = index
                while(self.scanUntil(CharacterSet(charactersIn:"\\\""))){
					if currentChar == "\\" {
						self.advance()
						self.advance()
						continue
					}
					// end = characters.index(index, offsetBy: 1)
					end = index
					assert(end >= start)
                    self.advance()
                    if self.accept("\"") && self.accept("\"") {
                        return (.stringLiteral, self.tokenFrom(start, to: end))
                    }
                }
            }
            else {
				// If not third quote, then we have empty string
                return (.stringLiteral, "")
            }
        }
        else {
            // Parse normal string here
			start = index
            while(!self.atEnd()) {
                end = self.characters.index(before:index)
                if self.accept("\\") {
                    self.advance()
                }
                else if self.accept("\""){
                    return (.stringLiteral, self.tokenFrom(start, to: end))
                }
                self.advance()
            }
        }
        self.error = "Unexpected end of input in a string"
        return (.error(self.error!), "")

    }
}

infix operator ~

public func ~=(left:CharacterSet, lexer: Lexer) -> Bool {
    return lexer.accept(left)
}

public func ~=(left:UnicodeScalar, lexer: Lexer) -> Bool {
    return lexer.accept(left)
}
