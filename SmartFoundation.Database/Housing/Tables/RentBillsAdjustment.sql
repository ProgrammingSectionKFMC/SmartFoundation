CREATE TABLE [Housing].[RentBillsAdjustment] (
    [rentBillsAdjustmentID]          BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentInfoID_FK]              BIGINT          NULL,
    [buildingDetailsID_FK]           BIGINT          NULL,
    [rentBillsID_FK]                 BIGINT          NULL,
    [rentBillsAdjustmentAmount]      DECIMAL (18, 2) NULL,
    [rentBillsAdjustmentActive]      BIT             NULL,
    [buildlingRentChangeReasonID_FK] BIGINT          NULL,
    [rentBillsAdjustmentDescription] NVARCHAR (1000) NULL,
    [idaraID_FK]                     BIGINT          NULL,
    [entryDate]                      DATETIME        CONSTRAINT [DF_RentBillsAdjustment_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (20)   NULL,
    [hostName]                       NVARCHAR (200)  NULL,
    CONSTRAINT [PK_RentBillsAdjustment] PRIMARY KEY CLUSTERED ([rentBillsAdjustmentID] ASC),
    CONSTRAINT [FK_RentBillsAdjustment_BuildingDetails] FOREIGN KEY ([buildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_RentBillsAdjustment_RentBills] FOREIGN KEY ([rentBillsID_FK]) REFERENCES [Housing].[RentBills] ([rentBillsID]),
    CONSTRAINT [FK_RentBillsAdjustment_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID])
);

