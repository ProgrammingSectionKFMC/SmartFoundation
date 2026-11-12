SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [Tickets].[TicketAdminDL]
(
      @pageName_  NVARCHAR(400)
    , @idaraID    INT
    , @entryData  INT
    , @hostName   NVARCHAR(400)
    , @filterServiceID  BIGINT = NULL
    , @filterTicketClassID INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

  
        SELECT
              s.[serviceID]
            , s.[serviceCode]
            , s.[serviceName_A]
            , s.[serviceName_E]
            , s.[serviceDesc]
            , s.[idaraID_FK]
            , s.[ticketClassID_FK]
            , tc.[ticketClassName_A]
            , tc.[ticketClassName_E]
            , s.[defaultPriorityID_FK]
            , p.[priorityName_A]
            , p.[priorityName_E]
            , s.[requiresLocation]
            , s.[allowsChildTickets]
            , s.[requiresQualityReview]
            , s.[serviceActive]
        FROM [Tickets].[Service] s
        LEFT JOIN [Tickets].[TicketClass] tc ON s.[ticketClassID_FK] = tc.[ticketClassID]
        LEFT JOIN [Tickets].[Priority] p ON s.[defaultPriorityID_FK] = p.[priorityID]
        WHERE s.[serviceActive] = 1
          AND (s.[idaraID_FK] = @idaraID OR s.[idaraID_FK] IS NULL)
          AND (s.[serviceID] = @filterServiceID OR @filterServiceID IS NULL)
          AND (s.[ticketClassID_FK] = @filterTicketClassID OR @filterTicketClassID IS NULL)
        ORDER BY s.[serviceID] DESC;

        SELECT [ticketClassID], [ticketClassName_A], [ticketClassName_E]
        FROM [Tickets].[TicketClass]
        WHERE [ticketClassActive] = 1
        ORDER BY [ticketClassID];

        SELECT [priorityID], [priorityName_A], [priorityName_E]
        FROM [Tickets].[Priority]
        WHERE [priorityActive] = 1
        ORDER BY [priorityID];


        SELECT
              rr.[serviceRoutingRuleID]
            , rr.[serviceID_FK]
            , s.[serviceName_A]
            , s.[serviceName_E]
            , rr.[idaraID_FK]
            , rr.[targetDSDID_FK]
            , rr.[queueDistributorID_FK]
            , rr.[effectiveFrom]
            , rr.[effectiveTo]
            , rr.[changeReason]
            , rr.[serviceRoutingRuleActive]
        FROM [Tickets].[ServiceRoutingRule] rr
        INNER JOIN [Tickets].[Service] s ON rr.[serviceID_FK] = s.[serviceID]
        --WHERE rr.[serviceRoutingRuleActive] = 1
        --  AND (rr.[idaraID_FK] = @idaraID OR rr.[idaraID_FK] IS NULL)
        --  AND rr.[effectiveFrom] <= GETDATE()
        --  AND (rr.[effectiveTo] IS NULL OR rr.[effectiveTo] > GETDATE())
        --ORDER BY rr.[serviceRoutingRuleID] DESC;

        WHERE rr.[serviceRoutingRuleActive] = 1
           AND s.[serviceActive] = 1
           AND (rr.[idaraID_FK] = @idaraID
                OR rr.[idaraID_FK] IS NULL)
           AND (s.[idaraID_FK] = @idaraID
                OR s.[idaraID_FK] IS NULL)
           AND rr.[effectiveFrom] <= GETDATE()
           AND (rr.[effectiveTo] IS NULL
                OR rr.[effectiveTo] > GETDATE())

        SELECT
              sp.[serviceSLAPolicyID]
            , sp.[serviceID_FK]
            , s.[serviceName_A]
            , s.[serviceName_E]
            , sp.[priorityID_FK]
            , p.[priorityName_A]
            , sp.[firstResponseTargetMinutes]
            , sp.[assignmentTargetMinutes]
            , sp.[operationalCompletionTargetMinutes]
            , sp.[finalClosureTargetMinutes]
            , sp.[slaPolicyActive]
        FROM [Tickets].[ServiceSLAPolicy] sp
        INNER JOIN [Tickets].[Service] s ON sp.[serviceID_FK] = s.[serviceID]
        INNER JOIN [Tickets].[Priority] p ON sp.[priorityID_FK] = p.[priorityID]
        --WHERE sp.[slaPolicyActive] = 1
        --  AND (sp.[idaraID_FK] = @idaraID OR sp.[idaraID_FK] IS NULL)
        --ORDER BY sp.[serviceSLAPolicyID] DESC;

        WHERE sp.[slaPolicyActive] = 1
           AND s.[serviceActive] = 1
           AND p.[priorityActive] = 1
           AND (sp.[idaraID_FK] = @idaraID
                OR sp.[idaraID_FK] IS NULL)
           AND (s.[idaraID_FK] = @idaraID
                OR s.[idaraID_FK] IS NULL)

        SELECT
              scs.[serviceCatalogSuggestionID]
            , scs.[sourceTicketID_FK]
            , scs.[idaraID_FK]
            , scs.[proposedServiceName_A]
            , scs.[proposedServiceName_E]
            , scs.[proposedServiceDesc]
            , scs.[proposedTargetDSDID_FK]
            , scs.[proposedPriorityID_FK]
            , scs.[approvalStatus]
            , scs.[approvedByUserID]
            , scs.[approvalDate]
            , scs.[createdServiceID_FK]
            , scs.[suggestionActive]
        FROM [Tickets].[ServiceCatalogSuggestion] scs
        WHERE (scs.[idaraID_FK] = @idaraID OR scs.[idaraID_FK] IS NULL)
          AND scs.[suggestionActive] = 1
        ORDER BY scs.[serviceCatalogSuggestionID] DESC;

         SELECT s.[serviceID], s.[serviceName_A], s.[serviceName_E], s.[ticketClassID_FK]
        FROM [Tickets].[Service] s
        WHERE s.[serviceActive] = 1
          AND (s.[idaraID_FK] = @idaraID OR s.[idaraID_FK] IS NULL)
        ORDER BY s.[serviceName_A];


        ----------------------------------------------------------------
        -- تبويبات إعدادات التذاكر (تُضاف بعد الجداول السابقة دون تغيير ترتيبها)
        -- ترقيم الجداول في MVC بعد جدول الصلاحيات [0]:
        --   [8] فئات التذاكر   [9] الأولويات   [10] حالات التذكرة   [11] أسباب الإيقاف
        --   [12] أسباب التحكيم [13] نتائج مراجعة الجودة   [14] قضايا التحكيم المفتوحة
        --   [15] الجهات (قائمة الجهة المحوَّل إليها في قرار التحكيم)
        -- الحذف في هذه الجداول إيقاف (Active = 0)، لذلك تُعرض الصفوف النشطة فقط.
        ----------------------------------------------------------------

        SELECT [ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E],
               COALESCE(NULLIF([ticketClassDesc_A], N''), [ticketClassDesc]) AS [ticketClassDesc], [entryDate]
        FROM [Tickets].[TicketClass]
        WHERE [ticketClassActive] = 1
        ORDER BY [ticketClassID];

        SELECT [priorityID], [priorityCode], [priorityName_A], [priorityName_E],
               COALESCE(NULLIF([priorityDesc_A], N''), [priorityDesc]) AS [priorityDesc], [priorityLevel], [entryDate]
        FROM [Tickets].[Priority]
        WHERE [priorityActive] = 1
        ORDER BY [priorityLevel], [priorityID];

        SELECT [ticketStatusID], [ticketStatusCode], [ticketStatusName_A], [ticketStatusName_E],
               COALESCE(NULLIF([ticketStatusDesc_A], N''), [ticketStatusDesc]) AS [ticketStatusDesc], [entryDate]
        FROM [Tickets].[TicketStatus]
        WHERE [ticketStatusActive] = 1
        ORDER BY [ticketStatusID];

        SELECT [pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E],
               COALESCE(NULLIF([pauseReasonDesc_A], N''), [pauseReasonDesc]) AS [pauseReasonDesc], [entryDate]
        FROM [Tickets].[PauseReason]
        WHERE [pauseReasonActive] = 1
        ORDER BY [pauseReasonID];

        SELECT [arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E],
               COALESCE(NULLIF([arbitrationReasonDesc_A], N''), [arbitrationReasonDesc]) AS [arbitrationReasonDesc], [entryDate]
        FROM [Tickets].[ArbitrationReason]
        WHERE [arbitrationReasonActive] = 1
        ORDER BY [arbitrationReasonID];

        SELECT [qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E],
               COALESCE(NULLIF([qualityReviewResultDesc_A], N''), [qualityReviewResultDesc]) AS [qualityReviewResultDesc], [entryDate]
        FROM [Tickets].[QualityReviewResult]
        WHERE [qualityReviewResultActive] = 1
        ORDER BY [qualityReviewResultID];

        SELECT
              ac.[arbitrationCaseID]
            , ac.[ticketID_FK]
            , t.[ticketNo]
            , COALESCE(t.[title_A], t.[title]) AS [title]
            , COALESCE(ar.[arbitrationReasonName_A], ar.[arbitrationReasonName_E]) AS [arbitrationReasonName_A]
            , ac.[arbitrationStatus]
            , ac.[entryDate]
        FROM [Tickets].[ArbitrationCase] ac
        INNER JOIN [Tickets].[Ticket] t ON ac.[ticketID_FK] = t.[ticketID]
        LEFT JOIN [Tickets].[ArbitrationReason] ar ON ac.[arbitrationReasonID_FK] = ar.[arbitrationReasonID]
        WHERE ac.[arbitrationStatus] = N'OPEN'
          AND ac.[arbitrationCaseActive] = 1
          AND ac.[idaraID_FK] = @idaraID
          AND t.[idaraID_FK] = @idaraID
        ORDER BY ac.[arbitrationCaseID] DESC;

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

        ----------------------------------------------------------------
        -- الجهة المسؤولة عن الخدمة (قسم ← فرع ← شعبة)
        --   [16] الأقسام (القائمة الأولى في نموذج الخدمة)
        --   [17] شجرة الجهات: القائمتان الثانية والثالثة عبر /crud/DDLFiltered
        --        (PageName=TicketAdmin&TableIndex=17&FK=parentDSDID)
        --   [18] الجهة الحالية لكل خدمة مفكّكة إلى قسم/فرع/شعبة لتعبئة نموذج التعديل
        ----------------------------------------------------------------

        ;WITH u AS (
            SELECT x.[DSDID], x.[deptID_FK], x.[secID_FK], x.[divID_FK]
                 , dp.[deptName_A], s.[secName_A], v.[divName_A]
                 , ROW_NUMBER() OVER (PARTITION BY x.[deptID_FK], x.[secID_FK], x.[divID_FK] ORDER BY x.[DSDID]) AS rn
            FROM dbo.DeptSecDiv x
            INNER JOIN dbo.Department dp ON dp.[deptID] = x.[deptID_FK] AND ISNULL(dp.[deptActive], 1) = 1
            LEFT JOIN dbo.Section s ON s.[secID] = x.[secID_FK]
            LEFT JOIN dbo.Divison v ON v.[divID] = x.[divID_FK]
            WHERE x.[idaraID_FK] = @idaraID
              AND NOT (x.[secID_FK] IS NULL AND x.[divID_FK] IS NOT NULL)
              AND (x.[secID_FK] IS NULL OR ISNULL(s.[secActive], 1) = 1)
              AND (x.[divID_FK] IS NULL OR ISNULL(v.[divActive], 1) = 1)
        ), t AS (SELECT * FROM u WHERE rn = 1)
        SELECT t.[DSDID], t.[deptName_A]
        FROM t
        WHERE t.[secID_FK] IS NULL AND t.[divID_FK] IS NULL
        ORDER BY t.[deptName_A];

        ;WITH u AS (
            SELECT x.[DSDID], x.[deptID_FK], x.[secID_FK], x.[divID_FK]
                 , dp.[deptName_A], s.[secName_A], v.[divName_A]
                 , ROW_NUMBER() OVER (PARTITION BY x.[deptID_FK], x.[secID_FK], x.[divID_FK] ORDER BY x.[DSDID]) AS rn
            FROM dbo.DeptSecDiv x
            INNER JOIN dbo.Department dp ON dp.[deptID] = x.[deptID_FK] AND ISNULL(dp.[deptActive], 1) = 1
            LEFT JOIN dbo.Section s ON s.[secID] = x.[secID_FK]
            LEFT JOIN dbo.Divison v ON v.[divID] = x.[divID_FK]
            WHERE x.[idaraID_FK] = @idaraID
              AND NOT (x.[secID_FK] IS NULL AND x.[divID_FK] IS NOT NULL)
              AND (x.[secID_FK] IS NULL OR ISNULL(s.[secActive], 1) = 1)
              AND (x.[divID_FK] IS NULL OR ISNULL(v.[divActive], 1) = 1)
        ), t AS (SELECT * FROM u WHERE rn = 1)
        SELECT
              t.[DSDID]
            , CASE
                  WHEN t.[divID_FK] IS NOT NULL THEN (SELECT MIN(p.[DSDID]) FROM t p
                       WHERE p.[deptID_FK] = t.[deptID_FK] AND p.[secID_FK] = t.[secID_FK] AND p.[divID_FK] IS NULL)
                  WHEN t.[secID_FK] IS NOT NULL THEN (SELECT MIN(p.[DSDID]) FROM t p
                       WHERE p.[deptID_FK] = t.[deptID_FK] AND p.[secID_FK] IS NULL AND p.[divID_FK] IS NULL)
                  ELSE 0
              END AS [parentDSDID]
            , COALESCE(t.[divName_A], t.[secName_A], t.[deptName_A]) AS [nodeName_A]
        FROM t
        ORDER BY t.[deptName_A], t.[secName_A], t.[divName_A];

        ;WITH u AS (
            SELECT x.[DSDID], x.[deptID_FK], x.[secID_FK], x.[divID_FK]
                 , dp.[deptName_A], s.[secName_A], v.[divName_A]
                 , ROW_NUMBER() OVER (PARTITION BY x.[deptID_FK], x.[secID_FK], x.[divID_FK] ORDER BY x.[DSDID]) AS rn
            FROM dbo.DeptSecDiv x
            INNER JOIN dbo.Department dp ON dp.[deptID] = x.[deptID_FK] AND ISNULL(dp.[deptActive], 1) = 1
            LEFT JOIN dbo.Section s ON s.[secID] = x.[secID_FK]
            LEFT JOIN dbo.Divison v ON v.[divID] = x.[divID_FK]
            WHERE x.[idaraID_FK] = @idaraID
        ), t AS (SELECT * FROM u WHERE rn = 1)
        , r AS (
            SELECT [serviceID_FK], [targetDSDID_FK]
                 , ROW_NUMBER() OVER (PARTITION BY [serviceID_FK] ORDER BY [effectiveFrom] DESC, [serviceRoutingRuleID] DESC) AS rn
            FROM [Tickets].[ServiceRoutingRule]
            WHERE [idaraID_FK] = @idaraID
              AND [serviceRoutingRuleActive] = 1
              AND ([effectiveTo] IS NULL OR [effectiveTo] > GETDATE())
        )
        SELECT
              r.[serviceID_FK] AS [serviceID]
            , r.[targetDSDID_FK] AS [targetDSDID]
            , x.[deptName_A] + ISNULL(N' / ' + x.[secName_A], N'') + ISNULL(N' / ' + x.[divName_A], N'') AS [responsibleUnit]
            , (SELECT MIN(p.[DSDID]) FROM t p
               WHERE p.[deptID_FK] = x.[deptID_FK] AND p.[secID_FK] IS NULL AND p.[divID_FK] IS NULL) AS [unitDeptDSDID]
            , CASE WHEN x.[secID_FK] IS NOT NULL THEN (SELECT MIN(p.[DSDID]) FROM t p
               WHERE p.[deptID_FK] = x.[deptID_FK] AND p.[secID_FK] = x.[secID_FK] AND p.[divID_FK] IS NULL) END AS [unitSecDSDID]
            , CASE WHEN x.[divID_FK] IS NOT NULL THEN x.[DSDID] END AS [unitDivDSDID]
        FROM r
        INNER JOIN u x ON x.[DSDID] = r.[targetDSDID_FK]
        WHERE r.rn = 1;

END
GO
