//
//  AdminDashboardViewController.swift
//  welink
//
//  Created by rawan on 21/12/2025.
//

import UIKit

class AdminDashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var providerRequestsTableView: UITableView!

    private struct ProviderRequest {
        let name: String
        let requestedAtText: String
    }

    private var providerRequests: [ProviderRequest] = [
        ProviderRequest(name: "Mohammed Ahmed", requestedAtText: "Requested at March 2, 2025"),
        ProviderRequest(name: "Fares Ali", requestedAtText: "Requested at March 2, 2025"),
        ProviderRequest(name: "Amal Yahya", requestedAtText: "Requested at March 3, 2025")
    ]

    private let providerRequestDetailsStoryboardID = "AdminProviderRequest"

    override func viewDidLoad() {
        super.viewDidLoad()

        providerRequestsTableView.dataSource = self
        providerRequestsTableView.delegate = self
        providerRequestsTableView.rowHeight = 140
        providerRequestsTableView.estimatedRowHeight = 140
        providerRequestsTableView.tableFooterView = UIView()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return providerRequests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProviderRequestCell", for: indexPath)
        let item = providerRequests[indexPath.row]

        cell.selectionStyle = .none

        if let avatarImageView = cell.viewWithTag(5) as? UIImageView {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
            avatarImageView.tintColor = UIColor.systemGray3
            avatarImageView.contentMode = .scaleAspectFill
            avatarImageView.clipsToBounds = true
            avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
        }

        if let nameLabel = cell.viewWithTag(1) as? UILabel {
            nameLabel.text = item.name
        }

        if let dateLabel = cell.viewWithTag(2) as? UILabel {
            dateLabel.text = item.requestedAtText
        }

        if let approveButton = cell.viewWithTag(3) as? UIButton {
            approveButton.tag = indexPath.row
            approveButton.removeTarget(nil, action: nil, for: .allEvents)
            approveButton.addTarget(self, action: #selector(didTapApprove(_:)), for: .touchUpInside)

            approveButton.setTitle("Approve", for: .normal)
            approveButton.backgroundColor = UIColor(named: "AccentColor") ?? UIColor.systemGreen
            approveButton.setTitleColor(.white, for: .normal)
            approveButton.layer.cornerRadius = 8
            approveButton.clipsToBounds = true
        }

        if let rejectButton = cell.viewWithTag(4) as? UIButton {
            rejectButton.tag = indexPath.row
            rejectButton.removeTarget(nil, action: nil, for: .allEvents)
            rejectButton.addTarget(self, action: #selector(didTapReject(_:)), for: .touchUpInside)

            rejectButton.setTitle("Reject", for: .normal)
            rejectButton.backgroundColor = UIColor.systemGray5
            rejectButton.setTitleColor(.systemRed, for: .normal)
            rejectButton.layer.cornerRadius = 8
            rejectButton.clipsToBounds = true
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "AdminDashboard", bundle: nil)
        let detailsVC = storyboard.instantiateViewController(withIdentifier: providerRequestDetailsStoryboardID)
        navigationController?.pushViewController(detailsVC, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }

    @objc private func didTapApprove(_ sender: UIButton) {
        let index = sender.tag
        guard providerRequests.indices.contains(index) else { return }
        let item = providerRequests[index]

        let alert = UIAlertController(title: "Provider Approved",
                                      message: "You have successfully approved \(item.name).",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func didTapReject(_ sender: UIButton) {
        let index = sender.tag
        guard providerRequests.indices.contains(index) else { return }
        let item = providerRequests[index]

        let alert = UIAlertController(title: "Reject Provider",
                                      message: "Are you sure you want to reject \(item.name)?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reject", style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.providerRequests.remove(at: index)
            self.providerRequestsTableView.reloadData()
        }))
        present(alert, animated: true)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
