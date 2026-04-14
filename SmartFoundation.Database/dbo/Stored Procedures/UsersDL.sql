-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[UsersDL] 
	-- Add the parameters for the stored procedure here
	  @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
 Declare @isAdmin int;
        Set @isAdmin =(select top(1) 
        
        isnull(ud.usersAuthTypeID_FK,3) 
        
        from dbo.Users s
        Left JOIN  dbo.UsersDetails ud ON s.usersID = ud.usersID_FK
        left Join  dbo.UsersAuthType ua on ud.usersAuthTypeID_FK = ua.UsersAuthTypeID
        
        where s.usersActive = 1 
        and s.usersID = @entrydata 
        and ud.userActive = 1
        order by s.usersID desc)





         IF (@isAdmin = 1)
BEGIN
    SELECT 
        d.usersID,
        d.nationalID,
        d.GeneralNo,
        d.FullName,
        d.firstName_A,
        d.secondName_A,
        d.thirdName_A,
        d.lastName_A,
        d.firstName_E,
        d.secondName_E,
        d.thirdName_E,
        d.lastName_E,
        d.UsersAuthTypeID,
        d.UsersAuthTypeName_A,
        d.ActiveStatus,
        d.InactiveReason,
        d.userTypeName_A,
        d.userTypeID_FK,
        d.userActive,
        d.IdaraID,
        d.idaraLongName_A,
        d.EntryFullName,
        d.entryDateText AS entryDate,
        d.nationalIDIssueDate,
        d.dateOfBirth,
        d.genderID_FK,
        d.nationalityID_FK,
        d.religionID_FK,
        d.maritalStatusID_FK,
        d.educationID_FK
    FROM [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
    ORDER BY d.usersID DESC, d.entryDate DESC;
END 

        ELSE IF (@isAdmin = 2)
BEGIN
    SELECT
        d.usersID,
        d.nationalID,
        d.GeneralNo,
        d.FullName,
        d.firstName_A,
        d.secondName_A,
        d.thirdName_A,
        d.lastName_A,
        d.firstName_E,
        d.secondName_E,
        d.thirdName_E,
        d.lastName_E,
        d.UsersAuthTypeID,
        d.UsersAuthTypeName_A,
        d.ActiveStatus,
        d.InactiveReason,
        d.userTypeName_A,
        d.userTypeID_FK,
        d.userActive,
        d.IdaraID,
        d.idaraLongName_A,
        d.EntryFullName,
        d.entryDateText AS entryDate,
        d.nationalIDIssueDate,
        d.dateOfBirth,
        d.genderID_FK,
        d.nationalityID_FK,
        d.religionID_FK,
        d.maritalStatusID_FK,
        d.educationID_FK
    FROM [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
    WHERE d.IdaraID = @idaraID
    ORDER BY d.usersID DESC;
END

         IF (@isAdmin = 3)
BEGIN
    SELECT
        d.usersID,
        d.nationalID,
        d.GeneralNo,
        d.FullName,
        d.firstName_A,
        d.secondName_A,
        d.thirdName_A,
        d.lastName_A,
        d.firstName_E,
        d.secondName_E,
        d.thirdName_E,
        d.lastName_E,
        d.UsersAuthTypeID,
        d.UsersAuthTypeName_A,
        d.ActiveStatus,
        d.InactiveReason,
        d.userTypeName_A,
        d.userTypeID_FK,
        d.userActive,
        d.IdaraID,
        d.idaraLongName_A,
        d.EntryFullName,
        d.entryDateText AS entryDate,
        d.nationalIDIssueDate,
        d.dateOfBirth,
        d.genderID_FK,
        d.nationalityID_FK,
        d.religionID_FK,
        d.maritalStatusID_FK,
        d.educationID_FK
    FROM [DATACORE].[dbo].[V_GetFullSystemUsersDetails] d
    WHERE d.IdaraID = @idaraID
    ORDER BY d.usersID DESC;
END
           



            if(@isAdmin = 1)
        Begin
          Select i.idaraID,i.idaraLongName_A from dbo.Idara i
        END

        ELSE if(@isAdmin = 2)
        Begin
            Select i.idaraID,i.idaraLongName_A from dbo.Idara i
           where  i.IdaraID = @idaraID
        END

         ELSE if(@isAdmin = 3)
        Begin
            Select i.idaraID,i.idaraLongName_A from dbo.Idara i
           where  i.IdaraID = @idaraID
        END
           



           
            if(@isAdmin = 1)
        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1

           END
           else if(@isAdmin = 2)
        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1 and ua.UsersAuthTypeID in (2,3)

           END
           else if(@isAdmin = 3)

        Begin

           select ua.UsersAuthTypeID,ua.UsersAuthTypeName_A from dbo.UsersAuthType ua where ua.UsersAuthTypeActive = 1 and ua.UsersAuthTypeID in (2,3)

           END


           select t.userTypeID,t.userTypeName_A from dbo.UserType t where t.userTypeActive =1


           select g.genderID,g.genderName_A from dbo.Gender g 

           select n.nationalityID,n.nationalityName_A from dbo.Nationality n where n.nationalityActive = 1

           select n.religionID,n.religionName_A from dbo.Religion n where n.religionActive = 1

           select n.maritalStatusID,n.maritalStatusName_A from dbo.MaritalStatus n where n.maritalStatusActive = 1

           select n.educationID,n.educationName_A from dbo.Education n where n.educationActive = 1

           select @isAdmin isAdmin

            if(@isAdmin = 1)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null 
        END

        ELSE if(@isAdmin = 2)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null and d.IdaraID = @idaraID
        END

         ELSE if(@isAdmin = 3)
        Begin
            select r.distributorName_A,r.distributorID,d.IdaraID
           from dbo.V_GetFullStructureForDSD d
           inner join dbo.Distributor r on d.DSDID = r.DSDID_FK and r.distributorType_FK = 1 and d.DSDLevel = 3
           where d.DepartmentID is not null and d.IdaraID = @idaraID
        END




   
END