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
        let myURL = URL(string:url)
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
       
    }
    override func loadView() {
            let webConfiguration = WKWebViewConfiguration()
            webView = WKWebView(frame: .zero, configuration: webConfiguration)
            webView.uiDelegate = self
            view = webView
    }
       
   

}
