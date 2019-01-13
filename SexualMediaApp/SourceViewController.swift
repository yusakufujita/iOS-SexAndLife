//
//  SourceViewController.swift
//  SexualMediaApp
//
//  Created by Masahiro Atarashi on 2019/01/09.
//  Copyright © 2019 Masahiro Atarashi. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import SDWebImage
import SVProgressHUD

class SourceViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    
    var receiveData:String = ""
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var tableView: UITableView!
    var sourceArticleArray: [ArticleData] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(R.nib.listCell)
        tableView.estimatedRowHeight = 200
        SVProgressHUD.show()
        
        
        reloadSourceArticleData()
        /*
        Database.database().reference().child("users").observeSingleEvent(of: .value) {  (snap,error) in
            if let users = snap.value as? [String:NSDictionary] {
                self.userSum = users.count
                self.reloadFavoriteData()
            }
        }*/
    }
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationItem.title = receiveData
        
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage =  UIImage() //nill
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barTintColor = .white //.clear
        navigationController?.navigationBar.tintColor = .black  //clear
        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.black]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        SVProgressHUD.dismiss()
    }
    
    func reloadSourceArticleData() {
        print("reloadSourceArticleData()が呼ばれたよ")
        self.sourceArticleArray = []
        //tableView.reloadData()
        if Auth.auth().currentUser != nil {
            let articlesRef = Database.database().reference().child(Const.ArticlePath)
            articlesRef.observe(.childAdded, with: {snapshot in
                if let uid = Auth.auth().currentUser?.uid {
                    let articleData = ArticleData(snapshot: snapshot, myId: uid)
                    if articleData.sourceName == self.receiveData{
                        self.sourceArticleArray.insert(articleData, at: 0)
                    }
                    
                    self.tableView.reloadData()
                    SVProgressHUD.dismiss()
                }
            })
            articlesRef.observe(.childChanged, with: { snapshot in
                if let uid = Auth.auth().currentUser?.uid {
                    let articleData = ArticleData(snapshot: snapshot, myId: uid)
                    
                    var index: Int = 0
                    for article in self.sourceArticleArray {
                        if article.id == articleData.id {
                            index = self.sourceArticleArray.index(of: article)!
                            break
                        }
                    }
                    
                    if articleData.sourceName == self.receiveData{ //トップ記事は30記事まで
                        //差し替えるために一度削除 ここでエラーになった。
                        self.sourceArticleArray.remove(at: index)
                        //削除したところに更新済みのデータを追加
                        self.sourceArticleArray.insert(articleData, at:index)
                        
                    }
                    
                    
                    let before = self.tableView.contentOffset.y
                    self.tableView.reloadData()
                    let after = self.tableView.contentOffset.y
                    
                    if before > after {
                        self.tableView.contentOffset.y = before
                    }
                    
                    SVProgressHUD.dismiss()
                    
                }
            })
            
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { //sourceImage
            return 1
        } else if section == 1 { //sourceInfo
            return 1
        } else {
            return sourceArticleArray.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell: SourceImageCell = tableView.dequeueReusableCell(withIdentifier: "sourceImageCell", for:indexPath) as! SourceImageCell
            cell.receiveSourceName = receiveData
            cell.setCellInfo()
            return cell
        } else if indexPath.section == 1 {
            let cell:SourceInfoCell = tableView.dequeueReusableCell(withIdentifier: "sourceInfoCell", for:indexPath) as! SourceInfoCell
            cell.receiveSourceName = receiveData
            cell.setCellInfo()
            return cell
        } else {
        
            guard let cell = tableView.dequeueReusableCell(withIdentifier: R.nib.listCell, for:indexPath)  else { return UITableViewCell()}
            cell.setCellInfo(articleData: sourceArticleArray[indexPath.row])
            cell.clipButton.addTarget(self, action: #selector(handleButton(sender:event:)), for: UIControl.Event.touchUpInside)
            cell.selectionStyle = .none //ハイライトを消す
            cell.backgroundColor = UIColor.black //.clear //一時的に黒へ //後ろが見えるようになる。
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            return
        } else if indexPath.section == 1 {
            return
        } else {
            let selectCellViewModel = sourceArticleArray[indexPath.row]
            fromSourceArticleToSummary(giveCellViewModel: selectCellViewModel)
        
        }
    }
    
    func fromSourceArticleToSummary(giveCellViewModel:ArticleData) {
        let giveCellViewModel = giveCellViewModel
        let vc:SummaryViewController = storyboard?.instantiateViewController(withIdentifier: "SummaryViewController") as! SummaryViewController
        vc.receiveCellViewModel = giveCellViewModel
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    @objc func handleButton(sender: UIButton, event:UIEvent) {
        // タップされたセルのインデックスを求める
        let touch = event.allTouches?.first
        let point = touch!.location(in: self.tableView)
        let indexPath = tableView.indexPathForRow(at: point)
        
        // 配列からタップされたインデックスのデータを取り出す
        let articleData = sourceArticleArray[indexPath!.row]
        
        // Firebaseに保存するデータの準備
        if let uid = Auth.auth().currentUser?.uid {
            if articleData.isLiked {
                var index = -1
                for likeId in articleData.likes {
                    if likeId == uid {
                        // 削除するためにインデックスを保持しておく
                        index = articleData.likes.index(of: likeId)!
                        break
                    }
                }
                articleData.likes.remove(at: index)
                
            } else {
                articleData.likes.append(uid)
            }
            

            let articleRef = Database.database().reference().child(Const.ArticlePath).child(articleData.id!)
            let likes = ["likes": articleData.likes]
            articleRef.updateChildValues(likes)
            
        }
        
    }
}

class SourceImageCell:UITableViewCell{
    
    @IBOutlet weak var sourceImageView: UIImageView!
    var imageURLString = ""
    var receiveSourceName = ""
    
    override func awakeFromNib() {
        
    }
    
    func setCellInfo() {
        let ref = Firestore.firestore().collection("sourceData")
        //sourceNameがreceiveDataと一致するドキュメントのImageURLStringを取得したい。
        
        //まずはPILCONのImageURLStringを取得してみよう。
        /*ref.document("dm1retb0c77L1UenZOOk").getDocument { (document, error) in
            if let document = document, document.exists {
                for item in document.data()! {
                    if item.key == "ImageURLString" {
                        self.imageURLString = item.value as! String
                        self.sourceImageView.sd_setImage(with: URL(string: self.imageURLString), placeholderImage: UIImage(named: "placeholderImage"))
                        
                    }
                }
            }
        }*/
        ref.whereField("SourceName", isEqualTo: receiveSourceName).getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    self.imageURLString = document["ImageURLString"] as! String
                }
                self.sourceImageView.sd_setImage(with: URL(string: self.imageURLString), placeholderImage: UIImage(named: "placeholderImage"))
            }
        }
        
    }
}

class SourceInfoCell:UITableViewCell{
    var receiveSourceName = ""
    @IBOutlet weak var sourceInfoTextView: UITextView!{
        didSet{
            sourceInfoTextView.text = ""
        }
    }
    
    
    override func awakeFromNib() {
    }
    
    
    func setCellInfo() {
        let ref = Firestore.firestore().collection("sourceData")
        ref.whereField("SourceName", isEqualTo: receiveSourceName).getDocuments() { (querySnapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    self.sourceInfoTextView.text = document["SourceInfo"] as? String
                }
            }
        }
    }
}
    

