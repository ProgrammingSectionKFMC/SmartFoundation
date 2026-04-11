CREATE TABLE [VIC].[VehicleTransferRequestHistory] (
    [HistoryID]    INT             IDENTITY (1, 1) NOT NULL,
    [RequestID_FK] INT             NOT NULL,
    [Status]       NVARCHAR (50)   NOT NULL,
    [ActionBy]     INT             NOT NULL,
    [ActionDate]   DATETIME        DEFAULT (getdate()) NOT NULL,
    [Notes]        NVARCHAR (1000) NULL,
    [hostName]     NVARCHAR (200)  NULL,
    [entryDate]    DATETIME        CONSTRAINT [DF_VehicleTransferRequestHistory_ed] DEFAULT (getdate()) NOT NULL,
    [entryData]    NVARCHAR (20)   NULL,
    PRIMARY KEY CLUSTERED ([HistoryID] ASC),
    CONSTRAINT [FK_VehicleTransferRequestHistory_Request] FOREIGN KEY ([RequestID_FK]) REFERENCES [VIC].[VehicleTransferRequest] ([RequestID]),
    CONSTRAINT [FK_VTRH_Request] FOREIGN KEY ([RequestID_FK]) REFERENCES [VIC].[VehicleTransferRequest] ([RequestID])
);

