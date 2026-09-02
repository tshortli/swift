// RUN: %target-typecheck-verify-swift \
// RUN:  -enable-experimental-feature CustomAvailabilityDomains

// REQUIRES: swift_feature_CustomAvailabilityDomains

// MARK: Valid domain definitions

@_availabilityDomain(EnabledDomain)
_const let enabledDomain = true

@_availabilityDomain(DisabledDomain)
_const let disabledDomain = false

@_availabilityDomain(AlwaysEnabledDomain, defaulted)
_const let alwaysEnabledDomain = true

@_availabilityDomain(DynamicDomain)
let dynamicDomain = Bool.random()

// The name of the domain is independent of the name of the variable.
@_availabilityDomain(DomainWithUnrelatedVariableName)
_const let someVariable = true

@_availabilityDomain(TypeAnnotatedDomain)
_const let typeAnnotatedDomain: Bool = true

@_availabilityDomain(PublicDomain)
_const public let publicDomain = true

@available(EnabledDomain)
func availableInEnabledDomain() { }

@available(DisabledDomain, unavailable)
func unavailableInDisabledDomain() { }

@available(AlwaysEnabledDomain)
func availableInAlwaysEnabledDomain() { }

@available(DynamicDomain)
func availableInDynamicDomain() { }

@available(DomainWithUnrelatedVariableName)
func availableInDomainWithUnrelatedVariableName() { }

// MARK: Invalid attribute arguments

@_availabilityDomain // expected-error {{expected '(' in '_availabilityDomain' attribute}}
_const let missingParens = true

@_availabilityDomain() // expected-error {{expected an availability domain name in '@_availabilityDomain'}}
_const let missingName = true

@_availabilityDomain("QuotedDomain") // expected-error {{expected an availability domain name in '@_availabilityDomain'}}
_const let quotedName = true

@_availabilityDomain(NotDefaulted, notDefaulted) // expected-error {{expected 'defaulted' in '@_availabilityDomain'}}
_const let notDefaulted = true

@_availabilityDomain(DefaultedTwice, defaulted, defaulted) // expected-error {{expected ')' in '_availabilityDomain' attribute}}
_const let defaultedTwice = true

// MARK: Invalid declarations

@_availabilityDomain(VarDomain) // expected-error {{'@_availabilityDomain' may only be used on a global 'let' declaration}}
var varDomain = true

@_availabilityDomain(ComputedDomain) // expected-error {{'@_availabilityDomain' may only be used on a global 'let' declaration}}
var computedDomain: Bool { return true }

@_availabilityDomain(FuncDomain) // expected-error {{@_availabilityDomain may only be used on 'var' declarations}}
func funcDomain() -> Bool { true }

struct S {
  @_availabilityDomain(MemberDomain) // expected-error {{'@_availabilityDomain' may only be used on a global 'let' declaration}}
  static let memberDomain = true
}

func f() {
  @_availabilityDomain(LocalDomain) // expected-error {{'@_availabilityDomain' may only be used on a global 'let' declaration}}
  let localDomain = true
  _ = localDomain
}

// MARK: Invalid types

@_availabilityDomain(IntDomain) // expected-error {{availability domain 'IntDomain' must have type 'Bool'}}
_const let intDomain = 1

@_availabilityDomain(StringDomain) // expected-error {{availability domain 'StringDomain' must have type 'Bool'}}
_const let stringDomain = "true"

@_availabilityDomain(OptionalBoolDomain) // expected-error {{availability domain 'OptionalBoolDomain' must have type 'Bool'}}
_const let optionalBoolDomain: Bool? = true

// MARK: Invalid 'defaulted'

@_availabilityDomain(DefaultedDisabledDomain, defaulted) // expected-error {{'defaulted' may only be used on an availability domain that has a value of 'true' and is '_const'}}
_const let defaultedDisabledDomain = false

@_availabilityDomain(DefaultedDynamicDomain, defaulted) // expected-error {{'defaulted' may only be used on an availability domain that has a value of 'true' and is '_const'}}
let defaultedDynamicDomain = Bool.random()

// MARK: Redefinitions

@_availabilityDomain(RedefinedDomain) // expected-note {{availability domain 'RedefinedDomain' previously defined here}}
_const let redefinedDomain = true

@_availabilityDomain(RedefinedDomain) // expected-error {{invalid redeclaration of availability domain 'RedefinedDomain'}}
_const let redefinedDomainAgain = false

// The first definition wins, so 'RedefinedDomain' is enabled.
@available(RedefinedDomain)
func availableInRedefinedDomain() { }

func testRedefinedDomain() { // expected-note {{add '@available' attribute to enclosing global function}}
  availableInRedefinedDomain() // expected-error {{'availableInRedefinedDomain()' is only available in RedefinedDomain}}
  // expected-note@-1 {{add 'if #available' version check}}
}

// MARK: Built-in domain names

@_availabilityDomain(macOS) // expected-error {{'macOS' is a built-in availability domain}}
_const let macOSDomain = true

@_availabilityDomain(swift) // expected-error {{'swift' is a built-in availability domain}}
_const let swiftDomain = true

@_availabilityDomain(Swift) // expected-error {{'Swift' is a built-in availability domain}}
_const let swiftRuntimeDomain = true

@_availabilityDomain(SwiftLanguageMode) // expected-error {{'SwiftLanguageMode' is a built-in availability domain}}
_const let swiftLanguageModeDomain = true

@_availabilityDomain(_PackageDescription) // expected-error {{'_PackageDescription' is a built-in availability domain}}
_const let packageDescriptionDomain = true
