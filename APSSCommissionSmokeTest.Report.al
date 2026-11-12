report 90421 "APSS Commission Smoke Test"
{
    Caption = 'Commission Calculation Smoke Test';
    ProcessingOnly = true;
    UsageCategory = Tasks;
    ApplicationArea = All;
    dataset
    {
        dataitem(Once; Integer)
        {
            DataItemTableView = sorting(Number) where(Number = const(1));
            trigger OnAfterGetRecord()
            var
                Line: Record "APSS Commission Calculation" temporary;
                Mgt: Codeunit "APSS Commission Mgt.";
            begin
                CheckAppliedPaymentDates();
                Line.Init();
                Line."Invoice (USD)" := 10000;
                Line."Bill (USD)" := 7500;
                Line."Freight Charge" := 500;
                Line."Supplier Payment Date" := DMY2Date(1, 9, 2026);
                Line."Customer Payment Date" := DMY2Date(16, 10, 2026);
                Line."In Collection Period" := true;
                Line."Accounting Cost Complete" := true;
                Line."Supplier Match Complete" := true;
                Line."Customer Paid" := true;
                Line."Suppliers Paid" := true;
                Line."Cost Inputs Reviewed" := true;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Advance months', 1.5, Line."Advance Months");
                CheckValue('Deduction percentage points', 1.5, Line."Deduction (%)");
                CheckValue('Actual rate', 13.5, Line."Actual Commission (%)");
                CheckValue('Net profit', 2500, Line."Net P/L (USD)");
                CheckValue('Margin percentage points', 25, Line."P/L (%)");
                CheckValue('Preview', 337.50, Line."Calculated Commission Preview");
                CheckValue('Payable is blocked', 0, Line."Commission Value (USD)");
                if Line.Eligible then
                    Error('A test preview must not become eligible.');
                Line."Cost Inputs Reviewed" := false;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Unreviewed cost is blocked', 0, Line."Calculated Commission Preview");
                Line."Cost Inputs Reviewed" := true;
                Line."Supplier Payment Date" := 0D;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Missing date is blocked', 0, Line."Calculated Commission Preview");
                Line."Supplier Payment Date" := Line."Customer Payment Date" + 10;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('No negative advance months', 0, Line."Advance Months");
                CheckValue('No advance deduction', 375, Line."Calculated Commission Preview");
                Line."Bill (USD)" := 11000;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Loss is negative', -1000, Line."Net P/L (USD)");
                CheckValue('Loss penalty rate', 60, Line."Actual Commission (%)");
                CheckValue('Loss penalty preview', -600, Line."Calculated Commission Preview");
                Line."Supplier Payment Date" := DMY2Date(1, 9, 2026);
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Advance does not reduce loss penalty', -600, Line."Calculated Commission Preview");
                Line."Bill (USD)" := 10123.45;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Loss penalty cents', -74.07, Line."Calculated Commission Preview");
                Line."Cost Inputs Reviewed" := false;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Unreviewed loss remains blocked', 0, Line."Calculated Commission Preview");
                Line."Cost Inputs Reviewed" := true;
                Line."Bill (USD)" := 10000;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Break even has no commission', 0, Line."Calculated Commission Preview");
                CheckValue('Break even actual rate', 0, Line."Actual Commission (%)");
                Line."Bill (USD)" := 7500;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Profit rate restored after loss', 13.5, Line."Actual Commission (%)");
                CheckValue('Profit preview restored after loss', 337.50, Line."Calculated Commission Preview");
                // Profit must not be blocked just because supplier matching is pending.
                Line."Bill (USD)" := 7500;
                Line."Supplier Match Complete" := false;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Accounting profit independent of supplier match', 2500, Line."Net P/L (USD)");
                CheckValue('Unmatched supplier blocks preview', 0, Line."Calculated Commission Preview");
                Line."In Collection Period" := false;
                Mgt.CalculateAdvanceAndCommission(Line);
                CheckValue('Out-of-period profit cleared', 0, Line."Net P/L (USD)");
                CheckValue('Out-of-period preview cleared', 0, Line."Calculated Commission Preview");
                Message('Calculation smoke tests passed. Temporary records only; no invoice collection or payroll entries were created.');
            end;
        }
    }
    local procedure CheckAppliedPaymentDates()
    var
        InvoiceEntry: Record "Cust. Ledger Entry" temporary;
        Payments: Record "Cust. Ledger Entry" temporary;
        Details: Record "Detailed Cust. Ledg. Entry" temporary;
        Mgt: Codeunit "APSS Commission Mgt.";
        PaymentDate: Date;
    begin
        InvoiceEntry.Init();
        InvoiceEntry."Entry No." := 100;
        InvoiceEntry."Customer No." := 'TEST-CUSTOMER';
        InvoiceEntry."Document Type" := InvoiceEntry."Document Type"::Invoice;
        InvoiceEntry."Posting Date" := DMY2Date(28, 5, 2026);
        InsertTestPayment(Payments, 200, DMY2Date(2, 10, 2026));
        InsertTestPayment(Payments, 201, DMY2Date(2, 10, 2026));
        // USD 987.84 receipt + USD 10 bank-charge Payment, with no bank records.
        InsertTestApplication(Details, 1, 100, 200, -987.84, false);
        InsertTestApplication(Details, 2, 100, 201, -10, false);
        if not Mgt.FindLastAppliedPaymentDate(InvoiceEntry, Details, Payments, PaymentDate) then
            Error('Applied receipt and bank-charge Payments must produce a date without bank entries.');
        CheckPaymentDate('May invoice paid in October', DMY2Date(2, 10, 2026), PaymentDate);

        Payments.Get(201);
        Payments."Posting Date" := DMY2Date(3, 10, 2026);
        Payments.Modify();
        Mgt.FindLastAppliedPaymentDate(InvoiceEntry, Details, Payments, PaymentDate);
        CheckPaymentDate('Latest payment, not first', DMY2Date(3, 10, 2026), PaymentDate);

        Details.Reset();
        Details.DeleteAll();
        // Reverse links, used when the invoice is the applying entry.
        InsertTestApplication(Details, 3, 200, 100, 987.84, false);
        InsertTestApplication(Details, 4, 201, 100, 10, false);
        InsertTestPayment(Payments, 202, DMY2Date(30, 10, 2026));
        InsertTestApplication(Details, 5, 202, 100, 10, true);
        InsertTestPayment(Payments, 203, DMY2Date(30, 10, 2026));
        Payments.Get(203);
        Payments.Reversed := true;
        Payments.Modify();
        InsertTestApplication(Details, 6, 203, 100, 10, false);
        InsertTestPayment(Payments, 204, DMY2Date(30, 10, 2026));
        Payments.Get(204);
        Payments."Document Type" := Payments."Document Type"::"Credit Memo";
        Payments.Modify();
        InsertTestApplication(Details, 7, 204, 100, 10, false);
        InsertTestPayment(Payments, 205, DMY2Date(30, 10, 2026));
        Payments.Get(205);
        Payments."Customer No." := 'OTHER-CUSTOMER';
        Payments.Modify();
        InsertTestApplication(Details, 8, 205, 100, 10, false);
        Mgt.FindLastAppliedPaymentDate(InvoiceEntry, Details, Payments, PaymentDate);
        CheckPaymentDate('Reverse links; ignore unapplied, reversed, credit and other customer', DMY2Date(3, 10, 2026), PaymentDate);

        Payments.Get(201);
        Payments."Posting Date" := DMY2Date(2, 11, 2026);
        Payments.Modify();
        Mgt.FindLastAppliedPaymentDate(InvoiceEntry, Details, Payments, PaymentDate);
        CheckPaymentDate('Use latest overall payment before selecting the month', DMY2Date(2, 11, 2026), PaymentDate);
        Details.Reset();
        Details.DeleteAll();
        InsertTestApplication(Details, 9, 204, 100, 997.84, false);
        if Mgt.FindLastAppliedPaymentDate(InvoiceEntry, Details, Payments, PaymentDate) then
            Error('Credit-only settlement must not produce a Payment date.');
        CheckPaymentDate('No Payment means no date', 0D, PaymentDate);
    end;

    local procedure InsertTestPayment(var Payments: Record "Cust. Ledger Entry" temporary; EntryNo: Integer; PostingDate: Date)
    begin
        Payments.Init();
        Payments."Entry No." := EntryNo;
        Payments."Customer No." := 'TEST-CUSTOMER';
        Payments."Document Type" := Payments."Document Type"::Payment;
        Payments."Posting Date" := PostingDate;
        Payments.Insert();
    end;

    local procedure InsertTestApplication(var Details: Record "Detailed Cust. Ledg. Entry" temporary; EntryNo: Integer; CustEntryNo: Integer; AppliedEntryNo: Integer; AppliedAmount: Decimal; IsUnapplied: Boolean)
    begin
        Details.Init();
        Details."Entry No." := EntryNo;
        Details."Cust. Ledger Entry No." := CustEntryNo;
        Details."Applied Cust. Ledger Entry No." := AppliedEntryNo;
        Details."Entry Type" := Details."Entry Type"::Application;
        Details."Source Code" := 'GENJNL';
        Details.Amount := AppliedAmount;
        Details.Unapplied := IsUnapplied;
        Details.Insert();
    end;

    local procedure CheckPaymentDate(Name: Text; Expected: Date; Actual: Date)
    begin
        if Expected <> Actual then
            Error('%1: expected %2, actual %3.', Name, Expected, Actual);
    end;

    local procedure CheckValue(Name: Text; Expected: Decimal; Actual: Decimal)
    begin
        if Abs(Expected - Actual) > 0.000001 then
            Error('%1: expected %2, actual %3.', Name, Expected, Actual);
    end;
}
