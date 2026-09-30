// AddCigar
// Supports Camera and Photo Library


import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddCigar: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhoto: Data?
    
    var editCigar: CigarTemplate?
    
    @State private var name = ""
    @State private var type = ""
    @State private var length = ""
    @State private var gauge = ""
    @State private var location = ""
    @State private var price = ""
    @State private var strength = ""
    @State private var rating = 3
    @State private var notes = ""
    @State private var date = Date()
    @State private var showingLengthPicker = false
    @State private var showingGaugePicker = false
    
    private let typeOptions = ["Rothschild", "Robusto", "Petite Corona", "Corona", "Toro", "Lonsdale", "Churchill", "Lancero", "Double Corona", "Presidente", "Grande"]
    private let strengthOptions = ["Mild", "Medium", "Strong"]
    private let lengthOptions = stride(from: 3.0, through: 9.0, by: 0.25).map { String(format: "%.2f", $0) }
    private let gaugeOptions = Array(26...64).map(String.init)
    
    init(editCigar: CigarTemplate? = nil) {
        self.editCigar = editCigar
        
        // Initialize state variables with either existing values or defaults
        _name = State(initialValue: editCigar?.name ?? "")
        _type = State(initialValue: editCigar?.type ?? "Robusto")
        _length = State(initialValue: Self.normalizedLength(editCigar?.length ?? "6"))
        _gauge = State(initialValue: editCigar?.gauge ?? "50")
        _location = State(initialValue: editCigar?.location ?? "")
        _price = State(initialValue: editCigar?.price ?? "")
        _strength = State(initialValue: editCigar?.strength ?? "Medium")
        _rating = State(initialValue: editCigar?.rating ?? 3)
        _notes = State(initialValue: editCigar?.notes ?? "")
        _date = State(initialValue: editCigar?.date ?? Date())
        _selectedPhoto = State(initialValue: editCigar?.photo)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CigarPhotoPicker(selectedItem: $selectedItem, selectedPhoto: $selectedPhoto)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("Details") {
                    IconTextFieldRow(
                        systemImage: "plus.circle",
                        title: "Name",
                        text: $name,
                        placeholder: "Name"
                    )

                    IconTextFieldRow(
                        systemImage: "storefront",
                        title: "Store",
                        text: $location,
                        placeholder: "Store"
                    )

                    IconTextFieldRow(
                        systemImage: "dollarsign.circle",
                        title: "Price",
                        text: $price,
                        placeholder: "Price",
                        keyboardType: .decimalPad
                    )

                    IconDateRow(systemImage: "calendar", title: "Date", date: $date)

                    IconRatingRow(systemImage: "star", title: "Rating", rating: $rating)
                }

                Section("Size") {
                    DisclosureGroup(
                        isExpanded: $showingLengthPicker,
                        content: {
                            Picker("Length", selection: $length) {
                                ForEach(lengthOptions, id: \.self) { option in
                                    Text("\(option)\"")
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxHeight: 150)
                        },
                        label: {
                            HStack {
                                Label("Length", systemImage: "arrow.left.and.right")
                                Spacer()
                                Text("\(length)\"")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    .onChange(of: showingLengthPicker) {
                        if showingLengthPicker {
                            showingGaugePicker = false
                        }
                    }

                    DisclosureGroup(
                        isExpanded: $showingGaugePicker,
                        content: {
                            Picker("Gauge", selection: $gauge) {
                                ForEach(gaugeOptions, id: \.self) { option in
                                    Text(option)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxHeight: 150)
                        },
                        label: {
                            HStack {
                                Label("Gauge", systemImage: "circle.dotted")
                                Spacer()
                                Text(gauge)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    .onChange(of: showingGaugePicker) {
                        if showingGaugePicker {
                            showingLengthPicker = false
                        }
                    }
                }

                Section("Features") {
                    IconMenuRow(
                        systemImage: "chart.bar.xaxis",
                        title: "Strength",
                        value: strength,
                        options: strengthOptions
                    ) { option in
                        strength = option
                    }

                    IconMenuRow(
                        systemImage: "shippingbox",
                        title: "Type",
                        value: type,
                        options: typeOptions
                    ) { option in
                        type = option
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(editCigar == nil ? "Add Cigar" : "Edit Cigar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCigar()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private static func normalizedLength(_ raw: String) -> String {
        if raw.contains(".") {
            if let value = Double(raw) {
                return String(format: "%.2f", value)
            }
            return raw
        }
        if let value = Double(raw) {
            return String(format: "%.2f", value)
        }
        return "6.00"
    }

    private func saveCigar() {
        let compressedPhoto = PhotoCompression.compressedData(from: selectedPhoto)

        if let cigarToEdit = editCigar {
            cigarToEdit.name = name
            cigarToEdit.type = type
            cigarToEdit.length = length
            cigarToEdit.gauge = gauge
            cigarToEdit.location = location.isEmpty ? "~" : location
            cigarToEdit.price = price.isEmpty ? "0.00" : price
            cigarToEdit.strength = strength
            cigarToEdit.rating = rating
            cigarToEdit.notes = notes
            cigarToEdit.date = date
            cigarToEdit.photo = compressedPhoto
        } else {
            let newCigar = CigarTemplate(
                name: name,
                type: type,
                length: length,
                gauge: gauge,
                location: location.isEmpty ? "~" : location,
                price: price.isEmpty ? "0.00" : price,
                strength: strength,
                rating: rating,
                notes: notes,
                date: date,
                photo: compressedPhoto
            )
            modelContext.insert(newCigar)
        }
    }
}

// Photo Picker
struct CigarPhotoPicker: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedPhoto: Data?
    @State private var showingSourceDialog = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var showingCameraUnavailableAlert = false
    
    var body: some View {
        Button {
            showingSourceDialog = true
        } label: {
            ZStack {
                Rectangle()
                    .fill(Color(.brown))
                    .frame(height: 300)
                
                if let photo = selectedPhoto,
                   let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                        .contentShape(Rectangle())
                } else {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 30))
                            .foregroundColor(Color("AccentDarkColor"))
                        Text("Tap to add photo")
                            .foregroundColor(Color("AccentDarkColor"))
                            .font(.caption)
                    }
                }
            }
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Add Photo", isPresented: $showingSourceDialog, titleVisibility: .visible) {
            Button("Camera") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showingCamera = true
                } else {
                    showingCameraUnavailableAlert = true
                }
            }
            Button("Photo Library") {
                showingPhotoLibrary = true
            }
            if selectedPhoto != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedPhoto = nil
                    selectedItem = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showingPhotoLibrary,
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(selectedPhoto: $selectedPhoto)
                .ignoresSafeArea()
        }
        .alert("Camera Unavailable", isPresented: $showingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not support camera capture.")
        }
        .onChange(of: selectedItem) {
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                    selectedPhoto = PhotoCompression.compressedData(from: data)
                }
            }
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedPhoto: Data?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPhoto: $selectedPhoto, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding var selectedPhoto: Data?
        let dismiss: DismissAction

        init(selectedPhoto: Binding<Data?>, dismiss: DismissAction) {
            _selectedPhoto = selectedPhoto
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.9) {
                selectedPhoto = PhotoCompression.compressedData(from: imageData)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

struct PhotoView: View {
    let imageData: Data?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.brown))
                .frame(height: 200)
            
            if let imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 30))
                        .foregroundColor(Color("AccentDarkColor"))
                    Text("Tap to add photo")
                        .foregroundColor(Color("AccentDarkColor"))
                        .font(.caption)
                }
            }
        }
        .padding(.bottom)
    }
}


private struct IconTextFieldRow: View {
    let systemImage: String
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .foregroundStyle(.secondary)
                .accessibilityLabel(title)
        }
    }
}

private struct IconDateRow: View {
    let systemImage: String
    let title: String
    @Binding var date: Date
    
    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            DatePicker(title, selection: $date, displayedComponents: .date)
                .labelsHidden()
        }
    }
}

private struct IconRatingRow: View {
    let systemImage: String
    let title: String
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            StarRating(rating: rating, starSpacing: 4, isInteractive: true) { selected in
                rating = selected
            }
        }
    }
}

private struct IconMenuRow: View {
    let systemImage: String
    let title: String
    let value: String
    let options: [String]
    var onSelect: (String) -> Void
    
    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        onSelect(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AddCigar()
}
