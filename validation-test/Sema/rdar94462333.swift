// RUN: %target-typecheck-verify-swift

// REQUIRES: concurrency
// REQUIRES: OS=ios

import UIKit

@MainActor func issue(stackView: UIStackView) {
  stackView.arrangedSubviews.forEach(stackView.removeArrangedSubview)
}