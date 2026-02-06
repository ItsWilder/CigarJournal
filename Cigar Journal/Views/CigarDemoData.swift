import Foundation

enum CigarDemoData {
    static func templates() -> [CigarTemplate] {
        let calendar = Calendar.current
        let today = Date()

        return [
            CigarTemplate(
                name: "Avo XO Notturno (Tubo)",
                shape: "Petite Corona",
                length: "5",
                gauge: "42",
                location: "JR Cigars",
                price: "10.90",
                strength: "Medium",
                rating: 4,
                notes: """
                Surprisingly polished despite its rough appearance. The smoke is warm and nutty, with subtle layers of honeyed tea, orange peel, and just a touch of caramel sweetness. Definitely more refined than expected-smooth and easygoing. Great choice for a relaxing evening.
                """,
                date: calendar.date(byAdding: .day, value: 0, to: today) ?? today
            ),
            CigarTemplate(
                name: "Quesada 50th Anniversary Toro Prensado",
                shape: "Toro",
                length: "6.25",
                gauge: "56",
                location: "Cigar Club",
                price: "17.00",
                strength: "Medium",
                rating: 4,
                notes: """
                Touches of wood, coffee and licorice precede the caramel finish. The draw and burn are even throughout. Very nice!
                """,
                date: calendar.date(byAdding: .day, value: -1, to: today) ?? today
            ),
            CigarTemplate(
                name: "Casa Magna Colorado",
                shape: "Robusto",
                length: "5.5",
                gauge: "52",
                location: "Bobby's Cigars",
                price: "9.87",
                strength: "Medium",
                rating: 5,
                notes: """
                This still brings those rich flavors of dark chocolate, nutmeg, and wood, with a little red pepper spice and a long, smooth finish. Just as good as when it won CoY in 2008!
                """,
                date: calendar.date(byAdding: .day, value: -2, to: today) ?? today
            ),
            CigarTemplate(
                name: "A. Flores 1975 Gran Reserva Desflorada",
                shape: "Half Corona",
                length: "3.5",
                gauge: "46",
                location: "Cigar Country",
                price: "6.60",
                strength: "Medium",
                rating: 3,
                notes: """
                This little smoke is nutty and spicy with woody undertones, but it burns a bit hot, causing a charry finish. Nice but not my favorite.

                Wrapper: Ecuadorian Connecticut
                Binder: Ecuadorian Habano and Nicaraguan Jalapa
                Filler: Dominican Republic and Nicaragua
                Origin: Dominican Republic
                """,
                date: calendar.date(byAdding: .day, value: -3, to: today) ?? today
            ),
            CigarTemplate(
                name: "Herrera Esteli Brazilian Maduro Lonsdale Deluxe",
                shape: "Lonsdale",
                length: "6",
                gauge: "44",
                location: "Cigar House",
                price: "10.95",
                strength: "Strong",
                rating: 4,
                notes: """
                Slim cigar with a full, satisfying draw. Bold flavors of spice, dark chocolate, and espresso, with hints of leather and earth on the finish. Lovely!
                """,
                date: calendar.date(byAdding: .day, value: -4, to: today) ?? today
            ),
            CigarTemplate(
                name: "Rocky Patel A.L.R. Second Edition",
                shape: "Toro",
                length: "6.5",
                gauge: "52",
                location: "Buckies",
                price: "16.25",
                strength: "Medium",
                rating: 5,
                notes: "Tons of nutmeg, German chocolate cake, and shredded coconut that get richer and more complex with each puff.",
                date: calendar.date(byAdding: .day, value: -5, to: today) ?? today
            )
        ]
    }
}
