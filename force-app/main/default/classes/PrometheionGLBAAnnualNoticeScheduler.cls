/**
 * GLBAAnnualNoticeScheduler - Scheduled job for GLBA annual privacy notices
 *
 * Automatically sends annual privacy notices to customers who are due.
 * Should be scheduled to run daily to ensure timely notice delivery.
 *
 * Schedule Example:
 * System.schedule('GLBA Annual Notice Check', '0 0 6 * * ?', new GLBAAnnualNoticeScheduler());
 *
 * @author Prometheion
 * @version 1.0
 */
public with sharing class GLBAAnnualNoticeScheduler implements Schedulable {

    /**
     * Execute the scheduled job
     * @param sc - SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        // Check if it's a business day
        if (isBusinessDay()) {
            // Queue the batch job to send annual notices
            Database.executeBatch(new GLBAAnnualNoticeBatch(), 200);
        }
    }

    /**
     * Check if today is a business day (Mon-Fri)
     * @return true if business day
     */
    private Boolean isBusinessDay() {
        Date today = Date.today();
        DateTime dt = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dt.format('EEEE');
        return dayOfWeek != 'Saturday' && dayOfWeek != 'Sunday';
    }

    /**
     * Schedule the job to run daily at 6 AM
     * @return Job ID
     */
    public static String scheduleDaily() {
        String cronExp = '0 0 6 * * ?'; // 6 AM every day
        return System.schedule(
            'GLBA Annual Notice Distribution - Daily',
            cronExp,
            new GLBAAnnualNoticeScheduler()
        );
    }

    /**
     * Batch class to process annual notices
     */
    public class GLBAAnnualNoticeBatch implements Database.Batchable<SObject>, Database.Stateful {
        private Integer noticesSent = 0;
        private Integer errors = 0;

        public Database.QueryLocator start(Database.BatchableContext bc) {
            // Find contacts due for annual notice
            Date today = Date.today();
            return Database.getQueryLocator([
                SELECT Id, Contact__c, Account__c, Contact__r.Email,
                       Next_Annual_Notice_Due__c
                FROM Privacy_Notice__c
                WHERE Next_Annual_Notice_Due__c <= :today
                AND Notice_Type__c IN ('Initial', 'Annual')
                AND Contact__c != null
                WITH USER_MODE
                ORDER BY Next_Annual_Notice_Due__c ASC
            ]);
        }

        public void execute(Database.BatchableContext bc, List<Privacy_Notice__c> scope) {
            List<Privacy_Notice__c> newNotices = new List<Privacy_Notice__c>();
            Set<Id> processedContacts = new Set<Id>();

            for (Privacy_Notice__c oldNotice : scope) {
                // Skip if already processed this contact
                if (processedContacts.contains(oldNotice.Contact__c)) {
                    continue;
                }
                processedContacts.add(oldNotice.Contact__c);

                try {
                    // Create new annual notice
                    newNotices.add(new Privacy_Notice__c(
                        Contact__c = oldNotice.Contact__c,
                        Account__c = oldNotice.Account__c,
                        Notice_Type__c = 'Annual',
                        Sent_Date__c = System.now(),
                        Delivery_Method__c = String.isNotBlank(oldNotice.Contact__r.Email) ? 'Email' : 'Mail',
                        Delivery_Status__c = 'Pending',
                        Notice_Version__c = 'v' + Date.today().year() + '.1',
                        Opt_Out_Deadline__c = Date.today().addDays(30),
                        Next_Annual_Notice_Due__c = Date.today().addDays(365)
                    ));
                    noticesSent++;
                } catch (Exception e) {
                    errors++;
                    System.debug(LoggingLevel.ERROR,
                        '[GLBAAnnualNoticeBatch] Error processing contact ' +
                        oldNotice.Contact__c + ': ' + e.getMessage());
                }
            }

            if (!newNotices.isEmpty()) {
                Database.insert(newNotices, AccessLevel.USER_MODE);

                // Publish compliance events
                List<GLBA_Compliance_Event__e> events = new List<GLBA_Compliance_Event__e>();
                for (Privacy_Notice__c notice : newNotices) {
                    events.add(new GLBA_Compliance_Event__e(
                        Notice_Id__c = notice.Id,
                        Contact_Id__c = notice.Contact__c,
                        Notice_Type__c = 'Annual',
                        Action__c = 'Annual Notice Scheduled',
                        Timestamp__c = System.now(),
                        User_Id__c = UserInfo.getUserId()
                    ));
                }
                EventBus.publish(events);
            }
        }

        public void finish(Database.BatchableContext bc) {
            // Send summary email to compliance team
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject('GLBA Annual Notice Distribution Complete');
            mail.setPlainTextBody(
                'GLBA Annual Notice Distribution Summary:\n\n' +
                'Notices Sent: ' + noticesSent + '\n' +
                'Errors: ' + errors + '\n' +
                'Completed: ' + System.now().format()
            );
            // In production, would set toAddresses to compliance team
            // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            System.debug(LoggingLevel.INFO,
                '[GLBAAnnualNoticeBatch] Completed. Sent: ' + noticesSent + ', Errors: ' + errors);
        }
    }
}
