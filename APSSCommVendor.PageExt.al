pageextension 90424 "APSS Comm Vendor Card" extends "Vendor Card"
{
    layout
    {
        addlast(General)
        {
            field("APSS Comm Transport Vendor"; Rec."APSS Comm Transport Vendor")
            {
                ApplicationArea = All;
            }
        }
    }
}
