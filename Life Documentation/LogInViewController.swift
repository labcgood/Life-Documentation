//
//  LogInViewController.swift
//  Life Documentation
//
//  Created by Labe on 2024/10/25.
//

import UIKit
import FirebaseFirestore
import Firebase
import FirebaseAuth

class LogInViewController: UIViewController {

    @IBOutlet weak var frameView: UIView!
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    let auth = Auth.auth()
    var activeTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setKeyboardNotification() //監聽鍵盤活動
        updateUI() //初始化畫面
        isUserLogIn() //判斷是否有使用者登入中
    }
    
    // 點空白處收鍵盤
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }

    // 設定UI
    func updateUI() {
        // 輸入框背景view設定
        frameView.clipsToBounds = true
        frameView.layer.cornerRadius = 10
        
        // 隱藏返回鍵
        self.navigationItem.hidesBackButton = true
    }
    
    // 判斷是否有使用者登入，如果已登入狀態就直接進入日記頁面
    func isUserLogIn() {
        if auth.currentUser == nil {
            print("目前沒有用戶登入，用戶ID：\(auth.currentUser?.uid ?? "")")
            return
        } else {
            print("用戶\(auth.currentUser?.uid ?? "")登入中")
            self.performSegue(withIdentifier: "logInSuccsToDiaryViewController", sender: self)
        }
    }
    
    // 登入功能
    func logIn(email: String, password: String) {
        auth.signIn(withEmail: email, password: password) { Result, error in
            if let error {
                print("登入失敗：\(error.localizedDescription)")
                print("email:\(email),password:\(password)")
                let alert = UIAlertController(title: "錯誤", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else {
                print("用戶登入成功，ID：\(self.auth.currentUser?.uid ?? "")")
                self.performSegue(withIdentifier: "logInSuccsToDiaryViewController", sender: self)
            }
        }
    }
    
    // 登入按鍵（ 呼叫logIn() ）
    @IBAction func logIn(_ sender: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else { return }
        logIn(email: email, password: password)
    }
}
