//
//  ServiceDetailsViewController.swift
//  welink
//
//  Created by Zahra on 19/12/2025.
//

import UIKit
import Supabase

class ServiceDetailsViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var serviceImageView: UIImageView!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var providerNameLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var reviewsTableView: UITableView!
    @IBOutlet weak var messageButton: UIButton!
    @IBOutlet weak var bookNowButton: UIButton!
    @IBOutlet weak var reviewsTableViewHeight: NSLayoutConstraint!
    
    // MARK: - Properties
    var service: SeekerSearchResult? // Holds the service data passed from Search/Home/Category
    var serviceId: String? // Or just pass the ID
    
    private var ratings: [ServiceRating] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDateTimeTapGestures()
        setupReviewsTableView()
        
        if let service = service {
            // Service data was passed directly
            displayServiceData(service)
            fetchRatings(serviceId: service.id)
        } else if let serviceId = serviceId {
            // Only ID was passed, fetch full details
            fetchServiceDetails(serviceId: serviceId)
        } else {
            // No data provided - show error
            showError(message: "No service data available")
        }
    }
    
    // MARK: - Hides the tab bar when viewing service details
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
    }
    
    // MARK: - Setup Reviews Table View
    func setupReviewsTableView() {
        reviewsTableView.delegate = self
        reviewsTableView.dataSource = self
        reviewsTableView.rowHeight = UITableView.automaticDimension
        reviewsTableView.estimatedRowHeight = 100
        reviewsTableView.isScrollEnabled = false  // Fixed height, no scroll
    }
    
    // MARK: - Database Functions
    func fetchServiceDetails(serviceId: String) {
        Task {
            do {
                // Fetch service with provider info
                let response: ServiceWithUser = try await SupabaseClientManager.shared.client
                    .database
                    .from("services")
                    .select("*, users(name, image)")
                    .eq("id", value: serviceId)
                    .single()
                    .execute()
                    .value
                
                // Convert to SeekerSearchResult
                let service = SeekerSearchResult(
                    id: response.id,
                    name: response.name,
                    description: response.description,
                    pricePerHour: response.price_per_hour,
                    image: response.image,
                    userId: response.user_id,
                    providerName: response.users?.name,
                    providerImage: response.users?.image
                )
                
                self.service = service
                
                // Fetch ratings
                await fetchRatings(serviceId: serviceId)
                
                // Update UI
                await MainActor.run {
                    self.displayServiceData(service)
                }
                
            } catch {
                print("❌ Error fetching service details: \(error)")
                await MainActor.run {
                    self.showError(message: "Failed to load service details")
                }
            }
        }
    }
    
    func updateReviewsTableHeight() {
        reviewsTableView.layoutIfNeeded()
        
        DispatchQueue.main.async {
            self.reviewsTableViewHeight.constant =
                self.reviewsTableView.contentSize.height
            self.view.layoutIfNeeded()
        }
    }
    
    func fetchRatings(serviceId: String) {
        Task {
            do {
                // Fetch ratings with user info
                let response: [RatingWithUser] = try await SupabaseClientManager.shared.client
                    .database
                    .from("ratings")
                    .select("*, users(name, image)")
                    .eq("service_id", value: serviceId)
                    .order("created_at", ascending: false) 
                    .execute()
                    .value
                
                // Convert to ServiceRating
                self.ratings = response.map { rating in
                    var serviceRating = ServiceRating(
                        id: rating.id,
                        serviceId: rating.service_id,
                        userId: rating.user_id,
                        reviewContent: rating.review_content,
                        starsCount: rating.stars_count,
                        createdAt: rating.created_at
                    )
                    serviceRating.userName = rating.users?.name
                    serviceRating.userImage = rating.users?.image
                    return serviceRating
                }
                
                await MainActor.run {
                    self.updateRatingDisplay()
                }
                
            } catch {
                print("❌ Error fetching ratings: \(error)")
            }
        }
    }
    
    // MARK: - Display Functions
    func displayServiceData(_ service: SeekerSearchResult) {
        // Set service name as title
        self.title = service.name
        
        // Set provider name
        providerNameLabel.text = service.providerName ?? "Unknown Provider"
        
        // Set description
        descriptionLabel.text = service.description
        
        // Set price
        priceLabel.text = String(format: "%.0f BD/hr", service.pricePerHour)
        
        // Load service image
        if let imageUrl = service.image {
            loadImage(from: imageUrl, into: serviceImageView)
        } else {
            serviceImageView.backgroundColor = .systemPink
        }
        
        // Setup provider profile image
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        
        // Try to load provider's actual image first
        if let providerImageUrl = service.providerImage,
           let url = URL(string: providerImageUrl),
           !providerImageUrl.isEmpty {
            // Load image from URL (same as SearchViewController)
            loadProviderImageAsync(from: url, providerName: service.providerName)
        } else {
            // No image URL, show initial
            if let providerName = service.providerName, !providerName.isEmpty {
                let initial = String(providerName.prefix(1)).uppercased()
                profileImageView.image = createInitialImage(text: initial, size: CGSize(width: 60, height: 60))
                profileImageView.contentMode = .scaleAspectFit
            } else {
                profileImageView.image = createInitialImage(text: "?", size: CGSize(width: 60, height: 60))
                profileImageView.contentMode = .scaleAspectFit
            }
        }
        
        // Placeholder for availability
        dateLabel.text = "Available"
        timeLabel.text = "Select time"
        
    }
    
    // Add this new function for loading provider image
    func loadProviderImageAsync(from url: URL, providerName: String?) {
        // Set placeholder first (initial letter)
        if let name = providerName, !name.isEmpty {
            let initial = String(name.prefix(1)).uppercased()
            profileImageView.image = createInitialImage(text: initial, size: CGSize(width: 60, height: 60))
            profileImageView.contentMode = .scaleAspectFit
        } else {
            profileImageView.image = createInitialImage(text: "?", size: CGSize(width: 60, height: 60))
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        // Resize and apply to image view (same as SearchViewController)
                        let resizedImage = self.resizeImage(image: image, targetSize: CGSize(width: 60, height: 60))
                        self.profileImageView.image = resizedImage
                        self.profileImageView.contentMode = .scaleAspectFill
                        self.profileImageView.clipsToBounds = true
                        self.profileImageView.layer.cornerRadius = self.profileImageView.frame.width / 2
                    }
                }
            } catch {
                print("Failed to load provider image: \(error)")
            }
        }
    }

    // Resize image helper
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    func updateRatingDisplay() {
        let averageRating = calculateAverageRating()
        
        if averageRating > 0 {
            let fullStars = Int(round(averageRating))
            let emptyStars = 5 - fullStars
            
            let filledStar = "★"  // Filled star
            let emptyStar = "☆"   // Empty star
            
            let starString = String(repeating: filledStar, count: fullStars) +
                            String(repeating: emptyStar, count: emptyStars)
            
            ratingLabel.text = starString
        } else {
            ratingLabel.text = "☆☆☆☆☆"  // No ratings
        }
        
        // Reload reviews table to show fetched reviews
        reviewsTableView.reloadData()
        
        print("Average rating: \(averageRating)/5")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.updateReviewsTableHeight()
        }
    }
    
    func calculateAverageRating() -> Double {
        guard !ratings.isEmpty else { return 0 }
        let sum = ratings.reduce(0) { $0 + $1.starsCount }
        return Double(sum) / Double(ratings.count)
    }
    
    // MARK: - Date/Time Selection
    func setupDateTimeTapGestures() {
        // Make labels tappable
        dateLabel.isUserInteractionEnabled = true
        timeLabel.isUserInteractionEnabled = true
        
        // Add tap gestures
        let dateTap = UITapGestureRecognizer(target: self, action: #selector(dateLabeltapped))
        dateLabel.addGestureRecognizer(dateTap)
        
        let timeTap = UITapGestureRecognizer(target: self, action: #selector(timeLabeltapped))
        timeLabel.addGestureRecognizer(timeTap)
    }

    @objc func dateLabeltapped() {
        showDatePicker()
    }

    @objc func timeLabeltapped() {
        showTimePicker()
    }

    func showDatePicker() {
        let alert = UIAlertController(title: "Select Date", message: "\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minimumDate = Date() // Can't book in the past
        datePicker.frame = CGRect(x: 0, y: 50, width: alert.view.bounds.width - 20, height: 200)
        
        alert.view.addSubview(datePicker)
        
        let selectAction = UIAlertAction(title: "Select", style: .default) { _ in
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            self.dateLabel.text = formatter.string(from: datePicker.date)
            print("Selected date: \(formatter.string(from: datePicker.date))")
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(selectAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }

    func showTimePicker() {
        let alert = UIAlertController(title: "Select Time", message: "\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        
        let timePicker = UIDatePicker()
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .wheels
        timePicker.frame = CGRect(x: 0, y: 50, width: alert.view.bounds.width - 20, height: 200)
        
        alert.view.addSubview(timePicker)
        
        let selectAction = UIAlertAction(title: "Select", style: .default) { _ in
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            self.timeLabel.text = formatter.string(from: timePicker.date)
            print("Selected time: \(formatter.string(from: timePicker.date))")
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(selectAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func loadImage(from urlString: String, into imageView: UIImageView) {
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        imageView.image = image
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }

    func createInitialImage(text: String, size: CGSize = CGSize(width: 60, height: 60)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Light gray circle
            UIColor(hex: "D9D9D9").setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Dark green text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width / 2, weight: .medium),
                .foregroundColor: UIColor(hex: "2D493A")
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {

        let isLast = indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1

        if isLast {
            cell.separatorInset = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: 0,
                right: .greatestFiniteMagnitude
            )
        } else {
            cell.separatorInset = .zero
        }
    }


    func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    @IBAction func messageButtonTapped(_ sender: UIButton) {
        print("Message button tapped")
        guard let userId = service?.userId else { return }
        // TODO: Navigate to messaging screen with provider
    }
    
    @IBAction func bookNowButtonTapped(_ sender: UIButton) {
        print("Book Now button tapped")
        guard let service = service else { return }
        // TODO: Navigate to booking screen
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension ServiceDetailsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Show maximum 2 reviews (the latest ones)
        return min(ratings.count, 2)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell", for: indexPath) as? ReviewTableViewCell else {
            return UITableViewCell()
        }
        
        let rating = ratings[indexPath.row]
        cell.configure(with: rating)
        cell.selectionStyle = .none  // No selection highlight
        
        return cell
    }
}
