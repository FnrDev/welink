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
        let hasSearches = !recentSearches.isEmpty
        tableView.isHidden = !hasSearches
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
            // print("Searching for: \(searchText)")
            searchBar.resignFirstResponder()
        }
    }

    extension SearchViewController: UITableViewDelegate, UITableViewDataSource {
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return recentSearches.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = recentSearches[indexPath.row]
            cell.textLabel?.textColor = .gray
            return cell
        }

       // Handle when user taps a row
       func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
             let searchText = recentSearches[indexPath.row]
             searchBar.text = searchText // Put text in search bar
             // print("Selected: \(searchText)")
             tableView.deselectRow(at: indexPath, animated: true)
        }
        
        // Swipe to delete
        func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
             if editingStyle == .delete {
                recentSearches.remove(at: indexPath.row)
                saveRecentSearches()
                tableView.deleteRows(at: [indexPath], with: .fade)
                updateUI()
             }
         }

}
