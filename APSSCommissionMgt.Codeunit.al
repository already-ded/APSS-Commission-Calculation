codeunit 90420 "APSS Commission Mgt."
{
    // Phase 1: sales collection and explicitly reviewed calculation previews.
    // Supplier links and payroll approval are deliberately not inferred.
    // Collect by the last verified customer bank receipt DOCUMENT DATE.
    // This is the same date source used by report 50047 "APSS PL by Posted SI".
    // Each selected commission month covers the 26th of the prior month
    // through the 25th of the selected month (both dates inclusive).
    // A fully cash-settled customer invoice can be collected even if its
    // sales invoice Posting Date belongs to an earlier month.
    procedure CollectForMonth(CommissionMonth: Date)
    var
        Invoice: Record "Sales Invoice Header";
        GLSetup: Record "General Ledger Setup";
        MonthStart: Date;
        PeriodStart: Date;
        PeriodEnd: Date;
        Collected: Integer;
        Refreshed: Integer;
        Skipped: Integer;
    begin
        if CommissionMonth = 0D then
            Error('Choose a commission month.');
        GLSetup.Get();
        if GLSetup."LCY Code" <> 'USD' then
            Error('This test version requires LCY Code USD. Current LCY is %1.', GLSetup."LCY Code");

        // Keep the commission MONTH stored as the 1st of the chosen month,
        // but collect last bank receipts dated 26th prior month..25th chosen month.
        // Using the 25th as the anchor avoids invalid dates in short months.
        MonthStart := DMY2Date(1, Date2DMY(CommissionMonth, 2), Date2DMY(CommissionMonth, 3));
        PeriodEnd := DMY2Date(25, Date2DMY(CommissionMonth, 2), Date2DMY(CommissionMonth, 3));
        PeriodStart := CalcDate('<-1M>', PeriodEnd) + 1;

        // Do not filter on Sales Invoice Posting Date at all: the commission
        // month is based solely on the last verified bank receipt Document Date.
        // This scans posted invoices from all periods (may take longer in a
        // company with a large invoice history).
        RefreshExistingMonth(MonthStart);
        if Invoice.FindSet() then
            repeat
                CollectInvoice(Invoice, MonthStart, PeriodStart, PeriodEnd, Collected, Refreshed, Skipped);
            until Invoice.Next() = 0;

        Message('%1 new invoice(s), %2 refreshed, %3 approved/skipped. Commission Month: %4; last bank receipt Document Date: %5 through %6 (inclusive).',
            Collected, Refreshed, Skipped, MonthStart, PeriodStart, PeriodEnd);
    end;

    local procedure CollectInvoice(Invoice: Record "Sales Invoice Header"; MonthStart: Date; PeriodStart: Date; PeriodEnd: Date; var Collected: Integer; var Refreshed: Integer; var Skipped: Integer)
    var
        CLE: Record "Cust. Ledger Entry";
        Line: Record "APSS Commission Calculation";
        NewLine: Boolean;
        LastReceiptDate: Date;
        SupplierMgt: Codeunit "APSS Commission Suppliers";
        AccountingMgt: Codeunit "APSS Commission Accounting";
    begin
        // First verify full CASH settlement and retrieve the last bank receipt
        // Document Date. An invoice's Posting Date NEVER selects the month.
        if not FindInvoiceLedgerEntry(Invoice, CLE) then
            exit;
        CLE.CalcFields("Original Amount", "Original Amt. (LCY)", "Remaining Amount");
        if not GetCashSettlement(CLE, LastReceiptDate) then
            exit;
        if (LastReceiptDate < PeriodStart) or (LastReceiptDate > PeriodEnd) then
            exit;

        Line.LockTable();
        // Re-use a previously collected row to avoid duplication when the
        // payment receipt month differs from the old invoice posting month.
        Line.SetRange("Our Ref", Invoice."No.");
        Line.SetRange(Type, Line.Type::Invoice);
        if Line.Count() > 1 then
            Error('Multiple commission lines already exist for invoice %1. Reconcile them before recollecting.', Invoice."No.");
        NewLine := not Line.FindFirst();
        if not NewLine then
            if Line.Status = Line.Status::Approved then begin
                Skipped += 1;
                exit;
            end;
        if NewLine then begin
            Line.Init();
            Line."Entry No." := 0;
        end;
        // Store the selected commission month (first day), NOT the receipt
        // window start, which is the 26th of the previous calendar month.
        Line."Commission Month" := MonthStart;
        Line."In Collection Period" := true;
        Line.Type := Line.Type::Invoice;
        Line."Our Ref" := Invoice."No.";
        Line."Their Ref" := Invoice."External Document No.";
        Line."Customer No." := Invoice."Bill-to Customer No.";
        Line."Customer Name" := Invoice."Bill-to Name";
        Line."Salesperson Code" := Invoice."Salesperson Code";
        Line."Analysis No." := ResolveAnalysisNo(Invoice);
        Line."Invoice Date" := Invoice."Posting Date";
        Line."Currency Code" := Invoice."Currency Code";
        Invoice.CalcFields(Amount);
        Line.Amount := Invoice.Amount;

        // Clear prior calculated results; preserve reviewed purchase-cost inputs.
        Line."Customer Ledger Entry No." := CLE."Entry No.";
        Line."Customer Remaining Amount" := CLE."Remaining Amount";
        Line."Customer Payment Date" := LastReceiptDate;
        Line."Customer Paid" := true;
        Line."Invoice (USD)" := 0;
        Line."Exchange Rate" := 0;
        Line.Eligible := false;
        Line."Commission Value (USD)" := 0;
        Line."Calculated Commission Preview" := 0;
        Line."Advance Months" := 0;
        Line."Deduction (%)" := 0;
        Line."Actual Commission (%)" := 0;
        Line."P/L (%)" := 0;
        Line."Net P/L (USD)" := 0;
        Line."Commission Rate (%)" := 15;
        Line."Monthly Interest Rate" := 1;
        Line.Status := Line.Status::"Review Required";
        Line."Calculation Note" := 'Customer fully paid. Last bank receipt Document Date is within the 26th-to-25th commission period; supplier documents/payments require review.';
        if Line."Analysis No." = '' then
            Line."Calculation Note" := 'Customer fully paid but Analysis No. missing. Supplier matching requires review.';
        Line."Collection Run Date" := CurrentDateTime();

        if NewLine then begin
            Line.Insert(true);
            Collected += 1;
        end else begin
            Line.Modify(true);
            Refreshed += 1;
        end;
        // Preserve existing supplier logic. In particular, a customer receipt
        // does NOT make the commission payable before all suppliers are paid.
        SupplierMgt.Collect(Line, PeriodEnd);
        AccountingMgt.ApplyAmounts(Line, Invoice, PeriodEnd);
        CalculateAdvanceAndCommission(Line);
        Line.Modify(true);
    end;

    local procedure RefreshExistingMonth(MonthStart: Date)
    var
        Line: Record "APSS Commission Calculation";
        Allocation: Record "APSS Commission Allocation";
        Purchase: Record "APSS Commission Purchase";
    begin
        Line.LockTable();
        Line.SetRange("Commission Month", MonthStart);
        Line.SetFilter(Status, '<>%1', Line.Status::Approved);
        if Line.FindSet(true) then
            repeat
                // Derived data only. Keep invoice identity and do not delete a
                // record just because its payment was unapplied or moved months.
                Allocation.SetRange("Commission Entry No.", Line."Entry No.");
                Allocation.DeleteAll();
                Purchase.SetRange("Commission Entry No.", Line."Entry No.");
                Purchase.DeleteAll();
                Clear(Line."Supplier 1"); Clear(Line."Supplier 1 Name");
                Clear(Line."Supplier 1 Invoice Amount"); Clear(Line."Supplier 1 Payment Date");
                Clear(Line."Supplier 2"); Clear(Line."Supplier 2 Name");
                Clear(Line."Supplier 2 Invoice Amount"); Clear(Line."Supplier 2 Payment Date");
                Clear(Line."Supplier 3"); Clear(Line."Supplier 3 Name");
                Clear(Line."Supplier 3 Invoice Amount"); Clear(Line."Supplier 3 Payment Date");
                Clear(Line."Supplier Payment Date"); Clear(Line."Customer Payment Date");
                Line."In Collection Period" := false;
                Line."Accounting Cost Complete" := false;
                Line."Cost Checked Through" := 0D;
                Line."Accounting Cost Note" := 'Not requalified in this run; accounting amounts cleared.';
                Line."Supplier Match Complete" := false;
                Line."Supplier Document Count" := 0;
                Line."Unmatched Item Lines" := 0;
                Line."Matched Supplier Total USD" := 0;
                Line."Customer Paid" := false;
                Line."Suppliers Paid" := false;
                Line."Cost Inputs Reviewed" := false;
                Line."Customer Remaining Amount" := 0;
                Line."Invoice (USD)" := 0;
                Line."Exchange Rate" := 0;
                Line."Bill (USD)" := 0;
                Line."Freight Charge" := 0;
                Line."Net P/L (USD)" := 0;
                Line."P/L (%)" := 0;
                Line."Advance Months" := 0;
                Line."Deduction (%)" := 0;
                Line."Actual Commission (%)" := 0;
                Line."Calculated Commission Preview" := 0;
                Line."Commission Value (USD)" := 0;
                Line.Eligible := false;
                Line.Status := Line.Status::"Review Required";
                Line."Calculation Note" := 'Does not currently qualify for this 26th-to-25th period. Recollection will refresh qualifying invoices only.';
                Line."Supplier Collection Note" := 'Previous supplier snapshots cleared; invoice awaiting requalification.';
                Line."Collection Run Date" := CurrentDateTime();
                Line.Modify(true);
            until Line.Next() = 0;
    end;

    local procedure FindInvoiceLedgerEntry(Invoice: Record "Sales Invoice Header"; var CLE: Record "Cust. Ledger Entry"): Boolean
    begin
        CLE.Reset();
        // Prefer the explicit ledger entry link carried by the posted invoice.
        if Invoice."Cust. Ledger Entry No." <> 0 then begin
            if not CLE.Get(Invoice."Cust. Ledger Entry No.") then
                exit(false);
            exit((CLE."Document Type" = CLE."Document Type"::Invoice) and
                 (CLE."Document No." = Invoice."No.") and
                 (CLE."Customer No." = Invoice."Bill-to Customer No."));
        end;
        // Legacy invoices without an explicit link: accept only one exact match.
        CLE.SetRange("Document Type", CLE."Document Type"::Invoice);
        CLE.SetRange("Document No.", Invoice."No.");
        CLE.SetRange("Customer No.", Invoice."Bill-to Customer No.");
        if CLE.Count() <> 1 then
            exit(false);
        exit(CLE.FindFirst());
    end;

    local procedure ResolveAnalysisNo(Invoice: Record "Sales Invoice Header"): Code[50]
    var
        Ref: RecordRef;
        Fld: FieldRef;
        Index: Integer;
    begin
        // Exact field names only. No number-pattern or item matching guesses.
        Ref.GetTable(Invoice);
        // Prefer the APSS custom field if present on the SALES header too.
        // Its sales-side field ID is not assumed to equal purchase field 50001.
        for Index := 1 to Ref.FieldCount do begin
            Fld := Ref.FieldIndex(Index);
            if Fld.Name = 'APSS Analysis No.' then
                if (Fld.Type = FieldType::Code) or (Fld.Type = FieldType::Text) then
                    if Format(Fld.Value) <> '' then
                        exit(CopyStr(Format(Fld.Value), 1, 50));
        end;
        for Index := 1 to Ref.FieldCount do begin
            Fld := Ref.FieldIndex(Index);
            if (Fld.Name = 'Analysis No.') or (Fld.Name = 'Analysis No') then
                if Format(Fld.Value) <> '' then
                    exit(CopyStr(Format(Fld.Value), 1, 50));
        end;
        exit(CopyStr(Invoice."Opportunity No.", 1, 50));
    end;

    // Report 50047 derives its Payment Date from the matching Bank Account
    // Ledger Entry's Document Date (using Source Code CASHRECJNL on the
    // Detailed Customer Ledger Entry). Unlike the report's FindFirst(),
    // calculate the LAST receipt date across all verified partial receipts.
    local procedure GetCashSettlement(CLE: Record "Cust. Ledger Entry"; var PaymentDate: Date): Boolean
    var
        Detail: Record "Detailed Cust. Ledg. Entry";
        Payment: Record "Cust. Ledger Entry";
        BankEntry: Record "Bank Account Ledger Entry";
        CashApplied: Decimal;
        ReceiptDate: Date;
    begin
        PaymentDate := 0D;
        CLE.CalcFields("Original Amount", "Remaining Amount");

        // The bank receipt Document Date determines the month. Do not use an
        // application Posting Date cutoff here, because a bank receipt dated
        // in one month can be posted in another. Use current active payments
        // and the current remaining balance, as the source report does.
        if (CLE."Original Amount" <= 0) or (Abs(CLE."Remaining Amount") > 0.01) then
            exit(false);

        Detail.SetRange("Cust. Ledger Entry No.", CLE."Entry No.");
        Detail.SetRange("Entry Type", Detail."Entry Type"::Application);
        Detail.SetRange(Unapplied, false);
        // Use the same receipt-journal source code as the APSS P/L report.
        Detail.SetRange("Source Code", 'CASHRECJNL');
        if Detail.FindSet() then
            repeat
                if (Detail."Applied Cust. Ledger Entry No." <> CLE."Entry No.") and
                   (Detail.Amount < 0) then
                    if Payment.Get(Detail."Applied Cust. Ledger Entry No.") then
                        if (Payment."Document Type" = Payment."Document Type"::Payment) and
                           (Payment."Customer No." = CLE."Customer No.") then begin
                            ReceiptDate := 0D;
                            BankEntry.Reset();
                            BankEntry.SetRange("Document No.", Payment."Document No.");
                            BankEntry.SetRange("Posting Date", Payment."Posting Date");
                            BankEntry.SetRange(Reversed, false);
                            BankEntry.SetFilter(Amount, '>%1', 0); // Incoming bank receipts only.
                            if BankEntry.FindSet() then
                                repeat
                                    if BankEntry."Document Date" > ReceiptDate then
                                        ReceiptDate := BankEntry."Document Date";
                                until BankEntry.Next() = 0;

                            // Only count payment applications with verified
                            // bank ledger receipts, not credit memos/discounts.
                            if ReceiptDate <> 0D then begin
                                CashApplied -= Detail.Amount;
                                if ReceiptDate > PaymentDate then
                                    PaymentDate := ReceiptDate;
                            end;
                        end;
            until Detail.Next() = 0;

        exit((CashApplied >= CLE."Original Amount" - 0.01) and (PaymentDate <> 0D));
    end;

    procedure CalculateAdvanceAndCommission(var Commission: Record "APSS Commission Calculation")
    var
        DaysAdvanced: Integer;
    begin
        if Commission.Status = Commission.Status::Approved then
            Error('Approved commission cannot be recalculated.');
        Commission."Commission Rate (%)" := 15;
        Commission."Monthly Interest Rate" := 1;
        Commission."Advance Months" := 0;
        Commission."Deduction (%)" := 0;
        Commission."Actual Commission (%)" := 0;
        Commission."Calculated Commission Preview" := 0;
        Commission."Commission Value (USD)" := 0;
        Commission.Eligible := false;
        Commission.Status := Commission.Status::"Review Required";
        if (Commission."Customer Payment Date" <> 0D) and (Commission."Supplier Payment Date" <> 0D) then begin
            DaysAdvanced := Commission."Customer Payment Date" - Commission."Supplier Payment Date";
            if DaysAdvanced > 0 then
                Commission."Advance Months" := DaysAdvanced / 30;
        end;
        Commission."Deduction (%)" := Commission."Advance Months" * Commission."Monthly Interest Rate";
        Commission."Actual Commission (%)" := 15 - Commission."Deduction (%)";
        if Commission."Actual Commission (%)" < 0 then
            Commission."Actual Commission (%)" := 0;
        if not Commission."In Collection Period" then begin
            Commission."Net P/L (USD)" := 0;
            Commission."P/L (%)" := 0;
            Commission."Calculation Note" := 'Invoice no longer qualifies for its collection period. Recollect the correct month.';
            exit;
        end;
        // Accounting completeness controls PROFIT; supplier completeness controls
        // COMMISSION. Do not replace accounting cost with PI allocations.
        if not Commission."Accounting Cost Complete" then begin
            Commission."Net P/L (USD)" := 0;
            Commission."P/L (%)" := 0;
            Commission."Calculation Note" := 'Accounting amount verification incomplete. Check Accounting Amount Note.';
            exit;
        end;
        Commission."Net P/L (USD)" := Commission."Invoice (USD)" - Commission."Bill (USD)";
        Commission."P/L (%)" := 0;
        if Commission."Invoice (USD)" <> 0 then
            Commission."P/L (%)" := Commission."Net P/L (USD)" / Commission."Invoice (USD)" * 100;
        // Losses use a fixed 60% penalty, independent of the advance-period
        // deduction used for profitable sales. Preserve the negative sign.
        if Commission."Net P/L (USD)" < 0 then
            Commission."Actual Commission (%)" := 60;
        if Commission."Net P/L (USD)" = 0 then
            Commission."Actual Commission (%)" := 0;
        if Commission."Cost Inputs Reviewed" and Commission."Supplier Match Complete" and
           Commission."Customer Paid" and Commission."Suppliers Paid" and
           (Commission."Customer Payment Date" <> 0D) and (Commission."Supplier Payment Date" <> 0D) then
            Commission."Calculated Commission Preview" := Round(Commission."Net P/L (USD)" * Commission."Actual Commission (%)" / 100, 0.01);
        if Commission."Net P/L (USD)" < 0 then
            Commission."Calculation Note" := 'Loss penalty: Net P/L x 60%; advance deduction does not change this rate. Preview requires Reviewed and verified invoice/payment data. Payroll posting is not implemented.'
        else
            Commission."Calculation Note" := 'Preview only. Verify all supplier documents and payments before implementing payable commission. Multi-payment weighting is not implemented.';
    end;
}
