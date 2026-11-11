codeunit 90424 "APSS Commission Accounting"
{
    // Derived from APSS report 50047. Unlike its reporting-period filter,
    // commission costs are cumulative through the payout cutoff because the
    // selected receipt may settle an older invoice. Amounts are LCY = USD.
    procedure ApplyAmounts(var Commission: Record "APSS Commission Calculation"; Invoice: Record "Sales Invoice Header"; Cutoff: Date)
    var
        GLSetup: Record "General Ledger Setup";
        GLE: Record "G/L Entry";
        Relation: Record "G/L - Item Ledger Relation";
        VE: Record "Value Entry";
        InvoiceVE: Record "Value Entry";
        ChargeVE: Record "Value Entry";
        Outbound: Record "Item Ledger Entry" temporary;
        ILE: Record "Item Ledger Entry";
        Revenue: Decimal;
        BaseCost: Decimal;
        Freight: Decimal;
        Portion: Decimal;
        RevenueFound: Boolean;
        CostFound: Boolean;
        Incomplete: Boolean;
    begin
        GLSetup.Get();
        if GLSetup."LCY Code" <> 'USD' then
            Error('Accounting amounts require LCY USD. Current LCY: %1.', GLSetup."LCY Code");
        Commission."Accounting Cost Complete" := false;
        Commission."Cost Checked Through" := Cutoff;
        Commission."Invoice (USD)" := 0;
        Commission."Exchange Rate" := 0;
        Commission."Bill (USD)" := 0;
        Commission."Freight Charge" := 0;

        GLE.SetRange("Document No.", Invoice."No.");
        GLE.SetRange("Posting Date", Invoice."Posting Date");
        GLE.SetFilter("G/L Account No.", '6000..6999');
        if Invoice."Posting Date" <= Cutoff then
            if GLE.FindSet() then
                repeat
                    RevenueFound := true;
                    Revenue -= GLE.Amount;
                until GLE.Next() = 0;
        GLE.Reset();
        GLE.SetRange("Document No.", Invoice."No.");
        GLE.SetFilter("Posting Date", '..%1', Cutoff);
        GLE.SetFilter("G/L Account No.", '7000..7999');
        if GLE.FindSet() then
            repeat
                CostFound := true;
                BaseCost += GLE.Amount;
                Relation.Reset();
                Relation.SetRange("G/L Entry No.", GLE."Entry No.");
                if Relation.FindSet() then
                    repeat
                        if VE.Get(Relation."Value Entry No.") then
                            if ILE.Get(VE."Item Ledger Entry No.") then
                                if not Outbound.Get(ILE."Entry No.") then begin
                                    // The original report takes the first non-adjustment
                                    // invoice value entry's valued quantity per ILE.
                                    InvoiceVE.Reset();
                                    InvoiceVE.SetRange("Item Ledger Entry No.", ILE."Entry No.");
                                    InvoiceVE.SetRange("Document No.", Invoice."No.");
                                    InvoiceVE.SetRange(Adjustment, false);
                                    InvoiceVE.SetFilter("Posting Date", '..%1', Cutoff);
                                    if InvoiceVE.FindFirst() then begin
                                        Outbound := ILE;
                                        Outbound.Quantity := InvoiceVE."Valued Quantity";
                                        Outbound.Insert();
                                    end else
                                        Incomplete := true;
                                end;
                    until Relation.Next() = 0;
            until GLE.Next() = 0;

        Outbound.Reset();
        if Outbound.FindSet() then
            repeat
                ChargeVE.Reset();
                ChargeVE.SetRange("Item Ledger Entry No.", Outbound."Entry No.");
                ChargeVE.SetFilter("Item Charge No.", '<>%1', '');
                ChargeVE.SetFilter("Posting Date", '..%1', Cutoff);
                if ChargeVE.FindSet() then
                    repeat
                        // Add only non-inventoriable cost not already in BaseCost.
                        // Inventoriable charges remain part of the G/L cost.
                        if ChargeVE."Cost Amount (Non-Invtbl.)" <> 0 then
                            if ChargeVE."Valued Quantity" = 0 then
                                Incomplete := true
                            else
                                if not ChargeAlreadyInBase(ChargeVE."Entry No.", Invoice."No.", Cutoff) then begin
                                    Portion := -ChargeVE."Cost Amount (Non-Invtbl.)" /
                                                ChargeVE."Valued Quantity" * Outbound.Quantity;
                                    Freight += Portion;
                                end;
                    until ChargeVE.Next() = 0;
            until Outbound.Next() = 0;

        Commission."Invoice (USD)" := Round(Revenue, 0.01);
        Commission."Freight Charge" := Round(Freight, 0.01); // Informational component only.
        Commission."Bill (USD)" := Round(BaseCost + Freight, 0.01);
        if Commission."Invoice (USD)" <> 0 then
            Commission."Exchange Rate" := Commission.Amount / Commission."Invoice (USD)";
        Commission."Accounting Cost Complete" := RevenueFound and CostFound and not Incomplete;
        if not RevenueFound then
            Commission."Accounting Cost Note" := 'No sales G/L entries on accounts 6000..6999 for this invoice/posting date. Verify account setup.'
        else
            if not CostFound then
                Commission."Accounting Cost Note" := 'No cost G/L entries on accounts 7000..7999 for this sales invoice through cutoff. Profit blocked for review.'
            else
                if Incomplete then
                    Commission."Accounting Cost Note" := 'Accounting entries found, but item/value entry quantity mapping is incomplete. Profit blocked for review.'
                else
                    Commission."Accounting Cost Note" := 'Posted G/L revenue and cumulative G/L cost plus outbound non-inventoriable item charges. Bill includes freight; no second freight deduction.';
    end;

    local procedure ChargeAlreadyInBase(ValueEntryNo: Integer; SalesInvoiceNo: Code[20]; Cutoff: Date): Boolean
    var
        Relation: Record "G/L - Item Ledger Relation";
        GLE: Record "G/L Entry";
    begin
        Relation.SetRange("Value Entry No.", ValueEntryNo);
        if Relation.FindSet() then
            repeat
                if GLE.Get(Relation."G/L Entry No.") then
                    if (GLE."Document No." = SalesInvoiceNo) and
                       (GLE."Posting Date" <= Cutoff) and
                       (GLE."G/L Account No." >= '7000') and (GLE."G/L Account No." <= '7999') then
                        exit(true);
            until Relation.Next() = 0;
        exit(false);
    end;
}
