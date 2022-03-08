//
//  AppDelegate.swift
//  Thinksns Plus
//
//  Created by lip on 2016/12/13.
//  Copyright © 2016年 ZhiYiCX. All rights reserved.
//
//  应用代理

import UIKit
import MonkeyKing
import RealmSwift
import Regex
import GCDWebServer

@UIApplicationMain
class AppDeleguate: UIResponder, UIApplicationDelegate, JPUSHRegisterDelegate, EMChatManagerDelegate, EMChatroomManagerDelegate, EMGroupManagerDelegate, EMCallManagerDelegate, WXApiDelegate {
    //EMCDDeviceManagerDelegate
    var window: UIWindow?
    /// 注册推送别名计时器
    var registerJPushAliasTimer: Timer?
    /// 注册别名重连计时器间隔
    let kRegisterJPushAliasDistance = 60.0
    var server: GCDWebUploader?
    var IMReconnectTime: Int = 0
    var isIMReconnecting: Bool = false
    var IMlastReconnectionTimeStamp: Int64 = 0
    var statusBarHeight: CGFloat = 0
    

    // MARK: - Application and setup
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        /// 该类初始化之后,配置整个应用主题色等
        DispatchQueue.main.async {
            UITextField.appearance().tintColor = TSColor.main.theme
            UITextView.appearance().tintColor = TSColor.main.theme
        }
        setupDataBaseVersion()

        let apiKey = TSAppConfig.share.environment.aMapApiKey
        guard apiKey.count.isEqualZero == false else {
            fatalError("环境配置错误,检查 AppEnvironment.plist 文件")
        }
        AMapServices.shared().apiKey = apiKey
        // 配置服务器地址
        // V2 版本网络请求
        let noteworkManager2 = RequestNetworkData.share
        noteworkManager2.configRootURL(rootURL: TSAppConfig.share.rootServerAddress)
        // 配置应用相关
        userDefaultsRegister()
        // 优先配置数据库
        setupDataBaseVersion()
        setupLogLevel()
        setupCrash()
        setupShareConfig()
        setupHY(application, didFinishLaunchingWithOptions: launchOptions)
        setupRootViewController()
        setupReachabilityObserve()
        setupIQKeyboardManager()
        setupImageCache()
        launchGCDWebUploader()
        setupJPush(didFinishLaunchingWithOptions: launchOptions)
        window?.backgroundColor = UIColor.white
        // 注册状态栏改变的通知
        NotificationCenter.default.addObserver(self, selector: #selector(statusBarFrameDidChange(notice:)), name: Notification.Name.UIApplicationDidChangeStatusBarFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusBarFrameWillChange(notice:)), name: Notification.Name.UIApplicationWillChangeStatusBarFrame, object: nil)
        return true
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        return WXApi.handleOpen(url, delegate: self)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.host == "safepay" {
            AlipaySDK.defaultService().processOrder(withPaymentResult: url) { (resultDic) in
                if let payBackInfoDic = resultDic as! Dictionary<String, String>? {
                    self.checkAlipayCharge(payBackInfoDic: payBackInfoDic)
                }
            }
        }
        if  MonkeyKing.handleOpenURL(url) || WXApi.handleOpen(url, delegate: self) {
            return true
        }
        return false
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        if url.host == "safepay" {
            AlipaySDK.defaultService().processOrder(withPaymentResult: url) { (resultDic) in
                if let payBackInfoDic = resultDic as! Dictionary<String, String>? {
                    self.checkAlipayCharge(payBackInfoDic: payBackInfoDic)
                }
            }
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        EMClient.shared().applicationDidEnterBackground(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        EMClient.shared().applicationWillEnterForeground(application)
    }

    func statusBarFrameDidChange(notice: Notification) {
        if statusBarHeight == 40 {
            TSUtil.share().statusHeight = ScreenHeight - 20
        } else if statusBarHeight == 20 {
            TSUtil.share().statusHeight = ScreenHeight
        }
    }

    func statusBarFrameWillChange(notice: Notification) {
        let cgrectValue: NSValue = notice.userInfo!["UIApplicationStatusBarFrameUserInfoKey"] as! NSValue
        let frame: CGRect = cgrectValue.cgRectValue
        statusBarHeight = frame.size.height
        if statusBarHeight == 40 {
            TSUtil.share().statusHeight = ScreenHeight - 20
        } else if statusBarHeight == 20 {
            TSUtil.share().statusHeight = ScreenHeight
        }
    }

    /** [临时注释] 暂时未使用到的系统提供的方法 2017-02-10
     func applicationWillResignActive(_ application: UIApplication) {
     // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
     }
     
     func applicationWillEnterForeground(_ application: UIApplication) {
     // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
     }
     
     func applicationDidBecomeActive(_ application: UIApplication) {
     // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     }
     
     func applicationWillTerminate(_ application: UIApplication) {
     // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
     }
     */
}
