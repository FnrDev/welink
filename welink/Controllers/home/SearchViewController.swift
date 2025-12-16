//
//  SearchViewController.swift
//  welink
//
//  Created by Zahra on 14/12/2025.
//

import UIKit
import Supabase

class SearchViewController: UIViewController {

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
                
                let results: [SeekerSearchResult] = try await client.database
                    .from("services")
                    .select()
                    .ilike("name", value: "%\(query)%")
                    .execute()
                    .value
                
                await MainActor.run {
                    self.searchResults = results
                    self.updateUI()
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
    
    // What to show in each row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        if isShowingResults {
            // Show service from database
            let service = searchResults[indexPath.row]
            cell.textLabel?.text = service.name
            cell.detailTextLabel?.text = "BD \(service.pricePerHour)/hr"
            cell.textLabel?.textColor = .black
            
            // Placeholder image
            cell.imageView?.image = UIImage(systemName: "photo.circle.fill")
            cell.imageView?.tintColor = .systemGray4
            
        } else {
            // Show recent search
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
