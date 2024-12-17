//
//  Utils.swift
//  Life Documentation
//
//  Created by Labe on 2024/10/26.
//
import UIKit

// 因為偵測鍵盤的方法在很多地方都可以用到，如果在每個controller都要寫一次的話會讓code太多，所以直接用擴展的方式處理
// 擴展 UIViewController，用來處理鍵盤通知
extension UIViewController {
    
    // 設置鍵盤通知，讓子類別可以方便地使用「根據鍵盤的顯示、收起的動作來決定移動View」的方法
    func setKeyboardNotification() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardShown), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardHidden), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // 移除監聽，減少記憶體洩漏的風險
    func removeKeyboardNotification() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // 鍵盤出現時將 view 上移
    @objc func keyboardShown(notification: Notification) {
        guard let activeTextField = findActiveTextField(in: self.view) else { return }
        
        let info = notification.userInfo! as NSDictionary
        let keyboardSize = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let keyboardTopY = self.view.frame.height - keyboardSize.height
        let editingTextFieldBottomY = activeTextField.convert(activeTextField.bounds, to: self.view).maxY
        let targetY = editingTextFieldBottomY - keyboardTopY
        
        if self.view.frame.minY >= 0 {
            if targetY > 0 {
                UIView.animate(withDuration: 0.25) {
                    self.view.frame = CGRect(x: 0, y: -(targetY + 80), width: self.view.frame.width, height: self.view.frame.height)
                }
            }
        }
    }
    
    // 鍵盤隱藏時將 view 移回原位
    @objc func keyboardHidden(notification: Notification) {
        UIView.animate(withDuration: 0.25) {
            self.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        }
    }
    
    // 尋找當前使用的 UITextField
    private func findActiveTextField(in view: UIView) -> UITextField? {
        // 利用迴圈尋找正在活動中的view
        for subview in view.subviews {
            // 如果活動中的view是UITextField的話，就回傳
            if let textField = subview as? UITextField, textField.isFirstResponder {
                return textField
                // 如果不是的話就再調用一次自己(function)尋找子view中的子view是不是UITextField，找到就回傳
            } else if let foundTextField = findActiveTextField(in: subview) {
                return foundTextField
            }
        }
        return nil
    }
}

// 因為重複在各個View Controller中使用到AlertController，且用法簡單，所以直接擴展在UIViewController裡方便使用
extension UIViewController {
    // 顯示提示、警告
    func showAlert(title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }
}
