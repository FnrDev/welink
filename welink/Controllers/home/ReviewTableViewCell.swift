//
//  ReviewTableViewCell.swift
//  welink
//
//  Created by Zahra on 19/12/2025.
//

import UIKit

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var reviewerNameLabel: UILabel!
    @IBOutlet weak var starsLabel: UILabel!
    @IBOutlet weak var reviewTextLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Make profile image circular
        profileImageView.layer.cornerRadius = 20
        profileImageView.clipsToBounds = true
    }
    
    // Display each review
    func configure(with rating: ServiceRating) {
        print(" Configuring review:")
            print("   Name: \(rating.userName ?? "nil")")
            print("   Stars: \(rating.starsCount)")
            print("   Content: \(rating.reviewContent)")
            
        reviewerNameLabel.text = rating.userName ?? "Anonymous"
        reviewTextLabel.text = rating.reviewContent
        
        // Show FILLED stars
        let filledStars = String(repeating: "★", count: rating.starsCount)  // Filled
        let emptyStars = String(repeating: "☆", count: 5 - rating.starsCount)  // Empty
        starsLabel.text = filledStars + emptyStars
        starsLabel.textColor = .black  // Make them visible
        
        // Show initial or image
        if let userName = rating.userName, !userName.isEmpty {
            let initial = String(userName.prefix(1)).uppercased()
            profileImageView.image = createInitialImage(text: initial)
        } else {
            profileImageView.image = createInitialImage(text: "?")
        }
    }
    
    // Create initial avatar
    private func createInitialImage(text: String) -> UIImage {
        let size = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor(hex: "D9D9D9").setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor(hex: "2D493A")
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
