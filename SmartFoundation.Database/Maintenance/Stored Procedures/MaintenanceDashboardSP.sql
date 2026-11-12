
CREATE   PROCEDURE [Maintenance].[MaintenanceDashboardSP]
      @Action NVARCHAR(200)
    , @idaraID_FK NVARCHAR(10) = NULL
    , @entryData NVARCHAR(20) = NULL
    , @hostName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ;THROW 50001, N'لا توجد عمليات حفظ في لوحة مؤشرات الصيانة حالياً', 1;
END;

GO

