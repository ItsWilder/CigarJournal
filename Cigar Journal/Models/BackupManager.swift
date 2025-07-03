//
//  BackupManager.swift
//  Cigar Journal
//
//  Created by David Wilder on 5/3/25.
//

import Foundation

class BackupManager {
    static let fileName = "cigar_backup.json"

    static func saveToJSON(_ backups: [CigarBackup]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(backups)

        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        try data.write(to: url)
    }

    static func loadFromJSON() throws -> [CigarBackup] {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([CigarBackup].self, from: data)
    }

    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func exportToCSV(_ backups: [CigarBackup]) throws -> URL {
        let header = "Name,Type,Length,Gauge,Location,Price,Strength,Rating,Notes,Date\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let rows = backups.map { cigar in
            let priceString = cigar.price.map { String(format: "%.2f", $0) } ?? ""
            let dateString = dateFormatter.string(from: cigar.date)
            let notes = (cigar.notes ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            
            return [
                cigar.name,
                cigar.type ?? "",
                cigar.length ?? "",
                cigar.gauge ?? "",
                cigar.location ?? "",
                priceString,
                cigar.strength ?? "",
                String(cigar.rating),
                "\"\(notes)\"",
                dateString
            ].joined(separator: ",")
        }.joined(separator: "\n")

        let csvText = header + rows
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cigar_export.csv")

        try csvText.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
}
