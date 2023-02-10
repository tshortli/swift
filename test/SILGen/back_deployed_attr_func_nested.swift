// RUN: %target-swift-emit-sil -parse-as-library -module-name back_deploy %s -target %target-cpu-apple-macosx10.50 -verify
// RUN: %target-swift-emit-silgen -parse-as-library -module-name back_deploy %s | %FileCheck %s
// RUN: %target-swift-emit-silgen -parse-as-library -module-name back_deploy %s -target %target-cpu-apple-macosx10.50 | %FileCheck %s

// REQUIRES: OS=macosx

@backDeployed(before: macOS 10.52)
public func funcWithNestedFunc() -> Int {
  func nestedFunc() -> Int { 2 }
  return nestedFunc()
}
