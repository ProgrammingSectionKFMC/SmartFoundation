CREATE TABLE [dbo].[Rank] (
    [rankID]         INT            IDENTITY (1, 1) NOT NULL,
    [rankClassID_FK] INT            NULL,
    [rankNameA]      NVARCHAR (100) NULL,
    [rankNameE]      NVARCHAR (100) NULL,
    [userType_FK]    INT            NULL,
    [rankActive]     BIT            NULL,
    CONSTRAINT [PK_Rank] PRIMARY KEY CLUSTERED ([rankID] ASC)
);

