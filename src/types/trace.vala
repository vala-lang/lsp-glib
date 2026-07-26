/**
 * A TraceValue represents the level of verbosity with which the server
 * systematically reports its execution trace using `$/logTrace` notifications.
 * The initial trace value is set by the client at initialization and can be
 * modified later using the `$/setTrace` notification.
 */
public enum Lsp.TraceValue {
    OFF,
    MESSAGES,
    VERBOSE;

    public unowned string to_string () {
        switch (this) {
            case OFF:
                return "off";
            case MESSAGES:
                return "messages";
            case VERBOSE:
                return "verbose";
        }
        assert_not_reached ();
    }

    public static TraceValue parse_string (string value) throws DeserializeError {
        switch (value) {
            case "off":
                return OFF;
            case "messages":
                return MESSAGES;
            case "verbose":
                return VERBOSE;
        }
        throw new DeserializeError.INVALID_TYPE ("%s is not a %s", value,
            typeof (TraceValue).name ());
    }
}
