import CodableSwiftDataModelMacro
import Foundation

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

