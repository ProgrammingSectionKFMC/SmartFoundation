CREATE VIEW [dbo].[_VIEW_TSK_TasksInfo] AS 
	SELECT v.*  
		, CASE 
			WHEN v.subComponentName IS NOT NULL THEN v.subComponentName + ISNULL(' ('+v.stepTitle+')','') 
			WHEN v.taskStepID IS NOT NULL AND ISNULL(v.hideStepName,0) = 0  THEN v.stepTitle +' (' + v.parentComponentNameAll +')' 
			ELSE v.taskName 
		END theTask2
		, CASE 
			WHEN v.isSingleTask = 1 THEN v.parentComponentNameAll 
			WHEN v.subComponentNameAll IS NOT NULL THEN v.subComponentNameAll  
			WHEN v.taskStepID IS NOT NULL AND ISNULL(v.hideStepName,0) = 0  THEN v.stepTitle +' (' + v.parentComponentNameAll +')' 
			ELSE v.taskName 
		END theTask 
		, CASE WHEN v.statusID IS NULL THEN 1 ELSE  tl.isUnderprocess END   isUnderprocess
		, tl.isFinished 
		, tl.isCanceled 
		, tl.isNew 
		, tl.isSuccessful 
		, tl.isDelay 

	FROM ( 
		SELECT t.taskID , t.taskName 
			, CASE WHEN tc.isSingleTask = 1 THEN '' 
				ELSE 
					ISNULL
					(
						( SELECT t_.componentName FROM TSK_Task t_  WHERE t.parentID_FK = t_.taskID )
						, (SELECT t_.componentName FROM TSK_Task t_ INNER JOIN TSK_Task tt ON tt.parentID_FK = t_.taskID  WHERE t.parentID_FK = tt.taskID ) 
					) 
				END 
			parentComponentName  
			, ISNULL
				(
					( SELECT t_.componentName FROM TSK_Task t_  WHERE t.parentID_FK = t_.taskID )
					, (SELECT t_.componentName FROM TSK_Task t_ INNER JOIN TSK_Task tt ON tt.parentID_FK = t_.taskID  WHERE t.parentID_FK = tt.taskID ) 
				) parentComponentNameAll
			, t.description , CASE WHEN t.description IS NULL THEN 0 ELSE 1 END hasDescription
			, t.weightMinutes enteredWeightMinutes
			, CASE WHEN  isOrganizer = 1 OR taskStepID IS NULL THEN 0 ELSE t.weightMinutes END weightMinutes  
			, dbo.minutesToHours(CASE WHEN  isOrganizer = 1 OR taskStepID IS NULL THEN 0 ELSE t.weightMinutes END ,'hh mm') durationText
			, t.parentID_FK taskParentID , t.initiatorID_FK , t.componentName 
			, tsc.title subComponentNameAll
			, CASE WHEN ISNULL(hideStepName,0) = 0 THEN tsc.title ELSE NULL END subComponentName
			, tsc.title subComponentTitle , t.subComponentID_FK
			, tp.taskProjectID , tp.taskProjectName , tp.taskProjectTitle 
			, ts.taskStepID , ts.stepName , ts.stepTitle , ts.isMultiRecord ,ts.hideStepName , ts.parentID_FK taskStepParentID 
			, tc.taskComponentID , tc.fieldName , tc.title taskComponentTitle , tc.parentID_FK taskComponentParentID 
			, ISNULL(( SELECT l.taskLabelID_FK FROM _VIEW_TSK_Task_TaskLabel l WHERE l.taskID_FK = t.taskID AND l.taskLabelTypeID = 1 ),1) statusID 
			, ( SELECT l.taskLabelID_FK FROM _VIEW_TSK_Task_TaskLabel l WHERE l.taskID_FK = t.taskID AND l.taskLabelTypeID = 2 ) urgentID
			, CASE WHEN ( SELECT COUNT(*) FROM TSK_TaskStep ts_ WHERE ts_.parentID_FK = t.taskStepID_FK ) > 0 THEN 1 ELSE 0 END isComplex
			, (
				SELECT taskLabelTypeID , taskLabelTypeName  , taskLabelID_FK currentLabel , vttl.labelColor , vttl.fontColor , vttl.class , vttl.borderColor , vttl.taskLabelName , vttl.note 
				FROM _VIEW_TSK_Task_TaskLabel vttl 
				WHERE vttl.taskID_FK = t.taskID 
				FOR JSON PATH , INCLUDE_NULL_VALUES 
			) labels  
			, ( SELECT TOP(1) tl_.note FROM TSK_Task_TaskLabel tl_ WHERE tl_.taskID_FK = t.taskID AND tl_.note IS NOT NULL ORDER BY tl_.TTLID DESC ) lastNote 
			, ts.isFiltered isTaskStepFiltered , ts.isDeletable 
			, ( SELECT TOP(1) tt.taskDurationID_FK FROM TSK_Task tt WHERE tt.taskDurationID_FK IS NOT NULL AND (tt.taskID = t.taskID OR tt.taskID = t.parentID_FK )  ) taskDurationID 
			, pt.taskID parentID_1 , ppt.taskID parentID_2
			, ts.isOrganizer 
			, t.attachmentBookID_FK 
			, CASE WHEN tsc.taskSubComponentID IS NOT NULL THEN 1 ELSE 0 END isSubComponent 
			, tc.isComponentUpdatable , tc.isSubComponentUpdatable , tc.isSingleTask 
			, DATEDIFF(DAY,t.initiationDateTime ,GETDATE() ) taskSince 
		FROM TSK_Task t 
			LEFT OUTER JOIN TSK_TaskStep ts ON t.taskStepID_FK = ts.taskStepID 		
			LEFT OUTER JOIN TSK_TaskComponent tc ON t.taskComponentID_FK = tc.taskComponentID  
			LEFT OUTER JOIN TSK_TaskSubComponent tsc ON t.subComponentID_FK = tsc.taskSubComponentID 
			LEFT OUTER JOIN TSK_Task pt ON t.parentID_FK = pt.taskID 
			LEFT OUTER JOIN TSK_Task ppt ON pt.parentID_FK = ppt.taskID 
			LEFT OUTER JOIN TSK_TaskProject tp ON t.taskProjectID_FK = tp.taskProjectID  
		WHERE t.isActive = 1 AND ISNULL(pt.isActive,1) = 1  AND ISNULL(ppt.isActive,1) = 1 -- SELECT * FROM TSK_TaskComponent 
	) v 
		LEFT OUTER JOIN TSK_TaskLabel tl ON tl.taskLabelID = v.statusID 


