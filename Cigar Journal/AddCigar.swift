// AddCigar
// Photos only - No Camera


import SwiftUI
import PhotosUI

struct AddCigar: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhoto: Data?
    @State private var showPickerModal = false
    
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
    
    init(editCigar: CigarTemplate? = nil) {
        self.editCigar = editCigar
        
        // Initialize state variables with either existing values or defaults
        _name = State(initialValue: editCigar?.name ?? "")
        _type = State(initialValue: editCigar?.type ?? "Robusto")
        _length = State(initialValue: editCigar?.length ?? "6")
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
        NavigationStack{
            ScrollView {
                
                CigarPhotoPicker(selectedItem: $selectedItem, selectedPhoto: $selectedPhoto)
                    .padding(.top, 8.0)
                
                CustomTextField(text: $name, placeholder: "Enter name", label: "Name", systemImage: "plus.circle")
                    .padding(.top, 12.0)
                
                HStack (spacing: -14) {
                    
                    CustomPickerField(selection: $type, label: "Type", options: ["Rothschild", "Robusto", "Petite Corona", "Corona", "Toro", "Lonsdale", "Churchill", "Lancero", "Double Corona", "Presidente", "Grande"])
                    
                    VStack(alignment: .leading) {
                        Text("Size")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showPickerModal.toggle()
                        }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary)
                                .opacity(0.05)
                                .frame(height: 60)
                                .overlay(
                                    HStack {
                                        Text("\(length) x \(gauge)")
                                            .padding(.leading)
                                        Spacer()
                                    }
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    CustomPickerField(selection: $strength, label: "Strength", options: ["Mild", "Medium", "Strong"])
                }
                .padding(.top, 2.0)
                
                
                HStack (spacing: -14) {
                    CustomTextField(text: $location, placeholder: "Enter location", label: "Purchased", systemImage: "location.circle")
                        .padding(.top, 2.0)
                    CustomTextField(text: $price, placeholder: "Enter price", label: "Price", systemImage: "dollarsign.circle")
                        .keyboardType(.decimalPad)
                }
                .padding(.top, 2.0)
                
                
                
                CustomTextField(text: $notes, placeholder: "Enter notes", label: "Notes", systemImage: "note.text")
                    .padding(.top, 2.0)
                
                VStack(alignment: .leading) {
                    Text("Rating")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(Color.gray)
                        .padding(18.0) //had to put this in to align the text
                        .frame(height: 12.0) //had to put this in to align the text
                    
                    Picker("Rating", selection: $rating) {
                        ForEach (1...5, id: \.self) { number in
                            Text("\(number)")
                                .tag(number)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)
                    .padding(.horizontal)
                    .cornerRadius(8)
                }
                
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle(editCigar == nil ? "Add Cigar" : "Edit Cigar")
            .overlay {
                if showPickerModal {
                    PickerModalOverlay(showPickerModal: $showPickerModal, length: $length, gauge: $gauge)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let cigarToEdit = editCigar {
                            // Update existing cigar
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
                            cigarToEdit.photo = selectedPhoto
                        } else {
                            // Create new cigar
                            let newCigar = CigarTemplate(
                                name: name,
                                shape: type,
                                length: length,
                                gauge: gauge,
                                location: location.isEmpty ? "~" : location,
                                price: price.isEmpty ? "0.00" : price,
                                strength: strength,
                                rating: rating,
                                notes: notes,
                                date: date,
                                photo: selectedPhoto
                            )
                            modelContext.insert(newCigar)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// Photo Picker
struct CigarPhotoPicker: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedPhoto: Data?
    
    var body: some View {
        PhotosPicker(selection: $selectedItem,
                     matching: .images,
                     photoLibrary: .shared()) {
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
                     .onChange(of: selectedItem) {
                         Task {
                             if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                                 selectedPhoto = data
                             }
                         }
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


struct CustomTextField: View {
    @Binding var text: String
    var placeholder: String
    var label: String
    var systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(Color.gray)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary)
                    .opacity(0.05)
                
                HStack {
                    
                    if text.isEmpty {
                        Image(systemName: systemImage)
                            .font(.footnote)
                            .opacity(0.2)
                            .frame(width: 24)
                            .padding(.leading, 12)
                    }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.footnote)
                            .opacity(0.2)
                    }
                }
                
                TextField("", text: $text, axis: .vertical)
                    .padding(14)
            }
        }
        .padding(.horizontal)
    }
}

struct CustomPickerField: View {
    @Binding var selection: String
    var label: String
    var options: [String]
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Text(label)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary)
                    .opacity(0.05)
                    .frame(height: 60)
                
                Picker(label, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option)
                            .tag(option)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// Components and logic for PickerModalOverlay below
struct LengthGaugePicker: View {
    @Binding var length: String
    @Binding var gauge: String
    @Binding var showPicker: Bool
    @Binding var animationAmount: Double
    
    var body: some View {
        VStack {
            Text("Length  x  Gauge")
                .font(.headline)
            
            HStack {
                Picker("Length", selection: $length) {
                    ForEach(Array(3...9), id: \.self) { length in
                        Text("\(length)").tag("\(length)")
                    }
                }
                .pickerStyle(.wheel)
                
                Text("x")
                
                Picker("Gauge", selection: $gauge) {
                    ForEach(Array(26...64), id: \.self) { gauge in
                        Text("\(gauge)").tag("\(gauge)")
                    }
                }
                .pickerStyle(.wheel)
                
            }
            Button("Done") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    animationAmount = 0.5
                    showPicker.toggle()
                }
            }
        }
        .padding()
    }
}

// Size (Length x Guage) modal overlay design
private struct PickerModalOverlay: View {
    @Binding var showPickerModal: Bool
    @Binding var length: String
    @Binding var gauge: String
    @State private var animationAmount = 0.5
    
    var body: some View {
        LengthGaugePicker(length: $length, gauge: $gauge, showPicker: $showPickerModal, animationAmount: $animationAmount)
            .background(.ultraThinMaterial)
            .frame(width: 300, height: 250)
            .cornerRadius(24)
            .shadow(radius: 20)
            .scaleEffect(animationAmount)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    animationAmount = 1.0
                }
            }
    }
}

#Preview {
    AddCigar()
}
