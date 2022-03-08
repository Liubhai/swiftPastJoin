//
//  NoticeTableViewController.swift
//  ThinkSNS +
//
//  Created by lip on 2017/9/4.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  通知视图控制器

import UIKit

class NoticeTableViewController: TSTableViewController {
    /// 数据源
    lazy var dataSource: [NoticeModel] = []
    /// 数据加载数量
    let limit = TSAppConfig.share.localInfo.limit
    /// 父控制器
    var superViewController: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor.white
        title = "系统消息"
        tableView.register(NoticeTableViewCell.self, forCellReuseIdentifier: "NoticeTableViewController")
        tableView.mj_header.beginRefreshing()
        tableView.mj_footer.isHidden = true
        tableView.separatorStyle = .none
    }

    override func refresh() {
        /// 清除对应的小红点
        var clearrequest = UserNetworkRequest().readCounts
        clearrequest.urlPath = clearrequest.fullPathWith(replacers: [])
        clearrequest.parameter = ["type": "system"]
        RequestNetworkData.share.text(request: clearrequest) { (_) in
            // 直接清理本地的数据
            TSCurrentUserInfo.share.unreadCount.system = 0
        }

        var request = NoticeNetworkRequest().notiList
        request.urlPath = request.fullPathWith(replacers: [])

        let parameter: [String : Any] = ["limit": limit, "offset": 0, "type": "all"]
        request.parameter = parameter
        let readGroup = DispatchGroup()
        readGroup.enter()
        RequestNetworkData.share.text(request: request) { [unowned self] (networkResult) in
            self.tableView.mj_header.endRefreshing()
            switch networkResult {
            case .error(_):
                self.show(placeholderView: .network)
            case .failure(let response):
                if let message = response.message {
                    self.show(indicatorA: message, timeInterval: 3)
                    return
                }
                self.show(indicatorA: "提示信息_网络错误".localized, timeInterval: 3)
            case .success(let reponse):
                self.dataSource = reponse.models
                if self.dataSource.isEmpty {
                    self.show(placeholderView: .empty)
                }
                if reponse.models.count < self.limit {
                    self.tableView.mj_footer.isHidden = true
                    self.tableView.mj_footer.endRefreshingWithNoMoreData()
                } else {
                    self.tableView.mj_footer.isHidden = false
                    self.tableView.mj_footer.resetNoMoreData()
                }
                self.tableView.reloadData()
                readGroup.leave()
            }
        }
        readGroup.notify(queue: .main) { // 当获取完数据成功后,标记该数据已读,移除小红点
            if self.dataSource.isEmpty {
                return
            }
            var request = NoticeNetworkRequest().readAllNoti
            request.urlPath = request.fullPathWith(replacers: [])

            RequestNetworkData.share.text(request: request, complete: { (_) in
                TSCurrentUserInfo.share.unreadCount.isHiddenNoticeBadge = true
                if let messageVC = self.superViewController as? MessageViewController {
                    messageVC.badges[1].isHidden = true
                }
            })
        }
    }

    override func loadMore() {
        var request = NoticeNetworkRequest().notiList
        request.urlPath = request.fullPathWith(replacers: [])

        let oldDataSourceCount = self.dataSource.count
        let parameter: [String: Any] = ["limit": limit, "offset": oldDataSourceCount, "type": "all"]
        request.parameter = parameter
        RequestNetworkData.share.text(request: request) { [unowned self] (networkResult) in
            self.tableView.mj_header.endRefreshing()
            switch networkResult {
            case .error(_):
                self.show(placeholderView: .network)
            case .failure(let response):
                if let message = response.message {
                    self.show(indicatorA: message, timeInterval: 3)
                    return
                }
                self.show(indicatorA: "提示信息_网络错误".localized, timeInterval: 3)
            case .success(let reponse):
                self.dataSource = self.dataSource + reponse.models
                if self.dataSource.isEmpty {
                    self.show(placeholderView: .empty)
                }
                if reponse.models.count < self.limit {
                    self.tableView.mj_footer.isHidden = true
                    self.tableView.mj_footer.endRefreshingWithNoMoreData()
                } else {
                    self.tableView.mj_footer.isHidden = false
                    self.tableView.mj_footer.resetNoMoreData()
                }
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoticeTableViewController", for: indexPath) as! NoticeTableViewCell
        let model = dataSource[indexPath.row]
        cell.selectionStyle = .none
        cell.contentLabel.text = model.detail.content
        cell.createdDateLabel.text = TSDate().dateString(.normal, nsDate: model.createdDate as NSDate)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
}
