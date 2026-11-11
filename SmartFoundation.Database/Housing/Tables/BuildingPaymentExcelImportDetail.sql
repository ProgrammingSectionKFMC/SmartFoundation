CREATE TABLE [Housing].[BuildingPaymentExcelImportDetail] (
    [ImportDetailID]             BIGINT          IDENTITY (1, 1) NOT NULL,
    [DeductListID_FK]            INT             NOT NULL,
    [ExcelRowNo]                 INT             NOT NULL,
    [ExcelPaymentID_FK]          BIGINT          NOT NULL,
    [ReplacedManualPaymentID_FK] BIGINT          NULL,
    [MatchStatus]                NVARCHAR (20)   NOT NULL,
    [MatchNote]                  NVARCHAR (1000) NULL,
    [entryDate]                  DATETIME2 (0)   CONSTRAINT [DF_BPExcelDetail_entryDate] DEFAULT (sysdatetime()) NOT NULL,
    [entryData]                  NVARCHAR (200)  NULL,
    [MatchedManualPaymentID_FK]  BIGINT          NULL,
    CONSTRAINT [PK_BPExcelDetail] PRIMARY KEY CLUSTERED ([ImportDetailID] ASC),
    CONSTRAINT [CK_BPExcelDetail_CoveredManual] CHECK ([MatchStatus]=N'COVERED_BY_MANUAL' AND [MatchedManualPaymentID_FK] IS NOT NULL AND [ReplacedManualPaymentID_FK] IS NULL AND [MatchedManualPaymentID_FK]<>[ExcelPaymentID_FK] OR [MatchStatus]<>N'COVERED_BY_MANUAL' AND [MatchedManualPaymentID_FK] IS NULL),
    CONSTRAINT [CK_BPExcelDetail_DifferentPayments] CHECK ([ReplacedManualPaymentID_FK] IS NULL OR [ReplacedManualPaymentID_FK]<>[ExcelPaymentID_FK]),
    CONSTRAINT [CK_BPExcelDetail_Replacement] CHECK ([MatchStatus]=N'REPLACED' AND [ReplacedManualPaymentID_FK] IS NOT NULL OR [MatchStatus]<>N'REPLACED' AND [ReplacedManualPaymentID_FK] IS NULL),
    CONSTRAINT [CK_BPExcelDetail_RowNo] CHECK ([ExcelRowNo]>(0)),
    CONSTRAINT [CK_BPExcelDetail_Status] CHECK ([MatchStatus]=N'COVERED_BY_MANUAL' OR [MatchStatus]=N'REPLACED' OR [MatchStatus]=N'PROTECTED' OR [MatchStatus]=N'AMBIGUOUS' OR [MatchStatus]=N'POSSIBLE_MATCH' OR [MatchStatus]=N'IMPORTED'),
    CONSTRAINT [FK_BPExcelDetail_DeductList] FOREIGN KEY ([DeductListID_FK]) REFERENCES [Housing].[DeductList] ([deductListID]),
    CONSTRAINT [FK_BPExcelDetail_ExcelPayment] FOREIGN KEY ([ExcelPaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [FK_BPExcelDetail_MatchedManual] FOREIGN KEY ([MatchedManualPaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [FK_BPExcelDetail_ReplacedPayment] FOREIGN KEY ([ReplacedManualPaymentID_FK]) REFERENCES [Housing].[BuildingPayment] ([paymentID]),
    CONSTRAINT [UQ_BPExcelDetail_Payment] UNIQUE NONCLUSTERED ([ExcelPaymentID_FK] ASC),
    CONSTRAINT [UQ_BPExcelDetail_Row] UNIQUE NONCLUSTERED ([DeductListID_FK] ASC, [ExcelRowNo] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_BPExcelDetail_MatchedManual]
    ON [Housing].[BuildingPaymentExcelImportDetail]([MatchedManualPaymentID_FK] ASC) WHERE ([MatchedManualPaymentID_FK] IS NOT NULL);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_BPExcelDetail_ReplacedManual]
    ON [Housing].[BuildingPaymentExcelImportDetail]([ReplacedManualPaymentID_FK] ASC) WHERE ([ReplacedManualPaymentID_FK] IS NOT NULL);

