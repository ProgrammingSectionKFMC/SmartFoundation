CREATE TABLE [dbo].[Education] (
    [educationID]          INT            IDENTITY (1, 1) NOT NULL,
    [educationName_A]      NVARCHAR (100) NULL,
    [educationName_E]      NVARCHAR (100) NULL,
    [educationDescription] NVARCHAR (300) NULL,
    [educationActive]      BIT            NULL,
    CONSTRAINT [PK_Education] PRIMARY KEY CLUSTERED ([educationID] ASC)
);

