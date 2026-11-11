enum 90420 "APSS Commission Type"
{
    Extensible = true;

    value(0; Invoice)
    {
        Caption = 'Invoice';
    }
}

enum 90421 "APSS Commission Status"
{
    Extensible = true;

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; Eligible)
    {
        Caption = 'Eligible';
    }
    value(2; "Pending Supplier Payment")
    {
        Caption = 'Pending Supplier Payment';
    }
    value(3; "Pending Customer Payment")
    {
        Caption = 'Pending Customer Payment';
    }
    value(4; "Review Required")
    {
        Caption = 'Review Required';
    }
    value(5; Approved)
    {
        Caption = 'Approved';
    }
}
