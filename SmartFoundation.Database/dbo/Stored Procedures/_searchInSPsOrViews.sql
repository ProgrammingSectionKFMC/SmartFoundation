

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE   PROCEDURE [dbo].[_searchInSPsOrViews]  @textToSearch NVARCHAR(1000) , @isCaseInsenstive BIT = NULL 

AS 
	DECLARE @textToSearch_ NVARCHAR(1000)
	IF @isCaseInsenstive = 1 
		SET @textToSearch_ = LOWER(@textToSearch)
	ELSE 
		SET @textToSearch_ = @textToSearch
		PRINT @textToSearch_
	SELECT DISTINCT 
		   o.name AS Object_Name , o.type_desc
	  FROM sys.sql_modules m 
		   INNER JOIN  sys.objects o 
			 ON m.object_id = o.object_id
	 WHERE CASE WHEN @isCaseInsenstive = 1 THEN LOWER(m.definition) ELSE m.definition END Like '%'+@textToSearch_+'%' ESCAPE '\' 
