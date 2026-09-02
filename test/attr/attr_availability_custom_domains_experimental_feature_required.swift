// RUN: %target-typecheck-verify-swift

// The '@_availabilityDomain' attribute requires the 'CustomAvailabilityDomains'
// feature, and referring to the domain it defines requires the
// 'CustomAvailability' feature that 'CustomAvailabilityDomains' implies.

@_availabilityDomain(SomeDomain) // expected-error {{'@_availabilityDomain' is an experimental feature; use '-enable-experimental-feature CustomAvailabilityDomains'}}
_const let someDomain = true

@available(SomeDomain, unavailable) // expected-error {{SomeDomain requires '-enable-experimental-feature CustomAvailability'}}
func availableInSomeDomain() { }

if #available(SomeDomain) {} // expected-error {{SomeDomain requires '-enable-experimental-feature CustomAvailability'}}
// expected-error@-1 {{condition required for target platform}}
if #unavailable(SomeDomain) {} // expected-error {{SomeDomain requires '-enable-experimental-feature CustomAvailability'}}
