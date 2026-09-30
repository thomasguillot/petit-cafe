import Foundation
import Testing
@testable import PetitCafeKit

struct UpdateDigestTests {
    private let hex = String(repeating: "ab", count: 32)

    private func release(digest: String?) -> GitHubRelease {
        GitHubRelease(
            tagName: "v1.1.0", htmlURL: "https://github.com/owner/repo/releases/tag/v1.1.0",
            assets: [
                .init(
                    name: "PetitCafe-1.1.0.dmg",
                    browserDownloadURL: "https://github.com/owner/repo/releases/download/v1.1.0/PetitCafe.dmg",
                    contentType: "application/x-apple-diskimage", size: 4096, digest: digest)
            ])
    }

    @Test func thePlanCarriesThePublishedChecksum() {
        let plan = UpdateAvailability.plan(
            current: AppVersion("1.0.0")!, releases: [release(digest: "sha256:\(hex.uppercased())")])

        #expect(plan?.sha256 == hex)
    }

    @Test func aMissingOrMalformedChecksumIsNil() {
        let current = AppVersion("1.0.0")!

        #expect(UpdateAvailability.plan(current: current, releases: [release(digest: nil)])?.sha256 == nil)
        #expect(UpdateAvailability.plan(current: current, releases: [release(digest: "md5:abc")])?.sha256 == nil)
        #expect(UpdateAvailability.plan(current: current, releases: [release(digest: "sha256:abc")])?.sha256 == nil)
    }

    @Test func theChecksumIsDecodedFromTheAPI() throws {
        let json = """
        [{"tag_name":"v1.1.0","html_url":"https://example.com","assets":[{"name":"a.dmg",
        "browser_download_url":"https://example.com/a.dmg","content_type":"application/octet-stream",
        "size":1,"digest":"sha256:\(hex)"}]}]
        """
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: Data(json.utf8))

        #expect(releases.first?.assets.first?.digest == "sha256:\(hex)")
    }
}
