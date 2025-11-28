//
//  CreateServiceViewController.swift
//  welink
//
//  Created by Ahmed on 28/11/2025.
//

import UIKit

// Struct for creating a new service
struct CreateServiceRequest: Encodable {
    let name: String
    let description: String
    let price_per_hour: Double
    let availability: ServiceAvailability
    let image: String?
    let user_id: String
}

struct ServiceAvailability: Encodable {
    let date: String
    let category: String
}

class CreateServiceViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var uploadIcon: UIImageView!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var uploadContainerView: RoundedView!
    @IBOutlet weak var datePicker: UIDatePicker!
    
    // Add these outlets - connect them in Storyboard
    @IBOutlet weak var serviceNameTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    
    // const
    let placeholderText = "Describe your service in details"
    let placeholderColor = UIColor.lightGray
    let textColor = UIColor.black
    
    // Store the uploaded image URL
    private var uploadedImageURL: String?
    private var isUploading = false
    private var selectedCategory: String = "Cleaning"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup skills menu values
        let choices = ["Cleaning", "Plumbing", "Electrical", "Painting"]
            
        let actions = choices.enumerated().map { index, choice in
            UIAction(title: choice, state: index == 0 ? .on : .off) { [weak self] action in
                self?.selectedCategory = choice
                print("Selected: \(choice)")
            }
        }
        
        categoryButton.menu = UIMenu(children: actions)
        
        // style for service description
        descriptionTextView.layer.cornerRadius = 12
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.lightGray.cgColor
        
        descriptionTextView.delegate = self
        descriptionTextView.text = placeholderText
        descriptionTextView.textColor = placeholderColor
        
        setupDottedBorder()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == placeholderText {
            textView.text = ""
            textView.textColor = textColor
        }
    }
        
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = placeholderText
            textView.textColor = placeholderColor
        }
    }
    
    func getDescriptionText() -> String? {
        if descriptionTextView.text == placeholderText {
            return nil
        }
        return descriptionTextView.text
    }
    
    func setupDottedBorder() {
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = UIColor.lightGray.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [6, 4]
        dashedBorder.lineWidth = 1.5
        
        uploadContainerView.layer.cornerRadius = 12
        uploadContainerView.layer.addSublayer(dashedBorder)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let dashedBorder = uploadContainerView.layer.sublayers?.first(where: { $0 is CAShapeLayer }) as? CAShapeLayer {
            dashedBorder.frame = uploadContainerView.bounds
            dashedBorder.path = UIBezierPath(roundedRect: uploadContainerView.bounds, cornerRadius: 12).cgPath
        }
    }

    @IBAction func uploadButtonTapped(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            
            // Show selected image
            previewImageView.image = selectedImage
            previewImageView.isHidden = false
            previewImageView.alpha = 1.0
            previewImageView.contentMode = .scaleAspectFill
            previewImageView.clipsToBounds = true
            previewImageView.backgroundColor = .red  // Debug: should see red if visible
            
            // Bring to front
            previewImageView.superview?.bringSubviewToFront(previewImageView)
            
            // Hide other elements
            uploadIcon.isHidden = true
            uploadButton.isHidden = true
            
            // Upload image to Supabase
            Task {
                await uploadImageToSupabase(image: selectedImage)
            }
        }
        
        dismiss(animated: true)
    }
    
    private func uploadImageToSupabase(image: UIImage) async {
        guard !isUploading else { return }
        isUploading = true
        
        // Compress image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            showUploadError("Failed to process image")
            return
        }
        
        // Generate unique filename
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "services/\(fileName)"
        
        do {
            // Upload to Supabase Storage
            try await SupabaseClientManager.shared.client.storage
                .from("images")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: .init(contentType: "image/jpeg")
                )
            
            // Get the public URL (synchronous)
            let publicURL = try SupabaseClientManager.shared.client.storage
                .from("images")
                .getPublicURL(path: filePath)
            
            uploadedImageURL = publicURL.absoluteString
            
            await MainActor.run {
                uploadButton.setTitle("Image uploaded ✓", for: .normal)
                uploadButton.isHidden = true
                isUploading = false
            }
            
            print("Image uploaded successfully: \(publicURL)")
            
        } catch {
            print("Upload error: \(error)")
            showUploadError(error.localizedDescription)
        }
    }
    
    @MainActor
    private func showUploadError(_ message: String) {
        isUploading = false
        uploadButton.setTitle("Upload image", for: .normal)
        uploadButton.isEnabled = true
        
        let alert = UIAlertController(title: "Upload Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // Call this when creating the service to get the uploaded image URL
    func getUploadedImageURL() -> String? {
        return uploadedImageURL
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    // date picker
    
    @IBAction func dateChanged(_ sender: Any) {
        let selectedDate = datePicker.date
        print("Selected date: \(selectedDate)")
    }
    
    // create service function
    @IBAction func createService(_ sender: Any) {
        // Validate inputs
        guard let serviceName = serviceNameTextField.text, !serviceName.isEmpty else {
            showAlert(title: "Missing Information", message: "Please enter a service name")
            return
        }
        
        guard let priceText = priceTextField.text,
              !priceText.isEmpty,
              let price = Decimal(string: priceText) else {
            showAlert(title: "Missing Information", message: "Please enter a valid price")
            return
        }
        
        guard let description = getDescriptionText() else {
            showAlert(title: "Missing Information", message: "Please enter a service description")
            return
        }
        
        // Get availability from date picker
        let selectedDate = datePicker.date
        let formatter = ISO8601DateFormatter()
        let availability: [String: Any] = [
            "date": formatter.string(from: selectedDate),
            "category": selectedCategory
        ]
        
        // Create service in database
        Task {
            await saveServiceToDatabase(
                name: serviceName,
                description: description,
                price: price,
                availability: availability,
                imageURL: uploadedImageURL
            )
        }
    }
    
    private func saveServiceToDatabase(
        name: String,
        description: String,
        price: Decimal,
        availability: [String: Any],
        imageURL: String?
    ) async {
        do {
            // Get current user ID
            let session = try await SupabaseClientManager.shared.client.auth.session
            let userId = session.user.id
            
            // Create availability struct
            let formatter = ISO8601DateFormatter()
            let availabilityData = ServiceAvailability(
                date: availability["date"] as? String ?? formatter.string(from: Date()),
                category: availability["category"] as? String ?? "Cleaning"
            )
            
            // Create service request
            let serviceRequest = CreateServiceRequest(
                name: name,
                description: description,
                price_per_hour: NSDecimalNumber(decimal: price).doubleValue,
                availability: availabilityData,
                image: imageURL,
                user_id: userId.uuidString
            )
            
            try await SupabaseClientManager.shared.client.database
                .from("services")
                .insert(serviceRequest)
                .execute()
            
            await MainActor.run {
                showAlert(title: "Success", message: "Service created successfully!") { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            }
            
        } catch {
            print("Error creating service: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to create service: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}
