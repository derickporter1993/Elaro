/**
 * @description Tests for {@link SafeSoqlBuilder}. Covers validation (object/field/operator),
 * WHERE-clause construction, value binding, and — most importantly — that an injection
 * payload is bound as a literal value rather than concatenated into the query.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Utilities
 * @see SafeSoqlBuilder
 */
@IsTest(testFor=SafeSoqlBuilder.class)
private class SafeSoqlBuilderTest {

    private static final Set<String> ALLOWED = new Set<String>{ 'Account' };

    @IsTest
    static void validateObjectAcceptsAllowlistedAccessibleObject() {
        Test.startTest();
        String result = SafeSoqlBuilder.validateObject('Account', ALLOWED);
        Test.stopTest();
        Assert.areEqual('Account', result, 'An allowlisted, accessible object should validate');
    }

    @IsTest
    static void validateObjectRejectsNonAllowlistedObject() {
        Test.startTest();
        Exception caught;
        try {
            SafeSoqlBuilder.validateObject('Contact', ALLOWED);
            Assert.fail('Expected rejection of a non-allowlisted object');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();
        Assert.isNotNull(caught, 'A non-allowlisted object must be rejected');
    }

    @IsTest
    static void validateObjectRejectsBlank() {
        Test.startTest();
        Exception caught;
        try {
            SafeSoqlBuilder.validateObject('', ALLOWED);
            Assert.fail('Expected rejection of a blank object');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();
        Assert.isNotNull(caught, 'A blank object name must be rejected');
    }

    @IsTest
    static void validateFieldRejectsUnknownField() {
        Test.startTest();
        Exception caught;
        try {
            SafeSoqlBuilder.validateField('Account', 'Not_A_Real_Field__c', true);
            Assert.fail('Expected rejection of an unknown field');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();
        Assert.isNotNull(caught, 'An unknown field must be rejected');
    }

    @IsTest
    static void validateFieldReturnsCanonicalName() {
        Test.startTest();
        String result = SafeSoqlBuilder.validateField('Account', 'name', true);
        Test.stopTest();
        Assert.areEqual('Name', result, 'Field validation should return the canonical API name');
    }

    @IsTest
    static void validateOperatorRejectsDisallowedOperator() {
        Test.startTest();
        Exception caught;
        try {
            SafeSoqlBuilder.validateOperator('; DROP', null);
            Assert.fail('Expected rejection of a disallowed operator');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();
        Assert.isNotNull(caught, 'A disallowed operator must be rejected');
    }

    @IsTest
    static void buildWhereReturnsEmptyForNoFilters() {
        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(null, 'Account', null);
        Test.stopTest();
        Assert.areEqual('', q.whereClause, 'No filters should yield an empty WHERE clause');
        Assert.isTrue(q.binds.isEmpty(), 'No filters should yield no binds');
    }

    @IsTest
    static void buildWhereBindsStringValue() {
        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('Name', '=', 'Acme')
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        Test.stopTest();

        Assert.isTrue(q.whereClause.contains(':elaroBind0'), 'Value should be a bind token, not inline');
        Assert.isTrue(q.whereClause.contains('Name ='), 'Clause should reference the validated field');
        Assert.areEqual('Acme', q.binds.get('elaroBind0'), 'The bind map should hold the literal value');
    }

    @IsTest
    static void buildWhereNeutralizesInjectionPayload() {
        // The classic boolean-logic injection that a denylist + quote-escaper misses.
        String payload = '\' OR Name != \'';
        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('Name', '=', payload)
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        Test.stopTest();

        // The payload must be bound as a literal value, never concatenated into the clause.
        Assert.isTrue(q.whereClause.contains(':elaroBind0'), 'Payload must be bound, not inlined');
        Assert.isFalse(
            q.whereClause.contains('OR Name'),
            'The injected boolean logic must NOT appear in the query text'
        );
        Assert.areEqual(payload, q.binds.get('elaroBind0'), 'The payload is inert data in the bind map');
    }

    @IsTest
    static void buildWhereHandlesInList() {
        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('Name', 'IN', 'Acme, Globex, Initech')
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        Test.stopTest();

        Assert.isTrue(q.whereClause.contains('Name IN :elaroBind0'), 'IN should bind a list token');
        Assert.isTrue(q.binds.get('elaroBind0') instanceof List<String>, 'IN bind should be a List<String>');
        Assert.areEqual(3, ((List<String>) q.binds.get('elaroBind0')).size(), 'List should split on commas');
    }

    @IsTest
    static void buildWhereHandlesNullComparison() {
        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('Industry', '=', 'null')
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        Test.stopTest();

        Assert.isTrue(q.whereClause.contains('Industry = null'), 'Null comparison should be inlined safely');
        Assert.isTrue(q.binds.isEmpty(), 'A null comparison needs no bind');
    }

    @IsTest
    static void buildWhereCoercesNumericValue() {
        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('NumberOfEmployees', '>', '100')
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        Test.stopTest();

        Assert.isTrue(q.binds.get('elaroBind0') instanceof Decimal, 'Numeric value should bind as Decimal');
    }

    @IsTest
    static void buildWhereProducesExecutableQuery() {
        Account a = new Account(Name = 'SafeSoqlBuilder Acme', NumberOfEmployees = 250);
        insert a;

        List<SafeSoqlBuilder.FilterCriteria> filters = new List<SafeSoqlBuilder.FilterCriteria>{
            new SafeSoqlBuilder.FilterCriteria('Name', '=', 'SafeSoqlBuilder Acme')
        };

        Test.startTest();
        SafeSoqlBuilder.SafeQuery q = SafeSoqlBuilder.buildWhere(filters, 'Account', null);
        String soql = 'SELECT Id, Name FROM Account' + q.whereClause + ' WITH USER_MODE';
        List<Account> rows = Database.queryWithBinds(soql, q.binds, AccessLevel.USER_MODE);
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'The bound query should return exactly the matching record');
        Assert.areEqual('SafeSoqlBuilder Acme', rows[0].Name, 'The returned record should be the inserted one');
    }
}
