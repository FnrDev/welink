//
//  CustomTabBarViewController.swift
//  welink
//
//  Created by Ahmed on 17/12/2025.
//

import UIKit

class CustomTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Keep existing view controllers from current storyboard
        var controllers = self.viewControllers ?? []
        
        // Load the Search VC from SeekerHome storyboard
        let seekerStoryboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        if let searchVC = seekerStoryboard.instantiateViewController(withIdentifier: "SearchVC") as? SearchViewController {
            
            // Set up the tab bar item
            searchVC.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 1)
            
            // Replace the search tab with the new VC
            controllers[1] = searchVC // Assuming search is at index 1
            
            self.viewControllers = controllers
        }
    }
}
