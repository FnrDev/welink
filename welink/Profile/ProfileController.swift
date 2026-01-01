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

// Struct to decode application data
struct ApplicationData: Decodable {
    let id: Int64
    let user_id: String
    let full_name: String
    let email: String
    let phone: String
    let image_path: String
    let services: [String]?
    let skills: [String]?
    let status: String?
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

// Struct to decode booking data
struct BookingData: Decodable {
    let id: String
    let service_id: String?
    let user_id: String?
    let created_at: String?
}

class ProfileController: UIViewController {

    // Seeker View Outlets
    @IBOutlet weak var bookingDataNumber: UILabel!
    @IBOutlet weak var bookingsViewContainer: UIView!
    @IBOutlet weak var applyToProviderBTN: UIButton!
    @IBOutlet weak var seekerView: UIView!
    
    // Provider View Outlets
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

    // Initial Avatar Outlets
    @IBOutlet weak var initialLetter: UILabel!
    @IBOutlet weak var intialAvatar: UIView!
    
    private var userSkills: [String] = []
    private var userServices: [ServiceData] = []
    private var currentUserId: String = ""
    private var currentUserName: String = ""
    private var currentUserRole: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupSkillsCollectionView()
        setupServicesTableView()
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
        
        // Hide both avatar views initially
        avatar.isHidden = true
        intialAvatar.isHidden = true
        intialAvatar.layer.cornerRadius = 12
        intialAvatar.clipsToBounds = true

        servicesIconContainer.layer.cornerRadius = 12
        servicesIconContainer.clipsToBounds = true

        servicesContainer.layer.cornerRadius = 12
        servicesContainer.clipsToBounds = true

        raitingIconContainer.layer.cornerRadius = 12
        raitingIconContainer.clipsToBounds = true

        raitings.layer.cornerRadius = 12
        raitings.clipsToBounds = true
        
        bookingsViewContainer.layer.cornerRadius = 12
        bookingsViewContainer.clipsToBounds = true
        
        applyToProviderBTN.layer.cornerRadius = 12
        applyToProviderBTN.clipsToBounds = true

        noSkillsLabel.isHidden = true
        noServicesLabel.isHidden = true

        totalServicesLabel?.text = "0"
        ratingLabel?.text = "0.0"
        bookingDataNumber?.text = "0"
        
        // Hide both views initially
        seekerView.isHidden = true
        raitings.isHidden = true
        servicesContainer.isHidden = true
    }
    
    // MARK: - Setup Avatar
    
    private func setupAvatar(imagePath: String?, userName: String) {
        if let imagePath = imagePath, !imagePath.isEmpty {
            // User has avatar - show image, hide initial
            avatar.isHidden = false
            intialAvatar.isHidden = true
            loadAvatar(from: imagePath)
        } else {
            // No avatar - show initials
            avatar.isHidden = true
            intialAvatar.isHidden = false
            
            // Get first 2 letters of name in uppercase
            let initials = String(userName.prefix(2)).uppercased()
            initialLetter.text = initials
            initialLetter.textAlignment = .center
        }
    }
    
    // MARK: - Setup UI Based on Role

    private func setupUIForRole(_ role: String) {
        if role == "seeker" {
            // Show Seeker View
            seekerView.isHidden = false
            bookingsViewContainer.isHidden = false
            applyToProviderBTN.isHidden = false
            
            // Hide Provider Views
            raitings.isHidden = true
            servicesContainer.isHidden = true
            skillsCollectionView.isHidden = true
            noSkillsLabel.isHidden = true
            servicesTableView.isHidden = true
            noServicesLabel.isHidden = true
            
            // Setup Seeker Menu (no Provider Dashboard)
            setupSeekerMenu()
            
        } else {
            // Show Provider View
            raitings.isHidden = false
            servicesContainer.isHidden = false
            
            // Hide Seeker Views
            seekerView.isHidden = true
            bookingsViewContainer.isHidden = true
            applyToProviderBTN.isHidden = true
            
            // Setup Provider Menu (with Provider Dashboard)
            setupProviderMenu()
        }
    }

    // MARK: - Setup Menus

    private func setupProviderMenu() {
        let providerDashboardAction = UIAction(title: "Provider Dashboard", image: UIImage(systemName: "square.grid.2x2")) { [weak self] _ in
            self?.openProviderDashboard()
        }

        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gearshape")) { [weak self] _ in
            self?.openSettings()
        }

        let historyAction = UIAction(title: "History", image: UIImage(systemName: "clock")) { [weak self] _ in
            self?.openHistory()
        }

        let menu = UIMenu(title: "", children: [providerDashboardAction, settingsAction, historyAction])
        menuButton.menu = menu
        menuButton.showsMenuAsPrimaryAction = true
    }
    
    private func setupSeekerMenu() {
        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gearshape")) { [weak self] _ in
            self?.openSettings()
        }

        let historyAction = UIAction(title: "History", image: UIImage(systemName: "clock")) { [weak self] _ in
            self?.openHistory()
        }

        let menu = UIMenu(title: "", children: [settingsAction, historyAction])
        menuButton.menu = menu
        menuButton.showsMenuAsPrimaryAction = true
    }

    // MARK: - Menu Actions

    private func openProviderDashboard() {
        let storyboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ProviderDashboardOnly")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    private func openSettings() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let settingsVC = storyboard.instantiateViewController(withIdentifier: "ProfileSettingsController")
        settingsVC.modalPresentationStyle = .fullScreen
        present(settingsVC, animated: true)
    }

    @IBAction func providerBTNApply(_ sender: Any) {
        Task {
            await checkPendingRequest()
        }
    }

    // MARK: - Check Pending Request

    private func checkPendingRequest() async {
        do {
            let session = try await SupabaseClientManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            print("🔍 Checking pending request for user: \(userId)")
            
            // Check if user has a pending application
            let response: [ApplicationData] = try await SupabaseClientManager.shared.client.database
                .from("applications")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            print("📋 Applications found: \(response.count)")
            
            await MainActor.run {
                if response.isEmpty {
                    print("✅ No pending request - navigating to apply page")
                    // No pending request - navigate to apply page
                    performSegue(withIdentifier: "showProviderApply", sender: nil)
                } else if let application = response.first {
                    // Check application status
                    if application.status == "rejected" {
                        print("❌ Application rejected - showing rejected alert")
                        showRejectedAlert()
                    } else if application.status == "pending" {
                        print("⏳ Application pending - showing pending alert")
                        showPendingAlert()
                    } else {
                        // Status is "accepted" - should not happen for seekers, but handle it
                        print("✅ Application accepted")
                        performSegue(withIdentifier: "showProviderApply", sender: nil)
                    }
                }
            }
            
        } catch {
            print("❌ Error checking pending request: \(error)")
            await MainActor.run {
                // If error, still allow navigation
                performSegue(withIdentifier: "showProviderApply", sender: nil)
            }
        }
    }

    // MARK: - Show Pending Alert

    private func showPendingAlert() {
        let alert = UIAlertController(
            title: "Pending Request",
            message: "You already have a pending application. Please wait for it to be reviewed.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Show Rejected Alert

    private func showRejectedAlert() {
        let alert = UIAlertController(
            title: "Application Rejected",
            message: "Your application has been rejected. Please contact support for more information.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Open History
    
    private func openHistory() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        guard let historyVC = storyboard.instantiateViewController(withIdentifier: "HistoryController") as? HistoryController else {
            return
        }
        
        // Wrap in Navigation Controller for feedback push to work
        let navController = UINavigationController(rootViewController: historyVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
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
                        currentUserRole = user.role

                        // Setup avatar (image or initials)
                        setupAvatar(imagePath: user.image, userName: user.name)
                        
                        // Setup UI based on role
                        setupUIForRole(user.role)

                        // Only show skills for providers
                        if user.role == "provider" {
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
                }

                // Fetch data based on role
                if currentUserRole == "seeker" {
                    await fetchUserBookings(userId: userId)
                } else {
                    await fetchUserServices(userId: userId)
                }

            } catch {
                print("Error fetching user: \(error)")
            }
        }
    }
    
    // MARK: - Fetch User Bookings (for Seekers)
    
    private func fetchUserBookings(userId: String) async {
        do {
            let response: [BookingData] = try await SupabaseClientManager.shared.client.database
                .from("bookings")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            await MainActor.run {
                bookingDataNumber?.text = "\(response.count)"
            }

        } catch {
            print("Error fetching bookings: \(error)")
            await MainActor.run {
                bookingDataNumber?.text = "0"
            }
        }
    }

    // MARK: - Fetch User Services (for Providers)

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
    
    // Each service is its own section
    func numberOfSections(in tableView: UITableView) -> Int {
        return userServices.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    // Add spacing between sections (cells)
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 8
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        return footerView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as? SearchResultCell else {
            return UITableViewCell()
        }
        
        let service = userServices[indexPath.section]
        cell.configure(with: service, providerName: currentUserName)
        cell.showCellBackground = true
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let service = userServices[indexPath.section]
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
