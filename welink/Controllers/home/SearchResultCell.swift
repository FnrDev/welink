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
    
    // Flag to determine if cell should have background
    var showCellBackground: Bool = false {
        didSet {
            updateCellBackground()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Make image circular
        profileImageView.layer.cornerRadius = 25
        profileImageView.clipsToBounds = true
        profileImageView.contentMode = .scaleAspectFill
        
        // Align price to right
        priceLabel.textAlignment = .center
        
        // Default: no background
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        profileImageView.image = nil
        showCellBackground = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if showCellBackground {
            // Add vertical spacing between cells
            contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))
        }
    }
    
    // MARK: - Update Cell Background
    
    private func updateCellBackground() {
        if showCellBackground {
            contentView.backgroundColor = .systemGray6
            contentView.layer.cornerRadius = 12
            contentView.clipsToBounds = true
        } else {
            contentView.backgroundColor = .clear
            contentView.layer.cornerRadius = 0
        }
    }
    
    // MARK: - Configure with SeekerSearchResult
    
    func configure(with service: SeekerSearchResult) {
        serviceNameLabel.text = service.name
        providerNameLabel.text = service.providerName ?? "Unknown Provider"
        priceLabel.text = "BD \(Int(service.pricePerHour))/hr"
        
        let rating = service.averageRating ?? 0
        starsLabel.text = rating > 0 ? String(format: "%.1f", rating) : "0.0"
        starsLabel.textColor = UIColor(hex: "2D493A")
        
        loadImage(from: service.image, fallbackName: service.providerName)
    }
    
    // MARK: - Configure with ServiceData
    
    func configure(with service: ServiceData, providerName: String? = nil) {
        serviceNameLabel.text = service.name
        providerNameLabel.text = providerName ?? "Your Service"
        
        if let price = service.price_per_hour {
            priceLabel.text = "BD \(Int(price))/hr"
        } else {
            priceLabel.text = "BD 0/hr"
        }
        
        let rating = service.rating ?? 0
        starsLabel.text = rating > 0 ? String(format: "%.1f", rating) : "0.0"
        starsLabel.textColor = UIColor(hex: "2D493A")
        
        loadImage(from: service.image, fallbackName: providerName)
    }
    
    // MARK: - Image Loading
    
    private func loadImage(from imageURL: String?, fallbackName: String?) {
        if let imageURL = imageURL,
           let url = URL(string: imageURL),
           !imageURL.isEmpty {
            loadImageAsync(from: url, fallbackName: fallbackName)
        } else {
            if let name = fallbackName, !name.isEmpty {
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
