page 90422 "APSS Commission Purchases"
{
    PageType = ListPart;
    SourceTable = "APSS Commission Purchase";
    Caption = 'Collected Supplier Invoices';
    Editable = false;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(Invoices)
            {
                field("Purchase Invoice No."; Rec."Purchase Invoice No.")
                {
                    ApplicationArea = All;
                    DrillDown = true;
                    ToolTip = 'Open this posted purchase invoice.';
                    trigger OnDrillDown()
                    var
                        Invoice: Record "Purch. Inv. Header";
                    begin
                        if not Invoice.Get(Rec."Purchase Invoice No.") then
                            Error('Posted purchase invoice %1 was not found.', Rec."Purchase Invoice No.");
                        Invoice.SetRecFilter();
                        Page.RunModal(Page::"Posted Purchase Invoice", Invoice);
                    end;
                }
                field("Vendor No."; Rec."Vendor No.") { ApplicationArea = All; }
                field("Vendor Name"; Rec."Vendor Name") { ApplicationArea = All; }
                field("Currency Code"; Rec."Currency Code") { ApplicationArea = All; }
                field("Invoice Amount"; Rec."Invoice Amount") { ApplicationArea = All; }
                field("Invoice USD"; Rec."Invoice USD") { ApplicationArea = All; }
                field("Allocated Cost USD"; Rec."Allocated Cost USD") { ApplicationArea = All; }
                field("Matched Item Line Count"; Rec."Matched Item Line Count") { ApplicationArea = All; }
                field("Payment Terms Code"; Rec."Payment Terms Code") { ApplicationArea = All; }
                field("Cash Paid Amount"; Rec."Cash Paid Amount") { ApplicationArea = All; }
                field("Last Payment Date"; Rec."Last Payment Date") { ApplicationArea = All; }
                field("Remaining Amount"; Rec."Remaining Amount") { ApplicationArea = All; }
                field("Cash Paid"; Rec."Cash Paid") { ApplicationArea = All; }
                field("Match Source"; Rec."Match Source") { ApplicationArea = All; }
                field("Review Note"; Rec."Review Note") { ApplicationArea = All; }
                field("As Of Date"; Rec."As Of Date") { ApplicationArea = All; }
            }
        }
    }
}
