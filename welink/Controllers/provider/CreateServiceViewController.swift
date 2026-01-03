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
    let start_date: String
    let end_date: String
    let image: String?
    let user_id: String
    let categories: [String]
}

// Response struct to capture created service ID
struct CreateServiceResponse: Decodable {
    let id: UUID
}

// Struct for updating an existing service
struct UpdateServiceRequest: Encodable {
    let name: String
    let description: String
    let price_per_hour: Double
    let start_date: String
    let end_date: String
    let image: String?
    let categories: [String]
}

class CreateServiceViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var uploadIcon: UIImageView!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var uploadContainerView: RoundedView!
    @IBOutlet weak var startDatePicker: UIDatePicker!
    @IBOutlet weak var endDatePicker: UIDatePicker!
    
    @IBOutlet weak var serviceNameTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var createButton: UIButton!
    
    // const
    let placeholderText = "Describe your service in details"
    let placeholderColor = UIColor.lightGray
    let textColor = UIColor.black
    
    // Store the uploaded image URL
    private var uploadedImageURL: String?
    private var isUploading = false

    // Changed to array for multiple categories
    private var selectedCategories: Set<String> = []

    // Edit mode properties
    var isEditMode: Bool = false
    var editingServiceId: String?
    var existingService: SeekerSearchResult?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup category button - explicitly disable menu
        categoryButton.menu = nil
        categoryButton.showsMenuAsPrimaryAction = false
        updateCategoryButtonTitle()

        // Fix upload button background color to prevent it changing when action sheet is shown
        var config = uploadButton.configuration ?? UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(named: "AccentColor")
        config.baseForegroundColor = UIColor.white
        uploadButton.configuration = config
        
        // style for service description
        descriptionTextView.layer.cornerRadius = 12
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.lightGray.cgColor
        
        descriptionTextView.delegate = self
        descriptionTextView.text = placeholderText
        descriptionTextView.textColor = placeholderColor

        setupDottedBorder()
        setupPreviewImageViewConstraints()
        setupImageTapGesture()

        // If in edit mode, populate fields with existing data
        if isEditMode {
            populateFieldsForEditing()
        }
    }

    private func setupImageTapGesture() {
        previewImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(previewImageTapped))
        previewImageView.addGestureRecognizer(tapGesture)
    }

    @objc private func previewImageTapped() {
        // Only respond if there's already an image displayed
        guard !previewImageView.isHidden else { return }
        openImagePicker()
    }

    private func openImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    private func populateFieldsForEditing() {
        guard let service = existingService else { return }

        // Update title
        self.title = "Edit Service"

        // Update button title
        createButton?.setTitle("Update Service", for: .normal)

        // Populate service name
        serviceNameTextField.text = service.name

        // Populate price
        priceTextField.text = String(format: "%.0f", service.pricePerHour ?? 0)

        // Populate description
        descriptionTextView.text = service.description ?? ""
        descriptionTextView.textColor = textColor

        // Populate dates
        if let startDateString = service.startDate, let endDateString = service.endDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            // Try format 1: ISO8601 with T
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            var startDate = dateFormatter.date(from: startDateString)
            var endDate = dateFormatter.date(from: endDateString)

            // Try format 2: space instead of T
            if startDate == nil || endDate == nil {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                startDate = dateFormatter.date(from: startDateString)
                endDate = dateFormatter.date(from: endDateString)
            }

            if let start = startDate {
                startDatePicker.date = start
            }
            if let end = endDate {
                endDatePicker.date = end
            }
        }

        // Populate image if exists
        if let imageUrl = service.image, !imageUrl.isEmpty {
            uploadedImageURL = imageUrl
            loadExistingImage(from: imageUrl)
        }

        // Populate categories from existing service
        if let categories = service.categories, !categories.isEmpty {
            self.selectedCategories = Set(categories)
            self.updateCategoryButtonTitle()
        }
    }

    private func loadExistingImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        previewImageView.image = image
                        previewImageView.isHidden = false
                        previewImageView.contentMode = .scaleAspectFill
                        previewImageView.clipsToBounds = true
                        previewImageView.layer.cornerRadius = 12

                        uploadIcon.isHidden = true
                        uploadButton.isHidden = true
                    }
                }
            } catch {
                print("Failed to load existing image: \(error)")
            }
        }
    }

    private func setupPreviewImageViewConstraints() {
        // Remove any existing constraints on previewImageView
        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        // Pin previewImageView to all edges of uploadContainerView
        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: uploadContainerView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: uploadContainerView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: uploadContainerView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: uploadContainerView.bottomAnchor)
        ])
    }
    
    @IBAction func categoryButtonTapped(_ sender: Any) {
        // This should be connected to the categoryButton's Touch Up Inside action in Storyboard
        showCategoriesAlert()
    }
    
    func showCategoriesAlert() {
        let choices = ["Home", "Tutoring", "Design"]
        
        let alert = UIAlertController(
            title: "Select Categories",
            message: "Choose one or more categories",
            preferredStyle: .actionSheet
        )
        
        // Add action for each category
        for choice in choices {
            let isSelected = selectedCategories.contains(choice)
            let title = isSelected ? "✓ \(choice)" : choice
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.toggleCategory(choice)
                // Show alert again to allow multiple selections
                self?.showCategoriesAlert()
            }
            alert.addAction(action)
        }
        
        // Add "Done" button
        let doneAction = UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
            self?.updateCategoryButtonTitle()
        }
        alert.addAction(doneAction)
        
        // For iPad compatibility
        if let popover = alert.popoverPresentationController {
            popover.sourceView = categoryButton
            popover.sourceRect = categoryButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            // Remove if already selected
            selectedCategories.remove(category)
        } else {
            // Add if not selected
            selectedCategories.insert(category)
        }
        print("Selected categories: \(selectedCategories)")
    }
    
    func updateCategoryButtonTitle() {
        if selectedCategories.isEmpty {
            categoryButton.setTitle("Select Categories", for: .normal)
        } else if selectedCategories.count == 1 {
            categoryButton.setTitle(selectedCategories.first!, for: .normal)
        } else {
            categoryButton.setTitle("\(selectedCategories.count) categories selected", for: .normal)
        }
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
        openImagePicker()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            
            // Show selected image
            previewImageView.image = selectedImage
            previewImageView.isHidden = false
            previewImageView.contentMode = .scaleAspectFill
            previewImageView.clipsToBounds = true
            previewImageView.layer.cornerRadius = 12
            
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
        let selectedDate = startDatePicker.date
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
        
        // Validate categories
        guard !selectedCategories.isEmpty else {
            showAlert(title: "Missing Information", message: "Please select at least one category")
            return
        }
        
        // Get dates from date pickers
        let formatter = ISO8601DateFormatter()
        let startDate = formatter.string(from: startDatePicker.date)
        let endDate = formatter.string(from: endDatePicker.date)

        // Validate that end date is after start date
        guard endDatePicker.date >= startDatePicker.date else {
            showAlert(title: "Invalid Dates", message: "End date must be after start date")
            return
        }

        // Create or update service in database
        Task {
            if isEditMode {
                await updateServiceInDatabase(
                    name: serviceName,
                    description: description,
                    price: price,
                    startDate: startDate,
                    endDate: endDate,
                    imageURL: uploadedImageURL,
                    categories: Array(selectedCategories)
                )
            } else {
                await saveServiceToDatabase(
                    name: serviceName,
                    description: description,
                    price: price,
                    startDate: startDate,
                    endDate: endDate,
                    imageURL: uploadedImageURL,
                    categories: Array(selectedCategories)
                )
            }
        }
    }

    private func updateServiceInDatabase(
        name: String,
        description: String,
        price: Decimal,
        startDate: String,
        endDate: String,
        imageURL: String?,
        categories: [String]
    ) async {
        guard let serviceId = editingServiceId else {
            await MainActor.run {
                showAlert(title: "Error", message: "Service ID not found")
            }
            return
        }

        do {
            // Update service request
            let updateRequest = UpdateServiceRequest(
                name: name,
                description: description,
                price_per_hour: NSDecimalNumber(decimal: price).doubleValue,
                start_date: startDate,
                end_date: endDate,
                image: imageURL,
                categories: categories
            )

            try await SupabaseClientManager.shared.client.database
                .from("services")
                .update(updateRequest)
                .eq("id", value: serviceId)
                .execute()

            await MainActor.run {
                showAlert(title: "Success", message: "Service updated successfully") {
                    self.navigationController?.popViewController(animated: true)
                }
            }

        } catch {
            print("Error updating service: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to update service: \(error.localizedDescription)")
            }
        }
    }

    private func saveServiceToDatabase(
        name: String,
        description: String,
        price: Decimal,
        startDate: String,
        endDate: String,
        imageURL: String?,
        categories: [String]
    ) async {
        do {
            // Get current user ID
            let session = try await SupabaseClientManager.shared.client.auth.session
            let userId = session.user.id

            // Create service request
            let serviceRequest = CreateServiceRequest(
                name: name,
                description: description,
                price_per_hour: NSDecimalNumber(decimal: price).doubleValue,
                start_date: startDate,
                end_date: endDate,
                image: imageURL,
                user_id: userId.uuidString,
                categories: categories
            )

            let response: [CreateServiceResponse] = try await SupabaseClientManager.shared.client.database
                .from("services")
                .insert(serviceRequest)
                .select("id")
                .execute()
                .value

            guard let createdService = response.first else {
                await MainActor.run {
                    showAlert(title: "Error", message: "Service created but failed to get service ID")
                }
                return
            }

            await MainActor.run {
                self.navigateToServiceDetails(serviceId: createdService.id.uuidString)
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

    private func navigateToServiceDetails(serviceId: String) {
        let storyboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ServiceDetailsVC") as? ServiceDetailsViewController else {
            return
        }
        vc.serviceId = serviceId
        navigationController?.pushViewController(vc, animated: true)
    }
}
