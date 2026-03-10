CREATE TABLE [dbo].[Religion] (
    [religionID]          INT            IDENTITY (1, 1) NOT NULL,
    [religionName_A]      NVARCHAR (50)  NULL,
    [religionName_E]      NVARCHAR (50)  NULL,
    [religionDescription] NVARCHAR (200) NULL,
    [religionActive]      BIT            NULL,
    CONSTRAINT [PK_Religion] PRIMARY KEY CLUSTERED ([religionID] ASC)
);

