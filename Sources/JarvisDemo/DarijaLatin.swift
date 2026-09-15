import Foundation

/// Local transliteration for display, not translation. Unvowelled names may need correction.
enum DarijaLatin {
    private static let words: [String: String] = [
        "واش":"wach", "شنو":"chno", "شنوا":"chnoua", "علاش":"3lach", "كيفاش":"kifach", "فين":"fin",
        "فاش":"fach", "شكون":"chkon", "شحال":"ch7al", "امتى":"imta", "دابا":"daba", "اليوم":"lyoum",
        "غدا":"ghdda", "البارح":"lbare7", "بغيت":"bghit", "بغيتك":"bghitek", "بغينا":"bghina",
        "خاصني":"khassni", "خاصك":"khassk", "خاصنا":"khassna", "خاص":"khass", "خاصو":"khasso",
        "غادي":"ghadi", "غادين":"ghadin", "نقدر":"n9der", "تقدر":"t9der", "يمكن":"ymken",
        "ندير":"ndir", "دير":"dir", "ديرو":"diro", "درت":"dert", "درتي":"derti",
        "حل":"7ell", "حلي":"7elli", "وريني":"werrini", "شوف":"chouf", "شوفي":"choufi", "شوفو":"choufo",
        "ليا":"lia", "لي":"li", "لينا":"lina", "ليك":"lik", "ديال":"dyal", "ديالي":"dyali", "ديالك":"dyalk",
        "الفيديو":"lvideo", "فيديو":"video", "الفيديوهات":"lvideohat", "فيديوهات":"videohat",
        "المشروع":"lprojet", "مشروع":"projet", "جارفيس":"Jarvis", "جارفس":"Jarvis",
        "واجد":"wajed", "واجدة":"wajda", "واجدين":"wajdin", "موجد":"mwejjed", "كمل":"kmel", "كملت":"kmelt",
        "خدام":"khddam", "خدامة":"khddama", "كيخدم":"kikhdem", "خدم":"khdem", "سالي":"sali", "ساليت":"salit",
        "نعم":"iyeh", "ايه":"iyeh", "واخا":"wakha", "صافي":"safi", "مزيان":"mzyan", "بزاف":"bzzaf",
        "شكرا":"chokran", "عافاك":"3afak", "سمح":"sme7", "سمحلي":"sme7li",
        "السلام":"salam", "عليكم":"3likom", "سلام":"salam", "مرحبا":"mer7ba", "الو":"allo",
        "انا":"ana", "انت":"nta", "انتي":"nti", "حنا":"7na", "هو":"howa", "هي":"hiya", "هما":"houma",
        "هاد":"had", "هادا":"hada", "هدا":"hada", "هاذ":"had", "هذي":"hadi", "هادي":"hadi", "هادشي":"hadchi",
        "اللي":"lli", "ليلي":"lili", "على":"3la", "عند":"3nd", "عندي":"3ndi", "عندك":"3ndek", "مع":"m3a",
        "من":"men", "فوق":"fo9", "تحت":"te7t", "باش":"bach", "حيت":"7it", "حيتاش":"7itach",
        "ماشي":"machi", "ما":"ma", "لا":"la", "ولا":"wla", "و":"w", "راه":"rah", "باقي":"ba9i", "باقا":"ba9a",
        "واحد":"wa7ed", "جوج":"jouj", "ثلاثة":"tlata", "شوية":"chwiyya", "حاجة":"7aja", "حوايج":"7wayj",
        "كلشي":"kolchi", "والو":"walo", "كاين":"kayn", "كاينة":"kayna", "كاينين":"kaynin", "مكاينش":"makaynch",
        "الوقت":"lwe9t", "الناس":"nnas", "نهضر":"nhder", "نهضرو":"nhdro", "قلت":"gelt", "قول":"goul",
        "تستست":"test test"
    ]
    static func render(_ text: String) -> String {
        let input = text.precomposedStringWithCompatibilityMapping
        let regex = try! NSRegularExpression(pattern: "[\\p{Arabic}\\p{M}]+")
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        let result = NSMutableString(string: input)
        for match in matches.reversed() {
            let original = (input as NSString).substring(with: match.range)
            let unmarked = String(String.UnicodeScalarView(original.unicodeScalars.filter { !CharacterSet.nonBaseCharacters.contains($0) }))
            let key = unmarked.replacingOccurrences(of: "ـ", with: "")
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "ar"))
                .replacingOccurrences(of: "أ", with: "ا").replacingOccurrences(of: "إ", with: "ا").replacingOccurrences(of: "آ", with: "ا")
            var latin = words[key] ?? (original.applyingTransform(.toLatin, reverse: false) ?? original)
            for (from, to) in [("ʿ","3"),("ʾ","2"),("ḥ","7"),("Ḥ","7"),("ḫ","kh"),("Ḫ","Kh"),("ġ","gh"),("Ġ","Gh"),("š","ch"),("Š","Ch"),("q","9"),("ṯ","t"),("ḏ","d"),("گ","g"),("ڭ","g"),("ڤ","v"),("پ","p"),("چ","ch")] {
                latin = latin.replacingOccurrences(of: from, with: to)
            }
            latin = latin.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
            result.replaceCharacters(in: match.range, with: latin)
        }
        return (result as String).replacingOccurrences(of: "؟", with: "?").replacingOccurrences(of: "،", with: ",").replacingOccurrences(of: "؛", with: ";")
    }
}
