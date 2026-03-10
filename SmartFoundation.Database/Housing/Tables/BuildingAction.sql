CREATE TABLE [Housing].[BuildingAction] (
    [buildingActionID]              BIGINT           IDENTITY (1, 1) NOT NULL,
    [buildingActionUDID]            UNIQUEIDENTIFIER CONSTRAINT [DF_BuildingAction_buildingActionUDID] DEFAULT (newid()) NULL,
    [buildingActionTypeID_FK]       INT              NULL,
    [buildingStatusID_FK]           INT              NULL,
    [residentInfoID_FK]             BIGINT           NULL,
    [generalNo_FK]                  BIGINT           NULL,
    [buildingPaymentTypeID_FK]      INT              NULL,
    [buildingDetailsID_FK]          BIGINT           NULL,
    [buildingDetailsNo]             NVARCHAR (20)    NULL,
    [buildingActionFromDate]        DATETIME         NULL,
    [buildingActionToDate]          DATETIME         NULL,
    [buildingActionDate]            DATETIME         NULL,
    [buildingActionDate2]           DATETIME         NULL,
    [buildingActionDecisionNo]      NVARCHAR (200)   NULL,
    [buildingActionDecisionDate]    DATETIME         NULL,
    [fromDSD_FK]                    INT              NULL,
    [toDSD_FK]                      INT              NULL,
    [buildingActionFromSourceID_FK] INT              NULL,
    [buildingActionToSourceID_FK]   INT              NULL,
    [buildingActionNote]            NVARCHAR (1000)  NULL,
    [buildingActionExtraText1]      NVARCHAR (200)   NULL,
    [buildingActionExtraText2]      NVARCHAR (200)   NULL,
    [buildingActionExtraText3]      NVARCHAR (200)   NULL,
    [buildingActionExtraText4]      NVARCHAR (200)   NULL,
    [buildingActionExtraDate1]      DATETIME         NULL,
    [buildingActionExtraDate2]      DATETIME         NULL,
    [buildingActionExtraDate3]      DATETIME         NULL,
    [buildingActionExtraFloat1]     FLOAT (53)       NULL,
    [buildingActionExtraFloat2]     FLOAT (53)       NULL,
    [buildingActionExtraInt1]       INT              NULL,
    [buildingActionExtraInt2]       INT              NULL,
    [buildingActionExtraInt3]       INT              NULL,
    [buildingActionExtraInt4]       INT              NULL,
    [buildingActionExtraType1]      INT              NULL,
    [buildingActionExtraType2]      INT              NULL,
    [buildingActionExtraType3]      INT              NULL,
    [buildingActionActive]          BIT              CONSTRAINT [DF_BuildingAction_buildingActionActive] DEFAULT ((1)) NULL,
    [buildingActionParentID]        BIGINT           NULL,
    [CustdyRecord]                  NVARCHAR (4000)  NULL,
    [AssignPeriodID_FK]             BIGINT           NULL,
    [ExtendReasonTypeID_FK]         INT              NULL,
    [IdaraId_FK]                    BIGINT           NULL,
    [entryDate]                     DATETIME         CONSTRAINT [DF_BuildingAction_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                     NVARCHAR (20)    NULL,
    [hostName]                      NVARCHAR (200)   NULL,
    CONSTRAINT [PK_BuildingAction] PRIMARY KEY CLUSTERED ([buildingActionID] ASC),
    CONSTRAINT [FK_BuildingAction_BuildingActionSource] FOREIGN KEY ([buildingActionFromSourceID_FK]) REFERENCES [Housing].[BuildingActionSource] ([buildingActionSourceID]),
    CONSTRAINT [FK_BuildingAction_BuildingActionSource1] FOREIGN KEY ([buildingActionToSourceID_FK]) REFERENCES [Housing].[BuildingActionSource] ([buildingActionSourceID]),
    CONSTRAINT [FK_BuildingAction_BuildingActionType] FOREIGN KEY ([buildingActionTypeID_FK]) REFERENCES [Housing].[BuildingActionType] ([buildingActionTypeID]),
    CONSTRAINT [FK_BuildingAction_BuildingDetails] FOREIGN KEY ([buildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_BuildingAction_BuildingPaymentType] FOREIGN KEY ([buildingPaymentTypeID_FK]) REFERENCES [Housing].[BuildingPaymentType] ([buildingPaymentTypeID]),
    CONSTRAINT [FK_BuildingAction_BuildingStatus] FOREIGN KEY ([buildingStatusID_FK]) REFERENCES [Housing].[BuildingStatus] ([buildingStatusID]),
    CONSTRAINT [FK_BuildingAction_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID])
);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_ParentID]
    ON [Housing].[BuildingAction]([buildingActionParentID] ASC)
    INCLUDE([buildingActionID], [buildingActionTypeID_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_ParentID_TypeID]
    ON [Housing].[BuildingAction]([buildingActionParentID] ASC, [buildingActionTypeID_FK] ASC)
    INCLUDE([buildingActionID]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_buildingDetailsID_FK_buildingActionID]
    ON [Housing].[BuildingAction]([buildingDetailsID_FK] ASC, [buildingActionID] DESC);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_LastByDetails]
    ON [Housing].[BuildingAction]([buildingDetailsID_FK] ASC, [buildingActionID] DESC)
    INCLUDE([buildingActionTypeID_FK], [buildingActionActive], [entryDate], [IdaraId_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Waiting]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [IdaraId_FK] ASC, [buildingActionParentID] ASC)
    INCLUDE([buildingActionID], [residentInfoID_FK], [entryDate], [entryData], [buildingActionDecisionDate], [buildingActionDecisionNo], [buildingActionExtraType1], [buildingActionExtraType2], [buildingActionExtraInt1], [buildingDetailsID_FK], [buildingDetailsNo], [buildingActionNote]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Parent_Active]
    ON [Housing].[BuildingAction]([buildingActionParentID] ASC, [buildingActionActive] ASC)
    INCLUDE([buildingActionID], [buildingActionTypeID_FK], [IdaraId_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Root_Type_Active]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionID] ASC)
    INCLUDE([residentInfoID_FK], [IdaraId_FK], [buildingActionDate], [entryDate], [buildingActionDecisionNo], [buildingActionDecisionDate], [buildingActionExtraType1], [buildingActionExtraType2], [buildingActionNote], [entryData]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Active_Type_Idara]
    ON [Housing].[BuildingAction]([buildingActionActive] ASC, [buildingActionTypeID_FK] ASC, [IdaraId_FK] ASC)
    INCLUDE([buildingActionID], [buildingActionParentID], [buildingDetailsID_FK], [buildingDetailsNo], [AssignPeriodID_FK], [buildingActionExtraInt1], [buildingActionNote], [entryData], [entryDate]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Root_1_7_Active]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionID] ASC)
    INCLUDE([residentInfoID_FK], [IdaraId_FK], [buildingActionDate], [buildingActionDecisionNo], [buildingActionDecisionDate], [buildingActionExtraType1], [buildingActionExtraType2], [entryData], [entryDate]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Resident_Building_Type_Active]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC, [buildingDetailsID_FK] ASC, [buildingActionTypeID_FK] ASC, [buildingActionActive] ASC)
    INCLUDE([buildingActionDate], [buildingActionParentID], [buildingActionID]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_RootType1_Active]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionID] ASC)
    INCLUDE([residentInfoID_FK], [IdaraId_FK], [buildingActionDate], [entryDate], [buildingActionDecisionNo], [buildingActionDecisionDate], [buildingActionExtraType1], [buildingActionExtraType2], [buildingActionNote], [entryData]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Vacate]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC, [buildingDetailsID_FK] ASC, [buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionDate] DESC);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Occupant]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC, [buildingDetailsID_FK] ASC, [buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionDate] DESC)
    INCLUDE([buildingActionID]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_ResidentDetails_TypeDate]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC, [buildingDetailsID_FK] ASC, [buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionDate] DESC)
    INCLUDE([buildingActionID], [buildingActionParentID], [IdaraId_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_LastActionTypeID_NULL]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC) WHERE ([buildingActionTypeID_FK] IS NULL);


GO
CREATE TRIGGER [Housing].[trg_BuildingAction_Audit]
ON Housing.BuildingAction
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Handle INSERT
  --  INSERT INTO KAMA_SYSTEM.dbo.TA_AuditLog
  --  (ChangeType,DataBaseName, Table_Name, entryData, GenNO, TA_UID, OldData, NewData, ChangedFields)
  --  SELECT 
  --      'INSERT',
		--'KFMC',
  --      'BuildingAction',
  --      CONVERT(nvarchar(100), SYSTEM_USER) + ' - ' 
  --      + CONVERT(nvarchar(100), ORIGINAL_LOGIN()) + ' - ' 
  --      + CONVERT(nvarchar(100), SUSER_SNAME()) + ' - ' 
  --      + CONVERT(nvarchar(100), USER_NAME()),
  --      ISNULL(i.generalNo_FK, ''),
  --      i.buildingActionID,
  --      NULL,
  --      CONCAT_WS(', ',
  --          'buildingActionTypeID_FK=' + CONVERT(nvarchar, i.buildingActionTypeID_FK),
  --          'buildingStatusID_FK=' + CONVERT(nvarchar, i.buildingStatusID_FK),
  --          'generalNo_FK=' + CONVERT(nvarchar, i.generalNo_FK),
  --          'buildingPaymentTypeID_FK=' + CONVERT(nvarchar, i.buildingPaymentTypeID_FK),
  --          'buildingDetailsNo=' + ISNULL(i.buildingDetailsNo, ''),
  --          'buildingActionFromDate=' + CONVERT(nvarchar, i.buildingActionFromDate, 120),
  --          'buildingActionToDate=' + CONVERT(nvarchar, i.buildingActionToDate, 120),
  --          'buildingActionDate=' + CONVERT(nvarchar, i.buildingActionDate, 120),
  --          'buildingActionDate2=' + CONVERT(nvarchar, i.buildingActionDate2, 120),
  --          'buildingActionDecisionNo=' + ISNULL(i.buildingActionDecisionNo, ''),
  --          'buildingActionDecisionDate=' + CONVERT(nvarchar, i.buildingActionDecisionDate, 120),
  --          'fromDSD_FK=' + CONVERT(nvarchar, i.fromDSD_FK),
  --          'toDSD_FK=' + CONVERT(nvarchar, i.toDSD_FK),
  --          'buildingActionFromSourceID_FK=' + CONVERT(nvarchar, i.buildingActionFromSourceID_FK),
  --          'buildingActionToSourceID_FK=' + CONVERT(nvarchar, i.buildingActionToSourceID_FK),
  --          'buildingActionNote=' + ISNULL(i.buildingActionNote, ''),
  --          'buildingActionExtraText1=' + ISNULL(i.buildingActionExtraText1, ''),
  --          'buildingActionExtraText2=' + ISNULL(i.buildingActionExtraText2, ''),
  --          'buildingActionExtraText3=' + ISNULL(i.buildingActionExtraText3, ''),
  --          'buildingActionExtraText4=' + ISNULL(i.buildingActionExtraText4, ''),
  --          'buildingActionExtraDate1=' + CONVERT(nvarchar, i.buildingActionExtraDate1, 120),
  --          'buildingActionExtraDate2=' + CONVERT(nvarchar, i.buildingActionExtraDate2, 120),
  --          'buildingActionExtraDate3=' + CONVERT(nvarchar, i.buildingActionExtraDate3, 120),
  --          'buildingActionExtraFloat1=' + CONVERT(nvarchar, i.buildingActionExtraFloat1),
  --          'buildingActionExtraFloat2=' + CONVERT(nvarchar, i.buildingActionExtraFloat2),
  --          'buildingActionExtraInt1=' + CONVERT(nvarchar, i.buildingActionExtraInt1),
  --          'buildingActionExtraInt2=' + CONVERT(nvarchar, i.buildingActionExtraInt2),
  --          'buildingActionExtraInt3=' + CONVERT(nvarchar, i.buildingActionExtraInt3),
  --          'buildingActionExtraInt4=' + CONVERT(nvarchar, i.buildingActionExtraInt4),
  --          'buildingActionExtraType1=' + CONVERT(nvarchar, i.buildingActionExtraType1),
  --          'buildingActionExtraType2=' + CONVERT(nvarchar, i.buildingActionExtraType2),
  --          'buildingActionExtraType3=' + CONVERT(nvarchar, i.buildingActionExtraType3),
  --          'buildingActionActive=' + CONVERT(nvarchar, i.buildingActionActive),
  --          'buildingActionParentID=' + CONVERT(nvarchar, i.buildingActionParentID),
  --          'entryDate=' + CONVERT(nvarchar, i.entryDate, 120),
  --          'entryData=' + ISNULL(i.entryData, ''),
  --          'hostName=' + ISNULL(i.hostName, '')
  --      )
		--,
		--null
  --  FROM inserted i;

  --  -- Handle DELETE
  --  INSERT INTO KAMA_SYSTEM.dbo.TA_AuditLog
  --  (ChangeType,DataBaseName, Table_Name, entryData, GenNO, TA_UID, OldData, NewData, ChangedFields)
  --  SELECT 
  --      'DELETE',
		--'KFMC',
  --      'BuildingAction',
  --      CONVERT(nvarchar(100), SYSTEM_USER) + ' - ' 
  --      + CONVERT(nvarchar(100), ORIGINAL_LOGIN()) + ' - ' 
  --      + CONVERT(nvarchar(100), SUSER_SNAME()) + ' - ' 
  --      + CONVERT(nvarchar(100), USER_NAME()),
  --      ISNULL(d.generalNo_FK, ''),
  --      d.buildingActionID,
  --      CONCAT_WS(', ',
  --          'buildingActionTypeID_FK=' + CONVERT(nvarchar, d.buildingActionTypeID_FK),
  --          'buildingStatusID_FK=' + CONVERT(nvarchar, d.buildingStatusID_FK),
  --          'generalNo_FK=' + CONVERT(nvarchar, d.generalNo_FK),
  --          'buildingPaymentTypeID_FK=' + CONVERT(nvarchar, d.buildingPaymentTypeID_FK),
  --          'buildingDetailsNo=' + ISNULL(d.buildingDetailsNo, ''),
  --          'buildingActionFromDate=' + CONVERT(nvarchar, d.buildingActionFromDate, 120),
  --          'buildingActionToDate=' + CONVERT(nvarchar, d.buildingActionToDate, 120),
  --          'buildingActionDate=' + CONVERT(nvarchar, d.buildingActionDate, 120),
  --          'buildingActionDate2=' + CONVERT(nvarchar, d.buildingActionDate2, 120),
  --          'buildingActionDecisionNo=' + ISNULL(d.buildingActionDecisionNo, ''),
  --          'buildingActionDecisionDate=' + CONVERT(nvarchar, d.buildingActionDecisionDate, 120),
  --          'fromDSD_FK=' + CONVERT(nvarchar, d.fromDSD_FK),
  --          'toDSD_FK=' + CONVERT(nvarchar, d.toDSD_FK),
  --          'buildingActionFromSourceID_FK=' + CONVERT(nvarchar, d.buildingActionFromSourceID_FK),
  --          'buildingActionToSourceID_FK=' + CONVERT(nvarchar, d.buildingActionToSourceID_FK),
  --          'buildingActionNote=' + ISNULL(d.buildingActionNote, ''),
  --          'buildingActionExtraText1=' + ISNULL(d.buildingActionExtraText1, ''),
  --          'buildingActionExtraText2=' + ISNULL(d.buildingActionExtraText2, ''),
  --          'buildingActionExtraText3=' + ISNULL(d.buildingActionExtraText3, ''),
  --          'buildingActionExtraText4=' + ISNULL(d.buildingActionExtraText4, ''),
  --          'buildingActionExtraDate1=' + CONVERT(nvarchar, d.buildingActionExtraDate1, 120),
  --          'buildingActionExtraDate2=' + CONVERT(nvarchar, d.buildingActionExtraDate2, 120),
  --          'buildingActionExtraDate3=' + CONVERT(nvarchar, d.buildingActionExtraDate3, 120),
  --          'buildingActionExtraFloat1=' + CONVERT(nvarchar, d.buildingActionExtraFloat1),
  --          'buildingActionExtraFloat2=' + CONVERT(nvarchar, d.buildingActionExtraFloat2),
  --          'buildingActionExtraInt1=' + CONVERT(nvarchar, d.buildingActionExtraInt1),
  --          'buildingActionExtraInt2=' + CONVERT(nvarchar, d.buildingActionExtraInt2),
  --          'buildingActionExtraInt3=' + CONVERT(nvarchar, d.buildingActionExtraInt3),
  --          'buildingActionExtraInt4=' + CONVERT(nvarchar, d.buildingActionExtraInt4),
  --          'buildingActionExtraType1=' + CONVERT(nvarchar, d.buildingActionExtraType1),
  --          'buildingActionExtraType2=' + CONVERT(nvarchar, d.buildingActionExtraType2),
  --          'buildingActionExtraType3=' + CONVERT(nvarchar, d.buildingActionExtraType3),
  --          'buildingActionActive=' + CONVERT(nvarchar, d.buildingActionActive),
  --          'buildingActionParentID=' + CONVERT(nvarchar, d.buildingActionParentID),
  --          'entryDate=' + CONVERT(nvarchar, d.entryDate, 120),
  --          'entryData=' + ISNULL(d.entryData, ''),
  --          'hostName=' + ISNULL(d.hostName, '')
  --      ),
  --      NULL,
  --      NULL
  --  FROM deleted d;

  --  -- Handle UPDATE
  --  INSERT INTO KAMA_SYSTEM.dbo.TA_AuditLog
  --  (ChangeType,DataBaseName, Table_Name, entryData, GenNO, TA_UID, OldData, NewData, ChangedFields)
  --  SELECT 
  --      'UPDATE',
		--'KFMC',
  --      'BuildingAction',
  --      CONVERT(nvarchar(100), SYSTEM_USER) + ' - ' 
  --      + CONVERT(nvarchar(100), ORIGINAL_LOGIN()) + ' - ' 
  --      + CONVERT(nvarchar(100), SUSER_SNAME()) + ' - ' 
  --      + CONVERT(nvarchar(100), USER_NAME()),
  --      ISNULL(i.generalNo_FK, ''),
  --      d.buildingActionID,
  --      CONCAT_WS(', ',
  --          'buildingActionTypeID_FK=' + CONVERT(nvarchar, d.buildingActionTypeID_FK),
  --          'buildingStatusID_FK=' + CONVERT(nvarchar, d.buildingStatusID_FK),
  --          'generalNo_FK=' + CONVERT(nvarchar, d.generalNo_FK),
  --          'buildingPaymentTypeID_FK=' + CONVERT(nvarchar, d.buildingPaymentTypeID_FK),
  --          'buildingDetailsNo=' + ISNULL(d.buildingDetailsNo, ''),
  --          'buildingActionFromDate=' + CONVERT(nvarchar, d.buildingActionFromDate, 120),
  --          'buildingActionToDate=' + CONVERT(nvarchar, d.buildingActionToDate, 120),
  --          'buildingActionDate=' + CONVERT(nvarchar, d.buildingActionDate, 120),
  --          'buildingActionDate2=' + CONVERT(nvarchar, d.buildingActionDate2, 120),
  --          'buildingActionDecisionNo=' + ISNULL(d.buildingActionDecisionNo, ''),
  --          'buildingActionDecisionDate=' + CONVERT(nvarchar, d.buildingActionDecisionDate, 120),
  --          'fromDSD_FK=' + CONVERT(nvarchar, d.fromDSD_FK),
  --          'toDSD_FK=' + CONVERT(nvarchar, d.toDSD_FK),
  --          'buildingActionFromSourceID_FK=' + CONVERT(nvarchar, d.buildingActionFromSourceID_FK),
  --          'buildingActionToSourceID_FK=' + CONVERT(nvarchar, d.buildingActionToSourceID_FK),
  --          'buildingActionNote=' + ISNULL(d.buildingActionNote, ''),
  --          'buildingActionExtraText1=' + ISNULL(d.buildingActionExtraText1, ''),
  --          'buildingActionExtraText2=' + ISNULL(d.buildingActionExtraText2, ''),
  --          'buildingActionExtraText3=' + ISNULL(d.buildingActionExtraText3, ''),
  --          'buildingActionExtraText4=' + ISNULL(d.buildingActionExtraText4, ''),
  --          'buildingActionExtraDate1=' + CONVERT(nvarchar, d.buildingActionExtraDate1, 120),
  --          'buildingActionExtraDate2=' + CONVERT(nvarchar, d.buildingActionExtraDate2, 120),
  --          'buildingActionExtraDate3=' + CONVERT(nvarchar, d.buildingActionExtraDate3, 120),
  --          'buildingActionExtraFloat1=' + CONVERT(nvarchar, d.buildingActionExtraFloat1),
  --          'buildingActionExtraFloat2=' + CONVERT(nvarchar, d.buildingActionExtraFloat2),
  --          'buildingActionExtraInt1=' + CONVERT(nvarchar, d.buildingActionExtraInt1),
  --          'buildingActionExtraInt2=' + CONVERT(nvarchar, d.buildingActionExtraInt2),
  --          'buildingActionExtraInt3=' + CONVERT(nvarchar, d.buildingActionExtraInt3),
  --          'buildingActionExtraInt4=' + CONVERT(nvarchar, d.buildingActionExtraInt4),
  --          'buildingActionExtraType1=' + CONVERT(nvarchar, d.buildingActionExtraType1),
  --          'buildingActionExtraType2=' + CONVERT(nvarchar, d.buildingActionExtraType2),
  --          'buildingActionExtraType3=' + CONVERT(nvarchar, d.buildingActionExtraType3),
  --          'buildingActionActive=' + CONVERT(nvarchar, d.buildingActionActive),
  --          'buildingActionParentID=' + CONVERT(nvarchar, d.buildingActionParentID),
  --          'entryDate=' + CONVERT(nvarchar, d.entryDate, 120),
  --          'entryData=' + ISNULL(d.entryData, ''),
  --          'hostName=' + ISNULL(d.hostName, '')
  --      ),
  --      CONCAT_WS(', ',
  --          'buildingActionTypeID_FK=' + CONVERT(nvarchar, i.buildingActionTypeID_FK),
  --          'buildingStatusID_FK=' + CONVERT(nvarchar, i.buildingStatusID_FK),
  --          'generalNo_FK=' + CONVERT(nvarchar, i.generalNo_FK),
  --          'buildingPaymentTypeID_FK=' + CONVERT(nvarchar, i.buildingPaymentTypeID_FK),
  --          'buildingDetailsNo=' + ISNULL(i.buildingDetailsNo, ''),
  --          'buildingActionFromDate=' + CONVERT(nvarchar, i.buildingActionFromDate, 120),
  --   'buildingActionToDate=' + CONVERT(nvarchar, i.buildingActionToDate, 120),
  --          'buildingActionDate=' + CONVERT(nvarchar, i.buildingActionDate, 120),
  --          'buildingActionDate2=' + CONVERT(nvarchar, i.buildingActionDate2, 120),
  --          'buildingActionDecisionNo=' + ISNULL(i.buildingActionDecisionNo, ''),
  --'buildingActionDecisionDate=' + CONVERT(nvarchar, i.buildingActionDecisionDate, 120),
  --          'fromDSD_FK=' + CONVERT(nvarchar, i.fromDSD_FK),
  --          'toDSD_FK=' + CONVERT(nvarchar, i.toDSD_FK),
  --          'buildingActionFromSourceID_FK=' + CONVERT(nvarchar, i.buildingActionFromSourceID_FK),
  --          'buildingActionToSourceID_FK=' + CONVERT(nvarchar, i.buildingActionToSourceID_FK),
  --          'buildingActionNote=' + ISNULL(i.buildingActionNote, ''),
  --          'buildingActionExtraText1=' + ISNULL(i.buildingActionExtraText1, ''),
  --          'buildingActionExtraText2=' + ISNULL(i.buildingActionExtraText2, ''),
  --          'buildingActionExtraText3=' + ISNULL(i.buildingActionExtraText3, ''),
  --          'buildingActionExtraText4=' + ISNULL(i.buildingActionExtraText4, ''),
  --          'buildingActionExtraDate1=' + CONVERT(nvarchar, i.buildingActionExtraDate1, 120),
  --          'buildingActionExtraDate2=' + CONVERT(nvarchar, i.buildingActionExtraDate2, 120),
  --          'buildingActionExtraDate3=' + CONVERT(nvarchar, i.buildingActionExtraDate3, 120),
  --          'buildingActionExtraFloat1=' + CONVERT(nvarchar, i.buildingActionExtraFloat1),
  --          'buildingActionExtraFloat2=' + CONVERT(nvarchar, i.buildingActionExtraFloat2),
  --          'buildingActionExtraInt1=' + CONVERT(nvarchar, i.buildingActionExtraInt1),
  --          'buildingActionExtraInt2=' + CONVERT(nvarchar, i.buildingActionExtraInt2),
  --          'buildingActionExtraInt3=' + CONVERT(nvarchar, i.buildingActionExtraInt3),
  --          'buildingActionExtraInt4=' + CONVERT(nvarchar, i.buildingActionExtraInt4),
  --          'buildingActionExtraType1=' + CONVERT(nvarchar, i.buildingActionExtraType1),
  --          'buildingActionExtraType2=' + CONVERT(nvarchar, i.buildingActionExtraType2),
  --          'buildingActionExtraType3=' + CONVERT(nvarchar, i.buildingActionExtraType3),
  --          'buildingActionActive=' + CONVERT(nvarchar, i.buildingActionActive),
  --          'buildingActionParentID=' + CONVERT(nvarchar, i.buildingActionParentID),
  --          'entryDate=' + CONVERT(nvarchar, i.entryDate, 120),
  --          'entryData=' + ISNULL(i.entryData, ''),
  --          'hostName=' + ISNULL(i.hostName, '')
  --      ),
  --      CONCAT_WS(', ',
  --          CASE WHEN ISNULL(d.buildingActionTypeID_FK, -1) <> ISNULL(i.buildingActionTypeID_FK, -1) THEN 'buildingActionTypeID_FK=' + CONVERT(nvarchar, i.buildingActionTypeID_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingStatusID_FK, -1) <> ISNULL(i.buildingStatusID_FK, -1) THEN 'buildingStatusID_FK=' + CONVERT(nvarchar, i.buildingStatusID_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.generalNo_FK, -1) <> ISNULL(i.generalNo_FK, -1) THEN 'generalNo_FK=' + CONVERT(nvarchar, i.generalNo_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingPaymentTypeID_FK, -1) <> ISNULL(i.buildingPaymentTypeID_FK, -1) THEN 'buildingPaymentTypeID_FK=' + CONVERT(nvarchar, i.buildingPaymentTypeID_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingDetailsNo, '') <> ISNULL(i.buildingDetailsNo, '') THEN 'buildingDetailsNo=' + ISNULL(i.buildingDetailsNo, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionFromDate, '1900-01-01') <> ISNULL(i.buildingActionFromDate, '1900-01-01') THEN 'buildingActionFromDate=' + CONVERT(nvarchar, i.buildingActionFromDate, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionToDate, '1900-01-01') <> ISNULL(i.buildingActionToDate, '1900-01-01') THEN 'buildingActionToDate=' + CONVERT(nvarchar, i.buildingActionToDate, 120) ELSE NULL END,
  -- CASE WHEN ISNULL(d.buildingActionDate, '1900-01-01') <> ISNULL(i.buildingActionDate, '1900-01-01') THEN 'buildingActionDate=' + CONVERT(nvarchar, i.buildingActionDate, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionDate2, '1900-01-01') <> ISNULL(i.buildingActionDate2, '1900-01-01') THEN 'buildingActionDate2=' + CONVERT(nvarchar, i.buildingActionDate2, 120) ELSE NULL END,
  --       CASE WHEN ISNULL(d.buildingActionDecisionNo, '') <> ISNULL(i.buildingActionDecisionNo, '') THEN 'buildingActionDecisionNo=' + ISNULL(i.buildingActionDecisionNo, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionDecisionDate, '1900-01-01') <> ISNULL(i.buildingActionDecisionDate, '1900-01-01') THEN 'buildingActionDecisionDate=' + CONVERT(nvarchar, i.buildingActionDecisionDate, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.fromDSD_FK, -1) <> ISNULL(i.fromDSD_FK, -1) THEN 'fromDSD_FK=' + CONVERT(nvarchar, i.fromDSD_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.toDSD_FK, -1) <> ISNULL(i.toDSD_FK, -1) THEN 'toDSD_FK=' + CONVERT(nvarchar, i.toDSD_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionFromSourceID_FK, -1) <> ISNULL(i.buildingActionFromSourceID_FK, -1) THEN 'buildingActionFromSourceID_FK=' + CONVERT(nvarchar, i.buildingActionFromSourceID_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionToSourceID_FK, -1) <> ISNULL(i.buildingActionToSourceID_FK, -1) THEN 'buildingActionToSourceID_FK=' + CONVERT(nvarchar, i.buildingActionToSourceID_FK) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionNote, '') <> ISNULL(i.buildingActionNote, '') THEN 'buildingActionNote=' + ISNULL(i.buildingActionNote, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraText1, '') <> ISNULL(i.buildingActionExtraText1, '') THEN 'buildingActionExtraText1=' + ISNULL(i.buildingActionExtraText1, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraText2, '') <> ISNULL(i.buildingActionExtraText2, '') THEN 'buildingActionExtraText2=' + ISNULL(i.buildingActionExtraText2, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraText3, '') <> ISNULL(i.buildingActionExtraText3, '') THEN 'buildingActionExtraText3=' + ISNULL(i.buildingActionExtraText3, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraText4, '') <> ISNULL(i.buildingActionExtraText4, '') THEN 'buildingActionExtraText4=' + ISNULL(i.buildingActionExtraText4, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraDate1, '1900-01-01') <> ISNULL(i.buildingActionExtraDate1, '1900-01-01') THEN 'buildingActionExtraDate1=' + CONVERT(nvarchar, i.buildingActionExtraDate1, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraDate2, '1900-01-01') <> ISNULL(i.buildingActionExtraDate2, '1900-01-01') THEN 'buildingActionExtraDate2=' + CONVERT(nvarchar, i.buildingActionExtraDate2, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraDate3, '1900-01-01') <> ISNULL(i.buildingActionExtraDate3, '1900-01-01') THEN 'buildingActionExtraDate3=' + CONVERT(nvarchar, i.buildingActionExtraDate3, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraFloat1, -1) <> ISNULL(i.buildingActionExtraFloat1, -1) THEN 'buildingActionExtraFloat1=' + CONVERT(nvarchar, i.buildingActionExtraFloat1) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraFloat2, -1) <> ISNULL(i.buildingActionExtraFloat2, -1) THEN 'buildingActionExtraFloat2=' + CONVERT(nvarchar, i.buildingActionExtraFloat2) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraInt1, -1) <> ISNULL(i.buildingActionExtraInt1, -1) THEN 'buildingActionExtraInt1=' + CONVERT(nvarchar, i.buildingActionExtraInt1) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraInt2, -1) <> ISNULL(i.buildingActionExtraInt2, -1) THEN 'buildingActionExtraInt2=' + CONVERT(nvarchar, i.buildingActionExtraInt2) ELSE NULL END,
  --         CASE WHEN ISNULL(d.buildingActionExtraInt3, -1) <> ISNULL(i.buildingActionExtraInt3, -1) THEN 'buildingActionExtraInt3=' + CONVERT(nvarchar, i.buildingActionExtraInt3) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraInt4, -1) <> ISNULL(i.buildingActionExtraInt4, -1) THEN 'buildingActionExtraInt4=' + CONVERT(nvarchar, i.buildingActionExtraInt4) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraType1, -1) <> ISNULL(i.buildingActionExtraType1, -1) THEN 'buildingActionExtraType1=' + CONVERT(nvarchar, i.buildingActionExtraType1) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraType2, -1) <> ISNULL(i.buildingActionExtraType2, -1) THEN 'buildingActionExtraType2=' + CONVERT(nvarchar, i.buildingActionExtraType2) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionExtraType3, -1) <> ISNULL(i.buildingActionExtraType3, -1) THEN 'buildingActionExtraType3=' + CONVERT(nvarchar, i.buildingActionExtraType3) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionActive, -1) <> ISNULL(i.buildingActionActive, -1) THEN 'buildingActionActive=' + CONVERT(nvarchar, i.buildingActionActive) ELSE NULL END,
  --          CASE WHEN ISNULL(d.buildingActionParentID, -1) <> ISNULL(i.buildingActionParentID, -1) THEN 'buildingActionParentID=' + CONVERT(nvarchar, i.buildingActionParentID) ELSE NULL END,
  --          CASE WHEN ISNULL(d.entryDate, '1900-01-01') <> ISNULL(i.entryDate, '1900-01-01') THEN 'entryDate=' + CONVERT(nvarchar, i.entryDate, 120) ELSE NULL END,
  --          CASE WHEN ISNULL(d.entryData, '') <> ISNULL(i.entryData, '') THEN 'entryData=' + ISNULL(i.entryData, '') ELSE NULL END,
  --          CASE WHEN ISNULL(d.hostName, '') <> ISNULL(i.hostName, '') THEN 'hostName=' + ISNULL(i.hostName, '') ELSE NULL END
  --      )
  --  FROM inserted i
  --  INNER JOIN deleted d ON i.buildingActionID = d.buildingActionID;

END
