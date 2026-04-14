
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
    DECLARE @NotifPermissionTypeID BIGINT = NULL;
    DECLARE @NotifPermissionTypeIDs NVARCHAR(500) = NULL;

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
        SET @NotifPermissionTypeID = NULL;
        SET @NotifPermissionTypeIDs = NULL;
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
                  , @userNote                        = @parameter_35
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
                  , @userNote                        = @parameter_35
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
                  , @ElectrictyService              = @parameter_19
                  , @WaterService                   = @parameter_20      
                  , @GasService                     = @parameter_21        
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
                  , @ElectrictyService              = @parameter_19
                  , @WaterService                   = @parameter_20      
                  , @GasService                     = @parameter_21  
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
                  , @ElectrictyService              = @parameter_19
                  , @WaterService                   = @parameter_20      
                  , @GasService                     = @parameter_21  
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

                    SET @NotifUserID                 = NULL;
                    SET @NotifDistributorID          = NULL;
                    SET @NotifRoleID                 = NULL;
                    SET @NotifDsdID                  = NULL;
                    SET @NotifPermissionTypeID       = NULL;
                    SET @NotifPermissionTypeIDs      = NULL;
                    SET @NotifIdaraID                = @parameter_12;
                    SET @NotifMenuID                 = 275;
                    SET @NotifStartDate              = NULL;
                    SET @NotifEndDate                = NULL;
                           
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


                    SET @NotifUserID                 = NULL;
                    SET @NotifDistributorID          = NULL;
                    SET @NotifRoleID                 = NULL;
                    SET @NotifDsdID                  = NULL;
                    SET @NotifPermissionTypeID       = NULL;
                    SET @NotifPermissionTypeIDs      = NULL;
                    SET @NotifIdaraID                = @parameter_10;
                    SET @NotifMenuID                 = 275;
                    SET @NotifStartDate              = NULL;
                    SET @NotifEndDate                = NULL;

                           

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

                    SET @NotifUserID                 = NULL;
                    SET @NotifDistributorID          = NULL;
                    SET @NotifRoleID                 = NULL;
                    SET @NotifDsdID                  = NULL;
                    SET @NotifIdaraID                = @parameter_09;
                    SET @NotifMenuID                 = 275;
                    SET @NotifPermissionTypeID       = NULL;
                    SET @NotifPermissionTypeIDs      = NULL;
                    SET @NotifStartDate              = NULL;
                    SET @NotifEndDate                = NULL;
               
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

                    SET @NotifUserID                 = NULL;
                    SET @NotifDistributorID          = NULL;
                    SET @NotifRoleID                 = NULL;
                    SET @NotifDsdID                  = NULL;
                    SET @NotifIdaraID                = @parameter_09;
                    SET @NotifMenuID                 = 273;
                    SET @NotifPermissionTypeID       = NULL;
                    SET @NotifPermissionTypeIDs      = NULL;
                    SET @NotifStartDate              = NULL;
                    SET @NotifEndDate                = NULL;
                           
               
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
                     , @WaitingClassID      = @parameter_21
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
                     , @WaitingClassID      = @parameter_21
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


                  if(cast(@parameter_22 as int) > 0)

                  begin
                  SET @SendNotif  = 1;
                  SET @NotifTitle = N'طلب قراءة عدادات جديد بإنتظار الانهاء ⚡';
                  SET @NotifBody  = N'طلب قراءة عدادات جديد للمستفيد '+@parameter_15+N' وارد بانتظار الانهاء اضغط هنا للاطلاع عليه ';
                  SET @NotifUrl   = N'/ElectronicBillSystem/MeterReadForOccubentAndExit';
                  
                  
                  SET @NotifUserID                 = NULL;
                  SET @NotifDistributorID          = NULL;
                  SET @NotifRoleID                 = NULL;
                  SET @NotifDsdID                  = NULL;
                  SET @NotifPermissionTypeID       = NULL;
                  SET @NotifPermissionTypeIDs      = NULL;
                  SET @NotifIdaraID                = @idaraID;
                  SET @NotifMenuID                 = 281;
                  SET @NotifStartDate              = NULL;
                  SET @NotifEndDate                = NULL;


                  END

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
                  , @MeterServiceTypeID           = @parameter_30
                  , @buildingActionRoot           = @parameter_31
                  , @NewMeterReadValue            = @parameter_27  
                  , @ExitDate                     = @parameter_29
                  , @BillsID                      = @parameter_32
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
                  , @BillsID                      = @parameter_32
                  , @buildingActionRoot           = @parameter_31
                  , @MeterServiceTypeID           = @parameter_30
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  
               
            END

             ELSE IF @ActionType = 'APPROVEMETERREADFOROCCUBENTANDEXIT'
            BEGIN
                      INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [Housing].[MeterReadForOccubentAndExitSP]
                    @Action                       = @ActionType
                  , @ActionID                     = @parameter_01
                  , @residentInfoID               = @parameter_02
                  , @NationalID                   = @parameter_03
                  , @GeneralNo                    = @parameter_04
                  , @buildingActionDecisionNo     = @parameter_05
                  , @buildingActionDecisionDate   = @parameter_46
                  , @WaitingClassID               = @parameter_07
                  , @WaitingClassName             = @parameter_08
                  , @WaitingOrderTypeID           = @parameter_09
                  , @WaitingOrderTypeName         = @parameter_10
                  , @Notes                        = @parameter_12
                  , @FullName_A                   = @parameter_15
                  , @buildingDetailsID            = @parameter_18
                  , @buildingDetailsNo            = @parameter_19
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @meterID                      = @parameter_23
                  , @NewMeterReadValue            = @parameter_27  
                  , @meterReadID                  = @parameter_28  
                  , @ExitDate                     = @parameter_29
                  , @BillsID                      = @parameter_32
                  , @buildingActionRoot           = @parameter_31
                  , @MeterServiceTypeID           = @parameter_30
                  , @idaraID_FK                   = @idaraID
                  , @entryData                    = @entrydata
                  , @hostName                     = @hostName;
                  

                  if(@parameter_31 = 1)
                  begin
                   SET @SendNotif  = 1;
                   SET @NotifTitle = N'تم قراءة العدادات ⚡';
                   SET @NotifBody  = N' تم قراءة العدادات للمستفيد '+@parameter_15+N' اضغط هنا للاطلاع عليه ';
                   SET @NotifUrl   = N'/Housing/HousingResident';
                   
                   
                   SET @NotifUserID                 = NULL;
                   SET @NotifDistributorID          = NULL;
                   SET @NotifRoleID                 = NULL;
                   SET @NotifDsdID                  = NULL;
                   SET @NotifPermissionTypeID       = NULL;
                   SET @NotifPermissionTypeIDs      = NULL;
                   SET @NotifIdaraID                = @idaraID;
                   SET @NotifMenuID                 = 279;
                   SET @NotifStartDate              = NULL;
                   SET @NotifEndDate                = NULL;
                   END


                   
                  if(@parameter_31 = 2)
                  begin
                   SET @SendNotif  = 1;
                   SET @NotifTitle = N'تم قراءة العدادات ⚡';
                   SET @NotifBody  = N' تم قراءة العدادات للمستفيد '+@parameter_15+N' اضغط هنا للاطلاع عليه ';
                   SET @NotifUrl   = N'/Housing/HousingExit?NID='+@parameter_03;
                   
                   
                   SET @NotifUserID                 = NULL;
                   SET @NotifDistributorID          = NULL;
                   SET @NotifRoleID                 = NULL;
                   SET @NotifDsdID                  = NULL;
                   SET @NotifPermissionTypeID       = NULL;
                   SET @NotifPermissionTypeIDs      = NULL;
                   SET @NotifIdaraID                = @idaraID;
                   SET @NotifMenuID                 = 285;
                   SET @NotifStartDate              = NULL;
                   SET @NotifEndDate                = NULL;
                   END
               
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
                  , @buildingDetailsNo            = @parameter_19
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
                  , @buildingDetailsNo            = @parameter_19
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
                  , @buildingDetailsNo            = @parameter_19
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
                  , @buildingDetailsNo            = @parameter_19
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




                   SET @SendNotif  = 1;
                   SET @NotifTitle = N'طلب تدقيق مالي جديد بإنتظار الانهاء  💵';
                   SET @NotifBody  = N'طلب تدقيق مالي جديد للمستفيد '+@parameter_15+N' وارد بانتظار الانهاء اضغط هنا للاطلاع عليه ';
                   SET @NotifUrl   = N'/IncomeSystem/FinancialAuditForExtendAndEvictions';


                   SET @NotifUserID                 = NULL;
                   SET @NotifDistributorID          = NULL;
                   SET @NotifRoleID                 = NULL;
                   SET @NotifDsdID                  = NULL;
                   SET @NotifPermissionTypeID       = NULL;
                   SET @NotifPermissionTypeIDs      = NULL;
                   SET @NotifIdaraID                = @idaraID;
                   SET @NotifMenuID                 = 284;
                   SET @NotifStartDate              = NULL;
                   SET @NotifEndDate                = NULL;

        


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
                  , @buildingDetailsNo            = @parameter_19
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
            

            
             ELSE IF @ActionType = 'EXTENDINSURANCE'
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
                  , @buildingDetailsNo            = @parameter_19
                  , @AssignPeriodID               = @parameter_20
                  , @LastActionID                 = @parameter_21
                  , @ExtendLetterDate             = @parameter_22
                  , @ExtendLetterNo               = @parameter_23
                  , @ExtendStartDate              = @parameter_24
                  , @ExtendEndDate                = @parameter_25
                  , @ExtendTypeID                 = @parameter_27
                  , @InsuranceAmount              = @parameter_30 
                  , @Remaining                    = @parameter_28 
                  , @InsuranceAmountWithRemaining = @parameter_31 
                  , @ExtendInsuranceNo            = @parameter_33 
                  , @ExtendInsuranceDate          = @parameter_35
                  , @ExtendInsuranceType          = @parameter_27
                  , @ExtendInsuranceNote          = @parameter_26
                  , @ExtendInsuranceTypeID        = @parameter_34
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



                   SET @SendNotif  = 1;
                   SET @NotifTitle = N'طلب تدقيق مالي جديد بإنتظار الانهاء  💵';
                   SET @NotifBody  = N'طلب تدقيق مالي جديد للمستفيد '+@parameter_15+N' وارد بانتظار الانهاء اضغط هنا للاطلاع عليه ';
                   SET @NotifUrl   = N'/IncomeSystem/FinancialAuditForExtendAndEvictions';


                   SET @NotifUserID                 = NULL;
                   SET @NotifDistributorID          = NULL;
                   SET @NotifRoleID                 = NULL;
                   SET @NotifDsdID                  = NULL;
                   SET @NotifPermissionTypeID       = NULL;
                   SET @NotifPermissionTypeIDs      = NULL;
                   SET @NotifIdaraID                = @idaraID;
                   SET @NotifMenuID                 = 284;
                   SET @NotifStartDate              = NULL;
                   SET @NotifEndDate                = NULL;

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

                  if(cast(@parameter_42 as int) > 0)

                  begin
                   SET @SendNotif  = 1;
                   SET @NotifTitle = N'طلب قراءة عدادات جديد بإنتظار الانهاء ⚡';
                   SET @NotifBody  = N'طلب قراءة عدادات جديد للمستفيد '+@parameter_15+N' وارد بانتظار الانهاء اضغط هنا للاطلاع عليه ';
                   SET @NotifUrl   = N'/ElectronicBillSystem/MeterReadForOccubentAndExit?U='+@parameter_02;


                   SET @NotifUserID                 = NULL;
                   SET @NotifDistributorID          = NULL;
                   SET @NotifRoleID                 = NULL;
                   SET @NotifDsdID                  = NULL;
                   SET @NotifPermissionTypeID       = NULL;
                   SET @NotifPermissionTypeIDs      = NULL;
                   SET @NotifIdaraID                = @idaraID;
                   SET @NotifMenuID                 = 281;
                   SET @NotifStartDate              = NULL;
                   SET @NotifEndDate                = NULL;

                END

            END

            ELSE IF @ActionType = 'APPROVEHOUSINGEXIT'
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


                  Declare @residentFullNameForFINANCIALAUDITFOREXTENDANDEVICTIONS nvarchar(2000),@residentNIDForFINANCIALAUDITFOREXTENDANDEVICTIONS nvarchar(2000)
                  set @residentFullNameForFINANCIALAUDITFOREXTENDANDEVICTIONS =
                  (
                  select r.FullName_A from Housing.V_GetFullResidentDetails r where r.residentInfoID = @parameter_02
                  )

                  set @residentNIDForFINANCIALAUDITFOREXTENDANDEVICTIONS =
                  (
                  select r.NationalID from Housing.V_GetFullResidentDetails r where r.residentInfoID = @parameter_02
                  )

                  if(@parameter_16 = 57)
                  BEGIN

                   

                SET @SendNotif  = 1;
                SET @NotifTitle = N'انتهاء التدقيق المالي 🎉';
                SET @NotifBody  = N'انتهى التدقيق المالي للمستفيد '+@residentFullNameForFINANCIALAUDITFOREXTENDANDEVICTIONS+N' اضغط هنا لانهاء اجراءات الاخلاء الان ';
                SET @NotifUrl   = N'/Housing/HousingExit?NID='+@residentNIDForFINANCIALAUDITFOREXTENDANDEVICTIONS;


                SET @NotifUserID                 = NULL;
                SET @NotifDistributorID          = NULL;
                SET @NotifRoleID                 = NULL;
                SET @NotifDsdID                  = NULL;
                SET @NotifPermissionTypeID       = NULL;
                SET @NotifPermissionTypeIDs      = NULL;
                SET @NotifIdaraID                = @idaraID;
                SET @NotifMenuID                 = 285;
                SET @NotifStartDate              = NULL;
                SET @NotifEndDate                = NULL;




                  END



                   if(@parameter_16 = 51)
                  BEGIN

                   

                SET @SendNotif  = 1;
                SET @NotifTitle = N'انتهاء التدقيق المالي 🎉';
                SET @NotifBody  = N'انتهى التدقيق المالي للمستفيد '+@residentFullNameForFINANCIALAUDITFOREXTENDANDEVICTIONS+N' اضغط هنا لانهاء اجراءات الامهال الان ';
                SET @NotifUrl   = N'/Housing/HousingExtend';


                SET @NotifUserID                 = NULL;
                SET @NotifDistributorID          = NULL;
                SET @NotifRoleID                 = NULL;
                SET @NotifDsdID                  = NULL;
                SET @NotifPermissionTypeID       = NULL;
                SET @NotifPermissionTypeIDs      = NULL;
                SET @NotifIdaraID                = @idaraID;
                SET @NotifMenuID                 = 285;
                SET @NotifStartDate              = NULL;
                SET @NotifEndDate                = NULL;




               END

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
        -- HousingHandover
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
          --نظام الدعم الفني للموقع 
----------------------------------------------------------------

       ----------------------------------------------------------------
        -- SupportMyTickets
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'SupportMyTickets'
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N'عفوا لاتملك صلاحية لهذه العملية'; GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'SMT_CREATE_TICKET'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [support].[SupportMyTicketsSP]
                      @Action             = @ActionType
                    , @ticketTypeID       = @parameter_01
                    , @priorityID         = @parameter_02
                    , @ticketTitle        = @parameter_03
                    , @ticketDescription  = @parameter_04
                    , @affectedPageName   = @parameter_05
                    , @affectedPageUrl    = @parameter_06
                    , @affectedActionName = @parameter_07
                    , @errorDetails       = @parameter_08
                    , @entryData          = @entrydata
                    , @hostName           = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0; SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType'; GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- SupportTicketDetails
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'SupportPhoneTickets'
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N'عفوا لاتملك صلاحية لهذه العملية'; GOTO Finish;
            END

            DELETE FROM @Result;

            IF @ActionType = 'SPT_CREATE_TICKET'
            BEGIN
                INSERT INTO @Result(IsSuccessful, Message_)
                EXEC [support].[SupportPhoneTicketsSP]
                      @Action             = @ActionType
                    , @ticketTypeID       = @parameter_01
                    , @priorityID         = @parameter_02
                    , @ticketTitle        = @parameter_03
                    , @ticketDescription  = @parameter_04
                    , @affectedPageName   = @parameter_05
                    , @affectedPageUrl    = @parameter_06
                    , @affectedActionName = @parameter_07
                    , @errorDetails       = @parameter_08
                    , @callerUserID       = @parameter_09
                    , @entryData          = @entrydata
                    , @hostName           = @hostName;
            END
            ELSE
            BEGIN
                SET @ok = 0; SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType'; GOTO Finish;
            END

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- SupportTicketDetails
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'SupportTicketDetails'
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N'عفوا لاتملك صلاحية لهذه العملية'; GOTO Finish;
            END

            DELETE FROM @Result;

            INSERT INTO @Result(IsSuccessful, Message_)
            EXEC [support].[SupportTicketDetailsSP]
                  @Action               = @ActionType
                , @ticketID             = @parameter_01
                , @replyText            = @parameter_02
                , @isInternal           = @parameter_03
                , @statusID             = @parameter_04
                , @assignToTeamMemberID = @parameter_05
                , @assignmentNote       = @parameter_06
                , @taskTitle            = @parameter_07
                , @taskDescription      = @parameter_08
                , @taskPriorityID       = @parameter_09
                , @taskAssignToMemberID = @parameter_10
                , @taskDueDate          = @parameter_11
                , @taskID               = @parameter_12
                , @taskStatusID         = @parameter_13
                , @entryData            = @entrydata
                , @hostName             = @hostName;

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- SupportInbox
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'SupportInbox'
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N'عفوا لاتملك صلاحية لهذه العملية'; GOTO Finish;
            END

            DELETE FROM @Result;

            INSERT INTO @Result(IsSuccessful, Message_)
            EXEC [support].[SupportInboxSP]
                  @Action               = @ActionType
                , @ticketID             = @parameter_01
                , @statusID             = @parameter_02
                , @assignToTeamMemberID = @parameter_03
                , @assignmentNote       = @parameter_04
                , @ticketIDsCsv         = @parameter_05
                , @entryData            = @entrydata
                , @hostName             = @hostName;

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END

        ----------------------------------------------------------------
        -- SupportTeamManagement
        ----------------------------------------------------------------
        ELSE IF @pageName_ = 'SupportTeamManagement'
        BEGIN
            IF (
                SELECT COUNT(*) FROM dbo.V_GetListUserPermission v
                WHERE v.userID = @entrydata AND v.menuName_E = @pageName_ AND v.permissionTypeName_E = @ActionType
            ) <= 0
            BEGIN
                SET @ok = 0; SET @msg = N'عفوا لاتملك صلاحية لهذه العملية'; GOTO Finish;
            END

            DELETE FROM @Result;

            INSERT INTO @Result(IsSuccessful, Message_)
            EXEC [support].[SupportTeamManagementSP]
                  @Action            = @ActionType
                , @teamMemberID      = @parameter_01
                , @userID            = @parameter_02
                , @canReceiveTickets = @parameter_03
                , @canAssignTickets  = @parameter_04
                , @memberActive      = @parameter_05
                , @teamMemberRoleID  = @parameter_06
                , @roleID            = @parameter_07
                , @entryData         = @entrydata
                , @hostName          = @hostName;

            SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result;
            GOTO Finish;
        END



----------------------------------------------------------------
          --العربات 
----------------------------------------------------------------
        ----------------------------------------------------------------
-- Custody_Close
----------------------------------------------------------------
ELSE IF @pageName_ = 'Custody_Close'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[Custody_Close_SP]
              @vehicleWithUsersID = @parameter_01
            , @endDate            = @parameter_02
            , @note               = @parameter_03
            , @entryData          = @entrydata
            , @hostName           = @hostName
            , @idaraID_FK         = @idaraID;
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
-- Custody_Create
----------------------------------------------------------------
ELSE IF @pageName_ = 'Custody_Create'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    DECLARE @Result_CustodyCreate TABLE
    (
          IsSuccessful       INT
        , Message_           NVARCHAR(4000)
        , vehicleWithUsersID INT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_CustodyCreate(IsSuccessful, Message_, vehicleWithUsersID)
        EXEC [VIC].[Custody_Create_SP]
              @chassisNumber = @parameter_01
            , @userID_FK      = @parameter_02
            , @startDate      = @parameter_03
            , @note           = @parameter_04
            , @entryData      = @entrydata
            , @hostName       = @hostName
            , @idaraID_FK     = @idaraID;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_CustodyCreate;
    GOTO Finish;
END

----------------------------------------------------------------
-- Custody_Transfer
----------------------------------------------------------------
ELSE IF @pageName_ = 'Custody_Transfer'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    DECLARE @Result_CustodyTransfer TABLE
    (
          IsSuccessful             INT
        , Message_                 NVARCHAR(4000)
        , ClosedVehicleWithUsersID INT
        , NewVehicleWithUsersID    INT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_CustodyTransfer(IsSuccessful, Message_, ClosedVehicleWithUsersID, NewVehicleWithUsersID)
        EXEC [VIC].[Custody_Transfer_SP]
              @chassisNumber = @parameter_01
            , @toUserID_FK    = @parameter_02
            , @transferDate   = @parameter_03
            , @note           = @parameter_04
            , @entryData      = @entrydata
            , @hostName       = @hostName
            , @idaraID_FK     = @idaraID;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_CustodyTransfer;
    GOTO Finish;
END

----------------------------------------------------------------
-- Handover_Create
----------------------------------------------------------------
ELSE IF @pageName_ = 'Handover_Create'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[Handover_Create_SP]
              @requestID      = @parameter_01
            , @handoverTypeID = @parameter_02
            , @handoverDate   = @parameter_03
            , @note           = @parameter_04
            , @idaraID_FK     = @idaraID
            , @entryData      = @entrydata
            , @hostName       = @hostName;
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
-- HandoverType
----------------------------------------------------------------
ELSE IF @pageName_ = 'HandoverType'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[HandoverType_Upsert_SP]
              @handoverTypeID     = NULL
            , @handoverTypeName_A = @parameter_01
            , @handoverTypeName_E = @parameter_02
            , @active             = @parameter_03
            , @entryData          = @entrydata
            , @hostName           = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[HandoverType_Upsert_SP]
              @handoverTypeID     = @parameter_01
            , @handoverTypeName_A = @parameter_02
            , @handoverTypeName_E = @parameter_03
            , @active             = @parameter_04
            , @entryData          = @entrydata
            , @hostName           = @hostName;
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
-- MaintenanceDetails_Delete
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceDetails_Delete'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'DELETE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceDetails_Delete_SP]
              @maintDetailesID = @parameter_01
            , @idaraID_FK      = @idaraID
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
-- MaintenanceTemplate_Delete
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceTemplate_Delete'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'DELETE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceTemplate_Delete_SP]
              @TemplateID = @parameter_01
            , @entryData  = @entrydata
            , @hostName   = @hostName;
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
-- MaintenanceTemplate_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceTemplate_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[MaintenanceTemplate_Upsert_SP]
              @TemplateID        = NULL
            , @MaintOrdTypeID_FK = @parameter_01
            , @typesID_FK        = @parameter_02
            , @TemplateOrder     = @parameter_03
            , @active            = @parameter_04
            , @entryData         = @entrydata
            , @hostName          = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceTemplate_Upsert_SP]
              @TemplateID        = @parameter_01
            , @MaintOrdTypeID_FK = @parameter_02
            , @typesID_FK        = @parameter_03
            , @TemplateOrder     = @parameter_04
            , @active            = @parameter_05
            , @entryData         = @entrydata
            , @hostName          = @hostName;
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
-- MaintenanceDetails_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceDetails_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[MaintenanceDetails_Upsert_SP]
              @maintDetailesID  = NULL
            , @maintOrdID       = @parameter_01
            , @typesID          = @parameter_02
            , @supportID        = @parameter_03
            , @checkStatus      = @parameter_04
            , @actionState      = @parameter_05
            , @correctiveAction = @parameter_06
            , @fsn              = @parameter_07
            , @maintLevel       = @parameter_08
            , @currentDate      = @parameter_09
            , @notes            = @parameter_10
            , @idaraID_FK       = @idaraID
            , @entryData        = @entrydata
            , @hostName         = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceDetails_Upsert_SP]
              @maintDetailesID  = @parameter_01
            , @maintOrdID       = @parameter_02
            , @typesID          = @parameter_03
            , @supportID        = @parameter_04
            , @checkStatus      = @parameter_05
            , @actionState      = @parameter_06
            , @correctiveAction = @parameter_07
            , @fsn              = @parameter_08
            , @maintLevel       = @parameter_09
            , @currentDate      = @parameter_10
            , @notes            = @parameter_11
            , @idaraID_FK       = @idaraID
            , @entryData        = @entrydata
            , @hostName         = @hostName;
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
-- MaintenanceOrder_Close
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceOrder_Close'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceOrder_Close_SP]
              @maintOrdID = @parameter_01
            , @endDate    = @parameter_02
            , @idaraID_FK = @idaraID
            , @entryData  = @entrydata
            , @hostName   = @hostName;
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
-- MaintenanceOrder_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenanceOrder_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[MaintenanceOrder_Upsert_SP]
              @maintOrdID     = NULL
            , @maintOrdTypeID = @parameter_01
            , @chassisNumber  = @parameter_02
            , @startDate      = @parameter_03
            , @endDate        = @parameter_04
            , @desc           = @parameter_05
            , @active         = @parameter_06
            , @idaraID_FK     = @idaraID
            , @entryData      = @entrydata
            , @hostName       = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenanceOrder_Upsert_SP]
              @maintOrdID     = @parameter_01
            , @maintOrdTypeID = @parameter_02
            , @chassisNumber  = @parameter_03
            , @startDate      = @parameter_04
            , @endDate        = @parameter_05
            , @desc           = @parameter_06
            , @active         = @parameter_07
            , @idaraID_FK     = @idaraID
            , @entryData      = @entrydata
            , @hostName       = @hostName;
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
-- MaintenancePlan_AutoGenerate
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenancePlan_AutoGenerate'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[MaintenancePlan_AutoGenerate_SP]
              @idaraID_FK = @idaraID
            , @entryData  = @entrydata
            , @hostName   = @hostName;
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
-- MaintenancePlan_SetActive
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenancePlan_SetActive'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenancePlan_SetActive_SP]
              @planID      = @parameter_01
            , @active      = @parameter_02
            , @idaraID_FK  = @idaraID
            , @entryData   = @entrydata
            , @hostName    = @hostName;
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
-- MaintenancePlan_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'MaintenancePlan_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[MaintenancePlan_Upsert_SP]
              @planID        = NULL
            , @chassisNumber = @parameter_01
            , @periodMonths  = @parameter_02
            , @nextDueDate   = @parameter_03
            , @active        = @parameter_04
            , @idaraID_FK    = @idaraID
            , @entryData     = @entrydata
            , @hostName      = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[MaintenancePlan_Upsert_SP]
              @planID        = @parameter_01
            , @chassisNumber = @parameter_02
            , @periodMonths  = @parameter_03
            , @nextDueDate   = @parameter_04
            , @active        = @parameter_05
            , @idaraID_FK    = @idaraID
            , @entryData     = @entrydata
            , @hostName      = @hostName;
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
-- Scrap_Action
----------------------------------------------------------------
ELSE IF @pageName_ = 'Scrap_Action'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType IN ('APPROVE', 'CANCEL')
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[Scrap_Action_SP]
              @Action         = @ActionType
            , @ScrapID        = @parameter_01
            , @idaraID_FK     = @idaraID
            , @actionByUserID = @parameter_02
            , @actionNote     = @parameter_03
            , @entryData      = @entrydata
            , @hostName       = @hostName;
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
-- Scrap_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'Scrap_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
        WHERE v.userID = @entrydata
          AND v.menuName_E = @pageName_
          AND v.permissionTypeName_E = @ActionType
    ) <= 0
    BEGIN
        SET @ok = 0;
        SET @msg = N'عفوا لاتملك صلاحية لهذه العملية';
        GOTO Finish;
    END

    DECLARE @Result_ScrapUpsert TABLE
    (
          IsSuccessful INT
        , Message_     NVARCHAR(4000)
        , ScrapID      BIGINT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_ScrapUpsert(IsSuccessful, Message_, ScrapID)
        EXEC [VIC].[Scrap_Upsert_SP]
              @ScrapID        = NULL
            , @chassisNumber  = @parameter_01
            , @idaraID_FK     = @idaraID
            , @ScrapDate      = @parameter_02
            , @ScrapTypeID_FK = @parameter_03
            , @RefNo          = @parameter_04
            , @Reason         = @parameter_05
            , @Note           = @parameter_06
            , @Notes          = @parameter_07
            , @entryData      = @entrydata
            , @hostName       = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result_ScrapUpsert(IsSuccessful, Message_, ScrapID)
        EXEC [VIC].[Scrap_Upsert_SP]
              @ScrapID        = @parameter_01
            , @chassisNumber  = @parameter_02
            , @idaraID_FK     = @idaraID
            , @ScrapDate      = @parameter_03
            , @ScrapTypeID_FK = @parameter_04
            , @RefNo          = @parameter_05
            , @Reason         = @parameter_06
            , @Note           = @parameter_07
            , @Notes          = @parameter_08
            , @entryData      = @entrydata
            , @hostName       = @hostName;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_
    FROM @Result_ScrapUpsert;

    GOTO Finish;
END


----------------------------------------------------------------
-- TransferRequest_Approve
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Approve'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TransferRequest_Approve_SP]
              @requestID  = @parameter_01
            , @actionBy   = @parameter_02
            , @note       = @parameter_03
            , @hostName   = @hostName
            , @idaraID_FK = @idaraID;
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
-- TransferRequest_Cancel
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Cancel'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'DELETE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TransferRequest_Cancel_SP]
              @requestID  = @parameter_01
            , @actionBy   = @parameter_02
            , @note       = @parameter_03
            , @hostName   = @hostName
            , @idaraID_FK = @idaraID;
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
-- TransferRequest_Close
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Close'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'CLOSE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TransferRequest_Close_SP]
              @requestID  = @parameter_01
            , @actionBy   = @parameter_02
            , @note       = @parameter_03
            , @hostName   = @hostName
            , @idaraID_FK = @idaraID;
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
-- TransferRequest_Create
----------------------------------------------------------------
----------------------------------------------------------------
-- TransferRequest_Create
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Create'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    DECLARE @Result_TransferRequest_Create TABLE
    (
          IsSuccessful INT
        , Message_     NVARCHAR(4000)
        , RequestID    INT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_TransferRequest_Create(IsSuccessful, Message_, RequestID)
        EXEC [VIC].[TransferRequest_Create_SP]
              @requestTypeID = @parameter_01
            , @chassisNumber = @parameter_02
            , @fromUserID    = @parameter_03
            , @toUserID      = @parameter_04
            , @deptID        = @parameter_05
            , @createByUser  = @parameter_06
            , @note          = @parameter_07
            , @idaraID_FK    = @idaraID
            , @entryData     = @entrydata
            , @hostName      = @hostName;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_TransferRequest_Create;
    GOTO Finish;
END

----------------------------------------------------------------
-- TransferRequest_Execute
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Execute'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    DECLARE @Result_TransferRequest_Execute TABLE
    (
          IsSuccessful       INT
        , Message_           NVARCHAR(4000)
        , vehicleWithUsersID INT
    );

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result_TransferRequest_Execute(IsSuccessful, Message_, vehicleWithUsersID)
        EXEC [VIC].[TransferRequest_Execute_SP]
              @requestID  = @parameter_01
            , @entryData  = @entrydata
            , @hostName   = @hostName
            , @idaraID_FK = @idaraID
            , @note       = @parameter_02;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_TransferRequest_Execute;
    GOTO Finish;
END

----------------------------------------------------------------
-- TransferRequest_Reject
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequest_Reject'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TransferRequest_Reject_SP]
              @requestID  = @parameter_01
            , @actionBy   = @parameter_02
            , @note       = @parameter_03
            , @hostName   = @hostName
            , @idaraID_FK = @idaraID;
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
-- TransferRequestType
----------------------------------------------------------------
ELSE IF @pageName_ = 'TransferRequestType'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[TransferRequestType_Upsert_SP]
              @vehicleTransferRequestTypeID = NULL
            , @nameA                        = @parameter_01
            , @nameE                        = @parameter_02
            , @active                       = @parameter_03;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TransferRequestType_Upsert_SP]
              @vehicleTransferRequestTypeID = @parameter_01
            , @nameA                        = @parameter_02
            , @nameE                        = @parameter_03
            , @active                       = @parameter_04;
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
-- TypesRoot_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'TypesRoot_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[TypesRoot_Upsert_SP]
              @typesID            = NULL
            , @typesName_A        = @parameter_01
            , @typesName_E        = @parameter_02
            , @typesDesc          = @parameter_03
            , @typesActive        = @parameter_04
            , @typesStartDate     = @parameter_05
            , @typesEndDate       = @parameter_06
            , @typesRoot_ParentID = @parameter_07
            , @entryData          = @entrydata
            , @hostName           = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[TypesRoot_Upsert_SP]
              @typesID            = @parameter_01
            , @typesName_A        = @parameter_02
            , @typesName_E        = @parameter_03
            , @typesDesc          = @parameter_04
            , @typesActive        = @parameter_05
            , @typesStartDate     = @parameter_06
            , @typesEndDate       = @parameter_07
            , @typesRoot_ParentID = @parameter_08
            , @entryData          = @entrydata
            , @hostName           = @hostName;
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
-- Vehicle_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'Vehicle_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    -- ملاحظة: VIC.Vehicle_Upsert_SP يرجّع 3 أعمدة (IsSuccessful, Message_, chassisNumber)
    DECLARE @Result_VehicleUpsert TABLE
    (
          IsSuccessful  INT
        , Message_      NVARCHAR(4000)
        , chassisNumber NVARCHAR(100)
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_VehicleUpsert(IsSuccessful, Message_, chassisNumber)
        EXEC [VIC].[Vehicle_Upsert_SP]
              @UsersID               = @entrydata
            , @MenuLink              = NULL
            , @SkipPermission        = 1
            , @chassisNumber         = @parameter_01
            , @ownerID_FK            = @parameter_02
            , @ManufacturerNameID_FK = @parameter_03
            , @vehicleModelID_FK     = @parameter_04
            , @vehicleClassID_FK     = @parameter_05
            , @TypeOfUseID_FK        = @parameter_06
            , @vehicleColorID_FK     = @parameter_07
            , @countryMadeID_FK      = @parameter_08
            , @regstritionTypeID_FK  = @parameter_09
            , @regionID_FK           = @parameter_10
            , @fuelTypeID_FK         = @parameter_11
            , @vehicleTypeID_FK      = @parameter_12
            , @yearModel             = @parameter_13
            , @capacity              = @parameter_14
            , @serialNumber          = @parameter_15
            , @plateLetters          = @parameter_16
            , @plateNumbers          = @parameter_17
            , @armyNumber            = @parameter_18
            , @vehicleNote           = @parameter_19
            , @idaraID_FK            = @idaraID
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result_VehicleUpsert(IsSuccessful, Message_, chassisNumber)
        EXEC [VIC].[Vehicle_Upsert_SP]
              @UsersID               = @entrydata
            , @MenuLink              = NULL
            , @SkipPermission        = 1
            , @chassisNumber         = @parameter_01
            , @ownerID_FK            = @parameter_02
            , @ManufacturerNameID_FK = @parameter_03
            , @vehicleModelID_FK     = @parameter_04
            , @vehicleClassID_FK     = @parameter_05
            , @TypeOfUseID_FK        = @parameter_06
            , @vehicleColorID_FK     = @parameter_07
            , @countryMadeID_FK      = @parameter_08
            , @regstritionTypeID_FK  = @parameter_09
            , @regionID_FK           = @parameter_10
            , @fuelTypeID_FK         = @parameter_11
            , @vehicleTypeID_FK      = @parameter_12
            , @yearModel             = @parameter_13
            , @capacity              = @parameter_14
            , @serialNumber          = @parameter_15
            , @plateLetters          = @parameter_16
            , @plateNumbers          = @parameter_17
            , @armyNumber            = @parameter_18
            , @vehicleNote           = @parameter_19
            , @idaraID_FK            = @idaraID
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_VehicleUpsert;
    GOTO Finish;
END

----------------------------------------------------------------
-- VehicleDocument_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'VehicleDocument_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    -- ملاحظة: VIC.VehicleDocument_Upsert_SP يرجّع 3 أعمدة (IsSuccessful, Message_, vehicleDocumentID)
    DECLARE @Result_VehicleDocument TABLE
    (
          IsSuccessful      INT
        , Message_          NVARCHAR(4000)
        , vehicleDocumentID INT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_VehicleDocument(IsSuccessful, Message_, vehicleDocumentID)
        EXEC [VIC].[VehicleDocument_Upsert_SP]
              @vehicleDocumentID     = NULL
            , @chassisNumber         = @parameter_01
            , @vehicleDocumentTypeID = @parameter_02
            , @vehicleDocumentNo     = @parameter_03
            , @StartDate             = @parameter_04
            , @EndDate               = @parameter_05
            , @idaraID_FK            = @idaraID
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result_VehicleDocument(IsSuccessful, Message_, vehicleDocumentID)
        EXEC [VIC].[VehicleDocument_Upsert_SP]
              @vehicleDocumentID     = @parameter_01
            , @chassisNumber         = @parameter_02
            , @vehicleDocumentTypeID = @parameter_03
            , @vehicleDocumentNo     = @parameter_04
            , @StartDate             = @parameter_05
            , @EndDate               = @parameter_06
            , @idaraID_FK            = @idaraID
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_VehicleDocument;
    GOTO Finish;
END

----------------------------------------------------------------
-- VehicleDocumentType_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'VehicleDocumentType_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    -- ملاحظة: VIC.VehicleDocumentType_Upsert_SP يرجّع 3 أعمدة (IsSuccessful, Message_, vehicleDocumentTypeID)
    DECLARE @Result_VehicleDocumentType TABLE
    (
          IsSuccessful           INT
        , Message_               NVARCHAR(4000)
        , vehicleDocumentTypeID  INT
    );

    IF @ActionType = 'INSERT'
    BEGIN
        INSERT INTO @Result_VehicleDocumentType(IsSuccessful, Message_, vehicleDocumentTypeID)
        EXEC [VIC].[VehicleDocumentType_Upsert_SP]
              @vehicleDocumentTypeID = NULL
            , @NameA                 = @parameter_01
            , @NameE                 = @parameter_02
            , @Active                = @parameter_03
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result_VehicleDocumentType(IsSuccessful, Message_, vehicleDocumentTypeID)
        EXEC [VIC].[VehicleDocumentType_Upsert_SP]
              @vehicleDocumentTypeID = @parameter_01
            , @NameA                 = @parameter_02
            , @NameE                 = @parameter_03
            , @Active                = @parameter_04
            , @entryData             = @entrydata
            , @hostName              = @hostName;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1 @ok = IsSuccessful, @msg = Message_ FROM @Result_VehicleDocumentType;
    GOTO Finish;
END

----------------------------------------------------------------
-- VehicleInsurance_SetActive
----------------------------------------------------------------
ELSE IF @pageName_ = 'VehicleInsurance_SetActive'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'SETACTIVE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[VehicleInsurance_SetActive_SP]
              @VehicleInsuranceID = @parameter_01
            , @active             = @parameter_02
            , @idaraID_FK          = @idaraID
            , @entryData           = @entrydata
            , @hostName            = @hostName;
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
-- VehicleInsurance_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'VehicleInsurance_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'UPSERT'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[VehicleInsurance_Upsert_SP]
              @VehicleInsuranceID = @parameter_01
            , @chassisNumber      = @parameter_02
            , @OperationTypeID    = @parameter_03
            , @InsuranceTypeID    = @parameter_04
            , @Source             = @parameter_05
            , @StartInsurance     = @parameter_06
            , @EndInsurance       = @parameter_07
            , @Amount             = @parameter_08
            , @Note               = @parameter_09
            , @active             = @parameter_10
            , @idaraID_FK          = @idaraID
            , @entryData           = @entrydata
            , @hostName            = @hostName;
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
-- VehicleScrap_Approve
----------------------------------------------------------------
ELSE IF @pageName_ = 'VehicleScrap_Approve'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'APPROVE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[VehicleScrap_Approve_SP]
              @ScrapID          = @parameter_01
            , @ApprovedByUserID = @parameter_02
            , @ApprovedDate     = @parameter_03
            , @entryData        = @entrydata
            , @hostName         = @hostName
            , @idaraID_FK        = @idaraID;
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
-- Violation_SetPayment
----------------------------------------------------------------
ELSE IF @pageName_ = 'Violation_SetPayment'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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

    IF @ActionType = 'PAYMENT'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[Violation_SetPayment_SP]
              @violationID  = @parameter_01
            , @PaymentDate  = @parameter_02
            , @entryPayment = @entrydata
            , @hostName     = @hostName
            , @idaraID_FK   = @idaraID;
    END
    ELSE
    BEGIN
        SET @ok = 0;
        SET @msg = N'نوع العملية المطلوبة غير معروف. ActionType';
        GOTO Finish;
    END

    SELECT TOP 1
          @ok  = IsSuccessful
        , @msg = Message_
    FROM @Result;

    GOTO Finish;
END
----------------------------------------------------------------
-- Violation_Upsert
----------------------------------------------------------------
ELSE IF @pageName_ = 'Violation_Upsert'
BEGIN
    IF (
        SELECT COUNT(*)
        FROM DATACORE.dbo.V_GetListUserPermission v
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
        EXEC [VIC].[Violation_Upsert_SP]
              @violationID       = NULL
            , @violationTypeID   = @parameter_01
            , @chassisNumber     = @parameter_02
            , @violationDate     = @parameter_03
            , @violationPrice    = @parameter_04
            , @violationLocation = @parameter_05
            , @idaraID_FK        = @idaraID
            , @entryData         = @entrydata
            , @hostName          = @hostName;
    END
    ELSE IF @ActionType = 'UPDATE'
    BEGIN
        INSERT INTO @Result(IsSuccessful, Message_)
        EXEC [VIC].[Violation_Upsert_SP]
              @violationID       = @parameter_01
            , @violationTypeID   = @parameter_02
            , @chassisNumber     = @parameter_03
            , @violationDate     = @parameter_04
            , @violationPrice    = @parameter_05
            , @violationLocation = @parameter_06
            , @idaraID_FK        = @idaraID
            , @entryData         = @entrydata
            , @hostName          = @hostName;
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
                      @Title             = @NotifTitle
                    , @Body              = @NotifBody
                    , @Url               = @NotifUrl
                    , @StartDate         = @NotifStartDate
                    , @EndDate           = @NotifEndDate
                    , @UserID            = @NotifUserID
                    , @DistributorID     = @NotifDistributorID
                    , @RoleID            = @NotifRoleID
                    , @DsdID             = @NotifDsdID
                    , @PermissionTypeID  = @NotifPermissionTypeID
                    , @PermissionTypeIDs = @NotifPermissionTypeIDs
                    , @IdaraID           = @NotifIdaraID
                    , @MenuID            = @NotifMenuID
                    , @entryData         = @entrydata
                    , @hostName          = @hostName;
            END TRY
            BEGIN CATCH
            --    SELECT 0 AS IsSuccessful, ISNULL(@msg, N'فشل تنفيذ الاشعار') AS Message_;
            --RETURN;
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