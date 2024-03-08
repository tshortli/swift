//===--- FeatureSet.cpp - Language feature support --------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "FeatureSet.h"

#include "swift/AST/ASTVisitor.h"
#include "swift/AST/Decl.h"
#include "swift/AST/ExistentialLayout.h"
#include "swift/AST/GenericParamList.h"
#include "swift/AST/InverseMarking.h"
#include "swift/AST/ParameterList.h"
#include "swift/AST/Pattern.h"
#include "swift/AST/TypeCheckRequests.h"
#include "clang/AST/DeclObjC.h"

using namespace swift;

/// Does the interface of this declaration use a type for which the
/// given predicate returns true?
static bool usesTypeMatching(Decl *decl, llvm::function_ref<bool(Type)> fn) {
  if (auto value = dyn_cast<ValueDecl>(decl)) {
    if (Type type = value->getInterfaceType()) {
      return type.findIf(fn);
    }
  }

  return false;
}

/// \param isRelevantInverse the function used to inspect a mark corresponding
/// to an inverse to determine whether it "has" an inverse that we care about.
static bool hasInverse(
    Decl *decl, InvertibleProtocolKind ip,
    std::function<bool(InverseMarking::Mark const &)> isRelevantInverse) {

  auto getTypeDecl = [](Type type) -> TypeDecl * {
    if (auto genericTy = type->getAnyGeneric())
      return genericTy;
    if (auto gtpt = dyn_cast<GenericTypeParamType>(type))
      return gtpt->getDecl();
    return nullptr;
  };

  if (auto *extension = dyn_cast<ExtensionDecl>(decl)) {
    if (auto *nominal = extension->getSelfNominalTypeDecl())
      return hasInverse(nominal, ip, isRelevantInverse);
    return false;
  }

  auto hasInverseInType = [&](Type type) {
    return type.findIf([&](Type type) -> bool {
      if (auto *typeDecl = getTypeDecl(type))
        return hasInverse(typeDecl, ip, isRelevantInverse);
      return false;
    });
  };

  if (auto *TD = dyn_cast<TypeDecl>(decl)) {
    if (auto *alias = dyn_cast<TypeAliasDecl>(TD))
      return hasInverseInType(alias->getUnderlyingType());

    if (auto *NTD = dyn_cast<NominalTypeDecl>(TD)) {
      if (isRelevantInverse(NTD->hasInverseMarking(ip)))
        return true;
    }

    if (auto *P = dyn_cast<ProtocolDecl>(TD)) {
      // Check the protocol's associated types too.
      return llvm::any_of(
          P->getAssociatedTypeMembers(), [&](AssociatedTypeDecl *ATD) {
            return isRelevantInverse(ATD->hasInverseMarking(ip));
          });
    }

    return false;
  }

  if (auto *VD = dyn_cast<ValueDecl>(decl)) {
    if (VD->hasInterfaceType())
      return hasInverseInType(VD->getInterfaceType());
  }

  return false;
}

// ALLANXXX document, nest in FeatureUseChecker
class ReferencedTypesCollector : public DeclVisitor<ReferencedTypesCollector> {
  llvm::SmallPtrSet<Type, 16> &Types;

  void addType(Type ty) {
    if (!ty)
      return;

    Types.insert(ty);

    // ALLANXXX
//    Decl *declToVisit = nullptr;
//    if (auto *nominal = ty->getAnyNominal()) {
//      declToVisit = nominal;
//    } else if (auto *generic = ty->getAnyGeneric()) {
//      declToVisit = generic;
//    }
//
//    if (declToVisit) {
//      if (!DidVisit.contains(declToVisit))
//        ToVisit.insert(declToVisit);
//    }
  }

  void addInheritedTypes(InheritedTypes inherited) {
    for (unsigned i : inherited.getIndices()) {
      addType(inherited.getResolvedType(i));
    }
  }

  void addTypesFromGenericContext(const GenericContext *ownerCtx) {
    if (auto params = ownerCtx->getGenericParams()) {
      for (auto param : *params) {
        addInheritedTypes(param->getInherited());
      }
    }

    if (ownerCtx->getTrailingWhereClause()) {
      WhereClauseOwner(const_cast<GenericContext *>(ownerCtx))
        .visitRequirements(
                           TypeResolutionStage::Interface,
                           [this](const Requirement &req, RequirementRepr *reqRepr) {
                             switch (req.getKind()) {
                               case RequirementKind::SameShape:
                               case RequirementKind::Conformance:
                               case RequirementKind::SameType:
                               case RequirementKind::Superclass:
                                 addType(req.getFirstType());
                                 addType(req.getSecondType());
                                 break;
                               case RequirementKind::Layout:
                                 addType(req.getFirstType());
                                 break;
                             }
                             return false;
                           });
    }
  }

public:
  ReferencedTypesCollector(llvm::SmallPtrSet<Type, 16> &types) : Types(types) {}

  void visitNominalTypeDecl(NominalTypeDecl *nominal) {
    addInheritedTypes(nominal->getInherited());
  }

  void visitExtensionDecl(ExtensionDecl *extension) {
    addType(extension->getExtendedType());
    addInheritedTypes(extension->getInherited());
    addTypesFromGenericContext(extension);
  }

  void visitValueDecl(ValueDecl *value) {
    if (auto genericContext = value->getAsGenericContext())
      addTypesFromGenericContext(genericContext);

    if (Type type = value->getInterfaceType()) {
      type.visit([this](Type ty) {
        addType(ty);
      });
    }
  }
};

class FeatureUseChecker {

};

template <typename F>
[[nodiscard]] static bool usesTypeDeclMatching(Decl *originalDecl, F predicate) {
  SmallPtrSet<Decl *, 16> didVisit;
  llvm::SmallSetVector<Decl *, 16> toVisit;
  toVisit.insert(originalDecl);

  auto visitType = [&toVisit, &didVisit](Type ty) {
    if (ty) {
      if (auto *nominal = ty->getAnyNominal()) {
        if (!didVisit.contains(nominal))
          toVisit.insert(nominal);
      }
    }
  };

  auto visitInherited = [&visitType](InheritedTypes inherited) {
    for (unsigned i : inherited.getIndices()) {
      visitType(inherited.getResolvedType(i));
    }
  };

  auto visitGenericContext = [&visitType,
                              &visitInherited](const GenericContext *ownerCtx) {
    if (!ownerCtx->isGenericContext())
      return;

    if (auto params = ownerCtx->getGenericParams()) {
      for (auto param : *params) {
        visitInherited(param->getInherited());
      }
    }

    if (ownerCtx->getTrailingWhereClause()) {
      WhereClauseOwner(const_cast<GenericContext *>(ownerCtx))
          .visitRequirements(
              TypeResolutionStage::Interface,
              [&visitType](const Requirement &req, RequirementRepr *reqRepr) {
                switch (req.getKind()) {
                case RequirementKind::SameShape:
                case RequirementKind::Conformance:
                case RequirementKind::SameType:
                case RequirementKind::Superclass:
                  visitType(req.getFirstType());
                  visitType(req.getSecondType());
                  break;
                case RequirementKind::Layout:
                  visitType(req.getFirstType());
                  break;
                }
                return false;
              });
    }
  };

  while (toVisit.size() > 0) {
    auto decl = toVisit.pop_back_val();
    if (!didVisit.insert(decl).second)
      continue;

    if (predicate(decl))
      return true;

    if (auto nominal = dyn_cast<NominalTypeDecl>(decl))
      visitInherited(nominal->getInherited());

    if (auto ext = dyn_cast<ExtensionDecl>(decl)) {
      visitType(ext->getExtendedType());
      visitInherited(ext->getInherited());
      visitGenericContext(decl->getAsGenericContext());
    }

    if (auto value = dyn_cast<ValueDecl>(decl)) {
      if (auto genericContext = decl->getAsGenericContext())
        visitGenericContext(genericContext);

      if (Type type = value->getInterfaceType()) {
        type.visit([visitType](Type ty) {
          visitType(ty);
        });
      }
    }
  }

  return false;
}

// ----------------------------------------------------------------------------
// MARK: - Standard Features
// ----------------------------------------------------------------------------

/// Functions to determine which features a particular declaration uses. The
/// usesFeatureNNN functions correspond to the features in Features.def.

#define BASELINE_LANGUAGE_FEATURE(FeatureName, SENumber, Description)          \
  static bool usesFeature##FeatureName(Decl *decl) { return false; }
#define LANGUAGE_FEATURE(FeatureName, SENumber, Description)
#include "swift/Basic/Features.def"

#define UNINTERESTING_FEATURE(FeatureName)                                     \
  static bool usesFeature##FeatureName(Decl *decl) { return false; }

static bool usesFeatureRethrowsProtocol(Decl *decl) {
  return usesTypeDeclMatching(decl, [](Decl *typeDecl) {
    if (auto proto = dyn_cast<ProtocolDecl>(typeDecl))
      return proto->getAttrs().hasAttribute<AtRethrowsAttr>();
    return false;
  });
}

UNINTERESTING_FEATURE(BuiltinBuildTaskExecutorRef)
UNINTERESTING_FEATURE(BuiltinBuildComplexEqualityExecutor)
UNINTERESTING_FEATURE(BuiltinCreateAsyncTaskInGroupWithExecutor)
UNINTERESTING_FEATURE(BuiltinCreateAsyncDiscardingTaskInGroup)
UNINTERESTING_FEATURE(BuiltinCreateAsyncDiscardingTaskInGroupWithExecutor)
UNINTERESTING_FEATURE(BuiltinUnprotectedStackAlloc)
UNINTERESTING_FEATURE(BuiltinAllocVector)

static bool usesFeatureNewCxxMethodSafetyHeuristics(Decl *decl) {
  return decl->hasClangNode();
}

static bool usesFeatureSpecializeAttributeWithAvailability(Decl *decl) {
  if (auto func = dyn_cast<AbstractFunctionDecl>(decl)) {
    for (auto specialize : func->getAttrs().getAttributes<SpecializeAttr>()) {
      if (!specialize->getAvailableAttrs().empty())
        return true;
    }
  }
  return false;
}

static bool usesFeaturePrimaryAssociatedTypes2(Decl *decl) {
  if (auto *protoDecl = dyn_cast<ProtocolDecl>(decl)) {
    if (protoDecl->getPrimaryAssociatedTypes().size() > 0)
      return true;
  }

  return false;
}

static bool usesFeatureAssociatedTypeAvailability(Decl *decl) {
  return isa<AssociatedTypeDecl>(decl) &&
         decl->getAttrs().hasAttribute<AvailableAttr>();
}

static bool isImplicitRethrowsProtocol(const ProtocolDecl *proto) {
  return proto->isSpecificProtocol(KnownProtocolKind::AsyncSequence) ||
         proto->isSpecificProtocol(KnownProtocolKind::AsyncIteratorProtocol);
}

static bool usesFeatureAsyncSequenceFailure(Decl *decl) {
  if (auto proto = dyn_cast<ProtocolDecl>(decl)) {
    return isImplicitRethrowsProtocol(proto);
  }

  return false;
}

static bool usesFeatureMacros(Decl *decl) { return isa<MacroDecl>(decl); }

static bool usesFeatureFreestandingExpressionMacros(Decl *decl) {
  auto macro = dyn_cast<MacroDecl>(decl);
  if (!macro)
    return false;

  return macro->getMacroRoles().contains(MacroRole::Expression);
}

static bool usesFeatureAttachedMacros(Decl *decl) {
  auto macro = dyn_cast<MacroDecl>(decl);
  if (!macro)
    return false;

  return static_cast<bool>(macro->getMacroRoles() & getAttachedMacroRoles());
}

static bool usesFeatureExtensionMacros(Decl *decl) {
  auto macro = dyn_cast<MacroDecl>(decl);
  if (!macro)
    return false;

  return macro->getMacroRoles().contains(MacroRole::Extension);
}

static bool usesFeatureMoveOnly(Decl *decl) {
  return hasInverse(decl, InvertibleProtocolKind::Copyable,
                    [](auto &marking) -> bool {
                      return marking.is(InverseMarking::Kind::LegacyExplicit);
                    });
}

static bool usesFeatureMoveOnlyResilientTypes(Decl *decl) {
  if (usesFeatureMoveOnly(decl)) {
    return usesTypeDeclMatching(decl, [](Decl *typeDecl) {
      if (auto *nominal = dyn_cast<NominalTypeDecl>(typeDecl))
        return nominal->isResilient();
      return false;
    });
  }

  return false;
}

static bool hasParameterPacks(Decl *decl) {
  if (auto genericContext = decl->getAsGenericContext()) {
    auto sig = genericContext->getGenericSignature();
    if (llvm::any_of(sig.getGenericParams(),
                     [&](const GenericTypeParamType *GP) {
                       return GP->isParameterPack();
                     })) {
      return true;
    }
  }

  return false;
}

/// A declaration needs the $ParameterPacks feature if it declares a
/// generic parameter pack, or if its type references a generic nominal
/// or type alias which declares a generic parameter pack.
static bool usesFeatureParameterPacks(Decl *decl) {
  if (hasParameterPacks(decl))
    return true;

  if (auto *valueDecl = dyn_cast<ValueDecl>(decl)) {
    if (valueDecl->getInterfaceType().findIf([&](Type t) {
          if (auto *alias = dyn_cast<TypeAliasType>(t.getPointer()))
            return hasParameterPacks(alias->getDecl());
          if (auto *nominal = t->getAnyNominal())
            return hasParameterPacks(nominal);

          return false;
        })) {
      return true;
    }
  }

  return false;
}

static bool usesFeatureLexicalLifetimes(Decl *decl) {
  return decl->getAttrs().hasAttribute<EagerMoveAttr>() ||
         decl->getAttrs().hasAttribute<NoEagerMoveAttr>() ||
         decl->getAttrs().hasAttribute<LexicalLifetimesAttr>();
}

static bool usesFeatureFreestandingMacros(Decl *decl) {
  auto macro = dyn_cast<MacroDecl>(decl);
  if (!macro)
    return false;

  return macro->getMacroRoles().contains(MacroRole::Declaration);
}

static bool usesFeatureRetroactiveAttribute(Decl *decl) {
  auto ext = dyn_cast<ExtensionDecl>(decl);
  if (!ext)
    return false;

  return llvm::any_of(
      ext->getInherited().getEntries(),
      [](const InheritedEntry &entry) { return entry.isRetroactive(); });
}

static bool usesFeatureExtensionMacroAttr(Decl *decl) {
  return usesFeatureExtensionMacros(decl);
}

static bool usesFeatureTypedThrows(Decl *decl) {
  if (auto func = dyn_cast<AbstractFunctionDecl>(decl)) {
    return usesTypeMatching(decl, [](Type ty) {
      if (auto funcType = ty->getAs<AnyFunctionType>())
        return funcType->hasThrownError();

      return false;
    });
  }

  return false;
}

static bool usesFeatureOptionalIsolatedParameters(Decl *decl) {
  auto *value = dyn_cast<ValueDecl>(decl);
  if (!value)
    return false;

  auto *paramList = getParameterList(value);
  if (!paramList)
    return false;

  for (auto param : *paramList) {
    if (param->isIsolated()) {
      auto paramType = param->getInterfaceType();
      return !paramType->getOptionalObjectType().isNull();
    }
  }

  return false;
}

static bool usesFeatureExtern(Decl *decl) {
  return decl->getAttrs().hasAttribute<ExternAttr>();
}

static bool usesFeatureExpressionMacroDefaultArguments(Decl *decl) {
  if (auto func = dyn_cast<AbstractFunctionDecl>(decl)) {
    for (auto param : *func->getParameters()) {
      if (param->getDefaultArgumentKind() ==
          DefaultArgumentKind::ExpressionMacro)
        return true;
    }
  }

  return false;
}

UNINTERESTING_FEATURE(BuiltinStoreRaw)

// ----------------------------------------------------------------------------
// MARK: - Upcoming Features
// ----------------------------------------------------------------------------

UNINTERESTING_FEATURE(ConciseMagicFile)
UNINTERESTING_FEATURE(ForwardTrailingClosures)
UNINTERESTING_FEATURE(StrictConcurrency)
UNINTERESTING_FEATURE(BareSlashRegexLiterals)
UNINTERESTING_FEATURE(DeprecateApplicationMain)

static bool usesFeatureImportObjcForwardDeclarations(Decl *decl) {
  ClangNode clangNode = decl->getClangNode();
  if (!clangNode)
    return false;

  const clang::Decl *clangDecl = clangNode.getAsDecl();
  if (!clangDecl)
    return false;

  if (auto objCInterfaceDecl = dyn_cast<clang::ObjCInterfaceDecl>(clangDecl))
    return !objCInterfaceDecl->hasDefinition();

  if (auto objCProtocolDecl = dyn_cast<clang::ObjCProtocolDecl>(clangDecl))
    return !objCProtocolDecl->hasDefinition();

  return false;
}

UNINTERESTING_FEATURE(DisableOutwardActorInference)
UNINTERESTING_FEATURE(InternalImportsByDefault)
UNINTERESTING_FEATURE(IsolatedDefaultValues)
UNINTERESTING_FEATURE(GlobalConcurrency)
UNINTERESTING_FEATURE(FullTypedThrows)
UNINTERESTING_FEATURE(ExistentialAny)
UNINTERESTING_FEATURE(InferSendableFromCaptures)
UNINTERESTING_FEATURE(ImplicitOpenExistentials)

// ----------------------------------------------------------------------------
// MARK: - Experimental Features
// ----------------------------------------------------------------------------

UNINTERESTING_FEATURE(StaticAssert)
UNINTERESTING_FEATURE(NamedOpaqueTypes)
UNINTERESTING_FEATURE(FlowSensitiveConcurrencyCaptures)

static bool usesFeatureCodeItemMacros(Decl *decl) {
  auto macro = dyn_cast<MacroDecl>(decl);
  if (!macro)
    return false;

  return macro->getMacroRoles().contains(MacroRole::CodeItem);
}

UNINTERESTING_FEATURE(BodyMacros)
UNINTERESTING_FEATURE(TupleConformances)

static bool usesFeatureSymbolLinkageMarkers(Decl *decl) {
  auto &attrs = decl->getAttrs();
  return std::any_of(attrs.begin(), attrs.end(), [](auto *attr) {
    if (isa<UsedAttr>(attr))
      return true;
    if (isa<SectionAttr>(attr))
      return true;
    return false;
  });
}

UNINTERESTING_FEATURE(LazyImmediate)

static bool usesFeatureMoveOnlyClasses(Decl *decl) {
  return isa<ClassDecl>(decl) && usesFeatureMoveOnly(decl);
}

static bool usesFeatureNoImplicitCopy(Decl *decl) {
  return decl->isNoImplicitCopy();
}

UNINTERESTING_FEATURE(OldOwnershipOperatorSpellings)

static bool usesFeatureMoveOnlyEnumDeinits(Decl *decl) {
  if (auto *ei = dyn_cast<EnumDecl>(decl)) {
    return usesFeatureMoveOnly(ei) && ei->getValueTypeDestructor();
  }
  return false;
}

UNINTERESTING_FEATURE(MoveOnlyTuples)

static bool usesFeatureMoveOnlyPartialConsumption(Decl *decl) {
  // Partial consumption does not affect declarations directly.
  return false;
}

UNINTERESTING_FEATURE(MoveOnlyPartialReinitialization)

UNINTERESTING_FEATURE(OneWayClosureParameters)

static bool usesFeatureLayoutPrespecialization(Decl *decl) {
  auto &attrs = decl->getAttrs();
  return std::any_of(attrs.begin(), attrs.end(), [](auto *attr) {
    if (auto *specialize = dyn_cast<SpecializeAttr>(attr)) {
      return !specialize->getTypeErasedParams().empty();
    }
    return false;
  });
}

UNINTERESTING_FEATURE(AccessLevelOnImport)
UNINTERESTING_FEATURE(LayoutStringValueWitnesses)
UNINTERESTING_FEATURE(LayoutStringValueWitnessesInstantiation)
UNINTERESTING_FEATURE(DifferentiableProgramming)
UNINTERESTING_FEATURE(ForwardModeDifferentiation)
UNINTERESTING_FEATURE(AdditiveArithmeticDerivedConformances)
UNINTERESTING_FEATURE(SendableCompletionHandlers)
UNINTERESTING_FEATURE(OpaqueTypeErasure)
UNINTERESTING_FEATURE(ParserRoundTrip)
UNINTERESTING_FEATURE(ParserValidation)
UNINTERESTING_FEATURE(ParserDiagnostics)
UNINTERESTING_FEATURE(ImplicitSome)
UNINTERESTING_FEATURE(ParserASTGen)
UNINTERESTING_FEATURE(BuiltinMacros)
UNINTERESTING_FEATURE(ImportSymbolicCXXDecls)
UNINTERESTING_FEATURE(GenerateBindingsForThrowingFunctionsInCXX)

static bool usesFeatureReferenceBindings(Decl *decl) {
  auto *vd = dyn_cast<VarDecl>(decl);
  return vd && vd->getIntroducer() == VarDecl::Introducer::InOut;
}

UNINTERESTING_FEATURE(BuiltinModule)
UNINTERESTING_FEATURE(RegionBasedIsolation)
UNINTERESTING_FEATURE(PlaygroundExtendedCallbacks)
UNINTERESTING_FEATURE(ThenStatements)
UNINTERESTING_FEATURE(DoExpressions)
UNINTERESTING_FEATURE(ImplicitLastExprResults)

static bool usesFeatureRawLayout(Decl *decl) {
  return usesTypeDeclMatching(decl, [](Decl *typeDecl) {
    return typeDecl->getAttrs().hasAttribute<RawLayoutAttr>();
  });
}

UNINTERESTING_FEATURE(Embedded)

static bool usesFeatureNoncopyableGenerics(Decl *decl) {
  auto checkInverseMarking = [](auto &marking) -> bool {
    switch (marking.getKind()) {
    case InverseMarking::Kind::None:
    case InverseMarking::Kind::LegacyExplicit: // covered by other checks.
      return false;

    case InverseMarking::Kind::Explicit:
    case InverseMarking::Kind::Inferred:
      return true;
    }
  };

  return hasInverse(decl, InvertibleProtocolKind::Copyable,
                    checkInverseMarking) ||
         hasInverse(decl, InvertibleProtocolKind::Escapable,
                    checkInverseMarking);
}

static bool usesFeatureStructLetDestructuring(Decl *decl) {
  auto sd = dyn_cast<StructDecl>(decl);
  if (!sd)
    return false;

  for (auto member : sd->getStoredProperties()) {
    if (!member->isLet())
      continue;

    auto init = member->getParentPattern();
    if (!init)
      continue;

    if (!init->getSingleVar())
      return true;
  }

  return false;
}

static bool usesFeatureNonescapableTypes(Decl *decl) {
  if (decl->getAttrs().hasAttribute<NonEscapableAttr>() ||
      decl->getAttrs().hasAttribute<UnsafeNonEscapableResultAttr>()) {
    return true;
  }
  auto *fd = dyn_cast<FuncDecl>(decl);
  if (fd && fd->getAttrs().getAttribute(DeclAttrKind::ResultDependsOnSelf)) {
    return true;
  }
  auto *pd = dyn_cast<ParamDecl>(decl);
  if (pd && pd->hasResultDependsOn()) {
    return true;
  }
  return false;
}

static bool usesFeatureStaticExclusiveOnly(Decl *decl) {
  return usesTypeDeclMatching(decl, [](Decl *typeDecl) {
    return typeDecl->getAttrs().hasAttribute<StaticExclusiveOnlyAttr>();
  });
}

static bool usesFeatureExtractConstantsFromMembers(Decl *decl) {
  return decl->getAttrs().hasAttribute<ExtractConstantsFromMembersAttr>();
}

UNINTERESTING_FEATURE(BitwiseCopyable)
UNINTERESTING_FEATURE(FixedArrays)
UNINTERESTING_FEATURE(GroupActorErrors)

static bool usesFeatureTransferringArgsAndResults(Decl *decl) {
  if (auto *pd = dyn_cast<ParamDecl>(decl))
    if (pd->isTransferring())
      return true;

  if (auto *fDecl = dyn_cast<FuncDecl>(decl)) {
    auto fnTy = fDecl->getInterfaceType();
    bool hasTransferring = false;
    if (auto *ft = llvm::dyn_cast_if_present<FunctionType>(fnTy)) {
      if (ft->hasExtInfo())
        hasTransferring = ft->hasTransferringResult();
    } else if (auto *ft =
                   llvm::dyn_cast_if_present<GenericFunctionType>(fnTy)) {
      if (ft->hasExtInfo())
        hasTransferring = ft->hasTransferringResult();
    }
    if (hasTransferring)
      return true;
  }

  return false;
}

static bool usesFeatureDynamicActorIsolation(Decl *decl) {
  auto usesPreconcurrencyConformance = [&](const InheritedTypes &inherited) {
    return llvm::any_of(
        inherited.getEntries(),
        [](const InheritedEntry &entry) { return entry.isPreconcurrency(); });
  };

  if (auto *T = dyn_cast<TypeDecl>(decl))
    return usesPreconcurrencyConformance(T->getInherited());

  if (auto *E = dyn_cast<ExtensionDecl>(decl)) {
    // If type has `@preconcurrency` conformance(s) all of its
    // extensions have to be guarded by the flag too.
    if (auto *T = dyn_cast<TypeDecl>(E->getExtendedNominal())) {
      if (usesPreconcurrencyConformance(T->getInherited()))
        return true;
    }

    return usesPreconcurrencyConformance(E->getInherited());
  }

  return false;
}

UNINTERESTING_FEATURE(BorrowingSwitch)

static bool usesFeatureIsolatedAny(Decl *decl) {
  return usesTypeMatching(decl, [](Type type) {
    if (auto fnType = type->getAs<AnyFunctionType>()) {
      return fnType->getIsolation().isErased();
    }
    return false;
  });
}

// ----------------------------------------------------------------------------
// MARK: - FeatureSet
// ----------------------------------------------------------------------------

void FeatureSet::collectRequiredFeature(Feature feature,
                                        InsertOrRemove operation) {
  required.insertOrRemove(feature, operation == Insert);
}

void FeatureSet::collectSuppressibleFeature(Feature feature,
                                            InsertOrRemove operation) {
  suppressible.insertOrRemove(numFeatures() - size_t(feature),
                              operation == Insert);
}

static bool shouldSuppressFeature(StringRef featureName, Decl *decl) {
  auto attr = decl->getAttrs().getAttribute<AllowFeatureSuppressionAttr>();
  if (!attr) return false;

  for (auto suppressedFeature : attr->getSuppressedFeatures()) {
    if (suppressedFeature.is(featureName))
      return true;
  }

  return false;
}

/// Go through all the features used by the given declaration and
/// either add or remove them to this set.
void FeatureSet::collectFeaturesUsed(Decl *decl, InsertOrRemove operation) {
  // Go through each of the features, checking whether the
  // declaration uses that feature.
#define LANGUAGE_FEATURE(FeatureName, SENumber, Description)                   \
  if (usesFeature##FeatureName(decl))                                          \
    collectRequiredFeature(Feature::FeatureName, operation);
#define SUPPRESSIBLE_LANGUAGE_FEATURE(FeatureName, SENumber, Description)      \
  if (usesFeature##FeatureName(decl))                                          \
    collectSuppressibleFeature(Feature::FeatureName, operation);
#define CONDITIONALLY_SUPPRESSIBLE_LANGUAGE_FEATURE(FeatureName, SENumber, Description)      \
  if (usesFeature##FeatureName(decl)) {                                        \
    if (shouldSuppressFeature(#FeatureName, decl))                             \
      collectSuppressibleFeature(Feature::FeatureName, operation);             \
    else                                                                       \
      collectRequiredFeature(Feature::FeatureName, operation);                 \
  }
#include "swift/Basic/Features.def"
}

FeatureSet swift::getUniqueFeaturesUsed(Decl *decl) {
  // Add all the features used by this declaration.
  FeatureSet features;
  features.collectFeaturesUsed(decl, FeatureSet::Insert);

  // Remove all the features used by all enclosing declarations.
  Decl *enclosingDecl = decl;
  while (!features.empty()) {
    // Find the next outermost enclosing declaration.
    if (auto accessor = dyn_cast<AccessorDecl>(enclosingDecl))
      enclosingDecl = accessor->getStorage();
    else
      enclosingDecl = enclosingDecl->getDeclContext()->getAsDecl();
    if (!enclosingDecl)
      break;

    features.collectFeaturesUsed(enclosingDecl, FeatureSet::Remove);
  }

  return features;
}
