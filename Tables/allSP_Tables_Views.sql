-- ============================================================================
-- SMART FOUNDATION TICKETING SYSTEM - COMPLETE MSSQL DATABASE SCHEMA
-- Generated from plan.md | Schema: [Tickets]
-- Date: 2026-04-01
-- ============================================================================

-- ============================================================================
-- STEP 0: CREATE SCHEMA
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Tickets')
BEGIN
    EXEC('CREATE SCHEMA [Tickets]');
END
GO

-- ============================================================================
-- STEP 1: LOOKUP TABLES (INT keys, soft delete where needed)
-- ============================================================================

-- 1.1 TicketStatus
CREATE TABLE [Tickets].[TicketStatus] (
    [TicketStatusID]    INT IDENTITY(1,1) NOT NULL,
    [StatusCode]        NVARCHAR(50)      NOT NULL,
    [StatusNameAR]      NVARCHAR(200)     NULL,
    [StatusNameEN]      NVARCHAR(200)     NULL,
    [SortOrder]         INT               NULL DEFAULT 0,
    [IsActive]          BIT               NOT NULL DEFAULT 1,
    [CreatedBy]         BIGINT            NULL,
    [CreatedDate]       DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]        BIGINT            NULL,
    [ModifiedDate]      DATETIME2(7)      NULL,
    CONSTRAINT [PK_TicketStatus] PRIMARY KEY CLUSTERED ([TicketStatusID]),
    CONSTRAINT [UQ_TicketStatus_Code] UNIQUE ([StatusCode])
);
GO

-- 1.2 TicketClass
CREATE TABLE [Tickets].[TicketClass] (
    [TicketClassID]     INT IDENTITY(1,1) NOT NULL,
    [ClassCode]         NVARCHAR(50)      NOT NULL,
    [ClassNameAR]       NVARCHAR(200)     NULL,
    [ClassNameEN]       NVARCHAR(200)     NULL,
    [SortOrder]         INT               NULL DEFAULT 0,
    [IsActive]          BIT               NOT NULL DEFAULT 1,
    [CreatedBy]         BIGINT            NULL,
    [CreatedDate]       DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]        BIGINT            NULL,
    [ModifiedDate]      DATETIME2(7)      NULL,
    CONSTRAINT [PK_TicketClass] PRIMARY KEY CLUSTERED ([TicketClassID]),
    CONSTRAINT [UQ_TicketClass_Code] UNIQUE ([ClassCode])
);
GO

-- 1.3 Priority
CREATE TABLE [Tickets].[Priority] (
    [PriorityID]        INT IDENTITY(1,1) NOT NULL,
    [PriorityCode]      NVARCHAR(50)      NOT NULL,
    [PriorityNameAR]    NVARCHAR(200)     NULL,
    [PriorityNameEN]    NVARCHAR(200)     NULL,
    [SortOrder]         INT               NULL DEFAULT 0,
    [IsActive]          BIT               NOT NULL DEFAULT 1,
    [CreatedBy]         BIGINT            NULL,
    [CreatedDate]       DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]        BIGINT            NULL,
    [ModifiedDate]      DATETIME2(7)      NULL,
    CONSTRAINT [PK_Priority] PRIMARY KEY CLUSTERED ([PriorityID]),
    CONSTRAINT [UQ_Priority_Code] UNIQUE ([PriorityCode])
);
GO

-- 1.4 RequesterType
CREATE TABLE [Tickets].[RequesterType] (
    [RequesterTypeID]   INT IDENTITY(1,1) NOT NULL,
    [TypeCode]          NVARCHAR(50)      NOT NULL,
    [TypeNameAR]        NVARCHAR(200)     NULL,
    [TypeNameEN]        NVARCHAR(200)     NULL,
    [SortOrder]         INT               NULL DEFAULT 0,
    [IsActive]          BIT               NOT NULL DEFAULT 1,
    [CreatedBy]         BIGINT            NULL,
    [CreatedDate]       DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]        BIGINT            NULL,
    [ModifiedDate]      DATETIME2(7)      NULL,
    CONSTRAINT [PK_RequesterType] PRIMARY KEY CLUSTERED ([RequesterTypeID]),
    CONSTRAINT [UQ_RequesterType_Code] UNIQUE ([TypeCode])
);
GO

-- 1.5 PauseReason
CREATE TABLE [Tickets].[PauseReason] (
    [PauseReasonID]     INT IDENTITY(1,1) NOT NULL,
    [ReasonCode]        NVARCHAR(50)      NOT NULL,
    [ReasonNameAR]      NVARCHAR(200)     NULL,
    [ReasonNameEN]      NVARCHAR(200)     NULL,
    [SortOrder]         INT               NULL DEFAULT 0,
    [IsActive]          BIT               NOT NULL DEFAULT 1,
    [CreatedBy]         BIGINT            NULL,
    [CreatedDate]       DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]        BIGINT            NULL,
    [ModifiedDate]      DATETIME2(7)      NULL,
    CONSTRAINT [PK_PauseReason] PRIMARY KEY CLUSTERED ([PauseReasonID]),
    CONSTRAINT [UQ_PauseReason_Code] UNIQUE ([ReasonCode])
);
GO

-- 1.6 ArbitrationReason
CREATE TABLE [Tickets].[ArbitrationReason] (
    [ArbitrationReasonID] INT IDENTITY(1,1) NOT NULL,
    [ReasonCode]          NVARCHAR(50)      NOT NULL,
    [ReasonNameAR]        NVARCHAR(200)     NULL,
    [ReasonNameEN]        NVARCHAR(200)     NULL,
    [SortOrder]           INT               NULL DEFAULT 0,
    [IsActive]            BIT               NOT NULL DEFAULT 1,
    [CreatedBy]           BIGINT            NULL,
    [CreatedDate]         DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]          BIGINT            NULL,
    [ModifiedDate]        DATETIME2(7)      NULL,
    CONSTRAINT [PK_ArbitrationReason] PRIMARY KEY CLUSTERED ([ArbitrationReasonID]),
    CONSTRAINT [UQ_ArbitrationReason_Code] UNIQUE ([ReasonCode])
);
GO

-- 1.7 ClarificationReason
CREATE TABLE [Tickets].[ClarificationReason] (
    [ClarificationReasonID] INT IDENTITY(1,1) NOT NULL,
    [ReasonCode]            NVARCHAR(50)      NOT NULL,
    [ReasonNameAR]          NVARCHAR(200)     NULL,
    [ReasonNameEN]          NVARCHAR(200)     NULL,
    [SortOrder]             INT               NULL DEFAULT 0,
    [IsActive]              BIT               NOT NULL DEFAULT 1,
    [CreatedBy]             BIGINT            NULL,
    [CreatedDate]           DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]            BIGINT            NULL,
    [ModifiedDate]          DATETIME2(7)      NULL,
    CONSTRAINT [PK_ClarificationReason] PRIMARY KEY CLUSTERED ([ClarificationReasonID]),
    CONSTRAINT [UQ_ClarificationReason_Code] UNIQUE ([ReasonCode])
);
GO

-- 1.8 QualityReviewResult
CREATE TABLE [Tickets].[QualityReviewResult] (
    [QualityReviewResultID] INT IDENTITY(1,1) NOT NULL,
    [ResultCode]            NVARCHAR(50)      NOT NULL,
    [ResultNameAR]          NVARCHAR(200)     NULL,
    [ResultNameEN]          NVARCHAR(200)     NULL,
    [SortOrder]             INT               NULL DEFAULT 0,
    [IsActive]              BIT               NOT NULL DEFAULT 1,
    [CreatedBy]             BIGINT            NULL,
    [CreatedDate]           DATETIME2(7)      NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]            BIGINT            NULL,
    [ModifiedDate]          DATETIME2(7)      NULL,
    CONSTRAINT [PK_QualityReviewResult] PRIMARY KEY CLUSTERED ([QualityReviewResultID]),
    CONSTRAINT [UQ_QualityReviewResult_Code] UNIQUE ([ResultCode])
);
GO

-- ============================================================================
-- STEP 1-SEED: LOOKUP SEED DATA
-- ============================================================================

-- Seed TicketStatus
INSERT INTO [Tickets].[TicketStatus] ([StatusCode],[StatusNameEN],[StatusNameAR],[SortOrder])
VALUES
    ('NEW',         'New',                      N'جديد',            1),
    ('OPEN',        'Open',                     N'مفتوح',           2),
    ('ASSIGNED',    'Assigned',                 N'مُعيَّن',          3),
    ('IN_PROGRESS', 'In Progress',              N'قيد التنفيذ',      4),
    ('ON_HOLD',     'On Hold',                  N'معلق',            5),
    ('PENDING_CLARIFICATION', 'Pending Clarification', N'بانتظار توضيح', 6),
    ('IN_ARBITRATION', 'In Arbitration',        N'في التحكيم',       7),
    ('RESOLVED',    'Resolved (Operational)',    N'تم الحل (تشغيلي)', 8),
    ('PENDING_QA',  'Pending Quality Review',   N'بانتظار مراجعة الجودة', 9),
    ('CLOSED',      'Closed',                   N'مغلق',            10),
    ('REOPENED',    'Reopened',                  N'أعيد فتحه',       11),
    ('REJECTED',    'Rejected to Supervisor',   N'مرفوض للمشرف',    12),
    ('CANCELLED',   'Cancelled',                N'ملغي',            13);
GO

-- Seed TicketClass
INSERT INTO [Tickets].[TicketClass] ([ClassCode],[ClassNameEN],[ClassNameAR],[SortOrder])
VALUES
    ('INCIDENT',    'Incident',         N'حادثة',       1),
    ('REQUEST',     'Service Request',  N'طلب خدمة',    2),
    ('COMPLAINT',   'Complaint',        N'شكوى',        3),
    ('INQUIRY',     'Inquiry',          N'استفسار',     4);
GO

-- Seed Priority
INSERT INTO [Tickets].[Priority] ([PriorityCode],[PriorityNameEN],[PriorityNameAR],[SortOrder])
VALUES
    ('CRITICAL', 'Critical', N'حرج',     1),
    ('HIGH',     'High',     N'عالي',    2),
    ('MEDIUM',   'Medium',   N'متوسط',   3),
    ('LOW',      'Low',      N'منخفض',   4);
GO

-- Seed RequesterType
INSERT INTO [Tickets].[RequesterType] ([TypeCode],[TypeNameEN],[TypeNameAR],[SortOrder])
VALUES
    ('RESIDENT', 'Resident / Beneficiary', N'مقيم / مستفيد',    1),
    ('INTERNAL', 'Internal User',          N'مستخدم داخلي',     2);
GO

-- Seed PauseReason
INSERT INTO [Tickets].[PauseReason] ([ReasonCode],[ReasonNameEN],[ReasonNameAR],[SortOrder])
VALUES
    ('CHILD_DEPENDENCY',    'Dependent Child Ticket',       N'تذكرة فرعية معلقة',      1),
    ('ARBITRATION',         'In Arbitration',               N'في التحكيم',              2),
    ('CLARIFICATION',       'Pending Clarification',        N'بانتظار توضيح',           3),
    ('WAREHOUSE_DELAY',     'Warehouse Delay',              N'تأخير المستودع',          4),
    ('APPROVAL_DELAY',      'Approval Delay',               N'تأخير الموافقة',          5),
    ('EXTERNAL_DEPENDENCY', 'External Dependency',          N'اعتماد خارجي',            6);
GO

-- Seed ArbitrationReason
INSERT INTO [Tickets].[ArbitrationReason] ([ReasonCode],[ReasonNameEN],[ReasonNameAR],[SortOrder])
VALUES
    ('WRONG_DEPARTMENT',    'Wrong Department',             N'قسم خاطئ',        1),
    ('WRONG_DIVISION',      'Wrong Division',               N'شعبة خاطئة',      2),
    ('WRONG_SECTION',       'Wrong Section',                N'وحدة خاطئة',      3),
    ('UNCLEAR_OWNERSHIP',   'Unclear Ownership',            N'ملكية غير واضحة', 4),
    ('OTHER',               'Other',                        N'أخرى',            5);
GO

-- Seed ClarificationReason
INSERT INTO [Tickets].[ClarificationReason] ([ReasonCode],[ReasonNameEN],[ReasonNameAR],[SortOrder])
VALUES
    ('MISSING_LOCATION',    'Missing Location Details',         N'تفاصيل موقع مفقودة',      1),
    ('MISSING_TECHNICAL',   'Missing Technical Details',        N'تفاصيل تقنية مفقودة',      2),
    ('MISSING_APPROVAL',    'Missing Approval/Authorization',   N'موافقة مفقودة',            3),
    ('AMBIGUOUS_REQUEST',   'Ambiguous Request Description',    N'وصف طلب غامض',            4),
    ('OTHER',               'Other',                            N'أخرى',                     5);
GO

-- Seed QualityReviewResult
INSERT INTO [Tickets].[QualityReviewResult] ([ResultCode],[ResultNameEN],[ResultNameAR],[SortOrder])
VALUES
    ('APPROVED',        'Approved for Final Closure',   N'مُعتمد للإغلاق النهائي',  1),
    ('RETURNED',        'Returned for Correction',      N'مُعاد للتصحيح',           2),
    ('REJECTED',        'Closure Rejected',             N'إغلاق مرفوض',             3);
GO

-- ============================================================================
-- STEP 2: MASTER TABLES (BIGINT keys)
-- ============================================================================

-- 2.1 Service
CREATE TABLE [Tickets].[Service] (
    [ServiceID]             BIGINT IDENTITY(1,1)    NOT NULL,
    [IdaraID_FK]            BIGINT                  NOT NULL,
    [ServiceCode]           NVARCHAR(50)            NOT NULL,
    [ServiceNameAR]         NVARCHAR(500)           NULL,
    [ServiceNameEN]         NVARCHAR(500)           NULL,
    [ServiceDescriptionAR]  NVARCHAR(2000)          NULL,
    [ServiceDescriptionEN]  NVARCHAR(2000)          NULL,
    [TicketClassID_FK]      INT                     NULL,
    [DefaultPriorityID_FK]  INT                     NULL,
    [RequiresLocation]      BIT                     NOT NULL DEFAULT 0,
    [RequiresQualityReview] BIT                     NOT NULL DEFAULT 0,
    [IsActive]              BIT                     NOT NULL DEFAULT 1,
    [IsDeleted]             BIT                     NOT NULL DEFAULT 0,
    [CreatedBy]             BIGINT                  NULL,
    [CreatedDate]           DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]            BIGINT                  NULL,
    [ModifiedDate]          DATETIME2(7)            NULL,
    CONSTRAINT [PK_Service] PRIMARY KEY CLUSTERED ([ServiceID]),
    CONSTRAINT [UQ_Service_Code_Idara] UNIQUE ([ServiceCode], [IdaraID_FK]),
    CONSTRAINT [FK_Service_TicketClass] FOREIGN KEY ([TicketClassID_FK]) REFERENCES [Tickets].[TicketClass]([TicketClassID]),
    CONSTRAINT [FK_Service_Priority] FOREIGN KEY ([DefaultPriorityID_FK]) REFERENCES [Tickets].[Priority]([PriorityID])
);
GO

-- 2.2 ServiceRoutingRule
CREATE TABLE [Tickets].[ServiceRoutingRule] (
    [ServiceRoutingRuleID]  BIGINT IDENTITY(1,1)    NOT NULL,
    [ServiceID_FK]          BIGINT                  NOT NULL,
    [IdaraID_FK]            BIGINT                  NOT NULL,
    [TargetDSDID_FK]        BIGINT                  NOT NULL,
    [QueueDistributorID_FK] BIGINT                  NULL,
    [EffectiveFrom]         DATE                    NOT NULL,
    [EffectiveTo]           DATE                    NULL,
    [ChangeReason]          NVARCHAR(1000)          NULL,
    [ApprovedBy]            BIGINT                  NULL,
    [ApprovedDate]          DATETIME2(7)            NULL,
    [IsActive]              BIT                     NOT NULL DEFAULT 1,
    [CreatedBy]             BIGINT                  NULL,
    [CreatedDate]           DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]            BIGINT                  NULL,
    [ModifiedDate]          DATETIME2(7)            NULL,
    CONSTRAINT [PK_ServiceRoutingRule] PRIMARY KEY CLUSTERED ([ServiceRoutingRuleID]),
    CONSTRAINT [FK_SRR_Service] FOREIGN KEY ([ServiceID_FK]) REFERENCES [Tickets].[Service]([ServiceID])
);
GO

-- 2.3 ServiceSLAPolicy
CREATE TABLE [Tickets].[ServiceSLAPolicy] (
    [ServiceSLAPolicyID]            BIGINT IDENTITY(1,1)    NOT NULL,
    [ServiceID_FK]                  BIGINT                  NOT NULL,
    [IdaraID_FK]                    BIGINT                  NOT NULL,
    [PriorityID_FK]                 INT                     NOT NULL,
    [FirstResponseTargetMinutes]    INT                     NULL,
    [AssignmentTargetMinutes]       INT                     NULL,
    [OperationalCompletionTargetMinutes] INT                NULL,
    [FinalClosureTargetMinutes]     INT                     NULL,
    [EffectiveFrom]                 DATE                    NOT NULL,
    [EffectiveTo]                   DATE                    NULL,
    [IsActive]                      BIT                     NOT NULL DEFAULT 1,
    [CreatedBy]                     BIGINT                  NULL,
    [CreatedDate]                   DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                    BIGINT                  NULL,
    [ModifiedDate]                  DATETIME2(7)            NULL,
    CONSTRAINT [PK_ServiceSLAPolicy] PRIMARY KEY CLUSTERED ([ServiceSLAPolicyID]),
    CONSTRAINT [FK_SSLA_Service] FOREIGN KEY ([ServiceID_FK]) REFERENCES [Tickets].[Service]([ServiceID]),
    CONSTRAINT [FK_SSLA_Priority] FOREIGN KEY ([PriorityID_FK]) REFERENCES [Tickets].[Priority]([PriorityID])
);
GO

-- 2.4 ServiceCatalogSuggestion
CREATE TABLE [Tickets].[ServiceCatalogSuggestion] (
    [ServiceCatalogSuggestionID]    BIGINT IDENTITY(1,1)    NOT NULL,
    [SourceTicketID_FK]             BIGINT                  NULL,
    [IdaraID_FK]                    BIGINT                  NOT NULL,
    [ProposedServiceNameAR]         NVARCHAR(500)           NULL,
    [ProposedServiceNameEN]         NVARCHAR(500)           NULL,
    [ProposedDescription]           NVARCHAR(2000)          NULL,
    [ProposedTargetDSDID_FK]        BIGINT                  NULL,
    [ProposedPriorityID_FK]         INT                     NULL,
    [ApprovalStatus]                NVARCHAR(50)            NOT NULL DEFAULT 'PENDING',
    [ApprovedBy]                    BIGINT                  NULL,
    [ApprovedDate]                  DATETIME2(7)            NULL,
    [RejectionReason]               NVARCHAR(1000)          NULL,
    [CreatedServiceID_FK]           BIGINT                  NULL,
    [CreatedBy]                     BIGINT                  NULL,
    [CreatedDate]                   DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                    BIGINT                  NULL,
    [ModifiedDate]                  DATETIME2(7)            NULL,
    CONSTRAINT [PK_ServiceCatalogSuggestion] PRIMARY KEY CLUSTERED ([ServiceCatalogSuggestionID]),
    CONSTRAINT [FK_SCS_Priority] FOREIGN KEY ([ProposedPriorityID_FK]) REFERENCES [Tickets].[Priority]([PriorityID]),
    CONSTRAINT [FK_SCS_CreatedService] FOREIGN KEY ([CreatedServiceID_FK]) REFERENCES [Tickets].[Service]([ServiceID])
);
GO

-- ============================================================================
-- STEP 3: TRANSACTION TABLES
-- ============================================================================

-- 3.1 Ticket (Central Transaction Table)
CREATE TABLE [Tickets].[Ticket] (
    [TicketID]                      BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketNo]                      NVARCHAR(50)            NOT NULL,
    [IdaraID_FK]                    BIGINT                  NOT NULL,
    [ParentTicketID_FK]             BIGINT                  NULL,
    [RootTicketID_FK]               BIGINT                  NULL,
    [ServiceID_FK]                  BIGINT                  NULL,
    [TicketClassID_FK]              INT                     NOT NULL,
    [RequesterTypeID_FK]            INT                     NOT NULL,
    [RequesterUserID_FK]            BIGINT                  NULL,
    [RequesterResidentID_FK]        BIGINT                  NULL,
    [Title]                         NVARCHAR(500)           NOT NULL,
    [Description]                   NVARCHAR(4000)          NULL,
    [SuggestedPriorityID_FK]        INT                     NULL,
    [EffectivePriorityID_FK]        INT                     NULL,
    [TicketStatusID_FK]             INT                     NOT NULL,
    [CurrentDSDID_FK]               BIGINT                  NULL,
    [CurrentQueueDistributorID_FK]  BIGINT                  NULL,
    [AssignedUserID_FK]             BIGINT                  NULL,
    [LocationBuilding]              NVARCHAR(200)           NULL,
    [LocationFloor]                 NVARCHAR(100)           NULL,
    [LocationRoom]                  NVARCHAR(100)           NULL,
    [LocationNotes]                 NVARCHAR(500)           NULL,
    [IsOtherService]                BIT                     NOT NULL DEFAULT 0,
    [IsParentBlocked]               BIT                     NOT NULL DEFAULT 0,
    [RequiresQualityReview]         BIT                     NOT NULL DEFAULT 0,
    [OperationalResolvedDate]       DATETIME2(7)            NULL,
    [OperationalResolvedBy]         BIGINT                  NULL,
    [FinalClosedDate]               DATETIME2(7)            NULL,
    [FinalClosedBy]                 BIGINT                  NULL,
    [CreatedBy]                     BIGINT                  NULL,
    [CreatedDate]                   DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                    BIGINT                  NULL,
    [ModifiedDate]                  DATETIME2(7)            NULL,
    CONSTRAINT [PK_Ticket] PRIMARY KEY CLUSTERED ([TicketID]),
    CONSTRAINT [UQ_Ticket_TicketNo] UNIQUE ([TicketNo]),
    CONSTRAINT [FK_Ticket_Service] FOREIGN KEY ([ServiceID_FK]) REFERENCES [Tickets].[Service]([ServiceID]),
    CONSTRAINT [FK_Ticket_TicketClass] FOREIGN KEY ([TicketClassID_FK]) REFERENCES [Tickets].[TicketClass]([TicketClassID]),
    CONSTRAINT [FK_Ticket_RequesterType] FOREIGN KEY ([RequesterTypeID_FK]) REFERENCES [Tickets].[RequesterType]([RequesterTypeID]),
    CONSTRAINT [FK_Ticket_SuggestedPriority] FOREIGN KEY ([SuggestedPriorityID_FK]) REFERENCES [Tickets].[Priority]([PriorityID]),
    CONSTRAINT [FK_Ticket_EffectivePriority] FOREIGN KEY ([EffectivePriorityID_FK]) REFERENCES [Tickets].[Priority]([PriorityID]),
    CONSTRAINT [FK_Ticket_Status] FOREIGN KEY ([TicketStatusID_FK]) REFERENCES [Tickets].[TicketStatus]([TicketStatusID]),
    CONSTRAINT [FK_Ticket_Parent] FOREIGN KEY ([ParentTicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_Ticket_Root] FOREIGN KEY ([RootTicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    -- BR-01: A requester is either resident or internal, not both
    CONSTRAINT [CK_Ticket_RequesterExclusivity] CHECK (
        NOT ([RequesterUserID_FK] IS NOT NULL AND [RequesterResidentID_FK] IS NOT NULL)
    )
);
GO

-- 3.2 ArbitrationCase
CREATE TABLE [Tickets].[ArbitrationCase] (
    [ArbitrationCaseID]         BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]               BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [RaisedByUserID_FK]         BIGINT                  NOT NULL,
    [RaisedFromDSDID_FK]        BIGINT                  NOT NULL,
    [ArbitrationReasonID_FK]    INT                     NOT NULL,
    [ArbitratorDistributorID_FK] BIGINT                 NULL,
    [Status]                    NVARCHAR(50)            NOT NULL DEFAULT 'OPEN',
    [DecisionType]              NVARCHAR(50)            NULL,
    [DecisionTargetDSDID_FK]    BIGINT                  NULL,
    [DecisionNotes]             NVARCHAR(2000)          NULL,
    [DecisionDate]              DATETIME2(7)            NULL,
    [DecisionBy]                BIGINT                  NULL,
    [CreatedBy]                 BIGINT                  NULL,
    [CreatedDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                BIGINT                  NULL,
    [ModifiedDate]              DATETIME2(7)            NULL,
    CONSTRAINT [PK_ArbitrationCase] PRIMARY KEY CLUSTERED ([ArbitrationCaseID]),
    CONSTRAINT [FK_AC_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_AC_ArbitrationReason] FOREIGN KEY ([ArbitrationReasonID_FK]) REFERENCES [Tickets].[ArbitrationReason]([ArbitrationReasonID])
);
GO

-- 3.3 ClarificationRequest
CREATE TABLE [Tickets].[ClarificationRequest] (
    [ClarificationRequestID]    BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]               BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [RequestedByUserID_FK]      BIGINT                  NOT NULL,
    [RequestedFromUserID_FK]    BIGINT                  NULL,
    [RequestedFromDSDID_FK]     BIGINT                  NULL,
    [ClarificationReasonID_FK]  INT                     NOT NULL,
    [RequestNotes]              NVARCHAR(4000)          NULL,
    [ResponseNotes]             NVARCHAR(4000)          NULL,
    [RequestDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ResponseDate]              DATETIME2(7)            NULL,
    [RespondedByUserID_FK]      BIGINT                  NULL,
    [Status]                    NVARCHAR(50)            NOT NULL DEFAULT 'OPEN',
    [CreatedBy]                 BIGINT                  NULL,
    [CreatedDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                BIGINT                  NULL,
    [ModifiedDate]              DATETIME2(7)            NULL,
    CONSTRAINT [PK_ClarificationRequest] PRIMARY KEY CLUSTERED ([ClarificationRequestID]),
    CONSTRAINT [FK_CR_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_CR_ClarificationReason] FOREIGN KEY ([ClarificationReasonID_FK]) REFERENCES [Tickets].[ClarificationReason]([ClarificationReasonID])
);
GO

-- 3.4 QualityReview
CREATE TABLE [Tickets].[QualityReview] (
    [QualityReviewID]           BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]               BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [ReviewerUserID_FK]         BIGINT                  NULL,
    [ReviewScope]               NVARCHAR(500)           NULL,
    [QualityReviewResultID_FK]  INT                     NULL,
    [ReviewNotes]               NVARCHAR(4000)          NULL,
    [ReviewDate]                DATETIME2(7)            NULL,
    [ReturnToUserID_FK]         BIGINT                  NULL,
    [IsFinalized]               BIT                     NOT NULL DEFAULT 0,
    [CreatedBy]                 BIGINT                  NULL,
    [CreatedDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                BIGINT                  NULL,
    [ModifiedDate]              DATETIME2(7)            NULL,
    CONSTRAINT [PK_QualityReview] PRIMARY KEY CLUSTERED ([QualityReviewID]),
    CONSTRAINT [FK_QR_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_QR_Result] FOREIGN KEY ([QualityReviewResultID_FK]) REFERENCES [Tickets].[QualityReviewResult]([QualityReviewResultID])
);
GO

-- 3.5 TicketPauseSession
CREATE TABLE [Tickets].[TicketPauseSession] (
    [TicketPauseSessionID]      BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]               BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [PauseReasonID_FK]          INT                     NOT NULL,
    [RelatedChildTicketID_FK]   BIGINT                  NULL,
    [RelatedArbitrationCaseID_FK] BIGINT                NULL,
    [RelatedClarificationRequestID_FK] BIGINT           NULL,
    [PauseStartDate]            DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [PauseEndDate]              DATETIME2(7)            NULL,
    [ShouldPauseSLA]            BIT                     NOT NULL DEFAULT 1,
    [Notes]                     NVARCHAR(2000)          NULL,
    [CreatedBy]                 BIGINT                  NULL,
    [CreatedDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                BIGINT                  NULL,
    [ModifiedDate]              DATETIME2(7)            NULL,
    CONSTRAINT [PK_TicketPauseSession] PRIMARY KEY CLUSTERED ([TicketPauseSessionID]),
    CONSTRAINT [FK_TPS_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_TPS_PauseReason] FOREIGN KEY ([PauseReasonID_FK]) REFERENCES [Tickets].[PauseReason]([PauseReasonID]),
    CONSTRAINT [FK_TPS_ChildTicket] FOREIGN KEY ([RelatedChildTicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_TPS_Arbitration] FOREIGN KEY ([RelatedArbitrationCaseID_FK]) REFERENCES [Tickets].[ArbitrationCase]([ArbitrationCaseID]),
    CONSTRAINT [FK_TPS_Clarification] FOREIGN KEY ([RelatedClarificationRequestID_FK]) REFERENCES [Tickets].[ClarificationRequest]([ClarificationRequestID])
);
GO

-- 3.6 TicketSLA
CREATE TABLE [Tickets].[TicketSLA] (
    [TicketSLAID]               BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]               BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [SLATypeCode]               NVARCHAR(50)            NOT NULL, -- FIRST_RESPONSE, ASSIGNMENT, OPERATIONAL_COMPLETION, FINAL_CLOSURE
    [TargetMinutes]             INT                     NOT NULL,
    [ElapsedMinutes]            INT                     NOT NULL DEFAULT 0,
    [RemainingMinutes]          INT                     NOT NULL DEFAULT 0,
    [IsBreached]                BIT                     NOT NULL DEFAULT 0,
    [StartDate]                 DATETIME2(7)            NULL,
    [StopDate]                  DATETIME2(7)            NULL,
    [CompletionDate]            DATETIME2(7)            NULL,
    [LastCalculatedDate]        DATETIME2(7)            NULL,
    [CreatedBy]                 BIGINT                  NULL,
    [CreatedDate]               DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [ModifiedBy]                BIGINT                  NULL,
    [ModifiedDate]              DATETIME2(7)            NULL,
    CONSTRAINT [PK_TicketSLA] PRIMARY KEY CLUSTERED ([TicketSLAID]),
    CONSTRAINT [FK_TSLA_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [UQ_TicketSLA_TicketType] UNIQUE ([TicketID_FK], [SLATypeCode])
);
GO

-- ============================================================================
-- STEP 4: HISTORY TABLES (BIGINT keys, immutable)
-- ============================================================================

-- 4.1 TicketHistory
CREATE TABLE [Tickets].[TicketHistory] (
    [TicketHistoryID]       BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketID_FK]           BIGINT                  NOT NULL,
    [IdaraID_FK]            BIGINT                  NOT NULL,
    [ActionTypeCode]        NVARCHAR(100)           NOT NULL,
    [OldStatusID_FK]        INT                     NULL,
    [NewStatusID_FK]        INT                     NULL,
    [OldDSDID_FK]           BIGINT                  NULL,
    [NewDSDID_FK]           BIGINT                  NULL,
    [OldAssignedUserID_FK]  BIGINT                  NULL,
    [NewAssignedUserID_FK]  BIGINT                  NULL,
    [PerformedByUserID_FK]  BIGINT                  NOT NULL,
    [Notes]                 NVARCHAR(4000)          NULL,
    [ActionDate]            DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT [PK_TicketHistory] PRIMARY KEY CLUSTERED ([TicketHistoryID]),
    CONSTRAINT [FK_TH_Ticket] FOREIGN KEY ([TicketID_FK]) REFERENCES [Tickets].[Ticket]([TicketID]),
    CONSTRAINT [FK_TH_OldStatus] FOREIGN KEY ([OldStatusID_FK]) REFERENCES [Tickets].[TicketStatus]([TicketStatusID]),
    CONSTRAINT [FK_TH_NewStatus] FOREIGN KEY ([NewStatusID_FK]) REFERENCES [Tickets].[TicketStatus]([TicketStatusID])
);
GO

-- 4.2 TicketSLAHistory
CREATE TABLE [Tickets].[TicketSLAHistory] (
    [TicketSLAHistoryID]    BIGINT IDENTITY(1,1)    NOT NULL,
    [TicketSLAID_FK]        BIGINT                  NOT NULL,
    [IdaraID_FK]            BIGINT                  NOT NULL,
    [SLAEventTypeCode]      NVARCHAR(100)           NOT NULL, -- INITIALIZED, PAUSED, RESUMED, BREACHED, COMPLETED
    [EventDate]             DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    [Notes]                 NVARCHAR(2000)          NULL,
    [PerformedByUserID_FK]  BIGINT                  NULL,
    CONSTRAINT [PK_TicketSLAHistory] PRIMARY KEY CLUSTERED ([TicketSLAHistoryID]),
    CONSTRAINT [FK_TSLAH_TicketSLA] FOREIGN KEY ([TicketSLAID_FK]) REFERENCES [Tickets].[TicketSLA]([TicketSLAID])
);
GO

-- 4.3 CatalogRoutingChangeLog
CREATE TABLE [Tickets].[CatalogRoutingChangeLog] (
    [CatalogRoutingChangeLogID] BIGINT IDENTITY(1,1)    NOT NULL,
    [ServiceID_FK]              BIGINT                  NOT NULL,
    [IdaraID_FK]                BIGINT                  NOT NULL,
    [OldRoutingRuleID_FK]       BIGINT                  NULL,
    [NewRoutingRuleID_FK]       BIGINT                  NULL,
    [ChangeReason]              NVARCHAR(1000)          NULL,
    [SourceArbitrationCaseID_FK] BIGINT                 NULL,
    [ApprovedByUserID_FK]       BIGINT                  NULL,
    [EffectiveFromDate]         DATE                    NOT NULL,
    [LoggedDate]                DATETIME2(7)            NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT [PK_CatalogRoutingChangeLog] PRIMARY KEY CLUSTERED ([CatalogRoutingChangeLogID]),
    CONSTRAINT [FK_CRCL_Service] FOREIGN KEY ([ServiceID_FK]) REFERENCES [Tickets].[Service]([ServiceID]),
    CONSTRAINT [FK_CRCL_OldRule] FOREIGN KEY ([OldRoutingRuleID_FK]) REFERENCES [Tickets].[ServiceRoutingRule]([ServiceRoutingRuleID]),
    CONSTRAINT [FK_CRCL_NewRule] FOREIGN KEY ([NewRoutingRuleID_FK]) REFERENCES [Tickets].[ServiceRoutingRule]([ServiceRoutingRuleID]),
    CONSTRAINT [FK_CRCL_Arbitration] FOREIGN KEY ([SourceArbitrationCaseID_FK]) REFERENCES [Tickets].[ArbitrationCase]([ArbitrationCaseID])
);
GO

-- ============================================================================
-- STEP 5: SQL VIEWS
-- ============================================================================

-- 5.1 V_ServiceFullDefinition
CREATE OR ALTER VIEW [Tickets].[V_ServiceFullDefinition]
AS
SELECT
    s.[ServiceID],
    s.[IdaraID_FK],
    s.[ServiceCode],
    s.[ServiceNameAR],
    s.[ServiceNameEN],
    s.[ServiceDescriptionAR],
    s.[ServiceDescriptionEN],
    tc.[ClassCode] AS TicketClassCode,
    tc.[ClassNameEN] AS TicketClassName,
    p.[PriorityCode] AS DefaultPriorityCode,
    p.[PriorityNameEN] AS DefaultPriorityName,
    s.[RequiresLocation],
    s.[RequiresQualityReview],
    s.[IsActive],
    srr.[ServiceRoutingRuleID] AS ActiveRoutingRuleID,
    srr.[TargetDSDID_FK],
    srr.[QueueDistributorID_FK],
    srr.[EffectiveFrom] AS RoutingEffectiveFrom,
    srr.[EffectiveTo] AS RoutingEffectiveTo
FROM [Tickets].[Service] s
LEFT JOIN [Tickets].[TicketClass] tc ON s.[TicketClassID_FK] = tc.[TicketClassID]
LEFT JOIN [Tickets].[Priority] p ON s.[DefaultPriorityID_FK] = p.[PriorityID]
LEFT JOIN [Tickets].[ServiceRoutingRule] srr
    ON srr.[ServiceID_FK] = s.[ServiceID]
    AND srr.[IsActive] = 1
    AND srr.[EffectiveFrom] <= CAST(GETDATE() AS DATE)
    AND (srr.[EffectiveTo] IS NULL OR srr.[EffectiveTo] >= CAST(GETDATE() AS DATE))
WHERE s.[IsDeleted] = 0;
GO

-- 5.2 V_TicketFullDetails
CREATE OR ALTER VIEW [Tickets].[V_TicketFullDetails]
AS
SELECT
    t.[TicketID],
    t.[TicketNo],
    t.[IdaraID_FK],
    t.[ParentTicketID_FK],
    t.[RootTicketID_FK],
    t.[Title],
    t.[Description],
    t.[IsOtherService],
    t.[IsParentBlocked],
    t.[RequiresQualityReview],
    -- Service
    s.[ServiceCode],
    s.[ServiceNameEN],
    s.[ServiceNameAR],
    -- Class
    tc.[ClassCode] AS TicketClassCode,
    tc.[ClassNameEN] AS TicketClassName,
    -- Requester
    rt.[TypeCode] AS RequesterTypeCode,
    rt.[TypeNameEN] AS RequesterTypeName,
    t.[RequesterUserID_FK],
    t.[RequesterResidentID_FK],
    -- Priority
    sp.[PriorityCode] AS SuggestedPriorityCode,
    ep.[PriorityCode] AS EffectivePriorityCode,
    ep.[PriorityNameEN] AS EffectivePriorityName,
    -- Status
    ts.[StatusCode] AS TicketStatusCode,
    ts.[StatusNameEN] AS TicketStatusName,
    -- Routing
    t.[CurrentDSDID_FK],
    t.[CurrentQueueDistributorID_FK],
    t.[AssignedUserID_FK],
    -- Location
    t.[LocationBuilding],
    t.[LocationFloor],
    t.[LocationRoom],
    t.[LocationNotes],
    -- Dates
    t.[OperationalResolvedDate],
    t.[FinalClosedDate],
    t.[CreatedDate],
    t.[CreatedBy]
FROM [Tickets].[Ticket] t
LEFT JOIN [Tickets].[Service] s ON t.[ServiceID_FK] = s.[ServiceID]
LEFT JOIN [Tickets].[TicketClass] tc ON t.[TicketClassID_FK] = tc.[TicketClassID]
LEFT JOIN [Tickets].[RequesterType] rt ON t.[RequesterTypeID_FK] = rt.[RequesterTypeID]
LEFT JOIN [Tickets].[Priority] sp ON t.[SuggestedPriorityID_FK] = sp.[PriorityID]
LEFT JOIN [Tickets].[Priority] ep ON t.[EffectivePriorityID_FK] = ep.[PriorityID]
LEFT JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID];
GO

-- 5.3 V_TicketLastAction
CREATE OR ALTER VIEW [Tickets].[V_TicketLastAction]
AS
SELECT
    th.[TicketID_FK],
    th.[TicketHistoryID],
    th.[ActionTypeCode],
    th.[OldStatusID_FK],
    th.[NewStatusID_FK],
    th.[PerformedByUserID_FK],
    th.[Notes],
    th.[ActionDate]
FROM [Tickets].[TicketHistory] th
INNER JOIN (
    SELECT [TicketID_FK], MAX([TicketHistoryID]) AS MaxHistoryID
    FROM [Tickets].[TicketHistory]
    GROUP BY [TicketID_FK]
) latest ON th.[TicketID_FK] = latest.[TicketID_FK] AND th.[TicketHistoryID] = latest.MaxHistoryID;
GO

-- 5.4 V_TicketCurrentSLA
CREATE OR ALTER VIEW [Tickets].[V_TicketCurrentSLA]
AS
SELECT
    tsla.[TicketSLAID],
    tsla.[TicketID_FK],
    tsla.[IdaraID_FK],
    tsla.[SLATypeCode],
    tsla.[TargetMinutes],
    tsla.[ElapsedMinutes],
    tsla.[RemainingMinutes],
    tsla.[IsBreached],
    tsla.[StartDate],
    tsla.[StopDate],
    tsla.[CompletionDate],
    tsla.[LastCalculatedDate],
    t.[TicketNo],
    t.[Title]
FROM [Tickets].[TicketSLA] tsla
INNER JOIN [Tickets].[Ticket] t ON tsla.[TicketID_FK] = t.[TicketID];
GO

-- 5.5 V_TicketInboxByScope
CREATE OR ALTER VIEW [Tickets].[V_TicketInboxByScope]
AS
SELECT
    t.[TicketID],
    t.[TicketNo],
    t.[IdaraID_FK],
    t.[Title],
    t.[CurrentDSDID_FK],
    t.[CurrentQueueDistributorID_FK],
    t.[AssignedUserID_FK],
    ts.[StatusCode],
    ts.[StatusNameEN],
    ep.[PriorityCode] AS EffectivePriorityCode,
    ep.[PriorityNameEN] AS EffectivePriorityName,
    t.[IsParentBlocked],
    t.[CreatedDate],
    s.[ServiceNameEN]
FROM [Tickets].[Ticket] t
LEFT JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
LEFT JOIN [Tickets].[Priority] ep ON t.[EffectivePriorityID_FK] = ep.[PriorityID]
LEFT JOIN [Tickets].[Service] s ON t.[ServiceID_FK] = s.[ServiceID]
WHERE ts.[StatusCode] NOT IN ('CLOSED','CANCELLED');
GO

-- 5.6 V_TicketArbitrationInbox
CREATE OR ALTER VIEW [Tickets].[V_TicketArbitrationInbox]
AS
SELECT
    ac.[ArbitrationCaseID],
    ac.[TicketID_FK],
    t.[TicketNo],
    t.[Title],
    ac.[IdaraID_FK],
    ac.[RaisedByUserID_FK],
    ac.[RaisedFromDSDID_FK],
    ar.[ReasonCode] AS ArbitrationReasonCode,
    ar.[ReasonNameEN] AS ArbitrationReasonName,
    ac.[ArbitratorDistributorID_FK],
    ac.[Status],
    ac.[CreatedDate]
FROM [Tickets].[ArbitrationCase] ac
INNER JOIN [Tickets].[Ticket] t ON ac.[TicketID_FK] = t.[TicketID]
INNER JOIN [Tickets].[ArbitrationReason] ar ON ac.[ArbitrationReasonID_FK] = ar.[ArbitrationReasonID]
WHERE ac.[Status] = 'OPEN';
GO

-- 5.7 V_TicketQualityInbox
CREATE OR ALTER VIEW [Tickets].[V_TicketQualityInbox]
AS
SELECT
    qr.[QualityReviewID],
    qr.[TicketID_FK],
    t.[TicketNo],
    t.[Title],
    qr.[IdaraID_FK],
    qr.[ReviewerUserID_FK],
    qr.[ReviewScope],
    qr.[IsFinalized],
    qr.[CreatedDate],
    t.[OperationalResolvedDate]
FROM [Tickets].[QualityReview] qr
INNER JOIN [Tickets].[Ticket] t ON qr.[TicketID_FK] = t.[TicketID]
WHERE qr.[IsFinalized] = 0;
GO

-- ============================================================================
-- STEP 6: STORED PROCEDURES (Multiplexer pattern with @Action)
-- ============================================================================

-- 6.1 ServiceSP
CREATE OR ALTER PROCEDURE [Tickets].[ServiceSP]
    @Action                     NVARCHAR(100),
    @ServiceID                  BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @ServiceCode                NVARCHAR(50)    = NULL,
    @ServiceNameAR              NVARCHAR(500)   = NULL,
    @ServiceNameEN              NVARCHAR(500)   = NULL,
    @ServiceDescriptionAR       NVARCHAR(2000)  = NULL,
    @ServiceDescriptionEN       NVARCHAR(2000)  = NULL,
    @TicketClassID              INT             = NULL,
    @DefaultPriorityID          INT             = NULL,
    @RequiresLocation           BIT             = 0,
    @RequiresQualityReview      BIT             = 0,
    @TargetDSDID                BIGINT          = NULL,
    @QueueDistributorID         BIGINT          = NULL,
    @EffectiveFrom              DATE            = NULL,
    @EffectiveTo                DATE            = NULL,
    @ChangeReason               NVARCHAR(1000)  = NULL,
    @PriorityID                 INT             = NULL,
    @FirstResponseTargetMin     INT             = NULL,
    @AssignmentTargetMin        INT             = NULL,
    @OperationalCompletionMin   INT             = NULL,
    @FinalClosureTargetMin      INT             = NULL,
    @SuggestionID               BIGINT          = NULL,
    @RejectionReason            NVARCHAR(1000)  = NULL,
    @RoutingRuleID              BIGINT          = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- INSERT_SERVICE
    IF @Action = 'INSERT_SERVICE'
    BEGIN
        BEGIN TRAN;
        INSERT INTO [Tickets].[Service]
            ([IdaraID_FK],[ServiceCode],[ServiceNameAR],[ServiceNameEN],
             [ServiceDescriptionAR],[ServiceDescriptionEN],[TicketClassID_FK],
             [DefaultPriorityID_FK],[RequiresLocation],[RequiresQualityReview],
             [CreatedBy])
        VALUES
            (@IdaraID, @ServiceCode, @ServiceNameAR, @ServiceNameEN,
             @ServiceDescriptionAR, @ServiceDescriptionEN, @TicketClassID,
             @DefaultPriorityID, @RequiresLocation, @RequiresQualityReview,
             @PerformedByUserID);

        DECLARE @NewServiceID BIGINT = SCOPE_IDENTITY();

        -- Audit
        INSERT INTO [dbo].[AuditLog] ([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.Service','INSERT_SERVICE',@NewServiceID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewServiceID AS ServiceID, @ServiceCode AS ServiceCode FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));

        COMMIT TRAN;
        SELECT @NewServiceID AS ServiceID;
        RETURN;
    END

    -- UPDATE_SERVICE
    IF @Action = 'UPDATE_SERVICE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[Service]
        SET [ServiceNameAR] = ISNULL(@ServiceNameAR, [ServiceNameAR]),
            [ServiceNameEN] = ISNULL(@ServiceNameEN, [ServiceNameEN]),
            [ServiceDescriptionAR] = ISNULL(@ServiceDescriptionAR, [ServiceDescriptionAR]),
            [ServiceDescriptionEN] = ISNULL(@ServiceDescriptionEN, [ServiceDescriptionEN]),
            [TicketClassID_FK] = ISNULL(@TicketClassID, [TicketClassID_FK]),
            [DefaultPriorityID_FK] = ISNULL(@DefaultPriorityID, [DefaultPriorityID_FK]),
            [RequiresLocation] = @RequiresLocation,
            [RequiresQualityReview] = @RequiresQualityReview,
            [ModifiedBy] = @PerformedByUserID,
            [ModifiedDate] = SYSUTCDATETIME()
        WHERE [ServiceID] = @ServiceID;
        COMMIT TRAN;
        RETURN;
    END

    -- DELETE_SERVICE (soft delete)
    IF @Action = 'DELETE_SERVICE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[Service]
        SET [IsDeleted] = 1, [IsActive] = 0,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [ServiceID] = @ServiceID;
        COMMIT TRAN;
        RETURN;
    END

    -- INSERT_ROUTING_RULE
    IF @Action = 'INSERT_ROUTING_RULE'
    BEGIN
        IF @TargetDSDID IS NULL
            THROW 50001, 'TargetDSDID_FK is mandatory for routing rules (BR-04).', 1;

        BEGIN TRAN;
        -- Close existing active rule
        UPDATE [Tickets].[ServiceRoutingRule]
        SET [EffectiveTo] = DATEADD(DAY, -1, @EffectiveFrom), [IsActive] = 0,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [ServiceID_FK] = @ServiceID AND [IsActive] = 1;

        DECLARE @OldRuleID BIGINT = (SELECT TOP 1 [ServiceRoutingRuleID]
            FROM [Tickets].[ServiceRoutingRule]
            WHERE [ServiceID_FK] = @ServiceID AND [IsActive] = 0
            ORDER BY [ModifiedDate] DESC);

        INSERT INTO [Tickets].[ServiceRoutingRule]
            ([ServiceID_FK],[IdaraID_FK],[TargetDSDID_FK],[QueueDistributorID_FK],
             [EffectiveFrom],[EffectiveTo],[ChangeReason],[ApprovedBy],[ApprovedDate],[CreatedBy])
        VALUES
            (@ServiceID, @IdaraID, @TargetDSDID, @QueueDistributorID,
             @EffectiveFrom, @EffectiveTo, @ChangeReason, @PerformedByUserID, SYSUTCDATETIME(), @PerformedByUserID);

        DECLARE @NewRuleID BIGINT = SCOPE_IDENTITY();

        -- Log routing change
        INSERT INTO [Tickets].[CatalogRoutingChangeLog]
            ([ServiceID_FK],[IdaraID_FK],[OldRoutingRuleID_FK],[NewRoutingRuleID_FK],
             [ChangeReason],[ApprovedByUserID_FK],[EffectiveFromDate])
        VALUES
            (@ServiceID, @IdaraID, @OldRuleID, @NewRuleID, @ChangeReason, @PerformedByUserID, @EffectiveFrom);

        COMMIT TRAN;
        SELECT @NewRuleID AS ServiceRoutingRuleID;
        RETURN;
    END

    -- CLOSE_ROUTING_RULE
    IF @Action = 'CLOSE_ROUTING_RULE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ServiceRoutingRule]
        SET [EffectiveTo] = CAST(GETDATE() AS DATE), [IsActive] = 0,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [ServiceRoutingRuleID] = @RoutingRuleID;
        COMMIT TRAN;
        RETURN;
    END

    -- UPSERT_SLA_POLICY
    IF @Action = 'UPSERT_SLA_POLICY'
    BEGIN
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM [Tickets].[ServiceSLAPolicy]
                   WHERE [ServiceID_FK] = @ServiceID AND [PriorityID_FK] = @PriorityID AND [IsActive] = 1)
        BEGIN
            UPDATE [Tickets].[ServiceSLAPolicy]
            SET [FirstResponseTargetMinutes] = @FirstResponseTargetMin,
                [AssignmentTargetMinutes] = @AssignmentTargetMin,
                [OperationalCompletionTargetMinutes] = @OperationalCompletionMin,
                [FinalClosureTargetMinutes] = @FinalClosureTargetMin,
                [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
            WHERE [ServiceID_FK] =

            --------------------------------
            --------------------------------
            --------------------------------
            --------------------------------
            --------------------------------
            --------------------------------
            --------------------------------
            -- ============================================================================
-- CONTINUING FROM ServiceSP - UPSERT_SLA_POLICY
-- ============================================================================

-- (Completing the UPSERT_SLA_POLICY action)
CREATE OR ALTER PROCEDURE [Tickets].[ServiceSP]
    @Action                     NVARCHAR(100),
    @ServiceID                  BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @ServiceCode                NVARCHAR(50)    = NULL,
    @ServiceNameAR              NVARCHAR(500)   = NULL,
    @ServiceNameEN              NVARCHAR(500)   = NULL,
    @ServiceDescriptionAR       NVARCHAR(2000)  = NULL,
    @ServiceDescriptionEN       NVARCHAR(2000)  = NULL,
    @TicketClassID              INT             = NULL,
    @DefaultPriorityID          INT             = NULL,
    @RequiresLocation           BIT             = 0,
    @RequiresQualityReview      BIT             = 0,
    @TargetDSDID                BIGINT          = NULL,
    @QueueDistributorID         BIGINT          = NULL,
    @EffectiveFrom              DATE            = NULL,
    @EffectiveTo                DATE            = NULL,
    @ChangeReason               NVARCHAR(1000)  = NULL,
    @PriorityID                 INT             = NULL,
    @FirstResponseTargetMin     INT             = NULL,
    @AssignmentTargetMin        INT             = NULL,
    @OperationalCompletionMin   INT             = NULL,
    @FinalClosureTargetMin      INT             = NULL,
    @SuggestionID               BIGINT          = NULL,
    @RejectionReason            NVARCHAR(1000)  = NULL,
    @RoutingRuleID              BIGINT          = NULL,
    @ProposedServiceNameAR      NVARCHAR(500)   = NULL,
    @ProposedServiceNameEN      NVARCHAR(500)   = NULL,
    @ProposedDescription        NVARCHAR(2000)  = NULL,
    @ProposedTargetDSDID        BIGINT          = NULL,
    @ProposedPriorityID         INT             = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== INSERT_SERVICE ==========
    IF @Action = 'INSERT_SERVICE'
    BEGIN
        BEGIN TRAN;
        INSERT INTO [Tickets].[Service]
            ([IdaraID_FK],[ServiceCode],[ServiceNameAR],[ServiceNameEN],
             [ServiceDescriptionAR],[ServiceDescriptionEN],[TicketClassID_FK],
             [DefaultPriorityID_FK],[RequiresLocation],[RequiresQualityReview],[CreatedBy])
        VALUES
            (@IdaraID,@ServiceCode,@ServiceNameAR,@ServiceNameEN,
             @ServiceDescriptionAR,@ServiceDescriptionEN,@TicketClassID,
             @DefaultPriorityID,@RequiresLocation,@RequiresQualityReview,@PerformedByUserID);
        DECLARE @NewServiceID BIGINT = SCOPE_IDENTITY();
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Service','INSERT_SERVICE',@NewServiceID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewServiceID AS ServiceID,@ServiceCode AS Code FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewServiceID AS ServiceID;
        RETURN;
    END

    -- ========== UPDATE_SERVICE ==========
    IF @Action = 'UPDATE_SERVICE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[Service]
        SET [ServiceNameAR]=ISNULL(@ServiceNameAR,[ServiceNameAR]),
            [ServiceNameEN]=ISNULL(@ServiceNameEN,[ServiceNameEN]),
            [ServiceDescriptionAR]=ISNULL(@ServiceDescriptionAR,[ServiceDescriptionAR]),
            [ServiceDescriptionEN]=ISNULL(@ServiceDescriptionEN,[ServiceDescriptionEN]),
            [TicketClassID_FK]=ISNULL(@TicketClassID,[TicketClassID_FK]),
            [DefaultPriorityID_FK]=ISNULL(@DefaultPriorityID,[DefaultPriorityID_FK]),
            [RequiresLocation]=@RequiresLocation,
            [RequiresQualityReview]=@RequiresQualityReview,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceID]=@ServiceID;
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Service','UPDATE_SERVICE',@ServiceID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ServiceID AS ServiceID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== DELETE_SERVICE (soft) ==========
    IF @Action = 'DELETE_SERVICE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[Service]
        SET [IsDeleted]=1,[IsActive]=0,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceID]=@ServiceID;
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Service','DELETE_SERVICE',@ServiceID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ServiceID AS ServiceID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== INSERT_ROUTING_RULE ==========
    IF @Action = 'INSERT_ROUTING_RULE'
    BEGIN
        IF @TargetDSDID IS NULL
            THROW 50001,'TargetDSDID_FK is mandatory for routing rules (BR-04).',1;
        BEGIN TRAN;
        DECLARE @OldRuleID_Insert BIGINT;
        SELECT @OldRuleID_Insert = [ServiceRoutingRuleID]
        FROM [Tickets].[ServiceRoutingRule]
        WHERE [ServiceID_FK]=@ServiceID AND [IsActive]=1;

        UPDATE [Tickets].[ServiceRoutingRule]
        SET [EffectiveTo]=DATEADD(DAY,-1,@EffectiveFrom),[IsActive]=0,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceID_FK]=@ServiceID AND [IsActive]=1;

        INSERT INTO [Tickets].[ServiceRoutingRule]
            ([ServiceID_FK],[IdaraID_FK],[TargetDSDID_FK],[QueueDistributorID_FK],
             [EffectiveFrom],[EffectiveTo],[ChangeReason],[ApprovedBy],[ApprovedDate],[CreatedBy])
        VALUES(@ServiceID,@IdaraID,@TargetDSDID,@QueueDistributorID,
             @EffectiveFrom,@EffectiveTo,@ChangeReason,@PerformedByUserID,SYSUTCDATETIME(),@PerformedByUserID);
        DECLARE @NewRuleID_Insert BIGINT = SCOPE_IDENTITY();

        INSERT INTO [Tickets].[CatalogRoutingChangeLog]
            ([ServiceID_FK],[IdaraID_FK],[OldRoutingRuleID_FK],[NewRoutingRuleID_FK],
             [ChangeReason],[ApprovedByUserID_FK],[EffectiveFromDate])
        VALUES(@ServiceID,@IdaraID,@OldRuleID_Insert,@NewRuleID_Insert,@ChangeReason,@PerformedByUserID,@EffectiveFrom);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ServiceRoutingRule','INSERT_ROUTING_RULE',@NewRuleID_Insert,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ServiceID AS ServiceID,@TargetDSDID AS TargetDSDID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewRuleID_Insert AS ServiceRoutingRuleID;
        RETURN;
    END

    -- ========== CLOSE_ROUTING_RULE ==========
    IF @Action = 'CLOSE_ROUTING_RULE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ServiceRoutingRule]
        SET [EffectiveTo]=CAST(GETDATE() AS DATE),[IsActive]=0,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceRoutingRuleID]=@RoutingRuleID;
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ServiceRoutingRule','CLOSE_ROUTING_RULE',@RoutingRuleID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @RoutingRuleID AS RuleID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== UPSERT_SLA_POLICY ==========
    IF @Action = 'UPSERT_SLA_POLICY'
    BEGIN
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM [Tickets].[ServiceSLAPolicy]
                   WHERE [ServiceID_FK]=@ServiceID AND [PriorityID_FK]=@PriorityID AND [IsActive]=1)
        BEGIN
            UPDATE [Tickets].[ServiceSLAPolicy]
            SET [FirstResponseTargetMinutes]=@FirstResponseTargetMin,
                [AssignmentTargetMinutes]=@AssignmentTargetMin,
                [OperationalCompletionTargetMinutes]=@OperationalCompletionMin,
                [FinalClosureTargetMinutes]=@FinalClosureTargetMin,
                [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
            WHERE [ServiceID_FK]=@ServiceID AND [PriorityID_FK]=@PriorityID AND [IsActive]=1;
        END
        ELSE
        BEGIN
            INSERT INTO [Tickets].[ServiceSLAPolicy]
                ([ServiceID_FK],[IdaraID_FK],[PriorityID_FK],[FirstResponseTargetMinutes],
                 [AssignmentTargetMinutes],[OperationalCompletionTargetMinutes],
                 [FinalClosureTargetMinutes],[EffectiveFrom],[CreatedBy])
            VALUES(@ServiceID,@IdaraID,@PriorityID,@FirstResponseTargetMin,
                 @AssignmentTargetMin,@OperationalCompletionMin,
                 @FinalClosureTargetMin,ISNULL(@EffectiveFrom,CAST(GETDATE() AS DATE)),@PerformedByUserID);
        END
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ServiceSLAPolicy','UPSERT_SLA_POLICY',@ServiceID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ServiceID AS ServiceID,@PriorityID AS PriorityID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== APPROVE_SERVICE_SUGGESTION ==========
    IF @Action = 'APPROVE_SERVICE_SUGGESTION'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ServiceCatalogSuggestion]
        SET [ApprovalStatus]='APPROVED',[ApprovedBy]=@PerformedByUserID,[ApprovedDate]=SYSUTCDATETIME(),
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceCatalogSuggestionID]=@SuggestionID;
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ServiceCatalogSuggestion','APPROVE_SERVICE_SUGGESTION',@SuggestionID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @SuggestionID AS SuggestionID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== REJECT_SERVICE_SUGGESTION ==========
    IF @Action = 'REJECT_SERVICE_SUGGESTION'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ServiceCatalogSuggestion]
        SET [ApprovalStatus]='REJECTED',[RejectionReason]=@RejectionReason,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ServiceCatalogSuggestionID]=@SuggestionID;
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ServiceCatalogSuggestion','REJECT_SERVICE_SUGGESTION',@SuggestionID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @SuggestionID AS SuggestionID,@RejectionReason AS Reason FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000,'Unknown @Action for ServiceSP.',1;
END
GO

-- ============================================================================
-- 6.2 TicketSP
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[TicketSP]
    @Action                     NVARCHAR(100),
    @TicketID                   BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @ServiceID                  BIGINT          = NULL,
    @TicketClassID              INT             = NULL,
    @RequesterTypeID            INT             = NULL,
    @RequesterUserID            BIGINT          = NULL,
    @RequesterResidentID        BIGINT          = NULL,
    @Title                      NVARCHAR(500)   = NULL,
    @Description                NVARCHAR(4000)  = NULL,
    @SuggestedPriorityID        INT             = NULL,
    @EffectivePriorityID        INT             = NULL,
    @CurrentDSDID               BIGINT          = NULL,
    @CurrentQueueDistributorID  BIGINT          = NULL,
    @AssignedUserID             BIGINT          = NULL,
    @LocationBuilding           NVARCHAR(200)   = NULL,
    @LocationFloor              NVARCHAR(100)   = NULL,
    @LocationRoom               NVARCHAR(100)   = NULL,
    @LocationNotes              NVARCHAR(500)   = NULL,
    @ParentTicketID             BIGINT          = NULL,
    @IsOtherService             BIT             = 0,
    @PauseReasonID              INT             = NULL,
    @PauseNotes                 NVARCHAR(2000)  = NULL,
    @RelatedChildTicketID       BIGINT          = NULL,
    @RelatedArbitrationCaseID   BIGINT          = NULL,
    @RelatedClarificationID     BIGINT          = NULL,
    @Notes                      NVARCHAR(4000)  = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== INSERT_TICKET ==========
    IF @Action = 'INSERT_TICKET'
    BEGIN
        -- BR-01: Requester exclusivity
        IF @RequesterUserID IS NOT NULL AND @RequesterResidentID IS NOT NULL
            THROW 50010,'A ticket requester can be either resident or internal user, not both (BR-01).',1;
        -- BR-02: Other tickets may lack ServiceID
        IF @IsOtherService = 0 AND @ServiceID IS NULL
            THROW 50011,'Known-service tickets must have a ServiceID_FK.',1;

        BEGIN TRAN;

        -- Generate ticket number
        DECLARE @TicketNo NVARCHAR(50);
        DECLARE @SeqNum BIGINT;
        SELECT @SeqNum = ISNULL(MAX([TicketID]),0)+1 FROM [Tickets].[Ticket];
        SET @TicketNo = 'TKT-' + RIGHT('000000'+CAST(@SeqNum AS NVARCHAR),6);

        -- Resolve routing from service catalogue if not Other
        DECLARE @ResolvedDSDID BIGINT = @CurrentDSDID;
        DECLARE @ResolvedQueueDistID BIGINT = @CurrentQueueDistributorID;
        IF @IsOtherService = 0 AND @ServiceID IS NOT NULL AND @ResolvedDSDID IS NULL
        BEGIN
            SELECT TOP 1
                @ResolvedDSDID = [TargetDSDID_FK],
                @ResolvedQueueDistID = [QueueDistributorID_FK]
            FROM [Tickets].[ServiceRoutingRule]
            WHERE [ServiceID_FK]=@ServiceID AND [IsActive]=1
              AND [EffectiveFrom]<=CAST(GETDATE() AS DATE)
              AND ([EffectiveTo] IS NULL OR [EffectiveTo]>=CAST(GETDATE() AS DATE));
        END

        -- Resolve effective priority from service default if not provided
        DECLARE @FinalPriorityID INT = @EffectivePriorityID;
        IF @FinalPriorityID IS NULL AND @ServiceID IS NOT NULL
            SELECT @FinalPriorityID = [DefaultPriorityID_FK] FROM [Tickets].[Service] WHERE [ServiceID]=@ServiceID;
        IF @FinalPriorityID IS NULL
            SET @FinalPriorityID = @SuggestedPriorityID;

        -- Resolve requires quality review from service
        DECLARE @ReqQR BIT = 0;
        IF @ServiceID IS NOT NULL
            SELECT @ReqQR = ISNULL([RequiresQualityReview],0) FROM [Tickets].[Service] WHERE [ServiceID]=@ServiceID;

        -- Get NEW status ID
        DECLARE @NewStatusID INT;
        SELECT @NewStatusID = [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='NEW';

        INSERT INTO [Tickets].[Ticket]
            ([TicketNo],[IdaraID_FK],[ParentTicketID_FK],[RootTicketID_FK],[ServiceID_FK],
             [TicketClassID_FK],[RequesterTypeID_FK],[RequesterUserID_FK],[RequesterResidentID_FK],
             [Title],[Description],[SuggestedPriorityID_FK],[EffectivePriorityID_FK],
             [TicketStatusID_FK],[CurrentDSDID_FK],[CurrentQueueDistributorID_FK],
             [LocationBuilding],[LocationFloor],[LocationRoom],[LocationNotes],
             [IsOtherService],[RequiresQualityReview],[CreatedBy])
        VALUES
            (@TicketNo,@IdaraID,NULL,NULL,@ServiceID,
             @TicketClassID,@RequesterTypeID,@RequesterUserID,@RequesterResidentID,
             @Title,@Description,@SuggestedPriorityID,@FinalPriorityID,
             @NewStatusID,@ResolvedDSDID,@ResolvedQueueDistID,
             @LocationBuilding,@LocationFloor,@LocationRoom,@LocationNotes,
             @IsOtherService,@ReqQR,@PerformedByUserID);

        DECLARE @NewTicketID BIGINT = SCOPE_IDENTITY();

        -- Root ticket = self for top-level tickets
        UPDATE [Tickets].[Ticket] SET [RootTicketID_FK]=@NewTicketID WHERE [TicketID]=@NewTicketID;

        -- TicketHistory
        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[NewStatusID_FK],[NewDSDID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@NewTicketID,@IdaraID,'TICKET_CREATED',@NewStatusID,@ResolvedDSDID,@PerformedByUserID,'Ticket created');

        -- Audit
        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','INSERT_TICKET',@NewTicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewTicketID AS TicketID,@TicketNo AS TicketNo FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));

        COMMIT TRAN;
        SELECT @NewTicketID AS TicketID, @TicketNo AS TicketNo;
        RETURN;
    END

    -- ========== ASSIGN_TICKET ==========
    IF @Action = 'ASSIGN_TICKET'
    BEGIN
        -- BR-06: Validate assignment eligibility through UserDistributor
        IF NOT EXISTS (SELECT 1 FROM [dbo].[UserDistributor]
                       WHERE [UserID]=@AssignedUserID AND [DistributorID]=@CurrentQueueDistributorID AND [IsActive]=1)
            THROW 50020,'User is not eligible for assignment in this organizational scope (BR-06).',1;

        BEGIN TRAN;
        DECLARE @OldStatusAssign INT, @OldUserAssign BIGINT;
        SELECT @OldStatusAssign=[TicketStatusID_FK], @OldUserAssign=[AssignedUserID_FK]
        FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;

        DECLARE @AssignedStatusID INT;
        SELECT @AssignedStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='ASSIGNED';

        UPDATE [Tickets].[Ticket]
        SET [AssignedUserID_FK]=@AssignedUserID,[TicketStatusID_FK]=@AssignedStatusID,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],
             [OldAssignedUserID_FK],[NewAssignedUserID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'TICKET_ASSIGNED',@OldStatusAssign,@AssignedStatusID,
             @OldUserAssign,@AssignedUserID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','ASSIGN_TICKET',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID,@AssignedUserID AS AssignedTo FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== MOVE_TO_IN_PROGRESS ==========
    IF @Action = 'MOVE_TO_IN_PROGRESS'
    BEGIN
        BEGIN TRAN;
        DECLARE @OldStatusIP INT;
        SELECT @OldStatusIP=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @InProgressStatusID INT;
        SELECT @InProgressStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='IN_PROGRESS';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@InProgressStatusID,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'MOVED_TO_IN_PROGRESS',@OldStatusIP,@InProgressStatusID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','MOVE_TO_IN_PROGRESS',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== REJECT_TO_SUPERVISOR ==========
    IF @Action = 'REJECT_TO_SUPERVISOR'
    BEGIN
        -- BR-07: Execution user rejects to supervisor only, never directly to arbitration
        BEGIN TRAN;
        DECLARE @OldStatusReject INT;
        SELECT @OldStatusReject=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @RejectedStatusID INT;
        SELECT @RejectedStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='REJECTED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@RejectedStatusID,[AssignedUserID_FK]=NULL,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],
             [OldAssignedUserID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'REJECTED_TO_SUPERVISOR',@OldStatusReject,@RejectedStatusID,
             @PerformedByUserID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','REJECT_TO_SUPERVISOR',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== CREATE_CHILD_TICKET ==========
    IF @Action = 'CREATE_CHILD_TICKET'
    BEGIN
        -- BR-10: A child ticket belongs to one parent only
        DECLARE @RootID BIGINT;
        SELECT @RootID=[RootTicketID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@ParentTicketID;
        IF @RootID IS NULL SET @RootID=@ParentTicketID;

        BEGIN TRAN;
        DECLARE @ChildTicketNo NVARCHAR(50);
        DECLARE @ChildSeq BIGINT;
        SELECT @ChildSeq=ISNULL(MAX([TicketID]),0)+1 FROM [Tickets].[Ticket];
        SET @ChildTicketNo='TKT-'+RIGHT('000000'+CAST(@ChildSeq AS NVARCHAR),6);

        DECLARE @ChildNewStatusID INT;
        SELECT @ChildNewStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='NEW';

        INSERT INTO [Tickets].[Ticket]
            ([TicketNo],[IdaraID_FK],[ParentTicketID_FK],[RootTicketID_FK],[ServiceID_FK],
             [TicketClassID_FK],[RequesterTypeID_FK],[RequesterUserID_FK],
             [Title],[Description],[EffectivePriorityID_FK],[TicketStatusID_FK],
             [CurrentDSDID_FK],[CurrentQueueDistributorID_FK],[IsOtherService],[CreatedBy])
        VALUES
            (@ChildTicketNo,@IdaraID,@ParentTicketID,@RootID,@ServiceID,
             @TicketClassID,@RequesterTypeID,@PerformedByUserID,
             @Title,@Description,@EffectivePriorityID,@ChildNewStatusID,
             @CurrentDSDID,@CurrentQueueDistributorID,ISNULL(@IsOtherService,0),@PerformedByUserID);

        DECLARE @ChildTicketID BIGINT = SCOPE_IDENTITY();

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@ChildTicketID,@IdaraID,'CHILD_TICKET_CREATED',@ChildNewStatusID,@PerformedByUserID,
            'Child of TKT '+CAST(@ParentTicketID AS NVARCHAR));

        -- Also log on parent
        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[PerformedByUserID_FK],[Notes])
        VALUES(@ParentTicketID,@IdaraID,'CHILD_TICKET_LINKED',@PerformedByUserID,
            'Child TKT-'+CAST(@ChildTicketID AS NVARCHAR)+' created');

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','CREATE_CHILD_TICKET',@ChildTicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ChildTicketID AS ChildID,@ParentTicketID AS ParentID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @ChildTicketID AS TicketID, @ChildTicketNo AS TicketNo;
        RETURN;
    END

    -- ========== PAUSE_TICKET ==========
    IF @Action = 'PAUSE_TICKET'
    BEGIN
        BEGIN TRAN;
        DECLARE @OldStatusPause INT;
        SELECT @OldStatusPause=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @OnHoldStatusID INT;
        SELECT @OnHoldStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='ON_HOLD';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@OnHoldStatusID,[IsParentBlocked]=CASE WHEN @RelatedChildTicketID IS NOT NULL THEN 1 ELSE [IsParentBlocked] END,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketPauseSession]
            ([TicketID_FK],[IdaraID_FK],[PauseReasonID_FK],[RelatedChildTicketID_FK],
             [RelatedArbitrationCaseID_FK],[RelatedClarificationRequestID_FK],[ShouldPauseSLA],[Notes],[CreatedBy])
        VALUES(@TicketID,@IdaraID,@PauseReasonID,@RelatedChildTicketID,
             @RelatedArbitrationCaseID,@RelatedClarificationID,1,@PauseNotes,@PerformedByUserID);

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'TICKET_PAUSED',@OldStatusPause,@OnHoldStatusID,@PerformedByUserID,@PauseNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','PAUSE_TICKET',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID,@PauseReasonID AS ReasonID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== RESUME_TICKET ==========
    IF @Action = 'RESUME_TICKET'
    BEGIN
        BEGIN TRAN;
        DECLARE @OldStatusResume INT;
        SELECT @OldStatusResume=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @IPStatusResume INT;
        SELECT @IPStatusResume=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='IN_PROGRESS';

        -- Close open pause sessions
        UPDATE [Tickets].[TicketPauseSession]
        SET [PauseEndDate]=SYSUTCDATETIME(),[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID_FK]=@TicketID AND [PauseEndDate] IS NULL;

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@IPStatusResume,[IsParentBlocked]=0,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'TICKET_RESUMED',@OldStatusResume,@IPStatusResume,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','RESUME_TICKET',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== RESOLVE_OPERATIONALLY ==========
    IF @Action = 'RESOLVE_OPERATIONALLY'
    BEGIN
        -- BR-12: Cannot resolve if blocking children are open
        IF EXISTS (SELECT 1 FROM [Tickets].[Ticket]
                   WHERE [ParentTicketID_FK]=@TicketID
                   AND [TicketStatusID_FK] NOT IN (SELECT [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode] IN ('CLOSED','CANCELLED')))
            THROW 50030,'Cannot resolve: open child tickets still exist (BR-12).',1;

        BEGIN TRAN;
        DECLARE @OldStatusResolve INT;
        SELECT @OldStatusResolve=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @ResolvedStatusID INT;
        SELECT @ResolvedStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='RESOLVED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@ResolvedStatusID,[OperationalResolvedDate]=SYSUTCDATETIME(),
            [OperationalResolvedBy]=@PerformedByUserID,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'RESOLVED_OPERATIONALLY',@OldStatusResolve,@ResolvedStatusID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','RESOLVE_OPERATIONALLY',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== CLOSE_TICKET ==========
    IF @Action = 'CLOSE_TICKET'
    BEGIN
        BEGIN TRAN;
        DECLARE @OldStatusClose INT;
        SELECT @OldStatusClose=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @ClosedStatusID INT;
        SELECT @ClosedStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='CLOSED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@ClosedStatusID,[FinalClosedDate]=SYSUTCDATETIME(),
            [FinalClosedBy]=@PerformedByUserID,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'TICKET_CLOSED',@OldStatusClose,@ClosedStatusID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','CLOSE_TICKET',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== REOPEN_TICKET ==========
    IF @Action = 'REOPEN_TICKET'
    BEGIN
        BEGIN TRAN;
        DECLARE @OldStatusReopen INT;
        SELECT @OldStatusReopen=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @ReopenedStatusID INT;
        SELECT @ReopenedStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='REOPENED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@ReopenedStatusID,[FinalClosedDate]=NULL,[FinalClosedBy]=NULL,
            [OperationalResolvedDate]=NULL,[OperationalResolvedBy]=NULL,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'TICKET_REOPENED',@OldStatusReopen,@ReopenedStatusID,@PerformedByUserID,@Notes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.Ticket','REOPEN_TICKET',@TicketID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000,'Unknown @Action for TicketSP.',1;
END
GO

-- ============================================================================
-- 6.3 ArbitrationSP
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[ArbitrationSP]
    @Action                     NVARCHAR(100),
    @ArbitrationCaseID          BIGINT          = NULL,
    @TicketID                   BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @RaisedByUserID             BIGINT          = NULL,
    @RaisedFromDSDID            BIGINT          = NULL,
    @ArbitrationReasonID        INT             = NULL,
    @ArbitratorDistributorID    BIGINT          = NULL,
    @DecisionType               NVARCHAR(50)    = NULL,
    @DecisionTargetDSDID        BIGINT          = NULL,
    @DecisionNotes              NVARCHAR(2000)  = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== OPEN_ARBITRATION_CASE ==========
    IF @Action = 'OPEN_ARBITRATION_CASE'
    BEGIN
        BEGIN TRAN;
        INSERT INTO [Tickets].[ArbitrationCase]
            ([TicketID_FK],[IdaraID_FK],[RaisedByUserID_FK],[RaisedFromDSDID_FK],
             [ArbitrationReasonID_FK],[ArbitratorDistributorID_FK],[Status],[CreatedBy])
        VALUES(@TicketID,@IdaraID,@RaisedByUserID,@RaisedFromDSDID,
             @ArbitrationReasonID,@ArbitratorDistributorID,'OPEN',@PerformedByUserID);
        DECLARE @NewCaseID BIGINT = SCOPE_IDENTITY();

        -- Update ticket status to IN_ARBITRATION
        DECLARE @OldStatusArb INT;
        SELECT @OldStatusArb=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @ArbStatusID INT;
        SELECT @ArbStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='IN_ARBITRATION';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@ArbStatusID,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'ARBITRATION_OPENED',@OldStatusArb,@ArbStatusID,@PerformedByUserID,
            'Arbitration case '+CAST(@NewCaseID AS NVARCHAR)+' opened');

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ArbitrationCase','OPEN_ARBITRATION_CASE',@NewCaseID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewCaseID AS CaseID,@TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewCaseID AS ArbitrationCaseID;
        RETURN;
    END

    -- ========== DECIDE_REDIRECT ==========
    IF @Action = 'DECIDE_REDIRECT'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ArbitrationCase]
        SET [Status]='DECIDED',[DecisionType]='REDIRECT',[DecisionTargetDSDID_FK]=@DecisionTargetDSDID,
            [DecisionNotes]=@DecisionNotes,[DecisionDate]=SYSUTCDATETIME(),[DecisionBy]=@PerformedByUserID,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ArbitrationCaseID]=@ArbitrationCaseID;

        -- Redirect ticket
        DECLARE @OldDSDRedirect BIGINT;
        SELECT @OldDSDRedirect=[CurrentDSDID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @OpenStatusID INT;
        SELECT @OpenStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='OPEN';

        UPDATE [Tickets].[Ticket]
        SET [CurrentDSDID_FK]=@DecisionTargetDSDID,[TicketStatusID_FK]=@OpenStatusID,
            [AssignedUserID_FK]=NULL,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldDSDID_FK],[NewDSDID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'ARBITRATION_REDIRECT',@OldDSDRedirect,@DecisionTargetDSDID,@PerformedByUserID,@DecisionNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ArbitrationCase','DECIDE_REDIRECT',@ArbitrationCaseID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ArbitrationCaseID AS CaseID,@DecisionTargetDSDID AS NewDSD FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== DECIDE_OVERRULE ==========
    IF @Action = 'DECIDE_OVERRULE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ArbitrationCase]
        SET [Status]='DECIDED',[DecisionType]='OVERRULE',
            [DecisionNotes]=@DecisionNotes,[DecisionDate]=SYSUTCDATETIME(),[DecisionBy]=@PerformedByUserID,
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ArbitrationCaseID]=@ArbitrationCaseID;

        -- Return ticket to original scope
        DECLARE @OverruleOpenStatusID INT;
        SELECT @OverruleOpenStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='OPEN';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@OverruleOpenStatusID,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'ARBITRATION_OVERRULED',@PerformedByUserID,@DecisionNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ArbitrationCase','DECIDE_OVERRULE',@ArbitrationCaseID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ArbitrationCaseID AS CaseID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== CANCEL_ARBITRATION_CASE ==========
    IF @Action = 'CANCEL_ARBITRATION_CASE'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ArbitrationCase]
        SET [Status]='CANCELLED',[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ArbitrationCaseID]=@ArbitrationCaseID;

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ArbitrationCase','CANCEL_ARBITRATION_CASE',@ArbitrationCaseID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ArbitrationCaseID AS CaseID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000,'Unknown @Action for ArbitrationSP.',1;
END
GO

-- ============================================================================
-- 6.4 ClarificationSP
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[ClarificationSP]
    @Action                     NVARCHAR(100),
    @ClarificationRequestID     BIGINT          = NULL,
    @TicketID                   BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @RequestedByUserID          BIGINT          = NULL,
    @RequestedFromUserID        BIGINT          = NULL,
    @RequestedFromDSDID         BIGINT          = NULL,
    @ClarificationReasonID      INT             = NULL,
    @RequestNotes               NVARCHAR(4000)  = NULL,
    @ResponseNotes              NVARCHAR(4000)  = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== OPEN_CLARIFICATION_REQUEST ==========
    IF @Action = 'OPEN_CLARIFICATION_REQUEST'
    BEGIN
        BEGIN TRAN;
        INSERT INTO [Tickets].[ClarificationRequest]
            ([TicketID_FK],[IdaraID_FK],[RequestedByUserID_FK],[RequestedFromUserID_FK],
             [RequestedFromDSDID_FK],[ClarificationReasonID_FK],[RequestNotes],[Status],[CreatedBy])
        VALUES(@TicketID,@IdaraID,@RequestedByUserID,@RequestedFromUserID,
             @RequestedFromDSDID,@ClarificationReasonID,@RequestNotes,'OPEN',@PerformedByUserID);
        DECLARE @NewClarID BIGINT = SCOPE_IDENTITY();

        DECLARE @OldStatusClar INT;
        SELECT @OldStatusClar=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;
        DECLARE @PendClarStatusID INT;
        SELECT @PendClarStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='PENDING_CLARIFICATION';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@PendClarStatusID,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'CLARIFICATION_OPENED',@OldStatusClar,@PendClarStatusID,@PerformedByUserID,@RequestNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ClarificationRequest','OPEN_CLARIFICATION_REQUEST',@NewClarID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewClarID AS ClarID,@TicketID AS TicketID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewClarID AS ClarificationRequestID;
        RETURN;
    END

    -- ========== RESPOND_TO_CLARIFICATION ==========
    IF @Action = 'RESPOND_TO_CLARIFICATION'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ClarificationRequest]
        SET [ResponseNotes]=@ResponseNotes,[ResponseDate]=SYSUTCDATETIME(),
            [RespondedByUserID_FK]=@PerformedByUserID,[Status]='RESPONDED',
            [ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ClarificationRequestID]=@ClarificationRequestID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'CLARIFICATION_RESPONDED',@PerformedByUserID,@ResponseNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ClarificationRequest','RESPOND_TO_CLARIFICATION',@ClarificationRequestID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ClarificationRequestID AS ClarID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== CLOSE_CLARIFICATION_REQUEST ==========
    IF @Action = 'CLOSE_CLARIFICATION_REQUEST'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[ClarificationRequest]
        SET [Status]='CLOSED',[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [ClarificationRequestID]=@ClarificationRequestID;

        -- Return ticket to previous working status
        DECLARE @IPStatusClarClose INT;
        SELECT @IPStatusClarClose=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='IN_PROGRESS';

        DECLARE @OldStatusClarClose INT;
        SELECT @OldStatusClarClose=[TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID]=@TicketID;

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@IPStatusClarClose,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'CLARIFICATION_CLOSED',@OldStatusClarClose,@IPStatusClarClose,@PerformedByUserID,'Clarification resolved');

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.ClarificationRequest','CLOSE_CLARIFICATION_REQUEST',@ClarificationRequestID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @ClarificationRequestID AS ClarID FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000,'Unknown @Action for ClarificationSP.',1;
END
GO

-- ============================================================================
-- 6.5 QualityReviewSP
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[QualityReviewSP]
    @Action                     NVARCHAR(100),
    @QualityReviewID            BIGINT          = NULL,
    @TicketID                   BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @ReviewerUserID             BIGINT          = NULL,
    @ReviewScope                NVARCHAR(500)   = NULL,
    @QualityReviewResultID      INT             = NULL,
    @ReviewNotes                NVARCHAR(4000)  = NULL,
    @ReturnToUserID             BIGINT          = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== OPEN_QUALITY_REVIEW ==========
    IF @Action = 'OPEN_QUALITY_REVIEW'
    BEGIN
        -- BR-14: Cannot start before operational resolution
        DECLARE @TicketStatus NVARCHAR(50);
        SELECT @TicketStatus=ts.[StatusCode]
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK]=ts.[TicketStatusID]
        WHERE t.[TicketID]=@TicketID;

        IF @TicketStatus NOT IN ('RESOLVED','PENDING_QA')
            THROW 50040,'Quality review cannot start before operational resolution (BR-14).',1;

        BEGIN TRAN;
        INSERT INTO [Tickets].[QualityReview]
            ([TicketID_FK],[IdaraID_FK],[ReviewerUserID_FK],[ReviewScope],[CreatedBy])
        VALUES(@TicketID,@IdaraID,@ReviewerUserID,@ReviewScope,@PerformedByUserID);
        DECLARE @NewQRID BIGINT = SCOPE_IDENTITY();

        DECLARE @PendQAStatusID INT;
        SELECT @PendQAStatusID=[TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode]='PENDING_QA';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK]=@PendQAStatusID,[ModifiedBy]=@PerformedByUserID,[ModifiedDate]=SYSUTCDATETIME()
        WHERE [TicketID]=@TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES(@TicketID,@IdaraID,'QUALITY_REVIEW_OPENED',@PendQAStatusID,@PerformedByUserID,'Quality review started');

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES('Tickets.QualityReview','OPEN_QUALITY_REVIEW',@NewQRID,@PerformedByUserID,SYSUTCDATETIME(),
            (SELECT @NewQR





            -- ============================================================================
-- 6.5 QualityReviewSP (CONTINUED)
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[QualityReviewSP]
    @Action                     NVARCHAR(100),
    @QualityReviewID            BIGINT          = NULL,
    @TicketID                   BIGINT          = NULL,
    @IdaraID                    BIGINT          = NULL,
    @ReviewerUserID             BIGINT          = NULL,
    @ReviewScope                NVARCHAR(500)   = NULL,
    @QualityReviewResultID      INT             = NULL,
    @ReviewNotes                NVARCHAR(4000)  = NULL,
    @ReturnToUserID             BIGINT          = NULL,
    @PerformedByUserID          BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== OPEN_QUALITY_REVIEW ==========
    IF @Action = 'OPEN_QUALITY_REVIEW'
    BEGIN
        -- BR-14: Cannot start before operational resolution
        DECLARE @CurrentStatus NVARCHAR(50);
        SELECT @CurrentStatus = ts.[StatusCode]
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
        WHERE t.[TicketID] = @TicketID;

        IF @CurrentStatus NOT IN ('RESOLVED','PENDING_QA')
            THROW 50040, 'Quality review cannot start before operational resolution (BR-14).', 1;

        BEGIN TRAN;
        INSERT INTO [Tickets].[QualityReview]
            ([TicketID_FK],[IdaraID_FK],[ReviewerUserID_FK],[ReviewScope],[CreatedBy])
        VALUES (@TicketID, @IdaraID, @ReviewerUserID, @ReviewScope, @PerformedByUserID);
        DECLARE @NewQRID BIGINT = SCOPE_IDENTITY();

        DECLARE @PendQAStatusID INT;
        SELECT @PendQAStatusID = [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode] = 'PENDING_QA';

        DECLARE @OldStatusQR INT;
        SELECT @OldStatusQR = [TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID] = @TicketID;

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK] = @PendQAStatusID,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketID] = @TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES (@TicketID, @IdaraID, 'QUALITY_REVIEW_OPENED', @OldStatusQR, @PendQAStatusID, @PerformedByUserID, 'Quality review started');

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.QualityReview','OPEN_QUALITY_REVIEW', @NewQRID, @PerformedByUserID, SYSUTCDATETIME(),
            (SELECT @NewQRID AS QRID, @TicketID AS TicketID FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewQRID AS QualityReviewID;
        RETURN;
    END

    -- ========== APPROVE_FINAL_CLOSURE ==========
    IF @Action = 'APPROVE_FINAL_CLOSURE'
    BEGIN
        BEGIN TRAN;
        DECLARE @ApproveResultID INT;
        SELECT @ApproveResultID = [QualityReviewResultID] FROM [Tickets].[QualityReviewResult] WHERE [ResultCode] = 'APPROVED';

        UPDATE [Tickets].[QualityReview]
        SET [QualityReviewResultID_FK] = @ApproveResultID,
            [ReviewNotes] = @ReviewNotes, [ReviewDate] = SYSUTCDATETIME(),
            [IsFinalized] = 1,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [QualityReviewID] = @QualityReviewID;

        -- Close the ticket (final closure)
        DECLARE @OldStatusApprove INT;
        SELECT @OldStatusApprove = [TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID] = @TicketID;
        DECLARE @ClosedStatusApprove INT;
        SELECT @ClosedStatusApprove = [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode] = 'CLOSED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK] = @ClosedStatusApprove,
            [FinalClosedDate] = SYSUTCDATETIME(), [FinalClosedBy] = @PerformedByUserID,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketID] = @TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES (@TicketID, @IdaraID, 'FINAL_CLOSURE_APPROVED', @OldStatusApprove, @ClosedStatusApprove, @PerformedByUserID, @ReviewNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.QualityReview','APPROVE_FINAL_CLOSURE', @QualityReviewID, @PerformedByUserID, SYSUTCDATETIME(),
            (SELECT @QualityReviewID AS QRID, @TicketID AS TicketID FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== RETURN_FOR_CORRECTION ==========
    IF @Action = 'RETURN_FOR_CORRECTION'
    BEGIN
        BEGIN TRAN;
        DECLARE @ReturnResultID INT;
        SELECT @ReturnResultID = [QualityReviewResultID] FROM [Tickets].[QualityReviewResult] WHERE [ResultCode] = 'RETURNED';

        UPDATE [Tickets].[QualityReview]
        SET [QualityReviewResultID_FK] = @ReturnResultID,
            [ReviewNotes] = @ReviewNotes, [ReviewDate] = SYSUTCDATETIME(),
            [ReturnToUserID_FK] = @ReturnToUserID, [IsFinalized] = 1,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [QualityReviewID] = @QualityReviewID;

        -- Return ticket to IN_PROGRESS
        DECLARE @OldStatusReturn INT;
        SELECT @OldStatusReturn = [TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID] = @TicketID;
        DECLARE @IPStatusReturn INT;
        SELECT @IPStatusReturn = [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode] = 'IN_PROGRESS';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK] = @IPStatusReturn,
            [OperationalResolvedDate] = NULL, [OperationalResolvedBy] = NULL,
            [AssignedUserID_FK] = ISNULL(@ReturnToUserID, [AssignedUserID_FK]),
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketID] = @TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES (@TicketID, @IdaraID, 'RETURNED_FOR_CORRECTION', @OldStatusReturn, @IPStatusReturn, @PerformedByUserID, @ReviewNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.QualityReview','RETURN_FOR_CORRECTION', @QualityReviewID, @PerformedByUserID, SYSUTCDATETIME(),
            (SELECT @QualityReviewID AS QRID, @ReturnToUserID AS ReturnTo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    -- ========== REJECT_CLOSURE ==========
    IF @Action = 'REJECT_CLOSURE'
    BEGIN
        BEGIN TRAN;
        DECLARE @RejectResultID INT;
        SELECT @RejectResultID = [QualityReviewResultID] FROM [Tickets].[QualityReviewResult] WHERE [ResultCode] = 'REJECTED';

        UPDATE [Tickets].[QualityReview]
        SET [QualityReviewResultID_FK] = @RejectResultID,
            [ReviewNotes] = @ReviewNotes, [ReviewDate] = SYSUTCDATETIME(),
            [IsFinalized] = 1,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [QualityReviewID] = @QualityReviewID;

        -- Return ticket to REOPENED
        DECLARE @OldStatusReject INT;
        SELECT @OldStatusReject = [TicketStatusID_FK] FROM [Tickets].[Ticket] WHERE [TicketID] = @TicketID;
        DECLARE @ReopenStatusReject INT;
        SELECT @ReopenStatusReject = [TicketStatusID] FROM [Tickets].[TicketStatus] WHERE [StatusCode] = 'REOPENED';

        UPDATE [Tickets].[Ticket]
        SET [TicketStatusID_FK] = @ReopenStatusReject,
            [OperationalResolvedDate] = NULL, [OperationalResolvedBy] = NULL,
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketID] = @TicketID;

        INSERT INTO [Tickets].[TicketHistory]
            ([TicketID_FK],[IdaraID_FK],[ActionTypeCode],[OldStatusID_FK],[NewStatusID_FK],[PerformedByUserID_FK],[Notes])
        VALUES (@TicketID, @IdaraID, 'CLOSURE_REJECTED', @OldStatusReject, @ReopenStatusReject, @PerformedByUserID, @ReviewNotes);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.QualityReview','REJECT_CLOSURE', @QualityReviewID, @PerformedByUserID, SYSUTCDATETIME(),
            (SELECT @QualityReviewID AS QRID FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for QualityReviewSP.', 1;
END
GO

-- ============================================================================
-- 6.6 TicketSLASP (Optional dedicated SLA SP)
-- ============================================================================
CREATE OR ALTER PROCEDURE [Tickets].[TicketSLASP]
    @Action                 NVARCHAR(100),
    @TicketID               BIGINT          = NULL,
    @IdaraID                BIGINT          = NULL,
    @TicketSLAID            BIGINT          = NULL,
    @SLATypeCode            NVARCHAR(50)    = NULL,
    @TargetMinutes          INT             = NULL,
    @Notes                  NVARCHAR(2000)  = NULL,
    @PerformedByUserID      BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ========== INITIALIZE_SLA ==========
    IF @Action = 'INITIALIZE_SLA'
    BEGIN
        BEGIN TRAN;
        INSERT INTO [Tickets].[TicketSLA]
            ([TicketID_FK],[IdaraID_FK],[SLATypeCode],[TargetMinutes],[RemainingMinutes],
             [StartDate],[CreatedBy])
        VALUES (@TicketID, @IdaraID, @SLATypeCode, @TargetMinutes, @TargetMinutes,
             SYSUTCDATETIME(), @PerformedByUserID);
        DECLARE @NewSLAID BIGINT = SCOPE_IDENTITY();

        INSERT INTO [Tickets].[TicketSLAHistory]
            ([TicketSLAID_FK],[IdaraID_FK],[SLAEventTypeCode],[Notes],[PerformedByUserID_FK])
        VALUES (@NewSLAID, @IdaraID, 'INITIALIZED', @Notes, @PerformedByUserID);

        INSERT INTO [dbo].[AuditLog]([TableName],[Action],[RecordID],[PerformedBy],[AuditDate],[AuditData])
        VALUES ('Tickets.TicketSLA','INITIALIZE_SLA', @NewSLAID, @PerformedByUserID, SYSUTCDATETIME(),
            (SELECT @NewSLAID AS SLAID, @SLATypeCode AS SLAType FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
        COMMIT TRAN;
        SELECT @NewSLAID AS TicketSLAID;
        RETURN;
    END

    -- ========== PAUSE_SLA ==========
    IF @Action = 'PAUSE_SLA'
    BEGIN
        BEGIN TRAN;
        -- Calculate elapsed so far
        DECLARE @StartDatePause DATETIME2(7), @ElapsedPause INT, @TargetPause INT;
        SELECT @StartDatePause = [StartDate], @ElapsedPause = [ElapsedMinutes], @TargetPause = [TargetMinutes]
        FROM [Tickets].[TicketSLA] WHERE [TicketSLAID] = @TicketSLAID;

        DECLARE @AdditionalMinutes INT = DATEDIFF(MINUTE, ISNULL(@StartDatePause, SYSUTCDATETIME()), SYSUTCDATETIME());
        SET @ElapsedPause = @ElapsedPause + @AdditionalMinutes;

        UPDATE [Tickets].[TicketSLA]
        SET [ElapsedMinutes] = @ElapsedPause,
            [RemainingMinutes] = CASE WHEN @TargetPause - @ElapsedPause > 0 THEN @TargetPause - @ElapsedPause ELSE 0 END,
            [StopDate] = SYSUTCDATETIME(),
            [LastCalculatedDate] = SYSUTCDATETIME(),
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketSLAID] = @TicketSLAID;

        INSERT INTO [Tickets].[TicketSLAHistory]
            ([TicketSLAID_FK],[IdaraID_FK],[SLAEventTypeCode],[Notes],[PerformedByUserID_FK])
        VALUES (@TicketSLAID, @IdaraID, 'PAUSED', @Notes, @PerformedByUserID);
        COMMIT TRAN;
        RETURN;
    END

    -- ========== RESUME_SLA ==========
    IF @Action = 'RESUME_SLA'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[TicketSLA]
        SET [StartDate] = SYSUTCDATETIME(), [StopDate] = NULL,
            [LastCalculatedDate] = SYSUTCDATETIME(),
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketSLAID] = @TicketSLAID;

        INSERT INTO [Tickets].[TicketSLAHistory]
            ([TicketSLAID_FK],[IdaraID_FK],[SLAEventTypeCode],[Notes],[PerformedByUserID_FK])
        VALUES (@TicketSLAID, @IdaraID, 'RESUMED', @Notes, @PerformedByUserID);
        COMMIT TRAN;
        RETURN;
    END

    -- ========== CHECK_BREACH ==========
    IF @Action = 'CHECK_BREACH'
    BEGIN
        BEGIN TRAN;
        DECLARE @Elapsed INT, @Target INT, @Breached BIT, @StopDt DATETIME2(7), @StartDt DATETIME2(7);
        SELECT @Elapsed = [ElapsedMinutes], @Target = [TargetMinutes], @Breached = [IsBreached],
               @StopDt = [StopDate], @StartDt = [StartDate]
        FROM [Tickets].[TicketSLA] WHERE [TicketSLAID] = @TicketSLAID;

        -- Calculate real-time elapsed if SLA is running
        DECLARE @RealElapsed INT = @Elapsed;
        IF @StopDt IS NULL AND @StartDt IS NOT NULL
            SET @RealElapsed = @Elapsed + DATEDIFF(MINUTE, @StartDt, SYSUTCDATETIME());

        IF @RealElapsed >= @Target AND @Breached = 0
        BEGIN
            UPDATE [Tickets].[TicketSLA]
            SET [IsBreached] = 1, [ElapsedMinutes] = @RealElapsed, [RemainingMinutes] = 0,
                [LastCalculatedDate] = SYSUTCDATETIME(),
                [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
            WHERE [TicketSLAID] = @TicketSLAID;

            INSERT INTO [Tickets].[TicketSLAHistory]
                ([TicketSLAID_FK],[IdaraID_FK],[SLAEventTypeCode],[Notes],[PerformedByUserID_FK])
            VALUES (@TicketSLAID, @IdaraID, 'BREACHED', 'SLA target exceeded', @PerformedByUserID);
        END
        ELSE
        BEGIN
            UPDATE [Tickets].[TicketSLA]
            SET [ElapsedMinutes] = @RealElapsed,
                [RemainingMinutes] = CASE WHEN @Target - @RealElapsed > 0 THEN @Target - @RealElapsed ELSE 0 END,
                [LastCalculatedDate] = SYSUTCDATETIME()
            WHERE [TicketSLAID] = @TicketSLAID;
        END
        COMMIT TRAN;
        RETURN;
    END

    -- ========== COMPLETE_SLA ==========
    IF @Action = 'COMPLETE_SLA'
    BEGIN
        BEGIN TRAN;
        UPDATE [Tickets].[TicketSLA]
        SET [CompletionDate] = SYSUTCDATETIME(), [StopDate] = SYSUTCDATETIME(),
            [LastCalculatedDate] = SYSUTCDATETIME(),
            [ModifiedBy] = @PerformedByUserID, [ModifiedDate] = SYSUTCDATETIME()
        WHERE [TicketSLAID] = @TicketSLAID;

        INSERT INTO [Tickets].[TicketSLAHistory]
            ([TicketSLAID_FK],[IdaraID_FK],[SLAEventTypeCode],[Notes],[PerformedByUserID_FK])
        VALUES (@TicketSLAID, @IdaraID, 'COMPLETED', @Notes, @PerformedByUserID);
        COMMIT TRAN;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for TicketSLASP.', 1;
END
GO

-- ============================================================================
-- STEP 7: DL (DATA LAYER) PROCEDURES
-- ============================================================================

-- 7.1 ServiceDL
CREATE OR ALTER PROCEDURE [Tickets].[ServiceDL]
    @Action             NVARCHAR(100),
    @IdaraID            BIGINT          = NULL,
    @ServiceID          BIGINT          = NULL,
    @PriorityID         INT             = NULL,
    @ApprovalStatus     NVARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'GET_SERVICE_CATALOGUE'
    BEGIN
        SELECT * FROM [Tickets].[V_ServiceFullDefinition]
        WHERE (@IdaraID IS NULL OR [IdaraID_FK] = @IdaraID)
          AND [IsActive] = 1
        ORDER BY [ServiceNameEN];
        RETURN;
    END

    IF @Action = 'GET_SERVICE_DETAIL'
    BEGIN
        SELECT * FROM [Tickets].[V_ServiceFullDefinition]
        WHERE [ServiceID] = @ServiceID;
        RETURN;
    END

    IF @Action = 'GET_ROUTING_RULES'
    BEGIN
        SELECT srr.*, s.[ServiceCode], s.[ServiceNameEN]
        FROM [Tickets].[ServiceRoutingRule] srr
        JOIN [Tickets].[Service] s ON srr.[ServiceID_FK] = s.[ServiceID]
        WHERE srr.[ServiceID_FK] = @ServiceID
        ORDER BY srr.[EffectiveFrom] DESC;
        RETURN;
    END

    IF @Action = 'GET_SLA_POLICIES'
    BEGIN
        SELECT sla.*, p.[PriorityCode], p.[PriorityNameEN], s.[ServiceNameEN]
        FROM [Tickets].[ServiceSLAPolicy] sla
        JOIN [Tickets].[Priority] p ON sla.[PriorityID_FK] = p.[PriorityID]
        JOIN [Tickets].[Service] s ON sla.[ServiceID_FK] = s.[ServiceID]
        WHERE sla.[ServiceID_FK] = @ServiceID AND sla.[IsActive] = 1
        ORDER BY p.[SortOrder];
        RETURN;
    END

    IF @Action = 'GET_SLA_POLICY_FOR_SERVICE_PRIORITY'
    BEGIN
        SELECT TOP 1 * FROM [Tickets].[ServiceSLAPolicy]
        WHERE [ServiceID_FK] = @ServiceID AND [PriorityID_FK] = @PriorityID AND [IsActive] = 1
          AND [EffectiveFrom] <= CAST(GETDATE() AS DATE)
          AND ([EffectiveTo] IS NULL OR [EffectiveTo] >= CAST(GETDATE() AS DATE));
        RETURN;
    END

    IF @Action = 'GET_SERVICE_SUGGESTIONS'
    BEGIN
        SELECT scs.*, s.[ServiceNameEN] AS SourceServiceName
        FROM [Tickets].[ServiceCatalogSuggestion] scs
        LEFT JOIN [Tickets].[Service] s ON scs.[CreatedServiceID_FK] = s.[ServiceID]
        WHERE (@IdaraID IS NULL OR scs.[IdaraID_FK] = @IdaraID)
          AND (@ApprovalStatus IS NULL OR scs.[ApprovalStatus] = @ApprovalStatus)
        ORDER BY scs.[CreatedDate] DESC;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for ServiceDL.', 1;
END
GO

-- 7.2 TicketDL
CREATE OR ALTER PROCEDURE [Tickets].[TicketDL]
    @Action             NVARCHAR(100),
    @TicketID           BIGINT          = NULL,
    @IdaraID            BIGINT          = NULL,
    @StatusCode         NVARCHAR(50)    = NULL,
    @CurrentDSDID       BIGINT          = NULL,
    @AssignedUserID     BIGINT          = NULL,
    @QueueDistributorID BIGINT          = NULL,
    @ParentTicketID     BIGINT          = NULL,
    @RootTicketID       BIGINT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'GET_TICKET_DETAILS'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketFullDetails]
        WHERE [TicketID] = @TicketID;
        RETURN;
    END

    IF @Action = 'GET_TICKETS_BY_STATUS'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketFullDetails]
        WHERE (@IdaraID IS NULL OR [IdaraID_FK] = @IdaraID)
          AND (@StatusCode IS NULL OR [TicketStatusCode] = @StatusCode)
        ORDER BY [CreatedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_INBOX_BY_SCOPE'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketInboxByScope]
        WHERE (@IdaraID IS NULL OR [IdaraID_FK] = @IdaraID)
          AND (@CurrentDSDID IS NULL OR [CurrentDSDID_FK] = @CurrentDSDID)
          AND (@QueueDistributorID IS NULL OR [CurrentQueueDistributorID_FK] = @QueueDistributorID)
        ORDER BY [CreatedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_INBOX_BY_ASSIGNEE'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketInboxByScope]
        WHERE [AssignedUserID_FK] = @AssignedUserID
        ORDER BY [CreatedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_TICKET_HISTORY'
    BEGIN
        SELECT th.*, ts_old.[StatusCode] AS OldStatusCode, ts_new.[StatusCode] AS NewStatusCode
        FROM [Tickets].[TicketHistory] th
        LEFT JOIN [Tickets].[TicketStatus] ts_old ON th.[OldStatusID_FK] = ts_old.[TicketStatusID]
        LEFT JOIN [Tickets].[TicketStatus] ts_new ON th.[NewStatusID_FK] = ts_new.[TicketStatusID]
        WHERE th.[TicketID_FK] = @TicketID
        ORDER BY th.[ActionDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_TICKET_TREE'
    BEGIN
        -- Load all tickets in the tree from root
        DECLARE @Root BIGINT = @RootTicketID;
        IF @Root IS NULL
            SELECT @Root = [RootTicketID_FK] FROM [Tickets].[Ticket] WHERE [TicketID] = @TicketID;

        SELECT t.[TicketID], t.[TicketNo], t.[Title], t.[ParentTicketID_FK], t.[RootTicketID_FK],
               ts.[StatusCode], ts.[StatusNameEN], p.[PriorityCode]
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
        LEFT JOIN [Tickets].[Priority] p ON t.[EffectivePriorityID_FK] = p.[PriorityID]
        WHERE t.[RootTicketID_FK] = @Root
        ORDER BY t.[TicketID];
        RETURN;
    END

    IF @Action = 'GET_LAST_ACTION'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketLastAction]
        WHERE [TicketID_FK] = @TicketID;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for TicketDL.', 1;
END
GO

-- 7.3 ArbitrationDL
CREATE OR ALTER PROCEDURE [Tickets].[ArbitrationDL]
    @Action                     NVARCHAR(100),
    @IdaraID                    BIGINT          = NULL,
    @ArbitratorDistributorID    BIGINT          = NULL,
    @TicketID                   BIGINT          = NULL,
    @Status                     NVARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'GET_OPEN_DISPUTES'
    BEGIN
        SELECT * FROM [Tickets].[V_TicketArbitrationInbox]
        WHERE (@IdaraID IS NULL OR [IdaraID_FK] = @IdaraID)
          AND (@ArbitratorDistributorID IS NULL OR [ArbitratorDistributorID_FK] = @ArbitratorDistributorID)
        ORDER BY [CreatedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_DISPUTE_HISTORY'
    BEGIN
        SELECT ac.*, ar.[ReasonCode], ar.[ReasonNameEN],
               t.[TicketNo], t.[Title]
        FROM [Tickets].[ArbitrationCase] ac
        JOIN [Tickets].[ArbitrationReason] ar ON ac.[ArbitrationReasonID_FK] = ar.[ArbitrationReasonID]
        JOIN [Tickets].[Ticket] t ON ac.[TicketID_FK] = t.[TicketID]
        WHERE (@TicketID IS NULL OR ac.[TicketID_FK] = @TicketID)
          AND (@IdaraID IS NULL OR ac.[IdaraID_FK] = @IdaraID)
          AND (@Status IS NULL OR ac.[Status] = @Status)
        ORDER BY ac.[CreatedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_ROUTING_CORRECTION_CANDIDATES'
    BEGIN
        SELECT ac.[TicketID_FK], t.[TicketNo], t.[Title],
               ac.[ArbitrationCaseID], ac.[DecisionTargetDSDID_FK],
               s.[ServiceID], s.[ServiceNameEN]
        FROM [Tickets].[ArbitrationCase] ac
        JOIN [Tickets].[Ticket] t ON ac.[TicketID_FK] = t.[TicketID]
        LEFT JOIN [Tickets].[Service] s ON t.[ServiceID_FK] = s.[ServiceID]
        WHERE ac.[Status] = 'DECIDED' AND ac.[DecisionType] = 'REDIRECT'
          AND t.[IsOtherService] = 0
          AND (@IdaraID IS NULL OR ac.[IdaraID_FK] = @IdaraID)
        ORDER BY ac.[DecisionDate] DESC;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for ArbitrationDL.', 1;
END
GO

-- 7.4 DashboardDL
CREATE OR ALTER PROCEDURE [Tickets].[DashboardDL]
    @Action         NVARCHAR(100),
    @IdaraID        BIGINT      = NULL,
    @DSDID          BIGINT      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'GET_COUNTS_BY_STATUS'
    BEGIN
        SELECT ts.[StatusCode], ts.[StatusNameEN], COUNT(*) AS TicketCount
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
        WHERE (@IdaraID IS NULL OR t.[IdaraID_FK] = @IdaraID)
          AND (@DSDID IS NULL OR t.[CurrentDSDID_FK] = @DSDID)
        GROUP BY ts.[StatusCode], ts.[StatusNameEN]
        ORDER BY ts.[StatusNameEN];
        RETURN;
    END

    IF @Action = 'GET_SLA_BREACHES'
    BEGIN
        SELECT tsla.[TicketSLAID], tsla.[TicketID_FK], t.[TicketNo], t.[Title],
               tsla.[SLATypeCode], tsla.[TargetMinutes], tsla.[ElapsedMinutes],
               tsla.[IsBreached]
        FROM [Tickets].[TicketSLA] tsla
        JOIN [Tickets].[Ticket] t ON tsla.[TicketID_FK] = t.[TicketID]
        WHERE tsla.[IsBreached] = 1
          AND (@IdaraID IS NULL OR tsla.[IdaraID_FK] = @IdaraID)
        ORDER BY tsla.[ModifiedDate] DESC;
        RETURN;
    END

    IF @Action = 'GET_ARBITRATION_LOAD'
    BEGIN
        SELECT ac.[ArbitratorDistributorID_FK], COUNT(*) AS OpenCaseCount
        FROM [Tickets].[ArbitrationCase] ac
        WHERE ac.[Status] = 'OPEN'
          AND (@IdaraID IS NULL OR ac.[IdaraID_FK] = @IdaraID)
        GROUP BY ac.[ArbitratorDistributorID_FK];
        RETURN;
    END

    IF @Action = 'GET_CLARIFICATION_LOAD'
    BEGIN
        SELECT cr.[RequestedFromDSDID_FK], COUNT(*) AS OpenRequestCount
        FROM [Tickets].[ClarificationRequest] cr
        WHERE cr.[Status] = 'OPEN'
          AND (@IdaraID IS NULL OR cr.[IdaraID_FK] = @IdaraID)
        GROUP BY cr.[RequestedFromDSDID_FK];
        RETURN;
    END

    IF @Action = 'GET_SERVICE_FREQUENCY'
    BEGIN
        SELECT s.[ServiceID], s.[ServiceNameEN], COUNT(t.[TicketID]) AS TicketCount
        FROM [Tickets].[Service] s
        LEFT JOIN [Tickets].[Ticket] t ON s.[ServiceID] = t.[ServiceID_FK]
        WHERE (@IdaraID IS NULL OR s.[IdaraID_FK] = @IdaraID)
        GROUP BY s.[ServiceID], s.[ServiceNameEN]
        ORDER BY TicketCount DESC;
        RETURN;
    END

    IF @Action = 'GET_OVERDUE_OPERATIONAL'
    BEGIN
        SELECT t.[TicketID], t.[TicketNo], t.[Title], ts.[StatusCode],
               tsla.[SLATypeCode], tsla.[TargetMinutes], tsla.[ElapsedMinutes]
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
        JOIN [Tickets].[TicketSLA] tsla ON t.[TicketID] = tsla.[TicketID_FK]
        WHERE tsla.[SLATypeCode] = 'OPERATIONAL_COMPLETION' AND tsla.[IsBreached] = 1
          AND ts.[StatusCode] NOT IN ('CLOSED','CANCELLED','RESOLVED')
          AND (@IdaraID IS NULL OR t.[IdaraID_FK] = @IdaraID)
        ORDER BY tsla.[ElapsedMinutes] DESC;
        RETURN;
    END

    IF @Action = 'GET_OVERDUE_FINAL_CLOSURE'
    BEGIN
        SELECT t.[TicketID], t.[TicketNo], t.[Title], ts.[StatusCode],
               tsla.[SLATypeCode], tsla.[TargetMinutes], tsla.[ElapsedMinutes]
        FROM [Tickets].[Ticket] t
        JOIN [Tickets].[TicketStatus] ts ON t.[TicketStatusID_FK] = ts.[TicketStatusID]
        JOIN [Tickets].[TicketSLA] tsla ON t.[TicketID] = tsla.[TicketID_FK]
        WHERE tsla.[SLATypeCode] = 'FINAL_CLOSURE' AND tsla.[IsBreached] = 1
          AND ts.[StatusCode] NOT IN ('CLOSED','CANCELLED')
          AND (@IdaraID IS NULL OR t.[IdaraID_FK] = @IdaraID)
        ORDER BY tsla.[ElapsedMinutes] DESC;
        RETURN;
    END

    THROW 50000, 'Unknown @Action for DashboardDL.', 1;
END
GO

-- ============================================================================
-- END OF MSSQL SCRIPTS
-- ============================================================================