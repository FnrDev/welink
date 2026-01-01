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

        setupTabBar()
        setupViewControllers()
    }

    private func setupTabBar() {
        // Style the tab bar
        tabBar.tintColor = UIColor(hex: "2D493A")
        tabBar.unselectedItemTintColor = .gray
        tabBar.backgroundColor = .systemBackground
    }

    private func setupViewControllers() {
        let seekerStoryboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        let profileStoryboard = UIStoryboard(name: "Profile", bundle: nil)
        let messagesStoryboard = UIStoryboard(name: "Messages", bundle: nil)

        var controllers: [UIViewController] = []

        // Tab 1: Home
        let homeVC = seekerStoryboard.instantiateViewController(withIdentifier: "HomeVC")
        let homeNavController = UINavigationController(rootViewController: homeVC)
        homeNavController.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        controllers.append(homeNavController)

        // Tab 2: Search
        let searchVC = seekerStoryboard.instantiateViewController(withIdentifier: "SearchVC")
        let searchNavController = UINavigationController(rootViewController: searchVC)
        searchNavController.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        controllers.append(searchNavController)

        // Tab 3: Messages
        let messagesVC = messagesStoryboard.instantiateViewController(withIdentifier: "MessagesVC")
        let messagesNavController = UINavigationController(rootViewController: messagesVC)
        messagesNavController.tabBarItem = UITabBarItem(title: "Messages", image: UIImage(systemName: "message"), selectedImage: UIImage(systemName: "message.fill"))
        controllers.append(messagesNavController)

        // Tab 4: Profile
        let profileVC = profileStoryboard.instantiateViewController(withIdentifier: "ProfileVC")
        let profileNavController = UINavigationController(rootViewController: profileVC)
        profileNavController.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), selectedImage: UIImage(systemName: "person.fill"))
        controllers.append(profileNavController)

        self.viewControllers = controllers
    }
}
