//
//  NotificationsViewController.swift
//  welink
//
//  Created by Ahmed on 17/12/2025.
//


import UIKit

class NotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!

    private struct NotificationRow: Decodable {
        let id: String
        let user_id: String
        let type: String
        let title: String
        let content: String
        let is_read: Bool
        let created_at: String
    }

    private struct NotificationItem {
        let id: String
        let notificationId: String?
        let type: String
        let title: String
        let content: String
        let isRead: Bool
        let createdAt: String
    }

    private var items: [NotificationItem] = []

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No notifications yet"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Notifications"

        guard tableView != nil else {
            print("[Notifications] ERROR: tableView outlet is not connected!")
            return
        }

        tableView.dataSource = self
        tableView.delegate = self

        tableView.rowHeight = 100
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView()

        setupEmptyState()

        Task { [weak self] in
            await self?.loadNotifications()
        }
    }

    private func setupEmptyState() {
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        emptyStateLabel.isHidden = true
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !items.isEmpty
        tableView.isHidden = items.isEmpty
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.loadNotifications()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath)
        let item = items[indexPath.row]

        if let cardView = cell.viewWithTag(5) as? UIView {
            cardView.backgroundColor = item.isRead ? UIColor.systemGray6 : UIColor.systemBlue.withAlphaComponent(0.1)
            cardView.layer.cornerRadius = 14
            cardView.clipsToBounds = true
        }

        if let avatarContainer = cell.viewWithTag(1) as? UIView {
            avatarContainer.backgroundColor = iconBackgroundColor(for: item.type)
            avatarContainer.clipsToBounds = true

            let size: CGFloat = 52
            if let w = avatarContainer.constraints.first(where: { $0.firstAttribute == .width }) {
                w.constant = size
            } else {
                let w = avatarContainer.widthAnchor.constraint(equalToConstant: size)
                w.priority = .required
                w.isActive = true
            }

            if let h = avatarContainer.constraints.first(where: { $0.firstAttribute == .height }) {
                h.constant = size
            } else {
                let h = avatarContainer.heightAnchor.constraint(equalToConstant: size)
                h.priority = .required
                h.isActive = true
            }

            avatarContainer.layoutIfNeeded()
            avatarContainer.layer.cornerRadius = size / 2

            if let avatarLabel = avatarContainer.viewWithTag(2) as? UILabel {
                avatarLabel.text = iconText(for: item.type)
                avatarLabel.textAlignment = .center
                avatarLabel.frame = avatarContainer.bounds
                avatarLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }

        if let nameLabel = cell.viewWithTag(3) as? UILabel {
            nameLabel.text = item.title
            nameLabel.font = item.isRead ? .systemFont(ofSize: 16) : .boldSystemFont(ofSize: 16)
        }

        if let subtitleLabel = cell.viewWithTag(4) as? UILabel {
            subtitleLabel.text = item.content
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        let item = items[indexPath.row]

        // Mark notification as read (only for notifications table rows)
        guard let notificationId = item.notificationId else { return }
        if !item.isRead {
            Task { [weak self] in
                await self?.markNotificationAsRead(id: notificationId)
            }
        }
    }

    // MARK: - Data Loading

    private struct UserRoleRow: Decodable {
        let role: String?
    }

    private struct PendingProviderRow: Decodable {
        let id: String
        let name: String
        let status: String?
        let created_at: String?
    }

    private func loadNotifications() async {
        guard let session = try? await SupabaseClientManager.shared.client.auth.session else {
            print("[Notifications] No active session")
            await MainActor.run {
                self.updateEmptyState()
            }
            return
        }

        let currentUserId = session.user.id.uuidString.lowercased()

        let role = await fetchUserRole(userId: currentUserId)
        if role.lowercased() == "admin" {
            await loadPendingProviders()
        } else {
            await loadNotificationRows(for: currentUserId)
        }
    }

    private func fetchUserRole(userId: String) async -> String {
        let client = SupabaseClientManager.shared.client
        do {
            let rows: [UserRoleRow] = try await client.database
                .from("users")
                .select("role")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            return rows.first?.role ?? "seeker"
        } catch {
            print("[Notifications] Error fetching user role:", error.localizedDescription)
            return "seeker"
        }
    }

    private func loadNotificationRows(for userId: String) async {
        print("[Notifications] Loading notification rows for user: \(userId)")

        let client = SupabaseClientManager.shared.client

        do {
            let rows: [NotificationRow] = try await client.database
                .from("notifications")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            print("[Notifications] Fetched \(rows.count) notifications")

            let mapped: [NotificationItem] = rows.map { row in
                NotificationItem(
                    id: row.id,
                    notificationId: row.id,
                    type: row.type,
                    title: row.title,
                    content: row.content,
                    isRead: row.is_read,
                    createdAt: row.created_at
                )
            }

            await MainActor.run {
                self.items = mapped
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        } catch {
            print("[Notifications] Error loading: \(error)")
            await MainActor.run {
                self.items = []
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        }
    }

    private func loadPendingProviders() async {
        print("[Notifications] Loading pending providers (admin)")

        let client = SupabaseClientManager.shared.client

        do {
            let rows: [PendingProviderRow] = try await client.database
                .from("users")
                .select("id, name, status, created_at")
                .eq("role", value: "provider")
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            let mapped: [NotificationItem] = rows.map { row in
                NotificationItem(
                    id: row.id,
                    notificationId: nil,
                    type: "provider_pending",
                    title: row.name,
                    content: "Pending provider account",
                    isRead: false,
                    createdAt: row.created_at ?? ""
                )
            }

            await MainActor.run {
                self.items = mapped
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        } catch {
            print("[Notifications] Error loading pending providers:", error.localizedDescription)
            await MainActor.run {
                self.items = []
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        }
    }

    private func markNotificationAsRead(id: String) async {
        let client = SupabaseClientManager.shared.client

        do {
            _ = try await client.database
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: id)
                .execute()

            // Update local state
            await MainActor.run {
                if let index = self.items.firstIndex(where: { $0.notificationId == id }) {
                    let item = self.items[index]
                    self.items[index] = NotificationItem(
                        id: item.id,
                        notificationId: item.notificationId,
                        type: item.type,
                        title: item.title,
                        content: item.content,
                        isRead: true,
                        createdAt: item.createdAt
                    )
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
            }
        } catch {
            print("Error marking notification as read:", error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func iconText(for type: String) -> String {
        switch type {
        case "provider_pending": return "P"
        case "booking_request": return "B"
        case "booking_accepted": return "✓"
        case "booking_rejected": return "✗"
        case "booking_cancelled": return "C"
        case "new_rating": return "★"
        case "application_accepted": return "✓"
        case "application_rejected": return "✗"
        case "system": return "!"
        default: return "N"
        }
    }

    private func iconBackgroundColor(for type: String) -> UIColor {
        switch type {
        case "provider_pending": return .systemOrange
        case "booking_request": return .systemBlue
        case "booking_accepted", "application_accepted": return .systemGreen
        case "booking_rejected", "application_rejected": return .systemRed
        case "booking_cancelled": return .systemOrange
        case "new_rating": return .systemYellow
        case "system": return .systemGray
        default: return .systemGray5
        }
    }
}
