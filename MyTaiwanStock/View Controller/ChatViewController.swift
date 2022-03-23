//
//  ChatViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/3/16.
//

import UIKit
import Firebase
import FirebaseAuth
import MessageKit
import InputBarAccessoryView

class ChatViewController: MessagesViewController, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    
    private var currentUser: User?
    private let database = Firestore.firestore()
    private var reference: CollectionReference?
    private var messageListener: ListenerRegistration?
    private var channelID: String!

    var messages: [Message] = []
    

    init(channelName: String, channelId: String) {
        super.init(nibName: nil, bundle: nil)
        title = channelName
        channelID = channelId
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        
        reference = database.collection("channels/\(channelID!)/thread")
        reference?.addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("""
        Error listening for channel updates: \
        \(error?.localizedDescription ?? "No error")
        """)
                return
            }
            snapshot.documentChanges.forEach { change in
                self.handleDocumentChange(change)

            }
            
        }
        /// signin anonymously at viewDidLoad(),
        signIn()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        alignAvatarView()
    }
    func currentSender() -> SenderType {
        return Sender(senderId: currentUser?.uid ?? "", displayName: "Any One")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

        avatarView.tintColor = .white
        avatarView.image = UIImage(systemName: "person.fill", withConfiguration: UIImage.SymbolConfiguration(scale: .small ))
        
    }
   
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let dateformatter = DateFormatter()
        dateformatter.locale = Locale(identifier: "zh_TW")
        dateformatter.dateStyle = .short
        dateformatter.timeStyle = .short
        let sentTime = messages[indexPath.section].sentDate
        
        return NSAttributedString(string: dateformatter.string(from: sentTime), attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UIColor(white: 0.5, alpha: 1)
        ])
        
    }
    // TODO: adjust avatar view position
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    func alignAvatarView() {
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            // set the vertical position of the Avatar for incoming messages so that the bottom of the Avatar
            // aligns with the bottom of the Message
            layout.setMessageIncomingAvatarPosition(.init(vertical: .cellTop))

            // set the vertical position of the Avatar for outgoing messages so that the bottom of the Avatar
            // aligns with the `cellBottom`
            layout.setMessageOutgoingAvatarPosition(.init(vertical: .cellTop))
        }
    }
    func signIn() {
        Auth.auth().signInAnonymously { authResult, error in
            guard let user = authResult?.user else { return }
          
            self.currentUser = user
        }
    }
    private func handleDocumentChange(_ change: DocumentChange){
        switch change.type {
        case .added:
            let message = Message(document: change.document)
            
            messages.append(message)
            messages.sort { (msg1, msg2) -> Bool in
                msg1.sentDate < msg2.sentDate
            }
            messagesCollectionView.reloadData()
        default:
            break
        }
    }

}
// MARK: message input area
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard let currentUser = currentUser else { return }
        let message = Message(user: currentUser,content: text)
        save(message)
    }
    
    private func save(_ message: Message) {
        print("save message to firestore ")
        reference?.addDocument(data: message.representation) { [weak self] error in
        guard let self = self else { return }
        if let error = error {
          print("Error sending message: \(error.localizedDescription)")
          return
        }
        self.messagesCollectionView.scrollToLastItem()
      }
    }
}
