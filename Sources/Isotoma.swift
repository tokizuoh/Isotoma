import Foundation

enum Source: String, Codable {
    case hatena
    case zenn
}

struct Post: Codable {
    let title: String
    let url: String
    let publishedAt: Date
    let source: Source
}

@main
struct Isotoma {
    private static let hatena = "https://tokizuoh.hatenablog.com/rss?size=10"
    private static let zenn = "https://zenn.dev/tokizuoh/feed"
    
    static func main() async throws {
        if let posts = await fetchLatestPosts(count: 10) {
            try savePostsToJSONFile(posts: Array(posts.prefix(5)))
        } else {
            // NOP
        }
    }
    
    private static func fetchLatestPosts(count: Int) async -> [Post]? {
        async let hatenaPosts = parseRSSFeed(urlString: hatena, source: .hatena)
        async let zennPosts = parseRSSFeed(urlString: zenn, source: .zenn)
        
        let allPosts = (await [hatenaPosts, zennPosts].compactMap { $0 }).flatMap { $0 }
        
        let sortedPosts = allPosts.sorted(by: { $0.publishedAt > $1.publishedAt })
        
        return Array(sortedPosts.prefix(count))
    }
    
    private static func parseRSSFeed(urlString: String, source: Source) async -> [Post]? {
        do {
            async let rssData = fetch(from: URL(string: urlString)!)
            
            let rssDataResult = try await rssData
            
            let parser = XMLParser(data: rssDataResult)
            let rssParserDelegate = RSSParserDelegate(source: source)
            parser.delegate = rssParserDelegate
            
            return parser.parse() ? rssParserDelegate.posts : nil
        } catch {
            return nil
        }
    }
    
    private static func fetch(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    private static func savePostsToJSONFile(posts: [Post]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        
        let jsonData = try encoder.encode(posts)
        let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("latest_posts.json")
        try jsonData.write(to: fileURL)
    }
}

class RSSParserDelegate: NSObject, XMLParserDelegate {
    private(set) var posts: [Post] = []
    private var currentItem: [String: String] = [:]
    private var currentElement: String = ""
    private let source: Source
    
    init(source: Source) {
        self.source = source
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentItem = [:]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentItem[currentElement, default: ""] += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if let title = currentItem["title"],
               let urlString = currentItem["link"],
               let pubDateString = currentItem["pubDate"],
               let pubDate = dateFromString(pubDateString) {
                if source == .hatena,
                   let category = currentItem["category"],
                   category == "その他" {
                    return
                }

                let post = Post(title: title, url: urlString, publishedAt: pubDate, source: source)
                posts.append(post)
            }
        }
    }
    
    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }
}
