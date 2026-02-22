@IsTest(testFor=ElaroAuditTrailPoller.class)
private class ElaroAuditTrailPollerTest {
    
    @IsTest
    static void testSchedule() {
        Test.startTest();
        String jobId = ElaroAuditTrailPoller.schedule();
        Test.stopTest();
        
        Assert.areNotEqual(null, jobId, 'Job should be scheduled');
        
        // Verify job was created
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE Id = :jobId
        ];
        
        Assert.areEqual(1, jobs.size(), 'Job should exist');
        Assert.areEqual('Elaro Audit Trail Poller', jobs[0].CronJobDetail.Name);
    }
    
    @IsTest
    static void testUnschedule() {
        // First schedule a job
        String jobId = ElaroAuditTrailPoller.schedule();
        
        Test.startTest();
        ElaroAuditTrailPoller.unschedule();
        Test.stopTest();
        
        // Verify job was removed
        List<CronTrigger> jobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = 'Elaro Audit Trail Poller'
        ];
        
        Assert.areEqual(0, jobs.size(), 'Job should be unscheduled');
    }
    
    @IsTest
    static void testExecute() {
        ElaroAuditTrailPoller poller = new ElaroAuditTrailPoller();
        SchedulableContext ctx = null;

        Exception caughtEx;
        Test.startTest();
        try {
            poller.execute(ctx);
        } catch (Exception e) {
            caughtEx = e;
        }
        Test.stopTest();

        Assert.isNull(caughtEx, 'Poller execute should complete without throwing an exception');
    }
    
    @IsTest
    static void testPollAuditTrail() {
        Exception caughtEx;
        Test.startTest();
        try {
            ElaroAuditTrailPoller.pollAuditTrail();
        } catch (Exception e) {
            caughtEx = e;
        }
        Test.stopTest();

        Assert.isNull(caughtEx, 'Audit trail polling should complete without throwing an exception');
    }
}

