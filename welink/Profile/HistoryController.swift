//
//  HistoryController.swift
//  welink
//
//  Created by Ali Matar on 23/12/2025.
//

import UIKit

// Struct to decode booking with service details
struct HistoryBookingData: Decodable {
    let id: String
    let serviceId: String
    let serviceName: String
    let serviceImage: String?
    let price: Double
    let createdAt: String
    let providerName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceId = "service_id"
        case createdAt = "created_at"
        case service
    }
    
    enum ServiceKeys: String, CodingKey {
        case name
        case image
        case price_per_hour
        case users
    }
    
    enum UserKeys: String, CodingKey {
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        serviceId = try container.decode(String.self, forKey: .serviceId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        let serviceContainer = try container.nestedContainer(keyedBy: ServiceKeys.self, forKey: .service)
        serviceName = try serviceContainer.decode(String.self, forKey: .name)
        serviceImage = try serviceContainer.decodeIfPresent(String.self, forKey: .image)
        price = try serviceContainer.decodeIfPresent(Double.self, forKey: .price_per_hour) ?? 0
        
        // Try to get provider name from nested users
        if let usersContainer = try? serviceContainer.nestedContainer(keyedBy: UserKeys.self, forKey: .users) {
            providerName = try usersContainer.decodeIfPresent(String.self, forKey: .name)
        } else {
            providerName = nil
        }
    }
}

// Struct to decode ratings
struct RatingData: Decodable {
    let id: String
    let service_id: String
    let user_id: String
    let review_content: String?
    let stars_count: Int
}

// Struct to create rating
struct CreateRatingRequest: Encodable {
    let service_id: String
    let user_id: String
    let review_content: String
    let stars_count: Int
}

class HistoryController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var noHistoryLabel: UILabel!
    
    private var historyBookings: [HistoryBookingData] = []
    private var filteredBookings: [HistoryBookingData] = []
    private var userRatings: [String: RatingData] = [:] // serviceId: RatingData
    private var currentUserId: String = ""
    private var isSearching: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the programmatic navigation bar (keep Storyboard one)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupUI()
        setupTableView()
        setupSearchBar()
        fetchHistory()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        noHistoryLabel?.isHidden = true
        noHistoryLabel?.text = "No booking history found."
    }
    
    // MARK: - Setup Table View
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        let nib = UINib(nibName: "HistoryCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "HistoryCell")
        tableView.rowHeight = 160
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
    }
    
    // MARK: - Setup Search Bar
    
    private func setupSearchBar() {
        searchBar?.delegate = self
    }
    
    // MARK: - Fetch History
    
    private func fetchHistory() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                currentUserId = session.user.id.uuidString
                
                // Fetch bookings with service details (removed rating)
                let bookings: [HistoryBookingData] = try await SupabaseClientManager.shared.client.database
                    .from("bookings")
                    .select("id, service_id, created_at, service:services(name, image, price_per_hour, users(name))")
                    .eq("user_id", value: currentUserId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                // Fetch user's ratings
                let ratings: [RatingData] = try await SupabaseClientManager.shared.client.database
                    .from("ratings")
                    .select()
                    .eq("user_id", value: currentUserId)
                    .execute()
                    .value
                
                // Create dictionary of ratings by service_id
                var ratingsDict: [String: RatingData] = [:]
                for rating in ratings {
                    ratingsDict[rating.service_id] = rating
                }
                
                await MainActor.run {
                    historyBookings = bookings
                    filteredBookings = bookings
                    userRatings = ratingsDict
                    
                    if bookings.isEmpty {
                        tableView.isHidden = true
                        noHistoryLabel?.isHidden = false
                    } else {
                        tableView.isHidden = false
                        noHistoryLabel?.isHidden = true
                        tableView.reloadData()
                    }
                }
                
            } catch {
                print("Error fetching history: \(error)")
                await MainActor.run {
                    tableView.isHidden = true
                    noHistoryLabel?.isHidden = false
                    noHistoryLabel?.text = "Failed to load history."
                }
            }
        }
    }
    
    // MARK: - Show Feedback Dialog
    
    private func showFeedbackDialog(bookingId: String, serviceId: String, serviceName: String) {
        if let existingRating = userRatings[serviceId] {
            showViewFeedbackAlert(rating: existingRating, serviceName: serviceName)
        } else {
            navigateToFeedback(serviceId: serviceId, serviceName: serviceName)
        }
    }
    
    // MARK: - Navigate to Feedback Controller
    
    private func navigateToFeedback(serviceId: String, serviceName: String) {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        
        guard let feedbackVC = storyboard.instantiateViewController(withIdentifier: "hitsoryFeedBack") as? HistoryFeedBackController else {
            print("DEBUG: Failed to instantiate HistoryFeedBackController")
            return
        }
        
        feedbackVC.serviceId = serviceId
        feedbackVC.serviceName = serviceName
        feedbackVC.currentUserId = currentUserId
        feedbackVC.delegate = self
        
        // Push to navigation controller
        navigationController?.pushViewController(feedbackVC, animated: true)
    }
    
    // MARK: - Show View Feedback Alert
    
    private func showViewFeedbackAlert(rating: RatingData, serviceName: String) {
        let stars = String(repeating: "⭐", count: rating.stars_count)
        let review = rating.review_content ?? "No review provided"
        
        let alert = UIAlertController(
            title: "Your Feedback for \(serviceName)",
            message: "\(stars)\n\n\(review)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    // MARK: - Show Alert
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Show Toast
    
    func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor(red: 45/255, green: 73/255, blue: 58/255, alpha: 1.0)
        toastLabel.textColor = .white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        toastLabel.text = message
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 20
        toastLabel.clipsToBounds = true
        toastLabel.numberOfLines = 0
        
        let maxWidth = view.frame.width - 40
        let textSize = toastLabel.intrinsicContentSize
        let labelWidth = min(textSize.width + 40, maxWidth)
        
        toastLabel.frame = CGRect(
            x: (view.frame.width - labelWidth) / 2,
            y: view.safeAreaInsets.top + 60,
            width: labelWidth,
            height: 40
        )
        
        view.addSubview(toastLabel)
        
        // Animate in
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            // Animate out after delay
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Back Button Action (Connect in Storyboard)
    
    @IBAction func backButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension HistoryController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? filteredBookings.count : historyBookings.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 12
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        return footerView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as? HistoryCell else {
            return UITableViewCell()
        }
        
        let booking = isSearching ? filteredBookings[indexPath.section] : historyBookings[indexPath.section]
        let hasFeedback = userRatings[booking.serviceId] != nil
        
        cell.configure(
            with: booking,
            hasFeedback: hasFeedback,
            userId: currentUserId,
            providerName: booking.providerName ?? ""
        )
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - HistoryCellDelegate

extension HistoryController: HistoryCellDelegate {
    func didTapFeedbackButton(bookingId: String, serviceId: String, serviceName: String) {
        showFeedbackDialog(bookingId: bookingId, serviceId: serviceId, serviceName: serviceName)
    }
}

// MARK: - HistoryFeedBackDelegate

extension HistoryController: HistoryFeedBackDelegate {
    func didSubmitFeedback(serviceId: String, stars: Int, review: String) {
        let newRating = RatingData(
            id: UUID().uuidString,
            service_id: serviceId,
            user_id: currentUserId,
            review_content: review,
            stars_count: stars
        )
        userRatings[serviceId] = newRating
        tableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate

extension HistoryController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredBookings = historyBookings
        } else {
            isSearching = true
            filteredBookings = historyBookings.filter { booking in
                booking.serviceName.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        isSearching = false
        filteredBookings = historyBookings
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
}
