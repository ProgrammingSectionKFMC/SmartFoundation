CREATE PROCEDURE [dbo].[Masters_ExtraDataLoad]
      @pageName_      NVARCHAR(400)
    , @ActionType     NVARCHAR(100)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
    , @parameter_01   NVARCHAR(4000) = NULL
    , @parameter_02   NVARCHAR(4000) = NULL
    , @parameter_03   NVARCHAR(4000) = NULL
    , @parameter_04   NVARCHAR(4000) = NULL
    , @parameter_05   NVARCHAR(4000) = NULL
    , @parameter_06   NVARCHAR(4000) = NULL
    , @parameter_07   NVARCHAR(4000) = NULL
    , @parameter_08   NVARCHAR(4000) = NULL
    , @parameter_09   NVARCHAR(4000) = NULL
    , @parameter_10   NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------
    --                   START TRY BLOCK
    -------------------------------------------------------------------

     -------------------------------------------------------------------
    --                   Residents
    -------------------------------------------------------------------
    BEGIN TRY
        BEGIN TRANSACTION;


        IF @pageName_ = 'Residents'
        BEGIN
         IF @ActionType = 'ResidentActions'
            BEGIN
                Select top(1)
                     [buildingActionID]
                    ,[buildingActionUDID]
                    ,[buildingActionTypeID_FK]
                    ,[buildingStatusID_FK]
                    ,[residentInfoID_FK]
                    ,[generalNo_FK]
                    ,[buildingPaymentTypeID_FK]
                    ,[buildingDetailsID_FK]
                    ,[buildingDetailsNo]
                    ,[buildingActionFromDate]
                    ,[buildingActionToDate]
                    ,[buildingActionDate]
                    ,[buildingActionDate2]
                    ,[buildingActionDecisionNo]
                    ,[buildingActionDecisionDate]
                    ,[fromDSD_FK]
                    ,[toDSD_FK]
                    ,[buildingActionFromSourceID_FK]
                    ,[buildingActionToSourceID_FK]
                    ,[buildingActionNote]
                    ,[buildingActionExtraText1]
                    ,[buildingActionExtraText2]
                    ,[buildingActionExtraText3]
                    ,[buildingActionExtraText4]
                    ,[buildingActionExtraDate1]
                    ,[buildingActionExtraDate2]
                    ,[buildingActionExtraDate3]
                    ,[buildingActionExtraFloat1]
                    ,[buildingActionExtraFloat2]
                    ,[buildingActionExtraInt1]
                    ,[buildingActionExtraInt2]
                    ,[buildingActionExtraInt3]
                    ,[buildingActionExtraInt4]
                    ,[buildingActionExtraType1]
                    ,[buildingActionExtraType2]
                    ,[buildingActionExtraType3]
                    ,[buildingActionActive]
                    ,[buildingActionParentID]
                    ,[CustdyRecord]
                    ,[AssignPeriodID_FK]
                    ,[ExtendReasonTypeID_FK]
                    ,[IdaraId_FK]
                    ,[entryDate]
                    ,[entryData]
                    ,[hostName]
                       from
                       Housing.BuildingAction w
                       where w.residentInfoID_FK = @parameter_01 --and w.buildingActionTypeID_FK = @parameter_02

                       order by buildingActionID asc

            END





            

        END



         -------------------------------------------------------------------
    --                   AllMeterRead
    -------------------------------------------------------------------

         ELSE IF @pageName_ = 'AllMeterRead'
        BEGIN
         IF @ActionType = 'MeterLastBill'
            BEGIN

                    IF EXISTS (
                            SELECT 1
                            FROM Housing.Bills b
                            inner join housing.BillPeriod bp on bp.BillPeriodID = b.CurrentPeriodID
                            WHERE b.BillActive = 1
                              AND b.meterServiceTypeID = @parameter_01
                              AND b.meterID = @parameter_02
                              AND b.CurrentPeriodID <> @parameter_03
                        )
                        BEGIN
                            -- ✅ يوجد فاتورة سابقة (غير الفترة الحالية)
                            SELECT TOP (1)
                                   b.meterID,
                                   b.meterNo,
                                   --b.LastRead,
                                   b.CurrentRead,
                                   bp.billPeriodName_A+ N' - '+cast(DATEPART(YEAR,bp.billPeriodStartDate) as nvarchar) periods_,
                                   b.TotalPrice
                            FROM Housing.Bills b
                            inner join housing.BillPeriod bp on bp.BillPeriodID = b.CurrentPeriodID
                            WHERE b.BillActive = 1
                              AND b.meterServiceTypeID = @parameter_01
                              AND b.meterID = @parameter_02
                              --AND b.CurrentPeriodID <> @parameter_03
                            ORDER BY
                                ISNULL(b.PeriodYear, 0) DESC,
                                ISNULL(b.PeriodMonth, 0) DESC,
                                ISNULL(b.CurrentPeriodID, 0) DESC,
                                b.BillsID DESC;
                        END
                        ELSE
                        BEGIN
                            -- ❌ لا يوجد فاتورة سابقة
                            SELECT TOP (1)
                                   md.meterID,
                                   md.meterNo,
                                   --CAST(N'لا يوجد قراءة سابقة' AS NVARCHAR(200)) AS LastRead,
                                   CAST(N'لا يوجد قراءة سابقة' AS NVARCHAR(200)) AS CurrentRead,
                                   N' - ' as periods_,
                                   CAST(N'لا يوجد فاتورة سابقة' AS NVARCHAR(200)) AS TotalPrice
                            FROM Housing.V_MetersDetails md
                            WHERE md.meterID = @parameter_02
                              AND md.meterServiceTypeID_FK = @parameter_01;
                        END
                
                END
                ELSE  IF @ActionType = 'MeterNewBill'
            BEGIN


            SELECT 
            case 
            when s.LastRead > s.CurrentRead then 0
            when s.LastRead = s.CurrentRead then 0
            else
            1 END as checks,
            s.CurrentRead,s.LastRead,s.ReadDiff,s.PRICE,s.PRICETAX,s.meterServicePrice,s.meterServicePriceTAX,(s.meterServicePrice+s.meterServicePriceTAX) ServicePriceWithTAX,s.TotalPrice,s.meterID,s.meterNo,s.CurrentPeriodID
            FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;

            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice,mst.meterServiceTypeName_A
            FROM Housing.Bills b
            inner join Housing.MeterServiceType mst on b.meterServiceTypeID = mst.meterServiceTypeID
            where b.BillsID = @parameter_01
            END


        END




         -------------------------------------------------------------------
    --                  ImportExcelForBuildingPayment
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'ImportExcelForBuildingPayment'
        BEGIN
         IF @ActionType = 'GetBuildingPaymentByDeductList'
            BEGIN

                   SELECT [paymentID]
                        ,[PaymentUID]
                        ,[buildingPaymentTypeID_FK]
                        ,[generalNo_FK]
                        ,[IDNumber]
                        ,[residentInfoID_FK]
                        ,[rankNameA]
                        ,[unitID]
                        ,[userName]
                        ,[buildingDetailsID_FK]
                        ,[amount]
                        ,[deductListID_FK]
                        ,[buildingPayementActive]
                        ,[BillChargeTypeID_FK]
                        ,[ParentIDpaymentID_FK]
                        ,[IdaraId_FK]
                        ,[entryDate]
                        ,[entryData]
                        ,[hostName]
                    FROM [DATACORE].[Housing].[BuildingPayment] bb
                    where bb.buildingPayementActive = 1 and bb.deductListID_FK = @parameter_01

                
            END
                ELSE  IF @ActionType = 'MeterNewBill'
            BEGIN


            SELECT s.CurrentRead,s.LastRead,s.ReadDiff,s.PRICE,s.PRICETAX,s.meterServicePrice,s.meterServicePriceTAX,(s.meterServicePrice+s.meterServicePriceTAX) ServicePriceWithTAX,s.TotalPrice,s.meterID,s.meterNo,s.CurrentPeriodID
            FROM Housing.CalculteElectrictyBills_ByNewReadValue(@parameter_02, @parameter_04) s;

            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice
            FROM Housing.Bills b
            where b.BillsID = @parameter_01
            END


        END




               -------------------------------------------------------------------
    --                  ImportExcelForBuildingPayment
    -------------------------------------------------------------------


         ELSE IF @pageName_ = 'FinancialAuditForExtendAndEvictions'
        BEGIN
         IF @ActionType = 'GetBillsTotalPriceForResident'
            BEGIN

                   
        SELECT 
        r.BillsID,
        r.BillNumber,
        r.TotalPrice,
        r.residentInfoID_FK AS residentInfoID,
        r.BillChargeTypeID_FK AS BillChargeTypeID,
        bct.BillChargeTypeName_A, r.buildingDetailsID,
        b.buildingDetailsNo,
        r.idaraID_FK AS idaraID,
        vgrd.FullName_A
        FROM   Housing.Bills AS r 
        INNER JOIN Housing.BillChargeType AS bct ON r.BillChargeTypeID_FK = bct.BillChargeTypeID
        LEFT JOIN  Housing.V_GetGeneralListForBuilding b on r.buildingDetailsID = b.buildingDetailsID
        LEFT JOIN Housing.V_GetFullResidentDetails AS vgrd ON r.residentInfoID_FK = vgrd.residentInfoID


        WHERE (r.BillActive = 1) 
        and (r.residentInfoID_FK = @parameter_01) 
        and (r.BillChargeTypeID_FK = @parameter_02) 
        and (r.buildingDetailsID = @parameter_03 or r.buildingDetailsID is null) 
        and (r.idaraID_FK = @idaraID)

                
            END
                ELSE  IF @ActionType = 'GetBillsPaidByResident'
            BEGIN


            SELECT 
            bp.amount ,
            bp.residentInfoID_FK AS residentInfoID,
            bp.BillChargeTypeID_FK AS BillChargeTypeID,
            t.BillChargeTypeName_A,
            bp.buildingDetailsID_FK AS buildingDetailsID,
            bd.buildingDetailsNo,
            vgrd.FullName_A
            FROM   Housing.BuildingPayment AS bp INNER JOIN
                         Housing.DeductList AS d ON bp.deductListID_FK = d.deductListID INNER JOIN
                         Housing.BillChargeType AS t ON bp.BillChargeTypeID_FK = t.BillChargeTypeID INNER JOIN
                         Housing.BuildingDetails AS bd ON bp.buildingDetailsID_FK = bd.buildingDetailsID LEFT JOIN
                         Housing.V_GetFullResidentDetails AS vgrd ON bp.residentInfoID_FK = vgrd.residentInfoID
            WHERE 
            (d.deductActive = 1) 
            AND (bp.buildingPayementActive = 1) 
            AND(bp.residentInfoID_FK = @parameter_01) 
            AND (bp.BillChargeTypeID_FK = @parameter_02) 
            AND (bp.IdaraId_FK = 1) 
            AND (bp.buildingDetailsID_FK = @parameter_03 or bp.buildingDetailsID_FK is null)


            END


            ELSE  IF @ActionType = 'EDITBILL'
            BEGIN


            select b.BillsID,b.meterNo,b.CurrentRead,b.LastRead,b.CurrentPeriodID,b.ReadDiff, b.TotalPrice
            FROM Housing.Bills b
            where b.BillsID = @parameter_01
            END


        END



    -------------------------------------------------------------------
    --                     PAGE NOT FOUND
    --            DO NOT TOUCH DOWN THIS LINE PLEASE
    -------------------------------------------------------------------
        ELSE
        BEGIN
            SELECT 0 AS IsSuccessful, N'الصفحة المرسلة مقيدة. PageName' AS Message_;
        END

        COMMIT TRANSACTION;
    END TRY

    -------------------------------------------------------------------
    --                     CATCH BLOCK
    -------------------------------------------------------------------
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000), @ErrSeverity INT, @ErrState INT, @IdentityCatchError INT;

        SELECT 
              @ErrMsg      = ERROR_MESSAGE(),
              @ErrSeverity = ERROR_SEVERITY(),
              @ErrState    = ERROR_STATE();

        INSERT INTO DATACORE.dbo.ErrorLog
        (
              ERROR_MESSAGE_
            , ERROR_SEVERITY_
            , ERROR_STATE_
            , SP_NAME
            , entryData
            , hostName
        )
        VALUES
        (
              @ErrMsg
            , @ErrSeverity
            , @ErrState
            , N'[dbo].[Masters_DataLoad]'
            , @entrydata
            , @hostname
        );

        SET @IdentityCatchError = SCOPE_IDENTITY();

        SELECT 
              0 AS IsSuccessful,
              N'حصل خطأ غير معروف رمز الخطأ : ' + CAST(@IdentityCatchError AS NVARCHAR(200)) AS Message_;
    END CATCH
END
