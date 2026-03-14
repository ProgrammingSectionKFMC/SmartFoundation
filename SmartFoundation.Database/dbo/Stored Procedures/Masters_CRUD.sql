
CREATE PROCEDURE [dbo].[Masters_CRUD]
      @pageName_      NVARCHAR(400)
    , @ActionType     NVARCHAR(100)
    , @idaraID        INT
    , @entrydata      INT
    , @hostName       NVARCHAR(4000) = NULL
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
    , @parameter_11   NVARCHAR(4000) = NULL
    , @parameter_12   NVARCHAR(4000) = NULL
    , @parameter_13   NVARCHAR(4000) = NULL
    , @parameter_14   NVARCHAR(4000) = NULL
    , @parameter_15   NVARCHAR(4000) = NULL
    , @parameter_16   NVARCHAR(4000) = NULL
    , @parameter_17   NVARCHAR(4000) = NULL
    , @parameter_18   NVARCHAR(4000) = NULL
    , @parameter_19   NVARCHAR(4000) = NULL
    , @parameter_20   NVARCHAR(4000) = NULL
    , @parameter_21   NVARCHAR(4000) = NULL
    , @parameter_22   NVARCHAR(4000) = NULL
    , @parameter_23   NVARCHAR(4000) = NULL
    , @parameter_24   NVARCHAR(4000) = NULL
    , @parameter_25   NVARCHAR(4000) = NULL
    , @parameter_26   NVARCHAR(4000) = NULL
    , @parameter_27   NVARCHAR(4000) = NULL
    , @parameter_28   NVARCHAR(4000) = NULL
    , @parameter_29   NVARCHAR(4000) = NULL
    , @parameter_30   NVARCHAR(4000) = NULL
    , @parameter_31   NVARCHAR(4000) = NULL
    , @parameter_32   NVARCHAR(4000) = NULL
    , @parameter_33   NVARCHAR(4000) = NULL
    , @parameter_34   NVARCHAR(4000) = NULL
    , @parameter_35   NVARCHAR(4000) = NULL
    , @parameter_36   NVARCHAR(4000) = NULL
    , @parameter_37   NVARCHAR(4000) = NULL
    , @parameter_38   NVARCHAR(4000) = NULL
    , @parameter_39   NVARCHAR(4000) = NULL
    , @parameter_40   NVARCHAR(4000) = NULL
    , @parameter_41   NVARCHAR(4000) = NULL
    , @parameter_42   NVARCHAR(4000) = NULL
    , @parameter_43   NVARCHAR(4000) = NULL
    , @parameter_44   NVARCHAR(4000) = NULL
    , @parameter_45   NVARCHAR(4000) = NULL
    , @parameter_46   NVARCHAR(4000) = NULL
    , @parameter_47   NVARCHAR(4000) = NULL
    , @parameter_48   NVARCHAR(4000) = NULL
    , @parameter_49   NVARCHAR(4000) = NULL
    , @parameter_50   NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;

    DECLARE @Result TABLE (IsSuccessful INT, Message_ NVARCHAR(4000));
    DECLARE @ok  INT = 0;
    DECLARE @msg NVARCHAR(4000) = N'';

    -- Notification Outbox
    DECLARE @SendNotif BIT = 0;
    DECLARE @NotifTitle NVARCHAR(200)  = NULL;
    DECLARE @NotifBody  NVARCHAR(2000) = NULL;
    DECLARE @NotifUrl   NVARCHAR(500)  = NULL;

    DECLARE @NotifUserID        BIGINT = NULL;
    DECLARE @NotifDistributorID BIGINT = NULL;
    DECLARE @NotifRoleID        BIGINT = NULL;
    DECLARE @NotifDsdID         BIGINT = NULL;
    DECLARE @NotifIdaraID       BIGINT = NULL;
    DECLARE @NotifMenuID        BIGINT = NULL;

    DECLARE @NotifStartDate NVARCHAR(500) = NULL;
    DECLARE @NotifEndDate   NVARCHAR(500) = NULL;
    DECLARE @entrydataname   NVARCHAR(500) = NULL;
    set @entrydataname = (SELECT u.FullName FROM V_GetListUsersInDSD u WHERE U.usersID =@entrydata)


    BEGIN TRY
        IF @tc = 0
            BEGIN TRAN;

        -- reset outbox
        SET @SendNotif = 0;
        SET @NotifTitle = NULL;
        SET @NotifBody  = NULL;
        SET @NotifUrl   = NULL;
        SET @NotifUserID = NULL;
        SET @NotifDistributorID = NULL;
        SET @NotifRoleID  = NULL;
        SET @NotifDsdID = NULL;
        SET @NotifStartDate = NULL;
        SET @NotifEndDate = NULL;
        ----------------------------------------------------------------
        -- Permission
        ----------------------------------------------------------------
        IF @pageName_ = 'Permission'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PermissionSP]
                      @Action                         = @ActionType
                    , @DistributorPermissionTypeID_FK = @parameter_02
                    , @permissionStartDate            = @parameter_03
                    , @permissionEndDate              = @parameter_04
                    , @permissionNote                 = @parameter_05
                    , @UsersID                        = @parameter_06
                    , @RoleID                         = @parameter_07
                    , @IdaraID                        = @parameter_08
                    , @DeptID                         = @parameter_09
                    , @SectionID                      = @parameter_10
                    , @DivisonID                      = @parameter_11
                    , @distributorID                  = @parameter_12
                    , @searchID                       = @parameter_13
                    , @InIdaraID                      = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName;
            END
            ELSE IF @ActionType = 'INSERTFULLACCESS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PermissionSP]
                      @Action                              = @ActionType
                    , @distributorIDFroGiveAllPermissions   = @parameter_01
                    , @permissionStartDate                  = @parameter_02
                    , @permissionEndDate                    = @parameter_03
                    , @permissionNote                       = @parameter_04
                    , @UsersID                              = @parameter_05
                    , @RoleID                               = @parameter_06
                    , @IdaraID                              = @parameter_07
                    , @DeptID                               = @parameter_08
                    , @SectionID                            = @parameter_09
                    , @DivisonID                            = @parameter_10
                    , @distributorID                        = @parameter_11
                    , @searchID                             = @parameter_12
                    , @InIdaraID                      = @idaraID
                    , @entryData                            = @entrydata
                    , @hostName                             = @hostName;
            END
            ELSE IF @ActionType = 'UPDATE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PermissionSP]
                      @Action               = @ActionType
                    , @PermissionID         = @parameter_01
                    , @permissionStartDate  = @parameter_04
                    , @permissionEndDate    = @parameter_05
                    , @permissionNote       = @parameter_06
                    , @InIdaraID                      = @idaraID
                    , @entryData            = @entrydata
                    , @hostName             = @hostName;
            END
            ELSE IF @ActionType = 'DELETE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PermissionSP]
                      @Action                         = @ActionType
                    , @PermissionID                   = @parameter_01
                    , @DistributorPermissionTypeID_FK = @parameter_02
                    , @permissionStartDate            = @parameter_03
                    , @permissionEndDate              = @parameter_04
                    , @permissionNote                 = @parameter_05
                    , @UsersID                        = @parameter_06
                    , @RoleID                         = @parameter_07
                    , @IdaraID                        = @parameter_08
                    , @DeptID                         = @parameter_09
                    , @SectionID                      = @parameter_10
                    , @DivisonID                      = @parameter_11
                    , @distributorID                  = @parameter_12
                    , @searchID                       = @parameter_13
                    , @InIdaraID                      = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


        ----------------------------------------------------------------
        -- PagesManagment
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'PagesManagment'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'AddProgram'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PagesManagmentSP]
                    @Action                          = @ActionType
                  , @programID                       = NULL
                  , @programName_A                   = @parameter_02
                  , @programName_E                   = @parameter_03
                  , @programDescription              = @parameter_04
                  , @programActive                   = @parameter_09
                  , @programLink                     = @parameter_06
                  , @programIcon                     = @parameter_07
                  , @programSerial                   = @parameter_08
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

            END


            ELSE IF @ActionType = 'EditProgram'
            BEGIN
               INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PagesManagmentSP]
                    @Action                          = @ActionType
                  , @programID                       = @parameter_01
                  , @programName_A                   = @parameter_02
                  , @programName_E                   = @parameter_03
                  , @programDescription              = @parameter_04
                  , @programActive                   = @parameter_09
                  , @programLink                     = @parameter_06
                  , @programIcon                     = @parameter_07
                  , @programSerial                   = @parameter_08
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;
            END


             ELSE IF @ActionType = 'DeleteProgram'
            BEGIN
               INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PagesManagmentSP]
                    @Action                          = @ActionType
                  , @programID                       = @parameter_01
                  , @programName_A                   = @parameter_02
                  , @programName_E                   = @parameter_03
                  , @programDescription              = @parameter_04
                  , @programActive                   = @parameter_09
                  , @programLink                     = @parameter_06
                  , @programIcon                     = @parameter_07
                  , @programSerial                   = @parameter_08
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;
            END


               ELSE IF @ActionType = 'AddMenuList'
            BEGIN
               INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [dbo].[PagesManagmentSP]
                    @Action                          = @ActionType
                  , @programID                       = @parameter_01
                  , @programName_A                   = @parameter_02
                  , @programName_E                   = @parameter_03
                  , @programDescription              = @parameter_04
                  , @programSerial                   = @parameter_05


                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;
            END







            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



        ----------------------------------------------------------------
        -- Users
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'Users'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERTUSERS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [DBO].[UsersSP]
                    @Action                          = @ActionType
                  , @usersID                         = NULL
                  , @nationalID                      = @parameter_02
                  , @GeneralNo                       = @parameter_03
                  , @firstName_A                     = @parameter_04
                  , @secondName_A                    = @parameter_05
                  , @thirdName_A                     = @parameter_06
                  , @forthName_A                     = @parameter_07
                  , @lastName_A                      = @parameter_08
                  , @firstName_E                     = @parameter_09
                  , @secondName_E                    = @parameter_10
                  , @thirdName_E                     = @parameter_11
                  , @forthName_E                     = @parameter_12
                  , @lastName_E                      = @parameter_13
                  , @UsersAuthTypeID                 = @parameter_14
                  , @userTypeID_FK                   = @parameter_16
                  , @IdaraID                         = @parameter_17
                  , @nationalIDIssueDate             = @parameter_22
                  , @dateOfBirth                     = @parameter_23
                  , @genderID_FK                     = @parameter_24
                  , @nationalityID_FK                = @parameter_25
                  , @religionID_FK                   = @parameter_26
                  , @maritalStatusID_FK              = @parameter_27
                  , @educationID_FK                  = @parameter_28
                  , @userNote                        = @parameter_20
                  , @distributorID                   = @parameter_36
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

            END


            ELSE IF @ActionType = 'UPDATEUSERS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [DBO].[UsersSP]
                    @Action                          = @ActionType
                  , @usersID                         = @parameter_01
                  , @nationalID                      = @parameter_02
                  , @GeneralNo                       = @parameter_03
                  , @firstName_A                     = @parameter_04
                  , @secondName_A                    = @parameter_05
                  , @thirdName_A                     = @parameter_06
                  , @forthName_A                     = @parameter_07
                  , @lastName_A                      = @parameter_08
                  , @firstName_E                     = @parameter_09
                  , @secondName_E                    = @parameter_10
                  , @thirdName_E                     = @parameter_11
                  , @forthName_E                     = @parameter_12
                  , @lastName_E                      = @parameter_13
                  , @UsersAuthTypeID                 = @parameter_14
                  , @userTypeID_FK                   = @parameter_16
                  , @IdaraID                         = @parameter_17
                  , @nationalIDIssueDate             = @parameter_22
                  , @dateOfBirth                     = @parameter_23
                  , @genderID_FK                     = @parameter_24
                  , @nationalityID_FK                = @parameter_25
                  , @religionID_FK                   = @parameter_26
                  , @maritalStatusID_FK              = @parameter_27
                  , @educationID_FK                  = @parameter_28
                  , @userNote                        = @parameter_20
                  , @distributorID                   = @parameter_36
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

            END

             

              ELSE IF @ActionType = 'DELETEUSERS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [DBO].[UsersSP]
                    @Action                          = @ActionType
                  , @usersID                         = @parameter_01
                  , @nationalID                      = @parameter_02
                  , @GeneralNo                       = @parameter_03
                  , @firstName_A                     = @parameter_04
                  , @secondName_A                    = @parameter_05
                  , @thirdName_A                     = @parameter_06
                  , @forthName_A                     = @parameter_07
                  , @lastName_A                      = @parameter_08
                  , @firstName_E                     = @parameter_09
                  , @secondName_E                    = @parameter_10
                  , @thirdName_E                     = @parameter_11
                  , @forthName_E                     = @parameter_12
                  , @lastName_E                      = @parameter_13
                  , @UsersAuthTypeID                 = @parameter_14
                  , @userTypeID_FK                   = @parameter_16
                  , @IdaraID                         = @parameter_17
                  , @nationalIDIssueDate             = @parameter_22
                  , @dateOfBirth                     = @parameter_23
                  , @genderID_FK                     = @parameter_24
                  , @nationalityID_FK                = @parameter_25
                  , @religionID_FK                   = @parameter_26
                  , @maritalStatusID_FK              = @parameter_27
                  , @educationID_FK                  = @parameter_28
                  , @userNote                        = @parameter_20
                  , @distributorID                   = @parameter_36
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

            END

          
              ELSE IF @ActionType = 'RESETUSERPASSWORD'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [DBO].[ReSetUserPassword]
                    @Action                          = @ActionType
                  , @usersID                         = @parameter_01
                  , @NationalID                      = NULL
                  , @PlainPassword                   = NULL
                  , @OldPassword                     = NULL
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

            END





            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



        ----------------------------------------------------------------
        -- BuildingType
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingType'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingTypeSP]
                      @Action                  = @ActionType
                    , @buildingTypeID          = NULL
                    , @buildingTypeCode        = @parameter_01
                    , @buildingTypeName_A      = @parameter_02
                    , @buildingTypeName_E      = @parameter_03
                    , @buildingTypeDescription = @parameter_04
                    , @idaraID_FK              = @idaraID
                    , @entryData               = @entrydata
                    , @hostName                = @hostName;

               
            END
            ELSE IF @ActionType = 'UPDATE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingTypeSP]
                      @Action                  = @ActionType
                    , @buildingTypeID          = @parameter_01
                    , @buildingTypeCode        = @parameter_02
                    , @buildingTypeName_A      = @parameter_03
                    , @buildingTypeName_E      = @parameter_04
                    , @buildingTypeDescription = @parameter_10
                    , @idaraID_FK              = @idaraID
                    , @entryData               = @entrydata
                    , @hostName                = @hostName;

             
            END
            ELSE IF @ActionType = 'DELETE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingTypeSP]
                      @Action         = @ActionType
                    , @buildingTypeID = @parameter_01
                    , @entryData      = @entrydata
                    , @hostName       = @hostName;

                -- (اختياري) إشعار حذف
            END
            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- BuildingClass
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingClass'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingClassSP]
                      @Action                   = @ActionType
                    , @BuildingClassName_A      = @parameter_01
                    , @BuildingClassName_E      = @parameter_02
                    , @BuildingClassDescription = @parameter_03
                    , @idaraID_FK               = @idaraID
                    , @entryData                = @entrydata
                    , @hostName                 = @hostName;

               
            END
            ELSE IF @ActionType = 'UPDATE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingClassSP]
                      @Action                   = @ActionType
                    , @BuildingClassID          = @parameter_01
                    , @BuildingClassName_A      = @parameter_02
                    , @BuildingClassName_E      = @parameter_03
                    , @BuildingClassDescription = @parameter_10
                    , @idaraID_FK               = @idaraID
                    , @entryData                = @entrydata
                    , @hostName                 = @hostName;
            END
            ELSE IF @ActionType = 'DELETE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingClassSP]
                      @Action          = @ActionType
                    , @BuildingClassID = @parameter_01
                    , @entryData       = @entrydata
                    , @hostName        = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- BuildingUtilityType
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingUtilityType'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingUtilityTypeSP]
                      @Action                         = @ActionType
                    , @buildingUtilityTypeName_A      = @parameter_01
                    , @buildingUtilityTypeName_E      = @parameter_02
                    , @buildingUtilityTypeDescription = @parameter_03
                    , @buildingUtilityTypeStartDate   = @parameter_04
                    , @buildingUtilityTypeEndDate     = @parameter_05
                    , @buildingUtilityIsRent          = @parameter_06
                    , @idaraID_FK                     = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName;

                
            END
            ELSE IF @ActionType = 'UPDATE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingUtilityTypeSP]
                      @Action                         = @ActionType
                    , @buildingUtilityTypeID          = @parameter_01
                    , @buildingUtilityTypeName_A      = @parameter_02
                    , @buildingUtilityTypeName_E      = @parameter_03
                    , @buildingUtilityTypeDescription = @parameter_10
                    , @buildingUtilityTypeStartDate   = @parameter_06
                    , @buildingUtilityTypeEndDate     = @parameter_07
                    , @buildingUtilityIsRent          = @parameter_08
                    , @idaraID_FK                     = @idaraID
                    , @entryData                      = @entrydata
                    , @hostName                       = @hostName;
            END
            ELSE IF @ActionType = 'DELETE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingUtilityTypeSP]
                      @Action                = @ActionType
                    , @buildingUtilityTypeID = @parameter_01
                    , @entryData             = @entrydata
                    , @hostName              = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- MilitaryLocation
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'MilitaryLocation'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MilitaryLocationSP]
                    @Action                          = @ActionType
                  , @militaryLocationID              = NULL
                  , @militaryLocationCode            = @parameter_01
                  , @militaryAreaCityID_FK           = @parameter_02
                  , @militaryLocationName_A          = @parameter_04
                  , @militaryLocationName_E          = @parameter_05
                  , @militaryLocationCoordinates     = @parameter_06
                  , @militaryLocationDescription     = @parameter_07
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;

               
            END
            ELSE IF @ActionType = 'UPDATE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MilitaryLocationSP]
                    @Action                          = @ActionType
                  , @militaryLocationID              = @parameter_01
                  , @militaryLocationCode            = @parameter_02
                  , @militaryAreaCityID_FK           = @parameter_03
                  , @militaryLocationName_A          = @parameter_05
                  , @militaryLocationName_E          = @parameter_06
                  , @militaryLocationCoordinates     = @parameter_07
                  , @militaryLocationDescription     = @parameter_08
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;
            END
            ELSE IF @ActionType = 'DELETE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MilitaryLocationSP]
                    @Action                          = @ActionType
                  , @militaryLocationID              = @parameter_01
                  , @militaryLocationCode            = @parameter_02
                  , @militaryAreaCityID_FK           = @parameter_03
                  , @militaryLocationName_A          = @parameter_04
                  , @militaryLocationName_E          = @parameter_05
                  , @militaryLocationCoordinates     = @parameter_06
                  , @militaryLocationDescription     = @parameter_07
                  , @militaryLocationActive          = @parameter_08
                  , @idaraID_FK                      = @idaraID
                  , @entryData                       = @entrydata
                  , @hostName                        = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


         ----------------------------------------------------------------
        -- BuildingDetails
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'BuildingDetails'
        BEGIN
          
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingDetailsSP]
                    @Action                         = @ActionType
                  , @buildingDetailsNo              = @parameter_02
                  , @buildingDetailsRooms           = @parameter_03
                  , @buildingLevelsCount            = @parameter_04
                  , @buildingDetailsArea            = @parameter_05
                  , @buildingDetailsCoordinates     = @parameter_06
                  , @buildingTypeID_FK              = @parameter_16
                  , @buildingClassID_FK             = @parameter_07
                  , @militaryLocationID_FK          = @parameter_08
                  , @buildingUtilityTypeID_FK       = @parameter_15
                  , @buildingDetailsTel_1           = @parameter_09
                  , @buildingDetailsTel_2           = @parameter_10
                  , @buildingDetailsRemark          = @parameter_14
                  , @buildingDetailsStartDate       = @parameter_13
                  , @buildingDetailsEndDate         = @parameter_18
                  , @buildingRentTypeID_FK          = @parameter_11
                  , @buildingRentAmount             = @parameter_12
                  , @idaraID_FK                     = @idaraID
                  , @entryData                      = @entrydata
                  , @hostName                       = @hostName;
                           
               
            END

              ELSE IF @ActionType = 'UPDATE'
            BEGIN
                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingDetailsSP]
                    @Action                         = @ActionType
                  , @buildingDetailsID              = @parameter_01
                  , @buildingDetailsNo              = @parameter_02
                  , @buildingDetailsRooms           = @parameter_03
                  , @buildingLevelsCount            = @parameter_04
                  , @buildingDetailsArea            = @parameter_05
                  , @buildingDetailsCoordinates     = @parameter_06
                  , @buildingTypeID_FK              = @parameter_07
                  , @buildingUtilityTypeID_FK       = @parameter_08
                  , @militaryLocationID_FK          = @parameter_09
                  , @buildingClassID_FK             = @parameter_10
                  , @buildingDetailsTel_1           = @parameter_11
                  , @buildingDetailsTel_2           = @parameter_12
                  , @buildingDetailsRemark          = @parameter_16
                  , @buildingDetailsStartDate       = @parameter_15
                  , @buildingDetailsEndDate         = @parameter_18
                  , @buildingRentTypeID_FK          = @parameter_13
                  , @buildingRentAmount             = @parameter_14
                  , @idaraID_FK                     = @idaraID
                  , @entryData                      = @entrydata
                  , @hostName                       = @hostName;

            END

             ELSE IF @ActionType = 'DELETE'
            BEGIN
                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[BuildingDetailsSP]
                    @Action                         = @ActionType
                  , @buildingDetailsID              = @parameter_01
                  , @buildingDetailsNo              = @parameter_02
                  , @buildingDetailsRooms           = @parameter_03
                  , @buildingLevelsCount            = @parameter_04
                  , @buildingDetailsArea            = @parameter_05
                  , @buildingDetailsCoordinates     = @parameter_06
                  , @buildingTypeID_FK              = @parameter_07
                  --, @buildingUtilityTypeID_FK       = @parameter_08
                  , @militaryLocationID_FK          = @parameter_09
                  , @buildingClassID_FK             = @parameter_10
                  , @buildingDetailsTel_1           = @parameter_11
                  , @buildingDetailsTel_2           = @parameter_12
                  , @buildingDetailsRemark          = @parameter_16
                  , @buildingDetailsStartDate       = @parameter_15
                  , @buildingDetailsActive          = @parameter_16
                  , @buildingRentTypeID_FK          = @parameter_13
                  , @buildingRentAmount             = @parameter_14
                  , @idaraID_FK                     = @idaraID
                  , @entryData                      = @entrydata
                  , @hostName                       = @hostName;

            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



        ----------------------------------------------------------------
        -- BuildingDetails
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'Residents'
        BEGIN
          
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'INSERT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[ResidentsSP]
                    @Action               = @ActionType
                  , @NationalID           = @parameter_01
                  , @generalNo            = @parameter_02
                  , @firstName_A          = @parameter_03
                  , @secondName_A         = @parameter_04
                  , @thirdName_A          = @parameter_05
                  , @lastName_A           = @parameter_06
                  , @firstName_E          = @parameter_07
                  , @secondName_E         = @parameter_08
                  , @thirdName_E          = @parameter_09
                  , @lastName_E           = @parameter_10
                  , @rankID_FK            = @parameter_11
                  , @militaryUnitID_FK    = @parameter_12
                  , @martialStatusID_FK   = @parameter_13
                  , @nationalityID_FK     = @parameter_14
                  , @dependinceCounter    = @parameter_15
                  , @genderID_FK          = @parameter_16
                  , @birthDate            = @parameter_17
                  , @Mobile               = @parameter_18
                  , @notes                = @parameter_19
                  , @idaraID_FK           = @idaraID
                  , @entryData            = @entrydata
                  , @hostName             = @hostName;
                           
               
            END

              ELSE IF @ActionType = 'UPDATE'
            BEGIN
                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[ResidentsSP]
                    @Action               = @ActionType
                  , @residentInfoID       = @parameter_01
                  , @NationalID           = @parameter_02
                  , @generalNo            = @parameter_03
                  , @firstName_A          = @parameter_04
                  , @secondName_A         = @parameter_05
                  , @thirdName_A          = @parameter_06
                  , @lastName_A           = @parameter_07
                  , @firstName_E          = @parameter_08
                  , @secondName_E         = @parameter_09
                  , @thirdName_E          = @parameter_10
                  , @lastName_E           = @parameter_11
                  , @rankID_FK            = @parameter_14
                  , @militaryUnitID_FK    = @parameter_16
                  , @martialStatusID_FK   = @parameter_18
                  , @nationalityID_FK     = @parameter_21
                  , @dependinceCounter    = @parameter_20
                  , @genderID_FK          = @parameter_23
                  , @birthDate            = @parameter_25
                  , @Mobile               = @parameter_26
                  , @notes                = @parameter_27
                  , @idaraID_FK           = @idaraID
                  , @entryData            = @entrydata
                  , @hostName             = @hostName;

            END

             ELSE IF @ActionType = 'DELETE'
            BEGIN
                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[ResidentsSP]
                    @Action               = @ActionType
                  , @residentInfoID       = @parameter_01
                  , @idaraID_FK           = @idaraID
                  , @entryData            = @entrydata
                  , @hostName             = @hostName;

            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END




       ----------------------------------------------------------------
        -- WaitingListByResident
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingListByResident'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            

            DELETE FROM @Result;

              IF @ActionType = 'INSERTWAITINGLIST'
            BEGIN

           

             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = NULL
                  , @residentInfoID_FK            = @parameter_01
                  , @NationalID                   = @parameter_02
                  , @GeneralNo                    = @parameter_03
                  , @buildingActionDecisionNo     = @parameter_04
                  , @buildingActionDecisionDate   = @parameter_05
                  , @WaitingClassID               = @parameter_06
                  , @WaitingOrderTypeID           = @parameter_07
                  , @Notes                        = @parameter_08
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                           
               
            END

              ELSE IF @ActionType = 'UPDATEWAITINGLIST'
            BEGIN

          

             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                  INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingOrderTypeID           = @parameter_08
                  , @Notes                        = @parameter_09
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

             ELSE IF @ActionType = 'DELETEWAITINGLIST'
            BEGIN

           

             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_20
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END



              ELSE IF @ActionType = 'INSERTOCCUBENTLETTER'
            BEGIN


             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = NULL
                  , @residentInfoID_FK            = @parameter_01
                  , @NationalID                   = @parameter_02
                  , @GeneralNo                    = @parameter_03
                  , @buildingActionDecisionNo     = @parameter_04
                  , @buildingActionDecisionDate   = @parameter_05
                  , @WaitingClassID               = @parameter_06
                  , @WaitingOrderTypeID           = @parameter_07
                  , @Notes                        = @parameter_08
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                           
               
            END

             ELSE IF @ActionType = 'UPDATEOCCUBENTLETTER'
            BEGIN

          

             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                  INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingOrderTypeID           = @parameter_08
                  , @Notes                        = @parameter_09
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END


             ELSE IF @ActionType = 'DELETEOCCUBENTLETTER'
            BEGIN



             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                 INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_20
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

             ELSE IF @ActionType = 'MOVEWAITINGLIST'
            BEGIN


             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  --, @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_01
                  , @NationalID                   = @parameter_02
                  , @GeneralNo                    = @parameter_03
                  , @buildingActionDecisionNo     = @parameter_30
                  , @buildingActionDecisionDate   = @parameter_31
                  --, @WaitingClassID               = @parameter_07
                  --, @WaitingOrderTypeID           = @parameter_08
                  , @Notes                        = @parameter_13
                  , @NewIdaraForMoveWaitingList   = @parameter_12
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;


                   -- إشعار (من الماستر فقط)
                    SET @SendNotif  = 1;
                    SET @NotifTitle = N'طلب نقل سجلات انتظار جديد وارد للادارة 📩';
                    SET @NotifBody  = N'يوجد نقل سجلات انتظار جديد وارد للادارة اضغط هنا للاطلاع عليه';
                    SET @NotifUrl   = N'/Housing/WaitingListMoveList';

                    SET @NotifUserID        = NULL;
                    SET @NotifDistributorID = NULL;
                    SET @NotifRoleID        = NULL;
                    SET @NotifDsdID         = NULL;
                    SET @NotifIdaraID       = @parameter_12;
                    SET @NotifMenuID        = 275;
                    SET @NotifStartDate     = NULL;
                    SET @NotifEndDate       = NULL;
                           
            END 


             ELSE IF @ActionType = 'DELETEMOVEWAITINGLIST'
            BEGIN


                 INSERT INTO @Result(IsSuccessful, Message_)
                 EXEC [Housing].[WaitingListByResidentSP]
                      @Action                       = @ActionType
                  , @ActionID                     = @parameter_25
                  , @residentInfoID_FK            = @parameter_01
                  , @NationalID                   = @parameter_02
                  , @GeneralNo                    = @parameter_03
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @Notes                        = @parameter_26
                  , @NewIdaraForMoveWaitingList   = @parameter_10
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

                    SET @SendNotif  = 1;
                    SET @NotifTitle = N'الغاء نقل سجلات انتظار وارد اليكم  ⚠️';
                    SET @NotifBody  = N'تم الغاء نقل سجلات الانتظارالوارد لديكم من قبل الادارة المرسلة اضغط هنا للاطلاع عليه';
                    SET @NotifUrl   = N'/Housing/WaitingListMoveList';

                    SET @NotifUserID        = NULL;
                    SET @NotifDistributorID = NULL;
                    SET @NotifRoleID        = NULL;
                    SET @NotifDsdID         = NULL;
                    SET @NotifIdaraID       = @parameter_10;
                    SET @NotifMenuID        = 275;
                    SET @NotifStartDate     = NULL;
                    SET @NotifEndDate       = NULL;
                           

            END





              ELSE IF @ActionType = 'DELETERESIDENTALLWAITINGLIST'
            BEGIN


            

             IF (
               select count(*) from Housing.V_MoveWaitingList f
               where f.residentInfoID  = @parameter_01 and f.LastActionID is null
            ) > 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا يوجد طلب نقل للمستفيد تحت الاجراء لايمكن عمل اي اجراء الى حين الانتهاء منه';
                GOTO Finish;
            END

                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListByResidentSP]
                    @Action                       = @ActionType
                  --, @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_01
                  , @NationalID                   = @parameter_02
                  , @GeneralNo                    = @parameter_03
                  , @buildingActionDecisionNo     = @parameter_30
                  , @buildingActionDecisionDate   = @parameter_31
                  , @ActionTypeID                 = @parameter_15
                  --, @WaitingClassID               = @parameter_07
                  --, @WaitingOrderTypeID           = @parameter_08
                  , @Notes                        = @parameter_13
                  --, @NewIdaraForMoveWaitingList   = @parameter_12
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                           
            END 




            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        end



        ----------------------------------------------------------------
        -- WaitingListByResident
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingListMoveList'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
              
              IF @ActionType = 'MOVEWAITINGLISTREJECT'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListMoveListSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_06
                  , @buildingActionDecisionDate   = @parameter_07
                  , @Notes                        = @parameter_23
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
                  
                    SET @SendNotif  = 1;
                    SET @NotifTitle = N'رفض نقل سجلات انتظار لمستفيد  ⚠️';
                    SET @NotifBody  = N'تم رفض نقل سجلات انتظار لمستفيد من قبل الادارة المرسل اليها اضغط هنا للاطلاع عليه';
                    SET @NotifUrl   = N'/Housing/WaitingListMoveList';

                    SET @NotifUserID        = NULL;
                    SET @NotifDistributorID = NULL;
                    SET @NotifRoleID        = NULL;
                    SET @NotifDsdID         = NULL;
                    SET @NotifIdaraID       = @parameter_09;
                    SET @NotifMenuID        = 275;
                    SET @NotifStartDate     = NULL;
                    SET @NotifEndDate       = NULL;
               
            END

              ELSE IF @ActionType = 'MOVEWAITINGLISTAPPROVE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListMoveListSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_06
                  , @buildingActionDecisionDate   = @parameter_07
                  , @Notes                        = @parameter_23
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

                   SET @SendNotif  = 1;
                    SET @NotifTitle = N'قبول نقل سجلات انتظار لمستفيد  ✔';
                    SET @NotifBody  = N'تم قبول نقل سجلات انتظار للمستفيد صاحب الهوية رقم :'+@parameter_03 +N'من قبل الادارة المرسل اليها';
                    SET @NotifUrl   = N'/Housing/WaitingListByResident?NID='+@parameter_03;

                    SET @NotifUserID        = NULL;
                    SET @NotifDistributorID = NULL;
                    SET @NotifRoleID        = NULL;
                    SET @NotifDsdID         = NULL;
                    SET @NotifIdaraID       = @parameter_09;
                    SET @NotifMenuID        = 273;
                    SET @NotifStartDate     = NULL;
                    SET @NotifEndDate       = NULL;
                           
               
            END





            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


        
        ----------------------------------------------------------------
        -- WaitingList
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'WaitingList'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'MOVETOASSIGNLIST'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[WaitingListSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @residentName                 = @parameter_15
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


         ----------------------------------------------------------------
        -- WaitingList
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'OtherWaitingList'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'MOVETOOCCUPENTPROCEDURES'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[OtherWaitingListSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID_FK            = @parameter_02
                  , @residentName                 = @parameter_15
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @buildingDetailsID            = @parameter_20
                  , @Notes                        = @parameter_12
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



         ----------------------------------------------------------------
        -- Assign
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'Assign'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'OPENASSIGNPERIOD'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignSP]
                       @Action              = @ActionType
                     , @Notes               = @parameter_01
                     , @AssignPeriodID      = @parameter_20
                     , @idaraID_FK          = @idaraID
                     , @entryData           = @entrydata
                     , @hostName            = @hostName;

            END

            ELSE IF @ActionType = 'CLOSEASSIGNPERIOD'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignSP]
                       @Action              = @ActionType
                     , @Notes               = @parameter_01
                     , @AssignPeriodID      = @parameter_20
                     , @idaraID_FK          = @idaraID
                     , @entryData           = @entrydata
                     , @hostName            = @hostName;

            END


            ELSE IF @ActionType = 'ASSIGNHOUSE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

             ELSE IF @ActionType = 'CANCLEASSIGNHOUSE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18

                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @lastActionTypeID             = @parameter_16
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

        ELSE IF @ActionType = 'UPDATEASSIGNHOUSE'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18

                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @lastActionTypeID             = @parameter_16
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


        
         ----------------------------------------------------------------
        -- ASSIGNSTATUS
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'ASSIGNSTATUS'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'ENDASSIGNPERIOD'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignStatusSP]
                       @Action              = @ActionType
                     , @Notes               = @parameter_01
                     , @AssignPeriodID      = @parameter_02
                     , @idaraID_FK          = @idaraID
                     , @entryData           = @entrydata
                     , @hostName            = @hostName;

            END



            ELSE IF @ActionType = 'ASSIGNSTATUS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AssignStatusSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @BuildingActionTypeCases      = @parameter_23
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



        ----------------------------------------------------------------
        -- HousingResident
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingResident'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'HOUSINGESRESIDENTSCUSTDY'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @BuildingActionTypeCases      = @parameter_23
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END



            ELSE IF @ActionType = 'HOUSINGESRESIDENTS'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingResidentSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @OccupentLetterNo             = @parameter_23
                  , @OccupentLetterDate           = @parameter_24
                  , @OccupentDate                 = @parameter_25
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


        ----------------------------------------------------------------
        -- MeterReadForOccubentAndExit
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'MeterReadForOccubentAndExit'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'METERREADFOROCCUBENTANDEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MeterReadForOccubentAndExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @meterID                      = @parameter_23
                  , @NewMeterReadValue            = @parameter_27  
                  , @ExitDate                     = @parameter_29 
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END



            ELSE IF @ActionType = 'UPDATEMETERREADFOROCCUBENTANDEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MeterReadForOccubentAndExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_06
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @meterID                      = @parameter_23
                  , @NewMeterReadValue            = @parameter_27  
                  , @meterReadID                  = @parameter_28  
                  , @ExitDate                     = @parameter_29
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType1';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END






        ----------------------------------------------------------------
        -- HousingExtend
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingExtend'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'HOUSINGEXTEND'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExtendSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_26
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END



            ELSE IF @ActionType = 'EDITHOUSINGEXTEND'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExtendSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_26
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END
                  
               

               ELSE IF @ActionType = 'CANCELHOUSINGEXTEND'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExtendSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_26
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END
                  

            ELSE IF @ActionType = 'SENDHOUSINGEXTENDTOFINANCE'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExtendSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_26
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

             ELSE IF @ActionType = 'ApproveExtend'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExtendSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_26
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END
            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- HousingExit
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingExit'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'HOUSINGEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END



            ELSE IF @ActionType = 'EDITHOUSINGEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
               EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @LastActionTypeID             = @parameter_16
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END
                  
               

               ELSE IF @ActionType = 'CANCELHOUSINGEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END
                  

            ELSE IF @ActionType = 'SENDHOUSINGEXITTOFINANCE'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @LastActionTypeID             = @parameter_16
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

             ELSE IF @ActionType = 'ApproveExtend'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END


               ELSE IF @ActionType = 'HOUSINGEXITPENALTYRECORD'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExitDate                     = @parameter_22
                  , @PenaltyPrice                 = @parameter_40
                  , @PenaltyReason                = @parameter_31
                  , @BillsID                      = @parameter_41
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END


          ----------------------------------------------------------------
        -- FinancialAuditForExtendAndEvictions
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'FinancialAuditForExtendAndEvictions'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'FINANCIALAUDITFOREXTENDANDEVICTIONS'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForExtendAndEvictionsSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = @parameter_11
                  , @buildingDetailsID                  = @parameter_03
                  , @LastActionID                       = @parameter_21
                  , @LastActionTypeID                   = @parameter_16
                  , @ExitDate                           = @parameter_30
                  , @LastActionExtendReasonTypeID       = @parameter_40
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END

              ELSE IF @ActionType = 'PAYMENTANDREFUNDFOREXTENDANDEXIT'
            BEGIN
                        INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForExtendAndEvictionsSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = null
                  , @buildingDetailsID                  = @parameter_05
                  , @LastActionID                       = @parameter_21
                  , @PaymentType                        = @parameter_12
                  , @PaymentNo                          = @parameter_13
                  , @PaymentDate                        = @parameter_14
                  , @Amount                             = @parameter_09
                  , @BillChargeTypeID_FK                = @parameter_03
                  --, @FromBillChargeTypeID_FK            = @parameter_
                  , @description                        = @parameter_27
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END


             ELSE IF @ActionType = 'FINANCIALSETTLEMENT'
            BEGIN
                        INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForExtendAndEvictionsSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = null
                  , @buildingDetailsID                  = @parameter_05
                  , @LastActionID                       = @parameter_21
                  , @PaymentType                        = @parameter_12
                  --, @PaymentNo                          = @parameter_13
                  --, @PaymentDate                        = @parameter_14
                  , @Amount                             = @parameter_39
                  , @FullRemining                       = @parameter_09
                  , @BillChargeTypeID_FK                = @parameter_03
                  , @ToBillChargeTypeID_FK              = @parameter_30
                  , @description                        = @parameter_27
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END


           

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



            ----------------------------------------------------------------
        -- FinancialAuditForUser
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'FinancialAuditForUser'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'FinancialAuditForUser'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForUserSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = @parameter_11
                  , @buildingDetailsID                  = @parameter_03
                  , @LastActionID                       = @parameter_21
                  , @LastActionTypeID                   = @parameter_16
                  , @ExitDate                           = @parameter_30
                  , @LastActionExtendReasonTypeID       = @parameter_40
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END

              ELSE IF @ActionType = 'PAYMENTANDREFUNDFORUSER'
            BEGIN
                        INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForUserSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = null
                  , @buildingDetailsID                  = @parameter_05
                  , @LastActionID                       = @parameter_21
                  , @PaymentType                        = @parameter_12
                  , @PaymentNo                          = @parameter_13
                  , @PaymentDate                        = @parameter_14
                  , @Amount                             = @parameter_09
                  , @BillChargeTypeID_FK                = @parameter_03
                  --, @FromBillChargeTypeID_FK            = @parameter_
                  , @description                        = @parameter_27
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END


             ELSE IF @ActionType = 'FINANCIALSETTLEMENTFORUSER'
            BEGIN
                        INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[FinancialAuditForUserSP]
                    @Action                             = @ActionType
                  , @ActionID                           = @parameter_22
                  , @residentInfoID                     = @parameter_02
                  , @Notes                              = null
                  , @buildingDetailsID                  = @parameter_05
                  , @LastActionID                       = @parameter_21
                  , @PaymentType                        = @parameter_12
                  --, @PaymentNo                          = @parameter_13
                  --, @PaymentDate                        = @parameter_14
                  , @Amount                             = @parameter_39
                  , @FullRemining                       = @parameter_09
                  , @BillChargeTypeID_FK                = @parameter_03
                  , @ToBillChargeTypeID_FK              = @parameter_30
                  , @description                        = @parameter_27
                  , @idaraID_FK                         = @idaraID
                  , @entryData                          = @entrydata
                  , @hostName                           = @hostName;

            END


           

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END







       ----------------------------------------------------------------
        -- Meters
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'Meters'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'INSERTNEWMETERTYPE'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = null
                    ,@meterTypeID_FK                       = null
                    ,@meterNo                              = null
                    ,@meterName_A                          = null
                    ,@meterName_E                          = null
                    ,@meterDescription                     = null
                    ,@meterStartDate                       = null
                    ,@meterEndDate                         = null
                    ,@meterServiceTypeID                   = @parameter_09
                    ,@meterTypeName_A                      = @parameter_10
                    ,@meterTypeName_E                      = @parameter_11
                    ,@meterTypeConversionFactor            = @parameter_13
                    ,@meterMaxRead                         = @parameter_14
                    ,@meterTypeStartDate                   = @parameter_15
                    ,@meterTypeEndDate                     = @parameter_16
                    ,@meterServicePrice                    = @parameter_17
                    ,@meterTypeDescription                 = @parameter_18
                    ,@MeterNote                            = null        
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           
                                                           
                                                           
            END



            ELSE IF @ActionType = 'UPDATENEWMETERTYPE'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = null
                    ,@meterTypeID_FK                       = @parameter_01
                    ,@meterNo                              = null
                    ,@meterName_A                          = null
                    ,@meterName_E                          = null
                    ,@meterDescription                     = null
                    ,@meterStartDate                       = null
                    ,@meterEndDate                         = null
                    ,@meterServiceTypeID                   = @parameter_02
                    ,@meterTypeName_A                      = @parameter_03
                    ,@meterTypeName_E                      = @parameter_04
                    ,@meterTypeConversionFactor            = @parameter_06
                    ,@meterMaxRead                         = @parameter_07
                    ,@meterTypeStartDate                   = @parameter_08
                    ,@meterTypeEndDate                     = @parameter_09
                    ,@meterServicePrice                    = @parameter_15
                    ,@meterTypeDescription                 = @parameter_18
                    ,@MeterNote                            = null        
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END
                  
               

                ELSE IF @ActionType = 'DELETENEWMETERTYPE'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterTypeID_FK                       = @parameter_01
                    ,@Notes							       = @parameter_18
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END
                  

             ELSE IF @ActionType = 'INSERTNEWMETER'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = null
                    ,@meterTypeID_FK                       = @parameter_02
                    ,@meterNo                              = @parameter_03
                    ,@meterName_A                          = @parameter_04
                    ,@meterName_E                          = @parameter_05
                    ,@meterDescription                     = @parameter_06
                    ,@meterStartDate                       = @parameter_07
                    --,@meterEndDate                         = null
                    ,@meterServiceTypeID                   = @parameter_40
                    ,@meterTypeName_A                      = null
                    ,@meterTypeName_E                      = null
                    ,@meterTypeConversionFactor            = null
                    ,@meterMaxRead                         = null
                    --,@meterTypeStartDate                   = null
                    --,@meterTypeEndDate                     = null
                    ,@meterServicePrice                    = null
                    ,@meterTypeDescription                 = null
                    ,@MeterNote                            = null
                    ,@Notes                                = null
                    ,@meterReadValue                       = @parameter_24
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END

               ELSE IF @ActionType = 'EDITNEWMETER'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = @parameter_01
                    ,@meterTypeID_FK                       = @parameter_02
                    ,@meterNo                              = @parameter_03
                    ,@meterName_A                          = @parameter_04
                    ,@meterName_E                          = @parameter_05
                    ,@meterDescription                     = @parameter_06
                    ,@meterStartDate                       = @parameter_07
                    --,@meterEndDate                         = null
                    ,@meterServiceTypeID                   = @parameter_40
                    ,@meterTypeName_A                      = null
                    ,@meterTypeName_E                      = null
                    ,@meterTypeConversionFactor            = null
                    ,@meterMaxRead                         = null
                    --,@meterTypeStartDate                   = null
                    --,@meterTypeEndDate                     = null
                    ,@meterServicePrice                    = null
                    ,@meterTypeDescription                 = null
                    ,@MeterNote                            = null
                    ,@Notes                                = null
                    ,@meterReadValue                       = @parameter_24
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END


                ELSE IF @ActionType = 'DELETENEWMETER'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = @parameter_01
                    ,@Notes                                = @parameter_45
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END

            
                ELSE IF @ActionType = 'LINKMETERTOBUILDINGS'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterID                              = @parameter_04
                    ,@buildingDetailsID_FK                 = @parameter_03
                    ,@Notes                                = @parameter_45
                    ,@meterReadValue                       = @parameter_24
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END

              ELSE IF @ActionType = 'UNLINKMETERTOBUILDINGS'
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MetersSP]
                     @Action                               = @ActionType
                    ,@meterForBuildingID                   = @parameter_01
                    ,@Notes                                = @parameter_45
                    ,@meterID                              = @parameter_02
                    ,@buildingDetailsID_FK                 = @parameter_03
                    ,@meterReadValue                       = @parameter_24
                    ,@buildingDetailsNo1                   = @parameter_10
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END

            

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END




       ----------------------------------------------------------------
        -- Meters
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'AllMeterRead'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'OPENMETERREADPERIOD'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AllMeterReadSP]
                     @Action                               = @ActionType
                    ,@MeterServiceTypeID                  = @parameter_01   
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           
                                                           
                                                           
            END



            ELSE IF @ActionType = 'CLOSEMETERREADPERIOD'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AllMeterReadSP]
                     @Action                               = @ActionType
                    ,@MeterServiceTypeID                   = @parameter_02
                    ,@billPeriodID                         = @parameter_01
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           
                                                           
                                                           
            END
                  
               

                ELSE IF @ActionType in( 'READELECTRICITYMETER','READWATERMETER','READGASMETER')
            BEGIN 
            
                     INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AllMeterReadSP]
                     @Action                               = @ActionType
                    ,@MeterServiceTypeID                   = @parameter_01
                    ,@meterID                              = @parameter_02
                    ,@billPeriodID                         = @parameter_03
                    ,@meterReadValue                       = @parameter_04
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;
                                                           

            END
                  

             ELSE IF @ActionType in(N'EDITELECTRICITYMETER',N'EDITWATERMETER',N'EDITGASMETER')
            BEGIN 
            
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AllMeterReadSP]
                     @Action                               = @ActionType
                    ,@MeterServiceTypeID                   = @parameter_41
                    ,@meterID                              = @parameter_05
                    ,@billPeriodID                         = @parameter_39
                    ,@meterReadValue                       = @parameter_10
                    ,@billsID                              = @parameter_01
                    ,@MeterReadID                          = @parameter_09
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;

            END


              ELSE IF @ActionType in(N'DELETEELECTRICITYMETER',N'DELETEWATERMETER',N'DELETEGASMETER')
            BEGIN 
            
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[AllMeterReadSP]
                     @Action                               = @ActionType
                    ,@MeterServiceTypeID                   = @parameter_41
                    ,@meterID                              = @parameter_05
                    ,@billPeriodID                         = @parameter_39
                    ,@meterReadValue                       = @parameter_10
                    ,@billsID                              = @parameter_01
                    ,@MeterReadID                          = @parameter_09
                    ,@IdaraId_FK                           = @idaraID
                    ,@entryData                            = @entrydata
                    ,@hostName                             = @hostName;

            END



            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END






        ----------------------------------------------------------------
        -- MeterReadForOccubentAndExit
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'HousingHandover'
        BEGIN
            IF (
                SELECT COUNT(*)
                FROM  dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata
                  AND v.menuName_E = @pageName_
                  --AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0;
                SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
                GOTO Finish;
            END

            DELETE FROM @Result;
                             


              IF @ActionType = 'HousingHandoverAction'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[HousingHandoverSP]
                    @Action                       = @ActionType
                  , @buildingDetailsID            = @parameter_01
                  , @buildingDetailsNo            = @parameter_02
                  , @LastActionTypeID             = @parameter_10
                  , @NextActionTypeID             = @parameter_07
                  , @LastActionID                 = @parameter_12
                  , @Notes                        = @parameter_11
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;

            END

            ELSE
            BEGIN
                SET @ok = 0;
                SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType1';
                GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



















        ----------------------------------------------------------------
        -- DO NOT TOUCH BELOW THIS LINE
        ----------------------------------------------------------------



-- ========================================
-- AI Chat History
-- ========================================
ELSE IF @pageName_ = N'AiChatHistory'
BEGIN
    IF @ActionType = N'SAVEAICHATHISTORY'
    BEGIN
        IF @tc = 0 AND XACT_STATE() = 1
            COMMIT;

        INSERT INTO dbo.AiChatHistory (
            UserId, UserQuestion, AiAnswer, PageKey, PageTitle, PageUrl,
            EntityKey, Intent, ResponseTimeMs, CitationsCount, IpAddress, IdaraID
        )
        VALUES (
            TRY_CONVERT(INT, @parameter_01),
            @parameter_02,
            @parameter_03,
            @parameter_04,
            @parameter_05,
            @parameter_06,
            @parameter_07,
            @parameter_08,
            TRY_CONVERT(INT, @parameter_09),
            TRY_CONVERT(INT, @parameter_10),
            @parameter_11,
            @idaraID
        );

        Declare @NewID BIGINT;
        SET @NewID = CAST(SCOPE_IDENTITY() AS BIGINT);

           BEGIN TRY
            EXEC dbo.sp_AiChat_UpdateFrequentQuestions @ChatId = @NewID;
        END TRY
        BEGIN CATCH
            -- لا نوقف حفظ المحادثة إذا فشل تحديث الأسئلة الشائعة
            -- (اختياري) سجل الخطأ في جدول ErrorLog عندك
        END CATCH

        SELECT 
            SCOPE_IDENTITY() AS ChatId,
            1 AS IsSuccessful,
            N'تم حفظ تاريخ المحادثة بنجاح' AS Message_;
        RETURN;
    END

    ELSE IF @ActionType = N'SAVEAICHATFEEDBACK'
    BEGIN
        IF @tc = 0 AND XACT_STATE() = 1
            COMMIT;

        UPDATE dbo.AiChatHistory
        SET UserFeedback = TRY_CONVERT(TINYINT, @parameter_01),
            FeedbackComment = @parameter_02,
            FeedbackDate = SYSUTCDATETIME()
        WHERE ChatId = TRY_CONVERT(BIGINT, @parameter_03);

        SELECT 1 AS IsSuccessful, N'تم حفظ التقييم' AS Message_;
        RETURN;
    END

    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية غير معروف';
        GOTO Finish;
    END
END

         ----------------------------------------------------------------
        -- DO NOT TOUCH
        ----------------------------------------------------------------

         
        ELSE
        BEGIN
            SET @ok = 0;
            SET @msg = N'الصفحة المرسلة مقيدة. PageName';
            GOTO Finish;
        END

Finish:
        IF ISNULL(@ok,0) = 0
        BEGIN
            IF @tc = 0 AND XACT_STATE() = 1 ROLLBACK;
            SELECT 0 AS IsSuccessful, ISNULL(@msg, N'فشل تنفيذ العملية') AS Message_;
            RETURN;
        END

        IF @tc = 0 AND XACT_STATE() = 1 COMMIT;

        IF @SendNotif = 1
        BEGIN
            BEGIN TRY
                EXEC dbo.Notifications_Create
                      @Title         = @NotifTitle
                    , @Body          = @NotifBody
                    , @Url           = @NotifUrl
                    , @StartDate     = @NotifStartDate
                    , @EndDate       = @NotifEndDate
                    , @UserID        = @NotifUserID
                    , @DistributorID = @NotifDistributorID
                    , @RoleID        = @NotifRoleID
                    , @DsdID         = @NotifDsdID
                    , @IdaraID       = @NotifIdaraID
                    , @MenuID        = @NotifMenuID
                    , @entryData     = @entrydata
                    , @hostName      = @hostName;
            END TRY
            BEGIN CATCH
                SELECT 0 AS IsSuccessful, ISNULL(@msg, N'فشل تنفيذ الاشعار') AS Message_;
            RETURN;
                -- تجاهل فشل الإشعار
            END CATCH
        END

        SELECT 1 AS IsSuccessful, @msg AS Message_;
        RETURN;

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrNumber INT = ERROR_NUMBER();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        DECLARE @IdCatch BIGINT = NULL;

        IF @tc = 0 AND XACT_STATE() <> 0
            ROLLBACK;

        ----------------------------------------------------------------
        -- ✅ أخطاء العميل (Business) لا نسجلها
        -- (أي رقم بين 50001 و 50999)
        ----------------------------------------------------------------
        IF @ErrNumber BETWEEN 50001 AND 50999
        BEGIN
            SELECT 0 AS IsSuccessful, @ErrMsg AS Message_;
            RETURN;
        END

        ----------------------------------------------------------------
        -- ✅ أخطاء برمجية/غير متوقعة: نسجلها ونرجع رمز
        ----------------------------------------------------------------
        BEGIN TRY
            INSERT INTO  dbo.ErrorLog
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
                , N'[dbo].[Masters_CRUD]'
                , @entrydata
                , @hostName
            );

            SET @IdCatch = SCOPE_IDENTITY();
        END TRY
        BEGIN CATCH
            SET @IdCatch = NULL;
        END CATCH

        IF @IdCatch IS NOT NULL
            SELECT 0 AS IsSuccessful,
                   N'حصل خطأ غير معروف رمز الخطأ : ' + CAST(@IdCatch AS NVARCHAR(200)) AS Message_;
        ELSE
            SELECT 0 AS IsSuccessful,
                   N'حصل خطأ غير معروف ولم يتم تسجيله في ErrorLog' AS Message_;
    END CATCH
END