# APSS commission loss rule update v10

Built from the 12 uploaded source files (objects 90420–90423). Replace those source files with these canonical filenames; do not retain duplicate `(1)`/`(2)` copies in the AL project. Add the new accounting codeunit and Vendor table/page extensions, all object ID 90424 in their separate object types. Check ID/field availability in your app, increment your existing app version and compile with your BC symbols. No app.json or extension identity was invented.

## v10 loss rule

- Net P/L < 0: commission preview = Net P/L x 60%, rounded to cents. Example: -1,000 USD gives -600 USD. This negative result represents the intended monthly salesperson deduction.
- Net P/L > 0: the existing 15% base commission less advance deduction applies.
- Net P/L = 0: commission preview = 0.
- Actual Commission (%) shows 60 for a loss; the standard Commission Rate (%) stays 15. Advance months/deduction remain informational on loss rows and do not alter the fixed 60% penalty.
- Existing Reviewed, accounting, supplier matching and payment prerequisites still apply. Calculate Current Preview or toggle Reviewed after updating; recollection clears Reviewed.
- This remains a preview. Commission Value stays zero and no salary deduction, journal or payroll posting is created by this package.
- The AL smoke report now checks losses, cents, advance independence, unreviewed loss blocking, break even and return to a positive profit. Run it in Sandbox after compilation; these AL checks have not been executed here.

## v9 changes

- One manual **Reviewed** checkbox replaces the old review caption. Eligible is removed from the page (its stored field and internal safeguards remain). Toggling Reviewed recalculates the current preview. Recollection clears Reviewed.
- Allocated Quantity (Base) and Variant Code are removed from the detail pages only. Internal quantities and variants remain necessary to match items correctly.
- Collect gathers all related goods purchase invoices from explicit PO links and Analysis No. + item/variant, even if allocation is unresolved. Details are unique per commission row + purchase invoice; there is no one-invoice limit. Supplier 1–3 shows up to three distinct goods vendors; the detail panel holds all invoices.
- If one explicit PO supplies insufficient quantity, analysis-linked purchase lines can supplement it. Allocation proceeds only when quantity and uniqueness checks pass. Ambiguous candidates remain visible with review notes and block supplier-match completion/commission preview. The Reviewed checkbox does not override missing evidence.
- Full Invoice USD is the entire supplier invoice; Allocated Cost USD is only the portion matched to this sale. Neither replaces the accounting Bill USD, which already includes freight.

### Sandbox acceptance cases

1. One sales invoice with two items from different vendors: both posted purchase invoices and both vendors must appear after Collect.
2. One item supplied as 6 units on PO A and 4 on PO B for a 10-unit sale: with the same analysis, no other competing sale and valid ledger conversion, both invoices must allocate and costs must add once.
3. Multiple sale lines referencing the same purchase invoice: only one invoice detail row; assigned item costs accumulate without duplicating the full invoice amount.
4. Analysis candidates exceed sales quantity or compete with other sales: invoices remain visible, notes explain the uncertainty and preview remains blocked.
5. Tick Reviewed, then recollect: confirmation resets. Eligible, allocated quantity and variant are absent from the pages.

These acceptance cases require your actual BC Sandbox. This package contains AL source, not a compiled extension. No BC compiler or live database was available here; source consistency checks passed. Keep your existing app.json/extension identity, replace canonical files, increment the app version and compile against installed symbols. Do not use ForceSync to remove fields.

## Inherited accounting behavior

- Retains customer last verified bank receipt **Document Date** collection: previous month 26th to selected month 25th inclusive. Customer cash verification itself is unchanged.
- Invoice USD now comes from invoice G/L revenue accounts **6000–6999**, using the sales invoice number and its Posting Date. Original document-currency Amount remains the sales invoice Amount excluding VAT.
- Bill USD now comes from G/L cost accounts **7000–7999** for that sales invoice through the payout cutoff, plus the outbound non-inventoriable item charges calculated using the report 50047 G/L/item/value-entry relationships. The cost date filter has **no lower bound**, so old invoice costs are not lost just because the cash receipt is this month. This differs deliberately from report 50047's selected reporting-period totals.
- Bill USD includes freight. **Net P/L = Invoice USD − Bill USD**. Freight Charge is an informational included component (additional non-inventoriable charges identified by the routine), not a full freight breakdown and not a second deduction. Missing accounting source entries/quantity mapping blocks profit and is explained in Accounting Amount Note; missing supplier matches blocks commission preview only.
- PI item allocations remain supplier/payment trace and reconciliation information. They no longer overwrite Bill USD. Goods matching excludes Charge (Item) and G/L Account lines already. For transport companies entered using Item lines, mark **Transport Vendor for Commission** on the Vendor Card before recollection. Explicitly marked vendors are excluded from supplier association/payment checks; their accounting cost remains in Bill USD. No name-based classification is used.
- Recollection resets derived results for **unapproved rows stored in the chosen Commission Month** and repopulates qualifying invoices. Rows that no longer qualify remain visible with Qualifies for Collection Period = false, Review Required, and cleared calculated results/details. They are not deleted. Approved rows are not modified. Rows in other stored months are not reset by this run; recollect their respective month to migrate them. Review flags are reset; re-review after the amount basis changes.

## Test in Sandbox

1. Select the payout month and run Collect for Month again.
2. Check Qualifies for Collection Period, Accounting Amounts Verified, Accounting Amount Note and Cost Checked Through.
3. Compare Invoice USD and Bill USD against underlying G/L/Value Entries using the same cumulative cutoff. If the old report is used for reconciliation, align its cost period or explain the period difference.
4. Confirm freight appears inside Bill USD and is not subtracted twice. Review the figures and tick Reviewed to enable the existing preview when customer/supplier prerequisites are met.
5. Check a fully paid invoice with a receipt on the 26th and one on the 25th, plus receipts outside the window. Test January/December rollover.
6. Recollect after a receipt is unapplied or moved to a different month: an existing unapproved row in the selected month must be flagged and its old results cleared. Approved records must remain unchanged.
7. Check goods supplier plus freight supplier: only goods suppliers enter the supplier list/payment eligibility; accounting Bill retains freight cost. Mark the freight vendor explicitly if freight was coded as Item.
8. Run Commission Calculation Smoke Test. It now sets the prerequisite flags, checks freight is not deducted twice, profit independent of supplier-match status, and out-of-period blocking.

## Limits

Source consistency checks were run for v9. Earlier arithmetic/period checks relate to the inherited v8 code. AL compilation and live BC testing were not available. The source includes additive fields only; inspect schema synchronization normally before publishing.

Existing single-date deduction, fixed 15% rate and 1% monthly interest remain. Weighted partial advances, highest-value supplier term selection and full payroll approval are unchanged/pending. Commission Value stays zero/Eligible stays false; the available output is the test preview. This update does not claim to complete those policy features.

The accounting routine inherits report 50047's first non-adjustment valued quantity per item ledger entry assumption. Reconcile partial invoice/return/charge scenarios in Sandbox. Missing zero-cost evidence stays for review rather than treating absent cost as zero. It prevents re-adding a non-inventoriable charge already linked into the included cost G/L set.

Tables and fields already in your uploaded files retain IDs and types. New Commission fields: 54 Accounting Cost Complete, 55 Accounting Cost Note, 56 In Collection Period, 57 Cost Checked Through. New Vendor field 90424 APSS Comm Transport Vendor defaults false; only authorized vendor maintenance users should change it.
