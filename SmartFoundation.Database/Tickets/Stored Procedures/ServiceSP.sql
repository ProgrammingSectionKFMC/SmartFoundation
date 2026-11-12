 CREATE   PROCEDURE [Tickets].[ServiceSP]
 (
       @Action                      NVARCHAR(200)
     , @serviceID                   BIGINT          = NULL
     , @serviceCode                 NVARCHAR(100)   = NULL
     , @serviceName_A               NVARCHAR(500)   = NULL
     , @serviceName_E               NVARCHAR(500)   = NULL
     , @serviceDesc                 NVARCHAR(2000)  = NULL
     , @idaraID_FK                  INT             = NULL
     , @ticketClassID_FK            INT             = NULL
     , @defaultPriorityID_FK        INT             = NULL
     , @requiresLocation            BIT             = NULL
     , @allowsChildTickets          BIT             = NULL
     , @requiresQualityReview       BIT             = NULL
     , @targetDSDID_FK              INT             = NULL
     , @queueDistributorID_FK       INT             = NULL
     , @changeReason                NVARCHAR(1000)  = NULL
     , @approvedByUserID            INT             = NULL
     , @serviceSLAPolicyID          BIGINT          = NULL
     , @priorityID_FK               INT             = NULL
     , @firstResponseTargetMinutes  INT             = NULL
     , @assignmentTargetMinutes     INT             = NULL
     , @operationalCompletionTargetMinutes INT       = NULL
     , @finalClosureTargetMinutes   INT             = NULL
     , @serviceCatalogSuggestionID  BIGINT          = NULL
     , @proposedServiceName_A       NVARCHAR(500)   = NULL
     , @proposedServiceName_E       NVARCHAR(500)   = NULL
     , @proposedServiceDesc_A       NVARCHAR(2000)  = NULL
     , @proposedServiceDesc         NVARCHAR(2000)  = NULL
     , @proposedTargetDSDID_FK      INT             = NULL
     , @proposedPriorityID_FK       INT             = NULL
     , @approvalNotes_A             NVARCHAR(2000)  = NULL
     , @approvalNotes               NVARCHAR(2000)  = NULL
     , @effectiveFrom               DATETIME        = NULL
     , @entryData                   NVARCHAR (20)   = NULL
     , @hostName                    NVARCHAR (200)  = NULL
     -- تعديل 02: باراميتر مستقل اختياري، أضيف في النهاية لعدم كسر الاستدعاءات الموضعية الحالية
     , @serviceRoutingRuleID        BIGINT = NULL
 )
 AS
 BEGIN
     SET NOCOUNT ON;
     SET XACT_ABORT ON;

     DECLARE @tc INT = @@TRANCOUNT;
     DECLARE @NewID BIGINT = NULL;
     DECLARE @Note NVARCHAR(MAX) = NULL;

     BEGIN TRY
         -- تعديل 03: تفتح المعاملة إذا لم توجد معاملة خارجية؛ الإغلاق عند كل نجاح أدناه
         IF @tc = 0 BEGIN TRAN;

         -- Service code is generated automatically (SRV-00042) when the form leaves it empty.
         SET @serviceCode = NULLIF(LTRIM(RTRIM(@serviceCode)), N'');
         DECLARE @AutoServiceCode BIT = CASE WHEN @serviceCode IS NULL THEN 1 ELSE 0 END;

         IF NULLIF(LTRIM(RTRIM(@Action)), N'') IS NULL
         BEGIN ;THROW 50001, N'نوع الإجراء مطلوب', 1; END

         ----------------------------------------------------------------
         -- INSERT_SERVICE
         ----------------------------------------------------------------
         IF @Action = N'INSERT_SERVICE'
         BEGIN
             IF NULLIF(LTRIM(RTRIM(@serviceName_A)), N'') IS NULL
             BEGIN ;THROW 50001, N'اسم الخدمة بالعربية مطلوب', 1; END

             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END

             IF EXISTS (
                 -- تعديل 05: حماية فحص التكرار أثناء المعاملة (يوصى بقيد فريد مناسب)
                 SELECT 1 FROM [Tickets].[Service] WITH (UPDLOCK, HOLDLOCK)
                 WHERE [serviceName_A] = @serviceName_A
                   AND [serviceActive] = 1
                   AND [idaraID_FK] = @idaraID_FK
             )
             BEGIN ;THROW 50001, N'توجد خدمة بنفس الاسم العربي لهذه الإدارة مسبقاً', 1; END

             INSERT INTO [Tickets].[Service]
             (
                   [serviceCode], [serviceName_A], [serviceName_E], [serviceDesc]
                 , [idaraID_FK], [ticketClassID_FK], [defaultPriorityID_FK]
                 , [requiresLocation], [allowsChildTickets], [requiresQualityReview]
                 , [serviceActive], [entryData], [hostName]
             )
             VALUES
             (
                   ISNULL(@serviceCode, N'SRV-NEW'), @serviceName_A, @serviceName_E, @serviceDesc
                 , @idaraID_FK, @ticketClassID_FK, @defaultPriorityID_FK
                 , ISNULL(@requiresLocation, 0), ISNULL(@allowsChildTickets, 0), ISNULL(@requiresQualityReview, 0)
                 , 1, @entryData, @hostName
             );

             SET @NewID = SCOPE_IDENTITY();
             IF @NewID IS NULL OR @NewID <= 0
             BEGIN ;THROW 50002, N'فشل إنشاء الخدمة بسبب خطأ في توليد المعرف', 1; END

             IF @AutoServiceCode = 1
             BEGIN
                 SET @serviceCode = N'SRV-' + RIGHT(N'00000' + CAST(@NewID AS NVARCHAR(20)), CASE WHEN @NewID > 99999 THEN LEN(CAST(@NewID AS NVARCHAR(20))) ELSE 5 END);
                 UPDATE [Tickets].[Service] SET [serviceCode] = @serviceCode WHERE [serviceID] = @NewID;
             END

             SET @Note = N'{"serviceID":"' + CAST(@NewID AS NVARCHAR(20))
                 + N'","serviceCode":"' + STRING_ESCAPE(ISNULL(@serviceCode, N''), 'json')
                 + N'","serviceName_A":"' + STRING_ESCAPE(ISNULL(@serviceName_A, N''), 'json') + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Service]', N'INSERT_SERVICE', @NewID, @entryData, @Note);

             -- Responsible unit (department / branch / section) becomes the service's active routing rule.
             IF @targetDSDID_FK IS NOT NULL
             BEGIN
                 IF NOT EXISTS (SELECT 1 FROM dbo.DeptSecDiv WHERE [DSDID] = @targetDSDID_FK AND [idaraID_FK] = @idaraID_FK)
                 BEGIN ;THROW 50001, N'الجهة المختارة غير موجودة أو لا تتبع الإدارة', 1; END
                 INSERT INTO [Tickets].[ServiceRoutingRule]
                 ( [serviceID_FK], [idaraID_FK], [targetDSDID_FK], [effectiveFrom]
                 , [changeReason], [changeReason_A], [approvedByUserID]
                 , [serviceRoutingRuleActive], [entryData], [hostName] )
                 VALUES
                 ( @NewID, @idaraID_FK, @targetDSDID_FK, GETDATE()
                 , N'Responsible unit set when the service was added', N'تحديد الجهة المسؤولة عند إضافة الخدمة', TRY_CAST(@entryData AS INT)
                 , 1, @entryData, @hostName );
             END

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم إنشاء الخدمة بنجاح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- UPDATE_SERVICE
         ----------------------------------------------------------------
         ELSE IF @Action = N'UPDATE_SERVICE'
         BEGIN
             IF @serviceID IS NULL OR @serviceID <= 0
             BEGIN ;THROW 50001, N'معرف الخدمة مطلوب للتحديث', 1; END

             -- تعديل 04: عمليات الكتابة مقيدة بإدارة المستخدم، ويجب التحقق من صلاحياته في طبقة الاستدعاء
             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END

             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE [serviceID] = @serviceID AND [idaraID_FK] = @idaraID_FK AND [serviceActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على الخدمة أو أنها غير نشطة', 1; END

             -- تعديل 05: منع تكرار اسم الخدمة عند التعديل (مع استثناء السجل الحالي)
             IF NULLIF(LTRIM(RTRIM(@serviceName_A)), N'') IS NOT NULL
                AND EXISTS (SELECT 1 FROM [Tickets].[Service] WITH (UPDLOCK, HOLDLOCK)
                            WHERE serviceName_A = @serviceName_A AND idaraID_FK = @idaraID_FK
                              AND serviceActive = 1 AND serviceID <> @serviceID)
             BEGIN ;THROW 50001, N'توجد خدمة أخرى بنفس الاسم لهذه الإدارة', 1; END

             UPDATE [Tickets].[Service]
             SET
                   [serviceCode]           = ISNULL(@serviceCode, [serviceCode])
                 , [serviceName_A]         = ISNULL(@serviceName_A, [serviceName_A])
                 , [serviceName_E]         = ISNULL(@serviceName_E, [serviceName_E])
                 , [serviceDesc]           = ISNULL(@serviceDesc, [serviceDesc])
                 , [ticketClassID_FK]      = ISNULL(@ticketClassID_FK, [ticketClassID_FK])
                 , [defaultPriorityID_FK]  = ISNULL(@defaultPriorityID_FK, [defaultPriorityID_FK])
                 , [requiresLocation]      = ISNULL(@requiresLocation, [requiresLocation])
                 , [allowsChildTickets]    = ISNULL(@allowsChildTickets, [allowsChildTickets])
                 , [requiresQualityReview] = ISNULL(@requiresQualityReview, [requiresQualityReview])
                 , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
                 , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
             -- تعديل 04: عدم تحديث خدمة خارج الإدارة أو معطلة
             WHERE [serviceID] = @serviceID AND [idaraID_FK] = @idaraID_FK AND [serviceActive] = 1;

             IF @@ROWCOUNT = 0
             BEGIN ;THROW 50002, N'لم يتم تحديث أي صفوف', 1; END

             SET @Note = N'{"serviceID":"' + CAST(@serviceID AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Service]', N'UPDATE_SERVICE', @serviceID, @entryData, @Note);

             -- Responsible unit changed in the form: close the current routing rule and start a new one.
             IF @targetDSDID_FK IS NOT NULL
             BEGIN
                 IF NOT EXISTS (SELECT 1 FROM dbo.DeptSecDiv WHERE [DSDID] = @targetDSDID_FK AND [idaraID_FK] = @idaraID_FK)
                 BEGIN ;THROW 50001, N'الجهة المختارة غير موجودة أو لا تتبع الإدارة', 1; END
                 IF NOT EXISTS (
                     SELECT 1 FROM [Tickets].[ServiceRoutingRule] WITH (UPDLOCK, HOLDLOCK)
                     WHERE [serviceID_FK] = @serviceID AND [idaraID_FK] = @idaraID_FK
                       AND [serviceRoutingRuleActive] = 1
                       AND ([effectiveTo] IS NULL OR [effectiveTo] > GETDATE())
                       AND [targetDSDID_FK] = @targetDSDID_FK
                 )
                 BEGIN
                     UPDATE [Tickets].[ServiceRoutingRule]
                     SET [effectiveTo] = GETDATE()
                       , [serviceRoutingRuleActive] = 0
                       , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
                       , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
                     WHERE [serviceID_FK] = @serviceID AND [idaraID_FK] = @idaraID_FK AND [serviceRoutingRuleActive] = 1;

                     INSERT INTO [Tickets].[ServiceRoutingRule]
                     ( [serviceID_FK], [idaraID_FK], [targetDSDID_FK], [effectiveFrom]
                     , [changeReason], [changeReason_A], [approvedByUserID]
                     , [serviceRoutingRuleActive], [entryData], [hostName] )
                     VALUES
                     ( @serviceID, @idaraID_FK, @targetDSDID_FK, GETDATE()
                     , N'Responsible unit changed from the service form', N'تغيير الجهة المسؤولة من تعديل الخدمة', TRY_CAST(@entryData AS INT)
                     , 1, @entryData, @hostName );

                     SET @NewID = SCOPE_IDENTITY();
                     SET @Note = N'{"serviceRoutingRuleID":"' + CAST(@NewID AS NVARCHAR(20))
                         + N'","serviceID":"' + CAST(@serviceID AS NVARCHAR(20))
                         + N'","targetDSDID_FK":"' + CAST(@targetDSDID_FK AS NVARCHAR(20)) + N'"}';
                     INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                     VALUES (N'[Tickets].[ServiceRoutingRule]', N'INSERT_ROUTING_RULE', @NewID, @entryData, @Note);
                 END
             END

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم تحديث الخدمة بنجاح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- DELETE_SERVICE (soft delete)
         ----------------------------------------------------------------
         ELSE IF @Action = N'DELETE_SERVICE'
         BEGIN
             IF @serviceID IS NULL OR @serviceID <= 0
             BEGIN ;THROW 50001, N'معرف الخدمة مطلوب للحذف', 1; END
             -- تعديل 04: قيد الإدارة مطلوب عند التعطيل
             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END

             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE [serviceID] = @serviceID AND [idaraID_FK] = @idaraID_FK AND [serviceActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على الخدمة أو أنها غير نشطة مسبقاً', 1; END

             UPDATE [Tickets].[Service]
             SET [serviceActive] = 0
               , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
               , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
             -- تعديل 04: عدم تحديث خدمة خارج الإدارة أو معطلة
             WHERE [serviceID] = @serviceID AND [idaraID_FK] = @idaraID_FK AND [serviceActive] = 1;

             IF @@ROWCOUNT = 0
             BEGIN ;THROW 50002, N'لم يتم حذف أي صفوف', 1; END

             SET @Note = N'{"serviceID":"' + CAST(@serviceID AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[Service]', N'DELETE_SERVICE', @serviceID, @entryData, @Note);

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم تعطيل الخدمة بنجاح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- INSERT_ROUTING_RULE
         ----------------------------------------------------------------
         ELSE IF @Action = N'INSERT_ROUTING_RULE'
         BEGIN
             IF @serviceID IS NULL
             BEGIN ;THROW 50001, N'معرف الخدمة مطلوب لقاعدة التوجيه', 1; END

             IF @targetDSDID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الجهة المستهدفة مطلوب لقاعدة التوجيه', 1; END

             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب لقاعدة التوجيه', 1; END

             -- تعديل 06: التحقق من أن الخدمة نشطة ومسموحة للإدارة (أو عامة)
             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE [serviceID] = @serviceID AND [serviceActive] = 1
                 AND ([idaraID_FK] = @idaraID_FK OR [idaraID_FK] IS NULL))
             BEGIN ;THROW 50001, N'لم يتم العثور على خدمة نشطة متاحة للإدارة', 1; END

             DECLARE @EffFrom DATETIME = ISNULL(@effectiveFrom, GETDATE());
             -- تعديل 07: منع قاعدتين نشطتين لنفس الخدمة والإدارة في وقت سريان متداخل.
             -- الافتراض: كل خدمة/إدارة لها وجهة نشطة واحدة فقط؛ إذا تعددت الوجهات ينبغي تعديل القاعدة.
             IF EXISTS (
                 SELECT 1 FROM [Tickets].[ServiceRoutingRule] WITH (UPDLOCK, HOLDLOCK)
                 WHERE [serviceID_FK] = @serviceID AND [idaraID_FK] = @idaraID_FK
                   AND [serviceRoutingRuleActive] = 1
                   AND ([effectiveTo] IS NULL OR [effectiveTo] > @EffFrom)
             )
             BEGIN ;THROW 50001, N'توجد قاعدة توجيه نشطة متداخلة لهذه الخدمة والإدارة', 1; END

             INSERT INTO [Tickets].[ServiceRoutingRule]
             (
                   [serviceID_FK], [idaraID_FK], [targetDSDID_FK], [queueDistributorID_FK]
                 , [effectiveFrom], [changeReason], [approvedByUserID]
                 , [serviceRoutingRuleActive], [entryData], [hostName]
             )
             VALUES
             (
                   @serviceID, @idaraID_FK, @targetDSDID_FK, @queueDistributorID_FK
                 , @EffFrom, @changeReason, @approvedByUserID
                 , 1, @entryData, @hostName
             );

             SET @NewID = SCOPE_IDENTITY();
             IF @NewID IS NULL OR @NewID <= 0
             BEGIN ;THROW 50002, N'فشل إنشاء قاعدة التوجيه', 1; END

             SET @Note = N'{"serviceRoutingRuleID":"' + CAST(@NewID AS NVARCHAR(20))
                 + N'","serviceID":"' + CAST(@serviceID AS NVARCHAR(20))
                 + N'","targetDSDID_FK":"' + CAST(@targetDSDID_FK AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ServiceRoutingRule]', N'INSERT_ROUTING_RULE', @NewID, @entryData, @Note);

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم إنشاء قاعدة التوجيه بنجاح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- CLOSE_ROUTING_RULE
         ----------------------------------------------------------------
         ELSE IF @Action = N'CLOSE_ROUTING_RULE'
         BEGIN
             -- تعديل 02: استخدام المعرف الجديد عند تمريره، مع دعم الاستدعاء القديم مؤقتًا.
             DECLARE @RuleID BIGINT = COALESCE(@serviceRoutingRuleID, @serviceID);

             IF @RuleID IS NULL
             BEGIN ;THROW 50001, N'معرف قاعدة توجيه الخدمة (الممرر كـ @serviceID) مطلوب', 1; END

             -- تعديل 08: قيد الإدارة أثناء التحقق من قاعدة التوجيه
             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب', 1; END
             IF NOT EXISTS (SELECT 1 FROM [Tickets].[ServiceRoutingRule] WHERE [serviceRoutingRuleID] = @RuleID AND [idaraID_FK] = @idaraID_FK AND [serviceRoutingRuleActive] = 1)
             BEGIN ;THROW 50001, N'لم يتم العثور على قاعدة توجيه نشطة', 1; END

             UPDATE [Tickets].[ServiceRoutingRule]
             SET [effectiveTo] = GETDATE()
               , [serviceRoutingRuleActive] = 0
               , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
               , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
             -- تعديل 08: منع إغلاق قاعدة تابعة لإدارة أخرى
             WHERE [serviceRoutingRuleID] = @RuleID AND [idaraID_FK] = @idaraID_FK AND [serviceRoutingRuleActive] = 1;

             IF @@ROWCOUNT = 0
             BEGIN ;THROW 50002, N'لم يتم إغلاق أي قاعدة توجيه', 1; END

             SET @Note = N'{"serviceRoutingRuleID":"' + CAST(@RuleID AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ServiceRoutingRule]', N'CLOSE_ROUTING_RULE', @RuleID, @entryData, @Note);

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم إغلاق قاعدة التوجيه بنجاح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- UPSERT_SLA_POLICY
         ----------------------------------------------------------------
         ELSE IF @Action = N'UPSERT_SLA_POLICY'
         BEGIN
             IF @serviceID IS NULL
             BEGIN ;THROW 50001, N'معرف الخدمة مطلوب لسياسة SLA', 1; END

             IF @priorityID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الأولوية مطلوب لسياسة SLA', 1; END

             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب لسياسة SLA', 1; END

             -- تعديل 09: التأكد من الخدمة والأولوية قبل تسجيل SLA
             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Service] WHERE serviceID = @serviceID
                            AND serviceActive = 1 AND (idaraID_FK = @idaraID_FK OR idaraID_FK IS NULL))
             BEGIN ;THROW 50001, N'الخدمة غير نشطة أو غير متاحة للإدارة', 1; END
             IF NOT EXISTS (SELECT 1 FROM [Tickets].[Priority] WHERE priorityID = @priorityID_FK AND priorityActive = 1)
             BEGIN ;THROW 50001, N'الأولوية غير نشطة أو غير موجودة', 1; END
             IF @firstResponseTargetMinutes < 0 OR @assignmentTargetMinutes < 0
                OR @operationalCompletionTargetMinutes < 0 OR @finalClosureTargetMinutes < 0
             BEGIN ;THROW 50001, N'مدد SLA لا يمكن أن تكون سالبة', 1; END

             IF EXISTS (
                 SELECT 1 FROM [Tickets].[ServiceSLAPolicy] WITH (UPDLOCK, HOLDLOCK)
                 WHERE [serviceID_FK] = @serviceID
                   AND [priorityID_FK] = @priorityID_FK
                   AND [idaraID_FK] = @idaraID_FK
                   AND [slaPolicyActive] = 1
             )
             BEGIN
                 UPDATE [Tickets].[ServiceSLAPolicy]
                 SET
                       [firstResponseTargetMinutes]         = ISNULL(@firstResponseTargetMinutes, [firstResponseTargetMinutes])
                     , [assignmentTargetMinutes]            = ISNULL(@assignmentTargetMinutes, [assignmentTargetMinutes])
                     , [operationalCompletionTargetMinutes] = ISNULL(@operationalCompletionTargetMinutes, [operationalCompletionTargetMinutes])
                     , [finalClosureTargetMinutes]          = ISNULL(@finalClosureTargetMinutes, [finalClosureTargetMinutes])
                     , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
                     , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
                 WHERE [serviceID_FK] = @serviceID
                   AND [priorityID_FK] = @priorityID_FK
                   AND [idaraID_FK] = @idaraID_FK
                   AND [slaPolicyActive] = 1;

                 -- تعديل 10: سجل التدقيق يشير إلى معرف السياسة الفعلي، لا معرف الخدمة
                 SELECT TOP (1) @serviceSLAPolicyID = serviceSLAPolicyID
                 FROM [Tickets].[ServiceSLAPolicy]
                 WHERE serviceID_FK = @serviceID AND priorityID_FK = @priorityID_FK
                   AND idaraID_FK = @idaraID_FK AND slaPolicyActive = 1
                 ORDER BY serviceSLAPolicyID DESC;
                 SET @Note = N'{"action":"UPDATED","serviceID":"' + CAST(@serviceID AS NVARCHAR(20))
                     + N'","priorityID_FK":"' + CAST(@priorityID_FK AS NVARCHAR(20)) + N'"}';

                 INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                 VALUES (N'[Tickets].[ServiceSLAPolicy]', N'UPSERT_SLA_POLICY', @serviceSLAPolicyID, @entryData, @Note);

                 -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

                 IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

                 SELECT 1 AS IsSuccessful, N'تم تحديث سياسة SLA بنجاح' AS Message_;
                 RETURN;
             END
             ELSE
             BEGIN
                 INSERT INTO [Tickets].[ServiceSLAPolicy]
                 (
                       [idaraID_FK], [serviceID_FK], [priorityID_FK]
                     , [firstResponseTargetMinutes], [assignmentTargetMinutes]
                     , [operationalCompletionTargetMinutes], [finalClosureTargetMinutes]
                     , [effectiveFrom], [slaPolicyActive], [entryData], [hostName]
                 )
                 VALUES
                 (
                       @idaraID_FK, @serviceID, @priorityID_FK
                     , @firstResponseTargetMinutes, @assignmentTargetMinutes
                     , @operationalCompletionTargetMinutes, @finalClosureTargetMinutes
                     , GETDATE(), 1, @entryData, @hostName
                 );

                 SET @NewID = SCOPE_IDENTITY();
                 -- تعديل 10: التحقق من أن الإدخال أنتج معرفًا صحيحًا
                 IF @NewID IS NULL OR @NewID <= 0
                 BEGIN ;THROW 50002, N'فشل إنشاء سياسة SLA', 1; END

                 SET @Note = N'{"action":"INSERTED","serviceSLAPolicyID":"' + ISNULL(CAST(@NewID AS NVARCHAR(20)), N'')
                     + N'","serviceID":"' + CAST(@serviceID AS NVARCHAR(20))
                     + N'","priorityID_FK":"' + CAST(@priorityID_FK AS NVARCHAR(20)) + N'"}';

                 INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
                 VALUES (N'[Tickets].[ServiceSLAPolicy]', N'UPSERT_SLA_POLICY', @NewID, @entryData, @Note);

                 -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

                 IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

                 SELECT 1 AS IsSuccessful, N'تم إنشاء سياسة SLA بنجاح' AS Message_;
                 RETURN;
             END
         END

         ----------------------------------------------------------------
         -- APPROVE_SERVICE_SUGGESTION
         ----------------------------------------------------------------
         ELSE IF @Action = N'APPROVE_SERVICE_SUGGESTION'
         BEGIN
             IF @serviceCatalogSuggestionID IS NULL OR @serviceCatalogSuggestionID <= 0
             BEGIN ;THROW 50001, N'معرف اقتراح دليل الخدمة مطلوب', 1; END
             -- تعديل 11: حصر الاعتماد بإدارة المستدعي
             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب لاعتماد الاقتراح', 1; END

             DECLARE @SugID BIGINT = @serviceCatalogSuggestionID;
             DECLARE @SugIdaraID INT;
             DECLARE @SugName_A NVARCHAR(500);
             DECLARE @SugName_E NVARCHAR(500);
             DECLARE @SugDesc NVARCHAR(2000);
             DECLARE @SugDSDID INT;
             DECLARE @SugPriorityID INT;

             SELECT
                   @SugIdaraID  = [idaraID_FK]
                 , @SugName_A   = [proposedServiceName_A]
                 , @SugName_E   = [proposedServiceName_E]
                                 , @SugDesc     = COALESCE([proposedServiceDesc_A], [proposedServiceDesc])
                 , @SugDSDID    = [proposedTargetDSDID_FK]
                 , @SugPriorityID = [proposedPriorityID_FK]
             -- تعديل 11: قفل السجل ومنع اعتماده مرتين مع التحقق من الإدارة والنشاط
             FROM [Tickets].[ServiceCatalogSuggestion] WITH (UPDLOCK, HOLDLOCK)
             WHERE [serviceCatalogSuggestionID] = @SugID
               AND [idaraID_FK] = @idaraID_FK
               AND [suggestionActive] = 1
               AND [approvalStatus] = N'PENDING';

             IF @SugName_A IS NULL
             BEGIN ;THROW 50001, N'لم يتم العثور على اقتراح نشط قيد الانتظار لهذه الإدارة', 1; END
             -- تعديل 11: منع إنشاء خدمة مكررة عند الاعتماد
             IF EXISTS (SELECT 1 FROM [Tickets].[Service] WITH (UPDLOCK, HOLDLOCK)
                        WHERE [serviceName_A] = @SugName_A AND [idaraID_FK] = @SugIdaraID
                          AND [serviceActive] = 1)
             BEGIN ;THROW 50001, N'توجد خدمة نشطة بنفس اسم الاقتراح', 1; END

             INSERT INTO [Tickets].[Service]
             (
                   [serviceCode], [serviceName_A], [serviceName_E], [serviceDesc]
                 , [idaraID_FK], [defaultPriorityID_FK]
                 , [requiresLocation], [allowsChildTickets], [requiresQualityReview]
                 , [serviceActive], [entryData], [hostName]
             )
             VALUES
             (
                   N'SRV-NEW'
                 , @SugName_A, @SugName_E, @SugDesc
                 , @SugIdaraID, @SugPriorityID
                 , 1, 0, 1
                 , 1, @entryData, @hostName
             );

             SET @NewID = SCOPE_IDENTITY();
             -- تعديل 11: التأكد من إنشاء الخدمة قبل اعتماد الاقتراح
             IF @NewID IS NULL OR @NewID <= 0
             BEGIN ;THROW 50002, N'فشل إنشاء الخدمة من الاقتراح', 1; END

             -- Same automatic code as services added from the form (SRV-00042).
             UPDATE [Tickets].[Service]
             SET [serviceCode] = N'SRV-' + RIGHT(N'00000' + CAST(@NewID AS NVARCHAR(20)), CASE WHEN @NewID > 99999 THEN LEN(CAST(@NewID AS NVARCHAR(20))) ELSE 5 END)
             WHERE [serviceID] = @NewID;

             UPDATE [Tickets].[ServiceCatalogSuggestion]
             SET
                   [approvalStatus]    = N'APPROVED'
                 , [approvedByUserID]  = @approvedByUserID
                 , [approvalDate]      = GETDATE()
                                 , [approvalNotes_A]   = ISNULL(@approvalNotes_A, @approvalNotes)
                                 , [approvalNotes]     = ISNULL(@approvalNotes, @approvalNotes_A)
                 , [createdServiceID_FK] = @NewID
                 , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
                 , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
             WHERE [serviceCatalogSuggestionID] = @SugID
               AND [idaraID_FK] = @idaraID_FK AND [approvalStatus] = N'PENDING'
               AND [suggestionActive] = 1;
             -- تعديل 11: نجاح تحديث اقتراح واحد فقط
             IF @@ROWCOUNT <> 1
             BEGIN ;THROW 50002, N'فشل اعتماد الاقتراح أو تغيرت حالته', 1; END

             IF @SugDSDID IS NOT NULL
             BEGIN
                 INSERT INTO [Tickets].[ServiceRoutingRule]
                 (
                       [serviceID_FK], [idaraID_FK], [targetDSDID_FK]
                     , [effectiveFrom], [changeReason], [approvedByUserID]
                     , [serviceRoutingRuleActive], [entryData], [hostName]
                 )
                 VALUES
                 (
                       @NewID, @SugIdaraID, @SugDSDID
                     , GETDATE(), N'تم الإنشاء تلقائياً من اقتراح معتمد رقم ' + CAST(@SugID AS NVARCHAR(20))
                     , @approvedByUserID
                     , 1, @entryData, @hostName
                 );
             END

             SET @Note = N'{"suggestionID":"' + CAST(@SugID AS NVARCHAR(20))
                 + N'","createdServiceID":"' + CAST(@NewID AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ServiceCatalogSuggestion]', N'APPROVE_SERVICE_SUGGESTION', @SugID, @entryData, @Note);

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تمت الموافقة على الاقتراح وإنشاء الخدمة' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- REJECT_SERVICE_SUGGESTION
         ----------------------------------------------------------------
         ELSE IF @Action = N'REJECT_SERVICE_SUGGESTION'
         BEGIN
             IF @serviceCatalogSuggestionID IS NULL OR @serviceCatalogSuggestionID <= 0
             BEGIN ;THROW 50001, N'معرف اقتراح دليل الخدمة مطلوب', 1; END
             -- تعديل 12: حصر رفض الاقتراح بإدارة المستدعي
             IF @idaraID_FK IS NULL
             BEGIN ;THROW 50001, N'معرف الإدارة مطلوب لرفض الاقتراح', 1; END

             SET @SugID = @serviceCatalogSuggestionID;

             IF NOT EXISTS (
                 SELECT 1 FROM [Tickets].[ServiceCatalogSuggestion] WITH (UPDLOCK, HOLDLOCK)
                 WHERE [serviceCatalogSuggestionID] = @SugID
                   AND [idaraID_FK] = @idaraID_FK AND [suggestionActive] = 1
                   AND [approvalStatus] = N'PENDING'
             )
             BEGIN ;THROW 50001, N'لم يتم العثور على الاقتراح أو أنه ليس في حالة PENDING', 1; END

             UPDATE [Tickets].[ServiceCatalogSuggestion]
             SET
                   [approvalStatus]   = N'REJECTED'
                 , [approvedByUserID] = @approvedByUserID
                 , [approvalDate]     = GETDATE()
                                 , [approvalNotes_A]  = ISNULL(@approvalNotes_A, @approvalNotes)
                                 , [approvalNotes]    = ISNULL(@approvalNotes, @approvalNotes_A)
                 , [suggestionActive] = 0
                 , [entryData] = ISNULL(ISNULL([entryData],N'') + N',' + @entryData, [entryData])
                 , [hostName]  = ISNULL(ISNULL(@hostName,N'') + N',' + [hostName], [hostName])
             -- تعديل 12: رفض الاقتراح النشط داخل الإدارة فقط
             WHERE [serviceCatalogSuggestionID] = @SugID AND [idaraID_FK] = @idaraID_FK
               AND [approvalStatus] = N'PENDING' AND [suggestionActive] = 1;

             IF @@ROWCOUNT = 0
             BEGIN ;THROW 50002, N'لم يتم تحديث أي اقتراح', 1; END

             SET @Note = N'{"suggestionID":"' + CAST(@SugID AS NVARCHAR(20)) + N'"}';

             INSERT INTO dbo.AuditLog (TableName, ActionType, RecordID, PerformedBy, Notes)
             VALUES (N'[Tickets].[ServiceCatalogSuggestion]', N'REJECT_SERVICE_SUGGESTION', @SugID, @entryData, @Note);

             -- تعديل 03: تأكيد المعاملة قبل إرجاع النجاح

             IF @tc = 0 AND XACT_STATE() = 1 COMMIT TRAN;

             SELECT 1 AS IsSuccessful, N'تم رفض الاقتراح' AS Message_;
             RETURN;
         END

         ----------------------------------------------------------------
         -- Unknown Action
         ----------------------------------------------------------------
         ELSE
         BEGIN
             ;THROW 50001, N'نوع الإجراء غير معروف في ServiceSP', 1;
         END

     END TRY
     BEGIN CATCH
         IF @tc = 0 AND XACT_STATE() <> 0 ROLLBACK;
         ;THROW;
     END CATCH
 END

GO

