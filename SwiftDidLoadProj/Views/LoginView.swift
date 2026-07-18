import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    var viewModel: AppViewModel
    
    @State private var isSignUp = false
    @State private var password = ""
    @State private var email = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Illustration / Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: isSignUp ? "person.badge.plus" : "lock.shadow")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(.top, 20)
                        
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(isSignUp ? "Sign up to create and share shopping lists" : "Sign in to synchronize your shopping spaces")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Error Message Banner
                    if let errorMessage = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .lineLimit(3)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                    
                    // Input Form
                    VStack(spacing: 16) {
                        // Email Address Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email Address")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            TextField("Enter email address", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                        }
                        .padding(.all, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Password Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            SecureField("Enter password", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                        }
                        .padding(.all, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await performAuthentication()
                            }
                        }) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Register" : "Sign In")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(canSubmit ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.6))
                            .cornerRadius(14)
                        }
                        .disabled(!canSubmit || isLoading)
                        
                        // Toggle Auth Mode
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Text(isSignUp ? "Sign In" : "Register")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isUserLoggedIn {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        return !email.isEmpty && !password.isEmpty
    }
    
    private func performAuthentication() async {
        guard canSubmit else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                let session = try await SupabaseService.shared.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await viewModel.loginUser(session: session)
            } else {
                let session = try await SupabaseService.shared.logIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                await viewModel.loginUser(session: session)
            }
            
            isLoading = false
            dismiss()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
