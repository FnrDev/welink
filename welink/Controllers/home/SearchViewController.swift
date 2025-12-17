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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Remove search bar border
        searchBar.backgroundImage = UIImage()
        searchBar.layer.borderWidth = 0
        searchBar.layer.borderColor = UIColor.clear.cgColor
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
                
        // Get saved searches from phone storage and update the screen
        loadRecentSearches()
        updateUI()

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
                
                // Query with JOIN
                let response: [ServiceWithUser] = try await client.database
                    .from("services")
                    .select("""
                        id,
                        name,
                        description,
                        price_per_hour,
                        image,
                        user_id,
                        users!inner(name)
                    """)
                    .ilike("name", value: "%\(query)%")
                    .lte("price_per_hour", value: activeFilters.maxPrice)  // ← NEW: Filter by price!
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
                        providerName: serviceWithUser.users?.name
                    )
                }
                
                // NEW: Sort results based on filter
                switch activeFilters.sortBy {
                case .price:
                    results.sort { $0.pricePerHour < $1.pricePerHour }
                    print("Sorted by price (low to high)")
                case .rating:
                    // TODO: Sort by rating when we have rating data
                    print("Sort by rating not implemented yet")
                }
                
                await MainActor.run {
                    self.searchResults = results
                    self.updateUI()
                    
                    print("Search completed with \(results.count) results")
                    print("   Applied filters: Sort=\(activeFilters.sortBy), MaxPrice=BD\(activeFilters.maxPrice)")
                }
                
            } catch {
                print("Search error: \(error)")
                print("Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.searchResults = []
                    self.updateUI()
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
            // print("Searching for: \(searchText)")
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
    
    // Create circular image with initial
    func createInitialImage(text: String) -> UIImage {
        let size = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Light gray circle
            UIColor(hex: "D9D9D9").setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Dark green text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
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
    
    // Resize image to specific size
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Load image asynchronously
    func loadImageAsync(from url: URL, into imageView: UIImageView?) {
        // Set placeholder first (first letter)
        let initial = String(url.lastPathComponent.prefix(1)).uppercased()
        imageView?.image = createInitialImage(text: initial)
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        let resizedImage = self.resizeImage(image: image, targetSize: CGSize(width: 40, height: 40))
                        imageView?.image = resizedImage
                        imageView?.contentMode = .scaleAspectFill
                        imageView?.clipsToBounds = true
                        imageView?.layer.cornerRadius = 20
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }
    
    // What to show in each row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        if isShowingResults {
            let service = searchResults[indexPath.row]
            cell.textLabel?.text = service.name
            let providerName = service.providerName ?? "Unknown Provider"
            cell.detailTextLabel?.text = "\(providerName) - BD \(service.pricePerHour)/hr"
            cell.textLabel?.textColor = .black
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            cell.detailTextLabel?.textColor = .gray
            
            // Try to show image, fallback to initial
            if let imageURL = service.image,
               let url = URL(string: imageURL),
               !imageURL.isEmpty {
                // Load image from URL
                loadImageAsync(from: url, into: cell.imageView)
            } else {
                // Show first letter as fallback
                let initial = String(service.name.prefix(1)).uppercased()
                cell.imageView?.image = createInitialImage(text: initial)
            }
            
        } else {
            cell.textLabel?.text = recentSearches[indexPath.row]
            cell.textLabel?.textColor = .lightGray
            cell.imageView?.image = nil
        }
        
        return cell
    }
    
    // When user taps a row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isShowingResults {
            let service = searchResults[indexPath.row]
            // TODO: Navigate to service detail screen
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
        print("   Categories: \(filters.selectedCategories)")
        
        // Re-perform search with filters
        if let searchText = searchBar.text, !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
}
