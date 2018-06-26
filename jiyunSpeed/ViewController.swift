//
//  ViewController.swift
//  jiyunSpeed
//
//  Created by Jorah Li on 22/6/2561 BE.
//  Copyright © 2561 Jorah Li. All rights reserved.
//

import UIKit
import NetworkExtension
import JavaScriptCore

public enum VPNStatus {
    case Off
    case Connecting
    case On
    case Disconnecting
}


@objc protocol JavaScriptMethodProtocol:JSExport {
    func playLog(videoId:String)
    func stopVpn()
    func getVpnLastLog()->String
    func toast(_ str: String)
    func recordLogin()
    func getAppVersionCode()->String
    func openShare(_ title: String, _ content: String)
    func launchVpn(
       _ msg: String,
       _ lineId: String,
       _ name: String,
       _ password: String,
       _ ca: String,
       _ tls: String,
       _ remote: String,
       _ port: String
    )
    func existsCollectVideo(collectId:String, _ handleName:String, _ typeStr:String)
}

@objc class jsMethod: NSObject, JavaScriptMethodProtocol {
    
    
    private var vc:ViewController?
    var jsContext:JSContext!
    
    init(viewController:ViewController) {
        self.vc = viewController
    }
    
    func toast(_ str: String) {
        print(str)
    }
    
    func getVpnLastLog () -> String{
        return ""
    }
    
    func recordLogin() {
       print("login")
    }
    
    func getAppVersionCode () -> String{
        return ""
    }
    
    func openShare(_ title: String, _ content: String) {
        print("js call share title is")
    }

    
    // todo: 时间一长，重装才能 开启成功 ?
    func launchVpn(_ msg: String, _ lineId: String, _ name: String, _ password: String, _ ca: String, _ tls: String, _ remote: String, _ port: String) {
        print("start vpn ca \(ca)")
        self.vc?.connectVpn()
    }
    
    func stopVpn() {
        self.vc?.stopVpn()
    }

    func playLog(videoId:String) {
        print(videoId)
    }
    
    func existsCollectVideo(collectId:String, _ handleName:String, _ typeStr:String) {
        // call js
        let handleFunc = self.jsContext.objectForKeyedSubscript(handleName)
        let dict = ["type": typeStr, "status": false] as [String : Any]
        // handleFunc?.call(withArguments: [dict])
    }
}


class ViewController: UIViewController{
    
    @IBOutlet weak var mWb: UIWebView!
    @IBOutlet weak var mVpnStatus: UILabel!
    @IBOutlet weak var mConnectBtn: UIButton!
    @IBOutlet weak var mStopBtn: UIButton!
    private var jsContext:JSContext!
    private var manager: NETunnelProviderManager?
    public var observerAdded: Bool = false
    public let kProxyServiceVPNStatusNotification = "kProxyServiceVPNStatusNotification"
    
    
    public private(set) var vpnStatus = VPNStatus.Off {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.initBtn()
        self.initWb()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
   
    func initWb () {
        // let url = URL(string: "https://app.geeyun.org/#/login")
        let url = URL(string: "http://192.168.1.103:9001/#/login")
        self.mWb.delegate = self
        self.mWb.scalesPageToFit = true
        self.mWb.loadRequest(URLRequest(url: url!))
        // todo: add before user agent
        UserDefaults.standard.register(defaults: ["UserAgent": "androidvpn"])
    }

    func initBtn () {
        mConnectBtn.tag = 2000
        mStopBtn.tag = 2001
        mStopBtn.addTarget(self, action: #selector(ViewController.btnClick), for: UIControlEvents.touchUpInside)
        mConnectBtn.addTarget(self, action: #selector(ViewController.btnClick), for: UIControlEvents.touchUpInside)
    }
    
    @objc func btnClick(sender: UIButton?) {
        let tag = sender?.tag
        switch (tag!) {
        case mConnectBtn.tag:
            connectVpn()
            break
        case mStopBtn.tag:
            stopVpn()
            break
        default:
            break
        }
    }
    
    func stopVpn () {
       self.manager?.connection.stopVPNTunnel()
    }
    
    func connectVpn () {
        print("call connect")
        self.mWb.stringByEvaluatingJavaScript(from: "startConectAfterPermission()")
        let callback = { (error: Error?) -> Void in
            self.manager?.loadFromPreferences(completionHandler: { (error) in
                guard error == nil else {
                    print("\(error!.localizedDescription)")
                    return
                }
                
                let options: [String : NSObject] = [
                    "username": "647622122" as NSString,
                    "password": "111111" as NSString
                ]
                
                do {
                    try self.manager?.connection.startVPNTunnel(options: options)
                    self.addVPNStatusObserver()
                } catch {
                    print("\(error.localizedDescription)")
                }
            })
        }
        
        configureVPN(callback: callback)
    }
    
    func addVPNStatusObserver() {
        guard !observerAdded else{
            return
        }
        loadProviderManager { [unowned self] (manager) -> Void in
            if let manager = manager {
                self.observerAdded = true
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: manager.connection, queue: OperationQueue.main, using: { [unowned self] (notification) -> Void in
                    self.updateVPNStatus(manager: manager)
                })
                
            }
        }
    }
    

    
    func updateVPNStatus(manager: NEVPNManager) {
        switch manager.connection.status {
        case .connected:
            mVpnStatus.text = "connected"
            self.updateWebVpnStatus(status: "connected")
            print("connected")
            self.vpnStatus = .On
        case .connecting, .reasserting:
            mVpnStatus.text = "connection"
            print("connecting")
            self.vpnStatus = .Connecting
        case .disconnecting:
            print("disconnecting")
            mVpnStatus.text = "disconnecting"
            self.vpnStatus = .Disconnecting
        case .disconnected, .invalid:
            print("off")
            mVpnStatus.text = "off"
            self.vpnStatus = .Off
        }
    }
    

    public func loadProviderManager(complete: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences{ (managers, error) -> Void in
            if let managers = managers {
                if managers.count > 0 {
                    let manager = managers[0]
                    complete(manager)
                    return
                }
            }
            complete(nil)
        }
    }

}

extension ViewController {
    // MARK: -
    func configureVPN(callback: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            guard error == nil else {
                print("\(error!.localizedDescription)")
                callback(error)
                return
            }
            // call web  webView.evaluateJavaScript("something = 42", completionHandler: nil)
            self.manager = managers?.first ?? NETunnelProviderManager()
            
            self.manager?.loadFromPreferences(completionHandler: { (error) in
                guard error == nil else {
                    print("\(error!.localizedDescription)")
                    callback(error)
                    return
                }
                let configurationFile = Bundle.main.url(forResource: "freeopenvpn_USA_udp", withExtension: "ovpn")
                let configurationContent = try! Data(contentsOf: configurationFile!)
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.serverAddress = "freeopenvpn.org"
                tunnelProtocol.providerBundleIdentifier = "org.com.jiyunSpeed.net.packetTunnel"
                tunnelProtocol.providerConfiguration = ["configuration": configurationContent]
                tunnelProtocol.disconnectOnSleep = false
                self.manager?.protocolConfiguration = tunnelProtocol
                self.manager?.localizedDescription = "jiyunVpn"
                self.manager?.isEnabled = true
                self.manager?.saveToPreferences(completionHandler: { (error) in
                    guard error == nil else {
                        print("\(error!.localizedDescription)")
                        callback(error)
                        return
                    }
                    
                    callback(nil)
                })
            })
        }
    }
}

extension ViewController: UIWebViewDelegate {
    // 该方法是在UIWebView在开发加载时调用
    func webViewDidStartLoad(_ webView: UIWebView) {
        print("开始加载")
        // LCProgressHUD.showLoading("正在加载")
    }
    
    // 该方法是在UIWebView加载完之后才调用
    func webViewDidFinishLoad(_ webView: UIWebView) {
        print("加载完成")
        // LCProgressHUD.hide()
        let jsContext = webView.value(forKeyPath: "documentView.webView.mainFrame.javaScriptContext") as? JSContext
        jsContext?.setObject(jsMethod(viewController: self), forKeyedSubscript: "android" as NSCopying & NSObjectProtocol)
        // self.mWb.stringByEvaluatingJavaScript(from: "alert(1)")
        let status = "connected"
        self.mWb.stringByEvaluatingJavaScript(from: "(setStatus('\(status)'))")
        // let curUrl =  webView.request?.url?.absoluteURL
        // useful ?
        // self.jsContext?.evaluateScript(try? String(contentsOf: curUrl!, encoding: String.Encoding.utf8))//WebView当前访问页面的链接 可动态注册
        self.jsContext?.exceptionHandler = { context, exception in
            print("JS Error: \(exception?.description ?? "unknown error")")
        }

    }
    
    func updateWebVpnStatus(status: String) {
        self.mWb.stringByEvaluatingJavaScript(from: "(setStatus('\(status)'))")
    }
    
    // 该方法是在UIWebView请求失败的时候调用
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        print("加载失败")
        // LCProgressHUD.hide()
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        let reqUrl = request.url?.absoluteString
        if (reqUrl?.starts(with: "alipays://"))! {
            UIApplication.shared.open(request.url!)
            return false;
        }
        return true;
        
        }

    }
    



