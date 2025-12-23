//
//  AdminproviderRequestViewController.swift
//  welink
//
//  Created by rawan on 23/12/2025.
//
import UIKit

final class AdminProviderRequestViewController: UIViewController {

    struct Service {
        let title: String
        let subtitle: String
        let priceText: String
        let ratingText: String
    }

    struct ProviderRequestDetails {
        let id: Int
        let name: String
        let requestedAtText: String
        let phone: String
        let email: String
        let skills: [String]
        let services: [Service]
    }

    var request: ProviderRequestDetails?
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private let headerStack = UIStackView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let requestedAtLabel = UILabel()

    private let detailsTitleLabel = UILabel()
    private let detailsRow = UIStackView()
    private let phoneStack = UIStackView()
    private let emailStack = UIStackView()

    private let skillsTitleLabel = UILabel()
    private let skillsWrapStack = UIStackView()

    private let servicesTitleLabel = UILabel()
    private let servicesStack = UIStackView()

    private let approveButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)

    override func loadView() {
        view = UIView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.title = "Provider Request"

        configureLayout()
        configureStyles()
        configureActions()
        apply(request: request)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        #if DEBUG
        if scrollView.superview == nil || stackView.superview == nil || scrollView.frame.height < 10 {
            let alert = UIAlertController(
                title: "Debug: Provider Request",
                message: "scrollView.superview=\(scrollView.superview != nil)\nstackView.superview=\(stackView.superview != nil)\nscrollFrame=\(scrollView.frame)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
        #endif
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill

        // Header
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor.systemGray5
        avatarView.layer.cornerRadius = 26
        avatarView.clipsToBounds = true

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 52),
            avatarView.heightAnchor.constraint(equalToConstant: 52)
        ])

        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.textAlignment = .center
        avatarLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        avatarLabel.textColor = UIColor(named: "AccentColor") ?? .systemGreen
        avatarView.addSubview(avatarLabel)

        NSLayoutConstraint.activate([
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
        ])

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, requestedAtLabel])
        nameStack.axis = .vertical
        nameStack.spacing = 4
        nameStack.alignment = .leading

        headerStack.addArrangedSubview(avatarView)
        headerStack.addArrangedSubview(nameStack)

        stackView.addArrangedSubview(headerStack)

        // Provider Details
        stackView.addArrangedSubview(detailsTitleLabel)

        detailsRow.axis = .horizontal
        detailsRow.spacing = 16
        detailsRow.alignment = .center
        detailsRow.distribution = .fill

        phoneStack.axis = .horizontal
        phoneStack.spacing = 8
        phoneStack.alignment = .center

        emailStack.axis = .horizontal
        emailStack.spacing = 8
        emailStack.alignment = .center

        let phoneIcon = UIImageView(image: UIImage(systemName: "phone.fill"))
        phoneIcon.translatesAutoresizingMaskIntoConstraints = false
        phoneIcon.tintColor = .secondaryLabel
        phoneIcon.setContentHuggingPriority(.required, for: .horizontal)
        phoneIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            phoneIcon.widthAnchor.constraint(equalToConstant: 18),
            phoneIcon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let emailIcon = UIImageView(image: UIImage(systemName: "envelope.fill"))
        emailIcon.translatesAutoresizingMaskIntoConstraints = false
        emailIcon.tintColor = .secondaryLabel
        emailIcon.setContentHuggingPriority(.required, for: .horizontal)
        emailIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            emailIcon.widthAnchor.constraint(equalToConstant: 18),
            emailIcon.heightAnchor.constraint(equalToConstant: 18)
        ])

        let phoneValue = UILabel()
        phoneValue.tag = 1001
        phoneValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let emailValue = UILabel()
        emailValue.tag = 1002
        emailValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        phoneStack.addArrangedSubview(phoneIcon)
        phoneStack.addArrangedSubview(phoneValue)

        emailStack.addArrangedSubview(emailIcon)
        emailStack.addArrangedSubview(emailValue)

        detailsRow.addArrangedSubview(phoneStack)
        detailsRow.addArrangedSubview(emailStack)

        stackView.addArrangedSubview(detailsRow)

        // Skills
        stackView.addArrangedSubview(skillsTitleLabel)

        skillsWrapStack.axis = .horizontal
        skillsWrapStack.spacing = 8
        skillsWrapStack.alignment = .leading
        skillsWrapStack.distribution = .fillProportionally

        let skillsWrapContainer = WrappingStackView()
        skillsWrapContainer.translatesAutoresizingMaskIntoConstraints = false
        skillsWrapContainer.horizontalSpacing = 8
        skillsWrapContainer.verticalSpacing = 8

        stackView.addArrangedSubview(skillsWrapContainer)

        // Services
        stackView.addArrangedSubview(servicesTitleLabel)

        servicesStack.axis = .vertical
        servicesStack.spacing = 12
        servicesStack.alignment = .fill
        stackView.addArrangedSubview(servicesStack)

        // Buttons
        approveButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        rejectButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        stackView.addArrangedSubview(UIView())
        stackView.addArrangedSubview(approveButton)
        stackView.addArrangedSubview(rejectButton)

        // Keep a reference to wrapping container via tag
        skillsWrapContainer.tag = 2001
    }

    private func configureStyles() {
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        requestedAtLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        requestedAtLabel.textColor = .secondaryLabel

        detailsTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        detailsTitleLabel.text = "Provider Details"

        skillsTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        skillsTitleLabel.text = "Skills"

        servicesTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        servicesTitleLabel.text = "Services"

        approveButton.setTitle("Approve", for: .normal)
        approveButton.backgroundColor = UIColor(named: "AccentColor") ?? .systemGreen
        approveButton.setTitleColor(.white, for: .normal)
        approveButton.layer.cornerRadius = 12
        approveButton.clipsToBounds = true

        rejectButton.setTitle("Reject", for: .normal)
        rejectButton.backgroundColor = .systemGray6
        rejectButton.setTitleColor(.systemRed, for: .normal)
        rejectButton.layer.cornerRadius = 12
        rejectButton.clipsToBounds = true

        if let phoneValue = phoneStack.viewWithTag(1001) as? UILabel {
            phoneValue.font = UIFont.systemFont(ofSize: 15)
            phoneValue.textColor = .secondaryLabel
        }

        if let emailValue = emailStack.viewWithTag(1002) as? UILabel {
            emailValue.font = UIFont.systemFont(ofSize: 15)
            emailValue.textColor = .secondaryLabel
            emailValue.lineBreakMode = .byTruncatingMiddle
        }
    }

    private func configureActions() {
        approveButton.addTarget(self, action: #selector(didTapApprove), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(didTapReject), for: .touchUpInside)
    }

    func apply(request: ProviderRequestDetails?) {
        guard isViewLoaded else { return }
        guard let request else { return }

        nameLabel.text = request.name
        requestedAtLabel.text = request.requestedAtText

        let firstChar = request.name.trimmingCharacters(in: .whitespacesAndNewlines).first
        avatarLabel.text = firstChar.map { String($0).uppercased() } ?? ""

        if let phoneValue = phoneStack.viewWithTag(1001) as? UILabel {
            phoneValue.text = request.phone
        }

        if let emailValue = emailStack.viewWithTag(1002) as? UILabel {
            emailValue.text = request.email
        }

        // Skills chips
        if let skillsWrapContainer = stackView.arrangedSubviews.first(where: { $0.tag == 2001 }) as? WrappingStackView {
            skillsWrapContainer.removeAllArrangedSubviews()
            request.skills.forEach { skill in
                let chip = ChipButton(title: skill)
                skillsWrapContainer.addArrangedSubview(chip)
            }
        }

        // Services cards
        servicesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        request.services.forEach { service in
            let card = ServiceCardView(service: service)
            servicesStack.addArrangedSubview(card)
        }
    }

    @objc private func didTapApprove() {
        guard let request else { return }
        let alert = UIAlertController(
            title: "Provider Approved",
            message: "You have successfully approved \(request.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onApprove?()
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func didTapReject() {
        guard let request else { return }
        let alert = UIAlertController(
            title: "Reject Provider",
            message: "Are you sure you want to reject \(request.name)?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive) { [weak self] _ in
            self?.onReject?()
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

private final class ChipButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        setTitleColor(.white, for: .normal)
        backgroundColor = UIColor(named: "AccentColor") ?? .systemGreen
        layer.cornerRadius = 14
        contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class ServiceCardView: UIView {
    init(service: AdminProviderRequestViewController.Service) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        clipsToBounds = true

        let iconView = UIView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = UIColor(named: "AccentColor") ?? .systemGreen
        iconView.layer.cornerRadius = 20

        let iconLabel = UILabel()
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = "W"
        iconLabel.textColor = .white
        iconLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        iconLabel.textAlignment = .center
        iconView.addSubview(iconLabel)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = service.title
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)

        let priceLabel = UILabel()
        priceLabel.text = service.priceText
        priceLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        priceLabel.textColor = .secondaryLabel
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        let subtitleLabel = UILabel()
        subtitleLabel.text = service.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, priceLabel])
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .firstBaseline

        let leftStack = UIStackView(arrangedSubviews: [titleRow, subtitleLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 6
        leftStack.alignment = .leading

        let starImage = UIImageView(image: UIImage(systemName: "star.fill"))
        starImage.tintColor = UIColor.darkGray

        let ratingLabel = UILabel()
        ratingLabel.text = service.ratingText
        ratingLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        ratingLabel.textColor = .secondaryLabel

        let ratingStack = UIStackView(arrangedSubviews: [starImage, ratingLabel])
        ratingStack.axis = .horizontal
        ratingStack.spacing = 4
        ratingStack.alignment = .center

        let row = UIStackView(arrangedSubviews: [iconView, leftStack, UIView(), ratingStack])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WrappingStackView: UIView {

    var horizontalSpacing: CGFloat = 8 { didSet { setNeedsLayout() } }
    var verticalSpacing: CGFloat = 8 { didSet { setNeedsLayout() } }

    private(set) var arrangedSubviews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addArrangedSubview(_ view: UIView) {
        arrangedSubviews.append(view)
        addSubview(view)
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        arrangedSubviews.removeAll()
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        let maxWidth = bounds.width
        for v in arrangedSubviews {
            let size = v.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            v.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        let height = arrangedSubviews.map { $0.frame.maxY }.max() ?? 0
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }
}
