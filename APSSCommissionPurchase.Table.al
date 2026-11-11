table 90422 "APSS Commission Purchase"
{
    Caption = 'Commission Purchase Invoice';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Commission Entry No."; Integer) { TableRelation = "APSS Commission Calculation"."Entry No."; }
        field(2; "Purchase Invoice No."; Code[20]) { Caption = 'Purchase Invoice No.'; }
        field(3; "Vendor No."; Code[20]) { Caption = 'Supplier No.'; }
        field(4; "Vendor Name"; Text[100]) { Caption = 'Supplier Name'; }
        field(5; "Currency Code"; Code[10]) { Caption = 'Currency'; }
        field(6; "Invoice Amount"; Decimal) { Caption = 'Full Invoice Amount'; DecimalPlaces = 2 : 2; }
        field(7; "Invoice USD"; Decimal) { Caption = 'Full Invoice USD'; DecimalPlaces = 2 : 2; }
        field(8; "Remaining Amount"; Decimal) { Caption = 'Remaining Amount'; DecimalPlaces = 2 : 2; }
        field(9; "Last Payment Date"; Date) { Caption = 'Last Supplier Payment'; }
        field(10; "Cash Paid Amount"; Decimal) { Caption = 'Applied Cash (Invoice Currency)'; DecimalPlaces = 2 : 2; }
        field(11; "Cash Paid"; Boolean) { Caption = 'Full Cash Verified'; }
        field(12; "Payment Terms Code"; Code[10]) { Caption = 'Payment Terms'; }
        field(13; "Vendor Ledger Entry No."; Integer) { Caption = 'Vendor Ledger Entry No.'; }
        field(14; "Match Source"; Text[50]) { Caption = 'Match Source'; }
        field(15; "Review Note"; Text[250]) { Caption = 'Review Note'; }
        field(16; "As Of Date"; Date) { Caption = 'Checked Through'; }
        field(17; "Allocated Quantity (Base)"; Decimal) { Caption = 'Allocated Item Quantity (Base)'; DecimalPlaces = 0 : 5; }
        field(18; "Allocated Cost USD"; Decimal) { Caption = 'Allocated Cost (USD)'; DecimalPlaces = 2 : 2; }
        field(19; "Matched Item Line Count"; Integer) { Caption = 'Matched Item Lines'; }
    }
    keys
    {
        key(PK; "Commission Entry No.", "Purchase Invoice No.") { Clustered = true; }
    }
}
