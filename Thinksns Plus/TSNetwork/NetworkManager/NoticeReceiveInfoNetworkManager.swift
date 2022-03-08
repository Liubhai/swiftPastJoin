//
//  NoticeReceiveInfoNetworkManager.swift
//  ThinkSNS +
//
//  Created by lip on 2017/9/14.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  通知接收信息网络请求 (点赞/评论/待审核等)

import UIKit

class NoticeReceiveInfoNetworkManager {
    class func receiveLikeList(limit: Int = TSAppConfig.share.localInfo.limit, after: Int?, complete: @escaping ([ReceiveLikeModel]?, _ errorInfo: String?) -> Void) {
        var request = UserNetworkRequest().receiveLike
        request.urlPath = request.fullPathWith(replacers: [])
        var parameter: [String: Any] = ["limit": limit]
        if let after = after {
            parameter["after"] = after
        }
        request.parameter = parameter

        var models: [ReceiveLikeModel]?
        var errorInfo: String?
        let requestGroup = DispatchGroup()
        requestGroup.enter()
        RequestNetworkData.share.text(request: request) { (networkResult) in
            switch networkResult {
                case .error(let error):
                    if error == NetworkError.networkErrorFailing {
                    errorInfo = "提示信息_网络错误".localized
                } else {
                    errorInfo = "网络请求超时"
                }
            case .failure(let response):
                if let message = response.message {
                    errorInfo = message
                } else {
                    errorInfo = "提示信息_网络错误".localized
                }
            case .success(let response):
                models = response.models
            }
            requestGroup.leave()
        }

        requestGroup.notify(queue: DispatchQueue.main) {
            guard let receiveModels = models else {
                complete(nil, errorInfo)
                return
            }
            guard receiveModels.isEmpty == false else {
                complete([], nil)
                return
            }
            let userIds = receiveModels.map({ (temp) -> Int in
                return temp.userId
            })

            let filterIds = Array(Set(userIds))
            TSUserNetworkingManager().getUserInfo(filterIds, complete: { (_, userInfoModels, _) in
                guard let userInfoModels = userInfoModels else {
                    complete(nil, "提示信息_网络错误".localized)
                    return
                }
                let results = receiveModels.map({ (model) -> ReceiveLikeModel in
                    for user in userInfoModels {
                        if model.userId == user.userIdentity {
                            model.userInfo = user
                        }
                    }
                    return model
                })
                complete(results, nil)
            })
        }
    }

    class func receiveCommentList(limit: Int = TSAppConfig.share.localInfo.limit, after: Int?, complete: @escaping ([ReceiveCommentModel]?, _ errorInfo: String?) -> Void) {
        var request = UserNetworkRequest().receiveComment
        request.urlPath = request.fullPathWith(replacers: [])
        var parameter: [String: Any] = ["limit": limit]
        if let after = after {
            parameter["after"] = after
        }
        request.parameter = parameter

        var models: [ReceiveCommentModel]?
        var errorInfo: String?
        let requestGroup = DispatchGroup()
        requestGroup.enter()
        RequestNetworkData.share.text(request: request) { (networkResult) in
            switch networkResult {
            case .error(let error):
                if error == NetworkError.networkErrorFailing {
                    errorInfo = "提示信息_网络错误".localized
                } else {
                    errorInfo = "网络请求超时"
                }
            case .failure(let response):
                if let message = response.message {
                    errorInfo = message
                } else {
                    errorInfo = "提示信息_网络错误".localized
                }
            case .success(let response):
                models = response.models
            }
            requestGroup.leave()
        }

        requestGroup.notify(queue: DispatchQueue.main) {
            guard let receiveModels = models else {
                complete(nil, errorInfo)
                return
            }
            guard receiveModels.isEmpty == false else {
                complete([], nil)
                return
            }
            var userIds = receiveModels.map({ (temp) -> Int in
                return temp.userId
            })
            for model in receiveModels {
                if let replyUserId = model.replyUserId {
                    userIds.append(replyUserId)
                }
            }

            let filterIds = Array(Set(userIds))
            TSUserNetworkingManager().getUserInfo(filterIds, complete: { (_, userInfoModels, _) in
                guard let userInfoModels = userInfoModels else {
                    complete(nil, "提示信息_网络错误".localized)
                    return
                }
                var results = [ReceiveCommentModel]()
                for index in 0..<receiveModels.count {
                    let model = receiveModels[index]
                    for user in userInfoModels {
                        if model.replyUserId == user.userIdentity {
                            model.replyUser = user
                        }
                        if model.userId == user.userIdentity {
                            model.user = user
                        }
                    }
                    results.append(model)
                }
                complete(results, nil)
            })
        }
    }
    /*
     // 动态 feeds
     // 评论 comments
     // 资讯的评论 news
     // 圈子 groups（无at）
     // 帖子 groups-post
     // 问题的评论 questions
     // 回答的评论 question-answers
     // 话题 feed-topics
     */
    // MARK: - at我的
    class func receiveAtMeList(limit: Int = TSAppConfig.share.localInfo.limit, index: Int?, complete: @escaping ([ReceiveCommentModel]?, _ errorInfo: String?) -> Void) {
        NoticeReceiveInfoNetworkManager.requestAtMessageIDList(limit: limit, index: index) { (models, errorInfo) in
            /// 第一步：
            // 把messageIDModel分为动态和评论两大类
            if errorInfo == nil && models != nil {
                // 用于最后还原整个列表数据
                let origalModels = models
                var atMeFeeds: [TSAtMeListModel] = []
                var atMeComments: [TSAtMeListModel] = []
                var atMeCommentIDs: [Int] = []
                // 需要请求用户信息的全部ID
                var commentsUserIDs: [Int] = []
                // 请求的用户信息
                var commentsUserInfosDic: [Int : TSUserInfoModel] = [:]
                // 完善后的评论model ReceiveCommentModel(乱序)
                var completeModels: [ReceiveCommentModel] = []
                // 失败的信息，只有有接口报错就把错误信息付值给他
                var comleteErrorInfo: String = ""
                for atmeModel in models! {
                    if atmeModel.type == "feeds" {
                        atMeFeeds.append(atmeModel)
                    } else if atmeModel.type == "comments" {
                        atMeComments.append(atmeModel)
                        /// 这个地方的resourceID才是评论的ID
                        /// 这个ID是消息的ID，用于排序的
                        atMeCommentIDs.append(atmeModel.resourceID)
                    }
                }
                /// 第二步：
                // 先通过评论id去拿评论的信息，然后通过评论信息进行分类，然后非类型去拿父级信息，如动态，资讯等
                NoticeReceiveInfoNetworkManager.requestCommentsInfo(commentIDs: atMeCommentIDs, complete: { (models, errorInfo) in
                    // 动态
                    var feedCommnetInfos: [TSCommentsSimpelModel] = []
                    var feedCommnetFeedIDs: [Int] = []
                    // 资讯
                    var newsCommnetInfos: [TSCommentsSimpelModel] = []
                    var newsCommnetInfoIDs: [Int] = []
                    // 帖子
                    var postCommentInfos: [TSCommentsSimpelModel] = []
                    var postCommentPostIDs: [Int] = []
                    // 问题
                    var questionCommnetInfos: [TSCommentsSimpelModel] = []
                    var questionCommnetQuestionIDs: [Int] = []
                    // 回答
                    var answerCommentInfos: [TSCommentsSimpelModel] = []
                    var answerCommentAnswerIDs: [Int] = []

                    for model in models! {
                        if model.type == "feeds" {
                            feedCommnetInfos.append(model)
                            feedCommnetFeedIDs.append(model.sourceID)
                        } else if model.type == "news" {
                            newsCommnetInfos.append(model)
                            newsCommnetInfoIDs.append(model.sourceID)
                        } else if model.type == "groups-post" {
                            postCommentInfos.append(model)
                            postCommentPostIDs.append(model.sourceID)
                        } else if model.type == "questions" {
                            questionCommnetInfos.append(model)
                            questionCommnetQuestionIDs.append(model.sourceID)
                        } else if model.type == "question-answers" {
                            answerCommentInfos.append(model)
                            answerCommentAnswerIDs.append(model.sourceID)
                        }
                        commentsUserIDs.append(model.userId)
                    }
                    let group = DispatchGroup()
                    /// 单独请求
                    // 动态ID直接放到feedCommnetFeedIDs里边一起请求
                    for atMemodel in atMeFeeds {
                        feedCommnetFeedIDs.append(atMemodel.resourceID)
                    }

                    if feedCommnetFeedIDs.isEmpty == false {
                        group.enter()
                        NoticeReceiveInfoNetworkManager.requestFeedInfo(feedIDs: feedCommnetFeedIDs, complete: { (Infos, error) in
                            if error == nil {
                                var feedComments: [ReceiveCommentModel] = []
                                if let infos = Infos {
                                    for simpleCommentModel in feedCommnetInfos {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == simpleCommentModel.sourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = simpleCommentModel.id
                                                commentModel?.content = simpleCommentModel.body
                                                commentModel?.userId = simpleCommentModel.userId
                                                commentModel?.targetUserId = simpleCommentModel.targetUserID
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = simpleCommentModel.createDate
                                                commentModel?.sourceType = .feed
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.isVieo = false
                                                tempExten.content = info["feed_content"] as? String
                                                tempExten.targetId = simpleCommentModel.sourceID
                                                if info["images"] != nil {
                                                    let images = info["images"] as? Array<Dictionary<String, Any>>
                                                    if (images?.count)! > 0 {
                                                        tempExten.coverId = images?[0]["file"] as? Int
                                                    }
                                                }
                                                if let videoDic = info["video"] as? Dictionary<String, Any>, tempExten.coverId == nil {
                                                    // 先判断是否是图片动态，然后尝试读取视频封面图
                                                    tempExten.coverId = videoDic["cover_id"] as? Int
                                                    tempExten.isVieo = true
                                                }
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,ID已经在最外层拆分评论分组的时候处理了
                                                feedComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                    /// 遍历一下动态类型的消息
                                    /// 这是动态组装的一个评论model，没有回复内容，需要UI处理一下兼容
                                    /// 所以UI上显示的评论的人实际上是动态的人信息
                                    /// 评论的ID其实是没有的，所以也不要有快速回复的弹窗
                                    for atMeModel in atMeFeeds {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == atMeModel.resourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = atMeModel.id
                                                commentModel?.isAtContent = true
                                                commentModel?.content = ""
                                                commentModel?.userId = (info["user_id"] as! NSNumber) as! Int
                                                commentModel?.targetUserId = atMeModel.userId
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = atMeModel.createDate
                                                commentModel?.sourceType = .feed
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.targetId = atMeModel.resourceID
                                                tempExten.isVieo = false
                                                tempExten.content = info["feed_content"] as? String
                                                if let images = info["images"] as? Array<Dictionary<String, Any>> {
                                                    if images.count > 0 {
                                                        tempExten.coverId = images[0]["id"] as? Int
                                                    }
                                                }
                                                if let video = info["video"] as? Dictionary<String, Any> {
                                                    tempExten.coverId = video["cover_id"] as? Int
                                                    tempExten.isVieo = true
                                                }
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,用户ID就是该动态的用户信息
                                                commentsUserIDs.append((commentModel?.userId)!)
                                                feedComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                } else {
                                    // 没有返回数据，说明对应的评论无效
                                }
                                if feedComments.isEmpty == false {
                                    completeModels = completeModels + feedComments
                                }
                            } else {
                                comleteErrorInfo = error!
                            }
                            group.leave()
                        })
                    }
                    // MARK: - 资讯评论
                    if newsCommnetInfoIDs.isEmpty == false {
                        group.enter()
                        NoticeReceiveInfoNetworkManager.requestNewsInfo(IDs: newsCommnetInfoIDs, complete: { (Infos, error) in
                            if error == nil {
                                var newsComments: [ReceiveCommentModel] = []
                                if let infos = Infos {
                                    for simpleCommentModel in newsCommnetInfos {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == simpleCommentModel.sourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = simpleCommentModel.id
                                                commentModel?.content = simpleCommentModel.body
                                                commentModel?.userId = simpleCommentModel.userId
                                                commentModel?.targetUserId = simpleCommentModel.targetUserID
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = simpleCommentModel.createDate
                                                commentModel?.sourceType = .news
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.content = info["title"] as? String
                                                tempExten.targetId = simpleCommentModel.sourceID
                                                if info["images"] != nil {
                                                    let images = info["images"] as? Dictionary<String, Any>
                                                    if images != nil {
                                                        tempExten.coverId = images?["id"] as? Int
                                                    }
                                                }
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,ID已经在最外层拆分评论分组的时候处理了
                                                newsComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                } else {
                                    // 没有返回数据
                                }
                                if newsComments.isEmpty == false {
                                    completeModels = completeModels + newsComments
                                }
                            } else {
                                comleteErrorInfo = error!
                            }
                            group.leave()
                        })
                    }
                    // MARK: 帖子评论
                    if postCommentPostIDs.isEmpty == false {
                        group.enter()
                        NoticeReceiveInfoNetworkManager.requestPostInfo(IDs: postCommentPostIDs, complete: { (Infos, error) in
                            if error == nil {
                                var postComments: [ReceiveCommentModel] = []
                                if let infos = Infos {
                                    for simpleCommentModel in postCommentInfos {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == simpleCommentModel.sourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = simpleCommentModel.id
                                                commentModel?.content = simpleCommentModel.body
                                                commentModel?.userId = simpleCommentModel.userId
                                                commentModel?.targetUserId = simpleCommentModel.targetUserID
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = simpleCommentModel.createDate
                                                commentModel?.sourceType = .group
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.content = info["title"] as? String
                                                tempExten.targetId = simpleCommentModel.sourceID
                                                if info["images"] != nil {
                                                    let images = info["images"] as? Array<Dictionary<String, Any>>
                                                    if (images?.count)! > 0 {
                                                        tempExten.coverId = images?[0]["id"] as? Int
                                                    }
                                                }
                                                tempExten.groupId = info["group_id"] as? Int
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,ID已经在最外层拆分评论分组的时候处理了
                                                postComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                } else {
                                    // 没有返回数据
                                }
                                if postComments.isEmpty == false {
                                    completeModels = completeModels + postComments
                                }
                            } else {
                                comleteErrorInfo = error!
                            }
                            group.leave()
                        })
                    }
                    // MARK: - 问题评论
                    if questionCommnetQuestionIDs.isEmpty == false {
                        group.enter()
                        NoticeReceiveInfoNetworkManager.requestQuestionInfo(IDs: questionCommnetQuestionIDs, complete: { (Infos, error) in
                            if error == nil {
                                var questionComments: [ReceiveCommentModel] = []
                                if let infos = Infos {
                                    for simpleCommentModel in questionCommnetInfos {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == simpleCommentModel.sourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = simpleCommentModel.id
                                                commentModel?.content = simpleCommentModel.body
                                                commentModel?.userId = simpleCommentModel.userId
                                                commentModel?.targetUserId = simpleCommentModel.targetUserID
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = simpleCommentModel.createDate
                                                commentModel?.sourceType = .question
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.targetId = simpleCommentModel.sourceID
                                                let content = info["subject"] as? String
                                                tempExten.content = content
                                                tempExten.coverId = content?.ts_getCustomMarkdownImageId().first
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,ID已经在最外层拆分评论分组的时候处理了
                                                questionComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                } else {
                                    // 没有返回数据
                                }
                                if questionComments.isEmpty == false {
                                    completeModels = completeModels + questionComments
                                }
                            } else {
                                comleteErrorInfo = error!
                            }
                            group.leave()
                        })
                    }
                    // MARK: - 回答评论
                    if answerCommentAnswerIDs.isEmpty == false {
                        group.enter()
                        NoticeReceiveInfoNetworkManager.requestAnswerInfo(IDs: answerCommentAnswerIDs, complete: { (Infos, error) in
                            if error == nil {
                                var answerComments: [ReceiveCommentModel] = []
                                if let infos = Infos {
                                    for simpleCommentModel in answerCommentInfos {
                                        for info in infos {
                                            if Int(info["id"] as! NSNumber) == simpleCommentModel.sourceID {
                                                let commentModel = ReceiveCommentModel(JSON: [:])
                                                commentModel?.id = simpleCommentModel.id
                                                commentModel?.content = simpleCommentModel.body
                                                commentModel?.userId = simpleCommentModel.userId
                                                commentModel?.targetUserId = simpleCommentModel.targetUserID
                                                commentModel?.replyUserId = 0
                                                commentModel?.createDate = simpleCommentModel.createDate
                                                commentModel?.sourceType = .answers
                                                let tempExten = ReceiveExtenModel()
                                                tempExten.targetId = simpleCommentModel.sourceID
                                                let question = info["question"] as? Dictionary<String, Any>
                                                let content = question!["subject"] as? String
                                                tempExten.coverId = content?.ts_getCustomMarkdownImageId().first
                                                tempExten.content = content?.ts_customMarkdownToNormal()
                                                commentModel?.exten = tempExten
                                                // 发评论用户的信息最后再统一更新,ID已经在最外层拆分评论分组的时候处理了
                                                answerComments.append(commentModel!)
                                                continue
                                            }
                                        }
                                    }
                                } else {
                                    // 没有返回数据
                                }
                                if answerComments.isEmpty == false {
                                    completeModels = completeModels + answerComments
                                }
                            } else {
                                comleteErrorInfo = error!
                            }
                            group.leave()
                        })
                    }
                    /// 所有都请求完毕
                    group.notify(queue: .main) { _ in
                        /// 最后请求一遍用户信息，更新到model里边去
                        NoticeReceiveInfoNetworkManager.requestUserInfo(userIds: commentsUserIDs, complete: { (userInfos, error) in
                            if error != nil {
                                complete(nil, error)
                                return
                            }
                            // 把数组转换为字典
                            for userInfo in userInfos! {
                                commentsUserInfosDic[userInfo.userIdentity] = userInfo
                            }
                            // 需要先判断一下是否有请求失败的，如果有一个失败了，就提示错误
                            if comleteErrorInfo.isEmpty == true {
                                var enAbleComments: [ReceiveCommentModel] = []
                                for commentModel in completeModels {
                                    let userInfo = commentsUserInfosDic[commentModel.userId]
                                    if userInfo != nil {
                                        commentModel.user = userInfo
                                        enAbleComments.append(commentModel)
                                    }
                                }
                                /// 恢复消息的排序
                                var commentsLists: [ReceiveCommentModel] = []
                                for atModel in origalModels! {
                                    for enAbleComment in enAbleComments {
                                        /// 如果是feed类型的也是当作评论处理，所以ID也是评论ID
                                        if atModel.type == "comments" {
                                            if atModel.resourceID == enAbleComment.id {
                                                enAbleComment.atMessageID = atModel.id
                                                commentsLists.append(enAbleComment)
                                                continue
                                            }
                                        } else {
                                            if atModel.id == enAbleComment.id {
                                                enAbleComment.atMessageID = atModel.id
                                                commentsLists.append(enAbleComment)
                                                continue
                                            }
                                        }
                                    }
                                }
                                complete(commentsLists, nil)
                            } else {
                                complete(nil, comleteErrorInfo)
                            }
                        })
                    }
                })
            }
        }
    }
    /// 获取消息ID列表
    fileprivate class func requestAtMessageIDList(limit: Int = TSAppConfig.share.localInfo.limit, index: Int?, complete: @escaping ([TSAtMeListModel]?, _ errorInfo: String?) -> Void) {
        var requst = Request<TSAtMeListModel>(method: .get, path: TSURLPathV2.Message.atMeIDList.rawValue, replacers: [])
        requst.urlPath = requst.fullPathWith(replacers: [])

        var parameter: [String: Any] = ["limit": limit]
        if let index = index {
            parameter["index"] = index
        }
        requst.parameter = parameter
        var models: [TSAtMeListModel]?
        var errorInfo: String?
        RequestNetworkData.share.text(request: requst) { (networkResult) in
            switch networkResult {
            case .error(let error):
                if error == NetworkError.networkErrorFailing {
                    errorInfo = "提示信息_网络错误".localized
                } else {
                    errorInfo = "网络请求超时"
                }
            case .failure(let response):
                if let message = response.message {
                    errorInfo = message
                } else {
                    errorInfo = "提示信息_网络错误".localized
                }
            case .success(let response):
                models = response.models
            }
            complete(models, errorInfo)
        }
    }
    /// 获取评论的信息
    fileprivate class func requestCommentsInfo(commentIDs: [Int], complete: @escaping ([TSCommentsSimpelModel]?, _ errorInfo: String?) -> Void) {
        var requst = Request<TSCommentsSimpelModel>(method: .get, path: "comments", replacers: [])
        requst.urlPath = requst.fullPathWith(replacers: [])

        var parameter: [String: Any] = [:]
        var commentIDStr = ""
        for commentID in commentIDs {
            commentIDStr = commentIDStr.isEmpty ? String(commentID) : commentIDStr + "," +  String(commentID)
        }
        parameter["id"] = commentIDStr
        requst.parameter = parameter
        var models: [TSCommentsSimpelModel]?
        var errorInfo: String?
        RequestNetworkData.share.text(request: requst) { (networkResult) in
            switch networkResult {
            case .error(let error):
                if error == NetworkError.networkErrorFailing {
                    errorInfo = "提示信息_网络错误".localized
                } else {
                    errorInfo = "网络请求超时"
                }
            case .failure(let response):
                if let message = response.message {
                    errorInfo = message
                } else {
                    errorInfo = "提示信息_网络错误".localized
                }
            case .success(let response):
                models = response.models
            }
            complete(models, errorInfo)
        }
    }
    /// 获取动态信息
    fileprivate class func requestFeedInfo(feedIDs: [Int], complete: @escaping ([[String: Any]]?, _ errorInfo: String?) -> Void) {
        let requestPath = TSURLPathV2.path.rawValue + "feeds"
        var parameter: [String: Any] = [:]
        var feedIdStr = ""
        for feedIs in feedIDs {
            feedIdStr = feedIdStr.isEmpty ? String(feedIs) : feedIdStr + "," +  String(feedIs)
        }
        parameter["id"] = feedIdStr
        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
            // 请求失败
            guard result else {
                complete([], nil)
                return
            }
            // 服务器数据异常
            guard let datas = networkResponse as? [String: Any] else {
                complete([], nil)
                return
            }
            complete(datas["feeds"] as! [[String : Any]], nil)
        })
    }
    /// 帖子详情
    fileprivate class func requestPostInfo(IDs: [Int], complete: @escaping ([[String: Any]]?, _ errorInfo: String?) -> Void) {
        let requestPath = TSURLPathV2.path.rawValue + "group/simple-posts"
        var parameter: [String: Any] = [:]
        var idStr = ""
        for idInt in IDs {
            idStr = idStr.isEmpty ? String(idInt) : idStr + "," +  String(idInt)
        }
        parameter["id"] = idStr
        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
            // 请求失败
            guard result else {
                complete([], nil)
                return
            }
            // 服务器数据异常
            guard let datas = networkResponse as? [[String : Any]] else {
                complete([], nil)
                return
            }
            complete(datas, nil)
        })
    }
    /// 资讯信息
    fileprivate class func requestNewsInfo(IDs: [Int], complete: @escaping ([[String: Any]]?, _ errorInfo: String?) -> Void) {
        let requestPath = TSURLPathV2.path.rawValue + "news"
        var parameter: [String: Any] = [:]
        var idStr = ""
        for idInt in IDs {
            idStr = idStr.isEmpty ? String(idInt) : idStr + "," +  String(idInt)
        }
        parameter["id"] = idStr
        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
            // 请求失败
            guard result else {
                complete([], nil)
                return
            }
            // 服务器数据异常
            guard let datas = networkResponse as? [[String : Any]] else {
                complete([], nil)
                return
            }
            complete(datas, nil)
        })
    }
    /// 问题信息
    fileprivate class func requestQuestionInfo(IDs: [Int], complete: @escaping ([[String: Any]]?, _ errorInfo: String?) -> Void) {
        let requestPath = TSURLPathV2.path.rawValue + "questions"
        var parameter: [String: Any] = [:]
        var idStr = ""
        for idInt in IDs {
            idStr = idStr.isEmpty ? String(idInt) : idStr + "," +  String(idInt)
        }
        parameter["id"] = idStr
        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
            // 请求失败
            guard result else {
                complete([], nil)
                return
            }
            // 服务器数据异常
            guard let datas = networkResponse as? [[String : Any]] else {
                complete([], nil)
                return
            }
            complete(datas, nil)
        })
    }
    /// 回答信息
    fileprivate class func requestAnswerInfo(IDs: [Int], complete: @escaping ([[String: Any]]?, _ errorInfo: String?) -> Void) {
        let requestPath = TSURLPathV2.path.rawValue + "qa/reposted-answers"
        var parameter: [String: Any] = [:]
        var idStr = ""
        for idInt in IDs {
            idStr = idStr.isEmpty ? String(idInt) : idStr + "," +  String(idInt)
        }
        parameter["id"] = idStr
        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
            // 请求失败
            guard result else {
                complete([], nil)
                return
            }
            // 服务器数据异常
            guard let datas = networkResponse as? [[String : Any]] else {
                complete([], nil)
                return
            }
            complete(datas, nil)
        })
    }
    /// 请求用户信息
    fileprivate class func requestUserInfo(userIds: [Int], complete: @escaping ([TSUserInfoModel]?, _ errorInfo: String?) -> Void) {
        TSTaskQueueTool.getAndSave(userIds: userIds) { (users, msg, status) in
            guard let users = users else {
                complete(nil, msg)
                return
            }
            complete(users, nil)
        }
    }
    //        let requestPath = TSURLPathV2.path.rawValue + TSURLPathV2.Message.atMeIDList.rawValue
    //        var parameter: [String: Any] = ["limit": limit]
    //        if let after = after {
    //            parameter["after"] = after
    //        }
    //        try! RequestNetworkData.share.textRequest(method: .get, path: requestPath, parameter: parameter, complete: { (networkResponse, result) in
    //            // 请求失败
    //            guard result else {
    //                //let message = TSCommonNetworkManager.getNetworkSuccessMessage(with: networkResponse)
    //                complete(nil, nil)
    //                return
    //            }
    //            // 服务器数据异常
    //            guard let datas = networkResponse as? [[String: Any]] else {
    //                complete(nil, nil)
    //                return
    //            }
    //            /// 解析数据
    //        })
}
