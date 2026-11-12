codeunit 90422 "APSS Commission Suppliers"
{
    // Item-level, conservative purchase-cost allocation.
    // Evidence priority: explicit PO/PO-line reference > Analysis No. + Item +
    // Variant + unambiguous base quantity. No item-only global search.

    procedure Collect(var Commission: Record "APSS Commission Calculation"; AsOfDate: Date)
    var
        SalesInvLine: Record "Sales Invoice Line";
        Detail: Record "APSS Commission Purchase";
        Allocation: Record "APSS Commission Allocation";
        CommissionMgt: Codeunit "APSS Commission Mgt.";
        ItemLineCount: Integer;
        UnmatchedCount: Integer;
        TotalAllocatedUSD: Decimal;
        LatestSupplierPayment: Date;
        AllMatchedInvoicesPaid: Boolean;
        FirstProblem: Text[250];
        Problem: Text[250];
    begin
        if Commission.Status = Commission.Status::Approved then
            Error('Cannot recollect suppliers for an approved commission.');

        // Prevent two concurrent collections from reserving the same PI line.
        Allocation.LockTable();
        Allocation.SetRange("Commission Entry No.", Commission."Entry No.");
        Allocation.DeleteAll();
        Detail.SetRange("Commission Entry No.", Commission."Entry No.");
        Detail.DeleteAll();
        ClearSupplierDisplay(Commission);

        if Commission."Our Ref" = '' then begin
            Commission."Supplier Collection Note" := 'Missing sales invoice number (Our Ref).';
            CommissionMgt.CalculateAdvanceAndCommission(Commission);
            exit;
        end;

        SalesInvLine.SetRange("Document No.", Commission."Our Ref");
        SalesInvLine.SetRange(Type, SalesInvLine.Type::Item);
        if SalesInvLine.FindSet() then
            repeat
                ItemLineCount += 1;
                CollectRelatedInvoices(Commission, SalesInvLine, AsOfDate);
                Clear(Problem);
                if not MatchAndAllocateLine(Commission, SalesInvLine, AsOfDate, Problem) then begin
                    UnmatchedCount += 1;
                    if FirstProblem = '' then
                        FirstProblem := CopyStr(StrSubstNo('%1 line %2: %3', SalesInvLine."No.", SalesInvLine."Line No.", Problem), 1, 250);
                end;
            until SalesInvLine.Next() = 0;

        Commission."Unmatched Item Lines" := UnmatchedCount;
        Commission."Supplier Match Complete" := (ItemLineCount > 0) and (UnmatchedCount = 0);
        Detail.Reset();
        Detail.SetRange("Commission Entry No.", Commission."Entry No.");
        Commission."Supplier Document Count" := Detail.Count();
        AllMatchedInvoicesPaid := (Commission."Supplier Document Count" > 0);
        if Detail.FindSet() then
            repeat
                TotalAllocatedUSD += Detail."Allocated Cost USD";
                if Detail."Matched Item Line Count" = 0 then begin
                    Commission."Supplier Match Complete" := false;
                    if FirstProblem = '' then
                        FirstProblem := CopyStr(StrSubstNo('Related purchase invoice %1 has no confirmed item allocation.', Detail."Purchase Invoice No."), 1, 250);
                end;
                if not Detail."Cash Paid" then
                    AllMatchedInvoicesPaid := false;
                if Detail."Last Payment Date" > LatestSupplierPayment then
                    LatestSupplierPayment := Detail."Last Payment Date";
                AddVendorDisplay(Commission, Detail);
            until Detail.Next() = 0;

        Commission."Matched Supplier Total USD" := TotalAllocatedUSD;
        // Allocated PI cost is a reconciliation figure only. AccountingMgt
        // writes Bill USD after supplier collection, including freight.

        // 'Suppliers Paid' is only true if every sales item is confidently linked
        // and every linked purchase invoice is cash-settled through AsOfDate.
        Commission."Suppliers Paid" := Commission."Supplier Match Complete" and AllMatchedInvoicesPaid;
        if Commission."Suppliers Paid" then
            Commission."Supplier Payment Date" := LatestSupplierPayment;

        if ItemLineCount = 0 then
            Commission."Supplier Collection Note" := 'No positive-quantity item lines on this sales invoice. Cost mapping needs manual review.'
        else
            if Commission."Supplier Match Complete" then
                Commission."Supplier Collection Note" := CopyStr(
                    StrSubstNo('%1 item line(s) allocated to %2 purchase invoice(s). Goods costs matched; accounting Bill is calculated separately. %3',
                        ItemLineCount, Commission."Supplier Document Count", GetPaymentNote(Commission."Suppliers Paid")), 1, 250)
            else
                Commission."Supplier Collection Note" := CopyStr(
                    StrSubstNo('%1 related purchase invoice(s) collected; matching needs review. Accounting Bill is calculated separately. %2',
                        Commission."Supplier Document Count", FirstProblem), 1, 250);

        CommissionMgt.CalculateAdvanceAndCommission(Commission);
    end;

    local procedure CollectRelatedInvoices(Commission: Record "APSS Commission Calculation"; SalesInvLine: Record "Sales Invoice Line"; AsOfDate: Date)
    var
        Candidate: Record "Purch. Inv. Line" temporary;
        PurchaseHeader: Record "Purch. Inv. Header";
        ExplicitLinkFound: Boolean;
    begin
        if SalesInvLine."Quantity (Base)" <= 0 then
            exit;
        // Discovery is independent of allocation. A PO link must not hide a
        // second vendor invoice carrying the same analysis and sales item.
        ExplicitLinkFound := FindExplicitPOCandidates(SalesInvLine, AsOfDate, Candidate);
        if Commission."Analysis No." <> '' then
            FindAnalysisCandidates(Commission."Analysis No.", SalesInvLine, AsOfDate, Candidate);
        Candidate.Reset();
        if Candidate.FindSet() then
            repeat
                PurchaseHeader.Get(Candidate."Document No.");
                AddOrUpdatePurchaseDetail(Commission, PurchaseHeader, AsOfDate, 'Related PO/analysis + item; review allocation', 0, 0);
            until Candidate.Next() = 0;
    end;

    local procedure MatchAndAllocateLine(Commission: Record "APSS Commission Calculation"; SalesInvLine: Record "Sales Invoice Line"; AsOfDate: Date; var Problem: Text[250]): Boolean
    var
        Candidate: Record "Purch. Inv. Line" temporary;
        PurchaseHeader: Record "Purch. Inv. Header";
        VendorEntry: Record "Vendor Ledger Entry";
        IsExplicitLink: Boolean;
        CandidateCount: Integer;
        AvailableQty: Decimal;
        TotalAvailableQty: Decimal;
        SalesQty: Decimal;
        RemainingQty: Decimal;
        QuantityToAllocate: Decimal;
        CurrencyFactor: Decimal;
        AllocatedCostUSD: Decimal;
        SourceLabel: Text[50];
    begin
        SalesQty := SalesInvLine."Quantity (Base)";
        if SalesQty <= 0 then begin
            Problem := 'Zero or negative base quantity.';
            exit(false);
        end;

        IsExplicitLink := FindExplicitPOCandidates(SalesInvLine, AsOfDate, Candidate);
        if IsExplicitLink then
            SourceLabel := 'Shipment/PO line + Item'
        else begin
            if Commission."Analysis No." = '' then begin
                Problem := 'No Analysis No. and no explicit PO link.';
                exit(false);
            end;
            SourceLabel := 'Analysis + Item + Qty';
            FindAnalysisCandidates(Commission."Analysis No.", SalesInvLine, AsOfDate, Candidate);

            // With only Analysis+Item, repeated item sales cannot be assigned to
            // one invoice deterministically. Do not allocate on guesswork.
            if HasOtherItemSalesLine(Commission, SalesInvLine) then begin
                Problem := 'Item is also invoiced on another line/invoice for the same analysis; requires a PO/receipt allocation link.';
                exit(false);
            end;
        end;

        // A sale can be supplied by more than one PO/vendor. Supplement an
        // insufficient explicit PO match with analysis evidence, but retain
        // the ambiguity checks before assigning any cost.
        if IsExplicitLink and (Commission."Analysis No." <> '') then begin
            Candidate.Reset();
            if Candidate.FindSet() then
                repeat
                    AvailableQty := Candidate."Quantity (Base)" - GetAlreadyAllocatedQty(Candidate);
                    if AvailableQty > 0.00001 then
                        TotalAvailableQty += AvailableQty;
                until Candidate.Next() = 0;
            if TotalAvailableQty < SalesQty - 0.00001 then begin
                if HasOtherItemSalesLine(Commission, SalesInvLine) then begin
                    Problem := 'PO quantity is insufficient and the same item is sold on other lines/invoices. Related invoices collected; allocation needs review.';
                    exit(false);
                end;
                FindAnalysisCandidates(Commission."Analysis No.", SalesInvLine, AsOfDate, Candidate);
                IsExplicitLink := false;
                SourceLabel := 'PO + Analysis + Item + Qty';
            end;
            TotalAvailableQty := 0;
        end;

        Candidate.Reset();
        if not Candidate.FindSet() then begin
            if IsExplicitLink then
                Problem := 'Linked PO exists but no posted purchase invoice item line was found by cutoff.'
            else
                Problem := 'No posted purchase invoice with matching Analysis No., Item and Variant.';
            exit(false);
        end;

        repeat
            AvailableQty := Candidate."Quantity (Base)" - GetAlreadyAllocatedQty(Candidate);
            if AvailableQty > 0.00001 then begin
                CandidateCount += 1;
                TotalAvailableQty += AvailableQty;
                if not PurchaseHeader.Get(Candidate."Document No.") then begin
                    Problem := 'Purchase invoice header was not found.';
                    exit(false);
                end;
                if not GetCostFactor(PurchaseHeader, VendorEntry, CurrencyFactor) then begin
                    Problem := CopyStr(StrSubstNo('Cannot verify USD exchange conversion or vendor ledger entry for PI %1.', PurchaseHeader."No."), 1, 250);
                    exit(false);
                end;
            end;
        until Candidate.Next() = 0;

        if CandidateCount = 0 then begin
            Problem := 'All candidate purchase invoice quantities were already allocated elsewhere.';
            exit(false);
        end;
        if TotalAvailableQty < SalesQty - 0.00001 then begin
            Problem := CopyStr(StrSubstNo('Insufficient unmatched purchase quantity: sale %1, available %2.', SalesQty, TotalAvailableQty), 1, 250);
            exit(false);
        end;
        if (TotalAvailableQty > SalesQty + 0.00001) and
           ((not IsExplicitLink) or (CandidateCount > 1)) then begin
            Problem := 'Purchase quantities exceed this sale. Multiple candidate lines cannot be apportioned reliably without an explicit receipt allocation.';
            exit(false);
        end;

        RemainingQty := SalesQty;
        Candidate.FindSet();
        repeat
            AvailableQty := Candidate."Quantity (Base)" - GetAlreadyAllocatedQty(Candidate);
            if (AvailableQty > 0.00001) and (RemainingQty > 0.00001) then begin
                QuantityToAllocate := AvailableQty;
                if QuantityToAllocate > RemainingQty then
                    QuantityToAllocate := RemainingQty;
                PurchaseHeader.Get(Candidate."Document No.");
                if not GetCostFactor(PurchaseHeader, VendorEntry, CurrencyFactor) then
                    Error('USD conversion changed while allocating invoice %1.', PurchaseHeader."No.");
                AllocatedCostUSD := Round(
                    Candidate.Amount * QuantityToAllocate / Candidate."Quantity (Base)" * CurrencyFactor, 0.01);
                InsertAllocation(Commission, SalesInvLine, Candidate, QuantityToAllocate, AllocatedCostUSD, SourceLabel);
                AddOrUpdatePurchaseDetail(Commission, PurchaseHeader, AsOfDate, SourceLabel, QuantityToAllocate, AllocatedCostUSD);
                RemainingQty -= QuantityToAllocate;
            end;
        until (Candidate.Next() = 0) or (RemainingQty <= 0.00001);
        if RemainingQty > 0.00001 then
            Error('Allocation quantity changed during collection for %1 line %2.', SalesInvLine."Document No.", SalesInvLine."Line No.");
        exit(true);
    end;

    local procedure FindExplicitPOCandidates(SalesInvLine: Record "Sales Invoice Line"; AsOfDate: Date; var Candidate: Record "Purch. Inv. Line" temporary): Boolean
    var
        SalesShipmentLine: Record "Sales Shipment Line";
        SalesOrderLine: Record "Sales Line";
        PurchaseLine: Record "Purch. Inv. Line";
        PurchaseOrderNo: Code[20];
        PurchaseOrderLineNo: Integer;
    begin
        if (SalesInvLine."Shipment No." <> '') and (SalesInvLine."Shipment Line No." <> 0) then
            if SalesShipmentLine.Get(SalesInvLine."Shipment No.", SalesInvLine."Shipment Line No.") then begin
                PurchaseOrderNo := SalesShipmentLine."Purchase Order No.";
                PurchaseOrderLineNo := SalesShipmentLine."Purch. Order Line No.";
            end;

        if (PurchaseOrderNo = '') and (SalesInvLine."Order No." <> '') and (SalesInvLine."Order Line No." <> 0) then
            if SalesOrderLine.Get(SalesOrderLine."Document Type"::Order, SalesInvLine."Order No.", SalesInvLine."Order Line No.") then begin
                PurchaseOrderNo := SalesOrderLine."Purchase Order No.";
                PurchaseOrderLineNo := SalesOrderLine."Purch. Order Line No.";
                if PurchaseOrderNo = '' then begin
                    PurchaseOrderNo := SalesOrderLine."Special Order Purchase No.";
                    PurchaseOrderLineNo := SalesOrderLine."Special Order Purch. Line No.";
                end;
            end;

        if PurchaseOrderNo = '' then
            exit(false);

        PurchaseLine.SetRange("Order No.", PurchaseOrderNo);
        if PurchaseOrderLineNo <> 0 then
            PurchaseLine.SetRange("Order Line No.", PurchaseOrderLineNo);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetRange("No.", SalesInvLine."No.");
        PurchaseLine.SetRange("Variant Code", SalesInvLine."Variant Code");
        if PurchaseLine.FindSet() then
            repeat
                AddCandidate(PurchaseLine, AsOfDate, Candidate);
            until PurchaseLine.Next() = 0;
        exit(true);
    end;

    local procedure FindAnalysisCandidates(AnalysisNo: Code[50]; SalesInvLine: Record "Sales Invoice Line"; AsOfDate: Date; var Candidate: Record "Purch. Inv. Line" temporary)
    var
        PurchaseHeader: Record "Purch. Inv. Header";
        PurchaseLine: Record "Purch. Inv. Line";
        HeaderRef: RecordRef;
        LineRef: RecordRef;
    begin
        HeaderRef.GetTable(PurchaseHeader);
        if SetAnalysisFilter(HeaderRef, AnalysisNo) then
            if HeaderRef.FindSet() then
                repeat
                    HeaderRef.SetTable(PurchaseHeader);
                    PurchaseLine.Reset();
                    PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                    PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
                    PurchaseLine.SetRange("No.", SalesInvLine."No.");
                    PurchaseLine.SetRange("Variant Code", SalesInvLine."Variant Code");
                    if PurchaseLine.FindSet() then
                        repeat
                            AddCandidate(PurchaseLine, AsOfDate, Candidate);
                        until PurchaseLine.Next() = 0;
                until HeaderRef.Next() = 0;
        HeaderRef.Close();

        // Some APSS/APNS installations keep Analysis No. on purchase lines,
        // not headers. Inspect the actual field name dynamically.
        PurchaseLine.Reset();
        LineRef.GetTable(PurchaseLine);
        if SetAnalysisFilter(LineRef, AnalysisNo) then
            if LineRef.FindSet() then
                repeat
                    LineRef.SetTable(PurchaseLine);
                    if (PurchaseLine.Type = PurchaseLine.Type::Item) and
                       (PurchaseLine."No." = SalesInvLine."No.") and
                       (PurchaseLine."Variant Code" = SalesInvLine."Variant Code") then
                        AddCandidate(PurchaseLine, AsOfDate, Candidate);
                until LineRef.Next() = 0;
        LineRef.Close();
    end;

    local procedure AddCandidate(PurchaseLine: Record "Purch. Inv. Line"; AsOfDate: Date; var Candidate: Record "Purch. Inv. Line" temporary)
    var
        PurchaseHeader: Record "Purch. Inv. Header";
        Vendor: Record Vendor;
    begin
        if PurchaseLine."Quantity (Base)" <= 0 then
            exit;
        if not PurchaseHeader.Get(PurchaseLine."Document No.") then
            exit;
        if (PurchaseHeader."Posting Date" > AsOfDate) or PurchaseHeader.Cancelled then
            exit;
        // Freight/charge-only lines are already excluded by Type::Item filters.
        // Explicitly marked transport vendors are excluded even if item-coded.
        if Vendor.Get(PurchaseHeader."Pay-to Vendor No.") then
            if Vendor."APSS Comm Transport Vendor" then
                exit;
        if Candidate.Get(PurchaseLine."Document No.", PurchaseLine."Line No.") then
            exit;
        Candidate := PurchaseLine;
        Candidate.Insert();
    end;

    local procedure GetAlreadyAllocatedQty(PurchaseLine: Record "Purch. Inv. Line"): Decimal
    var
        Allocation: Record "APSS Commission Allocation";
        Allocated: Decimal;
    begin
        Allocation.SetRange("Purchase Invoice No.", PurchaseLine."Document No.");
        Allocation.SetRange("Purchase Invoice Line No.", PurchaseLine."Line No.");
        if Allocation.FindSet() then
            repeat
                Allocated += Allocation."Allocated Quantity (Base)";
            until Allocation.Next() = 0;
        exit(Allocated);
    end;

    local procedure InsertAllocation(Commission: Record "APSS Commission Calculation"; SalesInvLine: Record "Sales Invoice Line"; PurchaseLine: Record "Purch. Inv. Line"; QuantityBase: Decimal; CostUSD: Decimal; MatchSource: Text[50])
    var
        Allocation: Record "APSS Commission Allocation";
    begin
        Allocation.Init();
        Allocation."Commission Entry No." := Commission."Entry No.";
        Allocation."Sales Invoice No." := SalesInvLine."Document No.";
        Allocation."Sales Invoice Line No." := SalesInvLine."Line No.";
        Allocation."Item No." := SalesInvLine."No.";
        Allocation."Variant Code" := SalesInvLine."Variant Code";
        Allocation."Purchase Invoice No." := PurchaseLine."Document No.";
        Allocation."Purchase Invoice Line No." := PurchaseLine."Line No.";
        Allocation."Purchase Order No." := PurchaseLine."Order No.";
        Allocation."Allocated Quantity (Base)" := QuantityBase;
        Allocation."Allocated Cost USD" := CostUSD;
        Allocation."Match Source" := MatchSource;
        Allocation.Insert();
    end;

    local procedure AddOrUpdatePurchaseDetail(Commission: Record "APSS Commission Calculation"; PurchaseHeader: Record "Purch. Inv. Header"; AsOfDate: Date; MatchSource: Text[50]; QuantityBase: Decimal; AllocatedUSD: Decimal)
    var
        Detail: Record "APSS Commission Purchase";
        VendorEntry: Record "Vendor Ledger Entry";
        Factor: Decimal;
        IsNew: Boolean;
    begin
        IsNew := not Detail.Get(Commission."Entry No.", PurchaseHeader."No.");
        if IsNew then begin
            Detail.Init();
            Detail."Commission Entry No." := Commission."Entry No.";
            Detail."Purchase Invoice No." := PurchaseHeader."No.";
            Detail."Vendor No." := PurchaseHeader."Pay-to Vendor No.";
            Detail."Vendor Name" := PurchaseHeader."Pay-to Name";
            Detail."Currency Code" := PurchaseHeader."Currency Code";
            Detail."Payment Terms Code" := PurchaseHeader."Payment Terms Code";
            Detail."Match Source" := MatchSource;
            Detail."As Of Date" := AsOfDate;
            Detail."Review Note" := 'Related goods invoice found. No cost allocated yet; verify the link to this sale. Accounting Bill is calculated separately.';
            PurchaseHeader.CalcFields(Amount);
            Detail."Invoice Amount" := PurchaseHeader.Amount;
            if GetCostFactor(PurchaseHeader, VendorEntry, Factor) then begin
                Detail."Vendor Ledger Entry No." := VendorEntry."Entry No.";
                Detail."Invoice USD" := Round(PurchaseHeader.Amount * Factor, 0.01);
                VendorEntry.SetFilter("Date Filter", '..%1', AsOfDate);
                VendorEntry.CalcFields("Remaining Amount");
                Detail."Remaining Amount" := Abs(VendorEntry."Remaining Amount");
                ReadPayments(VendorEntry, AsOfDate, Detail);
            end;
        end;
        Detail."Allocated Quantity (Base)" += QuantityBase;
        Detail."Allocated Cost USD" += AllocatedUSD;
        if QuantityBase > 0 then begin
            Detail."Matched Item Line Count" += 1;
            Detail."Match Source" := MatchSource;
            Detail."Review Note" := 'Item allocation confirmed for this invoice. Full invoice amount can differ from the portion assigned to this sale. Accounting Bill already includes freight.';
        end;
        if IsNew then
            Detail.Insert()
        else
            Detail.Modify();
    end;

    local procedure GetCostFactor(PurchaseHeader: Record "Purch. Inv. Header"; var VendorEntry: Record "Vendor Ledger Entry"; var Factor: Decimal): Boolean
    begin
        Factor := 0;
        if not FindVendorEntry(PurchaseHeader, VendorEntry) then
            exit(false);
        VendorEntry.CalcFields("Original Amount", "Original Amt. (LCY)");
        if VendorEntry."Original Amount" = 0 then
            exit(false);
        // This extension is for the APSS company whose LCY is USD.
        // Use the posted invoice ledger's original LCY/document-currency ratio.
        Factor := VendorEntry."Original Amt. (LCY)" / VendorEntry."Original Amount";
        exit(Factor > 0);
    end;

    local procedure FindVendorEntry(PurchaseHeader: Record "Purch. Inv. Header"; var Entry: Record "Vendor Ledger Entry"): Boolean
    begin
        Entry.Reset();
        if PurchaseHeader."Vendor Ledger Entry No." <> 0 then begin
            if not Entry.Get(PurchaseHeader."Vendor Ledger Entry No.") then
                exit(false);
            exit((Entry."Document Type" = Entry."Document Type"::Invoice) and
                 (Entry."Document No." = PurchaseHeader."No.") and
                 (Entry."Vendor No." = PurchaseHeader."Pay-to Vendor No."));
        end;
        Entry.SetRange("Document Type", Entry."Document Type"::Invoice);
        Entry.SetRange("Document No.", PurchaseHeader."No.");
        Entry.SetRange("Vendor No.", PurchaseHeader."Pay-to Vendor No.");
        if Entry.Count() <> 1 then
            exit(false);
        exit(Entry.FindFirst());
    end;

    local procedure ReadPayments(Entry: Record "Vendor Ledger Entry"; AsOfDate: Date; var Detail: Record "APSS Commission Purchase")
    var
        Application: Record "Detailed Vendor Ledg. Entry";
        Payment: Record "Vendor Ledger Entry";
    begin
        Entry.CalcFields("Original Amount", "Remaining Amount");
        Application.SetRange("Vendor Ledger Entry No.", Entry."Entry No.");
        Application.SetRange("Entry Type", Application."Entry Type"::Application);
        Application.SetRange(Unapplied, false);
        Application.SetFilter("Posting Date", '..%1', AsOfDate);
        if Application.FindSet() then
            repeat
                if Application."Applied Vend. Ledger Entry No." <> Entry."Entry No." then
                    if Payment.Get(Application."Applied Vend. Ledger Entry No.") then
                        if (Payment."Document Type" = Payment."Document Type"::Payment) and
                           (Payment."Vendor No." = Entry."Vendor No.") and
                           (Payment."Posting Date" <= AsOfDate) and (Application.Amount > 0) then begin
                            Detail."Cash Paid Amount" += Application.Amount;
                            if Payment."Posting Date" > Detail."Last Payment Date" then
                                Detail."Last Payment Date" := Payment."Posting Date";
                        end;
            until Application.Next() = 0;
        Detail."Cash Paid" := (Abs(Entry."Remaining Amount") <= 0.01) and
            (Abs(Entry."Original Amount") > 0.01) and
            (Detail."Cash Paid Amount" >= Abs(Entry."Original Amount") - 0.01) and
            (Detail."Last Payment Date" <> 0D);
    end;

    local procedure HasOtherItemSalesLine(Commission: Record "APSS Commission Calculation"; CurrentLine: Record "Sales Invoice Line"): Boolean
    var
        OtherLine: Record "Sales Invoice Line";
        OtherHeader: Record "Sales Invoice Header";
    begin
        OtherLine.SetRange(Type, OtherLine.Type::Item);
        OtherLine.SetRange("No.", CurrentLine."No.");
        OtherLine.SetRange("Variant Code", CurrentLine."Variant Code");
        OtherLine.SetFilter("Quantity (Base)", '>%1', 0);
        if OtherLine.FindSet() then
            repeat
                if (OtherLine."Document No." = CurrentLine."Document No.") and
                   (OtherLine."Line No." <> CurrentLine."Line No.") then
                    exit(true);
                if OtherLine."Document No." <> CurrentLine."Document No." then
                    if OtherHeader.Get(OtherLine."Document No.") then
                        if ResolveSalesAnalysis(OtherHeader) = Commission."Analysis No." then
                            exit(true);
            until OtherLine.Next() = 0;
        exit(false);
    end;

    local procedure ResolveSalesAnalysis(Header: Record "Sales Invoice Header"): Code[50]
    var
        Ref: RecordRef;
        Fld: FieldRef;
        Index: Integer;
    begin
        Ref.GetTable(Header);
        for Index := 1 to Ref.FieldCount do begin
            Fld := Ref.FieldIndex(Index);
            if (Fld.Name = 'APSS Analysis No.') and (Format(Fld.Value) <> '') then
                exit(CopyStr(Format(Fld.Value), 1, 50));
        end;
        for Index := 1 to Ref.FieldCount do begin
            Fld := Ref.FieldIndex(Index);
            if ((Fld.Name = 'Analysis No.') or (Fld.Name = 'Analysis No')) and (Format(Fld.Value) <> '') then
                exit(CopyStr(Format(Fld.Value), 1, 50));
        end;
        exit(CopyStr(Header."Opportunity No.", 1, 50));
    end;

    local procedure SetAnalysisFilter(var Ref: RecordRef; AnalysisNo: Code[50]): Boolean
    var
        Fld: FieldRef;
        Index: Integer;
    begin
        // APSS posted purchase header extension: field 50001 (where installed).
        if Ref.Number = Database::"Purch. Inv. Header" then
            if Ref.FieldExist(50001) then begin
                Fld := Ref.Field(50001);
                if (Fld.Name = 'APSS Analysis No.') and (Fld.Type = FieldType::Code) then begin
                    Fld.SetRange(AnalysisNo);
                    exit(true);
                end;
            end;
        for Index := 1 to Ref.FieldCount do begin
            Fld := Ref.FieldIndex(Index);
            if (Fld.Name = 'APSS Analysis No.') or
               (Fld.Name = 'Analysis No.') or (Fld.Name = 'Analysis No') then
                if (Fld.Type = FieldType::Code) or (Fld.Type = FieldType::Text) then begin
                    Fld.SetRange(AnalysisNo);
                    exit(true);
                end;
        end;
        exit(false);
    end;

    local procedure AddVendorDisplay(var Commission: Record "APSS Commission Calculation"; Detail: Record "APSS Commission Purchase")
    begin
        // Display distinct vendors; one vendor can have multiple PI documents.
        if (Commission."Supplier 1" = '') or (Commission."Supplier 1" = Detail."Vendor No.") then begin
            Commission."Supplier 1" := Detail."Vendor No.";
            Commission."Supplier 1 Name" := Detail."Vendor Name";
            Commission."Supplier 1 Invoice Amount" += Detail."Allocated Cost USD";
            if Detail."Last Payment Date" > Commission."Supplier 1 Payment Date" then
                Commission."Supplier 1 Payment Date" := Detail."Last Payment Date";
            exit;
        end;
        if (Commission."Supplier 2" = '') or (Commission."Supplier 2" = Detail."Vendor No.") then begin
            Commission."Supplier 2" := Detail."Vendor No.";
            Commission."Supplier 2 Name" := Detail."Vendor Name";
            Commission."Supplier 2 Invoice Amount" += Detail."Allocated Cost USD";
            if Detail."Last Payment Date" > Commission."Supplier 2 Payment Date" then
                Commission."Supplier 2 Payment Date" := Detail."Last Payment Date";
            exit;
        end;
        if (Commission."Supplier 3" = '') or (Commission."Supplier 3" = Detail."Vendor No.") then begin
            Commission."Supplier 3" := Detail."Vendor No.";
            Commission."Supplier 3 Name" := Detail."Vendor Name";
            Commission."Supplier 3 Invoice Amount" += Detail."Allocated Cost USD";
            if Detail."Last Payment Date" > Commission."Supplier 3 Payment Date" then
                Commission."Supplier 3 Payment Date" := Detail."Last Payment Date";
        end;
        // Additional vendors remain visible in the unbounded Purchases FactBox.
    end;

    local procedure GetPaymentNote(SuppliersPaid: Boolean): Text[60]
    begin
        if SuppliersPaid then
            exit('All matched PIs cash-settled by cutoff; review required.');
        exit('Supplier payments incomplete; review required.');
    end;

    local procedure ClearSupplierDisplay(var Commission: Record "APSS Commission Calculation")
    begin
        Clear(Commission."Supplier 1");
        Clear(Commission."Supplier 1 Name");
        Clear(Commission."Supplier 1 Invoice Amount");
        Clear(Commission."Supplier 1 Payment Date");
        Clear(Commission."Supplier 2");
        Clear(Commission."Supplier 2 Name");
        Clear(Commission."Supplier 2 Invoice Amount");
        Clear(Commission."Supplier 2 Payment Date");
        Clear(Commission."Supplier 3");
        Clear(Commission."Supplier 3 Name");
        Clear(Commission."Supplier 3 Invoice Amount");
        Clear(Commission."Supplier 3 Payment Date");
        Commission."Supplier Payment Date" := 0D;
        Commission."Supplier Document Count" := 0;
        Commission."Matched Supplier Total USD" := 0;
        Commission."Bill (USD)" := 0;
        Commission."Supplier Match Complete" := false;
        Commission."Unmatched Item Lines" := 0;
        Commission."Cost Inputs Reviewed" := false;
        Commission."Suppliers Paid" := false;
    end;
}
