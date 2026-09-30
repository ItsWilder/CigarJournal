// CigarBackup
// A JSON snapshot of the whole journal (photos included) that can be exported
// to Files/iCloud Drive and restored later. Restore is add-only: it never
// deletes or overwrites anything already in the journal.

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct CigarBackup: Codable {
    var version = 1
    var exportedAt: Date
    var cigars: [Entry]

    struct Entry: Codable {
        var name: String
        var type: String
        var length: String
        var gauge: String
        var location: String
        var price: String
        var strength: String
        var rating: Int
        var notes: String
        var date: Date
        var photo: Data?
        // Added with store locations; older backups simply don't have them.
        var storePlaceID: String?
        var storeLatitude: Double?
        var storeLongitude: Double?
        var storeAddress: String?
    }
}

extension CigarBackup {
    init(cigars: [CigarTemplate]) {
        self.exportedAt = .now
        self.cigars = cigars.map { cigar in
            Entry(
                name: cigar.name,
                type: cigar.type,
                length: cigar.length,
                gauge: cigar.gauge,
                location: cigar.location,
                price: cigar.price,
                strength: cigar.strength,
                rating: cigar.rating,
                notes: cigar.notes,
                date: cigar.date,
                photo: cigar.photo,
                storePlaceID: cigar.storePlaceID,
                storeLatitude: cigar.storeLatitude,
                storeLongitude: cigar.storeLongitude,
                storeAddress: cigar.storeAddress
            )
        }
    }

    init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(CigarBackup.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    var suggestedFilename: String {
        "CigarJournal-\(exportedAt.formatted(.iso8601.year().month().day()))"
    }

    /// Entries that aren't already in the journal. A cigar counts as a match when the
    /// name is the same and the date is within a second (ISO 8601 drops fractional seconds).
    func entriesMissing(from existing: [CigarTemplate]) -> [Entry] {
        cigars.filter { entry in
            !existing.contains { cigar in
                cigar.name.caseInsensitiveCompare(entry.name) == .orderedSame
                    && abs(cigar.date.timeIntervalSince(entry.date)) < 1
            }
        }
    }

    static func insert(_ entries: [Entry], into context: ModelContext) {
        for entry in entries {
            let cigar = CigarTemplate(
                name: entry.name,
                type: entry.type,
                length: entry.length,
                gauge: entry.gauge,
                location: entry.location,
                price: entry.price,
                strength: entry.strength,
                rating: entry.rating,
                notes: entry.notes,
                date: entry.date,
                photo: entry.photo
            )
            cigar.storePlaceID = entry.storePlaceID
            cigar.storeLatitude = entry.storeLatitude
            cigar.storeLongitude = entry.storeLongitude
            cigar.storeAddress = entry.storeAddress
            context.insert(cigar)
        }
    }
}

/// Wraps already-encoded backup JSON for `.fileExporter`.
nonisolated struct CigarBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
