import SwiftUI

enum AppTheme {
    enum Colors {
        static let primary = Color.green
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.systemGray6)
        static let textPrimary = Color.black
        static let textSecondary = Color.gray
        static let discountText = Color.blue
        static let walletIcon = Color.yellow
        static let headerGradientStart = Color(red: 0.7, green: 0.85, blue: 1.0)
        static let headerGradientMiddle = Color(red: 0.85, green: 0.92, blue: 1.0)
        static let headerGradientEnd = Color.white
    }
    
    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
        
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 6
    }
}
