CREATE TABLE [VIC].[VehicleMaintenancePlan] (
    [PlanID]           INT            IDENTITY (1, 1) NOT NULL,
    [chassisNumber_FK] NVARCHAR (100) NOT NULL,
    [periodMonths]     INT            NOT NULL,
    [nextDueDate]      DATETIME       NOT NULL,
    [planActive]       BIT            CONSTRAINT [DF_VehicleMaintenancePlan_planActive] DEFAULT ((1)) NOT NULL,
    [IdaraID_FK]       BIGINT         NULL,
    [entryDate]        DATETIME       CONSTRAINT [DF_VehicleMaintenancePlan_entryDate] DEFAULT (getdate()) NOT NULL,
    [entryData]        NVARCHAR (40)  NULL,
    [hostName]         NVARCHAR (400) NULL,
    CONSTRAINT [PK_VehicleMaintenancePlan] PRIMARY KEY CLUSTERED ([PlanID] ASC),
    CONSTRAINT [CK_VehicleMaintenancePlan_PeriodMonths] CHECK ([periodMonths]>(0)),
    CONSTRAINT [FK_VehicleMaintenancePlan_Vehicles] FOREIGN KEY ([chassisNumber_FK]) REFERENCES [VIC].[Vehicles] ([chassisNumber])
);

