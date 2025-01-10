//
//  EditViewController.swift
//  Life Documentation
//
//  Created by Labe on 2024/11/9.
//

import UIKit
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

class EditViewController: UIViewController {
    
    
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var addImageButton: UIButton!
    @IBOutlet weak var diaryTextView: UITextView!
    
    var currentDiary = DiaryContent(diaryDate: "")
    var showDairy = DiaryContent(diaryDate: "")
    var isNewDiary = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        diaryTextView.delegate = self
        
        updataUI() // 設定UI
        setTextViewKeyboardNotification() // 監聽鍵盤
    }
    
    // 畫面消失時解除鍵盤監聽
    override func viewDidDisappear(_ animated: Bool) {
        removeTextViewKeyboardNotification()
    }
    
    // 點空白處收鍵盤
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // 【設定畫面】
    func updataUI() {
        // 加入儲存日記的按鈕
        let saveButton = UIBarButtonItem(title: "儲存", style: .plain, target: self, action: #selector(saveNewDiary))
        navigationItem.rightBarButtonItem = saveButton
        
        // 鍵盤上方新增按鈕-收回鍵盤
        diaryTextView.inputAccessoryView = createToolbar()
        
        // 判斷日記是新增或修改，再依狀況顯示畫面
        switch isNewDiary {
        // 如果是新增日記，就顯示初始畫面
        case true:
            print("編輯新的日記")
            // 設定datepicker
            datePicker.maximumDate = Date.now
            
            // textView placeholder效果
            diaryTextView.textColor = .gray
            diaryTextView.text = "請輸入文字......"
            
        // 如果是修改日記就將日記資料帶入畫面
        case false:
            print("編輯舊的日記")
            // 日期
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: showDairy.diaryDate) {
                datePicker.date = date
            } else {
                showAlert(title: "錯誤", message: "日期轉換失敗")
            }
            
            // 文字
            if let diaryText = showDairy.diaryText {
                diaryTextView.text = diaryText
            } else {
                diaryTextView.textColor = .gray
                diaryTextView.text = "請輸入文字......"
            }
            
            // 照片
            if let diaryImageURLString = showDairy.diaryImageURLString {
                imageView.sd_setImage(with: URL(string: diaryImageURLString))
            }
        }
    }
    
    // 【儲存按鈕】儲存編輯的日記
    @objc func saveNewDiary() {
        // 如果是編輯舊日記就先把原本的資料刪除，重新上傳一筆資料
        if isNewDiary == false {
            Task {
                await deleteOldData()
            }
        }
        
        // 【日期】紀錄當前日記的日期
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dairyTime = formatter.string(from: datePicker.date)
        currentDiary.diaryDate = dairyTime
        
        // 【文字】取得日記文字
        if diaryTextView.textColor == .black {
            currentDiary.diaryText = diaryTextView.text
        } else {
            currentDiary.diaryText = nil
        }
        
        // 【照片】如果沒有設定相片，將currentDiary的diaryImageURLString設成nil
        if imageView.image == nil {
            self.currentDiary.diaryImageURLString = nil
            
            // 如果日誌填寫完整，把日記內容上傳到firebase
            if self.currentDiary.diaryImageURLString == nil && self.currentDiary.diaryText == nil {
                self.showAlert(title: "日記填寫不完整", message: "請選擇圖片或輸入文字")
                return
            } else {
                // 上傳日記
                uploadDiary(diaryContent: self.currentDiary) { result in
                    switch result {
                    case .success:
                        self.showSuccessAlert()
                        print("✓ 日記上傳成功")
                    case .failure(let error):
                        print("‼ 日記上傳失敗，原因：\(error.localizedDescription)")
                    }
                }
            }
            
        } else {
            // 上傳相片並取得圖片的url
            guard let userID = Auth.auth().currentUser?.uid else { return }
            uploadDiaryImage(userID: userID, diaryImage: imageView.image!) { result in
                switch result {
                case .success(let diaryImageURLString):
                    self.currentDiary.diaryImageURLString = diaryImageURLString
                    print(self.currentDiary)
                    
                    // 如果日誌填寫完整，把日記內容上傳到firebase
                    if self.currentDiary.diaryImageURLString == nil && self.currentDiary.diaryText == nil {
                        self.showAlert(title: "日記填寫不完整", message: "請選擇圖片或輸入文字")
                        return
                    } else {
                        // 上傳日記
                        self.uploadDiary(diaryContent: self.currentDiary) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    self.showSuccessAlert()
                                    print("✓ 日記上傳成功")
                                case .failure(let error):
                                    print("‼ 日記上傳失敗，原因：\(error.localizedDescription)")
                                }
                            }
                        }
                    }
                case .failure(let error):
                    self.showAlert(title: "錯誤", message: "日記圖片上傳失敗：\(error.localizedDescription)")
                    print("‼ 日記圖片上傳失敗：\(error.localizedDescription)")
                }
            }
        }
    }
    
    // 【上傳圖片】
    func uploadDiaryImage(userID: String, diaryImage: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 建立 storage文件夾，把相片存在diary資料夾裡
        let imageID = "\(UUID().uuidString).jpg"
        currentDiary.diaryImageID = imageID
        let storageRef = Storage.storage().reference().child("\(userID)/diary/\(imageID)")
        
        // 將 UIImage轉換成 JPEG格式的 Data，以便上傳
        guard let imageData = diaryImage.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "InvalidImage", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unable to process image"])))
            return
        }
        
        // putData 是 Firebase Storage 上傳檔案的 API，這裡上傳 imageData（圖片的二進位資料），metadata 為 nil，表示不額外指定任何檔案的 Meta 資訊
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error {
                completion(.failure(error))
                print("‼ 日記圖片上傳失敗：\(error.localizedDescription)")
                return
            }
            
            // 上傳成功後，要取得頭貼的url，downloadURL是 Firebase Storage提供的 API，用於取得上傳檔案的公開訪問 url
            storageRef.downloadURL { url, error in
                // 失敗：報錯
                if let error {
                    completion(.failure(error))
                    print("‼ 日記圖片url取得失敗：\(error.localizedDescription)")
                    return
                }
                // 成功：成功取得url的字串後，返回該 url給調用方
                if let downloadURLString = url?.absoluteString {
                    completion(.success(downloadURLString))
                    print("✓ 日記圖片上傳成功")
                }
            }
        }
    }
    
    // 【上傳日記】上傳日記到firebase
    func uploadDiary(diaryContent: DiaryContent, completion: @escaping (Result<Void, Error>) -> Void) {
        // 準備要上傳的資料（因為上傳firebase的資料不能是nil，所以沒有的部分(照片或文字)就不上傳相對應的資料）
        var diaryData: [String: Any] = [
            "diaryDate": diaryContent.diaryDate
        ]
        
        if let imageURL = diaryContent.diaryImageURLString {
            diaryData["diaryImageURLString"] = imageURL
        }
        
        if let imageID = diaryContent.diaryImageID {
            diaryData["diaryImageID"] = imageID
        }
        
        if let text = diaryContent.diaryText {
            diaryData["diaryText"] = text
        }
        
        if let diaryID = diaryContent.diaryID {
            diaryData["diaryID"] = diaryID
        }
        
        // 初始化 Cloud Firestore後建立資料路徑，使用addDocument方法將日記資料上傳
        let db = Firestore.firestore()
        let userID = Auth.auth().currentUser?.uid ?? ""
        let diariesRef = db.collection("userDiaries").document(userID).collection("diaries")
        
        diariesRef.addDocument(data: diaryData) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // 【提示】上傳成功跳出提示，並在點擊"好的"後回到主頁
    func showSuccessAlert() {
        let alertVC = UIAlertController(title: "日記上傳成功", message: nil, preferredStyle: .alert)
        let alerAction = UIAlertAction(title: "好的", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        }
        alertVC.addAction(alerAction)
        self.present(alertVC, animated: true)
    }
    
    // 【刪除舊資料】刪除firebase上的舊日記資料及上傳的照片，以便重新上傳新資料
    func deleteOldData() async {
        // 刪除上傳的照片
        if let diaryImageID = showDairy.diaryImageID, let userID = Auth.auth().currentUser?.uid {
            let storegeRef = Storage.storage().reference().child("\(userID)/diary/\(diaryImageID)")
            print(storegeRef.fullPath)
            storegeRef.delete { error in
                if let error {
                    self.showAlert(title: "錯誤", message: "未成功刪除照片：\(error.localizedDescription)")
                } else {
                    print("✓ 已刪除Storage圖片：\(diaryImageID)")
                }
            }
        }
        
        // 刪除上傳的日記
        if let diaryID = showDairy.diaryID, let userID = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            let diariesRef = db.collection("userDiaries").document(userID).collection("diaries").document(diaryID)
            do {
                try await diariesRef.delete()
                print("✓ 已刪除firestore日記資料：\(diaryID)")
            } catch {
                print("‼ 刪除firestore日記資料失敗，\(error.localizedDescription)")
            }
        }
    }
    
    // 【新增相片】
    @IBAction func addImage(_ sender: Any) {
        let controller = UIImagePickerController()
        controller.delegate = self
        present(controller, animated: true)
    }
}

// 【TextView設定】相關設定、功能
extension EditViewController: UITextViewDelegate {
    
    // 依據TextView的編輯狀態做外觀改變
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .gray {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    // 結束編輯時，如果TextView為空，就恢復初始設定
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.textColor = .gray
            textView.text = "今天的心情......"
        }
    }
    
    // 編輯及結束編輯TextView時，調整畫面，讓TextView不要被鍵盤擋住
    func setTextViewKeyboardNotification() {
        let center: NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(textViewKeyboardShown), name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(textViewKeyboardHidden), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func removeTextViewKeyboardNotification() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func textViewKeyboardShown(notification: Notification) {
        let info: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardSize = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let targetY = keyboardSize.height
        self.view.frame = CGRect(x: 0, y: Int(-targetY), width: Int(self.view.frame.width), height: Int(self.view.frame.height))
    }
    
    @objc func textViewKeyboardHidden(notification: Notification) {
        UIView.animate(withDuration: 0.25) {
            self.view.frame = CGRect(x: 0, y: 0, width: Int(self.view.frame.width), height: Int(self.view.frame.height))
        }
    }
    
    // 生成UIToolbar，用來在鍵盤上方新增工具列
    func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit() //自動調整工具欄的大小以配合鍵盤的寬度。
        
        // 完成文字編輯後收起鍵盤的按鈕，這邊製作了一個文字跟一個圖示的版本
        let doneButton = UIBarButtonItem(title: "收回鍵盤", style: .done, target: self, action: #selector(dismissKeyboard))
        let doneImageButton = UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .done, target: self, action: #selector(dismissKeyboard))
        // 生出一個佔位空間，排在最前面，讓其他按鈕可以靠右邊排列
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // 設定按鈕顏色
        doneButton.tintColor = .black
        doneImageButton.tintColor = .black
        
        // 把剛剛生成的按鈕依序放進toolbar
        toolbar.items = [flexibleSpace, doneButton, doneImageButton]
        return toolbar
    }
    
    @objc func dismissKeyboard() {
        self.diaryTextView.resignFirstResponder()
    }
}

// 【選取相片】擴展選取相片的功能
extension EditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imageView.image = info[.originalImage] as? UIImage
        dismiss(animated: true)
    }
}
