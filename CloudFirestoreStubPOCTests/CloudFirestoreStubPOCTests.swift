//
// CloudFirestoreStubPOCTests.swift
// CloudFirestoreStubPOCTests
//
// Copyright (c) 2017 Hironori Ichimiya <hiron@hironytic.com>
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
import RxCocoa
@testable import CloudFirestoreStubPOC

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
    return DateComponents(calendar: Calendar(identifier: .gregorian),
                          timeZone: TimeZone(identifier: "UTC"),
                          year: year,
                          month: month,
                          day: day,
                          hour: hour,
                          minute: minute,
                          second: second).date!
}

class CloudFirestoreStubPOCTests: XCTestCase {
    var dataStore: StubDataStore!
    var disposeBag: DisposeBag!
    var stubResolver: DataStoreResolver!

    typealias RequiredResolver = DefaultChannelListViewModel.Resolver & DefaultMessageViewModel.Resolver
    class StubResolver: RequiredResolver {
        let dataStore: DataStore
        init(dataStore: DataStore) {
            self.dataStore = dataStore
        }
        func resolveDataStore() -> DataStore {
            return dataStore
        }
    }

    override func setUp() {
        super.setUp()
        
        dataStore = StubDataStore(initialCollections: [
            "/channels": [
                "CSP36ah": [
                    "name": "general",
                    "public": true,
                ],
            ],
            "/channels/CSP36ah/messages": [
                "MV5ahcO": [
                    "from": "Suneo",
                    "message": "What are you doing? Busy? Can you help me?",
                    "timestamp": makeDate(2017, 12, 3, 15, 41, 12),
                ],
                "MV5yaC0": [
                    "from": "Nobita",
                    "message": "Taking a nap.",
                    "timestamp": makeDate(2017, 12, 3, 15, 41, 54),
                ],
                "MV6Almn": [
                    "from": "Suneo",
                    "message": "Can you help me to buy me an iTunes prepaid card at the nearby convenience store?",
                    "timestamp": makeDate(2017, 12, 3, 15, 42, 30),
                ],
            ],
        ])
        stubResolver = StubResolver(dataStore: dataStore)

        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testChannelList() {
        let viewModel = DefaultChannelListViewModel(resolver: stubResolver)

        let expect1 = expectation(description: "There is one channel")
        var item0OrNil: ChannelListItem?
        let observer = EventuallyFulfill(expect1) { (items: [ChannelListItem]) in
            guard items.count == 1 else { return false }
            
            item0OrNil = items[0]
            return true
        }
        viewModel.channels
            .bind(to: observer)
            .disposed(by: disposeBag)
        
        wait(for: [expect1], timeout: 3.0)
        
        guard let item0 = item0OrNil else { return }
        XCTAssertEqual(item0.channelID, "CSP36ah")
        XCTAssertEqual(item0.name, "general")
        
        let expect3 = expectation(description: "One more channel appears")
        var item1OrNil: ChannelListItem?
        observer.reset(expect3) { (items: [ChannelListItem]) in
            guard items.count == 2 else { return false }
            
            item1OrNil = items[1]
            return true
        }
        
        let expect2 = expectation(description: "One channel is added")
        dataStore
            .write { writer in
                let newChannelPath = self.dataStore.collection("channels").document("NewChannel")
                writer.setDocumentData([
                    "name": "random",
                    "public": true,
                ], at: newChannelPath)
            }
            .subscribe(onCompleted: {
                expect2.fulfill()
            }, onError: { error in
                XCTFail("error \(error)")
            })
            .disposed(by: disposeBag)
        
        wait(for: [expect2, expect3], timeout: 3.0)
        guard let item1 = item1OrNil else { return }
        XCTAssertEqual(item1.channelID, "NewChannel")
        XCTAssertEqual(item1.name, "random")
    }
    
    func testMessage() {
        let viewModel = DefaultMessageViewModel(resolver: stubResolver, channelID: "CSP36ah")
        
        let expect1 = expectation(description: "There are three messages")
        var itemsOrNil: [MessageItem]?
        let observer = EventuallyFulfill(expect1) { (items: [MessageItem]) in
            guard items.count == 3 else { return false }
            
            itemsOrNil = items
            return true
        }
        
        viewModel.items
            .bind(to: observer)
            .disposed(by: disposeBag)
        
        wait(for: [expect1], timeout: 3.0)
        
        guard let items = itemsOrNil else { return }
        XCTAssertEqual(items[0].from, "Suneo")
        XCTAssertEqual(items[0].message, "What are you doing? Busy? Can you help me?")
        XCTAssertEqual(items[1].from, "Nobita")
        XCTAssertEqual(items[1].message, "Taking a nap.")
        XCTAssertEqual(items[2].from, "Suneo")
        XCTAssertEqual(items[2].message, "Can you help me to buy me an iTunes prepaid card at the nearby convenience store?")

        let expect3 = expectation(description: "Nobita's message should be changed")
        observer.reset(expect3) { (items: [MessageItem]) in
            guard items.count == 3 else { return false }
            guard items[1].message == "Just finished my homework!" else { return false }
            return true
        }
        
        let expect2 = expectation(description: "Change message")
        dataStore
            .write { writer in
                let messagePath = self.dataStore
                    .collection("channels")
                    .document("CSP36ah")
                    .collection("messages")
                    .document("MV5yaC0")
                writer.mergeDocumentData(["message": "Just finished my homework!"], at: messagePath)
            }
            .subscribe(onCompleted: {
                expect2.fulfill()
            }, onError: { error in
                XCTFail("error \(error)")
            })
            .disposed(by: disposeBag)

        wait(for: [expect2, expect3], timeout: 3.0)
    }
}
