// PhotoStripEditor
// A row of photo thumbnails with remove buttons and an Add button (camera, or several
// from the library at once). Used for a cigar's extra photos and a smoke's photos.

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// A photo in a form: either one already saved (`record`) or a new one not saved yet.
nonisolated struct PendingPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let record: CigarPhoto?

    init(data: Data, record: CigarPhoto? = nil) {
        self.data = data
        self.record = record
    }
}

struct PhotoStripEditor: View {
    @Binding var photos: [PendingPhoto]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingLibrary = false
    @State private var showingCamera = false
    @State private var cameraPhoto: Data?

    private let tileSize: CGFloat = 72

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    CigarPhotoView(photo: photo.data, maxPointSize: tileSize)
                        .frame(width: tileSize, height: tileSize)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button("Remove Photo", systemImage: "xmark.circle.fill") {
                                withAnimation {
                                    photos.removeAll { $0.id == photo.id }
                                }
                            }
                            .labelStyle(.iconOnly)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .padding(4)
                        }
                }

                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Camera", systemImage: "camera") {
                            showingCamera = true
                        }
                    }
                    Button("Photo Library", systemImage: "photo.on.rectangle") {
                        showingLibrary = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(width: tileSize, height: tileSize)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel("Add Photos")
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .photosPicker(isPresented: $showingLibrary, selection: $pickerItems, maxSelectionCount: 10, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker(selectedPhoto: $cameraPhoto)
                .ignoresSafeArea()
        }
        .onChange(of: cameraPhoto) { _, data in
            guard let data else { return }
            photos.append(PendingPhoto(data: data))
            cameraPhoto = nil
        }
        .task(id: pickerItems) {
            guard !pickerItems.isEmpty else { return }
            let items = pickerItems
            pickerItems = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photos.append(PendingPhoto(data: await PhotoCompression.compressedData(from: data)))
                }
            }
        }
    }
}

extension CigarTemplate {
    /// Saves a form's photo list: deletes photos that were removed and adds new ones.
    /// - Parameters:
    ///   - original: the saved photos the form started with.
    ///   - session / firstSmoke: which smoke new photos belong to, if any.
    func savePhotos(
        _ photos: [PendingPhoto],
        original: [CigarPhoto],
        session: SmokeSession? = nil,
        firstSmoke: Bool = false,
        in context: ModelContext
    ) {
        let kept = Set(photos.compactMap { $0.record?.persistentModelID })
        for record in original where !kept.contains(record.persistentModelID) {
            context.delete(record)
        }
        addPhotos(photos.filter { $0.record == nil }.map(\.data), session: session, firstSmoke: firstSmoke, in: context)
    }
}
