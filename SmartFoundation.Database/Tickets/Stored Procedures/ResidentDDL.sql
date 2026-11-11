
CREATE PROCEDURE [Tickets].[ResidentDDL]
(
      @pageName_      NVARCHAR(400)
    , @idaraID        INT
    , @entrydata      INT
    , @hostname       NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @pageName_ = N'ResidentDDL'
    BEGIN
        ;WITH ResidentHousing AS
        (
            SELECT
                r.[residentInfoID] AS [residentInfoID],
                r.[NationalID] AS [NationalID],
                r.[generalNo_FK] AS [generalNo_FK],
                r.[FullName_A] AS [ResidentName_A],
                r.[FullName_E] AS [FullName_E],
                r.[rankNameA] AS [rankNameA],
                r.[militaryUnitName_A] AS [militaryUnitName_A],
                CASE
                    WHEN ba.[BuildingNo] IS NULL
                        OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), ba.[BuildingNo]))) = N''
                        OR CONVERT(NVARCHAR(100), ba.[BuildingNo]) = N'No_house'
                    
                    THEN N'بدون سكن'
                    ELSE CONVERT(NVARCHAR(100), ba.[BuildingNo])
                END AS [BuildingNo],
                ROW_NUMBER() OVER
                (
                    PARTITION BY r.[residentInfoID]
                    ORDER BY
                        CASE
                            WHEN ba.[BuildingNo] IS NULL
                              OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), ba.[BuildingNo]))) = N''
                              OR CONVERT(NVARCHAR(100), ba.[BuildingNo]) = N'No_house'
                            THEN 1 ELSE 0
                        END,
                        ba.[BuildingAssignDate] DESC,
                        ba.[BuildingAssignID] DESC
                ) AS [rn]
            FROM [Housing].[V_GetFullResidentDetails] r
            INNER JOIN [DATACORE].[Housing].[BuildingAssign] ba
                ON r.[generalNo_FK] = ba.[GeneralNo]
            INNER JOIN [DATACORE].[Housing].[BuildingAssignStatus] bas
                ON ba.[BuildingAssignStatusID_FK] = bas.[BuildingAssignStatusID]
            WHERE r.[IdaraID] = @idaraID
              AND bas.[Active] = 1
        )
        SELECT
            rh.[residentInfoID] AS [residentInfoID],
            rh.[NationalID] AS [NationalID],
            rh.[generalNo_FK] AS [generalNo_FK],
            rh.[ResidentName_A] AS [ResidentName_A],
            rh.[ResidentName_A]
                
                + N' | هوية: '
                + COALESCE(NULLIF(CONVERT(NVARCHAR(50), rh.[NationalID]), N''), CONVERT(NVARCHAR(50), rh.[generalNo_FK]), N'-')
                + N' | السكن: '
                + COALESCE(NULLIF(rh.[BuildingNo], N''), N'بدون سكن') AS [FullName_A],
            rh.[ResidentName_A]
                + N' | هوية: '
                + COALESCE(NULLIF(CONVERT(NVARCHAR(50), rh.[NationalID]), N''), CONVERT(NVARCHAR(50), rh.[generalNo_FK]), N'-')
                + N' | السكن: '
                + COALESCE(NULLIF(rh.[BuildingNo], N''), N'بدون سكن') AS [ResidentDisplay],
            rh.[FullName_E] AS [FullName_E],
            rh.[rankNameA] AS [rankNameA],
            rh.[militaryUnitName_A] AS [militaryUnitName_A],
            rh.[BuildingNo] AS [BuildingNo]
        FROM ResidentHousing rh
        WHERE rh.[rn] = 1
        ORDER BY rh.[ResidentName_A] ASC;

        RETURN;
    END
END
