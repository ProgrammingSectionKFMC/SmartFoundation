CREATE TABLE [dbo].[DeptSecDiv] (
    [DSDID]             BIGINT         IDENTITY (1, 1) NOT NULL,
    [OrganizationID_FK] BIGINT         NULL,
    [idaraID_FK]        BIGINT         NULL,
    [deptID_FK]         BIGINT         NULL,
    [secID_FK]          BIGINT         NULL,
    [divID_FK]          BIGINT         NULL,
    [entryDate]         DATETIME       CONSTRAINT [DF_DeptSecDiv_entryDate] DEFAULT (getdate()) NULL,
    [entryData]         NVARCHAR (20)  NULL,
    [hostName]          NVARCHAR (200) CONSTRAINT [DF_DeptSecDiv_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DeptSecDiv] PRIMARY KEY CLUSTERED ([DSDID] ASC),
    CONSTRAINT [FK_DeptSecDiv_Department] FOREIGN KEY ([deptID_FK]) REFERENCES [dbo].[Department] ([deptID]),
    CONSTRAINT [FK_DeptSecDiv_Divison] FOREIGN KEY ([divID_FK]) REFERENCES [dbo].[Divison] ([divID]),
    CONSTRAINT [FK_DeptSecDiv_Section] FOREIGN KEY ([secID_FK]) REFERENCES [dbo].[Section] ([secID])
);

