CREATE VIEW [dbo].[_VIEW_TSK_UsersTasksAndFinishedBy] AS 
		SELECT * 
			, CASE WHEN finishedBy = userID THEN 1 ELSE 0 END finishedByThisUser 
		FROM ( 
			SELECT taskID , vt.statusID , tl.taskLabelName statusName  , vt.isSuccessful , vt.isCanceled , vt.isDelay , vt.isNew , vt.isUnderprocess  , te.userID_FK userID  
				, weightMinutes 
				, CASE WHEN  vt.isSuccessful = 1
					THEN ( SELECT TOP(1) byUserID_FK FROM TSK_Task_TaskLabel ttl WHERE ttl.taskID_FK = vt.taskID ) 
					ELSE NULL END finishedBy  
			FROM _VIEW_TSK_TasksInfo vt
				LEFT OUTER JOIN TSK_Task_Employee te 
					ON (
							te.taskID_FK IN ( vt.taskID , vt.parentID_1  , vt.parentID_2 ) AND te.taskStepID_FK = vt.taskStepID)
								OR (te.taskID_FK IN ( vt.taskID , vt.parentID_1 , vt.parentID_2 ) AND te.taskStepID_FK IS NULL 
						) 
				LEFT OUTER JOIN TSK_TaskLabel tl ON tl.taskLabelID = vt.statusID 
			 WHERE vt.parentID_1 IS NOT NULL AND isComplex = 0   
		) v 