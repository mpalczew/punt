import Foundation

enum URLCleaner {
    private static let trackingParams: Set<String> = [
        // UTM
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        // Facebook
        "fbclid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        // Google
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        // Microsoft
        "msclkid",
        // HubSpot
        "hsa_cam", "hsa_grp", "hsa_mt", "hsa_src", "hsa_ad", "hsa_acc",
        "hsa_net", "hsa_ver", "hsa_la", "hsa_ol", "hsa_kw",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Generic
        "ref", "referrer", "source",
    ]

    static func clean(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        guard let queryItems = components.queryItems, !queryItems.isEmpty else {
            return url
        }

        let filtered = queryItems.filter { item in
            !trackingParams.contains(item.name.lowercased())
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url ?? url
    }
}
