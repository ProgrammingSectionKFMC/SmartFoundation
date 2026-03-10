CREATE TABLE [dbo].[DecisionDigitalSignture] (
    [decisionDigitalSigntureID]      BIGINT           IDENTITY (1, 1) NOT NULL,
    [decisionDigitalSigntureUID]     UNIQUEIDENTIFIER CONSTRAINT [DF_DecisionDigitalSignture_decisionDigitalSigntureUID] DEFAULT (newid()) NULL,
    [transactionID_FK]               BIGINT           NULL,
    [decisionID_FK]                  BIGINT           NULL,
    [documentID_FK]                  BIGINT           NULL,
    [decisionDigitalSigntureQR]      IMAGE            NULL,
    [decisionDigitalSigntureOwnedBy] INT              NULL,
    [entryDate]                      DATETIME         CONSTRAINT [DF_DecisionDigitalSignture_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                      NVARCHAR (20)    NULL,
    [hostName]                       NVARCHAR (200)   NULL,
    CONSTRAINT [PK_DecisionDigitalSignture] PRIMARY KEY CLUSTERED ([decisionDigitalSigntureID] ASC)
);

