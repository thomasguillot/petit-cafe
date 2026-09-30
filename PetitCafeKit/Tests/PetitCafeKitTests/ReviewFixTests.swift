import Foundation
import Testing
@testable import PetitCafeKit

struct ReleaseNotesFixTests {
    @Test func aChangelogHeadingStartingWithInstallerIsKept() {
        let blocks = ReleaseNotes.blocks(from: "## Installer fixes\n- Faster swap\n\n## Install\nDrag it over.")

        #expect(blocks == [.heading(level: 2, text: "Installer fixes"), .bullet("Faster swap")])
    }

    @Test func orderedItemsStaySeparate() {
        let blocks = ReleaseNotes.blocks(from: "1. First thing\n2. Second thing")

        #expect(blocks == [.bullet("First thing"), .bullet("Second thing")])
    }

    @Test func aVersionNumberAtTheStartOfALineIsNotAList() {
        #expect(ReleaseNotes.blocks(from: "1.2.0 is out.") == [.paragraph("1.2.0 is out.")])
    }
}

struct GitHubReleaseToleranceTests {
    @Test func unusedKeysMayBeMissing() throws {
        let json = """
        [{"tag_name":"v1.1.0","assets":[{"name":"a.dmg","browser_download_url":"https://example.com/a.dmg","size":1}]}]
        """
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: Data(json.utf8))

        #expect(releases.first?.assets.first?.size == 1)
    }
}
