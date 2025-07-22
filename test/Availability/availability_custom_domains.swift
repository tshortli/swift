// RUN: %target-typecheck-verify-swift \
// RUN:  -enable-experimental-feature CustomAvailability \
// RUN:  -define-enabled-availability-domain EnabledDomain \
// RUN:  -define-disabled-availability-domain DisabledDomain \
// RUN:  -define-dynamic-availability-domain DynamicDomain

// REQUIRES: swift_feature_CustomAvailability

func alwaysAvailable() { }

@available(EnabledDomain)
func availableInEnabledDomain() { }

@available(EnabledDomain, unavailable)
func unavailableInEnabledDomain() { } // expected-note * {{'unavailableInEnabledDomain()' has been explicitly marked unavailable here}}

@available(DisabledDomain, unavailable)
func unavailableInDisabledDomain() { } // expected-note * {{'unavailableInDisabledDomain()' has been explicitly marked unavailable here}}

@available(DynamicDomain)
func availableInDynamicDomain() { }

@available(DynamicDomain, deprecated, message: "Use something else")
func deprecatedInDynamicDomain() { }

@available(DynamicDomain, unavailable)
func unavailableInDynamicDomain() { } // expected-note * {{'unavailableInDynamicDomain()' has been explicitly marked unavailable here}}

@available(UnknownDomain) // expected-error {{unrecognized platform name 'UnknownDomain'}}
func availableInUnknownDomain() { }

func testDeployment() { // expected-note 2 {{add '@available' attribute to enclosing global function}}
  alwaysAvailable()
  availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
  unavailableInDisabledDomain() // expected-error {{'unavailableInDisabledDomain()' is unavailable}}
  deprecatedInDynamicDomain() // expected-warning {{'deprecatedInDynamicDomain()' is deprecated: Use something else}}
  unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInUnknownDomain()
}

func testIfAvailable(_ truthy: Bool) { // expected-note 9 {{add '@available' attribute to enclosing global function}}
  if #available(EnabledDomain) { // expected-note {{enclosing scope here}}
    availableInEnabledDomain()
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
    availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}

    if #available(DynamicDomain) {
      availableInEnabledDomain()
      unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
      availableInDynamicDomain()
      unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
    } else {
      availableInEnabledDomain()
      unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
      availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
      // expected-note@-1 {{add 'if #available' version check}}
      unavailableInDynamicDomain()
    }

    if #available(EnabledDomain) {} // expected-warning {{unnecessary check for 'EnabledDomain'; enclosing scope ensures guard will always be true}}

    if #unavailable(EnabledDomain) { // FIXME: [availability] Diagnose as unreachable
      // Unreachable.
      availableInEnabledDomain()
      unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
      availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
      // expected-note@-1 {{add 'if #available' version check}}
      unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
    }
  } else {
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain()
    availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
  }

  if #available(EnabledDomain), #available(DynamicDomain) {
    availableInEnabledDomain()
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
    availableInDynamicDomain()
    unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
  } else {
    // In this branch, we only know that one of the domains is unavailable,
    // but we don't know which.
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
    availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInDynamicDomain() // expected-error {{'unavailableInDynamicDomain()' is unavailable}}
  }

  if #available(EnabledDomain), truthy {
    availableInEnabledDomain()
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
  } else {
    // In this branch, the state of EnabledDomain remains unknown since
    // execution will reach here if "truthy" is false.
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
  }

  if #unavailable(EnabledDomain) {
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain()
  } else {
    availableInEnabledDomain()
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
  }

  // FIXME: [availability] Support mixed #available and #unavailable.
  if #unavailable(EnabledDomain), #available(DynamicDomain) {
    // expected-error@-1 {{#available and #unavailable cannot be in the same statement}}
  }
}

func testWhileAvailable() { // expected-note {{add '@available' attribute to enclosing global function}}
  while #available(EnabledDomain) { // expected-note {{enclosing scope here}}
    availableInEnabledDomain()
    unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}

    if #available(EnabledDomain) {} // expected-warning {{unnecessary check for 'EnabledDomain'; enclosing scope ensures guard will always be true}}
    if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose as unreachable
  }

  while #unavailable(EnabledDomain) {
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain()

    if #available(EnabledDomain) {} // FIXME: [availability] Diagnose as unreachable
    if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose as redundant
  }
}

func testGuardAvailable() { // expected-note 3 {{add '@available' attribute to enclosing global function}}
  guard #available(EnabledDomain) else { // expected-note {{enclosing scope here}}
    availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
    // expected-note@-1 {{add 'if #available' version check}}
    unavailableInEnabledDomain()
    availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
    // expected-note@-1 {{add 'if #available' version check}}

    return
  }

  availableInEnabledDomain()
  unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}

  if #available(EnabledDomain) {} // expected-warning {{unnecessary check for 'EnabledDomain'; enclosing scope ensures guard will always be true}}
  if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose as unreachable
}

@available(EnabledDomain)
func testEnabledDomainAvailable() { // expected-note {{add '@available' attribute to enclosing global function}} expected-note {{enclosing scope here}}
  availableInEnabledDomain()
  unavailableInEnabledDomain() // expected-error {{'unavailableInEnabledDomain()' is unavailable}}

  if #available(EnabledDomain) {} // expected-warning {{unnecessary check for 'EnabledDomain'; enclosing scope ensures guard will always be true}}
  if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose as unreachable

  alwaysAvailable()
  unavailableInDisabledDomain() // expected-error {{'unavailableInDisabledDomain()' is unavailable}}
  deprecatedInDynamicDomain() // expected-warning {{'deprecatedInDynamicDomain()' is deprecated: Use something else}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInUnknownDomain()
}

@available(EnabledDomain, unavailable)
func testEnabledDomainUnavailable() { // expected-note {{add '@available' attribute to enclosing global function}}
  availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  unavailableInEnabledDomain()

  if #available(EnabledDomain) {} // FIXME: [availability] Diagnose as unreachable
  if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose as redundant

  alwaysAvailable()
  unavailableInDisabledDomain() // expected-error {{'unavailableInDisabledDomain()' is unavailable}}
  deprecatedInDynamicDomain() // expected-warning {{'deprecatedInDynamicDomain()' is deprecated: Use something else}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInUnknownDomain()
}

@available(*, unavailable)
func testUniversallyUnavailable() {
  alwaysAvailable()
  // FIXME: [availability] Diagnostic consistency: potentially unavailable declaration shouldn't be diagnosed
  // in contexts that are unavailable to broader domains
  availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  unavailableInDisabledDomain()
  deprecatedInDynamicDomain() // expected-warning {{'deprecatedInDynamicDomain()' is deprecated: Use something else}}
  availableInDynamicDomain() // expected-error {{'availableInDynamicDomain()' is only available in DynamicDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
  availableInUnknownDomain()

  if #available(EnabledDomain) {} // FIXME: [availability] Diagnose?
  if #unavailable(EnabledDomain) {} // FIXME: [availability] Diagnose?
}

@available(EnabledDomain)
struct EnabledDomainAvailable {
  @available(DynamicDomain)
  func dynamicDomainAvailableMethod() {
    availableInEnabledDomain()
    availableInDynamicDomain()

    alwaysAvailable()
    unavailableInDisabledDomain() // expected-error {{'unavailableInDisabledDomain()' is unavailable}}
  }
}

func testFixIts() {
  // expected-note@-1 {{add '@available' attribute to enclosing global function}}{{1-1=@available(EnabledDomain)\n}}
  availableInEnabledDomain() // expected-error {{'availableInEnabledDomain()' is only available in EnabledDomain}}
  // expected-note@-1 {{add 'if #available' version check}}{{3-29=if #available(EnabledDomain) {\n      availableInEnabledDomain()\n  \} else {\n      // Fallback\n  \}}}
}

struct Container { }

@available(EnabledDomain)
extension Container {
  @available(EnabledDomain)
  func redundantlyAvailableInEnabledDomain() { }

  @available(EnabledDomain, unavailable)
  func unavailableInEnabledDomain() { }
}

protocol OpaqueReturnType { }

@available(EnabledDomain)
struct AvailableOpaqueReturnType: OpaqueReturnType { }

@available(EnabledDomain, unavailable)
struct UnavailableOpaqueReturnType: OpaqueReturnType { }

func testOpaqueReturnType() -> some OpaqueReturnType {
  if #available(EnabledDomain) { // expected-error {{opaque return type cannot depend on EnabledDomain availability}}
    return AvailableOpaqueReturnType()
  } else {
    return UnavailableOpaqueReturnType()
  }
}

class Base {
  func alwaysAvailable() { }

  @available(EnabledDomain)
  func overrideAsAvailable() { } // expected-note {{overridden declaration is here}}

  func overrideLessAvailable() { } // expected-note 2 {{overridden declaration is here}}

  @available(EnabledDomain)
  func overrideMoreAvailable() { }

  @available(EnabledDomain, unavailable)
  func overrideAsUnavailable() { }

  @available(EnabledDomain, unavailable)
  func overrideLessUnavailable() { } // expected-note 2 {{'overrideLessUnavailable()' has been explicitly marked unavailable here}}

  func overrideMoreUnavailable() { } // expected-note 2 {{overridden declaration is here}}
}

class DerivedAlwaysAvailable: Base {
  override func alwaysAvailable() { }

  @available(EnabledDomain)
  override func overrideAsAvailable() { }

  @available(EnabledDomain)
  override func overrideLessAvailable() { } // expected-error {{overriding 'overrideLessAvailable' must be as available as declaration it overrides}}

  override func overrideMoreAvailable() { }

  @available(EnabledDomain, unavailable)
  override func overrideAsUnavailable() { }

  override func overrideLessUnavailable() { } // expected-error {{cannot override 'overrideLessUnavailable' which has been marked unavailable}}
  // expected-note@-1 {{remove 'override' modifier to declare a new 'overrideLessUnavailable'}}

  @available(EnabledDomain, unavailable)
  override func overrideMoreUnavailable() { } // expected-error {{cannot override 'overrideMoreUnavailable' with a declaration that is marked unavailable}}{{298:3-41=}}
}

@available(EnabledDomain)
class DerivedAvailable: Base {
  override func alwaysAvailable() { }

  @available(EnabledDomain)
  override func overrideAsAvailable() { }

  @available(EnabledDomain)
  override func overrideLessAvailable() { }

  override func overrideMoreAvailable() { }

  @available(EnabledDomain, unavailable)
  override func overrideAsUnavailable() { }

  override func overrideLessUnavailable() { } // expected-error {{cannot override 'overrideLessUnavailable' which has been marked unavailable}}
  // expected-note@-1 {{remove 'override' modifier to declare a new 'overrideLessUnavailable'}}

  @available(EnabledDomain, unavailable)
  override func overrideMoreUnavailable() { } // expected-error {{cannot override 'overrideMoreUnavailable' with a declaration that is marked unavailable}}{{320:3-41=}}
}

@available(EnabledDomain, unavailable)
class DerivedUnavailable: Base {
  override func alwaysAvailable() { }

  @available(EnabledDomain)
  override func overrideAsAvailable() { } // expected-error {{overriding 'overrideAsAvailable' must be as available as declaration it overrides}}

  @available(EnabledDomain)
  override func overrideLessAvailable() { } // expected-error {{overriding 'overrideLessAvailable' must be as available as declaration it overrides}}

  override func overrideMoreAvailable() { }

  @available(EnabledDomain, unavailable)
  override func overrideAsUnavailable() { }

  override func overrideLessUnavailable() { }

  @available(EnabledDomain, unavailable)
  override func overrideMoreUnavailable() { }
}

protocol HasRequirementsInEnabledDomain {
  // ALLANXXX
}
