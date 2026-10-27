CREATE TABLE [Housing].[ExitMeterBillProration] (
    [ProrationID]            BIGINT          IDENTITY (1, 1) NOT NULL,
    [ExitRequestActionID_FK] BIGINT          NOT NULL,
    [OriginalBillsID_FK]     BIGINT          NOT NULL,
    [ResidentBillsID_FK]     BIGINT          NULL,
    [VacantBillsID_FK]       BIGINT          NULL,
    [RevisionNo]             INT             NOT NULL,
    [ExitDate]               DATE            NOT NULL,
    [BillsFromDate]          DATE            NOT NULL,
    [BillsToDate]            DATE            NOT NULL,
    [OriginalAmount]         DECIMAL (18, 2) NOT NULL,
    [ResidentAmount]         DECIMAL (18, 2) NOT NULL,
    [VacantAmount]           DECIMAL (18, 2) NOT NULL,
    [CorrectionStatus]       TINYINT         NOT NULL,
    [CreatedDate]            DATETIME2 (3)   DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]              NVARCHAR (20)   NOT NULL,
    [ClosedDate]             DATETIME2 (3)   NULL,
    [ClosedBy]               NVARCHAR (20)   NULL,
    [PreOccupancyBillsID_FK] BIGINT          NULL,
    [PreOccupancyAmount]     DECIMAL (18, 2) CONSTRAINT [DF_ExitMeterBillProration_PreOccupancyAmount] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_ExitMeterBillProration] PRIMARY KEY CLUSTERED ([ProrationID] ASC),
    CONSTRAINT [CK_ExitMeterBillProration_Amounts] CHECK ([OriginalAmount]>=(0) AND [ResidentAmount]>=(0) AND [VacantAmount]>=(0) AND [OriginalAmount]=([ResidentAmount]+[VacantAmount])),
    CONSTRAINT [CK_ExitMeterBillProration_PreAmount] CHECK ([PreOccupancyAmount]>=(0) AND [PreOccupancyAmount]<=[VacantAmount]),
    CONSTRAINT [CK_ExitMeterBillProration_Revision] CHECK ([RevisionNo]>=(1)),
    CONSTRAINT [CK_ExitMeterBillProration_Status] CHECK ([CorrectionStatus]=(3) OR [CorrectionStatus]=(2) OR [CorrectionStatus]=(1)),
    CONSTRAINT [FK_ExitMeterBillProration_Original] FOREIGN KEY ([OriginalBillsID_FK]) REFERENCES [Housing].[Bills] ([BillsID])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitMeterBillProration_Revision]
    ON [Housing].[ExitMeterBillProration]([ExitRequestActionID_FK] ASC, [OriginalBillsID_FK] ASC, [RevisionNo] ASC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExitMeterBillProration_Active]
    ON [Housing].[ExitMeterBillProration]([OriginalBillsID_FK] ASC) WHERE ([CorrectionStatus]=(1));

