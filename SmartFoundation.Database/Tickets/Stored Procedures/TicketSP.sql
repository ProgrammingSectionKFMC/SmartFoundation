CREATE PROCEDURE [Tickets].[TicketSP]
 (
       @Action                      NVARCHAR(200)
     , @ticketID                    BIGINT          = NULL
     , @parentTicketID_FK           BIGINT          = NULL
     , @serviceID_FK                BIGINT          = NULL
     , @ticketClassID_FK            INT             = NULL
     , @requesterTypeID_FK          INT             = NULL
     , @requesterUserID_FK          INT             = NULL
     , @requesterResidentID_FK      BIGINT          = NULL
     , @title_A                     NVARCHAR(500)   = NULL
     , @title                       NVARCHAR(500)   = NULL
     , @description_A               NVARCHAR(4000)  = NULL
     , @description_                NVARCHAR(4000)  = NULL
     , @suggestedPriorityID_FK      INT             = NULL
     , @ticketStatusID_FK           INT             = NULL
     , @currentDSDID_FK             INT             = NULL
     , @currentQueueDistributorID_FK INT            = NULL
     , @assignedUserID_FK           INT             = NULL
     , @locationBuildingNo          NVARCHAR(100)   = NULL
     , @locationUnitNo              NVARCHAR(50)    = NULL
     , @locationArea_A              NVARCHAR(200)   = NULL
     , @locationArea                NVARCHAR(200)   = NULL
     , @requiresQualityReview       BIT             = NULL
     , @isOtherService              BIT             = NULL
     , @ticketReasonID_FK           INT             = NULL
     , @reporterName                NVARCHAR(200)   = NULL
     , @reporterPhone               NVARCHAR(30)    = NULL
     , @isUrgent                    NVARCHAR(10)    = NULL
     , @idaraID_FK                  INT             = NULL
     , @entryData                   NVARCHAR(20)    = NULL
     , @hostName                    NVARCHAR(200)   = NULL
     , @notes_A                     NVARCHAR(4000)  = NULL
     , @notes                       NVARCHAR(4000)  = NULL
     , @pauseNotes_A                NVARCHAR(2000)  = NULL
     , @pauseReasonID_FK            INT             = NULL
     , @reviewScope                 NVARCHAR(100)   = NULL
     , @qualityReviewResultID_FK    INT             = NULL
     , @reviewNotes                 NVARCHAR(4000)  = NULL
     , @returnToUserID              INT             = NULL
     , @arbitrationReasonID_FK      INT             = NULL
     , @arbitratorDistributorID     INT             = NULL
     , @decisionType                NVARCHAR(50)    = NULL
     , @decisionTargetDSDID_FK      INT             = NULL
     , @decisionNotes               NVARCHAR(4000)  = NULL
     , @arbitrationCaseID           BIGINT          = NULL
     , @fileName                    NVARCHAR(500)   = NULL
     , @storedFileName              NVARCHAR(500)   = NULL
     , @filePath                    NVARCHAR(1000)  = NULL
     , @fileSizeBytes               BIGINT          = NULL
     , @contentType                 NVARCHAR(200)   = NULL
     , @attachmentType              NVARCHAR(50)    = NULL
     , @performerUserID             INT             = NULL
     , @clarificationRequestID       BIGINT          = NULL
     , @clarificationReasonID_FK     INT             = NULL
     , @requestedFromUserID          INT             = NULL
     , @requestedFromDSDID_FK        INT             = NULL
 )
 AS
 BEGIN
     SET NOCOUNT ON;
     SET XACT_ABORT ON;

     DECLARE @tc INT = @@TRANCOUNT;
     DECLARE @NewID BIGINT = NULL;
     DECLARE @Note NVARCHAR(MAX) = NULL;
     DECLARE @NewTicketNo NVARCHAR(50) = NULL;
     DECLARE @TicketNoLockResult INT = NULL; -- تعديل 05: يستخدم في حجز تسلسل أرقام التذاكر
     DECLARE @titleToSave NVARCHAR(500) = COALESCE(@title_A, @title);
     DECLARE @descriptionToSave NVARCHAR(4000) = COALESCE(@description_A, @description_);
     DECLARE @locationAreaToSave NVARCHAR(200) = COALESCE(@locationArea_A, @locationArea);
     DECLARE @notesToSave NVARCHAR(4000) = COALESCE(@notes_A, @notes);
     DECLARE @pauseNotesToSave NVARCHAR(2000) = COALESCE(@pauseNotes_A, @notes_A, @notes);
     DECLARE @ParentTicketToUpdate BIGINT = NULL;
     DECLARE @RemainingOpenChildren INT = 0;
     DECLARE @ParentCurrentStatus INT = NULL;
     DECLARE @PausedStatusID INT = NULL;
     DECLARE @ResumeStatusID INT = NULL;

     BEGIN TRY
         IF @tc = 0 BEGIN TRAN;

         IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
         BEGIN ;THROW 50001, N'نوع الإجراء مطلوب', 1; END

         -- تعديل 02: حصر عمليات التعديل على تذاكر الإدارة المحددة.
         -- تنبيه: هذه حماية نطاق بيانات فقط وليست بديلًا للتحقق من صلاحية المستخدم.
         -- لا نستخدم @ticketID لهذا الفحص في DELETE_ATTACHMENT لأنه يحمل معرف المرفق.
         IF @Action NOT IN (N'INSERT_TICKET', N'CREATE_CHILD_TICKET',
                            N'RESPOND_CLARIFICATION', N'DECIDE_ARBITRATION',
                            N'CANCEL_ARBITRATION', N'DELETE_ATTACHMENT')
         BEGIN
             IF @idaraID_FK IS NULL
                 THROW 50001, N'معرف الإدارة مطلوب لتنفيذ الإجراء', 1;
             IF @ticketID IS NOT NULL AND NOT EXISTS
             (
                 SELECT 1 FROM [Tickets].[Ticket] t WITH (UPDLOCK, HOLDLOCK)
                 WHERE t.[ticketID] = @ticketID
                   AND t.[idaraID_FK] = @idaraID_FK
                   AND t.[ticketActive] = 1
             )
                 THROW 50001, N'التذكرة غير موجودة أو لا تتبع الإدارة المحددة', 1;
         END

         -- تعديل 03: إجراءات تنفيذ العمل مقصورة على الموظف المسند إليه التذكرة.
         -- الصلاحية تحدد من يملك الإجراء عمومًا، وهذا الفحص يحدد على أي تذكرة.
         -- إجراءات الإشراف (توجيه، إسناد، إعادة إسناد، رفض، إغلاق، إعادة فتح، أولوية) لها فحص النطاق أدناه.
         IF @ticketID IS NOT NULL
            AND @Action IN (N'START_WORK', N'RESOLVE_TICKET', N'PAUSE_TICKET', N'RESUME_TICKET')
         BEGIN
             DECLARE @ownerAssignedUserID INT;
             SELECT @ownerAssignedUserID = [assignedUserID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @ownerAssignedUserID IS NULL
                 THROW 50001, N'التذكرة غير مسندة لأي موظف، يجب إسنادها أولًا', 1;

             IF @performerUserID IS NULL OR @performerUserID <> @ownerAssignedUserID
                 THROW 50001, N'هذا الإجراء متاح فقط للموظف المسند إليه التذكرة', 1;
         END

         -- تعديل 04: إجراءات الإشراف مقصورة على أعضاء الجهة الحالية للتذكرة (صف التوزيع أو الهيكل التنظيمي)،
         -- بنفس شرط أهلية المستلم في ASSIGN_TICKET. امتلاك صلاحية الصفحة لا يكفي للتصرف في تذكرة جهة أخرى.
         -- التذكرة التي لم توجَّه بعد (بدون جهة أو صف) يكفي فيها فحص الإدارة أعلاه.
         IF @ticketID IS NOT NULL
            AND @Action IN (N'ROUTE_TICKET', N'ASSIGN_TICKET', N'REASSIGN_TICKET', N'REJECT_TICKET',
                            N'CLOSE_TICKET', N'REOPEN_TICKET', N'UPDATE_PRIORITY')
         BEGIN
             DECLARE @scopeQueueDistributorID INT, @scopeDSDID INT;
             SELECT @scopeQueueDistributorID = [currentQueueDistributorID_FK]
                  , @scopeDSDID = [currentDSDID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF (@scopeQueueDistributorID IS NOT NULL OR @scopeDSDID IS NOT NULL)
                AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.[UserDistributor] ud
                    INNER JOIN dbo.[Distributor] d ON d.[distributorID] = ud.[distributorID_FK]
                    WHERE ud.[userID_FK] = @performerUserID
                      AND ISNULL(ud.[UDActive], 1) = 1
                      AND (ud.[UDStartDate] IS NULL OR CAST(ud.[UDStartDate] AS date) <= CAST(GETDATE() AS date))
                      AND (ud.[UDEndDate] IS NULL OR CAST(ud.[UDEndDate] AS date) >= CAST(GETDATE() AS date))
                      AND ISNULL(d.[distributorActive], 1) = 1
                      AND (
                            (@scopeQueueDistributorID IS NOT NULL AND ud.[distributorID_FK] = @scopeQueueDistributorID)
                         OR (@scopeDSDID IS NOT NULL AND d.[DSDID_FK] = @scopeDSDID)
                      )
                )
                 THROW 50001, N'لا يمكنك تنفيذ هذا الإجراء على تذكرة لا تتبع جهتك', 1;
         END

         ----------------------------------------------------------------
         -- INSERT_TICKET
         ----------------------------------------------------------------
         IF @Action = N'INSERT_TICKET'
         BEGIN
             ----------------------------------------------------------------
             -- Simple create form: the user picks who reports, the service and
             -- (optionally) a reason; everything else is derived here.
             ----------------------------------------------------------------
             DECLARE @newReqCode NVARCHAR(50);
             SELECT @newReqCode = [requesterTypeCode]
             FROM [Tickets].[RequesterType]
             WHERE [requesterTypeID] = @requesterTypeID_FK AND [requesterTypeActive] = 1;

             IF @newReqCode = N'RESIDENT'
                 SET @requesterUserID_FK = NULL;
             ELSE
             BEGIN
                 -- Employee and public reports are recorded by the signed-in user.
                 -- تعديل 04: الهوية من الجلسة فقط (@performerUserID / @entryData)، وتُتجاهل القيمة المرسلة في p03،
                 -- فلا يمكن تسجيل بلاغ باسم موظف آخر. لا توجد صلاحية "التسجيل نيابة عن الغير" حاليًا.
                 SET @requesterResidentID_FK = NULL;
                 SET @requesterUserID_FK = COALESCE(@performerUserID, TRY_CAST(@entryData AS INT));
             END

             SET @reporterName  = NULLIF(LTRIM(RTRIM(@reporterName)), N'');
             SET @reporterPhone = NULLIF(REPLACE(LTRIM(RTRIM(@reporterPhone)), N' ', N''), N'');
             IF ISNULL(@newReqCode, N'') <> N'PUBLIC'
             BEGIN
                 SET @reporterName = NULL;
                 SET @reporterPhone = NULL;
             END
             IF @reporterPhone IS NOT NULL AND (@reporterPhone LIKE N'%[^0-9+]%' OR LEN(@reporterPhone) NOT BETWEEN 7 AND 15)
                 THROW 50001, N'رقم جوال المبلّغ غير صحيح', 1;

             IF @serviceID_FK IS NULL AND ISNULL(@isOtherService, 0) = 0
                 THROW 50001, N'يرجى اختيار نوع المشكلة', 1;

             IF @serviceID_FK IS NOT NULL AND @ticketClassID_FK IS NULL
                 SELECT @ticketClassID_FK = [ticketClassID_FK] FROM [Tickets].[Service] WHERE [serviceID] = @serviceID_FK;

             -- Unselected dropdowns post their placeholder (-99999 / -1).
             IF @ticketReasonID_FK <= 0 SET @ticketReasonID_FK = NULL;
             IF @requesterResidentID_FK <= 0 SET @requesterResidentID_FK = NULL;
             DECLARE @newReasonName NVARCHAR(500), @newReasonPriority INT;
             IF @ticketReasonID_FK IS NOT NULL
             BEGIN
                 SELECT @newReasonName = [ticketReasonName_A], @newReasonPriority = [priorityID_FK]
                 FROM [Tickets].[TicketReason]
                 WHERE [ticketReasonID] = @ticketReasonID_FK
                   AND [serviceID_FK] = @serviceID_FK
                   AND [ticketReasonActive] = 1;

                 IF @newReasonName IS NULL
                     THROW 50001, N'السبب المختار لا يتبع الخدمة المختارة', 1;
             END

             IF NULLIF(LTRIM(RTRIM(@titleToSave)), N'') IS NULL
                 SET @titleToSave = COALESCE(@newReasonName,
                     (SELECT [serviceName_A] FROM [Tickets].[Service] WHERE [serviceID] = @serviceID_FK));
             IF NULLIF(LTRIM(RTRIM(@descriptionToSave)), N'') IS NULL
                 SET @descriptionToSave = @titleToSave;

             IF @suggestedPriorityID_FK IS NULL
                 SET @suggestedPriorityID_FK = CASE
                     WHEN @isUrgent IN (N'1', N'true', N'on')
                         THEN (SELECT [priorityID] FROM [Tickets].[Priority] WHERE [priorityCode] = N'HIGH' AND [priorityActive] = 1)
                     ELSE @newReasonPriority END;

             SET @locationAreaToSave = NULLIF(LTRIM(RTRIM(@locationAreaToSave)), N'');
             SET @locationBuildingNo = NULLIF(NULLIF(LTRIM(RTRIM(@locationBuildingNo)), N''), N'-99999');

             IF @newReqCode = N'RESIDENT' AND @locationBuildingNo IS NULL AND @requesterResidentID_FK IS NOT NULL
             BEGIN
                 -- Same lookup as TicketDL ResidentDDL: the resident's current housing.
                 SELECT TOP 1 @locationBuildingNo = NULLIF(CONVERT(NVARCHAR(100), ba.[BuildingNo]), N'No_house')
                 FROM [Housing].[V_GetFullResidentDetails] r
                 INNER JOIN [DATACORE].[Housing].[BuildingAssign] ba ON r.[generalNo_FK] = ba.[GeneralNo]
                 INNER JOIN [DATACORE].[Housing].[BuildingAssignStatus] bas ON ba.[BuildingAssignStatusID_FK] = bas.[BuildingAssignStatusID]
                 WHERE r.[residentInfoID] = @requesterResidentID_FK
                   AND bas.[Active] = 1
                 ORDER BY CASE WHEN ba.[BuildingNo] IS NULL
                                 OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), ba.[BuildingNo]))) IN (N'', N'No_house') THEN 1 ELSE 0 END,
                          ba.[BuildingAssignDate] DESC, ba.[BuildingAssignID] DESC;
             END

             IF @newReqCode = N'PUBLIC' AND @locationAreaToSave IS NULL AND @locationBuildingNo IS NULL
                 THROW 50001, N'يرجى كتابة موقع البلاغ (الحي أو الشارع أو أقرب معلم)', 1;
           IF NULLIF(LTRIM(RTRIM(@titleToSave)), N'') IS NULL
             BEGIN ;THROW 50001, N'عنوان التذكرة مطلوب', 1; END

             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END

             IF @ticketClassID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف فئة التذكرة مطلوب', 1; END

             IF @requesterTypeID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف نوع مقدم الطلب مطلوب', 1; END

             DECLARE @reqCode NVARCHAR(50);
             SELECT @reqCode = [requesterTypeCode]
             FROM [Tickets].[RequesterType]
             WHERE [requesterTypeID] = @requesterTypeID_FK
               AND [requesterTypeActive] = 1;

             -- تعديل 03: رفض نوع مقدم طلب غير معروف أو غير نشط بدل تجاوزه بصمت.
             IF @reqCode IS NULL OR @reqCode NOT IN (N'RESIDENT', N'INTERNAL', N'SUPERVISOR', N'MANAGER', N'PUBLIC')
                 THROW 50001, N'نوع مقدم الطلب غير صالح أو غير مدعوم', 1;

             IF @reqCode = N'RESIDENT'
             BEGIN
                 IF @requesterResidentID_FK IS NULL
                 BEGIN ;THROW 50001, N'تذاكر السكان تتطلب معرف ساكن لمقدم الطلب', 1; END
                 IF @requesterUserID_FK IS NOT NULL
                 BEGIN ;THROW 50001, N'تذاكر السكان يجب ألا تحتوي على معرف مستخدم لمقدم الطلب', 1; END

                 -- تعديل 05: أهلية الساكن بنفس شرط قائمة ResidentDDL: يتبع إدارة البلاغ وله سكن فعّال.
                 IF NOT EXISTS
                 (
                     SELECT 1
                     FROM [Housing].[V_GetFullResidentDetails] r
                     INNER JOIN [DATACORE].[Housing].[BuildingAssign] ba ON r.[generalNo_FK] = ba.[GeneralNo]
                     INNER JOIN [DATACORE].[Housing].[BuildingAssignStatus] bas ON ba.[BuildingAssignStatusID_FK] = bas.[BuildingAssignStatusID]
                     WHERE r.[residentInfoID] = @requesterResidentID_FK
                       AND r.[IdaraID] = @idaraID_FK
                       AND bas.[Active] = 1
                 )
                     THROW 50001, N'الساكن المختار غير موجود أو لا يتبع هذه الإدارة أو ليس له سكن فعّال', 1;

                 -- رقم المبنى في البلاغ يجب أن يكون أحد مساكن الساكن الفعّالة.
                 IF @locationBuildingNo IS NOT NULL AND NOT EXISTS
                 (
                     SELECT 1
                     FROM [Housing].[V_GetFullResidentDetails] r
                     INNER JOIN [DATACORE].[Housing].[BuildingAssign] ba ON r.[generalNo_FK] = ba.[GeneralNo]
                     INNER JOIN [DATACORE].[Housing].[BuildingAssignStatus] bas ON ba.[BuildingAssignStatusID_FK] = bas.[BuildingAssignStatusID]
                     WHERE r.[residentInfoID] = @requesterResidentID_FK
                       AND bas.[Active] = 1
                       AND CONVERT(NVARCHAR(100), ba.[BuildingNo]) = @locationBuildingNo
                 )
                     THROW 50001, N'المبنى المحدد لا يتبع سكن الساكن المختار', 1;
             END
             ELSE IF @reqCode IN (N'INTERNAL', N'SUPERVISOR', N'MANAGER', N'PUBLIC')
             BEGIN
                 IF @requesterUserID_FK IS NULL
                 BEGIN ;THROW 50001, N'التذاكر الداخلية تتطلب معرف مستخدم لمقدم الطلب', 1; END
                 IF @requesterResidentID_FK IS NOT NULL
                 BEGIN ;THROW 50001, N'التذاكر الداخلية يجب ألا تحتوي على معرف ساكن لمقدم الطلب', 1; END
             END

             IF @isOtherService IS NULL OR @isOtherService = 0
             BEGIN
                 IF @serviceID_FK IS NULL
                 BEGIN ;THROW 50001, N'معرف الخدمة مطلوب للتذاكر غير المصنفة كأخرى', 1; END
             END

             -- تعديل 04: فحص الخدمة ونطاقها قبل إنشاء التذكرة (الخدمة العامة مسموحة).
             IF @serviceID_FK IS NOT NULL AND NOT EXISTS
             (
                 SELECT 1 FROM [Tickets].[Service] s
                 WHERE s.[serviceID] = @serviceID_FK AND s.[serviceActive] = 1
                   AND (s.[idaraID_FK] = @idaraID_FK OR s.[idaraID_FK] IS NULL)
             )
                 THROW 50001, N'الخدمة غير نشطة أو غير متاحة لهذه الإدارة', 1;

             -- تعديل 05: قفل منطقي داخل المعاملة لمنع تكرار أرقام التذاكر عند الطلبات المتزامنة.
             SET @TicketNoLockResult = NULL;
             EXEC @TicketNoLockResult = sys.sp_getapplock
                 @Resource = N'Tickets.TicketNo.YearlySequence',
                 @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
             IF @TicketNoLockResult < 0
                 THROW 50002, N'تعذر حجز رقم التذكرة، أعد المحاولة', 1;
             DECLARE @yr NVARCHAR(4) = CONVERT(NVARCHAR(4), YEAR(GETDATE()));
             DECLARE @seq INT;
             SELECT @seq = ISNULL(MAX(TRY_CONVERT(INT, RIGHT([ticketNo], 5))), 0) + 1
             FROM [Tickets].[Ticket]
             WHERE [ticketNo] LIKE N'TKT-' + @yr + N'-%';

             -- تعديل 06: منع دوران التسلسل بعد 99999 إلى أرقام مكررة.
             IF @seq > 99999 THROW 50002, N'تم استنفاد تسلسل أرقام التذاكر لهذا العام', 1;
             SET @NewTicketNo = N'TKT-' + @yr + N'-' + RIGHT(N'00000' + CAST(@seq AS NVARCHAR(10)), 5);

             DECLARE @statusNewID INT;
             SELECT @statusNewID = [ticketStatusID]
             FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'NEW' AND [ticketStatusActive] = 1;

             IF @statusNewID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة NEW في جدول حالات التذاكر', 1; END

             DECLARE @svcDSDID INT = @currentDSDID_FK;
             -- تعديل 07: عدم فرض 0 مبكرًا؛ حتى تُطبّق قيمة الخدمة الافتراضية عند عدم تمرير باراميتر.
             DECLARE @svcRequiresQR BIT = @requiresQualityReview;

             IF @serviceID_FK IS NOT NULL
             BEGIN
                 SELECT @svcRequiresQR = COALESCE(@svcRequiresQR, s.[requiresQualityReview], 0)
                 FROM [Tickets].[Service] s
                 WHERE s.[serviceID] = @serviceID_FK AND s.[serviceActive] = 1;
             END

             SET @svcRequiresQR = ISNULL(@svcRequiresQR, 0); -- تعديل 07: قيمة افتراضية عندما لا تُحدَّد الخدمة.
             DECLARE @effectivePriorityID INT = @suggestedPriorityID_FK;
             IF @effectivePriorityID IS NULL AND @serviceID_FK IS NOT NULL
             BEGIN
                 SELECT @effectivePriorityID = s.[defaultPriorityID_FK]
                 FROM [Tickets].[Service] s
                 WHERE s.[serviceID] = @serviceID_FK;
             END

             IF @parentTicketID_FK IS NOT NULL AND @parentTicketID_FK > 0
             BEGIN
                 ;THROW 50001, N'استخدم CREATE_CHILD_TICKET لإنشاء التذاكر الفرعية', 1;
             END

             SET @parentTicketID_FK = NULL;

             INSERT INTO [Tickets].[Ticket]
             (
                   [ticketNo], [idaraID_FK], [parentTicketID_FK], [rootTicketID_FK]
                 , [serviceID_FK], [ticketClassID_FK], [requesterTypeID_FK]
                 , [requesterUserID_FK], [requesterResidentID_FK]
                 , [title], [title_A], [description_], [description_A]
                 , [suggestedPriorityID_FK], [effectivePriorityID_FK], [ticketStatusID_FK]
                 , [currentDSDID_FK], [currentQueueDistributorID_FK], [assignedUserID_FK]
                 , [locationBuildingNo], [locationUnitNo], [locationArea], [locationArea_A]
                 , [operationalResolutionDate], [finalClosureDate]
                 , [requiresQualityReview], [isOtherService], [isParentBlocked], [ticketActive]
                 , [reporterName], [reporterPhone], [ticketReasonID_FK]
                 , [entryData], [hostName]
             )
             VALUES
             (
                   @NewTicketNo, @idaraID_FK, @parentTicketID_FK, NULL
                 , @serviceID_FK, @ticketClassID_FK, @requesterTypeID_FK
                 , @requesterUserID_FK, @requesterResidentID_FK
                 , @titleToSave, @titleToSave, @descriptionToSave, @descriptionToSave
                 , @suggestedPriorityID_FK, @effectivePriorityID, @statusNewID
                 , @svcDSDID, @currentQueueDistributorID_FK, @assignedUserID_FK
                 , @locationBuildingNo, @locationUnitNo, @locationAreaToSave, @locationAreaToSave
                 , NULL, NULL
                 , @svcRequiresQR, ISNULL(@isOtherService, 0), 0, 1
                 , @reporterName, @reporterPhone, @ticketReasonID_FK
                 , @entryData, @hostName
             );

             SET @NewID = SCOPE_IDENTITY();
             IF @NewID IS NULL OR @NewID <= 0
             BEGIN ;THROW 50002, N'فشل إنشاء التذكرة بسبب خطأ في توليد المعرف', 1; END

             UPDATE [Tickets].[Ticket]
             SET [rootTicketID_FK] = @NewID
             WHERE [ticketID] = @NewID AND [rootTicketID_FK] IS NULL;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @NewID, @idaraID_FK, N'CREATED', NULL, @statusNewID
             , NULL, @svcDSDID, NULL, NULL
             , @requesterUserID_FK, N'تم إنشاء التذكرة', COALESCE(@notes_A, N'تم إنشاء التذكرة'), @entryData, @hostName );

             ----------------------------------------------------------------
             -- Automatic routing by the service's routing rule, then automatic
             -- assignment when the target unit has exactly one eligible employee.
             ----------------------------------------------------------------
             DECLARE @autoDSD INT = NULL, @autoQD INT = NULL, @autoUnit NVARCHAR(300) = NULL;
             DECLARE @autoUser INT = NULL, @autoUserName NVARCHAR(400) = NULL;

             IF @svcDSDID IS NULL AND @serviceID_FK IS NOT NULL
             BEGIN
                 SELECT TOP 1 @autoDSD = rr.[targetDSDID_FK], @autoQD = rr.[queueDistributorID_FK]
                 FROM [Tickets].[ServiceRoutingRule] rr
                 WHERE rr.[serviceID_FK] = @serviceID_FK
                   AND (rr.[idaraID_FK] = @idaraID_FK OR rr.[idaraID_FK] IS NULL)
                   AND rr.[serviceRoutingRuleActive] = 1
                   AND rr.[effectiveFrom] <= GETDATE()
                   AND (rr.[effectiveTo] IS NULL OR rr.[effectiveTo] > GETDATE())
                 ORDER BY CASE WHEN rr.[idaraID_FK] = @idaraID_FK THEN 0 ELSE 1 END, rr.[serviceRoutingRuleID] DESC;
             END

             IF @autoDSD IS NOT NULL
             BEGIN
                 DECLARE @autoRoutedID INT = (SELECT [ticketStatusID] FROM [Tickets].[TicketStatus] WHERE [ticketStatusCode] = N'ROUTED' AND [ticketStatusActive] = 1);
                 SELECT TOP 1 @autoUnit = COALESCE(f.[DivisonName], f.[SectionName], f.[DepartmentName])
                 FROM dbo.[V_GetFullStructureForDSD] f WHERE f.[DSDID] = @autoDSD;

                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @autoRoutedID, [currentDSDID_FK] = @autoDSD, [currentQueueDistributorID_FK] = @autoQD
                 WHERE [ticketID] = @NewID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @NewID, @idaraID_FK, N'ROUTED', @statusNewID, @autoRoutedID
                 , NULL, @autoDSD, NULL, NULL
                 , @performerUserID, N'Auto-routed by service routing rule'
                 , N'توجيه تلقائي إلى ' + ISNULL(@autoUnit, N'الجهة المختصة') + N' حسب قاعدة توجيه الخدمة', @entryData, @hostName );

                 -- Same eligibility rule as ASSIGN_TICKET.
                 IF (SELECT COUNT(DISTINCT ud.[userID_FK])
                     FROM dbo.[UserDistributor] ud
                     INNER JOIN dbo.[Distributor] d ON d.[distributorID] = ud.[distributorID_FK]
                     WHERE ISNULL(ud.[UDActive], 1) = 1
                       AND (ud.[UDStartDate] IS NULL OR CAST(ud.[UDStartDate] AS date) <= CAST(GETDATE() AS date))
                       AND (ud.[UDEndDate] IS NULL OR CAST(ud.[UDEndDate] AS date) >= CAST(GETDATE() AS date))
                       AND ISNULL(d.[distributorActive], 1) = 1
                       AND ((@autoQD IS NOT NULL AND ud.[distributorID_FK] = @autoQD) OR d.[DSDID_FK] = @autoDSD)) = 1
                 BEGIN
                     SELECT TOP 1 @autoUser = ud.[userID_FK]
                     FROM dbo.[UserDistributor] ud
                     INNER JOIN dbo.[Distributor] d ON d.[distributorID] = ud.[distributorID_FK]
                     WHERE ISNULL(ud.[UDActive], 1) = 1
                       AND (ud.[UDStartDate] IS NULL OR CAST(ud.[UDStartDate] AS date) <= CAST(GETDATE() AS date))
                       AND (ud.[UDEndDate] IS NULL OR CAST(ud.[UDEndDate] AS date) >= CAST(GETDATE() AS date))
                       AND ISNULL(d.[distributorActive], 1) = 1
                       AND ((@autoQD IS NOT NULL AND ud.[distributorID_FK] = @autoQD) OR d.[DSDID_FK] = @autoDSD);

                     SELECT TOP 1 @autoUserName = LTRIM(RTRIM(CONCAT(u.[firstName_A], N' ', u.[secondName_A], N' ', u.[lastName_A])))
                     FROM dbo.[UsersDetails] u WHERE u.[usersID_FK] = @autoUser AND u.[userActive] = 1
                     ORDER BY u.[usersDetailsID] DESC;

                     DECLARE @autoAssignedID INT = (SELECT [ticketStatusID] FROM [Tickets].[TicketStatus] WHERE [ticketStatusCode] = N'ASSIGNED' AND [ticketStatusActive] = 1);
                     UPDATE [Tickets].[Ticket] SET [ticketStatusID_FK] = @autoAssignedID, [assignedUserID_FK] = @autoUser WHERE [ticketID] = @NewID;

                     INSERT INTO [Tickets].[TicketHistory]
                     ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                     , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                     , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                     VALUES
                     ( @NewID, @idaraID_FK, N'ASSIGNED', @autoRoutedID, @autoAssignedID
                     , @autoDSD, @autoDSD, NULL, @autoUser
                     , @performerUserID, N'Auto-assigned: only eligible employee in the unit'
                     , N'إسناد تلقائي إلى ' + ISNULL(@autoUserName, N'الموظف') + N' (الموظف الوحيد في الجهة)', @entryData, @hostName );
                 END
             END

             SET @Note = N'{"ticketID":"' + CAST(@NewID AS NVARCHAR(20))
                 + N'","ticketNo":"' + ISNULL(@NewTicketNo, N'') + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'INSERT_TICKET', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful
                  , N'تم إنشاء التذكرة بنجاح: ' + @NewTicketNo
                    + CASE WHEN @autoUnit IS NOT NULL THEN N' — وُجِّهت إلى ' + @autoUnit ELSE N' — بانتظار التوجيه' END
                    + CASE WHEN @autoUserName IS NOT NULL THEN N' وأُسندت إلى ' + @autoUserName ELSE N'' END AS Message_;
         END

         ----------------------------------------------------------------
         -- ROUTE_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'ROUTE_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             -- تعديل 12: استخدام خدمة التذكرة الفعلية في التوجيه، لا خدمة يرسلها المستدعي.
             DECLARE @rtOldStatus INT, @rtOldDSD INT, @rtServiceID BIGINT;
             SELECT @rtOldStatus = [ticketStatusID_FK], @rtOldDSD = [currentDSDID_FK]
                  , @rtServiceID = [serviceID_FK]
             FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @rtOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             DECLARE @statusRoutedID INT;
             SELECT @statusRoutedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'ROUTED' AND [ticketStatusActive] = 1;

             IF @statusRoutedID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة ROUTED', 1; END

             IF @rtOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'NEW', N'REOPENED') AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'لا يمكن توجيه التذكرة من حالتها الحالية', 1; END

             DECLARE @routeDSDID INT = @currentDSDID_FK;
             DECLARE @routeQDID INT = @currentQueueDistributorID_FK;

             IF @routeDSDID IS NULL AND @rtServiceID IS NOT NULL
             BEGIN
                 SELECT TOP 1 @routeDSDID = rr.[targetDSDID_FK], @routeQDID = ISNULL(@routeQDID, rr.[queueDistributorID_FK])
                 FROM [Tickets].[ServiceRoutingRule] rr
                 WHERE rr.[serviceID_FK] = @rtServiceID
                   AND (rr.[idaraID_FK] = @idaraID_FK OR rr.[idaraID_FK] IS NULL)
                   AND rr.[serviceRoutingRuleActive] = 1
                   AND rr.[effectiveFrom] <= GETDATE()
                   AND (rr.[effectiveTo] IS NULL OR rr.[effectiveTo] > GETDATE())
                 ORDER BY rr.[serviceRoutingRuleID] DESC;
             END

             IF @routeDSDID IS NULL
                 THROW 50001, N'لم يتم تحديد جهة توجيه للتذكرة', 1; -- تعديل 12

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusRoutedID
               , [currentDSDID_FK] = @routeDSDID
               , [currentQueueDistributorID_FK] = @routeQDID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'ROUTED', @rtOldStatus, @statusRoutedID
             , @rtOldDSD, @routeDSDID, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم توجيه التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم توجيه التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'ROUTE_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم توجيه التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- ASSIGN_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'ASSIGN_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @assignedUserID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف المستخدم المعيّن مطلوب', 1; END

           DECLARE @asOldStatus INT, @asOldAssigned INT;
           DECLARE @asCurrentQueueDistributorID BIGINT, @asCurrentDSDID BIGINT;
           SELECT @asOldStatus = [ticketStatusID_FK]
              , @asOldAssigned = [assignedUserID_FK]
              , @asCurrentQueueDistributorID = [currentQueueDistributorID_FK]
              , @asCurrentDSDID = [currentDSDID_FK]
             FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @asOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

           IF EXISTS (SELECT 1 FROM [Tickets].[TicketStatus] WHERE [ticketStatusID] = @asOldStatus
                      AND [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED'))
           BEGIN ;THROW 50001, N'لا يمكن إسناد التذكرة في حالتها الحالية', 1; END
           IF @asCurrentQueueDistributorID IS NULL AND @asCurrentDSDID IS NULL
           BEGIN ;THROW 50001, N'لا يمكن إسناد التذكرة بدون مسار توزيع أو هيكل تنظيمي حالي', 1; END

           IF NOT EXISTS (
             SELECT 1
             FROM dbo.[UserDistributor] ud
             INNER JOIN dbo.[Distributor] d
               ON d.[distributorID] = ud.[distributorID_FK]
             WHERE ud.[userID_FK] = @assignedUserID_FK
               AND ISNULL(ud.[UDActive], 1) = 1
               AND (ud.[UDStartDate] IS NULL OR CAST(ud.[UDStartDate] AS date) <= CAST(GETDATE() AS date))
               AND (ud.[UDEndDate] IS NULL OR CAST(ud.[UDEndDate] AS date) >= CAST(GETDATE() AS date))
               AND ISNULL(d.[distributorActive], 1) = 1
               AND (
                 (@asCurrentQueueDistributorID IS NOT NULL AND ud.[distributorID_FK] = @asCurrentQueueDistributorID)
                OR (@asCurrentDSDID IS NOT NULL AND d.[DSDID_FK] = @asCurrentDSDID)
               )
           )
           BEGIN ;THROW 50001, N'المستخدم المحدد غير مؤهل لاستلام التذكرة في المسار الحالي', 1; END

             DECLARE @statusAssignedID INT;
             SELECT @statusAssignedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'ASSIGNED' AND [ticketStatusActive] = 1;

             IF @statusAssignedID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة ASSIGNED', 1; END

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusAssignedID
               , [assignedUserID_FK] = @assignedUserID_FK
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'ASSIGNED', @asOldStatus, @statusAssignedID
             , NULL, NULL, @asOldAssigned, @assignedUserID_FK
             , @performerUserID, ISNULL(@notes, N'تم إسناد التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم إسناد التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","assignedUserID":"' + CAST(@assignedUserID_FK AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'ASSIGN_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إسناد التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- REASSIGN_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'REASSIGN_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @assignedUserID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف المستخدم الجديد المعيّن مطلوب', 1; END

           DECLARE @raOldStatus INT, @raOldAssigned INT, @raOldDSD BIGINT;
           DECLARE @raCurrentQueueDistributorID BIGINT, @raTargetDSDID BIGINT;
           SELECT @raOldStatus = [ticketStatusID_FK]
              , @raOldAssigned = [assignedUserID_FK]
              , @raOldDSD = [currentDSDID_FK]
              , @raCurrentQueueDistributorID = [currentQueueDistributorID_FK]
             FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @raOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

           SET @raTargetDSDID = ISNULL(@currentDSDID_FK, @raOldDSD);

           IF @raCurrentQueueDistributorID IS NULL AND @raTargetDSDID IS NULL
           BEGIN ;THROW 50001, N'لا يمكن إعادة إسناد التذكرة بدون مسار توزيع أو هيكل تنظيمي حالي', 1; END

           IF NOT EXISTS (
             SELECT 1
             FROM dbo.[UserDistributor] ud
             INNER JOIN dbo.[Distributor] d
               ON d.[distributorID] = ud.[distributorID_FK]
             WHERE ud.[userID_FK] = @assignedUserID_FK
               AND ISNULL(ud.[UDActive], 1) = 1
               AND (ud.[UDStartDate] IS NULL OR CAST(ud.[UDStartDate] AS date) <= CAST(GETDATE() AS date))
               AND (ud.[UDEndDate] IS NULL OR CAST(ud.[UDEndDate] AS date) >= CAST(GETDATE() AS date))
               AND ISNULL(d.[distributorActive], 1) = 1
               AND (
                 (@currentDSDID_FK IS NOT NULL AND d.[DSDID_FK] = @raTargetDSDID)
                OR (
                   @currentDSDID_FK IS NULL
                 AND (
                     (@raCurrentQueueDistributorID IS NOT NULL AND ud.[distributorID_FK] = @raCurrentQueueDistributorID)
                    OR (@raTargetDSDID IS NOT NULL AND d.[DSDID_FK] = @raTargetDSDID)
                 )
                )
               )
           )
           BEGIN ;THROW 50001, N'المستخدم المحدد غير مؤهل لاستلام التذكرة في المسار المستهدف', 1; END

             UPDATE [Tickets].[Ticket]
             SET [assignedUserID_FK] = @assignedUserID_FK
               , [currentDSDID_FK] = ISNULL(@currentDSDID_FK, [currentDSDID_FK])
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'REASSIGNED', @raOldStatus, @raOldStatus
             , @raOldDSD, ISNULL(@currentDSDID_FK, @raOldDSD), @raOldAssigned, @assignedUserID_FK
             , @performerUserID, ISNULL(@notes, N'تمت إعادة إسناد التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تمت إعادة إسناد التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","newAssignedUserID":"' + CAST(@assignedUserID_FK AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'REASSIGN_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إعادة إسناد التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- UPDATE_PRIORITY
         ----------------------------------------------------------------
         ELSE IF @Action = N'UPDATE_PRIORITY'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @suggestedPriorityID_FK IS NULL
             BEGIN ;THROW 50001, N'الأولوية الجديدة مطلوبة', 1; END

             DECLARE @upOldStatus INT, @upOldSuggestedPriority INT, @upOldEffectivePriority INT;
             SELECT
                   @upOldStatus = [ticketStatusID_FK]
                 , @upOldSuggestedPriority = [suggestedPriorityID_FK]
                 , @upOldEffectivePriority = [effectivePriorityID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID
               AND [ticketActive] = 1;

             IF @upOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF @upOldStatus IN
             (
                 SELECT [ticketStatusID]
                 FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'CLOSED', N'REJECTED')
                   AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'لا يمكن تعديل أولوية التذكرة في حالتها الحالية', 1; END

             IF NOT EXISTS
             (
                 SELECT 1
                 FROM [Tickets].[Priority]
                 WHERE [priorityID] = @suggestedPriorityID_FK
                   AND [priorityActive] = 1
             )
             BEGIN ;THROW 50001, N'الأولوية المحددة غير صالحة أو غير نشطة', 1; END

             UPDATE [Tickets].[Ticket]
             SET [suggestedPriorityID_FK] = @suggestedPriorityID_FK
               , [effectivePriorityID_FK] = @suggestedPriorityID_FK
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'UPDATE_PRIORITY', @upOldStatus, @upOldStatus
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم تعديل أولوية التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم تعديل أولوية التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","oldSuggestedPriorityID":"' + COALESCE(CAST(@upOldSuggestedPriority AS NVARCHAR(20)), N'')
                 + N'","oldEffectivePriorityID":"' + COALESCE(CAST(@upOldEffectivePriority AS NVARCHAR(20)), N'')
                 + N'","newPriorityID":"' + CAST(@suggestedPriorityID_FK AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'UPDATE_PRIORITY', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم تحديث أولوية التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- START_WORK
         ----------------------------------------------------------------
         ELSE IF @Action = N'START_WORK'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @swOldStatus INT;
             SELECT @swOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @swOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             DECLARE @statusInProgressID INT;
             SELECT @statusInProgressID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'IN_PROGRESS' AND [ticketStatusActive] = 1;

             IF @statusInProgressID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة IN_PROGRESS', 1; END

             IF @swOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'ASSIGNED', N'REOPENED') AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'يمكن بدء العمل على التذكرة فقط من حالتي ASSIGNED أو REOPENED', 1; END

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusInProgressID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'STARTED', @swOldStatus, @statusInProgressID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم بدء العمل'), COALESCE(@notes_A, ISNULL(@notes, N'تم بدء العمل')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'START_WORK', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم بدء العمل بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- RESOLVE_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'RESOLVE_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @rvOldStatus INT, @rvRequiresQR BIT;
             SELECT @rvOldStatus = [ticketStatusID_FK], @rvRequiresQR = ISNULL([requiresQualityReview], 0)
             FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @rvOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF @rvOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'IN_PROGRESS', N'CLARIFICATION') AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'يمكن حل التذكرة فقط من حالتي IN_PROGRESS أو CLARIFICATION', 1; END

             IF EXISTS (
               SELECT 1
               FROM [Tickets].[ClarificationRequest] cr
               WHERE cr.[ticketID_FK] = @ticketID
                 AND ISNULL(cr.[clarificationActive], 1) = 1
                 AND cr.[clarificationStatus] = N'OPEN'
             )
             BEGIN ;THROW 50001, N'لا يمكن حل التذكرة مع وجود طلب توضيح مفتوح', 1; END

             IF @rvRequiresQR = 0
                AND EXISTS (
                     SELECT 1
                     FROM [Tickets].[Ticket] child
                     WHERE child.[parentTicketID_FK] = @ticketID
                       AND child.[ticketActive] = 1
                       AND child.[ticketStatusID_FK] NOT IN (
                             SELECT [ticketStatusID]
                             FROM [Tickets].[TicketStatus]
                             WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                               AND [ticketStatusActive] = 1
                       )
                )
             BEGIN ;THROW 50001, N'لا يمكن الإغلاق النهائي مع وجود تذاكر فرعية مفتوحة', 1; END

             IF @rvRequiresQR = 1
             BEGIN
                 DECLARE @statusResolvedID INT;
                 SELECT @statusResolvedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'RESOLVED' AND [ticketStatusActive] = 1;

                 IF @statusResolvedID IS NULL
                     THROW 50002, N'تعذر العثور على حالة RESOLVED', 1; -- تعديل 13
                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @statusResolvedID
                   , [operationalResolutionDate] = GETDATE()
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ticketID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, N'RESOLVED', @rvOldStatus, @statusResolvedID
                 , NULL, NULL, NULL, NULL
                 , @performerUserID, ISNULL(@notes, N'تم حل التذكرة - بانتظار مراجعة الجودة'), COALESCE(@notes_A, ISNULL(@notes, N'تم حل التذكرة - بانتظار مراجعة الجودة')), @entryData, @hostName );

                 SELECT 1 AS IsSuccessful, N'تم حل التذكرة - بانتظار مراجعة الجودة' AS Message_;
             END
             ELSE
             BEGIN
                 DECLARE @statusClosedID INT;
                 SELECT @statusClosedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'CLOSED' AND [ticketStatusActive] = 1;

                 IF @statusClosedID IS NULL
                     THROW 50002, N'تعذر العثور على حالة CLOSED', 1; -- تعديل 13
                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @statusClosedID
                   , [operationalResolutionDate] = GETDATE()
                   , [finalClosureDate] = GETDATE()
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ticketID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, N'CLOSED', @rvOldStatus, @statusClosedID
                 , NULL, NULL, NULL, NULL
                 , @performerUserID, ISNULL(@notes, N'تم حل التذكرة وإغلاقها'), COALESCE(@notes_A, ISNULL(@notes, N'تم حل التذكرة وإغلاقها')), @entryData, @hostName );

                 SELECT 1 AS IsSuccessful, N'تم حل التذكرة وإغلاقها' AS Message_;
             END

             SET @ParentTicketToUpdate = NULL;
             SET @RemainingOpenChildren = 0;
             SET @ParentCurrentStatus = NULL;
             SET @PausedStatusID = NULL;
             SET @ResumeStatusID = NULL;

             SELECT @ParentTicketToUpdate = [parentTicketID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID;

             IF @ParentTicketToUpdate IS NOT NULL
             BEGIN
                 SELECT @RemainingOpenChildren = COUNT(*)
                 FROM [Tickets].[Ticket] child
                 WHERE child.[parentTicketID_FK] = @ParentTicketToUpdate
                   AND child.[ticketActive] = 1
                   AND child.[ticketStatusID_FK] NOT IN (
                         SELECT [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                           AND [ticketStatusActive] = 1
                   );

                 IF ISNULL(@RemainingOpenChildren, 0) = 0
                 BEGIN
                     UPDATE [Tickets].[Ticket]
                     SET [isParentBlocked] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     UPDATE [Tickets].[TicketPauseSession]
                     SET [pauseEnd] = GETDATE()
                       , [ticketPauseSessionActive] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID_FK] = @ParentTicketToUpdate
                       AND [relatedChildTicketID_FK] IS NOT NULL
                       AND [pauseEnd] IS NULL;

                     SELECT @ParentCurrentStatus = [ticketStatusID_FK]
                     FROM [Tickets].[Ticket]
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     SELECT @PausedStatusID = [ticketStatusID]
                     FROM [Tickets].[TicketStatus]
                     WHERE [ticketStatusCode] = N'PAUSED'
                       AND [ticketStatusActive] = 1;

                     IF @ParentCurrentStatus = @PausedStatusID
                        AND NOT EXISTS (
                             SELECT 1
                             FROM [Tickets].[TicketPauseSession]
                             WHERE [ticketID_FK] = @ParentTicketToUpdate
                               AND [pauseEnd] IS NULL
                               AND [ticketPauseSessionActive] = 1
                        )
                     BEGIN
                         SELECT TOP 1 @ResumeStatusID = [oldStatusID_FK]
                         FROM [Tickets].[TicketHistory]
                         WHERE [ticketID_FK] = @ParentTicketToUpdate
                           AND [actionTypeCode] = N'PAUSED'
                         ORDER BY [ticketHistoryID] DESC;

                         UPDATE [Tickets].[Ticket]
                         SET [ticketStatusID_FK] = ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                           , [entryData] = @entryData
                           , [hostName]  = @hostName
                         WHERE [ticketID] = @ParentTicketToUpdate;

                         INSERT INTO [Tickets].[TicketHistory]
                         ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                         , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                         , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                         VALUES
                         ( @ParentTicketToUpdate, @idaraID_FK, N'RESUMED', @ParentCurrentStatus, ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                         , NULL, NULL, NULL, NULL
                         , @performerUserID, N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', @entryData, @hostName );
                     END
                 END
             END

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'RESOLVE_TICKET', @ticketID, @entryData, @Note);
         END

         ----------------------------------------------------------------
         -- CLOSE_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'CLOSE_TICKET'
         BEGIN
             IF EXISTS (SELECT 1 FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND ISNULL([requiresQualityReview], 0) = 1)
             BEGIN ;THROW 50001, N'هذه التذكرة تتطلب مراجعة الجودة، وتُغلق تلقائياً عند اعتماد المراجعة', 1; END
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @clOldStatus INT;
             SELECT @clOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @clOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF @clOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'RESOLVED' AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'يمكن إغلاق التذكرة فقط من حالة RESOLVED', 1; END

             IF EXISTS (
                 SELECT 1
                 FROM [Tickets].[Ticket] child
                 WHERE child.[parentTicketID_FK] = @ticketID
                   AND child.[ticketActive] = 1
                   AND child.[ticketStatusID_FK] NOT IN (
                         SELECT [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                           AND [ticketStatusActive] = 1
                   )
             )
             BEGIN ;THROW 50001, N'لا يمكن إغلاق التذكرة مع وجود تذاكر فرعية مفتوحة', 1; END

             DECLARE @clStatusClosedID INT;
             SELECT @clStatusClosedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'CLOSED' AND [ticketStatusActive] = 1;

             IF @clStatusClosedID IS NULL
                 THROW 50002, N'تعذر العثور على حالة CLOSED', 1; -- تعديل 13
             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @clStatusClosedID
               , [finalClosureDate] = GETDATE()
               , [operationalResolutionDate] = ISNULL([operationalResolutionDate], GETDATE())
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'CLOSED', @clOldStatus, @clStatusClosedID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم إغلاق التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم إغلاق التذكرة')), @entryData, @hostName );

             SET @ParentTicketToUpdate = NULL;
             SET @RemainingOpenChildren = 0;
             SET @ParentCurrentStatus = NULL;
             SET @PausedStatusID = NULL;
             SET @ResumeStatusID = NULL;

             SELECT @ParentTicketToUpdate = [parentTicketID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID;

             IF @ParentTicketToUpdate IS NOT NULL
             BEGIN
                 SELECT @RemainingOpenChildren = COUNT(*)
                 FROM [Tickets].[Ticket] child
                 WHERE child.[parentTicketID_FK] = @ParentTicketToUpdate
                   AND child.[ticketActive] = 1
                   AND child.[ticketStatusID_FK] NOT IN (
                         SELECT [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                           AND [ticketStatusActive] = 1
                   );

                 IF ISNULL(@RemainingOpenChildren, 0) = 0
                 BEGIN
                     UPDATE [Tickets].[Ticket]
                     SET [isParentBlocked] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     UPDATE [Tickets].[TicketPauseSession]
                     SET [pauseEnd] = GETDATE()
                       , [ticketPauseSessionActive] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID_FK] = @ParentTicketToUpdate
                       AND [relatedChildTicketID_FK] IS NOT NULL
                       AND [pauseEnd] IS NULL;

                     SELECT @ParentCurrentStatus = [ticketStatusID_FK]
                     FROM [Tickets].[Ticket]
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     SELECT @PausedStatusID = [ticketStatusID]
                     FROM [Tickets].[TicketStatus]
                     WHERE [ticketStatusCode] = N'PAUSED'
                       AND [ticketStatusActive] = 1;

                     IF @ParentCurrentStatus = @PausedStatusID
                        AND NOT EXISTS (
                             SELECT 1
                             FROM [Tickets].[TicketPauseSession]
                             WHERE [ticketID_FK] = @ParentTicketToUpdate
                               AND [pauseEnd] IS NULL
                               AND [ticketPauseSessionActive] = 1
                        )
                     BEGIN
                         SELECT TOP 1 @ResumeStatusID = [oldStatusID_FK]
                         FROM [Tickets].[TicketHistory]
                         WHERE [ticketID_FK] = @ParentTicketToUpdate
                           AND [actionTypeCode] = N'PAUSED'
                         ORDER BY [ticketHistoryID] DESC;

                         UPDATE [Tickets].[Ticket]
                         SET [ticketStatusID_FK] = ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                           , [entryData] = @entryData
                           , [hostName]  = @hostName
                         WHERE [ticketID] = @ParentTicketToUpdate;

                         INSERT INTO [Tickets].[TicketHistory]
                         ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                         , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                         , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                         VALUES
                         ( @ParentTicketToUpdate, @idaraID_FK, N'RESUMED', @ParentCurrentStatus, ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                         , NULL, NULL, NULL, NULL
                         , @performerUserID, N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', @entryData, @hostName );
                     END
                 END
             END

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'CLOSE_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إغلاق التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- REJECT_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'REJECT_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @rjOldStatus INT;
             SELECT @rjOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @rjOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF @rjOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'NEW', N'REOPENED') AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'يمكن رفض التذكرة فقط من حالتي NEW أو REOPENED', 1; END

             DECLARE @statusRejectedID INT;
             SELECT @statusRejectedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'REJECTED' AND [ticketStatusActive] = 1;

             IF @statusRejectedID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة REJECTED', 1; END

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusRejectedID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'REJECTED', @rjOldStatus, @statusRejectedID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم رفض التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم رفض التذكرة')), @entryData, @hostName );

             SET @ParentTicketToUpdate = NULL;
             SET @RemainingOpenChildren = 0;

             SELECT @ParentTicketToUpdate = [parentTicketID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID;

             IF @ParentTicketToUpdate IS NOT NULL
             BEGIN
                 SELECT @RemainingOpenChildren = COUNT(*)
                 FROM [Tickets].[Ticket] child
                 WHERE child.[parentTicketID_FK] = @ParentTicketToUpdate
                   AND child.[ticketActive] = 1
                   AND child.[ticketStatusID_FK] NOT IN (
                         SELECT [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                           AND [ticketStatusActive] = 1
                   );

                 IF ISNULL(@RemainingOpenChildren, 0) = 0
                 BEGIN
                     UPDATE [Tickets].[Ticket]
                     SET [isParentBlocked] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     UPDATE [Tickets].[TicketPauseSession]
                     SET [pauseEnd] = GETDATE()
                       , [ticketPauseSessionActive] = 0
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID_FK] = @ParentTicketToUpdate
                       AND [relatedChildTicketID_FK] IS NOT NULL
                       AND [pauseEnd] IS NULL;
                 END
             END

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'REJECT_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم رفض التذكرة' AS Message_;
         END

         ----------------------------------------------------------------
         -- REOPEN_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'REOPEN_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @roOldStatus INT;
             SELECT @roOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @roOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF @roOldStatus NOT IN (
                 SELECT [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'CLOSED', N'RESOLVED') AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'يمكن إعادة فتح التذكرة فقط من حالتي CLOSED أو RESOLVED', 1; END

             DECLARE @statusReopenedID INT;
             SELECT @statusReopenedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'REOPENED' AND [ticketStatusActive] = 1;

             IF @statusReopenedID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة REOPENED', 1; END

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusReopenedID
               , [finalClosureDate] = NULL
               , [operationalResolutionDate] = NULL
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'REOPENED', @roOldStatus, @statusReopenedID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تمت إعادة فتح التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تمت إعادة فتح التذكرة')), @entryData, @hostName );

             SET @ParentTicketToUpdate = NULL;
             SET @ParentCurrentStatus = NULL;
             SET @PausedStatusID = NULL;

             SELECT @ParentTicketToUpdate = [parentTicketID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID;

             IF @ParentTicketToUpdate IS NOT NULL
             BEGIN
                 UPDATE [Tickets].[Ticket]
                 SET [isParentBlocked] = 1
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ParentTicketToUpdate;

                 IF NOT EXISTS (
                     SELECT 1
                     FROM [Tickets].[TicketPauseSession]
                     WHERE [ticketID_FK] = @ParentTicketToUpdate
                       AND [relatedChildTicketID_FK] = @ticketID
                       AND [pauseEnd] IS NULL
                       AND [ticketPauseSessionActive] = 1
                 )
                 BEGIN
                     INSERT INTO [Tickets].[TicketPauseSession]
                     ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK], [relatedChildTicketID_FK]
                     , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A]
                     , [ticketPauseSessionActive], [entryData], [hostName] )
                     VALUES
                     ( @ParentTicketToUpdate, @idaraID_FK, 1, @ticketID
                     , GETDATE(), NULL, 1, N'إيقاف تلقائي: تمت إعادة فتح تذكرة فرعية', N'إيقاف تلقائي: تمت إعادة فتح تذكرة فرعية'
                     , 1, @entryData, @hostName );
                 END

                 SELECT @ParentCurrentStatus = [ticketStatusID_FK]
                 FROM [Tickets].[Ticket]
                 WHERE [ticketID] = @ParentTicketToUpdate;

                 SELECT @PausedStatusID = [ticketStatusID]
                 FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'PAUSED'
                   AND [ticketStatusActive] = 1;

                 IF @PausedStatusID IS NOT NULL
                    AND @ParentCurrentStatus IS NOT NULL
                    AND @ParentCurrentStatus <> @PausedStatusID
                 BEGIN
                     UPDATE [Tickets].[Ticket]
                     SET [ticketStatusID_FK] = @PausedStatusID
                       , [entryData] = @entryData
                       , [hostName]  = @hostName
                     WHERE [ticketID] = @ParentTicketToUpdate;

                     INSERT INTO [Tickets].[TicketHistory]
                     ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                     , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                     , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                     VALUES
                     ( @ParentTicketToUpdate, @idaraID_FK, N'PAUSED', @ParentCurrentStatus, @PausedStatusID
                     , NULL, NULL, NULL, NULL
                     , @performerUserID, N'تم إيقاف التذكرة الأصلية تلقائياً بعد إعادة فتح تذكرة فرعية', N'تم إيقاف التذكرة الأصلية تلقائياً بعد إعادة فتح تذكرة فرعية', @entryData, @hostName );
                 END
             END

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'REOPEN_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تمت إعادة فتح التذكرة' AS Message_;
         END

         ----------------------------------------------------------------
         -- PAUSE_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'PAUSE_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @pauseReasonID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف سبب الإيقاف مطلوب', 1; END

             DECLARE @pOldStatus INT;
             SELECT @pOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @pOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF EXISTS (SELECT 1 FROM [Tickets].[TicketPauseSession]
                        WHERE [ticketID_FK] = @ticketID AND [pauseEnd] IS NULL AND [ticketPauseSessionActive] = 1)
             BEGIN ;THROW 50001, N'التذكرة موقفة بالفعل', 1; END

             DECLARE @statusPausedID INT;
             SELECT @statusPausedID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'PAUSED' AND [ticketStatusActive] = 1;

             IF @statusPausedID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة PAUSED', 1; END

             INSERT INTO [Tickets].[TicketPauseSession]
             ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK]
             , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A]
             , [ticketPauseSessionActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @pauseReasonID_FK
             , GETDATE(), NULL, 1, @pauseNotesToSave, @pauseNotesToSave
             , 1, @entryData, @hostName );

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusPausedID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'PAUSED', @pOldStatus, @statusPausedID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم إيقاف التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم إيقاف التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","pauseReasonID":"' + CAST(@pauseReasonID_FK AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'PAUSE_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إيقاف التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- RESUME_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'RESUME_TICKET'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @rmOldStatus INT;
             SELECT @rmOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @rmOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             DECLARE @openPauseID BIGINT, @prevStatusID INT, @openPauseClarificationRequestID BIGINT;
             SELECT TOP 1 @openPauseID = [ticketPauseSessionID]
                          , @openPauseClarificationRequestID = [relatedClarificationRequestID_FK]
             FROM [Tickets].[TicketPauseSession]
             WHERE [ticketID_FK] = @ticketID AND [pauseEnd] IS NULL AND [ticketPauseSessionActive] = 1
             ORDER BY [ticketPauseSessionID] DESC;

             IF @openPauseID IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على جلسة إيقاف مفتوحة لهذه التذكرة', 1; END

             IF @openPauseClarificationRequestID IS NOT NULL
             BEGIN ;THROW 50001, N'استخدم إجراء الرد على التوضيح لإنهاء هذا الإيقاف', 1; END

             SELECT TOP 1 @prevStatusID = [oldStatusID_FK]
             FROM [Tickets].[TicketHistory]
             WHERE [ticketID_FK] = @ticketID AND [actionTypeCode] = N'PAUSED'
             ORDER BY [ticketHistoryID] DESC;

             IF @prevStatusID IS NULL
             BEGIN
                 SET @prevStatusID = @rmOldStatus;
             END

             UPDATE [Tickets].[TicketPauseSession]
             SET [pauseEnd] = GETDATE()
               , [ticketPauseSessionActive] = 0
             WHERE [ticketPauseSessionID] = @openPauseID;

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @prevStatusID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'RESUMED', @rmOldStatus, @prevStatusID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم استئناف التذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم استئناف التذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'RESUME_TICKET', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم استئناف التذكرة بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- REQUEST_CLARIFICATION
         ----------------------------------------------------------------
         ELSE IF @Action = N'REQUEST_CLARIFICATION'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @clarificationReasonID_FK IS NULL
             BEGIN ;THROW 50001, N'سبب طلب التوضيح مطلوب', 1; END
             IF @requestedFromUserID IS NULL AND @requestedFromDSDID_FK IS NULL
             BEGIN ;THROW 50001, N'يجب تحديد المستخدم أو الجهة المطلوب منها التوضيح', 1; END
             IF NULLIF(LTRIM(RTRIM(@notesToSave)), N'') IS NULL
             BEGIN ;THROW 50001, N'ملاحظات طلب التوضيح مطلوبة', 1; END

             DECLARE @crOldStatus INT;
             DECLARE @statusClarificationID INT;
             DECLARE @clarificationPauseReasonID INT;

             SELECT @crOldStatus = [ticketStatusID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID
               AND [ticketActive] = 1;

             IF @crOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             SELECT @statusClarificationID = [ticketStatusID]
             FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'CLARIFICATION'
               AND [ticketStatusActive] = 1;

             IF @statusClarificationID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة CLARIFICATION', 1; END

             IF @crOldStatus IN (
                 SELECT [ticketStatusID]
                 FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                   AND [ticketStatusActive] = 1
             )
             BEGIN ;THROW 50001, N'لا يمكن طلب توضيح لتذكرة منتهية أو مغلقة', 1; END

             IF @crOldStatus = @statusClarificationID
             BEGIN ;THROW 50001, N'التذكرة في حالة طلب توضيح بالفعل', 1; END

             IF EXISTS (
                 SELECT 1
                 FROM [Tickets].[ClarificationRequest]
                 WHERE [ticketID_FK] = @ticketID
                   AND ISNULL([clarificationActive], 1) = 1
                   AND [clarificationStatus] = N'OPEN'
             )
             BEGIN ;THROW 50001, N'يوجد طلب توضيح مفتوح لهذه التذكرة بالفعل', 1; END

             IF EXISTS (
                 SELECT 1
                 FROM [Tickets].[TicketPauseSession]
                 WHERE [ticketID_FK] = @ticketID
                   AND [pauseEnd] IS NULL
                   AND [ticketPauseSessionActive] = 1
             )
             BEGIN ;THROW 50001, N'لا يمكن طلب توضيح بينما التذكرة موقفة بالفعل', 1; END

             IF NOT EXISTS (
                 SELECT 1
                 FROM [Tickets].[ClarificationReason]
                 WHERE [clarificationReasonID] = @clarificationReasonID_FK
                   AND [clarificationReasonActive] = 1
             )
             BEGIN ;THROW 50001, N'سبب طلب التوضيح المحدد غير صالح', 1; END

             IF @requestedFromDSDID_FK IS NOT NULL
                AND NOT EXISTS (
                     SELECT 1
                     FROM dbo.[V_GetFullStructureForDSD] f
                     WHERE f.[DSDID] = @requestedFromDSDID_FK
                       AND (@idaraID_FK IS NULL OR f.[IdaraID] = @idaraID_FK)
                )
             BEGIN ;THROW 50001, N'الجهة المطلوب منها التوضيح غير صالحة', 1; END

             SELECT @clarificationPauseReasonID = [pauseReasonID]
             FROM [Tickets].[PauseReason]
             WHERE [pauseReasonCode] = N'CLARIFICATION'
               AND [pauseReasonActive] = 1;

             IF @clarificationPauseReasonID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على سبب الإيقاف CLARIFICATION', 1; END

             INSERT INTO [Tickets].[ClarificationRequest]
             ( [ticketID_FK], [idaraID_FK], [requestedByUserID], [requestedFromUserID], [requestedFromDSDID_FK]
             , [clarificationReasonID_FK], [requestNotes], [responseNotes], [clarificationStatus], [clarificationActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @performerUserID, @requestedFromUserID, @requestedFromDSDID_FK
             , @clarificationReasonID_FK, @notesToSave, NULL, N'OPEN', 1, @entryData, @hostName );

             SET @NewID = SCOPE_IDENTITY();

             INSERT INTO [Tickets].[TicketPauseSession]
             ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK], [relatedClarificationRequestID_FK]
             , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A]
             , [ticketPauseSessionActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @clarificationPauseReasonID, @NewID
             , GETDATE(), NULL, 1, @pauseNotesToSave, @pauseNotesToSave
             , 1, @entryData, @hostName );

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusClarificationID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'CLARIFICATION_REQUESTED', @crOldStatus, @statusClarificationID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم طلب توضيح للتذكرة'), COALESCE(@notes_A, ISNULL(@notes, N'تم طلب توضيح للتذكرة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","clarificationRequestID":"' + CAST(@NewID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ClarificationRequest]', N'REQUEST_CLARIFICATION', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إرسال طلب التوضيح بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- RESPOND_CLARIFICATION
         ----------------------------------------------------------------
         ELSE IF @Action = N'RESPOND_CLARIFICATION'
         BEGIN
             -- تعديل 10: فحص الإدارة في الإجراءات التي تعتمد على معرف غير معرف التذكرة.
             IF @idaraID_FK IS NULL
                 THROW 50001, N'معرف الإدارة مطلوب', 1;
             IF NOT EXISTS (
                 SELECT 1 FROM [Tickets].[ClarificationRequest] x
                 INNER JOIN [Tickets].[Ticket] t ON t.[ticketID] = x.[ticketID_FK]
                 WHERE x.[clarificationRequestID] = @clarificationRequestID
                   AND x.[idaraID_FK] = @idaraID_FK
                   AND t.[idaraID_FK] = @idaraID_FK
                   AND t.[ticketActive] = 1
             )
                 THROW 50001, N'السجل غير موجود أو لا يتبع الإدارة المحددة', 1;
             IF @clarificationRequestID IS NULL
             BEGIN ;THROW 50001, N'معرف طلب التوضيح مطلوب', 1; END
             IF NULLIF(LTRIM(RTRIM(@notesToSave)), N'') IS NULL
             BEGIN ;THROW 50001, N'ملاحظات الرد على التوضيح مطلوبة', 1; END

             DECLARE @responseTicketID BIGINT;
             DECLARE @responseClarificationStatus NVARCHAR(50);
             DECLARE @responseTicketStatus INT;
             DECLARE @responseResumeStatusID INT;
             DECLARE @responseOtherOpenClarifications INT;
             DECLARE @responseOtherOpenPauses INT;
             DECLARE @responseAssignedUserID INT;
             DECLARE @responseClarificationStatusID INT;
             DECLARE @responsePausedStatusID INT;
             DECLARE @responseAssignedStatusID INT;
             DECLARE @responseRoutedStatusID INT;

             SELECT @responseTicketID = [ticketID_FK]
                  , @responseClarificationStatus = [clarificationStatus]
             FROM [Tickets].[ClarificationRequest]
             WHERE [clarificationRequestID] = @clarificationRequestID
               AND ISNULL([clarificationActive], 1) = 1;

             IF @responseTicketID IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على طلب التوضيح', 1; END

             IF @responseClarificationStatus <> N'OPEN'
             BEGIN ;THROW 50001, N'طلب التوضيح ليس في حالة OPEN', 1; END

             SELECT @responseClarificationStatusID = [ticketStatusID]
             FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'CLARIFICATION'
               AND [ticketStatusActive] = 1;

             IF @responseClarificationStatusID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة CLARIFICATION', 1; END

             SELECT @responseTicketStatus = [ticketStatusID_FK]
                  , @responseAssignedUserID = [assignedUserID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @responseTicketID
               AND [ticketActive] = 1;

             IF @responseTicketStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على التذكرة المرتبطة بطلب التوضيح', 1; END

             UPDATE [Tickets].[ClarificationRequest]
             SET [responseNotes] = @notesToSave
               , [responseDate] = GETDATE()
               , [clarificationStatus] = N'RESPONDED'
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [clarificationRequestID] = @clarificationRequestID;

             UPDATE [Tickets].[TicketPauseSession]
             SET [pauseEnd] = GETDATE()
               , [ticketPauseSessionActive] = 0
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID_FK] = @responseTicketID
               AND [relatedClarificationRequestID_FK] = @clarificationRequestID
               AND [pauseEnd] IS NULL
               AND [ticketPauseSessionActive] = 1;

             SELECT @responseOtherOpenClarifications = COUNT(*)
             FROM [Tickets].[ClarificationRequest]
             WHERE [ticketID_FK] = @responseTicketID
               AND [clarificationRequestID] <> @clarificationRequestID
               AND ISNULL([clarificationActive], 1) = 1
               AND [clarificationStatus] = N'OPEN';

             SELECT @responseOtherOpenPauses = COUNT(*)
             FROM [Tickets].[TicketPauseSession]
             WHERE [ticketID_FK] = @responseTicketID
               AND [pauseEnd] IS NULL
               AND [ticketPauseSessionActive] = 1;

             SET @responseResumeStatusID = @responseTicketStatus;

             IF ISNULL(@responseOtherOpenClarifications, 0) = 0
                AND @responseTicketStatus = @responseClarificationStatusID
             BEGIN
                 IF ISNULL(@responseOtherOpenPauses, 0) > 0
                 BEGIN
                     SELECT @responsePausedStatusID = [ticketStatusID]
                     FROM [Tickets].[TicketStatus]
                     WHERE [ticketStatusCode] = N'PAUSED'
                       AND [ticketStatusActive] = 1;

                     SET @responseResumeStatusID = ISNULL(@responsePausedStatusID, @responseTicketStatus);
                 END
                 ELSE
                 BEGIN
                     -- SELECT leaves the variable unchanged when no row matches; reset so the fallback below runs.
                     SET @responseResumeStatusID = NULL;
                     SELECT TOP 1 @responseResumeStatusID = [oldStatusID_FK]
                     FROM [Tickets].[TicketHistory]
                     WHERE [ticketID_FK] = @responseTicketID
                       AND [actionTypeCode] = N'CLARIFICATION_REQUESTED'
                       AND [oldStatusID_FK] IS NOT NULL
                       AND [oldStatusID_FK] <> @responseClarificationStatusID
                     ORDER BY [ticketHistoryID] DESC;

                     IF @responseResumeStatusID IS NULL
                     BEGIN
                         SELECT @responseAssignedStatusID = [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] = N'ASSIGNED'
                           AND [ticketStatusActive] = 1;

                         SELECT @responseRoutedStatusID = [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] = N'ROUTED'
                           AND [ticketStatusActive] = 1;

                         SET @responseResumeStatusID = CASE
                             WHEN @responseAssignedUserID IS NOT NULL THEN @responseAssignedStatusID
                             ELSE @responseRoutedStatusID
                         END;
                     END
                 END

                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = ISNULL(@responseResumeStatusID, @responseTicketStatus)
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @responseTicketID;
             END

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @responseTicketID, @idaraID_FK, N'CLARIFICATION_RESPONDED', @responseTicketStatus, ISNULL(@responseResumeStatusID, @responseTicketStatus)
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم الرد على طلب التوضيح'), COALESCE(@notes_A, ISNULL(@notes, N'تم الرد على طلب التوضيح')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@responseTicketID AS NVARCHAR(20))
                 + N'","clarificationRequestID":"' + CAST(@clarificationRequestID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ClarificationRequest]', N'RESPOND_CLARIFICATION', @clarificationRequestID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم تسجيل الرد على طلب التوضيح بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- CREATE_CHILD_TICKET
         ----------------------------------------------------------------
         ELSE IF @Action = N'CREATE_CHILD_TICKET'
         BEGIN
             IF @parentTicketID_FK IS NULL OR @parentTicketID_FK <= 0
             BEGIN ;THROW 50001, N'معرف التذكرة الأصلية مطلوب للتذاكر الفرعية', 1; END

           IF NULLIF(LTRIM(RTRIM(@titleToSave)), N'') IS NULL
             BEGIN ;THROW 50001, N'العنوان مطلوب', 1; END

             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END

             DECLARE @parentExists BIT = 0;
             DECLARE @parentRootID BIGINT;
             DECLARE @parentSvcID BIGINT;
             DECLARE @parentAllowsChild BIT = 0;

             SELECT @parentExists = 1
                  , @parentRootID = [rootTicketID_FK]
                  , @parentSvcID = [serviceID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @parentTicketID_FK AND [ticketActive] = 1
               AND [idaraID_FK] = @idaraID_FK; -- تعديل 08: منع ربط تذاكر إدارات مختلفة

             IF @parentExists = 0
             BEGIN ;THROW 50001, N'لم يتم العثور على التذكرة الأصلية أو أنها غير نشطة', 1; END

             SELECT @parentAllowsChild = ISNULL([allowsChildTickets], 0)
             FROM [Tickets].[Service]
             WHERE [serviceID] = @parentSvcID AND [serviceActive] = 1;

             IF @parentAllowsChild = 0
             BEGIN ;THROW 50001, N'خدمة التذكرة الأصلية لا تسمح بإنشاء تذاكر فرعية', 1; END

             -- تعديل 05: قفل منطقي داخل المعاملة لمنع تكرار أرقام التذاكر عند الطلبات المتزامنة.
             SET @TicketNoLockResult = NULL;
             EXEC @TicketNoLockResult = sys.sp_getapplock
                 @Resource = N'Tickets.TicketNo.YearlySequence',
                 @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
             IF @TicketNoLockResult < 0
                 THROW 50002, N'تعذر حجز رقم التذكرة، أعد المحاولة', 1;
             DECLARE @childYr NVARCHAR(4) = CONVERT(NVARCHAR(4), YEAR(GETDATE()));
             DECLARE @childSeq INT;
             SELECT @childSeq = ISNULL(MAX(TRY_CONVERT(INT, RIGHT([ticketNo], 5))), 0) + 1
             FROM [Tickets].[Ticket]
             WHERE [ticketNo] LIKE N'TKT-' + @childYr + N'-%';

             -- تعديل 06: التحقق من حد التسلسل في التذاكر الفرعية أيضًا.
             IF @childSeq > 99999 THROW 50002, N'تم استنفاد تسلسل أرقام التذاكر لهذا العام', 1;
             SET @NewTicketNo = N'TKT-' + @childYr + N'-' + RIGHT(N'00000' + CAST(@childSeq AS NVARCHAR(10)), 5);

             DECLARE @childStatusNewID INT;
             SELECT @childStatusNewID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'NEW' AND [ticketStatusActive] = 1;

             INSERT INTO [Tickets].[Ticket]
             (
                   [ticketNo], [idaraID_FK], [parentTicketID_FK], [rootTicketID_FK]
                 , [serviceID_FK], [ticketClassID_FK], [requesterTypeID_FK]
                 , [requesterUserID_FK], [requesterResidentID_FK]
                 , [title], [title_A], [description_], [description_A]
                 , [suggestedPriorityID_FK], [effectivePriorityID_FK], [ticketStatusID_FK]
                 , [currentDSDID_FK], [currentQueueDistributorID_FK], [assignedUserID_FK]
                 , [locationBuildingNo], [locationUnitNo], [locationArea], [locationArea_A]
                 , [operationalResolutionDate], [finalClosureDate]
                 , [requiresQualityReview], [isOtherService], [isParentBlocked], [ticketActive]
                 , [entryData], [hostName]
             )
             VALUES
             (
                   @NewTicketNo, @idaraID_FK, @parentTicketID_FK, @parentRootID
                 , ISNULL(@serviceID_FK, @parentSvcID), @ticketClassID_FK, @requesterTypeID_FK
                 , @requesterUserID_FK, @requesterResidentID_FK
                 , @titleToSave, @titleToSave, @descriptionToSave, @descriptionToSave
                 , @suggestedPriorityID_FK, @suggestedPriorityID_FK, @childStatusNewID
                 , @currentDSDID_FK, @currentQueueDistributorID_FK, @assignedUserID_FK
                 , @locationBuildingNo, @locationUnitNo, @locationAreaToSave, @locationAreaToSave
                 , NULL, NULL
                 , 0, 0, 0, 1
                 , @entryData, @hostName
             );

             SET @NewID = SCOPE_IDENTITY();
             IF @NewID IS NULL OR @NewID <= 0
             BEGIN ;THROW 50002, N'فشل إنشاء التذكرة الفرعية', 1; END

             SELECT @ParentCurrentStatus = [ticketStatusID_FK]
             FROM [Tickets].[Ticket]
             WHERE [ticketID] = @parentTicketID_FK;

             SELECT @PausedStatusID = [ticketStatusID]
             FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'PAUSED'
               AND [ticketStatusActive] = 1;

             UPDATE [Tickets].[Ticket]
             SET [isParentBlocked] = 1
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @parentTicketID_FK;

             IF @PausedStatusID IS NOT NULL
                AND @ParentCurrentStatus IS NOT NULL
                AND @ParentCurrentStatus <> @PausedStatusID
             BEGIN
                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @PausedStatusID
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @parentTicketID_FK;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @parentTicketID_FK, @idaraID_FK, N'PAUSED', @ParentCurrentStatus, @PausedStatusID
                 , NULL, NULL, NULL, NULL
                 , @performerUserID, N'تم إيقاف التذكرة الأصلية تلقائياً بسبب إنشاء تذكرة فرعية', N'تم إيقاف التذكرة الأصلية تلقائياً بسبب إنشاء تذكرة فرعية', @entryData, @hostName );
             END

             INSERT INTO [Tickets].[TicketPauseSession]
             ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK], [relatedChildTicketID_FK]
             , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A]
             , [ticketPauseSessionActive], [entryData], [hostName] )
             VALUES
             ( @parentTicketID_FK, @idaraID_FK, 1, @NewID
             , GETDATE(), NULL, 1, N'إيقاف تلقائي: تم إنشاء تذكرة فرعية', N'إيقاف تلقائي: تم إنشاء تذكرة فرعية'
             , 1, @entryData, @hostName );

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @NewID, @idaraID_FK, N'CREATED', NULL, @childStatusNewID
             , NULL, @currentDSDID_FK, NULL, NULL
             , @performerUserID, N'تم إنشاء تذكرة فرعية', COALESCE(@notes_A, N'تم إنشاء تذكرة فرعية'), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@NewID AS NVARCHAR(20))
                 + N'","ticketNo":"' + ISNULL(@NewTicketNo, N'') + N''
                 + N'","parentTicketID":"' + CAST(@parentTicketID_FK AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Ticket]', N'CREATE_CHILD_TICKET', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful
                  , N'تم إنشاء تذكرة فرعية: ' + @NewTicketNo AS Message_;
         END

         ----------------------------------------------------------------
         -- SUBMIT_QUALITY_REVIEW
         ----------------------------------------------------------------
         ELSE IF @Action = N'SUBMIT_QUALITY_REVIEW'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @qualityReviewResultID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف نتيجة مراجعة الجودة مطلوب', 1; END

             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Ticket] t JOIN [Tickets].[TicketStatus] s ON s.[ticketStatusID] = t.[ticketStatusID_FK]
                            WHERE t.[ticketID] = @ticketID AND s.[ticketStatusCode] = N'RESOLVED')
             BEGIN ;THROW 50001, N'مراجعة الجودة متاحة فقط للتذاكر المحلولة', 1; END
             IF EXISTS (SELECT 1 FROM [Tickets].[QualityReview] WHERE [ticketID_FK] = @ticketID AND ISNULL([finalized], 0) = 0 AND ISNULL([qualityReviewActive], 1) = 1)
             BEGIN ;THROW 50001, N'توجد مراجعة جودة بانتظار الاعتماد لهذه التذكرة', 1; END
             INSERT INTO [Tickets].[QualityReview]
             ( [ticketID_FK], [idaraID_FK], [reviewerUserID], [reviewScope]
             , [qualityReviewResultID_FK], [reviewNotes], [returnToUserID], [finalized]
             , [qualityReviewActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @performerUserID, @reviewScope
             , @qualityReviewResultID_FK, @reviewNotes, @returnToUserID, 0
             , 1, @entryData, @hostName );

             SET @NewID = SCOPE_IDENTITY();

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'QUALITY_REVIEW', NULL, NULL
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@reviewNotes, N'تم إرسال مراجعة الجودة'), COALESCE(@notes_A, ISNULL(@reviewNotes, N'تم إرسال مراجعة الجودة')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","qualityReviewID":"' + CAST(@NewID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[QualityReview]', N'SUBMIT_QUALITY_REVIEW', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إرسال مراجعة الجودة' AS Message_;
         END

         ----------------------------------------------------------------
         -- FINALIZE_QUALITY_REVIEW
         ----------------------------------------------------------------
         ELSE IF @Action = N'FINALIZE_QUALITY_REVIEW'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END

             DECLARE @qrID BIGINT, @qrResultID INT, @qrReturnTo INT;
             SELECT TOP 1 @qrID = [qualityReviewID], @qrResultID = [qualityReviewResultID_FK], @qrReturnTo = [returnToUserID]
             FROM [Tickets].[QualityReview]
             WHERE [ticketID_FK] = @ticketID AND [finalized] = 0 AND [qualityReviewActive] = 1
             ORDER BY [qualityReviewID] DESC;

             IF @qrID IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على مراجعة جودة معلقة لهذه التذكرة', 1; END

             DECLARE @qrOldStatus INT;
             SELECT @qrOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket]
             WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             DECLARE @qrResultCode NVARCHAR(50);
             SELECT @qrResultCode = [qualityReviewResultCode] FROM [Tickets].[QualityReviewResult]
             WHERE [qualityReviewResultID] = @qrResultID;

             UPDATE [Tickets].[QualityReview]
             SET [finalized] = 1
               , [reviewNotes] = ISNULL(@reviewNotes, [reviewNotes])
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [qualityReviewID] = @qrID;

             IF @qrResultCode = N'APPROVED'
             BEGIN
                 IF EXISTS (
                     SELECT 1
                     FROM [Tickets].[Ticket] child
                     WHERE child.[parentTicketID_FK] = @ticketID
                       AND child.[ticketActive] = 1
                       AND child.[ticketStatusID_FK] NOT IN (
                             SELECT [ticketStatusID]
                             FROM [Tickets].[TicketStatus]
                             WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                               AND [ticketStatusActive] = 1
                       )
                 )
                 BEGIN ;THROW 50001, N'لا يمكن اعتماد مراجعة الجودة مع وجود تذاكر فرعية مفتوحة', 1; END

                 DECLARE @qrCloseID INT;
                 SELECT @qrCloseID = [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'CLOSED' AND [ticketStatusActive] = 1;

                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @qrCloseID, [finalClosureDate] = GETDATE()
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ticketID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, N'QUALITY_APPROVED', @qrOldStatus, @qrCloseID
                 , NULL, NULL, NULL, NULL
                 , @performerUserID, N'تم اعتماد مراجعة الجودة - تم إغلاق التذكرة', COALESCE(@notes_A, N'تم اعتماد مراجعة الجودة - تم إغلاق التذكرة'), @entryData, @hostName );

                 SET @ParentTicketToUpdate = NULL;
                 SET @RemainingOpenChildren = 0;
                 SET @ParentCurrentStatus = NULL;
                 SET @PausedStatusID = NULL;
                 SET @ResumeStatusID = NULL;

                 SELECT @ParentTicketToUpdate = [parentTicketID_FK]
                 FROM [Tickets].[Ticket]
                 WHERE [ticketID] = @ticketID;

                 IF @ParentTicketToUpdate IS NOT NULL
                 BEGIN
                     SELECT @RemainingOpenChildren = COUNT(*)
                     FROM [Tickets].[Ticket] child
                     WHERE child.[parentTicketID_FK] = @ParentTicketToUpdate
                       AND child.[ticketActive] = 1
                       AND child.[ticketStatusID_FK] NOT IN (
                             SELECT [ticketStatusID]
                             FROM [Tickets].[TicketStatus]
                             WHERE [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED')
                               AND [ticketStatusActive] = 1
                       );

                     IF ISNULL(@RemainingOpenChildren, 0) = 0
                     BEGIN
                         UPDATE [Tickets].[Ticket]
                         SET [isParentBlocked] = 0
                           , [entryData] = @entryData
                           , [hostName]  = @hostName
                         WHERE [ticketID] = @ParentTicketToUpdate;

                         UPDATE [Tickets].[TicketPauseSession]
                         SET [pauseEnd] = GETDATE()
                           , [ticketPauseSessionActive] = 0
                           , [entryData] = @entryData
                           , [hostName]  = @hostName
                         WHERE [ticketID_FK] = @ParentTicketToUpdate
                           AND [relatedChildTicketID_FK] IS NOT NULL
                           AND [pauseEnd] IS NULL;

                         SELECT @ParentCurrentStatus = [ticketStatusID_FK]
                         FROM [Tickets].[Ticket]
                         WHERE [ticketID] = @ParentTicketToUpdate;

                         SELECT @PausedStatusID = [ticketStatusID]
                         FROM [Tickets].[TicketStatus]
                         WHERE [ticketStatusCode] = N'PAUSED'
                           AND [ticketStatusActive] = 1;

                         IF @ParentCurrentStatus = @PausedStatusID
                            AND NOT EXISTS (
                                 SELECT 1
                                 FROM [Tickets].[TicketPauseSession]
                                 WHERE [ticketID_FK] = @ParentTicketToUpdate
                                   AND [pauseEnd] IS NULL
                                   AND [ticketPauseSessionActive] = 1
                            )
                         BEGIN
                             SELECT TOP 1 @ResumeStatusID = [oldStatusID_FK]
                             FROM [Tickets].[TicketHistory]
                             WHERE [ticketID_FK] = @ParentTicketToUpdate
                               AND [actionTypeCode] = N'PAUSED'
                             ORDER BY [ticketHistoryID] DESC;

                             UPDATE [Tickets].[Ticket]
                             SET [ticketStatusID_FK] = ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                               , [entryData] = @entryData
                               , [hostName]  = @hostName
                             WHERE [ticketID] = @ParentTicketToUpdate;

                             INSERT INTO [Tickets].[TicketHistory]
                             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                             VALUES
                             ( @ParentTicketToUpdate, @idaraID_FK, N'RESUMED', @ParentCurrentStatus, ISNULL(@ResumeStatusID, @ParentCurrentStatus)
                             , NULL, NULL, NULL, NULL
                             , @performerUserID, N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', N'تم استئناف التذكرة الأصلية تلقائياً بعد اكتمال التذاكر الفرعية', @entryData, @hostName );
                         END
                     END
                 END
             END
             ELSE IF @qrResultCode IN (N'RETURN_CORRECTION', N'REJECTED')
             BEGIN
                 DECLARE @qrInProgressID INT;
                 SELECT @qrInProgressID = [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'IN_PROGRESS' AND [ticketStatusActive] = 1;

                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @qrInProgressID
                   , [assignedUserID_FK] = ISNULL(@qrReturnTo, [assignedUserID_FK])
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ticketID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, N'QUALITY_RETURNED', @qrOldStatus, @qrInProgressID
                 , NULL, NULL, NULL, @qrReturnTo
                 , @performerUserID, N'تم إرجاع مراجعة الجودة للتصحيح', COALESCE(@notes_A, N'تم إرجاع مراجعة الجودة للتصحيح'), @entryData, @hostName );
             END
             ELSE IF @qrResultCode = N'ESCALATED'
             BEGIN
                 DECLARE @qrArbID INT;
                 SELECT @qrArbID = [ticketStatusID] FROM [Tickets].[TicketStatus]
                 WHERE [ticketStatusCode] = N'ARBITRATION' AND [ticketStatusActive] = 1;

                 -- An escalation must create an arbitration case, otherwise the ticket has nothing to decide.
                 DECLARE @qrDSD INT = (SELECT [currentDSDID_FK] FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID);
                 IF @qrDSD IS NULL
                 BEGIN ;THROW 50001, N'لا يمكن التصعيد للتحكيم لتذكرة بلا جهة حالية', 1; END
                 INSERT INTO [Tickets].[ArbitrationCase]
                 ( [ticketID_FK], [idaraID_FK], [raisedByUserID], [raisedFromDSDID_FK], [arbitrationReasonID_FK], [arbitratorDistributorID]
                 , [arbitrationStatus], [decisionType], [decisionNotes], [arbitrationCaseActive], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, @performerUserID, @qrDSD, NULL, NULL
                 , N'OPEN', NULL, N'تصعيد من مراجعة الجودة', 1, @entryData, @hostName );
                 DECLARE @qrArbCaseID BIGINT = SCOPE_IDENTITY();
                 INSERT INTO [Tickets].[TicketPauseSession]
                 ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK], [relatedArbitrationCaseID_FK]
                 , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A], [ticketPauseSessionActive], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, (SELECT TOP 1 [pauseReasonID] FROM [Tickets].[PauseReason] WHERE [pauseReasonCode] = N'ARBITRATION'), @qrArbCaseID
                 , GETDATE(), NULL, 1, N'Auto pause: quality review escalated', N'إيقاف تلقائي: تم تصعيد مراجعة الجودة للتحكيم', 1, @entryData, @hostName );
                 
                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = @qrArbID
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @ticketID;

                 INSERT INTO [Tickets].[TicketHistory]
                 ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
                 , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
                 , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
                 VALUES
                 ( @ticketID, @idaraID_FK, N'QUALITY_ESCALATED', @qrOldStatus, @qrArbID
                 , NULL, NULL, NULL, NULL
                 , @performerUserID, N'تم تصعيد مراجعة الجودة إلى التحكيم', COALESCE(@notes_A, N'تم تصعيد مراجعة الجودة إلى التحكيم'), @entryData, @hostName );
             END

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","qualityReviewID":"' + CAST(@qrID AS NVARCHAR(20))
                 + N'","result":"' + ISNULL(@qrResultCode, N'') + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[QualityReview]', N'FINALIZE_QUALITY_REVIEW', @qrID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إنهاء مراجعة الجودة' AS Message_;
         END

         ----------------------------------------------------------------
         -- RAISE_ARBITRATION
         ----------------------------------------------------------------
         ELSE IF @Action = N'RAISE_ARBITRATION'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF @arbitrationReasonID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف سبب التحكيم مطلوب', 1; END

             DECLARE @abOldStatus INT, @abOldDSD INT;
             SELECT @abOldStatus = [ticketStatusID_FK], @abOldDSD = [currentDSDID_FK]
             FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1;

             IF @abOldStatus IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             IF EXISTS (SELECT 1 FROM [Tickets].[TicketStatus] WHERE [ticketStatusID] = @abOldStatus
                        AND [ticketStatusCode] IN (N'RESOLVED', N'CLOSED', N'REJECTED', N'ARBITRATION'))
             BEGIN ;THROW 50001, N'لا يمكن رفع التحكيم للتذكرة في حالتها الحالية', 1; END
             IF EXISTS (SELECT 1 FROM [Tickets].[ArbitrationCase] WHERE [ticketID_FK] = @ticketID
                        AND [arbitrationStatus] = N'OPEN' AND [arbitrationCaseActive] = 1)
             BEGIN ;THROW 50001, N'يوجد طلب تحكيم مفتوح لهذه التذكرة بالفعل', 1; END
             DECLARE @statusArbID INT;
             SELECT @statusArbID = [ticketStatusID] FROM [Tickets].[TicketStatus]
             WHERE [ticketStatusCode] = N'ARBITRATION' AND [ticketStatusActive] = 1;

             IF @statusArbID IS NULL
             BEGIN ;THROW 50002, N'تعذر العثور على حالة ARBITRATION', 1; END

             INSERT INTO [Tickets].[ArbitrationCase]
             ( [ticketID_FK], [idaraID_FK], [raisedByUserID], [raisedFromDSDID_FK]
             , [arbitrationReasonID_FK], [arbitratorDistributorID]
             , [arbitrationStatus], [decisionType], [decisionNotes]
             , [arbitrationCaseActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @performerUserID, @abOldDSD
             , @arbitrationReasonID_FK, @arbitratorDistributorID
             , N'OPEN', NULL, @notes
             , 1, @entryData, @hostName );

             SET @NewID = SCOPE_IDENTITY();

             INSERT INTO [Tickets].[TicketPauseSession]
             ( [ticketID_FK], [idaraID_FK], [pauseReasonID_FK], [relatedArbitrationCaseID_FK]
             , [pauseStart], [pauseEnd], [slaPauseFlag], [pauseNotes], [pauseNotes_A]
             , [ticketPauseSessionActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, 2, @NewID
             , GETDATE(), NULL, 1, N'إيقاف تلقائي: تم التصعيد للتحكيم', N'إيقاف تلقائي: تم التصعيد للتحكيم'
             , 1, @entryData, @hostName );

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = @statusArbID
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @ticketID;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, N'ARBITRATION', @abOldStatus, @statusArbID
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم رفع التحكيم'), COALESCE(@notes_A, ISNULL(@notes, N'تم رفع التحكيم')), @entryData, @hostName );

             SET @Note = N'{"ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","arbitrationCaseID":"' + CAST(@NewID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ArbitrationCase]', N'RAISE_ARBITRATION', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم رفع حالة التحكيم بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- DECIDE_ARBITRATION
         ----------------------------------------------------------------
         ELSE IF @Action = N'DECIDE_ARBITRATION'
         BEGIN
             -- تعديل 10: فحص الإدارة في الإجراءات التي تعتمد على معرف غير معرف التذكرة.
             IF @idaraID_FK IS NULL
                 THROW 50001, N'معرف الإدارة مطلوب', 1;
             IF NOT EXISTS (
                 SELECT 1 FROM [Tickets].[ArbitrationCase] x
                 INNER JOIN [Tickets].[Ticket] t ON t.[ticketID] = x.[ticketID_FK]
                 WHERE x.[arbitrationCaseID] = @arbitrationCaseID
                   AND x.[idaraID_FK] = @idaraID_FK
                   AND t.[idaraID_FK] = @idaraID_FK
                   AND t.[ticketActive] = 1
             )
                 THROW 50001, N'السجل غير موجود أو لا يتبع الإدارة المحددة', 1;
             IF @arbitrationCaseID IS NULL
             BEGIN ;THROW 50001, N'معرف قضية التحكيم مطلوب', 1; END
             IF @decisionType IS NULL
             BEGIN ;THROW 50001, N'نوع القرار مطلوب', 1; END

             SET @decisionType = UPPER(LTRIM(RTRIM(@decisionType)));
             IF @decisionType NOT IN (N'UPHOLD', N'REDIRECT')
             BEGIN ;THROW 50001, N'نوع القرار غير صالح', 1; END
             IF @decisionType = N'REDIRECT' AND @decisionTargetDSDID_FK IS NULL
             BEGIN ;THROW 50001, N'يرجى اختيار الجهة المحوَّل إليها', 1; END
             IF @decisionType = N'UPHOLD' SET @decisionTargetDSDID_FK = NULL;
             DECLARE @daTicketID BIGINT, @daStatus NVARCHAR(50);
             SELECT @daTicketID = [ticketID_FK], @daStatus = [arbitrationStatus]
             FROM [Tickets].[ArbitrationCase]
             WHERE [arbitrationCaseID] = @arbitrationCaseID AND [arbitrationCaseActive] = 1;

             IF @daTicketID IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على قضية تحكيم نشطة', 1; END
             IF @daStatus <> N'OPEN'
             BEGIN ;THROW 50001, N'قضية التحكيم ليست في حالة OPEN', 1; END

             UPDATE [Tickets].[ArbitrationCase]
             SET [arbitrationStatus] = N'DECIDED'
               , [decisionType] = @decisionType
               , [decisionTargetDSDID_FK] = @decisionTargetDSDID_FK
               , [decisionNotes] = @decisionNotes
               , [decisionDate] = GETDATE()
               , [entryData] = @entryData
               , [hostName]  = @hostName -- تعديل 11: تصحيح تكرار اسم الجهاز الحالي مع نفسه
             WHERE [arbitrationCaseID] = @arbitrationCaseID;

             DECLARE @daOldStatus INT, @daOldDSD INT;
             SELECT @daOldStatus = [ticketStatusID_FK], @daOldDSD = [currentDSDID_FK]
             FROM [Tickets].[Ticket] WHERE [ticketID] = @daTicketID;

             DECLARE @daPrevStatus INT;
             SELECT TOP 1 @daPrevStatus = [oldStatusID_FK]
             FROM [Tickets].[TicketHistory]
             WHERE [ticketID_FK] = @daTicketID AND [actionTypeCode] IN (N'ARBITRATION', N'QUALITY_ESCALATED')
             ORDER BY [ticketHistoryID] DESC;

             IF @decisionType = N'REDIRECT' AND @decisionTargetDSDID_FK IS NOT NULL
             BEGIN
                 UPDATE [Tickets].[Ticket]
                 SET [currentDSDID_FK] = @decisionTargetDSDID_FK
                   , [ticketStatusID_FK] = (SELECT [ticketStatusID] FROM [Tickets].[TicketStatus] WHERE [ticketStatusCode] = N'ROUTED' AND [ticketStatusActive] = 1)
                   , [assignedUserID_FK] = NULL
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @daTicketID;

                 INSERT INTO [Tickets].[CatalogRoutingChangeLog]
                 ( [serviceID_FK], [idaraID_FK], [oldRoutingRuleID_FK], [newRoutingRuleID_FK]
                 , [changeReason], [sourceArbitrationCaseID_FK], [approvedByUserID]
                 , [effectiveFrom] )
                 SELECT t.[serviceID_FK], t.[idaraID_FK], NULL, NULL
                 , @decisionNotes, @arbitrationCaseID, @performerUserID
                 , GETDATE()
                 FROM [Tickets].[Ticket] t WHERE t.[ticketID] = @daTicketID;
             END
             ELSE
             BEGIN
                 UPDATE [Tickets].[Ticket]
                 SET [ticketStatusID_FK] = ISNULL(@daPrevStatus, @daOldStatus)
                   , [entryData] = @entryData
                   , [hostName]  = @hostName
                 WHERE [ticketID] = @daTicketID;
             END

             UPDATE [Tickets].[TicketPauseSession]
             SET [pauseEnd] = GETDATE(), [ticketPauseSessionActive] = 0
             WHERE [ticketID_FK] = @daTicketID AND [relatedArbitrationCaseID_FK] = @arbitrationCaseID
               AND [pauseEnd] IS NULL;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @daTicketID, @idaraID_FK, N'ARBITRATION_DECIDED', @daOldStatus, (SELECT [ticketStatusID_FK] FROM [Tickets].[Ticket] WHERE [ticketID] = @daTicketID)
             , @daOldDSD, @decisionTargetDSDID_FK, NULL, NULL
             , @performerUserID, ISNULL(@decisionNotes, N'تم اتخاذ قرار التحكيم'), COALESCE(@notes_A, ISNULL(@decisionNotes, N'تم اتخاذ قرار التحكيم')), @entryData, @hostName );

             SET @Note = N'{"arbitrationCaseID":"' + CAST(@arbitrationCaseID AS NVARCHAR(20))
                 + N'","decisionType":"' + ISNULL(@decisionType, N'') + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ArbitrationCase]', N'DECIDE_ARBITRATION', @arbitrationCaseID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم اتخاذ قرار التحكيم بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- CANCEL_ARBITRATION
         ----------------------------------------------------------------
         ELSE IF @Action = N'CANCEL_ARBITRATION'
         BEGIN
             -- تعديل 10: فحص الإدارة في الإجراءات التي تعتمد على معرف غير معرف التذكرة.
             IF @idaraID_FK IS NULL
                 THROW 50001, N'معرف الإدارة مطلوب', 1;
             IF NOT EXISTS (
                 SELECT 1 FROM [Tickets].[ArbitrationCase] x
                 INNER JOIN [Tickets].[Ticket] t ON t.[ticketID] = x.[ticketID_FK]
                 WHERE x.[arbitrationCaseID] = @arbitrationCaseID
                   AND x.[idaraID_FK] = @idaraID_FK
                   AND t.[idaraID_FK] = @idaraID_FK
                   AND t.[ticketActive] = 1
             )
                 THROW 50001, N'السجل غير موجود أو لا يتبع الإدارة المحددة', 1;
             IF @arbitrationCaseID IS NULL
             BEGIN ;THROW 50001, N'معرف قضية التحكيم مطلوب', 1; END

             DECLARE @caTicketID BIGINT;
             SELECT @caTicketID = [ticketID_FK]
             FROM [Tickets].[ArbitrationCase]
             WHERE [arbitrationCaseID] = @arbitrationCaseID AND [arbitrationStatus] = N'OPEN' AND [arbitrationCaseActive] = 1;

             IF @caTicketID IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على قضية تحكيم مفتوحة', 1; END

             UPDATE [Tickets].[ArbitrationCase]
             SET [arbitrationStatus] = N'CANCELLED'
               , [decisionNotes] = ISNULL(@decisionNotes, N'Cancelled')
               , [entryData] = @entryData
               , [hostName]  = @hostName -- تعديل 11: تصحيح تكرار اسم الجهاز الحالي مع نفسه
             WHERE [arbitrationCaseID] = @arbitrationCaseID;

             DECLARE @caOldStatus INT;
             SELECT @caOldStatus = [ticketStatusID_FK] FROM [Tickets].[Ticket] WHERE [ticketID] = @caTicketID;

             DECLARE @caPrevStatus INT;
             SELECT TOP 1 @caPrevStatus = [oldStatusID_FK]
             FROM [Tickets].[TicketHistory]
             WHERE [ticketID_FK] = @caTicketID AND [actionTypeCode] = N'ARBITRATION'
             ORDER BY [ticketHistoryID] DESC;

             UPDATE [Tickets].[Ticket]
             SET [ticketStatusID_FK] = ISNULL(@caPrevStatus, @caOldStatus)
               , [entryData] = @entryData
               , [hostName]  = @hostName
             WHERE [ticketID] = @caTicketID;

             UPDATE [Tickets].[TicketPauseSession]
             SET [pauseEnd] = GETDATE(), [ticketPauseSessionActive] = 0
             WHERE [ticketID_FK] = @caTicketID AND [relatedArbitrationCaseID_FK] = @arbitrationCaseID
               AND [pauseEnd] IS NULL;

             INSERT INTO [Tickets].[TicketHistory]
             ( [ticketID_FK], [idaraID_FK], [actionTypeCode], [oldStatusID_FK], [newStatusID_FK]
             , [oldDSDID_FK], [newDSDID_FK], [oldAssignedUserID], [newAssignedUserID]
             , [performerUserID], [notes], [notes_A], [entryData], [hostName] )
             VALUES
             ( @caTicketID, @idaraID_FK, N'ARBITRATION_CANCELLED', @caOldStatus, ISNULL(@caPrevStatus, @caOldStatus)
             , NULL, NULL, NULL, NULL
             , @performerUserID, ISNULL(@notes, N'تم إلغاء التحكيم'), COALESCE(@notes_A, ISNULL(@notes, N'تم إلغاء التحكيم')), @entryData, @hostName );

             SET @Note = N'{"arbitrationCaseID":"' + CAST(@arbitrationCaseID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ArbitrationCase]', N'CANCEL_ARBITRATION', @arbitrationCaseID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم إلغاء التحكيم' AS Message_;
         END

         ----------------------------------------------------------------
         -- UPLOAD_ATTACHMENT
         ----------------------------------------------------------------
         ELSE IF @Action = N'UPLOAD_ATTACHMENT'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف التذكرة مطلوب', 1; END
             IF NULLIF(LTRIM(RTRIM(@fileName)), N'') IS NULL
             BEGIN ;THROW 50001, N'اسم الملف مطلوب', 1; END
             IF NULLIF(LTRIM(RTRIM(@storedFileName)), N'') IS NULL
             BEGIN ;THROW 50001, N'اسم الملف المخزن مطلوب', 1; END
             IF NULLIF(LTRIM(RTRIM(@filePath)), N'') IS NULL
             BEGIN ;THROW 50001, N'مسار الملف مطلوب', 1; END

             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Ticket] WHERE [ticketID] = @ticketID AND [ticketActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على تذكرة نشطة', 1; END

             INSERT INTO [Tickets].[TicketAttachment]
             ( [ticketID_FK], [idaraID_FK], [fileName], [storedFileName], [filePath]
             , [fileSizeBytes], [contentType], [uploadedByUserID], [attachmentType]
             , [ticketAttachmentActive], [entryData], [hostName] )
             VALUES
             ( @ticketID, @idaraID_FK, @fileName, @storedFileName, @filePath
             , @fileSizeBytes, @contentType, @performerUserID, @attachmentType
             , 1, @entryData, @hostName );

             SET @NewID = SCOPE_IDENTITY();

             SET @Note = N'{"ticketAttachmentID":"' + CAST(@NewID AS NVARCHAR(20))
                 + N'","ticketID":"' + CAST(@ticketID AS NVARCHAR(20))
                 + N'","fileName":"' + ISNULL(@fileName, N'') + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[TicketAttachment]', N'UPLOAD_ATTACHMENT', @NewID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم رفع المرفق بنجاح' AS Message_;
         END

         ----------------------------------------------------------------
         -- DELETE_ATTACHMENT
         ----------------------------------------------------------------
         ELSE IF @Action = N'DELETE_ATTACHMENT'
         BEGIN
             IF @ticketID IS NULL
             BEGIN ;THROW 50001, N'معرف المرفق (الممرر كمعرف التذكرة) مطلوب', 1; END

             -- تعديل 09: التأكد من تبعية المرفق والتذكرة للإدارة قبل الحذف.
             IF @idaraID_FK IS NULL THROW 50001, N'معرف الإدارة مطلوب', 1;
             IF NOT EXISTS (SELECT 1 FROM [Tickets].[TicketAttachment] a
                            INNER JOIN [Tickets].[Ticket] t ON t.[ticketID] = a.[ticketID_FK]
                            WHERE a.[ticketAttachmentID] = @ticketID
                              AND a.[ticketAttachmentActive] = 1
                              AND a.[idaraID_FK] = @idaraID_FK
                              AND t.[idaraID_FK] = @idaraID_FK AND t.[ticketActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على مرفق نشط', 1; END

             UPDATE [Tickets].[TicketAttachment]
             SET [ticketAttachmentActive] = 0
               , [entryData] = @entryData
               , [hostName]  = @hostName -- تعديل 11: تصحيح تكرار اسم الجهاز الحالي مع نفسه
             WHERE [ticketAttachmentID] = @ticketID AND [idaraID_FK] = @idaraID_FK
               AND [ticketAttachmentActive] = 1; -- تعديل 09

             SET @Note = N'{"ticketAttachmentID":"' + CAST(@ticketID AS NVARCHAR(20)) + N'"}';
             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[TicketAttachment]', N'DELETE_ATTACHMENT', @ticketID, @entryData, @Note);

             SELECT 1 AS IsSuccessful, N'تم حذف المرفق' AS Message_;
         END

         ----------------------------------------------------------------
         -- Unknown Action
         ----------------------------------------------------------------
         ELSE
         BEGIN
             ;THROW 50001, N'نوع الإجراء غير معروف في TicketSP', 1;
         END

         IF @tc = 0 COMMIT TRAN;
     END TRY
     BEGIN CATCH
         IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
         ;THROW;
     END CATCH
 END
