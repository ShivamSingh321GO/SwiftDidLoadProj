import SwiftUI
import PhotosUI
import UIKit

// MARK: - CameraPickerView
// UIViewControllerRepresentable wrapper for UIImagePickerController (real camera)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }
    }
}

// MARK: - HandwritingScanView

struct HandwritingScanView: View {
    @Environment(AppViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    // Shared state — cartId is only used as context; we CREATE a new cart
    let cartId: UUID

    @State private var scanState: ScanState = .pickingPhoto
    @State private var selectedImage: UIImage? = nil
    @State private var scannedItems: [ScannedGroceryItem] = []
    @State private var errorMessage: String? = nil

    // Photo picker
    @State private var photoPickerItem: PhotosPickerItem? = nil

    // Camera sheet
    @State private var showCamera = false
    @State private var showPhotoLibrary = false

    enum ScanState {
        case pickingPhoto
        case scanning
        case reviewing
        case adding
        case done
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch scanState {
                case .pickingPhoto:   pickPhotoView
                case .scanning:       scanningView
                case .reviewing:      reviewView
                case .adding:         addingView
                case .done:           doneView
                }
            }
            .navigationTitle("Scan List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if scanState == .pickingPhoto {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            // Camera sheet
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(selectedImage: $selectedImage, sourceType: .camera) {
                    if selectedImage != nil {
                        scanState = .scanning
                        runScan()
                    }
                }
                .ignoresSafeArea()
            }
            // Photo library picker
            .photosPicker(isPresented: $showPhotoLibrary,
                          selection: $photoPickerItem,
                          matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = img
                            scanState = .scanning
                        }
                        runScan()
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Pick Photo / Camera

    private var pickPhotoView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero Icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 110, height: 110)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.bottom, 24)

            Text("Scan List")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.bottom, 10)

            Text("Write your list on paper, take a photo —\nwe'll find everything on Blinkit for you.")
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

            // Tips
            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "sun.max.fill", text: "Use good lighting for best results")
                tipRow(icon: "list.bullet", text: "Write one item per line")
                tipRow(icon: "hand.raised.fill", text: "Works with both print & handwriting")
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 28)

            Spacer()

            // Camera button (primary)
            Button(action: { showCamera = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("Take a Photo")
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.Colors.primary)
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Photo Library button (secondary)
            Button(action: { showPhotoLibrary = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose from Photos")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 12)
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Step 2: Scanning Animation

    private var scanningView: some View {
        VStack(spacing: 28) {
            Spacer()

            if let img = selectedImage {
                ZStack {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.Colors.primary, lineWidth: 2))

                    // Scan line overlay
                    ScanLineView()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }

            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
                    .scaleEffect(1.4)
                    .padding(.bottom, 4)

                Text("Reading your list...")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Apple Vision is recognizing the handwriting")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Step 3: Review

    private var reviewView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review Items")
                            .font(.headline)
                            .fontWeight(.bold)
                        let matched = scannedItems.filter { $0.isSelected && $0.matchedProduct != nil }.count
                        Text("\(matched) of \(scannedItems.count) items matched")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Button(action: rescan) {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            List {
                ForEach(Array(scannedItems.enumerated()), id: \.element.id) { idx, _ in
                    ScannedItemRow(item: $scannedItems[idx])
                }
            }
            .listStyle(.plain)

            // Bottom CTA
            VStack(spacing: 0) {
                let selectedCount = scannedItems.filter { $0.isSelected && $0.matchedProduct != nil }.count
                Button(action: addItemsToCart) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart.badge.plus")
                        Text("Add \(selectedCount) Item\(selectedCount == 1 ? "" : "s") to Cart")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(selectedCount > 0 ? AppTheme.Colors.primary : Color.gray)
                    .cornerRadius(14)
                }
                .disabled(selectedCount == 0)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
        }
    }

    // MARK: - Step 4: Adding

    private var addingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .tint(AppTheme.Colors.primary)
                .scaleEffect(1.5)
            Text("Creating cart & adding items...")
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Step 5: Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppTheme.Colors.primary)
            }

            VStack(spacing: 8) {
                Text("All Done!")
                    .font(.title2)
                    .fontWeight(.bold)
                let addedCount = scannedItems.filter { $0.isSelected && $0.matchedProduct != nil }.count
                Text("\(addedCount) items added to your cart.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.Colors.primary)
                .cornerRadius(14)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
        }
    }

    // MARK: - Logic

    private func runScan() {
        guard let image = selectedImage else { return }
        Task {
            do {
                let lines = try await HandwritingScannerService.shared.recognizeText(from: image)
                let catalog = AppViewModel.staticProducts
                let matched = await HandwritingScannerService.shared.matchItems(from: lines, catalog: catalog)
                await MainActor.run {
                    scannedItems = matched.isEmpty
                        ? [ScannedGroceryItem(rawText: "No text detected — try better lighting", matchedProduct: nil, isSelected: false)]
                        : matched
                    scanState = .reviewing
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Scan failed. Please try again."
                    scanState = .pickingPhoto
                }
            }
        }
    }

    private func addItemsToCart() {
        scanState = .adding
        let itemsToAdd = scannedItems.filter { $0.isSelected }.compactMap { $0.matchedProduct }
        for item in itemsToAdd {
            viewModel.addItem(item, toCart: cartId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            scanState = .done
        }
    }

    private func rescan() {
        selectedImage = nil
        photoPickerItem = nil
        scannedItems = []
        scanState = .pickingPhoto
    }
}

// MARK: - Scanned Item Row

struct ScannedItemRow: View {
    @Binding var item: ScannedGroceryItem

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if item.matchedProduct != nil { item.isSelected.toggle() }
            }) {
                Image(systemName: item.isSelected && item.matchedProduct != nil
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isSelected && item.matchedProduct != nil
                                     ? AppTheme.Colors.primary : Color(.systemGray4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                // Raw OCR text
                Text(item.rawText)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                if let product = item.matchedProduct {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.primary)
                        Text(product.name)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("₹\(product.price)")
                            .font(.footnote)
                            .foregroundColor(AppTheme.Colors.primary)
                            .fontWeight(.medium)
                    }
                } else {
                    Text("No match found")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if let product = item.matchedProduct {
                Image(product.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 6)
        .opacity(item.matchedProduct == nil ? 0.5 : 1.0)
    }
}

// MARK: - Scan Line Animation

struct ScanLineView: View {
    @State private var offset: CGFloat = -110

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, AppTheme.Colors.primary.opacity(0.8), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        offset = geo.size.height + 10
                    }
                }
        }
    }
}
