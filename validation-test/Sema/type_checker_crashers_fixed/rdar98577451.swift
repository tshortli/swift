// RUN: %target-typecheck-verify-swift

protocol P {
  associatedtype T
  func f() -> T
}

struct S: P {
  func f() -> some Any { return 3 }
}

struct G<T> {
  typealias Foo = (T?, S.T)
}

func f<T>(t: T) -> G<T>.Foo {
  return (t, S().f()) // Ok
}
