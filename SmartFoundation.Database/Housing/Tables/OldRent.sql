CREATE TABLE [Housing].[OldRent] (
    [OldRentID]  INT             IDENTITY (1, 1) NOT NULL,
    [BuildingNo] NVARCHAR (200)  NULL,
    [GeneralNo]  NVARCHAR (200)  NULL,
    [FullName]   NVARCHAR (200)  NULL,
    [Amount]     DECIMAL (18, 2) NULL,
    [Note]       NVARCHAR (1000) NULL,
    [active]     BIT             NULL
);

