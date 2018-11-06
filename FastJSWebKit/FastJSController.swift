//
//  FastJSController.swift
//  FastJSWebKit
//
//  Created by Steven Xie on 2018/10/18.
//  Copyright © 2018 Steven Xie. All rights reserved.
//

import UIKit
import WebKit

struct JKWkWebViewHandler {
    fileprivate var name:String!
    fileprivate var parmers:[String]!
    fileprivate var action:(([String:AnyObject]) -> Void)?
}

private let titleKeyPath = "title"
private let estimatedProgressKeyPath = "estimatedProgress"

public protocol FastJSControllerDelegate: class {
    func didStartLoading()
    func didFinishLoading(success: Bool)
}

class FastJSController: UIViewController {
    public weak var delegate: FastJSControllerDelegate?

    var storedStatusColor: UIBarStyle?
    var buttonColor: UIColor? = nil
    var titleColor: UIColor? = nil
    var closing: Bool! = false
    
    private var mAsyncScriptArray:[JKWkWebViewHandler] = []
    private var mSyncScriptArray:[JKWkWebViewHandler] = []
    
    var wkWebView = WKWebView()
    var navBarTitle: UILabel!
    public final var progressBar: UIProgressView {
        get {
            return _progressBar
        }
    }
    
    // MARK: KVO
    open override func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?,
                                    context: UnsafeMutableRawPointer?) {
        guard let theKeyPath = keyPath , object as? WKWebView == wkWebView else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if theKeyPath == estimatedProgressKeyPath {
            updateProgress()
        }
    }
    
    // ProgressView控件
    private lazy final var _progressBar: UIProgressView = {
        let progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.backgroundColor = .clear
        progressBar.trackTintColor = .clear
        return progressBar
    }()
    
    // 底部后退按钮
    lazy var backBarButtonItem: UIBarButtonItem =  {
        var tempBackBarButtonItem = UIBarButtonItem(image: FastJSController.bundledImage(named: "SwiftWebVCBack"),
                                                    style: UIBarButtonItem.Style.plain,
                                                    target: self,
                                                    action: #selector(self.goBackTapped(_:)))
        tempBackBarButtonItem.width = 18.0
        tempBackBarButtonItem.tintColor = self.buttonColor
        return tempBackBarButtonItem
    }()
    
    // 底部前进按钮
    lazy var forwardBarButtonItem: UIBarButtonItem =  {
        var tempForwardBarButtonItem = UIBarButtonItem(image: FastJSController.bundledImage(named: "SwiftWebVCNext"),
                                                       style: UIBarButtonItem.Style.plain,
                                                       target: self,
                                                       action: #selector(self.goForwardTapped(_:)))
        tempForwardBarButtonItem.width = 18.0
        tempForwardBarButtonItem.tintColor = self.buttonColor
        return tempForwardBarButtonItem
    }()
    
    // 底部刷新按钮
    lazy var refreshBarButtonItem: UIBarButtonItem = {
        var tempRefreshBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.refresh,
                                                       target: self,
                                                       action: #selector(self.reloadTapped(_:)))
        tempRefreshBarButtonItem.tintColor = self.buttonColor
        return tempRefreshBarButtonItem
    }()
    
    // 底部停止按钮
    lazy var stopBarButtonItem: UIBarButtonItem = {
        var tempStopBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.stop,
                                                    target: self,
                                                    action: #selector(self.stopTapped(_:)))
        tempStopBarButtonItem.tintColor = self.buttonColor
        return tempStopBarButtonItem
    }()
    
    // 底部活动按钮
    lazy var actionBarButtonItem: UIBarButtonItem = {
        var tempActionBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.action,
                                                      target: self,
                                                      action: #selector(self.actionButtonTapped(_:)))
        tempActionBarButtonItem.tintColor = self.buttonColor
        return tempActionBarButtonItem
    }()
    
    func getWKWebView() -> WKWebView {
        let webView = WKWebView(frame: self.view.bounds, configuration: getWebConfiguration())
        webView.uiDelegate = self
        webView.navigationDelegate = self

        webView.addObserver(self, forKeyPath: titleKeyPath, options: .new, context: nil)
        webView.addObserver(self, forKeyPath: estimatedProgressKeyPath, options: .new, context: nil)

        return webView
    }

    func getWebConfiguration() -> WKWebViewConfiguration {
        let configuretion = WKWebViewConfiguration()
        configuretion.preferences = WKPreferences()
        configuretion.preferences.javaScriptEnabled = true
        configuretion.userContentController = WKUserContentController()
        
        if self.mAsyncScriptArray.count != 0 || self.mSyncScriptArray.count != 0 {
            // 在载入时就添加JS
            // 只添加到mainFrame中
            let script = WKUserScript(source: createScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true)
            configuretion.userContentController.addUserScript(script)
        }
        
        // 异步需要回调，所以需要添加handler
        for item in self.mAsyncScriptArray {
            configuretion.userContentController.add(self, name: item.name)
        }
        
        return configuretion
    }
    
    public func loadWithFiles(resource: String, withExtension: String) {
        wkWebView = getWKWebView()
        
        view.insertSubview(wkWebView, at: 0)
        if let url = Bundle.main.url(forResource: resource, withExtension: withExtension) {
            let request = URLRequest(url: url)
            wkWebView.load(request)
        }
    }

    public func loadWithUrl(_ url: URL) {
        wkWebView = getWKWebView()

        view.insertSubview(wkWebView, at: 0)
        let request = URLRequest(url: url)
        wkWebView.load(request)
    }
    
    deinit {
        wkWebView.stopLoading()
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        wkWebView.uiDelegate = nil
        wkWebView.navigationDelegate = nil
        
        if let _ = wkWebView.observationInfo {
            wkWebView.removeObserver(self, forKeyPath: titleKeyPath, context: nil)
            wkWebView.removeObserver(self, forKeyPath: estimatedProgressKeyPath, context: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(progressBar)
        view.bringSubviewToFront(progressBar)
        progressBar.frame = CGRect(x: view.frame.minX,
                                   y: wkWebView.safeAreaInsets.top,
                                   width: view.frame.size.width,
                                   height: 2)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateToolbarItems()
        navBarTitle = UILabel()
        navBarTitle.backgroundColor = UIColor.clear
        if presentingViewController == nil {
            navBarTitle.textColor = UIColor.black
        } else {
            navBarTitle.textColor = self.titleColor
        }
        navBarTitle.shadowOffset = CGSize(width: 0, height: 1);
        navBarTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 17.0)
        navBarTitle.textAlignment = .center
        navigationItem.titleView = navBarTitle;
        
        super.viewWillAppear(animated)
        
        if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone) {
            self.navigationController?.setToolbarHidden(false, animated: false)
        } else if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone) {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false

        // 释放handler
        for item in self.mAsyncScriptArray {
            wkWebView.configuration.userContentController.removeScriptMessageHandler(forName: item.name)
            wkWebView.configuration.userContentController.removeAllUserScripts()
        }
    }
    
    /// MARK:- AutoLayout
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        wkWebView.frame = view.bounds
        
        let isIOS11 = ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0))
        let top = isIOS11 ? CGFloat(0.0) : topLayoutGuide.length
        let insets = UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0)
        wkWebView.scrollView.contentInset = insets
        wkWebView.scrollView.scrollIndicatorInsets = insets
        
        view.bringSubviewToFront(progressBar)
        progressBar.frame = CGRect(x: view.frame.minX,
                                   y: topLayoutGuide.length,
                                   width: view.frame.size.width,
                                   height: 2)
    }
    
    private final func updateProgress() {
        let completed = wkWebView.estimatedProgress == 1.0
        progressBar.setProgress(completed ? 0.0 : Float(wkWebView.estimatedProgress), animated: !completed)
        UIApplication.shared.isNetworkActivityIndicatorVisible = !completed
    }
}

// 封装 JS 交互方法
extension FastJSController {
    /// MARK: - 添加JS
    public func addAsyncJSFunc(functionName: String, parmers: [String], action: @escaping ([String:AnyObject]) -> Void) {
        var obj = self.mAsyncScriptArray.filter { (obj) -> Bool in
            return obj.name == functionName
            }.first
        
        if obj == nil {
            obj = JKWkWebViewHandler()
            obj!.name = functionName
            obj!.parmers = parmers
            obj!.action = action
            self.mAsyncScriptArray.append(obj!)
        }
    }
    
    public func addSyncJSFunc(functionName: String, parmers: [String]) {
        var obj = self.mSyncScriptArray.filter { (obj) -> Bool in
            return obj.name == functionName
            }.first
        
        if obj == nil {
            obj = JKWkWebViewHandler()
            obj!.name = functionName
            obj!.parmers = parmers
            self.mSyncScriptArray.append(obj!)
        }
    }
    
    /// MARK: - 插入JS
    private func createScript() -> String {
        var result = "iOSApp = {"
        for item in self.mAsyncScriptArray {
            let pars = createParmes(dict: item.parmers)
            let str = "\"\(item.name!)\":function(\(pars)){window.webkit.messageHandlers.\(item.name!).postMessage([\(pars)]);},"
            result += str
        }
        for item in self.mSyncScriptArray {
            let pars = createParmes(dict: item.parmers)
            let str = "\"\(item.name!)\":function(){return JSON.stringify(\(pars));},"
            result += str
        }
        result = (result as NSString).substring(to: result.count - 1)
        result += "}"
        print("++++++++\(result)")
        return result
    }
    
    private func createParmes(dict: [String]) -> String {
        var result = ""
        for key in dict {
            result += key + ","
        }
        if result.count > 0 {
            result = (result as NSString).substring(to: result.count - 1)
        }
        return result
    }

    /// MARK: - 执行JS
    public func actionJsFunc(functionName: String, pars: [AnyObject], completionHandler: ((Any?, Error?) -> Void)?) {
        var parString = ""
        for par in pars {
            parString += "\(par),"
        }
        
        if parString.count > 0 {
            parString = (parString as NSString).substring(to: parString.count - 1)
        }
        
        let function = "\(functionName)(\(parString));"
        wkWebView.evaluateJavaScript(function, completionHandler: completionHandler)
    }
}

// WebView UI 样式及处理逻辑
extension FastJSController {
    /// 控制条
    func updateToolbarItems() {
        backBarButtonItem.isEnabled = wkWebView.canGoBack
        forwardBarButtonItem.isEnabled = wkWebView.canGoForward
        
        let refreshStopBarButtonItem: UIBarButtonItem = wkWebView.isLoading ? stopBarButtonItem : refreshBarButtonItem
        
        let fixedSpace: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.fixedSpace, target: nil, action: nil)
        let flexibleSpace: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        
        if (UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            let toolbarWidth: CGFloat = 250.0
            fixedSpace.width = 35.0
            
            let items: NSArray = [fixedSpace, refreshStopBarButtonItem, fixedSpace, backBarButtonItem, fixedSpace, forwardBarButtonItem, fixedSpace, actionBarButtonItem]
            
            let toolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0.0, y: 0.0, width: toolbarWidth, height: 44.0))
            if !closing {
                toolbar.items = items as? [UIBarButtonItem]
                if presentingViewController == nil {
                    toolbar.barTintColor = navigationController!.navigationBar.barTintColor
                } else {
                    toolbar.barStyle = navigationController!.navigationBar.barStyle
                }
                toolbar.tintColor = navigationController!.navigationBar.tintColor
            }
            navigationItem.rightBarButtonItems = items.reverseObjectEnumerator().allObjects as? [UIBarButtonItem]
            
        } else {
            let items: NSArray = [fixedSpace, backBarButtonItem, flexibleSpace, forwardBarButtonItem, flexibleSpace, refreshStopBarButtonItem, flexibleSpace, actionBarButtonItem, fixedSpace]
            
            if let navigationController = navigationController, !closing {
                if presentingViewController == nil {
                    navigationController.toolbar.barTintColor = navigationController.navigationBar.barTintColor
                } else {
                    navigationController.toolbar.barStyle = navigationController.navigationBar.barStyle
                }
                navigationController.toolbar.tintColor = navigationController.navigationBar.tintColor
                toolbarItems = items as? [UIBarButtonItem]
            }
        }
    }
    
    /// MARK: - Action
    @objc func goBackTapped(_ sender: UIBarButtonItem) {
        wkWebView.goBack()
    }
    
    @objc func goForwardTapped(_ sender: UIBarButtonItem) {
        wkWebView.goForward()
    }
    
    @objc func reloadTapped(_ sender: UIBarButtonItem) {
        wkWebView.reload()
    }
    
    @objc func stopTapped(_ sender: UIBarButtonItem) {
        wkWebView.stopLoading()
        updateToolbarItems()
    }
    
    @objc func actionButtonTapped(_ sender: AnyObject) {
        if let url: URL = ((wkWebView.url != nil) ? wkWebView.url : URL(string: "")) {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(activityVC, animated: true, completion: nil)
        }
    }
    
    @objc func doneButtonTapped() {
        closing = true
        UINavigationBar.appearance().barStyle = storedStatusColor!
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Class Methods
    // Helper function to get image within SwiftWebVCResources bundle
    // - parameter named: The name of the image in the SwiftWebVCResources bundle
    class func bundledImage(named: String) -> UIImage? {
        let image = UIImage(named: named)
        if image == nil {
            return UIImage(named: named, in: Bundle(for: self.classForCoder()), compatibleWith: nil)
        }
        // Replace MyBasePodClass with yours
        return image
    }
    
}

/// MARK: - WKUIDelegate
extension FastJSController: WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { (_) -> Void in
            // We must call back js
            completionHandler()
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
}

/// MARK: - WKNavigationDelegate
extension FastJSController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.delegate?.didStartLoading()
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        updateToolbarItems()
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.delegate?.didFinishLoading(success: true)
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        webView.evaluateJavaScript("document.title", completionHandler: {(response, error) in
            self.navBarTitle.text = response as! String?
            self.navBarTitle.sizeToFit()
            self.updateToolbarItems()
        })
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.delegate?.didFinishLoading(success: false)
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        updateToolbarItems()
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let url = navigationAction.request.url
        let hostAddress = navigationAction.request.url?.host
        
        if (navigationAction.targetFrame == nil) {
            if UIApplication.shared.canOpenURL(url!) {
                UIApplication.shared.openURL(url!)
            }
        }
        
        // To connnect app store
        if hostAddress == "itunes.apple.com" {
            if UIApplication.shared.canOpenURL(navigationAction.request.url!) {
                UIApplication.shared.openURL(navigationAction.request.url!)
                decisionHandler(.cancel)
                return
            }
        }
        
        let url_elements = url!.absoluteString.components(separatedBy: ":")
        switch url_elements[0] {
        case "tel":
            openCustomApp(urlScheme: "telprompt://", additional_info: url_elements[1])
            decisionHandler(.cancel)
        case "sms":
            openCustomApp(urlScheme: "sms://", additional_info: url_elements[1])
            decisionHandler(.cancel)
        case "mailto":
            openCustomApp(urlScheme: "mailto://", additional_info: url_elements[1])
            decisionHandler(.cancel)
        default:
            print("Default")
        }
        decisionHandler(.allow)
    }
    
    func openCustomApp(urlScheme: String, additional_info:String){
        if let requestUrl: URL = URL(string:"\(urlScheme)"+"\(additional_info)") {
            let application:UIApplication = UIApplication.shared
            if application.canOpenURL(requestUrl) {
                application.openURL(requestUrl)
            }
        }
    }
}


// MARK: - WKScriptMessageHandler
extension FastJSController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        let funcObjs = self.mAsyncScriptArray.filter { (obj) -> Bool in
            return obj.name == message.name
        }
        
        if let funcObj = funcObjs.first {
            let pars = message.body as! [AnyObject]
            var dict: [String: AnyObject] = [:]
            for i in 0..<funcObj.parmers.count {
                let key = funcObj.parmers[i]
                if pars.count > i {
                    dict[key] = pars[i]
                }
            }
            
            funcObj.action?(dict)
        }
    }
}
