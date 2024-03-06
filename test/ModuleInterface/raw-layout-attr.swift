// RUN: %empty-directory(%t)
// RUN: %target-swift-emit-module-interface(%t.swiftinterface) %s -module-name Test -enable-experimental-feature RawLayout
// RUN: %target-swift-typecheck-module-from-interface(%t.swiftinterface) -module-name Test
// RUN: %FileCheck %s < %t.swiftinterface

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $RawLayout
// CHECK-NEXT:  @_rawLayout(size: 12, alignment: 4) @_moveOnly public struct TwelveBytes {
// CHECK:       }
// CHECK-NEXT:  #endif
@_rawLayout(size: 12, alignment: 4)
public struct TwelveBytes: ~Copyable {}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $RawLayout
// CHECK-NEXT:  extension Test.TwelveBytes {
// CHECK-NEXT:    public func foo()
// CHECK-NEXT:  }
// CHECK-NEXT:  #endif
extension TwelveBytes {
  public func foo() {}
}

// FIXME: $MoveOnly && $MoveOnlyResilientTypes should guard this extension

// CHECK:       #if compiler(>=5.3) && $RawLayout
// CHECK-NEXT:  extension Swift.Array where Element == Test.TwelveBytes {
// CHECK-NEXT:    #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes
// CHECK-NEXT:    public func foo()
// CHECK-NEXT:    #endif
// CHECK-NEXT:  }
// CHECK-NEXT:  #endif
extension Array where Element == TwelveBytes {
  public func foo() {}
}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $RawLayout
// CHECK-NEXT:  public func takesTwelveBytes(_ x: borrowing Test.TwelveBytes)
// CHECK-NEXT:  #endif
public func takesTwelveBytes(_ x: borrowing TwelveBytes) {}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $RawLayout
// CHECK-NEXT:  @_rawLayout(like: T) @_moveOnly public struct Cell<T> {
// CHECK:       }
// CHECK-NEXT:  #endif
@_rawLayout(like: T)
public struct Cell<T>: ~Copyable {}

// CHECK:       #if compiler(>=5.3) && $MoveOnly && $MoveOnlyResilientTypes && $RawLayout
// CHECK-NEXT:  @_rawLayout(likeArrayOf: T, count: 8) @_moveOnly public struct SmallVectorBuf<T> {
// CHECK:       }
// CHECK-NEXT:  #endif
@_rawLayout(likeArrayOf: T, count: 8)
public struct SmallVectorBuf<T>: ~Copyable {}

