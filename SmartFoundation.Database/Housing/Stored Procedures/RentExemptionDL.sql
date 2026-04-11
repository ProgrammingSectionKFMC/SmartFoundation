-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[RentExemptionDL] 
	-- Add the parameters for the stored procedure here
	    @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
	, @NationalID      NVARCHAR(400)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	   
       declare @residentInfoID nvarchar(1000)
       set @residentInfoID =
       (SELECT Top(1)
                 fr.residentInfoID [residentInfoID]
       FROM [DATACORE].[Housing].V_GetFullResidentDetails fr
           where fr.NationalID = @NationalID
           order by fr.residentDetailsID desc
           )


          -- One Resident Data

             SELECT distinct
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
                     fr.firstName_E,
                     fr.secondName_E,
                     fr.thirdName_E,
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
                ,fr.genderID_FK [genderID_FK]
                ,fr.genderName_A
                ,convert(nvarchar(10),fr.birthdate,23) birthdate
                ,fr.residentcontactDetails
                ,fr.note [note]
                ,fr.IdaraID IdaraID
                ,fr.IdaraName IdaraName
                ,(select count(*) from Housing.V_WaitingList w where w.NationalID = @NationalID and w.IdaraId = @idaraID and (w.LastActionTypeID IS NULL OR w.LastActionTypeID not in (19,53)) and w.IdaraId = @idaraID) WaitingListCount
                ,(select count(*) from Housing.V_WaitingListByLetter w where w.NationalID = @NationalID and w.IdaraId = @idaraID and (w.LastActionTypeID IS NULL OR w.LastActionTypeID not in (19,53)) and w.IdaraId = @idaraID) WaitingListByLetterCount

           FROM [Housing].V_GetFullResidentDetails fr
           where fr.NationalID = @NationalID

            

            --Get Waiting List By Resident Nationl ID


         SELECT 
         r.[residentRentExemptionTypeID_FK]
        ,r.[residentInfoID_FK]
        ,r.buildingDetailsID_FK
        ,b.buildingDetailsNo
        ,r.[residentRentExemptionActive]
        ,t.ResidentRentExemptionTypeName_A
        ,r.[residentRentExemptionLetterNo]
        ,convert(nvarchar(10),r.[residentRentExemptionLetterDate],23) residentRentExemptionLetterDate
        ,convert(nvarchar(10),r.[residentRentExemptionStartDate],23) residentRentExemptionStartDate
        ,convert(nvarchar(10),r.[residentRentExemptionEndDate],23) residentRentExemptionEndDate
        ,r.[residentRentExemptionDescription]
        ,r.[idaraID_FK]
        ,r.[entryDate]
        ,r.[entryData]
        ,r.[hostName]
        ,t.ResidentRentExemptionTypePercentage
        ,case when r.residentRentExemptionActive = 0 or cast(r.residentRentExemptionEndDate as date) < cast(GETDATE() as date) then N'0'
         else
         N'1'
         END RentExemptionStatus
          ,case when r.residentRentExemptionActive = 0 or cast(r.residentRentExemptionEndDate as date) < cast(GETDATE() as date) then N'منتهي'
         else
         N'نشط'
         END RentExemptionStatusText

        FROM [Housing].[ResidentRentExemption] r
        inner join Housing.ResidentRentExemptionType t on r.residentRentExemptionTypeID_FK = t.ResidentRentExemptionTypeID
        left join Housing.V_GetGeneralListForBuilding b on r.buildingDetailsID_FK = b.buildingDetailsID
        where r.residentInfoID_FK = @residentInfoID and r.idaraID_FK = @idaraID 
        





    -- Insert statements for procedure here
END