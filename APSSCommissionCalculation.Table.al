table 90420 "APSS Commission Calculation"
{
    Caption = 'APSS Commission Calculation';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Commission Month"; Date)
        {
            Caption = 'Commission Month';
            ToolTip = 'Specifies the first day of the month for which commission is calculated.';
        }
        field(3; Type; Enum "APSS Commission Type")
        {
            Caption = 'Type';
        }
        field(4; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer."No.";
        }
        field(5; "Customer Name"; Text[100])
        {
            Caption = 'Customer Name';
        }
        field(6; "Salesperson Code"; Code[20])
        {
            Caption = 'Salesperson Code';
            TableRelation = "Salesperson/Purchaser".Code;
        }
        field(7; "Analysis No."; Code[50])
        {
            Caption = 'Analysis No.';
            ToolTip = 'Groups the sales invoice and all related supplier documents.';
        }
        field(8; "Our Ref"; Code[20])
        {
            Caption = 'Our Ref.';
        }
        field(9; "Their Ref"; Text[50])
        {
            Caption = 'Their Ref.';
        }
        field(10; "Invoice Date"; Date)
        {
            Caption = 'Invoice Date';
        }
        field(11; "Customer Payment Date"; Date)
        {
            Caption = 'Customer Payment Date';
        }
        field(12; "Currency Code"; Code[10])
        {
            Caption = 'Currency';
            TableRelation = Currency.Code;
        }
        field(13; Amount; Decimal)
        {
            Caption = 'Amount';
            DecimalPlaces = 0 : 2;
        }
        field(14; "Exchange Rate"; Decimal)
        {
            Caption = 'xRate';
            DecimalPlaces = 0 : 6;
        }
        field(15; "Invoice (USD)"; Decimal)
        {
            Caption = 'Invoice (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(16; "Bill (USD)"; Decimal)
        {
            Caption = 'Bill (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(17; "Freight Charge"; Decimal)
        {
            Caption = 'Freight Included in Bill (USD)';
            ToolTip = 'Informational only. Bill includes freight; this amount is not subtracted again.';
            DecimalPlaces = 0 : 2;
        }
        field(18; "P/L (%)"; Decimal)
        {
            Caption = 'P/L (%)';
            DecimalPlaces = 0 : 4;
        }
        field(19; "Net P/L (USD)"; Decimal)
        {
            Caption = 'Net P/L (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(20; "Supplier 1"; Code[20])
        {
            Caption = 'Supplier 1';
            TableRelation = Vendor."No.";
        }
        field(21; "Supplier 1 Name"; Text[100])
        {
            Caption = 'Supplier 1 Name';
        }
        field(22; "Supplier 1 Payment Date"; Date)
        {
            Caption = 'Supplier 1 Payment Date';
        }
        field(23; "Supplier 1 Invoice Amount"; Decimal)
        {
            Caption = 'Supplier 1 Allocated Cost (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(24; "Supplier 2"; Code[20])
        {
            Caption = 'Supplier 2';
            TableRelation = Vendor."No.";
        }
        field(25; "Supplier 2 Name"; Text[100])
        {
            Caption = 'Supplier 2 Name';
        }
        field(26; "Supplier 2 Payment Date"; Date)
        {
            Caption = 'Supplier 2 Payment Date';
        }
        field(27; "Supplier 2 Invoice Amount"; Decimal)
        {
            Caption = 'Supplier 2 Allocated Cost (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(28; "Supplier 3"; Code[20])
        {
            Caption = 'Supplier 3';
            TableRelation = Vendor."No.";
        }
        field(29; "Supplier 3 Name"; Text[100])
        {
            Caption = 'Supplier 3 Name';
        }
        field(30; "Supplier 3 Payment Date"; Date)
        {
            Caption = 'Supplier 3 Payment Date';
        }
        field(31; "Supplier 3 Invoice Amount"; Decimal)
        {
            Caption = 'Supplier 3 Allocated Cost (USD)';
            DecimalPlaces = 0 : 2;
        }
        field(32; "Supplier Payment Date"; Date)
        {
            Caption = 'Supplier Payment Date';
            ToolTip = 'The supplier payment date used for the advance-period calculation.';
        }
        field(33; "Advance Months"; Decimal)
        {
            Caption = 'ADV (Months)';
            DecimalPlaces = 0 : 4;
            Editable = false;
        }
        field(34; "Monthly Interest Rate"; Decimal)
        {
            Caption = 'Monthly Interest Rate';
            InitValue = 1;
            DecimalPlaces = 0 : 4;
        }
        field(35; "Deduction (%)"; Decimal)
        {
            Caption = 'Deduction (%)';
            DecimalPlaces = 0 : 4;
            Editable = false;
        }
        field(36; "Commission Rate (%)"; Decimal)
        {
            Caption = 'Commission Rate (%)';
            InitValue = 15;
            DecimalPlaces = 0 : 4;
        }
        field(37; "Actual Commission (%)"; Decimal)
        {
            Caption = '% Commission Actual';
            DecimalPlaces = 0 : 4;
            Editable = false;
        }
        field(38; "Commission Value (USD)"; Decimal)
        {
            Caption = 'Commission Value (USD)';
            DecimalPlaces = 0 : 2;
            Editable = false;
        }
        field(39; "Customer Paid"; Boolean)
        {
            Caption = 'Customer Paid';
        }
        field(40; "Suppliers Paid"; Boolean)
        {
            Caption = 'Suppliers Paid';
        }
        field(41; Eligible; Boolean)
        {
            Caption = 'Eligible';
            Editable = false;
        }
        field(42; Status; Enum "APSS Commission Status")
        {
            Caption = 'Status';
        }
        field(43; "Collection Run Date"; DateTime)
        {
            Caption = 'Collection Run Date';
            Editable = false;
        }
        field(44; "Calculation Note"; Text[250])
        {
            Caption = 'Calculation Note';
        }
        field(45; "Customer Ledger Entry No."; Integer)
        {
            Caption = 'Customer Ledger Entry No.';
            Editable = false;
        }
        field(46; "Cost Inputs Reviewed"; Boolean)
        {
            Caption = 'Reviewed';
            ToolTip = 'Confirms that you have checked this commission row and its sales, supplier, cost and payment information. Recollection clears this confirmation. This is not a posting approval.';
        }
        field(47; "Calculated Commission Preview"; Decimal)
        {
            Caption = 'Commission Preview (USD)';
            DecimalPlaces = 2 : 2;
            Editable = false;
        }

        field(48; "Customer Remaining Amount"; Decimal)
        {
            Caption = 'Customer Remaining Amount';
            DecimalPlaces = 2 : 2;
            Editable = false;
        }

        field(49; "Supplier Collection Note"; Text[250]) { Caption = 'Supplier Collection Note'; Editable = false; }
        field(50; "Supplier Document Count"; Integer) { Caption = 'Supplier Invoice Count'; Editable = false; }
        field(51; "Matched Supplier Total USD"; Decimal) { Caption = 'Allocated Item Cost (USD)'; DecimalPlaces = 2 : 2; Editable = false; }
        field(52; "Supplier Match Complete"; Boolean)
        {
            Caption = 'Supplier Item Match Complete';
            Editable = false;
            ToolTip = 'All positive item lines on this posted sales invoice have reliable purchase-line allocations. Still requires finance review for other costs and supplier obligations.';
        }
        field(53; "Unmatched Item Lines"; Integer)
        {
            Caption = 'Unmatched Item Lines';
            Editable = false;
        }

        field(54; "Accounting Cost Complete"; Boolean) { Caption = 'Accounting Amounts Verified'; Editable = false; }
        field(55; "Accounting Cost Note"; Text[250]) { Caption = 'Accounting Amount Note'; Editable = false; }
        field(56; "In Collection Period"; Boolean) { Caption = 'Qualifies for Collection Period'; Editable = false; }
        field(57; "Cost Checked Through"; Date) { Caption = 'Cost Checked Through'; Editable = false; }

    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(CustomerEntry; "Customer Ledger Entry No.") { }
        key(Analysis; "Commission Month", "Analysis No.", "Our Ref")
        {
        }
    }
}
