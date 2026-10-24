//
//  webViewController.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//
import WebKit
import UIKit

class webViewController: UIViewController, WKUIDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    var url: String!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set a mobile user agent
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.applicationNameForUserAgent = "Mobile"
        
        // Inject viewport meta tag if not already set
        let userScript = WKUserScript(source: "if (!document.querySelector('meta[name=viewport]')) { var meta = document.createElement('meta'); meta.name = 'viewport'; meta.content = 'initial-scale=1.0'; document.head.appendChild(meta); }", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        
        // Initialize webView with custom configuration
        webView.uiDelegate = self
        
        // Load the web page
        if let myURL = URL(string: url) {
            let myRequest = URLRequest(url: myURL)
            webView.load(myRequest)
        }  
    }
}
