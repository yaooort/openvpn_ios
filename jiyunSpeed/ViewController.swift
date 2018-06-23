//
//  ViewController.swift
//  jiyunSpeed
//
//  Created by Jorah Li on 22/6/2561 BE.
//  Copyright © 2561 Jorah Li. All rights reserved.
//

import UIKit
import NetworkExtension

class ViewController: UIViewController {

    var manager: NETunnelProviderManager?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func mBtn(_ sender: Any) {
        print("connect btn clicked")
        let callback = { (error: Error?) -> Void in
            self.manager?.loadFromPreferences(completionHandler: { (error) in
                guard error == nil else {
                    print("\(error!.localizedDescription)")
                    return
                }
                
                let options: [String : NSObject] = [
                    "username": "" as NSString,
                    "password": "" as NSString
                ]
                
                do {
                    try self.manager?.connection.startVPNTunnel(options: options)
                } catch {
                    print("\(error.localizedDescription)")
                }
            })
        }
        
        configureVPN(callback: callback)
        
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
            
            let passwordKey = "1111"
            
            do {
                // try self.keychain.set("sohil", key: passwordKey)
            } catch {
                print("\(error.localizedDescription)")
                callback(error)
                return
            }
            
            // guard let passwordReference = self.keychain[attributes: passwordKey]?.persistentRef else {
                // fatalError()
            // }
            
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
                tunnelProtocol.serverAddress = "123"
                tunnelProtocol.providerBundleIdentifier = "org.com.jiyunSpeed.net.packetTunnel"
                tunnelProtocol.providerConfiguration = ["configuration": configurationContent]
                tunnelProtocol.username = "sohil"
              //  tunnelProtocol.passwordReference = passwordReference
                // tunnelProtocol.passwordReference = ""
                tunnelProtocol.disconnectOnSleep = false
                
                self.manager?.protocolConfiguration = tunnelProtocol
                self.manager?.localizedDescription = "OpenVPN iOS Client 2"
                
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


