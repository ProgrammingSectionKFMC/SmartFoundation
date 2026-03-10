CREATE TABLE [dbo].[Servers] (
    [ServerID]      INT            IDENTITY (1, 1) NOT NULL,
    [ServerName]    NVARCHAR (200) NULL,
    [serverIsFiles] BIT            NULL,
    [serverActive]  BIT            NULL,
    [serverIp]      NVARCHAR (200) NULL,
    CONSTRAINT [PK_Servers] PRIMARY KEY CLUSTERED ([ServerID] ASC)
);

