//
//  AdminCategoriesViewController.swift
//  welink
//
//  Created by rawan on 21/12/2025.
//

import UIKit
class AdminCategoriesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout
{
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchBar: UISearchBar!

    private let categories: [String] = [
        "Home", "Tutoring", "Design"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath)
        let title = categories[indexPath.item]

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

}
