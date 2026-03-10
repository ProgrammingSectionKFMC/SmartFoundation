CREATE VIEW dbo.V_MenuTree
AS
WITH MenuTree AS
(
    /* =============================
       📌 المستوى الأول = Program → Menu
       ============================= */
    SELECT
        p.programID,
        p.programName_A,
        p.programName_E,
        p.programIcon,
        p.programLink,
        p.programSerial,

        m.menuID,
        m.menuName_A,
        m.menuName_E,
        m.menuDescription,
        m.menuLink,
        m.parentMenuID_FK,
        m.programID_FK,
        m.menuSerial,
        m.menuActive,
        m.isDashboard,

        CAST(1 AS int) AS LevelNo,   -- Level 1 below program

        CAST(m.menuName_A AS nvarchar(2000)) AS PathName_A,
        CAST(m.menuName_E AS nvarchar(2000)) AS PathName_E,

        CAST(
            RIGHT('0000' + CAST(ISNULL(p.programSerial, p.programID) AS varchar(4)), 4)
            + '.' +
            RIGHT('0000' + CAST(ISNULL(m.menuSerial, m.menuID) AS varchar(4)), 4)
            AS varchar(500)
        ) AS SortKey
    FROM Program p
    INNER JOIN Menu m
        ON m.programID_FK = p.programID   -- مرتبط بالبرنامج مباشرة
    WHERE 
        p.programActive = 1
        AND m.menuActive = 1
        AND m.parentMenuID_FK IS NULL     -- مستوى أول فقط


    UNION ALL


    /* =============================
       📌 المستويات التالية = Sub Menus
       ============================= */
    SELECT
        t.programID,
        t.programName_A,
        t.programName_E,
        t.programIcon,
        t.programLink,
        t.programSerial,

        m.menuID,
        m.menuName_A,
        m.menuName_E,
        m.menuDescription,
        m.menuLink,
        m.parentMenuID_FK,
        m.programID_FK,
        m.menuSerial,
        m.menuActive,
        m.isDashboard,

        t.LevelNo + 1 AS LevelNo,

        CAST(t.PathName_A + N' > ' + m.menuName_A AS nvarchar(2000)) AS PathName_A,
        CAST(t.PathName_E + N' > ' + m.menuName_E AS nvarchar(2000)) AS PathName_E,

        CAST(
            t.SortKey + '.' +
            RIGHT('0000' + CAST(ISNULL(m.menuSerial, m.menuID) AS varchar(4)), 4)
            AS varchar(500)
        ) AS SortKey
    FROM Menu m
    INNER JOIN MenuTree t
        ON m.parentMenuID_FK = t.menuID   -- ابن للمنيو السابق
    WHERE 
        m.menuActive = 1
        AND t.LevelNo < 50   -- حماية فقط
)
SELECT *
FROM MenuTree;

