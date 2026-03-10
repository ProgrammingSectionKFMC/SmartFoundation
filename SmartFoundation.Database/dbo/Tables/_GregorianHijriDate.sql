CREATE TABLE [dbo].[_GregorianHijriDate] (
    [gregorianDate]          DATETIME      NULL,
    [hijriDateddmmyyyy]      NVARCHAR (10) NULL,
    [hijriDateyyyymmdd]      NVARCHAR (10) NULL,
    [hijriDateddmmyyyy_]     NVARCHAR (10) NULL,
    [hijriDateyyyymmdd_]     NVARCHAR (10) NULL,
    [dayOfWeekE]             NVARCHAR (10) NULL,
    [dayOfWeekA]             NVARCHAR (10) NULL,
    [theTime]                NVARCHAR (10) NULL,
    [dayH]                   INT           NULL,
    [monthH]                 INT           NULL,
    [yearH]                  INT           NULL,
    [dayH_char]              NVARCHAR (2)  NULL,
    [monthH_char]            NVARCHAR (2)  NULL,
    [yearH_char]             NVARCHAR (4)  NULL,
    [SQLServerGregorianDate] DATETIME      NULL
);

