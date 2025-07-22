// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -typecheck -verify \
// RUN:   -enable-experimental-feature CustomAvailability \
// RUN:   -import-objc-header %S/Inputs/availability_domains_bridging_header.h \
// RUN:   -I %S/../Inputs/custom-modules/availability-domains \
// RUN:   -Xcc -DOBJC=1 %s

// Re-test with the bridging header precompiled into a .pch.
// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -emit-pch \
// RUN:   -o %t/bridging-header.pch \
// RUN:   %S/Inputs/availability_domains_bridging_header.h -Xcc -DOBJC=1

// RUN: %target-swift-frontend(mock-sdk: %clang-importer-sdk) -typecheck -verify \
// RUN:   -enable-experimental-feature CustomAvailability \
// RUN:   -import-objc-header %t/bridging-header.pch \
// RUN:   -I %S/../Inputs/custom-modules/availability-domains \
// RUN:   -Xcc -DOBJC=1 %s

// REQUIRES: swift_feature_CustomAvailability
// REQUIRES: objc_interop

import Oceans // re-exports Rivers

func testObjCDecls() { // expected-note 2 {{add '@available' attribute to enclosing global function}}
  _ = AvailableInArctic() // expected-error {{'AvailableInArctic' is only available in Arctic}}
  // expected-note@-1 {{add 'if #available' version check}}
  _ = UnavailableInPacific() // expected-error {{'UnavailableInPacific' is unavailable}}
  _ = AvailableInColorado() // expected-error {{'AvailableInColorado' is only available in Colorado}}
  // expected-note@-1 {{add 'if #available' version check}}
}
