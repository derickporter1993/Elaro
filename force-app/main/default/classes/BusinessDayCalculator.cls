/**
 * Calculates business days for SEC filing deadlines, excluding weekends
 * and holidays stored in Holiday__c. SEC Item 1.05 of Form 8-K requires
 * filing within 4 business days of a materiality determination.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see MaterialityAssessmentService
 * @see Holiday__c
 */
public inherited sharing class BusinessDayCalculator {

    private static final Integer DEFAULT_BUSINESS_DAYS = 4;
    private static final Integer HOLIDAY_BUFFER_MULTIPLIER = 3;

    /**
     * Calculates the filing deadline by adding business days to the determination date.
     * SEC Rule: 8-K must be filed within 4 business days of materiality determination.
     * Weekends (Saturday and Sunday) and federal holidays from Holiday__c are excluded.
     *
     * @param determinationDate The date materiality was determined
     * @param businessDays Number of business days to add (default 4 for 8-K)
     * @return The filing deadline DateTime, or null if determinationDate is null
     */
    public static DateTime calculateFilingDeadline(DateTime determinationDate, Integer businessDays) {
        if (determinationDate == null) {
            return null;
        }
        if (businessDays == null || businessDays <= 0) {
            return determinationDate;
        }

        Date startDate = determinationDate.date();
        Date maxDate = startDate.addDays(businessDays * HOLIDAY_BUFFER_MULTIPLIER);
        Set<Date> holidays = getHolidays(startDate, maxDate);

        Integer addedDays = 0;
        Date currentDate = startDate;

        while (addedDays < businessDays) {
            currentDate = currentDate.addDays(1);
            if (isBusinessDay(currentDate, holidays)) {
                addedDays++;
            }
        }

        return DateTime.newInstance(currentDate, determinationDate.time());
    }

    /**
     * Calculates the filing deadline using the default 4 business days for 8-K filings.
     *
     * @param determinationDate The date materiality was determined
     * @return The filing deadline DateTime
     */
    public static DateTime calculateFilingDeadline(DateTime determinationDate) {
        return calculateFilingDeadline(determinationDate, DEFAULT_BUSINESS_DAYS);
    }

    /**
     * Calculates filing deadline adjusted for AG (Attorney General) delay.
     * When the AG grants a delay under 18 U.S.C. 1798.82, the base deadline
     * is extended by the granted number of additional business days.
     *
     * @param determinationDate The date materiality was determined
     * @param baseBusinessDays Base business days (typically 4)
     * @param delayDays Additional delay business days granted by AG
     * @return The adjusted filing deadline DateTime
     */
    public static DateTime calculateWithAGDelay(DateTime determinationDate, Integer baseBusinessDays, Integer delayDays) {
        DateTime baseDeadline = calculateFilingDeadline(determinationDate, baseBusinessDays);
        if (baseDeadline == null || delayDays == null || delayDays <= 0) {
            return baseDeadline;
        }
        return calculateFilingDeadline(baseDeadline, delayDays);
    }

    /**
     * Counts the number of business days between two dates (exclusive of start, inclusive of end).
     *
     * @param startDate The start date
     * @param endDate The end date
     * @return Number of business days between the two dates
     */
    public static Integer countBusinessDaysBetween(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate <= startDate) {
            return 0;
        }

        Set<Date> holidays = getHolidays(startDate, endDate);
        Integer count = 0;
        Date currentDate = startDate;

        while (currentDate < endDate) {
            currentDate = currentDate.addDays(1);
            if (isBusinessDay(currentDate, holidays)) {
                count++;
            }
        }

        return count;
    }

    /**
     * Determines whether a given date is a business day (not a weekend or holiday).
     *
     * @param checkDate The date to evaluate
     * @param holidays Set of holiday dates to exclude
     * @return True if the date is a business day
     */
    @TestVisible
    private static Boolean isBusinessDay(Date checkDate, Set<Date> holidays) {
        DateTime tempDt = DateTime.newInstance(checkDate, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = tempDt.format('EEEE');

        if (dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday') {
            return false;
        }
        return !holidays.contains(checkDate);
    }

    /**
     * Retrieves holiday dates from Holiday__c within a date range.
     *
     * @param startDate Range start date
     * @param endDate Range end date
     * @return Set of holiday dates
     */
    private static Set<Date> getHolidays(Date startDate, Date endDate) {
        Set<Date> holidays = new Set<Date>();
        for (Holiday__c h : [
            SELECT Holiday_Date__c
            FROM Holiday__c
            WHERE Holiday_Date__c >= :startDate
            AND Holiday_Date__c <= :endDate
            WITH USER_MODE
        ]) {
            holidays.add(h.Holiday_Date__c);
        }
        return holidays;
    }
}
