// RUN: %target-typecheck-verify-swift \
// RUN:  -enable-experimental-feature CustomAvailabilityDomains

// REQUIRES: swift_feature_CustomAvailabilityDomains

@_availabilityDomain(EnabledDomain)
_const let enabledDomain = true

@_availabilityDomain(DisabledDomain)
_const let disabledDomain = false

@_availabilityDomain(DynamicDomain)
let dynamicDomain = Bool.random()

if #available(EnabledDomain) { }
if #available(DisabledDomain) { }
if #available(DynamicDomain) { }
if #available(UnknownDomain) { } // expected-error {{cannot find availability domain 'UnknownDomain'}}
// expected-error@-1 {{condition required for target platform}}

if #unavailable(EnabledDomain) { }
if #unavailable(DisabledDomain) { }
if #unavailable(DynamicDomain) { }
if #unavailable(UnknownDomain) { } // expected-error {{cannot find availability domain 'UnknownDomain'}}

if #available(EnabledDomain 1.0) { } // expected-error {{unexpected version number for EnabledDomain}}
if #available(EnabledDomain, DisabledDomain) { } // expected-error {{EnabledDomain availability must be specified alone}}

if #available(EnabledDomain, swift 5) { } // expected-error {{EnabledDomain availability must be specified alone}}

while #available(EnabledDomain) { }

guard #available(EnabledDomain) else { }
