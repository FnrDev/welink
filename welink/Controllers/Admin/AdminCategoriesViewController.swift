//
//  AdminCategoriesViewController.swift
//  welink
//
//  Created by rawan on 21/12/2025.
//

import UIKit

class AdminCategoriesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!

    private var allCategories: [String] = []
    private var filteredCategories: [String] = []

    private let showCategoryServicesSegueID = "ShowAdminCategoryServices"
    private var selectedCategoryName: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self

        searchBar.delegate = self

        Task { [weak self] in
            await self?.loadCategories()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath)
        let title = filteredCategories[indexPath.item]

        cell.layer.cornerRadius = 16
        cell.layer.masksToBounds = true

        let colors: [UIColor] = [
            UIColor.systemBlue.withAlphaComponent(0.20),
            UIColor.systemGreen.withAlphaComponent(0.20),
            UIColor.systemPink.withAlphaComponent(0.20)
        ]
        cell.backgroundColor = colors[indexPath.item % colors.count]

        if let titleLabel = cell.viewWithTag(2) as? UILabel {
            titleLabel.text = title
        }

        if let iconImageView = cell.viewWithTag(1) as? UIImageView {
            let assetName = title.lowercased()
            iconImageView.image = UIImage(named: assetName) ?? UIImage(systemName: "square.grid.2x2")
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard filteredCategories.indices.contains(indexPath.item) else { return }
        selectedCategoryName = filteredCategories[indexPath.item]
        performSegue(withIdentifier: showCategoryServicesSegueID, sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == showCategoryServicesSegueID else { return }
        guard let vc = segue.destination as? AdminCategoryServicesViewController else { return }
        vc.categoryName = selectedCategoryName ?? ""
    }

    private struct ServiceCategoriesRow: Decodable {
        let categories: [String]?
    }

    private func loadCategories() async {
        let client = SupabaseClientManager.shared.client

        do {
            let rows: [ServiceCategoriesRow] = try await client.database
                .from("services")
                .select("categories")
                .execute()
                .value

            let categories = rows
                .compactMap { $0.categories }
                .flatMap { $0 }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let uniqueSorted = Array(Set(categories)).sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })

            await MainActor.run {
                self.allCategories = uniqueSorted
                self.applyFilter(text: self.searchBar.text)
            }
        } catch {
            print("Error loading categories:", error.localizedDescription)
            await MainActor.run {
                self.allCategories = []
                self.applyFilter(text: self.searchBar.text)
            }
        }
    }

    private func applyFilter(text: String?) {
        let query = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredCategories = allCategories
        } else {
            filteredCategories = allCategories.filter { $0.localizedCaseInsensitiveContains(query) }
        }
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let spacing: CGFloat = 12

        let totalSpacing = (columns - 1) * spacing
        let availableWidth = collectionView.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columns)

        return CGSize(width: cellWidth, height: 110)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter(text: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
