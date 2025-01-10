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
    @IBOutlet weak var showDiariesTableView: UITableView!
    
    var user: User?
    var diaries: [DiaryContent] = []
   
    override func viewDidLoad() {
        super.viewDidLoad()
        showDiariesTableView.delegate = self
        showDiariesTableView.dataSource = self
        
        updateUI() // 初始化畫面
        
        // 確保 userID存在，呼叫 fetchUserInfo方法抓取使用者資訊(userInfo)，成功後呼叫updateUserInfo來更新畫面
        guard let userID = Auth.auth().currentUser?.uid else {
            print("‼ 錯誤：未找到使用者 ID")
            return
        }
        fetchUserInfo(userID: userID) { result in
            switch result {
            case .success(let user):
                self.updateUserInfoUI(user: user)
            case .failure(let error):
                print("‼ 錯誤：\(error.localizedDescription)")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.updateTableView(tableView: showDiariesTableView)
    }
    
    // 【設定UI】
    func updateUI() {
        super.view.backgroundColor = UIColor(red: 217/255, green: 234/255, blue: 253/255, alpha: 1)
        
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        
        showDiariesTableView.rowHeight = 100
        showDiariesTableView.backgroundColor = .clear
        
        self.navigationItem.hidesBackButton = true // 隱藏返回鍵
        
        // 在navigationItem右邊增加設定按鈕 - Pull Down Button
        settingMenu()

    }
    
    // 【設定按鈕清單】
    func settingMenu() {
        let menu = UIMenu(children: [
            UIAction(title: "登出", image: UIImage(systemName: "iphone.and.arrow.right.outward"), handler: { action in
                // 使用者登出
                do {
                    try Auth.auth().signOut()
                    print("✓ \(Auth.auth().currentUser?.uid ?? "")已登出")
                } catch {
                    self.showAlert(title: "錯誤", message: error.localizedDescription)
                }
                
                // 返回登入畫面
                self.performSegue(withIdentifier: "toLogInViewController", sender: self)
            })
        ])
        let saveButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), menu: menu)
        saveButton.tintColor = .white
        navigationItem.rightBarButtonItem = saveButton
    }
    
    // 【變更使用者資料】變更使用者名稱、相片
    func editUserInfo() {
        // 相片
        profileImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: <#T##Selector?#>)
        
        // 名稱
    }
    
    // 【取得userInfo】 取得上傳到firebase上的userInfo
    func fetchUserInfo(userID: String, completion: @escaping (Result<User, Error>) -> Void) {
        // 取得 Firestore 資料庫的引用
        let db = Firestore.firestore()
        // 指定要取得的文件路徑：userInfo集合下特定 userID的文件
        let userRef = db.collection("userInfo").document(userID)
        
        // 使用.getDocument從 Firestore 下載該文件的資料
        userRef.getDocument { document, error in
            if let error {
                print("‼ 錯誤（下載使用者資料失敗）：\(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 確認文件存在：document.exists是用來表示文件是否存在的屬性
            guard let document = document, document.exists else {
                print("‼ 錯誤：文件不存在")
                completion(.failure(NSError(domain: "DocumentNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                return
            }
            
            // 取得資料後，解析資料
            let data = document.data()
            let userName = data?["userName"] as? String
            let profileImageUrlString = data?["profileImageUrl"] as? String
            
            // 將資料存給user
            let user = User(userName: userName, userProfileImageURLString: profileImageUrlString)
            self.user = user
            
            // 如果成功抓取到資料，透過 completion 回傳成功，並傳遞 User物件
            completion(.success(user))
            print("✓ 使用者資料下載成功：\(user)")
        }
    }
    
    // 【更新使用者資訊】 更新畫面上的使用者資訊（頭貼跟名稱）
    func updateUserInfoUI(user: User) {
        profileImageView.sd_setImage(with: URL(string: user.userProfileImageURLString ?? ""))
        userNameLabel.text = "\(user.userName ?? "")的日記"
    }
    
    // 【取得日記】 取得firebase上的日記資料
    func fetchDiaries(completion: @escaping (Result<[DiaryContent]?, Error>) -> Void) {
        diaries.removeAll()
        
        let userID = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()
        let userDiariesRef = db.collection("userDiaries").document(userID).collection("diaries")
        userDiariesRef.getDocuments { snapshot, error in
            if let error {
                completion(.failure(error))
            } else {
                guard let documents = snapshot?.documents else {
                    print("✓ 日記文件抓取完成：沒有文件")
                    completion(.success([]))
                    return
                }
                
                for document in documents {
                    let data = document.data()
                    guard let date = data["diaryDate"] as? String else {
                        continue
                    }
                    
                    let diaryContent = DiaryContent(
                        diaryDate: date,
                        diaryImageURLString: data["diaryImageURLString"] as? String,
                        diaryImageID: data["diaryImageID"] as? String,
                        diaryText: data["diaryText"] as? String,
                        diaryID: document.documentID
                    )
                    self.diaries.append(diaryContent)
                }
                completion(.success(self.diaries))
            }
        }
    }
    
    // 更新TableView
    func updateTableView(tableView: UITableView) {
        fetchDiaries { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✓ 主頁日記下載完成")
                    self.diaries.sort { $0.diaryDate > $1.diaryDate }  //按照時間排序日記
                    self.showDiariesTableView.reloadData()
                case .failure(let error):
                    self.showAlert(title: "錯誤", message: "錯誤（下載日記發生錯誤：\(error.localizedDescription)）")
                }
            }
        }
    }
    
    // 【新增日記】新增日記的按鈕
    @IBAction func addDiary(_ sender: Any) {
        let theTrue = true
        performSegue(withIdentifier: "toEditViewController", sender: theTrue)
    }
    
    // 【傳送資料到編輯畫面】在編輯日記的畫面，利用變數isNewDiary判斷是新增日記或是修改日記、傳送選取的日記資料
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toEditViewController" {
            if let controller = segue.destination as? EditViewController {
                if let theBool = sender as? Bool {
                    controller.isNewDiary = theBool
                } else if let data = sender as? (DiaryContent, Bool) {
                    controller.showDairy = data.0
                    controller.isNewDiary = data.1
                }
            }
        }
    }
}

// 【TableView設定】
extension DiaryViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return diaries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "DiariesTableViewCell", for: indexPath) as? DiariesTableViewCell else { fatalError() }
        let diary = diaries[indexPath.row]
        cell.updateUI(show: diary)
        return cell
    }
    
    // 關閉row的選取效果、利用performSegue將日記用sender傳遞給prepare方法
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        let selectDiary = diaries[indexPath.row]
        let theFalse = false
        performSegue(withIdentifier: "toEditViewController", sender: (selectDiary, theFalse))
    }
    
    // 刪除日記
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let selectDiary = diaries[indexPath.row]
        if editingStyle == .delete {
            Task {
                await deleteDiary(diary: selectDiary)
            }
        }
    }
    
    func deleteDiary(diary: DiaryContent) async {
        if let diaryID = diary.diaryID, let userID = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            let diariesRef = db.collection("userDiaries").document(userID).collection("diaries").document(diaryID)
            do {
                try await diariesRef.delete()
                updateTableView(tableView: showDiariesTableView)
                print("✓ 已從主頁刪除firestore日記資料：\(diaryID)")
            } catch {
                print("‼ 在主頁刪除firestore日記資料失敗，\(error.localizedDescription)")
            }
        }
    }
}


