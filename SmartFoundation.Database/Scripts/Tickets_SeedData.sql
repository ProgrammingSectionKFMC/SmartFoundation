/*
    Tickets module - setup data (seed)
    ----------------------------------
    Generated 2026-11-10 from the test database (DATACORETi), which is the reference for the Tickets module.

    What it does:
      Part 1  Tickets lookup and catalogue tables (statuses, priorities, classes, services,
              reasons, templates, routing rules, SLA policies, history action types ...).
              Rows keep their original IDs. Only MISSING rows are inserted; existing rows are
              never updated or deleted, so local changes are kept.
      Part 2  dbo program / menus / distributors / permission types for the ticket pages
              (TicketList, TicketDetails, TicketAdmin, ServiceCatalogueList).
              Matched by name or code (IDs differ between databases); only missing rows are added.

    What it does NOT do:
      - No tickets, history, attachments or other transactional data.
      - No user permission grants (dbo.Permission). Grant users the ticket permissions
        from the permissions screens after running it.
      - Routing rules point to organisation units (dbo.DSD) by ID: they assume the same
        units as the test database. Review Tickets.ServiceRoutingRule if the units differ.

    Safe to run more than once. Runs in a single transaction: all or nothing.
    Run with: sqlcmd -S <server> -d <database> -E -I -f 65001 -i Tickets_SeedData.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

BEGIN TRANSACTION;

PRINT N'Part 1: Tickets lookup and catalogue tables';

-- Tickets.TicketClass (5 rows)
SET IDENTITY_INSERT [Tickets].[TicketClass] ON;
INSERT INTO [Tickets].[TicketClass] ([ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E], [ticketClassDesc], [ticketClassActive], [entryDate], [entryData], [hostName], [ticketClassDesc_A])
SELECT s.[ticketClassID], s.[ticketClassCode], s.[ticketClassName_A], s.[ticketClassName_E], s.[ticketClassDesc], s.[ticketClassActive], s.[entryDate], s.[entryData], s.[hostName], s.[ticketClassDesc_A]
FROM (VALUES
    (1, N'CLS-001', N'صيانة', N'Maintenance', N'Maintenance', 1, '2026-04-19T13:46:23.027', N'9', N'catalog-cleanup', N'أعطال المباني والمرافق والأجهزة'),
    (2, N'CLS-002', N'نظافة', N'Cleaning', N'Cleaning', 1, '2026-04-19T13:46:23.027', N'9', N'catalog-cleanup', N'طلبات النظافة العامة'),
    (3, N'CLS-003', N'تقنية واتصالات', N'Technical & Communications', N'Technical & Communications', 1, '2026-04-19T13:46:23.027', N'9', N'catalog-cleanup', N'الإنترنت والهاتف والكاميرات وأنظمة الدخول'),
    (4, N'CLS-004', N'طلبات إدارية واستفسارات', N'Administrative Requests', N'Administrative Requests', 1, '2026-04-19T13:46:23.027', N'9', N'catalog-cleanup', N'الشهادات والمستندات والنقل والاستفسارات'),
    (5, N'CLS-005', N'شكاوى', N'Complaints', N'Complaints', 1, '2026-04-19T13:46:23.027', N'9', N'catalog-cleanup', N'شكاوى الضوضاء والنظافة والمواقف والأمن والموظفين')
) AS s ([ticketClassID], [ticketClassCode], [ticketClassName_A], [ticketClassName_E], [ticketClassDesc], [ticketClassActive], [entryDate], [entryData], [hostName], [ticketClassDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[TicketClass] x WHERE x.[ticketClassID] = s.[ticketClassID]);
SET IDENTITY_INSERT [Tickets].[TicketClass] OFF;
DBCC CHECKIDENT (N'[Tickets].[TicketClass]', RESEED) WITH NO_INFOMSGS;

-- Tickets.Priority (4 rows)
SET IDENTITY_INSERT [Tickets].[Priority] ON;
INSERT INTO [Tickets].[Priority] ([priorityID], [priorityCode], [priorityName_A], [priorityName_E], [priorityDesc], [priorityLevel], [priorityActive], [entryDate], [entryData], [hostName], [priorityDesc_A], [priorityColor])
SELECT s.[priorityID], s.[priorityCode], s.[priorityName_A], s.[priorityName_E], s.[priorityDesc], s.[priorityLevel], s.[priorityActive], s.[entryDate], s.[entryData], s.[hostName], s.[priorityDesc_A], s.[priorityColor]
FROM (VALUES
    (1, N'CRITICAL', N'حرج', N'Critical', N'Safety risk or essential service down', 1, 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'خطر على الأشخاص أو توقف خدمة أساسية — يُعالج فوراً', N'#991b1b'),
    (2, N'HIGH', N'مرتفع', N'High', N'Affects daily use; same-day handling', 2, 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'يؤثر على الاستخدام اليومي — يُعالج في نفس اليوم', N'#dc2626'),
    (3, N'MEDIUM', N'متوسط', N'Medium', N'Normal issue; handled within working days', 3, 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'مشكلة اعتيادية — تُعالج خلال أيام العمل', N'#d97706'),
    (4, N'LOW', N'منخفض', N'Low', N'Non-urgent request; scheduled when possible', 4, 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'طلب غير عاجل — يُجدول حسب الإمكان', N'#6b7280')
) AS s ([priorityID], [priorityCode], [priorityName_A], [priorityName_E], [priorityDesc], [priorityLevel], [priorityActive], [entryDate], [entryData], [hostName], [priorityDesc_A], [priorityColor])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[Priority] x WHERE x.[priorityID] = s.[priorityID]);
SET IDENTITY_INSERT [Tickets].[Priority] OFF;
DBCC CHECKIDENT (N'[Tickets].[Priority]', RESEED) WITH NO_INFOMSGS;

-- Tickets.TicketStatus (11 rows)
SET IDENTITY_INSERT [Tickets].[TicketStatus] ON;
INSERT INTO [Tickets].[TicketStatus] ([ticketStatusID], [ticketStatusCode], [ticketStatusName_A], [ticketStatusName_E], [ticketStatusDesc], [ticketStatusActive], [entryDate], [entryData], [hostName], [ticketStatusDesc_A], [ticketStatusColor])
SELECT s.[ticketStatusID], s.[ticketStatusCode], s.[ticketStatusName_A], s.[ticketStatusName_E], s.[ticketStatusDesc], s.[ticketStatusActive], s.[entryDate], s.[entryData], s.[hostName], s.[ticketStatusDesc_A], s.[ticketStatusColor]
FROM (VALUES
    (1, N'NEW', N'جديد', N'New', N'Created, not routed yet', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'أُنشئت التذكرة ولم تُوجَّه بعد', N'#2563eb'),
    (2, N'ROUTED', N'موجّه', N'Routed', N'Routed to the responsible unit', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'وُجِّهت إلى الجهة المختصة', N'#0891b2'),
    (3, N'ASSIGNED', N'معيّن', N'Assigned', N'Assigned to an employee', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'أُسندت إلى موظف', N'#d97706'),
    (4, N'IN_PROGRESS', N'جاري التنفيذ', N'In Progress', N'Work in progress', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'العمل جارٍ على التذكرة', N'#ca8a04'),
    (5, N'CLARIFICATION', N'طلب توضيح', N'Clarification', N'Waiting for a clarification reply', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'بانتظار رد على طلب توضيح', N'#ea580c'),
    (6, N'ARBITRATION', N'تحكيم', N'Arbitration', N'Under arbitration', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'معروضة للتحكيم', N'#c2410c'),
    (7, N'PAUSED', N'متوقف', N'Paused', N'Temporarily paused', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'متوقفة مؤقتاً لسبب محدد', N'#7c3aed'),
    (8, N'RESOLVED', N'تم التنفيذ', N'Operationally Resolved', N'Work done, awaiting closure or quality review', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'نُفِّذ العمل وبانتظار الإغلاق أو مراجعة الجودة', N'#16a34a'),
    (9, N'CLOSED', N'مغلق نهائياً', N'Closed', N'Closed', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'أُغلقت التذكرة نهائياً', N'#15803d'),
    (10, N'REJECTED', N'مرفوض', N'Rejected', N'Rejected', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'رُفضت التذكرة', N'#dc2626'),
    (11, N'REOPENED', N'معاد فتحها', N'Reopened', N'Reopened after closure', 1, '2026-04-19T13:46:23.027', N'9', N'ticket-admin-setup', N'أُعيد فتح التذكرة بعد إغلاقها', N'#4f46e5')
) AS s ([ticketStatusID], [ticketStatusCode], [ticketStatusName_A], [ticketStatusName_E], [ticketStatusDesc], [ticketStatusActive], [entryDate], [entryData], [hostName], [ticketStatusDesc_A], [ticketStatusColor])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[TicketStatus] x WHERE x.[ticketStatusID] = s.[ticketStatusID]);
SET IDENTITY_INSERT [Tickets].[TicketStatus] OFF;
DBCC CHECKIDENT (N'[Tickets].[TicketStatus]', RESEED) WITH NO_INFOMSGS;

-- Tickets.RequesterType (6 rows)
SET IDENTITY_INSERT [Tickets].[RequesterType] ON;
INSERT INTO [Tickets].[RequesterType] ([requesterTypeID], [requesterTypeCode], [requesterTypeName_A], [requesterTypeName_E], [requesterTypeDesc], [requesterTypeActive], [entryDate], [entryData], [hostName], [requesterTypeDesc_A])
SELECT s.[requesterTypeID], s.[requesterTypeCode], s.[requesterTypeName_A], s.[requesterTypeName_E], s.[requesterTypeDesc], s.[requesterTypeActive], s.[entryDate], s.[entryData], s.[hostName], s.[requesterTypeDesc_A]
FROM (VALUES
    (1, N'RESIDENT', N'مقيم/مستفيد', N'Resident / Beneficiary', N'External beneficiary or resident of housing', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'مستفيد خارجي أو مقيم خارجي'),
    (2, N'INTERNAL', N'مستخدم داخلي', N'Internal User', N'Internal staff member from any department', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'موظف داخلي من أي قسم'),
    (3, N'SUPERVISOR', N'مشرف', N'Supervisor', N'Supervisor requesting on behalf of a section', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'مشرف يطلب الخدمة نيابة عن قسم'),
    (4, N'MANAGER', N'مدير', N'Manager', N'Department or division manager', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'مدير الإدارة أو القطاع'),
    (5, N'SYSTEM', N'النظام', N'System', N'Auto-generated by system process', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'تمت إنشاؤه آلياًاً من قبل النظام'),
    (16, N'PUBLIC', N'بلاغ عام', N'Public Report', N'Report about a public location (street, district, facility)', 1, '2026-11-05T13:04:08.147', N'9', N'setup', N'بلاغ عن موقع عام مثل شارع أو حي أو مرفق')
) AS s ([requesterTypeID], [requesterTypeCode], [requesterTypeName_A], [requesterTypeName_E], [requesterTypeDesc], [requesterTypeActive], [entryDate], [entryData], [hostName], [requesterTypeDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[RequesterType] x WHERE x.[requesterTypeID] = s.[requesterTypeID]);
SET IDENTITY_INSERT [Tickets].[RequesterType] OFF;
DBCC CHECKIDENT (N'[Tickets].[RequesterType]', RESEED) WITH NO_INFOMSGS;

-- Tickets.HistoryActionType (24 rows)
SET IDENTITY_INSERT [Tickets].[HistoryActionType] ON;
INSERT INTO [Tickets].[HistoryActionType] ([historyActionTypeID], [actionTypeCode], [actionTypeName_A], [actionTypeName_E], [historyActionTypeActive], [entryDate], [entryData], [hostName])
SELECT s.[historyActionTypeID], s.[actionTypeCode], s.[actionTypeName_A], s.[actionTypeName_E], s.[historyActionTypeActive], s.[entryDate], s.[entryData], s.[hostName]
FROM (VALUES
    (1, N'CREATED', N'إنشاء التذكرة', N'Ticket created', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (2, N'ROUTED', N'توجيه التذكرة', N'Ticket routed', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (3, N'ASSIGNED', N'إسناد التذكرة', N'Ticket assigned', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (4, N'REASSIGNED', N'إعادة إسناد التذكرة', N'Ticket reassigned', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (5, N'STARTED', N'بدء العمل', N'Work started', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (6, N'STATUS_CHANGED', N'تغيير الحالة', N'Status changed', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (7, N'UPDATE_PRIORITY', N'تحديث الأولوية', N'Priority updated', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (8, N'PAUSED', N'إيقاف مؤقت', N'Ticket paused', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (9, N'RESUMED', N'استئناف العمل', N'Ticket resumed', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (10, N'CLARIFICATION_REQUESTED', N'طلب توضيح', N'Clarification requested', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (11, N'CLARIFICATION_RESPONDED', N'الرد على طلب التوضيح', N'Clarification responded', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (12, N'ARBITRATION', N'رفع للتحكيم', N'Arbitration raised', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (13, N'ARBITRATION_DECIDED', N'قرار التحكيم', N'Arbitration decided', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (14, N'ARBITRATION_CANCELLED', N'إلغاء التحكيم', N'Arbitration cancelled', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (15, N'ESCALATED', N'تصعيد التذكرة', N'Ticket escalated', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (16, N'RESOLVED', N'حل التذكرة', N'Ticket resolved', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (17, N'QUALITY_REVIEW', N'إحالة لمراجعة الجودة', N'Sent to quality review', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (18, N'QUALITY_APPROVED', N'اعتماد مراجعة الجودة', N'Quality review approved', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (19, N'QUALITY_RETURNED', N'إرجاع من مراجعة الجودة', N'Returned by quality review', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (20, N'QUALITY_ESCALATED', N'تصعيد مراجعة الجودة', N'Quality review escalated', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (21, N'RETURN_CORRECTION', N'إرجاع للتصحيح', N'Returned for correction', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (22, N'CLOSED', N'إغلاق التذكرة', N'Ticket closed', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (23, N'REJECTED', N'رفض التذكرة', N'Ticket rejected', 1, '2026-11-03T11:26:43.317', N'1', N'seed'),
    (24, N'REOPENED', N'إعادة فتح التذكرة', N'Ticket reopened', 1, '2026-11-03T11:26:43.317', N'1', N'seed')
) AS s ([historyActionTypeID], [actionTypeCode], [actionTypeName_A], [actionTypeName_E], [historyActionTypeActive], [entryDate], [entryData], [hostName])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[HistoryActionType] x WHERE x.[historyActionTypeID] = s.[historyActionTypeID]);
SET IDENTITY_INSERT [Tickets].[HistoryActionType] OFF;
DBCC CHECKIDENT (N'[Tickets].[HistoryActionType]', RESEED) WITH NO_INFOMSGS;

-- Tickets.PauseReason (9 rows)
SET IDENTITY_INSERT [Tickets].[PauseReason] ON;
INSERT INTO [Tickets].[PauseReason] ([pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E], [pauseReasonDesc], [pauseReasonActive], [entryDate], [entryData], [hostName], [pauseReasonDesc_A])
SELECT s.[pauseReasonID], s.[pauseReasonCode], s.[pauseReasonName_A], s.[pauseReasonName_E], s.[pauseReasonDesc], s.[pauseReasonActive], s.[entryDate], s.[entryData], s.[hostName], s.[pauseReasonDesc_A]
FROM (VALUES
    (1, N'CHILD_DEPENDENCY', N'بانتظار تذكرة فرعية', N'Waiting for Child Ticket', N'Waiting for Child Ticket', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'إيقاف تلقائي حتى تُغلق التذكرة الفرعية'),
    (2, N'ARBITRATION', N'بانتظار قرار التحكيم', N'Waiting for Arbitration', N'Waiting for Arbitration', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'إيقاف تلقائي أثناء التحكيم'),
    (3, N'CLARIFICATION', N'بانتظار التوضيح', NULL, NULL, 1, '2026-04-19T13:46:23.030', N'9', N'code-test', NULL),
    (4, N'PSR-004', N'تأخر التوريد من المستودع', N'Warehouse Delay', N'Warehouse Delay', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'المواد المطلوبة غير متوفرة في المستودع'),
    (5, N'PSR-005', N'بانتظار موافقة', N'Waiting for Approval', N'Waiting for Approval', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'العمل يحتاج موافقة جهة أخرى قبل التنفيذ'),
    (16, N'PSR-016', N'بانتظار قطع غيار', N'Waiting for Spare Parts', N'Waiting for Spare Parts', 1, '2026-11-05T13:54:15.817', N'9', N'ticket-admin-setup', N'القطعة المطلوبة قيد الطلب أو الشراء'),
    (17, N'PSR-017', N'بانتظار حضور المستفيد', N'Waiting for Requester', N'Waiting for Requester', 1, '2026-11-05T13:54:15.817', N'9', N'ticket-admin-setup', N'تعذر دخول الموقع لعدم وجود المستفيد'),
    (18, N'PSR-018', N'بانتظار المقاول', N'Waiting for Contractor', N'Waiting for Contractor', 1, '2026-11-05T13:54:15.817', N'9', N'ticket-admin-setup', N'العمل مُسند لمقاول خارجي'),
    (21, N'PSR-021', N'سبب تجربة الكود التلقائي - معدل', NULL, NULL, 0, '2026-11-10T14:26:07.860', N'9', N'code-test', NULL)
) AS s ([pauseReasonID], [pauseReasonCode], [pauseReasonName_A], [pauseReasonName_E], [pauseReasonDesc], [pauseReasonActive], [entryDate], [entryData], [hostName], [pauseReasonDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[PauseReason] x WHERE x.[pauseReasonID] = s.[pauseReasonID]);
SET IDENTITY_INSERT [Tickets].[PauseReason] OFF;
DBCC CHECKIDENT (N'[Tickets].[PauseReason]', RESEED) WITH NO_INFOMSGS;

-- Tickets.ArbitrationReason (5 rows)
SET IDENTITY_INSERT [Tickets].[ArbitrationReason] ON;
INSERT INTO [Tickets].[ArbitrationReason] ([arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E], [arbitrationReasonDesc], [arbitrationReasonActive], [entryDate], [entryData], [hostName], [arbitrationReasonDesc_A])
SELECT s.[arbitrationReasonID], s.[arbitrationReasonCode], s.[arbitrationReasonName_A], s.[arbitrationReasonName_E], s.[arbitrationReasonDesc], s.[arbitrationReasonActive], s.[entryDate], s.[entryData], s.[hostName], s.[arbitrationReasonDesc_A]
FROM (VALUES
    (1, N'ARB-001', N'قسم غير مختص', N'Wrong Section', N'Wrong Section', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'التذكرة وصلت لقسم لا يختص بها'),
    (2, N'ARB-002', N'إدارة غير مختصة', N'Wrong Department', N'Wrong Department', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'التذكرة تتبع إدارة أخرى'),
    (3, N'ARB-003', N'تداخل في الاختصاص', N'Overlapping Scope', N'Overlapping Scope', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'أكثر من جهة مسؤولة عن التذكرة'),
    (4, N'ARB-004', N'خدمة غير محددة', N'Unclear Service', N'Unclear Service', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'لا يمكن تحديد الخدمة المطلوبة بدقة'),
    (5, N'ARB-005', N'طلب إعادة إسناد', N'Reassignment Request', N'Reassignment Request', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'طلب نقل التذكرة لجهة أو موظف آخر')
) AS s ([arbitrationReasonID], [arbitrationReasonCode], [arbitrationReasonName_A], [arbitrationReasonName_E], [arbitrationReasonDesc], [arbitrationReasonActive], [entryDate], [entryData], [hostName], [arbitrationReasonDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[ArbitrationReason] x WHERE x.[arbitrationReasonID] = s.[arbitrationReasonID]);
SET IDENTITY_INSERT [Tickets].[ArbitrationReason] OFF;
DBCC CHECKIDENT (N'[Tickets].[ArbitrationReason]', RESEED) WITH NO_INFOMSGS;

-- Tickets.ClarificationReason (5 rows)
SET IDENTITY_INSERT [Tickets].[ClarificationReason] ON;
INSERT INTO [Tickets].[ClarificationReason] ([clarificationReasonID], [clarificationReasonCode], [clarificationReasonName_A], [clarificationReasonName_E], [clarificationReasonDesc], [clarificationReasonActive], [entryDate], [entryData], [hostName], [clarificationReasonDesc_A])
SELECT s.[clarificationReasonID], s.[clarificationReasonCode], s.[clarificationReasonName_A], s.[clarificationReasonName_E], s.[clarificationReasonDesc], s.[clarificationReasonActive], s.[entryDate], s.[entryData], s.[hostName], s.[clarificationReasonDesc_A]
FROM (VALUES
    (1, N'MISSING_LOCATION', N'نقص بيانات الموقع', N'Missing Location Details', N'Building, unit, or area information is missing', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'لا توجد بيانات كافية عن المبنى أو الوحدة أو المنطقة'),
    (2, N'MISSING_TECHNICAL', N'نقص تفاصيل فنية', N'Missing Technical Specs', N'Technical details or specifications needed for work', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'يلزم تزويد تفاصيل أو مواصفات فنية قبل التنفيذ'),
    (3, N'MISSING_APPROVAL', N'نقص الموافقات', N'Missing Approval', N'Required approval document or sign-off not provided', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'مستندات أو اعتمادات مطلوبة غير مرفقة'),
    (4, N'UNCLEAR_DESCRIPTION', N'وصف غير واضح', N'Unclear Description', N'Ticket description is vague or ambiguous', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'وصف التذكرة غير واضح ويحتاج توضيحاً'),
    (5, N'MISSING_CONTACT', N'نقص بيانات التواصل', N'Missing Contact Info', N'Requester contact information is incomplete', 1, '2026-04-19T13:46:23.030', N'SEED', N'SEED-HOST', N'بيانات التواصل مع مقدم الطلب غير مكتملة')
) AS s ([clarificationReasonID], [clarificationReasonCode], [clarificationReasonName_A], [clarificationReasonName_E], [clarificationReasonDesc], [clarificationReasonActive], [entryDate], [entryData], [hostName], [clarificationReasonDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[ClarificationReason] x WHERE x.[clarificationReasonID] = s.[clarificationReasonID]);
SET IDENTITY_INSERT [Tickets].[ClarificationReason] OFF;
DBCC CHECKIDENT (N'[Tickets].[ClarificationReason]', RESEED) WITH NO_INFOMSGS;

-- Tickets.QualityReviewResult (5 rows)
SET IDENTITY_INSERT [Tickets].[QualityReviewResult] ON;
INSERT INTO [Tickets].[QualityReviewResult] ([qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E], [qualityReviewResultDesc], [qualityReviewResultActive], [entryDate], [entryData], [hostName], [qualityReviewResultDesc_A])
SELECT s.[qualityReviewResultID], s.[qualityReviewResultCode], s.[qualityReviewResultName_A], s.[qualityReviewResultName_E], s.[qualityReviewResultDesc], s.[qualityReviewResultActive], s.[entryDate], s.[entryData], s.[hostName], s.[qualityReviewResultDesc_A]
FROM (VALUES
    (1, N'APPROVED', N'مقبول', N'Approved', N'Approved', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'العمل مطابق ويُغلق التذكرة'),
    (2, N'RETURN_CORRECTION', N'إعادة للتصحيح', N'Return for Correction', N'Return for Correction', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'العمل يحتاج تصحيحاً ويرجع لمنفّذه'),
    (3, N'REJECTED', N'مرفوض', N'Rejected', N'Rejected', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'العمل غير مقبول'),
    (4, N'ESCALATED', N'تصعيد للتحكيم', N'Escalated', N'Escalated', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'خلاف على جودة العمل يُرفع للتحكيم'),
    (5, N'QRR-005', N'مقبول جزئياً', N'Partial Approval', N'Partial Approval', 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'جزء من العمل مقبول وجزء يحتاج متابعة')
) AS s ([qualityReviewResultID], [qualityReviewResultCode], [qualityReviewResultName_A], [qualityReviewResultName_E], [qualityReviewResultDesc], [qualityReviewResultActive], [entryDate], [entryData], [hostName], [qualityReviewResultDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[QualityReviewResult] x WHERE x.[qualityReviewResultID] = s.[qualityReviewResultID]);
SET IDENTITY_INSERT [Tickets].[QualityReviewResult] OFF;
DBCC CHECKIDENT (N'[Tickets].[QualityReviewResult]', RESEED) WITH NO_INFOMSGS;

-- Tickets.Service (30 rows)
SET IDENTITY_INSERT [Tickets].[Service] ON;
INSERT INTO [Tickets].[Service] ([serviceID], [serviceCode], [serviceName_A], [serviceName_E], [serviceDesc], [idaraID_FK], [ticketClassID_FK], [defaultPriorityID_FK], [requiresLocation], [allowsChildTickets], [requiresQualityReview], [serviceActive], [entryDate], [entryData], [hostName], [serviceDesc_A])
SELECT s.[serviceID], s.[serviceCode], s.[serviceName_A], s.[serviceName_E], s.[serviceDesc], s.[idaraID_FK], s.[ticketClassID_FK], s.[defaultPriorityID_FK], s.[requiresLocation], s.[allowsChildTickets], s.[requiresQualityReview], s.[serviceActive], s.[entryDate], s.[entryData], s.[hostName], s.[serviceDesc_A]
FROM (VALUES
    (1, N'SRV-00001', N'إصلاح صنبور مياه', N'Water Faucet Repair', N'إصلاح أو استبدال خلاطات المياه المتسربة أو التالفة', 1, 1, 2, 1, 1, 1, 1, '2026-04-19T13:46:23.030', N'SEED', N'ticket-admin-setup', N'إصلاح أو استبدال خلاطات المياه المتسربة أو التالفة'),
    (2, N'SRV-00002', N'إصلاح كهرباء', N'Electrical Repair', N'إصلاح التمديدات والمخارج والمفاتيح والإنارة مع فحوصات السلامة', 1, 1, 3, 1, 1, 1, 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'إصلاح التمديدات والمخارج والمفاتيح والإنارة مع فحوصات السلامة'),
    (3, N'SRV-00003', N'صيانة تكييف', N'Air Conditioner Maintenance', N'صيانة دورية أو تصحيحية لوحدات التكييف', 1, 1, 2, 1, 0, 1, 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'صيانة دورية أو تصحيحية لوحدات التكييف'),
    (4, N'SRV-00004', N'نظافة عامة', N'General Cleaning', N'تنظيف المناطق المشتركة وإزالة النفايات ومكافحة الحشرات', 1, 2, 4, 1, 0, 0, 1, '2026-04-19T13:46:23.030', N'9', N'ticket-admin-setup', N'تنظيف المناطق المشتركة وإزالة النفايات ومكافحة الحشرات'),
    (5, N'SRV-00005', N'إصلاح سباكة', N'Plumbing', N'إصلاحات السباكة العامة بما يشمل الأنابيب والمصارف والتركيبات', 1, 1, 3, 1, 1, 1, 1, '2026-04-19T13:46:23.030', N'SEED', N'ticket-admin-setup', N'إصلاحات السباكة العامة بما يشمل الأنابيب والمصارف والتركيبات'),
    (10016, N'SRV-10016', N'إصلاح شبكة الإنترنت', N'Internet Network Repair', N'إصلاح أو استكشاف أخطاء مشاكل اتصال شبكة الإنترنت في الوحدة السكنية أو المبنى', 1, 3, 2, 1, 1, 1, 1, '2026-06-14T11:20:08.220', N'SEED', N'ticket-admin-setup', N'إصلاح أو استكشاف أخطاء مشاكل اتصال شبكة الإنترنت في الوحدة السكنية أو المبنى'),
    (10017, N'SRV-10017', N'إصلاح خط هاتف', N'Telephone Line Repair', N'إصلاح خطوط الهاتف الداخلية والمقابس في الوحدة السكنية', 1, 3, 3, 1, 0, 0, 1, '2026-06-14T11:20:08.220', N'SEED', N'ticket-admin-setup', N'إصلاح خطوط الهاتف الداخلية والمقابس في الوحدة السكنية'),
    (10018, N'SRV-10018', N'إصلاح نظام الاتصال الداخلي', N'Intercom System Repair', N'إصلاح نظام الاتصال الداخلي وأجهزة التواصل مع الباب', 1, 3, 3, 1, 0, 0, 1, '2026-06-14T11:20:08.220', N'SEED', N'ticket-admin-setup', N'إصلاح نظام الاتصال الداخلي وأجهزة التواصل مع الباب'),
    (10019, N'SRV-10019', N'صيانة كاميرات المراقبة', N'CCTV Maintenance', N'صيانة وإصلاح كاميرات المراقبة وأنظمة التسجيل', 1, 3, 2, 1, 0, 1, 1, '2026-06-14T11:20:08.220', N'SEED', N'ticket-admin-setup', N'صيانة وإصلاح كاميرات المراقبة وأنظمة التسجيل'),
    (10020, N'SRV-10020', N'صيانة نظام الدخول', N'Access Control Maintenance', N'صيانة نظام التحكم الإلكتروني بالدخول وبطاقات المرور', 1, 3, 2, 1, 0, 1, 1, '2026-06-14T11:20:08.220', N'SEED', N'ticket-admin-setup', N'صيانة نظام التحكم الإلكتروني بالدخول وبطاقات المرور'),
    (10021, N'SRV-10021', N'شهادة إقامة', N'Residency Certificate Request', N'إصدار أو تجديد شهادات الإقامة لسكان الوحدة السكنية', 1, 4, 3, 0, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'إصدار أو تجديد شهادات الإقامة لسكان الوحدة السكنية'),
    (10022, N'SRV-10022', N'طلب نقل سكن', N'Housing Transfer Request', N'طلب نقل الوحدة السكنية لأسباب مبررة', 1, 4, 3, 0, 0, 1, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'طلب نقل الوحدة السكنية لأسباب مبررة'),
    (10023, N'SRV-10023', N'استفسار عام', N'General Inquiry', N'استفسار عام حول خدمات الإسكان واللوائح أو الإجراءات', 1, 4, 4, 0, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'استفسار عام حول خدمات الإسكان واللوائح أو الإجراءات'),
    (10024, N'SRV-10024', N'إصدار مستند', N'Document Issuance', N'إصدار المستندات والخطابات الرسمية للإسكان', 1, 4, 3, 0, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'إصدار المستندات والخطابات الرسمية للإسكان'),
    (10025, N'SRV-10025', N'استفسار عن الرسوم', N'Fee Inquiry', N'استفسار عن رسوم الإسكان والمدفوعات والأمور المالية', 1, 4, 4, 0, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'استفسار عن رسوم الإسكان والمدفوعات والأمور المالية'),
    (10026, N'SRV-10026', N'شكوى ضوضاء', N'Noise Complaint', N'شكوى من ضوضاء مفرطة أو إزعاج من الجيران', 1, 5, 2, 1, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'شكوى من ضوضاء مفرطة أو إزعاج من الجيران'),
    (10027, N'SRV-10027', N'شكوى نظافة', N'Cleanliness Complaint', N'شكوى عن نظافة المناطق المشتركة أو المحيط', 1, 5, 2, 1, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'شكوى عن نظافة المناطق المشتركة أو المحيط'),
    (10028, N'SRV-10028', N'شكوى مواقف', N'Parking Complaint', N'شكوى عن مشاكل المواقف أو الوقوف غير المصرح به', 1, 5, 3, 1, 0, 0, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'شكوى عن مشاكل المواقف أو الوقوف غير المصرح به'),
    (10029, N'SRV-10029', N'شكوى أمنية', N'Security Complaint', N'شكوى عن مخاوف أمنية أو نقص إجراءات السلامة', 1, 5, 2, 1, 0, 1, 1, '2026-06-14T11:20:08.223', N'SEED', N'ticket-admin-setup', N'شكوى عن مخاوف أمنية أو نقص إجراءات السلامة'),
    (10030, N'SRV-10030', N'شكوى عن موظف', N'Staff Complaint', N'شكوى عن سلوك موظف أو جودة الخدمة المقدمة', 1, 5, 2, 1, 0, 1, 1, '2026-06-14T11:20:08.223', N'SEED,9,9', N'ticket-admin-setup', N'شكوى عن سلوك موظف أو جودة الخدمة المقدمة'),
    (10031, N'SRV-10031', N'خدمة اختبار k6 معدلة', N'k6 test service edited', N'k6', 1, 4, NULL, 1, 0, 0, 0, '2026-11-03T12:08:28.020', N'9,9,9', N'127.0.0.1,127.0.0.1,127.0.0.1', NULL),
    (10032, N'SRV-10032', N'خدمة اختبار k6 معدلة', N'k6 test service edited', N'k6', 1, 4, NULL, 1, 0, 0, 0, '2026-11-03T12:10:42.603', N'9,9,9', N'127.0.0.1,127.0.0.1,127.0.0.1', NULL),
    (10033, N'SRV-10033', N'خدمة اختبار k6 معدلة', N'k6 test service edited', N'k6', 1, 4, 4, 0, 0, 1, 0, '2026-11-03T12:47:08.940', N'9,9,9', N'127.0.0.1,127.0.0.1,127.0.0.1', NULL),
    (10034, N'SRV-10034', N'خدمة اختبار k6 معدلة', N'k6 test service edited', N'k6', 1, 4, 4, 0, 0, 1, 0, '2026-11-03T12:49:01.803', N'9,9,9', N'127.0.0.1,127.0.0.1,127.0.0.1', NULL),
    (10035, N'SRV-10035', N'صيانة الأبواب والنوافذ', N'Doors & Windows Maintenance', N'إصلاح الأبواب والأقفال والنوافذ', 1, 1, 3, 1, 0, 1, 1, '2026-11-05T13:42:36.357', N'9', N'ticket-admin-setup', N'إصلاح الأبواب والأقفال والنوافذ'),
    (10036, N'SRV-10036', N'صيانة المصاعد', N'Elevator Maintenance', N'إصلاح أعطال المصاعد وتشغيلها بأمان', 1, 1, 2, 1, 0, 1, 1, '2026-11-05T13:42:36.357', N'9', N'ticket-admin-setup', N'إصلاح أعطال المصاعد وتشغيلها بأمان'),
    (10037, N'SRV-10037', N'صيانة الأجهزة المنزلية', N'Home Appliances Repair', N'إصلاح الأجهزة المنزلية المسلّمة مع الوحدة السكنية', 1, 1, 3, 1, 0, 1, 1, '2026-11-05T13:42:36.357', N'9', N'ticket-admin-setup', N'إصلاح الأجهزة المنزلية المسلّمة مع الوحدة السكنية'),
    (10038, N'SRV-10038', N'المرافق العامة', N'Public Facilities', N'بلاغات الشوارع والأحياء: تسريب، انقطاع كهرباء، إنارة، طرق', 1, 1, 2, 1, 1, 1, 1, '2026-11-05T13:42:36.357', N'9,9,9', N'::1,::1,ticket-admin-setup', N'بلاغات الشوارع والأحياء: تسريب، انقطاع كهرباء، إنارة، طرق'),
    (10041, N'SRV-10041', N'خدمة تجربة الجهة', N'Unit test service', NULL, 1, NULL, NULL, 0, 0, 0, 0, '2026-11-10T14:10:06.237', N'9,9,9', N'::1,::1,::1', NULL),
    (10042, N'SRV-10042', N'خدمة تجربة الكود التلقائي', NULL, NULL, 1, NULL, NULL, 0, 0, 0, 0, '2026-11-10T14:18:11.693', N'9', N'::1', NULL)
) AS s ([serviceID], [serviceCode], [serviceName_A], [serviceName_E], [serviceDesc], [idaraID_FK], [ticketClassID_FK], [defaultPriorityID_FK], [requiresLocation], [allowsChildTickets], [requiresQualityReview], [serviceActive], [entryDate], [entryData], [hostName], [serviceDesc_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[Service] x WHERE x.[serviceID] = s.[serviceID]);
SET IDENTITY_INSERT [Tickets].[Service] OFF;
DBCC CHECKIDENT (N'[Tickets].[Service]', RESEED) WITH NO_INFOMSGS;

-- Tickets.ServiceSLAPolicy (19 rows)
SET IDENTITY_INSERT [Tickets].[ServiceSLAPolicy] ON;
INSERT INTO [Tickets].[ServiceSLAPolicy] ([serviceSLAPolicyID], [idaraID_FK], [serviceID_FK], [priorityID_FK], [firstResponseTargetMinutes], [assignmentTargetMinutes], [operationalCompletionTargetMinutes], [finalClosureTargetMinutes], [effectiveFrom], [effectiveTo], [slaPolicyActive], [entryDate], [entryData], [hostName])
SELECT s.[serviceSLAPolicyID], s.[idaraID_FK], s.[serviceID_FK], s.[priorityID_FK], s.[firstResponseTargetMinutes], s.[assignmentTargetMinutes], s.[operationalCompletionTargetMinutes], s.[finalClosureTargetMinutes], s.[effectiveFrom], s.[effectiveTo], s.[slaPolicyActive], s.[entryDate], s.[entryData], s.[hostName]
FROM (VALUES
    (1, 1, 1, 2, 60, 240, 2880, 4320, '2026-01-01T00:00:00.000', NULL, 1, '2026-04-19T13:46:23.033', N'SEED', N'SEED-HOST'),
    (2, 1, 2, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-04-19T13:46:23.033', N'SEED', N'SEED-HOST'),
    (3, 1, 3, 2, 60, 240, 2880, 4320, '2026-01-01T00:00:00.000', NULL, 1, '2026-04-19T13:46:23.033', N'SEED', N'SEED-HOST'),
    (4, 1, 4, 4, 480, 960, 10080, 14400, '2026-01-01T00:00:00.000', NULL, 1, '2026-04-19T13:46:23.033', N'SEED', N'SEED-HOST'),
    (5, 1, 5, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-04-19T13:46:23.033', N'SEED', N'SEED-HOST'),
    (6, 1, 6, 6, 20, 40, 300, 450, '2026-03-24T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (7, 1, 7, 7, 25, 50, 360, 540, '2026-03-25T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (8, 1, 8, 8, 30, 60, 420, 630, '2026-03-26T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (9, 1, 9, 9, 35, 70, 480, 720, '2026-03-27T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (10, 1, 10, 10, 40, 80, 540, 810, '2026-03-28T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (11, 1, 11, 11, 45, 90, 600, 900, '2026-03-29T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (12, 1, 12, 12, 50, 100, 660, 990, '2026-03-30T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (13, 1, 13, 13, 55, 110, 720, 1080, '2026-03-31T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (14, 1, 14, 14, 60, 120, 780, 1170, '2026-04-01T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (15, 1, 15, 15, 65, 130, 840, 1260, '2026-04-02T14:50:02.983', NULL, 1, '2026-04-22T14:50:02.983', N'SEED10', N'SEED10-HOST'),
    (16, 1, 10035, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-11-05T13:42:36.357', N'9', N'catalog-cleanup'),
    (17, 1, 10036, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-11-05T13:42:36.357', N'9', N'catalog-cleanup'),
    (18, 1, 10037, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-11-05T13:42:36.357', N'9', N'catalog-cleanup'),
    (19, 1, 10038, 3, 120, 480, 5760, 7200, '2026-01-01T00:00:00.000', NULL, 1, '2026-11-05T13:42:36.357', N'9', N'catalog-cleanup')
) AS s ([serviceSLAPolicyID], [idaraID_FK], [serviceID_FK], [priorityID_FK], [firstResponseTargetMinutes], [assignmentTargetMinutes], [operationalCompletionTargetMinutes], [finalClosureTargetMinutes], [effectiveFrom], [effectiveTo], [slaPolicyActive], [entryDate], [entryData], [hostName])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[ServiceSLAPolicy] x WHERE x.[serviceSLAPolicyID] = s.[serviceSLAPolicyID]);
SET IDENTITY_INSERT [Tickets].[ServiceSLAPolicy] OFF;
DBCC CHECKIDENT (N'[Tickets].[ServiceSLAPolicy]', RESEED) WITH NO_INFOMSGS;

-- Tickets.ServiceRoutingRule (45 rows)
SET IDENTITY_INSERT [Tickets].[ServiceRoutingRule] ON;
INSERT INTO [Tickets].[ServiceRoutingRule] ([serviceRoutingRuleID], [serviceID_FK], [idaraID_FK], [targetDSDID_FK], [queueDistributorID_FK], [effectiveFrom], [effectiveTo], [approvedByUserID], [changeReason], [serviceRoutingRuleActive], [entryDate], [entryData], [hostName], [changeReason_A])
SELECT s.[serviceRoutingRuleID], s.[serviceID_FK], s.[idaraID_FK], s.[targetDSDID_FK], s.[queueDistributorID_FK], s.[effectiveFrom], s.[effectiveTo], s.[approvedByUserID], s.[changeReason], s.[serviceRoutingRuleActive], s.[entryDate], s.[entryData], s.[hostName], s.[changeReason_A]
FROM (VALUES
    (1, 1, 1, 100, NULL, '2026-01-01T00:00:00.000', '2026-11-05T14:24:35.263', 1, N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule', 0, '2026-04-19T13:46:23.033', N'9', N'routing-setup', N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule'),
    (2, 2, 1, 101, NULL, '2026-01-01T00:00:00.000', '2026-11-05T14:24:35.263', 1, N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule', 0, '2026-04-19T13:46:23.033', N'9', N'routing-setup', N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule'),
    (3, 3, 1, 102, NULL, '2026-01-01T00:00:00.000', '2026-11-05T14:24:35.263', 1, N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule', 0, '2026-04-19T13:46:23.033', N'9', N'routing-setup', N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule'),
    (4, 4, 1, 103, NULL, '2026-01-01T00:00:00.000', '2026-11-05T14:24:35.263', 1, N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule', 0, '2026-04-19T13:46:23.033', N'9', N'routing-setup', N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule'),
    (5, 5, 1, 104, NULL, '2026-01-01T00:00:00.000', '2026-11-05T14:24:35.263', 1, N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule', 0, '2026-04-19T13:46:23.033', N'9', N'routing-setup', N'Ù‚Ø§Ø¹Ø¯Ø© Ø£ÙˆÙ„ÙŠØ© - Initial routing rule'),
    (6, 6, 1, 101, NULL, '2026-03-24T14:50:02.980', NULL, 1001, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 1', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (7, 7, 1, 102, NULL, '2026-03-25T14:50:02.980', NULL, 1002, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 2', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (8, 8, 1, 103, NULL, '2026-03-26T14:50:02.980', NULL, 1003, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 3', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (9, 9, 1, 104, NULL, '2026-03-27T14:50:02.980', NULL, 1004, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 4', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (10, 10, 1, 105, NULL, '2026-03-28T14:50:02.980', NULL, 1005, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 5', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (11, 11, 1, 106, NULL, '2026-03-29T14:50:02.980', NULL, 1006, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 6', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (12, 12, 1, 107, NULL, '2026-03-30T14:50:02.980', NULL, 1007, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 7', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (13, 13, 1, 108, NULL, '2026-03-31T14:50:02.980', NULL, 1008, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 8', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (14, 14, 1, 109, NULL, '2026-04-01T14:50:02.980', NULL, 1009, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 9', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (15, 15, 1, 110, NULL, '2026-04-02T14:50:02.980', NULL, 1010, N'Ù‚Ø§Ø¹Ø¯Ø© ØªÙˆØ¬ÙŠÙ‡ Ù…ØªØ±Ø§Ø¨Ø·Ø© Ù„Ù„Ø®Ø¯Ù…Ø© 10', 1, '2026-04-22T14:50:02.980', N'SEED10', N'SEED10-HOST', NULL),
    (10016, 1, 1, 177, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة السباكة'),
    (10017, 2, 1, 171, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة الكهرباء'),
    (10018, 3, 1, 172, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة التبريد'),
    (10019, 4, 1, 98, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة النظافة العامة'),
    (10020, 5, 1, 177, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة السباكة'),
    (10021, 10016, 1, 34, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الشبكات'),
    (10022, 10017, 1, 202, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الإتصالات الهاتفية'),
    (10023, 10018, 1, 202, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الإتصالات الهاتفية'),
    (10024, 10019, 1, 35, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الدعم الفني'),
    (10025, 10020, 1, 231, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع البصمة'),
    (10026, 10021, 1, 70, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الإسكان'),
    (10027, 10022, 1, 76, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة الإسكان'),
    (10028, 10023, 1, 10, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى قسم الإسكان والممتلكات'),
    (10029, 10024, 1, 70, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الإسكان'),
    (10030, 10025, 1, 138, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الإيرادات'),
    (10031, 10026, 1, 221, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الحراسات والدوريات'),
    (10032, 10027, 1, 98, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة النظافة العامة'),
    (10033, 10028, 1, 221, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الحراسات والدوريات'),
    (10034, 10029, 1, 221, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الحراسات والدوريات'),
    (10035, 10030, 1, 141, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى فرع الجودة'),
    (10036, 10035, 1, 180, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة النجارة'),
    (10037, 10036, 1, 174, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة الميكانيكا'),
    (10038, 10037, 1, 173, NULL, '2026-11-05T14:23:35.263', NULL, 9, N'Routing to the responsible unit', 1, '2026-11-05T14:24:35.263', N'9', N'routing-setup', N'توجيه إلى شعبة الفنية والإشراف'),
    (10039, 10038, 1, 2, NULL, '2026-11-05T14:23:35.263', '2026-11-10T14:13:33.870', 9, N'Routing to the responsible unit', 0, '2026-11-05T14:24:35.263', N'9,9', N'::1,routing-setup', N'توجيه إلى قسم صيانة المرافق'),
    (10040, 10041, 1, 6, NULL, '2026-11-10T14:10:06.237', '2026-11-10T14:10:50.583', 9, N'Responsible unit set when the service was added', 0, '2026-11-10T14:10:06.237', N'9,9', N'::1,::1', N'تحديد الجهة المسؤولة عند إضافة الخدمة'),
    (10041, 10041, 1, 156, NULL, '2026-11-10T14:10:50.583', '2026-11-10T14:11:14.280', 9, N'Responsible unit changed from the service form', 0, '2026-11-10T14:10:50.583', N'9,9', N'::1,::1', N'تغيير الجهة المسؤولة من تعديل الخدمة'),
    (10042, 10041, 1, 174, NULL, '2026-11-10T14:11:14.283', '2026-11-10T14:11:39.683', 9, N'Responsible unit changed from the service form', 0, '2026-11-10T14:11:14.283', N'9', N'::1', N'تغيير الجهة المسؤولة من تعديل الخدمة'),
    (10043, 10038, 1, 4, NULL, '2026-11-10T14:13:33.870', '2026-11-10T14:13:41.787', 9, N'Responsible unit changed from the service form', 0, '2026-11-10T14:13:33.870', N'9,9', N'::1,::1', N'تغيير الجهة المسؤولة من تعديل الخدمة'),
    (10044, 10038, 1, 2, NULL, '2026-11-10T14:13:41.787', NULL, 9, N'Responsible unit changed from the service form', 1, '2026-11-10T14:13:41.787', N'9', N'::1', N'تغيير الجهة المسؤولة من تعديل الخدمة'),
    (10045, 10042, 1, 6, NULL, '2026-11-10T14:18:11.693', '2026-11-10T14:18:30.233', 9, N'Responsible unit set when the service was added', 0, '2026-11-10T14:18:11.693', N'9', N'::1', N'تحديد الجهة المسؤولة عند إضافة الخدمة')
) AS s ([serviceRoutingRuleID], [serviceID_FK], [idaraID_FK], [targetDSDID_FK], [queueDistributorID_FK], [effectiveFrom], [effectiveTo], [approvedByUserID], [changeReason], [serviceRoutingRuleActive], [entryDate], [entryData], [hostName], [changeReason_A])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[ServiceRoutingRule] x WHERE x.[serviceRoutingRuleID] = s.[serviceRoutingRuleID]);
SET IDENTITY_INSERT [Tickets].[ServiceRoutingRule] OFF;
DBCC CHECKIDENT (N'[Tickets].[ServiceRoutingRule]', RESEED) WITH NO_INFOMSGS;

-- Tickets.TicketReason (121 rows)
SET IDENTITY_INSERT [Tickets].[TicketReason] ON;
INSERT INTO [Tickets].[TicketReason] ([ticketReasonID], [ticketReasonCode], [ticketReasonName_A], [ticketReasonName_E], [ticketReasonDesc], [serviceID_FK], [ticketClassID_FK], [priorityID_FK], [displayOrder], [ticketReasonActive], [idaraID_FK], [entryDate], [entryData], [hostName])
SELECT s.[ticketReasonID], s.[ticketReasonCode], s.[ticketReasonName_A], s.[ticketReasonName_E], s.[ticketReasonDesc], s.[serviceID_FK], s.[ticketClassID_FK], s.[priorityID_FK], s.[displayOrder], s.[ticketReasonActive], s.[idaraID_FK], s.[entryDate], s.[entryData], s.[hostName]
FROM (VALUES
    (1, N'GEN_001', N'مشكلة في الإنترنت', N'Internet Issue', N'مشكلة في الاتصال بالإنترنت', 3, 1, 2, 1, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (2, N'GEN_002', N'مشكلة عامة في الكهرباء', N'General Electrical Issue', N'مشكلة في الكهرباء أو الإضاءة', 2, 1, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (3, N'GEN_003', N'مشكلة في المياه', N'Water Issue', N'مشكلة في إمدادات المياه', 1, 1, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'1', N'catalog-cleanup'),
    (4, N'GEN_004', N'مشكلة عامة في التكييف', N'General AC Issue', N'مشكلة في نظام التكييف', 3, 1, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (5, N'GEN_005', N'طلب صيانة عامة', N'General Maintenance Request', N'طلب صيانة عامة', 1, 1, 3, 5, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (6, N'GEN_006', N'تسريب مياه', N'Water Leak', N'تسريب مياه في المبنى', 1, 1, 1, 6, 1, NULL, '2026-04-28T14:04:11.780', N'1', N'System'),
    (7, N'GEN_007', N'مشكلة عامة في المصعد', N'General Elevator Issue', N'مشكلة في عمل المصعد', 10036, 1, 1, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (8, N'GEN_008', N'مشكلة عامة في الأبواب', N'General Door Issue', N'مشكلة في الأبواب أو الأقفال', 10035, 1, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (9, N'GEN_009', N'طلب تنظيف', N'Cleaning Request', N'مشكلة في نظافة المبنى أو الوحدة', 4, 2, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (10, N'GEN_010', N'مشكلة في الأمن', N'Security Issue', N'مشكلة أمنية أو سرقة', 2, 1, 1, 10, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (11, N'GEN_011', N'مشكلة في التلفزيون', N'TV/Cable Issue', N'مشكلة في التلفزيون أو البث', 3, 1, 3, 11, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (12, N'GEN_012', N'استبدال مفروشات', N'Furniture Replacement', N'طلب استبدال المفروشات', 4, 2, 3, 12, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (13, N'GEN_013', N'جهاز منزلي معطل', N'Broken Home Appliance', N'طلب إصلاح جهاز منزلي', 10037, 1, 3, 99, 1, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (14, N'GEN_014', N'مشكلة في السباكة', N'Plumbing Issue', N'مشكلة في السباكة أو الصرف الصحي', 5, 1, 2, 99, 1, NULL, '2026-04-28T14:04:11.780', N'1', N'catalog-cleanup'),
    (15, N'GEN_015', N'آخر', N'Other', N'أي مشكلة أخرى', 4, 2, 3, 15, 0, NULL, '2026-04-28T14:04:11.780', N'9', N'catalog-cleanup'),
    (16, N'NET_001', N'انقطاع الإنترنت بالكامل', N'Complete Internet Outage', N'Total loss of internet connectivity in the housing unit', 10016, 3, 2, 1, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (17, N'NET_002', N'بطء شديد في الإنترنت', N'Severe Internet Slowness', N'Internet speed significantly below expected levels', 10016, 3, 3, 2, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (18, N'NET_003', N'مشكلة في تغطية الواي فاي', N'WiFi Coverage Issue', N'Weak or no WiFi signal in certain areas of the unit', 10016, 3, 4, 3, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (19, N'NET_004', N'عدم القدرة على الاتصال بالشبكة', N'Unable to Connect to Network', N'Network adapter or settings preventing connection', 10016, 3, 3, 4, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (20, N'NET_005', N'مشكلة متكررة في الإنترنت', N'Recurring Internet Problem', N'Internet issue that keeps happening after temporary fixes', 10016, 3, 2, 5, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (21, N'PHN_001', N'خط الهاتف لا يعمل', N'Phone Line Not Working', N'Telephone line is dead with no dial tone', 10017, 3, 3, 1, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (22, N'PHN_002', N'ضوضاء أو تشويش في الخط', N'Line Noise or Interference', N'Static noise or interference on the telephone line', 10017, 3, 3, 2, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (23, N'PHN_003', N'مقبس هاتف مكسور', N'Broken Phone Jack', N'Physical damage to the telephone wall jack', 10017, 3, 4, 3, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (24, N'PHN_004', N'طلب نقل مقبس هاتف', N'Relocate Phone Jack', N'Request to move phone jack to a different location', 10017, 3, 4, 4, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (25, N'PHN_005', N'خط هاتف جديد', N'New Phone Line Installation', N'Request to install a new telephone line', 10017, 3, 3, 5, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (26, N'INT_001', N'جهاز الاتصال الداخلي لا يعمل', N'Intercom Device Not Working', N'The intercom unit is completely unresponsive', 10018, 3, 3, 1, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (27, N'INT_002', N'صوت مكتوم أو مشوه', N'Distorted or Muffled Audio', N'Intercom audio quality is poor and unclear', 10018, 3, 3, 2, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (28, N'INT_003', N'زر الباب لا يفتح', N'Door Release Button Not Working', N'Pressing the door release button does not open the door', 10018, 3, 2, 3, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (29, N'INT_004', N'كاميرا الباب معطلة', N'Door Camera Not Working', N'The video intercom camera shows no image', 10018, 3, 3, 4, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (30, N'INT_005', N'اتصال داخلي جديد', N'New Intercom Installation', N'Request to install intercom where none exists', 10018, 3, 4, 5, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (31, N'CCTV_001', N'كاميرا مراقبة معطلة', N'CCTV Camera Offline', N'CCTV camera is not recording or showing feed', 10019, 3, 2, 1, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (32, N'CCTV_002', N'صورة كاميرا ضعيفة', N'Poor Camera Image Quality', N'CCTV image is blurry or too dark', 10019, 3, 3, 2, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (33, N'CCTV_003', N'جهاز تسجيل لا يعمل', N'DVR Not Recording', N'The recording device stopped storing footage', 10019, 3, 2, 3, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (34, N'CCTV_004', N'طلب كاميرا جديدة', N'Request New Camera', N'Install additional CCTV camera', 10019, 3, 3, 4, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (35, N'CCTV_005', N'كابل كاميرا مقطوع', N'Camera Cable Damaged', N'Camera cable has been cut or damaged', 10019, 3, 2, 5, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (36, N'ACC_001', N'بطاقة المرور لا تعمل', N'Access Card Not Working', N'Key card not recognized by the reader', 10020, 3, 2, 1, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (37, N'ACC_002', N'بوابة إلكترونية لا تفتح', N'Electronic Gate Not Opening', N'Gate fails to open with valid access', 10020, 3, 2, 2, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (38, N'ACC_003', N'قارئ بصمة معطل', N'Fingerprint Reader Malfunction', N'Biometric reader is not responding', 10020, 3, 2, 3, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (39, N'ACC_004', N'طلب بطاقة مرور جديدة', N'Request New Access Card', N'Issue a new access card', 10020, 3, 3, 4, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (40, N'ACC_005', N'نظام تحكم الدخول متوقف', N'Access Control System Down', N'Entire system is offline', 10020, 3, 1, 5, 1, NULL, '2026-06-14T11:22:07.187', N'1', N'System'),
    (41, N'RES_001', N'تجديد شهادة إقامة', N'Renew Residency Certificate', N'Renewal of expired residency certificate', 10021, 4, 3, 1, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (42, N'RES_002', N'إصدار شهادة إقامة جديدة', N'New Residency Certificate', N'First-time issuance of residency certificate', 10021, 4, 3, 2, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (43, N'RES_003', N'تصحيح بيانات الشهادة', N'Certificate Data Correction', N'Fix incorrect information on existing certificate', 10021, 4, 4, 3, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (44, N'RES_004', N'طلب نسخة إضافية', N'Additional Certificate Copy', N'Request a duplicate copy of the certificate', 10021, 4, 4, 4, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (45, N'RES_005', N'استعجال إصدار الشهادة', N'Urgent Certificate Request', N'Expedited processing of residency certificate', 10021, 4, 2, 5, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (46, N'TRF_001', N'طلب نقل بسبب زيادة عدد الأسرة', N'Transfer Due to Family Growth', N'Current unit too small for growing family', 10022, 4, 3, 1, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (47, N'TRF_002', N'طلب نقل بسبب مشكلة صحية', N'Transfer Due to Health Issue', N'Medical condition requires different accommodation', 10022, 4, 2, 2, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (48, N'TRF_003', N'طلب نقل أقرب لعمل', N'Transfer Closer to Workplace', N'Request housing closer to place of employment', 10022, 4, 3, 3, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (49, N'TRF_004', N'طلب نقل بسبب حالة اجتماعية', N'Transfer Due to Social Circumstances', N'Change in social or marital status requiring relocation', 10022, 4, 3, 4, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (50, N'TRF_005', N'استفسار عن شروط النقل', N'Transfer Eligibility Inquiry', N'Inquire about requirements and conditions for housing transfer', 10022, 4, 4, 5, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (51, N'INQ_001', N'استفسار عن شروط الإسكان', N'Housing Policy Inquiry', N'Question about housing rules and eligibility criteria', 10023, 4, 4, 1, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (52, N'INQ_002', N'استفسار عن حالة الطلب', N'Application Status Inquiry', N'Check the current status of a pending housing request', 10023, 4, 4, 2, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (53, N'INQ_003', N'استفسار عن الخدمات المتاحة', N'Available Services Inquiry', N'Question about what housing services are offered', 10023, 4, 4, 3, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (54, N'INQ_004', N'طلب توجيه أو إرشاد', N'Guidance Request', N'Need guidance on housing procedures or processes', 10023, 4, 4, 4, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (55, N'INQ_005', N'شكوى عن تأخر الرد', N'Delayed Response Complaint', N'Complaint about not receiving a timely response to inquiry', 10023, 4, 3, 5, 0, NULL, '2026-06-14T11:22:43.633', N'9', N'catalog-cleanup'),
    (56, N'DOC_001', N'طلب خطاب إثبات سكن', N'Housing Proof Letter', N'Request official letter confirming housing unit and occupant', 10024, 4, 3, 1, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (57, N'DOC_002', N'طلب كشف حساب', N'Account Statement Request', N'Request detailed statement of housing-related charges', 10024, 4, 3, 2, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (58, N'DOC_003', N'طلب خطاب عدم ملكية', N'Non-Ownership Letter', N'Request letter confirming no other property ownership', 10024, 4, 3, 3, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (59, N'DOC_004', N'طلب مستند للعمل', N'Employment Document Request', N'Request housing document required by employer', 10024, 4, 2, 4, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (60, N'DOC_005', N'طلب مستند للمحكمة', N'Court Document Request', N'Request housing document for legal or court purposes', 10024, 4, 2, 5, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (61, N'FEE_001', N'استفسار عن رصيد مالي', N'Account Balance Inquiry', N'Check current balance on housing account', 10025, 4, 4, 1, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (62, N'FEE_002', N'استفسار عن فاتورة غير واضحة', N'Unclear Invoice Inquiry', N'Question about a charge or fee on the invoice', 10025, 4, 4, 2, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (63, N'FEE_003', N'اعتراض على رسم', N'Fee Dispute', N'Disagree with a charged fee and request review', 10025, 4, 3, 3, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (64, N'FEE_004', N'طلب إيصال سداد', N'Payment Receipt Request', N'Request receipt for a previously made payment', 10025, 4, 4, 4, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (65, N'FEE_005', N'استفسار عن طريقة السداد', N'Payment Method Inquiry', N'Question about accepted payment methods and channels', 10025, 4, 4, 5, 1, NULL, '2026-06-14T11:22:43.633', N'1', N'System'),
    (66, N'NOI_001', N'ضوضاء مستمرة ليلا', N'Nighttime Noise Disturbance', N'Excessive noise during nighttime quiet hours', 10026, 5, 2, 1, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (67, N'NOI_002', N'ضوضاء من الجار المجاور', N'Neighbor Noise', N'Persistent loud noise from adjacent unit', 10026, 5, 3, 2, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (68, N'NOI_003', N'ضوضاء من ورشة أو محرك', N'Workshop or Engine Noise', N'Loud mechanical noise from nearby workshop or generator', 10026, 5, 3, 3, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (69, N'NOI_004', N'موسيقى صاخبة', N'Loud Music', N'Excessively loud music or gatherings causing disturbance', 10026, 5, 3, 4, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (70, N'NOI_005', N'ضوضاء أثناء فترة النوم', N'Sleep Disturbance Noise', N'Noise disturbing sleep during rest hours', 10026, 5, 2, 5, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (71, N'CLN_001', N'نظافة الممرات المشتركة', N'Common Hallway Cleanliness', N'Common hallways and corridors not properly cleaned', 10027, 5, 3, 1, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (72, N'CLN_002', N'نظافة المصعد', N'Elevator Cleanliness', N'Elevator interior is dirty or has unpleasant odors', 10027, 5, 3, 2, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (73, N'CLN_003', N'نظافة مواقف السيارات', N'Parking Area Cleanliness', N'Parking lot area littered and not maintained', 10027, 5, 4, 3, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (74, N'CLN_004', N'تخلص غير صحيح من النفايات', N'Improper Waste Disposal', N'Trash not properly disposed or overflowing bins', 10027, 5, 3, 4, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (75, N'CLN_005', N'تراكم الحشرات بسبب النظافة', N'Pest Due to Cleanliness', N'Pest infestation due to poor sanitation', 10027, 5, 2, 5, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (76, N'PRK_001', N'وقوف سيارة في مكان غير مخصص', N'Unauthorized Parking', N'Vehicle parked in unauthorized or reserved spot', 10028, 5, 3, 1, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (77, N'PRK_002', N'حجز موقف بشكل دائم', N'Permanent Parking Spot Occupation', N'Someone permanently occupying a shared parking spot', 10028, 5, 3, 2, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (78, N'PRK_003', N'عدم وجود موقف متاح', N'No Available Parking', N'No parking spaces available despite being a resident', 10028, 5, 3, 3, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (79, N'PRK_004', N'سيارة تعيق حركة المرور', N'Vehicle Blocking Traffic', N'Parked vehicle blocking road or driveway access', 10028, 5, 2, 4, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (80, N'PRK_005', N'طلب موقف إضافي', N'Request Extra Parking', N'Request an additional parking space allocation', 10028, 5, 4, 5, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (81, N'SEC_001', N'إضاءة ضعيفة في الممرات', N'Poor Hallway Lighting', N'Insufficient lighting in common areas posing safety risk', 10029, 5, 2, 1, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (82, N'SEC_002', N'بوابة مبنى مفتوحة', N'Building Gate Left Open', N'Main building gate found open and unsecured', 10029, 5, 2, 2, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (83, N'SEC_003', N'أشخاص غرباء في المبنى', N'Strangers in Building', N'Unfamiliar individuals entering without authorization', 10029, 5, 1, 3, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (84, N'SEC_004', N'نقص حراسة أمنية', N'Insufficient Security Guard', N'Lack of security personnel during required hours', 10029, 5, 2, 4, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (85, N'SEC_005', N'كسر أو تلف في سياج المبنى', N'Building Fence Damaged', N'Perimeter fence or gate physically damaged', 10029, 5, 2, 5, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (86, N'STF_001', N'سوء معاملة من موظف', N'Staff Misconduct', N'Report of rude or unprofessional behavior by staff', 10030, 5, 2, 1, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (87, N'STF_002', N'تأخر في تنفيذ الطلب', N'Delayed Service Execution', N'Staff not processing requests within expected timeframe', 10030, 5, 3, 2, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (88, N'STF_003', N'عدم الالتزام بالمواعيد', N'Staff Missed Appointment', N'Staff failed to show up for scheduled visit or appointment', 10030, 5, 3, 3, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (89, N'STF_004', N'جودة عمل غير مرضية', N'Unsatisfactory Work Quality', N'Work completed by staff does not meet acceptable standards', 10030, 5, 3, 4, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (90, N'STF_005', N'عدم الرد على الاتصالات', N'Staff Unresponsive', N'Staff not answering calls or responding to messages', 10030, 5, 3, 5, 1, NULL, '2026-06-14T11:23:13.697', N'1', N'System'),
    (91, N'WAT_101', N'صنبور مكسور أو لا يغلق', N'Faucet Broken or Not Closing', N'Faucet Broken or Not Closing', 1, 1, 3, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (92, N'WAT_102', N'ضعف ضغط الماء', N'Low Water Pressure', N'Low Water Pressure', 1, 1, 3, 5, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (93, N'ELE_101', N'انقطاع الكهرباء عن الوحدة', N'Power Outage in Unit', N'Power Outage in Unit', 2, 1, 2, 1, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (94, N'ELE_102', N'مقبس أو مفتاح لا يعمل', N'Socket or Switch Not Working', N'Socket or Switch Not Working', 2, 1, 3, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (95, N'ELE_103', N'إنارة لا تعمل', N'Lighting Not Working', N'Lighting Not Working', 2, 1, 3, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (96, N'ELE_104', N'رائحة احتراق أو شرارة كهربائية', N'Burning Smell or Sparks', N'Burning Smell or Sparks', 2, 1, 1, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (97, N'AC_101', N'المكيف لا يعمل', N'AC Not Working', N'AC Not Working', 3, 1, 2, 1, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (98, N'AC_102', N'المكيف لا يبرد', N'AC Not Cooling', N'AC Not Cooling', 3, 1, 2, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (99, N'AC_103', N'تسريب ماء من المكيف', N'AC Water Leak', N'AC Water Leak', 3, 1, 3, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (100, N'AC_104', N'صوت مرتفع من المكيف', N'AC Loud Noise', N'AC Loud Noise', 3, 1, 4, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (101, N'CLN_101', N'إزالة نفايات متراكمة', N'Remove Accumulated Waste', N'Remove Accumulated Waste', 4, 2, 3, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (102, N'CLN_102', N'تنظيف المناطق المشتركة', N'Clean Common Areas', N'Clean Common Areas', 4, 2, 4, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (103, N'CLN_103', N'مكافحة حشرات أو قوارض', N'Pest Control', N'Pest Control', 4, 2, 2, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (104, N'PLB_101', N'انسداد في الصرف الصحي', N'Drain Blockage', N'Drain Blockage', 5, 1, 2, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (105, N'PLB_102', N'تسريب من الأنابيب', N'Pipe Leak', N'Pipe Leak', 5, 1, 2, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (106, N'PLB_103', N'سخان الماء لا يعمل', N'Water Heater Not Working', N'Water Heater Not Working', 5, 1, 3, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (107, N'PLB_104', N'مشكلة في دورة المياه', N'Toilet Problem', N'Toilet Problem', 5, 1, 3, 5, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (108, N'DOR_101', N'قفل الباب لا يعمل', N'Door Lock Not Working', N'Door Lock Not Working', 10035, 1, 2, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (109, N'DOR_102', N'باب مكسور أو لا يغلق', N'Door Broken or Not Closing', N'Door Broken or Not Closing', 10035, 1, 3, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (110, N'DOR_103', N'نافذة مكسورة أو لا تغلق', N'Window Broken or Not Closing', N'Window Broken or Not Closing', 10035, 1, 3, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (111, N'ELV_101', N'المصعد عالق', N'Elevator Stuck', N'Elevator Stuck', 10036, 1, 1, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (112, N'ELV_102', N'المصعد لا يعمل', N'Elevator Not Working', N'Elevator Not Working', 10036, 1, 2, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (113, N'ELV_103', N'باب المصعد لا يغلق', N'Elevator Door Not Closing', N'Elevator Door Not Closing', 10036, 1, 2, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (114, N'APL_101', N'الثلاجة لا تعمل', N'Refrigerator Not Working', N'Refrigerator Not Working', 10037, 1, 3, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (115, N'APL_102', N'الغسالة لا تعمل', N'Washing Machine Not Working', N'Washing Machine Not Working', 10037, 1, 3, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (116, N'APL_103', N'الفرن أو الموقد لا يعمل', N'Oven or Stove Not Working', N'Oven or Stove Not Working', 10037, 1, 3, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (117, N'PUB_101', N'تسريب مياه في الشارع', N'Water Leak in Street', N'Water Leak in Street', 10038, 1, 2, 1, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (118, N'PUB_102', N'انقطاع الكهرباء عن الحي', N'District Power Outage', N'District Power Outage', 10038, 1, 1, 2, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (119, N'PUB_103', N'إنارة شارع معطلة', N'Street Light Out', N'Street Light Out', 10038, 1, 3, 3, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (120, N'PUB_104', N'طفح مجاري في الشارع', N'Sewage Overflow in Street', N'Sewage Overflow in Street', 10038, 1, 1, 4, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup'),
    (121, N'PUB_105', N'حفرة أو تلف في الطريق', N'Road Damage or Pothole', N'Road Damage or Pothole', 10038, 1, 3, 5, 1, 1, '2026-11-05T13:42:36.360', N'9', N'catalog-cleanup')
) AS s ([ticketReasonID], [ticketReasonCode], [ticketReasonName_A], [ticketReasonName_E], [ticketReasonDesc], [serviceID_FK], [ticketClassID_FK], [priorityID_FK], [displayOrder], [ticketReasonActive], [idaraID_FK], [entryDate], [entryData], [hostName])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[TicketReason] x WHERE x.[ticketReasonID] = s.[ticketReasonID]);
SET IDENTITY_INSERT [Tickets].[TicketReason] OFF;
DBCC CHECKIDENT (N'[Tickets].[TicketReason]', RESEED) WITH NO_INFOMSGS;

-- Tickets.TicketDescriptionTemplate (92 rows)
SET IDENTITY_INSERT [Tickets].[TicketDescriptionTemplate] ON;
INSERT INTO [Tickets].[TicketDescriptionTemplate] ([templateID], [templateCode], [templateName_A], [templateName_E], [templateContent_A], [templateContent_E], [templateDesc], [serviceID_FK], [ticketClassID_FK], [displayOrder], [templateActive], [idaraID_FK], [entryDate], [entryData], [hostName])
SELECT s.[templateID], s.[templateCode], s.[templateName_A], s.[templateName_E], s.[templateContent_A], s.[templateContent_E], s.[templateDesc], s.[serviceID_FK], s.[ticketClassID_FK], s.[displayOrder], s.[templateActive], s.[idaraID_FK], s.[entryDate], s.[entryData], s.[hostName]
FROM (VALUES
    (1, N'INT_001', N'لا يوجد اتصال بالإنترنت', N'No Internet Connection', N'لا يوجد اتصال بالإنترنت في وحدتي السكنية. يرجى التحقق من المشكلة وإصلاحها في أسرع وقت ممكن.', N'No internet connection in my housing unit. Please check and fix the issue as soon as possible.', N'قالب وصف لمشكلة الإنترنت - لا يوجد اتصال', 3, 1, 1, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (2, N'INT_002', N'إنترنت بطيء جداً', N'Very Slow Internet', N'سرعة الإنترنت في وحدتي السكنية بطيئة جداً ولا تسمح باستخدام الخدمات الأساسية.', N'The internet speed in my housing unit is very slow and does not allow using basic services.', N'قالب وصف لمشكلة الإنترنت - سرعة بطيئة', 3, 1, 2, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (3, N'ELE_001', N'انقطاع كهرباء', N'Power Outage', N'هناك انقطاع في الكهرباء في وحدتي السكنية. يرجى التحقق من المشكلة وإصلاحها.', N'There is a power outage in my housing unit. Please check and fix the issue.', N'قالب وصف لمشكلة كهربائية - انقطاع', 2, 1, 3, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (4, N'ELE_002', N'مشكلة في الإضاءة', N'Lighting Issue', N'هناك مشكلة في الإضاءة في وحدتي السكنية. بعض الإضاءة لا تعمل بشكل صحيح.', N'There is a lighting issue in my housing unit. Some lights are not working properly.', N'قالب وصف لمشكلة كهربائية - إضاءة', 2, 1, 4, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (5, N'WAT_001', N'لا يوجد ماء', N'No Water Supply', N'لا يوجد إمداد ماء في وحدتي السكنية. يرجى التحقق من المشكلة وإصلاحها في أسرع وقت.', N'There is no water supply in my housing unit. Please check and fix the issue as soon as possible.', N'قالب وصف لمشكلة المياه - لا يوجد ماء', 1, 1, 5, 1, NULL, '2026-04-28T14:04:24.933', N'1', N'System'),
    (6, N'WAT_002', N'تسريب مياه', N'Water Leak', N'هناك تسريب مياه في وحدتي السكنية/المبنى. يرجى التحقق من المشكلة وإصلاحها في أسرع وقت لتجنب الأضرار.', N'There is a water leak in my housing unit/building. Please check and fix the issue as soon as possible to avoid damages.', N'قالب وصف لمشكلة المياه - تسريب', 1, 1, 6, 1, NULL, '2026-04-28T14:04:24.933', N'1', N'System'),
    (7, N'AC_001', N'لا يعمل التكييف', N'AC Not Working', N'نظام التكييف في وحدتي السكنية لا يعمل. يرجى التحقق من المشكلة وإصلاحها.', N'The AC system in my housing unit is not working. Please check and fix the issue.', N'قالب وصف لمشكلة التكييف - لا يعمل', 3, 1, 7, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (8, N'AC_002', N'تكييف غير كافٍ', N'Insufficient Cooling', N'نظام التكييف في وحدتي السكنية لا يوفر تبريداً كافياً.', N'The AC system in my housing unit does not provide sufficient cooling.', N'قالب وصف لمشكلة التكييف - تبريد غير كافٍ', 3, 1, 8, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (9, N'GEN_001', N'طلب صيانة عامة', N'General Maintenance Request', N'أحتاج إلى صيانة عامة لوحدتي السكنية. يرجى التواصل معي لتحديد الموعد المناسب.', N'I need general maintenance for my housing unit. Please contact me to arrange a suitable time.', N'قالب وصف عام لطلب الصيانة', 1, 1, 9, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (10, N'ELV_001', N'المصعد عالق', N'Elevator Stuck', N'المصعد عالق ولا يتحرك. يرجى التدخل العاجل لإطلاق أي شخص محاصر بداخله.', N'The elevator is stuck and not moving. Please intervene urgently to free anyone trapped inside.', N'قالب وصف لمشكلة المصعد - عالق', 10036, 1, 10, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (11, N'ELV_002', N'المصعد لا يعمل', N'Elevator Not Working', N'المصعد لا يعمل بشكل صحيح. يرجى التحقق من المشكلة وإصلاحها.', N'The elevator is not working properly. Please check and fix the issue.', N'قالب وصف لمشكلة المصعد - لا يعمل', 10036, 1, 11, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (12, N'SEC_001', N'طلب ترقية الأمن', N'Security Upgrade Request', N'أرغب في طلب ترقية إجراءات الأمن في المبنى/المنطقة السكنية.', N'I would like to request security upgrades for the building/residential area.', N'قالب وصف لمشكلة الأمن - ترقية', 2, 1, 12, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (13, N'CLN_001', N'طلب تنظيف', N'Cleaning Request', N'أحتاج إلى طلب خدمة تنظيف لوحدتي السكنية/المنطقة العامة.', N'I need to request a cleaning service for my housing unit/common area.', N'قالب وصف لمشكلة النظافة', 4, 2, 13, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (14, N'FRN_001', N'استبدال مفروشات تالفة', N'Replace Damaged Furniture', N'أحتاج إلى استبدال بعض المفروشات التالفة في وحدتي السكنية.', N'I need to replace some damaged furniture in my housing unit.', N'قالب وصف لطلب استبدال المفروشات', 4, 2, 14, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (15, N'APL_001', N'إصلاح جهاز تالف', N'Repair Damaged Appliance', N'أحتاج إلى إصلاح جهاز تالف في وحدتي السكنية.', N'I need to repair a damaged appliance in my housing unit.', N'قالب وصف لطلب إصلاح جهاز', 10037, 1, 15, 1, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (16, N'PLB_001', N'انسداد في الصرف الصحي', N'Drainage Clog', N'هناك انسداد في نظام الصرف الصحي في وحدتي السكنية.', N'There is a clog in the drainage system in my housing unit.', N'قالب وصف لمشكلة السباكة - انسداد', 5, 1, 16, 1, NULL, '2026-04-28T14:04:24.933', N'1', N'System'),
    (17, N'OTH_001', N'مشكلة أخرى', N'Other Issue', N'لدي مشكلة أخرى تحتاج إلى متابعة. سأقوم بتوضيح التفاصيل عند التواصل.', N'I have another issue that needs follow-up. I will provide details upon contact.', N'قالب وصف عام لأي مشكلة أخرى', 4, 2, 17, 0, NULL, '2026-04-28T14:04:24.933', N'9', N'catalog-cleanup'),
    (18, N'NET_T001', N'انقطاع الإنترنت بالكامل', N'Complete Internet Outage', N'انقطع الاتصال بالإنترنت بالكامل في وحدتي السكنية منذ يومين ولا أستطيع تصفح أي موقع أو استخدام أي خدمة تعتمد على الشبكة. أرجو سرعة الإصلاح.', N'Internet connectivity has been completely lost in my housing unit for two days. I cannot browse any website or use any network-dependent service. Please fix urgently.', NULL, 10016, 3, 1, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (19, N'NET_T002', N'بطء شديد في الإنترنت', N'Severe Internet Slowness', N'الإنترنت يعمل بشكل شديد البطء منذ عدة أيام. سرعة التحميل لا تتجاوز كيلوبايت في الثانية رغم أنني اشترك في خدمة عالية السرعة.', N'The internet has been extremely slow for several days. Download speed does not exceed a few KB per second despite having a high-speed plan.', NULL, 10016, 3, 2, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (20, N'NET_T003', N'ضعف تغطية واي فاي', N'Weak WiFi Coverage', N'إشارة الواي فاي ضعيفة جدا في غرف النوم ولا أستطيع الاتصال إلا في غرفة المعيشة بالقرب من الراوتر مباشرة.', N'WiFi signal is very weak in the bedrooms and I can only connect in the living room near the router.', NULL, 10016, 3, 3, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (21, N'NET_T004', N'فشل الاتصال بالشبكة', N'Network Connection Failure', N'جهازي لا يستطيع الاتصال بالشبكة رغم أن الإنترنت يعمل على الأجهزة الأخرى في المنزل. أرجو الفحص.', N'My device cannot connect to the network even though the internet works on other devices in the home.', NULL, 10016, 3, 4, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (22, N'NET_T005', N'انقطاع متكرر', N'Recurring Disconnection', N'الإنترنت ينقطع ويعود عدة مرات في اليوم منذ أسبوع. المشكلة متكررة ومؤثرة على عملي اليومي.', N'The internet disconnects and reconnects several times a day for the past week. The recurring issue is affecting my daily work.', NULL, 10016, 3, 5, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (23, N'PHN_T001', N'خط هاتف معطل', N'Dead Phone Line', N'خط الهاتف في وحدتي السكنية لا يعمل منذ فترة. لا توجد نغمة اتصال عند رفع السماعة.', N'The phone line in my housing unit has been non-functional for a while. There is no dial tone when lifting the receiver.', NULL, 10017, 3, 1, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (24, N'PHN_T002', N'تشويش على خط الهاتف', N'Phone Line Interference', N'أسمع ضوضاء وتشويش مستمر عند التحدث عبر الهاتف مما يجعل المحادثة صعبة جدا.', N'I hear continuous noise and interference when talking on the phone making conversations very difficult.', NULL, 10017, 3, 2, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (25, N'PHN_T003', N'تلف مقبس الهاتف', N'Damaged Phone Jack', N'مقبس الهاتف في الجدار تالف ومكسور ويحتاج استبدال لتشغيل خط الهاتف.', N'The telephone wall jack is damaged and broken and needs to be replaced to operate the phone line.', NULL, 10017, 3, 3, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (26, N'PHN_T004', N'طلب نقل مقبس الهاتف', N'Relocate Phone Jack', N'أرجو نقل مقبس الهاتف من مكانه الحالي إلى غرفة المعيشة لأن موقعه الحالي غير عملي.', N'Please relocate the phone jack from its current location to the living room as the current location is impractical.', NULL, 10017, 3, 4, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (27, N'PHN_T005', N'تركيب خط هاتف جديد', N'New Phone Line Install', N'أرجو تركيب خط هاتف جديد في الوحدة السكنية لأنه لا يوجد خط هاتف حاليا.', N'Please install a new telephone line in the housing unit as there is no existing phone line.', NULL, 10017, 3, 5, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (28, N'INT_T001', N'جهاز الاتصال الداخلي معطل', N'Intercom Unit Broken', N'جهاز الاتصال الداخلي لا يعمل إطلاقا ولا أستطيع التواصل مع الزوار عند الباب.', N'The intercom unit does not work at all and I cannot communicate with visitors at the door.', NULL, 10018, 3, 1, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (29, N'INT_T002', N'صورة كاميرا الباب غير واضحة', N'Unclear Door Camera', N'صورة كاميرا الفيديو عند الباب غير واضحة ولا أستطيع تمييز وجه الزائر.', N'The door video camera image is unclear and I cannot identify the visitors face.', NULL, 10018, 3, 2, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (30, N'INT_T003', N'زر فتح الباب لا يعمل', N'Door Release Failure', N'زر فتح الباب الرئيسي في جهاز الاتصال الداخلي لا يعمل وأضطر للنزول لفتح الباب يدويا.', N'The main door release button on the intercom does not work and I have to go down to open the door manually.', NULL, 10018, 3, 3, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (31, N'INT_T004', N'تركيب اتصال داخلي', N'Intercom Installation', N'أرجو تركيب جهاز اتصال داخلي في وحدتي السكنية لأنه غير متوفر حاليا.', N'Please install an intercom unit in my housing unit as it is not currently available.', NULL, 10018, 3, 4, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (32, N'INT_T005', N'صوت مشوه في الاتصال', N'Distorted Intercom Audio', N'صوت الاتصال الداخلي مشوه ومكتوم جدا ولا أسمع الزائر بوضوح.', N'The intercom audio is distorted and muffled and I cannot hear the visitor clearly.', NULL, 10018, 3, 5, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (33, N'CCTV_T001', N'كاميرا مراقبة معطلة', N'CCTV Camera Down', N'إحدى كاميرات المراقبة في موقف السيارات معطلة منذ عدة أيام ولا تسجل.', N'One of the CCTV cameras in the parking area has been offline for several days and is not recording.', NULL, 10019, 3, 1, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (34, N'CCTV_T002', N'جودة صورة الكاميرا رديئة', N'Poor CCTV Quality', N'صورة كاميرا المراقبة عند المدخل ضبابية جدا ولا يمكن تمييز الأشخاص أو السيارات.', N'The entrance CCTV camera image is very blurry and it is impossible to identify people or vehicles.', NULL, 10019, 3, 2, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (35, N'CCTV_T003', N'جهاز التسجيل لا يحفظ', N'DVR Not Storing Footage', N'جهاز التسجيل لا يحفظ المقاطع المرئية رغم أن الكاميرات تعمل. أرجو الفحص العاجل.', N'The recording device is not storing footage even though the cameras are working. Please inspect urgently.', NULL, 10019, 3, 3, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (36, N'CCTV_T004', N'طلب تركيب كاميرا إضافية', N'Install Additional Camera', N'أرجو تركيب كاميرا مراقبة إضافية عند مدخل المبنى الجانبي لتغطية نقطة أمنية.', N'Please install an additional CCTV camera at the side building entrance to cover a security blind spot.', NULL, 10019, 3, 4, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (37, N'CCTV_T005', N'إصلاح كابل كاميرا', N'Fix Camera Cable', N'كابل كاميرا المراقبة في الطابق الثاني مقطوع ومعلق. أرجو الإصلاح.', N'The CCTV camera cable on the second floor is cut and hanging. Please repair.', NULL, 10019, 3, 5, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (38, N'ACC_T001', N'بطاقة المرور غير مقروءة', N'Access Card Unreadable', N'بطاقة المرور الخاصة بي لا تعمل عند تمريرها على القارئ. أرجو استبدالها أو إعادة برمجتها.', N'My access card does not work when tapped on the reader. Please replace or reprogram it.', NULL, 10020, 3, 1, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (39, N'ACC_T002', N'البوابة الإلكترونية لا تفتح', N'Electronic Gate Stuck', N'البوابة الإلكترونية للزوار لا تفتح عند استخدام بطاقة المرور أو الزر. أرجو الفحص.', N'The visitor electronic gate does not open when using the access card or button. Please inspect.', NULL, 10020, 3, 2, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (40, N'ACC_T003', N'قارئ البصمة معطل', N'Fingerprint Reader Down', N'قارئ البصمة عند المدخل الرئيسي معطل ولا يقبل بصمة أي شخص. أرجو الإصلاح العاجل.', N'The fingerprint reader at the main entrance is not accepting anyones fingerprint. Please repair urgently.', NULL, 10020, 3, 3, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (41, N'ACC_T004', N'إصدار بطاقة مرور جديدة', N'Issue New Access Card', N'أرجو إصدار بطاقة مرور جديدة لأن بطاقتي القديمة فقدت ولا أستطيع الدخول.', N'Please issue a new access card because I lost my old card and cannot enter.', NULL, 10020, 3, 4, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (42, N'ACC_T005', N'نظام الدخول متوقف بالكامل', N'Access System Completely Down', N'نظام التحكم بالدخول متوقف بالكامل في البوابة الرئيسية ولا أحد يستطيع الدخول أو الخروج.', N'The access control system is completely down at the main gate and no one can enter or exit.', NULL, 10020, 3, 5, 1, NULL, '2026-06-14T11:24:09.870', N'1', N'System'),
    (43, N'RES_T001', N'تجديد شهادة إقامة', N'Renew Residency Certificate', N'أرجو تجديد شهادة الإقامة الخاصة بي لأنها انتهت صلاحيتها وأحتاجها للجهات الرسمية.', N'Please renew my residency certificate as it has expired and I need it for official purposes.', NULL, 10021, 4, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (44, N'RES_T002', N'إصدار شهادة أولى', N'First Certificate Issuance', N'أرجو إصدار شهادة إقامة لأول مرة لأنني ساكن جديد ولم تصدر لي شهادة من قبل.', N'Please issue a residency certificate for the first time as I am a new resident and have not been issued one before.', NULL, 10021, 4, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (45, N'RES_T003', N'تصحيح بيانات الشهادة', N'Correct Certificate Data', N'توجد أخطاء في بيانات شهادة الإقامة الخاصة بي. الاسم مكتوب بشكل خاطئ. أرجو التصحيح.', N'There are errors in my residency certificate data. The name is written incorrectly. Please correct.', NULL, 10021, 4, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (46, N'RES_T004', N'طلب نسخة إضافية', N'Duplicate Copy Request', N'أحتاج نسخة إضافية من شهادة الإقامة لتقديمها لجهة حكومية أخرى.', N'I need an additional copy of my residency certificate to submit to another government entity.', NULL, 10021, 4, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (47, N'RES_T005', N'تجديد استعجالي', N'Urgent Certificate Renewal', N'أحتاج تجديد شهادة الإقامة بشكل عاجل لتقديمها في موعد محدد خلال أيام.', N'I urgently need to renew my residency certificate to submit by a specific deadline within days.', NULL, 10021, 4, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (48, N'TRF_T001', N'نقل بسبب زيادة أفراد الأسرة', N'Transfer Due to Family Size', N'عدد أفراد أسرتي تزايد والوحدة الحالية لا تكفي. أرجو مراعاة طلبي في النقل إلى وحدة أكبر.', N'My family size has increased and the current unit is insufficient. Please consider my transfer request to a larger unit.', NULL, 10022, 4, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (49, N'TRF_T002', N'نقل بسبب ظروف صحية', N'Transfer Due to Health', N'لدي ظروف صحية تتطلب وحدة سكنية في طابق أرضي. أرجو مراعاة طلبي.', N'I have health conditions requiring a ground floor housing unit. Please consider my request.', NULL, 10022, 4, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (50, N'TRF_T003', N'نقل بسبب بعد مكان العمل', N'Transfer Closer to Work', N'مكان عملي الجديد بعيد جدا عن سكني الحالي. أرجو نقلنا إلى وحدة أقرب.', N'My new workplace is very far from my current housing. Please transfer us to a closer unit.', NULL, 10022, 4, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (51, N'TRF_T004', N'نقل بسبب ظروف اجتماعية', N'Transfer Due to Social Change', N'تغيرت ظروفي الاجتماعية وأحتاج نقل وحدتي السكنية. أرجو دراسة طلبي.', N'My social circumstances have changed and I need to relocate my housing unit. Please study my request.', NULL, 10022, 4, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (52, N'TRF_T005', N'استفسار عن أهلية النقل', N'Transfer Eligibility Check', N'أريد الاستفسار عن الشروط المطلوبة لنقل وحدة سكنية وهل أنا مؤهل أم لا.', N'I want to inquire about the requirements for housing unit transfer and whether I am eligible.', NULL, 10022, 4, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (53, N'INQ_T001', N'استفسار عن شروط الإسكان', N'Housing Policy Question', N'أريد الاستفسار عن الشروط واللوائح المتعلقة بتخصيص السكن وشروط الأهلية.', N'I want to inquire about the rules and regulations related to housing allocation and eligibility criteria.', NULL, 10023, 4, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (54, N'INQ_T002', N'استفسار عن حالة طلب سابق', N'Pending Application Status', N'أقدمت بطلب منذ فترة وأريد معرفة حالته الحالية وهل تمت معالجته.', N'I submitted a request some time ago and want to know its current status and whether it has been processed.', NULL, 10023, 4, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (55, N'INQ_T003', N'استفسار عن الخدمات المتاحة', N'Available Services', N'أريد معرفة الخدمات التي تقدمها إدارة الإسكان للمقيمين وكيفية الاستفادة منها.', N'I want to know what services the housing administration provides to residents and how to benefit from them.', NULL, 10023, 4, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (56, N'INQ_T004', N'طلب توجيه للإجراءات', N'Procedure Guidance', N'أحتاج مساعدة في فهم الإجراءات المطلوبة لتقديم طلب معين في الإسكان.', N'I need help understanding the procedures required to submit a specific housing request.', NULL, 10023, 4, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (57, N'INQ_T005', N'شكوى تأخر الرد', N'Complaint About Delayed Reply', N'قدمت استفسارا من فترة ولم أتلق ردا حتى الآن. أرجو سرعة الرد على استفساري.', N'I submitted an inquiry a while ago and have not received a response yet. Please reply to my inquiry promptly.', NULL, 10023, 4, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (58, N'DOC_T001', N'طلب خطاب إثبات سكن', N'Housing Proof Letter', N'أرجو إصدار خطاب رسمي يثبت سكني في الوحدة رقم كذا وأني مقيم بشكل نظامي.', N'Please issue an official letter confirming my residence in unit number such-and-such as a legal resident.', NULL, 10024, 4, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (59, N'DOC_T002', N'طلب كشف حساب', N'Account Statement', N'أرجو إصدار كشف حساب مفصل يوضح جميع المبالغ المستحقة والمدفوعة على حسابي السكني.', N'Please issue a detailed account statement showing all outstanding and paid amounts on my housing account.', NULL, 10024, 4, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (60, N'DOC_T003', N'طلب خطاب عدم ملكية', N'Non-Ownership Letter', N'أحتاج خطاب رسمي يفيد بعدم ملكيتي لأي عقار آخر بخلاف الوحدة السكنية الحالية.', N'I need an official letter stating that I do not own any other property besides my current housing unit.', NULL, 10024, 4, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (61, N'DOC_T004', N'مستند مطلوب للعمل', N'Employment Document', N'أحتاج مستند سكن رسمي لتقديمه لمصدري في جهة عملي.', N'I need an official housing document to submit to my employer.', NULL, 10024, 4, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (62, N'DOC_T005', N'مستند مطلوب للمحكمة', N'Court Document', N'أرجو إصدار مستند سكن لتقديمه في قضية لدى المحكمة.', N'Please issue a housing document to submit in a court case.', NULL, 10024, 4, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (63, N'FEE_T001', N'استفسار عن الرصيد', N'Balance Inquiry', N'أريد معرفة رصيدي الحالي في حساب الإسكان وهل هناك مبالغ مستحقة.', N'I want to know my current balance in the housing account and whether there are any outstanding amounts.', NULL, 10025, 4, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (64, N'FEE_T002', N'استفسار عن فاتورة غير واضحة', N'Unclear Invoice', N'هناك بند في فاتورتي لا أعرف سببه. أرجو التوضيح وتفصيل الرسوم.', N'There is an item on my invoice that I do not understand. Please clarify and detail the charges.', NULL, 10025, 4, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (65, N'FEE_T003', N'اعتراض على رسم محاسب', N'Fee Dispute', N'تم احتساب رسم لا أستحقه وأعترض عليه. أرجو المراجعة وإلغاء المبلغ الخاطئ.', N'A fee that I do not owe has been charged and I object to it. Please review and cancel the incorrect amount.', NULL, 10025, 4, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (66, N'FEE_T004', N'طلب إيصال سداد', N'Payment Receipt', N'سددت مبلغا سابقا ولم أحصل على إيصال. أرجو إصدار إيصال رسمي بالسداد.', N'I made a payment previously and did not receive a receipt. Please issue an official payment receipt.', NULL, 10025, 4, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (67, N'FEE_T005', N'طرق الدفع المتاحة', N'Payment Methods', N'أريد معرفة طرق الدفع المتاحة لسداد رسوم الإسكان وهل يمكن الدفع الإلكتروني.', N'I want to know the available payment methods for housing fees and whether electronic payment is possible.', NULL, 10025, 4, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (68, N'NOI_T001', N'ضوضاء مستمرة ليلا', N'Nighttime Noise', N'الجار في الطابق العلوي يقوم بأعمال صاخبة بعد الساعة الحادية عشرة ليلا بشكل متكرر مما يزعجنا ويؤثر على نوم أطفالي.', N'The upstairs neighbor performs noisy activities after 11 PM regularly which disturbs us and affects my childrens sleep.', NULL, 10026, 5, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (69, N'NOI_T002', N'ضوضاء من الجار المجاور', N'Neighbor Noise', N'الجار المجاور يشغل التلفاز والراديو بصوت عال جدا بشكل يومي خاصة في أوقات الراحة.', N'The next door neighbor plays the TV and radio very loudly on a daily basis especially during rest hours.', NULL, 10026, 5, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (70, N'NOI_T003', N'ضوضاء من محرك أو ورشة', N'Workshop Noise', N'يوجد ورشة عمل أو مولد كهرباء بالقرب من وحدتي السكنية يصدر ضوضاء مستمرة طوال اليوم.', N'There is a workshop or generator near my housing unit that produces continuous noise all day.', NULL, 10026, 5, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (71, N'NOI_T004', N'حفلات صاخبة', N'Loud Gatherings', N'يقيم الجار حفلات ومناسبات صاخبة بشكل متكرر دون مراعاة للسكان الآخرين.', N'The neighbor frequently hosts loud parties and gatherings without consideration for other residents.', NULL, 10026, 5, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (72, N'NOI_T005', N'ضوضاء أثناء النوم', N'Sleep Disturbance', N'أصوات مزعجة من وحدة مجاورة تستمر لساعات متأخرة من الليل وتمنعني من النوم.', N'Annoying sounds from a neighboring unit continue late into the night preventing me from sleeping.', NULL, 10026, 5, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (73, N'CLN_T001', N'ممرات مشتركة غير نظيفة', N'Dirty Common Hallways', N'الممرات المشتركة في الطابق لا تنظف بانتظام وتراكمت الأوساخ والأتربة.', N'The common hallways on the floor are not cleaned regularly and dirt and dust have accumulated.', NULL, 10027, 5, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (74, N'CLN_T002', N'مصعد غير نظيف', N'Dirty Elevator', N'المصعد دائما متسخ وبه بقايا طعام وروائح كريهة. أرجو تكثيف التنظيف.', N'The elevator is always dirty with food remnants and unpleasant odors. Please increase cleaning frequency.', NULL, 10027, 5, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (75, N'CLN_T003', N'موقف سيارات وسخ', N'Dirty Parking Lot', N'مواقف السيارات مليئة بالأوساخ والقمامة ولم يتم تنظيفها منذ فترة طويلة.', N'The parking lots are full of dirt and garbage and have not been cleaned for a long time.', NULL, 10027, 5, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (76, N'CLN_T004', N'نفايات متراكمة', N'Overflowing Waste Bins', N'سلات المهملات ممتلئة والقمامات متناثرة حولها مما يسبب روائح كريهة.', N'The waste bins are overflowing and garbage is scattered around causing bad odors.', NULL, 10027, 5, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (77, N'CLN_T005', N'حشرات بسبب النظافة', N'Pest Infestation', N'ظهرت حشرات في المنطقة المشتركة بسبب سوء النظافة. أرجو المعالجة والتنظيف العاجل.', N'Pests have appeared in the common area due to poor cleanliness. Please treat and clean urgently.', NULL, 10027, 5, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (78, N'PRK_T001', N'وقوف في مكان غير مخصص', N'Unauthorized Parking', N'سيارة مجهولة تقف في موقفي المخصص بشكل متكرر. أرجو اتخاذ الإجراء اللازم.', N'An unknown vehicle regularly parks in my assigned spot. Please take appropriate action.', NULL, 10028, 5, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (79, N'PRK_T002', N'حجز موقف بشكل دائم', N'Parking Spot Monopolized', N'أحد السكان يقوم بحجز أكثر من موقف بطريقة دائمة مما يحرم الآخرين من أماكن الوقوف.', N'One resident permanently occupies multiple parking spots depriving others of parking spaces.', NULL, 10028, 5, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (80, N'PRK_T003', N'لا يوجد موقف فارغ', N'No Parking Available', N'عند عودتي من العمل لا أجد أي موقف فارغ رغم أنني من سكان المبنى.', N'When I return from work I cannot find any empty parking spot despite being a building resident.', NULL, 10028, 5, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (81, N'PRK_T004', N'سيارة تعيق الممر', N'Vehicle Blocking Path', N'سيارة متوقفة أمام مدخل المبنى وتمنع دخول وخروج السيارات بشكل كامل.', N'A vehicle is parked in front of the building entrance blocking all vehicle entry and exit.', NULL, 10028, 5, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (82, N'PRK_T005', N'طلب موقف إضافي', N'Extra Parking Request', N'لدي سيارتان وأحتاج موقفا إضافي. أرجو دراسة طلبي وتخصيص موقف ثاني.', N'I have two cars and need an additional parking spot. Please consider my request and allocate a second spot.', NULL, 10028, 5, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (83, N'SEC_T001', N'إضاءة ضعيفة في الممرات', N'Poor Hallway Lighting', N'إضاءة الممرات المشتركة ضعيفة جدا وخاصة في الليل مما يشكل خطرا أمنيا على السكان.', N'Common hallway lighting is very poor especially at night posing a security risk to residents.', NULL, 10029, 5, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (84, N'SEC_T002', N'بوابة المبنى مفتوحة', N'Building Gate Open', N'البوابة الرئيسية للمبنى تترك مفتوحة لفترات طويلة بدون حراسة مما يسمح بدخول أي شخص.', N'The main building gate is left open for long periods without security allowing anyone to enter.', NULL, 10029, 5, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (85, N'SEC_T003', N'أشخاص مجهولون في المبنى', N'Strangers in Building', N'لagedListoned أشخاص مجهولين يتجولون في المبنى بشكل متكرر بدون هدف واضح.', N'Unknown persons have been roaming the building frequently without a clear purpose.', NULL, 10029, 5, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (86, N'SEC_T004', N'نقص في الحراسة', N'Insufficient Security', N'لا يوجد حارس أمن في أوقات كثيرة من اليوم خاصة في الفترة المسائية.', N'There is no security guard present during many hours of the day especially in the evening.', NULL, 10029, 5, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (87, N'SEC_T005', N'سياج المبنى متضرر', N'Damaged Building Fence', N'السياج المحيط بالمبنى به فجوة كبيرة تسمح بدخول الحيوانات والأشخاص من الجانب.', N'The building perimeter fence has a large gap allowing animals and people to enter from the side.', NULL, 10029, 5, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (88, N'STF_T001', N'سوء معاملة من موظف', N'Staff Rudeness', N'تعامل موظف معي بطريقة غير لائقة وأسيء اللفظ أثناء استفساري عن خدمة الإسكان.', N'A staff member treated me inappropriately and used offensive language during my housing service inquiry.', NULL, 10030, 5, 1, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (89, N'STF_T002', N'تأخر في تنفيذ طلب', N'Delayed Request Processing', N'قدمت طلب صيانة منذ أكثر من أسبوعين ولم يتم التنفيذ حتى الآن رغم المتابعة.', N'I submitted a maintenance request over two weeks ago and it has not been completed despite follow-ups.', NULL, 10030, 5, 2, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (90, N'STF_T003', N'عدم الحضور للموعد', N'Missed Scheduled Visit', N'تم تحديد موعد لفحص وحدتي السكنية ولم يحضر أحد من فريق الصيانة.', N'A date was set to inspect my housing unit and no one from the maintenance team showed up.', NULL, 10030, 5, 3, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (91, N'STF_T004', N'جودة عمل غير مقبولة', N'Poor Workmanship', N'تم إصلاح مشكلة سابقة لكن جودة العمل غير مقبولة والمشكلة عادت بعد فترة قصيرة.', N'A previous issue was fixed but the work quality was unacceptable and the problem returned shortly after.', NULL, 10030, 5, 4, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System'),
    (92, N'STF_T005', N'عدم الرد على الاتصالات', N'Staff Unresponsive to Calls', N'أتصل بمكتب الإسكان بشكل متكرر ولا أحد يرد على الهاتف أو يتابع طلبي.', N'I call the housing office repeatedly and no one answers the phone or follows up on my request.', NULL, 10030, 5, 5, 1, NULL, '2026-06-14T11:26:16.263', N'1', N'System')
) AS s ([templateID], [templateCode], [templateName_A], [templateName_E], [templateContent_A], [templateContent_E], [templateDesc], [serviceID_FK], [ticketClassID_FK], [displayOrder], [templateActive], [idaraID_FK], [entryDate], [entryData], [hostName])
WHERE NOT EXISTS (SELECT 1 FROM [Tickets].[TicketDescriptionTemplate] x WHERE x.[templateID] = s.[templateID]);
SET IDENTITY_INSERT [Tickets].[TicketDescriptionTemplate] OFF;
DBCC CHECKIDENT (N'[Tickets].[TicketDescriptionTemplate]', RESEED) WITH NO_INFOMSGS;

PRINT N'Part 2: program, menus, distributors and permission types';

-- Program
IF NOT EXISTS (SELECT 1 FROM dbo.Program WHERE programName_E = N'Tickets')
    INSERT INTO dbo.Program (programName_A, programName_E, programDescription, programActive, programLink, programIcon, programSerial, entryDate)
    VALUES (N'نظام التذاكر', N'Tickets', N'Ticket Management System', 1, N'Ticket', N'fa-solid fa-ticket', 18, GETDATE());

DECLARE @programID INT = (SELECT TOP 1 programID FROM dbo.Program WHERE programName_E = N'Tickets' ORDER BY programID);

-- Menus (one per ticket page)
INSERT INTO dbo.Menu (menuName_A, menuName_E, menuDescription, parentMenuID_FK, menuLink, programID_FK, menuSerial, menuActive, isDashboard, PageLvl)
SELECT s.menuName_A, s.menuName_E, s.menuDescription, NULL, s.menuLink, @programID, s.menuSerial, s.menuActive, s.isDashboard, s.PageLvl
FROM (VALUES
    (N'قائمة التذاكر', N'TicketList', N'Ticket List', N'TicketList', 1, 1, 0, 3),
    (N'إجراءات التذاكر', N'TicketDetails', N'Ticket Details', N'TicketDetails', 2, 1, 0, 3),
    (N'إعدادات التذاكر', N'TicketAdmin', N'Ticket Admin', N'TicketAdmin', 3, 1, 0, 2),
    (N'دليل الخدمات', N'ServiceCatalogueList', N'Service Catalogue', N'ServiceCatalogueList', 4, 1, 0, 2)
) AS s (menuName_A, menuName_E, menuDescription, menuLink, menuSerial, menuActive, isDashboard, PageLvl)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Menu m WHERE m.menuName_E = s.menuName_E AND m.programID_FK = @programID);

-- PageLvl 0 hides the ticket pages from the permissions screen (it lists levels 1-3 only).
-- Fix menus created by earlier runs of this script.
UPDATE m SET PageLvl = CASE m.menuName_E WHEN N'TicketAdmin' THEN 2 WHEN N'ServiceCatalogueList' THEN 2 ELSE 3 END
FROM dbo.Menu m
WHERE m.programID_FK = @programID
  AND m.PageLvl = 0
  AND m.menuName_E IN (N'TicketList', N'TicketDetails', N'TicketAdmin', N'ServiceCatalogueList');

-- Distributors (permission groups per page)
INSERT INTO dbo.Distributor (distributorName_A, distributorName_E, distributorDescription, distributorCode, distributorActive, distributorType_FK, roleID_FK, entryDate)
SELECT s.distributorName_A, s.distributorName_E, s.distributorDescription, s.distributorCode, s.distributorActive, s.distributorType_FK, s.roleID_FK, GETDATE()
FROM (VALUES
    (N'قائمة التذاكر: عرض وإنشاء التذاكر', N'Perm - TicketList', N'TicketList', N'TKT-TLIST', 1, 4, 1),
    (N'إجراءات التذاكر: توجيه وإسناد وحل وإغلاق', N'Perm - TicketDetails', N'TicketDetails', N'TKT-TDET', 1, 4, 1),
    (N'إعدادات التذاكر: الفئات والأولويات والحالات', N'Perm - TicketAdmin', N'TicketAdmin', N'TKT-TADM', 1, 4, 1),
    (N'الصلاحيات - إدارة التذاكر', N'Perm - Tickets CRUD', N'Tickets', N'TKT-CRUD', 1, 4, 1),
    (N'دليل الخدمات: إضافة وتعديل الخدمات', N'Perm - Service Catalogue', N'Service Catalogue', N'TKT-SCAT', 1, 4, 1)
) AS s (distributorName_A, distributorName_E, distributorDescription, distributorCode, distributorActive, distributorType_FK, roleID_FK)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Distributor d WHERE d.distributorCode = s.distributorCode);

-- Permission types (ACCESS, INSERT_TICKET, ROUTE_TICKET ...)
INSERT INTO dbo.PermissionType (permissionTypeName_A, permissionTypeName_E, permissionTypeActive, RoleID_FK)
SELECT s.permissionTypeName_A, s.permissionTypeName_E, s.permissionTypeActive, s.RoleID_FK
FROM (VALUES
    (N'وصول', N'ACCESS', 1, NULL),
    (N'الموافقة على اقتراحات الخدمات', N'APPROVESERVICESUGGESTION', 1, 1),
    (N'تعيين التذكرة', N'ASSIGN_TICKET', 1, NULL),
    (N'إلغاء التحكيم', N'CANCEL_ARBITRATION', 1, 1),
    (N'إغلاق التذكرة', N'CLOSE_TICKET', 1, NULL),
    (N'إنشاء تذكرة فرعية', N'CREATE_CHILD_TICKET', 1, NULL),
    (N'اتخاذ قرار التحكيم', N'DECIDE_ARBITRATION', 1, 1),
    (N'حذف', N'DELETE', 1, NULL),
    (N'حذف مرفق', N'DELETE_ATTACHMENT', 1, 1),
    (N'حذف سبب تحكيم', N'DELETEARBITRATIONREASON', 1, 1),
    (N'حذف سبب إيقاف', N'DELETEPAUSEREASON', 1, 1),
    (N'حذف أولوية', N'DELETEPRIORITY', 1, 1),
    (N'حذف نتيجة مراجعة جودة', N'DELETEQUALITYREVIEWRESULT', 1, 1),
    (N'حذف خدمة', N'DELETESERVICE', 1, 1),
    (N'حذف فئة تذكرة', N'DELETETICKETCLASS', 1, 1),
    (N'حذف حالة تذكرة', N'DELETETICKETSTATUS', 1, 1),
    (N'اعتماد مراجعة الجودة', N'FINALIZE_QUALITY_REVIEW', 1, 1),
    (N'ادخال', N'INSERT', 1, NULL),
    (N'إنشاء تذكرة', N'INSERT_TICKET', 1, 1),
    (N'إضافة سبب تحكيم', N'INSERTARBITRATIONREASON', 1, 1),
    (N'إضافة سبب إيقاف', N'INSERTPAUSEREASON', 1, 1),
    (N'إضافة أولوية', N'INSERTPRIORITY', 1, 1),
    (N'إضافة نتيجة مراجعة جودة', N'INSERTQUALITYREVIEWRESULT', 1, 1),
    (N'إضافة خدمة', N'INSERTSERVICE', 1, 1),
    (N'إضافة فئة تذكرة', N'INSERTTICKETCLASS', 1, 1),
    (N'إضافة حالة تذكرة', N'INSERTTICKETSTATUS', 1, 1),
    (N'إدارة قواعد التوجيه', N'MANAGEROUTINGRULES', 1, 1),
    (N'إدارة سياسات SLA', N'MANAGESLAPOLICIES', 1, 1),
    (N'إيقاف التذكرة', N'PAUSE_TICKET', 1, NULL),
    (N'رفع تحكيم', N'RAISE_ARBITRATION', 1, NULL),
    (N'إعادة إسناد التذكرة', N'REASSIGN_TICKET', 1, NULL),
    (N'رفض التذكرة', N'REJECT_TICKET', 1, NULL),
    (N'إعادة فتح التذكرة', N'REOPEN_TICKET', 1, NULL),
    (N'طلب توضيح', N'REQUEST_CLARIFICATION', 1, 1),
    (N'حل التذكرة', N'RESOLVE_TICKET', 1, NULL),
    (N'الرد على التوضيح', N'RESPOND_CLARIFICATION', 1, 1),
    (N'استئناف التذكرة', N'RESUME_TICKET', 1, NULL),
    (N'توجيه التذكرة', N'ROUTE_TICKET', 1, NULL),
    (N'قراءة', N'SELECT', 1, NULL),
    (N'بدء العمل', N'START_WORK', 1, NULL),
    (N'تسجيل نتيجة مراجعة الجودة', N'SUBMIT_QUALITY_REVIEW', 1, 1),
    (N'تحديث', N'UPDATE', 1, NULL),
    (N'تعديل أولوية التذكرة', N'UPDATE_PRIORITY', 1, 1),
    (N'تعديل سبب تحكيم', N'UPDATEARBITRATIONREASON', 1, 1),
    (N'تعديل سبب إيقاف', N'UPDATEPAUSEREASON', 1, 1),
    (N'تعديل أولوية', N'UPDATEPRIORITY', 1, 1),
    (N'تعديل نتيجة مراجعة جودة', N'UPDATEQUALITYREVIEWRESULT', 1, 1),
    (N'تعديل خدمة', N'UPDATESERVICE', 1, 1),
    (N'تعديل فئة تذكرة', N'UPDATETICKETCLASS', 1, 1),
    (N'تعديل حالة تذكرة', N'UPDATETICKETSTATUS', 1, 1),
    (N'رفع مرفق', N'UPLOAD_ATTACHMENT', 1, NULL)
) AS s (permissionTypeName_A, permissionTypeName_E, permissionTypeActive, RoleID_FK)
WHERE NOT EXISTS (SELECT 1 FROM dbo.PermissionType p WHERE p.permissionTypeName_E = s.permissionTypeName_E);

-- Which permission types each ticket page offers
INSERT INTO dbo.DistributorPermissionType (permissionTypeID_FK, DistributorID_FK, distributorPermissionTypeStartDate, distributorPermissionTypeActive, permissionAuthLvl, entryDate)
SELECT pt.permissionTypeID, d.distributorID, GETDATE(), s.active, s.authLvl, GETDATE()
FROM (VALUES
    (N'TKT-CRUD', N'ACCESS', 1, 3),
    (N'TKT-CRUD', N'DELETE', 1, 3),
    (N'TKT-CRUD', N'INSERT', 1, 3),
    (N'TKT-CRUD', N'REQUEST_CLARIFICATION', 1, 3),
    (N'TKT-CRUD', N'RESPOND_CLARIFICATION', 1, 3),
    (N'TKT-CRUD', N'SELECT', 1, 3),
    (N'TKT-CRUD', N'UPDATE', 1, 3),
    (N'TKT-SCAT', N'ACCESS', 1, 3),
    (N'TKT-SCAT', N'APPROVESERVICESUGGESTION', 1, 3),
    (N'TKT-SCAT', N'DELETESERVICE', 1, 3),
    (N'TKT-SCAT', N'INSERTSERVICE', 1, 3),
    (N'TKT-SCAT', N'MANAGEROUTINGRULES', 1, 3),
    (N'TKT-SCAT', N'MANAGESLAPOLICIES', 1, 3),
    (N'TKT-SCAT', N'UPDATESERVICE', 1, 3),
    (N'TKT-TADM', N'ACCESS', 1, 3),
    (N'TKT-TADM', N'DELETEARBITRATIONREASON', 1, 3),
    (N'TKT-TADM', N'DELETEPAUSEREASON', 1, 3),
    (N'TKT-TADM', N'DELETEPRIORITY', 1, 3),
    (N'TKT-TADM', N'DELETEQUALITYREVIEWRESULT', 1, 3),
    (N'TKT-TADM', N'DELETETICKETCLASS', 1, 3),
    (N'TKT-TADM', N'DELETETICKETSTATUS', 1, 3),
    (N'TKT-TADM', N'INSERTARBITRATIONREASON', 1, 3),
    (N'TKT-TADM', N'INSERTPAUSEREASON', 1, 3),
    (N'TKT-TADM', N'INSERTPRIORITY', 1, 3),
    (N'TKT-TADM', N'INSERTQUALITYREVIEWRESULT', 1, 3),
    (N'TKT-TADM', N'INSERTTICKETCLASS', 1, 3),
    (N'TKT-TADM', N'INSERTTICKETSTATUS', 1, 3),
    (N'TKT-TADM', N'REQUEST_CLARIFICATION', 1, 3),
    (N'TKT-TADM', N'RESPOND_CLARIFICATION', 1, 3),
    (N'TKT-TADM', N'UPDATEARBITRATIONREASON', 1, 3),
    (N'TKT-TADM', N'UPDATEPAUSEREASON', 1, 3),
    (N'TKT-TADM', N'UPDATEPRIORITY', 1, 3),
    (N'TKT-TADM', N'UPDATEQUALITYREVIEWRESULT', 1, 3),
    (N'TKT-TADM', N'UPDATETICKETCLASS', 1, 3),
    (N'TKT-TADM', N'UPDATETICKETSTATUS', 1, 3),
    (N'TKT-TDET', N'ACCESS', 1, 3),
    (N'TKT-TDET', N'ASSIGN_TICKET', 1, 3),
    (N'TKT-TDET', N'CANCEL_ARBITRATION', 1, 3),
    (N'TKT-TDET', N'CLOSE_TICKET', 1, 3),
    (N'TKT-TDET', N'CREATE_CHILD_TICKET', 1, 3),
    (N'TKT-TDET', N'DECIDE_ARBITRATION', 1, 3),
    (N'TKT-TDET', N'DELETE', 1, 3),
    (N'TKT-TDET', N'DELETE_ATTACHMENT', 1, 3),
    (N'TKT-TDET', N'FINALIZE_QUALITY_REVIEW', 1, 3),
    (N'TKT-TDET', N'INSERT', 1, 3),
    (N'TKT-TDET', N'INSERT_TICKET', 1, 3),
    (N'TKT-TDET', N'PAUSE_TICKET', 1, 3),
    (N'TKT-TDET', N'RAISE_ARBITRATION', 1, 3),
    (N'TKT-TDET', N'REASSIGN_TICKET', 1, 3),
    (N'TKT-TDET', N'REJECT_TICKET', 1, 3),
    (N'TKT-TDET', N'REOPEN_TICKET', 1, 3),
    (N'TKT-TDET', N'REQUEST_CLARIFICATION', 1, 3),
    (N'TKT-TDET', N'RESOLVE_TICKET', 1, 3),
    (N'TKT-TDET', N'RESPOND_CLARIFICATION', 1, 3),
    (N'TKT-TDET', N'RESUME_TICKET', 1, 3),
    (N'TKT-TDET', N'ROUTE_TICKET', 1, 3),
    (N'TKT-TDET', N'SELECT', 1, 3),
    (N'TKT-TDET', N'START_WORK', 1, 3),
    (N'TKT-TDET', N'SUBMIT_QUALITY_REVIEW', 1, 3),
    (N'TKT-TDET', N'UPDATE', 1, 3),
    (N'TKT-TDET', N'UPDATE_PRIORITY', 1, 3),
    (N'TKT-TDET', N'UPLOAD_ATTACHMENT', 1, 3),
    (N'TKT-TLIST', N'ACCESS', 1, 3),
    (N'TKT-TLIST', N'DELETE', 1, 3),
    (N'TKT-TLIST', N'INSERT', 1, 3),
    (N'TKT-TLIST', N'INSERT_TICKET', 1, 3),
    (N'TKT-TLIST', N'REQUEST_CLARIFICATION', 1, 3),
    (N'TKT-TLIST', N'RESPOND_CLARIFICATION', 1, 3),
    (N'TKT-TLIST', N'SELECT', 1, 3),
    (N'TKT-TLIST', N'UPDATE', 1, 3)
) AS s (distributorCode, permissionTypeName_E, active, authLvl)
CROSS APPLY (SELECT TOP 1 distributorID FROM dbo.Distributor WHERE distributorCode = s.distributorCode ORDER BY distributorID) d
CROSS APPLY (SELECT TOP 1 permissionTypeID FROM dbo.PermissionType WHERE permissionTypeName_E = s.permissionTypeName_E ORDER BY permissionTypeID) pt
WHERE NOT EXISTS (SELECT 1 FROM dbo.DistributorPermissionType x WHERE x.permissionTypeID_FK = pt.permissionTypeID AND x.DistributorID_FK = d.distributorID);

-- Link each menu to its distributor
INSERT INTO dbo.MenuDistributor (menuID_FK, distributorID_FK, roleID_FK, isDenied, menuDistributorActive)
SELECT m.menuID, d.distributorID, s.roleID_FK, s.isDenied, s.active
FROM (VALUES
    (N'TicketList', N'TKT-TLIST', 1, NULL, 1),
    (N'TicketDetails', N'TKT-TDET', 1, NULL, 1),
    (N'TicketAdmin', N'TKT-TADM', 1, NULL, 1),
    (N'ServiceCatalogueList', N'TKT-SCAT', 1, NULL, 1)
) AS s (menuName_E, distributorCode, roleID_FK, isDenied, active)
CROSS APPLY (SELECT TOP 1 menuID FROM dbo.Menu WHERE menuName_E = s.menuName_E AND programID_FK = @programID ORDER BY menuID) m
CROSS APPLY (SELECT TOP 1 distributorID FROM dbo.Distributor WHERE distributorCode = s.distributorCode ORDER BY distributorID) d
WHERE NOT EXISTS (SELECT 1 FROM dbo.MenuDistributor x WHERE x.menuID_FK = m.menuID AND x.distributorID_FK = d.distributorID);

COMMIT TRANSACTION;
PRINT N'Tickets seed data: done.';
