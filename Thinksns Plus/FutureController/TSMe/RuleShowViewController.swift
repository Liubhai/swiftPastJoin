//
//  RuleShowViewController.swift
//  ThinkSNSPlus
//
//  Created by IMAC on 2018/4/21.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit
import MarkdownView

class RuleShowViewController: TSViewController {
    let markDownView: MarkdownView = MarkdownView()
    var ruleMarkdownStr: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        markDownView.frame = CGRect(x: 0, y: 15, width: self.view.frame.width, height: self.view.frame.height)
        view.backgroundColor = UIColor.white
        view.addSubview(markDownView)
        markDownView.load(markdown: ruleMarkdownStr)
        markDownView.onRendered = { [weak self] height in
            guard let `self` = self else {
                return
            }
            self.markDownView.frame.size = CGSize(width: self.view.frame.width, height: height)
        }
    }

}
