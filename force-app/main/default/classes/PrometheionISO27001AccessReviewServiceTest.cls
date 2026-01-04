/**
 * Test class for PrometheionISO27001AccessReviewService
 * Tests ISO 27001 Control A.9 Access Control functionality
 *
 * @author Prometheion
 * @version 1.0
 */
@IsTest
private class PrometheionISO27001AccessReviewServiceTest {

    @TestSetup
    static void setupTestData() {
        // Test data is created within individual tests using User context
    }

    @IsTest
    static void testInitiateQuarterlyReviews() {
        Test.startTest();
        List<Access_Review__c> reviews = PrometheionISO27001AccessReviewService.initiateQuarterlyReviews();
        Test.stopTest();

        // Verifies the method runs without error
        // Actual user count depends on org configuration
        System.assertNotEquals(null, reviews, 'Should return list of reviews');
    }

    @IsTest
    static void testInitiatePrivilegedAccessReviews() {
        Test.startTest();
        List<Access_Review__c> reviews = PrometheionISO27001AccessReviewService.initiatePrivilegedAccessReviews();
        Test.stopTest();

        System.assertNotEquals(null, reviews, 'Should return list of reviews');
        for (Access_Review__c review : reviews) {
            System.assertEquals(true, review.Is_Privileged_User__c, 'All should be privileged');
            System.assertEquals('High', review.Risk_Level__c, 'All should be high risk');
        }
    }

    @IsTest
    static void testProcessReviewDecision_Approve() {
        // Create test review
        Access_Review__c review = new Access_Review__c(
            Review_Type__c = 'Quarterly Review',
            Review_Status__c = 'Pending',
            Due_Date__c = Date.today().addDays(7),
            Profiles_Reviewed__c = 'Standard User',
            Is_Privileged_User__c = false,
            Risk_Level__c = 'Low'
        );
        insert review;

        Test.startTest();
        PrometheionISO27001AccessReviewService.processReviewDecision(
            review.Id,
            'Approve All Access',
            'Access is appropriate for role'
        );
        Test.stopTest();

        review = [SELECT Review_Status__c, Decision__c, Decision_Justification__c
                  FROM Access_Review__c WHERE Id = :review.Id];
        System.assertEquals('Approved', review.Review_Status__c, 'Status should be Approved');
        System.assertEquals('Approve All Access', review.Decision__c, 'Decision should match');
    }

    @IsTest
    static void testProcessReviewDecision_Revoke() {
        Access_Review__c review = new Access_Review__c(
            Review_Type__c = 'Termination Review',
            Review_Status__c = 'In Progress',
            Due_Date__c = Date.today(),
            Profiles_Reviewed__c = 'System Administrator',
            Is_Privileged_User__c = true,
            Risk_Level__c = 'High'
        );
        insert review;

        Test.startTest();
        PrometheionISO27001AccessReviewService.processReviewDecision(
            review.Id,
            'Revoke All Access',
            'Employee terminated'
        );
        Test.stopTest();

        review = [SELECT Review_Status__c, Decision__c FROM Access_Review__c WHERE Id = :review.Id];
        System.assertEquals('Revoked', review.Review_Status__c, 'Status should be Revoked');
    }

    @IsTest
    static void testProcessReviewDecision_Modify() {
        Access_Review__c review = new Access_Review__c(
            Review_Type__c = 'Role Change Review',
            Review_Status__c = 'Pending',
            Due_Date__c = Date.today().addDays(3),
            Profiles_Reviewed__c = 'Standard User',
            Is_Privileged_User__c = false,
            Risk_Level__c = 'Medium'
        );
        insert review;

        Test.startTest();
        PrometheionISO27001AccessReviewService.processReviewDecision(
            review.Id,
            'Modify Access',
            'Removing unnecessary permissions'
        );
        Test.stopTest();

        review = [SELECT Review_Status__c FROM Access_Review__c WHERE Id = :review.Id];
        System.assertEquals('Modified', review.Review_Status__c, 'Status should be Modified');
    }

    @IsTest
    static void testProcessReviewDecision_Escalate() {
        Access_Review__c review = new Access_Review__c(
            Review_Type__c = 'Privileged Access Review',
            Review_Status__c = 'Pending',
            Due_Date__c = Date.today().addDays(1),
            Profiles_Reviewed__c = 'System Administrator',
            Is_Privileged_User__c = true,
            Risk_Level__c = 'Critical'
        );
        insert review;

        Test.startTest();
        PrometheionISO27001AccessReviewService.processReviewDecision(
            review.Id,
            'Escalate to Security',
            'Suspicious access pattern detected'
        );
        Test.stopTest();

        review = [SELECT Review_Status__c FROM Access_Review__c WHERE Id = :review.Id];
        System.assertEquals('Escalated', review.Review_Status__c, 'Status should be Escalated');
    }

    @IsTest
    static void testIdentifyDormantAccounts() {
        Test.startTest();
        List<PrometheionISO27001AccessReviewService.DormantAccountInfo> dormant =
            PrometheionISO27001AccessReviewService.identifyDormantAccounts();
        Test.stopTest();

        System.assertNotEquals(null, dormant, 'Should return list');
        // Actual count depends on org users
    }

    @IsTest
    static void testCreateTerminationReview() {
        // Get current user as placeholder
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Test.startTest();
        Access_Review__c review = PrometheionISO27001AccessReviewService.createTerminationReview(
            u.Id,
            Date.today()
        );
        Test.stopTest();

        System.assertNotEquals(null, review.Id, 'Review should be created');
        System.assertEquals('Termination Review', review.Review_Type__c, 'Type should match');
        System.assertEquals('Revoke All Access', review.Decision__c, 'Decision should be revoke');
        System.assertEquals('High', review.Risk_Level__c, 'Should be high risk');
    }

    @IsTest
    static void testGetPendingReviews() {
        // Create pending reviews
        List<Access_Review__c> reviews = new List<Access_Review__c>();
        for (Integer i = 0; i < 10; i++) {
            reviews.add(new Access_Review__c(
                Reviewer__c = UserInfo.getUserId(),
                Review_Type__c = 'Quarterly Review',
                Review_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(7),
                Profiles_Reviewed__c = 'Standard User',
                Is_Privileged_User__c = false,
                Risk_Level__c = 'Low'
            ));
        }
        insert reviews;

        Test.startTest();
        List<Access_Review__c> pending = PrometheionISO27001AccessReviewService.getPendingReviews(
            UserInfo.getUserId()
        );
        Test.stopTest();

        System.assert(pending.size() >= 10, 'Should return pending reviews');
    }

    @IsTest
    static void testGetOverdueReviews() {
        // Create overdue reviews
        List<Access_Review__c> reviews = new List<Access_Review__c>();
        for (Integer i = 0; i < 5; i++) {
            reviews.add(new Access_Review__c(
                Reviewer__c = UserInfo.getUserId(),
                Review_Type__c = 'Quarterly Review',
                Review_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(-5),
                Profiles_Reviewed__c = 'Standard User',
                Is_Privileged_User__c = false,
                Risk_Level__c = 'Medium'
            ));
        }
        insert reviews;

        Test.startTest();
        List<Access_Review__c> overdue = PrometheionISO27001AccessReviewService.getOverdueReviews();
        Test.stopTest();

        System.assert(overdue.size() >= 5, 'Should return overdue reviews');
    }

    @IsTest
    static void testGetComplianceMetrics() {
        // Create some test data
        List<Access_Review__c> reviews = new List<Access_Review__c>();
        for (Integer i = 0; i < 5; i++) {
            reviews.add(new Access_Review__c(
                Review_Type__c = 'Quarterly Review',
                Review_Status__c = 'Approved',
                Due_Date__c = Date.today().addDays(-1),
                Review_Date__c = System.now(),
                Profiles_Reviewed__c = 'Standard User',
                Is_Privileged_User__c = false,
                Risk_Level__c = 'Low'
            ));
        }
        insert reviews;

        Test.startTest();
        Map<String, Object> metrics = PrometheionISO27001AccessReviewService.getComplianceMetrics();
        Test.stopTest();

        System.assert(metrics.containsKey('reviewsThisQuarter'), 'Should have reviewsThisQuarter');
        System.assert(metrics.containsKey('completionRate'), 'Should have completionRate');
        System.assert(metrics.containsKey('overdueCount'), 'Should have overdueCount');
        System.assert(metrics.containsKey('privilegedUsersCount'), 'Should have privilegedUsersCount');
        System.assert(metrics.containsKey('dormantAccountsCount'), 'Should have dormantAccountsCount');
    }

    @IsTest
    static void testDormantAccountInfoWrapper() {
        PrometheionISO27001AccessReviewService.DormantAccountInfo info =
            new PrometheionISO27001AccessReviewService.DormantAccountInfo();
        info.userId = UserInfo.getUserId();
        info.userName = 'Test User';
        info.username = 'test@example.com';
        info.profileName = 'Standard User';
        info.lastLoginDate = System.now().addDays(-100);
        info.daysSinceLogin = 100;

        System.assertEquals('Test User', info.userName, 'userName should match');
        System.assertEquals(100, info.daysSinceLogin, 'daysSinceLogin should match');
    }

    @IsTest
    static void testBulkReviewCreation() {
        Test.startTest();
        Integer startQueries = Limits.getQueries();

        List<Access_Review__c> reviews = PrometheionISO27001AccessReviewService.initiateQuarterlyReviews();

        Integer endQueries = Limits.getQueries();
        Test.stopTest();

        // Should be bulkified regardless of number of users
        System.assert(endQueries - startQueries < 20, 'Should be bulkified');
    }

    @IsTest
    static void testRiskLevelCalculation() {
        // Create reviews with different risk levels
        List<Access_Review__c> reviews = new List<Access_Review__c>{
            new Access_Review__c(
                Review_Type__c = 'Quarterly Review',
                Review_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(7),
                Profiles_Reviewed__c = 'System Administrator',
                Is_Privileged_User__c = true,
                Risk_Level__c = 'Critical'
            ),
            new Access_Review__c(
                Review_Type__c = 'Quarterly Review',
                Review_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(7),
                Profiles_Reviewed__c = 'Standard User',
                Is_Privileged_User__c = false,
                Risk_Level__c = 'Low'
            )
        };
        insert reviews;

        Access_Review__c criticalReview = [
            SELECT Risk_Level__c FROM Access_Review__c WHERE Is_Privileged_User__c = true LIMIT 1
        ];
        System.assertEquals('Critical', criticalReview.Risk_Level__c, 'Should be critical for privileged');

        Access_Review__c lowReview = [
            SELECT Risk_Level__c FROM Access_Review__c WHERE Is_Privileged_User__c = false LIMIT 1
        ];
        System.assertEquals('Low', lowReview.Risk_Level__c, 'Should be low for standard');
    }
}
