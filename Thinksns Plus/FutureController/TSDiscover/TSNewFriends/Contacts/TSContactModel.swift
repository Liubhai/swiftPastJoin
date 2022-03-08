//
//  TSContactModel.swift
//  ThinkSNS +
//
//  Created by GorCat on 2017/8/17.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//

import UIKit
import Contacts

struct TSContactModel {

    /// 姓名
    var name: String
    /// 电话
    var phone: String
    /// 头像
    var avatar: UIImage?

    init?(contact: CNContact) {
        let nameInfo = contact.familyName + contact.middleName + contact.givenName
        let phoneInfo = contact.phoneNumbers.last?.value.stringValue
        guard let phoneNumber = TSContactModel.filter(phone: phoneInfo), nameInfo != "" else {
            return nil
        }
        name = nameInfo
        phone = phoneNumber
        if let imageData = contact.imageData {
            avatar = UIImage(data: imageData)
        }
    }

    /// 过滤手机号的格式
    static func filter(phone: String?) -> String? {
        guard var phone = phone else {
            return nil
        }
        guard phone != TSCurrentUserInfo.share.userInfo?.phone else {
            return nil
        }
        // 1.去掉手机号中的 “-”
        phone = phone.replacingOccurrences(of: "-", with: "")
        // 2.去掉小于 11 位的号码
        if phone.count < 11 {
            return nil
        }
        // 3.如果手机号满 11 位，为过滤 +86 等前缀，截取最后 11 位
        phone = phone.substring(from: phone.index(phone.endIndex, offsetBy: -11))
        return TSAccountRegex.isPhoneNnumberFormat(phone) ? phone : nil
    }
}
