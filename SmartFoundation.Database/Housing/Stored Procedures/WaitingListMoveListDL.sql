-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
Create PROCEDURE [Housing].[WaitingListMoveListDL] 
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
	   

          -- One Resident Data

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
          where 
          --mw.NationalID = @parameter_01 
          --and 
          mw.ToIdaraID = @idaraID
          order by mw.ActionID desc




    -- Insert statements for procedure here
END
