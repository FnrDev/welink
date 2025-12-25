//
//  SearchResultCell.swift
//  welink
//
//  Created by Zahra on 24/12/2025.
//

import UIKit

class SearchResultCell: UITableViewCell {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var serviceNameLabel: UILabel!
    @IBOutlet weak var providerNameLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var starsLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Make image circular
        profileImageView.layer.cornerRadius = 25
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
    }
    
    func configure(with service: SeekerSearchResult) {
        // Service name
        serviceNameLabel.text = service.name
        
        // Provider name
        providerNameLabel.text = service.providerName ?? "Unknown Provider"
        
        // Price
        priceLabel.text = "BD \(service.pricePerHour)/hr"
        
        // Stars 
        let rating = service.averageRating ?? 0
        if rating > 0 {
            starsLabel.text = String(format: "%.1f", rating)
        } else {
            starsLabel.text = "0.0"
        }
        starsLabel.textColor = UIColor(hex: "2D493A")
        
        // Load image
        if let imageURL = service.image,
           let url = URL(string: imageURL),
           !imageURL.isEmpty {
            loadImageAsync(from: url, fallbackName: service.providerName)
        } else {
            // Show initial as fallback
            if let name = service.providerName, !name.isEmpty {
                let initial = String(name.prefix(1)).uppercased()
                profileImageView.image = createInitialImage(text: initial)
            } else {
                profileImageView.image = createInitialImage(text: "?")
            }
        }
    }
    
    // Create circular image with initial
    private func createInitialImage(text: String) -> UIImage {
        let size = CGSize(width: 50, height: 50)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor(hex: "D9D9D9").setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            
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
    
    // Resize image
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Load image asynchronously
    private func loadImageAsync(from url: URL, fallbackName: String?) {
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
                        let resizedImage = self.resizeImage(image: image, targetSize: CGSize(width: 50, height: 50))
                        self.profileImageView.image = resizedImage
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }
}
