import GLib from 'gi://GLib';
import Lsp from 'gi://Lsp?version=3.0';

const assertEqual = (actual, expected, message) => {
    if (actual !== expected)
        throw new Error(`${message}: expected ${expected}, got ${actual}`);
};

const assert = (condition, message) => {
    if (!condition)
        throw new Error(message);
};

const makePosition = (line, character) => {
    const position = new Lsp.Position();
    position.init(line, character);
    return position;
};

const range = new Lsp.Range();
range.init(makePosition(4, 2), makePosition(4, 11));

const diagnostic = Lsp.Diagnostic.new(
    'unused local',
    range,
);
diagnostic.set_severity(Lsp.DiagnosticSeverity.WARNING);
diagnostic.set_code('W001');
diagnostic.set_source('gjs-test');
diagnostic.set_tags(Lsp.DiagnosticTagFlags.UNNECESSARY |
    Lsp.DiagnosticTagFlags.DEPRECATED);

const relatedLocation = new Lsp.Location();
relatedLocation.init(
    GLib.Uri.parse('file:///related.vala', GLib.UriFlags.NONE),
    range,
);
const related = Lsp.DiagnosticRelatedInformation.new(
    relatedLocation,
    'related message',
);
diagnostic.set_related_information([related]);
diagnostic.set_data(new GLib.Variant('s', 'diagnostic-token'));

const decoded = Lsp.Diagnostic.from_variant(diagnostic.to_variant());
assertEqual(decoded.get_range().start.line, 4, 'range did not round-trip');
assertEqual(decoded.get_severity(), Lsp.DiagnosticSeverity.WARNING,
    'severity did not round-trip');
assertEqual(decoded.get_code(), 'W001', 'code did not round-trip');
assertEqual(decoded.get_source(), 'gjs-test', 'source did not round-trip');
assert(decoded.get_tags() & Lsp.DiagnosticTagFlags.UNNECESSARY,
    'unnecessary tag did not round-trip');
assert(decoded.get_tags() & Lsp.DiagnosticTagFlags.DEPRECATED,
    'deprecated tag did not round-trip');
const decodedRelated = decoded.get_related_information();
assertEqual(decodedRelated.length, 1,
    'related diagnostic count did not round-trip');
assertEqual(decodedRelated[0].get_message(), 'related message',
    'related diagnostic did not round-trip');
assertEqual(decoded.get_data().deepUnpack(), 'diagnostic-token',
    'data did not round-trip');
