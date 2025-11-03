public with sharing class FlowExecutionStats {
    public class ExecAgg {
        @AuraEnabled public String flowName;
        @AuraEnabled public Integer runs;
        @AuraEnabled public Integer faults;
        @AuraEnabled public Datetime lastRun;
    }
    @AuraEnabled(cacheable=true)
    public static List<ExecAgg> topFlows(Integer limitSize) {
        // Get top flows by run count
        List<AggregateResult> ars = [
            SELECT Flow_Name__c fn,
                   COUNT(Id) runs,
                   MAX(Run_Time__c) lastRun
            FROM Flow_Execution__c
            GROUP BY Flow_Name__c
            ORDER BY COUNT(Id) DESC
            LIMIT :Math.max(1, limitSize)
        ];
        
        // Collect flow names for fault query
        Set<String> flowNames = new Set<String>();
        Map<String, ExecAgg> flowMap = new Map<String, ExecAgg>();
        for (AggregateResult ar : ars) {
            String flowName = (String) ar.get('fn');
            flowNames.add(flowName);
            ExecAgg e = new ExecAgg();
            e.flowName = flowName;
            e.runs = (Integer) ar.get('runs');
            e.faults = 0; // Default to 0, will update if faults exist
            e.lastRun = (Datetime) ar.get('lastRun');
            flowMap.put(flowName, e);
        }
        
        // Query faults separately - more efficient than CASE aggregation
        if (!flowNames.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Flow_Name__c fn, COUNT(Id) faultCount
                FROM Flow_Execution__c
                WHERE Flow_Name__c IN :flowNames AND Status__c = 'Fault'
                GROUP BY Flow_Name__c
            ]) {
                String flowName = (String) ar.get('fn');
                flowMap.get(flowName).faults = (Integer) ar.get('faultCount');
            }
        }
        
        // Return in order of runs (descending)
        List<ExecAgg> out = new List<ExecAgg>();
        for (AggregateResult ar : ars) {
            String flowName = (String) ar.get('fn');
            out.add(flowMap.get(flowName));
        }
        return out;
    }
}
