/// Verify that the configurations of the `@_availabilityDomain` attribute can
/// be printed in a .swiftinterface file and then read back in.

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-emit-module-interface(%t/Library.swiftinterface) \
// RUN:   %t/Library.swift -module-name Library \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains
// RUN: %target-swift-typecheck-module-from-interface(%t/Library.swiftinterface) \
// RUN:   -module-name Library
// RUN: %FileCheck --check-prefix INTERFACE-CHECK %s < %t/Library.swiftinterface

// RUN: %target-swift-frontend -typecheck -verify -I %t %t/ClientDiagnostics.swift \
// RUN:   -module-cache-path %t/ModuleCache \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains

// RUN: %target-swift-frontend -emit-sil -I %t %t/ClientQueries.swift \
// RUN:   -module-cache-path %t/ModuleCache \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains \
// RUN:   | %FileCheck --check-prefix CLIENT-SIL %s

// REQUIRES: swift_feature_CustomAvailabilityDomains

/// Every domain definition is guarded, since a compiler that predates the
/// attribute cannot parse it. The initializer of a '_const' domain records
/// whether the domain is enabled, which is how the kind of the domain is
/// inferred again when this interface is compiled.

// INTERFACE-CHECK:      #if compiler(>=5.3) && $CustomAvailabilityDomains
// INTERFACE-CHECK-NEXT: @_availabilityDomain(EnabledDomain) _const public let enabledDomain: Swift::Bool = true
// INTERFACE-CHECK-NEXT: #endif

// INTERFACE-CHECK:      #if compiler(>=5.3) && $CustomAvailabilityDomains
// INTERFACE-CHECK-NEXT: @_availabilityDomain(AlwaysEnabledDomain, defaulted) _const public let alwaysEnabledDomain: Swift::Bool = true
// INTERFACE-CHECK-NEXT: #endif

// INTERFACE-CHECK:      #if compiler(>=5.3) && $CustomAvailabilityDomains
// INTERFACE-CHECK-NEXT: @_availabilityDomain(DisabledDomain) _const public let disabledDomain: Swift::Bool = false
// INTERFACE-CHECK-NEXT: #endif

/// A dynamic domain is the one kind with no initializer. The absence of
/// '_const' identifies it.

// INTERFACE-CHECK:      #if compiler(>=5.3) && $CustomAvailabilityDomains
// INTERFACE-CHECK-NEXT: @_availabilityDomain(DynamicDomain) public let dynamicDomain: Swift::Bool
// INTERFACE-CHECK-NEXT: #endif

//--- Library.swift

@_availabilityDomain(EnabledDomain)
_const public let enabledDomain = true

@_availabilityDomain(AlwaysEnabledDomain, defaulted)
_const public let alwaysEnabledDomain = true

@_availabilityDomain(DisabledDomain)
_const public let disabledDomain = false

@_availabilityDomain(DynamicDomain)
public let dynamicDomain = Bool.random()


//--- ClientDiagnostics.swift

import Library

@available(EnabledDomain)
public func availableInEnabledDomain() {}

@available(AlwaysEnabledDomain)
public func availableInAlwaysEnabledDomain() {}

@available(DisabledDomain)
public func availableInDisabledDomain() {}

@available(DynamicDomain)
public func availableInDynamicDomain() {}

public func testAvailable() { // expected-note 3 {{add '@available' attribute to enclosing global function}}
  availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInAlwaysEnabledDomain()
  availableInDisabledDomain() // expected-error {{'availableInDisabledDomain()' is only available in DisabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
}

//--- ClientQueries.swift

import Library

func yes() {}
func no() {}

// CLIENT-SIL-LABEL: sil @$s13ClientQueries18queryEnabledDomainyyF :
// CLIENT-SIL: function_ref @$s13ClientQueries3yesyyF :
// CLIENT-SIL-NOT: function_ref @$s13ClientQueries2noyyF :
public func queryEnabledDomain() {
  if #available(EnabledDomain) { yes() } else { no() }
}

// CLIENT-SIL-LABEL: sil @$s13ClientQueries24queryAlwaysEnabledDomainyyF :
// CLIENT-SIL: function_ref @$s13ClientQueries3yesyyF :
// CLIENT-SIL-NOT: function_ref @$s13ClientQueries2noyyF :
public func queryAlwaysEnabledDomain() {
  if #available(AlwaysEnabledDomain) { yes() } else { no() }
}

// CLIENT-SIL-LABEL: sil @$s13ClientQueries19queryDisabledDomainyyF :
// CLIENT-SIL: function_ref @$s13ClientQueries2noyyF :
// CLIENT-SIL-NOT: function_ref @$s13ClientQueries3yesyyF :
public func queryDisabledDomain() {
  if #available(DisabledDomain) { yes() } else { no() }
}

// CLIENT-SIL-LABEL: sil @$s13ClientQueries18queryDynamicDomainyyF :
// CLIENT-SIL: function_ref @$s13ClientQueries3yesyyF :
// FIXME: [availability] This should branch on the result of the getter for dynamicDomain
// CLIENT-SIL-NOT: function_ref @$s13ClientQueries2noyyF :
public func queryDynamicDomain() {
  if #available(DynamicDomain) { yes() } else { no() }
}
