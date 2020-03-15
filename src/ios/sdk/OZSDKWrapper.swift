//
//  OZSDKWrapper.swift
//  Plugintest
//
//  Created by Grigor Hakobyan on 3/11/20.
//  Copyright © 2020 Appilens. All rights reserved.
//

import Foundation
import UIKit

@objc(OZSDKWrapper)
public class OZSDKWrapper: NSObject {
    
    @objc(sharedInstance)
    static let shared = OZSDKWrapper()
    
    @objc
    func presentLivenessViewController(from vc: UIViewController) {
        let livenessViewController = OZLivenessViewController()
        livenessViewController.actions = [.smile, .scanning]
//        livenessViewController.delegate = delegate
        vc.present(livenessViewController, animated: true)
    }
}
