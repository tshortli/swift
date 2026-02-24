// RUN: %target-swift-frontend -typecheck -verify -I %S/Inputs -I %swift_src_root/lib/ClangImporter/SwiftBridging %s -cxx-interoperability-mode=default

import VirtMethodWitMoveOnly

func f(_ x: CxxForeignRef, _ y: consuming MoveOnly) {
    x.takesMoveOnly(y)
}
