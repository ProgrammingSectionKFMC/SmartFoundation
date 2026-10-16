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
    [buildingActionExtraText5]      NVARCHAR (1000)  NULL,
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
    [InAssignPeriod]                INT              NULL,
    [ExtendReasonTypeID_FK]         INT              NULL,
    [OccupentDate]                  DATETIME         NULL,
    [ExitDate]                      DATETIME         NULL,
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
    INCLUDE([buildingActionID], [residentInfoID_FK], [buildingActionDecisionDate], [buildingActionDecisionNo], [buildingActionExtraType1], [buildingActionExtraType2], [buildingActionExtraInt1], [buildingDetailsID_FK], [buildingDetailsNo], [buildingActionNote], [entryDate], [entryData]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Parent_Active]
    ON [Housing].[BuildingAction]([buildingActionParentID] ASC, [buildingActionActive] ASC)
    INCLUDE([buildingActionID], [buildingActionTypeID_FK], [IdaraId_FK]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Root_Type_Active]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC, [buildingActionID] ASC)
    INCLUDE([residentInfoID_FK], [IdaraId_FK], [buildingActionDate], [buildingActionNote], [entryData], [entryDate], [buildingActionDecisionNo], [buildingActionDecisionDate], [buildingActionExtraType1], [buildingActionExtraType2]);


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
    INCLUDE([residentInfoID_FK], [IdaraId_FK], [buildingActionDate], [buildingActionNote], [entryData], [entryDate], [buildingActionDecisionNo], [buildingActionDecisionDate], [buildingActionExtraType1], [buildingActionExtraType2]);


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
    INCLUDE([IdaraId_FK], [buildingActionID], [buildingActionParentID]);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_LastActionTypeID_NULL]
    ON [Housing].[BuildingAction]([residentInfoID_FK] ASC) WHERE ([buildingActionTypeID_FK] IS NULL);


GO
CREATE NONCLUSTERED INDEX [IX_BuildingAction_Type_Active]
    ON [Housing].[BuildingAction]([buildingActionTypeID_FK] ASC, [buildingActionActive] ASC)
    INCLUDE([buildingActionID], [buildingActionParentID], [IdaraId_FK], [residentInfoID_FK], [entryData], [buildingActionNote], [buildingActionDate], [buildingActionDecisionDate], [buildingActionDecisionNo], [buildingActionExtraType1], [buildingActionExtraType2], [entryDate]);


GO
