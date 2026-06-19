import Foundation
import PDFKit
import UniformTypeIdentifiers

enum ResumeTextExtractorError: LocalizedError {
    case emptyDocument
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "没有从简历中读取到文字，请换一份可复制文字的 PDF 或 TXT 简历。"
        case .unsupportedFormat:
            return "当前版本优先支持 PDF 和 TXT 简历。Word 简历可以先导出为 PDF 后上传。"
        }
    }
}

struct ResumeTextExtractor {
    func extractText(from url: URL) throws -> String {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let extensionName = url.pathExtension.lowercased()
        let text: String

        switch extensionName {
        case "pdf":
            text = try extractPDFText(from: url)
        case "txt", "text":
            text = try String(contentsOf: url, encoding: .utf8)
        default:
            throw ResumeTextExtractorError.unsupportedFormat
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw ResumeTextExtractorError.emptyDocument
        }

        return cleaned
    }

    private func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ResumeTextExtractorError.emptyDocument
        }

        let pages = (0..<document.pageCount).compactMap { index in
            document.page(at: index)?.string
        }

        return pages.joined(separator: "\n")
    }
}

