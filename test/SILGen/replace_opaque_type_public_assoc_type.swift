// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module-path %t/replace_opaque_type_public_assoc_type_m.swiftmodule %S/Inputs/replace_opaque_type_public_assoc_type_m.swift
// RUN: %target-swift-emit-silgen -I %t %s -verify

import replace_opaque_type_public_assoc_type_m

struct PiggyBack: Gesture {
    var action: () -> Void

    var body: some Gesture {
        action()
        return self
    }
}
