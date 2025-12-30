//
//  SeekerHomeViewController.swift
//  welink
//
//  Created by Zahra on 30/11/2025.
//

import UIKit
import Supabase

// Simple struct just for fetching service IDs from bookings
struct BookingSimple: Codable {
    let service_id: String
}

// Simple struct just for fetching categories
struct ServiceCategories: Codable {
    let id: String
    let categories: [String]?
}

class SeekerHomeViewController: UIViewController {
    
    @IBOutlet weak var recommendedTableView: UITableView!
    @IBOutlet weak var popularTableView: UITableView!
    
    @IBOutlet weak var bell: UINavigationItem!
    
    var recommendedServices: [SeekerSearchResult] = []
    var popularServices: [SeekerSearchResult] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
            let bellButton = UIBarButtonItem(
                image: UIImage(systemName: "bell"),
                style: .plain,
                target: self,
                action: #selector(bellButtonTapped)
            )
            bellButton.tintColor = UIColor(hex: "2D493A")
            
            let negativeSpacer = UIBarButtonItem(
                barButtonSystemItem: .fixedSpace,
                target: nil,
                action: nil
            )
            negativeSpacer.width = -8
            
            navigationItem.rightBarButtonItems = [negativeSpacer, bellButton]
        
        setupTableViews()
        fetchRecommendedServices()
        fetchPopularServices()
    }
    
    func setupTableViews() {
        // Setup Recommended table
        recommendedTableView.delegate = self
        recommendedTableView.dataSource = self
        recommendedTableView.isScrollEnabled = false
        recommendedTableView.rowHeight = 80
        recommendedTableView.backgroundColor = .clear
        recommendedTableView.separatorStyle = .none
        
        // Setup Popular table
        popularTableView.delegate = self
        popularTableView.dataSource = self
        popularTableView.isScrollEnabled = false
        popularTableView.rowHeight = 80
        popularTableView.backgroundColor = .clear
        popularTableView.separatorStyle = .none
        
        let nib = UINib(nibName: "SearchResultCell", bundle: nil)
        recommendedTableView.register(nib, forCellReuseIdentifier: "SearchResultCell")
        popularTableView.register(nib, forCellReuseIdentifier: "SearchResultCell")
        
        print("Tables setup complete")
    }
    
    func fetchRecommendedServices() {
        Task {
            do {
                let client = SupabaseClientManager.shared.client
                
                // Try to get current user
                let session = try? await client.auth.session
                
                if let userId = session?.user.id.uuidString {
                    // User is logged in - get personalized recommendations
                    print("📊 Fetching personalized recommendations for user: \(userId)")
                    
                    // Get user's bookings
                    let bookings: [BookingSimple] = try await client.database
                        .from("bookings")
                        .select("service_id")
                        .eq("user_id", value: userId)
                        .execute()
                        .value
                    
                    if !bookings.isEmpty {
                        // Get the services they booked to find categories
                        let bookedServiceIds = bookings.map { $0.service_id }
                        
                        let bookedServices: [ServiceCategories] = try await client.database
                            .from("services")
                            .select("id, categories")
                            .in("id", value: bookedServiceIds)
                            .execute()
                            .value
                        
                        // Extract all categories from booked services
                        let allCategories = bookedServices
                            .compactMap { $0.categories }
                            .flatMap { $0 }
                        
                        // Get unique categories
                        let preferredCategories = Array(Set(allCategories))
                        
                        print("✅ User's preferred categories: \(preferredCategories)")
                        
                        if !preferredCategories.isEmpty {
                            // Find services in same categories
                            let allRecommendations: [ServiceWithUser] = try await client.database
                                .from("services")
                                .select("""
                                    id,
                                    name,
                                    description,
                                    price_per_hour,
                                    image,
                                    user_id,
                                    start_date,
                                    end_date,
                                    categories,
                                    users!inner(name, image)
                                """)
                                .overlaps("categories", value: preferredCategories)
                                .limit(10)  // Get more to filter from
                                .execute()
                                .value
                            
                            // Filter out already booked services in Swift
                            let filteredRecommendations = allRecommendations.filter { service in
                                !bookedServiceIds.contains(service.id)
                            }
                            
                            // Take first 2
                            let recommendations = Array(filteredRecommendations.prefix(2))
                            
                            if !recommendations.isEmpty {
                                await displayRecommendations(recommendations)
                                return
                            }
                        }
                    }
                }
                
                // Fallback: Show recent services for new users or users without bookings
                print("📌 Showing recent services (fallback)")
                let recentServices: [ServiceWithUser] = try await client.database
                    .from("services")
                    .select("""
                        id,
                        name,
                        description,
                        price_per_hour,
                        image,
                        user_id,
                        start_date,
                        end_date,
                        categories,
                        users!inner(name, image)
                    """)
                    .order("created_at", ascending: false)
                    .limit(2)
                    .execute()
                    .value
                
                await displayRecommendations(recentServices)
                
            } catch {
                print("❌ Error fetching recommendations: \(error)")
            }
        }
    }

    // Helper function to display recommendations
    func displayRecommendations(_ services: [ServiceWithUser]) async {
        var results = services.map { serviceWithUser in
            SeekerSearchResult(
                id: serviceWithUser.id,
                name: serviceWithUser.name,
                description: serviceWithUser.description,
                pricePerHour: serviceWithUser.price_per_hour,
                image: serviceWithUser.image,
                userId: serviceWithUser.user_id,
                providerName: serviceWithUser.users?.name,
                providerImage: serviceWithUser.users?.image,
                startDate: serviceWithUser.start_date,
                endDate: serviceWithUser.end_date,
                categories: serviceWithUser.categories,
                averageRating: nil
            )
        }
        
        // Fetch ratings for each
        for index in results.indices {
            if let rating = try? await fetchServiceRating(serviceId: results[index].id) {
                results[index].averageRating = rating
            }
        }
        
        await MainActor.run {
            self.recommendedServices = results
            self.recommendedTableView.reloadData()
            print("✅ Loaded \(results.count) recommended services")
        }
    }
    
    func fetchPopularServices() {
        Task {
            do {
                let client = SupabaseClientManager.shared.client
                
                // Get 5 services
                let response: [ServiceWithUser] = try await client.database
                    .from("services")
                    .select("""
                        id,
                        name,
                        description,
                        price_per_hour,
                        image,
                        user_id,
                        start_date,
                        end_date,
                        categories,
                        users!inner(name, image)
                    """)
                    .limit(10)  // Get 10 to have enough to sort
                    .execute()
                    .value
                
                // Convert to SeekerSearchResult
                var results = response.map { serviceWithUser in
                    SeekerSearchResult(
                        id: serviceWithUser.id,
                        name: serviceWithUser.name,
                        description: serviceWithUser.description,
                        pricePerHour: serviceWithUser.price_per_hour,
                        image: serviceWithUser.image,
                        userId: serviceWithUser.user_id,
                        providerName: serviceWithUser.users?.name,
                        providerImage: serviceWithUser.users?.image,
                        startDate: serviceWithUser.start_date,
                        endDate: serviceWithUser.end_date,
                        categories: serviceWithUser.categories,
                        averageRating: nil
                    )
                }
                
                // Fetch ratings for each
                for index in results.indices {
                    if let rating = try? await fetchServiceRating(serviceId: results[index].id) {
                        results[index].averageRating = rating
                    }
                }
                
                // Sort by rating
                results.sort { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
                
                // Take top 5
                results = Array(results.prefix(5))
                
                await MainActor.run {
                    self.popularServices = results
                    self.popularTableView.reloadData()
                    print("✅ Loaded \(results.count) popular services")
                }
                
            } catch {
                print("❌ Error fetching popular services: \(error)")
            }
        }
    }
    
    // Fetch average rating for a service
    func fetchServiceRating(serviceId: String) async throws -> Double? {
        let client = SupabaseClientManager.shared.client
        
        let response: [RatingWithUser] = try await client.database
            .from("ratings")
            .select("*")
            .eq("service_id", value: serviceId)
            .execute()
            .value
        
        guard !response.isEmpty else {
            return nil
        }
        
        let sum = response.reduce(0) { $0 + $1.stars_count }
        let average = Double(sum) / Double(response.count)
        return average
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension SeekerHomeViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == recommendedTableView {
            return recommendedServices.count
        } else {
            return popularServices.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Use SearchResultCell
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            return UITableViewCell()
        }
        
        let service = tableView == recommendedTableView ?
            recommendedServices[indexPath.row] :
            popularServices[indexPath.row]
        
        cell.configure(with: service)
        
        // Make cell background transparent/white for Home screen
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        
        cell.contentView.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
        
        // Check if this is NOT the last cell
        let numberOfRows = tableView == recommendedTableView ?
            recommendedServices.count :
            popularServices.count
        
        let isLastCell = indexPath.row == numberOfRows - 1
        
        if !isLastCell {
            // Add separator line
            let separator = UIView()
            separator.tag = 999  // Tag to identify it later
            separator.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
            separator.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(separator)
            
            // Position separator at the bottom with margins
            NSLayoutConstraint.activate([
                separator.heightAnchor.constraint(equalToConstant: 1),
                separator.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 70),
                separator.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                separator.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
            ])
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let service = tableView == recommendedTableView ?
            recommendedServices[indexPath.row] :
            popularServices[indexPath.row]
        
        print("Selected: \(service.name)")
        
        // Navigate to ServiceDetailsViewController
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        
        guard let detailsVC = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
            print("Could not instantiate ServiceDetailsViewController!")
            return
        }
        
        detailsVC.service = service
        navigationController?.pushViewController(detailsVC, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func homeCategoryTapped(_ sender: UIButton) {
        navigateToCategory("Home")
    }

    @IBAction func tutoringCategoryTapped(_ sender: UIButton) {
        navigateToCategory("Tutoring")
    }

    @IBAction func designCategoryTapped(_ sender: UIButton) {
        navigateToCategory("Design")
    }
    
    @objc func bellButtonTapped() {
        let storyboard = UIStoryboard(name: "Notifications", bundle: nil)
        
        guard let notificationsVC = storyboard.instantiateViewController(withIdentifier: "notificationsVC") as? NotificationsViewController else {
            print("Could not instantiate NotificationsViewController")
            return
        }
        
        navigationController?.pushViewController(notificationsVC, animated: true)
    }

    func navigateToCategory(_ category: String) {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        
        guard let categoryVC = storyboard.instantiateViewController(withIdentifier: "CategoryVC") as? CategoryViewController else {
            return
        }
        
        categoryVC.selectedCategory = category
        navigationController?.pushViewController(categoryVC, animated: true)
    }
}
