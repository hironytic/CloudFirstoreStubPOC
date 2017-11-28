//
// EventuallyFulfill.swift
// CloudFirestoreStubPOCTests
//
// Copyright (c) 2016, 2017 Hironori Ichimiya <hiron@hironytic.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import XCTest
import RxSwift

/// An observer that fulfills specified expectation when the condition matches eventually.
public class EventuallyFulfill<Element>: ObserverType {
    public typealias E = Element
    private var expectation: XCTestExpectation
    private var nextChecker: (Element) -> Bool
    private var errorChecker: (Error) -> Bool
    private var isFulfilled = false
    
    public init(_ expectation: XCTestExpectation, nextChecker: @escaping (Element) -> Bool) {
        self.expectation = expectation
        self.nextChecker = nextChecker
        self.errorChecker = { _ in false }
    }
    
    public init(_ expectation: XCTestExpectation, errorChecker: @escaping (Error) -> Bool) {
        self.expectation = expectation
        self.nextChecker = { _ in false }
        self.errorChecker = errorChecker
    }
    
    public init(_ expectation: XCTestExpectation, nextChecker: @escaping (Element) -> Bool, errorChecker: @escaping (Error) -> Bool) {
        self.expectation = expectation
        self.nextChecker = nextChecker
        self.errorChecker = errorChecker
    }
    
    public func reset(_ expectation: XCTestExpectation, nextChecker: @escaping (Element) -> Bool) {
        self.expectation = expectation
        self.nextChecker = nextChecker
        self.errorChecker = { _ in false }
        isFulfilled = false
    }
    
    public func reset(_ expectation: XCTestExpectation, errorChecker: @escaping (Error) -> Bool) {
        self.expectation = expectation
        self.nextChecker = { _ in false }
        self.errorChecker = errorChecker
        isFulfilled = false
    }
    
    public func reset(_ expectation: XCTestExpectation, nextChecker: @escaping (Element) -> Bool, errorChecker: @escaping (Error) -> Bool) {
        self.expectation = expectation
        self.nextChecker = nextChecker
        self.errorChecker = errorChecker
        isFulfilled = false
    }
    
    public func on(_ event: Event<Element>) {
        switch event {
        case .next(let element):
            if !isFulfilled && nextChecker(element) {
                expectation.fulfill()
                isFulfilled = true
            }
        case .error(let error):
            if !isFulfilled &&  errorChecker(error) {
                expectation.fulfill()
                isFulfilled = true
            }
        case .completed:
            break
        }
    }
}
