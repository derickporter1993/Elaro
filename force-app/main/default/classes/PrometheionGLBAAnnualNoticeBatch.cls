/**
 * GLBAAnnualNoticeBatch - Batch job for GLBA annual privacy notice distribution
 *
 * Processes Privacy_Notice__c records that are due for annual notice renewal
 * and creates new annual notices for affected contacts.
 *
 * @author Prometheion
 * @version 1.1
 */
public with sharing class PrometheionGLBAAnnualNoticeBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private static final String BATCH_NAME = 'PrometheionGLBAAnnualNoticeBatch';
    
    private Integer noticesSent = 0;
    private Integer errors = 0;
    private Integer totalProcessed = 0;
    private List<String> errorDetails = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, '[' + BATCH_NAME + '] start() - Job ID: ' + bc.getJobId());
        
        try {
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
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[' + BATCH_NAME + '] Query failed: ' + e.getMessage());
            SchedulerErrorHandler.logError(BATCH_NAME, e, '{"method": "start", "jobId": "' + bc.getJobId() + '"}');
            throw e;
        }
    }

    public void execute(Database.BatchableContext bc, List<Privacy_Notice__c> scope) {
        List<Privacy_Notice__c> newNotices = new List<Privacy_Notice__c>();
        Set<Id> processedContacts = new Set<Id>();

        for (Privacy_Notice__c oldNotice : scope) {
            totalProcessed++;
            
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
            } catch (Exception e) {
                errors++;
                String errorMsg = 'Error processing contact ' + oldNotice.Contact__c + ': ' + e.getMessage();
                errorDetails.add(errorMsg);
                System.debug(LoggingLevel.ERROR, '[' + BATCH_NAME + '] ' + errorMsg);
            }
        }

        if (!newNotices.isEmpty()) {
            // Use SaveResult handling for graceful error management
            List<Database.SaveResult> results = Database.insert(newNotices, false);
            
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                if (sr.isSuccess()) {
                    noticesSent++;
                } else {
                    errors++;
                    for (Database.Error err : sr.getErrors()) {
                        String errorMsg = 'Insert failed for notice ' + i + ': ' + err.getStatusCode() + ' - ' + err.getMessage();
                        errorDetails.add(errorMsg);
                        System.debug(LoggingLevel.ERROR, '[' + BATCH_NAME + '] ' + errorMsg);
                    }
                }
            }

            // Publish compliance events using generic Prometheion_Raw_Event__e
            publishComplianceEvents(newNotices, results);
        }
    }
    
    /**
     * Publish compliance events for successfully created notices
     */
    private void publishComplianceEvents(List<Privacy_Notice__c> notices, List<Database.SaveResult> results) {
        try {
            List<Prometheion_Raw_Event__e> events = new List<Prometheion_Raw_Event__e>();
            Datetime now = System.now();
            String userId = UserInfo.getUserId();

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    Privacy_Notice__c notice = notices[i];
                    Map<String, Object> eventData = new Map<String, Object>{
                        'noticeId' => results[i].getId(),
                        'contactId' => notice.Contact__c,
                        'noticeType' => 'Annual',
                        'action' => 'Annual Notice Scheduled',
                        'userId' => userId
                    };

                    events.add(new Prometheion_Raw_Event__e(
                        Event_Type__c = 'GLBA_COMPLIANCE',
                        Event_Data__c = JSON.serialize(eventData),
                        Timestamp__c = now
                    ));
                }
            }
            
            if (!events.isEmpty()) {
                EventBus.publish(events);
            }
        } catch (Exception e) {
            // Don't let event publishing failure break the batch
            System.debug(LoggingLevel.ERROR, '[' + BATCH_NAME + '] Event publishing failed: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, '[' + BATCH_NAME + '] finish() - Notices sent: ' + noticesSent + ', Errors: ' + errors);
        
        // Query job status for complete information
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            LIMIT 1
        ];
        
        // Build summary
        String summary = String.format(
            'GLBA Annual Notice Batch Complete\n' +
            'Status: {0}\n' +
            'Items Processed: {1}/{2}\n' +
            'Notices Sent: {3}\n' +
            'Errors: {4}',
            new List<Object>{
                job.Status,
                job.JobItemsProcessed,
                job.TotalJobItems,
                noticesSent,
                errors + job.NumberOfErrors
            }
        );
        
        // Log completion
        if (errors > 0 || job.NumberOfErrors > 0) {
            String errorContext = JSON.serialize(new Map<String, Object>{
                'jobId' => bc.getJobId(),
                'totalProcessed' => totalProcessed,
                'noticesSent' => noticesSent,
                'errors' => errors,
                'jobErrors' => job.NumberOfErrors,
                'errorSamples' => errorDetails.size() > 5 ? 
                    new List<String>(errorDetails.subList(0, 5)) : errorDetails
            });
            SchedulerErrorHandler.logError(BATCH_NAME, 
                new SchedulerErrorHandler.SchedulerException('Batch completed with errors'), 
                errorContext);
        } else {
            SchedulerErrorHandler.logSuccess(BATCH_NAME, summary);
        }
        
        // Send notification email
        sendCompletionEmail(job, summary);
    }
    
    /**
     * Send completion email to job creator
     */
    private void sendCompletionEmail(AsyncApexJob job, String summary) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { job.CreatedBy.Email });
            mail.setSubject('GLBA Annual Notice Distribution ' + (errors > 0 ? 'Completed with Errors' : 'Complete'));
            
            String body = summary + '\n\n';
            
            if (!errorDetails.isEmpty()) {
                body += '\nError Details (first 10):\n';
                Integer count = 0;
                for (String err : errorDetails) {
                    if (count++ >= 10) break;
                    body += '- ' + err + '\n';
                }
            }
            
            body += '\nCompleted: ' + System.now().format();
            mail.setPlainTextBody(body);
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[' + BATCH_NAME + '] Failed to send notification email: ' + e.getMessage());
        }
    }
}
