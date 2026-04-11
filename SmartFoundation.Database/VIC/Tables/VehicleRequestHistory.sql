CREATE TABLE [VIC].[VehicleRequestHistory] (
    [HistoryID]    BIGINT          IDENTITY (1, 1) NOT NULL,
    [RequestID_FK] BIGINT          NOT NULL,
    [Status]       NVARCHAR (40)   NOT NULL,
    [ActionBy]     BIGINT          NULL,
    [ActionDate]   DATETIME        CONSTRAINT [DF_VehicleRequestHistory_ActionDate] DEFAULT (getdate()) NOT NULL,
    [Notes]        NVARCHAR (1000) NULL,
    [entryDate]    DATETIME        CONSTRAINT [DF_VehicleRequestHistory_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]    NVARCHAR (100)  NULL,
    [hostName]     NVARCHAR (400)  NULL,
    CONSTRAINT [PK_VehicleRequestHistory] PRIMARY KEY CLUSTERED ([HistoryID] ASC)
);

