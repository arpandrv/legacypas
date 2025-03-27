CREATE PROCEDURE sp_ProcessInsuranceClaim
    @claim_code VARCHAR(50),
    @policy_id VARCHAR(50),
    @user_id VARCHAR(50),
    @init_dt DATETIME,
    @final_dt DATETIME,
    @is_ssf BIT = 1,
    @is_hib BIT = 0,
    @opd_ipd INT = 0,
    @hib_inv_no VARCHAR(50) = '',
    @check_prescription BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @discharge_check BIT;
    DECLARE @discharge_no_len INT;
    DECLARE @hosp_id INT;
    DECLARE @scheme_product_id INT;
    DECLARE @scheme_id INT;
    DECLARE @employer_id VARCHAR(50);
    DECLARE @icd_code VARCHAR(50);
    DECLARE @outcome VARCHAR(50);
    DECLARE @ssf_claim_post BIT;
    DECLARE @ipd_no INT;
    DECLARE @service_type VARCHAR(10);
    DECLARE @message VARCHAR(255) = '';
    DECLARE @status INT = 0; -- 0=Success, 1=Error
    
    -- Get claim information
    SELECT @hosp_id = hospid,
           @scheme_product_id = scheme_product_id,
           @scheme_id = scheme_id,
           @employer_id = EmployerId,
           @icd_code = icdcode,
           @outcome = outcome,
           @ssf_claim_post = ssf_claim_post,
           @ipd_no = ipd
    FROM InsuranceClaimCode
    WHERE claim_code = @claim_code;
    
    -- For IPD cases, check discharge status
    IF @opd_ipd = 1 -- IPD
    BEGIN
        SELECT @discharge_check = a.discharge,
               @discharge_no_len = LEN(ISNULL(b.dischargeno, ''))
        FROM inpatient a
        LEFT JOIN discharge b ON a.ipdno = b.ipdno
        WHERE a.hospid = @hosp_id
          AND a.claim_code = @claim_code;
          
        -- Check if discharge exists
        IF @discharge_no_len = 0
        BEGIN
            SET @message = 'Discharge not Found';
            SET @status = 1;
            GOTO ErrorExit;
        END;
        
        -- Check if discharge is pending
        IF @discharge_check = 0
        BEGIN
            SET @message = 'Inpatient Discharge Pending';
            SET @status = 1;
            GOTO ErrorExit;
        END;
    END;
    
    -- SSF validations
    IF @is_ssf = 1
    BEGIN
        -- Check if SSF API is registered (would be handled by app)
        
        -- Check scheme product
        IF @scheme_product_id = 0
        BEGIN
            SET @message = 'Scheme Product Empty';
            SET @status = 1;
            GOTO ErrorExit;
        END;
        
        -- Check employer for accident cases
        IF @scheme_id = 1 AND ISNULL(@employer_id, '') = ''
        BEGIN
            SET @message = 'Accident Case - Update Employer Detail';
            SET @status = 1;
            GOTO ErrorExit;
        END;
        
        -- Check ICD code
        IF ISNULL(@icd_code, '') = ''
        BEGIN
            SET @message = 'ICD Code Empty';
            SET @status = 1;
            GOTO ErrorExit;
        END;
        
        -- Check if already posted
        IF @outcome <> 'rejected' AND (@ssf_claim_post = 1 OR 
           EXISTS(SELECT 1 FROM InsuranceClaimCode 
                  WHERE ssf_claim_post = 1 AND claim_code = @claim_code))
        BEGIN
            SET @message = 'Already Posted';
            SET @status = 1;
            GOTO ErrorExit;
        END;
    END;
    
    -- HIB validations
    IF @is_hib = 1
    BEGIN
        -- Check if HIB API is registered (would be handled by app)
        
        -- Check ICD code - exemption for OPD4 and EMRT services
        SELECT @service_type = service 
        FROM ClaimServices 
        WHERE claim_code = @claim_code;
        
        IF ISNULL(@icd_code, '') = '' AND @service_type NOT IN ('OPD4', 'EMRT')
        BEGIN
            SET @message = 'ICD Code Empty';
            SET @status = 1;
            GOTO ErrorExit;
        END;
    END;
    
    -- Verify patient exists in SSF/HIB system
    IF NOT EXISTS(SELECT 1 FROM ssf_patient WHERE ssf_identity = @policy_id)
    BEGIN
        -- Signal to app that patient record needs to be created
        -- (actual API call would be handled by application)
        INSERT INTO claim_processing_log (claim_code, policy_id, action_required, log_date)
        VALUES (@claim_code, @policy_id, 'CREATE_PATIENT', GETDATE());
    END;
    
    -- Document validation for SSF
    IF @is_ssf = 1
    BEGIN
        -- Check if documents exist and are booked
        -- (File existence check would be handled by app)
        IF EXISTS(
            SELECT 1 FROM claim_documents
            WHERE claim_code = @claim_code 
              AND ty <> 'PS'
              AND ty NOT IN ('SR', 'SSR')
              AND booked = 0 
              AND bookedAmount <> 0
        )
        BEGIN
            SET @message = 'Some documents not booked';
            SET @status = 1;
            GOTO ErrorExit;
        END;
    END;
    
    -- Process claim (update database)
    BEGIN TRANSACTION;
    
    -- Update claim as processed
    UPDATE InsuranceClaimCode
    SET ssf_claim_post = CASE WHEN @is_ssf = 1 THEN 1 ELSE ssf_claim_post END,
        hib_claim_post = CASE WHEN @is_hib = 1 THEN 1 ELSE hib_claim_post END,
        processed_date = GETDATE(),
        processed_by = @user_id
    WHERE claim_code = @claim_code;
    
    -- Log the claim submission for external processing
    INSERT INTO claim_submission_queue
    (
        claim_code, 
        policy_id, 
        submission_type,
        ipd_no,
        init_date,
        final_date,
        status,
        created_date,
        created_by,
        hib_invoice_no
    )
    VALUES
    (
        @claim_code,
        @policy_id,
        CASE WHEN @is_ssf = 1 THEN 'SSF' WHEN @is_hib = 1 THEN 'HIB' ELSE 'OTHER' END,
        @ipd_no,
        @init_dt,
        @final_dt,
        'PENDING',
        GETDATE(),
        @user_id,
        @hib_inv_no
    );
    
    COMMIT TRANSACTION;
    
    -- Return success status
    SELECT 0 AS status_code, 'Claim processed successfully' AS message;
    RETURN 0;
    
ErrorExit:
    -- Return error information
    SELECT @status AS status_code, @message AS message;
    RETURN @status;
END
GO