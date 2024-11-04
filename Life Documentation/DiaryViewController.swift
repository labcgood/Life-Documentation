//
//  DiaryViewController.swift
//  Life Documentation
//
//  Created by Labe on 2024/10/4.
//

import UIKit
import FirebaseFirestore
import Firebase
import FirebaseAuth
import SDWebImage

class DiaryViewController: UIViewController {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    let auth = Auth.auth()
    var user: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.navigationItem.hidesBackButton = true // 隱藏返回鍵
        updateUI() // 初始化畫面
        
        // 確保 userID存在，呼叫 fetchUserInfo方法抓取使用者資訊(userInfo)，成功後呼叫updateUserInfo來更新畫面
        guard let userID = auth.currentUser?.uid else {
            print("錯誤：未找到使用者 ID")
            return
        }
        fetchUserInfo(userID: userID) { result in
            switch result {
            case .success(let user):
                self.updateUserInfo(user: user)
            case .failure(let error):
                print("錯誤：\(error.localizedDescription)")
            }
        }
    }
    
    // 取得上傳到firebase上的userInfo
    func fetchUserInfo(userID: String, completion: @escaping (Result<User, Error>) -> Void) {
        // 取得 Firestore 資料庫的引用
        let db = Firestore.firestore()
        // 指定要取得的文件路徑：userInfo集合下特定 userID的文件
        let userRef = db.collection("userInfo").document(userID)
        
        // 使用.getDocument從 Firestore 下載該文件的資料
        userRef.getDocument { document, error in
            if let error {
                print("錯誤（下載使用者資料失敗）：\(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 確認文件存在：document.exists是用來表示文件是否存在的屬性
            guard let document = document, document.exists else {
                print("錯誤：文件不存在")
                completion(.failure(NSError(domain: "DocumentNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                return
            }
            
            // 取得資料後，解析資料
            let data = document.data()
            let userName = data?["userName"] as? String
            let profileImageUrlString = data?["profileImageUrl"] as? String
            
            // 將資料存給user
            let user = User(userName: userName, userProfileImageUrlString: profileImageUrlString)
            self.user = user
            
            // 如果成功抓取到資料，透過 completion 回傳成功，並傳遞 User物件
            completion(.success(user))
            print("使用者資料下載成功：\(user)")
        }
    }
    
    // 更新畫面上的使用者資訊（頭貼跟名稱）
    func updateUserInfo(user: User) {
        print("使用者名稱：\(user.userName ?? "")")
        profileImageView.sd_setImage(with: URL(string: user.userProfileImageUrlString ?? ""))
        userNameLabel.text = "\(user.userName ?? "")的日記"
    }
    
    // 設定UI
    func updateUI() {
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
    }
    
    // 登出
    @IBAction func logOut(_ sender: Any) {
        do {
            try auth.signOut()
            print("\(auth.currentUser?.uid ?? "")已登出")
        } catch {
            showAlert(title: "錯誤", message: error.localizedDescription)
        }
        
        // 返回登入畫面
        performSegue(withIdentifier: "toLogInViewController", sender: self)
    }
}
