SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [Tickets].[TicketDrawerDL]
(
      @pageName_   NVARCHAR(400)
    , @idaraID     INT
    , @entryData   INT
    , @hostName    NVARCHAR(400)
    , @ticketID    BIGINT
)
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- نافذة تفاصيل التذكرة (تُفتح من صفحة قائمة التذاكر): كل بيانات النافذة في استدعاء واحد.
    -- ترقيم الجداول في MVC بعد جدول الصلاحيات [0] من Masters_DataLoad:
    --   [1] صلاحيات المستخدم على صفحة TicketList (قراءة التذكرة تتطلب SELECT)
    --   [2] بيانات التذكرة   [3] سجل الإجراءات   [4] التذاكر الفرعية   [5] فترات الإيقاف
    --   [6] مراجعات الجودة   [7] طلبات التوضيح   [8] المرفقات
    -- الاستعلامات منقولة كما هي من Tickets.TicketDL مع ربطها بـ @ticketID وإدارة المستخدم.
    ----------------------------------------------------------------

    -- [1] صلاحيات صفحة قائمة التذاكر
    SELECT f.[permissionTypeName_E]
    FROM dbo.ft_UserPagePermissions(@entryData, N'TicketList') f;

    -- بدون صلاحية القراءة لا تُرجَع أي بيانات للتذكرة
    IF NOT EXISTS (SELECT 1 FROM dbo.ft_UserPagePermissions(@entryData, N'TicketList') f
                   WHERE f.[permissionTypeName_E] = N'SELECT')
        RETURN;

    IF @ticketID IS NULL OR @ticketID <= 0
        THROW 50001, N'معرف التذكرة مطلوب', 1;

    -- [2] بيانات التذكرة  (TicketDL: TicketDetails)
         SELECT
               t.[ticketID]
             , t.[ticketNo]
             , t.[idaraID_FK]
             , t.[parentTicketID_FK]
             , t.[rootTicketID_FK]
             , t.[serviceID_FK]
             , CASE
                 WHEN svc.[serviceName_A] IS NULL OR svc.[serviceName_A] NOT LIKE N'%[ء-ي]%'
                   THEN svc.[serviceName_E]
                 ELSE svc.[serviceName_A]
               END AS [serviceName_A]
             , svc.[serviceName_E]
             , t.[ticketClassID_FK]
             , CASE
                 WHEN tc.[ticketClassName_A] IS NULL OR tc.[ticketClassName_A] NOT LIKE N'%[ء-ي]%'
                   THEN tc.[ticketClassName_E]
                 ELSE tc.[ticketClassName_A]
               END AS [ticketClassName_A]
             , tc.[ticketClassName_E]
             , t.[requesterTypeID_FK]
             , CASE
                 WHEN rt.[requesterTypeName_A] IS NULL OR rt.[requesterTypeName_A] NOT LIKE N'%[ء-ي]%'
                   THEN rt.[requesterTypeName_E]
                 ELSE rt.[requesterTypeName_A]
               END AS [requesterTypeName_A]
             , rt.[requesterTypeName_E]
             , t.[requesterUserID_FK]
             , t.[requesterResidentID_FK]
             , t.[reporterName]
             , t.[reporterPhone]
             , COALESCE(NULLIF(t.[reporterName], N''), NULLIF(LTRIM(RTRIM(
                   ISNULL(rud.firstName_A, N'') + N' ' +
                   ISNULL(rud.secondName_A, N'') + N' ' +
                   ISNULL(rud.thirdName_A, N'') + N' ' +
                   ISNULL(rud.lastName_A, N'')
               )), N''),
                 NULLIF(rres.[ResidentName_A], N'')
               ) AS [requesterName] -- تعديل 05: إظهار اسم المستفيد عند عدم وجود مستخدم مقدم للبلاغ
             , COALESCE(t.[title_A], t.[title]) AS [title]
             , COALESCE(t.[description_A], t.[description_]) AS [description_]
             , t.[suggestedPriorityID_FK]
             , t.[effectivePriorityID_FK]
             , CASE
                 WHEN p.[priorityName_A] IS NULL OR p.[priorityName_A] NOT LIKE N'%[ء-ي]%'
                   THEN p.[priorityName_E]
                 ELSE p.[priorityName_A]
               END AS [priorityName_A]
             , p.[priorityName_E]
             , p.[priorityCode]
             , t.[ticketStatusID_FK]
             , ts.[ticketStatusCode]
             , CASE
                 WHEN ts.[ticketStatusName_A] IS NULL OR ts.[ticketStatusName_A] NOT LIKE N'%[ء-ي]%'
                   THEN ts.[ticketStatusName_E]
                 ELSE ts.[ticketStatusName_A]
               END AS [ticketStatusName_A]
             , ts.[ticketStatusName_E]
             , ts.[ticketStatusColor]
             , p.[priorityColor]
             , t.[currentDSDID_FK]
             , (SELECT TOP 1 COALESCE(NULLIF(LTRIM(RTRIM(COALESCE(f.[DepartmentName], N'')
                     + CASE WHEN f.[SectionName] IS NOT NULL THEN N' / ' + f.[SectionName] ELSE N'' END
                     + CASE WHEN f.[DivisonName] IS NOT NULL THEN N' / ' + f.[DivisonName] ELSE N'' END)), N''), f.[IdaraName])
                FROM dbo.V_GetFullStructureForDSD f WHERE f.[DSDID] = t.[currentDSDID_FK]) AS [currentDSDName_A]
             , t.[currentQueueDistributorID_FK]
             , t.[assignedUserID_FK]
             , LTRIM(RTRIM(
                   ISNULL(aud.firstName_A, N'') + N' ' +
                   ISNULL(aud.secondName_A, N'') + N' ' +
                   ISNULL(aud.thirdName_A, N'') + N' ' +
                   ISNULL(aud.lastName_A, N'')
               )) AS [assignedUserName]
             , t.[locationBuildingNo]
             , t.[locationUnitNo]
             , COALESCE(t.[locationArea_A], t.[locationArea]) AS [locationArea]
             , t.[operationalResolutionDate]
             , t.[finalClosureDate]
             , t.[requiresQualityReview]
             , t.[isOtherService]
             , t.[isParentBlocked]
             , t.[ticketActive]
             , svc.[allowsChildTickets]
             , sla.[elapsedMinutes]   AS [slaElapsedMinutes]
             , sla.[targetMinutes]    AS [slaTargetMinutes]
             , sla.[isBreached]       AS [slaIsBreached]
             , sla.[slaTypeCode]      AS [slaTypeCode]
             , t.[entryDate]
         FROM [Tickets].[Ticket] t
         LEFT JOIN [Tickets].[Service] svc ON t.[serviceID_FK] = svc.[serviceID]
         LEFT JOIN [Tickets].[TicketClass] tc ON t.[ticketClassID_FK] = tc.[ticketClassID]
         LEFT JOIN [Tickets].[RequesterType] rt ON t.[requesterTypeID_FK] = rt.[requesterTypeID]
         LEFT JOIN [Tickets].[Priority] p ON t.[effectivePriorityID_FK] = p.[priorityID]
         LEFT JOIN [Tickets].[TicketStatus] ts ON t.[ticketStatusID_FK] = ts.[ticketStatusID]
         -- Requester user name (active details row only)
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
         -- Assigned user name (active details row only)
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
         -- تعديل 05: جلب اسم المستفيد من بيانات السكن عند البلاغات المقدمة بواسطة مستفيد.
         OUTER APPLY (
             SELECT TOP (1) r.[FullName_A] AS [ResidentName_A]
             FROM [Housing].[V_GetFullResidentDetails] r
             WHERE r.[residentInfoID] = t.[requesterResidentID_FK]
               AND (r.[IdaraID] = @idaraID)
         ) rres
         -- Resolution SLA
         OUTER APPLY (
             SELECT TOP 1 sl.[elapsedMinutes], sl.[targetMinutes], sl.[isBreached], sl.[slaTypeCode]
             FROM [Tickets].[TicketSLA] sl
             WHERE sl.[ticketID_FK] = t.[ticketID]
               AND sl.[slaTypeCode] = N'RESOLUTION'
               AND sl.[ticketSLAActive] = 1
             -- تعديل 06: تحديد أحدث SLA نشط بدلاً من TOP 1 بدون ترتيب.
             ORDER BY sl.[ticketSLAID] DESC
         ) sla
         WHERE t.[ticketActive] = 1
           AND (t.[idaraID_FK] = @idaraID)
           AND t.[ticketID] = @ticketID
         ORDER BY t.[ticketID] DESC;

    -- [3] سجل الإجراءات  (TicketDL: TicketHistory)
         SELECT
               th.[ticketHistoryID]
             , th.[ticketID_FK]
             , th.[actionTypeCode]
             , COALESCE(hat.[actionTypeName_A], hat.[actionTypeName_E], th.[actionTypeCode]) AS [actionTypeName_A]
             , COALESCE(hat.[actionTypeName_E], th.[actionTypeCode]) AS [actionTypeName_E]
             , th.[oldStatusID_FK]
             , os.[ticketStatusCode]   AS [oldStatusCode]
             , os.[ticketStatusName_E] AS [oldStatusName_E] -- تعديل 04: عمود اللغة الإنجليزية يعيد الإنجليزية
             , os.[ticketStatusName_A] AS [oldStatusName_A]
             , th.[newStatusID_FK]
             , ns.[ticketStatusCode]   AS [newStatusCode]
             , ns.[ticketStatusName_E] AS [newStatusName_E] -- تعديل 04
             , ns.[ticketStatusName_A] AS [newStatusName_A]
             , th.[oldDSDID_FK]
             , th.[newDSDID_FK]
             , th.[oldAssignedUserID]
             , th.[newAssignedUserID]
             , th.[performerUserID]
             , LTRIM(RTRIM(
                   ISNULL(pud.firstName_A, N'') + N' ' +
                   ISNULL(pud.secondName_A, N'') + N' ' +
                   ISNULL(pud.thirdName_A, N'') + N' ' +
                   ISNULL(pud.lastName_A, N'')
               )) AS [performerName]
             , COALESCE(
                 NULLIF(th.[notes_A], N''),
                 -- تعديل 03: إصلاح ترميز الرسائل العربية التي كانت تظهر كرموز غير مفهومة.
                 CASE th.[notes]
                   WHEN N'Ticket created' THEN N'تم إنشاء التذكرة'
                   WHEN N'Ticket routed' THEN N'تم توجيه التذكرة'
                   WHEN N'Ticket assigned' THEN N'تم إسناد التذكرة'
                   WHEN N'Ticket reassigned' THEN N'تمت إعادة إسناد التذكرة'
                   WHEN N'Work started' THEN N'تم بدء العمل'
                   WHEN N'Ticket resolved - awaiting quality review' THEN N'تم حل التذكرة - بانتظار مراجعة الجودة'
                   WHEN N'Ticket resolved and closed' THEN N'تم حل التذكرة وإغلاقها'
                   WHEN N'Ticket closed' THEN N'تم إغلاق التذكرة'
                   WHEN N'Ticket paused' THEN N'تم إيقاف التذكرة'
                   WHEN N'Ticket resumed' THEN N'تم استئناف التذكرة'
                   WHEN N'Child ticket created' THEN N'تم إنشاء تذكرة فرعية'
                   WHEN N'Quality review approved - ticket closed' THEN N'تم اعتماد مراجعة الجودة - تم إغلاق التذكرة'
                   WHEN N'Quality review returned for correction' THEN N'تم إرجاع مراجعة الجودة للتصحيح'
                   WHEN N'Quality review escalated to arbitration' THEN N'تم تصعيد مراجعة الجودة إلى التحكيم'
                   WHEN N'Arbitration raised' THEN N'تم رفع التحكيم'
                   WHEN N'Arbitration decided' THEN N'تم اتخاذ قرار التحكيم'
                   ELSE th.[notes]
                 END
               ) AS [notes]
             , th.[actionDate]
         FROM [Tickets].[TicketHistory] th
         LEFT JOIN [Tickets].[TicketStatus] os ON th.[oldStatusID_FK] = os.[ticketStatusID]
         LEFT JOIN [Tickets].[TicketStatus] ns ON th.[newStatusID_FK] = ns.[ticketStatusID]
         LEFT JOIN [Tickets].[HistoryActionType] hat ON hat.[actionTypeCode] = th.[actionTypeCode] AND hat.[historyActionTypeActive] = 1
         OUTER APPLY (
             SELECT TOP 1
                   CASE WHEN ud.firstName_A IS NULL OR ud.firstName_A NOT LIKE N'%[ء-ي]%' THEN ud.firstName_E ELSE ud.firstName_A END AS firstName_A
                 , CASE WHEN ud.secondName_A IS NULL OR ud.secondName_A NOT LIKE N'%[ء-ي]%' THEN ud.secondName_E ELSE ud.secondName_A END AS secondName_A
                 , CASE WHEN ud.thirdName_A IS NULL OR ud.thirdName_A NOT LIKE N'%[ء-ي]%' THEN ud.thirdName_E ELSE ud.thirdName_A END AS thirdName_A
                 , CASE WHEN ud.lastName_A IS NULL OR ud.lastName_A NOT LIKE N'%[ء-ي]%' THEN ud.lastName_E ELSE ud.lastName_A END AS lastName_A
             FROM dbo.UsersDetails ud
             WHERE ud.usersID_FK = th.[performerUserID]
             ORDER BY ud.entryDate DESC, ud.usersDetailsID DESC
         ) pud
         WHERE th.[ticketID_FK] = @ticketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = th.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID))
         ORDER BY th.[ticketHistoryID];

    -- [4] التذاكر الفرعية  (TicketDL: ChildTickets)
         SELECT
               ct.[ticketID]
             , ct.[ticketNo]
             , COALESCE(ct.[title_A], ct.[title]) AS [title]
             , ts.[ticketStatusCode]
             , ts.[ticketStatusName_E] AS [ticketStatusName_E] -- تعديل 04
             , ts.[ticketStatusName_A]
             , ts.[ticketStatusColor]
             , p.[priorityName_E] AS [priorityName_E] -- تعديل 04
             , ct.[entryDate]
         FROM [Tickets].[Ticket] ct
         LEFT JOIN [Tickets].[TicketStatus] ts ON ct.[ticketStatusID_FK] = ts.[ticketStatusID]
         LEFT JOIN [Tickets].[Priority] p ON ct.[effectivePriorityID_FK] = p.[priorityID]
         WHERE ct.[parentTicketID_FK] = @ticketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ct.[parentTicketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID))
           AND ct.[ticketActive] = 1
         ORDER BY ct.[ticketID] DESC;

    -- [5] فترات الإيقاف  (TicketDL: PauseSessions)
         SELECT
               ps.[ticketPauseSessionID]
             , ps.[ticketID_FK]
             , pr.[pauseReasonName_A]
             , pr.[pauseReasonName_E]
             , ps.[relatedChildTicketID_FK]
             , ps.[relatedArbitrationCaseID_FK]
             , ps.[relatedClarificationRequestID_FK]
             , ps.[pauseStart]
             , ps.[pauseEnd]
             , ps.[slaPauseFlag]
             , COALESCE(ps.[pauseNotes_A], ps.[pauseNotes]) AS [pauseNotes]
             , ps.[ticketPauseSessionActive]
         FROM [Tickets].[TicketPauseSession] ps
         LEFT JOIN [Tickets].[PauseReason] pr ON ps.[pauseReasonID_FK] = pr.[pauseReasonID]
         WHERE ps.[ticketID_FK] = @ticketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ps.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID))
         ORDER BY ps.[ticketPauseSessionID] DESC;

    -- [6] مراجعات الجودة  (TicketDL: QualityReviews)
         SELECT
               qr.[qualityReviewID]
             , qr.[ticketID_FK]
             , qr.[reviewerUserID]
             , qr.[reviewScope]
             , qr.[qualityReviewResultID_FK]
             , qrr.[qualityReviewResultCode]
             , qrr.[qualityReviewResultName_A]
             , qrr.[qualityReviewResultName_E]
             , qr.[reviewNotes]
             , qr.[returnToUserID]
             , qr.[finalized]
             , qr.[entryDate]
         FROM [Tickets].[QualityReview] qr
         LEFT JOIN [Tickets].[QualityReviewResult] qrr ON qr.[qualityReviewResultID_FK] = qrr.[qualityReviewResultID]
         WHERE qr.[ticketID_FK] = @ticketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = qr.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID))
           AND qr.[qualityReviewActive] = 1
         ORDER BY qr.[qualityReviewID] DESC;

    -- [7] طلبات التوضيح  (TicketDL: ClarificationRequests)
         SELECT
               cr.[clarificationRequestID]
             , cr.[ticketID_FK]
             , cr.[clarificationStatus]
             , cr.[clarificationReasonID_FK]
             , COALESCE(r.[clarificationReasonName_A], r.[clarificationReasonName_E]) AS [clarificationReasonName_A]
             , cr.[requestedFromDSDID_FK]
             , cr.[requestedFromUserID]
             , COALESCE(cr.[requestNotes_A], cr.[requestNotes]) AS [requestText]
             , COALESCE(cr.[responseNotes_A], cr.[responseNotes]) AS [responseText]
             , cr.[requestDate]
             , cr.[responseDate]
         FROM [Tickets].[ClarificationRequest] cr
         -- The request is visible only through a ticket of the caller's Idara.
         INNER JOIN [Tickets].[Ticket] t
             ON t.[ticketID] = cr.[ticketID_FK]
            AND t.[idaraID_FK] = @idaraID
            AND t.[ticketActive] = 1
         LEFT JOIN [Tickets].[ClarificationReason] r ON r.[clarificationReasonID] = cr.[clarificationReasonID_FK]
         WHERE cr.[ticketID_FK] = @ticketID
           AND ISNULL(cr.[clarificationActive], 1) = 1
         ORDER BY cr.[clarificationRequestID] DESC;

    -- [8] المرفقات  (TicketDL: TicketAttachments)
         SELECT
               ta.[ticketAttachmentID]
             , ta.[ticketID_FK]
             , ta.[fileName]
             , ta.[storedFileName]
             , ta.[filePath]
             , ta.[fileSizeBytes]
             , ta.[contentType]
             , ta.[uploadedByUserID]
             , ta.[attachmentType]
             , ta.[entryDate]
         FROM [Tickets].[TicketAttachment] ta
         WHERE ta.[ticketID_FK] = @ticketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ta.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID))
           AND ta.[ticketAttachmentActive] = 1
         ORDER BY ta.[ticketAttachmentID] DESC;

END
GO
