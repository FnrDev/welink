//
//  UIButton+Extensions.swift
//  welink
//
//  Created by Zahra on 25/12/2025.
//

import UIKit

extension UIButton {
    
    /// Apply standard app styling to button
    func applyAppStyle() {
        self.layer.cornerRadius = 12
        self.clipsToBounds = true
    }
    
    /// Apply category button styling (used in Home and Category screens)
    func applyCategoryStyle(isSelected: Bool) {
        self.layer.cornerRadius = 12
        self.clipsToBounds = true
        
        if isSelected {
            self.backgroundColor = UIColor(hex: "2D493A")
        } else {
            self.backgroundColor = .systemGray6
        }
    }
}
