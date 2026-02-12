/**
 * Lightweight structured logging service for the Health Check package.
 * Mirrors the ElaroLogger API from the main package but is self-contained
 * since the Health Check ships as a separate 2GP.
 *
 * Suppresses all logging output during test execution to keep test logs clean.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 */
public inherited sharing class HCLogger {

    /**
     * Log severity levels.
     */
    public enum Level {
        DEBUG_LEVEL,
        INFO_LEVEL,
        WARN_LEVEL,
        ERROR_LEVEL
    }

    /**
     * Logs an informational message.
     *
     * @param message The log message
     */
    public static void info(String message) {
        log(Level.INFO_LEVEL, message, null);
    }

    /**
     * Logs an informational message with structured context.
     *
     * @param message The log message
     * @param context Additional key-value context data
     */
    public static void info(String message, Map<String, Object> context) {
        log(Level.INFO_LEVEL, message, context);
    }

    /**
     * Logs a warning message.
     *
     * @param message The log message
     */
    public static void warn(String message) {
        log(Level.WARN_LEVEL, message, null);
    }

    /**
     * Logs a warning message with structured context.
     *
     * @param message The log message
     * @param context Additional key-value context data
     */
    public static void warn(String message, Map<String, Object> context) {
        log(Level.WARN_LEVEL, message, context);
    }

    /**
     * Logs an error message.
     *
     * @param message The log message
     */
    public static void error(String message) {
        log(Level.ERROR_LEVEL, message, null);
    }

    /**
     * Logs an error with full exception details.
     *
     * @param message The log message
     * @param ex The exception to log
     */
    public static void error(String message, Exception ex) {
        Map<String, Object> context = new Map<String, Object>{
            'exceptionType' => ex.getTypeName(),
            'exceptionMessage' => ex.getMessage(),
            'stackTrace' => ex.getStackTraceString()
        };
        log(Level.ERROR_LEVEL, message, context);
    }

    /**
     * Core logging method. Formats and outputs structured log entries.
     * Suppressed during test execution.
     *
     * @param level The severity level
     * @param message The log message
     * @param context Optional structured context data
     */
    private static void log(Level level, String message, Map<String, Object> context) {
        if (Test.isRunningTest()) {
            return;
        }

        List<String> parts = new List<String>{
            '[HC:' + level.name() + ']',
            Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
            message
        };

        if (context != null && !context.isEmpty()) {
            parts.add(JSON.serialize(context));
        }

        String formatted = String.join(parts, ' | ');

        if (level == Level.ERROR_LEVEL) {
            System.debug(LoggingLevel.ERROR, formatted);
        } else if (level == Level.WARN_LEVEL) {
            System.debug(LoggingLevel.WARN, formatted);
        } else {
            System.debug(LoggingLevel.INFO, formatted);
        }
    }
}
