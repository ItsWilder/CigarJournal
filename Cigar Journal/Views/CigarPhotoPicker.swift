// CigarPhotoPicker
// Tap the photo area to take a picture or choose one from the library.

import PhotosUI
import SwiftUI
import UIKit

struct CigarPhotoPicker: View {
    @Binding var selectedPhoto: Data?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingSourceDialog = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false

    var body: some View {
        Button {
            showingSourceDialog = true
        } label: {
            ZStack {
                CigarPhotoView(photo: selectedPhoto, maxPointSize: 500)
                if selectedPhoto == nil {
                    Text("Tap to add photo")
                        .font(.caption)
                        .foregroundStyle(.accentDark)
                        .padding(.top, 50)
                }
            }
            .frame(height: 300)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedPhoto == nil ? "Add photo" : "Change photo")
        .confirmationDialog("Add Photo", isPresented: $showingSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera", systemImage: "camera") {
                    showingCamera = true
                }
            }
            Button("Photo Library", systemImage: "photo.on.rectangle") {
                showingPhotoLibrary = true
            }
            if selectedPhoto != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedPhoto = nil
                    selectedItem = nil
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(selectedPhoto: $selectedPhoto)
                .ignoresSafeArea()
        }
        .task(id: selectedItem) {
            guard let selectedItem, let data = try? await selectedItem.loadTransferable(type: Data.self) else { return }
            selectedPhoto = await PhotoCompression.compressedData(from: data)
        }
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedPhoto: Data?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedPhoto = PhotoCompression.compressedData(from: image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
