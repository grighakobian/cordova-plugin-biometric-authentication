//
//  OZResources.swift
//  OZLivenessSDK
//
//  Created by Igor Ovchinnikov on 03/09/2019.
//

import Foundation

class OZResources {
    private init() { }
    
    private static var baseLocalization: [String: Any] = {
        let baseJsonURL = Bundle.main.url(forResource: "localization", withExtension: "json")!
        let baseJsonData = try! Data(contentsOf: baseJsonURL)
        let jsonObject = try! JSONSerialization.jsonObject(with: baseJsonData, options: .mutableContainers) as! [String: Any]
        return jsonObject
    }()
    
    static var closeButtonImage : UIImage? {
        return UIImage(named: "closebutton", in: Bundle.main, compatibleWith: nil)
    }
    
    static func localized(key: String) -> String {
        let locale = (OZSDK.localizationCode ?? .en).rawValue
        if let localization = baseLocalization[locale] as? [String: Any] {
            var localizedString = localization[key] as? String ?? key
            localizedString = localizedString.replacingOccurrences(of: "\\n", with: "\n")
            return localizedString
        }
        return key
    }
}

