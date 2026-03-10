CREATE   FUNCTION Housing.FN_EligibleMeters
(
    @idaraID int,
    @MonthStart date,
    @MonthEnd date
)
RETURNS TABLE
AS
RETURN
(
    SELECT md.meterID, md.meterNo, md.meterServiceTypeID_FK
    FROM Housing.V_MetersDetails md
    JOIN Housing.MeterForBuilding mfb
      ON md.meterID = mfb.meterID_FK
    WHERE
        md.MeterServiceTypeLinkedWithIdaraID_FK = @idaraID
    AND md.MeterIDaraID = @idaraID
    AND md.MeterTypeIDaraID = @idaraID
    AND md.meterActive = 1
    AND md.meterTypeActive = 1
    AND md.meterServiceTypeActive = 1
    AND mfb.meterForBuildingActive = 1
    AND md.meterStartDate <= @MonthEnd
    AND (md.meterEndDate IS NULL OR md.meterEndDate >= @MonthStart)
    AND md.meterTypeStartDate <= @MonthEnd
    AND (md.meterTypeEndDate IS NULL OR md.meterTypeEndDate >= @MonthStart)
    AND md.meterServiceTypeStartDate <= @MonthEnd
    AND (md.meterServiceTypeEndDate IS NULL OR md.meterServiceTypeEndDate >= @MonthStart)
    AND mfb.meterForBuildingStartDate <= @MonthEnd
    AND (mfb.meterForBuildingEndDate IS NULL OR mfb.meterForBuildingEndDate >= @MonthStart)
    GROUP BY md.meterID, md.meterNo, md.meterServiceTypeID_FK
);
