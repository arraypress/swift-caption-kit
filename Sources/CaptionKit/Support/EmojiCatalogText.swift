//
//  EmojiCatalogText.swift
//  CaptionKit
//
//  Created by David Sherlock on 2026.
//
//  Which spoken words earn an emoji, as data. Compiled in as a string rather
//  than shipped as a resource: a resource bundle beside a Homebrew binary
//  breaks when the binary is reached through a symlink.
//
//  Each entry is one emoji and the words that call for it, lowercase, matched
//  against a word's `matchKey` (case and attached punctuation ignored); a
//  plural `s` is forgiven. Words that are mostly filler in speech — "right",
//  "look", "think", "time", "no" — are deliberately absent: an emoji every
//  other sentence is noise, and nobody is looking to take it back out.
//
//  Checked by a test (`EmojiCatalog.parsed.problems` must be empty): every
//  emoji one character, every word lowercase letters only and listed once.
//

enum EmojiCatalogText {

    static let entries = #"""
    [
      {"emoji": "💰", "words": ["money", "cash", "dollar", "salary", "paycheck", "profit", "revenue", "income"]},
      {"emoji": "💸", "words": ["expensive", "spent", "spending", "overpriced", "debt"]},
      {"emoji": "🤑", "words": ["rich", "wealthy", "millionaire", "billionaire"]},
      {"emoji": "🆓", "words": ["free"]},
      {"emoji": "❤️", "words": ["love", "loved", "lovely", "heart", "romance"]},
      {"emoji": "🔥", "words": ["fire", "amazing", "incredible", "unbelievable", "hottest"]},
      {"emoji": "🤯", "words": ["insane", "crazy", "mindblowing", "shocking"]},
      {"emoji": "😱", "words": ["scary", "scared", "terrified", "horror", "nightmare"]},
      {"emoji": "😂", "words": ["funny", "hilarious", "joke", "laughing", "laughed"]},
      {"emoji": "😭", "words": ["cry", "crying", "cried", "tears"]},
      {"emoji": "😢", "words": ["sad", "heartbroken", "lonely"]},
      {"emoji": "😡", "words": ["angry", "furious", "rage"]},
      {"emoji": "💡", "words": ["idea", "tip", "hack", "trick", "insight"]},
      {"emoji": "🤔", "words": ["wonder", "wondering", "curious", "puzzle"]},
      {"emoji": "❓", "words": ["question"]},
      {"emoji": "⏰", "words": ["deadline", "clock", "alarm", "countdown"]},
      {"emoji": "📅", "words": ["today", "tomorrow", "yesterday", "calendar", "weekend", "monday", "friday"]},
      {"emoji": "☕", "words": ["coffee", "espresso", "latte", "tea"]},
      {"emoji": "🍕", "words": ["pizza", "food", "dinner", "lunch", "breakfast", "snack"]},
      {"emoji": "🍷", "words": ["wine", "cocktail"]},
      {"emoji": "🍺", "words": ["beer", "pub"]},
      {"emoji": "🏆", "words": ["win", "winner", "winning", "won", "champion", "trophy", "victory", "success"]},
      {"emoji": "🎯", "words": ["goal", "goals", "target", "bullseye"]},
      {"emoji": "💯", "words": ["perfect", "hundred", "guaranteed"]},
      {"emoji": "✨", "words": ["magic", "magical", "sparkle", "glow"]},
      {"emoji": "🤫", "words": ["secret", "secrets", "hidden"]},
      {"emoji": "⚠️", "words": ["warning", "danger", "dangerous", "careful", "risk", "risky"]},
      {"emoji": "❌", "words": ["mistake", "wrong", "fail", "failed", "failure"]},
      {"emoji": "✅", "words": ["correct", "approved", "finished", "solved", "checklist"]},
      {"emoji": "📱", "words": ["phone", "iphone", "app", "smartphone"]},
      {"emoji": "💻", "words": ["laptop", "computer", "code", "coding", "software"]},
      {"emoji": "🎬", "words": ["video", "movie", "film", "camera"]},
      {"emoji": "🎵", "words": ["music", "song", "songs", "playlist"]},
      {"emoji": "🎤", "words": ["sing", "singing", "singer", "podcast", "microphone"]},
      {"emoji": "💼", "words": ["job", "career", "office", "business", "boss", "interview"]},
      {"emoji": "🏠", "words": ["home", "house", "apartment", "rent"]},
      {"emoji": "✈️", "words": ["travel", "flight", "airport", "vacation", "holiday", "trip"]},
      {"emoji": "🌍", "words": ["world", "planet", "global", "country"]},
      {"emoji": "☀️", "words": ["sun", "sunny", "summer"]},
      {"emoji": "🌧️", "words": ["rain", "raining", "storm"]},
      {"emoji": "🏖️", "words": ["beach", "ocean", "sea"]},
      {"emoji": "💪", "words": ["strong", "strength", "gym", "workout", "muscle", "confidence"]},
      {"emoji": "🏃", "words": ["run", "running", "marathon", "sprint"]},
      {"emoji": "⚡", "words": ["fast", "faster", "quick", "quickly", "energy", "instantly"]},
      {"emoji": "🐢", "words": ["slow", "slowly"]},
      {"emoji": "😊", "words": ["happy", "smile", "smiling", "grateful"]},
      {"emoji": "🎉", "words": ["party", "celebrate", "celebration", "congratulations"]},
      {"emoji": "🎂", "words": ["birthday", "cake"]},
      {"emoji": "🎁", "words": ["gift", "giveaway", "bonus"]},
      {"emoji": "📚", "words": ["book", "books", "learn", "learning", "study", "studying", "library"]},
      {"emoji": "🎓", "words": ["school", "college", "university", "student", "teacher", "degree"]},
      {"emoji": "📈", "words": ["grow", "growth", "growing", "increase", "rising"]},
      {"emoji": "📉", "words": ["decline", "crash", "plunge", "recession"]},
      {"emoji": "🆕", "words": ["launch", "launched", "debut", "unveiled"]},
      {"emoji": "🧠", "words": ["brain", "smart", "genius", "clever", "memory"]},
      {"emoji": "😴", "words": ["sleep", "sleeping", "tired", "exhausted", "nap"]},
      {"emoji": "💭", "words": ["dream", "dreams", "dreaming", "imagine"]},
      {"emoji": "🦁", "words": ["brave", "courage", "fearless"]},
      {"emoji": "🐶", "words": ["dog", "puppy"]},
      {"emoji": "🐱", "words": ["cat", "kitten"]},
      {"emoji": "🚗", "words": ["car", "drive", "driving", "traffic"]},
      {"emoji": "🛒", "words": ["shopping", "shop", "buy", "bought", "store"]},
      {"emoji": "🔑", "words": ["unlock", "password", "locked"]},
      {"emoji": "⭐", "words": ["famous", "celebrity", "superstar"]},
      {"emoji": "🌱", "words": ["plant", "garden", "healthy", "nature"]}
    ]
    """#
}
