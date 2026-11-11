CREATE PROCEDURE [Tickets].[TicketDL]
 (
       @pageName_          NVARCHAR(400)
     , @idaraID            INT
     , @entryData          INT
     , @hostName           NVARCHAR(400)
     , @filterTicketID     BIGINT = NULL
     , @filterTicketNo     NVARCHAR(50) = NULL
     , @filterStatusID     INT = NULL
     , @filterServiceID    BIGINT = NULL
     , @filterAssignedUserID INT = NULL
     , @filterDSDID        INT = NULL
 )
 AS
 BEGIN
     SET NOCOUNT ON;

     -- تنبيه أمني: تمرير NULL في @idaraID يعرض سجلات جميع الإدارات في بعض الصفحات.
     -- يجب أن يحدد المستدعي صلاحية الاستعلام الشامل؛ لا تعتبر قيمة NULL تصريحًا تلقائيًا.
     -- تعديل 02: التحقق من معرف التذكرة قبل صفحات التفاصيل التابعة لها.
     IF @pageName_ IN (N'TicketHistory', N'ChildTickets', N'PauseSessions', N'TicketSLAs',
                        N'QualityReviews', N'ArbitrationCases', N'TicketAttachments')
        AND (@filterTicketID IS NULL OR @filterTicketID <= 0)
     BEGIN
         ;THROW 50001, N'معرف التذكرة مطلوب', 1;
     END


     IF @pageName_ = N'TicketDetails' OR @pageName_ IS NULL
     BEGIN
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
               AND (r.[IdaraID] = @idaraID OR @idaraID IS NULL)
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
           AND (t.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
           AND (t.[ticketID] = @filterTicketID OR @filterTicketID IS NULL)
           AND (t.[ticketNo] = @filterTicketNo OR @filterTicketNo IS NULL)
           AND (t.[ticketStatusID_FK] = @filterStatusID OR @filterStatusID IS NULL)
           AND (t.[serviceID_FK] = @filterServiceID OR @filterServiceID IS NULL)
           AND (t.[assignedUserID_FK] = @filterAssignedUserID OR @filterAssignedUserID IS NULL)
           AND (t.[currentDSDID_FK] = @filterDSDID OR @filterDSDID IS NULL)
         ORDER BY t.[ticketID] DESC;

         RETURN;
     END

     IF @pageName_ = N'TicketList'
     BEGIN
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
         -- Requester resident name (for RESIDENT type tickets where requesterUserID_FK is NULL)
         OUTER APPLY (
             SELECT TOP 1 r.[FullName_A] AS [ResidentName_A]
             FROM [Housing].[V_GetFullResidentDetails] r
             WHERE r.[residentInfoID] = t.[requesterResidentID_FK]
         ) rres
         -- Resolution SLA elapsed minutes
         OUTER APPLY (
             SELECT TOP 1 sl.[elapsedMinutes]
             FROM [Tickets].[TicketSLA] sl
             WHERE sl.[ticketID_FK] = t.[ticketID]
               AND sl.[slaTypeCode] = N'RESOLUTION'
               AND sl.[ticketSLAActive] = 1
             -- تعديل 06: تحديد أحدث SLA نشط بدلاً من TOP 1 بدون ترتيب.
             ORDER BY sl.[ticketSLAID] DESC
         ) sla
         -- Current DSD name (department/section/division) for tickets not yet assigned to a user
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
           AND (t.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
           AND (t.[ticketStatusID_FK] = @filterStatusID OR @filterStatusID IS NULL)
           AND (t.[serviceID_FK] = @filterServiceID OR @filterServiceID IS NULL)
           AND (t.[currentDSDID_FK] = @filterDSDID OR @filterDSDID IS NULL)
         ORDER BY t.[ticketID] DESC;

         SELECT [ticketStatusID], [ticketStatusName_A], [ticketStatusName_E]
         FROM [Tickets].[TicketStatus]
         WHERE [ticketStatusActive] = 1
         ORDER BY [ticketStatusID];

         SELECT [serviceID], [serviceName_A], [serviceName_E]
         FROM [Tickets].[Service]
         WHERE [serviceActive] = 1
           AND ([idaraID_FK] = @idaraID OR @idaraID IS NULL OR [idaraID_FK] IS NULL)
         ORDER BY [serviceID];

         RETURN;
     END

     IF @pageName_ = N'TicketHistory'
     BEGIN
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
         WHERE th.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = th.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
         ORDER BY th.[ticketHistoryID];

         RETURN;
     END

     IF @pageName_ = N'StatusDDL'
     BEGIN
         SELECT [ticketStatusID], [ticketStatusCode], [ticketStatusName_A], [ticketStatusName_E]
         FROM [Tickets].[TicketStatus]
         WHERE [ticketStatusActive] = 1
         ORDER BY [ticketStatusID];

         RETURN;
     END

     IF @pageName_ = N'ChildTickets'
     BEGIN
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
         WHERE ct.[parentTicketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ct.[parentTicketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
           AND ct.[ticketActive] = 1
         ORDER BY ct.[ticketID] DESC;

         RETURN;
     END

     IF @pageName_ = N'PauseSessions'
     BEGIN
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
         WHERE ps.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ps.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
         ORDER BY ps.[ticketPauseSessionID] DESC;

         RETURN;
     END

     IF @pageName_ = N'TicketSLAs'
     BEGIN
         SELECT
               sla.[ticketSLAID]
             , sla.[ticketID_FK]
             , sla.[slaTypeCode]
             , sla.[targetMinutes]
             , sla.[elapsedMinutes]
             , sla.[remainingMinutes]
             , sla.[isBreached]
             , sla.[slaStartDate]
             , sla.[slaStopDate]
             , sla.[slaCompletionDate]
             , sla.[ticketSLAActive]
         FROM [Tickets].[TicketSLA] sla
         WHERE sla.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = sla.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
           AND sla.[ticketSLAActive] = 1
         ORDER BY sla.[ticketSLAID];

         RETURN;
     END

     IF @pageName_ = N'QualityReviews'
     BEGIN
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
         WHERE qr.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = qr.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
           AND qr.[qualityReviewActive] = 1
         ORDER BY qr.[qualityReviewID] DESC;

         RETURN;
     END

     IF @pageName_ = N'ArbitrationCases'
     BEGIN
         SELECT
               ac.[arbitrationCaseID]
             , ac.[ticketID_FK]
             , ac.[raisedByUserID]
             , ac.[raisedFromDSDID_FK]
             , ar.[arbitrationReasonName_A]
             , ar.[arbitrationReasonName_E]
             , ac.[arbitratorDistributorID]
             , ac.[arbitrationStatus]
             , ac.[decisionType]
             , ac.[decisionTargetDSDID_FK]
             , ac.[decisionNotes]
             , ac.[decisionDate]
             , ac.[entryDate]
         FROM [Tickets].[ArbitrationCase] ac
         LEFT JOIN [Tickets].[ArbitrationReason] ar ON ac.[arbitrationReasonID_FK] = ar.[arbitrationReasonID]
         WHERE ac.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ac.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
           AND ac.[arbitrationCaseActive] = 1
         ORDER BY ac.[arbitrationCaseID] DESC;

         RETURN;
     END

     IF @pageName_ = N'TicketAttachments'
     BEGIN
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
         WHERE ta.[ticketID_FK] = @filterTicketID
           -- تعديل 07: منع قراءة تفاصيل تذكرة من إدارة أخرى.
           AND EXISTS (SELECT 1 FROM [Tickets].[Ticket] parentTicket
                       WHERE parentTicket.[ticketID] = ta.[ticketID_FK]
                         AND (parentTicket.[idaraID_FK] = @idaraID OR @idaraID IS NULL))
           AND ta.[ticketAttachmentActive] = 1
         ORDER BY ta.[ticketAttachmentID] DESC;

         RETURN;
     END

     IF @pageName_ = N'PauseReasonDDL'
     BEGIN
         SELECT [pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E]
         FROM [Tickets].[PauseReason]
         WHERE [pauseReasonActive] = 1
           -- Set automatically by child tickets, arbitration and clarification; not a manual choice.
           AND [pauseReasonCode] NOT IN (N'CHILD_DEPENDENCY', N'ARBITRATION', N'CLARIFICATION')
         ORDER BY [pauseReasonID];

         RETURN;
     END

     IF @pageName_ = N'ArbitrationReasonDDL'
     BEGIN
         SELECT [arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E]
         FROM [Tickets].[ArbitrationReason]
         WHERE [arbitrationReasonActive] = 1
         ORDER BY [arbitrationReasonID];

         RETURN;
     END

     IF @pageName_ = N'QualityReviewResultDDL'
     BEGIN
         SELECT [qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E]
         FROM [Tickets].[QualityReviewResult]
         WHERE [qualityReviewResultActive] = 1
         ORDER BY [qualityReviewResultID];

         RETURN;
     END

     IF @pageName_ = N'RequesterTypeDDL'
     BEGIN
         SELECT [requesterTypeID], [requesterTypeCode], [requesterTypeName_A], [requesterTypeName_E]
         FROM [Tickets].[RequesterType]
         WHERE [requesterTypeActive] = 1
         ORDER BY [requesterTypeID];

         RETURN;
     END

     IF @pageName_ = N'TicketClassDDL'
     BEGIN
         SELECT [ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E]
         FROM [Tickets].[TicketClass]
         WHERE [ticketClassActive] = 1
         ORDER BY [ticketClassID];

         RETURN;
     END

     IF @pageName_ = N'ClarificationReasonDDL'
     BEGIN
         SELECT [clarificationReasonID], [clarificationReasonCode], [clarificationReasonName_A], [clarificationReasonName_E]
         FROM [Tickets].[ClarificationReason]
         WHERE [clarificationReasonActive] = 1
         ORDER BY [clarificationReasonID];

         RETURN;
     END

     IF @pageName_ = N'ClarificationRequests'
     BEGIN
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
         LEFT JOIN [Tickets].[ClarificationReason] r ON r.[clarificationReasonID] = cr.[clarificationReasonID_FK]
         WHERE cr.[ticketID_FK] = @filterTicketID
           AND ISNULL(cr.[clarificationActive], 1) = 1
         ORDER BY cr.[clarificationRequestID] DESC;

         RETURN;
     END

     IF @pageName_ = N'PriorityDDL'
     BEGIN
         SELECT [priorityID], [priorityCode], [priorityName_A], [priorityName_E]
         FROM [Tickets].[Priority]
         WHERE [priorityActive] = 1
         ORDER BY [priorityID];

         RETURN;
     END

     IF @pageName_ = N'OpenArbitrations'
     BEGIN
         SELECT
               ac.[arbitrationCaseID]
             , ac.[ticketID_FK]
             , t.[ticketNo]
             , COALESCE(t.[title_A], t.[title]) AS [title]
             , COALESCE(ar.[arbitrationReasonName_A], ar.[arbitrationReasonName_E]) AS [arbitrationReasonName_A]
             , ar.[arbitrationReasonName_E] AS [arbitrationReasonName_E] -- تعديل 04
             , ac.[arbitrationStatus]
             , ac.[entryDate]
         FROM [Tickets].[ArbitrationCase] ac
         INNER JOIN [Tickets].[Ticket] t ON ac.[ticketID_FK] = t.[ticketID]
         LEFT JOIN [Tickets].[ArbitrationReason] ar ON ac.[arbitrationReasonID_FK] = ar.[arbitrationReasonID]
         WHERE ac.[arbitrationStatus] = N'OPEN'
           AND ac.[arbitrationCaseActive] = 1
           AND (ac.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
           -- تعديل 09: التحقق أيضًا من نطاق الإدارة في التذكرة المرتبطة.
           AND (t.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
         ORDER BY ac.[arbitrationCaseID] DESC;

         RETURN;
     END

     IF @pageName_ = N'PendingReviews'
     BEGIN
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
           AND (qr.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
           -- تعديل 09: التحقق أيضًا من نطاق الإدارة في التذكرة المرتبطة.
           AND (t.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
         ORDER BY qr.[qualityReviewID] DESC;

         RETURN;
     END

     IF @pageName_ = N'BreachedSLAs'
     BEGIN
         SELECT
               sla.[ticketSLAID]
             , sla.[ticketID_FK]
             , t.[ticketNo]
             , COALESCE(t.[title_A], t.[title]) AS [title]
             , sla.[slaTypeCode]
             , sla.[targetMinutes]
             , sla.[elapsedMinutes]
             , sla.[isBreached]
             , sla.[slaStartDate]
         FROM [Tickets].[TicketSLA] sla
         INNER JOIN [Tickets].[Ticket] t ON sla.[ticketID_FK] = t.[ticketID]
         WHERE sla.[isBreached] = 1
           AND sla.[ticketSLAActive] = 1
           AND (sla.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
           -- تعديل 09: التحقق أيضًا من نطاق الإدارة في التذكرة المرتبطة.
           AND (t.[idaraID_FK] = @idaraID OR @idaraID IS NULL)
         ORDER BY sla.[ticketSLAID] DESC;

         RETURN;
     END

     IF @pageName_ = N'TicketAdminLookup'
     BEGIN
         -- TicketAdmin tabs: active rows only (delete = deactivate); Arabic description first.
         SELECT [ticketStatusID], [ticketStatusCode], [ticketStatusName_A], [ticketStatusName_E],
                COALESCE(NULLIF([ticketStatusDesc_A], N''), [ticketStatusDesc]) AS [ticketStatusDesc], [entryDate]
         FROM [Tickets].[TicketStatus] WHERE [ticketStatusActive] = 1 ORDER BY [ticketStatusID];

         SELECT [pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E],
                COALESCE(NULLIF([pauseReasonDesc_A], N''), [pauseReasonDesc]) AS [pauseReasonDesc], [entryDate]
         FROM [Tickets].[PauseReason] WHERE [pauseReasonActive] = 1 ORDER BY [pauseReasonID];

         SELECT [arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E],
                COALESCE(NULLIF([arbitrationReasonDesc_A], N''), [arbitrationReasonDesc]) AS [arbitrationReasonDesc], [entryDate]
         FROM [Tickets].[ArbitrationReason] WHERE [arbitrationReasonActive] = 1 ORDER BY [arbitrationReasonID];

         SELECT [qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E],
                COALESCE(NULLIF([qualityReviewResultDesc_A], N''), [qualityReviewResultDesc]) AS [qualityReviewResultDesc], [entryDate]
         FROM [Tickets].[QualityReviewResult] WHERE [qualityReviewResultActive] = 1 ORDER BY [qualityReviewResultID];

         SELECT [ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E],
                COALESCE(NULLIF([ticketClassDesc_A], N''), [ticketClassDesc]) AS [ticketClassDesc], [entryDate]
         FROM [Tickets].[TicketClass] WHERE [ticketClassActive] = 1 ORDER BY [ticketClassID];

         SELECT [priorityID], [priorityCode], [priorityName_A], [priorityName_E],
                COALESCE(NULLIF([priorityDesc_A], N''), [priorityDesc]) AS [priorityDesc], [priorityLevel], [entryDate]
         FROM [Tickets].[Priority] WHERE [priorityActive] = 1 ORDER BY [priorityLevel], [priorityID];

         RETURN;
     END

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
           + COALESCE(NULLIF(rh.[NationalID], N''), CONVERT(NVARCHAR(50), rh.[generalNo_FK]), N'-')
           + N' | السكن: '
           + COALESCE(NULLIF(rh.[BuildingNo], N''), N'بدون سكن') AS [FullName_A],
         rh.[ResidentName_A]
           + N' | هوية: '
           + COALESCE(NULLIF(rh.[NationalID], N''), CONVERT(NVARCHAR(50), rh.[generalNo_FK]), N'-')
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

     IF @pageName_ = N'BuildingDDL'
     BEGIN
         SELECT
             bd.[buildingDetailsID] AS [buildingDetailsID],
             bd.[buildingDetailsNo] AS [buildingDetailsNo],
             bd.[buildingDetailsRooms] AS [buildingDetailsRooms],
             bt.[buildingTypeName_A] AS [buildingTypeName_A],
             m.[militaryLocationName_A] AS [militaryLocationName_A],
             bc.[buildingClassName_A] AS [buildingClassName_A]
         FROM [DATACORE].[Housing].[BuildingDetails] bd
         INNER JOIN [DATACORE].[Housing].[BuildingType] bt ON bd.[buildingTypeID_FK] = bt.[buildingTypeID]
         INNER JOIN [DATACORE].[Housing].[MilitaryLocation] m ON bd.[militaryLocationID_FK] = m.[militaryLocationID]
         INNER JOIN [DATACORE].[Housing].[BuildingClass] bc ON bd.[buildingClassID_FK] = bc.[buildingClassID]
         WHERE bd.[buildingDetailsActive] = 1
           AND bd.[IdaraId_FK] = @idaraID
           AND bt.[buildingTypeActive] = 1
           AND m.[militaryLocationActive] = 1
           AND bc.[buildingClassActive] = 1
         ORDER BY bd.[buildingDetailsNo] ASC;

         RETURN;
     END

     IF @pageName_ = N'TicketReasonDDL'
     BEGIN
         SELECT
             [ticketReasonID],
             [ticketReasonCode],
             [ticketReasonName_A],
             [ticketReasonName_E],
             [priorityID_FK]
             , [serviceID_FK]
         FROM [Tickets].[TicketReason]
         WHERE [ticketReasonActive] = 1
           AND ([idaraID_FK] = @idaraID OR [idaraID_FK] IS NULL)
         ORDER BY [displayOrder] ASC, [ticketReasonID] ASC;

         RETURN;
     END

     IF @pageName_ = N'TicketDescriptionTemplateDDL'
     BEGIN
         SELECT
             [templateID],
             [templateCode],
             [templateName_A],
             [templateName_E],
             [templateContent_A]
             , [serviceID_FK]
         FROM [Tickets].[TicketDescriptionTemplate]
         WHERE [templateActive] = 1
           AND ([idaraID_FK] = @idaraID OR [idaraID_FK] IS NULL)
         ORDER BY [displayOrder] ASC, [templateID] ASC;

         RETURN;
     END

     -- Unit tree for the service form (department / branch / section) and each service's current unit.
     -- Table 1: one row per unit with its parent unit (0 for departments); filtered by DDLFiltered on parentDSDID.
     -- Table 2: the active routing target of each service.
     IF @pageName_ = N'DSDTreeDDL'
     BEGIN
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
             , CASE WHEN t.[divID_FK] IS NOT NULL THEN 3 WHEN t.[secID_FK] IS NOT NULL THEN 2 ELSE 1 END AS [dsdLevel]
             , CASE
                   WHEN t.[divID_FK] IS NOT NULL THEN (SELECT MIN(p.[DSDID]) FROM t p
                        WHERE p.[deptID_FK] = t.[deptID_FK] AND p.[secID_FK] = t.[secID_FK] AND p.[divID_FK] IS NULL)
                   WHEN t.[secID_FK] IS NOT NULL THEN (SELECT MIN(p.[DSDID]) FROM t p
                        WHERE p.[deptID_FK] = t.[deptID_FK] AND p.[secID_FK] IS NULL AND p.[divID_FK] IS NULL)
                   ELSE 0
               END AS [parentDSDID]
             , COALESCE(t.[divName_A], t.[secName_A], t.[deptName_A]) AS [nodeName_A]
             , t.[deptName_A] + ISNULL(N' / ' + t.[secName_A], N'') + ISNULL(N' / ' + t.[divName_A], N'') AS [dsdName_A]
         FROM t
         ORDER BY t.[deptName_A], t.[secName_A], t.[divName_A];

         SELECT r.[serviceID_FK] AS [serviceID], r.[targetDSDID_FK] AS [targetDSDID]
         FROM (
             SELECT [serviceID_FK], [targetDSDID_FK]
                  , ROW_NUMBER() OVER (PARTITION BY [serviceID_FK] ORDER BY [effectiveFrom] DESC, [serviceRoutingRuleID] DESC) AS rn
             FROM [Tickets].[ServiceRoutingRule]
             WHERE [idaraID_FK] = @idaraID
               AND [serviceRoutingRuleActive] = 1
               AND ([effectiveTo] IS NULL OR [effectiveTo] > GETDATE())
         ) r
         WHERE r.rn = 1;

         RETURN;
     END

     IF @pageName_ = N'DSDDL'
     BEGIN
         SELECT
               f.[DSDID]
             , COALESCE(
                 NULLIF(
                     LTRIM(RTRIM(
                         COALESCE(f.[DepartmentName], N'')
                         + CASE WHEN f.[SectionName]  IS NOT NULL THEN N' / ' + f.[SectionName]  ELSE N'' END
                         + CASE WHEN f.[DivisonName]  IS NOT NULL THEN N' / ' + f.[DivisonName]  ELSE N'' END
                     )), N''),
                 f.[IdaraName],
                 CAST(f.[DSDID] AS NVARCHAR(20))
               ) AS [dsdName_A]
         FROM dbo.V_GetFullStructureForDSD f
         WHERE f.[IdaraID] = @idaraID
         ORDER BY f.[DepartmentName], f.[SectionName], f.[DivisonName];

         RETURN;
     END

     -- Returns active users whose DSD membership matches the given DSDID (@parameter_01).
     -- Used by the Assign Ticket modal to show only staff in the ticket's current department.
     IF @pageName_ = N'DsdUsersDDL'
     BEGIN
         SELECT
               v.[usersID]
             , v.[FullName] AS [fullName_A]
         FROM dbo.V_GetListUsersInDSD v
         WHERE v.[DSDID] = TRY_CAST(@filterDSDID AS BIGINT)
           -- تعديل 08: قصر المستخدمين على هيكل الإدارة المطلوبة.
           AND EXISTS (SELECT 1 FROM dbo.V_GetFullStructureForDSD f
                       WHERE f.[DSDID] = v.[DSDID] AND f.[IdaraID] = @idaraID)
         ORDER BY v.[FullName];

         RETURN;
     END

     -- Returns all active users with their DSDID for client-side filtering via DDLFiltered.
     -- Used by the Assign Ticket modal with DependsOn pattern.
     -- TableIndex 0 in Masters_DataLoad maps to this result.
     IF @pageName_ = N'DsdUsersAllDDL'
     BEGIN
         SELECT
               v.[usersID]
             , v.[FullName] AS [fullName_A]
             , v.[DSDID]
         FROM dbo.V_GetListUsersInDSD v
         -- تعديل 08: عدم عرض جميع مستخدمي الإدارات الأخرى في القائمة العامة.
         WHERE EXISTS (SELECT 1 FROM dbo.V_GetFullStructureForDSD f
                       WHERE f.[DSDID] = v.[DSDID] AND f.[IdaraID] = @idaraID)
         ORDER BY v.[FullName];

         RETURN;
     END
 END
