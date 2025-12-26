import UIKit

final class ProviderCardCell: UITableViewCell {

    private let desiredCardWidth: CGFloat = 377
    private let desiredCardHeight: CGFloat = 96
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

        guard let cardView = contentView.viewWithTag(100) else { return }

        let availableWidth = contentView.bounds.width
        let availableHeight = contentView.bounds.height

        let cardWidth = min(desiredCardWidth, availableWidth)
        let cardHeight = min(desiredCardHeight, availableHeight)

        let insetX = max((availableWidth - cardWidth) / 2, 0)
        let insetY = max((availableHeight - cardHeight) / 2, 0)

        let insetFrame = CGRect(
            x: insetX,
            y: insetY,
            width: availableWidth - (insetX * 2),
            height: availableHeight - (insetY * 2)
        )

        cardView.frame = insetFrame

        cardView.backgroundColor = UIColor.systemGray6
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

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.0
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowPath = UIBezierPath(roundedRect: insetFrame, cornerRadius: cardCornerRadius).cgPath
    }
}
