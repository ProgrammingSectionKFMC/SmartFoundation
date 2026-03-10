CREATE TABLE [dbo].[MainBranches] (
    [branchID]          INT            IDENTITY (1, 1) NOT NULL,
    [branchName_A]      NVARCHAR (100) NULL,
    [branchName_E]      NVARCHAR (100) NULL,
    [branchStartDate]   DATETIME       NULL,
    [branchEndDate]     DATETIME       NULL,
    [branchDescription] NVARCHAR (200) NULL,
    [branchActive]      BIT            NULL,
    [adminID_FK]        INT            NULL,
    PRIMARY KEY CLUSTERED ([branchID] ASC),
    CONSTRAINT [FK_Branches_Admins_FK] FOREIGN KEY ([adminID_FK]) REFERENCES [dbo].[LocalAdministrations] ([adminID])
);

