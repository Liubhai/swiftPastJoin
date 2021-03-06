//
//  TopicListModel.swift
//  ThinkSNSPlus
//
//  Created by IMAC on 2018/7/24.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit
import SwiftyJSON
import ObjectMapper

/// 话题列表 话题model
class TopicListModel: Mappable {
    var topicId: Int = 0
    var topicTitle: String = ""
    var topicLogo: TSNetFileModel?

    required init?(map: Map) {

    }

    func mapping(map: Map) {
        topicId <- map["id"]
        topicTitle <- map["name"]
        topicLogo <- map["logo"]
    }

    init(object: TopicListObject) {
        self.topicId = object.topicId
        self.topicTitle = object.topicTitle
        if nil != object.topicLogo {
            self.topicLogo = TSNetFileModel(object: object.topicLogo!)
        }
    }

    func object() -> TopicListObject {
        let object = TopicListObject()
        object.topicId = self.topicId
        object.topicTitle = self.topicTitle
        object.topicLogo = self.topicLogo?.object()
        return object
    }
}
