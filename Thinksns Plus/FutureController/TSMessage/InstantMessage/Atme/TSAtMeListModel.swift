//
//  TSAtMeListModel.swift
//  ThinkSNSPlus
//
//  Created by IMAC on 2018/8/27.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit
import ObjectMapper

class TSAtMeListModel: Mappable {
    /// 评论ID
    var id: Int!
    /// 用户ID
    var userId: Int!
    /// 类型
    var type: String!
    var resourceID: Int!
    var createDate: Date!

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        id <- map["id"]
        userId <- map["user_id"]
        type <- map["resourceable.type"]
        resourceID <- map["resourceable.id"]
        createDate <- (map["created_at"], TSDateTransfrom())
    }
}
