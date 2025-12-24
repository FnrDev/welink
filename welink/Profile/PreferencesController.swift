//
//  PreferencesController.swift
//  welink
//
//  Created by Ali Matar on 23/12/2025.
//

import UIKit

class PreferencesController: UIViewController {

    @IBOutlet weak var navigationBar: UINavigationBar?
    @IBOutlet weak var segmentedControl: UISegmentedControl?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigationBar()
        setupSegmentedControl()
    }
    
    private func setupNavigationBar() {
        guard let navigationBar = navigationBar else { return }
        
        let config = UIImage.SymbolConfiguration(weight: .semibold)
        let chevronImage = UIImage(systemName: "chevron.left", withConfiguration: config)
        
        let backButton = UIButton(type: .system)
        backButton.setImage(chevronImage, for: .normal)
        backButton.setTitle(" Back", for: .normal)
        backButton.tintColor = .systemBlue
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let barButton = UIBarButtonItem(customView: backButton)
        
        navigationBar.topItem?.leftBarButtonItem = barButton
        navigationBar.topItem?.title = "Preferences"
    }
    
    private func setupSegmentedControl() {
        guard let segmentedControl = segmentedControl else { return }
        
        segmentedControl.selectedSegmentIndex = 1
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            dismiss(animated: false)
        }
    }
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
}
