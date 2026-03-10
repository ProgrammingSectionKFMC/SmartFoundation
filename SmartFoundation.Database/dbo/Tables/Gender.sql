CREATE TABLE [dbo].[Gender] (
    [genderID]          INT            IDENTITY (1, 1) NOT NULL,
    [genderName_A]      NVARCHAR (50)  NULL,
    [genderName_E]      NVARCHAR (50)  NULL,
    [genderDescription] NVARCHAR (100) NULL,
    CONSTRAINT [PK_Gender] PRIMARY KEY CLUSTERED ([genderID] ASC)
);

