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
    @IBOutlet weak var seeAllButton: UIButton!
    
    // MARK: - Properties
    var service: SeekerSearchResult? // Holds the service data passed from Search/Home/Category
    var serviceId: String? // Or just pass the ID
    
    private var ratings: [ServiceRating] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDateTimeTapGestures()
        setupReviewsTableView()
        setupCloseButtonIfNeeded()

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

    private func setupCloseButtonIfNeeded() {
        // Add close button if presented modally
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
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
                    providerImage: response.users?.image,
                    startDate: response.start_date,
                    endDate: response.end_date,
                    categories: response.categories
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
    
    func displayServiceData(_ service: SeekerSearchResult) {
        self.title = service.name
        providerNameLabel.text = service.providerName ?? "Unknown Provider"
        descriptionLabel.text = service.description
        priceLabel.text = String(format: "%.0f BD/hr", service.pricePerHour)
        
        // Load service image
        if let imageUrl = service.image {
            loadImage(from: imageUrl, into: serviceImageView)
        } else {
            serviceImageView.backgroundColor = UIColor(hex: "2D493A")
        }
        
        // Setup provider profile image
        profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        
        // Try to load provider's actual image first
        if let providerImageUrl = service.providerImage,
           let url = URL(string: providerImageUrl),
           !providerImageUrl.isEmpty {
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
        
        // Display availability date range
        if let startDate = service.startDate, let endDate = service.endDate {
            // Try multiple date formats
            let dateFormatter = DateFormatter()
            
            // Try format 1: "2025-12-25 02:49:00" 
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            var start = dateFormatter.date(from: startDate)
            var end = dateFormatter.date(from: endDate)
            
            // Try format 2: ISO8601 (if format 1 fails)
            if start == nil || end == nil {
                let iso8601Formatter = ISO8601DateFormatter()
                start = iso8601Formatter.date(from: startDate)
                end = iso8601Formatter.date(from: endDate)
            }
            
            if let start = start, let end = end {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "dd MMM yyyy"
                
                let startString = displayFormatter.string(from: start)
                let endString = displayFormatter.string(from: end)
                
                dateLabel.text = "\(startString) - \(endString)"
                timeLabel.text = "Select time"
            } else {
                dateLabel.text = "Available"
                timeLabel.text = "Select time"
            }
        } else {
            // No dates provided
            dateLabel.text = "Available"
            timeLabel.text = "Select time"
        }
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
            
            let filledStar = "★"
            let emptyStar = "☆"
            
            let starString = String(repeating: filledStar, count: fullStars) +
                            String(repeating: emptyStar, count: emptyStars)
            
            ratingLabel.text = starString
            ratingLabel.textColor = UIColor(hex: "2D493A")
        } else {
            ratingLabel.text = "☆☆☆☆☆"
            ratingLabel.textColor = .lightGray
        }
        
        // Handle empty state - No reviews
        if ratings.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No reviews yet"
            emptyLabel.textAlignment = .center
            emptyLabel.textColor = UIColor.darkGray
            emptyLabel.font = UIFont.systemFont(ofSize: 16)
            emptyLabel.numberOfLines = 0

            reviewsTableView.backgroundView = emptyLabel
            reviewsTableView.separatorStyle = .none
            reviewsTableViewHeight.constant = 80
            
            seeAllButton.isHidden = true
            
            print("No reviews for this service")
        } else {
            // Has reviews - remove empty state
            reviewsTableView.backgroundView = nil
            reviewsTableView.separatorStyle = .singleLine
            seeAllButton.isHidden = false
            
            reviewsTableView.reloadData()
            // Update table height based on content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateReviewsTableHeight()
            }
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
        
        // Set minimum and maximum dates based on service availability
        if let service = service,
           let startDateString = service.startDate,
           let endDateString = service.endDate {
            
            print("Parsing dates...")
            print("Start: \(startDateString)")
            print("End: \(endDateString)")
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            var startDate: Date?
            var endDate: Date?
            
            // Try format 1: "2025-12-23T19:51:54" (ISO8601-style with T)
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            startDate = dateFormatter.date(from: startDateString)
            endDate = dateFormatter.date(from: endDateString)
            
            // Try format 2: "2025-12-23 19:51:54" (space instead of T)
            if startDate == nil || endDate == nil {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                startDate = dateFormatter.date(from: startDateString)
                endDate = dateFormatter.date(from: endDateString)
            }
            
            if let startDate = startDate, let endDate = endDate {
                datePicker.minimumDate = startDate
                datePicker.maximumDate = endDate
                print("Date picker range: \(startDate) to \(endDate)")
            } else {
                print("Failed to parse, using default")
                datePicker.minimumDate = Date()
            }
        } else {
            datePicker.minimumDate = Date()
        }
        
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
            cell.separatorInset = UIEdgeInsets(top: 0, left: 70, bottom: 0, right:  10)
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
            
            guard let service = service else {
                print("❌ No service available")
                return
            }
            
            let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
            
            guard let paymentVC = storyboard.instantiateViewController(withIdentifier: "PaymentVC") as? PaymentViewController else {
                print("❌ Could not instantiate PaymentViewController")
                return
            }
            
            // Pass all required data
            paymentVC.servicePrice = service.pricePerHour
            paymentVC.serviceName = service.name
            paymentVC.serviceId = service.id
            paymentVC.selectedDate = dateLabel.text ?? ""
            
            print("Navigating to payment screen")
            print("Service ID: \(service.id)")
            print("Price: \(service.pricePerHour) BD")
            print("Selected Date: \(dateLabel.text ?? "none")")
            
            navigationController?.pushViewController(paymentVC, animated: true)
    }
    
    @IBAction func seeAllReviewsTapped(_ sender: UIButton) {
        guard let service = service else {
                print("❌ No service available")
                return
            }
            
            let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
            
            guard let allReviewsVC = storyboard.instantiateViewController(withIdentifier: "AllReviewsVC") as? AllReviewsViewController else {
                print("❌ Could not instantiate AllReviewsViewController")
                return
            }
            
            allReviewsVC.serviceId = service.id
            allReviewsVC.serviceName = service.name
            
            print("Passing serviceId: \(service.id)")
            print("Passing serviceName: \(service.name)")
            
            navigationController?.pushViewController(allReviewsVC, animated: true)
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
