CREATE TABLE [VIC].[VehicleTransferRequest] (
    [RequestID]        INT            IDENTITY (1, 1) NOT NULL,
    [RequestTypeID_FK] INT            NULL,
    [chassisNumber_FK] NVARCHAR (100) NULL,
    [fromUserID_FK]    INT            NULL,
    [toUserID_FK]      INT            NULL,
    [deptID_FK]        INT            NULL,
    [CreateByUser]     NVARCHAR (200) NULL,
    [aproveNote]       NVARCHAR (200) NULL,
    [active]           BIT            NULL,
    [entryDate]        DATETIME       CONSTRAINT [DF_VehicleTransferRequest_entryDate] DEFAULT (getdate()) NULL,
    [entryData]        NVARCHAR (20)  NULL,
    [hostName]         NVARCHAR (200) NULL,
    [IdaraID_FK]       BIGINT         NULL,
    CONSTRAINT [PK_VehicleTransferRequest] PRIMARY KEY CLUSTERED ([RequestID] ASC),
    CONSTRAINT [FK_VehicleTransferRequest_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_VehicleTransferRequest_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

