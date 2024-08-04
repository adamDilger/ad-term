//
//  ad_termTests.swift
//  ad-termTests
//
//  Created by Adam Dilger on 4/8/2024.
//

import XCTest

@testable import ad_term

final class ad_termTests: XCTestCase {
    func testNumberParsing() throws {
        let p = EscapeParser();
        
        let data = [
            ("[1;2;3m", [1, 2, 3]),
            ("[2;m", [2, 0]),
            ("[;2m", [0, 2])
        ]

        for d in data {
            p.reset()
            var idx = 0;

            p.parse(d.0.data(using: .utf8)!, idx: &idx)
            
            let expected = d.1;
            for i in 0..<expected.count {
                XCTAssertEqual(p.numbers[i], d.1[i])
            }
        }
    }
    
//    func testFinalByte() throws {
//        let p = EscapeParser();
//        
//        let data = [
//            ("[1;2m", ),
//        ]
//
//        for d in data {
//            p.reset()
//            var idx = 0;
//
//            p.parse(d.0.data(using: .utf8)!, idx: &idx)
//            
//            let expected = d.1;
//            for i in 0..<expected.count {
//                XCTAssertEqual(p.numbers[i], d.1[i])
//            }
//        }
//    }
}
