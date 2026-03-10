CREATE TABLE [dbo].[Department] (
    [deptID]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [deptName_A]      NVARCHAR (50)  NULL,
    [deptName_E]      NVARCHAR (50)  NULL,
    [deptCode]        NVARCHAR (10)  NULL,
    [deptDescription] NVARCHAR (500) NULL,
    [deptStartDate]   DATE           NULL,
    [deptEndDate]     DATE           NULL,
    [deptActive]      BIT            NULL,
    [deptSoldiers]    BIT            NULL,
    [parentDeptID_FK] INT            NULL,
    [idaraID_FK]      BIGINT         NULL,
    [entryDate]       DATETIME       CONSTRAINT [DF_Department_entryDate] DEFAULT (getdate()) NULL,
    [entryData]       NVARCHAR (20)  NULL,
    [hostName]        NVARCHAR (200) CONSTRAINT [DF_Department_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_Department] PRIMARY KEY CLUSTERED ([deptID] ASC),
    CONSTRAINT [FK_Department_Idara] FOREIGN KEY ([idaraID_FK]) REFERENCES [dbo].[Idara] ([idaraID])
);

