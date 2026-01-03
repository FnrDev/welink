//
//  AdminDashboardViewController.swift
//  welink
//
//  Created by rawan on 21/12/2025.
//

import UIKit

class AdminDashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private static let applicationsDidChangeNotification = Notification.Name("applicationsDidChange")

    @IBOutlet weak var providerRequestsTableView: UITableView!
    @IBOutlet weak var totalUsersValueLabel: UILabel!
    @IBOutlet weak var totalCategoriesValueLabel: UILabel!
    @IBOutlet weak var totalProvidersValueLabel: UILabel!
    @IBOutlet weak var totalSeekersValueLabel: UILabel!

    private struct ProviderRequest {
        let applicationId: Int
        let userId: String
        let name: String
        let requestedAtText: String
        let phone: String
        let email: String
        let skills: [String]
        let services: [AdminProviderRequestViewController.Service]
    }

    private var providerRequests: [ProviderRequest] = []

    private let providerRequestDetailsStoryboardID = "AdminProviderRequest"
    private let notificationsStoryboardName = "Notifications"
    private let notificationsStoryboardID = "notificationsVC"

    override func viewDidLoad() {
        super.viewDidLoad()

        providerRequestsTableView.dataSource = self
        providerRequestsTableView.delegate = self
        providerRequestsTableView.rowHeight = 140
        providerRequestsTableView.estimatedRowHeight = 140
        providerRequestsTableView.tableFooterView = UIView()

        Task { [weak self] in
            await self?.loadPendingApplications()
            await self?.loadAnalytics()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationsDidChange),
            name: Self.applicationsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.loadPendingApplications()
        }
    }

    @objc private func handleApplicationsDidChange() {
        Task { [weak self] in
            await self?.loadPendingApplications()
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

    @IBAction private func didTapNotifications(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: notificationsStoryboardName, bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: notificationsStoryboardID)
        navigationController?.pushViewController(vc, animated: true)
    }

    private struct UserCountRow: Decodable {
        let id: String
        let role: String?
    }

    private struct ServiceCategoriesRow: Decodable {
        let categories: [String]?
    }

    private func loadAnalytics() async {
        let client = SupabaseClientManager.shared.client

        do {
            let users: [UserCountRow] = try await client.database
                .from("users")
                .select("id, role")
                .execute()
                .value

            let services: [ServiceCategoriesRow] = try await client.database
                .from("services")
                .select("categories")
                .execute()
                .value

            let categories = services
                .compactMap { $0.categories }
                .flatMap { $0 }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let uniqueCategoriesCount = Set(categories).count

            let providersCount = users.filter { ($0.role ?? "seeker").lowercased() == "provider" }.count
            let seekersCount = users.filter { ($0.role ?? "seeker").lowercased() == "seeker" }.count

            await MainActor.run {
                self.totalUsersValueLabel.text = "\(users.count)"
                self.totalCategoriesValueLabel.text = "\(uniqueCategoriesCount)"
                self.totalProvidersValueLabel.text = "\(providersCount)"
                self.totalSeekersValueLabel.text = "\(seekersCount)"
            }
        } catch {
            print("Error loading admin analytics:", error.localizedDescription)
        }
    }

    private struct ApplicationRow: Decodable {
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

    private func loadPendingApplications() async {
        let client = SupabaseClientManager.shared.client

        do {
            let rows: [ApplicationRow] = try await client.database
                .from("applications")
                .select("id, user_id, full_name, email, phone, status, created_at, services, skills")
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            let mapped: [ProviderRequest] = rows.map { row in
                let serviceItems: [AdminProviderRequestViewController.Service] = (row.services ?? []).map {
                    AdminProviderRequestViewController.Service(
                        title: $0,
                        subtitle: "",
                        priceText: "",
                        ratingText: ""
                    )
                }

                return ProviderRequest(
                    applicationId: row.id,
                    userId: row.user_id,
                    name: row.full_name,
                    requestedAtText: "Requested at \(formatDate(row.created_at))",
                    phone: row.phone,
                    email: row.email,
                    skills: row.skills ?? [],
                    services: serviceItems
                )
            }

            await MainActor.run {
                self.providerRequests = mapped
                self.providerRequestsTableView.reloadData()
            }
        } catch {
            print("Error loading pending applications:", error.localizedDescription)
            await MainActor.run {
                self.providerRequests = []
                self.providerRequestsTableView.reloadData()
            }
        }
    }

    private func updateProviderStatus(userId: String, status: String) async throws {
        let client = SupabaseClientManager.shared.client
        _ = try await client.database
            .from("users")
            .update(["status": status])
            .eq("id", value: userId)
            .execute()
    }

    private func updateUserRole(userId: String, role: String) async throws {
        let client = SupabaseClientManager.shared.client
        _ = try await client.database
            .from("users")
            .update(["role": role])
            .eq("id", value: userId)
            .execute()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return providerRequests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderRequestCell", for: indexPath)
        let item = providerRequests[indexPath.row]

        cell.selectionStyle = .none

        if let avatarImageView = cell.viewWithTag(5) as? UIImageView {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = UIColor.systemGray3
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
        }

        if let nameLabel = cell.viewWithTag(1) as? UILabel {
            nameLabel.text = item.name
        }

        if let dateLabel = cell.viewWithTag(2) as? UILabel {
            dateLabel.text = item.requestedAtText
        }

        if let approveButton = cell.viewWithTag(3) as? UIButton {
            approveButton.tag = indexPath.row
            approveButton.removeTarget(nil, action: nil, for: .allEvents)
            approveButton.addTarget(self, action: #selector(didTapApprove(_:)), for: .touchUpInside)

            approveButton.setTitle("Approve", for: .normal)
            approveButton.backgroundColor = UIColor(named: "AccentColor") ?? UIColor.systemGreen
            approveButton.setTitleColor(.white, for: .normal)
            approveButton.layer.cornerRadius = 8
            approveButton.clipsToBounds = true
        }

        if let rejectButton = cell.viewWithTag(4) as? UIButton {
            rejectButton.tag = indexPath.row
            rejectButton.removeTarget(nil, action: nil, for: .allEvents)
            rejectButton.addTarget(self, action: #selector(didTapReject(_:)), for: .touchUpInside)

            rejectButton.setTitle("Reject", for: .normal)
            rejectButton.backgroundColor = UIColor.systemGray5
            rejectButton.setTitleColor(.systemRed, for: .normal)
            rejectButton.layer.cornerRadius = 8
            rejectButton.clipsToBounds = true
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard providerRequests.indices.contains(indexPath.row) else { return }
        let item = providerRequests[indexPath.row]
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
            id: 0,
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
                    try await self.updateApplicationStatus(id: item.applicationId, status: "accepted")
                    try await self.updateUserRole(userId: item.userId, role: "provider")
                    try await self.updateProviderStatus(userId: item.userId, status: "active")
                    await AdminLogService.shared.log(
                        action: "Approved provider application",
                        targetUserId: item.userId,
                        metadata: ["application_id": String(item.applicationId)]
                    )
                    await MainActor.run {
                        guard self.providerRequests.indices.contains(selectedIndex) else { return }
                        self.providerRequests.remove(at: selectedIndex)
                        self.providerRequestsTableView.reloadData()
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
                    try await self.updateApplicationStatus(id: item.applicationId, status: "rejected")
                    try await self.updateUserRole(userId: item.userId, role: "seeker")
                    try await self.updateProviderStatus(userId: item.userId, status: "active")
                    await AdminLogService.shared.log(
                        action: "Rejected provider application",
                        targetUserId: item.userId,
                        metadata: ["application_id": String(item.applicationId)]
                    )
                    await MainActor.run {
                        guard self.providerRequests.indices.contains(selectedIndex) else { return }
                        self.providerRequests.remove(at: selectedIndex)
                        self.providerRequestsTableView.reloadData()
                    }
                } catch {
                    print("Reject error:", error.localizedDescription)
                }
            }
        }
        navigationController?.pushViewController(providerRequestVC, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }

    @objc private func didTapApprove(_ sender: UIButton) {
        let index = sender.tag
        guard providerRequests.indices.contains(index) else { return }
        let item = providerRequests[index]

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.updateApplicationStatus(id: item.applicationId, status: "accepted")
                try await self.updateUserRole(userId: item.userId, role: "provider")
                try await self.updateProviderStatus(userId: item.userId, status: "active")
                await AdminLogService.shared.log(
                    action: "Approved provider application",
                    targetUserId: item.userId,
                    metadata: ["application_id": String(item.applicationId)]
                )
                await MainActor.run {
                    self.providerRequests.remove(at: index)
                    self.providerRequestsTableView.reloadData()
                    let alert = UIAlertController(title: "Provider Approved",
                                                  message: "You have successfully approved \(item.name).",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            } catch {
                print("Approve error:", error.localizedDescription)
            }
        }
    }

    @objc private func didTapReject(_ sender: UIButton) {
        let index = sender.tag
        guard providerRequests.indices.contains(index) else { return }
        let item = providerRequests[index]

        let alert = UIAlertController(title: "Reject Provider",
                                      message: "Are you sure you want to reject \(item.name)?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            Task {
                do {
                    try await self.updateApplicationStatus(id: item.applicationId, status: "rejected")
                    try await self.updateUserRole(userId: item.userId, role: "seeker")
                    try await self.updateProviderStatus(userId: item.userId, status: "active")
                    await AdminLogService.shared.log(
                        action: "Rejected provider application",
                        targetUserId: item.userId,
                        metadata: ["application_id": String(item.applicationId)]
                    )
                    await MainActor.run {
                        guard self.providerRequests.indices.contains(index) else { return }
                        self.providerRequests.remove(at: index)
                        self.providerRequestsTableView.reloadData()
                    }
                } catch {
                    print("Reject error:", error.localizedDescription)
                }
            }
        }))
        present(alert, animated: true)
    }
}
