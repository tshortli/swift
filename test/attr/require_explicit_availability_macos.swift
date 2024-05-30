// Test the -require-explicit-availability flag
// REQUIRES: OS=macosx
// RUN: %empty-directory(%t)

/// Using the flag directly raises warnings and fixits.
// RUN: %target-swift-frontend -typecheck -parse-as-library -verify %s \
// RUN:   -target %target-cpu-apple-macosx10.10 -require-explicit-availability \
// RUN:   -require-explicit-availability-target "macOS 10.10" \
// RUN:   -verify-additional-prefix always-
// RUN: %target-swift-frontend -typecheck -parse-as-library -verify %s \
// RUN:   -target %target-cpu-apple-macosx10.10 -require-explicit-availability=warn \
// RUN:   -require-explicit-availability-target "macOS 10.10" \
// RUN:   -verify-additional-prefix always-

/// Using -library-level api defaults to enabling warnings, without fixits.
// RUN: sed -e "s/}} {{.*/}}/" < %s > %t/NoFixits.swift
// RUN: %target-swift-frontend -typecheck -parse-as-library -verify %t/NoFixits.swift \
// RUN:   -target %target-cpu-apple-macosx10.10 -library-level api \
// RUN:   -verify-additional-prefix always-

/// Explicitly disable the diagnostic.
// RUN: sed -e 's/xpected-warning/not-something-expected/' < %s > %t/None.swift
// RUN: %target-swift-frontend -typecheck -parse-as-library -verify %t/None.swift \
// RUN:   -target %target-cpu-apple-macosx10.10 -require-explicit-availability=ignore \
// RUN:   -require-explicit-availability-target "macOS 10.10" -library-level api \
// RUN:   -verify-additional-prefix norequire- \
// RUN:   -verify-additional-prefix always-

/// Upgrade the diagnostic to an error.
// RUN: sed -e "s/xpected-warning/xpected-error/" < %s > %t/Errors.swift
// RUN: %target-swift-frontend -typecheck -parse-as-library -verify %t/Errors.swift \
// RUN:   -target %target-cpu-apple-macosx10.10 -require-explicit-availability=error \
// RUN:   -require-explicit-availability-target "macOS 10.10" \
// RUN:   -verify-additional-prefix always-

/// Error on an invalid argument.
// RUN: not %target-swift-frontend -typecheck %s -require-explicit-availability=NotIt 2>&1 \
// RUN:   | %FileCheck %s --check-prefix CHECK-ARG
// CHECK-ARG: error: unknown argument 'NotIt', passed to -require-explicit-availability, expected 'error', 'warn' or 'ignore'

public struct S { // expected-warning {{public declarations should have an availability attribute with an introduction version}}
  public func method() { }
}

@available(macOS, unavailable)
public struct UnavailableStruct {
  public func okMethod() { }
}

public func foo() { bar() } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@usableFromInline
func bar() { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{-1:1-1=@available(macOS 10.10, *)\n}}

@available(macOS 10.1, *)
public func ok() { }

@available(macOS, unavailable)
public func unavailableOk() { }

@available(macOS, deprecated: 10.10)
public func missingIntro() { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{-1:1-1=@available(macOS 10.10, *)\n}}

@available(iOS 9.0, *)
public func missingTargetPlatform() { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{-1:1-1=@available(macOS 10.10, *)\n}}

func privateFunc() { }

@_alwaysEmitIntoClient
public func alwaysEmitted() { }

@available(macOS 10.1, *)
struct SOk {
  public func okMethod() { }
}

precedencegroup MediumPrecedence {}
infix operator + : MediumPrecedence

public func +(lhs: S, rhs: S) -> S { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

public enum E { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@available(macOS, unavailable)
public enum UnavailableEnum {
  case caseOk
}

public class C { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@available(macOS, unavailable)
public class UnavailableClass {
  public func okMethod() { }
}

public protocol P { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@available(macOS, unavailable)
public protocol UnavailableProto {
  func requirementOk()
}

private protocol PrivateProto { }

extension S { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  public func warnForPublicMembers() { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{3-3=@available(macOS 10.10, *)\n  }}
}

@available(macOS 10.1, *)
extension S {
  public func okWhenTheExtensionHasAttribute() { }
}

@available(macOS, unavailable)
extension S {
  public func okWhenTheExtensionIsUnavailable() { }
}

extension S {
  internal func dontWarnWithoutPublicMembers() { }
  private func dontWarnWithoutPublicMembers1() { }
}

// An empty extension should be ok.
extension S { }

extension S : P { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
}

extension S : PrivateProto {
}

open class OpenClass { } // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

private class PrivateClass { }

extension PrivateClass { }

@available(macOS 10.1, *)
public protocol PublicProtocol { }

@available(macOS 10.1, *)
extension S : PublicProtocol { }

@_spi(SPIsAreOK)
public func spiFunc() { }

@_spi(SPIsAreOK)
public struct spiStruct {
  public func spiMethod() {}
}

extension spiStruct {
  public func spiExtensionMethod() {}
}

public var publicVar = S() // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@available(macOS 10.10, *)
public var publicVarOk = S()

@available(macOS, unavailable)
public var unavailablePublicVarOk = S()

public var (a, b) = (S(), S()) // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}

@available(macOS 10.10, *)
public var (c, d) = (S(), S())

public var _ = S() // expected-error {{global variable declaration does not bind any variables}}

public var implicitGet: S { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  return S()
}

@available(macOS 10.10, *)
public var implicitGetOk: S {
  return S()
}

@available(macOS, unavailable)
public var unavailableImplicitGetOk: S {
  return S()
}

public var computed: S { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  get { return S() }
  set { }
}

public var computedHalf: S { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  @available(macOS 10.10, *)
  get { return S() }
  set { }
}

// FIXME the following warning is not needed.
public var computedOk: S { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  @available(macOS 10.10, *)
  get { return S() }

  @available(macOS 10.10, *)
  set { }
}

@available(macOS 10.10, *)
public var computedOk1: S {
  get { return S() }
  set { }
}

public class SomeClass { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  public init () {}

  public subscript(index: String) -> Int {
    get { return 42; }
    set(newValue) { }
  }
}

extension SomeClass { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{1-1=@available(macOS 10.10, *)\n}}
  public convenience init(s : S) {} // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{3-3=@available(macOS 10.10, *)\n  }}

  @available(macOS 10.10, *)
  public convenience init(s : SomeClass) {}

  public subscript(index: Int) -> Int { // expected-warning {{public declarations should have an availability attribute with an introduction version}} {{3-3=@available(macOS 10.10, *)\n  }}
    get { return 42; }
    set(newValue) { }
  }

  @available(macOS 10.10, *)
  public subscript(index: S) -> Int {
    get { return 42; }
    set(newValue) { }
  }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, macCatalyst 13.0, *)
public struct StructWithImplicitMembers { }

extension StructWithImplicitMembers: Hashable { }
// expected-note @-1 {{add @available attribute to enclosing extension}}
// expected-warning @-2 {{public declarations should have an availability attribute with an introduction version}}
// expected-error @-3 {{'StructWithImplicitMembers' is only available in macOS 10.15 or newer}}

@available(macOS 10.10, *)
public func availabilityQueryFunc() { // expected-always-note 2 {{enclosing scope here}}
  if #available(macOS 10.9, *) {} // expected-always-warning {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.10, *) {} // expected-always-warning {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.11, *) {}

  if #available(iOS 9.0, *) {}
}

@available(macOS 10.10, *)
@inlinable public func inlinableAvailabilityQueryFunc() { // expected-norequire-note 2 {{enclosing scope here}}
  if #available(macOS 10.9, *) {} // expected-norequire-warning {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.10, *) {} // expected-norequire-warning {{unnecessary check for 'macOS'; enclosing scope ensures guard will always be true}}
  if #available(macOS 10.11, *) {}

  if #available(iOS 9.0, *) {}
}
