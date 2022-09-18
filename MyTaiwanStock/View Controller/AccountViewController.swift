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

class AccountViewController: UIViewController {
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var signOutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initView()
        updateUI()
    }
    
    func initView() {
        googleSignInButton.addTarget(self, action: #selector(tapGoogleSignInButton), for: .touchUpInside)
        signOutButton.addTarget(self, action: #selector(tapSignOutButton), for: .touchUpInside)
    }
    @objc func tapGoogleSignInButton() {
        googleSignIn()
    }
    @objc func tapSignOutButton() {
        signOut()
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
            // send credential to firebase
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error = error {
                    print("authentication error \(error.localizedDescription)")
                    return
                }
                // successfully google sign in
                UserDefaults.standard.set(true, forKey: UserDefaults.isFirstTimeAfterSignIn)
                print(authResult ?? "none")
                self?.updateUI()
            }
        }
        
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
           let email = user.email,
           let imageURL = user.photoURL
        {
            emailLabel.text = email
            userImageView.kf.setImage(with: imageURL)
            signOutButton.isHidden = false
            googleSignInButton.isHidden = true
        } else
        {
            print("not sign in")
            emailLabel.text = ""
            userImageView.image = UIImage(systemName: "person.fill")?.withTintColor(UIColor.lightGray, renderingMode: .alwaysOriginal)
            signOutButton.isHidden = true
            googleSignInButton.isHidden = false
        }
    }

}
