//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import _SwiftSyntaxTestSupport
import SwiftBasicFormat
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros
import XCTest

private extension String {
  // This implementation is really slow; to use it outside a test it should be optimized.
  func trimmingTrailingWhitespace() -> String {
    return self.replacingOccurrences(of: "[ ]+\\n", with: "\n", options: .regularExpression)
  }
}

// MARK: - Note

/// Describes a diagnostic note that tests expect to be created by a macro expansion.
public struct NoteSpec {
  /// The expected message of the note
  public let message: String

  /// The line to which the note is expected to point
  public let line: Int

  /// The column to which the note is expected to point
  public let column: Int

  /// The file and line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  internal let originatorFile: StaticString
  internal let originatorLine: UInt

  /// Creates a new `NoteSpec` that describes a note tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - message: The expected message of the note
  ///   - line: The line to which the note is expected to point
  ///   - column: The column to which the note is expected to point
  ///   - originatorFile: The file at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  public init(
    message: String,
    line: Int,
    column: Int,
    originatorFile: StaticString = #file,
    originatorLine: UInt = #line
  ) {
    self.message = message
    self.line = line
    self.column = column
    self.originatorFile = originatorFile
    self.originatorLine = originatorLine
  }
}

func assertNote<T: SyntaxProtocol>(
  _ note: Note,
  in tree: T,
  expected spec: NoteSpec
) {
  assertStringsEqualWithDiff(note.message, spec.message, "message of note does not match", file: spec.originatorFile, line: spec.originatorLine)
  let location = note.location(converter: SourceLocationConverter(file: "", source: tree.description))
  XCTAssertEqual(location.line, spec.line, "line of note does not match", file: spec.originatorFile, line: spec.originatorLine)
  XCTAssertEqual(location.column, spec.column, "column of note does not match", file: spec.originatorFile, line: spec.originatorLine)
}

// MARK: - Fix-It

/// Describes a Fix-It that tests expect to be created by a macro expansion.
///
/// Currently, it only compares the message of the Fix-It. In the future, it might
/// also compare the expected changes that should be performed by the Fix-It.
public struct FixItSpec {
  /// The expected message of the Fix-It
  public let message: String

  /// The file and line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  internal let originatorFile: StaticString
  internal let originatorLine: UInt

  /// Creates a new `FixItSpec` that describes a Fix-It tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - message: The expected message of the note
  ///   - originatorFile: The file at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  public init(
    message: String,
    originatorFile: StaticString = #file,
    originatorLine: UInt = #line
  ) {
    self.message = message
    self.originatorFile = originatorFile
    self.originatorLine = originatorLine
  }
}

func assertFixIt(
  _ fixIt: FixIt,
  expected spec: FixItSpec
) {
  assertStringsEqualWithDiff(fixIt.message.message, spec.message, "message of Fix-It does not match", file: spec.originatorFile, line: spec.originatorLine)
}

// MARK: - Diagnostic

/// Describes a diagnostic that tests expect to be created by a macro expansion.
public struct DiagnosticSpec {
  /// If not `nil`, the ID, which the diagnostic is expected to have.
  public let id: MessageID?

  /// The expected message of the diagnostic
  public let message: String

  /// The line to which the diagnostic is expected to point
  public let line: Int

  /// The column to which the diagnostic is expected to point
  public let column: Int

  /// The expected severity of the diagnostic
  public let severity: DiagnosticSeverity

  /// If not `nil`, the text the diagnostic is expected to highlight
  public let highlight: String?

  /// The notes that are expected to be attached to the diagnostic
  public let notes: [NoteSpec]

  /// The messages of the Fix-Its the diagnostic is expected to produce
  public let fixIts: [FixItSpec]

  /// The file and line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  internal let originatorFile: StaticString
  internal let originatorLine: UInt

  /// Creates a new `DiagnosticSpec` that describes a diagnsotic tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - id: If not `nil`, the ID, which the diagnostic is expected to have.
  ///   - message: The expected message of the diagnostic
  ///   - line: The line to which the diagnostic is expected to point
  ///   - column: The column to which the diagnostic is expected to point
  ///   - severity: The expected severity of the diagnostic
  ///   - highlight: If not `nil`, the text the diagnostic is expected to highlight
  ///   - notes: The notes that are expected to be attached to the diagnostic
  ///   - fixIts: The messages of the Fix-Its the diagnostic is expected to produce
  ///   - originatorFile: The file at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this `NoteSpec` was created, so that assertion failures can be reported at its location.
  public init(
    id: MessageID? = nil,
    message: String,
    line: Int,
    column: Int,
    severity: DiagnosticSeverity = .error,
    highlight: String? = nil,
    notes: [NoteSpec] = [],
    fixIts: [FixItSpec] = [],
    originatorFile: StaticString = #file,
    originatorLine: UInt = #line
  ) {
    self.id = id
    self.message = message
    self.line = line
    self.column = column
    self.severity = severity
    self.highlight = highlight
    self.notes = notes
    self.fixIts = fixIts
    self.originatorFile = originatorFile
    self.originatorLine = originatorLine
  }
}

func assertDiagnostic<T: SyntaxProtocol>(
  _ diag: Diagnostic,
  in tree: T,
  expected spec: DiagnosticSpec
) {
  if let id = spec.id {
    XCTAssertEqual(diag.diagnosticID, id, "diagnostic ID does not match", file: spec.originatorFile, line: spec.originatorLine)
  }
  assertStringsEqualWithDiff(diag.message, spec.message, "message does not match", file: spec.originatorFile, line: spec.originatorLine)
  let location = diag.location(converter: SourceLocationConverter(file: "", source: tree.description))
  XCTAssertEqual(location.line, spec.line, "line does not match", file: spec.originatorFile, line: spec.originatorLine)
  XCTAssertEqual(location.column, spec.column, "column does not match", file: spec.originatorFile, line: spec.originatorLine)

  XCTAssertEqual(spec.severity, diag.diagMessage.severity, "severity does not match", file: spec.originatorFile, line: spec.originatorLine)

  if let highlight = spec.highlight {
    var highlightedCode = ""
    highlightedCode.append(diag.highlights.first?.with(\.leadingTrivia, []).description ?? "")
    for highlight in diag.highlights.dropFirst().dropLast() {
      highlightedCode.append(highlight.description)
    }
    if diag.highlights.count > 1 {
      highlightedCode.append(diag.highlights.last?.with(\.trailingTrivia, []).description ?? "")
    }

    assertStringsEqualWithDiff(
      highlightedCode.trimmingTrailingWhitespace(),
      highlight.trimmingTrailingWhitespace(),
      "highlight does not match",
      file: spec.originatorFile,
      line: spec.originatorLine
    )
  }
  if diag.notes.count != spec.notes.count {
    XCTFail(
      """
      Expected \(spec.notes.count) notes but received \(diag.notes.count):
      \(diag.notes.map(\.debugDescription).joined(separator: "\n"))
      """,
      file: spec.originatorFile,
      line: spec.originatorLine
    )
  } else {
    for (note, expectedNote) in zip(diag.notes, spec.notes) {
      assertNote(note, in: tree, expected: expectedNote)
    }
  }
  if diag.fixIts.count != spec.fixIts.count {
    XCTFail(
      """
      Expected \(spec.fixIts.count) Fix-Its but received \(diag.fixIts.count):
      \(diag.fixIts.map(\.message.message).joined(separator: "\n"))
      """,
      file: spec.originatorFile,
      line: spec.originatorLine
    )
  } else {
    for (fixIt, expectedFixIt) in zip(diag.fixIts, spec.fixIts) {
      assertFixIt(fixIt, expected: expectedFixIt)
    }
  }
}

/// Assert that expanding the given macros in the original source produces
/// the given expanded source code.
///
/// - Parameters:
///   - originalSource: The original source code, which is expected to contain
///     macros in various places (e.g., `#stringify(x + y)`).
///   - expandedSource: The source code that we expect to see after performing
///     macro expansion on the original source.
///   - diagnostics:
///   - macros: The macros that should be expanded, provided as a dictionary
///     mapping macro names (e.g., `"stringify"`) to implementation types
///     (e.g., `StringifyMacro.self`).
///   - testModuleName: The name of the test module to use.
///   - testFileName: The name of the test file name to use.
public func assertMacroExpansion(
  _ originalSource: String,
  expandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  macros: [String: Macro.Type],
  testModuleName: String = "TestModule",
  testFileName: String = "test.swift",
  indentationWidth: Trivia = .spaces(4),
  file: StaticString = #file,
  line: UInt = #line
) {
  // Parse the original source file.
  let origSourceFile = Parser.parse(source: originalSource)

  // Expand all macros in the source.
  let context = BasicMacroExpansionContext(
    sourceFiles: [origSourceFile: .init(moduleName: testModuleName, fullFilePath: testFileName)]
  )

  let expandedSourceFile = origSourceFile.expand(macros: macros, in: context)
  let diags = ParseDiagnosticsGenerator.diagnostics(for: expandedSourceFile)
  if !diags.isEmpty {
    XCTFail(
      """
      Expanded source should not contain any syntax errors, but contains:
      \(DiagnosticsFormatter.annotatedSource(tree: expandedSourceFile, diags: diags))

      Expanded syntax tree was:
      \(expandedSourceFile.debugDescription)
      """,
      file: file,
      line: line
    )
  }

  let formattedSourceFile = expandedSourceFile.formatted(using: BasicFormat(indentationWidth: indentationWidth))
  assertStringsEqualWithDiff(
    formattedSourceFile.description.trimmingCharacters(in: .newlines),
    expandedSource.trimmingCharacters(in: .newlines),
    additionalInfo: """
      Actual expanded source:
      \(expandedSource)
      """,
    file: file,
    line: line
  )

  if context.diagnostics.count != diagnostics.count {
    XCTFail(
      """
      Expected \(diagnostics.count) diagnostics but received \(context.diagnostics.count):
      \(context.diagnostics.map(\.debugDescription).joined(separator: "\n"))
      """,
      file: file,
      line: line
    )
  } else {
    for (actualDiag, expectedDiag) in zip(context.diagnostics, diagnostics) {
      assertDiagnostic(actualDiag, in: origSourceFile, expected: expectedDiag)
    }
  }
}
