CREATE TABLE [dbo].[Role] (
    [roleID]                      BIGINT         IDENTITY (1, 1) NOT NULL,
    [roleName_A]                  NVARCHAR (100) NULL,
    [roleName_E]                  NVARCHAR (100) NULL,
    [roleDescription]             NVARCHAR (250) NULL,
    [aMustInDepartment]           BIT            NULL,
    [aMustInSection]              BIT            NULL,
    [aMustInDivision]             BIT            NULL,
    [onDepartmentLevel]           BIT            NULL,
    [onSectionLevel]              BIT            NULL,
    [onDivisionLevel]             BIT            NULL,
    [departmentsCanAssignUsers]   BIT            NULL,
    [allowedInUserDepartmentOnly] BIT            NULL,
    [allowedInUserDSDOnly]        BIT            NULL,
    [atMostOne]                   BIT            NULL,
    [PublicView]                  BIT            NULL,
    CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED ([roleID] ASC)
);

