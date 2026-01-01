//
//  AdminSeekersListViewController.swift
//  welink
//
//  Created by rawan on 01/01/2026.
//
import UIKit
import Supabase

final class AdminSeekersListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!

    private struct SeekerRow: Decodable {
        let id: String
        let name: String
        let phone: String
        let image: String?
        let created_at: String?
        let role: String?
        let status: String?
    }

    private struct SeekerItem {
        let id: String
        let name: String
        let phone: String
        let createdAtText: String
        let imageURLString: String?
        let status: String
    }

    private static let imageCache = NSCache<NSString, UIImage>()

    private let rowHeight: CGFloat = 112

    private var allItems: [SeekerItem] = []
    private var filteredItems: [SeekerItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Seekers"

        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self

        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemBackground
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        tableView.rowHeight = rowHeight
        tableView.estimatedRowHeight = rowHeight

        Task { [weak self] in
            await self?.loadSeekers()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.loadSeekers()
        }
    }

    private func loadSeekers() async {
        let client = SupabaseClientManager.shared.client

        do {
            let rows: [SeekerRow] = try await client.database
                .from("users")
                .select("id, name, phone, image, created_at, role, status")
                .eq("role", value: "seeker")
                .order("created_at", ascending: false)
                .execute()
                .value

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US_POSIX")
            displayFormatter.dateStyle = .medium

            let postgresFormatter = DateFormatter()
            postgresFormatter.locale = Locale(identifier: "en_US_POSIX")
            postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"

            let postgresFormatterNoFrac = DateFormatter()
            postgresFormatterNoFrac.locale = Locale(identifier: "en_US_POSIX")
            postgresFormatterNoFrac.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

            let mapped: [SeekerItem] = rows.map { row in
                let createdAtText: String
                if let createdAt = row.created_at,
                   let date = isoFormatter.date(from: createdAt)
                        ?? postgresFormatter.date(from: createdAt)
                        ?? postgresFormatterNoFrac.date(from: createdAt) {
                    createdAtText = "Joined: \(displayFormatter.string(from: date))"
                } else {
                    if let createdAt = row.created_at, createdAt.count >= 10 {
                        createdAtText = "Joined: \(String(createdAt.prefix(10)))"
                    } else {
                        createdAtText = ""
                    }
                }

                return SeekerItem(
                    id: row.id,
                    name: row.name,
                    phone: row.phone,
                    createdAtText: createdAtText,
                    imageURLString: row.image,
                    status: (row.status?.isEmpty == false) ? (row.status ?? "active") : "active"
                )
            }

            await MainActor.run {
                self.allItems = mapped
                self.applyFilter(text: self.searchBar.text)
            }
        } catch {
            print("Error loading seekers:", error.localizedDescription)
            await MainActor.run {
                self.allItems = []
                self.applyFilter(text: self.searchBar.text)
            }
        }
    }

    private func applyFilter(text: String?) {
        let q = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.phone.localizedCaseInsensitiveContains(q)
            }
        }
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter(text: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeight
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderCell", for: indexPath)
        let item = filteredItems[indexPath.row]

        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        if let nameLabel = cell.contentView.viewWithTag(1) as? UILabel {
            nameLabel.text = item.name
            nameLabel.textColor = (item.status.lowercased() == "suspended") ? .systemRed : .label
        }

        if let subtitleLabel = cell.contentView.viewWithTag(2) as? UILabel {
            if item.status.lowercased() == "suspended" {
                subtitleLabel.text = item.createdAtText.isEmpty ? "Suspended" : "Suspended • \(item.createdAtText)"
            } else {
                subtitleLabel.text = item.createdAtText
            }
            subtitleLabel.textColor = .secondaryLabel
        }

        if let avatarImageView = cell.contentView.viewWithTag(3) as? UIImageView {
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.backgroundColor = UIColor.systemGray5
            avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
            avatarImageView.layer.masksToBounds = true
            avatarImageView.image = nil

            if let urlString = item.imageURLString {
                loadImage(urlString: urlString) { [weak tableView] image in
                    guard let tableView else { return }
                    if let currentCell = tableView.cellForRow(at: indexPath), currentCell === cell {
                        avatarImageView.image = image
                        avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
                    }
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard filteredItems.indices.contains(indexPath.row) else { return }

        let item = filteredItems[indexPath.row]
        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AdminSeekerDetailsVC")
        guard let detailsVC = vc as? AdminSeekerDetailsViewController else {
            let alert = UIAlertController(
                title: "Setup Error",
                message: "Seeker details scene is not using AdminSeekerDetailsViewController. Please set the scene custom class and storyboard ID in AdminDashboard.storyboard.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        detailsVC.seekerId = item.id
        navigationController?.pushViewController(detailsVC, animated: true)
    }

    private func loadImage(urlString: String, completion: @escaping (UIImage?) -> Void) {
        let key = urlString as NSString
        if let cached = Self.imageCache.object(forKey: key) {
            completion(cached)
            return
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                if let image {
                    Self.imageCache.setObject(image, forKey: key)
                }
                await MainActor.run { completion(image) }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }
}
