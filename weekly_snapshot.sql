/* 
===========================================================
PURPOSE
-----------------------------------------------------------
This query produces a WEEKLY SNAPSHOT (point-in-time view)
of ACTIVE parts for the last 12 months, showing:

- Total active parts
- Active parts WITH SupplierPartNumber (SPN)
- Active parts WITHOUT SupplierPartNumber
- Percent with SPN
- Percent without SPN

IMPORTANT:
- This is NOT based on parts created that week.
- It answers: "As of the end of each week, how many active
  parts exist, and how complete is SPN coverage today?"
===========================================================
*/

USE AssentDataAcist;
GO

/* 
Define the reporting window:
- StartDate = exactly 12 months ago (from today)
- EndDate   = today
These dates are used ONLY to build the weekly timeline.
*/
DECLARE @StartDate DATE = DATEADD(MONTH, -12, CAST(GETDATE() AS DATE));
DECLARE @EndDate   DATE = CAST(GETDATE() AS DATE);

/*
WeekCalendar CTE
-----------------------------------------------------------
This CTE generates a CONTINUOUS LIST OF WEEKS between
@StartDate and @EndDate.

Why this is needed:
- SQL does not have a built-in calendar table
- This ensures we return one row per week
- Even if no parts were created or changed that week

WeekStartDate is always the start of the week (Monday).
*/
WITH WeekCalendar AS (
    -- Anchor row: first week in the range
    SELECT 
        DATEADD(WEEK, DATEDIFF(WEEK, 0, @StartDate), 0) AS WeekStartDate

    UNION ALL

    -- Recursive step: add 1 week at a time
    SELECT 
        DATEADD(WEEK, 1, WeekStartDate)
    FROM WeekCalendar
    WHERE DATEADD(WEEK, 1, WeekStartDate) <= @EndDate
)

/*
Main SELECT
-----------------------------------------------------------
For EACH week in the calendar:
- Count all ACTIVE parts that existed by the END of that week
- Split them into WITH SPN vs WITHOUT SPN
- Calculate percentages
*/
SELECT
    wc.WeekStartDate,

    /* 
    TotalActiveParts:
    Counts all parts that:
    - Were created before the END of the week
    - Have NOT been deleted
    */
    COUNT(p.partID) AS TotalActiveParts,

    /*
    ActivePartsWithSPN:
    Active parts where SupplierPartNumber IS populated
    */
    SUM(
        CASE 
            WHEN p.SupplierPartNumber IS NOT NULL THEN 1 
            ELSE 0 
        END
    ) AS ActivePartsWithSPN,

    /*
    ActivePartsWithoutSPN:
    Active parts where SupplierPartNumber IS missing
    */
    SUM(
        CASE 
            WHEN p.SupplierPartNumber IS NULL THEN 1 
            ELSE 0 
        END
    ) AS ActivePartsWithoutSPN,

    /*
    PercentWithSPN:
    Percentage of active parts that have an SPN
    - Uses NULLIF to prevent divide-by-zero
    - Returned as a percentage (0–100)
    */
    CAST(
        100.0 * 
        SUM(CASE WHEN p.SupplierPartNumber IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(p.partID), 0)
        AS DECIMAL(5,2)
    ) AS PercentWithSPN,

    /*
    PercentWithoutSPN:
    Percentage of active parts missing an SPN
    */
    CAST(
        100.0 * 
        SUM(CASE WHEN p.SupplierPartNumber IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(p.partID), 0)
        AS DECIMAL(5,2)
    ) AS PercentWithoutSPN

FROM WeekCalendar wc

/*
LEFT JOIN to tblPart
-----------------------------------------------------------
This join determines WHICH parts "exist" as of each week.

Conditions:
1) p.DateCreated < end of the week
   → Part existed by that point in time

2) p.DateDeleted IS NULL
   → Part is still active today

IMPORTANT:
- SPN status is CURRENT STATE
- There is no historical SPN tracking in the schema
*/
LEFT JOIN tblPart p
    ON p.DateCreated < DATEADD(WEEK, 1, wc.WeekStartDate)
   AND p.part_status = 1
   AND p.DateDeleted IS NULL

/*
GROUP BY week so we get ONE ROW PER WEEK
*/
GROUP BY
    wc.WeekStartDate

/*
Order chronologically for reporting / charting
*/
ORDER BY
    wc.WeekStartDate

/*
Allow recursion to safely generate 52+ weeks
*/
OPTION (MAXRECURSION 400);
