import CodableSwiftDataModelMacro
import Foundation
import SwiftData
import Foundation
import Combine

public typealias ObjectDidChangePublisher = PassthroughSubject<(oldData: Data, newData: Data), Never>

// Key to track objects being encoded in the current encoder instance
extension CodingUserInfoKey {
    static let encodingState = CodingUserInfoKey(rawValue: "encodingState")!
}

// Thread-safe wrapper to track objects during encoding
final class EncodingState {
    private let lock = NSLock()
    private var objectIDs = Set<ObjectIdentifier>()
    
    static func track(_ object: AnyObject, encoder: any Encoder) -> EncodingState {
        guard let state = encoder.userInfo[.encodingState] as? EncodingState else {
            fatalError("Use ModelEncoder to decode")
        }
        state.insert(object)
        return state
    }
    
    static func untrack(_ object: AnyObject, state: EncodingState) {
        state.remove(object)
    }
    
    
    func contains<T: AnyObject>(_ object: T?) -> Bool {
        guard let o = object else {
            return false
        }
        lock.lock()
        let result = objectIDs.contains(ObjectIdentifier(o))
        lock.unlock()
        return result
    }
    
    func contains<T>(_ object: T?) -> Bool {
         return false
     }
    
    private func insert(_ object: AnyObject) {
        lock.lock()
        objectIDs.insert(ObjectIdentifier(object))
        lock.unlock()
    }
    
    private func remove(_ object: AnyObject) {
        lock.lock()
        objectIDs.remove(ObjectIdentifier(object))
        lock.unlock()
    }
}


@CodableClass
class MyCodableClass : Codable {
    var name: String = ""
    var price: Float = 1.0

    init(name: String, price: Float) {
        self.name = name
        self.price = price
    }
}

@CodableClass
final class Book: Codable {
    var title: String = ""
    var pages: [Page]?
    
    init(title: String, pages: [Page]? = nil) {
        self.title = title
        self.pages = pages
    }
}

@CodableClass
final class Page: Codable {
    var content: String = ""
    var book: Book?
    
    init(content: String, book: Book? = nil) {
        self.content = content
        self.book = book
    }
}

let o = MyCodableClass(name: "Car", price: 10000.0)

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

let jsonData = try encoder.encode(o)
let jsonString = String(data: jsonData, encoding: .utf8)
print(jsonString ?? "Failed to convert to JSON string")

