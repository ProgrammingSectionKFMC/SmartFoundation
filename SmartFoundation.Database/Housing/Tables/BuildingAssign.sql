CREATE TABLE [Housing].[BuildingAssign] (
    [BuildingAssignID]           INT             IDENTITY (1, 1) NOT NULL,
    [GeneralNo]                  INT             NULL,
    [BuildingActionID_FK]        INT             NULL,
    [BuildingAssignTypeID_FK]    INT             NULL,
    [ParentBuildingAssignID]     INT             NULL,
    [BuildingNo]                 NVARCHAR (200)  NULL,
    [BuildingAssignDate]         DATETIME        NULL,
    [BuildingAssignNo]           NVARCHAR (50)   NULL,
    [BuildingAssignStatusID_FK]  INT             NULL,
    [buildingPaymentTypeID_FK]   INT             NULL,
    [buildingActionDecisionNo]   NVARCHAR (50)   NULL,
    [buildingActionDecisionDate] DATETIME        NULL,
    [buildingActionOccupentDate] DATETIME        NULL,
    [MeterReadValue]             INT             NULL,
    [buildingActionLetterNo]     NVARCHAR (50)   NULL,
    [buildingActionLetterDate]   DATETIME        NULL,
    [Note]                       NVARCHAR (1000) NULL,
    [entryDate]                  DATETIME        CONSTRAINT [DF_BuildingAssign_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                  NVARCHAR (500)  NULL,
    [hostName]                   NVARCHAR (2000) NULL,
    CONSTRAINT [PK_BuildingAssign] PRIMARY KEY CLUSTERED ([BuildingAssignID] ASC)
);

