public with sharing class FlowExecutionLogger {
    public class LogInput {
        @InvocableVariable(required=true) public String flowName;
        @InvocableVariable public Id primaryRecordId;
        @InvocableVariable(required=true) public String status;
        @InvocableVariable public Integer cpu;
        @InvocableVariable public Integer soql;
        @InvocableVariable public Integer dml;
    }
    @InvocableMethod(label='Log Flow Execution')
    public static void logInvocable(List<LogInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            throw new IllegalArgumentException('Inputs cannot be null or empty');
        }
        
        List<Flow_Execution__c> toInsert = new List<Flow_Execution__c>();
        for (LogInput i : inputs) {
            // Input validation
            if (String.isBlank(i.flowName)) {
                throw new IllegalArgumentException('Flow name cannot be blank');
            }
            if (String.isBlank(i.status)) {
                throw new IllegalArgumentException('Status cannot be blank');
            }
            // Validate numeric values are non-negative
            if (i.cpu != null && i.cpu < 0) {
                throw new IllegalArgumentException('CPU time cannot be negative');
            }
            if (i.soql != null && i.soql < 0) {
                throw new IllegalArgumentException('SOQL count cannot be negative');
            }
            if (i.dml != null && i.dml < 0) {
                throw new IllegalArgumentException('DML count cannot be negative');
            }
            
            toInsert.add(new Flow_Execution__c(
                Flow_Name__c = i.flowName,
                Primary_Record__c = i.primaryRecordId,
                Status__c = i.status,
                CPU__c = i.cpu, SOQL__c = i.soql, DML__c = i.dml,
                Run_Time__c = System.now()
            ));
        }
        if (!toInsert.isEmpty()) insert toInsert;
    }
    @AuraEnabled
    public static void log(String flowName, Id primaryRecordId, String status, Integer cpu, Integer soql, Integer dml) {
        LogInput input = new LogInput();
        input.flowName = flowName;
        input.primaryRecordId = primaryRecordId;
        input.status = status;
        input.cpu = cpu;
        input.soql = soql;
        input.dml = dml;
        logInvocable(new List<LogInput>{ input });
    }
}
