//
// Created by lip on 2017/10/17.
// Copyright (c) 2017 ZhiYiCX. All rights reserved.
//

import Foundation
import ObjectMapper

class AppEnvironmentModel: Mappable {
    /// 崩溃收集标识
    var buglyAppID: String = ""
    /// 崩溃收集Key
    var buglyAppKey: String = ""
    /// 高德地图apikey
    var aMapApiKey: String = ""
    /// 是否隐藏游客开关
    var isHiddenGuestLoginButtonInLaunch: Bool = false
    /// 极光推送的key
    var jPushKey: String = ""
    /// 服务器地址
    var serverAddress: String = ""
    /// 环信配置Key
    var imAppKey: String = ""
    /// 环信配置推送证书名称
    var imApnsName: String = ""
    /// 是否是App Store上架版本
    /// 1、App Store 只有IAP充值积分，不允许其他支付方式。移除钱包功能，不能积分提现。后台配置无效
    /// 2、网站分发版本 支付宝/微信购买积分开关 按后台配置
    var isAppStoreVersion: Bool = false

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        buglyAppID <- map["BuglyAppID"]
        buglyAppKey <- map["BuglyAppKey"]
        aMapApiKey <- map["AMapApiKey"]
        isHiddenGuestLoginButtonInLaunch <- map["isHiddenGuestLoginButtonInLaunch"]
        jPushKey <- map["jPushKey"]
        isAppStoreVersion <- map["isAppStoreVersion"]
        #if DEBUG
        let serverType = UserDefaults.standard.integer(forKey: "TSPlusServerTypeKey")
        switch serverType {
        case 0:
            serverAddress <- map["serverAddress.develop.address"]
            imAppKey <- map["serverAddress.develop.imAppKey"]
            imApnsName <- map["serverAddress.develop.imApnsName"]
        case 1:
            serverAddress <- map["serverAddress.production.address"]
            imAppKey <- map["serverAddress.production.imAppKey"]
            imApnsName <- map["serverAddress.production.imApnsName"]
        case 2:
            serverAddress = UserDefaults.standard.object(forKey: "TSPlusServerURLKey") as! String
            imAppKey = UserDefaults.standard.object(forKey: "TSPlusServerJPNameKey") as! String
            imApnsName = UserDefaults.standard.object(forKey: "TSPlusServerJPKeyKey") as! String
        default:
            serverAddress <- map["serverAddress.develop.address"]
            imAppKey <- map["serverAddress.develop.imAppKey"]
            imApnsName <- map["serverAddress.develop.imApnsName"]
        }
        #else
        serverAddress <- map["serverAddress.production.address"]
        imAppKey <- map["serverAddress.production.imAppKey"]
        imApnsName <- map["serverAddress.production.imApnsName"]
        #endif
    }
}
