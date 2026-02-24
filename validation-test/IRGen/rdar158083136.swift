// RUN: %target-swift-frontend %s -emit-ir

func f<let i: Int, T>(
    _: consuming InlineArray<i, (String, T)>
) {
}
