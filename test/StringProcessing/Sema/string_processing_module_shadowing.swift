// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -emit-module -emit-module-path %t/ShadowsStringProcessing.swiftmodule -module-name ShadowsStringProcessing %S/Inputs/ShadowsStringProcessing.swift
// RUN: %target-typecheck-verify-swift -I %t

import ShadowsStringProcessing

func f(_ t : Regex<Substring>) -> Bool {
  return t.someProperty == "123"
}

func g(_: _StringProcessing.Regex<Substring>) {}
