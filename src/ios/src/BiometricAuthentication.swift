import UIKit
import Firebase
import OZLivenessSDK

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
    private var base64ImageString: String = String()
    
    private lazy var documentImageUrl: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        var documentDirectoryUrl = paths[0]
        documentDirectoryUrl.appendPathComponent("doc.png")
        return documentDirectoryUrl
    }()
    
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
        login { (result) in
            print(result)
        }
    }
    
    private func configureSdkSettings(_ command: CDVInvokedUrlCommand) {
        print(#function, "Arguments: \(command.arguments)")
        
        currentCommand = command
        
        if command.arguments.count > 0 {
            base64ImageString = command.argument(at: 0) as? String ?? ""
            print("base64ImageString: \(base64ImageString)")
            saveImageData(base64EncodedString: base64ImageString)
        }
       
        OZSDK.attemptSettings = OZAttemptSettings(singleCount: 2, commonCount: 3)
       credentials = Credentials(settings: commandDelegate.settings)
        
        var locale = "en"
        if command.arguments.count > 1 {
            locale = command.argument(at: 1) as! String
        }
        OZSDK.localizationCode = OZLocalizationCode(rawValue: locale)!
        OZSDK.host = credentials.apiUrl
    }
    
    private func presentLiveness() {
        let actions = [OZVerificationMovement.smile, OZVerificationMovement.scanning]
        let livenessViewController = OZSDK.createVerificationVCWithDelegate(self, actions: actions)
        self.rootViewController?.present(livenessViewController, animated: true)
    }
    
    private func configureFirebaseIfNeeded() {
        if (isFirebaseConfigured == false) {
            FirebaseApp.configure()
            isFirebaseConfigured.toggle()
        }
    }
    
    private func saveImageData(base64EncodedString: String) {
        let data = Data(base64Encoded: base64EncodedString, options: .init(rawValue: 0))
        do {
            try data?.write(to: documentImageUrl, options: .atomic)
        } catch {
            print(error)
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
          
            if let analyseResolutionStatus = analyseResolutionStatus {
                switch analyseResolutionStatus {
                case .initial, .processing, .success:
                    break
                case .finished:
                    self.commandDelegate.send(CDVPluginResult(status: .ok), callbackId: self.currentCommand.callbackId)
                    print("Finished with results:\(analyseResolutions)")
                case .operatorRequired:
                    self.sendNoResultCommand()
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
                let documentPhoto = DocumentPhoto(front: self.documentImageUrl, back: nil)
                self.documentAnalyze(
                    documentPhoto: documentPhoto,
                    results: analyseResults,
                    analyseStates: [.quality]
                )
            case .failure:
                self.sendNoResultCommand()
            }
        }
    }
}
