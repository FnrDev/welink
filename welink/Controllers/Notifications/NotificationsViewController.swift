//
//  NotificationsViewController.swift
//  welink
//
//  Created by Ahmed on 17/12/2025.
//


import UIKit

class NotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!

    private struct ProviderApplicationRow: Decodable {
        let id: Int
        let user_id: String
        let full_name: String
        let email: String
        let phone: String
        let status: String
        let created_at: Date
        let services: [String]?
        let skills: [String]?
    }

    private struct NotificationItem {
        let id: Int
        let name: String
        let subtitle: String
        let requestedAtText: String
        let phone: String
        let email: String
        let skills: [String]
        let services: [AdminProviderRequestViewController.Service]
    }

    private var items: [NotificationItem] = []
    private let providerRequestDetailsStoryboardID = "AdminProviderRequest"

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Notification"

        tableView.dataSource = self
        tableView.delegate = self

        tableView.rowHeight = 100
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView()

        Task { [weak self] in
            await self?.loadPendingProviderRequests()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath)
        let item = items[indexPath.row]

        if let cardView = cell.viewWithTag(5) as? UIView {
            cardView.backgroundColor = UIColor.systemGray6
            cardView.layer.cornerRadius = 14
            cardView.clipsToBounds = true
        }

        if let avatarContainer = cell.viewWithTag(1) as? UIView {
            avatarContainer.backgroundColor = UIColor.systemGray5
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
                let firstChar = item.name.trimmingCharacters(in: .whitespacesAndNewlines).first
                avatarLabel.text = firstChar.map { String($0).uppercased() } ?? ""
                avatarLabel.textAlignment = .center
                avatarLabel.frame = avatarContainer.bounds
                avatarLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }

        if let nameLabel = cell.viewWithTag(3) as? UILabel {
            nameLabel.text = item.name
        }

        if let subtitleLabel = cell.viewWithTag(4) as? UILabel {
            subtitleLabel.text = item.subtitle
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        let item = items[indexPath.row]
        let selectedIndex = indexPath.row

        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        let detailsVC = storyboard.instantiateViewController(withIdentifier: providerRequestDetailsStoryboardID)
        guard let providerRequestVC = detailsVC as? AdminProviderRequestViewController else {
            let alert = UIAlertController(
                title: "Setup Error",
                message: "AdminProviderRequest scene is not using AdminProviderRequestViewController. Please set the scene custom class in AdminDashboard.storyboard.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        providerRequestVC.request = AdminProviderRequestViewController.ProviderRequestDetails(
            id: item.id,
            name: item.name,
            requestedAtText: item.requestedAtText,
            phone: item.phone,
            email: item.email,
            skills: item.skills,
            services: item.services
        )

        providerRequestVC.onApprove = { [weak self] in
            guard let self else { return }
            Task {
                do {
                    try await self.updateApplicationStatus(id: item.id, status: "accepted")
                    await MainActor.run {
                        guard self.items.indices.contains(selectedIndex) else { return }
                        self.items.remove(at: selectedIndex)
                        self.tableView.reloadData()
                    }
                } catch {
                    print("Approve error:", error.localizedDescription)
                }
            }
        }

        providerRequestVC.onReject = { [weak self] in
            guard let self else { return }
            Task {
                do {
                    try await self.updateApplicationStatus(id: item.id, status: "rejected")
                    await MainActor.run {
                        guard self.items.indices.contains(selectedIndex) else { return }
                        self.items.remove(at: selectedIndex)
                        self.tableView.reloadData()
                    }
                } catch {
                    print("Reject error:", error.localizedDescription)
                }
            }
        }

        navigationController?.pushViewController(providerRequestVC, animated: true)
    }

    private func loadPendingProviderRequests() async {
        let client = SupabaseClientManager.shared.client

        do {
            let rows: [ProviderApplicationRow] = try await client.database
                .from("applications")
                .select("id, user_id, full_name, email, phone, status, created_at, services, skills")
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            let mapped: [NotificationItem] = rows.map { row in
                let services: [AdminProviderRequestViewController.Service] = (row.services ?? []).map {
                    AdminProviderRequestViewController.Service(
                        title: $0,
                        subtitle: "",
                        priceText: "",
                        ratingText: ""
                    )
                }

                return NotificationItem(
                    id: row.id,
                    name: row.full_name,
                    subtitle: "New Provider Request",
                    requestedAtText: "Requested at \(formatDate(row.created_at))",
                    phone: row.phone,
                    email: row.email,
                    skills: row.skills ?? [],
                    services: services
                )
            }

            await MainActor.run {
                self.items = mapped
                self.tableView.reloadData()
            }
        } catch {
            print("Error loading notifications:", error.localizedDescription)
            await MainActor.run {
                self.items = []
                self.tableView.reloadData()
            }
        }
    }

    private func updateApplicationStatus(id: Int, status: String) async throws {
        let client = SupabaseClientManager.shared.client
        _ = try await client.database
            .from("applications")
            .update(["status": status])
            .eq("id", value: id)
            .execute()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
