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
    @IBOutlet weak var servicesTableView: UITableView!
    @IBOutlet weak var noServicesLabel: UILabel!
    @IBOutlet weak var totalServicesLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!

    private var userSkills: [String] = []
    private var userServices: [ServiceData] = []
    private var currentUserId: String = ""
    private var currentUserName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupSkillsCollectionView()
        setupServicesTableView()
        setupMenu()
        fetchUserProfile()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchUserProfile()
    }

    // MARK: - Setup UI

    private func setupUI() {
        avatar.layer.cornerRadius = 12
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill

        servicesIconContainer.layer.cornerRadius = 12
        servicesIconContainer.clipsToBounds = true

        servicesContainer.layer.cornerRadius = 12
        servicesContainer.clipsToBounds = true

        raitingIconContainer.layer.cornerRadius = 12
        raitingIconContainer.clipsToBounds = true

        raitings.layer.cornerRadius = 12
        raitings.clipsToBounds = true

        noSkillsLabel.isHidden = true
        noServicesLabel.isHidden = true

        totalServicesLabel?.text = "0"
        ratingLabel?.text = "0.0"
    }

    // MARK: - Setup Menu

    private func setupMenu() {
        let providerDashboard = UIAction(title: "Provider Dashboard", image: UIImage(systemName: "hammer.fill")) { _ in
            self.openProviderDashboard()
        }

        let settings = UIAction(title: "Settings", image: UIImage(systemName: "gear")) { _ in
            self.openSettings()
        }

        let history = UIAction(title: "History", image: UIImage(systemName: "clock.arrow.circlepath")) { _ in
            self.openHistory()
        }

        let menu = UIMenu(title: "", children: [providerDashboard, settings, history])

        menuButton.menu = menu
        menuButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Menu Actions

    private func openProviderDashboard() {
        let storyboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ProviderDashboardVC")
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func openSettings() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let settingsVC = storyboard.instantiateViewController(withIdentifier: "ProfileSettingsController")
        settingsVC.modalPresentationStyle = .fullScreen
        present(settingsVC, animated: true)
    }

    private func openHistory() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let historyVC = storyboard.instantiateViewController(withIdentifier: "HistoryController")
        historyVC.modalPresentationStyle = .fullScreen
        present(historyVC, animated: true)
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

    // MARK: - Setup Services Table View

    private func setupServicesTableView() {
        servicesTableView.delegate = self
        servicesTableView.dataSource = self
        
        let nib = UINib(nibName: "SearchResultCell", bundle: nil)
        servicesTableView.register(nib, forCellReuseIdentifier: "SearchResultCell")
        
        servicesTableView.rowHeight = 80
        servicesTableView.separatorStyle = .none
        servicesTableView.backgroundColor = .clear
        servicesTableView.showsVerticalScrollIndicator = false
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
                        header.title = user.name
                        currentUserName = user.name

                        if let imagePath = user.image, !imagePath.isEmpty {
                            loadAvatar(from: imagePath)
                        }

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
                    servicesTableView.isHidden = false
                    noServicesLabel.isHidden = true
                    servicesTableView.reloadData()
                    updateStats()
                } else {
                    userServices = []
                    servicesTableView.isHidden = true
                    noServicesLabel.isHidden = false
                    noServicesLabel.text = "The user has not listed any services."
                    totalServicesLabel?.text = "0"
                    ratingLabel?.text = "0.0"
                }
            }

        } catch {
            print("Error fetching services: \(error)")
        }
    }

    // MARK: - Stats

    private func updateStats() {
        totalServicesLabel?.text = "\(userServices.count)"

        let ratings = userServices.compactMap { $0.rating }
        let avg = ratings.isEmpty ? 0 : (ratings.reduce(0, +) / Double(ratings.count))

        ratingLabel?.text = String(format: "%.1f", avg)
    }

    // MARK: - Navigate to Service Details

    private func navigateToServiceDetails(serviceId: String) {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let serviceDetailsVC = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
            return
        }

        serviceDetailsVC.serviceId = serviceId

        if let navController = navigationController {
            navController.pushViewController(serviceDetailsVC, animated: true)
        } else {
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
        return userSkills.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SkillCell", for: indexPath) as! SkillCell
        cell.configure(with: userSkills[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let skill = userSkills[indexPath.item]
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        let width = skill.size(withAttributes: [.font: font]).width + 32
        return CGSize(width: width, height: 36)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource

extension ProfileController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            return UITableViewCell()
        }
        
        let service = userServices[indexPath.row]
        cell.configure(with: service, providerName: currentUserName)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let service = userServices[indexPath.row]
        navigateToServiceDetails(serviceId: service.id)
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
