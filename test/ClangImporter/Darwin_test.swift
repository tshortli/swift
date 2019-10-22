// RUN: %target-typecheck-verify-swift %clang-importer-sdk

// REQUIRES: objc_interop

import Darwin
import MachO

_ = nil as Fract? // expected-error{{use of undeclared type 'Fract'}}
_ = nil as Darwin.Fract? // okay

_ = 0 as OSErr
// noErr is from the overlay
_ = noErr as OSStatus // expected-warning {{redundant cast to 'OSStatus' (aka 'Int32') has no effect}} {{11-23=}}
_ = 0 as UniChar

_ = ProcessSerialNumber()

_ = 0 as Byte // expected-error {{use of undeclared type 'Byte'}} {{10-14=UInt8}}
Darwin.fakeAPIUsingByteInDarwin() as Int // expected-error {{cannot convert value of type 'UInt8' to type 'Int' in coercion}}

_ = FALSE // expected-error {{use of unresolved identifier 'FALSE'}}
_ = DYLD_BOOL.FALSE
