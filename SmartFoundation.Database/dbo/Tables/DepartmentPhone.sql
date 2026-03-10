CREATE TABLE [dbo].[DepartmentPhone] (
    [deptPhoneID]    INT            IDENTITY (1, 1) NOT NULL,
    [phoneBookID_FK] INT            NULL,
    [DSDID_FK]       BIGINT         NULL,
    [entryDate]      DATETIME       CONSTRAINT [DF_DepartmentPhone_entryDate] DEFAULT (getdate()) NULL,
    [entryData]      NVARCHAR (20)  NULL,
    [hostName]       NVARCHAR (200) CONSTRAINT [DF_DepartmentPhone_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_DepartmentPhone] PRIMARY KEY CLUSTERED ([deptPhoneID] ASC),
    CONSTRAINT [FK_DepartmentPhone_DeptSecDiv] FOREIGN KEY ([DSDID_FK]) REFERENCES [dbo].[DeptSecDiv] ([DSDID]),
    CONSTRAINT [FK_DepartmentPhone_PhoneBook] FOREIGN KEY ([phoneBookID_FK]) REFERENCES [dbo].[PhoneBook] ([phoneBookID])
);

