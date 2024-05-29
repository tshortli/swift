// Ensure that the `unnecessary check` availability warning is emitted when unnecessary due to
// scope's explicit annotation

// RUN: %target-typecheck-verify-swift -verify -target %target-cpu-apple-macosx11.2
// REQUIRES: OS=macosx

@available(macOS 11.1, *)
class Foo {
  // expected-note@-1 2 {{enclosing scope here}}
  func foo() {
    // expected-warning@+1 {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
    if #available(macOS 11.0, *) {}
    // expected-warning@+1 {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
    if #available(macOS 11.1, *) {}

    if #available(macOS 11.2, *) {} // Ok
    if #available(macOS 11.3, *) {} // Ok
  }
}

@available(macOS 10.15, *)
@inlinable public func inlinableFunc() {   // expected-note 2 {{enclosing scope here}}
  // expected-warning@+1 {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.14, *) {}
  // expected-warning@+1 {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.15, *) {}

  if #available(macOS 11.0, *) {} // Ok
  if #available(macOS 11.1, *) {} // Ok
}
