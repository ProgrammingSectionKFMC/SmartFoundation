CREATE TABLE [Housing].[MeterSlide] (
    [meterSlideID]             INT             IDENTITY (1, 1) NOT NULL,
    [buildingUtilityTypeID_FK] BIGINT          NULL,
    [meterServiceTypeID_FK]    INT             NULL,
    [meterSlideSequence]       INT             NULL,
    [meterSlideName_A]         NVARCHAR (100)  NULL,
    [meterSlideName_E]         NVARCHAR (100)  NULL,
    [meterSlideDescription]    NVARCHAR (1000) NULL,
    [meterSlideMinValue]       INT             NULL,
    [meterSlideMaxValue]       INT             NULL,
    [meterSlideStartDate]      DATETIME        NULL,
    [meterSlideEndDate]        DATETIME        NULL,
    [meterSlidePriceFactor]    FLOAT (53)      NULL,
    [meterSlideActive]         BIT             NULL,
    [entryDate]                DATETIME        CONSTRAINT [DF_MeterSlide_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                NVARCHAR (20)   NULL,
    [hostName]                 NVARCHAR (200)  NULL,
    CONSTRAINT [PK_MeterSlide] PRIMARY KEY CLUSTERED ([meterSlideID] ASC),
    CONSTRAINT [FK_MeterSlide_BuildingUtilityType] FOREIGN KEY ([buildingUtilityTypeID_FK]) REFERENCES [Housing].[BuildingUtilityType] ([buildingUtilityTypeID]),
    CONSTRAINT [FK_MeterSlide_MeterServiceType] FOREIGN KEY ([meterServiceTypeID_FK]) REFERENCES [Housing].[MeterServiceType] ([meterServiceTypeID])
);


GO
CREATE NONCLUSTERED INDEX [IX_MeterSlide_Service_Utility_Seq]
    ON [Housing].[MeterSlide]([meterServiceTypeID_FK] ASC, [buildingUtilityTypeID_FK] ASC, [meterSlideSequence] ASC)
    INCLUDE([meterSlideMinValue], [meterSlideMaxValue], [meterSlidePriceFactor]);


GO
CREATE NONCLUSTERED INDEX [IX_MeterSlide_Utility_Service_Seq]
    ON [Housing].[MeterSlide]([buildingUtilityTypeID_FK] ASC, [meterServiceTypeID_FK] ASC, [meterSlideSequence] ASC)
    INCLUDE([meterSlideMinValue], [meterSlideMaxValue], [meterSlidePriceFactor]);

