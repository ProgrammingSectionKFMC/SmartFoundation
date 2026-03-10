CREATE TABLE [dbo].[ThameColorType] (
    [ThameColorTypeID]                 INT             IDENTITY (1, 1) NOT NULL,
    [ThameColorProgramBackGroundColor] NVARCHAR (50)   NULL,
    [ThameColorMenuBackGroundColor]    NVARCHAR (50)   NULL,
    [ThameColorChildBackGroundColor]   NVARCHAR (50)   NULL,
    [ThameColorProgramColor]           NVARCHAR (50)   NULL,
    [ThameColorMenuColor]              NVARCHAR (50)   NULL,
    [ThameColorChildColor]             NVARCHAR (50)   NULL,
    [ThameColorActive]                 BIT             NULL,
    [ThameColorDescription]            NVARCHAR (1000) NULL
);

