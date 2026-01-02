//
//  AdminServiceDetailsViewController.swift
//  welink
//
//  Created by rawan on 25/12/2025.
//

import UIKit
import Supabase

class AdminServiceDetailsViewController: UIViewController {

    private struct AdminServiceDetailsModel {
        let id: String
        let name: String
        let description: String?
        let pricePerHour: Double?
        let image: String?
        let userId: String?
        let providerName: String?
        let providerImage: String?
        let startDate: String?
        let endDate: String?
        let categories: [String]?
    }

    @IBOutlet private weak var serviceImageView: UIImageView?
    @IBOutlet private weak var profileImageView: UIImageView?
    @IBOutlet private weak var providerNameLabel: UILabel?
    @IBOutlet private weak var ratingLabel: UILabel?
    @IBOutlet private weak var descriptionLabel: UILabel?
    @IBOutlet private weak var priceLabel: UILabel?
    @IBOutlet private weak var dateLabel: UILabel?
    @IBOutlet private weak var timeLabel: UILabel?
    @IBOutlet private weak var reviewsTableView: UITableView?
    @IBOutlet private weak var reviewsTableViewHeight: AnyObject?
    @IBOutlet private weak var seeAllButton: UIButton?

    var serviceId: String?

    private var service: AdminServiceDetailsModel?
    private var ratings: [ServiceRating] = []
    private var didBindAfterLayout = false
    private var resolvedReviewsTableHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        bindFallbackViewsIfNeeded()
        setupReviewsTableView()
        setupSeeAllButton()

        guard let serviceId else {
            showError(message: "No service data available")
            return
        }

        fetchServiceDetails(serviceId: serviceId)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !didBindAfterLayout {
            didBindAfterLayout = true
            bindFallbackViewsIfNeeded()
            setupReviewsTableView()
        }
    }

    private func bindFallbackViewsIfNeeded() {
        if serviceImageView == nil {
            serviceImageView = findImageView { $0.bounds.height >= 140 }
        }

        if profileImageView == nil {
            profileImageView = findImageView { imageView in
                let size = min(imageView.bounds.width, imageView.bounds.height)
                return size > 0 && size <= 90
            }
        }

        if providerNameLabel == nil {
            providerNameLabel = findLabel(containing: "Sumaya")
        }

        if ratingLabel == nil {
            ratingLabel = findLabel(containing: "★★★★★")
        }

        if descriptionLabel == nil {
            descriptionLabel = findLabel(containing: "Specialized")
        }

        if priceLabel == nil {
            priceLabel = findLabel(containing: "BD")
        }

        if dateLabel == nil {
            dateLabel = findLabel(containing: "/")
        }

        if timeLabel == nil {
            timeLabel = findLabel(containing: "AM") ?? findLabel(containing: "PM")
        }

        if reviewsTableView == nil {
            reviewsTableView = findFirstView(ofType: UITableView.self)
        }

        resolvedReviewsTableHeightConstraint = (reviewsTableViewHeight as? NSLayoutConstraint)
        if resolvedReviewsTableHeightConstraint == nil {
            resolvedReviewsTableHeightConstraint = reviewsTableView?.constraints.first(where: {
                $0.firstAttribute == .height && $0.relation == .equal
            })
        }

        if seeAllButton == nil {
            seeAllButton = findButton(restorationIdentifier: "showAllReviews")
        }
    }

    private func setupSeeAllButton() {
        seeAllButton?.addTarget(self, action: #selector(seeAllReviewsTapped(_:)), for: .touchUpInside)
    }

    private func setupReviewsTableView() {
        reviewsTableView?.delegate = self
        reviewsTableView?.dataSource = self
        reviewsTableView?.rowHeight = UITableView.automaticDimension
        reviewsTableView?.estimatedRowHeight = 100
        reviewsTableView?.isScrollEnabled = false
    }

    private func fetchServiceDetails(serviceId: String) {
        Task {
            do {
                let response: ServiceWithUser = try await SupabaseClientManager.shared.client
                    .database
                    .from("services")
                    .select("*, users(name, image)")
                    .eq("id", value: serviceId)
                    .single()
                    .execute()
                    .value

                let mapped = AdminServiceDetailsModel(
                    id: response.id,
                    name: response.name,
                    description: response.description ?? "No description",
                    pricePerHour: response.price_per_hour,
                    image: response.image,
                    userId: response.user_id,
                    providerName: response.users?.name,
                    providerImage: response.users?.image,
                    startDate: response.start_date,
                    endDate: response.end_date,
                    categories: response.categories
                )

                self.service = mapped
                await fetchRatings(serviceId: serviceId)
                await MainActor.run {
                    self.displayServiceData(mapped)
                }
            } catch {
                print("❌ Error fetching admin service details: \(error)")
                await MainActor.run {
                    self.showError(message: "Failed to load service details")
                }
            }
        }
    }

    private func fetchRatings(serviceId: String) async {
        do {
            let response: [RatingWithUser] = try await SupabaseClientManager.shared.client
                .database
                .from("ratings")
                .select("*, users(name, image)")
                .eq("service_id", value: serviceId)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.ratings = response.map { rating in
                var serviceRating = ServiceRating(
                    id: rating.id,
                    serviceId: rating.service_id,
                    userId: rating.user_id,
                    reviewContent: rating.review_content,
                    starsCount: rating.stars_count,
                    createdAt: rating.created_at
                )
                serviceRating.userName = rating.users?.name
                serviceRating.userImage = rating.users?.image
                return serviceRating
            }

            await MainActor.run {
                self.updateRatingDisplay()
            }
        } catch {
            print("❌ Error fetching admin ratings: \(error)")
        }
    }

    private func displayServiceData(_ service: AdminServiceDetailsModel) {
        title = service.name

        providerNameLabel?.text = service.providerName ?? "Unknown Provider"
        descriptionLabel?.text = service.description
        priceLabel?.text = String(format: "%.0f BD/hr", service.pricePerHour ?? 0)

        if let imageUrl = service.image {
            loadImage(from: imageUrl, into: serviceImageView)
        }

        if let profileImageView {
            profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
            profileImageView.clipsToBounds = true
            profileImageView.contentMode = .scaleAspectFill
        }

        if let providerImageUrl = service.providerImage,
           let url = URL(string: providerImageUrl),
           !providerImageUrl.isEmpty {
            loadProviderImageAsync(from: url, providerName: service.providerName)
        } else {
            let initial: String
            if let providerName = service.providerName, !providerName.isEmpty {
                initial = String(providerName.prefix(1)).uppercased()
            } else {
                initial = "?"
            }
            profileImageView?.image = createInitialImage(text: initial, size: CGSize(width: 60, height: 60))
            profileImageView?.contentMode = .scaleAspectFit
        }

        dateLabel?.text = "Available"
        timeLabel?.text = "Select time"
    }

    private func updateRatingDisplay() {
        let averageRating = calculateAverageRating()

        if averageRating > 0 {
            let fullStars = Int(round(averageRating))
            let emptyStars = max(0, 5 - fullStars)
            let starString = String(repeating: "★", count: fullStars) + String(repeating: "☆", count: emptyStars)
            ratingLabel?.text = starString
        } else {
            ratingLabel?.text = "☆☆☆☆☆"
        }

        reviewsTableView?.reloadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.updateReviewsTableHeight()
        }
    }

    private func calculateAverageRating() -> Double {
        guard !ratings.isEmpty else { return 0 }
        let sum = ratings.reduce(0) { $0 + $1.starsCount }
        return Double(sum) / Double(ratings.count)
    }

    private func updateReviewsTableHeight() {
        guard let reviewsTableView else { return }
        reviewsTableView.layoutIfNeeded()
        DispatchQueue.main.async {
            self.resolvedReviewsTableHeightConstraint?.constant = reviewsTableView.contentSize.height
            self.view.layoutIfNeeded()
        }
    }

    private func loadImage(from urlString: String, into imageView: UIImageView?) {
        guard let imageView else { return }
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        imageView.image = image
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }

    private func loadProviderImageAsync(from url: URL, providerName: String?) {
        if let name = providerName, !name.isEmpty {
            let initial = String(name.prefix(1)).confirmingToUppercaseIfNeeded()
            profileImageView?.image = createInitialImage(text: initial, size: CGSize(width: 60, height: 60))
            profileImageView?.contentMode = .scaleAspectFit
        } else {
            profileImageView?.image = createInitialImage(text: "?", size: CGSize(width: 60, height: 60))
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.profileImageView?.image = image
                        self.profileImageView?.contentMode = .scaleAspectFill
                        self.profileImageView?.clipsToBounds = true
                        if let profileImageView = self.profileImageView {
                            profileImageView.layer.cornerRadius = profileImageView.frame.width / 2
                        }
                    }
                }
            } catch {
                print("Failed to load provider image: \(error)")
            }
        }
    }

    private func createInitialImage(text: String, size: CGSize = CGSize(width: 60, height: 60)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray4.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width / 2, weight: .medium),
                .foregroundColor: UIColor.label
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

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func seeAllReviewsTapped(_ sender: UIButton) {
        guard let service else {
            print("❌ No service available")
            return
        }

        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AdminAllReviewsVC")
        guard let allReviewsVC = vc as? AllReviewsViewController else {
            let alert = UIAlertController(
                title: "Setup Error",
                message: "To view all reviews from Admin, add a scene to AdminDashboard.storyboard with class AllReviewsViewController and Storyboard ID AdminAllReviewsVC.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        allReviewsVC.serviceId = service.id
        allReviewsVC.serviceName = service.name
        navigationController?.pushViewController(allReviewsVC, animated: true)
    }
}

extension AdminServiceDetailsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        min(ratings.count, 2)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell", for: indexPath) as? ReviewTableViewCell else {
            return UITableViewCell()
        }

        let rating = ratings[indexPath.row]
        cell.configure(with: rating)
        cell.selectionStyle = .none
        return cell
    }
}

private extension AdminServiceDetailsViewController {

    func findFirstView<T: UIView>(ofType type: T.Type) -> T? {
        return view.allSubviews().compactMap { $0 as? T }.first
    }

    func findImageView(where predicate: (UIImageView) -> Bool) -> UIImageView? {
        let candidates = view.allSubviews().compactMap { $0 as? UIImageView }
        return candidates.first(where: { predicate($0) })
    }

    func findLabel(containing text: String) -> UILabel? {
        let labels = view.allSubviews().compactMap { $0 as? UILabel }
        return labels.first(where: { ($0.text ?? "").localizedCaseInsensitiveContains(text) })
    }

    func findButton(restorationIdentifier: String) -> UIButton? {
        let buttons = view.allSubviews().compactMap { $0 as? UIButton }
        return buttons.first(where: { $0.restorationIdentifier == restorationIdentifier })
    }
}

private extension UIView {
    func allSubviews() -> [UIView] {
        var result: [UIView] = []
        var stack: [UIView] = [self]
        while let current = stack.popLast() {
            result.append(current)
            stack.append(contentsOf: current.subviews)
        }
        return result
    }
}

private extension String {
    func confirmingToUppercaseIfNeeded() -> String {
        uppercased()
    }
}
