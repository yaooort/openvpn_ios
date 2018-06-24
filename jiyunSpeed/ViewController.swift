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


@objc protocol VideoJsDelegate:JSExport {
    func playLog(videoId:String)
    func stopVpn()
    func launchVpn(
        msg: String,
        lineId: String,
        name: String,
        password: String,
        ca: String,
        tls: String,
        remote: String,
        port: String
    )
    func existsCollectVideo(collectId:String, _ handleName:String, _ typeStr:String)
}

@objc class VideoJsModel: NSObject, VideoJsDelegate {
    
    var jsContext:JSContext!
    
    func launchVpn(msg: String, lineId: String, name: String, password: String, ca: String, tls: String, remote: String, port: String) {
        print("start vpn ca \(ca)")
    }
    
    func stopVpn() {
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


class ViewController: UIViewController, UIWebViewDelegate{
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
        let url = URL(string: "https://app.geeyun.org/#/")
        mWb.loadRequest(URLRequest(url: url!))
        // todo: add before user agent
        UserDefaults.standard.register(defaults: ["UserAgent": "androidvpn"])
        self.mWb.delegate = self
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
            print("exec connect")
            connectVpn()
            break
        case mStopBtn.tag:
            print("exec stop connect")
            self.manager?.connection.stopVPNTunnel()
            break
        default:
            break
        }
    }
    
    func connectVpn () {
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
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        self.jsContext = webView.value(forKeyPath: "documentView.webView.mainFrame.javaScriptContext") as! JSContext
        let model = VideoJsModel()
        model.jsContext = self.jsContext
        self.jsContext.setObject(model, forKeyedSubscript: "android" as NSCopying & NSObjectProtocol)
        //WebView当前访问页面的链接 可动态注册
        // let curUrl = webView.request?.url?.absoluteString
        // self.jsContext.evaluateScript(try? String(contentsOfURL: NSURL(string: curUrl!)!, encoding: NSUTF8StringEncoding))
        // self.jsContext.evaluateScript(<#T##script: String!##String!#>, withSourceURL: <#T##URL!#>)
        self.jsContext.exceptionHandler = { (context, exception) in
            print("exception：", exception)
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


