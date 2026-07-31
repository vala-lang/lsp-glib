"""Exercise nested serialization through the generated PyGObject API.

Compact Vala types expose explicit getters and setters through GI, so this
suite avoids relying on Python property synthesis or mutable array proxies.
"""

# PyGObject namespaces are generated at runtime and do not provide .pyi files.
# pyright: reportMissingImports=false

import unittest
from typing import Any

import gi

gi.require_version("Lsp", "3.0")

from gi.repository import GLib, Lsp  # pyright: ignore[reportAttributeAccessIssue]


def make_range(
    start_line: int,
    start_character: int,
    end_line: int,
    end_character: int,
) -> Any:
    start = Lsp.Position()
    start.init(start_line, start_character)
    end = Lsp.Position()
    end.init(end_line, end_character)

    result = Lsp.Range()
    result.init(start, end)
    return result


class DiagnosticTest(unittest.TestCase):
    def test_round_trip(self) -> None:
        diagnostic_range = make_range(1, 2, 3, 4)
        original = Lsp.Diagnostic.new(
            "diagnostic message",
            diagnostic_range,
        )
        original.set_severity(Lsp.DiagnosticSeverity.WARNING)
        original.set_code("V123")
        original.set_source("vala")
        original.set_tags(
            Lsp.DiagnosticTagFlags.UNNECESSARY
            | Lsp.DiagnosticTagFlags.DEPRECATED
        )

        related_location = Lsp.Location()
        related_location.init(
            GLib.Uri.parse("file:///related.vala", GLib.UriFlags.NONE),
            make_range(5, 6, 7, 8),
        )
        related = Lsp.DiagnosticRelatedInformation.new(
            related_location,
            "related message",
        )
        original.set_related_information([related])
        original.set_data(GLib.Variant("s", "opaque payload"))

        decoded = Lsp.Diagnostic.from_variant(original.to_variant())

        decoded_range = decoded.get_range()
        self.assertEqual(decoded_range.start.line, 1)
        self.assertEqual(decoded_range.start.character, 2)
        self.assertEqual(decoded_range.end.line, 3)
        self.assertEqual(decoded_range.end.character, 4)
        self.assertEqual(decoded.get_severity(), Lsp.DiagnosticSeverity.WARNING)
        self.assertEqual(decoded.get_code(), "V123")
        self.assertEqual(decoded.get_source(), "vala")
        self.assertEqual(decoded.get_message(), "diagnostic message")
        self.assertTrue(
            decoded.get_tags() & Lsp.DiagnosticTagFlags.UNNECESSARY
        )
        self.assertTrue(
            decoded.get_tags() & Lsp.DiagnosticTagFlags.DEPRECATED
        )

        decoded_related = decoded.get_related_information()
        self.assertEqual(len(decoded_related), 1)
        self.assertEqual(decoded_related[0].get_message(), "related message")
        self.assertEqual(
            decoded_related[0].get_location().get_uri().to_string(),
            "file:///related.vala",
        )
        self.assertEqual(
            decoded_related[0].get_location().range.end.character,
            8,
        )
        self.assertEqual(decoded.get_data().unpack(), "opaque payload")

    def test_numeric_code(self) -> None:
        encoded = GLib.Variant(
            "a{sv}",
            {
                "range": make_range(0, 0, 0, 1).to_variant(),
                "message": GLib.Variant("s", "numeric code"),
                "code": GLib.Variant("x", 42),
            },
        )

        decoded = Lsp.Diagnostic.from_variant(encoded)
        self.assertEqual(decoded.get_code(), "42")


if __name__ == "__main__":
    unittest.main()
