//
//  HistoryExport.swift
//  CoolTime
//
//  쿨타임 기록을 CSV 로 내보낸다. **무료다** — 내 기록을 밖으로 가져가는 길은 잠그지 않는다.
//  사용 한 번이 한 줄이다. 엑셀 · Numbers 가 한글을 깨지 않게 UTF-8 BOM 을 붙인다.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct HistoryCSV: Transferable {
    let text: String

    init(items: [CooldownItem]) {
        let header = [
            String(localized: "이름"),
            String(localized: "날짜", comment: "CSV export column: date and time of a use"),
            String(localized: "쿨타임 중 사용", comment: "CSV export column: 1 if used before the cooldown ended"),
            String(localized: "비용", comment: "CSV export column: cost"),
            String(localized: "메모", comment: "CSV export column: note"),
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let rows = items.flatMap { item in
            item.usageHistory.sorted { $0.date < $1.date }.map { record in
                [item.name,
                 formatter.string(from: record.date),
                 record.brokeCooldown ? "1" : "0",
                 record.cost.map(String.init) ?? "",
                 record.note ?? ""]
            }
        }
        text = "\u{FEFF}" + ([header] + rows).map { $0.map(Self.escape).joined(separator: ",") }.joined(separator: "\r\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { csv in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CoolTime.csv")
            try Data(csv.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
