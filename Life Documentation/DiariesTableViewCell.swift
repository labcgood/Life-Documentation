//
//  DiariesTableViewCell.swift
//  Life Documentation
//
//  Created by Labe on 2024/12/6.
//

import UIKit
import SDWebImage

class DiariesTableViewCell: UITableViewCell {

    @IBOutlet weak var view: UIView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var diaryTextLabel: UILabel!
    @IBOutlet weak var diaryImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        view.clipsToBounds = true
        view.backgroundColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        view.layer.cornerRadius = 5
        dateLabel.font = UIFont.boldSystemFont(ofSize: 20)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func updateUI(show diary : DiaryContent) {
        let dateTextArray: [String] = diary.diaryDate.components(separatedBy: "-")
        let showDateString = dateTextArray[0] + "\n" + dateTextArray[1] + "-" + dateTextArray[2]
        dateLabel.text = showDateString
        diaryTextLabel.text = diary.diaryText
        diaryImageView.sd_setImage(with: URL(string: diary.diaryImageURLString ?? ""))
    }
}
