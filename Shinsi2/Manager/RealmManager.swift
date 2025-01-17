import Foundation
import RealmSwift

class RealmManager {
    static let shared = RealmManager()
    let realm: Realm = {
        let config = Realm.Configuration( schemaVersion: 13, migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion < 8 {
                
            }
        })
        Realm.Configuration.defaultConfiguration = config
        return try! Realm()
    }()
    
    lazy var searchHistory: Results<SearchHistory> = {
        return self.realm.objects(SearchHistory.self).sorted(byKeyPath: "date", ascending: false)
    }()
    
    lazy var downloaded: Results<Doujinshi> = {
        return self.realm.objects(Doujinshi.self).filter("isDownloaded == true").sorted(byKeyPath: "date", ascending: false)
    }()
    
    lazy var author: Results<Author> = {
        return self.realm.objects(Author.self).sorted(byKeyPath: "author")
    }()
    
    func browsingHistory(for doujinshi: Doujinshi) -> BrowsingHistory? {
        return realm.objects(BrowsingHistory.self).filter("id == %d", doujinshi.id).first
    }
    
    func createBrowsingHistory(for doujinshi: Doujinshi) {
        try! realm.write {
            realm.create(BrowsingHistory.self, value: ["doujinshi": doujinshi, "id": doujinshi.id], update: .modified)
        }
    }
    
    func updateBrowsingHistory(_ browsingHistory: BrowsingHistory, currentPage: Int) {
        try! realm.write {
            browsingHistory.updatedAt = Date()
            browsingHistory.currentPage = currentPage
        }
    }
    
    var browsedDoujinshi: [Doujinshi] {
        let hs = realm.objects(BrowsingHistory.self).sorted(byKeyPath: "updatedAt", ascending: false)
        var results: [Doujinshi] = []
        let maxHistory = min(30, hs.count)
        for i in 0..<maxHistory {
            if let d = hs[i].doujinshi {
                results.append(Doujinshi(value: d))
            }
        }
        return results
    }
    
    
    func saveAuthor(doujinshi: Doujinshi) {
        let title = doujinshi.author
        let cover = doujinshi.coverUrl
        let list = realm.objects(Author.self).filter("author = '\(title)'")
        if list.count > 0 {
            let authorModel = list[0]
            guard authorModel.covers.index(of: cover) == nil else {
                return
            }
            try! realm.write {
                authorModel.covers.append(cover)
            }
            return
        }
        
        try! realm.write {
            realm.add(Author().then {
                $0.author = title
                $0.covers.append(cover)
            })
        }
    }

    
    func deleteAuthor(author: Author) {
        try! realm.write {
            realm.delete(author)
        }
    }
    
    
    func saveSearchHistory(text: String?) {
        guard let text = text else {return}
        guard text.replacingOccurrences(of: " ", with: "").count != 0 else {return}
        if let obj = realm.objects(SearchHistory.self).filter("text = %@", text).first {
            try! realm.write {
                obj.date = Date()
            }
        } else {
            try! realm.write {
                let h = SearchHistory()
                h.text = text
                realm.add(h)
            }
        }
    }
    
    func deleteAllSearchHistory() {
        try! realm.write {
            realm.delete(realm.objects(SearchHistory.self))
        }
    }
    
    func deleteSearchHistory(history: SearchHistory) {
        try! realm.write {
            realm.delete(history)
        }
    }
    
    func saveDownloadedDoujinshi(book: Doujinshi) {
        var array = Array<String>()
        for i in 0..<book.gdata!.filecount {
            array.append(book.pages[i].url)
        }
        book.pages.removeAll()
        for i in 0..<book.gdata!.filecount {
            let p = Page()
            p.thumbUrl = String(format: book.gdata!.gid + "/%04d.jpg", i)
            p.url = array[i]
            book.pages.append(p)
        }
        if let first = book.pages.first {
            book.coverUrl = first.thumbUrl
        }
        book.isDownloaded = true
        book.date = Date()
        
        DispatchQueue.main.async {
            try! self.realm.write {
                self.realm.add(book)
            }
        }
    }
    
    func deleteDoujinshi(book: Doujinshi) {
        try! realm.write {
            realm.delete(book)
        }
    }
    
    func isDounjinshiDownloaded(doujinshi: Doujinshi) -> Bool {
        return downloaded.filter("gdata.gid = '\(doujinshi.gdata!.gid)'").count != 0
    }
}
