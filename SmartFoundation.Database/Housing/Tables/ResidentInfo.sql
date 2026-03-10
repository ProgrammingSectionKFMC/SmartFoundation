CREATE TABLE [Housing].[ResidentInfo] (
    [residentInfoID]     BIGINT           IDENTITY (1, 1) NOT NULL,
    [residentInfoUID]    UNIQUEIDENTIFIER CONSTRAINT [DF_ResidentInfo_residentInfoUID] DEFAULT (newid()) NOT NULL,
    [NationalID]         NVARCHAR (50)    NULL,
    [residentInfoActive] BIT              CONSTRAINT [DF_ResidentInfo_residentInfoActive] DEFAULT ((1)) NULL,
    [entryDate]          DATETIME         CONSTRAINT [DF_ResidentInfo_entryDate] DEFAULT (getdate()) NULL,
    [entryData]          NVARCHAR (20)    NULL,
    [hostName]           NVARCHAR (200)   NULL,
    CONSTRAINT [PK_ResidentInfo_1] PRIMARY KEY CLUSTERED ([residentInfoID] ASC)
);

