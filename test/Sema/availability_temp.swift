// RUN: %target-typecheck-verify-swift -parse-as-library -target-min-inlining-version min -target %target-cpu-apple-macosx50 -dump-type-refinement-contexts

// REQUIRES: OS=macosx

@available(macOS 51, *)
var x: Int {
  @available(macOS 52, *)
  get { return 0 }
}

@available(macOS 53, *)
struct S {
  var y: Int {
    @available(macOS 54, *)
    get { return 0 }
  }
}

enum E {
  @available(macOS 56, *)
  case a, b
}

@available(macOS 49, *)
public var z = 1, zz = 2

public func f(_ x: Int = {
    if #available(macOS 51, *) {
      return 1
    }
    return 2
}()) {

}
