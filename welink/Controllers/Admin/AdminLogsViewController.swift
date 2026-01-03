import UIKit
import Supabase

final class AdminLogsViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView?

    fileprivate enum JSONValue: Decodable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case object([String: JSONValue])
        case array([JSONValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                self = .null
            } else if let b = try? container.decode(Bool.self) {
                self = .bool(b)
            } else if let n = try? container.decode(Double.self) {
                self = .number(n)
            } else if let s = try? container.decode(String.self) {
                self = .string(s)
            } else if let o = try? container.decode([String: JSONValue].self) {
                self = .object(o)
            } else if let a = try? container.decode([JSONValue].self) {
                self = .array(a)
            } else {
                self = .null
            }
        }
    }

    private static func shortId(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.count <= 8 { return s }
        return String(s.prefix(8))
    }

    private static func formattedTimestamp(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = Self.isoFormatter.date(from: trimmed) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
        return trimmed
    }

    private static func metadataString(_ metadata: [String: JSONValue]?) -> String? {
        guard let metadata, !metadata.isEmpty else { return nil }
        let blockedKeys = Set(["status", "application_id"])
        let parts = metadata
            .filter { key, _ in !blockedKeys.contains(key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
            .map { key, value in "\(key): \(value.stringValue)" }
            .sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        return parts.joined(separator: "  •  ")
    }

    private func updatePrompt() {
        guard let startDate, let endDate else {
            navigationItem.prompt = nil
            return
        }

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        navigationItem.prompt = "\(df.string(from: startDate)) – \(df.string(from: endDate))"
    }

    private func updatePromptAndReload() {
        updatePrompt()
        Task { [weak self] in
            await self?.loadLogs(showSpinner: true)
        }
    }

    private struct AdminLogItem: Decodable {
        let id: Int64
        let created_at: String
        let action: String
        let target_user_id: String?
        let admin_user_id: String
        let metadata: [String: JSONValue]?
    }

    private struct GetLogsPayload: Encodable {
        let limit: Int
        let offset: Int
        let startDate: String?
        let endDate: String?
    }

    private struct GetLogsResponse: Decodable {
        let logs: [AdminLogItem]
    }

    private var logs: [AdminLogItem] = []
    private var targetUserNamesById: [String: String] = [:]
    private let refreshControl = UIRefreshControl()
    private var isLoading = false

    private var startDate: Date?
    private var endDate: Date?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Admin Log"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Date",
            style: .plain,
            target: self,
            action: #selector(dateFilterTapped)
        )
        updatePrompt()

        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.tableFooterView = UIView()
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = 84
        tableView?.separatorStyle = .singleLine
        tableView?.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView?.backgroundColor = UIColor.systemBackground

        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView?.refreshControl = refreshControl

        Task { [weak self] in
            await self?.loadLogs(showSpinner: true)
        }
    }

    @objc private func dateFilterTapped() {
        let alert = UIAlertController(title: "Date Range", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Today", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let cal = Calendar.current
            self.startDate = cal.startOfDay(for: Date())
            self.endDate = Date()
            self.updatePromptAndReload()
        }))

        alert.addAction(UIAlertAction(title: "Last 7 Days", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.endDate = Date()
            self.startDate = Calendar.current.date(byAdding: .day, value: -7, to: self.endDate ?? Date())
            self.updatePromptAndReload()
        }))

        alert.addAction(UIAlertAction(title: "Last 30 Days", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.endDate = Date()
            self.startDate = Calendar.current.date(byAdding: .day, value: -30, to: self.endDate ?? Date())
            self.updatePromptAndReload()
        }))

        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.startDate = nil
            self.endDate = nil
            self.updatePromptAndReload()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = alert.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    @objc private func refreshPulled() {
        Task { [weak self] in
            await self?.loadLogs(showSpinner: false)
        }
    }

    private func loadLogs(showSpinner: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            Task { @MainActor in
                self.refreshControl.endRefreshing()
                self.isLoading = false
            }
        }

        do {
            let startISO = startDate.map { Self.isoFormatter.string(from: $0) }
            let endISO = endDate.map { Self.isoFormatter.string(from: $0) }
            let payload = GetLogsPayload(limit: 100, offset: 0, startDate: startISO, endDate: endISO)

            // Expected edge function response:
            // { "logs": [ { "id": 1, "created_at": "...", "action": "...", "target_user_id": "...", "admin_user_id": "...", "metadata": { ... } } ] }
            let response: GetLogsResponse = try await SupabaseClientManager.shared.client.functions
                .invoke(
                    "admin-get-logs",
                    options: FunctionInvokeOptions(body: payload)
                )

            let ids = Array(Set(response.logs.compactMap { row in
                let s = (row.target_user_id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }))

            var names: [String: String] = [:]
            if !ids.isEmpty {
                struct UserNameRow: Decodable {
                    let id: String
                    let name: String
                }

                do {
                    let rows: [UserNameRow] = try await SupabaseClientManager.shared.client.database
                        .from("users")
                        .select("id, name")
                        .in("id", value: ids)
                        .execute()
                        .value
                    names = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
                } catch {
                    names = [:]
                }
            }

            await MainActor.run {
                self.logs = response.logs
                self.targetUserNamesById = names
                self.tableView?.reloadData()
            }
        } catch {
            await MainActor.run {
                self.showError(message: "Failed to load logs")
            }
        }
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

fileprivate extension AdminLogsViewController.JSONValue {
    var stringValue: String {
        switch self {
        case .string(let s):
            return s
        case .number(let n):
            if n.rounded() == n { return String(Int64(n)) }
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .object(let o):
            let inner = o.map { "\($0): \($1.stringValue)" }.sorted().joined(separator: ", ")
            return "{\(inner)}"
        case .array(let a):
            let inner = a.map { $0.stringValue }.joined(separator: ", ")
            return "[\(inner)]"
        case .null:
            return "null"
        }
    }
}

extension AdminLogsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        logs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AdminLogCell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "AdminLogCell")

        let item = logs[indexPath.row]

        var primary = item.action
        primary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if primary.isEmpty { primary = "Action" }

        let timeText = Self.formattedTimestamp(from: item.created_at)
        let meta = Self.metadataString(item.metadata)

        let targetId = (item.target_user_id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let targetName = targetId.isEmpty ? nil : targetUserNamesById[targetId]

        var secondaryParts: [String] = []
        if let targetName, !targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            secondaryParts.append(targetName)
        }
        secondaryParts.append(timeText)
        if let meta {
            secondaryParts.append(meta)
        }

        let subtitle = secondaryParts.joined(separator: "  •  ")

        if let titleLabel = cell.contentView.viewWithTag(1) as? UILabel,
           let subtitleLabel = cell.contentView.viewWithTag(2) as? UILabel {
            titleLabel.text = primary
            subtitleLabel.text = subtitle
        } else {
            var content = UIListContentConfiguration.subtitleCell()
            content.text = primary
            content.secondaryText = subtitle
            content.textProperties.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 13)
            content.secondaryTextProperties.color = .secondaryLabel
            content.textProperties.color = .label
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            cell.contentConfiguration = content
        }

        cell.backgroundColor = .systemBackground
        cell.contentView.backgroundColor = .systemBackground
        cell.layer.cornerRadius = 0
        cell.layer.masksToBounds = false

        cell.selectionStyle = .none
        return cell
    }
}
