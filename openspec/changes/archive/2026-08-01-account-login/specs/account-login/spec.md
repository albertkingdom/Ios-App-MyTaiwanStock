## ADDED Requirements

### Requirement: Google Sign-In authentication

The system SHALL allow the user to sign in with a Google account from the Account screen (`AccountViewController`). The system SHALL obtain a Google ID token and access token via `GIDSignIn.sharedInstance.signIn(withPresenting:)`, build a `GoogleAuthProvider` credential, and authenticate against Firebase Auth via `Auth.auth().signIn(with:)`.

#### Scenario: User signs in with Google
- **WHEN** the user taps the Google sign-in button on the Account screen and completes the Google account picker
- **THEN** the system SHALL exchange the returned Google ID token and access token for a Firebase credential and call `Auth.auth().signIn(with:)`
- **AND** on success the Account screen SHALL re-render to the signed-in state showing the account email and profile photo

#### Scenario: Google Sign-In fails
- **WHEN** the Google sign-in flow returns an error (e.g. user cancels, network failure)
- **THEN** the system SHALL log the error via `print(...)` and SHALL NOT display any user-facing error message
- **AND** the Account screen SHALL remain in the signed-out state

### Requirement: Sign in with Apple authentication

The system SHALL allow the user to sign in with Apple ID from the Account screen using `AuthenticationServices`. The system SHALL generate a random nonce, send its SHA-256 hash as `ASAuthorizationAppleIDRequest.nonce`, and upon completion build an `OAuthProvider` credential (`providerID: "apple.com"`) from the returned identity token and the original raw nonce, then authenticate via `Auth.auth().signIn(with:)`.

#### Scenario: User signs in with Apple
- **WHEN** the user taps the Apple sign-in button and completes Apple ID authentication
- **THEN** the system SHALL decode the returned identity token, build an `apple.com` OAuth credential using the stored raw nonce, and call `Auth.auth().signIn(with:)`
- **AND** on success the Account screen SHALL re-render to the signed-in state

#### Scenario: Apple Sign-In delegate fires without a stored nonce
- **WHEN** `authorizationController(controller:didCompleteWithAuthorization:)` is invoked while `currentNonce` is `nil`
- **THEN** the system SHALL raise a `fatalError`

#### Scenario: Apple Sign-In fails
- **WHEN** the Apple authorization flow returns an error via `authorizationController(controller:didCompleteWithError:)`
- **THEN** the system SHALL log the error via `print(...)` and SHALL NOT display any user-facing error message

### Requirement: Firebase session persistence

The system SHALL rely entirely on the Firebase Auth SDK's built-in Keychain-backed persistence to store and restore the signed-in session across app launches. The system SHALL NOT implement any additional custom storage of credentials or tokens in `UserDefaults` or the Keychain.

#### Scenario: Session restored on app relaunch
- **WHEN** the app is relaunched after a previous successful sign-in
- **THEN** `Auth.auth().currentUser` SHALL be non-nil without requiring the user to sign in again

### Requirement: Account screen UI reflects authentication state

The Account screen SHALL call `updateUI()` on `viewDidLoad()` and immediately after each sign-in or sign-out completion to reflect the current value of `Auth.auth().currentUser`. The system SHALL NOT register a Firebase `addStateDidChangeListener`, so the Account screen SHALL NOT automatically refresh in response to authentication state changes that occur while the screen is not being interacted with.

#### Scenario: Signed-in state shown
- **WHEN** `Auth.auth().currentUser` is non-nil and `updateUI()` runs
- **THEN** the system SHALL display the user's email and profile photo (or a placeholder icon if no photo URL exists), SHALL show the sign-out button, and SHALL hide both the Google and Apple sign-in buttons

#### Scenario: Signed-out state shown
- **WHEN** `Auth.auth().currentUser` is `nil` and `updateUI()` runs
- **THEN** the system SHALL clear the email label, show a placeholder person icon, hide the sign-out button, and show both the Google and Apple sign-in buttons

#### Scenario: Auth state changes outside the Account screen are not reflected live
- **WHEN** the Firebase Auth session becomes invalid while the user is on a different screen
- **THEN** the Account screen SHALL continue showing its last-rendered state until the user navigates back to it and `updateUI()` runs again

### Requirement: Sign out clears the Firebase session only

The system SHALL allow the user to sign out via a button on the Account screen, which SHALL call `try Auth.auth().signOut()` and then `updateUI()`. The system SHALL NOT call `GIDSignIn.sharedInstance.signOut()`, so any cached Google SDK session state SHALL remain independent of the Firebase sign-out. The system SHALL NOT clear the `isFirstTimeAfterSignIn` UserDefaults flag on sign-out.

#### Scenario: User signs out successfully
- **WHEN** the user taps the sign-out button while signed in
- **THEN** the system SHALL clear the Firebase Auth session and the Account screen SHALL re-render to the signed-out state

#### Scenario: Sign-out fails
- **WHEN** `Auth.auth().signOut()` throws an error
- **THEN** the system SHALL log the error via `print("Error signing out: %@", signOutError)` and SHALL NOT display any user-facing error message
- **AND** the Account screen SHALL remain in its current (signed-in) state

### Requirement: Downstream features scope data by the signed-in user's email

Firestore-backed features (favorite stock lists via `OnlineDBService`, and list creation via `AddListViewModel`) SHALL read `Auth.auth().currentUser?.email` to identify the current user and SHALL scope all Firestore reads and writes to that email value. When no user is signed in, these features SHALL silently return without performing any Firestore operation and SHALL NOT display a message indicating that sign-in is required.

#### Scenario: Signed-in user's favorites are scoped to their email
- **WHEN** a signed-in user with email "user@example.com" reads or writes their favorite stock list
- **THEN** the system SHALL filter and store the data using `email == "user@example.com"` as the identifying field

#### Scenario: Signed-out user's favorite-list operations no-op silently
- **WHEN** no user is signed in and a Firestore-backed favorite-list operation is invoked
- **THEN** the system SHALL return without performing any Firestore read or write and SHALL NOT inform the user that they are signed out

### Requirement: Anonymous chat authentication is independent of the Account screen

The stock discussion chat feature (`ChatViewModel.signIn()`) SHALL use Firebase Anonymous Authentication (`Auth.auth().signInAnonymously`), independent of the Google/Apple sign-in state managed by the Account screen. The system SHALL allow a user to be anonymously authenticated for chat while simultaneously being signed out on the Account screen, and vice versa.

#### Scenario: Chat works while Account screen shows signed-out
- **WHEN** the user has never signed in via Google or Apple but opens the chat feature
- **THEN** the system SHALL sign the user in anonymously for chat purposes only
- **AND** the Account screen SHALL continue to show the signed-out state
