import Foundation

/// Added by hex-sidestore; not part of upstream Hex.
///
/// SideStore re-signs the app under the installer's own Apple team and renames
/// App Groups to "<group>.<TEAMID>", so the upstream literal no longer matches.
/// The provisioning profile embedded at install time lists the group this copy
/// was actually granted, so read it from there.
nonisolated enum SideloadAppGroup {
    static func resolve(fallback: String) -> String {
        let groups = provisionedAppGroups()
        return groups.first { $0.hasPrefix(fallback) } ?? groups.first ?? fallback
    }

    private static func provisionedAppGroups() -> [String] {
        guard
            let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
            let profile = try? Data(contentsOf: url),
            let start = profile.range(of: Data("<?xml".utf8)),
            let end = profile.range(of: Data("</plist>".utf8), in: start.lowerBound..<profile.endIndex),
            let plist = try? PropertyListSerialization.propertyList(
                from: profile[start.lowerBound..<end.upperBound], format: nil
            ) as? [String: Any],
            let entitlements = plist["Entitlements"] as? [String: Any]
        else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }
}
