//
//  CreateServiceViewController.swift
//  welink
//
//  Created by Ahmed on 28/11/2025.
//

import UIKit

class CreateServiceViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var categoryButton: UIButton!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var uploadIcon: UIImageView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var uploadContainerView: RoundedView!
    
    // const
    let placeholderText = "Describe your service in details"
    let placeholderColor = UIColor.lightGray
    let textColor = UIColor.black
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup skills menu values
        let choices = ["Cleaning", "Plumbing", "Electrical", "Painting"]
            
        // Create actions with the first one selected by default
        let actions = choices.enumerated().map { index, choice in
            UIAction(title: choice, state: index == 0 ? .on : .off) { action in
                print("Selected: \(choice)")
            }
        }
        
        categoryButton.menu = UIMenu(children: actions)
        
        // style for service description
        // Set up border
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.lightGray.cgColor
        
        // Set up placeholder
        descriptionTextView.delegate = self
        descriptionTextView.text = placeholderText
        descriptionTextView.textColor = placeholderColor
        
        // make view of service image dotted
        setupDottedBorder()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == placeholderText {
                textView.text = ""
                textView.textColor = textColor
            }
        }
        
    // Show placeholder if empty
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = placeholderText
            textView.textColor = placeholderColor
        }
    }
    
    // Get the actual text (not placeholder)
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
        dashedBorder.lineDashPattern = [6, 4]  // [dash length, gap length]
        dashedBorder.lineWidth = 1.5
        
        uploadContainerView.layer.cornerRadius = 12
        uploadContainerView.layer.addSublayer(dashedBorder)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update border when view size changes
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
            previewImageView.contentMode = .scaleAspectFill
            previewImageView.clipsToBounds = true
            
            // Hide the upload icon and button
            uploadIcon.isHidden = true
            uploadButton.isHidden = true
        }
        
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
}
