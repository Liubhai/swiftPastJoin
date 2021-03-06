//
//  TSChatListTableViewController.swift
//  ThinkSNS +
//
//  Created by 刘邦海 on 2018/1/2.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//

import UIKit
import RealmSwift
import ObjectMapper
import SwiftyJSON

class TSChatListTableViewController: TSTableViewController, TSConversationTableViewCellDelegate, EMChatManagerDelegate, EMGroupManagerDelegate, EMClientDelegate, UISearchBarDelegate {
    var noticeCellModel: [NoticeConversationCellModel]
    private var conversationNotificationToken: NotificationToken?
    private let allMessages = TSDatabaseManager().chat.allMessages()
    private var messageListNotifictionToken: NotificationToken?
    weak var superViewController: MessageViewController?
    weak var superMessagePop: TSPopMessageFriendList?
    weak var pViewController: ChatListViewController?
    weak var pViewControllerMessage: TSPopMessageVC?
    var copyTableView: UITableView?

    /// 环信需要保存的数量
    var groupArray = NSMutableArray()
    var groupInfoDic = NSMutableDictionary()
    var conversationArray = NSMutableArray()
    var searchChat: UISearchBar?
    /// 直接从数据库能拿到的用户信息的聊天会话
    var searchArray = NSMutableArray()
    /// 没有存在于数据库里面的用户
    var searchNewUserIDArray = NSMutableArray()
    /// 需要请求用户信息接口拿到用户昵称去匹配搜索框关键字拿到的聊天会话
    var searchNewChatArray = NSMutableArray()
    /// 当前控制器是否显示
    var isCurrentVCAppear: Bool = false
    /// 是否出于搜索状态
    var isSearch: Bool = false

    /// 消息页以及子页面的头像尺寸
    let avatarSizeType = AvatarType.width38(showBorderLine: false)

    // MARK: - lifecycle
    init(style: UITableViewStyle, model: [NoticeConversationCellModel]) {
        self.noticeCellModel = model
        super.init(style: style)
        self.setupTableView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("不支持xib")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor.white
        NotificationCenter.default.addObserver(self, selector: #selector(getHyChatList), name: NSNotification.Name(rawValue: "sendMessageReloadChatListVc"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updataGroupInfo), name: Notification.Name(rawValue: "editgroupnameorimage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getHyChatList), name: Notification.Name(rawValue: "callEndReloadData"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reconnectionTSHYIMServiceFalse), name: Notification.Name.Chat.hyGetPasswordFalse, object: nil)
        EMClient.shared().add(self as EMClientDelegate, delegateQueue: nil)
        self.registerNotifications()
        // 在需要显示搜索结果的时候再设置frame并添加至父视图
        copyTableView = UITableView()
        copyTableView?.delegate = self
        copyTableView?.dataSource = self
        copyTableView?.tableFooterView = UIView()
        copyTableView?.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isCurrentVCAppear = true
        /// 简单判断下当前会话列表没有数据则请求下会话列表 主要用于第一次加载这个页面的时候请求环信聊天列表
        guard self.conversationArray.count == 0 else {
            return
        }
        self.tableView.mj_header.beginRefreshing()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.isCurrentVCAppear = true
        super.viewWillAppear(animated)
        if self.conversationArray.count != 0 {
            self.reloadLocationChatListData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.isCurrentVCAppear = false
        super.viewWillDisappear(animated)
    }

    deinit {
        conversationNotificationToken?.invalidate()
        messageListNotifictionToken?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    override func setupRefresh() {
        // 取消掉下拉刷新
        tableView.mj_header = TSRefreshHeader(refreshingTarget: self, refreshingAction: #selector(refresh))
    }

    override func refresh() {
        isSearch = false
        self.getHyChatList()
    }

    func setupTableView() {
        tableView.register(TSConversationTableViewCell.nib(), forCellReuseIdentifier: TSConversationTableViewCell.cellReuseIdentifier)
        tableView.register(NoticeConversationCell.self, forCellReuseIdentifier: "NoticeConversationCell")
        tableView.separatorStyle = .none
    }

    // MARK: - TSConversation TableViewCell Delegate
    func headButtonDidPress(for userId: Int) {
        /// 调试用环信详情页
        let indexpath: NSIndexPath = NSIndexPath(row: userId, section: 0)
        let chatCell: TSConversationTableViewCell? = tableView.cellForRow(at: indexpath as IndexPath) as? TSConversationTableViewCell
        chatCell?.countButtton.isHidden = true
        let chatConversation: EMConversation
        if isSearch {
            chatConversation = self.searchArray[userId] as! EMConversation
        } else {
            chatConversation = self.conversationArray[userId] as! EMConversation
        }
        let selectedUnread = chatConversation.unreadMessagesCount
        var resultError: EMError? = nil
        chatConversation.markAllMessages(asRead: &resultError)
        let count = Int32(TSCurrentUserInfo.share.unreadCount.imMessage) - selectedUnread
        TSCurrentUserInfo.share.unreadCount.imMessage = Int(count)
        self.superViewController?.countUnreadInfo()

        let vc = ChatDetailViewController(conversationChatter: chatConversation.conversationId, conversationType:chatConversation.type)
        vc?.chatTitle = chatCell?.nameLabel.text

        if chatConversation.type == EMConversationTypeChat {

        } else if chatConversation.type == EMConversationTypeGroupChat {
            vc?.groupOriginData = chatConversation.groupInfo! as NSDictionary
        } else {

        }
        navigationController?.pushViewController(vc!, animated: true)
        return
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.01
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearch ? self.searchArray.count : self.conversationArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return processConversations(indexPath)
    }

    func processNotices(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoticeConversationCell") as! NoticeConversationCell
        cell.model = noticeCellModel[indexPath.row]
        return cell
    }

    // MARK: - 长按删除会话历史记录
    func longPressResponse(resture: UITapGestureRecognizer) {
        if resture.state == .began {
            let editRow = resture.view?.tag
            let conver: EMConversation
            if isSearch {
                conver = self.searchArray[editRow!] as! EMConversation
            } else {
                conver = self.conversationArray[editRow!] as! EMConversation
            }
            let idSt: String = (conver.conversationId)!
            let idInt: Int = Int(idSt)!

            /// 非小助手就可以删除
            if let imHelperUid = TSAppConfig.share.localInfo.imHelper {
                if imHelperUid == idInt {
                    return
                }
            } else {
                TSLogCenter.log.debug("没有获取到小助手信息")
            }
            /// 弹窗确定是否删除
            let actionsheetView = TSCustomActionsheetView(titles: ["提示信息_聊天会话删除确认".localized, "提示信息_确定".localized])
            actionsheetView.setColor(color: TSColor.main.warn, index: 1)
            actionsheetView.notClickIndexs = [0]
            actionsheetView.show()
            actionsheetView.finishBlock = { (actionsheet: TSCustomActionsheetView, title: String, btnTag: Int) in
                if btnTag == 1 {
                    self.deleteChat(row: editRow!)
                }
            }
        }
    }

    func deleteChat(row: Int) {
        let conver: EMConversation
        if isSearch {
            conver = self.searchArray[row] as! EMConversation
        } else {
            conver = self.conversationArray[row] as! EMConversation
        }
        EMClient.shared().chatManager.deleteConversation(conver.conversationId, isDeleteMessages: true, completion: { (message, error) in
            if error == nil {
                if self.isSearch {
                    self.searchArray.removeObject(at: row)
                    self.tableView.isHidden = true
                    self.copyTableView?.isHidden = false
                    self.copyTableView?.reloadData()
                    // 更新未读数量
                    DispatchQueue.main.async {
                        let selectedUnread = conver.unreadMessagesCount
                        var resultError: EMError? = nil
                        conver.markAllMessages(asRead: &resultError)
                        let count = Int32(TSCurrentUserInfo.share.unreadCount.imMessage) - selectedUnread
                        TSCurrentUserInfo.share.unreadCount.imMessage = Int(count)
                        self.superViewController?.countUnreadInfo()
                    }
                    /// 这里也要更新 conversationArray
                    var convernew: EMConversation
                    for (index, _) in self.conversationArray.enumerated() {
                        convernew = self.conversationArray[row] as! EMConversation
                        if convernew.conversationId == conver.conversationId {
                            self.conversationArray.removeObject(at: index)
                            break
                        }
                    }
                } else {
                    // 更新未读数量
                    DispatchQueue.main.async {
                        let selectedUnread = conver.unreadMessagesCount
                        var resultError: EMError? = nil
                        conver.markAllMessages(asRead: &resultError)
                        let count = Int32(TSCurrentUserInfo.share.unreadCount.imMessage) - selectedUnread
                        TSCurrentUserInfo.share.unreadCount.imMessage = Int(count)
                        self.superViewController?.countUnreadInfo()
                    }
                    self.conversationArray.removeObject(at: row)
                    self.tableView.isHidden = false
                    self.copyTableView?.isHidden = true
                    self.tableView.reloadData()
                }
            }
        })
    }

    func processConversations(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TSConversationTableViewCell.cellReuseIdentifier) as! TSConversationTableViewCell
        /// 区分是群还是单聊  群聊需要群头像群昵称  单聊要去拿聊天对象的头像昵称
        let conver: EMConversation
        if isSearch {
            conver = self.searchArray[indexPath.row] as! EMConversation
        } else {
            /// 异常情况
            if self.conversationArray.count <= indexPath.row {
                return cell
            }
            conver = self.conversationArray[indexPath.row] as! EMConversation
        }
        var avatarString: String? = nil
        var chatName: String? = nil
        var verifiedIcon: String? = nil
        var verifiedType: String? = nil
        cell.isnewUser = false
        let idSt: String = (conver.conversationId)!
        let idInt: Int = Int(idSt)!
        if conver.type == EMConversationTypeChat {
            if conver.conversationId == "admin" {
                chatName = "管理员"
            } else {
                if TSDatabaseManager().user.get(idInt) != nil {
                    let hyUserInfo = TSDatabaseManager().user.get(idInt)
                    avatarString = TSUtil.praseTSNetFileUrl(netFile: hyUserInfo?.avatar)
                    verifiedIcon = hyUserInfo?.verified?.icon
                    verifiedType = hyUserInfo?.verified?.type
                    chatName = hyUserInfo?.name
                } else {
                    cell.isnewUser = true
                }
            }
        } else {
            chatName = "[群聊]"
            if let groupdict = conver.groupInfo {
                let groupFace = groupdict["group_face"]
                let groupChatFace = "\(groupFace ?? "")"
                let groupName = groupdict["name"]
                var groupChatName = "\(groupName ?? "")"
                let menberNumber = groupdict["affiliations_count"] ?? ""
                groupChatName = "\(groupName ?? "")(\(menberNumber))"
                avatarString = groupChatFace
                chatName = groupChatName
            }
        }
        if conver.type == EMConversationTypeGroupChat && conver.isBlocked == true {
            cell.hidScreenGroup = false
        } else {
            cell.hidScreenGroup = true
        }
        cell.tag = indexPath.row
        let cellLongPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressResponse(resture:)))
        cell.addGestureRecognizer(cellLongPress)
        let avatarInfo = AvatarInfo()
        avatarInfo.verifiedIcon = verifiedIcon ?? ""
        avatarInfo.verifiedType = verifiedType ?? ""
        avatarInfo.avatarURL = avatarString
        cell.avatarInfo = avatarInfo
        cell.nameLabel.text = chatName
        cell.headerButton.avatarInfo = avatarInfo
        // 群组的默认头像是在cell的hyConversation set方法中设置的
        // 所以需要在头像btn avatarInfo设置之后,否则群的默认头像会无效
        cell.hyConversation = conver
        cell.delegate = self
        cell.currentIndex = indexPath.row
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kTSConversationTableViewCellDefaltHeight
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.tableView.mj_header.isRefreshing() == true {
            return
        }
        /// 调试用环信详情页
        let chatCell: TSConversationTableViewCell? = tableView.cellForRow(at: indexPath) as? TSConversationTableViewCell
        chatCell?.countButtton.isHidden = true
        let chatConversation: EMConversation
        if isSearch {
            chatConversation = self.searchArray[indexPath.row] as! EMConversation
        } else {
            chatConversation = self.conversationArray[indexPath.row] as! EMConversation
        }
        let selectedUnread = chatConversation.unreadMessagesCount
        var resultError: EMError? = nil
        chatConversation.markAllMessages(asRead: &resultError)
        let count = Int32(TSCurrentUserInfo.share.unreadCount.imMessage) - selectedUnread
        TSCurrentUserInfo.share.unreadCount.imMessage = Int(count)
        self.superViewController?.countUnreadInfo()

        let vc = ChatDetailViewController(conversationChatter: chatConversation.conversationId, conversationType:chatConversation.type)
        vc?.chatTitle = chatCell?.nameLabel.text

        if chatConversation.type == EMConversationTypeGroupChat && chatConversation.groupInfo != nil {
            vc?.groupOriginData = chatConversation.groupInfo! as NSDictionary
        }
        vc?.hidScreen = (chatCell?.hidScreenGroup)!
        navigationController?.pushViewController(vc!, animated: true)
        return
    }

    // MARK: - UIScrollViewDelegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.pViewController?.searchBar?.resignFirstResponder()
    }

    // MARK: - 注册环信聊天代理
    func registerNotifications() {
        self.unregisterNotifications()
        EMClient.shared().chatManager.add(self as EMChatManagerDelegate, delegateQueue: nil)
        EMClient.shared().groupManager.add(self as EMGroupManagerDelegate, delegateQueue: nil)
    }

    // MARK: - 移除聊天代理
    func unregisterNotifications() {
        EMClient.shared().chatManager.remove(self as EMChatManagerDelegate)
        EMClient.shared().groupManager.removeDelegate(self)
    }

    // MARK: - 环信收到消息回调
    func messagesDidReceive(_ aMessages: [Any]!) {
        // 刷新tabbar小红点
        NotificationCenter.default.post(name: NSNotification.Name.APNs.receiveNotice, object: nil, userInfo: nil)
        // 如果在当前页面就刷新一下本地列表
        if self.isCurrentVCAppear == true {
            // 群聊
            // 信息变更：请求对应的群组信息，然后刷新本地列表
            var groupIDs: [String] = []
            for item in aMessages {
                let message = item as! EMMessage
                if let extInfo = message.ext {
                    if let messageType = extInfo["type"] as? String {
                        if message.chatType == EMChatTypeGroupChat {
                            if messageType == "ts_group_change" {
                                groupIDs.append(message.conversationId)
                            } else  if  messageType == "ts_user_join" {
                                groupIDs.append(message.conversationId)
                            }
                        }
                    }
                }
            }
            self.getChatGroupsInfo(groupIDs: groupIDs)
            // 单聊 直接刷新本地数据
            self.reloadLocationChatListData()
        } else {
            for item in aMessages {
                let message = item as! EMMessage
                if let extInfo = message.ext {
                    if let messageType = extInfo["type"] as? String {
                        TSLogCenter.log.debug(messageType)
                        if messageType == "ts_group_create" {
                            self.getChatGroupsInfo(groupIDs: [extInfo["group_id"] as! String])
                        }
                    }
                }
            }
        }
    }

    func netStatusChange(noti: NSNotification) {
        switch TSReachability.share.reachabilityStatus {
        case .WIFI, .Cellular:
            self.reconnectionTSHYIMService()
            break
        case .NotReachable:
            break
        }
    }
    /// 重连失败
    func reconnectionTSHYIMServiceFalse() {
        self.tableView.mj_header.endRefreshing()
        if self.isCurrentVCAppear == true {
            NotificationCenter.default.post(name: NSNotification.Name.NavigationController.showIndicatorA, object: nil, userInfo: ["content": "提示信息_聊天链接错误".localized])
        }
    }
    func connectionStateDidChange(_ aConnectionState: EMConnectionState) {
        if aConnectionState == EMConnectionConnected {
        } else {
            self.reconnectionTSHYIMService()
        }
    }
    // MARK: - 重链接TS服务器获取登录信息
    func reconnectionTSHYIMService() {
        let appDeleguate = UIApplication.shared.delegate as! AppDeleguate
        appDeleguate.getHyPassword()
    }

    func autoLoginDidCompleteWithError(_ aError: EMError!) {
        TSLogCenter.log.debug(aError)
        TSLogCenter.log.debug("IM 链接失败")
        self.reconnectionTSHYIMService()
    }

    // MARK: - 获取环信会话列表
    func getHyChatList() {
        if EMClient.shared().isConnected == false {
            self.reconnectionTSHYIMService()
            return
        }
        if !EMClient.shared().isLoggedIn {
            self.reconnectionTSHYIMService()
            copyTableView?.isHidden = true
            tableView.isHidden = false
            if tableView.mj_header.isRefreshing() {
                tableView.mj_header.endRefreshing()
            }
        } else {
            let globalQueueDefault = DispatchQueue.global()
            globalQueueDefault.async {
                var resultError: EMError? = nil
                var myGroup = NSArray()
                if let hyOnlineGroup = EMClient.shared().groupManager.getJoinedGroupsFromServer(withPage: 0, pageSize: -1, error: &resultError) {
                    myGroup = hyOnlineGroup as NSArray
                } else {
                    // 有可能是在其他设备上登录了该账号
                }
                self.groupArray.removeAllObjects()
                self.groupArray.addObjects(from: myGroup as! [Any])
                var conversations = NSArray()
                if let hyOnlineConversations = EMClient.shared().chatManager.getAllConversations() {
                    conversations = hyOnlineConversations as NSArray
                }
                self.conversationArray.removeAllObjects()
                self.conversationArray.addObjects(from: conversations as! [Any])

                /// tempIndexArray里面装的是群聊数据在conversationArray数组里面的位置,存在的群会话
                /// 需要请求群信息的群id
                var groupIDs: [String] = []
                let enableGroups = NSMutableArray()
                if self.groupArray.count != 0 && self.conversationArray.count != 0 {
                        for itemCon in self.conversationArray {
                            let itemCon = itemCon as! EMConversation
                            if itemCon.type == EMConversationTypeGroupChat {
                                for itemGroup in self.groupArray {
                                    let itemGroup = itemGroup as! EMGroup
                                    if itemGroup.groupId == itemCon.conversationId {
                                        enableGroups.add(itemGroup)
                                        groupIDs.append(itemGroup.groupId)
                                        // 设置是否被屏蔽消息
                                        itemCon.isBlocked = itemGroup.isBlocked
                                        break
                                    }
                                }
                            }
                        }
                }
                self.groupArray = enableGroups
                if groupIDs.isEmpty == true {
                    /// 没有群组会话，就不请求群信息
                    DispatchQueue.main.async {
                        self.updataHyChatList()
                    }
                    return
                }
                // 当前没有群信息且有缓存的群信息就先显示在页面上，稍后网络更新完成后再更新
                let patch = NSHomeDirectory() + "/Documents/groupInfo.data"
                let getData = FileManager.default.contents(atPath: patch)
                if self.groupInfoDic.count == 0 && getData != nil, let dataDic = try? JSONSerialization.jsonObject(with: getData!, options: .mutableContainers)  as? NSDictionary {
                    // 将群信息绑定到会话中
                    self.groupInfoDic = NSMutableDictionary(dictionary: dataDic!)
                    for (_, itemCon) in self.conversationArray.enumerated().reversed() {
                        if let conversation = itemCon as? EMConversation {
                            if let groupInfo = self.groupInfoDic[conversation.conversationId] {
                                conversation.groupInfo = groupInfo as! [AnyHashable : Any]
                            }
                        }
                    }
                    self.updataHyChatList()
                }
                self.getChatGroupsInfo(groupIDs: groupIDs, isInit: true)
                }
        }
    }

    func uploadGroupInfoDicFromGroupInfoArray(groupInfoArray: NSArray, isInit: Bool) {
        if isInit == true {
            self.groupInfoDic.removeAllObjects()
        }
        for item in groupInfoArray {
            let groupDic = item as! NSDictionary
            let groupID = groupDic["id"] as! NSString
            self.groupInfoDic.setValue(groupDic, forKey: groupID as String)
        }
    }

    func updataHyChatList() {
        let hasNoLastMessageArray = NSMutableArray()
        var hasNoLastMessageListArray: [EMConversation] = NSMutableArray() as! [EMConversation]
        /// 暂时处理：如果进入聊天室，但是一条历史消息都没有，那么这个会话过滤并且在本地删除这个会话
        for (index, item) in self.conversationArray.enumerated() {
            let conversation = item as? EMConversation
            if conversation?.latestMessage == nil {
                // 如果不是IM助手就需要删除
                if TSAppConfig.share.localInfo.imHelper == Int((conversation?.conversationId)!) {
                    continue
                 }
                hasNoLastMessageArray.add(index)
                hasNoLastMessageListArray.append(conversation!)
            }
        }

        /// 删除会话
        EMClient.shared().chatManager.deleteConversations(hasNoLastMessageListArray, isDeleteMessages: true, completion: { (error) in
            if error == nil {

            }
        })
        for item in hasNoLastMessageArray.reversed() {
            self.conversationArray.removeObject(at: item as! Int)
        }
        var hyUnreadCount: Int32 = 0
        for con in self.conversationArray {
            let conver = con as? EMConversation
            let counttt = (conver?.unreadMessagesCount)
            hyUnreadCount += counttt!
        }
        /// 按照时间排序
        let sortArray = self.conversationArray.sortedArray(comparator: { (obj1, obj2) -> ComparisonResult in
            let conversation1: EMConversation = obj1 as! EMConversation
            let conversation2: EMConversation = obj2 as! EMConversation
            // 判断空消息的情况，放在最后
            if conversation1.latestMessage == nil {
                return ComparisonResult.orderedDescending//降序
            } else if conversation2.latestMessage == nil {
                return ComparisonResult.orderedDescending//降序
            }
            //按照时间排序
            if conversation1.latestMessage.localTime < conversation2.latestMessage.localTime {
                return ComparisonResult.orderedDescending//降序
            } else if conversation1.latestMessage.localTime > conversation2.latestMessage.localTime {
                return ComparisonResult.orderedAscending//升序
            } else {
                return ComparisonResult.orderedSame//相等
            }
        })
        self.conversationArray.removeAllObjects()
        self.conversationArray.addObjects(from: sortArray)

        if self.groupArray.count != 0 && self.conversationArray.count != 0 {
            for itemCon in self.conversationArray {
                let itemCon = itemCon as! EMConversation
                if itemCon.type == EMConversationTypeGroupChat {
                    for itemGroup in self.groupArray {
                        let itemGroup = itemGroup as! EMGroup
                        if itemGroup.groupId == itemCon.conversationId {
                            // 设置是否被屏蔽消息
                            itemCon.isBlocked = itemGroup.isBlocked
                            break
                        }
                    }
                }
            }
        }

        hyUnreadCount = hyUnreadCount < 1 ? 0 : hyUnreadCount
        TSCurrentUserInfo.share.unreadCount.imMessage = Int(hyUnreadCount)

        DispatchQueue.main.async {
            UnreadCountNetworkManager().unploadTabbarBadge()
        }
        guard let superVC = self.superViewController else {
            guard let superMessageVC = self.superMessagePop else {
                return
            }
            DispatchQueue.main.async {
                self.copyTableView?.isHidden = true
                self.tableView.isHidden = false
                if self.tableView.mj_header.isRefreshing() {
                    self.tableView.mj_header.endRefreshing()
                }
                self.tableView.reloadData()
            }
            return
        }
        superVC.countUnreadInfo()
        DispatchQueue.main.async {
            self.copyTableView?.isHidden = true
            self.tableView.isHidden = false
            if self.tableView.mj_header.isRefreshing() {
                self.tableView.mj_header.endRefreshing()
            }
            self.tableView.reloadData()
        }
    }

    // MAR: - 更新本地的环信回话列表
    // 主要用于发送消息/接收消息的时候直接从环信本地数据库读取数据，更新最后一条会话信息
    func reloadLocationChatListData() {
        let globalQueueDefault = DispatchQueue.global()
        globalQueueDefault.async {
            var myGroup = NSArray()
            if let hyOnlineGroup = EMClient.shared().groupManager.getJoinedGroups() {
                myGroup = hyOnlineGroup as NSArray
            } else {
                // 有可能是在其他设备上登录了该账号
            }
            self.groupArray.removeAllObjects()
            self.groupArray.addObjects(from: myGroup as! [Any])

            var conversations = NSArray()
            if let hyOnlineConversations = EMClient.shared().chatManager.getAllConversations() {
                conversations = hyOnlineConversations as NSArray
            }
            self.conversationArray.removeAllObjects()
            self.conversationArray.addObjects(from: conversations as! [Any])
            var infoEmptyGroupIDs: [String] = []
            // 记录需要展示的群ID（和会话ID相同）
            var showConGroupsIDs = NSMutableArray()
            for item in self.conversationArray {
                let emConversation = item as? EMConversation
                let converId = emConversation?.conversationId
                // 只有群类型才做以下处理
                if emConversation?.type == EMConversationTypeGroupChat {
                    if let locGroupInfo = self.groupInfoDic[converId] {
                        let locGroupInfoDic = locGroupInfo as! NSDictionary
                        emConversation?.groupInfo = locGroupInfoDic as! [String : Any]
                    } else {
                        // 请求群信息
                        // 先不显示出来，直接请求数据，然后刷新
                        self.conversationArray.remove(item)
                        infoEmptyGroupIDs.append(converId!)
                    }
                    showConGroupsIDs.append(emConversation?.conversationId)
                }
            }
            // 需要展示的群
            var showConGroups: [EMGroup] = []
            var showConGroupsDic: [String: EMGroup] = [:]
            for itemGroup in self.groupArray {
                let itemGroup = itemGroup as! EMGroup
                for itemID in showConGroupsIDs {
                        let itemID = itemID as! String
                    if itemID == itemGroup.groupId {
                        showConGroups.append(itemGroup)
                        showConGroupsDic.updateValue(itemGroup, forKey: itemID)
                    }
                }
            }
            self.groupArray = NSMutableArray(array: showConGroups)
            // 更新是否被屏蔽消息状态
            for itemCon in self.conversationArray {
                let itemCon = itemCon as! EMConversation
                if let group = showConGroupsDic[itemCon.conversationId] {
                        itemCon.isBlocked = group.isBlocked
                }
            }

            if infoEmptyGroupIDs.isEmpty == false {
                self.getChatGroupsInfo(groupIDs: infoEmptyGroupIDs)
            }
            self.updataHyChatList()
        }
    }

    // MARK: - 从TS服务器获取群聊信息
    func getChatGroupsInfo(groupIDs: [String], isInit: Bool = false) {
        if groupIDs.isEmpty == true {
            return
        }
        let groupIDString = groupIDs.joined(separator: ",")
        TSAccountNetworkManager().getHyGroupInfo(groupid: groupIDString, complete: { (data, status) in
            guard status && data != nil else {
                // 删除无效的群会话
                for itemCon in self.conversationArray.reversed() {
                    let itemCon = itemCon as! EMConversation
                    for itemGroupID in groupIDs {
                        if itemCon.conversationId == itemGroupID {
                            self.conversationArray.remove(itemCon)
                        }
                    }
                }
                self.updataHyChatList()
                return
            }
            self.uploadLocaGroupInfoFile(infos: data!)
            // 将群信息绑定到会话中
            for itemCon in self.conversationArray.reversed() {
                if let conversation = itemCon as? EMConversation {
                    if let groupInfo = self.groupInfoDic[conversation.conversationId] {
                        // 更新群信息
                        let groupInfo = groupInfo as! NSDictionary
                        conversation.groupInfo = groupInfo as! [AnyHashable : Any]
                        // 更新本地用户信息
                        let groupUsers = NSMutableArray(array: (groupInfo["affiliations"] as? NSArray)!)
                        let userList = Mapper<TSUserInfoModel>().mapArray(JSONObject: groupUsers)
                        for item in userList! {
                            let userInfo: TSUserInfoModel = item
                            TSDatabaseManager().user.saveUserInfo(userInfo)
                        }
                    }
                }
            }
            self.updataHyChatList()
        })
    }

    // MARK: - 更新本地群缓存
    func uploadLocaGroupInfoFile(infos: NSArray) {
        for info in infos {
            let infoDic = info as! NSDictionary
            let infoID = infoDic["id"] as! String
            self.groupInfoDic.setValue(infoDic, forKey: infoID)
        }
        // 保存到本地
        let json = JSON(self.groupInfoDic)
        let patch = NSHomeDirectory() + "/Documents/groupInfo.data"
        try! FileManager.default.createFile(atPath: patch, contents: json.rawData(), attributes: nil)
    }
    // MARK: - 接收到修改群头像和群名称的通知;退群以及解散群 改变数据源（不刷新就改变数据源）(这段代码很冗余，望后继者优化 =。=)
    func updataGroupInfo(notice: Notification) {
        let dict = notice.object as? NSDictionary
        let noticeType = "\(dict!["changeType"] ?? "")"
        if noticeType == "name" {
            let noticeId = "\(dict!["id"] ?? "")"
            let noticeName = "\(dict!["name"] ?? "")"
            /// 循环 groupInfoArray 匹配群id 修改群信息
            /// 可变字典不能存数组，不可变字典没法更改字段的值，所以需要转
            /// 有可能不在这个列表中
            if self.groupInfoDic[noticeId] != nil {
                let groupDic = self.groupInfoDic[noticeId] as! NSDictionary
                let groupPassDict = NSMutableDictionary(dictionary: groupDic)
                groupPassDict.setValue(noticeName, forKey: "name")
                self.groupInfoDic.setValue(groupPassDict, forKey: noticeId)
                // 需要更新conver的groupinfo
                for (_, item) in self.conversationArray.enumerated() {
                    let emConversation = item as? EMConversation
                    let converId = emConversation?.conversationId
                    if noticeId == converId {
                        emConversation?.groupInfo = groupPassDict as! [AnyHashable : Any]
                    }
                }
                tableView.reloadData()
            }
        } else if noticeType == "image" {
            let noticeId = "\(dict!["id"] ?? "")"
            let noticeImage = "\(dict!["imageUrl"] ?? "")"
            /// 循环 groupInfoArray 匹配群id 修改群信息
            /// 拿群会话头像
            let groupDic = self.groupInfoDic[noticeId] as! NSDictionary
            let groupPassDict = NSMutableDictionary(dictionary: groupDic)
            groupPassDict.setValue(noticeImage, forKey: "group_face")
             self.groupInfoDic.setValue(groupPassDict, forKey: noticeId)
            // 需要更新conver的groupinfo
            for (_, item) in self.conversationArray.enumerated() {
                let emConversation = item as? EMConversation
                let converId = emConversation?.conversationId
                if noticeId == converId {
                    emConversation?.groupInfo = groupPassDict as! [AnyHashable : Any]
                }
            }
            tableView.reloadData()
        } else if noticeType == "leaveGroup" || noticeType == "destroyGroup" {
            /// 退群 或者 解散群 都应该将这个群从数据源移除
            let noticeId = "\(dict!["id"] ?? "")"
            /// 循环 groupInfoArray 匹配群id 移除该群
            /// 移除操作应该倒序检测
            self.groupInfoDic.removeObject(forKey: noticeId)
            
            for (index, _) in self.groupArray.enumerated().reversed() {
                let group = groupArray[index] as? EMGroup
                if noticeId == group?.groupId {
                    /// 可变字典不能存数组，不可变字典没法更改字段的值，所以需要转
                    groupArray.removeObject(at: index)
                }
            }
            if isSearch {
                for (index, _) in self.searchArray.enumerated().reversed() {
                    let conver: EMConversation = self.searchArray[index] as! EMConversation
                    if conver.conversationId == noticeId {
                        self.searchArray.removeObject(at: index)
                    }
                }
            }
            for (index, _) in self.conversationArray.enumerated().reversed() {
                let conver: EMConversation = self.conversationArray[index] as! EMConversation
                if conver.conversationId == noticeId {
                    self.conversationArray.removeObject(at: index)
                }
            }
            tableView.reloadData()
        }
    }

    // MARK: - 搜索会话
    func searchChatList(keyWord: String) {
        if keyWord.isEmpty {
            isSearch = false
            copyTableView?.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        } else {
            self.searchArray.removeAllObjects()
            if self.copyTableView?.superview == nil {
                self.copyTableView?.frame = self.tableView.frame
                self.pViewController?.view.addSubview(copyTableView!)
            }
            for (_, item) in self.conversationArray.enumerated() {
                var chatName = self.getChatName(conver: item as! EMConversation)
                // 忽略字母大小写
                chatName = chatName.lowercased()
                let lowKey = keyWord.lowercased()
                if (chatName.range(of: lowKey)) != nil {
                    self.searchArray.add(item as! EMConversation)
                }
            }
            self.isSearch = true
            self.tableView.isHidden = true
            self.copyTableView?.isHidden = false
            self.copyTableView?.reloadData()
        }
    }
    /// 获取显示的昵称(单聊&&群聊)
    func getChatName(conver: EMConversation) -> String {
        var chatName = ""
        if conver.type == EMConversationTypeChat {
            if conver.conversationId == "admin" {
                chatName = "管理员"
            } else {
                let converIDInt = Int(conver.conversationId)
                if TSDatabaseManager().user.get(converIDInt!) != nil {
                    let hyUserInfo = TSDatabaseManager().user.get(converIDInt!)
                    chatName = (hyUserInfo?.name)!
                }
            }
        } else {
            let groupdict = conver.groupInfo
            let groupName = groupdict!["name"]
            var groupChatName = "\(groupName ?? "")"
            let menberNumber = groupdict!["affiliations_count"] ?? ""
            groupChatName = "\(groupName ?? "")(\(menberNumber))"
            chatName = groupChatName
        }
        return chatName
    }
    // MARK: 环信delegate
    func didReceiveLeavedGroup(_ aGroup: EMGroup!, reason aReason: EMGroupLeaveReason) {
        var showTitle = ""
        if aReason == EMGroupLeaveReasonBeRemoved {
            showTitle = "你被管理员移出 \(aGroup.subject!)"
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sendMessageReloadChatListVc"), object: nil)
        } else if aReason == EMGroupLeaveReasonUserLeave {
            showTitle = "你退出了 \(aGroup.subject!)"
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sendMessageReloadChatListVc"), object: nil)
        } else if aReason == EMGroupLeaveReasonDestroyed {
            showTitle = "\(aGroup.subject!) 被解散了"
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sendMessageReloadChatListVc"), object: nil)
        }
        if isCurrentVCAppear == true {
            TSIndicatorWindowTop.showDefaultTime(state: .faild, title: showTitle)
        }
    }
    /// 获取时间戳
    /// - Returns: 返回时间戳
    func getTimeStamp() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1_000)
    }

}
