CREATE TABLE [dbo].[JSONData] (
    [IDUID]        UNIQUEIDENTIFIER CONSTRAINT [DF_JSONData_IDUID] DEFAULT (newid()) NOT NULL,
    [ID]           INT              IDENTITY (1, 1) NOT NULL,
    [JSONData]     NVARCHAR (MAX)   NULL,
    [JsonDeteTime] DATETIME         NULL,
    [JsonBarcode]  NVARCHAR (300)   NULL
);

