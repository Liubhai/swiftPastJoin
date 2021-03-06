//
//  URLExtensionForMusic.swift
//  Thinksns Plus
//
//  Created by LiuYu on 2017/3/1.
//  Copyright © 2017年 Lius. All rights reserved.
//

import Foundation

extension URL {
    /// 自定义scheme
    func musicCustomSchemeURL() -> URL {
        let components = NSURLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = "streaming"
        return (components?.url)!
    }
    /// 还原scheme
    func musicOriginalSchemeURL() -> URL {
        let components = NSURLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return (components?.url)!
    }
}
