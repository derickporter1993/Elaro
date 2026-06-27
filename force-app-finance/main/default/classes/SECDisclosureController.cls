/**
 * AuraEnabled controller for SEC Cybersecurity Disclosure Module LWC components.
 * Delegates all business logic to service classes and provides a unified API
 * surface for the frontend. All methods include error handling with
 * user-friendly AuraHandledException messages.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see MaterialityAssessmentService
 * @see DisclosureWorkflowService
 * @see BoardGovernanceService
 * @see IncidentTimelineService
 */
public with sharing class SECDisclosureController {

    // ─── Materiality Assessment Methods ─────────────────────────────────

    /**
     * Creates a new materiality assessment for a cybersecurity incident.
     *
     * @param incidentDescription Description of the cybersecurity incident
     * @param discoveryDate ISO-format discovery date string
     * @return The Id of the newly created Materiality_Assessment__c record
     * @throws AuraHandledException if parameters are invalid or creation fails
     */
    @AuraEnabled
    public static Id createAssessment(String incidentDescription, String discoveryDate) {
        try {
            DateTime parsedDate = DateTime.valueOf(discoveryDate);
            Materiality_Assessment__c assessment = MaterialityAssessmentService.createAssessment(
                incidentDescription, parsedDate
            );
            return assessment.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.createAssessment',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to create assessment. Please verify your input and try again.');
        }
    }

    /**
     * Retrieves a materiality assessment with its full incident timeline.
     *
     * @param assessmentId The Materiality_Assessment__c record Id as string
     * @return The assessment record with child Incident_Timeline__c records
     * @throws AuraHandledException if assessment not found or access denied
     */
    @AuraEnabled(cacheable=true)
    public static Materiality_Assessment__c getAssessment(String assessmentId) {
        try {
            return MaterialityAssessmentService.getAssessmentWithTimeline(
                Id.valueOf(assessmentId)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getAssessment',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve assessment. Please try again.');
        }
    }

    /**
     * Submits a materiality determination for an assessment.
     *
     * @param assessmentId The Materiality_Assessment__c record Id as string
     * @param result The determination result value
     * @param determinationDate ISO-format determination date string
     * @throws AuraHandledException if parameters are invalid or update fails
     */
    @AuraEnabled
    public static void submitDetermination(String assessmentId, String result, String determinationDate) {
        try {
            MaterialityAssessmentService.submitDetermination(
                Id.valueOf(assessmentId),
                result,
                DateTime.valueOf(determinationDate)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.submitDetermination',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to submit determination. Please try again.');
        }
    }

    /**
     * Requests an Attorney General delay for the filing deadline.
     *
     * @param assessmentId The Materiality_Assessment__c record Id as string
     * @param delayDays Number of additional business days requested
     * @throws AuraHandledException if request fails
     */
    @AuraEnabled
    public static void requestAGDelay(String assessmentId, Integer delayDays) {
        try {
            MaterialityAssessmentService.requestAGDelay(
                Id.valueOf(assessmentId),
                delayDays
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.requestAGDelay',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to request AG delay. Please try again.');
        }
    }

    /**
     * Retrieves all open (non-Closed) materiality assessments.
     *
     * @return List of open Materiality_Assessment__c records
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<Materiality_Assessment__c> getOpenAssessments() {
        try {
            return MaterialityAssessmentService.getOpenAssessments();
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getOpenAssessments',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve open assessments. Please try again.');
        }
    }

    // ─── Disclosure Workflow Methods ─────────────────────────────────────

    /**
     * Creates a new disclosure workflow for a materiality assessment.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id as string
     * @param formType The SEC form type (e.g., '8-K', '10-K')
     * @return The Id of the newly created Disclosure_Workflow__c record
     * @throws AuraHandledException if creation fails
     */
    @AuraEnabled
    public static Id createWorkflow(String assessmentId, String formType) {
        try {
            Disclosure_Workflow__c workflow = DisclosureWorkflowService.createWorkflow(
                Id.valueOf(assessmentId),
                formType
            );
            return workflow.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.createWorkflow',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to create workflow. Please try again.');
        }
    }

    /**
     * Advances a disclosure workflow to the next status in the approval chain.
     *
     * @param workflowId The Disclosure_Workflow__c record Id as string
     * @param newStatus The target status to transition to
     * @param reviewNotes Optional reviewer notes
     * @throws AuraHandledException if transition is invalid or update fails
     */
    @AuraEnabled
    public static void advanceWorkflow(String workflowId, String newStatus, String reviewNotes) {
        try {
            DisclosureWorkflowService.advanceWorkflow(
                Id.valueOf(workflowId),
                newStatus,
                reviewNotes
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.advanceWorkflow',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to advance workflow. Please try again.');
        }
    }

    /**
     * Records the EDGAR filing details for a disclosure workflow.
     *
     * @param workflowId The Disclosure_Workflow__c record Id as string
     * @param edgarNumber The EDGAR filing number assigned by the SEC
     * @throws AuraHandledException if recording fails
     */
    @AuraEnabled
    public static void recordFiling(String workflowId, String edgarNumber) {
        try {
            DisclosureWorkflowService.recordFiling(
                Id.valueOf(workflowId),
                edgarNumber
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.recordFiling',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to record filing. Please try again.');
        }
    }

    /**
     * Submits a disclosure workflow into the multi-step approval process.
     * Approval chain: CISO (submitter) > Legal > CFO > CEO > Board > Ready to File.
     * All approver lookup fields must be populated before submission.
     *
     * @param workflowId The Disclosure_Workflow__c record Id as string
     * @param comments Optional submitter comments for the approval record
     * @throws AuraHandledException if submission fails or approvers not configured
     */
    @AuraEnabled
    public static void submitForApproval(String workflowId, String comments) {
        try {
            DisclosureWorkflowService.submitForApproval(
                Id.valueOf(workflowId),
                comments
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.submitForApproval',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to submit for approval. Please try again.');
        }
    }

    /**
     * Retrieves the current approval status for a disclosure workflow,
     * including the pending approver name and step details.
     *
     * @param workflowId The Disclosure_Workflow__c record Id as string
     * @return Map containing approval status details
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled
    public static Map<String, Object> getApprovalStatus(String workflowId) {
        try {
            return DisclosureWorkflowService.getApprovalStatus(
                Id.valueOf(workflowId)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getApprovalStatus',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve approval status. Please try again.');
        }
    }

    /**
     * Retrieves all disclosure workflows for a materiality assessment.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id as string
     * @return List of Disclosure_Workflow__c records
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<Disclosure_Workflow__c> getWorkflows(String assessmentId) {
        try {
            return DisclosureWorkflowService.getWorkflowsByAssessment(
                Id.valueOf(assessmentId)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getWorkflows',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve workflows. Please try again.');
        }
    }

    // ─── Timeline Methods ───────────────────────────────────────────────

    /**
     * Retrieves incident timeline events for a materiality assessment.
     *
     * @param assessmentId The Materiality_Assessment__c record Id as string
     * @return List of Incident_Timeline__c records ordered by Event_Date__c
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<Incident_Timeline__c> getTimeline(String assessmentId) {
        try {
            return IncidentTimelineService.getTimeline(
                Id.valueOf(assessmentId)
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getTimeline',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve timeline. Please try again.');
        }
    }

    /**
     * Adds a timeline event to a materiality assessment.
     *
     * @param assessmentId The Materiality_Assessment__c record Id as string
     * @param eventDate ISO-format event date string
     * @param eventType The type of event
     * @param description Description of the event
     * @return The Id of the newly created Incident_Timeline__c record
     * @throws AuraHandledException if creation fails
     */
    @AuraEnabled
    public static Id addTimelineEvent(String assessmentId, String eventDate, String eventType, String description) {
        try {
            Incident_Timeline__c evt = IncidentTimelineService.addTimelineEvent(
                Id.valueOf(assessmentId),
                DateTime.valueOf(eventDate),
                eventType,
                description,
                UserInfo.getName()
            );
            return evt.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.addTimelineEvent',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to add timeline event. Please try again.');
        }
    }

    // ─── Board Governance Methods ───────────────────────────────────────

    /**
     * Creates a new board governance report for annual 10-K disclosure.
     *
     * @param reportPeriod The reporting period (e.g., 'FY2025')
     * @param reportType The type of report (e.g., '10-K', 'Annual')
     * @return The Id of the newly created Board_Governance_Report__c record
     * @throws AuraHandledException if creation fails
     */
    @AuraEnabled
    public static Id createGovernanceReport(String reportPeriod, String reportType) {
        try {
            Board_Governance_Report__c report = BoardGovernanceService.createReport(
                reportPeriod, reportType
            );
            return report.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.createGovernanceReport',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to create governance report. Please try again.');
        }
    }

    /**
     * Retrieves board governance reports for a given reporting period.
     *
     * @param reportPeriod The reporting period to filter by
     * @return List of Board_Governance_Report__c records
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<Board_Governance_Report__c> getGovernanceReports(String reportPeriod) {
        try {
            return BoardGovernanceService.getReportsByPeriod(reportPeriod);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'SECDisclosureController.getGovernanceReports',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Unable to retrieve governance reports. Please try again.');
        }
    }
}
