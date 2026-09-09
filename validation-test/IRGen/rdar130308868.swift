// rdar://130308868 - A witness drawn from a constrained extension must not
// require a conformance that is unavailable at the deployment target. SILGen
// bakes such a conformance into the witness thunk. Across a module boundary,
// IRGen emits a weak reference to a conformance descriptor that is null at
// runtime on an older OS. The thunk then crashes when it is called.
//
// This file checks witness selection, where the problem starts, so a separate
// module is not needed to reproduce it.

// RUN: %target-swift-frontend -emit-ir -target %target-cpu-apple-macosx10.15 -module-name test %s | %FileCheck %s

// REQUIRES: OS=macosx

// 'Raw' stands in for CoreAudio's 'AudioObjectPropertyAddress', whose
// conformance to 'Hashable' was introduced in macOS 15. The conformance below
// is introduced after the deployment target of this file.
public struct Raw {
  public var value: Int
}

@available(macOS 50, *)
extension Raw: Hashable {
  public static func == (lhs: Raw, rhs: Raw) -> Bool { lhs.value == rhs.value }
  public func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

// The conformance of 'AvailableRaw' to 'Hashable' is introduced at the
// deployment target, so a witness that requires it is fine.
public struct AvailableRaw {
  public var value: Int
}

@available(macOS 10.15, *)
extension AvailableRaw: Hashable {
  public static func == (lhs: AvailableRaw, rhs: AvailableRaw) -> Bool {
    lhs.value == rhs.value
  }
  public func hash(into hasher: inout Hasher) { hasher.combine(value) }
}

// Both wrappers witness '==' and 'hash(into:)' explicitly, and leave
// 'hashValue' and '_rawHashValue(seed:)' defaulted. Only the availability of
// the conformance of the raw value to 'Hashable' differs.

public struct Wrapper: RawRepresentable {
  public let rawValue: Raw
  public init(rawValue: Raw) { self.rawValue = rawValue }
}

extension Wrapper: Hashable {
  public static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
    lhs.rawValue.value == rhs.rawValue.value
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.value)
  }
}

// 'extension RawRepresentable where RawValue: Hashable, Self: Hashable' must
// not witness either requirement here, because that match requires
// 'Raw: Hashable'. 'hashValue' comes from derivation instead, and
// '_rawHashValue(seed:)' comes from the unconstrained 'Hashable' extension.

// CHECK-LABEL: define {{.*}} @"$s4test7WrapperVSHAASH9hashValueSivgTW"(
// CHECK-NOT:     $sSYsSHRzSH8RawValueSYRpzrlE
// CHECK:         call swiftcc {{.*}} @"$s4test7WrapperV9hashValueSivg"(

// CHECK-LABEL: define {{.*}} @"$s4test7WrapperVSHAASH13_rawHashValue4seedS2i_tFTW"(
// CHECK-NOT:     $sSYsSHRzSH8RawValueSYRpzrlE
// CHECK:         call swiftcc {{.*}} @"$sSHsE13_rawHashValue4seedS2i_tF"(

public struct AvailableWrapper: RawRepresentable {
  public let rawValue: AvailableRaw
  public init(rawValue: AvailableRaw) { self.rawValue = rawValue }
}

extension AvailableWrapper: Hashable {
  public static func == (lhs: AvailableWrapper, rhs: AvailableWrapper) -> Bool {
    lhs.rawValue.value == rhs.rawValue.value
  }
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.value)
  }
}

// Here the constrained extension is the best match, and nothing prevents it
// from being chosen. Both witnesses come from it.

// CHECK-LABEL: define {{.*}} @"$s4test16AvailableWrapperVSHAASH9hashValueSivgTW"(
// CHECK:         call swiftcc {{.*}} @"$sSYsSHRzSH8RawValueSYRpzrlE04hashB0Sivg"(

// CHECK-LABEL: define {{.*}} @"$s4test16AvailableWrapperVSHAASH13_rawHashValue4seedS2i_tFTW"(
// CHECK:         call swiftcc {{.*}} @"$sSYsSHRzSH8RawValueSYRpzrlE08_rawHashB04seedS2i_tF"(
