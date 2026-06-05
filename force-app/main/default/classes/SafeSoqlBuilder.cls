/**
 * @description Canonical, injection-safe builder for the WHERE clause of dynamic SOQL.
 * Validates object and field names against the schema (and an object allowlist), validates
 * operators against an allowlist, and emits values as bind variables (never string
 * concatenation), so the result is safe to run via Database.queryWithBinds(..., USER_MODE).
 *
 * This replaces the per-controller filter handling that drifted — notably the raw-string
 * denylist in ElaroMatrixController. The reference for the validation logic is the verified
 * pattern in ElaroDrillDownController; this class lifts it into one place and upgrades value
 * handling from String.escapeSingleQuotes() to true bind variables.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Utilities
 * @see ElaroDrillDownController
 * @see ElaroMatrixController
 */
public inherited sharing class SafeSoqlBuilder {

    /** Operators permitted by default. Callers may pass a narrower set to buildWhere. */
    public static final Set<String> DEFAULT_OPERATORS = new Set<String>{
        '=', '!=', '>', '<', '>=', '<=', 'LIKE', 'IN', 'NOT IN'
    };

    // Strict allowlist of SOQL date literals that may be inlined (no value to bind). Anything
    // not matching this pattern is treated as a bound value, never inlined.
    private static final Pattern DATE_LITERAL = Pattern.compile(
        '(?i)^(YESTERDAY|TODAY|TOMORROW|LAST_WEEK|THIS_WEEK|NEXT_WEEK|LAST_MONTH|THIS_MONTH|' +
        'NEXT_MONTH|LAST_90_DAYS|NEXT_90_DAYS|THIS_QUARTER|LAST_QUARTER|NEXT_QUARTER|THIS_YEAR|' +
        'LAST_YEAR|NEXT_YEAR|(LAST_N_DAYS|NEXT_N_DAYS|LAST_N_WEEKS|NEXT_N_WEEKS|LAST_N_MONTHS|' +
        'NEXT_N_MONTHS|LAST_N_QUARTERS|NEXT_N_QUARTERS|LAST_N_YEARS|NEXT_N_YEARS):[0-9]{1,9})$'
    );

    /**
     * @description Structured filter criterion supplied by a client, replacing a raw filter
     * String. Field and operator are validated; value is bound, never concatenated.
     */
    public class FilterCriteria {
        @AuraEnabled
        public String field { get; set; }
        @AuraEnabled
        public String operator { get; set; }
        @AuraEnabled
        public String value { get; set; }

        /**
         * @description No-arg constructor required for JSON deserialization from LWC.
         */
        public FilterCriteria() {
        }

        /**
         * @description Convenience constructor.
         * @param field The field API name
         * @param operator The comparison operator
         * @param value The (string) value to bind
         */
        public FilterCriteria(String field, String operator, String value) {
            this.field = field;
            this.operator = operator;
            this.value = value;
        }
    }

    /**
     * @description Result of building a WHERE clause: the clause text (with bind tokens) and
     * the binds map to hand to Database.queryWithBinds. whereClause is '' when there are no
     * filters.
     */
    public class SafeQuery {
        public String whereClause;
        public Map<String, Object> binds;

        private SafeQuery(String whereClause, Map<String, Object> binds) {
            this.whereClause = whereClause;
            this.binds = binds;
        }
    }

    /**
     * @description Validates that an object is in the caller's allowlist and is accessible to
     * the running user.
     *
     * @param objectName The SObject API name
     * @param allowlist The set of object API names the caller permits
     * @return The validated object API name
     * @throws AuraHandledException if blank, not allowlisted, unknown, or not accessible
     */
    public static String validateObject(String objectName, Set<String> allowlist) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('Object name is required');
        }
        if (allowlist != null && !allowlist.contains(objectName)) {
            throw new AuraHandledException('Object not authorized: ' + objectName);
        }
        SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        if (sType == null || !sType.getDescribe().isAccessible()) {
            throw new AuraHandledException('Access denied to object: ' + objectName);
        }
        return objectName;
    }

    /**
     * @description Validates that a field exists on the object, is accessible, and (when
     * required) is filterable. Returns the canonical field API name from the schema.
     *
     * @param objectName The SObject API name (assumed already validated)
     * @param fieldName The field API name to validate
     * @param requireFilterable Whether the field must be filterable (for WHERE clauses)
     * @return The canonical field API name
     * @throws AuraHandledException if the field is unknown, inaccessible, or not filterable
     */
    public static String validateField(String objectName, String fieldName, Boolean requireFilterable) {
        String clean = sanitizeIdentifier(fieldName);
        SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        if (sType == null) {
            throw new AuraHandledException('Unknown object: ' + objectName);
        }
        Map<String, SObjectField> fieldMap = sType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(clean.toLowerCase())) {
            throw new AuraHandledException('Invalid field: ' + fieldName);
        }
        DescribeFieldResult dfr = fieldMap.get(clean.toLowerCase()).getDescribe();
        if (!dfr.isAccessible()) {
            throw new AuraHandledException('Field not accessible: ' + fieldName);
        }
        if (requireFilterable && !dfr.isFilterable()) {
            throw new AuraHandledException('Field not filterable: ' + fieldName);
        }
        return dfr.getName();
    }

    /**
     * @description Validates and normalizes an operator against an allowlist.
     *
     * @param operator The operator to validate
     * @param allowlist The permitted operators (DEFAULT_OPERATORS if null)
     * @return The upper-cased, validated operator
     * @throws AuraHandledException if the operator is blank or not allowlisted
     */
    public static String validateOperator(String operator, Set<String> allowlist) {
        if (String.isBlank(operator)) {
            throw new AuraHandledException('Filter operator is required');
        }
        Set<String> allowed = (allowlist == null) ? DEFAULT_OPERATORS : allowlist;
        String normalized = operator.trim().toUpperCase();
        // Symbol operators are not upper-cased meaningfully; check both forms.
        if (!allowed.contains(operator.trim()) && !allowed.contains(normalized)) {
            throw new AuraHandledException('Operator not allowed: ' + operator);
        }
        return allowed.contains(operator.trim()) ? operator.trim() : normalized;
    }

    /**
     * @description Builds a parameterized WHERE clause from structured filters. Every value is
     * emitted as a bind variable (:elaroBindN); the only inlined tokens are schema-validated
     * field names, allowlisted operators, and strictly-validated SOQL date literals.
     *
     * @param filters The structured filter criteria (may be null/empty)
     * @param objectName The SObject API name (assumed already validated)
     * @param operatorAllowlist Permitted operators (DEFAULT_OPERATORS if null)
     * @return A SafeQuery whose whereClause is '' or ' WHERE ...' and whose binds map is
     *         ready for Database.queryWithBinds
     * @throws AuraHandledException if any field/operator is invalid
     */
    public static SafeQuery buildWhere(
        List<FilterCriteria> filters,
        String objectName,
        Set<String> operatorAllowlist
    ) {
        Map<String, Object> binds = new Map<String, Object>();
        if (filters == null || filters.isEmpty()) {
            return new SafeQuery('', binds);
        }

        List<String> parts = new List<String>();
        Integer bindIndex = 0;

        for (FilterCriteria f : filters) {
            String field = validateField(objectName, f.field, true);
            String op = validateOperator(f.operator, operatorAllowlist);

            // NULL comparison — no bind needed.
            if (f.value == null || f.value.equalsIgnoreCase('null')) {
                if (op == '=' || op == '!=') {
                    parts.add(field + (op == '=' ? ' = null' : ' != null'));
                }
                continue;
            }

            String token = 'elaroBind' + bindIndex;
            bindIndex++;

            if (op == 'IN' || op == 'NOT IN') {
                List<String> vals = new List<String>();
                for (String v : f.value.split(',')) {
                    vals.add(v.trim());
                }
                binds.put(token, vals);
                parts.add(field + ' ' + op + ' :' + token);
            } else if (op == 'LIKE') {
                binds.put(token, '%' + f.value + '%');
                parts.add(field + ' LIKE :' + token);
            } else if (isDateLiteral(f.value)) {
                // SOQL date literals (e.g. LAST_N_MONTHS:6) cannot be bound; inline only after
                // strict allowlist validation, so no injection is possible.
                parts.add(field + ' ' + op + ' ' + f.value.toUpperCase());
                bindIndex--; // no bind consumed
            } else {
                binds.put(token, coerceValue(f.value));
                parts.add(field + ' ' + op + ' :' + token);
            }
        }

        String clause = parts.isEmpty() ? '' : ' WHERE ' + String.join(parts, ' AND ');
        return new SafeQuery(clause, binds);
    }

    /**
     * @description Coerces a string value to the most specific bindable type (Decimal/Boolean/
     * String) so the bind matches typical field comparisons.
     *
     * @param value The raw string value
     * @return A Decimal, Boolean, or String suitable for binding
     */
    private static Object coerceValue(String value) {
        if (value.isNumeric() || value.matches('^-?[0-9]+(\\.[0-9]+)?$')) {
            return Decimal.valueOf(value);
        }
        if (value.equalsIgnoreCase('true') || value.equalsIgnoreCase('false')) {
            return Boolean.valueOf(value);
        }
        return value;
    }

    /**
     * @description Returns true if the value is a strictly-validated SOQL date literal.
     *
     * @param value The value to test
     * @return true if value matches the date-literal allowlist
     */
    private static Boolean isDateLiteral(String value) {
        return DATE_LITERAL.matcher(value).matches();
    }

    /**
     * @description Strips any character that is not valid in a SOQL identifier, as a backstop
     * before the schema check.
     *
     * @param identifier The raw identifier
     * @return The identifier with only [A-Za-z0-9_.] retained
     */
    private static String sanitizeIdentifier(String identifier) {
        if (String.isBlank(identifier)) {
            return '';
        }
        return identifier.replaceAll('[^a-zA-Z0-9_.]+', '');
    }
}
