// CigarDetails


import SwiftUI
import SwiftData

struct CigarDetails: View {
    
    let cigars: [CigarTemplate]
    @State var selectedIndex: Int
    @State var isShowingEditSheet = false
    @State private var isShowingFullImage = false
    private let maxVisibleDots = 5
    
    var body: some View {
        VStack {
            TabView(selection: $selectedIndex) {
                ForEach(cigars.indices, id: \.self) { index in
                    ScrollView {
                        let cigar = cigars[index]
                        VStack(alignment: .leading) {
                            ZStack {
                                Rectangle().fill(Color(.brown))
                                if let photo = cigar.photo,
                                   let uiImage = UIImage(data: photo) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 300)
                                        .clipped()
                                        .onTapGesture {
                                            isShowingFullImage = true
                                        }
                                } else {
                                    Image(systemName: "photo.on.rectangle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 300)
                                        .foregroundColor(Color("AccentDarkColor"))
                                }
                            }
                            .padding(.top, 8)
                            .clipShape(Rectangle())
                            
                            VStack(alignment: .leading) {
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
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom) {
            if cigars.count > 1 {
                HStack(spacing: 8) {
                    if let firstVisibleDotIndex, firstVisibleDotIndex > 0 {
                        Circle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }

                    ForEach(visibleDotIndices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.primary : Color.secondary.opacity(0.35))
                            .frame(width: index == selectedIndex ? 9 : 7, height: index == selectedIndex ? 9 : 7)
                    }

                    if let lastVisibleDotIndex, lastVisibleDotIndex < cigars.count - 1 {
                        Circle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 8)
            }
        }
        .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        isShowingEditSheet = true
                    }
                }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            AddCigar(editCigar: cigars[selectedIndex])
        }
        .fullScreenCover(isPresented: $isShowingFullImage) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                if let photo = cigars[selectedIndex].photo,
                   let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                }
                Button {
                    isShowingFullImage = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
    }

    private var visibleDotIndices: [Int] {
        guard cigars.count > maxVisibleDots else { return Array(cigars.indices) }

        let halfWindow = maxVisibleDots / 2
        let start = min(max(0, selectedIndex - halfWindow), cigars.count - maxVisibleDots)
        let end = start + maxVisibleDots - 1
        return Array(start...end)
    }

    private var firstVisibleDotIndex: Int? {
        visibleDotIndices.first
    }

    private var lastVisibleDotIndex: Int? {
        visibleDotIndices.last
    }
}


#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CigarTemplate.self, configurations: config)
        let example1 = CigarTemplate(name: "A. Flores 1975 Gran Reserva Maduro", type: "Robusto", length: "7", gauge: "40", location: "Cigar Club", price: "100", strength: "Medium", rating: 4, notes: "Surprisingly polished despite its rough appearance. The smoke is warm and nutty, with subtle layers of honeyed tea, orange peel, and just a touch of caramel sweetness. Definitely more refined than I expected—smooth and easygoing. Would be a great choice for a relaxing evening.", date: Date())
        let example2 = CigarTemplate(name: "Montecristo No. 2", type: "Torpedo", length: "6 1/8", gauge: "52", location: "Local Shop", price: "15", strength: "Full", rating: 5, notes: "Classic Cuban flavor with rich earth tones and a spicy finish.", date: Date())
        
        return CigarDetails(cigars: [example1, example2], selectedIndex: 0)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
