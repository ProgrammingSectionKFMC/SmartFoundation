CREATE TABLE [Housing].[ExtendInsurance] (
    [ExtendInsuranceID]            BIGINT          IDENTITY (1, 1) NOT NULL,
    [buildingActionID_FK]          BIGINT          NULL,
    [InsuranceAmount]              DECIMAL (18, 2) NULL,
    [Remaining]                    DECIMAL (18, 2) NULL,
    [InsuranceAmountWithRemaining] DECIMAL (18, 2) NULL,
    [ExtendInsuranceNo]            NVARCHAR (200)  NULL,
    [ExtendInsuranceDate]          DATETIME        NULL,
    [ExtendInsuranceType]          INT             NULL,
    [ExtendInsuranceNote]          NVARCHAR (2000) NULL,
    [ExtendInsuranceActive]        BIT             NULL,
    [ExtendInsuranceApproved]      BIT             NULL,
    [ExtendInsuranceIncomeNo]      NVARCHAR (200)  NULL,
    [ExtendInsuranceIncomeDate]    DATETIME        NULL,
    [IdaraId_FK]                   BIGINT          NULL,
    [entryDate]                    DATETIME        CONSTRAINT [DF_ExtendInsurance_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                    NVARCHAR (20)   NULL,
    [hostName]                     NVARCHAR (200)  NULL,
    CONSTRAINT [PK_ExtendInsurance] PRIMARY KEY CLUSTERED ([ExtendInsuranceID] ASC)
);

