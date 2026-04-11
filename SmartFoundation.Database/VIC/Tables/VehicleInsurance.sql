CREATE TABLE [VIC].[VehicleInsurance] (
    [VehicleInsuranceID]       INT            IDENTITY (1, 1) NOT NULL,
    [InsuranceOpertionType_FK] INT            NULL,
    [InsuranceTypeID_FK]       INT            NULL,
    [chassisNumber_FK]         NVARCHAR (100) NULL,
    [Source]                   NVARCHAR (150) NULL,
    [StartInsurance]           DATETIME       NULL,
    [EndInsurance]             DATETIME       NULL,
    [Amount]                   FLOAT (53)     NULL,
    [Note]                     NVARCHAR (400) NULL,
    [active]                   BIT            NULL,
    [entryDate]                DATETIME       CONSTRAINT [DF_VehicleInsurance_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)  NULL,
    [hostName]                 NVARCHAR (200) NULL,
    [IdaraID_FK]               BIGINT         NULL,
    CONSTRAINT [PK_VehicleInsurance] PRIMARY KEY CLUSTERED ([VehicleInsuranceID] ASC),
    CONSTRAINT [CK_VehicleInsurance_DateRange] CHECK ([StartInsurance] IS NULL OR [EndInsurance] IS NULL OR [StartInsurance]<=[EndInsurance]),
    CONSTRAINT [FK_VehicleInsurance_Idara] FOREIGN KEY ([IdaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID]),
    CONSTRAINT [FK_VehicleInsurance_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

