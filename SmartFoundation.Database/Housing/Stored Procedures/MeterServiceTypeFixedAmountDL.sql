-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Housing].[MeterServiceTypeFixedAmountDL] 
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
	   

            -- MeterServiceTypeFixedAmount Data
       SELECT 
       m.[MeterServiceTypeFixedAmountID]
      ,m.[MeterServiceTypeID_FK]
      ,t.meterServiceTypeName_A
      ,m.[FixedAmount]
      ,convert(nvarchar(10),m.[MeterServiceTypeFixedAmountStartDate],23) as MeterServiceTypeFixedAmountStartDate
      ,m.[MeterServiceTypeFixedAmountEndDate]
      ,m.[MeterServiceTypeFixedAmountActive]
      ,m.[idaraID_FK]
      
      
  FROM [Housing].[MeterServiceTypeFixedAmount] m
  inner join [Housing].[MeterServiceType] t on m.[MeterServiceTypeID_FK] = t.[MeterServiceTypeID]
  where m.MeterServiceTypeFixedAmountActive = 1 and t.meterServiceTypeActive = 1 and m.idaraID_FK = @idaraID
    
      --

      select t.meterServiceTypeID,t.meterServiceTypeName_A
      from [Housing].[MeterServiceType] t
      left join [Housing].[MeterServiceTypeFixedAmount] m on t.[MeterServiceTypeID] = m.[MeterServiceTypeID_FK] and m.idaraID_FK = @idaraID and m.MeterServiceTypeFixedAmountActive=1
      where m.MeterServiceTypeFixedAmountID is null
      order by t.meterServiceTypeID asc


END

GO

