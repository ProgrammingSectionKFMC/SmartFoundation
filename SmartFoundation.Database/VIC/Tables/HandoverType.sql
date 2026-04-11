CREATE TABLE [VIC].[HandoverType] (
    [handOverTypeID]     INT            IDENTITY (1, 1) NOT NULL,
    [handOverTypeName_A] NVARCHAR (50)  NULL,
    [handOverTypeName_E] NVARCHAR (50)  NULL,
    [active]             BIT            NULL,
    [entryDate]          DATETIME       CONSTRAINT [DF_HandoverType_ed] DEFAULT (getdate()) NOT NULL,
    [entryData]          NVARCHAR (40)  NULL,
    [hostName]           NVARCHAR (400) NULL,
    CONSTRAINT [PK_HandoverType] PRIMARY KEY CLUSTERED ([handOverTypeID] ASC)
);

