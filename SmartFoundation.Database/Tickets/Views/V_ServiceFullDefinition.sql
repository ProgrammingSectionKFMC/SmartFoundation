CREATE VIEW [Tickets].[V_ServiceFullDefinition]
AS
SELECT
      s.[serviceID]
    , s.[serviceCode]
    , s.[serviceName_A]
    , s.[serviceName_E]
    , s.[serviceDesc]
    , s.[idaraID_FK]
    , s.[ticketClassID_FK]
    , tc.[ticketClassCode]
    , tc.[ticketClassName_A]  AS [ticketClassName_A]
    , tc.[ticketClassName_E]  AS [ticketClassName_E]
    , s.[defaultPriorityID_FK]
    , p.[priorityCode]
    , p.[priorityName_A]      AS [priorityName_A]
    , p.[priorityName_E]      AS [priorityName_E]
    , s.[requiresLocation]
    , s.[allowsChildTickets]
    , s.[requiresQualityReview]
    , s.[serviceActive]
    , rr.[serviceRoutingRuleID]   AS [activeRoutingRuleID]
    , rr.[targetDSDID_FK]         AS [activeTargetDSDID]
    , rr.[effectiveFrom]           AS [routingEffectiveFrom]
    , sp.[serviceSLAPolicyID]     AS [slaPolicyID]
    , sp.[priorityID_FK]          AS [slaPriorityID_FK]
    , sp.[firstResponseTargetMinutes]
    , sp.[assignmentTargetMinutes]
    , sp.[operationalCompletionTargetMinutes]
    , sp.[finalClosureTargetMinutes]
FROM [Tickets].[Service] s
LEFT JOIN [Tickets].[TicketClass] tc ON s.[ticketClassID_FK] = tc.[ticketClassID]
LEFT JOIN [Tickets].[Priority] p ON s.[defaultPriorityID_FK] = p.[priorityID]
LEFT JOIN [Tickets].[ServiceRoutingRule] rr
    ON s.[serviceID] = rr.[serviceID_FK]
    AND rr.[serviceRoutingRuleActive] = 1
    AND rr.[effectiveFrom] <= GETDATE()
    AND (rr.[effectiveTo] IS NULL OR rr.[effectiveTo] > GETDATE())
LEFT JOIN [Tickets].[ServiceSLAPolicy] sp
    ON s.[serviceID] = sp.[serviceID_FK]
    AND sp.[slaPolicyActive] = 1
    AND sp.[priorityID_FK] = s.[defaultPriorityID_FK]
WHERE s.[serviceActive] = 1;
