@available(macOS 10.50, *)
public func conditionallyAvailableFunction() {}

@available(macOS, unavailable)
public func unavailableFunction() {}

@available(macOS 10.50, *)
public var conditionallyAvailableGlobal: Int {
  get {return 0}
  set {}
}

@available(macOS, unavailable)
public var unavailableGlobal: Int {
  get {return 0}
  set {}
}

@available(macOS 10.50, *)
public struct ConditionallyAvailableStruct {
  public func conditionallyAvailableMethod() {}
}

@available(macOS 10.50, *)
extension ConditionallyAvailableStruct {
  public struct NestedStruct {}
}

@available(macOS, unavailable)
public struct UnvailableStruct {
  public func unavailableMethod() {}
}

public protocol AlwaysAvailableProtocol {}

public struct AlwaysAvailableStruct {}

@available(macOS 10.50, *)
extension AlwaysAvailableStruct : AlwaysAvailableProtocol {}

@available(macOS, unavailable)
public protocol UnavailableProtocol {}

@available(macOS, unavailable)
extension AlwaysAvailableStruct : UnavailableProtocol {}

public enum AlwaysAvailableEnum {
  case alwaysAvailableCase

  @available(macOS 10.50, *)
  case conditionallyAvailableCase
}
