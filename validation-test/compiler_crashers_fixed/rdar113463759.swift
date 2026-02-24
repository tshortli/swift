// RUN: %target-swift-frontend -emit-ir %s

protocol SomeObjectProtocol {}

struct SomeObject: SomeObjectProtocol {}

protocol ObjectProviding {
    associatedtype Object: SomeObjectProtocol
    var object: Object { get }
}

struct ConformingObject<each B>: ObjectProviding {
    var object: some SomeObjectProtocol {
        SomeObject()
    }
}
