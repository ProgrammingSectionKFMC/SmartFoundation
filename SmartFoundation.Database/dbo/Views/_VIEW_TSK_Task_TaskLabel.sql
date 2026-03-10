CREATE VIEW [dbo].[_VIEW_TSK_Task_TaskLabel] AS 
	SELECT * 
	FROM ( 
		SELECT TTLID , taskID_FK 
			, tss.stepName   , CASE WHEN ( SELECT COUNT(*) FROM TSK_TaskStep ts_ WHERE ts_.parentID_FK = tt.taskStepID_FK ) > 0 THEN 1 ELSE 0 END isComplex
			, ttl.taskLabelID_FK , tl.taskLabelName , tl.labelColor , tl.fontColor , tl.borderColor , tl.class , tlt.taskLabelTypeID , tlt.taskLabelTypeName 
			, ttl.note , tt.parentID_FK 
			, ( 
				SELECT MAX(ttl_.TTLID) 
				FROM TSK_Task_TaskLabel ttl_ 
					INNER JOIN TSK_TaskLabel tl_ ON ttl_.taskLabelID_FK = tl_.taskLabelID 
				WHERE ttl_.taskID_FK = ttl.taskID_FK AND tl_.taskLabelTypeID_FK = tl.taskLabelTypeID_FK  
			) latest_TTLID  
		FROM TSK_Task_TaskLabel ttl 
			INNER JOIN TSK_Task tt ON ttl.taskID_FK = tt.taskID 
			LEFT OUTER JOIN TSK_TaskStep tss ON tss.taskStepID = tt.taskStepID_FK 
			INNER JOIN TSK_TaskLabel tl ON ttl.taskLabelID_FK = tl.taskLabelID 
			INNER JOIN TSK_TaskLabelType tlt ON tlt.taskLabelTypeID = tl.taskLabelTypeID_FK 
		WHERE tt.isActive = 1 
	) abc 
	WHERE TTLID = latest_TTLID  
