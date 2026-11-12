page 90420 "APSS Commission Calculation"
{
    Caption = 'APSS Commission Calculation';
    PageType = List;
    SourceTable = "APSS Commission Calculation";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(CommissionLines)
            {
                field("In Collection Period"; Rec."In Collection Period") { ApplicationArea = All; }
                field("Accounting Cost Complete"; Rec."Accounting Cost Complete") { ApplicationArea = All; }
                field("Accounting Cost Note"; Rec."Accounting Cost Note") { ApplicationArea = All; }
                field("Cost Checked Through"; Rec."Cost Checked Through") { ApplicationArea = All; }
                field("Supplier Document Count"; Rec."Supplier Document Count") { ApplicationArea = All; }
                field("Matched Supplier Total USD"; Rec."Matched Supplier Total USD") { ApplicationArea = All; }
                field("Supplier Collection Note"; Rec."Supplier Collection Note") { ApplicationArea = All; }
                field("Supplier Match Complete"; Rec."Supplier Match Complete") { ApplicationArea = All; Editable = false; }
                field("Unmatched Item Lines"; Rec."Unmatched Item Lines") { ApplicationArea = All; Editable = false; }
                field("Cost Inputs Reviewed"; Rec."Cost Inputs Reviewed")
                {
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        CommissionMgt: Codeunit "APSS Commission Mgt.";
                    begin
                        CommissionMgt.CalculateAdvanceAndCommission(Rec);
                    end;
                }
                field("Calculated Commission Preview"; Rec."Calculated Commission Preview") { ApplicationArea = All; }
                field("Customer Ledger Entry No."; Rec."Customer Ledger Entry No.") { ApplicationArea = All; }
                field("Commission Month"; Rec."Commission Month") { ApplicationArea = All; Editable = false; }
                field(Status; Rec.Status) { ApplicationArea = All; Editable = false; }
                field(Type; Rec.Type) { ApplicationArea = All; Editable = false; }
                field("Customer No."; Rec."Customer No.") { ApplicationArea = All; Editable = false; }
                field("Customer Name"; Rec."Customer Name") { ApplicationArea = All; Editable = false; }
                field("Salesperson Code"; Rec."Salesperson Code") { ApplicationArea = All; Editable = false; }
                field("Analysis No."; Rec."Analysis No.") { ApplicationArea = All; }
                field("Our Ref"; Rec."Our Ref")
                {
                    ApplicationArea = All;
                    Editable = false;
                    DrillDown = true;
                    ToolTip = 'Open the posted sales invoice identified by Our Ref. Their Ref. remains the customer external reference.';
                    trigger OnDrillDown()
                    begin
                        OpenSalesInvoice();
                    end;
                }
                field("Their Ref"; Rec."Their Ref")
                {
                    ApplicationArea = All;
                    Editable = false;
                    DrillDown = true;
                    ToolTip = 'Open the posted sales invoice identified by Our Ref. Their Ref. remains the customer external reference.';
                    trigger OnDrillDown()
                    begin
                        OpenSalesInvoice();
                    end;
                }
                field("Invoice Date"; Rec."Invoice Date") { ApplicationArea = All; Editable = false; }
                field("Customer Payment Date"; Rec."Customer Payment Date") { ApplicationArea = All; Editable = false; ToolTip = 'Specifies the latest Posting Date of a currently applied customer Payment. Bank-charge payments are included without requiring a bank ledger entry.'; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; Editable = false; }
                field(Amount; Rec.Amount) { ApplicationArea = All; Editable = false; }
                field("Exchange Rate"; Rec."Exchange Rate") { ApplicationArea = All; Editable = false; }
                field("Invoice (USD)"; Rec."Invoice (USD)") { ApplicationArea = All; Editable = false; }
                field("Bill (USD)"; Rec."Bill (USD)") { ApplicationArea = All; Editable = false; }
                field("Freight Charge"; Rec."Freight Charge") { ApplicationArea = All; Editable = false; }
                field("P/L (%)"; Rec."P/L (%)") { ApplicationArea = All; Editable = false; }
                field("Net P/L (USD)"; Rec."Net P/L (USD)") { ApplicationArea = All; Editable = false; }
                field("Supplier 1"; Rec."Supplier 1") { ApplicationArea = All; }
                field("Supplier 1 Payment Date"; Rec."Supplier 1 Payment Date") { ApplicationArea = All; }
                field("Supplier 2"; Rec."Supplier 2") { ApplicationArea = All; }
                field("Supplier 2 Payment Date"; Rec."Supplier 2 Payment Date") { ApplicationArea = All; }
                field("Supplier 3"; Rec."Supplier 3") { ApplicationArea = All; }
                field("Supplier 3 Payment Date"; Rec."Supplier 3 Payment Date") { ApplicationArea = All; }
                field("Supplier Payment Date"; Rec."Supplier Payment Date") { ApplicationArea = All; }
                field("Advance Months"; Rec."Advance Months") { ApplicationArea = All; }
                field("Monthly Interest Rate"; Rec."Monthly Interest Rate") { ApplicationArea = All; Editable = false; }
                field("Deduction (%)"; Rec."Deduction (%)") { ApplicationArea = All; }
                field("Commission Rate (%)"; Rec."Commission Rate (%)") { ApplicationArea = All; Editable = false; }
                field("Actual Commission (%)"; Rec."Actual Commission (%)") { ApplicationArea = All; }
                field("Commission Value (USD)"; Rec."Commission Value (USD)") { ApplicationArea = All; }
                field("Customer Remaining Amount"; Rec."Customer Remaining Amount") { ApplicationArea = All; }
                field("Customer Paid"; Rec."Customer Paid") { ApplicationArea = All; Editable = false; }
                field("Suppliers Paid"; Rec."Suppliers Paid") { ApplicationArea = All; Editable = false; }
                field("Calculation Note"; Rec."Calculation Note") { ApplicationArea = All; }
            }
        }
        area(factboxes)
        {
            part(SupplierInvoices; "APSS Commission Purchases")
            {
                ApplicationArea = All;
                SubPageLink = "Commission Entry No." = field("Entry No.");
            }
            part(MatchedItemLines; "APSS Commission Allocations")
            {
                ApplicationArea = All;
                SubPageLink = "Commission Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(CalculateSelected)
            {
                Caption = 'Calculate Current Preview';
                ApplicationArea = All;
                Image = Calculate;

                trigger OnAction()
                var
                    CommissionMgt: Codeunit "APSS Commission Mgt.";
                begin
                    CommissionMgt.CalculateAdvanceAndCommission(Rec);
                    Rec.Modify(true);
                end;
            }
            action(CollectForMonth)
            {
                Caption = 'Collect for Month';
                ApplicationArea = All;
                Image = CreateDocument;

                trigger OnAction()
                begin
                    Report.RunModal(Report::"APSS Collect Commission");
                    CurrPage.Update(false);
                end;
            }
        }
    }
    local procedure OpenSalesInvoice()
    var
        Invoice: Record "Sales Invoice Header";
    begin
        Rec.TestField("Our Ref");
        if not Invoice.Get(Rec."Our Ref") then
            Error('Posted sales invoice %1 was not found in company %2.', Rec."Our Ref", CompanyName());
        Invoice.SetRecFilter();
        Page.RunModal(Page::"Posted Sales Invoice", Invoice);
    end;

}
