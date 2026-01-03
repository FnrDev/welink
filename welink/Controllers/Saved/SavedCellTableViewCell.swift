//
//  SavedCellTableViewCell.swift
//  welink
//
//  Created by Ali Matar on 03/01/2026.
//

import UIKit

protocol SavedCellDelegate: AnyObject {
    func didTapViewService(serviceName: String)
    func didTapRemoveFavourite(favouriteId: Int64, indexPath: IndexPath)
    func showToast(message: String)
}

class SavedCellTableViewCell: UITableViewCell {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var serviceName: UILabel!
    @IBOutlet weak var usernameAndHourRate: UILabel!
    @IBOutlet weak var viewServiceButton: UIButton!
    @IBOutlet weak var favouriteBTN: UIButton!
    @IBOutlet weak var serviceImage: UIImageView!
    
    weak var delegate: SavedCellDelegate?
    private var favouriteId: Int64 = 0
    private var serviceNameText: String = ""
    private var indexPath: IndexPath?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        serviceImage.image = nil
        favouriteId = 0
        serviceNameText = ""
        indexPath = nil
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Image styling
        serviceImage.layer.cornerRadius = 12
        serviceImage.clipsToBounds = true
        serviceImage.contentMode = .scaleAspectFill
        
        // Container styling
        containerView?.layer.cornerRadius = 12
        containerView?.clipsToBounds = true
        
        // Cell styling
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Favourite button - always filled red for saved items
        favouriteBTN.setImage(UIImage(systemName: "heart.fill"), for: .normal)
        favouriteBTN.tintColor = .systemRed
        
        // View Service button styling
        viewServiceButton.layer.cornerRadius = 12
        viewServiceButton.clipsToBounds = true
    }
    
    // MARK: - Configure Cell
    
    func configure(with favourite: FavouriteData, indexPath: IndexPath) {
        self.favouriteId = favourite.id
        self.serviceNameText = favourite.service_name ?? ""
        self.indexPath = indexPath
        
        serviceName.text = favourite.service_name ?? "Unknown Service"
        
        // Show provider name and rate
        let providerName = favourite.provider_name ?? "Unknown"
        let rate = favourite.rate ?? "0"
        usernameAndHourRate.text = "\(providerName) - \(rate)/hr"
        
        // Load service image
        loadImage(from: favourite.service_image)
    }
    
    // MARK: - Load Image
    
    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            serviceImage.image = UIImage(systemName: "photo")
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        serviceImage.image = image
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    serviceImage.image = UIImage(systemName: "photo")
                }
            }
        }
    }
    
    // MARK: - View Service Button Action
    
    @IBAction func viewServiceButtonTapped(_ sender: UIButton) {
        delegate?.didTapViewService(serviceName: serviceNameText)
    }
    
    // MARK: - Favourite Button Action
    
    @IBAction func favouriteButtonTapped(_ sender: UIButton) {
        guard let indexPath = indexPath else { return }
        delegate?.didTapRemoveFavourite(favouriteId: favouriteId, indexPath: indexPath)
    }
}
