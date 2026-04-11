CREATE   VIEW [VIC].[V_ActiveTransferRequests]
AS
WITH LastHist AS
(
    SELECT
          h.RequestID_FK
        , h.Status
        , h.ActionDate
        , ROW_NUMBER() OVER
          (
              PARTITION BY h.RequestID_FK
              ORDER BY h.ActionDate DESC, h.HistoryID DESC
          ) AS rn
    FROM VIC.VehicleTransferRequestHistory h
)
SELECT
      r.RequestID
    , r.RequestTypeID_FK
    , r.chassisNumber_FK
    , r.fromUserID_FK
    , r.toUserID_FK
    , r.deptID_FK
    , r.IdaraID_FK
    , r.active

    , lh.Status     AS LastStatus
    , lh.ActionDate AS LastActionDate
FROM VIC.VehicleTransferRequest r
LEFT JOIN LastHist lh
    ON lh.RequestID_FK = r.RequestID
   AND lh.rn = 1
WHERE ISNULL(r.active,0) = 1;