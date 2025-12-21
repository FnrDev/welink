//
//  AllReviewsViewController.swift
//  welink
//
//  Created by Zahra on 21/12/2025.
//

import UIKit
import Supabase

class AllReviewsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var serviceId: String?
    var serviceName: String?
    private var ratings: [ServiceRating] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = serviceName ?? "All Reviews"
        setupTableView()
        fetchAllRatings()
    }

    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
    }

    func fetchAllRatings() {
        guard let serviceId = serviceId else {
            print("❌ No service ID provided")
            return
        }

        Task {
            do {
                let response: [RatingWithUser] = try await SupabaseClientManager.shared.client
                    .database
                    .from("ratings")
                    .select("*, users(name, image)")
                    .eq("service_id", value: serviceId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                self.ratings = response.map {
                    var rating = ServiceRating(
                        id: $0.id,
                        serviceId: $0.service_id,
                        userId: $0.user_id,
                        reviewContent: $0.review_content,
                        starsCount: $0.stars_count,
                        createdAt: $0.created_at
                    )
                    rating.userName = $0.users?.name
                    rating.userImage = $0.users?.image
                    return rating
                }

                await MainActor.run {
                    self.tableView.reloadData()
                }

            } catch {
                print("❌ Error fetching reviews:", error)
            }
        }
    }
}

// MARK: - TableView
extension AllReviewsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ratings.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "ReviewCell",
            for: indexPath
        ) as! ReviewTableViewCell

        cell.configure(with: ratings[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {

        let isLast = indexPath.row == ratings.count - 1
        cell.separatorInset = isLast
            ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
            : UIEdgeInsets(top: 0, left: 70, bottom: 0, right: 0)
    }
}
