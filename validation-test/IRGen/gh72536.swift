// RUN: %target-swift-emit-ir \
// RUN:     %s

func foo<each S>(_ s: repeat each S) async {}
await foo(true)

