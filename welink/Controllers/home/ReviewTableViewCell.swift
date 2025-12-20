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
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
    }
    
    // Display each review
    func configure(with rating: ServiceRating) {
        print("Configuring review:")
        print("Name: \(rating.userName ?? "nil")")
        print("Image URL: \(rating.userImage ?? "nil")")
        print("Stars: \(rating.starsCount)")
        print("Content: \(rating.reviewContent)")
        
        reviewerNameLabel.text = rating.userName ?? "Anonymous"
        reviewTextLabel.text = rating.reviewContent
        
        // Show FILLED stars
        let filledStars = String(repeating: "★", count: rating.starsCount)
        let emptyStars = String(repeating: "☆", count: 5 - rating.starsCount)
        starsLabel.text = filledStars + emptyStars
        starsLabel.textColor = .black
        
        // Fallback to initial
        if let imageURL = rating.userImage,
           let url = URL(string: imageURL),
           !imageURL.isEmpty {
            // Load image from URL (just like SearchViewController)
            loadImageAsync(from: url, fallbackName: rating.userName)
        } else {
            // Show initial as fallback
            if let userName = rating.userName, !userName.isEmpty {
                let initial = String(userName.prefix(1)).uppercased()
                profileImageView.image = createInitialImage(text: initial)
            } else {
                profileImageView.image = createInitialImage(text: "?")
            }
        }
    }
    
    // Create circular image with initial
    private func createInitialImage(text: String) -> UIImage {
        let size = CGSize(width: 50, height: 50)  // Match image view size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Light gray circle
            UIColor(hex: "D9D9D9").setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Dark green text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
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
    
    // Resize image to specific size
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Load image asynchronously
    private func loadImageAsync(from url: URL, fallbackName: String?) {
        // Set placeholder first (initial letter)
        if let name = fallbackName, !name.isEmpty {
            let initial = String(name.prefix(1)).uppercased()
            profileImageView.image = createInitialImage(text: initial)
        } else {
            profileImageView.image = createInitialImage(text: "?")
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        // Resize and apply to image view
                        let resizedImage = self.resizeImage(image: image, targetSize: CGSize(width: 50, height: 50))
                        self.profileImageView.image = resizedImage
                        self.profileImageView.contentMode = .scaleAspectFill
                        self.profileImageView.clipsToBounds = true
                        self.profileImageView.layer.cornerRadius = 25
                        print("✅ Image loaded and displayed")
                    }
                }
            } catch {
                print("❌ Failed to load image: \(error)")
            }
        }
    }
}
