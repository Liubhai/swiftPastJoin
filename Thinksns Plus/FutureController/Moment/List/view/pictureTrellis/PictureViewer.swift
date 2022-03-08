//
//  PictureViewer.swift
//  ThinkSNS +
//
//  Created by GorCat on 2017/10/31.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  单张图片加载视图

import UIKit
import Kingfisher
import RealmSwift

class PictureViewer: UIControl {

    /// 图片数据 model
    public var model = PaidPictureModel() {
        didSet {
            loadModel()
        }
    }
    /// 图片
    var picture: UIImage? {
        return pictureView.image
    }
    /// 在屏幕上的 frame
    var frameOnScreen: CGRect {
        let screenOrigin = pictureView.convert(pictureView.frame.origin, to: nil)
        return CGRect(origin: screenOrigin, size: size)
    }

    /// 屏幕比例
    internal let scale = UIScreen.main.scale
    // 加载图片的网络请求头
    internal let modifier = AnyModifier { request in
        var r = request
        if let authorization = TSCurrentUserInfo.share.accountToken?.token {
            r.setValue("Bearer " + authorization, forHTTPHeaderField: "Authorization")
        }
        return r
    }

    /// 图片占位图
    internal var placeholder: UIImage {
        return cacheImage ?? UIImage.create(with: TSColor.inconspicuous.disabled, size: frame.size)
    }
    /// 缓存图片
    var cacheImage: UIImage?

    /// 长图标识
    let longiconView = UIImageView()
    /// 图片视图
    let pictureView = UIImageView()
    /// 图片数量蒙层
    let countMaskButton = UIButton(type: .custom)

    // MARK: - 生命周期
    init() {
        super.init(frame: .zero)
        setUI()
        setNotification()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.PaidImage.buyPic, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUI()
    }

    // MARK: - UI

    /// 设置基础视图
    internal func setUI() {
        // 1.图片视图
        pictureView.contentScaleFactor = UIScreen.main.scale
        pictureView.contentMode = .scaleAspectFill
        pictureView.autoresizingMask = UIViewAutoresizing.flexibleHeight
        pictureView.clipsToBounds = true
        addSubview(pictureView)
        // 2.长图标识
        let image = UIImage(named: "IMG_pic_longpic")
        longiconView.image = image
        longiconView.sizeToFit()
        addSubview(longiconView)
        // 3.数量蒙层
        addSubview(countMaskButton)
    }

    fileprivate func loadModel() {
        // 2.长图标识
        longiconView.isHidden = !(model.originalSize.isLongPictureSize() && model.shouldShowLongicon)
        // 动图标示
        if model.mimeType == "image/gif" {
            longiconView.isHidden = false
            longiconView.image = UIImage(named: "pic_gif")
            longiconView.sizeToFit()
        } else {
            longiconView.image = UIImage(named: "IMG_pic_longpic")
            longiconView.sizeToFit()
        }
        // 1.加载图片
        loadPicture()
        // 3.图片数量蒙层
        loadCountMaskButton()
    }

    /// 加载数量蒙层按钮
    fileprivate func loadCountMaskButton() {
        countMaskButton.isHidden = model.unshowCount < 0
        guard model.unshowCount > 0 else {
            return
        }
        countMaskButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        countMaskButton.setTitle("+\(model.unshowCount)", for: .normal)
        countMaskButton.setTitleColor(.white, for: .normal)
        countMaskButton.backgroundColor = UIColor(white: 0, alpha: 0.4)
        countMaskButton.frame = bounds
    }

    /// 加载图片
    internal func loadPicture(forceToRefresh: Bool = false) {
        // 0.刷新子视图 frame
        updateChildviews()
        // 3.如果有本地缓存，先加载缓存图片
        cacheImage = nil
        if model.cache != nil {
            loadCachePicture()
        }
        // 4.如果有网络链接，再加载网络图片（网络加载出的图片会覆盖缓存图片）
        guard let url = model.url else {
            return
        }

        let imageUrl: String = url.smallPicUrl(showingSize: frame.size, originalSize: model.originalSize)
        downPicture(imageUrl: imageUrl, forceToRefresh: forceToRefresh)
    }

    /// 刷新子视图 frame
    internal func updateChildviews() {
        // 1.图片视图
        pictureView.frame = bounds
        // 2.长图标识
        let iconX = frame.width - longiconView.width
        let iconY = frame.height - longiconView.height
        longiconView.frame = CGRect(origin: CGPoint(x: iconX, y: iconY), size: longiconView.size)
    }

    /// 更新监听的 token
    func setNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(forceRefreshImage(notification:)), name: NSNotification.Name.PaidImage.buyPic, object: nil)
    }

    func forceRefreshImage(notification: Notification) {
        guard let userInfo = notification.userInfo, let url = userInfo["url"] as? String else {
            return
        }
        if url == model.url {
            model.paidInfo = nil
            loadPicture(forceToRefresh: true)
        }
    }

    /// 获取本地缓存图片
    internal func loadCachePicture() {
        guard let cache = model.cache else {
            return
        }
        self.pictureView.image = UIImage.create(with: TSColor.inconspicuous.disabled, size: frame.size)
        let pictureSize = CGSize(width: frame.width * 1.5, height: frame.height * 1.5)
        // 【坑】 发送失败的图片都会在启动应用时从这里加载 导致内存占用几百M
        ImageCache.default.retrieveImage(forKey: cache, options: []) { (image, _) in
            DispatchQueue.global(qos: .background).async {
                let image = image?.kf.resize(to: pictureSize, for: .aspectFill)
                DispatchQueue.main.sync {
                    self.pictureView.image = image
                    self.cacheImage = image
                }
            }
        }
    }

    /// 下载图片
    internal func downPicture(imageUrl: String, forceToRefresh: Bool) {
        let url = URL(string: imageUrl)
        var options: KingfisherOptionsInfo = [.requestModifier(modifier)]
        if forceToRefresh {
            options.append(.forceRefresh)
        }
        var placeholderImage: UIImage
        if let cacheImage = cacheImage {
            placeholderImage = cacheImage
        } else {
            placeholderImage = UIImage.create(with: TSColor.inconspicuous.disabled, size: frame.size)
        }
        pictureView.kf.setImage(with: url, placeholder: placeholderImage, options: options, progressBlock: nil, completionHandler: nil)
    }

}

extension String {

    func smallPicUrl(showingSize: CGSize, originalSize: CGSize) -> String {
        // 尺寸设置为 CGSize.zero，获取原图
        if showingSize == CGSize.zero {
            let imageUrl = self
            return imageUrl
        }
        assert(originalSize.width >= 0.0)
        assert(originalSize.height >= 0.0)
        let height = floor(showingSize.width * UIScreen.main.scale)
        let width = floor(showingSize.height * UIScreen.main.scale)
        /// 特别大的图片直接获取原图不要传递宽高参数，会导致无法显示
        if height > 4_000 || width > 4_000 {
            let imageUrl = self
            return imageUrl
        }
        let imageUrl = self + "?w=\(height)&h=\(width)&q=\(50)"
        return imageUrl
    }
}
