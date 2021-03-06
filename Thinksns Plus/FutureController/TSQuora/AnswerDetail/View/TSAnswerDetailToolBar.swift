//
//  TSAnswerDetailToolBar.swift
//  ThinkSNS +
//
//  Created by 小唐 on 12/09/2017.
//  Copyright © 2017 ZhiYiCX. All rights reserved.
//
//  答案详情页底部工具栏

import UIKit

protocol TSAnswerDetailToolBarProtocol: class {
    /// 点赞按钮点击响应
    func didClickFavorItemIn(toolBar: TSAnswerDetailToolBar) -> Void
    /// 评论按钮点击响应
    func didClickCommentItemIn(toolBar: TSAnswerDetailToolBar) -> Void
    /// 分享按钮点击响应
    func didClickShareItemIn(toolBar: TSAnswerDetailToolBar) -> Void
    /// 更多按钮点击响应
    func didClickMoreItemIn(toolBar: TSAnswerDetailToolBar) -> Void
}

class TSAnswerDetailToolBar: UIView {

    // MARK: - Internal Property
    static let defaultH: CGFloat = 48 + TSBottomSafeAreaHeight
    /// 点赞状态更新
    var isFavored: Bool = false {
        didSet {
            self.toolBar.setImage(isFavored ? "IMG_home_ico_good_high" : "IMG_home_ico_good_normal", At: 0)
        }
    }
    /// 回调代理
    weak var delegate: TSAnswerDetailToolBarProtocol?

    // MARK: - Internal Function

    // MARK: - Private Property
    private weak var toolBar: TSToolbarView!

    // MARK: - Initialize Function
    init() {
        super.init(frame: CGRect.zero)
        self.initialUI()
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.initialUI()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialUI()
    }

    // MARK: - LifeCircle Function

    // MARK: - Private  UI

    // 界面布局
    private func initialUI() -> Void {
        // 1. bar
        let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: TSAnswerDetailToolBar.defaultH)
        let favorItem = TSToolbarItemModel(image: "IMG_home_ico_good_normal", title: "喜欢", index: 0)
        let commentItem = TSToolbarItemModel(image: "IMG_home_ico_comment_normal", title: "评论", index: 1)
        let shareItem = TSToolbarItemModel(image: "IMG_detail_ico_share_normal", title: "分享", index: 2)
        let moreItem = TSToolbarItemModel(image: "IMG_home_ico_more", title: "更多", index: 3)
        let toolBar = TSToolbarView(frame: frame, type: .top, items: [favorItem, commentItem, shareItem, moreItem])
        self.addSubview(toolBar)
        toolBar.delegate = self
        self.toolBar = toolBar
        // 2. line
        let line = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        line.backgroundColor = TSColor.inconspicuous.disabled
        addSubview(line)
    }

    // MARK: - Private  数据加载

    // MARK: - Private  事件响应

}

// MARK: - TSToolbarViewDelegate

extension TSAnswerDetailToolBar: TSToolbarViewDelegate {
    /// 点击了工具栏
    func toolbar(_ toolbar: TSToolbarView, DidSelectedItemAt index: Int) {
        switch index {
        case 0: // 点赞
            self.delegate?.didClickFavorItemIn(toolBar: self)
            break
        case 1: // 评论
            self.delegate?.didClickCommentItemIn(toolBar: self)
            break
        case 2: // 分享
            self.delegate?.didClickShareItemIn(toolBar: self)
        case 3: // 更多
            self.delegate?.didClickMoreItemIn(toolBar: self)
        default:
            break
        }
    }
}
