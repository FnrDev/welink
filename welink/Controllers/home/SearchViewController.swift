//
//  SearchViewController.swift
//  welink
//
//  Created by Zahra on 14/12/2025.
//

import UIKit
import Supabase

class SearchViewController: UIViewController {

    var activeFilters = SearchFilters()
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var recentSearchesLabel: UILabel!
    @IBOutlet weak var clearAllButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    var recentSearches: [String] = [] //to store search terms
    let maxRecentSearches = 3 //how many searches to save
    var searchResults: [SeekerSearchResult] = []  // store services from database
    var isShowingResults = false  // false = recent searches, true = search results
    var showAllOnLoad = false  // When true, load all services immediately
    var showOnlyUserServices = false  // When true, only show current user's services

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

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No services found."
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
        // Remove search bar border
        searchBar.backgroundImage = UIImage()
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor

        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        
        let nib = UINib(nibName: "SearchResultCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "SearchResultCell")

        // Get saved searches from phone storage and update the screen
        loadRecentSearches()
        setupLoadingView()

        if showAllOnLoad {
            loadAllServices()
        } else {
            updateUI()
        }
    }

    private func setupLoadingView() {
        view.addSubview(loadingContainer)
        loadingContainer.addSubview(activityIndicator)
        loadingContainer.addSubview(loadingLabel)
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            loadingContainer.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),

            activityIndicator.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),

            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingLabel.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])

        loadingContainer.isHidden = true
    }

    private func showLoading() {
        loadingContainer.isHidden = false
        activityIndicator.startAnimating()
        emptyStateLabel.isHidden = true
        tableView.isHidden = true
    }

    private func hideLoading() {
        loadingContainer.isHidden = true
        activityIndicator.stopAnimating()

        if searchResults.isEmpty && isShowingResults {
            emptyStateLabel.isHidden = false
            tableView.isHidden = true
        } else {
            emptyStateLabel.isHidden = true
            tableView.isHidden = false
        }
    }
    
    // Load saved searches from phone storage
    func loadRecentSearches() {
        if let saved = UserDefaults.standard.array(forKey: "recentSearches") as? [String] {
                recentSearches = saved
        }
    }
    
    // Save searches to phone storage
    func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches")
    }
    
    // Add new search to the list
    func addRecentSearch(_ searchText: String) {
        
        // Remove duplicate if exists
        if let index = recentSearches.firstIndex(of: searchText) {
                recentSearches.remove(at: index)
        }
            
        // Most recent searches appear first
        recentSearches.insert(searchText, at: 0)
            
        // Keep only last 3 searches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
            
        saveRecentSearches()
        tableView.reloadData()
        updateUI()
    }
    
    // Show/Hide Table Elements
    func updateUI() {
        if isShowingResults {
            // Showing search results from database
            recentSearchesLabel.text = "Search Result"
            clearAllButton.isHidden = true
            tableView.isHidden = false
        } else {
            // Showing recent searches
            recentSearchesLabel.text = "Recent Searches"
            clearAllButton.isHidden = recentSearches.isEmpty
            tableView.isHidden = recentSearches.isEmpty
        }
        tableView.reloadData()
    }
    
    // Search database for services
    func performSearch(query: String) {
        isShowingResults = true
        updateUI()
        
        Task {
            do {
                let client = SupabaseClientManager.shared.client
                
                // Build query with filters
                var queryBuilder = client.database
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
                    .ilike("name", value: "%\(query)%")
                    .lte("price_per_hour", value: activeFilters.maxPrice)  // Price filter
                
                // Add category filter if any selected
                if !activeFilters.selectedCategories.isEmpty {
                    queryBuilder = queryBuilder.overlaps("categories", value: activeFilters.selectedCategories)
                    print("✅ Filtering by categories: \(activeFilters.selectedCategories)")
                }
                
                let response: [ServiceWithUser] = try await queryBuilder
                    .execute()
                    .value
                
                // Convert to results
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

                // Fetch ratings for each service
                for index in results.indices {
                    if let rating = try? await fetchServiceRating(serviceId: results[index].id) {
                        results[index].averageRating = rating
                        print("✅ Service '\(results[index].name)' has rating: \(rating)")
                    } else {
                        print("⚠️ No ratings found for '\(results[index].name)'")
                    }
                }
                
                // Filter by rating
                if activeFilters.minRating > 0 {
                    results = results.filter { ($0.averageRating ?? 0) >= activeFilters.minRating }
                    print("✅ Filtered by rating: \(activeFilters.minRating)+ stars")
                }
                
                // Sort results
                switch activeFilters.sortBy {
                case .price:
                    results.sort {
                        let price1 = $0.pricePerHour ?? 0
                        let price2 = $1.pricePerHour ?? 0
                        return activeFilters.sortAscending ? price1 < price2 : price1 > price2
                    }
                    print("Sorted by price (\(activeFilters.sortAscending ? "↑" : "↓"))")
                case .rating:
                    results.sort {
                        let rating1 = $0.averageRating ?? 0
                        let rating2 = $1.averageRating ?? 0
                        return activeFilters.sortAscending ? rating1 < rating2 : rating1 > rating2
                    }
                    print("Sorted by rating (\(activeFilters.sortAscending ? "↑" : "↓"))")
                }
                
                await MainActor.run {
                    self.searchResults = results
                    self.updateUI()
                    
                    print("✅ Search completed with \(results.count) results")
                    print("   Filters: Sort=\(activeFilters.sortBy), Price≤BD\(activeFilters.maxPrice), Rating≥\(activeFilters.minRating)")
                }
                
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.updateUI()
                }
            }
        }
    }

    // Load all services (used when coming from "See All" button)
    func loadAllServices() {
        isShowingResults = true
        recentSearchesLabel.text = showOnlyUserServices ? "My Services" : "All Services"
        clearAllButton.isHidden = true
        showLoading()

        Task {
            do {
                let client = SupabaseClientManager.shared.client

                var queryBuilder = client.database
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

                // Filter by current user if showOnlyUserServices is true
                if showOnlyUserServices {
                    if let session = try? await client.auth.session {
                        queryBuilder = queryBuilder.eq("user_id", value: session.user.id.uuidString)
                    }
                }

                let response: [ServiceWithUser] = try await queryBuilder
                    .order("created_at", ascending: false)
                    .execute()
                    .value

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

                // Fetch ratings for each service
                for index in results.indices {
                    if let rating = try? await fetchServiceRating(serviceId: results[index].id) {
                        results[index].averageRating = rating
                    }
                }

                await MainActor.run {
                    self.searchResults = results
                    self.tableView.reloadData()
                    self.hideLoading()
                    print("Loaded \(results.count) services")
                }

            } catch {
                print("Error loading all services: \(error)")
                await MainActor.run {
                    self.searchResults = []
                    self.tableView.reloadData()
                    self.hideLoading()
                }
            }
        }
    }

    // Go back to recent searches
    func showRecentSearches() {
        isShowingResults = false
        searchResults = []
        updateUI()
    }
    
    // Fetch average rating for a service
    func fetchServiceRating(serviceId: String) async throws -> Double? {
        let client = SupabaseClientManager.shared.client
        
        print("Fetching ratings for service ID: \(serviceId)")
        
        do {
            let response: [RatingWithUser] = try await client.database
                .from("ratings")
                .select("*")
                .eq("service_id", value: serviceId)
                .execute()
                .value
            
            print("📊 Found \(response.count) ratings")
            
            guard !response.isEmpty else {
                return nil
            }
            
            let sum = response.reduce(0) { $0 + $1.stars_count }
            let average = Double(sum) / Double(response.count)
            
            print("Average rating: \(average)")
            return average
            
        } catch {
            print("Error fetching ratings: \(error)")
            return nil
        }
    }

    // Clear all searches when button tapped
    @IBAction func clearAllButtonTapped(_ sender: UIButton) {
        recentSearches.removeAll()
        saveRecentSearches()
        tableView.reloadData()
        updateUI()
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFilter" {
            // Get the navigation controller
            if let navController = segue.destination as? UINavigationController,
               let filterVC = navController.viewControllers.first as? FilterViewController {
                filterVC.delegate = self
                filterVC.currentFilters = activeFilters
                print("Passing current filters to FilterVC")
            }
        }
    }
}

    
extension SearchViewController: UISearchBarDelegate {
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            guard let searchText = searchBar.text, !searchText.isEmpty else { return }
            
            addRecentSearch(searchText)
            performSearch(query: searchText)
            searchBar.resignFirstResponder()
        }
    
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            if isShowingResults {
                showRecentSearches()
            }
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            if searchText.isEmpty && isShowingResults {
                showRecentSearches()
            }
        }
}

extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
    
    // How many rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isShowingResults ? searchResults.count : recentSearches.count
    }
    
    // Set custom row height
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return isShowingResults ? 80 : 44
    }
    
    // What to show in each row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if isShowingResults {
            // Use custom cell for search results
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
                print("Failed to load SearchResultCell")
                return UITableViewCell()
            }
            
            let service = searchResults[indexPath.row]
            cell.configure(with: service)
//            cell.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            return cell
            
        } else {
            // Use basic cell for recent searches
            let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
            cell.textLabel?.text = recentSearches[indexPath.row]
            cell.textLabel?.textColor = .lightGray
//            cell.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            return cell
        }
    }
    
    // When user taps a row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isShowingResults {
            let service = searchResults[indexPath.row]

            print("Selected service:")
            print("Name: \(service.name)")
            print("ID: \(service.id)")
            print("Provider: \(service.providerName ?? "nil")")

            let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)

            guard let detailsVC = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
                print("❌ Could not instantiate ServiceDetailsViewController!")
                return
            }

            // Pass the service data
            detailsVC.service = service

            if let navController = navigationController {
                navController.pushViewController(detailsVC, animated: true)
            } else {
                // Fallback: wrap in nav controller and present modally
                let navController = UINavigationController(rootViewController: detailsVC)
                navController.modalPresentationStyle = .fullScreen
                present(navController, animated: true)
            }

        } else {
            let searchText = recentSearches[indexPath.row]
            searchBar.text = searchText
            performSearch(query: searchText)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Swipe to delete (only for recent searches)
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && !isShowingResults {
            recentSearches.remove(at: indexPath.row)
            saveRecentSearches()
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateUI()
        }
    }
    
    // Can only delete recent searches
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isShowingResults
    }
}


extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - FilterViewControllerDelegate
extension SearchViewController: FilterViewControllerDelegate {
    func didApplyFilters(_ filters: SearchFilters) {
        self.activeFilters = filters
        
        print("filters:")
        print("   Sort by: \(filters.sortBy)")
        print("   Max price: BD\(filters.maxPrice)")
        print("   Min rating: \(filters.minRating)+")
        print("   Categories: \(filters.selectedCategories)")
        
        // Re-perform search with filters
        if let searchText = searchBar.text, !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
}
