CREATE TABLE [Housing].[RentBills] (
    [rentBillsID]           BIGINT          IDENTITY (1, 1) NOT NULL,
    [residentInfoID_FK]     BIGINT          NULL,
    [buildingDetailsID_FK]  BIGINT          NULL,
    [buildingRentTypeID_FK] BIGINT          NULL,
    [rentBillsAmount]       DECIMAL (18, 2) NULL,
    [rentBillsFromDate]     DATETIME        NULL,
    [rentBillsToDate]       DATETIME        NULL,
    [rentBillsActive]       BIT             NULL,
    [idaraID_FK]            BIGINT          NULL,
    [entryDate]             DATETIME        CONSTRAINT [DF_RentBills_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)   NULL,
    [hostName]              NVARCHAR (200)  NULL,
    CONSTRAINT [PK_RentBills] PRIMARY KEY CLUSTERED ([rentBillsID] ASC),
    CONSTRAINT [FK_RentBills_BuildingDetails] FOREIGN KEY ([buildingDetailsID_FK]) REFERENCES [Housing].[BuildingDetails] ([buildingDetailsID]),
    CONSTRAINT [FK_RentBills_ResidentInfo] FOREIGN KEY ([residentInfoID_FK]) REFERENCES [Housing].[ResidentInfo] ([residentInfoID])
);


GO
CREATE NONCLUSTERED INDEX [IX_RentBills_resident]
    ON [Housing].[RentBills]([residentInfoID_FK] ASC)
    INCLUDE([rentBillsAmount]);

