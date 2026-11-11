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
                CheckValue('Loss requires policy review', 0, Line."Calculated Commission Preview");
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
    local procedure CheckValue(Name: Text; Expected: Decimal; Actual: Decimal)
    begin
        if Abs(Expected - Actual) > 0.000001 then
            Error('%1: expected %2, actual %3.', Name, Expected, Actual);
    end;
}
