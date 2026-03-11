-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[WaitingListByResidentDL] 
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

           FROM [DATACORE].[Housing].V_GetFullResidentDetails fr
           where fr.NationalID = @NationalID

            

            --Get Waiting List By Resident Nationl ID


            SELECT 
            w.ActionID,
            w.NationalID,
            w.GeneralNo + '1' GeneralNo,
            w.ActionDecisionNo,
            convert(nvarchar(10),w.[ActionDecisionDate],23) ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
            w.ActionNote,
            rd.FullName_A FullName_A,
            isnull(w.LastActionTypeID,0) LastActionTypeID,
            isnull(w.LastActionTypeName,N'لايوجد اجراء') LastActionTypeName
            FROM Housing.V_WaitingList w 
            inner join Housing.V_GetFullResidentDetails rd on w.residentInfoID = rd.residentInfoID 
            where w.NationalID = @NationalID
            AND w.IdaraId = @idaraID
            AND rd.IdaraID = @idaraID
            AND w.ActionTypeID = 1
            --AND (w.LastActionID is null or w.LastActionTypeID in (34,35))

             --Get Letter Waiting List By Resident Nationl ID


            SELECT 
            w.ActionID,
            w.NationalID,
            w.GeneralNo,
            w.ActionDecisionNo,
            convert(nvarchar(10),w.[ActionDecisionDate],23) ActionDecisionDate,
            w.WaitingClassID,
            w.WaitingClassName,
            w.WaitingOrderTypeID,
            w.WaitingOrderTypeName,
            w.waitingClassSequence,
            w.residentInfoID,
            w.ActionNote,
            rd.FullName_A FullName_A,
            isnull(w.LastActionTypeID,0) LastActionTypeID,
            isnull(w.LastActionTypeName,N'لايوجد اجراء') LastActionTypeName
            FROM Housing.V_WaitingList w 
            inner join Housing.V_GetFullResidentDetails rd on w.residentInfoID = rd.residentInfoID 
            where w.NationalID = @NationalID
            AND w.IdaraId = @idaraID
            AND rd.IdaraID = @idaraID
            AND w.ActionTypeID = 7

            -- Request Move To Other Idara List


        SELECT [ActionID]
              ,[residentInfoID]
              ,[NationalID]
              ,[GeneralNo]
              ,[fullname]
              ,[ActionDecisionNo]
              ,convert(nvarchar(10),[ActionDecisionDate],23) ActionDecisionDate
              ,[ActionDate]
              ,[IdaraId]
              ,[ActionIdaraName]
              ,[ToIdaraID]
              ,[Toidaraname]
              ,[WaitingListCount]
              ,[MainActionEntryData]
              ,convert(nvarchar(19),[MainActionEntryDate],120) MainActionEntryDate
              ,[ActionNote]
              ,[LastActionID]
              ,[LastActionTypeID]
              ,[LastActionIdaraID]
              ,[LastActionIdaraName]
              ,[LastActionTypeName]
              
              ,convert(nvarchar(19),[LastActionEntryDate],120) LastActionEntryDate
              ,[LastActionNote]
              ,[LastActionEntryData]
              ,[ActionStatus]
              
          FROM [DATACORE].[Housing].[V_MoveWaitingList] mw
          where mw.NationalID = @NationalID 
          and mw.IdaraId = @idaraID
          order by mw.ActionID desc





             -- WaitingClass DDL
            SELECT w.waitingClassID,w.waitingClassName_A
            FROM [DATACORE].[Housing].[WaitingClass] w
            WHERE w.idara_FK is null or w.idara_FK = @idaraID
            order by w.waitingClassID asc


            -- WaitingOrderType DDL
            SELECT r.waitingOrderTypeID,r.waitingOrderTypeName_A
            FROM [DATACORE].[Housing].[WaitingOrderType] r
            

            
            -- Idaras DDL
            SELECT r.idaraID,r.idaraLongName_A
            FROM [DATACORE].[dbo].[Idara] r
            where r.idaraID <> @idaraID
            order by r.idaraID asc
            

            SELECT B.buildingActionTypeID,B.buildingActionTypeName_A
            FROM Housing.BuildingActionType B
            WHERE B.buildingActionTypeID IN (19,53)







    -- Insert statements for procedure here
END