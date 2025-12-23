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
    @IBOutlet weak var saveChangesBTN: UIButton!
    @IBOutlet weak var phoneNumber: UITextField!
    @IBOutlet weak var fullName: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var userAvatar: UIImageView!
    
    private var currentUserId: String = ""
    private var currentImagePath: String?
    private var selectedImage: UIImage?
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        setupUI()
        fetchUserProfile()
        
        // Connect save button action
        saveChangesBTN.addTarget(self, action: #selector(saveChangesTapped(_:)), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Make avatar circular - use the smaller dimension to ensure circle
        let size = min(userAvatar.frame.width, userAvatar.frame.height)
        userAvatar.layer.cornerRadius = size / 2
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        // Avatar styling
        userAvatar.clipsToBounds = true
        userAvatar.contentMode = .scaleAspectFill
        userAvatar.isUserInteractionEnabled = true
        
        // Add tap gesture to avatar for changing photo
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        userAvatar.addGestureRecognizer(tapGesture)
        
        // Save button styling
        saveChangesBTN.layer.cornerRadius = 12
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
    
    // MARK: - Fetch User Profile
    
    private func fetchUserProfile() {
        Task {
            do {
                let session = try await SupabaseClientManager.shared.client.auth.session
                currentUserId = session.user.id.uuidString
                
                // Set email from auth session
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
                        
                        // Load avatar if available
                        if let imagePath = user.image, !imagePath.isEmpty {
                            loadAvatar(from: imagePath)
                        }
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
        print("Save button tapped") // Debug
        
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
            
            // Upload new image if selected
            if let image = selectedImage {
                imagePath = await uploadImageToSupabase(image: image)
            }
            
            // Update email in Supabase Auth
            try await SupabaseClientManager.shared.client.auth.update(user: .init(email: email))
            
            // Update user in database
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
                }
            }
        }
    }
}
