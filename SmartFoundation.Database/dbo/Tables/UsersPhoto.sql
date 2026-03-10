CREATE TABLE [dbo].[UsersPhoto] (
    [userPhotoID]     INT              NOT NULL,
    [userPhotoUID]    UNIQUEIDENTIFIER NULL,
    [usersID_FK]      BIGINT           NOT NULL,
    [Photo]           IMAGE            NULL,
    [userPhotoActive] BIT              NULL,
    [entryDate]       DATETIME         NULL,
    [entryData]       NVARCHAR (20)    NULL,
    [hostName]        NVARCHAR (200)   NULL
);

