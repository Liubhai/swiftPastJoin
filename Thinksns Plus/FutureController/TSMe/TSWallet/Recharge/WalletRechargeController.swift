//
//  WalletRechargeController.swift
//  ThinkSNS +
//
//  Created by GorCat on 2018/2/5.
//  Copyright © 2018年 ZhiYiCX. All rights reserved.
//
//  钱包充值

import UIKit

/// 支付结果
enum PayState: String {
    /// 错误的支付凭证
    case errorToken
    /// 支付成功
    case success
    /// 支付失败
    case fail
    /// 支付取消
    case cancel
}

class WalletRechargeController: UITableViewController {

    /// 金额选择按钮视图高度
    @IBOutlet weak var chooseMoneyViewHeight: NSLayoutConstraint!
    /// 金额选择按钮视图
    @IBOutlet weak var chooseMoneyView: ChooseMoneyButtonView!

    /// 选择充值方式 cell
    @IBOutlet weak var rechargeTypeCell: UITableViewCell!
    /// 确认按钮
    @IBOutlet weak var buttonForSure: TSColorLumpButton!
    /// 金额输入框
    @IBOutlet weak var textfieldForMoney: UITextField!

    var config = TSRechargeModel() {
        didSet {
            loadConfig()
        }
    }

    /// 当前充值金额
    var rechargeMoney: Double? {
        didSet {
            checkSureButtonStatus()
        }
    }
    /// 当前充值方式
    var rechargeType: WalletRechargeType? {
        didSet {
            checkSureButtonStatus()
        }
    }

    // MARK: - Lifecycle

    class func vc() -> WalletRechargeController {
        let sb = UIStoryboard(name: "WalletRechargeController", bundle: nil)
        let vc = sb.instantiateInitialViewController() as! WalletRechargeController
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loading()
        loadData()
        setUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(textFildDidChanged(notification:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
    }

    // MARK: - UI

    func loadData() {
        WalletNetworkManager.getConfig { [weak self] (status, message, model) in
            guard let model = model else {
                self?.loadFaild(type: .network)
                return
            }
            self?.config = TSRechargeModel(model: model)
            self?.endLoading()
        }
    }

    func loadConfig() {
        chooseMoneyView.array = config.options

        chooseMoneyViewHeight.constant = chooseMoneyView.height
        chooseMoneyView.setNeedsLayout()
        chooseMoneyView.layoutIfNeeded()
        tableView.reloadData()
    }

    func setUI() {
        title = "显示_充值".localized
        buttonForSure.sizeType = .large

        chooseMoneyView.set { [weak self] (money) in
            self?.textfieldForMoney.endEditing(true)
            self?.rechargeMoney = Double(money)
            self?.textfieldForMoney.text = ""
        }
    }

    func endEditing() {
        textfieldForMoney.endEditing(true)
    }

    func textFildDidChanged(notification: Notification) {
        // 输入框类型 key
        guard let textField = notification.object as? UITextField else {
            return
        }
        if textField == self.textfieldForMoney {
            TSAccountRegex.checkAndUplodTextFieldText(textField: textField, stringCountLimit: 8)
            chooseMoneyView.clearSelectedStatus()
            if let moneyNumber = Double(textField.text ?? "") {
                rechargeMoney = moneyNumber
            }
        }
    }

    /// 点击了确认按钮
    @IBAction func sureButtonTaped(_ sender: TSColorLumpButton) {
        // 收起键盘
        endEditing()
        guard let rechargeType = rechargeType else {
            TSLogCenter.log.debug("支付方式为 nil")
            return
        }
        guard let rechargeMoney = rechargeMoney else {
            TSLogCenter.log.debug("支付金额为 nil")
            return
        }
        // 计算出 CNY 分单位的金额数
        let moneyFen = Int(rechargeMoney * 100)
        // 禁用确认按钮
        sender.isUserInteractionEnabled = false
        // 2. 向后台获取支付凭证
        WalletNetworkManager.createRecharge(type: rechargeType.rawValue, amount: moneyFen, extra: nil) { [weak self] (status, message, info) in
            // 2.1 获取凭证出错
            guard let info = info, let order = info.pingOrder as? NSObject else {
                // 启用确认按钮
                sender.isUserInteractionEnabled = true
                // 显示错误信息
                self?.processPayCallback(message: .errorToken)
                return
            }
            // 3. 向支付三方发起支付，appURLScheme 为 app 回调地址
            // 需要读取app实际配置的URLScheme,否则会导致SDK回调异常
            // sot todo
            /*
            let appURLScheme = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
            Pingpp.createPayment(order, viewController: self, appURLScheme: appURLScheme, withCompletion: { [weak self] (message: String?, error: PingppError?) in
                // 启用确认按钮
                sender.isUserInteractionEnabled = true
                // 3.1 支付出错
                guard let message = message else {
                    self?.processPayCallback(message: .fail)
                    return
                }
                // 3.2 返回了未知的支付方式状态
                guard let payState = PayState(rawValue: message) else {
                    TSLogCenter.log.debug("返回了未知的支付方式状态")
                    return
                }
                // 3.3 支付完成，通知后台交易结束
                self?.processPayCallback(message: payState)
                if payState == .success {
                    WalletNetworkManager.getOrder(orderId: info.order.id, complete: { (_, _, _) in
                    })
                }
            })
 */
            TSLogCenter.log.debug(info)
        }
    }

    /// 处理支付回调信息，显示状态弹窗
    func processPayCallback(message: PayState) {
        var state: LoadingState
        var titelString = ""
        switch message {
        case .errorToken:
            // 0. 获取支付凭据失败
            state = .faild
            titelString = "显示_获取凭证失败".localized
        case .success:
            // 1. 支付成功
            state = .success
            titelString = "显示_支付成功".localized
        case .fail:
            // 2. 支付失败
            state = .faild
            titelString = "显示_支付失败".localized
        case .cancel:
            // 3. 取消支付
            state = .success
            titelString = "显示_取消支付".localized
        }
        // 显示状态弹窗
        let alert = TSIndicatorWindowTop(state: state, title: titelString)
        alert.show(timeInterval: TSIndicatorWindowTop.defaultShowTimeInterval)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        textfieldForMoney.endEditing(true)
        let cell = tableView.cellForRow(at: indexPath)
        // 1.点击了充值方式选择 cell
        if cell == rechargeTypeCell {
            let alert = TSAlertController(title: nil, message: nil, style: .actionsheet)
            for type in config.rechargeTypes {
                var title = ""
                switch type {
                case .alipay:
                    title = "支付宝支付"
                case .wx:
                    title = "微信支付"
                }
                alert.addAction(TSAlertAction(title: title, style: .default, handler: { [weak self] (_) in
                    self?.rechargeType = type
                }))
            }
            if !alert.actions.isEmpty {
                present(alert, animated: false, completion: nil)
            } else {
                alert.addAction(TSAlertAction(title: "当前未支持任何充值方式", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alert, animated: false, completion: nil)
                }
            }
        }
    }

    /// 检查确定按钮的状态
    func checkSureButtonStatus() {
        if rechargeMoney == nil || rechargeMoney == 0 {
            buttonForSure.isEnabled = false
            return
        }

        if rechargeType == nil {
            buttonForSure.isEnabled = false
            return
        }
        buttonForSure.isEnabled = true
    }
}

extension WalletRechargeController: LoadingViewDelegate {

    func loadingBackButtonTaped() {
        navigationController?.popViewController(animated: true)
    }

    func reloadingButtonTaped() {
        loadData()
    }
}
