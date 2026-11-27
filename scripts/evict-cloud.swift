// evict-cloud DIR...: make every downloaded file under DIR online-only, like Finder's "Free Up Space".
// Works for File Provider clouds (OneDrive, Dropbox, Google Drive, iCloud). Files stay in the cloud and
// download again when opened. Files not yet uploaded can't be evicted and are left alone.
import Foundation

var evicted = 0, failed = 0
for root in CommandLine.arguments.dropFirst() {
    let keys: [URLResourceKey] = [.isRegularFileKey, .ubiquitousItemDownloadingStatusKey]
    guard let files = FileManager.default.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: keys) else { continue }
    for case let url as URL in files {
        guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true,
              v.ubiquitousItemDownloadingStatus != .notDownloaded, url.lastPathComponent != ".DS_Store" else { continue }
        do { try FileManager.default.evictUbiquitousItem(at: url); evicted += 1 } catch { failed += 1 }
    }
}
print("evicted \(evicted) files\(failed > 0 ? ", \(failed) not yet uploaded or busy (left alone)" : "")")
