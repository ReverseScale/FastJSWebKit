# FastJSWebKit
轻量级 WKWebView <-> JS 通信方案 🤪

![](http://og1yl0w9z.bkt.clouddn.com/18-11-13/74833121.jpg)

-----
### 前言
了解本文之前需要准备 JS 和 WebView 中的一些基础知识，需要知道 JS 的基本语法和 WebView 中调用 JS 的常用接口。

iOS 实现 JS 和 Native 交互的 WebView 有 UIWebView 和 WKWebView。

UIWebView 通过 KVC 拿到 UIWebView 的JSContext，通过 JSContext 实现交互
而 WKWebView 有了新特性 MessageHandler 来实现 JS 调用 Native 方法。

从实现思路是来讲，UIWebView 和 WKWebView 是一样的。
所以，本文只介绍 WKWebView 上 JS 和 Native 的交互思路，UIWebView 有需求的可以模仿实现。

-----
### JS 和 Native 交互常用的场景
常用的分为下面几种场景：

* H5 获取本地用户信息（这种比较简单，只需要本地注入JS就行了，思路有三种下面介绍）

* H5 传递信息给 Native，Native 调用分享（这种属于JS调用 Native）

* Native 告诉 H5 分享结果（这种属于原生调用JS）

-----
#### 1）H5 获取本地用户信息

-----
##### *a.通过`WKUserContentController` 注入 JS 实现*

现有用户信息格式如下，需要注入到JS，供H5调用：

```Swift
let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
```

-----
📱 1.a1 Native 注入 JS 变量实现如下

```Swift
let userContent = WKUserContentController.init()

let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
for key in userInfo.keys {
    let script = WKUserScript.init(source: "var \(key) = \"\(userInfo[key]!)\"", injectionTime: .atDocumentStart, forMainFrameOnly: true)
    userContent.addUserScript(script)
}

let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))
```

通过遍历用户信息的 key，把 key 作为变量，value 作为字符串值，注入到 JS 上下文中。

-----
🖥 在H5中实现调用如下
```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <script type="text/javascript">
    function btnClick() {
        try {
            alert(name)
            alert(sex)
            alert(phone)
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="btnClick()" style="font-size: 100px;">test JS</button>
    </p>
</body>

</html>
```

-----
📱 1.a2 Native 注入 JS 对象实现如下
```Swift
let userContent = WKUserContentController.init()

let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)

let script = WKUserScript.init(source: "var userInfo = \(jsonText!)", injectionTime: .atDocumentStart, forMainFrameOnly: true)
userContent.addUserScript(script)
let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))
```

通过把用户信息字典转化成JSON，作为对象赋值给用户信息，注入JS上下文中。

-----
🖥 在H5中实现调用如下
```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <script type="text/javascript">
    function btnClick() {
        try {
            alert(JSON.stringify(userInfo))
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="btnClick()" style="font-size: 100px;">test JS</button>
    </p>
</body>

</html>
```

-----
📱 1.a3 Native 注入 JS 函数实现如下

```Swift
let userContent = WKUserContentController.init()

let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)

let script = WKUserScript.init(source: "var iOSApp = {\"getUserInfo\":function(){return \(jsonText!)}}", injectionTime: .atDocumentStart, forMainFrameOnly: true)
userContent.addUserScript(script)
let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))
```

通过封装`getUserInfo`匿名函数，执行函数返回我们的对象，生成全局对象iOSApp，调用`iOSApp.getUserInfo()`。

这样写的好处是，我们的H5在调用函数的时候，可以很容易知道哪些是 Native 注入，防止和本地造成冲突，便于理解。

-----
🖥 在H5中实现调用如下
```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <script type="text/javascript">
    function btnClick() {
        try {
            alert(JSON.stringify(iOSApp.getUserInfo()))
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="btnClick()" style="font-size: 100px;">test JS</button>
    </p>
</body>

</html>
```

以上讲了三种方式实现用户信息的传递，都是通过`WKUserContentController`注入JS实现的，实际上我也可以通过网页视图的`evaluateJavaScript`方法实现注入。

-----
##### *b.通过 `evaluateJavaScript` 方法实现*

同样的 WebView 中的调用 H5，提供了`evaluateJavaScript`接口，此接口既可以执行JS 函数回调结果，也可以注入 JS。

-----
📱 使用接口实现JS函数的注入
```Swift
let userContent = WKUserContentController.init()
let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))

...

//代理方法加载完成
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
    let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
    let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)

    webView.evaluateJavaScript("var iOSApp = {\"getUserInfo\":function(){return \(jsonText!)}}", completionHandler: nil)
}
```

在WebView中加载完成之后，使用`evaluateJavaScript`实现了JS函数的注入，H5实现调用正常。

-----
#### 2）H5 传递信息给 Native，Native 调用分享

很多时候 H5 需要传递信息给 Native，Native 再执行相应的逻辑。

-----
🖥 H5实现代码如下
```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <meta charset="utf-8">
    <script type="text/javascript">
    function btnClick() {
        try {
            window.webkit.messageHandlers.shareAction.postMessage({"title":"分享", "content":"内容", "url":"链接"})
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="btnClick()" style="font-size: 100px;">test JS</button>
    </p>
</body>

</html>
```
H5 将分享内容通过`window.webkit.messageHandlers.shareAction.postMessage`交给 Native 

-----
📱 Native 实现代码如下
```Swift
let userContent = WKUserContentController.init()
userContent.add(self, name: "shareAction")
let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))

...

//代理方法，window.webkit.messageHandlers.xxx.postMessage(xxx)实现发送到这里
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    print(message.body)
    print(message.name)
    print(message.frameInfo.request)
    
    if message.name == "shareAction" {
        let list = message.body as! [String: String]
        print(list["title"]!)
        print(list["content"]!)
        print(list["url"]!)
    }
}
```

`userContent.add(self, name: "shareAction")`本地添加`shareAction`的接口声明，当JS调用`shareAction`回调代理方法，实现参数捕获（WKScriptMessage）。
这样 Native 就得到了分享的传参了，然后可以调用本地 SDK 实现分享的逻辑了。

-----
#### 3）Native 告诉 H5 分享结果

上面实现了 JS 传参数给 Native，但是 Native 还需要告诉 H5 分享结果。

-----
📱 Native 实现代码如下

```Swift
let userContent = WKUserContentController.init()
userContent.add(self, name: "shareAction")
let config = WKWebViewConfiguration.init()
config.userContentController = userContent

let wkWebView: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
wkWebView.navigationDelegate = self
wkWebView.uiDelegate = self
view.addSubview(wkWebView)
view.insertSubview(wkWebView, at: 0)
wkWebView.load(URLRequest.init(url: URL.init(string: "http://192.168.2.1/js.html")!))

...

//代理方法，window.webkit.messageHandlers.xxx.postMessage(xxx)实现发送到这里
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    print(message.body)
    print(message.name)
    print(message.frameInfo.request)
    
    if message.name == "shareAction" {
        let list = message.body as! [Any]
        
        let dict = list[0] as! [String: String]
        print(dict["title"]!)
        print(dict["content"]!)
        print(dict["url"]!)
        
        let shareSucc = list[1] as! String//获取回调JS，通知H5分享成功了
        let script = "\(shareSucc)(true)"
        wkWebView?.evaluateJavaScript(script, completionHandler: nil)
    }
}
```

获取`shareSucc`的函数回调名称，在合适的时候我们可以通过这个JS函数回调，告诉H5我们的分享结果。

-----
🖥 JS实现如下
```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <meta charset="utf-8">
    <script type="text/javascript">
    function shareSucc(isShare) {
        alert(isShare)
    }

    function btnClick() {
        try {
            window.webkit.messageHandlers.shareAction.postMessage([{ "title": "分享", "content": "内容", "url": "链接" }, "shareSucc"])
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="btnClick()" style="font-size: 100px;">test JS</button>
    </p>
</body>

</html>
```

之前的`postMessage`是发送的字典，由于我们的需求增多了，所以还是改成数组。

最后发送`shareSucc`的字符串，告诉 Native 我们有一个`shareSucc`的函数可以接收分享的结果。

-----
### JS 和 Native 统一封装
上面讲了 JS 回调 Native，Native 回调 JS，实现了我们常用的一些业务逻辑。

里面有很多重复的代码，实现起来也不友好，下面我们把这些重用的全部封装一下，改成好用的接口给上层，使 Native 和 JS 的开发人员都不用操心太多的实现细节。

-----
🖥 H5界面的代码

```js
<!DOCTYPE html>
<html>

<head>
    <title>js Bridge demo</title>
    <meta charset="utf-8">
    <script type="text/javascript">
    function shareSucc(isShare) {
        alert(isShare)
    }

    function reqUserInfoClick() {
        try {
            alert(iOSApp.getUserInfo())
        } catch (err) {
            alert(err)
        }
    }

    function reqShareClick() {
        try {
            iOSApp.shareAction("分享title", "分享content", "分享url", "shareSucc")
        } catch (err) {
            alert(err)
        }
    }
    </script>
</head>

<body>
    <h1>js demo test</h1>
    <p style="text-align: center;">
        <button type="button" onclick="reqUserInfoClick()" style="font-size: 100px;">获取用户信息</button>
        <button type="button" onclick="reqShareClick()" style="font-size: 100px;">执行分享</button>
    </p>
</body>

</html>
```

-----
📦 封装 WKWebView 基类 JWebViewController

```Swift
import UIKit
import WebKit

class JWebViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler {

    private var mAsyncScriptArray:[JKWkWebViewHandler] = []
    private var mSyncScriptArray:[JKWkWebViewHandler] = []
    
    private var wkWebView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    public func startUrl(_ url: URL) {
        let configuretion = WKWebViewConfiguration()
        configuretion.preferences = WKPreferences()
        configuretion.preferences.javaScriptEnabled = true
        configuretion.userContentController = WKUserContentController()
        if self.mAsyncScriptArray.count != 0 || self.mSyncScriptArray.count != 0 {
            // 在载入时就添加JS // 只添加到mainFrame中
            let script = WKUserScript(source: createScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true)
            configuretion.userContentController.addUserScript(script)
        }

        //异步需要回调，所以需要添加handler
        for item in self.mAsyncScriptArray {
            configuretion.userContentController.add(self, name: item.name)
        }
        
        let wkWebView = WKWebView(frame: self.view.bounds, configuration: configuretion)
        wkWebView.uiDelegate = self
        self.view.insertSubview(wkWebView, at: 0)
        let request = URLRequest(url: url)
        wkWebView.load(request)
        self.wkWebView = wkWebView
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        //释放handler
        for item in self.mAsyncScriptArray {
            wkWebView?.configuration.userContentController.removeScriptMessageHandler(forName: item.name)
            wkWebView?.configuration.userContentController.removeAllUserScripts()
        }
    }
    
    // MARK: - 添加JS
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
    
    // MARK: - 插入JS
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

    // MARK: - 执行JS
    public func actionJsFunc(functionName: String, pars: [AnyObject], completionHandler: ((Any?, Error?) -> Void)?) {
        var parString = ""
        for par in pars {
            parString += "\(par),"
        }
        
        if parString.count > 0 {
            parString = (parString as NSString).substring(to: parString.count - 1)
        }
        
        let function = "\(functionName)(\(parString));"
        wkWebView?.evaluateJavaScript(function, completionHandler: completionHandler)
    }

    // MARK: - WKUIDelegate
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { (_) -> Void in
            // We must call back js
            completionHandler()
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - WKScriptMessageHandler
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

class JKWkWebViewHandler: NSObject {
    fileprivate var name:String!
    fileprivate var parmers:[String]!
    fileprivate var action:(([String:AnyObject]) -> Void)?
}
```

-----
📱 继承 JWebViewController 实现业务

```Swift
import UIKit

class ViewController: JWebViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
        let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
        let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)
        
        //添加getUserInfo脚本，返回用户信息
        addSyncJSFunc(functionName: "getUserInfo", parmers: [jsonText!])
        
        //添加shareAction脚本，获得分享参数
        addAsyncJSFunc(functionName: "shareAction", parmers: ["name", "sex", "phone", "shareBack"]) { [weak self] (dict) in
            print(dict["name"]!)
            print(dict["sex"]!)
            print(dict["phone"]!)
            
            //执行shareBack脚本，告诉H5分享结果
            self?.actionJsFunc(functionName: dict["shareBack"] as! String, pars: [true as AnyObject], completionHandler: nil)
        }
        
        //开始加载H5
        startUrl(URL.init(string: "http://192.168.2.1/js.html")!)
        
    }
    
}
```

-----
### 讲解 JWebViewController

构造`JKWkWebViewHandler`类，存储信息

```Swift
class JKWkWebViewHandler: NSObject {
    fileprivate var name:String!
    fileprivate var parmers:[String]!
    fileprivate var action:(([String:AnyObject]) -> Void)?
}
```

添加JS，使用`JKWkWebViewHandler`存储

```Swift
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
```

创建JS脚本，使用`iOSApp`对象封装，异步回调传回本地的函数`window.webkit.messageHandlers.xxx`直接封装在JS函数中。

这样有一个好处，H5调用JS，直接`iOSApp.xxx（XXX）`就行了，不需要写`window.webkit.messageHandlers.xxx`这些代码。

这对于H5来说，跟平时写的JS脚本没有什么区别，方便了调用。

对于 Native 来说，帮H5做了JS的回调的封装，并通过处理器回调得到自己想要的参数，通过这个封装，两端都只需关注业务层就行了，继承`JWebViewController`，可以专心写业务逻辑。

```Swift
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
```

构造JS，实现传参给H5页面

```Swift
public func actionJsFunc(functionName: String, pars: [AnyObject], completionHandler: ((Any?, Error?) -> Void)?) {
    var parString = ""
    for par in pars {
        parString += "\(par),"
    }
    
    if parString.count > 0 {
        parString = (parString as NSString).substring(to: parString.count - 1)
    }
    
    let function = "\(functionName)(\(parString));"
    wkWebView?.evaluateJavaScript(function, completionHandler: completionHandler)
}
```

注入JS脚本到`WKWebViewConfiguration`中

```Swift
let configuretion = WKWebViewConfiguration()
configuretion.preferences = WKPreferences()
configuretion.preferences.javaScriptEnabled = true
configuretion.userContentController = WKUserContentController()
if self.mAsyncScriptArray.count != 0 || self.mSyncScriptArray.count != 0 {
    // 在载入时就添加JS // 只添加到mainFrame中
    let script = WKUserScript(source: createScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true)
    configuretion.userContentController.addUserScript(script)
}

//异步需要回调，所以需要添加handler
for item in self.mAsyncScriptArray {
    configuretion.userContentController.add(self, name: item.name)
}

let wkWebView = WKWebView(frame: self.view.bounds, configuration: configuretion)
```

合适的时候释放JS的处理程序中，注意不释放的话，控制器不会调用DEINIT，发生内存泄露。

```Swift
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    
    //释放handler
    for item in self.mAsyncScriptArray {
              wkWebView?.configuration.userContentController.removeScriptMessageHandler(forName: item.name)
        wkWebView?.configuration.userContentController.removeAllUserScripts()
    }
}
```
