CREATE TABLE [Tickets].[ServiceSLAPolicy] (
    [serviceSLAPolicyID]                 BIGINT         IDENTITY (1, 1) NOT NULL,
    [idaraID_FK]                         INT            NOT NULL,
    [serviceID_FK]                       BIGINT         NOT NULL,
    [priorityID_FK]                      INT            NOT NULL,
    [firstResponseTargetMinutes]         INT            NULL,
    [assignmentTargetMinutes]            INT            NULL,
    [operationalCompletionTargetMinutes] INT            NULL,
    [finalClosureTargetMinutes]          INT            NULL,
    [effectiveFrom]                      DATETIME       NULL,
    [effectiveTo]                        DATETIME       NULL,
    [slaPolicyActive]                    BIT            NULL,
    [entryDate]                          DATETIME       CONSTRAINT [DF_Tickets_ServiceSLAPolicy_entryDate] DEFAULT (getdate()) NULL,
    [entryData]                          NVARCHAR (20)  NULL,
    [hostName]                           NVARCHAR (200) NULL,
    CONSTRAINT [PK_Tickets_ServiceSLAPolicy] PRIMARY KEY CLUSTERED ([serviceSLAPolicyID] ASC)
);


GO

