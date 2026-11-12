page 90423 "APSS Commission Allocations"
{
    Caption = 'Matched Purchase Item Lines';
    PageType = ListPart;
    SourceTable = "APSS Commission Allocation";
    Editable = false;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            repeater(MatchedLines)
            {
                field("Sales Invoice Line No."; Rec."Sales Invoice Line No.") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Purchase Invoice No."; Rec."Purchase Invoice No.")
                {
                    ApplicationArea = All;
                    DrillDown = true;
                    trigger OnDrillDown()
                    var
                        Invoice: Record "Purch. Inv. Header";
                    begin
                        if Invoice.Get(Rec."Purchase Invoice No.") then begin
                            Invoice.SetRecFilter();
                            Page.RunModal(Page::"Posted Purchase Invoice", Invoice);
                        end;
                    end;
                }
                field("Purchase Invoice Line No."; Rec."Purchase Invoice Line No.") { ApplicationArea = All; }
                field("Purchase Order No."; Rec."Purchase Order No.") { ApplicationArea = All; }
                field("Allocated Cost USD"; Rec."Allocated Cost USD") { ApplicationArea = All; }
                field("Match Source"; Rec."Match Source") { ApplicationArea = All; }
            }
        }
    }
}
