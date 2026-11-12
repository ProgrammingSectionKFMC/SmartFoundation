CREATE TABLE [VIC].[VehicleNationality] (
    [nationalityID]          INT            IDENTITY (1, 1) NOT NULL,
    [nationalityName_A]      NVARCHAR (50)  NULL,
    [nationalityName_E]      NVARCHAR (50)  NULL,
    [nationalityDescription] NVARCHAR (200) NULL,
    [nationalityActive]      BIT            NULL,
    CONSTRAINT [PK_VehicleNationality] PRIMARY KEY CLUSTERED ([nationalityID] ASC)
);


GO

