table 90423 "APSS Commission Allocation"
{
    Caption = 'Commission Purchase Line Allocation';
    DataClassification = CustomerContent;
    fields
    {
        field(1; "Commission Entry No."; Integer) { TableRelation = "APSS Commission Calculation"."Entry No."; }
        field(2; "Sales Invoice No."; Code[20]) { }
        field(3; "Sales Invoice Line No."; Integer) { }
        field(4; "Item No."; Code[20]) { }
        field(5; "Variant Code"; Code[10]) { }
        field(6; "Purchase Invoice No."; Code[20]) { }
        field(7; "Purchase Invoice Line No."; Integer) { }
        field(8; "Purchase Order No."; Code[20]) { }
        field(9; "Allocated Quantity (Base)"; Decimal) { DecimalPlaces = 0 : 5; }
        field(10; "Allocated Cost USD"; Decimal) { DecimalPlaces = 2 : 2; }
        field(11; "Match Source"; Text[50]) { }
    }
    keys
    {
        key(PK; "Commission Entry No.", "Sales Invoice Line No.", "Purchase Invoice No.", "Purchase Invoice Line No.") { Clustered = true; }
        key(PurchaseLine; "Purchase Invoice No.", "Purchase Invoice Line No.") { }
    }
}
