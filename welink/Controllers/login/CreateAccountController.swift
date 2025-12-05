//
//  CreateAccountController.swift
//  welink
//
//  Created by Ali Matar on 04/12/2025.
//

import UIKit
import PhotosUI

// Struct for creating a new user profile
struct CreateUserRequest: Encodable {
    let id: String
    let name: String
    let phone: String
    let image: String?
    let role: String
}

class CreateAccountController: UIViewController {

    @IBOutlet weak var providerSwitch: UISwitch!
    @IBOutlet weak var uploadBTN: UIButton!
    @IBOutlet weak var createAccountBTN: UIButton!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var phone: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var profileIMGView: UIImageView!
    @IBOutlet weak var fullName: UITextField!
    
    private var selectedImage: UIImage?
    private var uploadedImageURL: String?
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide image view initially
        profileIMGView.isHidden = true
        
        // Style for when it shows
        profileIMGView.clipsToBounds = true
        profileIMGView.contentMode = .scaleAspectFill
        profileIMGView.layer.cornerRadius = 12
    }
    
    @IBAction func uploadImageTapped(_ sender: UIButton) {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction func createAccountTapped(_ sender: UIButton) {
        // Validate inputs
        guard let name = fullName.text, !name.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your full name")
            return
        }
        
        guard let emailText = email.text, !emailText.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your email")
            return
        }
        
        guard let phoneNumber = phone.text, !phoneNumber.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter your phone number")
            return
        }
        
        guard let passwordText = password.text, !passwordText.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter a password")
            return
        }
        
        guard passwordText.count >= 6 else {
            showAlert(title: "Weak Password", message: "Password must be at least 6 characters")
            return
        }
        
        // Disable button and show loading
        setLoading(true)
        
        Task {
            await createAccount(name: name, email: emailText, phone: phoneNumber, password: passwordText)
        }
    }
    
    private func createAccount(name: String, email: String, phone: String, password: String) async {
        do {
            // Step 1: Sign up with Supabase Auth
            let authResponse = try await SupabaseClientManager.shared.client.auth.signUp(
                email: email,
                password: password
            )
            
            let userId = authResponse.user.id.uuidString
            
            // Step 2: Upload image if selected
            if let image = selectedImage {
                await uploadImageToSupabase(image: image, userId: userId)
            }
            
            // Step 3: Determine role based on switch
            let role = providerSwitch.isOn ? "provider" : "seeker"
            
            // Step 4: Insert profile into users table
            let userRequest = CreateUserRequest(
                id: userId,
                name: name,
                phone: phone,
                image: uploadedImageURL,
                role: role
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("users")
                .insert(userRequest)
                .execute()
            
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Success", message: "Account created successfully!") { [weak self] in
                    self?.navigateToHome()
                }
            }
            
        } catch {
            print("Error creating account: \(error)")
            await MainActor.run {
                setLoading(false)
                showAlert(title: "Error", message: "Failed to create account: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadImageToSupabase(image: UIImage, userId: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to process image")
            return
        }
        
        // Use userId in filename for organization
        let fileName = "\(userId).jpg"
        let filePath = "profiles/\(fileName)"
        
        do {
            try await SupabaseClientManager.shared.client.storage
                .from("images")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: .init(contentType: "image/jpeg")
                )
            
            let publicURL = try SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: filePath)
            
            uploadedImageURL = publicURL.absoluteString
            print("Image uploaded successfully: \(publicURL)")
            
        } catch {
            print("Upload error: \(error)")
        }
    }
    
    private func navigateToHome() {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        let homeVC = storyboard.instantiateViewController(withIdentifier: "Home")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = homeVC
            window.makeKeyAndVisible()
            
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }
    
    private func setLoading(_ loading: Bool) {
        isLoading = loading
        createAccountBTN.isEnabled = !loading
        createAccountBTN.setTitle(loading ? "Creating..." : "Create Account", for: .normal)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension CreateAccountController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self?.selectedImage = image
                    self?.profileIMGView.image = image
                    self?.profileIMGView.isHidden = false
                    self?.uploadBTN.setTitle("Change Image", for: .normal)
                }
            }
        }
    }
}
