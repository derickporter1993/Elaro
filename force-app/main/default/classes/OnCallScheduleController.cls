/**
 * @description Controller for On-Call Schedule LWC component
 * Provides CRUD operations for Elaro_On_Call_Schedule__c records
 *
 * @author Elaro Development Team
 * @since 2026-01
 */
public with sharing class OnCallScheduleController {

    /**
     * @description Gets all on-call schedules ordered by start time
     * @return List of schedule records with related user info
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<Elaro_On_Call_Schedule__c> getSchedules() {
        try {
            List<Elaro_On_Call_Schedule__c> schedules = [
                SELECT Id, Name, User__c, User__r.Name, User__r.Email,
                       Rotation_Name__c, Start_Time__c, End_Time__c,
                       Timezone__c, Notification_Methods__c, Active__c
                FROM Elaro_On_Call_Schedule__c
                WITH USER_MODE
                ORDER BY Start_Time__c DESC
                LIMIT 200
            ];

            // Strip inaccessible fields for FLS security
            return (List<Elaro_On_Call_Schedule__c>) ElaroSecurityUtils.stripInaccessibleFields(
                AccessType.READABLE,
                schedules
            );
        } catch (Exception e) {
            ElaroLogger.error('OnCallScheduleController.getSchedules', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to retrieve on-call schedules. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * @description Creates a new on-call schedule
     * @param schedule The schedule record to create
     * @return The created schedule ID
     * @throws AuraHandledException if creation fails
     */
    @AuraEnabled
    public static Id createSchedule(Elaro_On_Call_Schedule__c schedule) {
        try {
            validateSchedule(schedule);
            insert as user schedule;
            return schedule.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('OnCallScheduleController.createSchedule', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to create on-call schedule. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * @description Updates an existing on-call schedule
     * @param schedule The schedule record to update
     * @throws AuraHandledException if update fails
     */
    @AuraEnabled
    public static void updateSchedule(Elaro_On_Call_Schedule__c schedule) {
        try {
            validateSchedule(schedule);
            update as user schedule;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('OnCallScheduleController.updateSchedule', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to update on-call schedule. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * @description Deletes an on-call schedule
     * @param scheduleId The ID of the schedule to delete
     * @throws AuraHandledException if deletion fails
     */
    @AuraEnabled
    public static void deleteSchedule(Id scheduleId) {
        try {
            delete as user [SELECT Id FROM Elaro_On_Call_Schedule__c WHERE Id = :scheduleId WITH USER_MODE];
        } catch (Exception e) {
            ElaroLogger.error('OnCallScheduleController.deleteSchedule', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to delete on-call schedule. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * @description Validates schedule data before save
     * @param schedule The schedule to validate
     */
    private static void validateSchedule(Elaro_On_Call_Schedule__c schedule) {
        if (schedule.Start_Time__c == null) {
            throw new AuraHandledException('Start time is required');
        }
        if (schedule.End_Time__c == null) {
            throw new AuraHandledException('End time is required');
        }
        if (schedule.Start_Time__c >= schedule.End_Time__c) {
            throw new AuraHandledException('End time must be after start time');
        }
        if (schedule.User__c == null) {
            throw new AuraHandledException('User is required');
        }
    }
}
