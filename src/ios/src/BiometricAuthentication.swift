import UIKit

@objc(BiometricAuthentication)
class BiometricAuthentication : CDVPlugin {
    
    @objc(coolMethod:)
    func coolMethod(_ command: CDVInvokedUrlCommand) {
        let window = UIApplication.shared.keyWindow
        let rootViewController = window?.rootViewController
        let livenessViewController = OZLivenessViewController()
        livenessViewController.actions = [.smile, .scanning]
        
        rootViewController?.present(livenessViewController, animated: true)
    }
}
