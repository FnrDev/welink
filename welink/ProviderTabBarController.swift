//
//  ProviderTabBarController.swift
//  welink
//
//  Created on 25/12/2025.
//

import UIKit

class ProviderTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }

    private func setupTabBar() {
        tabBar.tintColor = UIColor(hex: "2D493A")
        tabBar.unselectedItemTintColor = .gray
        tabBar.backgroundColor = .systemBackground
    }

    private func setupViewControllers() {
        let providerStoryboard = UIStoryboard(name: "ProviderDashboard", bundle: nil)
        let seekerStoryboard = UIStoryboard(name: "SeekerHome", bundle: nil)
        let profileStoryboard = UIStoryboard(name: "Profile", bundle: nil)

        var controllers: [UIViewController] = []

        // Tab 1: Dashboard (Home)
        let dashboardVC = seekerStoryboard.instantiateViewController(withIdentifier: "HomeVC")
        let dashboardNavController = UINavigationController(rootViewController: dashboardVC)
        dashboardNavController.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        controllers.append(dashboardNavController)

        // Tab 2: Search
        let searchVC = seekerStoryboard.instantiateViewController(withIdentifier: "SearchVC")
        let searchNavController = UINavigationController(rootViewController: searchVC)
        searchNavController.tabBarItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        controllers.append(searchNavController)

        // Tab 3: Profile
        let profileVC = profileStoryboard.instantiateViewController(withIdentifier: "ProfileVC")
        let profileNavController = UINavigationController(rootViewController: profileVC)
        profileNavController.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), selectedImage: UIImage(systemName: "person.fill"))
        controllers.append(profileNavController)

        self.viewControllers = controllers
    }
}
