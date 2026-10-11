import ActivityKit
import Foundation

public struct QuickCopyItemData: Codable, Hashable {
    public var id: String
    public var label: String
    public var text: String
    public var isLink: Bool
    
    public init(id: String, label: String, text: String, isLink: Bool = false) {
        self.id = id
        self.label = label
        self.text = text
        self.isLink = isLink
    }

    enum CodingKeys: String, CodingKey {
        case id, label, name, text, isLink
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        let textVal = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
        self.text = textVal
        let lbl = (try? container.decodeIfPresent(String.self, forKey: .label))
        let nm = (try? container.decodeIfPresent(String.self, forKey: .name))
        self.label = lbl ?? nm ?? (textVal.isEmpty ? "項目" : String(textVal.prefix(12)))
        self.isLink = (try? container.decodeIfPresent(Bool.self, forKey: .isLink)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(text, forKey: .text)
        try container.encode(isLink, forKey: .isLink)
    }
}

public struct QuickCopyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var items: [QuickCopyItemData]
        public var lastCopiedText: String?
        public var updateTimestamp: Double
        
        public init(items: [QuickCopyItemData], lastCopiedText: String? = nil, updateTimestamp: Double = Date().timeIntervalSince1970) {
            self.items = items
            self.lastCopiedText = lastCopiedText
            self.updateTimestamp = updateTimestamp
        }
    }

    public var title: String
    
    public init(title: String = "常用速貼庫") {
        self.title = title
    }
}
