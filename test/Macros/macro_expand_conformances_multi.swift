// REQUIRES: swift_swift_parser

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %host-build-swift -swift-version 5 -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath

// Make sure we see the conformances from another file.
// RUN: %target-swift-frontend -typecheck -verify -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -module-name MacroUser -primary-file %t/other.swift %t/main.swift

//--- main.swift

@attached(extension, conformances: Equatable)
macro Equatable() = #externalMacro(module: "MacroDefinition", type: "EquatableMacro")

@attached(extension, conformances: Hashable)
macro Hashable() = #externalMacro(module: "MacroDefinition", type: "HashableMacro")

func requireEquatable(_ value: some Equatable) -> Int {
  print(value == value)
  return 0
}

func requireHashable(_ value: some Hashable) {
  print(value.hashValue)
}

@Equatable
struct S {}

protocol MyProtocol {}

@attached(extension, conformances: MyProtocol)
macro ConformanceViaExtension() = #externalMacro(module: "MacroDefinition", type: "ConformanceViaExtensionMacro")

@ConformanceViaExtension
class Parent {}

//--- other.swift

struct STest {
  var x = requireEquatable(S())
}

@ConformanceViaExtension
class Child: Parent {}
