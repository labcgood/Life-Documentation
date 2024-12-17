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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        diaryTextView.delegate = self
        
        updataUI() // 設定UI
        setTextViewKeyboardNotification() // 監聽鍵盤
    }
    
    // 畫面消失時解除監聽
    override func viewDidDisappear(_ animated: Bool) {
        removeTextViewKeyboardNotification()
    }
    
    // 點空白處收鍵盤
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    func updataUI() {
        // 加入儲存日記的按鈕
        let saveButton = UIBarButtonItem(title: "儲存", style: .plain, target: self, action: #selector(saveNewDiary))
        navigationItem.rightBarButtonItem = saveButton
        
        // 設定datepicker
        datePicker.maximumDate = Date.now
        
        // textView placeholder效果
        diaryTextView.textColor = .gray
        diaryTextView.text = "今天的心情......"
        
        // 鍵盤上方新增按鈕-收回鍵盤
        diaryTextView.inputAccessoryView = createToolbar()
        
    }
    
    // 儲存新增的日記要做的事
    @objc func saveNewDiary() {
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
                        print("日記上傳成功")
                    case .failure(let error):
                        print("日記上傳失敗，原因：\(error.localizedDescription)")
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
                                    let alertVC = UIAlertController(title: "日記上傳成功", message: nil, preferredStyle: .alert)
                                    let alerAction = UIAlertAction(title: "好的", style: .default) { _ in
                                        self.navigationController?.popViewController(animated: true)
                                    }
                                    alertVC.addAction(alerAction)
                                    self.present(alertVC, animated: true)
                                    print("日記上傳成功")
                                case .failure(let error):
                                    print("日記上傳失敗，原因：\(error.localizedDescription)")
                                }
                            }
                        }
                    }
                case .failure(let error):
                    self.showAlert(title: "錯誤", message: error.localizedDescription)
                    print("錯誤（日記圖片上傳失敗）：\(error.localizedDescription)")
                }
            }
        }
    }
    
    // 上傳圖片
    func uploadDiaryImage(userID: String, diaryImage: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 建立 storage文件夾，把相片存在diary資料夾裡
        let storageRef = Storage.storage().reference().child("\(userID)/diary/\(UUID().uuidString).jpg")
        
        // 將 UIImage轉換成 JPEG格式的 Data，以便上傳
        guard let imageData = diaryImage.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "InvalidImage", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unable to process image"])))
            return
        }
        
        // putData 是 Firebase Storage 上傳檔案的 API，這裡上傳 imageData（圖片的二進位資料），metadata 為 nil，表示不額外指定任何檔案的 Meta 資訊
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error {
                completion(.failure(error))
                print("錯誤（日記圖片上傳失敗）：\(error.localizedDescription)")
                return
            }
            
            // 上傳成功後，要取得頭貼的url，downloadURL是 Firebase Storage提供的 API，用於取得上傳檔案的公開訪問 url
            storageRef.downloadURL { url, error in
                // 失敗：報錯
                if let error {
                    completion(.failure(error))
                    print("錯誤（日記圖片url取得失敗）：\(error.localizedDescription)")
                    return
                }
                // 成功：成功取得url的字串後，返回該 url給調用方
                if let downloadURLString = url?.absoluteString {
                    completion(.success(downloadURLString))
                    print("日記圖片上傳成功")
                }
            }
        }
    }
    
    // 上傳日記到firebase
    func uploadDiary(diaryContent: DiaryContent, completion: @escaping (Result<Void, Error>) -> Void) {
        // 準備要上傳的資料（因為上傳firebase的資料不能是nil，所以沒有的部分(照片或文字)就不上傳相對應的資料）
        var diaryData: [String: Any] = [
            "diaryDate": diaryContent.diaryDate
        ]
        if let imageURL = diaryContent.diaryImageURLString {
            diaryData["diaryImageURLString"] = imageURL
        }
        if let text = diaryContent.diaryText {
            diaryData["diaryText"] = text
        }
        
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
    
    // 新增相片
    @IBAction func addImage(_ sender: Any) {
        let controller = UIImagePickerController()
        controller.delegate = self
        present(controller, animated: true)
    }
}

// TextView的相關設定、功能
extension EditViewController: UITextViewDelegate {
    
    // 依據TextView的編輯狀態做外觀改變
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .gray {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.textColor = .gray
            textView.text = "今天的心情......"
        }
    }
    
    
    // 設定編輯文字時，畫面上移
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
    
    // 在鍵盤上方多新增編輯完成可以收回鍵盤的按鈕
    func createToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "編輯完成", style: .done, target: self, action: #selector(dismissKeyboard))
        let doneImageButton = UIBarButtonItem(image: UIImage(systemName: "chevron.down"), style: .done, target: self, action: #selector(dismissKeyboard))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [flexibleSpace, doneButton, doneImageButton]
        return toolbar
    }
    
    @objc func dismissKeyboard() {
        self.diaryTextView.resignFirstResponder()
    }
}

// 擴展選取相片的功能
extension EditViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imageView.image = info[.originalImage] as? UIImage
        dismiss(animated: true)
    }
}
