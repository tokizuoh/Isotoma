import Foundation

enum Source {
    case hatena
    case zenn
}

struct Post {
    let title: String
    let urlString: String
    let published: Date
    let source: Source
}

@main
struct Isotoma {
    private static let hatena = "https://tokizuoh.hatenablog.com/rss?size=5"
    private static let zenn = "https://zenn.dev/tokizuoh/feed"
    
    static func main() async {
        if let posts = await fetchLatestPosts(count: 5) {
            // TODO: CSVに加工する
            print(posts)
        } else {
            // NOP
        }
    }
    
    private static func fetchLatestPosts(count: Int) async -> [Post]? {
        async let hatenaPosts = parseRSSFeed(urlString: hatena, source: .hatena)
        async let zennPosts = parseRSSFeed(urlString: zenn, source: .zenn)
        
        let allPosts = (await [hatenaPosts, zennPosts].compactMap { $0 }).flatMap { $0 }
        
        let sortedPosts = allPosts.sorted(by: { $0.published > $1.published })
        
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
                let post = Post(title: title, urlString: urlString, published: pubDate, source: source)
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
