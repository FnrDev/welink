//
//  CategoryViewController.swift
//  welink
//
//  Created by Zahra on 24/12/2025.
//

import UIKit
import Supabase

class CategoryViewController: UIViewController {
    
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var tutoringButton: UIButton!
    @IBOutlet weak var designButton: UIButton!
    @IBOutlet weak var servicesTableView: UITableView!
    @IBOutlet weak var homeLabel: UILabel!
    @IBOutlet weak var tutoringLabel: UILabel!
    @IBOutlet weak var designLabel: UILabel!
    
    var selectedCategory: String = "Home"  // Default category
    var services: [SeekerSearchResult] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupButtons()
        setupTableView()
        fetchServicesForCategory(selectedCategory)
    }
    
    func setupButtons() {
        // Style category buttons
        [homeButton, tutoringButton, designButton].forEach { button in
            button?.layer.cornerRadius = 8
            button?.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        }
        
        homeButton.applyAppStyle()
        tutoringButton.applyAppStyle()
        designButton.applyAppStyle()
        
        // Highlight selected category
        updateButtonStates()
    }
    
    func setupTableView() {
        servicesTableView.delegate = self
        servicesTableView.dataSource = self
        servicesTableView.rowHeight = 80
        
        // Register SearchResultCell
        let nib = UINib(nibName: "SearchResultCell", bundle: nil)
        servicesTableView.register(nib, forCellReuseIdentifier: "SearchResultCell")
        
        print("✅ Category table setup complete")
    }
    
    func updateButtonStates() {
        print("🎨 Updating button states for category: \(selectedCategory)")
        
        // Reset ALL buttons to default (Storyboard colors)
        homeButton.backgroundColor = .systemGray6  // Match your Storyboard
        homeLabel.textColor = .black  // Keep black text
        
        tutoringButton.backgroundColor = .systemGray6
        tutoringLabel.textColor = .black
        
        designButton.backgroundColor = .systemGray6
        designLabel.textColor = .black
        
        // Highlight ONLY the selected button
        switch selectedCategory {
        case "Home":
            homeButton.backgroundColor = UIColor(hex: "2D493A")
            homeLabel.textColor = .white
            
        case "Tutoring":
            tutoringButton.backgroundColor = UIColor(hex: "2D493A")
            tutoringLabel.textColor = .white
            
        case "Design":
            designButton.backgroundColor = UIColor(hex: "2D493A")
            designLabel.textColor = .white
            
        default:
            break
        }
    }
    
    func fetchServicesForCategory(_ category: String) {
        Task {
            do {
                let client = SupabaseClientManager.shared.client
                
                // Fetch services with this category
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
                    .contains("categories", value: [category])
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
                
                // Fetch ratings for each
                for index in results.indices {
                    if let rating = try? await fetchServiceRating(serviceId: results[index].id) {
                        results[index].averageRating = rating
                    }
                }
                
                await MainActor.run {
                    self.services = results
                    self.servicesTableView.reloadData()
                    print("✅ Loaded \(results.count) services for category: \(category)")
                }
                
            } catch {
                print("Error fetching services for category: \(error)")
            }
        }
    }
    
    // Fetch rating (copied from other screens)
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
    
    // MARK: - Button Actions
    @IBAction func homeButtonTapped(_ sender: UIButton) {
        selectedCategory = "Home"
        updateButtonStates()
        fetchServicesForCategory(selectedCategory)
    }
    
    @IBAction func tutoringButtonTapped(_ sender: UIButton) {
        selectedCategory = "Tutoring"
        updateButtonStates()
        fetchServicesForCategory(selectedCategory)
    }
    
    @IBAction func designButtonTapped(_ sender: UIButton) {
        selectedCategory = "Design"
        updateButtonStates()
        fetchServicesForCategory(selectedCategory)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension CategoryViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return services.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            return UITableViewCell()
        }
        
        let service = services[indexPath.row]
        cell.configure(with: service)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let service = services[indexPath.row]
        
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
