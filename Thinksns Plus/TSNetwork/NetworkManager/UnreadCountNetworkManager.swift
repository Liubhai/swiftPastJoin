//
//  UnreadCountNetworkManager.swift
//  ThinkSNS +
//
//  Created by lip on 2017/9/8.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  未读数网络请求管理
// 现在由两个接口完成: unread-count获取具体的列表数据 counts获取未读数量

import UIKit

class UnreadCountNetworkManager {
    static let share = UnreadCountNetworkManager()

    var responseNotices: UnreadDetailInfoModel? {
        didSet {
            /// [长期注释]
            /// 后端提供了一个新的接口来更新红点数量
            unreadCountVer2 { (model) in
                self.processNotice()
            }
        }
    }

    func unreadCount(complete: @escaping ((_: Bool) -> Void)) {
        if TSCurrentUserInfo.share.isLogin == false {
            complete(false)
            return
        }
        /// 后端提供了一个新的接口来更新红点数量
        unreadCountVer2 { (model) in

        }
        /// 获取具体的未读消息内容
        var request = NoticeNetworkRequest().unreadDetailInfo
        request.urlPath = request.fullPathWith(replacers: [])

        RequestNetworkData.share.text(request: request) { [weak self] (networkResult) in
            switch networkResult {
            case .error(_), .failure(_):
                complete(false)
                break
            case .success(let response):
                self?.responseNotices = response.model
                complete(true)
            }
        }
    }

    func processNotice() {
        guard let notices = responseNotices else {
            return
        }
        // 给信息分类
        if !notices.likesUsers.isEmpty {
            var likeUsers = ""
            let count = notices.likesUsers.count > 3 ? 3 : notices.likesUsers.count
            for user in notices.likesUsers[0..<count] {
                likeUsers = likeUsers + user.user.name + "、"
            }
            likeUsers.remove(at: likeUsers.index(before: likeUsers.endIndex))
            if notices.likesUsers.count <= 1 {
                likeUsers += "赞了我"
            } else {
                likeUsers += "等人赞了我"
            }
            TSCurrentUserInfo.share.unreadCount.likedUsers = likeUsers
            if let time = notices.likesUsers.first?.time {
                TSCurrentUserInfo.share.unreadCount.likeUsersDate = time
            }
        } else {
            TSCurrentUserInfo.share.unreadCount.likedUsers = nil
            TSCurrentUserInfo.share.unreadCount.likeUsersDate = nil
        }

        if !notices.commentsUsers.isEmpty {
            var commentsUser = ""
            let count = notices.commentsUsers.count > 2 ? 2 : notices.commentsUsers.count
            for user in notices.commentsUsers[0..<count] {
                commentsUser = commentsUser + user.user.name + "、"
            }
            commentsUser = commentsUser.substring(to: commentsUser.index(before: commentsUser.endIndex))
            if notices.commentsUsers.count <= 1 {
                commentsUser += "评论了我"
            } else {
                commentsUser += "等人评论了我"
            }
            TSCurrentUserInfo.share.unreadCount.commentsUsers = commentsUser
            if let time = notices.commentsUsers.first?.time {
                TSCurrentUserInfo.share.unreadCount.commentsUsersDate = time
            }
        } else {
            TSCurrentUserInfo.share.unreadCount.commentsUsers = nil
            TSCurrentUserInfo.share.unreadCount.commentsUsersDate = nil
        }
        /// [长期注释]
        /// 由于后端提供了一个新的接口来更新红点数量，所以这个地方不再更新红点数量
        /// 审核通知一栏的数量以ver2为准
        TSCurrentUserInfo.share.unreadCount.systemInfo = notices.systemInfo?.content
        TSCurrentUserInfo.share.unreadCount.systemTime = notices.systemInfo?.time
        if TSCurrentUserInfo.share.unreadCount.allPinned <= 0 {
            TSCurrentUserInfo.share.unreadCount.pendingUsers = "显示_审核通知占位字".localized
            TSCurrentUserInfo.share.unreadCount.pendingUsersDate = nil
        } else {
            TSCurrentUserInfo.share.unreadCount.pendingUsers = "显示_审核通知有未处理提示文字".localized
            TSCurrentUserInfo.share.unreadCount.pendingUsersDate = notices.pinnedsDate
        }
        /// at我的
        if notices.atUsers?.userNames.isEmpty == false {
            var atUser = ""
            let count = (notices.atUsers?.userNames.count)! > 2 ? 2 : (notices.atUsers?.userNames.count)!
            for userName in (notices.atUsers?.userNames[0..<count])! {
                atUser = atUser + userName + "、"
            }
            atUser = atUser.substring(to: atUser.index(before: atUser.endIndex))
            if notices.commentsUsers.count <= 1 {
                atUser += "@了我"
            } else {
                atUser += "等人@了我"
            }
            TSCurrentUserInfo.share.unreadCount.atUsers = atUser
            if let time = notices.atUsers?.time {
                TSCurrentUserInfo.share.unreadCount.atUsersDate = time
            }
        } else {
            TSCurrentUserInfo.share.unreadCount.atUsers = ""
            TSCurrentUserInfo.share.unreadCount.atUsersDate = nil
        }
    }
    // MARK: - 新的未读的数量
    func unreadCountVer2(complete: @escaping (_ model: UserCounts) -> Void) {
        var request = UserNetworkRequest().counts
        request.urlPath = request.fullPathWith(replacers: [])
        RequestNetworkData.share.text(request: request) {(result) in
            switch result {
            case .success(let response):
                if let model = response.model {
                    // 更新一下消息的红点
                    TSCurrentUserInfo.share.unreadCount.system = model.system
                    TSCurrentUserInfo.share.unreadCount.like = model.liked
                    TSCurrentUserInfo.share.unreadCount.comments = model.commented
                    TSCurrentUserInfo.share.unreadCount.pending = model.pinned
                    // 更新单独的未审核数量
                    TSCurrentUserInfo.share.unreadCount.newsCommentPinned = model.newsCommentPinned
                    TSCurrentUserInfo.share.unreadCount.feedCommentPinned = model.feedCommentPinned
                    TSCurrentUserInfo.share.unreadCount.groupJoinPinned = model.groupJoinPinned
                    TSCurrentUserInfo.share.unreadCount.postPinned = model.postPinned
                    TSCurrentUserInfo.share.unreadCount.postCommentPinned = model.postCommentPinned
                    TSCurrentUserInfo.share.unreadCount.at = model.at
                    TSCurrentUserInfo.share.unreadCount.mutual = model.mutual
                    TSCurrentUserInfo.share.unreadCount.follows = model.following
                    TSCurrentUserInfo.share.unreadCount.isHiddenNoticeBadge = TSCurrentUserInfo.share.unreadCount.onlyNoticeUnreadCount() <= 0
                    self.unploadTabbarBadge()
                    complete(response.model!)
                }
            case .failure(_), .error(_):
                break
            }
        }
    }
    // MARK: - 更新tabbar的红点状态
    func unploadTabbarBadge() {
        // 更新tabbar红点状态
        if let currentTC = TSRootViewController.share.currentShowViewcontroller as? TSHomeTabBarController {
            let tabBar = currentTC.customTabBar
            let tsUnred = TSCurrentUserInfo.share.unreadCount
            // 消息
            if (tsUnred.system + tsUnred.like + tsUnred.comments + tsUnred.pending + tsUnred.imMessage + tsUnred.at) > 0 {
                tabBar.showBadge(.message)
            } else {
                tabBar.hiddenBadge(.message)
            }
            // 个人中心
            if (tsUnred.follows + tsUnred.mutual) > 0 {
                tabBar.showBadge(.myCenter)
            } else {
                tabBar.hiddenBadge(.myCenter)
            }
            JPUSHService.setBadge(tsUnred.allNoticeUnreadCount() + tsUnred.imMessage)
            // 更新桌面applicationIconBadgeNumber
            UIApplication.shared.applicationIconBadgeNumber = tsUnred.allNoticeUnreadCount() + tsUnred.imMessage
        }
    }
}
