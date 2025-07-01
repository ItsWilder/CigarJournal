//
//  CigarRowView.swift
//  Cigar Journal
//
//  Created by David Wilder on 7/1/25.
//

import SwiftUI


/// A view to show a single cigar in a List view
struct CigarRowView: View {
    let cigar: CigarTemplate
    
    var body: some View {
        NavigationLink(value: cigar) {
            HStack {
                CigarRowImage(photo: cigar.photo)
                    .padding(.trailing, 1)
                
                VStack(alignment: .leading) {
                    Text(cigar.name)
                        .font(.headline)
                        .padding(.bottom, 2)
                    Text(cigar.date.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(cigar.price == "~" ? "~" : "$\(cigar.price)")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 4)
                    StarRating(rating: cigar.rating)
                        .font(.caption)
                }
            }
        }
    }
}

private struct CigarRowImage: View {
    var photo: Data?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.brown))
                .frame(width: 60, height: 60)

            if let imageData = photo,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color("AccentDarkColor"))
            }
        }
    }
}


#Preview {
    CigarRowView(cigar: SampleData.cigar)
}
