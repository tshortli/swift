/// Verify that the configurations of the `@_availabilityDomain` attribute can
/// be written to a binary module file and then read back in.

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %target-swift-frontend -emit-module -o %t/Library.swiftmodule \
// RUN:   -module-name Library -parse-as-library %t/Library.swift \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains

// RUN: %llvm-bcanalyzer -dump %t/Library.swiftmodule \
// RUN:   | %FileCheck --check-prefix BC-CHECK --implicit-check-not UnknownCode %s

// RUN: %target-swift-ide-test -print-module -module-to-print Library \
// RUN:   -source-filename x -I %t | %FileCheck --check-prefix MODULE-CHECK %s

// RUN: %target-swift-frontend -typecheck -verify -I %t %t/ClientDiagnostics.swift \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains

// RUN: %target-swift-frontend -emit-sil -I %t %t/ClientQueries.swift \
// RUN:   -enable-experimental-feature CustomAvailabilityDomains \
// RUN:   | %FileCheck --check-prefix CLIENT-SIL %s

// REQUIRES: swift_feature_CustomAvailabilityDomains

// EnabledDomain.
// BC-CHECK-DAG: <AvailabilityDomain_DECL_ATTR abbrevid={{[0-9]+}} op0=0 op1=0 op2=0 op3={{[0-9]+}}/>
// AlwaysEnabledDomain.
// BC-CHECK-DAG: <AvailabilityDomain_DECL_ATTR abbrevid={{[0-9]+}} op0=0 op1=1 op2=1 op3={{[0-9]+}}/>
// DisabledDomain.
// BC-CHECK-DAG: <AvailabilityDomain_DECL_ATTR abbrevid={{[0-9]+}} op0=0 op1=0 op2=2 op3={{[0-9]+}}/>
// DynamicDomain.
// BC-CHECK-DAG: <AvailabilityDomain_DECL_ATTR abbrevid={{[0-9]+}} op0=0 op1=0 op2=3 op3={{[0-9]+}}/>

// The printed module lists the declarations in alphabetical order.
// MODULE-CHECK:      @_availabilityDomain(AlwaysEnabledDomain, defaulted) _const let alwaysEnabledDomain: Bool
// MODULE-CHECK-NEXT: @_availabilityDomain(DisabledDomain) _const let disabledDomain: Bool
// MODULE-CHECK-NEXT: @_availabilityDomain(DynamicDomain) let dynamicDomain: Bool
// MODULE-CHECK-NEXT: @_availabilityDomain(EnabledDomain) _const let enabledDomain: Bool

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
