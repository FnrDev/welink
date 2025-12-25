//
//  HistoryController.swift
//  welink
//
//  Created by Ali Matar on 23/12/2025.
//

import UIKit

class HistoryController: UIViewController {

    @IBOutlet weak var navigationBar: UINavigationBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        // Create back button with SF Symbol arrow and text
        let config = UIImage.SymbolConfiguration(weight: .semibold)
        let chevronImage = UIImage(systemName: "chevron.left", withConfiguration: config)
        
        let backButton = UIButton(type: .system)
        backButton.setImage(chevronImage, for: .normal)
        backButton.setTitle(" Back", for: .normal)
        backButton.tintColor = .systemBlue
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let barButton = UIBarButtonItem(customView: backButton)
        
        navigationBar.topItem?.leftBarButtonItem = barButton
        navigationBar.topItem?.title = "History"
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
}
