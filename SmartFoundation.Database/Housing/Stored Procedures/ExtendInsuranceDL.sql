-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[ExtendInsuranceDL] 
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
	   
  SELECT 
       e.[ExtendInsuranceID]
      ,e.[buildingActionID_FK]
      ,e.[residentInfoID_FK]
      ,r.NationalID
      ,r.generalNo_FK
      ,r.FullName_A
      ,r.rankNameA
      ,w.WaitingClassName
      ,e.[buildingDetailsID_FK]
      ,e.[buildingDetailsNo]
      ,case 
       when e.[ExtendInsuranceApproved] is null  then N'0'
       when e.[ExtendInsuranceApproved] = 0  then N'2'
       when e.[ExtendInsuranceApproved] = 1  then N'1'
       END ExtendInsuranceApprovedStatus
       ,case 
       when e.[ExtendInsuranceApproved] is null  then N'بانتظار اعتماد التأمين'
       when e.[ExtendInsuranceApproved] = 0  then N'لم يتم تنفيذ التأمين'
       when e.[ExtendInsuranceApproved] = 1  then N'تم تنفيذ التأمين بنجاح'
       END ExtendInsuranceApprovedStatusText
      ,e.[InsuranceAmount]
      ,isnull(e.[Remaining],0.00) Remaining
      ,e.[InsuranceAmountWithRemaining]
      ,e.[ExtendInsuranceNo]
      ,convert(nvarchar(10),e.[ExtendInsuranceDate],23) ExtendInsuranceDate
      ,e.[ExtendInsuranceType]
      ,t.ExtendInsuranceTypeName_A
       
       ,u.FullName InsuranceEntryUser
      ,e.[ExtendInsuranceNote]
      ,e.[ExtendInsuranceActive]
      ,e.[ExtendInsuranceApproved]
      ,e.[ExtendInsuranceIncomeNo]
      ,convert(nvarchar(10),e.[ExtendInsuranceIncomeDate],23) ExtendInsuranceIncomeDate
      ,e.[ExtendInsuranceApprovedby]
      ,ua.FullName ApprovedeEntryUser
     
      ,convert(nvarchar(10),e.[ExtendInsuranceApprovedDate],23) ExtendInsuranceApprovedDate
      ,e.[IdaraId_FK]
      ,e.[entryDate]
      ,e.[entryData]
      ,e.[hostName]
      ,r.militaryUnitID_FK
      

  FROM [DATACORE].[Housing].[ExtendInsurance] e
  inner join Housing.V_GetFullResidentDetails r on e.residentInfoID_FK = r.residentInfoID
  inner join Housing.ExtendInsuranceType t on e.ExtendInsuranceType = t.ExtendInsuranceTypeID
  inner join Housing.V_WaitingList w on w.ActionID = 
  (select top(1) c.buildingActionID from Housing.fn_BuildingAction_ChainToRoot(e.[buildingActionID_FK]) c
  where c.buildingActionTypeID_FK = 1 order by c.buildingActionID desc)
  left join dbo.V_GetFullSystemUsersDetails u 
    on cast(
            right(
                e.entryData,
                charindex(',', reverse(e.entryData) + ',') - 1
            ) 
        as bigint) = cast(u.usersID as bigint) 
        left join dbo.V_GetFullSystemUsersDetails ua 
    on cast(
            right(
                e.ExtendInsuranceApprovedby,
                charindex(',', reverse(e.ExtendInsuranceApprovedby) + ',') - 1
            ) 
        as bigint) = cast(ua.usersID as bigint) 

        where e.IdaraId_FK = @idaraID and e.InsuranceAmountWithRemaining <> 0.00

  



   
END

GO

