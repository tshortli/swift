// RUN: %target-typecheck-verify-swift -swift-version 5

// REQUIRES: OS=macosx

public protocol Horse {}
func takesHorse<T : Horse>(_: T) {}
func takesHorseExistential(_: Horse) {}

extension Horse {
  func giddyUp() {}
  var isGalloping: Bool { true }
}

struct UsesHorse<T : Horse> {}

// Availability with version
public struct HasAvailableConformance1 {}

@available(macOS 100, *)
extension HasAvailableConformance1 : Horse {}

// These availability violations are warnings because this test does not pass
// -swift-version 6.
// See the other test case in test/Sema/conformance_availability.swift for the
// same example but with -swift-version 6.

func passAvailableConformance1(x: HasAvailableConformance1) { // expected-note 6{{add '@available' attribute to enclosing global function}}
  takesHorse(x) // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}

  takesHorseExistential(x) // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}
  
  x.giddyUp() // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}
  
  _ = x.isGalloping // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}
  
  _ = x[keyPath: \.isGalloping] // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}

  _ = UsesHorse<HasAvailableConformance1>.self // expected-warning {{conformance of 'HasAvailableConformance1' to 'Horse' is only available in macOS 100 or newer; this is an error in the Swift 6 language mode}}
  // expected-note@-1 {{add 'if #available' version check}}
}

@available(macOS 100, *)
func passAvailableConformance1a(x: HasAvailableConformance1) {
  takesHorse(x)
  takesHorseExistential(x)
  x.giddyUp()
  _ = x.isGalloping
  _ = UsesHorse<HasAvailableConformance1>.self
}

// Explicit unavailability
public struct HasAvailableConformance2 {}

@available(*, unavailable) // expected-note 6 {{conformance of 'HasAvailableConformance2' to 'Horse' has been explicitly marked unavailable here}}
extension HasAvailableConformance2 : Horse {}

// Some availability diagnostics become warnings in Swift 5 mode without
// because they were incorrectly accepted before and rejecting them would break
// source compatibility. Others are unaffected because they have always been
// rejected.

func passAvailableConformance2(x: HasAvailableConformance2) {
  takesHorse(x) // expected-error {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable}}
  takesHorseExistential(x) // expected-warning {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable; this is an error in the Swift 6 language mode}}
  x.giddyUp() // expected-error {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable}}
  _ = x.isGalloping // expected-error {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable}}
  _ = x[keyPath: \.isGalloping] // expected-error {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable}}
  _ = UsesHorse<HasAvailableConformance2>.self // expected-error {{conformance of 'HasAvailableConformance2' to 'Horse' is unavailable}}
}

@available(*, unavailable)
func passAvailableConformance2a(x: HasAvailableConformance2) {
  takesHorse(x)
  takesHorseExistential(x)
  x.giddyUp()
  _ = x.isGalloping
  _ = UsesHorse<HasAvailableConformance2>.self
}

// rdar://130308868 - A witness drawn from a constrained extension must not
// require a conformance that is less available than the conformance being
// checked. This is an error in Swift 5 mode too, since the witness would
// otherwise crash at runtime on an older OS.
protocol Stable {}

protocol Stall {
  associatedtype Occupant
  func groom() // expected-note 2 {{protocol requirement here}}
}

extension Stall where Occupant : Stable {
  func groom() {} // expected-note 2 {{instance method 'groom()' requires this conformance}}
}

struct Hay {}

@available(macOS 200, *)
extension Hay : Stable {}
// expected-note@-1 {{conformance of 'Hay' to 'Stable' was introduced in macOS 200}}

@available(macOS 100, *)
struct HayStall : Stall {
  // expected-error@-1 {{protocol 'Stall' requires the conformance of 'Hay' to 'Stable' to be available in macOS 100 and newer}}
  typealias Occupant = Hay
}

struct Straw {}

@available(macOS, unavailable)
extension Straw : Stable {}
// expected-note@-2 {{conformance of 'Straw' to 'Stable' has been explicitly marked unavailable here}}

struct StrawStall : Stall {
  // expected-error@-1 {{protocol 'Stall' requires the conformance of 'Straw' to 'Stable', which is unavailable in macOS}}
  typealias Occupant = Straw
}

