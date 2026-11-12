CREATE TABLE [VIC].[VehicleUserDetails] (
    [vehicleUserDetailsID] INT             IDENTITY (1, 1) NOT NULL,
    [vehicleUserID_FK]     INT             NOT NULL,
    [generalNo_Snapshot]   BIGINT          NULL,
    [rankID_FK]            INT             NULL,
    [nationalityID_FK]     INT             NULL,
    [genderID_FK]          INT             NULL,
    [firstName_A]          NVARCHAR (50)   NULL,
    [secondName_A]         NVARCHAR (50)   NULL,
    [thirdName_A]          NVARCHAR (50)   NULL,
    [lastName_A]           NVARCHAR (50)   NULL,
    [firstName_E]          NVARCHAR (50)   NULL,
    [secondName_E]         NVARCHAR (50)   NULL,
    [thirdName_E]          NVARCHAR (50)   NULL,
    [lastName_E]           NVARCHAR (50)   NULL,
    [note]                 NVARCHAR (1000) NULL,
    [detailsStartDate]     DATETIME        NULL,
    [detailsEndDate]       DATETIME        NULL,
    [detailsActive]        BIT             DEFAULT ((1)) NOT NULL,
    [IdaraID_FK]           BIGINT          NULL,
    [entryDate]            DATETIME        DEFAULT (getdate()) NOT NULL,
    [entryData]            NVARCHAR (40)   NULL,
    [hostName]             NVARCHAR (400)  NULL,
    CONSTRAINT [PK_VehicleUserDetails] PRIMARY KEY CLUSTERED ([vehicleUserDetailsID] ASC),
    CONSTRAINT [FK_VUD_Gender] FOREIGN KEY ([genderID_FK]) REFERENCES [VIC].[VehicleGender] ([genderID]),
    CONSTRAINT [FK_VUD_Nationality] FOREIGN KEY ([nationalityID_FK]) REFERENCES [VIC].[VehicleNationality] ([nationalityID]),
    CONSTRAINT [FK_VUD_Rank] FOREIGN KEY ([rankID_FK]) REFERENCES [VIC].[VehicleRank] ([rankID]),
    CONSTRAINT [FK_VUD_User] FOREIGN KEY ([vehicleUserID_FK]) REFERENCES [VIC].[VehicleUser] ([vehicleUserID])
);


GO

CREATE NONCLUSTERED INDEX [IX_VUD_User]
    ON [VIC].[VehicleUserDetails]([vehicleUserID_FK] ASC);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_VUD_OneActive]
    ON [VIC].[VehicleUserDetails]([vehicleUserID_FK] ASC) WHERE ([detailsActive]=(1));


GO

