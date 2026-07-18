import SwiftUI

struct KeyInformationSheet: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    
    // UI State for accordions
    @State private var showKeyInfo = true
    @State private var showNutritionalInfo = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if !item.image.isEmpty {
                    Image(item.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } else if let url = item.imageURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                }
                
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray3))
                        .font(.title2)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Key Information Disclosure
                    DisclosureGroup(isExpanded: $showKeyInfo) {
                        VStack(spacing: 16) {
                            infoRow(title: "Flavour", value: "Masala")
                            infoRow(title: "How to Use", value: "Usage instructions: Prepare noodles bowl in just 2 minutes - boil 270ml water and add both the tastemakers along with the noodle cake broken into 4 pieces. Cook for 2 minutes in an open pan, while you stir occasionally. Do not drain the remaining water. Serve and enjoy hot.")
                            infoRow(title: "Noodles Type", value: "Instant Noodles")
                            infoRow(title: "Preparation Time", value: "2 minutes")
                        }
                        .padding(.top, 16)
                    } label: {
                        Text("Key Information")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Nutritional Information Disclosure
                    DisclosureGroup(isExpanded: $showNutritionalInfo) {
                        VStack(spacing: 16) {
                            infoRow(title: "Protein Per 100 g", value: "7 g")
                            infoRow(title: "Total Carbohydrates Per 100 g", value: "55.3 g")
                            infoRow(title: "Total Sugar Per 100 g", value: "1.2 g")
                        }
                        .padding(.top, 16)
                    } label: {
                        Text("Nutritional Information")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .padding()
                }
            }
            
            // Bottom Sticky Bar (same as detail view)
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.weight)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("₹\(item.price)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Inclusive of all taxes")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Usually this might also dismiss or just add
                        // We will just dismiss for the sheet logic, or trigger add
                        dismiss()
                    }) {
                        Text("Add to cart")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.vertical, AppTheme.Spacing.small)
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
