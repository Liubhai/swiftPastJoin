//
//  QuoraTopicDetailIntroLabelCell.swift
//  ThinkSNS +
//
//  Created by GorCat on 2017/9/1.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  话题简介 cell

import UIKit
import YYKit

class QuoraTopicDetailIntroLabelCell: UITableViewCell {

    /// 话题简介
    let introlLabel = YYLabel()
    /// 分割线
    let separatorLine = UIView()

    /// 话题简介数据
    var model: QuoraTopicDetailIntroLabelCellModel? {
        didSet {
            setInfo()
        }
    }

    static let identifier = "QuoraTopicDetailIntroLabelCell"

    class func cellForm(table: UITableView, at indexPath: IndexPath, with data: QuoraTopicDetailIntroLabelCellModel) -> QuoraTopicDetailIntroLabelCell {
        let cell = table.dequeueReusableCell(withIdentifier: QuoraTopicDetailIntroLabelCell.identifier, for: indexPath) as! QuoraTopicDetailIntroLabelCell
        cell.model = data
        return cell
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUI()
    }

    func setUI() {
        // 分割线
        separatorLine.backgroundColor = TSColor.inconspicuous.disabled
        contentView.addSubview(separatorLine)
        separatorLine.snp.makeConstraints { (make) in
            make.topMargin.equalToSuperview()
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.height.equalTo(1)
        }
        // 简介 label
        introlLabel.font = UIFont.systemFont(ofSize: 14)
        introlLabel.textColor = TSColor.normal.content
        introlLabel.isUserInteractionEnabled = true
        introlLabel.numberOfLines = 3
        introlLabel.textVerticalAlignment = .top
        introlLabel.size = CGSize(width: UIScreen.main.bounds.width - 20, height: 1_000)
        addUnfoldButton()
        contentView.addSubview(introlLabel)
    }

    func setInfo() {
        guard let cellModel = model else {
            return
        }
        let introText = NSAttributedString(string: "专题简介：" + cellModel.introl)
        introlLabel.attributedText = introText
        introlLabel.sizeToFit()
        introlLabel.snp.makeConstraints { (make) in
            make.topMargin.leftMargin.equalTo(15)
            make.bottomMargin.rightMargin.equalTo(-15)
            make.height.equalTo(introlLabel.frame.height)
        }
    }

    func addUnfoldButton() {
        // 1.配置点击事件
        let hi = YYTextHighlight()
        hi.tapAction = { [weak self] (containerView, text, range, rect) in
            self?.introlLabel.numberOfLines = 0
            self?.introlLabel.sizeToFit()
            let newHeight = (self?.introlLabel.frame.height)!
            self?.introlLabel.snp.remakeConstraints { (make) in
                make.topMargin.leftMargin.equalTo(15)
                make.bottomMargin.rightMargin.equalTo(-15)
                make.height.equalTo(newHeight)
                NotificationCenter.default.post(name: NSNotification.Name.TopicDetailController.unfold, object: nil, userInfo: nil)
            }
        }
        // 2.配置按钮标题
        let foldTitle = QuoraStackBottomButtonsCell.getAttributeString(texts: ["...", "展开全部"], colors: [TSColor.normal.content, TSColor.main.theme])
        foldTitle.font = introlLabel.font
        foldTitle.setTextHighlight(hi, range: NSRange(location: "...".count - 1, length: "展开全部".count))
        // 3.配置按钮
        let foldButton = YYLabel()
        foldButton.attributedText = foldTitle
        foldButton.sizeToFit()
        // 4.设置 token
        let truncationToken = NSAttributedString.attachmentString(withContent: foldButton, contentMode: .center, attachmentSize: foldButton.size, alignTo: foldTitle.font!, alignment: .center)
        introlLabel.truncationToken = truncationToken
    }
}
