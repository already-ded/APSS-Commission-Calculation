report 90420 "APSS Collect Commission"
{
    Caption = 'Collect Monthly Commission (Test)';
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
                Mgt: Codeunit "APSS Commission Mgt.";
            begin
                Mgt.CollectForMonth(CommissionMonth);
            end;
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Period)
                {
                    field(Month; CommissionMonth)
                    {
                        Caption = 'Commission Month';
                        ApplicationArea = All;
                        ToolTip = 'Select the commission month. The latest applied customer Payment Posting Date must fall from the 26th of the prior month to the 25th of the selected month (inclusive). Supplier item matching and payment remain subject to review.';
                    }
                }
            }
        }
    }
    var
        CommissionMonth: Date;

    trigger OnInitReport()
    begin
        CommissionMonth := WorkDate();
    end;
}
