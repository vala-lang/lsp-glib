/**
 * Errors that can be returned in JSON-RPC and LSP error responses.
 *
 * Reserved error-range boundaries are intentionally excluded because they do
 * not represent errors that can be returned in a response.
 */
public errordomain Lsp.ProtocolError {
    PARSE_ERROR            = -32700,
    INVALID_REQUEST        = -32600,
    METHOD_NOT_FOUND       = -32601,
    INVALID_PARAMS         = -32602,
    INTERNAL_ERROR         = -32603,
    SERVER_NOT_INITIALIZED = -32002,
    UNKNOWN_ERROR_CODE     = -32001,
    REQUEST_FAILED         = -32803,
    SERVER_CANCELLED       = -32802,
    CONTENT_MODIFIED       = -32801,
    REQUEST_CANCELLED      = -32800
}
