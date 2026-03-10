
CREATE PROCEDURE [Housing].[ResidentsSP] 
(
      @Action                 NVARCHAR(100)   = NULL
     ,@residentInfoID         NVARCHAR(100)   = NULL
     ,@NationalID             NVARCHAR(100)   = NULL
     ,@generalNo              NVARCHAR(100)   = NULL
     ,@firstName_A            NVARCHAR(100)   = NULL
     ,@secondName_A           NVARCHAR(100)   = NULL
     ,@thirdName_A            NVARCHAR(100)   = NULL
     ,@lastName_A             NVARCHAR(100)   = NULL
     ,@firstName_E            NVARCHAR(100)   = NULL
     ,@secondName_E           NVARCHAR(100)   = NULL
     ,@thirdName_E            NVARCHAR(100)   = NULL
     ,@lastName_E             NVARCHAR(100)   = NULL
     ,@militaryUnitID_FK      NVARCHAR(100)   = NULL
     ,@rankID_FK              NVARCHAR(100)   = NULL
     ,@martialStatusID_FK     NVARCHAR(100)   = NULL
     ,@dependinceCounter      NVARCHAR(100)   = NULL
     ,@nationalityID_FK       NVARCHAR(100)   = NULL
     ,@genderID_FK            NVARCHAR(100)   = NULL
     ,@birthDate              NVARCHAR(100)   = NULL
	 ,@Mobile                 NVARCHAR(100)   = NULL
     ,@notes                  NVARCHAR(100)   = NULL
     ,@idaraID_FK             NVARCHAR(100)   = NULL
     ,@entryData              NVARCHAR(100)   = NULL
     ,@hostName               NVARCHAR(100)   = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE
          @NewID           BIGINT = NULL
        , @Note            NVARCHAR(MAX) = NULL
        , @Identity_Insert BIGINT = NULL
        , @Identity_Insert1 BIGINT = NULL
        , @Identity_Insert2 BIGINT = NULL
        , @Identity_Update BIGINT = NULL
        , @Identity_Update1 BIGINT = NULL
        , @Identity_Update2 BIGINT = NULL;

    -- تحويلات رقمية آمنة
    DECLARE @IdaraID_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@idaraID_FK)), ''));

    DECLARE @militaryUnitID_FK_INT        INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@militaryUnitID_FK)), ''));
    DECLARE @rankID_FK_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@rankID_FK)), ''));
    DECLARE @martialStatusID_FK_INT    INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@martialStatusID_FK)), ''));
    DECLARE @dependinceCounter_INT       INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@dependinceCounter)), ''));
    DECLARE @nationalityID_FK_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@nationalityID_FK)), ''));
    DECLARE @genderID_FK_INT INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@genderID_FK)), ''));


    BEGIN TRY
        -- Transaction-safe
        IF @tc = 0
            BEGIN TRAN;

        ----------------------------------------------------------------
        -- Business validations => THROW 50001
        ----------------------------------------------------------------
        IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'العملية مطلوبة', 1;
        END
       

       IF(@Action IN('INSERT','UPDATE'))
       BEGIN

        IF NULLIF(LTRIM(RTRIM(@NationalID)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية مطلوب', 1;
        END

          IF (select count(*) 
                from Housing.ResidentInfo ri
                inner join Housing.ResidentDetails rd on ri.residentInfoID = rd.residentInfoID_FK
                where ri.residentInfoActive = 1 and rd.residentDetailsActive = 1 and rd.generalNo_FK = @generalNo and ((@residentInfoID is not null) and (rd.residentInfoID_FK <> @residentInfoID))
                ) > 0
        BEGIN
            ;THROW 50001, N'الرقم العام مستخدم مسبقا لشخص اخر', 1;
        END


        if(@nationalityID_FK_INT = 1)
        Begin
        IF TRY_CONVERT(BIGINT, @NationalID) IS NULL
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون أرقام فقط', 1;
        END

        IF LEN(@NationalID) <> 10
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يكون 10 أرقام', 1;
        END
        
        IF LEFT(@NationalID, 1) <> N'1'
        BEGIN
            ;THROW 50001, N'رقم الهوية الوطنية يجب أن يبدأ بالرقم 1', 1;
        END
        END



         IF (
            (NULLIF(LTRIM(RTRIM(@firstName_A)), N'') IS NULL) 
         OR (NULLIF(LTRIM(RTRIM(@secondName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@thirdName_A)), N'') IS NULL)
         OR (NULLIF(LTRIM(RTRIM(@lastName_A)), N'') IS NULL)
         )
        BEGIN
            ;THROW 50001, N'الاسم العربي الرباعي مطلوب', 1;
        END


         IF NULLIF(LTRIM(RTRIM(@militaryUnitID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الوحدة العسكرية مطلوبة', 1;
        END


         IF NULLIF(LTRIM(RTRIM(@rankID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الرتبة مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@martialStatusID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الحالة الاجتماعية مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@nationalityID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'الجنسية مطلوبة', 1;
        END

         IF NULLIF(LTRIM(RTRIM(@genderID_FK)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'تحديد الجنس مطلوب', 1;
        END

      
         IF NULLIF(LTRIM(RTRIM(@Mobile)), N'') IS NULL
        BEGIN
            ;THROW 50001, N'رقم الجوال مطلوب', 1;
        END
        

          IF TRY_CONVERT(BIGINT, @Mobile) IS NULL
        BEGIN
            ;THROW 50001, N'رقم الجوال يجب أن يكون أرقام فقط', 1;
        END

        IF LEN(@Mobile) <> 10
        BEGIN
            ;THROW 50001, N'رقم الجوال يجب أن يكون 10 أرقام', 1;
        END
        
        IF LEFT(@Mobile, 2) <> N'05'
        BEGIN
            ;THROW 50001, N'رقم الجوال يجب أن يبدأ بالرقم 05', 1;
        END


        END


         IF(@Action IN('DELETE'))
       BEGIN

       if(select count(*) from Housing.V_WaitingList w where w.residentInfoID = @residentInfoID) > 0
       begin
       ;THROW 50001, N'لايمكن حذف المستفيد لوجود اجراءات متعلقة به في النظام', 1;

       end

       END
        ----------------------------------------------------------------
        -- INSERT
        ----------------------------------------------------------------
        IF @Action = N'INSERT'
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM  Housing.ResidentInfo c
                WHERE c.NationalID = @NationalID
                  AND c.residentInfoActive = 1
            )
            BEGIN
                ;THROW 50001, N'بيانات المستفيد مدخلة مسبقا', 1;
            END

            INSERT INTO  Housing.ResidentInfo
            (
                  [NationalID]
                 ,[residentInfoActive]
                 ,[entryData]
                 ,[hostName]
            )
            VALUES
            (
                  @NationalID
                , 1
                , @entryData
                , @hostName
            );

            SET @Identity_Insert = SCOPE_IDENTITY();
            IF @Identity_Insert IS NULL OR @Identity_Insert <= 0
            BEGIN
                ;THROW 50002, N'حصل خطأ في اضافة البيانات - ResidentInfo', 1; -- برمجي
            END

                INSERT INTO  Housing.ResidentDetails
                (
                      [residentInfoID_FK]
                     ,[generalNo_FK]
                     ,[rankID_FK]
                     ,[militaryUnitID_FK]
                     ,[martialStatusID_FK]
                     ,[dependinceCounter]
                     ,[nationalityID_FK]
                     ,[genderID_FK]
                     ,[firstName_A]
                     ,[secondName_A]
                     ,[thirdName_A]
                     ,[lastName_A]
                     ,[firstName_E]
                     ,[secondName_E]
                     ,[thirdName_E]
                     ,[lastName_E]
                     ,[note]
                     ,[birthdate]
                     ,[residentDetailsStartDate]
                     ,[residentDetailsActive]
                     ,[IdaraId_FK]
                     ,[entryData]
                     ,[hostName]
                )
                VALUES
                (
                      @Identity_Insert
                    , @generalNo
                    , @rankID_FK_INT
                    , @militaryUnitID_FK_INT
                    , @martialStatusID_FK_INT
                    , ISNULL(@dependinceCounter,0)
                    , @nationalityID_FK_INT
                    , @genderID_FK_INT
                    , @firstName_A
                    , @secondName_A
                    , @thirdName_A
                    , @lastName_A
                    , @firstName_E
                    , @secondName_E
                    , @thirdName_E
                    , @lastName_E
                    , @notes
                    , @birthDate
                    , GETDATE()
                    , 1
                    , @idaraID_FK
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة البيانات - ResidentDetails', 1; -- برمجي
                END

                 INSERT INTO  Housing.ResidentContactInfo
                (
                      [residentInfoID_FK]
                     ,[residentcontanctTypeID_FK]
                     ,[residentcontactDetails]
                     ,[residentcontactInfoStartDate]
                     ,[residentcontactInfoActive]
                     ,[entryData]
                     ,[hostName]
                )
                VALUES
                (
                      @Identity_Insert
                    , 1
                    , @Mobile
                    , GETDATE()
                    , 1
                    , @entryData
                    , @hostName
                );

                IF @@ROWCOUNT <= 0
                BEGIN
                    ;THROW 50003, N'حصل خطأ في اضافة البيانات - ResidentContactInfo', 1; -- برمجي
                END



           

            SET @NewID = @Identity_Insert;

            SET @Note = N'{'
                + N'"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @generalNo), '') + N'"'
                + N',"rankID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @rankID_FK_INT), '') + N'"'
                + N',"militaryUnitID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryUnitID_FK_INT), '') + N'"'
                + N',"martialStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @martialStatusID_FK_INT), '') + N'"'
                + N',"dependinceCounter": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dependinceCounter), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK_INT), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK_INT), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"notes": "' + ISNULL(CONVERT(NVARCHAR(MAX), @notes), '') + N'"'
                + N',"Mobile": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N',"residentcontanctTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"residentcontactDetails": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[ResidentInfo],[Housing].[ResidentDetails],[Housing].[ResidentContactInfo]'
                , N'INSERT'
                , ISNULL(@NewID, 0)
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم اضافة البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- UPDATE
        ----------------------------------------------------------------
        ELSE IF @Action = N'UPDATE'
        BEGIN
        
            IF @residentInfoID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.ResidentInfo bd
                WHERE bd.residentInfoID = @residentInfoID
                  AND bd.residentInfoActive = 1
            )
            BEGIN
                ;THROW 50001, N'المستفيد غير موجود', 1;
            END

            -- Duplicate check (مع تجاهل نفس السجل)
            --IF EXISTS
            --(
            --    SELECT 1
            --    FROM  Housing.ResidentInfo c
            --    WHERE c.NationalID = @NationalID
            --      AND c.residentInfoActive = 1
                  
            --)
            --BEGIN
            --    ;THROW 50001, N'البيانات مدخلة مسبقا', 1;
            --END

           
            UPDATE  Housing.ResidentInfo
            SET
                  NationalID = ISNULL(@NationalID, NationalID)
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE residentInfoID = @residentInfoID;

             SET @Identity_Update = @@ROWCOUNT;

            UPDATE  Housing.ResidentDetails
                SET
                      residentDetailsActive = 0
                    , residentDetailsEndDate = ISNULL(residentDetailsEndDate, GETDATE())
                    , entryData = ISNULL(@entryData, entryData)
                    , hostName  = ISNULL(@hostName, hostName)
                 WHERE residentInfoID_FK  = @residentInfoID
                  AND residentDetailsActive        = 1;

            SET @Identity_Update1 = @@ROWCOUNT;

            if (@Identity_Update1 > 0)
            BEGIN
                 INSERT INTO  Housing.ResidentDetails
                    (
                        residentInfoID_FK
                       , [generalNo_FK]          
                       , [rankID_FK]             
                       , [militaryUnitID_FK]     
                       , [martialStatusID_FK]    
                       , [dependinceCounter]     
                       , [nationalityID_FK]      
                       , [genderID_FK]           
                       , [firstName_A]           
                       , [secondName_A]          
                       , [thirdName_A]           
                       , [lastName_A]            
                       , [firstName_E]           
                       , [secondName_E]          
                       , [thirdName_E]           
                       , [lastName_E]            
                       , [note]                  
                       , [birthdate]
                       , [residentDetailsStartDate]
                       , [IdaraId_FK]      
                       ,residentDetailsActive
                       ,entryData
                       ,hostName
 
                    )
                    VALUES
                    (   
                         @residentInfoID
                        ,@generalNo
                        ,@rankID_FK_INT
                        ,@militaryUnitID_FK_INT
                        ,@martialStatusID_FK_INT
                        ,ISNULL(@dependinceCounter,0)
                        ,@nationalityID_FK_INT
                        ,@genderID_FK_INT
                        ,@firstName_A
                        ,@secondName_A
                        ,@thirdName_A
                        ,@lastName_A
                        ,@firstName_E
                        ,@secondName_E
                        ,@thirdName_E
                        ,@lastName_E
                        ,@notes
                        ,@birthDate
                        ,GETDATE()
                        ,@idaraID_FK 
                        ,1
                        ,@entryData
                        ,@hostName
 
                    );

                    SET @Identity_Insert1 = SCOPE_IDENTITY();
                   END


                      UPDATE  Housing.ResidentContactInfo
                SET
                      residentcontactInfoActive = 0
                    , residentcontactInfoEndDate = ISNULL(residentcontactInfoEndDate, GETDATE())
                    , entryData = ISNULL(@entryData, entryData)
                    , hostName  = ISNULL(@hostName, hostName)
                 WHERE residentInfoID_FK  = @residentInfoID
                  AND residentcontactInfoActive        = 1;

                  SET @Identity_Update2 = @@ROWCOUNT;

                  IF(@Identity_Update2 > 0)
                  BEGIN

                      INSERT INTO  Housing.ResidentContactInfo
                (
                      [residentInfoID_FK]
                     ,[residentcontanctTypeID_FK]
                     ,[residentcontactDetails]
                     ,[residentcontactInfoStartDate]
                     ,[residentcontactInfoActive]
                     ,[entryData]
                     ,[hostName]
                )
                VALUES
                (
                @residentInfoID
                ,1
                ,@Mobile
                ,GETDATE()
                ,1
                ,@entryData
                ,@hostName
                )
              
              SET @Identity_Insert2 = SCOPE_IDENTITY();

               END
               

                    ---- باقي تحديث الجوال

            SET @Note = N'{'
                + N'"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @generalNo), '') + N'"'
                + N',"rankID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @rankID_FK_INT), '') + N'"'
                + N',"militaryUnitID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryUnitID_FK_INT), '') + N'"'
                + N',"martialStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @martialStatusID_FK_INT), '') + N'"'
                + N',"dependinceCounter": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dependinceCounter), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK_INT), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK_INT), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"notes": "' + ISNULL(CONVERT(NVARCHAR(MAX), @notes), '') + N'"'
                + N',"Mobile": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N',"residentcontanctTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"residentcontactDetails": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[ResidentInfo],[Housing].[ResidentDetails],[Housing].[ResidentContactInfo]'
                , N'UPDATE'
                , @residentInfoID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم تحديث البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- DELETE (Soft Delete)
        ----------------------------------------------------------------
        ELSE IF @Action = N'DELETE'
        BEGIN

        IF @residentInfoID IS NULL
            BEGIN
                ;THROW 50001, N'رقم السجل مطلوب للتحديث', 1;
            END

            IF NOT EXISTS
            (
                SELECT 1
                FROM  Housing.ResidentInfo bd
                WHERE bd.residentInfoID = @residentInfoID
                  AND bd.residentInfoActive = 1
            )
            BEGIN
                ;THROW 50001, N'المستفيد غير موجود', 1;
            END

             UPDATE  Housing.ResidentInfo
            SET
                  residentInfoActive = 0
                , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
            WHERE residentInfoID = @residentInfoID;

             IF @@ROWCOUNT = 0
                    BEGIN
                        ;THROW 50002, N'حصل خطأ في تحديث البيانات - ResidentInfo', 1; -- برمجي/غير متوقع
                    END

            UPDATE  Housing.ResidentDetails
                SET
                      residentDetailsActive = 0
                    , residentDetailsEndDate = ISNULL(residentDetailsEndDate, GETDATE())
                    , entryData = ISNULL(ISNULL(entryData,'')+N','+@entryData, entryData)
                    , hostName  = ISNULL(ISNULL(@hostName,'')+N','+@hostName, hostName)
                 WHERE residentInfoID_FK  = @residentInfoID
                  AND residentDetailsActive        = 1;

                     IF @@ROWCOUNT = 0
                    BEGIN
                        ;THROW 50002, N'حصل خطأ في تحديث البيانات - ResidentDetails', 1; -- برمجي/غير متوقع
                    END
          
           

            SET @Note = N'{'
                + N'"residentInfoID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @NewID), '') + N'"'
                + N',"generalNo_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @generalNo), '') + N'"'
                + N',"rankID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @rankID_FK_INT), '') + N'"'
                + N',"militaryUnitID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @militaryUnitID_FK_INT), '') + N'"'
                + N',"martialStatusID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @martialStatusID_FK_INT), '') + N'"'
                + N',"dependinceCounter": "' + ISNULL(CONVERT(NVARCHAR(MAX), @dependinceCounter), '') + N'"'
                + N',"nationalityID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @nationalityID_FK_INT), '') + N'"'
                + N',"genderID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), @genderID_FK_INT), '') + N'"'
                + N',"firstName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_A), '') + N'"'
                + N',"secondName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_A), '') + N'"'
                + N',"thirdName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_A), '') + N'"'
                + N',"lastName_A": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_A), '') + N'"'
                + N',"firstName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @firstName_E), '') + N'"'
                + N',"secondName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @secondName_E), '') + N'"'
                + N',"thirdName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @thirdName_E), '') + N'"'
                + N',"lastName_E": "' + ISNULL(CONVERT(NVARCHAR(MAX), @lastName_E), '') + N'"'
                + N',"notes": "' + ISNULL(CONVERT(NVARCHAR(MAX), @notes), '') + N'"'
                + N',"Mobile": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N',"entryData": "' + ISNULL(CONVERT(NVARCHAR(MAX), @entryData), '') + N'"'
                + N',"hostName": "' + ISNULL(CONVERT(NVARCHAR(MAX), @hostName), '') + N'"'
                + N',"residentcontanctTypeID_FK": "' + ISNULL(CONVERT(NVARCHAR(MAX), '1'), '') + N'"'
                + N',"residentcontactDetails": "' + ISNULL(CONVERT(NVARCHAR(MAX), @Mobile), '') + N'"'
                + N'}';

            INSERT INTO  dbo.AuditLog
            (
                  TableName
                , ActionType
                , RecordID
                , PerformedBy
                , Notes
            )
            VALUES
            (
                  N'[Housing].[ResidentInfo],[Housing].[ResidentDetails],[Housing].[ResidentContactInfo]'
                , N'DELETE'
                , @residentInfoID
                , @entryData
                , @Note
            );

            SELECT 1 AS IsSuccessful, N'تم حذف البيانات بنجاح' AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- Unknown Action
        ----------------------------------------------------------------
        ELSE
        BEGIN
            ;THROW 50001, N'العملية غير مسجلة', 1;
        END

    END TRY
    BEGIN CATCH
        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END
