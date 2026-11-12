CREATE TABLE [Housing].[BuildingPaymentLinkAudit] (
    [buildingPaymentLinkAuditID] BIGINT          IDENTITY (1, 1) NOT NULL,
    [paymentID_FK]               BIGINT          NOT NULL,
    [oldLinkStatusID]            INT             NULL,
    [newLinkStatusID]            INT             NULL,
    [oldBuildingDetailsID]       NVARCHAR (400)  NULL,
    [newBuildingDetailsID]       NVARCHAR (400)  NULL,
    [linkMethod]                 NVARCHAR (50)   NOT NULL,
    [linkNote]                   NVARCHAR (1000) NULL,
    [changedBy]                  NVARCHAR (100)  NULL,
    [changedDate]                DATETIME        CONSTRAINT [DF_BuildingPaymentLinkAudit_ChangedDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_BuildingPaymentLinkAudit] PRIMARY KEY CLUSTERED ([buildingPaymentLinkAuditID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_BuildingPaymentLinkAudit_Payment]
    ON [Housing].[BuildingPaymentLinkAudit]([paymentID_FK] ASC, [changedDate] ASC);


GO

