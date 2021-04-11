//
//  Bundle.swift
//  common
//
//  Created by Jacob Su on 3/28/21.
//

import Foundation

@objc
public extension Bundle {
    @objc
    static var common: Bundle {
        get {
            return Bundle(for: TextureCubeLoader.self)
        }
    }
}
