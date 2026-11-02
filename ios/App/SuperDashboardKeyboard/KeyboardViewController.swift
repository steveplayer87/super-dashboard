import UIKit

private struct ClipItem: Codable {
    let id: String
    let label: String
    let text: String
    let category: String
}

final class KeyboardViewController: UIInputViewController {
    private let groupID = "group.com.steveplayer87.superdashboard"
    private let storeKey = "keyboardQuickCopyItems"
    private var items: [ClipItem] = []
    private var categories: [String] = []
    private var selectedCategory = "全部"
    private var hasSharedData = false
    private var decodeFailed = false
    private let root = UIStackView()
    private let tabs = UIStackView()
    private let grid = UIStackView()
    private let status = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.secondarySystemBackground
        root.axis = .vertical; root.spacing = 8; root.translatesAutoresizingMaskIntoConstraints = false
        tabs.axis = .horizontal; tabs.spacing = 6
        grid.axis = .vertical; grid.spacing = 6
        status.text = "尚無速貼資料，請先開啟超級儀表板同步"; status.font = .systemFont(ofSize: 12); status.textAlignment = .center; status.textColor = .secondaryLabel
        let top = UIStackView(); top.axis = .horizontal; top.alignment = .center
        let title = UILabel(); title.text = "超級速貼"; title.font = .boldSystemFont(ofSize: 15)
        top.addArrangedSubview(title); top.addArrangedSubview(UIView())
        root.addArrangedSubview(top); root.addArrangedSubview(tabs); root.addArrangedSubview(grid); root.addArrangedSubview(status)
        view.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),view.heightAnchor.constraint(equalToConstant: 260)])
        reloadItems()
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reloadItems() }
    private func reloadItems() {
        let defaultsData = UserDefaults(suiteName: groupID)?.data(forKey: storeKey)
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        let fileData = container.flatMap { try? Data(contentsOf: $0.appendingPathComponent("keyboardQuick_copy.json")) }
        let data = defaultsData ?? fileData
        hasSharedData = data != nil
        decodeFailed = false
        if let data = data {
            do { items = try JSONDecoder().decode([ClipItem].self, from: data) }
            catch { items = []; decodeFailed = true; status.text = "速貼資料格式錯誤：\(error.localizedDescription)" }
        } else { items = [] }
        categories = ["全部"] + Array(Set(items.map{$0.category})).filter{ !$0.isEmpty }.sorted()
        if !categories.contains(selectedCategory) { selectedCategory = "全部" }
        render()
    }
    private func render() {
        tabs.arrangedSubviews.forEach{$0.removeFromSuperview()}; grid.arrangedSubviews.forEach{$0.removeFromSuperview()}
        for category in categories {
            let b=UIButton(type:.system); b.setTitle(category, for:.normal); b.titleLabel?.font = .systemFont(ofSize:12,weight:category == selectedCategory ? .bold:.regular)
            b.backgroundColor = category == selectedCategory ? .systemBlue : .tertiarySystemFill; b.tintColor = category == selectedCategory ? .white : .label; b.layer.cornerRadius=9; b.contentEdgeInsets=UIEdgeInsets(top:6,left:9,bottom:6,right:9); b.addAction(UIAction{[weak self] _ in self?.selectedCategory=category; self?.render()},for:.touchUpInside); tabs.addArrangedSubview(b)
        }
        let visible = items.filter{ selectedCategory == "全部" || $0.category == selectedCategory }
        for chunk in stride(from:0,to:visible.count,by:3) {
            let row=UIStackView(); row.axis = .horizontal; row.spacing=6; row.distribution = .fillEqually
            for item in visible[chunk..<min(chunk+3,visible.count)] {
                let b=UIButton(type:.system); b.setTitle(item.label.isEmpty ? item.text : item.label,for:.normal); b.titleLabel?.font = .systemFont(ofSize:13); b.titleLabel?.numberOfLines=2; b.backgroundColor = .tertiarySystemFill; b.layer.cornerRadius=10; b.addAction(UIAction{[weak self] _ in self?.textDocumentProxy.insertText(item.text)},for:.touchUpInside); row.addArrangedSubview(b)
            }
            while row.arrangedSubviews.count < 3 { row.addArrangedSubview(UIView()) }; grid.addArrangedSubview(row)
        }
        if !items.isEmpty { status.text = "已載入 \(items.count) 筆 · 顯示 \(visible.count) 筆" }
        else if !hasSharedData { status.text = "未讀到共享資料（App Group）" }
        else if decodeFailed { /* Keep the decoding error visible. */ }
        else { status.text = "共享資料為空（已讀取）" }
    }
}
