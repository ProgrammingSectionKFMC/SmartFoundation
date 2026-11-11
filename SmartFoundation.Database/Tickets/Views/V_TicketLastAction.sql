CREATE VIEW [Tickets].[V_TicketLastAction]
AS
SELECT
      th.[ticketID_FK]       AS [ticketID]
    , th.[ticketHistoryID]
    , th.[actionTypeCode]
    , th.[oldStatusID_FK]
    , th.[newStatusID_FK]
    , th.[oldDSDID_FK]
    , th.[newDSDID_FK]
    , th.[oldAssignedUserID]
    , th.[newAssignedUserID]
    , th.[performerUserID]
    , th.[notes]
    , th.[actionDate]
    , os.[ticketStatusCode]  AS [oldStatusCode]
    , os.[ticketStatusName_E] AS [oldStatusName_E]
    , ns.[ticketStatusCode]  AS [newStatusCode]
    , ns.[ticketStatusName_E] AS [newStatusName_E]
FROM [Tickets].[TicketHistory] th
INNER JOIN [Tickets].[TicketStatus] ns
    ON th.[newStatusID_FK] = ns.[ticketStatusID]
LEFT JOIN [Tickets].[TicketStatus] os
    ON th.[oldStatusID_FK] = os.[ticketStatusID]
WHERE th.[ticketHistoryID] = (
    SELECT MAX(th2.[ticketHistoryID])
    FROM [Tickets].[TicketHistory] th2
    WHERE th2.[ticketID_FK] = th.[ticketID_FK]
);
