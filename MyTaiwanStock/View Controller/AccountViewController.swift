//
//  AccountViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 9/6/22.
//

import UIKit
import Firebase
import GoogleSignIn
import Kingfisher
import AuthenticationServices
import CryptoKit

class AccountViewController: UIViewController {
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    let signOutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .black
        button.tintColor = .white
        button.setTitle("Sign Out", for: .normal)
        button.setImage(UIImage(systemName: "figure.out",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)),
                               for: .normal)
        button.layer.cornerRadius = 5
        return button
    }()
    let appleSignInButton = ASAuthorizationAppleIDButton()
    fileprivate var currentNonce: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        updateUI()
    }
    
    func initView() {
        navigationItem.title = "帳戶"
        view.addSubview(signOutButton)
        view.addSubview(appleSignInButton)
       
        googleSignInButton.addTarget(self, action: #selector(tapGoogleSignInButton), for: .touchUpInside)
        signOutButton.addTarget(self, action: #selector(tapSignOutButton), for: .touchUpInside)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        appleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            appleSignInButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            appleSignInButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            appleSignInButton.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 20),
            appleSignInButton.heightAnchor.constraint(equalTo: googleSignInButton.heightAnchor),
            signOutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signOutButton.heightAnchor.constraint(equalToConstant: 40),
            signOutButton.widthAnchor.constraint(equalToConstant: 120)
        ])
        appleSignInButton.addTarget(self, action: #selector(handleSignInWithApple), for: .touchUpInside)
    }
    @objc func tapGoogleSignInButton() {
        googleSignIn()
    }
    @objc func tapSignOutButton() {
        signOut()
    }
    @objc func handleSignInWithApple() {
        startSignInWithAppleFlow()
    }
    func googleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: (UIApplication.shared.windows.first?.rootViewController)!) { authentication, error in
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard
                let user = authentication?.user,
                let idToken = user.idToken?.tokenString
            else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            self.firebaseSignIn(credential: credential)
        }
    }

    func firebaseSignIn(credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            if let error = error {
                print("authentication error \(error.localizedDescription)")
                return
            }
            //
            UserDefaults.standard.set(true, forKey: UserDefaults.isFirstTimeAfterSignIn)

            if let user = result?.user {
                print("successfully login with email \(user.email ?? "")")
            }
            self?.updateUI()
            self?.offerLocalDataImportIfNeeded()
        }
    }
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    
    func signOut() {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            updateUI()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
    
    func updateUI() {
        if let user = Auth.auth().currentUser,
           let email = user.email
        {
            emailLabel.text = email
            if let imageURL = user.photoURL {
                userImageView.kf.setImage(with: imageURL)
            } else {
                userImageView.image = UIImage(systemName: "person.fill")?.withTintColor(UIColor.lightGray, renderingMode: .alwaysOriginal)
            }
            signOutButton.isHidden = false
            googleSignInButton.isHidden = true
            appleSignInButton.isHidden = true
        } else {
            print("not sign in")
            emailLabel.text = ""
            userImageView.image = UIImage(systemName: "person.fill")?.withTintColor(UIColor.lightGray, renderingMode: .alwaysOriginal)
            signOutButton.isHidden = true
            googleSignInButton.isHidden = false
            appleSignInButton.isHidden = false
        }
    }

}

// MARK: local data import on login
extension AccountViewController {
    /// Tracks whether the import prompt has already been shown once this app session, so
    /// repeated login/logout of the same account within one session doesn't re-prompt and
    /// re-upload local data that was already handled. Intentionally in-memory (not
    /// persisted) — a fresh app launch is a new session and may legitimately prompt again.
    private static var hasOfferedImportThisSession = false

    /// Test-only hook: XCTest reruns test methods in the same process, so this static flag
    /// must be reset between tests to keep them isolated from one another.
    static func resetOfferedImportSessionStateForTesting() {
        hasOfferedImportThisSession = false
    }

    /// Local Core Data and Firestore are never silently merged. If local data exists at
    /// login time, the user must explicitly confirm the import (specs/account-login:
    /// "Local data import confirmation on Firebase login"). The prompt is offered at most
    /// once per app session to avoid re-prompting (and re-uploading) on repeated
    /// login/logout of the same account.
    func offerLocalDataImportIfNeeded(onlineDBService: OnlineDBUploading = OnlineDBService()) {
        guard !Self.hasOfferedImportThisSession else { return }

        let localLists = LocalDBService.shared.fetchAllListFromDB()
        guard !localLists.isEmpty else { return }

        Self.hasOfferedImportThisSession = true

        let alert = UIAlertController(
            title: "匯入本機資料",
            message: "偵測到本機已有清單資料，是否要匯入到目前登入的帳號？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "匯入", style: .default) { [weak self] _ in
            self?.importLocalDataToOnlineDB(lists: localLists, onlineDBService: onlineDBService)
        })
        alert.addAction(UIAlertAction(title: "不匯入", style: .cancel) { _ in
            // Intentionally no-op: declining leaves local data untouched and uploads
            // nothing. Kept as an explicit (rather than absent) handler so tests can
            // invoke it directly to prove the decline path has no side effects.
        })
        present(alert, animated: true)
    }

    /// Internal (not private) so tests can exercise the upload fan-out directly with an
    /// injected `OnlineDBUploading` mock, independent of driving the presented alert's
    /// private action-handler storage.
    func importLocalDataToOnlineDB(lists: [ListStruct], onlineDBService: OnlineDBUploading) {
        for list in lists {
            guard let listName = list.name else { continue }
            onlineDBService.uploadListToOnlineDB(listName: listName)

            for stockNoStruct in list.stockNos {
                guard let stockNumber = stockNoStruct.stockNo else { continue }
                onlineDBService.uploadNewStockNoToOnlineDB(stockNumber: stockNumber, listName: listName)

                for history in LocalDBService.shared.fetchHistoryFromDB(with: stockNumber) {
                    guard let date = history.date else { continue }
                    onlineDBService.uploadHistoryToOnlineDB(
                        stockNo: stockNumber,
                        price: history.price,
                        amount: Int(history.amount),
                        date: date,
                        status: Int(history.status)
                    )
                }
            }
        }
    }
}

// MARK: apple signIn delegate
extension AccountViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential.
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            firebaseSignIn(credential: credential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
    }
}

extension AccountViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: helper function
extension AccountViewController {
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}
