import Foundation

struct ExcludedApplication: Codable, Hashable, Identifiable {
    let bundleID: String
    let name: String

    var id: String { bundleID }
}

enum ApplicationExclusions {
    private static let key = "excludedApplications"

    static var applications: [ExcludedApplication] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let applications = try? JSONDecoder().decode([ExcludedApplication].self, from: data) else { return [] }
        return applications
    }

    static func contains(bundleID: String?, in applications: [ExcludedApplication]) -> Bool {
        guard let bundleID else { return false }
        return applications.contains { $0.bundleID == bundleID }
    }

    @discardableResult
    static func add(_ urls: [URL]) -> Bool {
        var updated = applications
        var accepted = false
        for url in urls {
            guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier,
                  !bundleID.isEmpty else { continue }
            accepted = true
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            updated.removeAll { $0.bundleID == bundleID }
            updated.append(ExcludedApplication(bundleID: bundleID, name: name))
        }
        guard accepted else { return false }
        if updated != applications { save(updated) }
        return true
    }

    static func remove(bundleID: String) {
        save(applications.filter { $0.bundleID != bundleID })
    }

    private static func save(_ applications: [ExcludedApplication]) {
        let sorted = applications.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        UserDefaults.standard.set(try? JSONEncoder().encode(sorted), forKey: key)
    }
}
