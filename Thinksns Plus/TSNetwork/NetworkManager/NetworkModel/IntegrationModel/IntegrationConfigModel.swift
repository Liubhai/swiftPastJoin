//
//  IntegrationConfigModel.swift
//  ThinkSNS +
//
//  Created by GorCat on 2018/1/23.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit
import ObjectMapper

class IntegrationConfigModel: Mappable {

    // 兑换比例，人民币一分钱可兑换的积分数量（例如：ratio = 10，1分钱 = 10积分）
    var ratio = 0
    // 充值选项，人民币分单位
    var optiongs = ""
    // 单笔最高充值额度
    var rechargeMax = 0
    // 单笔最小充值额度
    var rechargeMin = 0
    // 积分规则
    var rule = ""
    // IAP积分规则
    var iapRule = ""
    // 充值规则
    var chargeRule = ""
    // 提现规则
    var cashRule = ""
    // 提现最小额度
    var cashMin = 0
    // 提现最大额度
    var cashMax = 0
    // 提现方式
    var cashType: [String] = []
    // 充值方式
    var rechargeType: [String] = []

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        ratio <- map["recharge-ratio"]
        optiongs <- map["recharge-options"]
        rechargeMax <- map["recharge-max"]
        rechargeMin <- map["recharge-min"]
        rule <- map["rule"]
        iapRule <- map["apple-IAP-rule"]
        chargeRule <- map["recharge-rule"]
        cashRule <- map["cash-rule"]
        cashMax <- map["cash-max"]
        cashMin <- map["cash-min"]
        cashType <- map["cash"]
        rechargeType <- map["recharge-type"]
    }

    func options() -> [String] {
        let optiongStrs = optiongs.components(separatedBy: ",")
        var clearStrs: [String] = []
        // 过滤调空格
        for optionStr in optiongStrs {
            let clearStr = optionStr.replacingAll(matching: " ", with: "")
            clearStrs.append(clearStr)
        }
        return clearStrs
    }
}
