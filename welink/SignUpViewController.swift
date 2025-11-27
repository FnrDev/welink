//
//  SignUpViewController.swift
//  welink
//
//  Created by Ali Matar on 27/11/2025.
//

import UIKit

class SignUpViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Back",
                style: .plain,
                target: self,
                action: #selector(dismissVC)
        )
    }
    
    @objc func dismissVC() {
        dismiss(animated: true, completion: nil)
    }

}
