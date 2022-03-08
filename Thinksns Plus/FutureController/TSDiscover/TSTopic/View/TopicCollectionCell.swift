//
//  TopicCollectionCell.swift
//  ThinkSNSPlus
//
//  Created by IMAC on 2018/7/23.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit

class TopicCollectionCell: UICollectionViewCell {

    let itemHeit: CGFloat = 180
    let itemLeftAndRightSpacing: CGFloat = 15
    static let identifier = "topicCell"
    var titleLabel: UILabel!
    var imageBg: UIImageView!
    var imageShadow: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func initUI() {
        imageBg = UIImageView(frame: CGRect(x: itemLeftAndRightSpacing, y: 15, width: ScreenWidth - 2 * itemLeftAndRightSpacing, height: itemHeit))
        imageBg.layer.cornerRadius = CGFloat(6)
        imageBg.contentMode = UIViewContentMode.scaleAspectFill
        imageBg.clipsToBounds = true
        imageShadow = UIImageView(frame: CGRect(x: itemLeftAndRightSpacing, y:  15, width: ScreenWidth - 2 * itemLeftAndRightSpacing, height: itemHeit))
        imageShadow.layer.cornerRadius = CGFloat(6)
        imageShadow.backgroundColor = UIColor.black
        imageShadow.alpha = 0.2
        titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: ScreenWidth - 3 * itemLeftAndRightSpacing, height: itemHeit))
        titleLabel.font = UIFont.systemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.centerX = imageBg.centerX
        titleLabel.centerY = imageBg.centerY
        titleLabel.textColor = UIColor.white
        titleLabel.numberOfLines = 0
        /// 设置阴影颜色
        titleLabel.shadowColor = UIColor.black
        ///设置阴影大小
        titleLabel.shadowOffset = CGSize(width: 0.4, height: 0.4)
        self.addSubview(imageBg)
        self.addSubview(imageShadow)
        self.addSubview(titleLabel)
    }

    func setInfo(model: TopicListModel, index: IndexPath) {
        titleLabel.text = model.topicTitle
        imageBg.kf.setImage(with: URL(string: TSUtil.praseTSNetFileUrl(netFile: model.topicLogo) ?? ""), placeholder: #imageLiteral(resourceName: "pic_cover"), options: nil, progressBlock: nil, completionHandler: nil)
    }
}
