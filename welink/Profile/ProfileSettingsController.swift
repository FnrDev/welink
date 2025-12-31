//
//  ProfileSettingsController.swift
//  welink
//
//  Created by Ali Matar on 23/12/2025.
//

import UIKit
import PhotosUI

// Struct for updating user profile
struct UpdateUserRequest: Encodable {
    let name: String
    let phone: String
    let image: String?
}

class ProfileSettingsController: UIViewController {

    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var saveChangesBTN: UIButton!
    @IBOutlet weak var phoneNumber: UITextField!
    @IBOutlet weak var fullName: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var userAvatar: UIImageView!
    @IBOutlet weak var profileView: UIView!
    @IBOutlet weak var preferencesView: UIView!
    @IBOutlet weak var pincleView: UIView!
    @IBOutlet weak var changePasswordView: UIView!
    @IBOutlet weak var logoutBTN: UIButton!
    @IBOutlet weak var darkThemeContainer: UIView!
    
    @IBOutlet weak var darkThemeToogle: UISwitch!
    @IBOutlet weak var intialAvatar: UIView!
    @IBOutlet weak var intialLetter: UILabel!
    
    @IBOutlet weak var pincleEdit: UIView!
    private var currentUserId: String = ""
    private var currentUserName: String = ""
    private var currentImagePath: String?
    private var selectedImage: UIImage?
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        setupUI()
        setupSegmentedControl()
        setupChangePassword()
        setupLogout()
        setupDarkThemeToggle()
        fetchUserProfile()
        
        saveChangesBTN.addTarget(self, action: #selector(saveChangesTapped(_:)), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Avatar circular
        let size = min(userAvatar.frame.width, userAvatar.frame.height)
        userAvatar.layer.cornerRadius = size / 2
        
        // Initial avatar circular (same size as userAvatar)
        let initialSize = min(intialAvatar.frame.width, intialAvatar.frame.height)
        intialAvatar.layer.cornerRadius = initialSize / 2
        
        pincleEdit.layer.cornerRadius = pincleView.frame.height / 2
        // Pincle view full rounded (pill shape)
        pincleView.layer.cornerRadius = pincleView.frame.height / 2
    }
    
    // MARK: - Setup Logout
    
    private func setupLogout() {
        logoutBTN.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
    }
    
    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        
        let logoutAction = UIAlertAction(title: "Logout", style: .destructive) { _ in
            Task {
                await self.performLogout()
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(logoutAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func setupDarkThemeToggle() {
        // Load saved preference
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        darkThemeToogle.isOn = isDarkMode
        
        // Add action for toggle change
        darkThemeToogle.addTarget(self, action: #selector(darkThemeChanged(_:)), for: .valueChanged)
    }

    @objc private func darkThemeChanged(_ sender: UISwitch) {
        AppDelegate.setDarkMode(sender.isOn)
    }
    
    private func performLogout() async {
        do {
            try await SupabaseClientManager.shared.client.auth.signOut()
            
            await MainActor.run {
                // Navigate to login screen
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let loginVC = storyboard.instantiateViewController(withIdentifier: "ViewController")
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = loginVC
                    window.makeKeyAndVisible()
                    
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                }
            }
        } catch {
            print("Error logging out: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to logout: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Setup Change Password
    
    private func setupChangePassword() {
        let changePasswordTap = UITapGestureRecognizer(target: self, action: #selector(changePasswordTapped))
        changePasswordView.isUserInteractionEnabled = true
        changePasswordView.addGestureRecognizer(changePasswordTap)
    }
    
    @objc private func changePasswordTapped() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        let resetPasswordVC = storyboard.instantiateViewController(withIdentifier: "forgetPassword")
        resetPasswordVC.modalPresentationStyle = .fullScreen
        present(resetPasswordVC, animated: true)
    }
    
    // MARK: - Setup Segmented Control
    
    private func setupSegmentedControl() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        
        // Show profile by default
        profileView.isHidden = false
        preferencesView.isHidden = true
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // Profile selected
            profileView.isHidden = false
            preferencesView.isHidden = true
            navigationBar.topItem?.title = "Settings"
        } else {
            // Preferences selected
            profileView.isHidden = true
            preferencesView.isHidden = false
            navigationBar.topItem?.title = "Preferences"
        }
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Avatar styling
        userAvatar.clipsToBounds = true
        userAvatar.contentMode = .scaleAspectFill
        userAvatar.isUserInteractionEnabled = true
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        userAvatar.addGestureRecognizer(avatarTapGesture)
        
        // Initial avatar styling
        intialAvatar.clipsToBounds = true
        intialAvatar.isUserInteractionEnabled = true
        
        let initialAvatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        intialAvatar.addGestureRecognizer(initialAvatarTapGesture)
        
        // Hide both avatar views initially
        userAvatar.isHidden = true
        intialAvatar.isHidden = true
        
        // Save button styling
        saveChangesBTN.layer.cornerRadius = 12
        
        // Profile view rounded corners
        profileView.layer.cornerRadius = 12
        profileView.clipsToBounds = true
        
        // Preferences view rounded corners
        preferencesView.layer.cornerRadius = 12
        preferencesView.clipsToBounds = true
        
        // Pincle view styling
        pincleView.clipsToBounds = true
        
        // Change password view styling
        changePasswordView.layer.cornerRadius = 12
        changePasswordView.clipsToBounds = true
        
        // Dark theme container styling
        darkThemeContainer.layer.cornerRadius = 12
        darkThemeContainer.clipsToBounds = true
        
        // Logout button styling
        logoutBTN.layer.cornerRadius = 12
    }
    
    private func setupNavigationBar() {
        let config = UIImage.SymbolConfiguration(weight: .semibold)
        let chevronImage = UIImage(systemName: "chevron.left", withConfiguration: config)
        
        let backButton = UIButton(type: .system)
        backButton.setImage(chevronImage, for: .normal)
        backButton.setTitle(" Back", for: .normal)
        backButton.tintColor = .systemBlue
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let barButton = UIBarButtonItem(customView: backButton)
        
        navigationBar.topItem?.leftBarButtonItem = barButton
        navigationBar.topItem?.title = "Settings"
    }
    
    // MARK: - Setup Avatar
    
    private func setupAvatar(imagePath: String?, userName: String) {
        if let imagePath = imagePath, !imagePath.isEmpty {
            // User has avatar - show image, hide initial
            userAvatar.isHidden = false
            intialAvatar.isHidden = true
            loadAvatar(from: imagePath)
        } else {
            // No avatar - show initials
            userAvatar.isHidden = true
            intialAvatar.isHidden = false
            
            // Get first 2 letters of name in uppercase
            let initials = String(userName.prefix(2)).uppercased()
            intialLetter.text = initials
            intialLetter.textAlignment = .center
        }
    }
    
    // MARK: - Fetch User Profile
    
    private func fetchUserProfile() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                currentUserId = session.user.id.uuidString
                
                await MainActor.run {
                    email.text = session.user.email
                }
                
                let response: [ProfileUserData] = try await SupabaseClientManager.shared.client.database
                    .from("users")
                    .select()
                    .eq("id", value: currentUserId)
                    .execute()
                    .value
                
                if let user = response.first {
                    await MainActor.run {
                        fullName.text = user.name
                        phoneNumber.text = user.phone
                        currentImagePath = user.image
                        currentUserName = user.name
                        
                        // Setup avatar (image or initials)
                        setupAvatar(imagePath: user.image, userName: user.name)
                    }
                }
                
            } catch {
                print("Error fetching user: \(error)")
            }
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
                        userAvatar.image = image
                    }
                }
            } catch {
                print("Error loading avatar: \(error)")
            }
        }
    }
    
    // MARK: - Avatar Tap (Change Photo)
    
    @objc private func avatarTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Save Changes
    
    @objc func saveChangesTapped(_ sender: UIButton) {
        print("Save button tapped")
        
        guard let name = fullName.text, !name.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your full name")
            return
        }
        
        guard let phone = phoneNumber.text, !phone.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your phone number")
            return
        }
        
        guard let emailText = email.text, !emailText.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your email")
            return
        }
        
        setLoading(true)
        
        Task {
            await saveChanges(name: name, phone: phone, email: emailText)
        }
    }
    
    private func saveChanges(name: String, phone: String, email: String) async {
        do {
            var imagePath = currentImagePath
            
            if let image = selectedImage {
                imagePath = await uploadImageToSupabase(image: image)
            }
            
            try await SupabaseClientManager.shared.client.auth.update(user: .init(email: email))
            
            let updateRequest = UpdateUserRequest(
                name: name,
                phone: phone,
                image: imagePath
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .update(updateRequest)
                .eq("id", value: currentUserId)
                .execute()
            
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Success", message: "Profile updated successfully!") {
                    self.dismiss(animated: true)
                }
            }
            
        } catch {
            print("Error saving changes: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to save changes: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upload Image
    
    private func uploadImageToSupabase(image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to process image")
            return nil
        }
        
        let fileName = "\(currentUserId).jpg"
        let filePath = "profiles/\(fileName)"
        
        do {
            try await SupabaseClientManager.shared.client.storage
                .from("images")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: .init(contentType: "image/jpeg", upsert: true)
                )
            
            let publicURL = try SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: filePath)
            
            print("Image uploaded successfully: \(publicURL)")
            return publicURL.absoluteString
            
        } catch {
            print("Upload error: \(error)")
            return currentImagePath
        }
    }
    
    // MARK: - Helpers
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        saveChangesBTN.isEnabled = !loading
        saveChangesBTN.setTitle(loading ? "Saving..." : "Save Changes", for: .normal)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ProfileSettingsController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.selectedImage = image
                    self?.userAvatar.image = image
                    
                    // Show userAvatar, hide initialAvatar since user selected an image
                    self?.userAvatar.isHidden = false
                    self?.intialAvatar.isHidden = true
                }
            }
        }
    }
}
