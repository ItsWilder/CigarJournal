// FormRows
// Icon + value rows used by the Add/Edit cigar form.

import SwiftUI

struct IconTextFieldRow<Accessory: View>: View {
    let systemImage: String
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .foregroundStyle(.secondary)
            accessory
        }
    }
}

extension IconTextFieldRow where Accessory == EmptyView {
    init(systemImage: String, title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.init(systemImage: systemImage, title: title, text: text, keyboardType: keyboardType) { EmptyView() }
    }
}

struct IconDateRow: View {
    let systemImage: String
    let title: String
    @Binding var date: Date

    var body: some View {
        DatePicker(selection: $date, displayedComponents: .date) {
            Label(title, systemImage: systemImage)
        }
    }
}

struct IconRatingRow: View {
    let systemImage: String
    let title: String
    @Binding var rating: Int

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            StarRating(rating: rating, starSpacing: 4) { rating = $0 }
        }
    }
}

struct IconPickerRow: View {
    let systemImage: String
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Picker(selection: $selection) {
            // Keep values from older entries selectable even if they're not in the list anymore.
            ForEach(options.contains(selection) ? options : [selection] + options, id: \.self) { option in
                Text(option).tag(option)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .pickerStyle(.menu)
    }
}

struct IconWheelRow: View {
    let systemImage: String
    let title: String
    @Binding var selection: String
    let options: [String]
    var unit = ""
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Picker(title, selection: $selection) {
                ForEach(options.contains(selection) ? options : [selection] + options, id: \.self) { option in
                    Text(option + unit).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxHeight: 150)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(selection + unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
