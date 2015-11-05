//
//  ParserTestCase.swift
//  AgentFarms
//
//  Created by Stefan Urbanek on 14/10/15.
//  Copyright © 2015 Stefan Urbanek. All rights reserved.
//

import SeproLang
import XCTest

class ParserTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testEmpty() {
        var lexer = Lexer(source: "")
        var token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.End)

        lexer = Lexer(source: "  ")
        token = lexer.nextToken()
        XCTAssertEqual(token.type, TokenType.End)
    }

    func testNumber() {
        let lexer = Lexer(source: "1234")
        let token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.Integer)
        XCTAssertEqual(token.value, "1234")
    }

    func testKeyword() {
        let lexer = Lexer(source: "CONCEPT")
        let token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.Keyword)
        XCTAssertEqual(token.value, "CONCEPT")
    }

    func testKeywordCase() {
        let lexer = Lexer(source: "CONCEPT")
        let token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.Keyword)
        XCTAssertEqual(token.value, "CONCEPT")
    }

    func testSymbol() {
        let lexer = Lexer(source: "something")
        let token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.Symbol)
        XCTAssertEqual(token.value, "something")
    }

    func testMultiple() {
        let lexer = Lexer(source: "this that 10, 20, 30")
        var token = lexer.nextToken()

        XCTAssertEqual(token.type, TokenType.Keyword)
        XCTAssertEqual(token.value, "THIS")

        token = lexer.nextToken()
        XCTAssertEqual(token.type, TokenType.Symbol)
        XCTAssertEqual(token.value, "that")

        for val in ["10", "20"] {
            token = lexer.nextToken()
            XCTAssertEqual(token.type, TokenType.Integer)
            XCTAssertEqual(token.value, val)

            token = lexer.nextToken()
            XCTAssertEqual(token.type, TokenType.Comma)
        }
    }
}

class CompilerTestase: XCTestCase {
    func compile(source:String) -> Model{
        let parser = Parser(source: source)
        if let model = parser.compile() {
            return model
        }
        else {
            XCTFail("Compile failed. Reason: \(parser.error!)")
        }
        return Model()
    }

    func compileError(source:String) -> String?{
        let parser = Parser(source: source)
        parser.compile()
        return parser.error
    }

    func assertError(source:String, _ match:String) {
        let error:String = self.compileError(source)!

        if error.rangeOfString(match) == nil {
            XCTFail("Error: \"\(error)\" does not match: '\(match)'")
        }
    }

    func testEmpty() {
        let model = self.compile("")
        XCTAssertEqual(model.concepts.count, 0)
    }
    func testError() {
        var error: String?

        error = self.compileError("thisisbad")
        XCTAssertNotNil(error)

        error = self.compileError("CONCEPT")
        XCTAssertNotNil(error)

    }
    func testConcept() {
        var model: Model

        model = self.compile("CONCEPT some")
        XCTAssertEqual(model.concepts.count, 1)

        model = self.compile("CONCEPT one CONCEPT two\nCONCEPT three")
        XCTAssertEqual(model.concepts.count, 3)

        self.assertError("CONCEPT CONCEPT", "concept name")
        self.assertError("CONCEPT one two", "two")

    }

    func testConceptTags() {
        var model: Model
        var concept: Concept

        model = self.compile("CONCEPT test TAG left, right")
        concept = model.getConcept("test")!
        XCTAssertEqual(concept.tags.count, 2)
    }

    func testConceptSlots() {
        var model: Model
        var concept: Concept

        model = self.compile("CONCEPT test SLOT left, right")
        concept = model.getConcept("test")!
        XCTAssertEqual(concept.slots.count, 2)
    }

    func testAlwaysActuator() {
        var model: Model

        model = self.compile("WHERE ALL DO NOTHING")

        XCTAssertEqual(model.actuators.count, 1)

        let actuator = model.actuators[0]

        XCTAssertEqual(actuator.conditions.count, 1)
        XCTAssertEqual(actuator.actions.count, 1)

        let action = actuator.actions[0]
        XCTAssertTrue(action is NoAction)
    }

    /// Compile a model containing only one actuator
    func compileActuator(source:String) -> Actuator {
        var model: Model
        model = self.compile(source)
        
        if model.actuators.isEmpty {
            XCTFail("Actuator list is empty")
        }

        return model.actuators[0]
    }

    // MARK: Conditions

    func testTagConditions() {
        var actuator: Actuator
        var tagCondition: TagSetPredicate

        actuator = self.compileActuator("WHERE test DO NOTHING")

        XCTAssertEqual(actuator.conditions.count, 1)
        tagCondition = actuator.conditions[0] as! TagSetPredicate

        XCTAssertEqual(tagCondition.isNegated, false)
        XCTAssertEqual(tagCondition.tags, ["test"])
        XCTAssertNil(tagCondition.slot)

        actuator = self.compileActuator("WHERE NOT notest DO NOTHING")
        tagCondition = actuator.conditions[0] as! TagSetPredicate
        XCTAssertEqual(tagCondition.isNegated, true)
        XCTAssertEqual(tagCondition.tags, ["notest"])

        // TODO: this should be one
        let model = self.compile("WHERE open AND left DO NOTHING")
        XCTAssertEqual(model.actuators.count, 1)
        XCTAssertEqual(model.actuators[0].conditions.count, 2)

        actuator = self.compileActuator("WHERE open AND NOT left DO NOTHING")
        tagCondition = actuator.conditions[1] as! TagSetPredicate
        XCTAssertEqual(tagCondition.isNegated, true)
        XCTAssertEqual(tagCondition.tags, ["left"])
    }
    func testContextCondition(){
        var actuator: Actuator
        actuator = self.compileActuator("WHERE ROOT ready DO NOTHING")
        XCTAssertTrue(actuator.isRoot)

        let cond = actuator.conditions[0] as! TagSetPredicate
        XCTAssertEqual(cond.tags, ["ready"])
    }
    func testInteractiveCondition(){
        var left: TagSetPredicate
        var right: TagSetPredicate

        var actuator = self.compileActuator("WHERE left ON ANY DO NOTHING")
        left = actuator.conditions[0] as! TagSetPredicate
        XCTAssertEqual(left.tags, ["left"])

        XCTAssertEqual(actuator.otherConditions!.count, 1)

        actuator = self.compileActuator("WHERE left ON right AND test DO NOTHING")

        right = actuator.otherConditions![0] as! TagSetPredicate
        XCTAssertEqual(right.tags, ["right"])

        right = actuator.otherConditions![1] as! TagSetPredicate
        XCTAssertEqual(right.tags, ["test"])
    }

    // MARK: Actions

    func testTagAction() {
        var actuator: Actuator
        var action: TagsAction

        actuator = self.compileActuator("WHERE ALL DO SET test")

        XCTAssertEqual(actuator.actions.count, 1)
        action = actuator.actions[0] as! TagsAction
        XCTAssertEqual(action.tags, ["test"])


        actuator = self.compileActuator("WHERE ALL DO SET one, two")
        XCTAssertEqual(actuator.actions.count, 1)
        action = actuator.actions[0] as! TagsAction
        XCTAssertEqual(action.tags, ["one", "two"])

        actuator = self.compileActuator("WHERE ALL DO SET one UNSET two")

        action = actuator.actions[0] as! TagsAction
        XCTAssertEqual(action.tags, ["one"])
        action = actuator.actions[1] as! TagsAction
        XCTAssertEqual(action.tags, ["two"])
    }
    func testContextAction() {
        var actuator: Actuator
        var action: TagsAction

        actuator = self.compileActuator("WHERE ALL DO IN this SET test")
        action = actuator.actions[0] as! TagsAction

        XCTAssertEqual(action.inContext, ObjectContextType.This)
        XCTAssertEqual(action.inSlot, nil)

        actuator = self.compileActuator("WHERE ALL DO IN root SET test")
        action = actuator.actions[0] as! TagsAction

        XCTAssertEqual(action.inContext, ObjectContextType.Root)

        actuator = self.compileActuator("WHERE ALL DO IN other.link SET test")
        action = actuator.actions[0] as! TagsAction

        XCTAssertEqual(action.inContext, ObjectContextType.Other)
        XCTAssertEqual(action.inSlot, "link")

    }
    func testBindAction() {
        var actuator: Actuator
        var action: BindAction

        actuator = self.compileActuator("WHERE ALL DO BIND link TO this")
        action = actuator.actions[0] as! BindAction
        XCTAssertEqual(action.targetContext, ObjectContextType.This)
        XCTAssertNil(action.targetSlot)

        actuator = self.compileActuator("WHERE ALL DO BIND link TO backlink")
        action = actuator.actions[0] as! BindAction
        XCTAssertEqual(action.targetContext, ObjectContextType.This)
        XCTAssertEqual(action.targetSlot, "backlink")

        actuator = self.compileActuator("WHERE ALL DO BIND link TO root.some")
        action = actuator.actions[0] as! BindAction
        XCTAssertEqual(action.targetContext, ObjectContextType.Root)
        XCTAssertEqual(action.targetSlot, "some")

        actuator = self.compileActuator("WHERE ALL DO IN root BIND link TO some")
        action = actuator.actions[0] as! BindAction
        XCTAssertEqual(action.targetContext, ObjectContextType.Root)
        XCTAssertEqual(action.targetSlot, "some")
    }

    func testWorld() {
        var model: Model

        model = self.compile("WORLD main OBJECT atom")
        model = self.compile("WORLD main OBJECT atom AS link")
        model = self.compile("WORLD main ROOT global OBJECT atom AS o1, atom AS o2")
        model = self.compile("WORLD main OBJECT atom AS o1, atom AS o2")
        model = self.compile("WORLD main BIND left.next TO right, right.previous TO left")

        // TODO: fail this
        // model = self.compile("WORLD main OBJECT atom, atom ")
    }

}
