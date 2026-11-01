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

    // MARK: exact match against the stock list

    func test_partial_code_is_invalid_stockNo() {
        XCTAssertThrowsError(try validation.validStockNo("23")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidStockNo)
        }
    }

    func test_listed_and_otc_codes_are_valid_stockNo() {
        XCTAssertNoThrow(try validation.validStockNo("2330"))
        XCTAssertNoThrow(try validation.validStockNo("6488"))
    }

    func test_empty_code_is_invalid_stockNo() {
        XCTAssertThrowsError(try validation.validStockNo("")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidStockNo)
        }
        XCTAssertThrowsError(try validation.validStockNo(nil))
    }

    // MARK: share count above what a record can hold

    func test_amountInput_above_the_largest_storable_count_throws_instead_of_crashing_later() {
        XCTAssertEqual(try validation.validStockAmountInput("32767"), 32767)
        XCTAssertThrowsError(try validation.validStockAmountInput("32768")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidAmount)
        }
    }

    // MARK: fee and tax typed for a record

    func test_fee_or_tax_accepts_whole_dollars_in_range() {
        XCTAssertEqual(try validation.validFeeOrTaxInput("0"), 0)
        XCTAssertEqual(try validation.validFeeOrTaxInput("142"), 142)
        XCTAssertEqual(try validation.validFeeOrTaxInput("2147483647"), 2147483647)
    }

    func test_fee_or_tax_that_is_negative_decimal_empty_or_too_large_throws() {
        for text in ["-1", "1.5", "", "abc", "2147483648", nil] as [String?] {
            XCTAssertThrowsError(try validation.validFeeOrTaxInput(text), "\(text ?? "nil")") { error in
                XCTAssertEqual(error as? ValidationError, .invalidFeeOrTax)
            }
        }
    }
}
