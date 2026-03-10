CREATE TABLE [Demo].[Demo_Pie3D_UnitDistribution] (
    [SegmentId]      INT            IDENTITY (1, 1) NOT NULL,
    [SegmentKey]     NVARCHAR (50)  NOT NULL,
    [SegmentLabel_A] NVARCHAR (200) NOT NULL,
    [SegmentValue]   INT            NOT NULL,
    [SegmentHref]    NVARCHAR (300) NULL,
    [SegmentHint]    NVARCHAR (300) NULL,
    [SortOrder]      INT            NOT NULL,
    [IsActive]       BIT            DEFAULT ((1)) NOT NULL,
    [IdaraId_FK]     INT            NULL,
    PRIMARY KEY CLUSTERED ([SegmentId] ASC)
);

