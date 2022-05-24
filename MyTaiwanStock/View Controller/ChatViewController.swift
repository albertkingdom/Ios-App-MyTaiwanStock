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
import Combine

class ChatViewController: MessagesViewController, MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    var subscription = Set<AnyCancellable>()
    var viewModel:ChatViewModel!
    

    init(stockNo: String) {
        super.init(nibName: nil, bundle: nil)
        title = "\(stockNo) Chat Room"
        viewModel = ChatViewModel(stockNo: stockNo)

    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // signin anonymously at viewDidLoad(),
        viewModel.signIn()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        alignAvatarView()
        
        bindViewModel()
    }

    func bindViewModel() {
//        viewModel.messages.bind { [weak self] _ in
//            //print("list \(list)")
//            self?.messagesCollectionView.reloadData()
//            self?.messagesCollectionView.scrollToLastItem()
//        }
        
        viewModel.$messagesCombine.sink { [weak self] _ in
            //print("list \(list)")
            self?.messagesCollectionView.reloadData()
            self?.messagesCollectionView.scrollToLastItem()
        }.store(in: &subscription)
    }
    func currentSender() -> SenderType {
        return Sender(senderId: viewModel.currentUser.value?.uid ?? "", displayName: "Any One")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
//        guard let messages = viewModel.messages.value else { return Message(user: viewModel.currentUser.value!, content: "") }
        let messages = viewModel.messagesCombine
        
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
//        return viewModel.messages.value?.count ?? 0
        return viewModel.messagesCombine.count
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
        //guard let message = viewModel.messages.value?[indexPath.section] else { return  NSAttributedString() }
        let message = viewModel.messagesCombine[indexPath.section]
        let sentTime = message.sentDate

        
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


}
// MARK: message input area
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard let currentUser = viewModel.currentUser.value else { return }
        let message = Message(user: currentUser,content: text)
        viewModel.save(message)
        inputBar.inputTextView.text = ""
    }
    
}
