import FileProvider
import UniformTypeIdentifiers

final class DashboardFileProviderExtension: NSFileProviderExtension {
    private var sharedFolder: URL {
        let groupID = "group.com.steveplayer87.superdashboard"
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        return (container ?? documentStorageURL).appendingPathComponent("SuperDashboardFiles", isDirectory: true)
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        if identifier == .rootContainer {
            return DashboardFileProviderItem(identifier: .rootContainer, parent: .rootContainer, name: "超級儀表板", directory: true)
        }
        let url = sharedFolder.appendingPathComponent(identifier.rawValue)
        guard FileManager.default.fileExists(atPath: url.path) else { throw NSFileProviderError(.noSuchItem) }
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return DashboardFileProviderItem(identifier: identifier, parent: .rootContainer, name: url.lastPathComponent, directory: isDirectory.boolValue, size: size)
    }

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        guard containerItemIdentifier == .rootContainer else { throw NSFileProviderError(.noSuchItem) }
        try FileManager.default.createDirectory(at: sharedFolder, withIntermediateDirectories: true)
        return DashboardFileEnumerator(rootURL: sharedFolder)
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        identifier == .rootContainer ? sharedFolder : sharedFolder.appendingPathComponent(identifier.rawValue)
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        guard url.deletingLastPathComponent() == sharedFolder else { return nil }
        return NSFileProviderItemIdentifier(url.lastPathComponent)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) { completionHandler(nil) }
    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(FileManager.default.fileExists(atPath: url.path) ? nil : NSFileProviderError(.noSuchItem))
    }
    override func stopProvidingItem(at url: URL) { }
}

private final class DashboardFileEnumerator: NSObject, NSFileProviderEnumerator {
    private let rootURL: URL
    init(rootURL: URL) { self.rootURL = rootURL; super.init() }
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
            let items: [NSFileProviderItem] = urls.map { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return DashboardFileProviderItem(identifier: NSFileProviderItemIdentifier(url.lastPathComponent), parent: .rootContainer, name: url.lastPathComponent, directory: values?.isDirectory ?? false, size: values?.fileSize ?? 0)
            }
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
        } catch { observer.finishEnumeratingWithError(error) }
    }
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(NSFileProviderSyncAnchor(Data("superdashboard-v1".utf8)))
    }
    func invalidate() { }
}

private final class DashboardFileProviderItem: NSObject, NSFileProviderItem {
    let itemIdentifier: NSFileProviderItemIdentifier
    let parentItemIdentifier: NSFileProviderItemIdentifier
    let filename: String
    let typeIdentifier: String
    let capabilities: NSFileProviderItemCapabilities
    let documentSize: NSNumber?
    let contentModificationDate: Date?

    init(identifier: NSFileProviderItemIdentifier, parent: NSFileProviderItemIdentifier, name: String, directory: Bool, size: Int = 0) {
        itemIdentifier = identifier
        parentItemIdentifier = parent
        filename = name
        typeIdentifier = directory ? UTType.folder.identifier : (UTType(filenameExtension: (name as NSString).pathExtension)?.identifier ?? UTType.data.identifier)
        capabilities = directory ? [.allowsContentEnumerating] : [.allowsReading]
        documentSize = directory ? nil : NSNumber(value: size)
        contentModificationDate = (try? URL(fileURLWithPath: name).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        super.init()
    }
}
