/**
 * Provides real-time Salesforce governor limit metrics for performance monitoring.
 *
 * Returns both consumed and maximum limit values, enabling callers to calculate
 * headroom and detect approaching governor limits before they cause failures.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group System Monitoring
 * @see PerformanceRuleEngine
 */
public with sharing class LimitMetrics {
    public class GovernorStats {
        @AuraEnabled public Integer cpuMs;
        @AuraEnabled public Integer cpuMax;
        @AuraEnabled public Integer soql;
        @AuraEnabled public Integer soqlMax;
        @AuraEnabled public Integer dml;
        @AuraEnabled public Integer dmlMax;
        @AuraEnabled public Integer heapKb;
        @AuraEnabled public Integer heapMaxKb;
    }

    /**
     * Returns a snapshot of the current transaction's governor limit consumption.
     * Includes CPU time (ms), SOQL query count, DML statement count, and heap size (KB).
     *
     * @return GovernorStats wrapper containing current governor limit usage for the running transaction
     */
    @AuraEnabled(cacheable=true)
    public static GovernorStats fetchGovernorStats() {
        GovernorStats g = new GovernorStats();
        g.cpuMs = Limits.getCpuTime();
        g.cpuMax = Limits.getLimitCpuTime();
        g.soql  = Limits.getSOQLQueries();
        g.soqlMax = Limits.getLimitSOQLQueries();
        g.dml   = Limits.getDmlStatements();
        g.dmlMax = Limits.getLimitDmlStatements();
        g.heapKb = Math.round(Limits.getHeapSize() / 1024.0);
        g.heapMaxKb = Math.round(Limits.getLimitHeapSize() / 1024.0);
        return g;
    }
}
