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
    
    // MARK: - Properties
    let availableCategories = ["Home", "Design", "Tutoring"] // Available categories
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
        // TODO: Show selection
    }
    
    @IBAction func ratingButtonTapped(_ sender: UIButton) {
        print("Rating tapped")
        
    }
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        print("Applying filters:")
        print("   Sort by: \(currentFilters.sortBy)")
        print("   Max price: BD\(currentFilters.maxPrice)")
        print("   Categories: \(currentFilters.selectedCategories)")
        
        delegate?.didApplyFilters(currentFilters)
        dismiss(animated: true)
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
}
