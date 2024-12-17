//
//  LoginViewController.swift
//  Life Documentation
//
//  Created by Labe on 2024/9/29.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseStorage

class RegisterViewController: UIViewController {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var addImageButton: UIButton!
    @IBOutlet weak var frameView: UIView!
    @IBOutlet weak var signUpButton: UIButton!
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var checkPasswordTextField: UITextField!
    
    var haveProfileImage = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setKeyboardNotification() //監聽鍵盤活動
        updateUI() //初始化畫面
    }
    
    // 點空白處收鍵盤
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // 畫面消失時解除監聽
    override func viewDidDisappear(_ animated: Bool) {
        removeKeyboardNotification()
    }
    
    // 設定UI
    func updateUI() {
        // 頭貼imageView設定
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        
        // 輸入框背景view設定
        frameView.clipsToBounds = true
        frameView.layer.cornerRadius = 10
    }
    
    // 選擇頭貼
    @IBAction func selectProfilePic(_ sender: Any) {
        let controller = UIImagePickerController()
        controller.delegate = self
        present(controller, animated: true)
    }
    
    // 註冊帳號
    @IBAction func signUp(_ sender: Any) {
        
        // 先判斷密碼與確認密碼是否一致、是否設定頭貼、資料是否皆填妥
        // 以上沒有問題就呼叫registerUser來註冊帳號
        if passwordTextField.text != checkPasswordTextField.text {
            showAlert(title: "密碼確認失敗", message: "請檢查密碼是否輸入一致")
            print("密碼確認失敗")
        } else if haveProfileImage == false {
            showAlert(title: "請設定頭貼", message: nil)
            print("未設定頭貼")
        } else {
            // 先檢查使用者是否已填妥資料，並取得TextField輸入的資料
            guard let name = nameTextField.text, !name.isEmpty,
                  let email = emailTextField.text, !email.isEmpty,
                  let password = passwordTextField.text, !password.isEmpty else {
                showAlert(title: "資料填寫不完整", message: nil)
                print("資料填寫不完整")
                return
            }
            registerUser(name: name, email: email, password: password)
        }
    }
    
    // 創建使用者 - 在「註冊帳號」Button裡呼叫
    func registerUser(name: String ,email: String, password: String) {
        
        // 使用Auth.auth()的createUser方法來註冊使用者（這是Firebase的方法）
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            // 通知：註冊失敗
            if let error {
                self.showAlert(title: "註冊失敗", message: error.localizedDescription)
                print("註冊失敗：\(error.localizedDescription)")
                return
            }
            
            // 通知：註冊成功
            self.showAlert(title: "註冊成功", message: nil)
            print("註冊成功，使用者ID：\(authResult?.user.uid ?? "")")
            
            // 確保資料（為了方便使用資料，這邊都先用guard let做確保）
            // 在「註冊帳號」Button裡會確定使用者有選取頭貼
            guard let profileImage = self.profileImageView.image else {
                print("錯誤：頭貼缺失")
                return
            }
            // 上面已經註冊成功，這邊應該要有使用者 ID，所以使用 authResult來取得 ID
            guard let userID = authResult?.user.uid else {
                print("錯誤：無法取得使用者ID")
                return
            }
            
            // 呼叫上傳頭貼的function，以取得頭貼的url
            // 用switch方法來判斷成功跟失敗要做什麼事
            self.uploadProfileImage(userID: userID, profileImage: profileImage) { result in
                switch result {
                // 成功：取得 url後就呼叫 saveUserInfo方法，將使用者的 userName跟 profileImageUrl上傳到 firestore database裡儲存，方便以後使用者登入都可以抓取使用
                case .success(let profileImageUrlString):
                    self.saveUserInfo(userID: userID, userName: name, profileImageUrlString: profileImageUrlString) { error in
                        if let error {
                            print("使用者資料儲存失敗：\(error.localizedDescription)")
                        } else {
                            print("使用者資料儲存成功")
                            self.performSegue(withIdentifier: "registerSuccsToDiaryViewController", sender: self)
                        }
                    }
                // 失敗：報錯
                case .failure(let error):
                    print("錯誤（頭貼上傳失敗）：\(error.localizedDescription)")
                }
            }
        }
    }
    
    // 上傳頭貼圖片
    func uploadProfileImage(userID: String, profileImage: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 建立 storage文件夾
        let storageRef = Storage.storage().reference().child("\(userID)/userInfo/profilePicture.jpg")
        
        
        // 將 UIImage轉換成 JPEG格式的 Data，以便上傳
        // compressionQuality設定為 0.8，表示圖像的壓縮品質為 80%。數值範圍是 0.0 到 1.0，數值越高，品質越好，檔案越大
        guard let imageData = profileImage.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "InvalidImage", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unable to process image"])))
            return
        }
        
        // putData 是 Firebase Storage 上傳檔案的 API，這裡上傳 imageData（圖片的二進位資料），metadata 為 nil，表示不額外指定任何檔案的 Meta 資訊
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error {
                completion(.failure(error))
                print("錯誤（頭貼上傳失敗）：\(error.localizedDescription)")
                return
            }
            
            // 上傳成功後，要取得頭貼的url，downloadURL是 Firebase Storage提供的 API，用於取得上傳檔案的公開訪問 url
            storageRef.downloadURL { url, error in
                // 失敗：報錯
                if let error {
                    completion(.failure(error))
                    print("錯誤（頭貼url取得失敗）：\(error.localizedDescription)")
                    return
                }
                // 成功：成功取得url的字串後，返回該 url給調用方
                if let downloadURLString = url?.absoluteString {
                    completion(.success(downloadURLString))
                    print("頭貼上傳成功")
                }
            }
        }
    }
    
    // 儲存使用者資料到firebase(存到firestore database裡)
    func saveUserInfo(userID: String, userName: String, profileImageUrlString: String, completion: @escaping (Error?) -> Void) {
        // 在firestore建立資料夾
        let db = Firestore.firestore()
        let userRef = db.collection("userInfo").document(userID)
        
        // 要儲存的資料
        let userInfo: [String: Any] = [
            "userName": userName,
            "profileImageUrl": profileImageUrlString
        ]
        
        // 將資料儲存進去
        userRef.setData(userInfo) { error in
            completion(error)
        }
    }
}


// 擴展RegisterViewController，取得選取相片的功能
extension RegisterViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // 從相簿裡選擇頭貼相片
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        profileImageView.image = info[.originalImage] as? UIImage
        haveProfileImage = true
        dismiss(animated: true)
    }
}
