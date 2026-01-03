//
//  SavedController.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

class SavedController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var noSavedLabel: UILabel!
    
    private var savedFavourites: [FavouriteData] = []
    private var filteredFavourites: [FavouriteData] = []
    private var currentUserId: String = ""
    private var isSearching: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupTableView()
        setupSearchBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchSavedFavourites()
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        noSavedLabel?.isHidden = true
        noSavedLabel?.text = "No saved services found."
    }
    
    // MARK: - Setup Table View
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        let nib = UINib(nibName: "SavedCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "SavedCell")
        tableView.rowHeight = 160
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
    }
    
    // MARK: - Setup Search Bar
    
    private func setupSearchBar() {
        searchBar?.delegate = self
    }
    
    // MARK: - Fetch Saved Favourites
    
    private func fetchSavedFavourites() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                currentUserId = session.user.id.uuidString
                
                let favourites: [FavouriteData] = try await SupabaseClientManager.shared.client.database
                    .from("favourite")
                    .select()
                    .eq("user_id", value: currentUserId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                await MainActor.run {
                    savedFavourites = favourites
                    filteredFavourites = favourites
                    
                    if favourites.isEmpty {
                        tableView.isHidden = true
                        noSavedLabel?.isHidden = false
                    } else {
                        tableView.isHidden = false
                        noSavedLabel?.isHidden = true
                        tableView.reloadData()
                    }
                }
                
            } catch {
                print("Error fetching favourites: \(error)")
                await MainActor.run {
                    tableView.isHidden = true
                    noSavedLabel?.isHidden = false
                    noSavedLabel?.text = "Failed to load saved services."
                }
            }
        }
    }
    
    // MARK: - Remove Favourite
    
    private func removeFavourite(favouriteId: Int64, indexPath: IndexPath) {
        Task {
            do {
                try await SupabaseClientManager.shared.client.database
                    .from("favourite")
                    .delete()
                    .eq("id", value: String(favouriteId))
                    .execute()
                
                await MainActor.run {
                    // Remove from arrays
                    if isSearching {
                        let removedItem = filteredFavourites[indexPath.section]
                        filteredFavourites.remove(at: indexPath.section)
                        if let index = savedFavourites.firstIndex(where: { $0.id == removedItem.id }) {
                            savedFavourites.remove(at: index)
                        }
                    } else {
                        savedFavourites.remove(at: indexPath.section)
                        filteredFavourites = savedFavourites
                    }
                    
                    // Update UI
                    if savedFavourites.isEmpty {
                        tableView.isHidden = true
                        noSavedLabel?.isHidden = false
                    } else {
                        tableView.reloadData()
                    }
                    
                    showToast(message: "Removed from favourites")
                }
                
            } catch {
                print("Error removing favourite: \(error)")
                await MainActor.run {
                    showToast(message: "Failed to remove from favourites")
                }
            }
        }
    }
    
    // MARK: - Navigate to Service
    
    private func navigateToService(serviceName: String) {
        // Search for the service by name and navigate to its details
        Task {
            do {
                let services: [ServiceSearchResult] = try await SupabaseClientManager.shared.client.database
                    .from("services")
                    .select("id, name")
                    .eq("name", value: serviceName)
                    .limit(1)
                    .execute()
                    .value
                
                if let service = services.first {
                    await MainActor.run {
                        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
                        guard let serviceDetailsVC = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
                            return
                        }
                        
                        serviceDetailsVC.serviceId = service.id
                        
                        if let navController = navigationController {
                            navController.pushViewController(serviceDetailsVC, animated: true)
                        } else {
                            let navController = UINavigationController(rootViewController: serviceDetailsVC)
                            navController.modalPresentationStyle = .fullScreen
                            present(navController, animated: true)
                        }
                    }
                } else {
                    await MainActor.run {
                        showToast(message: "Service not found")
                    }
                }
                
            } catch {
                print("Error finding service: \(error)")
                await MainActor.run {
                    showToast(message: "Failed to load service")
                }
            }
        }
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
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension SavedController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? filteredFavourites.count : savedFavourites.count
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SavedCell", for: indexPath) as? SavedCellTableViewCell else {
            return UITableViewCell()
        }
        
        let favourite = isSearching ? filteredFavourites[indexPath.section] : savedFavourites[indexPath.section]
        
        cell.configure(with: favourite, indexPath: indexPath)
        cell.delegate = self
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - SavedCellDelegate

extension SavedController: SavedCellDelegate {
    func didTapViewService(serviceName: String) {
        navigateToService(serviceName: serviceName)
    }
    
    func didTapRemoveFavourite(favouriteId: Int64, indexPath: IndexPath) {
        removeFavourite(favouriteId: favouriteId, indexPath: indexPath)
    }
}

// MARK: - UISearchBarDelegate

extension SavedController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredFavourites = savedFavourites
        } else {
            isSearching = true
            filteredFavourites = savedFavourites.filter { favourite in
                (favourite.service_name?.lowercased().contains(searchText.lowercased()) ?? false) ||
                (favourite.provider_name?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        isSearching = false
        filteredFavourites = savedFavourites
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
}

// MARK: - Service Search Result Struct

struct ServiceSearchResult: Decodable {
    let id: String
    let name: String
}
