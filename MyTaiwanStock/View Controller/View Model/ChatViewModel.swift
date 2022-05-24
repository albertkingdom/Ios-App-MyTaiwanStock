//
//  ChatViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Firebase
import FirebaseAuth
import Foundation
import Combine

class ChatViewModel {
    var subscription = Set<AnyCancellable>()
    var stockNo: String!
//    var channelID: String! {
//        didSet {
//            fetchRemoteData()
//        }
//    }
    var channelIDCombine = CurrentValueSubject<String, Never>("")
    private let database = Firestore.firestore()
    //var messages = Observable<[Message]>([])
    @Published var messagesCombine:[Message] = []
    var currentUser = Observable<User>(nil)
    @Published var currentUserCombine: User!
    var reference: CollectionReference?
    private var channelReference: CollectionReference {
      return database.collection("channels")
    }
    var messageListener: ListenerRegistration?
    
    init(stockNo: String) {
        
        self.stockNo = stockNo
        //checkIsExistingChannel()
        setup()
    }
    deinit {
       
        removeListener()
    }
    
    func setup() {
        channelIDCombine.sink { id in
            print("observe id \(id)")
            if id.isEmpty {
                print("id is empty")
                self.checkIsExistingChannel()
            } else {
               
                self.fetchRemoteData()
            }
        }
        .store(in: &subscription)
    }
    
    func createChannel(){
        
        
        let documentRef = channelReference.addDocument(data: ["name": stockNo]) { error in
            if let error = error {
                print("Error saving channel: \(error.localizedDescription)")
            }
        }
//        channelID = documentRef.documentID
        channelIDCombine.send(documentRef.documentID)
    }
    func checkIsExistingChannel() {
        
        
        channelReference.whereField("name", isEqualTo: stockNo ?? "").getDocuments { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
                
            } else {
                for document in snapshot!.documents {
                    //print("\(document.documentID) => \(document.data())")
                    
                }
                
          
                if (snapshot!.documents.count > 0) {
                    guard let id = snapshot?.documents[0].documentID else { return }
                    //self.channelID = snapshot?.documents[0].documentID
                    self.channelIDCombine.send(id)
                    return
                }
                self.createChannel()
            }
        }
        
        
    }
    func signIn() {
        Auth.auth().signInAnonymously { authResult, error in
            guard let user = authResult?.user else { return }
          
            self.currentUser.value = user
        }
    }
    
    func fetchRemoteData() {

//        reference = database.collection("channels/\(channelID!)/thread")
        reference = database.collection("channels/\(channelIDCombine.value)/thread")
        messageListener = reference?.addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("""
        Error listening for channel updates: \
        \(error?.localizedDescription ?? "No error")
        """)
                return
            }
            snapshot.documentChanges.forEach { change in
                self?.handleDocumentChange(change)
                
            }
            
        }
    }
    
    private func handleDocumentChange(_ change: DocumentChange){
        switch change.type {
        case .added:
            let message = Message(document: change.document)
            //print("message \(message)")
            //messages.value?.append(message)
//            messages.value?.sort { (msg1, msg2) -> Bool in
//                msg1.sentDate < msg2.sentDate
//            }
            messagesCombine.append(message)
            
            messagesCombine.sort{ (msg1, msg2) -> Bool in
                msg1.sentDate < msg2.sentDate
            }

        default:
            break
        }
    }
    
    func save(_ message: Message) {
        //print("save message to firestore ")
        reference?.addDocument(data: message.representation) { [weak self] error in
        
        if let error = error {
          print("Error sending message: \(error.localizedDescription)")
          return
        }

      }
    }
    
    func removeListener() {
        messageListener?.remove()
    }
}
