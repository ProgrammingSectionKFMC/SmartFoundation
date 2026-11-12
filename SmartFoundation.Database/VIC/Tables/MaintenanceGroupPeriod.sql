CREATE TABLE [VIC].[MaintenanceGroupPeriod] (
    [PeriodID]    INT     IDENTITY (1, 1) NOT NULL,
    [GroupID_FK]  INT     NOT NULL,
    [MonthNumber] TINYINT NOT NULL,
    PRIMARY KEY CLUSTERED ([PeriodID] ASC),
    CHECK ([MonthNumber]>=(1) AND [MonthNumber]<=(12)),
    FOREIGN KEY ([GroupID_FK]) REFERENCES [VIC].[MaintenanceGroup] ([GroupID]),
    CONSTRAINT [UQ_GroupPeriod] UNIQUE NONCLUSTERED ([GroupID_FK] ASC, [MonthNumber] ASC)
);


GO

