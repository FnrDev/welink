//
//  SeekerHomeViewController.swift
//  welink
//
//  Created by Zahra on 30/11/2025.
//

import UIKit
import Supabase

class SeekerHomeViewController: UIViewController {
    
    @IBOutlet weak var recommendedTableView: UITableView!
    @IBOutlet weak var popularTableView: UITableView!
    
    var recommendedServices: [SeekerSearchResult] = []
    var popularServices: [SeekerSearchResult] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
                
                // Get 2 random services
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
                    .limit(2)  // Only 2 services
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
                
                await MainActor.run {
                    self.recommendedServices = results
                    self.recommendedTableView.reloadData()
                    print("✅ Loaded \(results.count) recommended services")
                }
                
            } catch {
                print("❌ Error fetching recommended services: \(error)")
            }
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
}
