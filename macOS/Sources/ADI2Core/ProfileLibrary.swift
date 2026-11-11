import Foundation

public struct SavedProfile: Identifiable, Equatable, Sendable {
    /// UUID of the local file, independent of the editable display name.
    public let id: String
    public let profile: EQProfile
    public init(id: String, profile: EQProfile) { self.id = id; self.profile = profile }
}
public struct LibraryListing: Sendable {
    public let profiles: [SavedProfile]
    public let warnings: [String]
}
/// Local, sandbox-container storage. Profiles retain the Linux JSON schema.
public struct FileProfileLibrary: Sendable {
    public let directory: URL
    private static let maximumFileSize = 2_000_000
    public init(directory: URL) { self.directory = directory.standardizedFileURL }
    public static func defaultDirectory() throws -> URL {
        try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
            .appendingPathComponent("ADI2Companion",isDirectory:true).appendingPathComponent("Profiles",isDirectory:true)
    }
    private func prepareDirectory() throws { try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true) }
    private func file(id: String) throws -> URL {
        guard let uuid = UUID(uuidString:id), uuid.uuidString == id else { throw ADI2Error.invalid("The saved profile ID is invalid.") }
        return directory.appendingPathComponent(uuid.uuidString + ".json",isDirectory:false)
    }
    public func save(_ profile: EQProfile) throws -> SavedProfile {
        try profile.validate()
        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let data = try encoder.encode(profile)
        guard data.count <= Self.maximumFileSize else { throw ADI2Error.invalid("A local profile must be smaller than 2 MB.") }
        try prepareDirectory()
        let id = UUID().uuidString
        let url = try file(id:id)
        try data.write(to:url,options:.atomic)
        return SavedProfile(id:id,profile:profile)
    }
    /// Corrupt, oversized, symbolic-link and unrecognized files are skipped with
    /// bounded warnings; healthy profiles remain available instead of vanishing.
    public func list() throws -> LibraryListing {
        try prepareDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey],options:[.skipsHiddenFiles])
            .filter {$0.pathExtension.lowercased() == "json"}.sorted {$0.lastPathComponent < $1.lastPathComponent}
        guard urls.count <= 4096 else { throw ADI2Error.invalid("The profile library contains too many files. Keep fewer than 4097 profiles in this folder.") }
        var profiles:[SavedProfile] = [],warnings:[String] = []
        var skipped = 0
        for url in urls {
            do {
                let id = url.deletingPathExtension().lastPathComponent
                _ = try file(id:id)
                let info = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
                guard info.isRegularFile == true,info.isSymbolicLink != true,(info.fileSize ?? Int.max) <= Self.maximumFileSize else { throw ADI2Error.invalid("Expected a regular JSON file smaller than 2 MB.") }
                let data = try Data(contentsOf:url,options:.mappedIfSafe)
                guard data.count <= Self.maximumFileSize else { throw ADI2Error.invalid("The profile is larger than 2 MB.") }
                let profile = try JSONDecoder().decode(EQProfile.self,from:data)
                try profile.validate()
                profiles.append(SavedProfile(id:id,profile:profile))
            } catch {
                skipped += 1
                if warnings.count < 20 { warnings.append("Could not load \(url.lastPathComponent): \(error.localizedDescription)") }
            }
        }
        if skipped > warnings.count { warnings.append("Skipped \(skipped - warnings.count) additional unreadable profile files.") }
        profiles.sort {
            let order = $0.profile.name.compare($1.profile.name,options:[.caseInsensitive,.literal],locale:Locale(identifier:"en_US_POSIX"))
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        return LibraryListing(profiles:profiles,warnings:warnings)
    }
    public func remove(id: String) throws {
        let url = try file(id:id)
        let info = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true else { throw ADI2Error.invalid("The saved profile is not a regular local file.") }
        try FileManager.default.removeItem(at:url)
    }
}
