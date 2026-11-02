-- STEP 1 ONLY: change HousingHandoverSP. Does not change the View or action roots.
CREATE PROCEDURE [Housing].[HousingHandoverSP]
    @Action NVARCHAR(200),
    @buildingDetailsID NVARCHAR(100) = NULL,
    @buildingDetailsNo NVARCHAR(100) = NULL,
    @LastActionTypeID NVARCHAR(100) = NULL,
    @NextActionTypeID NVARCHAR(1000) = NULL,
    @LastActionID NVARCHAR(100) = NULL,
    @Notes NVARCHAR(1000) = NULL,
    @idaraID_FK NVARCHAR(10) = NULL,
    @entryData NVARCHAR(20) = NULL,
    @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @Idara INT = TRY_CONVERT(INT, NULLIF(@idaraID_FK,N''));
    DECLARE @Home BIGINT = TRY_CONVERT(BIGINT, NULLIF(@buildingDetailsID,N''));
    DECLARE @Previous BIGINT = TRY_CONVERT(BIGINT, NULLIF(@LastActionID,N''));
    DECLARE @PreviousType INT = TRY_CONVERT(INT, NULLIF(@LastActionTypeID,N''));
    DECLARE @Next INT = TRY_CONVERT(INT, NULLIF(@NextActionTypeID,N''));
    DECLARE @UserID INT = TRY_CONVERT(INT, NULLIF(@entryData,N''));
    DECLARE @CurrentID BIGINT, @CurrentType INT, @CurrentNo NVARCHAR(100);
    DECLARE @Status INT, @NewID BIGINT, @LockResult INT;
    DECLARE @IndependentStart BIT = 0;
    DECLARE @Exit57ID BIGINT;

    BEGIN TRY
        IF @tc = 0 BEGIN TRANSACTION;
        IF @Action <> N'HousingHandoverAction' OR @Action IS NULL
            THROW 50001,N'العملية غير مسجلة.',1;
        IF @Idara IS NULL OR @Home IS NULL OR @Previous IS NULL
            OR @PreviousType IS NULL OR @Next IS NULL OR @UserID IS NULL
            THROW 50001,N'بيانات المنزل أو الحالة أو المستخدم غير صحيحة.',1;
        IF NULLIF(LTRIM(RTRIM(@Notes)),N'') IS NULL
            THROW 50001,N'الملاحظات مطلوبة.',1;


           DECLARE @LockResource NVARCHAR(255) =
    CONCAT(N'Housing.Occupancy:', @Idara, N':', @Home);

EXEC @LockResult = sys.sp_getapplock
    @Resource = @LockResource,
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 10000;
        IF @LockResult < 0
            THROW 50001,N'تجري معالجة أخرى للمنزل؛ حدّث الصفحة.',1;

        SELECT @CurrentID=b.LastActionID,
               @CurrentType=b.LastActionTypeID,
               @CurrentNo=b.buildingDetailsNo
        FROM Housing.V_GetGeneralListForBuilding b
        WHERE b.buildingDetailsID=@Home AND b.BuildingIdaraID=@Idara
              AND b.buildingDetailsActive=1;
        IF @CurrentID IS NULL OR @CurrentID<>@Previous OR @CurrentType<>@PreviousType
            THROW 50001,N'حالة المنزل تغيرت؛ حدّث الصفحة قبل اتخاذ الإجراء.',1;
        IF NOT EXISTS
(
    SELECT 1
    FROM Housing.Buildinghandover h
    WHERE h.BuildinghandoverActive = 1

      AND
      (
          (
              EXISTS
              (
                  SELECT 1
                  FROM Housing.Buildinghandover localH
                  WHERE localH.IdaraID_FK = @Idara
                    AND localH.BuildinghandoverActive = 1
              )
              AND h.IdaraID_FK = @Idara
          )
          OR
          (
              NOT EXISTS
              (
                  SELECT 1
                  FROM Housing.Buildinghandover localH
                  WHERE localH.IdaraID_FK = @Idara
                    AND localH.BuildinghandoverActive = 1
              )
              AND h.IdaraID_FK IS NULL
          )
      )

      AND h.BuildingActionTypeID_FK = @CurrentType
      AND h.NextBuildingActionTypeID_FK = @Next

      AND EXISTS
      (
          SELECT 1
          FROM dbo.V_GetListUserPermission p
          WHERE p.userID = @UserID
            AND p.permissionTypeRoleID = 20
            AND p.permissionTypeID = h.PermissionTypeID_FK
      )
)
    THROW 50001,N'الانتقال غير متاح أو لا تملك الصلاحية المطلوبة.',1;

        SELECT @Status=t.buildingStatusID_FK
        FROM Housing.BuildingActionType t WHERE t.buildingActionTypeID=@Next;
        IF @@ROWCOUNT<>1
            THROW 50001,N'نوع الإجراء القادم غير موجود.',1;

        -- Physical handover at 54 is not permission to release a house.
        IF @Next IN (4,5) AND @CurrentType IN (54,59,60)
            THROW 50001,N'لا يمكن تحويل المنزل قبل إرساله للتدقيق المالي في المرحلة 57.',1;

        -- First house-side operation MUST be independent of the resident's exit tree.
        IF @Next IN (4,5) AND @CurrentType IN (3,57,58)
        BEGIN
            SET @IndependentStart=1;
            IF @CurrentType IN (3,57,58)
            BEGIN
                SELECT TOP (1) @Exit57ID=x.buildingActionID
                FROM Housing.fn_BuildingAction_ChainToRoot(@CurrentID) chain
                JOIN Housing.BuildingAction x ON x.buildingActionID=chain.buildingActionID
                WHERE x.buildingActionTypeID_FK=57 AND x.buildingActionActive=1
                  AND x.buildingDetailsID_FK=@Home AND x.IdaraId_FK=@Idara
                ORDER BY x.buildingActionID DESC;
                IF @CurrentType IN (57,58) AND @Exit57ID IS NULL
                    THROW 50001,N'لا توجد مرحلة 57 موثوقة في دورة إخلاء المنزل.',1;
            END;
            -- Do not start two independent operational trees for the same post-exit cycle.
            IF EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction houseRoot WITH(UPDLOCK,HOLDLOCK)
                WHERE houseRoot.buildingDetailsID_FK=@Home
                  AND houseRoot.IdaraId_FK=@Idara
                  AND houseRoot.buildingActionActive=1
                  AND houseRoot.buildingActionParentID IS NULL
                  AND houseRoot.buildingActionTypeID_FK IN (4,5)
                  AND houseRoot.buildingActionID>@CurrentID
            ) THROW 50001,N'بدأت دورة تشغيل جديدة للمنزل بالفعل.',1;
            -- When the visible stage is financial 58 or 3, an operational cycle
            -- may already have started after 57 but be hidden by the legacy View.
            IF @Exit57ID IS NOT NULL AND EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction houseRoot WITH(UPDLOCK,HOLDLOCK)
                WHERE houseRoot.buildingDetailsID_FK=@Home
                  AND houseRoot.IdaraId_FK=@Idara
                  AND houseRoot.buildingActionActive=1
                  AND houseRoot.buildingActionParentID IS NULL
                  AND houseRoot.buildingActionTypeID_FK IN (4,5)
                  AND houseRoot.buildingActionID>@Exit57ID
            ) THROW 50001,N'بدأت دورة تشغيل لهذا الإخلاء بالفعل.',1;
        END
        ELSE
        BEGIN
            IF EXISTS
            (
                SELECT 1 FROM Housing.BuildingAction child WITH(UPDLOCK,HOLDLOCK)
                WHERE child.buildingActionParentID=@Previous AND child.buildingActionActive=1
            ) THROW 50001,N'تم تنفيذ هذا الإجراء مسبقًا.',1;
        END;

        INSERT Housing.BuildingAction
        (buildingActionTypeID_FK,buildingStatusID_FK,buildingDetailsID_FK,
         buildingDetailsNo,buildingActionDate,buildingActionNote,
         buildingActionActive,buildingActionParentID,IdaraId_FK,
         entryDate,entryData,hostName)
        VALUES
        (@Next,@Status,@Home,@CurrentNo,GETDATE(),@Notes,
         1,CASE WHEN @IndependentStart=1 THEN NULL ELSE @Previous END,
         @Idara,GETDATE(),@entryData,@hostName);
        SET @NewID=SCOPE_IDENTITY();
        IF @NewID IS NULL THROW 50002,N'تعذر تسجيل إجراء المنزل.',1;

        INSERT dbo.AuditLog(TableName,ActionType,RecordID,PerformedBy,Notes)
        VALUES(N'[Housing].[BuildingAction]',N'HousingHandoverAction',@NewID,@entryData,
               CONCAT(N'{"buildingActionID":',@NewID,
                      N',"buildingActionTypeID_FK":',@Next,
                      N',"previousActionID":',@Previous,
                      N',"independentOperationalRoot":',@IndependentStart,N'}'));
        IF @tc=0 COMMIT TRANSACTION;
        SELECT 1 AS IsSuccessful,
               CONCAT(N'تم اتخاذ إجراء للمنزل رقم ',@CurrentNo,N' بنجاح') AS Message_;
    END TRY
    BEGIN CATCH
        IF @tc=0 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;