//
//  ProfileController.swift
//  welink
//
//  Created by Ali Matar on 22/12/2025.
//

import UIKit

// Struct to decode user data
struct ProfileUserData: Decodable {
    let id: String
    let name: String
    let phone: String
    let image: String?
    let role: String
    let services: [String]?
    let skills: [String]?
}

// Struct to decode service data
struct ServiceData: Decodable {
    let id: String
    let name: String
    let description: String?
    let price_per_hour: Double?
    let image: String?
    let user_id: String?
    let categories: [String]?

    // ⭐️ Add this (must exist in your DB or be returned by query). Optional so it won't crash if missing.
    let rating: Double?
}

class ProfileController: UIViewController {

    @IBOutlet weak var header: UINavigationItem!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var servicesIconContainer: UIView!
    @IBOutlet weak var servicesContainer: UIView!
    @IBOutlet weak var skillsCollectionView: UICollectionView!
    @IBOutlet weak var raitingIconContainer: UIView!
    @IBOutlet weak var raitings: UIView!
    @IBOutlet weak var noSkillsLabel: UILabel!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var servicesCollectionView: UICollectionView!
    @IBOutlet weak var noServicesLabel: UILabel!

    // ✅ NEW: connect these from storyboard
    @IBOutlet weak var totalServicesLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var starsStackView: UIStackView! // contains 5 UIImageViews

    // Store skills for collection view
    private var userSkills: [String] = []

    // Store services for collection view
    private var userServices: [ServiceData] = []

    // Store user ID
    private var currentUserId: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupSkillsCollectionView()
        setupServicesCollectionView()
        setupMenu()
        fetchUserProfile()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh data every time the page appears
        fetchUserProfile()
    }

    // MARK: - Setup UI

    private func setupUI() {
        // Avatar - rounded corners
        avatar.layer.cornerRadius = 12
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill

        // Services icon container - rounded
        servicesIconContainer.layer.cornerRadius = 12
        servicesIconContainer.clipsToBounds = true

        // Services container - rounded
        servicesContainer.layer.cornerRadius = 12
        servicesContainer.clipsToBounds = true

        // Rating icon container - rounded
        raitingIconContainer.layer.cornerRadius = 12
        raitingIconContainer.clipsToBounds = true

        // Ratings view - rounded
        raitings.layer.cornerRadius = 12
        raitings.clipsToBounds = true

        // Hide labels initially
        noSkillsLabel.isHidden = true
        noServicesLabel.isHidden = true

        // Default stats
        totalServicesLabel?.text = "0"
        ratingLabel?.text = "0.0"
        updateStars(average: 0)
    }

    // MARK: - Setup Menu

    private func setupMenu() {
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
    }

    @objc private func menuButtonTapped() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Provider Dashboard", style: .default) { [weak self] _ in
            self?.openProviderDashboard()
        })

        actionSheet.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
            self?.openSettings()
        })

        actionSheet.addAction(UIAlertAction(title: "History", style: .default) { [weak self] _ in
            self?.openHistory()
        })

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = menuButton
            popover.sourceRect = menuButton.bounds
        }

        self.present(actionSheet, animated: true)
    }

    // MARK: - Menu Actions

    private func openProviderDashboard() {
        let storyboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ProviderDashboardOnly")

        // Change the window's root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()

        // Add transition animation
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    private func openSettings() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let settingsVC = storyboard.instantiateViewController(withIdentifier: "ProfileSettingsController")
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    private func openHistory() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let historyVC = storyboard.instantiateViewController(withIdentifier: "HistoryController")
        navigationController?.pushViewController(historyVC, animated: true)
    }

    // MARK: - Setup Skills Collection View

    private func setupSkillsCollectionView() {
        skillsCollectionView.delegate = self
        skillsCollectionView.dataSource = self
        skillsCollectionView.register(SkillCell.self, forCellWithReuseIdentifier: "SkillCell")
        skillsCollectionView.tag = 1

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        skillsCollectionView.collectionViewLayout = layout
        skillsCollectionView.backgroundColor = .clear
        skillsCollectionView.showsHorizontalScrollIndicator = false
    }

    // MARK: - Setup Services Collection View

    private func setupServicesCollectionView() {
        servicesCollectionView.delegate = self
        servicesCollectionView.dataSource = self
        servicesCollectionView.register(ServiceImageCell.self, forCellWithReuseIdentifier: "ServiceImageCell")
        servicesCollectionView.tag = 2

        // Enable selection
        servicesCollectionView.allowsSelection = true
        servicesCollectionView.isUserInteractionEnabled = true
        print("🔥 Collection view setup: allowsSelection=\(servicesCollectionView.allowsSelection), isUserInteractionEnabled=\(servicesCollectionView.isUserInteractionEnabled)")

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        servicesCollectionView.collectionViewLayout = layout
        servicesCollectionView.backgroundColor = .clear
        servicesCollectionView.showsVerticalScrollIndicator = false
    }

    // MARK: - Fetch User Profile

    private func fetchUserProfile() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                let userId = session.user.id.uuidString
                currentUserId = userId

                let response: [ProfileUserData] = try await SupabaseClientManager.shared.client.database
                    .from("users")
                    .select()
                    .eq("id", value: userId)
                    .execute()
                    .value

                if let user = response.first {
                    await MainActor.run {
                        // Set header title
                        header.title = user.name

                        // Load avatar if available
                        if let imagePath = user.image, !imagePath.isEmpty {
                            loadAvatar(from: imagePath)
                        }

                        // Load skills
                        if let skills = user.skills, !skills.isEmpty {
                            userSkills = skills
                            skillsCollectionView.isHidden = false
                            noSkillsLabel.isHidden = true
                            skillsCollectionView.reloadData()
                        } else {
                            skillsCollectionView.isHidden = true
                            noSkillsLabel.isHidden = false
                            noSkillsLabel.text = "The user has not listed any skills."
                        }
                    }
                }

                // Fetch services
                await fetchUserServices(userId: userId)

            } catch {
                print("Error fetching user: \(error)")
            }
        }
    }

    // MARK: - Fetch User Services

    private func fetchUserServices(userId: String) async {
        do {
            let response: [ServiceData] = try await SupabaseClientManager.shared.client.database
                .from("services")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            await MainActor.run {
                if !response.isEmpty {
                    userServices = response
                    servicesCollectionView.isHidden = false
                    noServicesLabel.isHidden = true
                    servicesCollectionView.reloadData()

                    updateStats()
                } else {
                    userServices = []
                    servicesCollectionView.isHidden = true
                    noServicesLabel.isHidden = false
                    noServicesLabel.text = "The user has not listed any services."

                    // reset stats
                    totalServicesLabel.text = "0"
                    ratingLabel.text = "0.0"
                    updateStars(average: 0)
                }
            }

        } catch {
            print("Error fetching services: \(error)")
        }
    }

    // MARK: - Stats (Total services + average rating out of 5)

    private func updateStats() {
        totalServicesLabel.text = "\(userServices.count)"

        let ratings = userServices.compactMap { $0.rating }
        let avg = ratings.isEmpty ? 0 : (ratings.reduce(0, +) / Double(ratings.count))

        ratingLabel.text = String(format: "%.1f", avg)
        updateStars(average: avg)
    }

    private func updateStars(average: Double) {
        // If you didn't connect starsStackView yet, avoid crashing.
        guard let starsStackView = starsStackView else { return }

        let fullStars = max(0, min(5, Int(average.rounded(.down))))
        let hasHalf = (average - Double(fullStars)) >= 0.5

        for (index, view) in starsStackView.arrangedSubviews.enumerated() {
            guard let iv = view as? UIImageView else { continue }
            let starIndex = index + 1

            if starIndex <= fullStars {
                iv.image = UIImage(systemName: "star.fill")
            } else if starIndex == fullStars + 1 && hasHalf {
                iv.image = UIImage(systemName: "star.leadinghalf.filled")
            } else {
                iv.image = UIImage(systemName: "star")
            }
        }
    }

    // MARK: - Navigation

    private func navigateToServiceDetails(serviceId: String) {
        print("🔥 navigateToServiceDetails called with serviceId: \(serviceId)")

        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let serviceDetailsVC = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
            print("❌ Could not instantiate ServiceDetailsViewController")
            return
        }

        print("🔥 ServiceDetailsViewController instantiated successfully")

        // Pass the service ID
        serviceDetailsVC.serviceId = serviceId

        // Check if we have navigation controller
        if let navController = navigationController {
            print("🔥 Navigation controller found, pushing view controller")
            navController.pushViewController(serviceDetailsVC, animated: true)
        } else {
            print("🔥 No navigation controller found, presenting modally")
            // Wrap in navigation controller for modal presentation
            let navController = UINavigationController(rootViewController: serviceDetailsVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }

    // MARK: - Load Avatar

    private func loadAvatar(from path: String) {
        let imageURL: URL?

        if path.starts(with: "http") {
            imageURL = URL(string: path)
        } else {
            imageURL = try? SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: path)
        }

        guard let url = imageURL else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        avatar.image = image
                    }
                }
            } catch {
                print("Error loading avatar: \(error)")
            }
        }
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource

extension ProfileController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 1 {
            return userSkills.count
        } else {
            return userServices.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SkillCell", for: indexPath) as! SkillCell
            cell.configure(with: userSkills[indexPath.item])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ServiceImageCell", for: indexPath) as! ServiceImageCell
            let service = userServices[indexPath.item]
            cell.configure(with: service.image)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.tag == 1 {
            let skill = userSkills[indexPath.item]
            let font = UIFont.systemFont(ofSize: 14, weight: .medium)
            let width = skill.size(withAttributes: [.font: font]).width + 32
            return CGSize(width: width, height: 36)
        } else {
            // 3 columns grid
            let spacing: CGFloat = 8
            let totalSpacing = spacing * 2
            let width = (collectionView.frame.width - totalSpacing) / 3
            return CGSize(width: width, height: width)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("🔥 Collection view tapped! Tag: \(collectionView.tag), IndexPath: \(indexPath)")

        // Only handle selection for services collection view (tag 2)
        if collectionView.tag == 2 {
            print("🔥 Services collection view tapped!")
            guard indexPath.item < userServices.count else {
                print("❌ Index out of bounds: \(indexPath.item) >= \(userServices.count)")
                return
            }

            let service = userServices[indexPath.item]
            print("🔥 Navigating to service: \(service.name) with ID: \(service.id)")
            navigateToServiceDetails(serviceId: service.id)
        } else {
            print("🔥 Skills collection view tapped (tag: \(collectionView.tag))")
        }
    }
}

// MARK: - Skill Cell

class SkillCell: UICollectionViewCell {

    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = UIColor(red: 45/255, green: 73/255, blue: 58/255, alpha: 1.0)
        contentView.layer.cornerRadius = 18
        contentView.clipsToBounds = true

        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with skill: String) {
        label.text = skill
    }
}

// MARK: - Service Image Cell

class ServiceImageCell: UICollectionViewCell {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = .systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func configure(with imagePath: String?) {
        guard let path = imagePath, !path.isEmpty else {
            imageView.image = UIImage(systemName: "photo")
            return
        }

        let imageURL: URL?

        if path.starts(with: "http") {
            imageURL = URL(string: path)
        } else {
            imageURL = try? SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: path)
        }

        guard let url = imageURL else {
            imageView.image = UIImage(systemName: "photo")
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.imageView.image = image
                    }
                }
            } catch {
                print("Error loading service image: \(error)")
            }
        }
    }
}

