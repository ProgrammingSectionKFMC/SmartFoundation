CREATE PROCEDURE [Housing].[HousingExtendFollowUpDL]
      @pageName_ NVARCHAR(400)
    , @idaraID INT
    , @entrydata INT
    , @hostname NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    SELECT
          w.ActionID
        , rd.FullName_A
        , w.NationalID
        , w.GeneralNo
        , rd.rankNameA
        , CONVERT(NVARCHAR(10), w.OccupentDate, 23) AS OccupentDate
        , w.LastActionDecisionNo
        , CONVERT(NVARCHAR(10), w.LastActionDecisionDate, 23) AS LastActionDecisionDate
        , CONVERT(NVARCHAR(10), w.buildingActionFromDate, 23) AS ExtendFromDate
        , CONVERT(NVARCHAR(10), w.buildingActionToDate, 23) AS ExtendToDate
        , w.residentInfoID
        , w.LastActionID
        , w.LastActionTypeID
        , w.buildingDetailsID
        , w.buildingDetailsNo
        , ba.buildingActionTypeResidentAlias
        , w.LastActionExtendReasonTypeID
        , ert.ExtendReasonTypeID
        , ert.ExtendReasonTypeName_A
        , ISNULL(w.LastActionNote, w.ActionNote) AS ActionNote
        , w.IdaraId
        , DATEDIFF(DAY, @Today, CAST(w.buildingActionToDate AS DATE)) AS ExtendRemainingDays
        , CASE
              WHEN CAST(w.buildingActionToDate AS DATE) < @Today
                  THEN N'انتهى الإمهال منذ ' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, CAST(w.buildingActionToDate AS DATE), @Today)) + N' يوم'
              WHEN CAST(w.buildingActionToDate AS DATE) = @Today
                  THEN N'ينتهي الإمهال اليوم'
              ELSE N'متبقي على انتهاء الإمهال ' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, @Today, CAST(w.buildingActionToDate AS DATE))) + N' يوم'
          END AS ExtendExpiryStatus
        , CASE
              WHEN ert.InsuranceRequired = 1 AND i.ExtendInsuranceID IS NULL THEN N'التأمين الاحترازي مطلوب'
              WHEN ert.InsuranceRequired = 1 AND i.ExtendInsuranceID IS NOT NULL THEN N'تم تنفيذ التأمين الاحترازي'
              ELSE N'التأمين الاحترازي غير مطلوب'
          END AS InsuranceStatusName
        , CASE
              WHEN ert.InsuranceRequired = 1 AND i.ExtendInsuranceID IS NULL THEN 0
              WHEN ert.InsuranceRequired = 1 AND i.ExtendInsuranceID IS NOT NULL THEN 1
              ELSE 2
          END AS InsuranceStatusNo
    FROM Housing.V_WaitingList w
    INNER JOIN Housing.V_GetFullResidentDetails rd
        ON w.residentInfoID = rd.residentInfoID
    INNER JOIN Housing.BuildingActionType ba
        ON w.LastActionTypeID = ba.buildingActionTypeID
    LEFT JOIN Housing.ExtendReasonType ert
        ON w.LastActionExtendReasonTypeID = ert.ExtendReasonTypeID
    LEFT JOIN Housing.ExtendInsurance i
        ON w.residentInfoID = i.residentInfoID_FK
        AND w.buildingDetailsID = i.buildingDetailsID_FK
        AND i.ExtendInsuranceActive = 1
    WHERE w.IdaraId = @idaraID
      AND w.LastActionTypeID = 24
      AND w.buildingActionToDate IS NOT NULL
      AND CAST(w.buildingActionToDate AS DATE) < DATEADD(DAY, 60, @Today)
    ORDER BY
        CAST(w.buildingActionToDate AS DATE) ASC,
        w.GeneralNo ASC;
END

GO

