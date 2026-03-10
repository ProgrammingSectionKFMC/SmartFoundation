CREATE TABLE [Housing].[Bills] (
    [BillsID]               BIGINT           IDENTITY (1, 1) NOT NULL,
    [BillsUID]              UNIQUEIDENTIFIER CONSTRAINT [DF_Bills_BillsUID] DEFAULT (newid()) NULL,
    [BillChargeTypeID_FK]   INT              NULL,
    [BillNumber]            AS               (concat(substring(CONVERT([nvarchar](8),[PeriodYear]),(3),(2)),right('0'+CONVERT([nvarchar](2),[PeriodMonth]),(2)),right('000000000'+CONVERT([nvarchar](50),[BillsID]),(9)))) PERSISTED NOT NULL,
    [BillTypeID_FK]         INT              NULL,
    [PerviosPeriodID]       INT              NULL,
    [CurrentPeriodID]       INT              NULL,
    [PeriodMonth]           INT              NULL,
    [PeriodYear]            INT              NULL,
    [CurrentPeriodTax]      DECIMAL (18, 2)  NULL,
    [meterNo]               NVARCHAR (100)   NULL,
    [meterID]               INT              NULL,
    [meterName_A]           NVARCHAR (200)   NULL,
    [meterName_E]           NVARCHAR (200)   NULL,
    [meterDescription]      NVARCHAR (200)   NULL,
    [buildingDetailsNo]     NVARCHAR (200)   NULL,
    [buildingUtilityTypeID] INT              NULL,
    [buildingDetailsID]     INT              NULL,
    [meterTypeID]           INT              NULL,
    [meterServiceTypeID]    INT              NULL,
    [meterReadID]           INT              NULL,
    [residentInfoID_FK]     BIGINT           NULL,
    [generalNo_FK]          BIGINT           NULL,
    [CurrentRead]           INT              NULL,
    [LastRead]              INT              NULL,
    [ReadDiff]              INT              NULL,
    [meterSlideMinValue1]   INT              NULL,
    [meterSlideMaxValue1]   INT              NULL,
    [SlidePriceFactor1]     DECIMAL (18, 2)  NULL,
    [PriceForSlide1]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue2]   INT              NULL,
    [meterSlideMaxValue2]   INT              NULL,
    [SlidePriceFactor2]     DECIMAL (18, 2)  NULL,
    [PriceForSlide2]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue3]   INT              NULL,
    [meterSlideMaxValue3]   INT              NULL,
    [SlidePriceFactor3]     DECIMAL (18, 2)  NULL,
    [PriceForSlide3]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue4]   INT              NULL,
    [meterSlideMaxValue4]   INT              NULL,
    [SlidePriceFactor4]     DECIMAL (18, 2)  NULL,
    [PriceForSlide4]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue5]   INT              NULL,
    [meterSlideMaxValue5]   INT              NULL,
    [SlidePriceFactor5]     DECIMAL (18, 2)  NULL,
    [PriceForSlide5]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue6]   INT              NULL,
    [meterSlideMaxValue6]   INT              NULL,
    [SlidePriceFactor6]     DECIMAL (18, 2)  NULL,
    [PriceForSlide6]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue7]   INT              NULL,
    [meterSlideMaxValue7]   INT              NULL,
    [SlidePriceFactor7]     DECIMAL (18, 2)  NULL,
    [PriceForSlide7]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue8]   INT              NULL,
    [meterSlideMaxValue8]   INT              NULL,
    [SlidePriceFactor8]     DECIMAL (18, 2)  NULL,
    [PriceForSlide8]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue9]   INT              NULL,
    [meterSlideMaxValue9]   INT              NULL,
    [SlidePriceFactor9]     DECIMAL (18, 2)  NULL,
    [PriceForSlide9]        DECIMAL (18, 2)  NULL,
    [meterSlideMinValue10]  INT              NULL,
    [meterSlideMaxValue10]  INT              NULL,
    [SlidePriceFactor10]    DECIMAL (18, 2)  NULL,
    [PriceForSlide10]       DECIMAL (18, 2)  NULL,
    [PRICE]                 DECIMAL (18, 2)  NULL,
    [PRICETAX]              DECIMAL (18, 2)  NULL,
    [meterServicePrice]     DECIMAL (18, 2)  NULL,
    [meterServicePriceTAX]  DECIMAL (18, 2)  NULL,
    [TotalPrice]            DECIMAL (18, 2)  NULL,
    [buildingRentTypeID_FK] BIGINT           NULL,
    [BillsFromDate]         DATETIME         NULL,
    [BillsToDate]           DATETIME         NULL,
    [PenaltyReason]         NVARCHAR (4000)  NULL,
    [BillActive]            BIT              NULL,
    [CanceledBy]            NVARCHAR (1000)  NULL,
    [idaraID_FK]            BIGINT           NULL,
    [entryDate]             DATETIME         CONSTRAINT [DF_Bills_entryDate] DEFAULT (getdate()) NULL,
    [entryData]             NVARCHAR (20)    NULL,
    [hostName]              NVARCHAR (200)   NULL,
    CONSTRAINT [PK_Bills] PRIMARY KEY CLUSTERED ([BillsID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_Bills_resident_active]
    ON [Housing].[Bills]([residentInfoID_FK] ASC, [BillActive] ASC)
    INCLUDE([TotalPrice], [BillsID]);


GO
CREATE NONCLUSTERED INDEX [IX_Bills_Period_Idara_ServiceType]
    ON [Housing].[Bills]([CurrentPeriodID] ASC, [idaraID_FK] ASC, [meterServiceTypeID] ASC, [BillTypeID_FK] ASC, [BillActive] ASC, [meterID] ASC)
    INCLUDE([BillsID], [PeriodMonth], [PeriodYear], [meterNo], [meterName_A], [buildingDetailsNo], [buildingDetailsID], [meterReadID], [CurrentRead], [LastRead], [ReadDiff], [PriceForSlide1], [PriceForSlide2], [PriceForSlide3], [PriceForSlide4], [PriceForSlide5], [PriceForSlide6], [PriceForSlide7], [PriceForSlide8], [PriceForSlide9], [PriceForSlide10], [PRICE], [PRICETAX], [meterServicePrice], [meterServicePriceTAX], [TotalPrice], [residentInfoID_FK], [entryDate], [entryData]);


GO
CREATE NONCLUSTERED INDEX [IX_Bills_Exists_Readed]
    ON [Housing].[Bills]([CurrentPeriodID] ASC, [idaraID_FK] ASC, [meterServiceTypeID] ASC, [BillTypeID_FK] ASC, [BillActive] ASC, [meterID] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_Bills_Resident_ServiceType_Avg]
    ON [Housing].[Bills]([residentInfoID_FK] ASC, [meterServiceTypeID] ASC, [BillActive] ASC)
    INCLUDE([TotalPrice]);


GO
CREATE NONCLUSTERED INDEX [IX_Bills_ResidentServiceLookup]
    ON [Housing].[Bills]([residentInfoID_FK] ASC, [meterServiceTypeID] ASC, [BillActive] ASC, [BillTypeID_FK] ASC, [PeriodYear] DESC, [PeriodMonth] DESC, [CurrentPeriodID] DESC, [BillsID] DESC)
    INCLUDE([TotalPrice]);

