procedure TSSFPatientSalesList_frm.DBGrid1DblClick(Sender: TObject);
var
  s: string;
  str: string;
  selectqry: tquery;
  discharge_check: boolean;
  discharge_no_len: integer;
begin
  selectqry := tquery.Create(nil);
  with selectqry do
  begin
    close;
    databasename := 'dmedipro';
    params.Clear;
    with sql do
    begin
      clear;
      add(' select a.discharge, len(isnull( b.dischargeno,'''')) as dischargeno , a.* ');
      add(' from inpatient a');
      add(' left join');
      add(' discharge b on a.ipdno=b.ipdno');
      add(' where hospid=' + inttostr(query1.FieldByName('hospid').AsInteger) +
           ' and claim_code=' + fillquoted(query1.FieldByName('claim_code').asstring) + ' ');
    end;
    open;
    discharge_check := fieldbyname('discharge').AsBoolean;
    discharge_no_len := fieldbyname('dischargeno').asinteger;
    close;
  end;
  selectqry.Destroy;

  if cboopdipd.ItemIndex = 1 then
  begin
    if discharge_no_len = 0 then
    begin
      showmessage('Discharge not Found');
      exit;
    end;

    if discharge_check = false then
    begin
      showmessage('Inpatient Discharge Pending');
      exit;
    end;
  end;

  if loginfrm.gSINGLE_FILE_UPLOAD = 'YES' then
  begin
    if FileExists(Loginfrm.gImagePath + '\Insurance\Claim\' + query1.FieldByName('claim_code').asstring + '-' +
                  query1.FieldByName('policyid').asstring + '.pdf') = false then
    begin
      str := str + ' select ''Service'' as ty ';
      str := str + ' union all ';
      str := str + ' select ''Item'' as ty  ';

      InsuranceInvoiceDetail_Qrp := tInsuranceInvoiceDetail_Qrp.create(application);
      try
        InsuranceInvoiceDetail_Qrp.company1.caption := gfirmname;
        InsuranceInvoiceDetail_Qrp.address.caption := gaddress;
        InsuranceInvoiceDetail_Qrp.telephone.caption := gtelephone;
        InsuranceInvoiceDetail_Qrp.regno.caption := firmreg(gfirmcode);

        openquery(InsuranceInvoiceDetail_Qrp.query2, str);
        openquery(InsuranceInvoiceDetail_Qrp.query1,
                  ' sp_InsuranceInvoiceDetail ' + fillquoted(query1.fieldbyname('claim_code').asstring) + ', ' +
                  booleantostring(chkssf.checked) + ', :ty ');
        QuickReportToPDF(InsuranceInvoiceDetail_Qrp.QuickRep1,
                         Loginfrm.gImagePath + '\Insurance\Claim\' + query1.FieldByName('claim_code').asstring + '-' +
                         query1.FieldByName('policyid').asstring + '.pdf', false);
      finally
        InsuranceInvoiceDetail_Qrp.release;
      end;
    end;
  end;

  if loginfrm.gSINGLE_FILE_UPLOAD = 'YES' then
  begin
    if FileExists(Loginfrm.gImagePath + '\Insurance\Claim\' + query1.FieldByName('claim_code').asstring + '-' +
                  query1.FieldByName('policyid').asstring + '.pdf') = false then
    begin
      showmessage('Single File Not Found: ' +
                  Loginfrm.gImagePath + '\Insurance\Claim\' + query1.FieldByName('claim_code').asstring + '-' +
                  query1.FieldByName('policyid').asstring + '.pdf');
      exit;
    end;
  end;

  ssf_booking_show := false;
  if chkhib.checked = true then
  begin
    if loginfrm.gInsuranceHIB_API = false then
    begin
      showmessage('HIB API not registered');
      exit;
    end;

    if chkHIBOPD.Checked = true then
    begin

    end
    else
    begin
      if ((cboopdipd.ItemIndex = 0) and (hib_inv_no = '')) then
      begin
        showmessage('Click Below for Invoice-wise Posting');
        exit;
      end;
    end;
  end;

  if chkssf.checked = true then
  begin
    if loginfrm.gInsuranceSSF_API = false then
    begin
      showmessage('SSF API not registered');
      exit;
    end;
    if query1.FieldByName('scheme_product_id').asinteger = 0 then
    begin
      showmessage('Scheme Product Empty');
      exit;
    end;

    if query1.FieldByName('scheme_id').asinteger = 1 then
    begin
      if query1.FieldByName('EmployerId').asstring = '' then
      begin
        showmessage('Accident Case Plz Update Employer Detail');
        exit;
      end;
    end;
  end;

  s := query1.FieldByName('claim_code').asstring;
  if chkssf.Checked = true then
  begin
    if Length(query1.FieldByName('icdcode').asstring) = 0 then
    begin
      showmessage('ICD Code Empty');
      exit;
    end;
  end;

  if chkhib.Checked = true then
  begin
    if Length(query1.FieldByName('icdcode').asstring) = 0 then
    begin
      if ((query3.FieldByName('service').asstring = 'OPD4') or (query3.FieldByName('service').asstring = 'EMRT')) then
      begin

      end
      else
      begin
        showmessage('ICD Code Empty');
        exit;
      end;
    end;
  end;

  if query1.FieldByName('outcome').asstring <> 'rejected' then
  begin
    if query1.FieldByName('ssf_claim_post').AsBoolean = true then
    begin
      showmessage('Already Posted');
      exit;
    end;

    if alreadyfound('dmedipro', 'InsuranceClaimCode', 'ssf_claim_post', 'ssf_claim_post=1 AND claim_code=' +
                    fillquoted(query1.FieldByName('claim_code').asstring)) = true then
    begin
      showmessage('Already Posted');
      exit;
    end;
  end;

  if AlreadyFound('dmedipro', 'ssf_patient', 'ssf_identity', 'ssf_identity=' + fillquoted(query1.FieldByName('policyid').asstring)) = false then
  begin
    if chkSSF.Checked = TRUE then
    begin
      ssf_PatientApiPost(query1.FieldByName('policyid').asstring);
    end
    else
    begin
      hib_PatientApiPost(query1.FieldByName('policyid').asstring);
    end;
  end;

  if chkssf.Checked = true then
  begin
    query2.First;
    while not query2.eof do
    begin
      if FileExists(query2.FieldByName('file_path').asstring) = false then
      begin
        if chkPrescription.Checked = true then
        begin
          if ((query2.FieldByName('ty').asstring = 'SR') or (query2.FieldByName('ty').asstring = 'SSR')) then
          begin

          end
          else
          begin
            showmessage('Not Found: ' + query2.FieldByName('file_path').asstring);
            exit;
          end;
        end
        else
        begin
          if query2.FieldByName('ty').asstring = 'PS' then
          begin

          end
          else
          begin
            if loginfrm.gSINGLE_FILE_UPLOAD = 'YES' then
            begin

            end
            else
            begin
              if ((query2.FieldByName('ty').asstring = 'SR') or (query2.FieldByName('ty').asstring = 'SSR')) then
              begin

              end
              else
              begin
                showmessage('Not Found: ' + query2.FieldByName('file_path').asstring);
                exit;
              end;
            end;
          end;
        end;
      end;

      if query2.FieldByName('ty').asstring = 'PS' then
      begin

      end
      else
      begin
        if (query2.FieldByName('booked').asboolean = false) then
        begin
          if (query2.FieldByName('bookedAmount').asfloat <> 0) then
          begin
            // STOP FOR FEW DAYS
            showmessage('Not Booked: ' + query2.FieldByName('inv_no').asstring);
            exit;
          end;
        end;
      end;
      query2.Next;
    end;
  end;

  if chkssf.checked = true then
  begin
    ssf_ClaimPostAPI(query1.FieldByName('policyid').asstring, 'AA', query1.FieldByName('claim_code').asstring,
                      loginfrm.guserid, ginitdt, gfinaldt, query1.FieldByName('ipd').ASINTEGER);
  end;

  if chkhib.checked = true then
  begin
    if AlreadyFound('dmedipro', 'ssf_patient', 'ssf_identity', 'ssf_identity=' + fillquoted(query1.FieldByName('policyid').asstring)) = false then
    begin
      try
        hib_PatientApiPost(query1.FieldByName('policyid').asstring);
      except

      end;
    end;

    Delay(3000);

    try
      hib_ClaimPostAPI(query1.FieldByName('policyid').asstring, hib_inv_no, query1.FieldByName('claim_code').asstring,
                        loginfrm.guserid, ginitdt, gfinaldt, query1.FieldByName('ipd').asinteger);
    except

    end;

    hib_inv_no := '';
  end;

  Delay(3000);
  refreshqry4();
  query1.Locate('claim_code', s, []);
end;
