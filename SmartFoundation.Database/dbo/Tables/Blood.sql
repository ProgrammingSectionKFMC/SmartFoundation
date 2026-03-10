CREATE TABLE [dbo].[Blood] (
    [bloodID]          INT            IDENTITY (1, 1) NOT NULL,
    [bloodName_A]      NVARCHAR (50)  NULL,
    [bloodName_E]      NVARCHAR (50)  NULL,
    [bloodDescription] NVARCHAR (200) NULL,
    [bloodActive]      BIT            NULL,
    CONSTRAINT [PK_Blood] PRIMARY KEY CLUSTERED ([bloodID] ASC)
);

