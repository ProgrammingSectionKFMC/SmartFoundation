SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    خط الجهة لتذكرة في جهة معينة (@DSDID):
      - الجهة نفسها والجهات التابعة لها (فروعها وشُعبها)
      - والجهات الأعلى منها مباشرة في نفس الخط (فرعها ثم قسمها)، دون الفروع الشقيقة.

    مثال: فرع الشبكات ← فرع الشبكات + شُعبه + قسم الحاسب الآلي نفسه، وليس فرع البرمجة.

    يُستخدم في موضعين يجب أن يتطابقا:
      - قائمة الموظفين في نماذج الإسناد (Tickets.TicketListDL، الجدول [11])
      - فحص أهلية المستلم ونطاق المنفّذ في Tickets.TicketSP
    عضوية الموظف في جهة = UserDistributor -> Distributor.DSDID_FK.
*/
CREATE FUNCTION [Tickets].[ft_UnitLine]
(
    @DSDID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT x.[DSDID]
    FROM dbo.[DeptSecDiv] u
    INNER JOIN dbo.[DeptSecDiv] x
        ON x.[idaraID_FK] = u.[idaraID_FK]
       AND x.[deptID_FK] = u.[deptID_FK]
    WHERE u.[DSDID] = @DSDID
      AND (
            -- الجهة نفسها وما تحتها
            (    (u.[secID_FK] IS NULL OR x.[secID_FK] = u.[secID_FK])
             AND (u.[divID_FK] IS NULL OR x.[divID_FK] = u.[divID_FK]))
            -- القسم الذي تتبعه
         OR (x.[secID_FK] IS NULL AND x.[divID_FK] IS NULL)
            -- الفرع الذي تتبعه الشعبة
         OR (u.[divID_FK] IS NOT NULL AND x.[secID_FK] = u.[secID_FK] AND x.[divID_FK] IS NULL)
      )
);
GO
