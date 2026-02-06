# SPNs Weekly Snapshot

This repository contains a single SQL script, `weekly_snapshot.sql`, that produces a point-in-time weekly snapshot of **active parts** and their **SupplierPartNumber (SPN) coverage** for the last 12 months.

## What the query reports
For each week in the last 12 months, the script returns:

- **Total active parts**
- **Active parts with SPN**
- **Active parts without SPN**
- **Percent with SPN**
- **Percent without SPN**

The output answers the question:

> “As of the end of each week, how many active parts exist, and how complete is SPN coverage?”

## How it works (high level)
1. **Builds a week-by-week calendar** using a recursive CTE, starting 12 months ago and ending today (weeks start on Monday).
2. **Left joins** each week to `tblPart` to find parts that:
   - Were created **before the end of that week**, and
   - Are **still active** (`part_status = 1` and `DateDeleted IS NULL`).
3. **Aggregates** counts and percentages of parts with and without `SupplierPartNumber`.

## Important notes
- This is **not** a “parts created per week” report. It is a **snapshot** of all active parts as of each week-end.
- SPN status is based on the **current value** of `SupplierPartNumber` (no historical SPN tracking is assumed).
- The script expects the `AssentDataAcist` database and a `tblPart` table with:
  - `partID`
  - `SupplierPartNumber`
  - `DateCreated`
  - `part_status`
  - `DateDeleted`

## Usage
Run `weekly_snapshot.sql` in the target SQL Server environment.

```
weekly_snapshot.sql
```

This will return one row per week (chronological order) for the last 12 months.
