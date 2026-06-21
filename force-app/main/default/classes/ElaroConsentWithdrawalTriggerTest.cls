/**
 * Tests for ElaroConsentWithdrawalTrigger and ElaroConsentWithdrawalHandler.
 *
 * Exercises the GDPR Article 7 consent-withdrawal flow: when a Consent__c record
 * transitions Consent_Withdrawn__c from false to true (after update), the handler
 * updates the related Contact's communication preferences, publishes
 * GDPR_Erasure_Event__e audit events, and (for full-processing withdrawals) creates
 * GDPR_Erasure_Request__c records.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 * @see ElaroConsentWithdrawalTrigger
 * @see ElaroConsentWithdrawalHandler
 */
@IsTest(testFor=ElaroConsentWithdrawalHandler.class)
private class ElaroConsentWithdrawalTriggerTest {

    @TestSetup
    static void makeData() {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 205; i++) {
            contacts.add(new Contact(
                LastName = 'Consenter ' + i,
                Email = 'consenter' + i + '@elaro.test',
                HasOptedOutOfEmail = false,
                DoNotCall = false
            ));
        }
        insert contacts;
    }

    /**
     * Builds a Consent__c with all required fields populated
     * (Consent_Type__c, Consent_Date__c, Consent_Version__c).
     */
    private static Consent__c newConsent(Id contactId, String consentType, Boolean withdrawn) {
        return new Consent__c(
            Contact__c = contactId,
            Consent_Type__c = consentType,
            Consent_Withdrawn__c = withdrawn,
            Consent_Date__c = System.now().addDays(-30),
            Consent_Version__c = 'v1.0'
        );
    }

    /**
     * Withdrawing a 'Data Processing' consent should flip the Contact to
     * DoNotCall = true and HasOptedOutOfEmail = true.
     */
    @IsTest
    static void shouldOptOutContactOnDataProcessingWithdrawal() {
        Contact c = [SELECT Id FROM Contact WHERE Email = 'consenter0@elaro.test' WITH USER_MODE LIMIT 1];
        Consent__c consent = newConsent(c.Id, 'Data Processing', false);
        insert as user consent;

        Test.startTest();
        consent.Consent_Withdrawn__c = true;
        update as user consent;
        Test.stopTest();

        Contact updated = [
            SELECT Id, DoNotCall, HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :c.Id
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.isTrue(updated.DoNotCall, 'Data Processing withdrawal should set DoNotCall = true');
        Assert.isTrue(updated.HasOptedOutOfEmail, 'Data Processing withdrawal should set HasOptedOutOfEmail = true');
    }

    /**
     * Withdrawing a 'Third Party Sharing' consent currently fails because the handler
     * assigns System.now() (a Datetime) to Contact.CCPA_OptOut_Date__c, which is a Date
     * field. The illegal assignment surfaces as a DmlException out of the update.
     *
     * This test pins the present (buggy) behavior: the trigger does not swallow handler
     * exceptions, so the consent update is rolled back. If the handler is fixed to write
     * a Date (e.g. System.today()), this test should be updated to assert the CCPA flags
     * are set on the Contact instead.
     */
    @IsTest
    static void shouldSurfaceCcpaDateTypeBugOnThirdPartySharingWithdrawal() {
        Contact c = [SELECT Id FROM Contact WHERE Email = 'consenter1@elaro.test' WITH USER_MODE LIMIT 1];
        Consent__c consent = newConsent(c.Id, 'Third Party Sharing', false);
        insert as user consent;

        Boolean threw = false;
        Test.startTest();
        try {
            consent.Consent_Withdrawn__c = true;
            update as user consent;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(
            threw,
            'Third Party Sharing withdrawal currently throws because a Datetime is assigned to the Date field CCPA_OptOut_Date__c'
        );
        Contact unchanged = [
            SELECT Id, CCPA_Do_Not_Sell__c FROM Contact WHERE Id = :c.Id WITH USER_MODE LIMIT 1
        ];
        Assert.isFalse(unchanged.CCPA_Do_Not_Sell__c, 'Failed update should leave the Contact unchanged');
    }

    /**
     * Updating a consent without flipping the withdrawn flag (false -> false) must
     * not change the Contact's preferences. Guards against the trigger firing on
     * unrelated updates.
     */
    @IsTest
    static void shouldNotOptOutWhenWithdrawnFlagUnchanged() {
        Contact c = [SELECT Id FROM Contact WHERE Email = 'consenter2@elaro.test' WITH USER_MODE LIMIT 1];
        Consent__c consent = newConsent(c.Id, 'Data Processing', false);
        consent.Consent_Source__c = 'Web Form';
        insert as user consent;

        Test.startTest();
        // Change an unrelated field; withdrawn stays false.
        consent.Consent_Source__c = 'Phone';
        update as user consent;
        Test.stopTest();

        Contact updated = [
            SELECT Id, DoNotCall, HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :c.Id
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.isFalse(updated.DoNotCall, 'No withdrawal transition should leave DoNotCall unchanged');
        Assert.isFalse(updated.HasOptedOutOfEmail, 'No withdrawal transition should leave HasOptedOutOfEmail unchanged');
    }

    /**
     * Re-saving an already-withdrawn consent (true -> true) is not a new withdrawal
     * transition, so no Contact preference changes should occur.
     */
    @IsTest
    static void shouldIgnoreAlreadyWithdrawnConsent() {
        Contact c = [SELECT Id FROM Contact WHERE Email = 'consenter3@elaro.test' WITH USER_MODE LIMIT 1];
        Consent__c consent = newConsent(c.Id, 'Data Processing', true);
        insert as user consent;
        // Reset the contact so we can detect any (incorrect) change from the true->true update.
        update as user new Contact(Id = c.Id, DoNotCall = false, HasOptedOutOfEmail = false);

        Test.startTest();
        consent.Consent_Source__c = 'API';
        update as user consent;
        Test.stopTest();

        Contact updated = [
            SELECT Id, DoNotCall, HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :c.Id
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.isFalse(updated.DoNotCall, 'true->true is not a new withdrawal; DoNotCall must stay false');
        Assert.isFalse(updated.HasOptedOutOfEmail, 'true->true is not a new withdrawal; opt-out must stay false');
    }

    /**
     * Bulk withdrawal of 200 consents in a single update must process every record
     * and stay within governor limits (no SOQL/DML in loops).
     */
    @IsTest
    static void shouldProcessBulkWithdrawals() {
        List<Contact> contacts = [
            SELECT Id FROM Contact WHERE Email LIKE 'consenter%@elaro.test' WITH USER_MODE LIMIT 200
        ];
        Assert.areEqual(200, contacts.size(), 'Test setup should provide 200 contacts');

        List<Consent__c> consents = new List<Consent__c>();
        for (Contact c : contacts) {
            consents.add(newConsent(c.Id, 'Data Processing', false));
        }
        insert as user consents;

        for (Consent__c consent : consents) {
            consent.Consent_Withdrawn__c = true;
        }

        Test.startTest();
        update as user consents;
        Test.stopTest();

        Integer optedOut = [
            SELECT COUNT()
            FROM Contact
            WHERE Id IN :contacts AND DoNotCall = true AND HasOptedOutOfEmail = true
            WITH USER_MODE
        ];
        Assert.areEqual(200, optedOut, 'All 200 contacts should be opted out after bulk withdrawal');
    }

    /**
     * Withdrawing a consent type the handler does not act on ('Profiling') still
     * publishes an audit event but must leave the Contact's preferences untouched,
     * covering the "no matching consent type" branch of updateContactPreferences.
     */
    @IsTest
    static void shouldNotUpdateContactForUnhandledConsentType() {
        Contact c = [SELECT Id FROM Contact WHERE Email = 'consenter4@elaro.test' WITH USER_MODE LIMIT 1];
        Consent__c consent = newConsent(c.Id, 'Profiling', false);
        insert as user consent;

        Test.startTest();
        consent.Consent_Withdrawn__c = true;
        update as user consent;
        Test.stopTest();

        Contact updated = [
            SELECT Id, DoNotCall, HasOptedOutOfEmail
            FROM Contact
            WHERE Id = :c.Id
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.isFalse(updated.DoNotCall, 'Profiling withdrawal is not handled; DoNotCall must stay false');
        Assert.isFalse(updated.HasOptedOutOfEmail, 'Profiling withdrawal is not handled; opt-out must stay false');

        Consent__c reloaded = [
            SELECT Id, Consent_Withdrawn__c FROM Consent__c WHERE Id = :consent.Id WITH USER_MODE LIMIT 1
        ];
        Assert.isTrue(reloaded.Consent_Withdrawn__c, 'Withdrawal flag should persist for unhandled consent types');
    }
}
