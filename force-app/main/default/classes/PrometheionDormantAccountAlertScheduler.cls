/**
 * DormantAccountAlertScheduler - Scheduled job for detecting dormant accounts
 *
 * Identifies user accounts with no login activity for 90+ days and creates
 * termination reviews or sends alerts to security team.
 *
 * Schedule Example:
 * System.schedule('Dormant Account Check', '0 0 5 * * ?', new DormantAccountAlertScheduler());
 *
 * @author Prometheion
 * @version 1.1
 */
public with sharing class PrometheionDormantAccountAlertScheduler implements Schedulable {

    private static final Integer DORMANT_THRESHOLD_DAYS = 90;
    private static final Integer WARNING_THRESHOLD_DAYS = 60;
    private static final Integer DEFAULT_BATCH_LIMIT = 500;
    private static final String SCHEDULER_NAME = 'PrometheionDormantAccountAlertScheduler';

    /**
     * Execute the scheduled job
     * @param sc - SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        Savepoint sp = SchedulerErrorHandler.setSavepoint();
        
        try {
            detectDormantAccounts();
            detectApproachingDormant();
            generateSecurityReport();
            
            // Log successful execution
            SchedulerErrorHandler.logSuccess(SCHEDULER_NAME, 'Dormant account detection completed successfully');
            
        } catch (Exception e) {
            // Rollback all changes on error
            SchedulerErrorHandler.rollbackAndLog(sp, SCHEDULER_NAME, e.getMessage());
            
            // Notify admins of failure
            SchedulerErrorHandler.notifyOnFailure(SCHEDULER_NAME, e.getMessage(), e.getStackTraceString());
        }
    }

    /**
     * Detect and process dormant accounts (90+ days inactive)
     */
    private void detectDormantAccounts() {
        Date dormantThreshold = Date.today().addDays(-DORMANT_THRESHOLD_DAYS);
        Integer batchLimit = getBatchLimit();

        List<User> dormantUsers = [
            SELECT Id, Name, Username, Email, Profile.Name, ManagerId, Manager.Email,
                   LastLoginDate, IsActive
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            AND (LastLoginDate < :dormantThreshold OR LastLoginDate = null)
            WITH USER_MODE
            LIMIT :batchLimit
        ];

        if (dormantUsers.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                '[' + SCHEDULER_NAME + '] No dormant accounts detected');
            return;
        }

        // Create access reviews for dormant accounts
        List<Access_Review__c> reviews = new List<Access_Review__c>();

        for (User u : dormantUsers) {
            Integer daysSinceLogin = u.LastLoginDate != null ?
                Math.abs(Date.today().daysBetween(u.LastLoginDate.date())) : 999;

            reviews.add(new Access_Review__c(
                User__c = u.Id,
                Reviewer__c = u.ManagerId,
                Review_Type__c = 'Termination Review',
                Review_Status__c = 'Pending',
                Due_Date__c = Date.today().addDays(7),
                Profiles_Reviewed__c = u.Profile.Name,
                Is_Privileged_User__c = u.Profile.Name == 'System Administrator',
                Last_Login_Date__c = u.LastLoginDate,
                Risk_Level__c = u.Profile.Name == 'System Administrator' ? 'Critical' : 'High',
                Decision_Justification__c = 'Auto-created: Account dormant for ' + daysSinceLogin + ' days'
            ));
        }

        if (!reviews.isEmpty()) {
            // Use SaveResult handling for graceful error management
            List<Database.SaveResult> results = Database.insert(reviews, false);
            Integer failures = SchedulerErrorHandler.handleSaveResults(results, SCHEDULER_NAME, 'INSERT');
            
            Integer successCount = reviews.size() - failures;
            System.debug(LoggingLevel.WARN,
                '[' + SCHEDULER_NAME + '] Created ' + successCount +
                ' termination reviews for dormant accounts (' + failures + ' failures)');

            // Alert security team
            if (successCount > 0) {
                sendDormantAccountAlert(dormantUsers);
            }
        }
    }

    /**
     * Detect accounts approaching dormant threshold (60-90 days)
     */
    private void detectApproachingDormant() {
        Date warningThreshold = Date.today().addDays(-WARNING_THRESHOLD_DAYS);
        Date dormantThreshold = Date.today().addDays(-DORMANT_THRESHOLD_DAYS);

        List<User> warningUsers = [
            SELECT Id, Name, Username, Email, Profile.Name, Manager.Email, LastLoginDate
            FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            AND LastLoginDate < :warningThreshold
            AND LastLoginDate >= :dormantThreshold
            WITH USER_MODE
            LIMIT 200
        ];

        if (!warningUsers.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                '[' + SCHEDULER_NAME + '] ' + warningUsers.size() +
                ' accounts approaching dormant threshold (60-90 days)');

            // Send warning notifications
            for (User u : warningUsers) {
                Integer daysSinceLogin = Math.abs(Date.today().daysBetween(u.LastLoginDate.date()));
                System.debug(LoggingLevel.INFO,
                    '[' + SCHEDULER_NAME + '] Warning: ' + u.Username +
                    ' - ' + daysSinceLogin + ' days since last login');
            }
        }
    }

    /**
     * Generate daily security report
     */
    private void generateSecurityReport() {
        Date dormantThreshold = Date.today().addDays(-DORMANT_THRESHOLD_DAYS);

        // Count active vs dormant
        Integer totalActive = [SELECT COUNT() FROM User WHERE IsActive = true AND UserType = 'Standard' WITH USER_MODE];

        Integer dormantCount = [
            SELECT COUNT() FROM User
            WHERE IsActive = true
            AND UserType = 'Standard'
            AND (LastLoginDate < :dormantThreshold OR LastLoginDate = null)
            WITH USER_MODE
        ];

        // Count privileged dormant accounts (higher risk)
        Integer privilegedDormant = [
            SELECT COUNT() FROM User
            WHERE IsActive = true
            AND (LastLoginDate < :dormantThreshold OR LastLoginDate = null)
            AND Profile.Name = 'System Administrator'
            WITH USER_MODE
        ];

        // Pending reviews
        Integer pendingReviews = [
            SELECT COUNT() FROM Access_Review__c
            WHERE Review_Status__c IN ('Pending', 'In Progress')
            AND Review_Type__c = 'Termination Review'
            WITH USER_MODE
        ];

        System.debug(LoggingLevel.INFO,
            '[' + SCHEDULER_NAME + '] Security Report - ' +
            'Total Active Users: ' + totalActive + ', ' +
            'Dormant Accounts: ' + dormantCount + ', ' +
            'Privileged Dormant: ' + privilegedDormant + ', ' +
            'Pending Reviews: ' + pendingReviews);
    }

    /**
     * Send alert for dormant accounts
     * @param dormantUsers - List of dormant users
     */
    private void sendDormantAccountAlert(List<User> dormantUsers) {
        // Count by profile
        Map<String, Integer> byProfile = new Map<String, Integer>();
        for (User u : dormantUsers) {
            String profile = u.Profile.Name;
            byProfile.put(profile, (byProfile.containsKey(profile) ? byProfile.get(profile) : 0) + 1);
        }

        System.debug(LoggingLevel.WARN,
            '[' + SCHEDULER_NAME + '] SECURITY ALERT: ' + dormantUsers.size() +
            ' dormant accounts detected. Breakdown by profile: ' + JSON.serialize(byProfile));

        // In production, would send to security team via email/Slack/SIEM
    }

    /**
     * Get batch limit from Custom Metadata or use default
     * @return Batch limit
     */
    private Integer getBatchLimit() {
        try {
            Prometheion_Scheduler_Config__mdt config = Prometheion_Scheduler_Config__mdt.getInstance('DormantAccountAlert');
            if (config != null && config.Batch_Size__c != null) {
                return config.Batch_Size__c.intValue();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[' + SCHEDULER_NAME + '] Could not load config: ' + e.getMessage());
        }
        return DEFAULT_BATCH_LIMIT;
    }

    /**
     * Schedule daily dormant account check at 5 AM
     * @return Job ID
     */
    public static String scheduleDaily() {
        String cronExp = '0 0 5 * * ?';
        return System.schedule(
            'Dormant Account Alert - Daily',
            cronExp,
            new PrometheionDormantAccountAlertScheduler()
        );
    }
}
