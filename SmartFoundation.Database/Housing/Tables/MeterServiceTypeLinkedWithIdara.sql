CREATE TABLE [Housing].[MeterServiceTypeLinkedWithIdara] (
    [MeterServiceTypeLinkedWithIdaraID]        INT            IDENTITY (1, 1) NOT NULL,
    [MeterServiceTypeID_FK]                    INT            NULL,
    [Idara_FK]                                 INT            NULL,
    [MeterServiceTypeLinkedWithIdaraStartDate] DATETIME       NULL,
    [MeterServiceTypeLinkedWithIdaraEndDate]   DATETIME       NULL,
    [MeterServiceTypeLinkedWithIdaraActive]    BIT            NULL,
    [entryDate]                                DATETIME       CONSTRAINT [DF_MeterServiceTypeLinkedWithIdara_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                                NVARCHAR (20)  NULL,
    [hostName]                                 NVARCHAR (200) NULL,
    CONSTRAINT [PK_MeterServiceTypeLinkedWithIdara] PRIMARY KEY CLUSTERED ([MeterServiceTypeLinkedWithIdaraID] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_MSTLinked_Idara_Active_Dates]
    ON [Housing].[MeterServiceTypeLinkedWithIdara]([Idara_FK] ASC, [MeterServiceTypeLinkedWithIdaraActive] ASC, [MeterServiceTypeID_FK] ASC, [MeterServiceTypeLinkedWithIdaraStartDate] ASC, [MeterServiceTypeLinkedWithIdaraEndDate] ASC);

