
CREATE   VIEW [VIC].[V_Dashboard_VehicleStatus]
AS
SELECT
    v.chassisNumber,
    v.IdaraID_FK AS IdaraID_FK,

    -- العهدة الحالية
    cu.userID_FK            AS CurrentUserID,
    cu.startDate            AS CustodyStartDate,

    -- أقرب وثيقة تنتهي
    doc.vehicleDocumentTypeID_FK AS NextDocTypeID,
    doc.vehicleDocumentNo        AS NextDocNo,
    doc.vehicleDocumentEndDate   AS NextDocEndDate,
    DATEDIFF(DAY, GETDATE(), doc.vehicleDocumentEndDate) AS DocDaysToExpire,

    -- التأمين الفعّال (أقرب نهاية)
    ins.InsuranceTypeID_FK  AS ActiveInsuranceTypeID,
    ins.EndInsurance        AS ActiveInsuranceEndDate,
    DATEDIFF(DAY, GETDATE(), ins.EndInsurance) AS InsDaysToExpire
FROM VIC.Vehicles v
OUTER APPLY (
    SELECT TOP (1)
        w.userID_FK,
        w.startDate
    FROM VIC.vehicleWithUsers w
    WHERE w.chassisNumber_FK = v.chassisNumber
      AND w.endDate IS NULL
    ORDER BY w.startDate DESC, w.vehicleWithUsersID DESC
) cu
OUTER APPLY (
    SELECT TOP (1)
        d.vehicleDocumentTypeID_FK,
        d.vehicleDocumentNo,
        d.vehicleDocumentEndDate
    FROM VIC.vehicleDocument d
    WHERE d.chassisNumber_FK = v.chassisNumber
      AND d.vehicleDocumentEndDate IS NOT NULL
    ORDER BY d.vehicleDocumentEndDate ASC, d.vehicleDocumentID DESC
) doc
OUTER APPLY (
    SELECT TOP (1)
        i.InsuranceTypeID_FK,
        i.EndInsurance
    FROM VIC.VehicleInsurance i
    WHERE i.chassisNumber_FK = v.chassisNumber
      AND i.active = 1
      AND i.EndInsurance IS NOT NULL
    ORDER BY i.EndInsurance ASC, i.VehicleInsuranceID DESC
) ins;