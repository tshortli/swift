// REQUIRES: VENDOR=apple
// Regression test for rdar://153808913 / GH-82360: TBD/IR validation used to
// flag Clang-emitted symbols (from imported C headers with function
// definitions) as missing from the Swift TBD. Those symbols aren't tracked by
// TBDGen because they don't correspond to any Swift decl; validation should
// simply ignore them.

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -emit-ir -o/dev/null -parse-as-library \
// RUN:     -module-name test -validate-tbd-against-ir=missing \
// RUN:     -import-objc-header %t/Bridging.h %t/use.swift

// RUN: %target-swift-frontend -emit-ir -o/dev/null -parse-as-library \
// RUN:     -module-name test -validate-tbd-against-ir=all \
// RUN:     -import-objc-header %t/Bridging.h %t/use.swift

//--- Bridging.h
#ifndef BRIDGING_H
#define BRIDGING_H

int c_taking_lambda(int (*f)(int, int), int a, int b) {
  return f(a, b);
}

int c_add(int a, int b) {
  return a + b;
}

typedef int (*ReturningLambdaType)(int, int);

ReturningLambdaType c_returning_lambda(void) {
  return &c_add;
}

#endif

//--- use.swift
public func swiftAdd(a: Int32, b: Int32) -> Int32 {
  return a + b
}

public func useAll() -> Int32 {
  let a = c_taking_lambda(swiftAdd, 2, 3)
  let b = c_taking_lambda({ x, y in x + y }, 2, 3)
  let f = c_returning_lambda()
  return a + b + f!(2, 4)
}
