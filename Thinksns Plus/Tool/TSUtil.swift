//
//  TSUtil.swift
//  ThinkSNS +
//
//  Created by 小唐 on 18/08/2017.
//  Copyright © 2017 ZhiYiCX. All rights reserved.
//
//  工程通用工具类

import Foundation
import UIKit

class TSUtil {
    private static let shareUtil = TSUtil()
    /// 支付需要输入密码的弹窗
    var pyVC: PayPasswordVC?
    /// 输入的支付密码
    var inputCode: String?

    /// 状态栏高度保存
    var statusHeight: CGFloat?

    class func share() -> TSUtil {
        return shareUtil
    }

    /// URL内部跳转正则匹配
    // 动态
    let AdvertDynamicRege = TSAppConfig.share.rootServerAddress + ".*?" + "feeds/(\\d+)"
    // 资讯
    private let AdvertInfoRege = TSAppConfig.share.rootServerAddress + ".*?" + "news/(\\d+)"
    // 圈子
    private let AdvertCircleRege = TSAppConfig.share.rootServerAddress + ".*?" + "groups/(\\d+)$"
    // 帖子
    private let AdvertPostRege = TSAppConfig.share.rootServerAddress + ".*?" + "groups/(\\d+)/posts/(\\d+)"
    // 问题
    private let AdvertQuestionRege = TSAppConfig.share.rootServerAddress + ".*?" + "questions/(\\d+)"
    // 问题话题
    private let AdvertQuestionTopicRege = TSAppConfig.share.rootServerAddress + ".*?" + "question-topics/(\\d+)"
    // 回答
    private let AdvertAnswerRege = TSAppConfig.share.rootServerAddress + ".*?" + "question-answers/(\\d+)"
    // 话题(动态)
    private let AdvertTopicRege = TSAppConfig.share.rootServerAddress + ".*?" + "topic/(\\d+)"

    // 带确定按钮的提示框
    public class func showAlert(title: String?, message: String?, showVC: UIViewController? = nil, clickAction: (() -> Void)?) -> Void {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let doneAction = UIAlertAction(title: "确定", style: UIAlertActionStyle.default) { (_) in
            clickAction?()
        }
        alertVC.addAction(doneAction)
        if nil == showVC {
            let rootVC = UIApplication.topViewController()
            rootVC?.present(alertVC, animated: true, completion: nil)
        } else {
            showVC?.present(alertVC, animated: true, completion: nil)
        }
    }

    //MARK - 过滤emoji
    public class func filterEmoji(str: String) -> String {
        let regex = try!NSRegularExpression(pattern: "[^\\u0020-\\u007E\\u00A0-\\u00BE\\u2E80-\\uA4CF\\uF900-\\uFAFF\\uFE30-\\uFE4F\\uFF00-\\uFFEF\\u0080-\\u009F\\u2000-\\u201f\\u1D000-\\u1F9DE\r\n]", options: .caseInsensitive)

        let modifiedString = regex.stringByReplacingMatches(in: str, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: str.count), withTemplate: "")

        return modifiedString
    }

   class func compressImageData(imageData: Data, maxSizeKB: CGFloat) -> Data {
        var resizeRate = 0.99
        let orignalImage = UIImage(data: imageData)
        var sizeOriginKB: CGFloat = CGFloat(imageData.count) / 1_024.0
        var comImageData: Data = imageData
        var count: Int = 0
        while sizeOriginKB > maxSizeKB && resizeRate > 0.01 {
            comImageData = UIImageJPEGRepresentation(orignalImage!, CGFloat(resizeRate))!
            sizeOriginKB = CGFloat(comImageData.count) / 1_024.0
            resizeRate -= 0.05
            count += 1
        }
        return comImageData
    }

    class func heightOfAttributeString(contentWidth: CGFloat, attributeString: NSAttributedString, font: UIFont, paragraphstyle: NSMutableParagraphStyle) -> CGFloat {
        let attributes = [NSFontAttributeName: font, NSParagraphStyleAttributeName: paragraphstyle.copy()]
        let att: NSString = NSString(string: attributeString.string)
        let rectToFit1 = att.boundingRect(with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: attributes, context: nil)
        if attributeString.length == 0 {
            return 0
        }
        return rectToFit1.size.height
    }

    class func heightOfLines(line: Int, font: UIFont) -> CGFloat {
        if line <= 0 {
            return 0
        }

        var mutStr = "*"
        for _ in 0 ..< line - 1 {
            mutStr = mutStr + "\n*"
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 3
        paragraphStyle.headIndent = 0.000_1
        paragraphStyle.tailIndent = -0.000_1
        let attribute = [NSFontAttributeName: UIFont.systemFont(ofSize: 15), NSParagraphStyleAttributeName: paragraphStyle.copy(), NSStrokeColorAttributeName: UIColor.black]
        let tSize = mutStr.size(attributes: attribute)
        return tSize.height
    }
    /// 根据视频名称获取发布视频动态的完整路径
    class func getWholeFilePath(name: String) -> String {
        // 完整的视频路径为：沙盒/tmp/videoFeedFiles/uid
        var videoFeedPath = ""
        if let uid = TSCurrentUserInfo.share.userInfo?.userIdentity {
            videoFeedPath = NSHomeDirectory() + "/tmp/" + "videoFeedFiles/" + "\(uid)/" + name
        } else {
            videoFeedPath = NSHomeDirectory() + "/tmp/" + "videoFeedFiles/" + name
        }
        return videoFeedPath
    }
    /// 找到所以输入的at
    class func findAllInputAt(inputStr: String) -> Array<NSTextCheckingResult> {
        let regx = try? NSRegularExpression(pattern: "@[\\u4e00-\\u9fa5\\w\\-\\_]+ ", options: NSRegularExpression.Options.caseInsensitive)
        return regx!.matches(in: inputStr, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: inputStr.endIndex.encodedOffset))
    }
    /// 找到所有TS的at
    class func findAllTSAt(inputStr: String) -> Array<NSTextCheckingResult> {
        let regx = try? NSRegularExpression(pattern: "\\u00ad(?:@[^/]+?)\\u00ad", options: NSRegularExpression.Options.caseInsensitive)
        return regx!.matches(in: inputStr, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: inputStr.endIndex.encodedOffset))
    }
    /// 替换手动输入的at
    class func replaceEditAtString(inputStr: String) -> String {
        /// 匹配手动输入at的正则
        let inputAtRege = "(?<!\\u00ad)@[^./\\s\\u00ad@]+"
        /// TS+规则的正则
        let tsAtRege = "\\u00ad(?:@[^/]+?)\\u00ad"
        /// 替换TS+ at规则的正则
        let replaceStr = "∫∂THINKSNS∂∫"
        /// TS+ at规则的分割符号
        let spStr = String(data: ("\u{00ad}".data(using: String.Encoding.unicode))!, encoding: String.Encoding.unicode)!
        var comperFromIndex: Int = 0
        /// 把TS+定制的at内容（包含特殊字符）保存到容器
        var tsAts: [String] = []
        /// TS+定制规则的at内容替换为特殊符号后的完整字符串
        var tsAtReplaceResultStr = inputStr
        /// 依次匹配到TS+的at，把找到的内容依次保存，然后替换为特殊符号
        while comperFromIndex < tsAtReplaceResultStr.endIndex.encodedOffset {
            let tsAtRegx = try? NSRegularExpression(pattern: tsAtRege, options: NSRegularExpression.Options.caseInsensitive)
            let matchs = tsAtRegx!.matches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset))
            /// 替换为特殊字符
            if let result = tsAtRegx?.stringByReplacingMatches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset), withTemplate: replaceStr), matchs.count > 0 {
                tsAts.append(TSCommonTool.getStriingFrom(tsAtReplaceResultStr, rang: matchs[0].range))
                tsAtReplaceResultStr = result
            } else {
                comperFromIndex = tsAtReplaceResultStr.endIndex.encodedOffset
            }
        }

        /// 找到手动输入的at并替换为TS+定制格式
        comperFromIndex = 0
        while comperFromIndex < tsAtReplaceResultStr.endIndex.encodedOffset {
            let inputAtRegx = try? NSRegularExpression(pattern: inputAtRege, options: NSRegularExpression.Options.caseInsensitive)
            let matchs = inputAtRegx!.matches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset))
            /// 如果找到了手动输入的at，并且成功截取出了指定range中的内容，并且替换为TS+指定样式
            if matchs.count > 0, let matchStr = TSCommonTool.getStriingFrom(tsAtReplaceResultStr, rang: matchs[0].range), let result = inputAtRegx?.stringByReplacingMatches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset), withTemplate: spStr + matchStr + spStr) {
                tsAtReplaceResultStr = result
            } else {
                comperFromIndex = tsAtReplaceResultStr.endIndex.encodedOffset
            }
        }

        /// 还原第一步被替换掉的TS+定制格式
        comperFromIndex = 0
        var replaceIndex = 0
        while comperFromIndex < tsAtReplaceResultStr.endIndex.encodedOffset, replaceIndex < tsAts.count {
            /// 原来的at
            let orignalAtStr = tsAts[replaceIndex]
            let inputAtRegx = try? NSRegularExpression(pattern: "(\(replaceStr))", options: NSRegularExpression.Options.caseInsensitive)
            let matchs = inputAtRegx!.matches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset))
            /// 如果找到了手动输入的at，并且成功截取出了指定range中的内容，并且替换为TS+指定样式
            if matchs.count > 0, let result = inputAtRegx?.stringByReplacingMatches(in: tsAtReplaceResultStr, options: NSRegularExpression.MatchingOptions.reportCompletion, range: NSRange(location: comperFromIndex, length: tsAtReplaceResultStr.endIndex.encodedOffset), withTemplate: orignalAtStr) {
                tsAtReplaceResultStr = result
                replaceIndex = replaceIndex + 1
            } else {
                comperFromIndex = tsAtReplaceResultStr.endIndex.encodedOffset
            }
        }
        return tsAtReplaceResultStr
    }
    /// 跳转到用户中心
    class func pushUserHomeName(name: String) {
        NotificationCenter.default.post(name: NSNotification.Name.AvatarButton.DidClick, object: nil, userInfo: ["uname": name])
    }

    /// 解析TS加网络文件格式，返回请求地址
    class func praseTSNetFileUrl(netFile: TSNetFileModel?) -> String? {
            return netFile?.url
    }

    ///  解析TS加网络文件格式，返回请求地址
    class func praseTSNetFileUrl(netFile: TSNetFileObject?) -> String? {
        return netFile?.url
    }

    /// 返回上一级页面
    class func popViewController(currentVC: UIViewController, animated: Bool) {
        if currentVC.presentingViewController != nil, let nav = currentVC.navigationController, nav.viewControllers.count == 1 {
            currentVC.dismiss(animated: animated, completion: nil)
        } else {
            currentVC.navigationController?.popViewController(animated: animated)
        }
    }

    /// URL跳转
    func getEnableAdvertModule() -> [String] {
        return [AdvertDynamicRege, AdvertInfoRege, AdvertCircleRege, AdvertPostRege, AdvertQuestionRege, AdvertQuestionTopicRege, AdvertAnswerRege, AdvertTopicRege]
    }
    class func pushURLDetail(url: URL, currentVC: UIViewController) {
        let enableAdvertModel: [String] = TSUtil().getEnableAdvertModule()
        if enableAdvertModel.isEmpty == false {
            let urlStr = url.absoluteString
            for advertRege in enableAdvertModel {
                let regx = try? NSRegularExpression(pattern: advertRege, options: NSRegularExpression.Options.caseInsensitive)
                let matches = regx?.matches(in: urlStr, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSRange(location: 0, length: urlStr.endIndex.encodedOffset))
                if let matches = matches, matches.isEmpty == false {
                    var detailVC: UIViewController?
                    if advertRege == TSUtil().AdvertDynamicRege {
                        // 动态
                        let components = urlStr.components(separatedBy: "feeds/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                               detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = TSCommetDetailTableView(feedId: detailIDInt, isTapMore: false)
                            }
                        }
                    } else if advertRege == TSUtil().AdvertInfoRege {
                        // 资讯
                        let components = urlStr.components(separatedBy: "news/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = TSNewsDetailViewController(newsId: detailIDInt)
                            }
                        }
                    } else if advertRege == TSUtil().AdvertCircleRege {
                        // 圈子
                        let components = urlStr.components(separatedBy: "groups/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = GroupDetailVC(groupId: detailIDInt)
                            }
                        }
                    } else if advertRege == TSUtil().AdvertPostRege {
                        // 帖子
                        var groupID = ""
                        let groupsComponents = urlStr.components(separatedBy: "groups/")
                        if groupsComponents.count >= 2 {
                            groupID = groupsComponents[1]
                            if groupID.components(separatedBy: "/").count >= 2 {
                                groupID = groupID.components(separatedBy: "/")[0]
                            }
                        }
                        let postsComponents = urlStr.components(separatedBy: "posts/")
                        var postsID = ""
                        if postsComponents.count >= 2 {
                            postsID = postsComponents[1]
                            if postsID.components(separatedBy: "/").count >= 2 {
                                postsID = postsID.components(separatedBy: "/")[0]
                            }
                        }
                        if let groupIDInt = Int(groupID), let postsIDInt = Int(postsID) {
                            detailVC = PostDetailController(groupId: groupIDInt, postId: postsIDInt)
                        }
                    } else if advertRege == TSUtil().AdvertQuestionRege {
                        // 问题
                        let components = urlStr.components(separatedBy: "questions/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                let questionVC = TSQuoraDetailController()
                                questionVC.questionId = detailIDInt
                                detailVC = questionVC
                            }
                        }
                    } else if advertRege == TSUtil().AdvertQuestionTopicRege {
                        // 问题-专题
                        let components = urlStr.components(separatedBy: "question-topics/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = TopicDetailController(topicId: detailIDInt)
                            }
                        }
                    } else if advertRege == TSUtil().AdvertAnswerRege {
                        // 回答
                        let components = urlStr.components(separatedBy: "question-answers/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = TSAnswerDetailController(answerId: detailIDInt)
                            }
                        }
                    } else if advertRege == TSUtil().AdvertTopicRege {
                        // 话题（动态）
                        let components = urlStr.components(separatedBy: "topic/")
                        if components.count >= 2 {
                            var detailID = components[1]
                            if detailID.components(separatedBy: "/").count >= 2 {
                                detailID = detailID.components(separatedBy: "/")[0]
                            }
                            if let detailIDInt = Int(detailID) {
                                detailVC = TopicPostListVC(groupId: detailIDInt)
                            }
                        }
                    }
                    if let detailVC = detailVC {
                        if let nav = currentVC as? UINavigationController {
                            nav.pushViewController(detailVC, animated: true)
                        } else if let nav = currentVC.navigationController {
                            nav.pushViewController(detailVC, animated: true)
                        } else {
                            let detailVCNav = TSNavigationController(rootViewController: detailVC)
                            currentVC.present(detailVCNav, animated: true, completion: nil)
                        }
                        return
                    }
                }
            }
            let webVC = TSWebViewController(url: url)
            if let nav = currentVC as? UINavigationController {
                nav.pushViewController(webVC, animated: true)
            } else if let nav = currentVC.navigationController {
                nav.pushViewController(webVC, animated: true)
            } else {
                let webVCNav = TSNavigationController(rootViewController: webVC)
                currentVC.present(webVCNav, animated: true, completion: nil)
            }
        } else {
            let webVC = TSWebViewController(url: url)
            currentVC.navigationController?.pushViewController(webVC, animated: true)
        }
    }
    /// 支付密码弹窗
    class func showPwdVC(complete: @escaping((_ inputCode: String?) -> Void)) {
        let pyVC = PayPasswordVC()
        TSUtil.share().pyVC = pyVC
        pyVC.view.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
        let nav = UINavigationController(rootViewController: pyVC)
        let bgView = UIView(frame: UIScreen.main.bounds)
        bgView.tag = 434_434
        bgView.isHidden = true
        bgView.backgroundColor = UIColor.white
        nav.view.addSubview(bgView)
        nav.view.sendSubview(toBack: bgView)
        pyVC.payNav = nav
        if let keyWindow = UIApplication.shared.keyWindow, let rootViewController = keyWindow.rootViewController {
            if let modalVC = rootViewController.presentedViewController {
                modalVC.view.addSubview(nav.view)
                modalVC.addChildViewController(nav)
                nav.didMove(toParentViewController: modalVC)
            } else {
                rootViewController.view.addSubview(nav.view)
                rootViewController.addChildViewController(nav)
                nav.didMove(toParentViewController: keyWindow.rootViewController)
            }
        }
        pyVC.sureBtnClickBlock = {(inputCodeStr: String) in
            TSUtil.share().inputCode = inputCodeStr
            complete(inputCodeStr)
        }
    }
    /// 移除支付密码弹窗
    class func dismissPwdVC() {
        if let payVC = TSUtil.share().pyVC {
            payVC.dismiss()
            TSUtil.share().pyVC = nil
        }
    }
}
