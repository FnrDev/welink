import UIKit

final class AdminServiceCell: UITableViewCell {

    private let avatarSize: CGFloat = 56

    private let cardCornerRadius: CGFloat = 16

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.masksToBounds = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let avatarImageView = contentView.viewWithTag(3) as? UIImageView {
            ensureFixedSizeConstraints(on: avatarImageView, size: avatarSize)
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.layer.cornerRadius = min(avatarImageView.bounds.width, avatarImageView.bounds.height) / 2
            avatarImageView.layer.masksToBounds = true
        }

        guard let cardView = contentView.viewWithTag(100) else { return }

        cardView.backgroundColor = UIColor.systemGray5
        cardView.layer.cornerRadius = cardCornerRadius
        if #available(iOS 13.0, *) {
            cardView.layer.cornerCurve = .continuous
        }
        cardView.layer.masksToBounds = true

        if let chevron = contentView.viewWithTag(6) as? UIImageView {
            chevron.isHidden = false
            chevron.tintColor = UIColor.systemGray
            if chevron.image == nil {
                chevron.image = UIImage(systemName: "chevron.right")
            }
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
