CREATE TABLE [Housing].[ResidentContactType] (
    [residentcontanctTypeID]    INT           IDENTITY (1, 1) NOT NULL,
    [residentcontactTypeName_A] NVARCHAR (50) NULL,
    [residentcontactTypeName_E] NVARCHAR (50) NULL,
    CONSTRAINT [PK_ResidentContactType] PRIMARY KEY CLUSTERED ([residentcontanctTypeID] ASC)
);

