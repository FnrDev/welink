//
//  ProviderDashboardViewController.swift
//  welink
//
//  Created by Ahmed on 25/11/2025.
//

import UIKit

class ProviderDashboardViewController: UIViewController {

    @IBOutlet weak var card1: UIView!
    @IBOutlet weak var card2: UIView!
    @IBOutlet weak var card3: UIView!
    @IBOutlet weak var card4: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cards = [card1, card2, card3, card4]
        for card in cards {
            card?.layer.cornerRadius = 16
            card?.clipsToBounds = true
        }
    }
    

    

}
