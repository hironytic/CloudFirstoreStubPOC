//
// StubDataStore.swift
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

import Foundation
import RxSwift
@testable import CloudFirestoreStubPOC

public enum StubDataStoreError: Error {
    case documentNotFound(documentPathString: String)
    case deletePlaceholderCannotBeUsed(keys: Set<String>)
}

public class StubDataStore: DataStore {
    private var result: [String: StubResultCollection]
    
    public init(initialCollections: [String: [String: [String: Any]]]) {
        result = [:]
        for collection in initialCollections {
            result[collection.key] = StubResultCollection(collectionPathString: collection.key,
                                                          initialDocuments: collection.value)
        }
    }
    
    public var deletePlaceholder: Any { return StubDataStorePlaceholder.deletePlaceholder }
    public var serverTimestampPlaceholder: Any { return StubDataStorePlaceholder.serverTimestampPlaceholder }
    
    public func collection(_ collectionID: String) -> CollectionPath {
        return StubRootCollectionPath(collectionID: collectionID)
    }
    
    public func observeDocument(at documentPath: DocumentPath) -> Observable<Entity?> {
        let StubDocumentPath = documentPath as! StubDocumentPath
        let collectionPathString = StubDocumentPath.basePath.pathString()
        let rc = resultCollection(for: collectionPathString)
        return rc.result
            .map { documents in
                return documents[StubDocumentPath.documentID]
                    .map { Entity(documentID: StubDocumentPath.documentID, data: $0) }
            }
    }
    
    public func observeCollection(matches query: DataStoreQuery) -> Observable<[Entity]> {
        let StubQuery = query as! StubDataStoreQuery
        let areInIncreasingOrder = { (result1: Entity, result2: Entity) -> Bool in
            return result1.documentID < result2.documentID
        }
        let isIncluded = { (_: Entity) -> Bool in return true }
        return StubQuery.observe(dataStore: self, sortedBy: areInIncreasingOrder, filteredBy: isIncluded)
            .scan([]) { acc, result in
                return result
            }
    }
    
    public func write(block: @escaping (DocumentWriter) throws -> Void) -> Completable {
        let writer = StubDocumentWriter(dataStore: self)
        return Completable.create { observer in
            do {
                try block(writer)
            } catch let error {
                observer(.error(error))
            }
            return writer.execute().subscribe(observer)
        }
    }
    
    fileprivate func resultCollection(for collectionPathString: String) -> StubResultCollection {
        if let resultCollection = result[collectionPathString] {
            return resultCollection
        } else {
            let newCollection = StubResultCollection(collectionPathString: collectionPathString,
                                                     initialDocuments: [:])
            result[collectionPathString] = newCollection
            return newCollection
        }
    }
}

private enum StubDataStorePlaceholder {
    case deletePlaceholder
    case serverTimestampPlaceholder
}

private class StubDataStoreQuery: DataStoreQuery {
    public func whereField(_ field: String, isEqualTo value: Any) -> DataStoreQuery {
        return StubFilterQuery(baseQuery: self, field: field, op: .equalTo, operand: value)
    }
    
    public func whereField(_ field: String, isLessThan value: Any) -> DataStoreQuery {
        return StubFilterQuery(baseQuery: self, field: field, op: .lessThan, operand: value)
    }
    
    public func whereField(_ field: String, isLessThanOrEqualTo value: Any) -> DataStoreQuery {
        return StubFilterQuery(baseQuery: self, field: field, op: .lessThanOrEqualTo, operand: value)
    }
    
    public func whereField(_ field: String, isGreaterThan value: Any) -> DataStoreQuery {
        return StubFilterQuery(baseQuery: self, field: field, op: .greaterThan, operand: value)
    }
    
    public func whereField(_ field: String, isGreaterThanOrEqualTo value: Any) -> DataStoreQuery {
        return StubFilterQuery(baseQuery: self, field: field, op: .greaterThanOrEqualTo, operand: value)
    }
    
    public func order(by field: String) -> DataStoreQuery {
        return StubOrderQuery(baseQuery: self, field: field, isDescending: false)
    }
    
    public func order(by field: String, descending: Bool) -> DataStoreQuery {
        return StubOrderQuery(baseQuery: self, field: field, isDescending: descending)
    }
    
    public func observe(dataStore: StubDataStore,
                        sortedBy areInIncreasingOrder: @escaping (Entity, Entity) -> Bool,
                        filteredBy isIncluded: @escaping (Entity) -> Bool) -> Observable<[Entity]> {
        fatalError("method should be overriden")
    }
}

private func compareValues(_ value1: Any, _ value2: Any) -> ComparisonResult {
    let typeOrder = { (value: Any) -> Int in
        switch value {
        case is NSNull:
            return 0
        case is Int:
            return 1
        case is Date:
            return 2
        case is Bool:
            return 3
        case is String:
            return 4
        case is Double:
            return 5
        default:
            return -1
        }
    }
    
    let typeOrder1 = typeOrder(value1)
    let typeOrder2 = typeOrder(value2)
    if typeOrder1 < typeOrder2 {
        return .orderedAscending
    } else if typeOrder1 > typeOrder2 {
        return .orderedDescending
    } else {
        switch value1 {
        case is NSNull:
            return .orderedSame
            
        case is Int:
            let v1 = value1 as! Int
            let v2 = value2 as! Int
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            } else {
                return .orderedSame
            }
            
        case is Date:
            let v1 = value1 as! Date
            let v2 = value2 as! Date
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            } else {
                return .orderedSame
            }
            
        case is Bool:
            let v1 = value1 as! Bool
            let v2 = value2 as! Bool
            if v1 == v2 {
                return .orderedSame
            } else if !v1 {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
            
        case is String:
            let v1 = value1 as! String
            let v2 = value2 as! String
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            } else {
                return .orderedSame
            }
            
        case is Double:
            let v1 = value1 as! Double
            let v2 = value2 as! Double
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            } else {
                return .orderedSame
            }
            
        default:
            return .orderedSame
        }
    }
}

private func isSameData(_ data1: [String: Any], _ data2: [String: Any]) -> Bool {
    for pair in data1 {
        guard let data2Value = data2[pair.key] else { return false }
        if compareValues(pair.value, data2Value) != .orderedSame {
            return false
        }
    }
    for pair in data2 {
        if !data1.keys.contains(pair.key) {
            return false
        }
    }
    return true
}

private enum FilterOperator {
    case equalTo
    case lessThan
    case lessThanOrEqualTo
    case greaterThan
    case greaterThanOrEqualTo
}

private class StubFilterQuery: StubDataStoreQuery {
    private let baseQuery: StubDataStoreQuery
    private let field: String
    private let op: FilterOperator
    private let operand: Any
    
    public init(baseQuery: StubDataStoreQuery, field: String, op: FilterOperator, operand: Any) {
        self.baseQuery = baseQuery
        self.field = field
        self.op = op
        self.operand = operand
    }
    
    public override func observe(dataStore: StubDataStore,
                                 sortedBy areInIncreasingOrder: @escaping (Entity, Entity) -> Bool,
                                 filteredBy isIncluded: @escaping (Entity) -> Bool) -> Observable<[Entity]> {
        return baseQuery.observe(dataStore: dataStore, sortedBy: areInIncreasingOrder, filteredBy: { document in
            return self.filterResultDocument(document) && isIncluded(document)
        })
    }
    
    private func filterResultDocument(_ document: Entity) -> Bool {
        let value = document.data[field] ?? NSNull()
        let cr = compareValues(value, operand)
        switch op {
        case .equalTo:
            return cr == .orderedSame
        case .lessThan:
            return cr == .orderedAscending
        case .lessThanOrEqualTo:
            return cr == .orderedAscending || cr == .orderedSame
        case .greaterThan:
            return cr == .orderedDescending
        case .greaterThanOrEqualTo:
            return cr == .orderedDescending || cr == .orderedSame
        }
    }
}

private class StubOrderQuery: StubDataStoreQuery {
    private let baseQuery: StubDataStoreQuery
    private let field: String
    private let isDescending: Bool
    
    public init(baseQuery: StubDataStoreQuery, field: String, isDescending: Bool) {
        self.baseQuery = baseQuery
        self.field = field
        self.isDescending = isDescending
    }
    
    public override func observe(dataStore: StubDataStore,
                                 sortedBy areInIncreasingOrder: @escaping (Entity, Entity) -> Bool,
                                 filteredBy isIncluded: @escaping (Entity) -> Bool) -> Observable<[Entity]> {
        return baseQuery.observe(dataStore: dataStore, sortedBy: { document1, document2 in
            let cr = self.compareResultDocuments(document1, document2)
            switch cr {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return areInIncreasingOrder(document1, document2)
            }
        }, filteredBy: isIncluded)
    }
    
    private func compareResultDocuments(_ document1: Entity, _ document2: Entity) -> ComparisonResult {
        let value1 = document1.data[field] ?? NSNull()
        let value2 = document2.data[field] ?? NSNull()
        let cr = compareValues(value1, value2)
        if isDescending {
            switch cr {
            case .orderedAscending:
                return .orderedDescending
            case .orderedDescending:
                return .orderedAscending
            case .orderedSame:
                return .orderedSame
            }
        } else {
            return cr
        }
    }
}

private protocol StubCollectionPath: CollectionPath {
    func pathString() -> String
}

private extension StubCollectionPath {
    func document() -> DocumentPath {
        return document(UUID().uuidString)
    }
    
    func document(_ documentID: String) -> DocumentPath {
        return StubDocumentPath(basePath: self, documentID: documentID)
    }
}

private class StubCollectionPathBase: StubDataStoreQuery, StubCollectionPath {
    public let collectionID: String
    
    public init(collectionID: String) {
        self.collectionID = collectionID
    }
    
    public func pathString() -> String {
        fatalError("method should be overriden")
    }
    
    public override func observe(dataStore: StubDataStore,
                                 sortedBy areInIncreasingOrder: @escaping (Entity, Entity) -> Bool,
                                 filteredBy isIncluded: @escaping (Entity) -> Bool) -> Observable<[Entity]> {
        let resultCollection = dataStore.resultCollection(for: pathString())
        return resultCollection.result
            .map { result in
                let filtered: [String: [String: Any]] = result.filter { isIncluded(Entity(documentID: $0.key, data: $0.value)) }
                return filtered
                    .sorted { keyValue1, keyValue2 in
                        return areInIncreasingOrder(Entity(documentID: keyValue1.key, data: keyValue1.value),
                                                    Entity(documentID: keyValue2.key, data: keyValue2.value))
                    }
                    .map { Entity(documentID: $0.key, data: $0.value) }
            }
    }
}

private class StubRootCollectionPath: StubCollectionPathBase {
    public override func pathString() -> String {
        return "/\(collectionID)"
    }
}

private class StubSubcollectionPath: StubCollectionPathBase {
    private let basePath: StubDocumentPath
    public init(basePath: StubDocumentPath, collectionID: String) {
        self.basePath = basePath
        super.init(collectionID: collectionID)
    }
    
    public override func pathString() -> String {
        return "\(basePath.pathString())/\(collectionID)"
    }
}

private class StubDocumentPath: DocumentPath {
    public let basePath: StubCollectionPath
    public let documentID: String
    
    public init(basePath: StubCollectionPath, documentID: String) {
        self.basePath = basePath
        self.documentID = documentID
    }
    
    public func collection(_ collectionID: String) -> CollectionPath {
        return StubSubcollectionPath(basePath: self, collectionID: collectionID)
    }
    
    public func pathString() -> String {
        return "\(basePath.pathString())/\(documentID)"
    }
}

private class StubDocumentWriter: DocumentWriter {
    private let dataStore: StubDataStore
    private var actionsForCollection: [String: [StubDocumentWritingAction]] = [:]
    
    public init(dataStore: StubDataStore) {
        self.dataStore = dataStore
    }
    
    private func appendAction(_ action: StubDocumentWritingAction, for collectionPath: StubCollectionPath) {
        let pathString = collectionPath.pathString()
        var actions = actionsForCollection[pathString] ?? []
        actions.append(action)
        actionsForCollection[pathString] = actions
    }
    
    public func setDocumentData(_ documentData: [String: Any], at documentPath: DocumentPath) {
        let documentPath = documentPath as! StubDocumentPath
        appendAction(.set(documentID: documentPath.documentID, data: documentData),
                     for: documentPath.basePath)
    }
    
    public func updateDocumentData(_ documentData: [String: Any], at documentPath: DocumentPath) {
        let documentPath = documentPath as! StubDocumentPath
        appendAction(.update(documentID: documentPath.documentID, fields: documentData),
                     for: documentPath.basePath)
    }
    
    public func mergeDocumentData(_ documentData: [String: Any], at documentPath: DocumentPath) {
        let documentPath = documentPath as! StubDocumentPath
        appendAction(.merge(documentID: documentPath.documentID, fields: documentData),
                     for: documentPath.basePath)
    }
    
    public func deleteDocument(at documentPath: DocumentPath) {
        let documentPath = documentPath as! StubDocumentPath
        appendAction(.delete(documentID: documentPath.documentID),
                     for: documentPath.basePath)
    }
    
    public func execute() -> Completable {
        let completables = actionsForCollection.map { (pair: (key: String, value: [StubDocumentWritingAction])) -> Completable in
            let (collectionPathString, actions) = pair
            let resultCollection = dataStore.resultCollection(for: collectionPathString)
            return resultCollection.executeActions(actions)
        }
        return Completable.concat(completables)
    }
}

private enum StubDocumentWritingAction {
    case set(documentID: String, data: [String: Any])
    case update(documentID: String, fields: [String: Any])
    case merge(documentID: String, fields: [String: Any])
    case delete(documentID: String)
}

private struct StubDocumentWritingExecution {
    let actions: [StubDocumentWritingAction]
    let observer: PrimitiveSequenceType.CompletableObserver
}

private class StubResultCollection {
    private let collectionPathString: String
    private let executionSubject = PublishSubject<StubDocumentWritingExecution>()
    public let result: Observable<[String: [String: Any]]>
    private let disposeBag = DisposeBag()
    
    public init(collectionPathString: String, initialDocuments: [String: [String: Any]]) {
        let resolvePlaceholders: ([String: Any], Date) -> (fields: [String: Any], keysToDelete: Set<String>) = { fields, currentTime in
            var resultFields = [String: Any](minimumCapacity: fields.count)
            var keysToDelete = Set<String>()
            for (key, value) in fields {
                if case StubDataStorePlaceholder.deletePlaceholder = value {
                    keysToDelete.insert(key)
                } else if case StubDataStorePlaceholder.serverTimestampPlaceholder = value {
                    resultFields[key] = currentTime
                } else {
                    resultFields[key] = value
                }
            }
            return (fields: resultFields, keysToDelete: keysToDelete)
        }
        
        self.collectionPathString = collectionPathString
        result = executionSubject
            .scan(initialDocuments) { (prevAcc, execution) -> [String: [String: Any]] in
                var acc = prevAcc
                let actions = execution.actions
                let observer = execution.observer
                var error: Error? = nil
                loop: for action in actions {
                    switch action {
                    case .set(let documentID, let data):
                        let (resolvedData, keysToDelete) = resolvePlaceholders(data, Date())
                        if !keysToDelete.isEmpty {
                            error = StubDataStoreError.deletePlaceholderCannotBeUsed(keys: keysToDelete)
                            break loop
                        }
                        acc[documentID] = resolvedData
                        
                    case .update(let documentID, let fields):
                        let (resolvedFields, keysToDelete) = resolvePlaceholders(fields, Date())
                        if let old = acc[documentID] {
                            let merged = old
                                .filter { !keysToDelete.contains($0.key) }
                                .merging(resolvedFields) { (_, new) in new }
                            acc[documentID] = merged
                        } else {
                            error = StubDataStoreError.documentNotFound(documentPathString: "\(collectionPathString)/\(documentID)")
                            break loop
                        }
                        
                    case .merge(let documentID, let fields):
                        let (resolvedFields, keysToDelete) = resolvePlaceholders(fields, Date())
                        if !keysToDelete.isEmpty {
                            error = StubDataStoreError.deletePlaceholderCannotBeUsed(keys: keysToDelete)
                            break loop
                        }
                        if let old = acc[documentID] {
                            let merged = old.merging(resolvedFields) { (_, new) in new }
                            acc[documentID] = merged
                        } else {
                            acc[documentID] = resolvedFields
                        }
                        
                    case .delete(let documentID):
                        acc.removeValue(forKey: documentID)
                    }
                }
                if let error = error {
                    observer(.error(error))
                    return prevAcc
                } else {
                    observer(.completed)
                    return acc
                }
            }
            .startWith(initialDocuments)
            .share(replay: 1, scope: .whileConnected)
        
        // subscribing result by myself so that it handles actions even if no one observe the result.
        result.subscribe().disposed(by: disposeBag)
    }
    
    public func executeActions(_ actions: [StubDocumentWritingAction]) -> Completable {
        return Completable.create { observer in
            self.executionSubject.onNext(StubDocumentWritingExecution(actions: actions, observer: observer))
            return Disposables.create()
        }
    }
}

