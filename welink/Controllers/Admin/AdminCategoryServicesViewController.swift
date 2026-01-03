import UIKit
import Supabase

final class AdminCategoryServicesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!

    var categoryName: String = ""

    private struct ServiceRow: Decodable {
        let id: String
        let name: String
        let description: String?
        let price_per_hour: Double?
        let image: String?
        let created_at: String?
        let user_id: String?
        let categories: [String]?
        let start_date: String?
        let end_date: String?
        let users: UserInfo?

        struct UserInfo: Decodable {
            let name: String
            let image: String?
        }
    }

    private struct ServiceItem {
        let id: String
        let title: String
        let subtitle: String
        let priceText: String
        let description: String
        let ratingText: String
        let imageURLString: String?
    }

    private static let imageCache = NSCache<NSString, UIImage>()

    private var items: [ServiceItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = categoryName.isEmpty ? "Services" : categoryName

        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        tableView.rowHeight = 92
        tableView.estimatedRowHeight = 92

        Task { [weak self] in
            await self?.loadServices()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.visibleCells.forEach { cell in
            if let avatarImageView = cell.viewWithTag(3) as? UIImageView {
                avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
                avatarImageView.layer.masksToBounds = true
            }
        }
    }

    private func loadServices() async {
        let client = SupabaseClientManager.shared.client

        do {
            var query = client.database
                .from("services")
                .select("""
                    id,
                    name,
                    description,
                    price_per_hour,
                    image,
                    created_at,
                    user_id,
                    categories,
                    start_date,
                    end_date,
                    users!services_user_id_fkey(name, image)
                """)

            if !categoryName.isEmpty {
                query = query.contains("categories", value: [categoryName])
            }

            let rows: [ServiceRow] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value

            let serviceIDs: [String] = rows.map { $0.id }
            let ratingsByServiceID = await loadAverageRatings(serviceIDs: serviceIDs)

            let mapped: [ServiceItem] = rows.map {
                let providerName = $0.users?.name ?? "Unknown Provider"
                let descriptionText = ($0.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let safeDescription = descriptionText.isEmpty ? "No description" : descriptionText
                let priceValue = $0.price_per_hour ?? 0

                let imageURLString = $0.image ?? $0.users?.image

                let ratingText: String
                if let avg = ratingsByServiceID[$0.id] {
                    ratingText = String(format: "%.1f", avg)
                } else {
                    ratingText = "0.0"
                }
                return ServiceItem(
                    id: $0.id,
                    title: $0.name,
                    subtitle: providerName,
                    priceText: "BD \(Int(priceValue))/hr",
                    description: safeDescription,
                    ratingText: ratingText,
                    imageURLString: imageURLString
                )
            }

            await MainActor.run {
                self.items = mapped
                self.tableView.reloadData()
            }
        } catch {
            print("Error loading category services:", error.localizedDescription)
            await MainActor.run {
                self.items = []
                self.tableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AdminServiceCell", for: indexPath)
        let item = items[indexPath.row]

        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        if let titleLabel = cell.viewWithTag(1) as? UILabel {
            titleLabel.text = item.title
        }

        if let subtitleLabel = cell.viewWithTag(2) as? UILabel {
            subtitleLabel.text = "\(item.subtitle) - \(item.priceText)\n\(item.description)"
            subtitleLabel.numberOfLines = 2
        }

        if let ratingLabel = cell.viewWithTag(4) as? UILabel {
            ratingLabel.text = item.ratingText
        }

        if let avatarImageView = cell.viewWithTag(3) as? UIImageView {
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.backgroundColor = UIColor.systemGray5
            avatarImageView.image = nil
            avatarImageView.layer.masksToBounds = true

            DispatchQueue.main.async {
                avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
                avatarImageView.layer.masksToBounds = true
            }

            if let urlString = item.imageURLString {
                if let normalized = normalizedURL(from: urlString) {
                    let expectedKey = String(describing: normalized.cacheKey)
                    avatarImageView.accessibilityIdentifier = expectedKey

                    loadImage(urlString: urlString) { [weak avatarImageView] image in
                        guard let avatarImageView else { return }
                        guard avatarImageView.accessibilityIdentifier == expectedKey else { return }
                        avatarImageView.image = image
                        DispatchQueue.main.async {
                            avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
                            avatarImageView.layer.masksToBounds = true
                        }
                    }
                } else {
                    avatarImageView.accessibilityIdentifier = nil
                }
            }
        }

        return cell
    }

    private func normalizedURL(from raw: String) -> (url: URL, cacheKey: NSString)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var candidate = trimmed

        // Supabase storage values may be saved as relative paths like:
        // - profiles/<id>.jpg
        // - applications/<id>.jpg
        // - images/profiles/<id>.jpg
        // Convert these to a full public URL.
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            let base = "https://mjzyqwziqqhcdrdadfpc.supabase.co/storage/v1/object/public/"
            let cleaned = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if cleaned.lowercased().hasPrefix("images/") {
                candidate = base + cleaned
            } else if cleaned.lowercased().hasPrefix("profiles/") || cleaned.lowercased().hasPrefix("applications/") {
                candidate = base + "images/" + cleaned
            }
        }

        if candidate.hasPrefix("//") {
            candidate = "https:" + candidate
        }
        if !(candidate.lowercased().hasPrefix("http://") || candidate.lowercased().hasPrefix("https://")) {
            candidate = "https://" + candidate
        }

        let encoded = candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? candidate
        guard let url = URL(string: encoded),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return (url, encoded as NSString)
    }

    private func loadImage(urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let normalized = normalizedURL(from: urlString) else {
            print("[AdminServices] Invalid image URL string:", urlString)
            completion(nil)
            return
        }

        let key = normalized.cacheKey
        if let cached = Self.imageCache.object(forKey: key) {
            completion(cached)
            return
        }

        let url = normalized.url

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                if let image {
                    Self.imageCache.setObject(image, forKey: key)
                }
                await MainActor.run { completion(image) }
            } catch {
                print("[AdminServices] Image load failed:", String(describing: key), url.absoluteString, error.localizedDescription)
                await MainActor.run { completion(nil) }
            }
        }
    }

    private struct RatingRow: Decodable {
        let service_id: String?
        let stars_count: Int?
    }

    private func loadAverageRatings(serviceIDs: [String]) async -> [String: Double] {
        guard !serviceIDs.isEmpty else { return [:] }

        let client = SupabaseClientManager.shared.client
        do {
            let rows: [RatingRow] = try await client.database
                .from("ratings")
                .select("service_id, stars_count")
                .in("service_id", value: serviceIDs)
                .execute()
                .value

            var sums: [String: (sum: Int, count: Int)] = [:]
            for row in rows {
                guard let serviceID = row.service_id else { continue }
                let stars = row.stars_count ?? 0
                if var existing = sums[serviceID] {
                    existing.sum += stars
                    existing.count += 1
                    sums[serviceID] = existing
                } else {
                    sums[serviceID] = (stars, 1)
                }
            }

            var averages: [String: Double] = [:]
            for (serviceID, value) in sums {
                guard value.count > 0 else { continue }
                averages[serviceID] = Double(value.sum) / Double(value.count)
            }
            return averages
        } catch {
            print("Error loading ratings:", error.localizedDescription)
            return [:]
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        92
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }

        let item = items[indexPath.row]
        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AdminServiceDetailsVC")
        guard let detailsVC = vc as? AdminServiceDetailsViewController else {
            let alert = UIAlertController(
                title: "Setup Error",
                message: "Admin serviceDetails scene is not using AdminServiceDetailsViewController. Please set the scene custom class and storyboard ID in AdminDashboard.storyboard.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        detailsVC.serviceId = item.id
        navigationController?.pushViewController(detailsVC, animated: true)
    }
}
