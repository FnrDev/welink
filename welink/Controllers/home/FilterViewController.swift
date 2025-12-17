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
        
        print("Filter screen loaded")
    }
    
    func updatePriceLabel() {
        priceLabel.text = "Max: BD \(Int(priceSlider.value))"
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
        // TODO: Show selection
    }
    
    @IBAction func ratingButtonTapped(_ sender: UIButton) {
        print("Rating tapped")
        // TODO: Show selection
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
