tableextension 90424 "APSS Comm Vendor" extends Vendor
{
    fields
    {
        field(90424; "APSS Comm Transport Vendor"; Boolean)
        {
            Caption = 'Transport Vendor for Commission';
            DataClassification = CustomerContent;
            ToolTip = 'Exclude this vendor from goods supplier matching and supplier-payment eligibility. Posted freight costs remain included in accounting Bill USD.';
        }
    }
}
