CREATE TABLE [dbo].[HousingExcelReview_20261108] (
    [RowNo]             INT             NOT NULL,
    [NationalID]        NVARCHAR (50)   NULL,
    [GeneralNo]         BIGINT          NOT NULL,
    [FullNameA]         NVARCHAR (300)  NULL,
    [CorrectNationalID] NVARCHAR (150)  NULL,
    [RequiredAction]    NVARCHAR (1000) NULL,
    [NoID]              TINYINT         NOT NULL,
    PRIMARY KEY CLUSTERED ([RowNo] ASC),
    CHECK ([NoID]=(2) OR [NoID]=(1) OR [NoID]=(0))
);

