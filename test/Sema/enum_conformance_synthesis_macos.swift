// RUN: %target-swift-frontend -typecheck -verify %s

// REQUIRES: OS=macosx

struct EquatableUnavailableOnMacOS { }

@available(macOS, unavailable)
extension EquatableUnavailableOnMacOS: Equatable { }

struct EquatableInFutureMacOS { }

@available(macOS 99, *)
extension EquatableInFutureMacOS: Equatable { }

// ALLANXXX should be diagnosed
enum HasEquatableUnavailableOnMacOSElement: Equatable {
  case a(EquatableUnavailableOnMacOS)
}
enum HasEquatableInMacOS99Element: Equatable {
  case a(EquatableInFutureMacOS)
}

// OK, the necessary member conformances are as unavailable.
@available(macOS, unavailable)
enum UnavailableOnMacOSWithUnavailableElement: Equatable {
  case a(EquatableUnavailableOnMacOS)
}
@available(macOS 99, *)
enum AvailableInFutureMacOSWithEquatableInFutureMacOSElement: Equatable {
  case a(EquatableInFutureMacOS)
}
