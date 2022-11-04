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
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(with: config, presenting: (UIApplication.shared.windows.first?.rootViewController)!) { user, error in
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard
                let authentication = user?.authentication,
                let idToken = authentication.idToken
            else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: authentication.accessToken)
            
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
