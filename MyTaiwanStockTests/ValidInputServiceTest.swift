//
//  ValidInputService.swift
//  MyTaiwanStockTests
//
//  Created by YKLin on 8/26/22.
//

import XCTest
@testable import MyTaiwanStock

class ValidInputServiceTest: XCTestCase {
    var validation: ValidInputService!
    override func setUp() {
        super.setUp()
        validation = ValidInputService()
    }
    override func tearDown() {
        validation = nil
        super.tearDown()
    }
    
    func test_is_valid_priceInput() {
        XCTAssertNoThrow( try validation.validStockPriceInput("100.0"))
    }
    
    func test_is_invalid_priceInput() {
        let expectedError = ValidationError.invalidPrice
        var error: ValidationError?
        
        XCTAssertThrowsError(try validation.validStockPriceInput("a")) { thrownError in
            error = thrownError as? ValidationError
        }
        
        XCTAssertEqual(expectedError, error)
        XCTAssertEqual(expectedError.errorDescription, error?.errorDescription)
    }
    
    func test_less_than_one_priceInput_throws() {
        let expectedError = ValidationError.invalidPrice
        var error: ValidationError?
        
        XCTAssertThrowsError(try validation.validStockPriceInput("0")) { thrownErrror in
            error = thrownErrror as? ValidationError
        }
        
        XCTAssertEqual(expectedError, error)
        XCTAssertEqual(expectedError.errorDescription, error?.errorDescription)
    }
    func test_is_valid_amountInput() {
        XCTAssertNoThrow(try validation.validStockAmountInput("200"))
    }
    
    func test_is_invalid_amountInput() {
        let expectedError = ValidationError.invalidAmount
        var error: ValidationError?
        
        XCTAssertThrowsError(try validation.validStockAmountInput("ab")) { thrownError in
            error = thrownError as? ValidationError
        }
        
        XCTAssertEqual(expectedError, error)
        XCTAssertEqual(expectedError.errorDescription, error?.errorDescription)
    }
    func test_less_than_one_amountInput_throws() {
        let expectedError = ValidationError.invalidAmount
        var error: ValidationError?
        
        XCTAssertThrowsError(try validation.validStockAmountInput("0")) { thrownErrror in
            error = thrownErrror as? ValidationError
        }
        
        XCTAssertEqual(expectedError, error)
        XCTAssertEqual(expectedError.errorDescription, error?.errorDescription)
    }
    func test_is_valid_stockNo() {
        XCTAssertNoThrow(try validation.validStockNo("0050"))
    }
    
    func test_is_invalid_stockNo() {
        let expectedError = ValidationError.invalidStockNo
        var error: ValidationError?
        
        XCTAssertThrowsError(try validation.validStockNo("9999")) { thrownError in
            error = thrownError as? ValidationError
        }
        
        XCTAssertEqual(error, expectedError)
        
        XCTAssertEqual(error?.errorDescription, expectedError.errorDescription)
    }
}
