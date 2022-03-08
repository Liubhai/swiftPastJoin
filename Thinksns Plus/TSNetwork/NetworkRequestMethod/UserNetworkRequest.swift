//
//  UserNetworkRequest.swift
//  ThinkSNS +
//
//  Created by lip on 2017/8/28.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  用户相关网络请求

import UIKit
import ObjectMapper

struct UserNetworkRequest {
    // MARK: - 赞
    /// 意见反馈
    ///
    /// - RouteParameter: None
    /// - RequestParameter:
    ///    - content: string. 反馈内容
    ///    - system_mark: Int. 移动端标记，非必填 ，格式为uid+毫秒时间戳
    let ideaFeedback = Request<Empty>(method: .post, path: "user/feedback", replacers: [])

    /// 用户收到的评论
    ///
    /// - RouteParameter: None
    /// - RequestParameter:
    ///    - limit: 整数.获取的条数，默认 20。
    ///    - after: 整数.传递上次获取的最后一条 id
    let receiveComment = Request<ReceiveCommentModel>(method: .get, path: "user/comments", replacers: [])
    /// 用户收到的喜欢
    ///
    /// - RouteParameter: None
    /// - RequestParameter:
    ///    - limit: 整数.获取的条数，默认 20。
    ///    - after: 整数.传递上次获取的最后一条 id
    let receiveLike = Request<ReceiveLikeModel>(method: .get, path: "user/likes", replacers: [])
    /// 收到的at
    let receiveAt = Request<ReceiveCommentModel>(method: .get, path: "user/comments", replacers: [])
    /// 关注指定用户
    static let follow = Request<Empty>(method: .put, path: "user/followings/:user", replacers: [":user"])
    /// 取消关注指定用户
    static let unfollow = Request<Empty>(method: .delete, path: "user/followings/:user", replacers: [":user"])

    /// 修改用户认证
    static let updateVerified = Request<Empty>(method: .patch, path: "user/certification", replacers: [])
    /// 获取一个用户的标签
    let userTags = Request<TSTagModel>(method: .get, path: "users/:user/tags", replacers: [":user"])
    // MARK: - 黑名单
    let addBlackList = Request<Empty>(method: .post, path: "user/black/{target}", replacers: ["{target}"])
    let deleteBlackList = Request<Empty>(method: .delete, path: "user/black/{target}", replacers: ["{target}"])
    let blackList = Request<TSUserInfoModel>(method: .get, path: "user/blacks", replacers: [])
    // MARK: 新增数据
    let counts = Request<UserCounts>(method: .get, path: "user/counts", replacers: [])
    /// 已读的数据使用 ["type": 已读数据] 传递
    let readCounts = Request<Empty>(method: .patch, path: "user/counts", replacers: [])
}

struct UserCounts: Mappable {
    /// 新增粉丝数
    var following: Int = 0
    /// 新增好友数量
    var mutual: Int = 0
    /// 新增赞数量
    var liked: Int = 0
    /// 新增评论数量
    var commented: Int = 0
    /// 新增系统消息数量
    var system: Int = 0
    /// 新增审核数量 该数量由多个字段合计
    var pinned: Int = 0
    /// 资讯评论审核
    var newsCommentPinned: Int = 0
    /// 动态评论审核
    var feedCommentPinned: Int = 0
    /// 圈子加入申请
    var groupJoinPinned: Int = 0
    /// 发布评论审核
    var postCommentPinned: Int = 0
    /// 帖子申请置顶审核
    var postPinned: Int = 0
    /// At我的
    var at: Int = 0

    init?(map: Map) { }

    mutating func mapping(map: Map) {
        following <- map["user.following"]
        mutual <- map["user.mutual"]
        liked <- map["user.liked"]
        commented <- map["user.commented"]
        system <- map["user.system"]
        newsCommentPinned <- map["user.news-comment-pinned"]
        feedCommentPinned <- map["user.feed-comment-pinned"]
        groupJoinPinned <- map["user.group-join-pinned"]
        postCommentPinned <- map["user.post-comment-pinned"]
        postPinned <- map["user.post-pinned"]
        at <- map["user.at"]
        /// 所有审核小分类的合计
        pinned = newsCommentPinned + feedCommentPinned + groupJoinPinned + postCommentPinned + postPinned
    }
}
