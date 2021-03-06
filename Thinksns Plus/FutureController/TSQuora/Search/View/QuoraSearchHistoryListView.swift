//
//  QuoraSearchHistoryListView.swift
//  ThinkSNS +
//
//  Created by GorCat on 2017/9/5.
//  Copyright © 2017年 ZhiYiCX. All rights reserved.
//
//  搜索历史记录列表

import UIKit
import RealmSwift

protocol QuoraSearchHistoryListViewDelegate: class {
    /// 点击了历史记录上的内容
    func historyListView(_ view: QuoraSearchHistoryListView, didSelectedCellWith historyContent: String)
}

class QuoraSearchHistoryListView: TSTableView {

    /// 历史记录类型
    var type: QuoraSearchHistoryObject.SearchType!

    /// 代理
    weak var historyDelegate: QuoraSearchHistoryListViewDelegate?

    /// 所有历史记录数据
    var allDatas: [QuoraSearchHistoryObject] = []
    /// 正在展示的历史记录数据
    var showingDatas: [QuoraSearchHistoryObject] = []
    /// 数据库 token
    var searchHistoryToken: NotificationToken!

    // MARK: - Lifecycle
    init(frame: CGRect, searchType: QuoraSearchHistoryObject.SearchType) {
        super.init(frame: frame, style: .plain)
        type = searchType
        setUI()
        loadData()
        setNotification()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUI()
        loadData()
        setNotification()
    }

    // MARK: - Custom user interface
    func setUI() {
        mj_header = nil
        mj_footer = nil
        dataSource = self
        delegate = self
        estimatedRowHeight = 44
        separatorStyle = .none
        register(UINib(nibName: "QuoraSearchHistoryCell", bundle: nil), forCellReuseIdentifier: QuoraSearchHistoryCell.identifier)
        register(UINib(nibName: "QuoraSearchHistoryBottomCell", bundle: nil), forCellReuseIdentifier: QuoraSearchHistoryBottomCell.identifier)
    }

    // MARK: - Data
    func loadData() {
        allDatas = Array(TSDatabaseManager().quora.getSearObjects(type: type))
        guard !allDatas.isEmpty else {
            return
        }
        let showingCount = Int(min(allDatas.count, 5))
        showingDatas = Array(allDatas[0..<showingCount])
        reloadData()
    }

    // MARK: - Notification
    func setNotification() {
        let datas = TSDatabaseManager().quora.getSearObjects(type: type)
        searchHistoryToken = datas.observe({ [weak self]  (_) in
            // 收到通知，说明数据库发生了变动，变动的具体信息包含在 changes 里的，这里偷懒，就不去扒 changes 里面的信息了
            self?.updateDatas()
        })
    }

    /// 更新数据，过滤数据中失效的数据
    func updateDatas() {
        allDatas = allDatas.flatMap { $0.isInvalidated ? nil : $0 }
        showingDatas = showingDatas.flatMap { $0.isInvalidated ? nil : $0 }
        reloadData()
        if showingDatas.isEmpty {
            show(placeholderView: .empty)
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension QuoraSearchHistoryListView: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showingDatas.isEmpty {
            return 0
        }
        return showingDatas.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 1.如果是最后一个 cell，用 "清空历史记录"/"显示全部记录" cell
        if showingDatas.count == indexPath.row {
            let cell = tableView.dequeueReusableCell(withIdentifier: QuoraSearchHistoryBottomCell.identifier) as! QuoraSearchHistoryBottomCell
            cell.selectionStyle = .none
            // 判断是不是已经展示了所有的数据，来更新最后一个 cell 的显示文字
            if allDatas.count == showingDatas.count {
                cell.labelForTitle.text = "清空搜索历史"
            } else {
                cell.labelForTitle.text = "显示全部历史"
            }
            return cell
        }
        // 2.除了最后一个 cell，其他 cell 用历史记录的 cell
        let cell = tableView.dequeueReusableCell(withIdentifier: QuoraSearchHistoryCell.identifier, for: indexPath) as! QuoraSearchHistoryCell
        cell.labelForHistory.text = showingDatas[indexPath.row].content
        cell.delegate = self
        cell.selectionStyle = .none
        return cell
    }

    // 点击 cell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 1.如果是最后一个 "清空历史记录"/"显示全部记录" 的 cell
        if indexPath.row == showingDatas.count {
            // 根据 cell 上对应的文字，更新列表上展示的内容
            let cell = cellForRow(at: indexPath) as! QuoraSearchHistoryBottomCell
            // 1.1 清空历史记录
            if cell.labelForTitle.text == "清空搜索历史" {
                TSDatabaseManager().quora.emptySearchObjects(type: type)
                return
            }
            // 1.2 显示全部的历史记录
            if cell.labelForTitle.text == "显示全部历史" {
                showingDatas = allDatas
                reloadData()
                return
            }
            return
        }
        // 2.如果是历史记录的 cell
        // 通过代理，将 cell 上的历史记录内容抛出
        let searchObject = showingDatas[indexPath.row]
        historyDelegate?.historyListView(self, didSelectedCellWith: searchObject.content)
        TSDatabaseManager().quora.delete(searchObject: searchObject)
        // 数据源更新后刷新列表，避免不同步导致的异常
        tableView.reloadData()
    }

}

// MARK: - QuoraSearchHistoryCellDeleagate: 历史记录 cell 的交互代理事件
extension QuoraSearchHistoryListView: QuoraSearchHistoryCellDeleagate {

    /// 点击了历史记录 cell 的关闭按钮
    func cell(_ cell: QuoraSearchHistoryCell, didSelected closeButton: UIButton) {
        // 1.获取 cell 的 row 信息
        let index = indexPath(for: cell)!.row
        // 2.获取该 cell 所显示的 data
        let searchObject = showingDatas[index]
        // 2.从数据库中删除 data
        TSDatabaseManager().quora.delete(searchObject: searchObject)
    }
}
