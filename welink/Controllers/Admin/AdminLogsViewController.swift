import UIKit
import Supabase

final class AdminLogsViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView?

    private enum JSONValue: Decodable {
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

            await MainActor.run {
                self.logs = response.logs
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

extension AdminLogsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        logs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AdminLogCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "AdminLogCell")

        let item = logs[indexPath.row]
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.text = item.action

        var detailParts: [String] = []
        detailParts.append(item.created_at)
        if let target = item.target_user_id, !target.isEmpty {
            detailParts.append("target: \(target)")
        }
        detailParts.append("admin: \(item.admin_user_id)")

        cell.detailTextLabel?.numberOfLines = 3
        cell.detailTextLabel?.text = detailParts.joined(separator: " • ")

        cell.selectionStyle = .none
        return cell
    }
}
