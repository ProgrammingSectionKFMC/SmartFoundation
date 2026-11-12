
CREATE   VIEW [Maintenance].[V_BuildingMaintenanceRequestDocuments]
AS
SELECT
    request.[RequestID],
    request.[TransactionID_FK],
    document.[documentID] AS [DocumentID],
    document.[documentTitle] AS [DocumentTitle],
    document.[documentTypeID_FK] AS [DocumentTypeID_FK],
    document.[documentStateID_FK] AS [DocumentStateID_FK],
    attachment.[attachmentID] AS [AttachmentID],
    attachment.[attachmentName] AS [AttachmentName],
    attachment.[attachmentPath] AS [AttachmentPath],
    attachment.[attachmentExtintion] AS [AttachmentExtintion],
    attachment.[attachmentSize] AS [AttachmentSize],
    document.[documentDate] AS [DocumentDate],
    document.[documentDescription] AS [DocumentDescription]
FROM [Maintenance].[BuildingMaintenanceRequest] AS request
INNER JOIN [dbo].[Document] AS document
    ON document.[transactionID_FK] = request.[TransactionID_FK]
LEFT JOIN [dbo].[Attachment] AS attachment
    ON attachment.[DocumentID_FK] = document.[documentID]
    AND attachment.[transactionID_FK] = document.[transactionID_FK];

GO

