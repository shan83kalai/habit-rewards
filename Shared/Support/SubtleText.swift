import SwiftUI

extension ShapeStyle where Self == Color {
    /// Like `.secondary`, but strong enough for small text to pass the accessibility contrast
    /// audit in light and dark mode (the system grey falls just short at caption sizes).
    static var subtle: Color { .primary.opacity(0.7) }
}
