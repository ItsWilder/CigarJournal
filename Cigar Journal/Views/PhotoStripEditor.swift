// PhotoStripEditor
// A row of photo thumbnails with remove buttons and an Add button (camera, or several
// from the library at once). Used for a cigar's extra photos and a smoke's photos.

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// A photo in a form: one already saved (`record`, or the cigar's original photo),
/// or a new one not saved yet.
nonisolated struct PendingPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let record: CigarPhoto?
    /// The original photo stored on the cigar itself.
    let isOriginal: Bool

    init(data: Data, record: CigarPhoto? = nil, isOriginal: Bool = false) {
        self.data = data
        self.record = record
        self.isOriginal = isOriginal
    }
}

struct PhotoStripEditor: View {
    @Binding var photos: [PendingPhoto]
    /// When set, tapping a photo makes it the key photo, which is labeled "Key".
    var keyPhotoID: Binding<UUID?>? = nil

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingLibrary = false
    @State private var showingCamera = false
    @State private var cameraPhoto: Data?

    private let tileSize: CGFloat = 72

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    let isKey = keyPhotoID?.wrappedValue == photo.id
                    CigarPhotoView(photo: photo.data, maxPointSize: tileSize)
                        .frame(width: tileSize, height: tileSize)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if isKey {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.accent, lineWidth: 3)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if isKey {
                                Text("Key")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.accent, in: .capsule)
                                    .padding(.bottom, 4)
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            keyPhotoID?.wrappedValue = photo.id
                        }
                        .accessibilityAddTraits(keyPhotoID == nil ? [] : .isButton)
                        .accessibilityLabel(isKey ? "Key photo" : "Photo")
                        .accessibilityHint(keyPhotoID == nil || isKey ? "" : "Makes this the key photo")
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
        // Keep a key photo chosen whenever there are photos (e.g. after removing the key).
        .onChange(of: photos.map(\.id)) { _, ids in
            guard let keyPhotoID else { return }
            if keyPhotoID.wrappedValue.map({ !ids.contains($0) }) ?? true {
                keyPhotoID.wrappedValue = ids.first
            }
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
    /// The cigar's original photo isn't a record, so it's left to the caller.
    /// - Parameters:
    ///   - original: the saved photo records the form started with.
    ///   - session / firstSmoke: which smoke new photos belong to, if any.
    /// - Returns: the new records, keyed by the form photo they came from.
    @discardableResult
    func savePhotos(
        _ photos: [PendingPhoto],
        original: [CigarPhoto],
        session: SmokeSession? = nil,
        firstSmoke: Bool = false,
        in context: ModelContext
    ) -> [UUID: CigarPhoto] {
        let kept = Set(photos.compactMap { $0.record?.persistentModelID })
        for record in original where !kept.contains(record.persistentModelID) {
            context.delete(record)
        }
        let new = photos.filter { $0.record == nil && !$0.isOriginal }
        let added = addPhotos(new.map(\.data), session: session, firstSmoke: firstSmoke, in: context)
        return Dictionary(uniqueKeysWithValues: zip(new.map(\.id), added))
    }
}
