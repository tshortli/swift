// REQUIRES: swift_swift_parser

// RUN: %empty-directory(%t)
// RUN: split-file %s %t

// RUN: %host-build-swift -swift-version 5 -emit-library -o %t/%target-library-name(MacroDefinition) -module-name=MacroDefinition %S/Inputs/syntax_macro_definitions.swift -g -no-toolchain-stdlib-rpath

// Make sure we see the conformances from another file.
// RUN: %target-swift-frontend -typecheck -verify -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -module-name MacroUser -primary-file %t/other.swift %t/main.swift

// rdar://179531233 — In primary-file mode, SILGen crashed with "Found an
// invalid conformance" when the consumer of a typealias defined on a base
// protocol lived in a different file from the macro-attached type that only
// inherited the base conformance via the macro-emitted refinement.
// RUN: %target-swift-frontend -emit-silgen -swift-version 5 -load-plugin-library %t/%target-library-name(MacroDefinition) -module-name MacroUser -primary-file %t/other.swift %t/main.swift -o /dev/null

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

// rdar://179531233 — `Refined` refines `Base`, and `Base` exposes a
// `Self`-referencing typealias. The macro-emitted refinement conformance is
// the *only* path through which `MacroAttached: Base` is reachable.
public protocol Base {}
public protocol Refined: Base {}
public extension Base {
  typealias Wrapper = WrapperType<Self>
}
public struct WrapperType<Conformer: Base> {}

@attached(extension, conformances: Refined)
macro AddRefined() = #externalMacro(module: "MacroDefinition", type: "AddAllConformancesMacro")

@AddRefined
struct MacroAttached {}

//--- other.swift

struct STest {
  var x = requireEquatable(S())
}

@ConformanceViaExtension
class Child: Parent {}

struct UsesMacroAttachedWrapper {
  let wrapper: MacroAttached.Wrapper
}
