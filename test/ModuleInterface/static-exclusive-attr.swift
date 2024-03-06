// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t.swiftinterface) %s -module-name Test -enable-experimental-feature StaticExclusiveOnly
// RUN: %target-swift-typecheck-module-from-interface(%t.swiftinterface) -module-name Test
// RUN: %FileCheck %s < %t.swiftinterface

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $StaticExclusiveOnly
// CHECK-NEXT:  @_staticExclusiveOnly @_moveOnly public struct Atomic {
// CHECK:       }
// CHECK-NEXT:  #endif
@_staticExclusiveOnly
public struct Atomic: ~Copyable {}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $StaticExclusiveOnly
// CHECK-NEXT:  extension Test.Atomic {
// CHECK-NEXT:    public func foo()
// CHECK-NEXT:  }
// CHECK-NEXT:  #endif
extension Atomic {
  public func foo() {}
}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $StaticExclusiveOnly
// CHECK-NEXT:  public func takesAtomic(_ x: borrowing Test.Atomic)
// CHECK-NEXT:  #endif
public func takesAtomic(_ x: borrowing Atomic) {}

public struct GenericBox<T> {}

extension GenericBox where T == Atomic {
  public func bar() {}
}
