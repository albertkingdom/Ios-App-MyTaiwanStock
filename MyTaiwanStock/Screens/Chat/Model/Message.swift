//
//  Message.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/3/16.
//

import Foundation
import MessageKit
import Firebase

struct Message: MessageType {
    var sender: SenderType
    
    var messageId: String {
        return UUID().uuidString
    }
    
    var sentDate: Date
    
    var kind: MessageKind {
        return .text(content)
    }
    
    var content: String
    
    init(user: User, content: String) {

        self.sender = Sender(senderId: user.uid, displayName: "Person")
        //self.kind = .text(content)
        self.content = content
        self.sentDate = Date()
    }
    init(document: QueryDocumentSnapshot) {
        let data = document.data()
        self.sender = Sender(senderId: data["senderId"] as! String, displayName: data["senderName"] as! String)
        self.sentDate = (data["created"] as! Timestamp).dateValue()
        //self.kind = .text(data["content"] as! String)
        self.content = data["content"] as! String
    }
    var representation: [String: Any] {
      var rep: [String: Any] = [
        "created": sentDate,
        "senderId": sender.senderId,
        "senderName": sender.displayName,
        "content": content
      ]
        return rep
    }
}
