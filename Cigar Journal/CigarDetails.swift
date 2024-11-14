// CigarDetails


import SwiftUI
import SwiftData

struct CigarDetails: View {
    
    let cigar: CigarTemplate
    @State var isShowingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) { // Aligns the text block to the left of the screen
                ZStack {
                    Rectangle()
                        .fill(Color(.brown))
                    
                    if let photo = cigar.photo,
                       let uiImage = UIImage(data: photo) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .clipped()
                            .contentShape(Rectangle())
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 300)
                            .foregroundColor(Color("AccentDarkColor"))
                    }
                }
                .padding(.top, 8.0)
                .clipShape(Rectangle())
                
                VStack(alignment: .leading) { // Alignment is for all the text
                    Text(cigar.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Text(cigar.date, style: .date)
                        .font(.subheadline)
                        .opacity(0.5)
                    Spacer()
                    Text("\(cigar.type)  /  \(cigar.length) x \(cigar.gauge)  /  \(cigar.strength)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    Spacer()
                    Text("\(cigar.location), $\(cigar.price)")
                        .fontWeight(.medium)
                    Spacer()
                    StarRating(rating: cigar.rating)
                        .padding(.top, 8)
                    Text("Notes:")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .font(.callout)
                        .padding(.top, 16)
                    Spacer()
                    Text(cigar.notes)
                }
                .padding()
            }
            .toolbar {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
            .sheet(isPresented: $isShowingEditSheet) {
                AddCigar(editCigar: cigar)
            }
        }
    }
}


#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CigarTemplate.self, configurations: config)
        let example = CigarTemplate(name: "A. Flores 1975 Gran Reserva Maduro", shape: "Robusto", length: "7", gauge: "40", location: "Cigar Club", price: "100", strength: "Medium", rating: 4, notes: "Surprisingly polished despite its rough appearance. The smoke is warm and nutty, with subtle layers of honeyed tea, orange peel, and just a touch of caramel sweetness. Definitely more refined than I expected—smooth and easygoing. Would be a great choice for a relaxing evening.", date: Date())
        
        return CigarDetails(cigar: example)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
