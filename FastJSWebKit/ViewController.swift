//
//  ViewController.swift
//  FastJSWebKit
//
//  Created by Steven Xie on 2018/10/18.
//  Copyright © 2018 Steven Xie. All rights reserved.
//

import UIKit

class ViewController: FastJSController {

    override func viewDidLoad() {
        super.viewDidLoad()
                
        let userInfo = ["name": "wb", "sex": "male", "phone": "12333434"]
        let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: .prettyPrinted)
        let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)
        
        // 发数据：添加getUserInfo脚本，返回用户信息
        // 🖥 getUserInfo
        addSyncJSFunc(functionName: "getUserInfo", parmers: [jsonText!])
        
        
        // 收数据：添加shareAction脚本，获得分享参数
        // 🖥 shareAction
        addAsyncJSFunc(functionName: "shareAction", parmers: ["title", "content", "url", "shareBack"]) { [weak self] (dict) in
            print(dict["title"]!)
            print(dict["content"]!)
            print(dict["url"]!)
            
            // 调用方法：执行shareBack脚本，告诉H5分享结果
            // 🖥 dict["shareBack"] -> shareSucc
            self?.actionJsFunc(functionName: dict["shareBack"] as! String, pars: [true as AnyObject], completionHandler: { (code, error) in
                
            })
        }
        
        //开始加载H5
//        loadWithUrl(URL.init(string: "https://www.baidu.com")!)
        loadWithFiles(resource: "test", withExtension: "html")
    }
}

