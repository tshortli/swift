# Conformance availability errors (ConformanceAvailability)

Errors related to protocol conformances that are unavailable or restricted to specific availability contexts.

## Overview

The `ConformanceAvailability` group covers errors that occur when a type is used in a context that requires a protocol conformance, but that conformance is subject to availability restrictions. These restrictions arise from `@available` attributes on the extension that declares the conformance.

### Unavailable conformance

A conformance may be unconditionally unavailable, obsoleted in the current OS version, or restricted to a specific language version:

```swift
struct S {}
protocol P {}

@available(*, unavailable)
extension S: P {}

func f(_ p: some P) {}

func test(s: S) {
  f(s) // error: conformance of 'S' to 'P' is unavailable
}
```

### Conformance available only in newer OS versions

A conformance may require a minimum OS version to be used:

```swift
struct S {}
protocol P {}

@available(macOS 15, *)
extension S: P {}

func f(_ p: some P) {}

func test(s: S) {
  f(s) // error: conformance of 'S' to 'P' is only available in macOS 15 or newer
}
```

To fix this, add an `@available` attribute or `if #available` check to the context:

```swift
@available(macOS 15, *)
func test(s: S) {
  f(s) // OK
}
```
