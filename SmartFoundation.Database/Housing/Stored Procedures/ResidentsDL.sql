-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[ResidentsDL] 
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
	   

          -- Residents Data
            SELECT Top(1000)
                 fr.residentInfoID [residentInfoID]
                ,fr.NationalID [NationalID]
                ,fr.generalNo_FK [generalNo_FK]
                ,fr.firstName_A [firstName_A]
                ,fr.secondName_A [secondName_A]
                ,fr.thirdName_A [thirdName_A]
                ,fr.lastName_A [lastName_A]
                ,fr.firstName_E [firstName_E]
                ,fr.secondName_E [secondName_E]
                ,fr.thirdName_E [thirdName_E]
                ,fr.lastName_E [lastName_E]
                ,LTRIM(RTRIM(
                 CONCAT_WS(N' ',
                     fr.firstName_A,
                     fr.secondName_A,
                     fr.thirdName_A,
                     fr.lastName_A
                 )
                 )) AS FullName_A
                ,LTRIM(RTRIM(
                 CONCAT_WS(N' ',
                     fr.firstName_E ,
                     fr.secondName_E ,
                     fr.thirdName_E ,
                     fr.lastName_E 
                 )
                 )) AS FullName_E
                ,fr.rankID_FK [rankID_FK]
                ,fr.rankNameA
                ,fr.militaryUnitID_FK [militaryUnitID_FK]
                ,fr.militaryUnitName_A
                ,fr.martialStatusID_FK [martialStatusID_FK]
                ,fr.maritalStatusName_A
                ,fr.dependinceCounter [dependinceCounter]
                ,fr.nationalityID_FK [nationalityID_FK]
                ,fr.nationalityName_A
                ,fr.genderID_FK as [genderID_FK]
                ,fr.genderName_A
                ,convert(nvarchar(10),fr.birthdate,23) birthdate
                ,fr.residentcontactDetails
                ,fr.note [note]

                

           FROM [DATACORE].[Housing].V_GetFullResidentDetails fr
           where fr.IdaraID = @idaraID
            
           ORDER BY fr.residentInfoID desc;


             -- rank DDL
            SELECT bu.rankID, bu.rankNameA
            FROM [DATACORE].[dbo].[Rank] bu
            WHERE bu.rankActive = 1 
            order by bu.rankClassID_FK asc


            -- militaryUnit DDL
            SELECT r.militaryUnitID, r.militaryUnitName_A
            FROM [DATACORE].[dbo].[militaryUnit] r
            

            

            -- MaritalStatus DDL
            SELECT r.maritalStatusID, r.maritalStatusName_A
            FROM [DATACORE].[dbo].[MaritalStatus] r
            WHERE r.maritalStatusActive = 1 ;


            

            -- Nationality DDL
            SELECT r.nationalityID, r.nationalityName_A
            FROM [DATACORE].[dbo].[Nationality] r
            WHERE r.nationalityActive = 1;


            

            -- Gender DDL
            SELECT r.genderID, r.genderName_A
            FROM [DATACORE].[dbo].[Gender] r
            


            ---- test
            select r.residentInfoID,FullName_A from [DATACORE].[Housing].V_GetFullResidentDetails r
            where IdaraID = @idaraID



    -- Insert statements for procedure here
END