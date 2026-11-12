SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Tickets].[TicketListDL]
(
      @pageName_         NVARCHAR(400)
    , @idaraID           INT
    , @entryData         INT
    , @hostName          NVARCHAR(400)
    , @filterStatusID    INT    = NULL
    , @filterServiceID   BIGINT = NULL
    , @filterDSDID       INT    = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- صفحة قائمة التذاكر: كل بيانات الصفحة في استدعاء واحد.
    -- ترقيم الجداول في MVC بعد جدول الصلاحيات [0] من Masters_DataLoad:
    --   [1]  التذاكر
    --   [2]  حالات التذكرة (فلتر)        [3]  الخدمات (فلتر + نموذج الإنشاء)
    --   [4]  أسباب الإيقاف               [5]  أسباب التحكيم
    --   [6]  نتائج مراجعة الجودة         [7]  الأولويات
    --   [8]  فئات التذاكر                [9]  أسباب طلب التوضيح
    --   [10] الجهات                      [11] موظفو الجهات (DDLFiltered: FK=DSDID)
    --   [12] صندوق مراجعة الجودة         [13] طلبات التوضيح المفتوحة لكل تذكرة
    --   [14] أنواع مقدم الطلب            [15] السكان
    --   [16] المباني                     [17] أسباب البلاغ (DDLFiltered: FK=serviceID_FK)
    ----------------------------------------------------------------

    -- [1] التذاكر
    SELECT
          t.[ticketID]
        , t.[ticketNo]
        , COALESCE(t.[title_A], t.[title]) AS [title]
        , CASE
            WHEN s.[serviceName_A] IS NULL OR s.[serviceName_A] NOT LIKE N'%[ء-ي]%'
              THEN s.[serviceName_E]
            ELSE s.[serviceName_A]
          END AS [serviceName_A]
        , s.[serviceName_E]
        , CASE
            WHEN rt.[requesterTypeName_A] IS NULL OR rt.[requesterTypeName_A] NOT LIKE N'%[ء-ي]%'
              THEN rt.[requesterTypeName_E]
            ELSE rt.[requesterTypeName_A]
          END AS [requesterTypeName_A]
        , rt.[requesterTypeName_E]
        , COALESCE(
            NULLIF(t.[reporterName], N''),
            NULLIF(LTRIM(RTRIM(
                ISNULL(rud.firstName_A, N'') + N' ' +
                ISNULL(rud.secondName_A, N'') + N' ' +
                ISNULL(rud.thirdName_A, N'') + N' ' +
                ISNULL(rud.lastName_A, N'')
            )), N''),
            rres.[ResidentName_A]
          ) AS [requesterName]
        , CASE
            WHEN p.[priorityName_A] IS NULL OR p.[priorityName_A] NOT LIKE N'%[ء-ي]%'
              THEN p.[priorityName_E]
            ELSE p.[priorityName_A]
          END AS [priorityName_A]
        , p.[priorityName_E]
        , CASE
            WHEN ts.[ticketStatusName_A] IS NULL OR ts.[ticketStatusName_A] NOT LIKE N'%[ء-ي]%'
              THEN ts.[ticketStatusName_E]
            ELSE ts.[ticketStatusName_A]
          END AS [ticketStatusName_A]
        , ts.[ticketStatusName_E]
        , ts.[ticketStatusCode]
        , COALESCE(
            NULLIF(LTRIM(RTRIM(
                ISNULL(aud.firstName_A, N'') + N' ' +
                ISNULL(aud.secondName_A, N'') + N' ' +
                ISNULL(aud.thirdName_A, N'') + N' ' +
                ISNULL(aud.lastName_A, N'')
            )), N''),
            dsd.[dsdName_A]
          ) AS [assignedUserName]
        , sla.[elapsedMinutes]
        , t.[currentDSDID_FK]
        , t.[assignedUserID_FK]
        , t.[entryDate]
    FROM [Tickets].[Ticket] t
    LEFT JOIN [Tickets].[Service] s ON t.[serviceID_FK] = s.[serviceID]
    LEFT JOIN [Tickets].[Priority] p ON t.[effectivePriorityID_FK] = p.[priorityID]
    LEFT JOIN [Tickets].[TicketStatus] ts ON t.[ticketStatusID_FK] = ts.[ticketStatusID]
    LEFT JOIN [Tickets].[RequesterType] rt ON t.[requesterTypeID_FK] = rt.[requesterTypeID]
    OUTER APPLY (
        SELECT TOP 1
              CASE WHEN ud.firstName_A IS NULL OR ud.firstName_A NOT LIKE N'%[ء-ي]%' THEN ud.firstName_E ELSE ud.firstName_A END AS firstName_A
            , CASE WHEN ud.secondName_A IS NULL OR ud.secondName_A NOT LIKE N'%[ء-ي]%' THEN ud.secondName_E ELSE ud.secondName_A END AS secondName_A
            , CASE WHEN ud.thirdName_A IS NULL OR ud.thirdName_A NOT LIKE N'%[ء-ي]%' THEN ud.thirdName_E ELSE ud.thirdName_A END AS thirdName_A
            , CASE WHEN ud.lastName_A IS NULL OR ud.lastName_A NOT LIKE N'%[ء-ي]%' THEN ud.lastName_E ELSE ud.lastName_A END AS lastName_A
        FROM dbo.UsersDetails ud
        WHERE ud.usersID_FK = t.[requesterUserID_FK]
          AND ud.userActive = 1
        ORDER BY ud.entryDate DESC, ud.usersDetailsID DESC
    ) rud
    OUTER APPLY (
        SELECT TOP 1
              CASE WHEN ud.firstName_A IS NULL OR ud.firstName_A NOT LIKE N'%[ء-ي]%' THEN ud.firstName_E ELSE ud.firstName_A END AS firstName_A
            , CASE WHEN ud.secondName_A IS NULL OR ud.secondName_A NOT LIKE N'%[ء-ي]%' THEN ud.secondName_E ELSE ud.secondName_A END AS secondName_A
            , CASE WHEN ud.thirdName_A IS NULL OR ud.thirdName_A NOT LIKE N'%[ء-ي]%' THEN ud.thirdName_E ELSE ud.thirdName_A END AS thirdName_A
            , CASE WHEN ud.lastName_A IS NULL OR ud.lastName_A NOT LIKE N'%[ء-ي]%' THEN ud.lastName_E ELSE ud.lastName_A END AS lastName_A
        FROM dbo.UsersDetails ud
        WHERE ud.usersID_FK = t.[assignedUserID_FK]
          AND ud.userActive = 1
        ORDER BY ud.entryDate DESC, ud.usersDetailsID DESC
    ) aud
    OUTER APPLY (
        SELECT TOP 1 r.[FullName_A] AS [ResidentName_A]
        FROM [Housing].[V_GetFullResidentDetails] r
        WHERE r.[residentInfoID] = t.[requesterResidentID_FK]
    ) rres
    OUTER APPLY (
        SELECT TOP 1 sl.[elapsedMinutes]
        FROM [Tickets].[TicketSLA] sl
        WHERE sl.[ticketID_FK] = t.[ticketID]
          AND sl.[slaTypeCode] = N'RESOLUTION'
          AND sl.[ticketSLAActive] = 1
        ORDER BY sl.[ticketSLAID] DESC
    ) sla
    OUTER APPLY (
        SELECT
            COALESCE(
                NULLIF(LTRIM(RTRIM(
                    COALESCE(f.[DepartmentName], N'')
                    + CASE WHEN f.[SectionName] IS NOT NULL THEN N' / ' + f.[SectionName] ELSE N'' END
                    + CASE WHEN f.[DivisonName]  IS NOT NULL THEN N' / ' + f.[DivisonName]  ELSE N'' END
                )), N''),
                f.[IdaraName],
                CAST(t.[currentDSDID_FK] AS NVARCHAR(20))
            ) AS [dsdName_A]
        FROM dbo.V_GetFullStructureForDSD f
        WHERE f.[DSDID] = t.[currentDSDID_FK]
    ) dsd
    WHERE t.[ticketActive] = 1
      AND t.[idaraID_FK] = @idaraID
      AND (t.[ticketStatusID_FK] = @filterStatusID OR @filterStatusID IS NULL)
      AND (t.[serviceID_FK] = @filterServiceID OR @filterServiceID IS NULL)
      AND (t.[currentDSDID_FK] = @filterDSDID OR @filterDSDID IS NULL)
    ORDER BY t.[ticketID] DESC;

    -- [2] حالات التذكرة
    SELECT [ticketStatusID], [ticketStatusName_A], [ticketStatusName_E]
    FROM [Tickets].[TicketStatus]
    WHERE [ticketStatusActive] = 1
    ORDER BY [ticketStatusID];

    -- [3] الخدمات
    SELECT s.[serviceID], s.[serviceName_A], s.[serviceName_E], s.[ticketClassID_FK]
    FROM [Tickets].[Service] s
    WHERE s.[serviceActive] = 1
      AND (s.[idaraID_FK] = @idaraID OR s.[idaraID_FK] IS NULL)
    ORDER BY s.[serviceName_A];

    -- [4] أسباب الإيقاف (المضبوطة تلقائياً من النظام ليست اختياراً يدوياً)
    SELECT [pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E]
    FROM [Tickets].[PauseReason]
    WHERE [pauseReasonActive] = 1
      AND [pauseReasonCode] NOT IN (N'CHILD_DEPENDENCY', N'ARBITRATION', N'CLARIFICATION')
    ORDER BY [pauseReasonID];

    -- [5] أسباب التحكيم
    SELECT [arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E]
    FROM [Tickets].[ArbitrationReason]
    WHERE [arbitrationReasonActive] = 1
    ORDER BY [arbitrationReasonID];

    -- [6] نتائج مراجعة الجودة
    SELECT [qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E]
    FROM [Tickets].[QualityReviewResult]
    WHERE [qualityReviewResultActive] = 1
    ORDER BY [qualityReviewResultID];

    -- [7] الأولويات
    SELECT [priorityID], [priorityCode], [priorityName_A], [priorityName_E]
    FROM [Tickets].[Priority]
    WHERE [priorityActive] = 1
    ORDER BY [priorityID];

    -- [8] فئات التذاكر
    SELECT [ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E]
    FROM [Tickets].[TicketClass]
    WHERE [ticketClassActive] = 1
    ORDER BY [ticketClassID];

    -- [9] أسباب طلب التوضيح
    SELECT [clarificationReasonID], [clarificationReasonCode], [clarificationReasonName_A], [clarificationReasonName_E]
    FROM [Tickets].[ClarificationReason]
    WHERE [clarificationReasonActive] = 1
    ORDER BY [clarificationReasonID];

    -- [10] الجهات
    SELECT
          f.[DSDID]
        , COALESCE(
            NULLIF(
                LTRIM(RTRIM(
                    COALESCE(f.[DepartmentName], N'')
                    + CASE WHEN f.[SectionName] IS NOT NULL THEN N' / ' + f.[SectionName] ELSE N'' END
                    + CASE WHEN f.[DivisonName] IS NOT NULL THEN N' / ' + f.[DivisonName] ELSE N'' END
                )), N''),
            f.[IdaraName],
            CAST(f.[DSDID] AS NVARCHAR(20))
          ) AS [dsdName_A]
    FROM dbo.V_GetFullStructureForDSD f
    WHERE f.[IdaraID] = @idaraID
    ORDER BY f.[DepartmentName], f.[SectionName], f.[DivisonName];

    -- [11] موظفو الجهات (قائمة الموظف تتبع الجهة المختارة)
    SELECT
          v.[usersID]
        , v.[FullName] AS [fullName_A]
        , v.[DSDID]
    FROM dbo.V_GetListUsersInDSD v
    WHERE EXISTS (SELECT 1 FROM dbo.V_GetFullStructureForDSD f
                  WHERE f.[DSDID] = v.[DSDID] AND f.[IdaraID] = @idaraID)
    ORDER BY v.[FullName];

    -- [12] صندوق مراجعة الجودة
    SELECT
          qr.[qualityReviewID]
        , qr.[ticketID_FK]
        , t.[ticketNo]
        , COALESCE(t.[title_A], t.[title]) AS [title]
        , qr.[reviewScope]
        , qr.[entryDate]
    FROM [Tickets].[QualityReview] qr
    INNER JOIN [Tickets].[Ticket] t ON qr.[ticketID_FK] = t.[ticketID]
    WHERE qr.[finalized] = 0
      AND qr.[qualityReviewActive] = 1
      AND qr.[idaraID_FK] = @idaraID
      AND t.[idaraID_FK] = @idaraID
    ORDER BY qr.[qualityReviewID] DESC;

    -- [13] طلب التوضيح المفتوح لكل تذكرة (بدل استعلام لكل تذكرة)
    SELECT
          cr.[ticketID_FK]
        , MAX(cr.[clarificationRequestID]) AS [clarificationRequestID]
    FROM [Tickets].[ClarificationRequest] cr
    INNER JOIN [Tickets].[Ticket] t
        ON t.[ticketID] = cr.[ticketID_FK]
       AND t.[idaraID_FK] = @idaraID
       AND t.[ticketActive] = 1
    WHERE cr.[clarificationStatus] = N'OPEN'
      AND ISNULL(cr.[clarificationActive], 1) = 1
    GROUP BY cr.[ticketID_FK];

    -- [14] أنواع مقدم الطلب
    SELECT [requesterTypeID], [requesterTypeCode], [requesterTypeName_A], [requesterTypeName_E]
    FROM [Tickets].[RequesterType]
    WHERE [requesterTypeActive] = 1
    ORDER BY [requesterTypeID];

    -- [15] السكان الذين لهم سكن فعّال
    ;WITH ResidentHousing AS
    (
        SELECT
              r.[residentInfoID]
            , r.[NationalID]
            , r.[generalNo_FK]
            , r.[FullName_A] AS [ResidentName_A]
            , CASE
                WHEN ba.[BuildingNo] IS NULL
                  OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), ba.[BuildingNo]))) = N''
                  OR CONVERT(NVARCHAR(100), ba.[BuildingNo]) = N'No_house'
                THEN N'بدون سكن'
                ELSE CONVERT(NVARCHAR(100), ba.[BuildingNo])
              END AS [BuildingNo]
            , ROW_NUMBER() OVER
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
        INNER JOIN [Housing].[BuildingAssign] ba ON r.[generalNo_FK] = ba.[GeneralNo]
        INNER JOIN [Housing].[BuildingAssignStatus] bas ON ba.[BuildingAssignStatusID_FK] = bas.[BuildingAssignStatusID]
        WHERE r.[IdaraID] = @idaraID
          AND bas.[Active] = 1
    )
    SELECT
          rh.[residentInfoID]
        , rh.[ResidentName_A]
            + N' | هوية: '
            + COALESCE(NULLIF(rh.[NationalID], N''), CONVERT(NVARCHAR(50), rh.[generalNo_FK]), N'-')
            + N' | السكن: '
            + COALESCE(NULLIF(rh.[BuildingNo], N''), N'بدون سكن') AS [FullName_A]
    FROM ResidentHousing rh
    WHERE rh.[rn] = 1
    ORDER BY rh.[ResidentName_A] ASC;

    -- [16] المباني
    SELECT bd.[buildingDetailsNo]
    FROM [Housing].[BuildingDetails] bd
    INNER JOIN [Housing].[BuildingType] bt ON bd.[buildingTypeID_FK] = bt.[buildingTypeID]
    INNER JOIN [Housing].[MilitaryLocation] m ON bd.[militaryLocationID_FK] = m.[militaryLocationID]
    INNER JOIN [Housing].[BuildingClass] bc ON bd.[buildingClassID_FK] = bc.[buildingClassID]
    WHERE bd.[buildingDetailsActive] = 1
      AND bd.[IdaraId_FK] = @idaraID
      AND bt.[buildingTypeActive] = 1
      AND m.[militaryLocationActive] = 1
      AND bc.[buildingClassActive] = 1
    ORDER BY bd.[buildingDetailsNo] ASC;

    -- [17] أسباب البلاغ (القائمة تتبع الخدمة المختارة)
    SELECT [ticketReasonID], [ticketReasonName_A], [serviceID_FK]
    FROM [Tickets].[TicketReason]
    WHERE [ticketReasonActive] = 1
      AND ([idaraID_FK] = @idaraID OR [idaraID_FK] IS NULL)
    ORDER BY [displayOrder] ASC, [ticketReasonID] ASC;

END
GO
