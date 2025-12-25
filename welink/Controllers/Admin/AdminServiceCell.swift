import UIKit

final class AdminServiceCell: UITableViewCell {

    private let avatarSize: CGFloat = 56

    override func layoutSubviews() {
        super.layoutSubviews()

        if let avatarImageView = viewWithTag(3) as? UIImageView {
            ensureFixedSizeConstraints(on: avatarImageView, size: avatarSize)
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
            avatarImageView.layer.masksToBounds = true
        }

        if let cardView = viewWithTag(100) {
            cardView.layer.cornerRadius = 14
            cardView.layer.masksToBounds = true
        }
    }

    private func ensureFixedSizeConstraints(on view: UIView, size: CGFloat) {
        let existingWidth = view.constraints.first { $0.firstAttribute == .width && $0.relation == .equal }
        if existingWidth == nil {
            let c = view.widthAnchor.constraint(equalToConstant: size)
            c.isActive = true
        } else {
            existingWidth?.constant = size
        }

        let existingHeight = view.constraints.first { $0.firstAttribute == .height && $0.relation == .equal }
        if existingHeight == nil {
            let c = view.heightAnchor.constraint(equalToConstant: size)
            c.isActive = true
        } else {
            existingHeight?.constant = size
        }
    }
}
