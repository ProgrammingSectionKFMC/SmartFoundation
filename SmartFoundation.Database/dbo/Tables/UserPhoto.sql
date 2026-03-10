CREATE TABLE [dbo].[UserPhoto] (
    [userPhotoID]     INT              IDENTITY (1, 1) NOT NULL,
    [userPhotoUID]    UNIQUEIDENTIFIER CONSTRAINT [DF_UserPhoto_userPhotoUID] DEFAULT (newid()) NULL,
    [userID_FK]       INT              NULL,
    [Photo]           IMAGE            NULL,
    [userPhotoActive] BIT              NULL,
    [entryDate]       DATETIME         CONSTRAINT [DF_UserPhoto_entryDate] DEFAULT (getdate()) NULL,
    [entryData]       NVARCHAR (20)    NULL,
    [hostName]        NVARCHAR (200)   CONSTRAINT [DF_UserPhoto_hostName] DEFAULT (host_name()) NULL,
    CONSTRAINT [PK_UserPhoto] PRIMARY KEY CLUSTERED ([userPhotoID] ASC)
);

