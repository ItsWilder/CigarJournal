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
}
