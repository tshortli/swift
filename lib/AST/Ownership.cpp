//===--- Ownership.cpp - Swift ASTs for Ownership ------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/AST/Ownership.h"
#include "swift/AST/Decl.h"
#include "swift/AST/StorageImpl.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Compiler.h"

using namespace swift;

llvm::StringRef swift::getOwnershipSpelling(ValueOwnership ownership) {
  switch (ownership) {
  case ValueOwnership::Default:
    return "default";
  case ValueOwnership::InOut:
    return "inout";
  case ValueOwnership::Shared:
    return "borrowing";
  case ValueOwnership::Owned:
    return "consuming";
  }
  llvm_unreachable("Invalid ValueOwnership");
}

llvm::StringRef swift::getOwnershipSpelling(LoweredOwnership ownership) {
  switch (ownership) {
  case LoweredOwnership::Shared:
    return getOwnershipSpelling(ValueOwnership::Shared);
  case LoweredOwnership::InOut:
    return getOwnershipSpelling(ValueOwnership::InOut);
  case LoweredOwnership::Owned:
    return getOwnershipSpelling(ValueOwnership::Owned);
  }
  llvm_unreachable("Invalid LoweredOwnership");
}

LoweredOwnership swift::getLoweredOwnership(ValueOwnership written,
                                            const AbstractFunctionDecl *fn,
                                            bool isSelf) {
  switch (written) {
  case ValueOwnership::Shared:
    return LoweredOwnership::Shared;
  case ValueOwnership::InOut:
    return LoweredOwnership::InOut;
  case ValueOwnership::Owned:
    return LoweredOwnership::Owned;
  case ValueOwnership::Default:
    break;
  }
  if (isa_and_nonnull<ConstructorDecl>(fn))
    return LoweredOwnership::Owned;
  if (auto *ad = dyn_cast_or_null<AccessorDecl>(fn)) {
    // A setter or an init accessor owns its parameters other than `self`. A
    // setter that's mutating writes `self` as `inout`, so if it isn't written,
    // `self` is borrowed.
    if (ad->getAccessorKind() == AccessorKind::Set ||
        ad->getAccessorKind() == AccessorKind::Init)
      return isSelf ? LoweredOwnership::Shared : LoweredOwnership::Owned;
    // A modify or mutate accessor's `self` is `inout`. Its other parameters
    // are borrowed, like those of any other function.
    if (isYieldingMutableAccessor(ad->getAccessorKind()) && isSelf)
      return LoweredOwnership::InOut;
  }
  return LoweredOwnership::Shared;
}
