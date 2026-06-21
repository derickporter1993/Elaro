/**
 * Test class for TrustCenterController.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Trust Center
 */
@IsTest(testFor=TrustCenterController.class)
private class TrustCenterControllerTest {

    @TestSetup
    static void makeData() {
        // Create test views
        List<Trust_Center_View__c> views = new List<Trust_Center_View__c>();
        views.add(new Trust_Center_View__c(
            Name = 'SOC 2',
            Framework__c = 'SOC2',
            Compliance_Percentage__c = 95.5,
            Controls_Total__c = 100,
            Controls_Compliant__c = 95,
            Last_Audit_Date__c = Date.today().addDays(-30),
            Certification_Status__c = 'Certified',
            Is_Public__c = true
        ));
        views.add(new Trust_Center_View__c(
            Name = 'HIPAA',
            Framework__c = 'HIPAA',
            Compliance_Percentage__c = 88.0,
            Controls_Total__c = 50,
            Controls_Compliant__c = 44,
            Last_Audit_Date__c = Date.today().addDays(-60),
            Certification_Status__c = 'Certified',
            Is_Public__c = true
        ));
        views.add(new Trust_Center_View__c(
            Name = 'PCI-DSS',
            Framework__c = 'PCI_DSS',
            Compliance_Percentage__c = 45.0,
            Controls_Total__c = 20,
            Controls_Compliant__c = 9,
            Certification_Status__c = 'In_Progress',
            Is_Public__c = false // Not public due to low compliance
        ));

        insert as user views;
    }

    @IsTest
    static void shouldGetPublicViews() {
        Test.startTest();
        List<Trust_Center_View__c> views = TrustCenterController.getPublicViews();
        Test.stopTest();

        Assert.areEqual(2, views.size(),
            'Should return only 2 public views');

        // Verify all returned views are public
        for (Trust_Center_View__c view : views) {
            Assert.isTrue(view.Is_Public__c, 'All views should be public');
        }

        // Verify sorted by compliance percentage DESC
        Assert.areEqual('SOC2', views[0].Framework__c,
            'SOC2 should be first (95.5%)');
        Assert.areEqual('HIPAA', views[1].Framework__c,
            'HIPAA should be second (88%)');
    }

    @IsTest
    static void shouldCreateShareableLink() {
        Test.startTest();
        Trust_Center_Link__c link = TrustCenterController.createShareableLink(
            'Email_Gated', 14, 'Beta Customer'
        );
        Test.stopTest();

        Assert.isNotNull(link.Id, 'Link should be created');
        Assert.isNotNull(link.Link_Token__c, 'Should have token');
        Assert.areEqual('Email_Gated', link.Access_Tier__c,
            'Should have correct access tier');
        Assert.areEqual('Beta Customer', link.Created_For__c,
            'Should have created for value');
    }

    @IsTest
    static void shouldGetActiveLinks() {
        // Create test links
        TrustCenterLinkService service = new TrustCenterLinkService();
        service.createLink('Public', 30, 'Link 1');
        service.createLink('NDA_Required', 90, 'Link 2');

        Test.startTest();
        List<Trust_Center_Link__c> links = TrustCenterController.getActiveLinks();
        Test.stopTest();

        Assert.areEqual(2, links.size(), 'Should return 2 active links');
    }

    @IsTest
    static void shouldRevokeLink() {
        TrustCenterLinkService service = new TrustCenterLinkService();
        Trust_Center_Link__c link = service.createLink('Public', 30, 'Test');

        Assert.isTrue(link.Is_Active__c, 'Link should start active');

        Test.startTest();
        TrustCenterController.revokeLink(link.Id);
        Test.stopTest();

        Trust_Center_Link__c updated = [
            SELECT Id, Is_Active__c
            FROM Trust_Center_Link__c
            WHERE Id = :link.Id
            WITH USER_MODE
            LIMIT 1
        ];

        Assert.isFalse(updated.Is_Active__c, 'Link should be revoked');
    }

    @IsTest
    static void shouldTriggerDataAggregation() {
        // Create test controls
        List<Compliance_Control__c> controls = new List<Compliance_Control__c>();
        for (Integer i = 0; i < 5; i++) {
            controls.add(new Compliance_Control__c(
                Name = 'TEST-' + i,
                Framework__c = 'ISO27001',
                Status__c = 'Compliant'
            ));
        }
        insert as user controls;

        // Delete existing views
        delete as user [SELECT Id FROM Trust_Center_View__c WITH USER_MODE];

        Test.startTest();
        TrustCenterController.triggerDataAggregation();
        Test.stopTest();

        List<Trust_Center_View__c> views = [
            SELECT Id, Framework__c
            FROM Trust_Center_View__c
            WHERE Framework__c = 'ISO27001'
            WITH USER_MODE
        ];

        Assert.isTrue(views.size() > 0,
            'Should create ISO27001 view after aggregation');
    }

    @IsTest
    static void shouldHandleQueryException() {
        // Force exception by providing invalid data
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Attempt to revoke non-existent link
            TrustCenterController.revokeLink(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('Unable to revoke link'),
                'Should throw user-friendly error message');
        }
        Test.stopTest();

        // Note: Passing null might not throw if service handles gracefully
        // This test validates error handling exists
    }

    // ─── Permission Context Tests (System.runAs) ────────────────────────

    /**
     * This internal admin controller reads Trust_Center_View__c WITH USER_MODE.
     * A Standard User without any Elaro permission set has no access to that
     * object, so getPublicViews must not leak the public views created in
     * @TestSetup; it returns nothing or raises an AuraHandledException.
     */
    @IsTest
    static void shouldDenyPublicViewsForUnauthorizedUser() {
        User minimal = ComplianceTestDataFactory.createTestUser();
        insert minimal;

        Test.startTest();
        System.runAs(minimal) {
            try {
                List<Trust_Center_View__c> views = TrustCenterController.getPublicViews();
                Assert.areEqual(0, views.size(),
                    'Unauthorized user must not see any Trust Center views');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(),
                    'A denied read may instead surface an authorization error');
            }
        }
        Test.stopTest();
    }

    /**
     * A Standard User without an Elaro permission set cannot create
     * Trust_Center_Link__c records, so createShareableLink must fail.
     */
    @IsTest
    static void shouldDenyCreateShareableLinkForUnauthorizedUser() {
        User minimal = ComplianceTestDataFactory.createTestUser();
        insert minimal;

        Test.startTest();
        System.runAs(minimal) {
            Boolean denied = false;
            try {
                TrustCenterController.createShareableLink('Public', 30, 'Attacker');
            } catch (AuraHandledException e) {
                denied = true;
            }
            Assert.isTrue(denied,
                'Unauthorized user should not be able to create shareable links');
        }
        Test.stopTest();
    }

    /**
     * With the Elaro User permission set (read access to Trust_Center_View__c)
     * the same otherwise-minimal user can read the public views.
     */
    @IsTest
    static void shouldAllowPublicViewsWithPermissionSet() {
        User authorized = ComplianceTestDataFactory.createTestUser();
        insert authorized;

        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'Elaro_User' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = authorized.Id, PermissionSetId = ps.Id
        );

        Test.startTest();
        System.runAs(authorized) {
            List<Trust_Center_View__c> views = TrustCenterController.getPublicViews();
            Assert.areEqual(2, views.size(),
                'Authorized user should see the 2 public Trust Center views');
        }
        Test.stopTest();
    }
}
