import Foundation
import CoreFoundation

public struct ImportResult: Sendable {
    public let profile: EQProfile
    public let warnings: [String]
    public let preampDB: Double?
}
public enum EQImporter {
    private static let aliases = ["PK":"Peak","PEQ":"Peak","PEAKING":"Peak","MODAL":"Peak","PEAK":"Peak","LS":"Shelf","LSC":"Shelf","LOW_SHELF":"Shelf","LOWSHELF":"Shelf","SHELF":"Shelf","HS":"Shelf","HSC":"Shelf","HIGH_SHELF":"Shelf","HIGHSHELF":"Shelf","HP":"High Pass","HPF":"High Pass","HIGHPASS":"High Pass","HPQ":"High Pass","HIGH PASS":"High Pass","LP":"High Cut","LPF":"High Cut","HIGHCUT":"High Cut","LOWPASS":"High Cut","LPQ":"High Cut","HIGH CUT":"High Cut"]
    public static func parse(text: String, name: String = "Imported EQ", output: Output = .phones) throws -> ImportResult {
        guard text.utf8.count <= 4 * 1024 * 1024 else { throw ADI2Error.invalid("EQ files must be smaller than 4 MB.") }
        let stripped = text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !stripped.isEmpty else { throw ADI2Error.invalid("Choose an Equalizer APO, REW, CSV or JSON EQ file.") }
        if stripped.first == "{" || stripped.first == "[" { return try json(stripped,name:name,output:output) }
        if stripped.lowercased().contains("filter") && stripped.lowercased().contains("fc") { return try apo(stripped,name:name,output:output) }
        return try csv(stripped,name:name,output:output)
    }
    private static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern:pattern,options:.caseInsensitive) else { return [] }
        let ns = text as NSString
        return re.matches(in:text,range:NSRange(location:0,length:ns.length)).map { m in
            (0..<m.numberOfRanges).map { n in let r = m.range(at:n); return r.location == NSNotFound ? "" : ns.substring(with:r) }
        }
    }
    private static func apo(_ text: String, name: String, output: Output) throws -> ImportResult {
        let number = #"([+-]?(?:\d+(?:\.\d*)?|\.\d+))"#
        let pattern = #"Filter\s*\d*\s*:\s*ON\s+([A-Z_]+)\s+Fc\s+"# + number + #"\s*Hz\s+Gain\s+"# + number + #"\s*dB(?:\s+Q\s+"# + number + #")?"#
        var bands:[Band] = [], warnings:[String] = []
        for m in matches(pattern,text) {
            guard let kind = aliases[m[1].uppercased()] else { warnings.append("Skipped unsupported filter type \(m[1])."); continue }
            guard let freq = Double(m[2]),let gain = Double(m[3]),let q = Double(m[4].isEmpty ? "1" : m[4]) else { continue }
            bands.append(Band(type:kind,gainDB:gain,frequency:freq,q:q))
        }
        // Disabled filters intentionally do not contribute. Flag any enabled line that was not parsed.
        let enabled = matches(#"(?m)^\s*Filter\s*\d*\s*:\s*ON\b.*$"#,text).count
        if enabled > matches(pattern,text).count { warnings.append("Some enabled filter lines could not be read; check the imported bands.") }
        let preamp = matches(#"Preamp\s*:\s*"# + number + #"\s*dB"#,text).first.flatMap { Double($0[1]) }
        return try finish(name:name,bands:bands,output:output,warnings:warnings,preamp:preamp)
    }
    private static func json(_ text: String, name: String, output: Output) throws -> ImportResult {
        let data = Data(text.utf8)
        let object:Any
        do { object = try JSONSerialization.jsonObject(with:data,options:[]) } catch { throw ADI2Error.invalid("The EQ JSON is invalid: \(error.localizedDescription)") }
        if var own = try? JSONDecoder().decode(EQProfile.self,from:data), (try? own.validate()) != nil { own.output = output; return ImportResult(profile:own,warnings:[],preampDB:nil) }
        var items:[Any]? = object as? [Any]
        var resolvedName = name
        if let d = object as? [String:Any] {
            for key in ["filters","eq","bands","filter"] { if let list = d[key] as? [Any] { items = list; break } }
            if (name == "Imported EQ" || name.isEmpty), let n = d["name"] as? String { resolvedName = n }
        }
        guard let items = items else { throw ADI2Error.invalid("The JSON needs a filters or bands list.") }
        var bands:[Band] = [],warnings:[String] = []
        for (i,item) in items.enumerated() {
            guard let d = item as? [String:Any] else { warnings.append("Skipped non-object JSON filter \(i+1)."); continue }
            let rawType = (d["type"] as? String ?? "PK").uppercased().trimmingCharacters(in:.whitespaces)
            let kind = aliases[rawType] ?? (rawType.contains("SHELF") ? "Shelf" : "Peak")
            if aliases[rawType] == nil && !rawType.contains("SHELF") { warnings.append("Filter \(i+1): unsupported type \(rawType), using Peak.") }
            func number(_ value: Any?) -> Double? {
                if let n = value as? NSNumber { return CFGetTypeID(n) == CFBooleanGetTypeID() ? nil : n.doubleValue }
                if let s = value as? String { return Double(s) }
                return nil
            }
            guard let freq = number(d["frequency"] ?? d["fc"] ?? d["freq_hz"]), let gain = number(d["gain"] ?? d["gain_db"] ?? 0), let q = number(d["q"] ?? d["bandwidth"] ?? 1) else { warnings.append("Skipped JSON filter \(i+1) with missing or invalid numbers."); continue }
            bands.append(Band(type:kind,gainDB:gain,frequency:freq,q:q))
        }
        return try finish(name:resolvedName,bands:bands,output:output,warnings:warnings,preamp:nil)
    }
    private static func csv(_ text: String, name: String, output: Output) throws -> ImportResult {
        let aliases = ["frequency":"freq","fc":"freq","hz":"freq","freq_hz":"freq","gain_db":"gain","db":"gain","bandwidth":"q","filter_type":"type","filter":"type"]
        let rows = try csvRows(text).filter { !$0.allSatisfy({$0.isEmpty}) && !($0.first ?? "").hasPrefix("#") }
        guard let first = rows.first else { throw ADI2Error.invalid("The CSV is empty.") }
        let header = first.map { aliases[$0.lowercased()] ?? $0.lowercased() }
        let hasHeader = header.contains("freq") && header.contains("gain")
        var bands:[Band] = [], warnings:[String] = []
        for (i,row) in rows.enumerated() where !hasHeader || i > 0 {
            func cell(_ key:String,_ index:Int) -> String? { let n = hasHeader ? header.firstIndex(of:key) : index; guard let n, row.indices.contains(n) else {return nil}; return row[n] }
            guard let f = cell("freq",0).flatMap(Double.init),let g = cell("gain",1).flatMap(Double.init) else { warnings.append("Skipped malformed CSV row \(i+1)."); continue }
            let qs = cell("q",2) ?? "1"
            guard let q = Double(qs.isEmpty ? "1" : qs) else { warnings.append("Skipped CSV row \(i+1) with invalid Q."); continue }
            let raw = (cell("type",3) ?? "PK").uppercased()
            let kind = self.aliases[raw] ?? "Peak"
            if self.aliases[raw] == nil { warnings.append("Row \(i+1): unsupported type \(raw), using Peak.") }
            bands.append(Band(type:kind,gainDB:g,frequency:f,q:q))
        }
        return try finish(name:name,bands:bands,output:output,warnings:warnings,preamp:nil)
    }
    /// Handles RFC 4180 quoted fields, doubled quotes and CRLF.
    private static func csvRows(_ text:String) throws -> [[String]] {
        var rows:[[String]] = [],row:[String] = [],field = "",quoted = false
        let chars = Array(text); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i+1 < chars.count && chars[i+1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if !quoted && c == "," { row.append(field.trimmingCharacters(in:.whitespaces)); field = "" }
            else if !quoted && (c == "\n" || c == "\r" || c == "\r\n") { row.append(field.trimmingCharacters(in:.whitespaces)); rows.append(row); row=[];field="" }
            else { field.append(c) }
            i += 1
        }
        guard !quoted else { throw ADI2Error.invalid("The CSV has an unterminated quoted field.") }
        if !field.isEmpty || !row.isEmpty { row.append(field.trimmingCharacters(in:.whitespaces)); rows.append(row) }
        return rows
    }
    private static func finish(name:String,bands original:[Band],output:Output,warnings initial:[String],preamp:Double?) throws -> ImportResult {
        guard !original.isEmpty else { throw ADI2Error.invalid("No usable EQ filters were found. Use Equalizer APO, REW, CSV or JSON filter data.") }
        guard original.allSatisfy({$0.frequency.isFinite && $0.gainDB.isFinite && $0.q.isFinite}),preamp?.isFinite != false else { throw ADI2Error.invalid("EQ values must be finite numbers.") }
        var warnings = initial, peaks = original.filter {$0.type == "Peak"}, chosen:[Band] = []
        let low = original.filter {$0.type == "Shelf" && $0.frequency <= 500}, high = original.filter {$0.type == "Shelf" && $0.frequency > 500}
        let hp = original.filter {$0.type == "High Pass"}, hc = original.filter {$0.type == "High Cut"}
        if let first = low.first {
            chosen.append(first)
            for extra in low.dropFirst() { warnings.append("Converted extra low shelf at \(String(format:"%.0f",extra.frequency)) Hz to Peak."); var b=extra;b.type="Peak";peaks.append(b) }
            for b in hp { warnings.append("Dropped High Pass at \(String(format:"%.0f",b.frequency)) Hz because band 1 holds a shelf.") }
        } else if let first = hp.first { chosen.append(first); for b in hp.dropFirst() { warnings.append("Dropped extra High Pass at \(String(format:"%.0f",b.frequency)) Hz.") } }
        var top:Band?
        if let last = high.last {
            top=last
            for extra in high.dropLast() { warnings.append("Converted extra high shelf at \(String(format:"%.0f",extra.frequency)) Hz to Peak.");var b=extra;b.type="Peak";peaks.append(b) }
            for b in hc { warnings.append("Dropped High Cut at \(String(format:"%.0f",b.frequency)) Hz because band 5 holds a shelf.") }
        } else if let last = hc.last { top=last;for b in hc.dropLast() { warnings.append("Dropped extra High Cut at \(String(format:"%.0f",b.frequency)) Hz.") } }
        let slots = 5 - chosen.count - (top == nil ? 0 : 1)
        if peaks.count > slots {
            let keep = Set(peaks.indices.sorted { abs(peaks[$0].gainDB) == abs(peaks[$1].gainDB) ? $0 < $1 : abs(peaks[$0].gainDB) > abs(peaks[$1].gainDB) }.prefix(slots))
            warnings.append("Dropped \(peaks.count-slots) weakest peak(s): " + peaks.indices.filter {!keep.contains($0)}.map {String(format:"%.0f Hz",peaks[$0].frequency)}.joined(separator:", "))
            peaks = peaks.indices.filter {keep.contains($0)}.map {peaks[$0]}
        }
        chosen += peaks.sorted {$0.frequency < $1.frequency}
        if let top { chosen.append(top) }
        while chosen.count < 5 {
            let padding = Band()
            if let last=chosen.last,["Shelf","High Cut"].contains(last.type) { chosen.insert(padding,at:chosen.count-1) } else {chosen.append(padding)}
        }
        for i in chosen.indices {
            let minimum = i >= 3 ? 200.0 : 20.0,qmax=i >= 3 ? 5.0 : 9.9
            if !Band.types(for:i).contains(chosen[i].type) || (chosen[i].type == "Shelf" && ((i == 0 && chosen[i].frequency > 500) || (i == 4 && chosen[i].frequency <= 500))) { warnings.append("Band \(i+1): type \(chosen[i].type) converted to Peak."); chosen[i].type="Peak" }
            if !(-12...12).contains(chosen[i].gainDB) { warnings.append("Band \(i+1): gain clamped to ±12 dB.");chosen[i].gainDB=max(-12,min(12,chosen[i].gainDB)) }
            if !(minimum...20000).contains(chosen[i].frequency) { warnings.append("Band \(i+1): frequency clamped to \(Int(minimum))…20000 Hz.");chosen[i].frequency=max(minimum,min(20000,chosen[i].frequency)) }
            if !(0.5...qmax).contains(chosen[i].q) { warnings.append("Band \(i+1): Q clamped to 0.5…\(qmax).");chosen[i].q=max(0.5,min(qmax,chosen[i].q)) }
        }
        if let preamp,preamp != 0 { warnings.append(String(format:"Preamp %+.1f dB has no ADI-2 equivalent. Adjust the output volume separately before applying.",preamp)) }
        let profile=EQProfile(name:name.isEmpty ? "Imported EQ" : name,output:output,bands:chosen)
        try profile.validate()
        return ImportResult(profile:profile,warnings:warnings,preampDB:preamp)
    }
}
