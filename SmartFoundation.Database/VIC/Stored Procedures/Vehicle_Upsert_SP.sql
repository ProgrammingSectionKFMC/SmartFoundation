
/* =========================================================
   Description:
   إضافة/تعديل مركبة في VIC.Vehicles حسب رقم الهيكل (chassisNumber).
   - يدعم تحقق صلاحيات اختياري عبر fn_UserHasMenuPermission عند SkipPermission=0.
   - يعبّي/يحدّث حقول التدقيق entryDate/entryData/hostName (وفق معيار VIC).
   - يرجع IsSuccessful/Message_ + chassisNumber بعد النجاح.
   Type: WRITE (UPSERT)
========================================================= */

CREATE   PROCEDURE [VIC].[Vehicle_Upsert_SP]
(
      @UsersID         INT = NULL
    , @MenuLink        NVARCHAR(1000) = NULL
    , @SkipPermission  BIT = 1

    , @chassisNumber           NVARCHAR(100)

    , @ownerID_FK              NVARCHAR(100) = NULL
    , @ManufacturerNameID_FK   INT = NULL
    , @vehicleModelID_FK       INT = NULL
    , @vehicleClassID_FK       INT = NULL
    , @TypeOfUseID_FK          INT = NULL
    , @vehicleColorID_FK       INT = NULL
    , @countryMadeID_FK        INT = NULL
    , @regstritionTypeID_FK    INT = NULL
    , @regionID_FK             INT = NULL
    , @fuelTypeID_FK           INT = NULL
    , @vehicleTypeID_FK        INT = NULL
    , @yearModel               INT = NULL
    , @capacity                INT = NULL
    , @serialNumber            NVARCHAR(100) = NULL
    , @plateLetters            NVARCHAR(100) = NULL
    , @plateNumbers            INT = NULL
    , @armyNumber              NVARCHAR(100) = NULL
    , @vehicleNote             NVARCHAR(800) = NULL
    , @idaraID_FK              NVARCHAR(10)  = NULL
    , @entryData               NVARCHAR(40)  = NULL
    , @hostName                NVARCHAR(400) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @MenuLink_Trim NVARCHAR(1000) = NULLIF(LTRIM(RTRIM(@MenuLink)), N'');
    DECLARE @CH_Trim       NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@chassisNumber)), N'');

    DECLARE @Owner_Trim    NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@ownerID_FK)), N'');
    DECLARE @Serial_Trim   NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@serialNumber)), N'');
    DECLARE @Letters_Trim  NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@plateLetters)), N'');
    DECLARE @Army_Trim     NVARCHAR(100)  = NULLIF(LTRIM(RTRIM(@armyNumber)), N'');
    DECLARE @Note_Trim     NVARCHAR(800)  = NULLIF(LTRIM(RTRIM(@vehicleNote)), N'');

    -- معيار الإدارة (BIGINT)
    DECLARE @IdaraID_BIG BIGINT =
        TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), N''));

    -- AuditLog
    DECLARE @Note_Audit NVARCHAR(MAX) = NULL;

    BEGIN TRY
        IF ISNULL(@SkipPermission, 1) = 0 AND @MenuLink_Trim IS NOT NULL
        BEGIN
            IF dbo.fn_UserHasMenuPermission(@UsersID, @MenuLink_Trim) = 0
                THROW 50001, N'عفواً لا تملك صلاحية', 1;
        END

        IF @CH_Trim IS NULL
            THROW 50001, N'chassisNumber مطلوب', 1;

        IF @IdaraID_BIG IS NULL
            THROW 50001, N'idaraID_FK مطلوب', 1;

        DECLARE @IsInsert BIT = CASE WHEN EXISTS
        (
            SELECT 1
            FROM VIC.Vehicles v
            WHERE v.chassisNumber = @CH_Trim
              AND v.IdaraID_FK = @IdaraID_BIG
        ) THEN 0 ELSE 1 END;

        -- لو الشاصي موجود لكن بإدارة مختلفة => نرفض (تجنّب تداخل الإدارات)
        IF @IsInsert = 1 AND EXISTS (SELECT 1 FROM VIC.Vehicles v2 WHERE v2.chassisNumber = @CH_Trim)
            THROW 50001, N'رقم الهيكل موجود بإدارة أخرى', 1;

        IF @tc = 0 BEGIN TRAN;

        IF @IsInsert = 0
        BEGIN
            UPDATE VIC.Vehicles
            SET
                  ownerID_FK            = @Owner_Trim
                , ManufacturerNameID_FK = @ManufacturerNameID_FK
                , vehicleModelID_FK     = @vehicleModelID_FK
                , vehicleClassID_FK     = @vehicleClassID_FK
                , TypeOfUseID_FK        = @TypeOfUseID_FK
                , vehicleColorID_FK     = @vehicleColorID_FK
                , countryMadeID_FK      = @countryMadeID_FK
                , regstritionTypeID_FK  = @regstritionTypeID_FK
                , regionID_FK           = @regionID_FK
                , fuelTypeID_FK         = @fuelTypeID_FK
                , vehicleTypeID_FK      = @vehicleTypeID_FK
                , yearModel             = @yearModel
                , capacity              = @capacity
                , serialNumber          = @Serial_Trim
                , plateLetters          = @Letters_Trim
                , plateNumbers          = @plateNumbers
                , armyNumber            = @Army_Trim
                , vehicleNote           = @Note_Trim
                , entryDate             = GETDATE()
                , entryData             = @entryData
                , hostName              = @hostName
            WHERE chassisNumber = @CH_Trim
              AND IdaraID_FK = @IdaraID_BIG;

            IF @@ROWCOUNT <= 0
                THROW 50002, N'لم يتم تعديل أي سجل', 1; -- CHANGED (50002)

            -- AuditLog (UPDATE)
            SET @Note_Audit = N'{'
                + N'"chassisNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @CH_Trim), '') + N'"'
                + N',"IdaraID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"ownerID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Owner_Trim), '') + N'"'
                + N',"ManufacturerNameID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ManufacturerNameID_FK), '') + N'"'
                + N',"vehicleModelID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleModelID_FK), '') + N'"'
                + N',"vehicleClassID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleClassID_FK), '') + N'"'
                + N',"TypeOfUseID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @TypeOfUseID_FK), '') + N'"'
                + N',"vehicleColorID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleColorID_FK), '') + N'"'
                + N',"countryMadeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @countryMadeID_FK), '') + N'"'
                + N',"regstritionTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @regstritionTypeID_FK), '') + N'"'
                + N',"regionID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @regionID_FK), '') + N'"'
                + N',"fuelTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @fuelTypeID_FK), '') + N'"'
                + N',"vehicleTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleTypeID_FK), '') + N'"'
                + N',"yearModel":"' + ISNULL(CONVERT(NVARCHAR(MAX), @yearModel), '') + N'"'
                + N',"capacity":"' + ISNULL(CONVERT(NVARCHAR(MAX), @capacity), '') + N'"'
                + N',"serialNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Serial_Trim), '') + N'"'
                + N',"plateLetters":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Letters_Trim), '') + N'"'
                + N',"plateNumbers":"' + ISNULL(CONVERT(NVARCHAR(MAX), @plateNumbers), '') + N'"'
                + N',"armyNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Army_Trim), '') + N'"'
                + N',"vehicleNote":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Note_Trim), '') + N'"'
                + N',"entryData":"' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName":"' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[Vehicles]'
                , N'UPDATE'
                , 0
                , @entryData
                , @Note_Audit
            );
        END
        ELSE
        BEGIN
            INSERT INTO VIC.Vehicles
            (
                  ownerID_FK
                , ManufacturerNameID_FK
                , vehicleModelID_FK
                , vehicleClassID_FK
                , TypeOfUseID_FK
                , vehicleColorID_FK
                , countryMadeID_FK
                , regstritionTypeID_FK
                , regionID_FK
                , fuelTypeID_FK
                , vehicleTypeID_FK
                , yearModel
                , capacity
                , chassisNumber
                , serialNumber
                , plateLetters
                , plateNumbers
                , armyNumber
                , vehicleNote
                , IdaraID_FK
                , entryDate
                , entryData
                , hostName
            )
            VALUES
            (
                  @Owner_Trim
                , @ManufacturerNameID_FK
                , @vehicleModelID_FK
                , @vehicleClassID_FK
                , @TypeOfUseID_FK
                , @vehicleColorID_FK
                , @countryMadeID_FK
                , @regstritionTypeID_FK
                , @regionID_FK
                , @fuelTypeID_FK
                , @vehicleTypeID_FK
                , @yearModel
                , @capacity
                , @CH_Trim
                , @Serial_Trim
                , @Letters_Trim
                , @plateNumbers
                , @Army_Trim
                , @Note_Trim
                , @IdaraID_BIG
                , GETDATE()
                , @entryData
                , @hostName
            );

            -- AuditLog (INSERT)
            SET @Note_Audit = N'{'
                + N'"chassisNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @CH_Trim), '') + N'"'
                + N',"IdaraID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @IdaraID_BIG), '') + N'"'
                + N',"ownerID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Owner_Trim), '') + N'"'
                + N',"ManufacturerNameID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @ManufacturerNameID_FK), '') + N'"'
                + N',"vehicleModelID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleModelID_FK), '') + N'"'
                + N',"vehicleClassID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleClassID_FK), '') + N'"'
                + N',"TypeOfUseID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @TypeOfUseID_FK), '') + N'"'
                + N',"vehicleColorID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleColorID_FK), '') + N'"'
                + N',"countryMadeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @countryMadeID_FK), '') + N'"'
                + N',"regstritionTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @regstritionTypeID_FK), '') + N'"'
                + N',"regionID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @regionID_FK), '') + N'"'
                + N',"fuelTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @fuelTypeID_FK), '') + N'"'
                + N',"vehicleTypeID_FK":"' + ISNULL(CONVERT(NVARCHAR(MAX), @vehicleTypeID_FK), '') + N'"'
                + N',"yearModel":"' + ISNULL(CONVERT(NVARCHAR(MAX), @yearModel), '') + N'"'
                + N',"capacity":"' + ISNULL(CONVERT(NVARCHAR(MAX), @capacity), '') + N'"'
                + N',"serialNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Serial_Trim), '') + N'"'
                + N',"plateLetters":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Letters_Trim), '') + N'"'
                + N',"plateNumbers":"' + ISNULL(CONVERT(NVARCHAR(MAX), @plateNumbers), '') + N'"'
                + N',"armyNumber":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Army_Trim), '') + N'"'
                + N',"vehicleNote":"' + ISNULL(CONVERT(NVARCHAR(MAX), @Note_Trim), '') + N'"'
                + N',"entryData":"' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName":"' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N'}';

            INSERT INTO DATACORE.dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[VIC].[Vehicles]'
                , N'INSERT'
                , 0
                , @entryData
                , @Note_Audit
            );
        END

        IF @tc = 0 COMMIT;

        SELECT
              1 AS IsSuccessful
            , CASE WHEN @IsInsert = 1 THEN N'تمت الإضافة بنجاح' ELSE N'تم التعديل بنجاح' END AS Message_
            , @CH_Trim AS chassisNumber;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH
END