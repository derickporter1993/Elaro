/**
 * Centralized structured logging service for the Elaro platform.
 * Publishes durable {@link LogEvent__e} Platform Events (HighVolume,
 * PublishImmediately) so audit log entries survive transaction rollback,
 * and emits a System.debug mirror for developer-console visibility.
 *
 * @author Elaro
 * @since v3.1.0 (Spring '26)
 * @group Logging
 * @see LogEvent__e
 */
public with sharing class ElaroLogger {

    private static final Integer MAX_MESSAGE_LENGTH = 131072;
    private static final Integer MAX_LEVEL_LENGTH = 10;

    /**
     * Test-only buffer of every LogEvent__e the logger attempted to publish
     * during the current transaction. Populated regardless of publish success
     * so tests can assert on logging intent without delivering the event bus.
     */
    @TestVisible
    private static List<LogEvent__e> publishedEvents = new List<LogEvent__e>();

    /**
     * Log severity levels.
     */
    public enum Level {
        DEBUG,
        INFO,
        WARN,
        ERROR
    }

    /**
     * Structured log entry assembled before publishing.
     */
    public class LogEntry {
        public Level level;
        public String message;
        public Map<String, Object> context;
        public DateTime timestamp;
        public String userId;

        public LogEntry(Level level, String message, Map<String, Object> context) {
            this.level = level;
            this.message = message;
            this.context = context;
            this.timestamp = System.now();
            this.userId = UserInfo.getUserId();
        }
    }

    /**
     * Primary logging entry point. Publishes a LogEvent__e for durable audit
     * capture and mirrors the entry to System.debug for developer visibility.
     * Logging never throws to callers; publish failures fall back to debug.
     *
     * @param level The severity level
     * @param message The human-readable log message
     * @param context Optional structured context, serialized to Context__c
     */
    public static void log(Level level, String message, Map<String, Object> context) {
        if (!shouldLog(level)) {
            return;
        }

        LogEntry entry = new LogEntry(level, message, context);

        // Developer-console mirror — preserves existing debug-log workflows. The durable
        // audit channel below is the Platform Event; this debug call is intentional UX.
        System.debug(toDebugLoggingLevel(level), formatLogEntry(entry)); // NOPMD: intentional dev-console mirror

        // Durable audit channel — LogEvent__e is publishBehavior=PublishImmediately,
        // so entries survive a DML rollback in the publishing transaction.
        LogEvent__e event = buildEvent(entry);
        publishedEvents.add(event);

        Database.SaveResult result = EventBus.publish(event);
        if (result != null && !result.isSuccess()) {
            // Only reached if the platform itself rejects the publish. Do not throw —
            // logging must never break callers.
            String errorDetail = '';
            for (Database.Error err : result.getErrors()) {
                errorDetail += err.getStatusCode() + ': ' + err.getMessage() + '; ';
            }
            // NOPMD: last-resort fallback when the durable Platform Event publish itself fails.
            System.debug( // NOPMD
                LoggingLevel.ERROR,
                'ElaroLogger publish failed: ' + errorDetail + ' | original=' + formatLogEntry(entry)
            );
        }
    }

    /**
     * Logs a message at DEBUG level.
     *
     * @param message The log message
     */
    public static void debug(String message) {
        log(Level.DEBUG, message, null);
    }

    /**
     * Logs a message at DEBUG level with structured context.
     *
     * @param message The log message
     * @param context Structured context map
     */
    public static void debug(String message, Map<String, Object> context) {
        log(Level.DEBUG, message, context);
    }

    /**
     * Logs a message at INFO level.
     *
     * @param message The log message
     */
    public static void info(String message) {
        log(Level.INFO, message, null);
    }

    /**
     * Logs a message at INFO level, prefixing the message with a source identifier.
     *
     * @param source The originating class/method
     * @param message The log message
     */
    public static void info(String source, String message) {
        log(Level.INFO, source + ': ' + message, null);
    }

    /**
     * Logs a message at INFO level with structured context.
     *
     * @param message The log message
     * @param context Structured context map
     */
    public static void info(String message, Map<String, Object> context) {
        log(Level.INFO, message, context);
    }

    /**
     * Logs a message at WARN level.
     *
     * @param message The log message
     */
    public static void warn(String message) {
        log(Level.WARN, message, null);
    }

    /**
     * Logs a message at WARN level, prefixing the message with a source identifier.
     *
     * @param source The originating class/method
     * @param message The log message
     */
    public static void warn(String source, String message) {
        log(Level.WARN, source + ': ' + message, null);
    }

    /**
     * Logs a message at WARN level with structured context.
     *
     * @param message The log message
     * @param context Structured context map
     */
    public static void warn(String message, Map<String, Object> context) {
        log(Level.WARN, message, context);
    }

    /**
     * Logs a message at ERROR level.
     *
     * @param message The log message
     */
    public static void error(String message) {
        log(Level.ERROR, message, null);
    }

    /**
     * Logs a message at ERROR level, capturing source and stack trace in context.
     *
     * @param source The originating class/method
     * @param message The error message
     * @param stackTrace The stack trace string
     */
    public static void error(String source, String message, String stackTrace) {
        log(
            Level.ERROR,
            message,
            new Map<String, Object>{ 'source' => source, 'stackTrace' => stackTrace }
        );
    }

    /**
     * Logs a message at ERROR level with structured context.
     *
     * @param message The error message
     * @param context Structured context map
     */
    public static void error(String message, Map<String, Object> context) {
        log(Level.ERROR, message, context);
    }

    /**
     * Logs a message at ERROR level, capturing exception metadata in context.
     *
     * @param message The error message
     * @param ex The exception to capture
     */
    public static void error(String message, Exception ex) {
        log(
            Level.ERROR,
            message,
            new Map<String, Object>{
                'exceptionType' => ex.getTypeName(),
                'exceptionMessage' => ex.getMessage(),
                'stackTrace' => ex.getStackTraceString()
            }
        );
    }

    /**
     * Determines whether the supplied level should be emitted. Retained as a hook
     * for future Elaro_Log_Settings__mdt integration; today it always returns true
     * so the durable audit channel is never silenced (including under test).
     *
     * @param level The level under consideration
     * @return Always true
     */
    private static Boolean shouldLog(Level level) {
        return true;
    }

    /**
     * Builds a LogEvent__e from a LogEntry, clamping fields to their max lengths.
     *
     * @param entry The log entry
     * @return A populated LogEvent__e ready to publish
     */
    private static LogEvent__e buildEvent(LogEntry entry) {
        String level = entry.level.name();
        if (level != null && level.length() > MAX_LEVEL_LENGTH) {
            level = level.substring(0, MAX_LEVEL_LENGTH);
        }

        String message = entry.message ?? '';
        if (message.length() > MAX_MESSAGE_LENGTH) {
            message = message.substring(0, MAX_MESSAGE_LENGTH);
        }

        String contextJson = null;
        if (entry.context != null && !entry.context.isEmpty()) {
            contextJson = JSON.serialize(entry.context);
            if (contextJson.length() > MAX_MESSAGE_LENGTH) {
                contextJson = contextJson.substring(0, MAX_MESSAGE_LENGTH);
            }
        }

        return new LogEvent__e(
            Level__c = level,
            Message__c = message,
            Context__c = contextJson,
            Timestamp__c = entry.timestamp,
            User_Id__c = entry.userId
        );
    }

    /**
     * Maps the logger level enum onto the platform LoggingLevel for System.debug.
     *
     * @param level The logger level
     * @return The corresponding System.LoggingLevel
     */
    private static LoggingLevel toDebugLoggingLevel(Level level) {
        if (level == Level.ERROR) {
            return LoggingLevel.ERROR;
        }
        if (level == Level.WARN) {
            return LoggingLevel.WARN;
        }
        if (level == Level.INFO) {
            return LoggingLevel.INFO;
        }
        return LoggingLevel.DEBUG;
    }

    /**
     * Formats a log entry as a single readable line for the debug mirror.
     *
     * @param entry The log entry
     * @return Formatted single-line string
     */
    private static String formatLogEntry(LogEntry entry) {
        List<String> parts = new List<String>{
            '[' + entry.level.name() + ']',
            entry.timestamp.format('yyyy-MM-dd HH:mm:ss'),
            'User=' + entry.userId,
            'Message=' + entry.message
        };

        if (entry.context != null && !entry.context.isEmpty()) {
            parts.add('Context=' + JSON.serialize(entry.context));
        }

        return String.join(parts, ' | ');
    }
}
