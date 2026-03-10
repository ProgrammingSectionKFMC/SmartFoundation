
CREATE VIEW [dbo].[V_MVCProgramMenuTree] AS
WITH MenuHierarchy AS (
    -- المستوى 0: البرنامج نفسه
    SELECT
        p.programID,
        p.programName_A AS programName,
		p.programLink as programLink,
        CAST(NULL AS bigint) AS menuID,
        CAST(NULL AS NVARCHAR(100)) AS menuName_A,
        CAST(NULL AS INT) AS parentMenuID_FK,
        CAST(NULL AS NVARCHAR(1000)) AS menuLink,
        CAST(NULL AS INT) AS menuSerial,
        CAST(p.programName_A AS NVARCHAR(MAX)) AS fullPath,
        0 AS level
    FROM Program p

    UNION ALL

    -- المستويات 1 إلى 5: القوائم الرئيسية والفرعية
    SELECT
        mh.programID,
        mh.programName,
		null as programLink,
        m.menuID,
        m.menuName_A,
        m.parentMenuID_FK,
        m.menuLink,
        m.menuSerial,
        CAST(mh.fullPath + ' > ' + m.menuName_A AS NVARCHAR(MAX)) AS fullPath,
        mh.level + 1 AS level
    FROM MenuHierarchy mh
    INNER JOIN Menu m ON 
        (mh.level = 0 AND m.programID_FK = mh.programID AND m.parentMenuID_FK IS NULL) -- القوائم الرئيسية
        OR (mh.level > 0 AND m.parentMenuID_FK = mh.menuID) -- القوائم الفرعية
    WHERE mh.level < 5
)
SELECT
    mh.programID,
    mh.programName,
	mh.programLink,
    mh.menuID,
    mh.menuName_A,
    mh.parentMenuID_FK,
    mh.menuLink,
    mh.menuSerial,
    mh.fullPath,
    mh.level
FROM MenuHierarchy mh;

