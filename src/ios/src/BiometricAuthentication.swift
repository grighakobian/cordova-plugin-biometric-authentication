import UIKit
import Firebase
import SVProgressHUD

var isFirebaseConfigured = false

enum BiometricAuthenticationError: Error {
    case credentialsNotProvided
}

struct Credentials {
    var apiUrl: String
    var username: String
    var password: String
    
    init(settings: [AnyHashable: Any]) {
        apiUrl = settings["api_url"] as! String
        username = settings["username"] as! String
        password = settings["password"] as! String
    }
}


@objc(BiometricAuthentication)
class BiometricAuthentication : CDVPlugin {
    
    private var credentials: Credentials!
    private var currentCommand: CDVInvokedUrlCommand!
    private var documentPath: String = String()
    private var displayLanguage: String = "en"
    
    private var rootViewController: UIViewController? {
        let window = UIApplication.shared.keyWindow
        return window?.rootViewController
    }
    
    @objc(analyze:)
    func analyze(_ command: CDVInvokedUrlCommand) {
        initialize(command: command)
        presentLiveness()
    }
    
    
    
    private func initialize(command: CDVInvokedUrlCommand) {
        configureSdkSettings(command)
        configureFirebaseIfNeeded()
        configureAppearances()
        login { (result) in
            print(result)
        }
    }
    
    private func configureSdkSettings(_ command: CDVInvokedUrlCommand) {
        currentCommand = command
        documentPath = command.argument(at: 0) as! String
        displayLanguage = command.argument(at: 1) as! String
        
        OZSDK.attemptSettings = OZAttemptSettings(singleCount: 2, commonCount: 3)
        OZSDK.localizationCode = OZLocalizationCode(rawValue: displayLanguage) ?? .en
        credentials = Credentials(settings: commandDelegate.settings)
        
    }
    
    private func presentLiveness() {
        let actions = [OZVerificationMovement.smile, OZVerificationMovement.scanning]
        let livenessViewController = OZSDK.createVerificationVCWithDelegate(self, actions: actions)
        rootViewController?.present(livenessViewController, animated: true)
    }
    
    private func configureAppearances() {
        SVProgressHUD.setHapticsEnabled(false)
        SVProgressHUD.setForegroundColor(UIColor.hex(0x6400dc))
        SVProgressHUD.setDefaultMaskType(.custom)
        SVProgressHUD.setBackgroundLayerColor(UIColor(white: 0, alpha: 0.2))
        SVProgressHUD.setRingThickness(4.0)
        SVProgressHUD.setRingRadius(24.0)
        SVProgressHUD.setMinimumSize(CGSize(width: 120, height: 120))
    }
    
    private func configureFirebaseIfNeeded() {
        if (isFirebaseConfigured == false) {
            FirebaseApp.configure()
            isFirebaseConfigured.toggle()
        }
    }
    

    private func login(completionHandler:  Optional<(Result<String, Error>)->Void> = nil) {
        // Check for existing auth token
        if let authToken = OZSDK.authToken {
            completionHandler?(.success(authToken))
            return
        }
        // Log in
        let username = credentials.username
        let password = credentials.password
        OZSDK.login(username, password: password) { (authToken, error) in
            guard let authToken = authToken, error == nil else {
                completionHandler?(.failure(error!))
                return
            }
            OZSDK.authToken = authToken
            completionHandler?(.success(authToken))
        }
    }
}

// MARK: - OZVerificationDelegate

extension BiometricAuthentication: OZVerificationDelegate {
    
    private func sendNoResultCommand() {
        let result = CDVPluginResult(status: .noResult)
        let callbackId = currentCommand.callbackId
        commandDelegate.send(result, callbackId: callbackId)
    }
    
    private func documentAnalyze(documentPhoto: DocumentPhoto, results: [OZVerificationResult], analyseStates: Set<OZAnalysesState>) {
        OZSDK.documentAnalyse(documentPhoto: documentPhoto, results: results, analyseStates: analyseStates, scenarioState: { (scenarioState) in
            print("scenarioState: \(scenarioState)")
        }, fileUploadProgress: { (progress) in
            print("Progress: \(progress)")
        }) { (analyseResolutionStatus, analyseResolutions, error) in
            print("analyseResolutionStatus: \(analyseResolutionStatus) analyseResolutions: \(analyseResolutions), error: \(error)")
            SVProgressHUD.show(withStatus: "Processing..")
            if let analyseResolutionStatus = analyseResolutionStatus {
                switch analyseResolutionStatus {
                case .success:
                    SVProgressHUD.showSuccess(withStatus: "Success")
                    SVProgressHUD.dismiss(withDelay: 2.0) {
                        self.commandDelegate.send(CDVPluginResult(status: .ok), callbackId: self.currentCommand.callbackId)
                    }
                case .initial, .processing, .finished, .operatorRequired:
                    break
                case .declined, .failed:
                    self.sendNoResultCommand()
                }
            } else if let error = error {
                self.sendNoResultCommand()
            }
        }
    }
    
    func onOZVerificationResult(results: [OZVerificationResult]) {
        print(#function, "results: \(results)")
        
        let analyseResults = results.filter({
            $0.status == .userProcessedSuccessfully
        })
        
        if analyseResults.isEmpty {
            sendNoResultCommand()
            return
        }
        
        login { (result) in
            switch result {
            case .success:
                SVProgressHUD.show(withStatus: "Uploading..")
                let documentPhotoUrl = URL(fileURLWithPath: self.documentPath)
                let documentPhoto = DocumentPhoto(front: documentPhotoUrl, back: nil)
                self.documentAnalyze(
                    documentPhoto: documentPhoto,
                    results: analyseResults,
                    analyseStates: [.quality, .liveness]
                )
            case .failure:
                SVProgressHUD.dismiss(withDelay: 2.0) {
                    self.sendNoResultCommand()
                }
            }
        }
    }
}

