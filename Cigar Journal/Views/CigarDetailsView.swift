// CigarDetails


import SwiftUI
import SwiftData

struct CigarDetails: View {
    
    let cigars: [CigarTemplate]
    @State var selectedIndex: Int
    @State var isShowingEditSheet = false
    @State private var isShowingFullImage = false
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(cigars.indices, id: \.self) { index in
                ScrollView {
                    let cigar = cigars[index]
                    VStack(alignment: .leading) {
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
                            ZStack {
                                Rectangle()
                                    .fill(Color(.brown))
                                    .frame(height: 300)
                                Image(systemName: "photo.on.rectangle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50)
                                    .foregroundColor(Color("AccentDarkColor"))
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(cigar.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                            Text(cigar.date, style: .date)
                                .font(.subheadline)
                                .opacity(0.5)
                            Text("\(cigar.type)  /  \(cigar.length) x \(cigar.gauge)  /  \(cigar.strength)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.top, 8)
                            Text("\(cigar.location), $\(cigar.price)")
                                .fontWeight(.medium)
                            StarRating(rating: cigar.rating)
                                .padding(.top, 8)
                            Text("Notes:")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .font(.callout)
                                .padding(.top, 16)
                            Text(cigar.notes)
                        }
                        .padding()
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .toolbar {
            Button("Edit") {
                isShowingEditSheet = true
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
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
    }
}


#Preview {
    CigarDetails(cigars: SampleData.cigars, selectedIndex: 0)
}
