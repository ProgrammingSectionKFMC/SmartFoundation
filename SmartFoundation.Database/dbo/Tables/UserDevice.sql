CREATE TABLE [dbo].[UserDevice] (
    [ID]                     INT             IDENTITY (1, 1) NOT NULL,
    [userID_FK]              INT             NULL,
    [deptID_FK]              INT             NULL,
    [ModelTypeID]            INT             NULL,
    [WinType_FK]             INT             NULL,
    [domainTypeID_FK]        INT             NULL,
    [serialNo]               NVARCHAR (200)  NULL,
    [CDPort]                 BIT             NULL,
    [usbPort]                BIT             NULL,
    [deviceNameChanging]     BIT             NULL,
    [domainInsert]           BIT             NULL,
    [programsInstall]        BIT             NULL,
    [userSupportID]          INT             NULL,
    [SecSupportSupervisorID] INT             NULL,
    [deptManagerID]          INT             NULL,
    [note]                   NVARCHAR (1000) NULL,
    [userDeviceActive]       BIT             NULL,
    [entryDate]              DATETIME        CONSTRAINT [DF_UserDevice_entryDate] DEFAULT (getdate()) NULL,
    [entryData]              NVARCHAR (20)   NULL,
    [hostName]               NVARCHAR (200)  CONSTRAINT [DF_UserDevice_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_UserDevice] PRIMARY KEY CLUSTERED ([ID] ASC)
);

