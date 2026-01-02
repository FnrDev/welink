import UIKit
import Supabase

// MARK: - Models
struct Service: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let price_per_hour: Double?
    let image: String?
    let user_id: UUID?
}

struct Booking: Decodable {
    let id: UUID
    let service_id: UUID?
    let created_at: String?
    let booked_date: String?
    let status: String?

    var createdAtDate: Date? {
        guard let dateString = created_at else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try simple format for timestamp without time zone
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        simpleFormatter.timeZone = TimeZone(identifier: "UTC")
        return simpleFormatter.date(from: dateString)
    }

    var bookedDateValue: Date? {
        guard let dateString = booked_date else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        simpleFormatter.timeZone = TimeZone(identifier: "UTC")
        return simpleFormatter.date(from: dateString)
    }
}

struct UserProfile: Decodable {
    let id: UUID
    let name: String
}

struct ServiceWithProvider: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let price_per_hour: Double?
    let image: String?
    let user_id: UUID?
    let users: UserProfile?
}

struct Rating: Decodable {
    let service_id: UUID?
    let stars_count: Int?
}

class ProviderDashboardViewController: UIViewController {
    
    @IBOutlet weak var backBTN: UIBarButtonItem!
    @IBOutlet weak var todayBookingsField: UILabel!
    @IBOutlet weak var todayReveune: UILabel!
    @IBOutlet weak var totalBookingField: UILabel!
    @IBOutlet weak var totalReveune: UILabel!
    @IBOutlet weak var servicesTableView: UITableView!
    
    private var myServices: [ServiceWithProvider] = []
    private var serviceRatings: [UUID: Double] = [:]
    
    // Loading UI
    private let loadingContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading services..."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Empty state UI
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No services yet.\nTap 'New Service' to create one."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        todayBookingsField.text = "0"
        todayReveune.text = "0"
        totalBookingField.text = "0"
        totalReveune.text = "0"
        
        setupTableView()
        setupLoadingView()

        // Connect the custom button inside barButtonItem to the action
        if let customButton = backBTN.customView as? UIButton {
            customButton.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDashboard),
            name: NSNotification.Name("RefreshProviderDashboard"),
            object: nil
        )
        
        Task {
            await loadDashboard()
            await loadMyServices()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Back Button Action

    @IBAction func backButtonTapped(_ sender: UIBarButtonItem) {
        navigateBack()
    }

    @objc private func backButtonAction() {
        navigateBack()
    }

    private func navigateBack() {
        // Restore the main tab bar controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let tabBarController = storyboard.instantiateViewController(withIdentifier: "SeekerTabController") as? UITabBarController else {
            return
        }

        // Switch to Profile tab (usually the last tab)
        tabBarController.selectedIndex = (tabBarController.viewControllers?.count ?? 1) - 1

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    @objc private func refreshDashboard() {
        Task {
            await loadDashboard()
            await loadMyServices()
        }
    }
    
    private func setupTableView() {
        servicesTableView.delegate = self
        servicesTableView.dataSource = self
        servicesTableView.register(ServiceTableViewCell.self, forCellReuseIdentifier: "ServiceCell")
        servicesTableView.rowHeight = 80
        servicesTableView.separatorStyle = .none
    }
    
    private func setupLoadingView() {
        view.addSubview(loadingContainer)
        loadingContainer.addSubview(activityIndicator)
        loadingContainer.addSubview(loadingLabel)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: servicesTableView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: servicesTableView.centerYAnchor),
            
            activityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: servicesTableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: servicesTableView.centerYAnchor)
        ])
    }
    
    private func showLoading() {
        loadingContainer.isHidden = false
        activityIndicator.startAnimating()
        emptyStateLabel.isHidden = true
        servicesTableView.isHidden = true
    }
    
    private func hideLoading() {
        loadingContainer.isHidden = true
        activityIndicator.stopAnimating()
        
        if myServices.isEmpty {
            emptyStateLabel.isHidden = false
            servicesTableView.isHidden = true
        } else {
            emptyStateLabel.isHidden = true
            servicesTableView.isHidden = false
        }
    }
    
    private func loadMyServices() async {
        await MainActor.run {
            showLoading()
        }
        
        let client = SupabaseClientManager.shared.client
        guard let session = try? await client.auth.session else {
            print("No user logged in")
            await MainActor.run {
                hideLoading()
            }
            return
        }
        let userId = session.user.id
        
        do {
            let services: [ServiceWithProvider] = try await client.database
                .from("services")
                .select("id, name, description, price_per_hour, image, user_id, users(id, name)")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(3)
                .execute()
                .value
            
            let serviceIds = services.map { $0.id.uuidString }
            if !serviceIds.isEmpty {
                let ratings: [Rating] = try await client.database
                    .from("ratings")
                    .select("service_id, stars_count")
                    .in("service_id", value: serviceIds)
                    .execute()
                    .value
                
                var ratingsDict: [UUID: [Int]] = [:]
                for rating in ratings {
                    if let serviceId = rating.service_id, let stars = rating.stars_count {
                        ratingsDict[serviceId, default: []].append(stars)
                    }
                }
                
                for (serviceId, stars) in ratingsDict {
                    let average = Double(stars.reduce(0, +)) / Double(stars.count)
                    serviceRatings[serviceId] = average
                }
            }
            
            await MainActor.run {
                self.myServices = services
                self.servicesTableView.reloadData()
                self.hideLoading()
            }
        } catch {
            print("Error loading services:", error.localizedDescription)
            await MainActor.run {
                hideLoading()
            }
        }
    }
    
    private func loadDashboard() async {
        let client = SupabaseClientManager.shared.client
        guard let session = try? await client.auth.session else {
            print("No user logged in")
            return
        }
        let userId = session.user.id
        
        do {
            let services: [Service] = try await client.database
                .from("services")
                .select("id, name, description, price_per_hour, image, user_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            let serviceIds = services.map { $0.id.uuidString }
            
            var bookings: [Booking] = []
            if !serviceIds.isEmpty {
                bookings = try await client.database
                    .from("bookings")
                    .select("id, service_id, created_at, booked_date, status")
                    .in("service_id", value: serviceIds)
                    .execute()
                    .value
            }
            
            let totalBookings = bookings.count
            
            let totalRevenue = bookings.reduce(0.0) { sum, booking in
                if let serviceId = booking.service_id,
                   let service = services.first(where: { $0.id == serviceId }) {
                    return sum + (service.price_per_hour ?? 0)
                }
                return sum
            }
            
            let today = Calendar.current.startOfDay(for: Date())
            let todaysBookings = bookings.filter {
                guard let created = $0.createdAtDate else { return false }
                return created >= today
            }
            
            let todaysRevenue = todaysBookings.reduce(0.0) { sum, booking in
                if let serviceId = booking.service_id,
                   let service = services.first(where: { $0.id == serviceId }) {
                    return sum + (service.price_per_hour ?? 0)
                }
                return sum
            }
            
            await MainActor.run {
                totalBookingField.text = "\(totalBookings)"
                totalReveune.text = formatCurrency(totalRevenue)
                todayBookingsField.text = "\(todaysBookings.count)"
                todayReveune.text = formatCurrency(todaysRevenue)
            }
            
        } catch {
            print("Dashboard load error:", error.localizedDescription)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value == 0 { return "0" }
        return "BD " + String(format: "%.2f", value)
    }
    
    @IBAction func seeAllButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let searchVC = storyboard.instantiateViewController(withIdentifier: "SearchVC") as? SearchViewController else {
            print("Could not instantiate SearchViewController")
            return
        }
        searchVC.showAllOnLoad = true
        searchVC.showOnlyUserServices = true

        let navVC = UINavigationController(rootViewController: searchVC)
        navVC.modalPresentationStyle = .pageSheet

        if let sheet = navVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        present(navVC, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension ProviderDashboardViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return myServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ServiceCell", for: indexPath) as! ServiceTableViewCell
        let service = myServices[indexPath.row]
        let rating = serviceRatings[service.id]
        cell.configure(with: service, rating: rating)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let service = myServices[indexPath.row]
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
            return
        }
        vc.serviceId = service.id.uuidString
        if let navController = navigationController {
            navController.pushViewController(vc, animated: true)
        } else {
            let navVC = UINavigationController(rootViewController: vc)
            navVC.modalPresentationStyle = .fullScreen
            present(navVC, animated: true)
        }
    }
}

// MARK: - Custom Table View Cell
class ServiceTableViewCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let serviceImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 1.0)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "W."
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let providerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let starImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "star.fill")
        iv.tintColor = .systemGray
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(containerView)
        containerView.addSubview(serviceImageView)
        serviceImageView.addSubview(logoLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(providerLabel)
        containerView.addSubview(starImageView)
        containerView.addSubview(ratingLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            serviceImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            serviceImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            serviceImageView.widthAnchor.constraint(equalToConstant: 50),
            serviceImageView.heightAnchor.constraint(equalToConstant: 50),
            
            logoLabel.centerXAnchor.constraint(equalTo: serviceImageView.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: serviceImageView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: serviceImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: starImageView.leadingAnchor, constant: -16),
            
            providerLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            providerLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            providerLabel.trailingAnchor.constraint(lessThanOrEqualTo: starImageView.leadingAnchor, constant: -16),
            
            starImageView.trailingAnchor.constraint(equalTo: ratingLabel.leadingAnchor, constant: -4),
            starImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            starImageView.widthAnchor.constraint(equalToConstant: 14),
            starImageView.heightAnchor.constraint(equalToConstant: 14),
            
            ratingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            ratingLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            ratingLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }
    
    func configure(with service: ServiceWithProvider, rating: Double?) {
        titleLabel.text = service.name
        let name = service.users?.name ?? "Your Service"
        let price = service.price_per_hour ?? 0
        providerLabel.text = "\(name) - BD\(Int(price)) /hr"
        ratingLabel.text = String(format: "%.1f", rating ?? 0.0)
        
        if let imageURLString = service.image,
           !imageURLString.isEmpty,
           let url = URL(string: imageURLString) {
            loadImage(from: url)
        } else {
            serviceImageView.image = nil
            logoLabel.isHidden = false
        }
    }
    
    private func loadImage(from url: URL) {
        logoLabel.isHidden = true
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.serviceImageView.image = image
                    self?.logoLabel.isHidden = true
                }
            } else {
                DispatchQueue.main.async {
                    self?.logoLabel.isHidden = false
                }
            }
        }.resume()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        serviceImageView.image = nil
        logoLabel.isHidden = false
    }
}
