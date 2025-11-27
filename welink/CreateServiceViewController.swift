//
//  CreateServiceViewController.swift
//  welink
//
//  Created by Ahmed on 28/11/2025.
//

import UIKit

class CreateServiceViewController: UIViewController {
    @IBOutlet weak var categoryButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        let choices = ["Cleaning", "Plumbing", "Electrical", "Painting"]
            
        // Create actions with the first one selected by default
        let actions = choices.enumerated().map { index, choice in
            UIAction(title: choice, state: index == 0 ? .on : .off) { action in
                print("Selected: \(choice)")
            }
        }
        
        categoryButton.menu = UIMenu(children: actions)
    }

}
