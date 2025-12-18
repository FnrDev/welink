//
//  FilterViewController.swift
//  welink
//
//  Created by Zahra on 18/12/2025.
//

import UIKit

// Filter options
struct SearchFilters {
    var sortBy: SortOption = .price
    var sortAscending: Bool = true
    var selectedCategories: [String] = []
    var maxPrice: Double = 100
    var minRating: Double = 0
    
    enum SortOption {
        case price
        case rating
    }
}

protocol FilterViewControllerDelegate: AnyObject {
    func didApplyFilters(_ filters: SearchFilters)
}

class FilterViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var sortSegmentedControl: UISegmentedControl!
    @IBOutlet weak var categoriesButton: UIButton!
    @IBOutlet weak var ratingButton: UIButton!
    @IBOutlet weak var priceSlider: UISlider!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var applyButton: UIButton!
    @IBOutlet weak var sortDirectionButton: UIButton!
    
    // MARK: - Properties
    let availableCategories = ["Home", "Design", "Tutoring"] // Available categories
    let availableRatings = [  // Available rating options
        (value: 0.0, display: "Any rating"),
        (value: 1.0, display: "1 ★"),
        (value: 2.0, display: "2 ★★"),
        (value: 3.0, display: "3 ★★★"),
        (value: 4.0, display: "4 ★★★★"),
        (value: 5.0, display: "5 ★★★★★")]
    weak var delegate: FilterViewControllerDelegate?
    var currentFilters = SearchFilters()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        title = "Filter"
        
        // Style buttons with rounded corners
        categoriesButton.layer.cornerRadius = 8
        ratingButton.layer.cornerRadius = 8
        applyButton.layer.cornerRadius = 8
        
        // Style apply button
        applyButton.backgroundColor = UIColor(red: 0x2D/255, green: 0x49/255, blue: 0x3A/255, alpha: 1.0)
        applyButton.setTitleColor(.white, for: .normal)
        
        // Setup price slider
        priceSlider.minimumValue = 0
        priceSlider.maximumValue = 100
        priceSlider.value = Float(currentFilters.maxPrice)
        
        updatePriceLabel()
        updateCategoriesButtonTitle()
        updateRatingButtonTitle()
        updateSortDirectionButton()
        
        print("Filter screen loaded")
    }
    
    func updatePriceLabel() {
        priceLabel.text = "Max: BD \(Int(priceSlider.value))"
    }
    
    
    // MARK: - Categories Selection
    func showCategoriesAlert() {
        let alert = UIAlertController(
            title: "Select Categories",
            message: "Choose one or more categories",
            preferredStyle: .actionSheet
        )
        
        // Add action for each category
        for category in availableCategories {
            let isSelected = currentFilters.selectedCategories.contains(category)
            let title = isSelected ? "✓ \(category)" : category
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.toggleCategory(category)
                // Show alert again to allow multiple selections
                self?.showCategoriesAlert()
            }
            alert.addAction(action)
        }
        
        // Add "Done" button
        let doneAction = UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
            self?.updateCategoriesButtonTitle()
        }
        alert.addAction(doneAction)
        present(alert, animated: true)
    }
    
    // MARK: - Rating Selection
    func showRatingAlert() {
        let alert = UIAlertController(
            title: "Minimum Rating",
            message: "Select minimum star rating",
            preferredStyle: .actionSheet
        )
        
        for rating in availableRatings {
            let isSelected = currentFilters.minRating == rating.value
            let title = isSelected ? "✓ \(rating.display)" : rating.display
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.currentFilters.minRating = rating.value
                self?.updateRatingButtonTitle()
                print("⭐ Min rating: \(rating.display)")
            }
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        // For iPad compatibility
        if let popover = alert.popoverPresentationController {
            popover.sourceView = ratingButton
            popover.sourceRect = ratingButton.bounds
        }
        
        present(alert, animated: true)
    }

    func updateRatingButtonTitle() {
        if currentFilters.minRating == 0 {
            ratingButton.setTitle("Rating", for: .normal)
        } else if currentFilters.minRating == 5.0 {
            ratingButton.setTitle("Rating (5★ only)", for: .normal)
        } else {
            ratingButton.setTitle("Rating (\(Int(currentFilters.minRating)))", for: .normal)
        }
    }

    func toggleCategory(_ category: String) {
        if currentFilters.selectedCategories.contains(category) {
            // Remove if already selected
            currentFilters.selectedCategories.removeAll { $0 == category }
        } else {
            // Add if not selected
            currentFilters.selectedCategories.append(category)
        }
        print("📂 Categories: \(currentFilters.selectedCategories)")
    }

    func updateCategoriesButtonTitle() {
        let count = currentFilters.selectedCategories.count
        if count == 0 {
            categoriesButton.setTitle("Categories", for: .normal)
        } else {
            categoriesButton.setTitle("Categories (\(count))", for: .normal)
        }
    }
    
    func updateSortDirectionButton() {
        let imageName = currentFilters.sortAscending ? "arrow.up" : "arrow.down"
        sortDirectionButton.setImage(UIImage(systemName: imageName), for: .normal)
        sortDirectionButton.tintColor = UIColor(red: 0x2D/255, green: 0x49/255, blue: 0x3A/255, alpha: 1.0)
    }
    
    // MARK: - Actions
    @IBAction func sortChanged(_ sender: UISegmentedControl) {
        currentFilters.sortBy = sender.selectedSegmentIndex == 0 ? .price : .rating
        print("Sort by: \(currentFilters.sortBy)")
    }
    
    @IBAction func priceSliderChanged(_ sender: UISlider) {
        currentFilters.maxPrice = Double(sender.value)
        updatePriceLabel()
    }
    
    @IBAction func categoriesButtonTapped(_ sender: UIButton) {
        print("Categories tapped")
        showCategoriesAlert()
    }
    
    @IBAction func ratingButtonTapped(_ sender: UIButton) {
        print("Rating tapped")
        showRatingAlert()
    }
    
    @IBAction func sortDirectionTapped(_ sender: UIButton) {
        currentFilters.sortAscending.toggle()
        updateSortDirectionButton()
        
        let direction = currentFilters.sortAscending ? "Low → High ↑" : "High → Low ↓"
        print("Sort direction: \(direction)")
    }
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        print("✅ Applying filters:")
        print("   Sort by: \(currentFilters.sortBy) (\(currentFilters.sortAscending ? "↑" : "↓"))")
        print("   Max price: BD\(currentFilters.maxPrice)")
        print("   Min rating: \(currentFilters.minRating)+")
        print("   Categories: \(currentFilters.selectedCategories)")
        
        delegate?.didApplyFilters(currentFilters)
        dismiss(animated: true)
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
}
