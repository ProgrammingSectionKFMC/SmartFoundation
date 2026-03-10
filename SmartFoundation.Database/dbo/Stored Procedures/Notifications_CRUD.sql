CREATE PROCEDURE [dbo].[Notifications_CRUD]
    @UserID NVARCHAR(50),
    @Type NVARCHAR(20) = NULL,
    @UserNotificationId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get notification details
    IF @Type = 'Body'
    BEGIN
        SELECT 
            un.UserNotificationId,
            un.NotificationId_FK,
            n.Title,
            n.Body,
            n.Url_,
            un.DeliveredUtc,
            un.IsClicked,
            un.IsRead,
            un.ReadUtc,
            un.ClickUtc
        FROM 
             dbo.UserNotifications un
            INNER JOIN  dbo.Notifications n 
                ON un.NotificationId_FK = n.NotificationId
        WHERE 
            un.UserId_FK = @UserID 
            AND un.IsClicked = 0 
            AND un.ClickUtc IS NULL
        ORDER BY 
            un.DeliveredUtc DESC;
    END
    
    -- Get notification count (unread only)
    ELSE IF @Type = 'Count'
    BEGIN
        SELECT COUNT(*) AS NotificationCount
        FROM  dbo.UserNotifications
        WHERE UserId_FK = @UserID 
          AND IsRead = 0
          AND ReadUtc IS NULL;
    END
    
    -- Mark single notification as clicked
    ELSE IF @Type = 'MarkClicked'
    BEGIN
        UPDATE  dbo.UserNotifications
        SET 
            IsClicked = 1,
            ClickUtc = GETUTCDATE(),
            IsRead = 1,
            ReadUtc = ISNULL(ReadUtc, GETUTCDATE())
        WHERE 
            UserNotificationId = @UserNotificationId
            AND UserId_FK = @UserID;
            
        SELECT @@ROWCOUNT AS RowsAffected;
    END
    
    -- ✅ NEW: Mark single notification as read (on hover)
    ELSE IF @Type = 'MarkRead'
    BEGIN
        UPDATE  dbo.UserNotifications
        SET 
            IsRead = 1,
            ReadUtc = GETUTCDATE()
        WHERE 
            UserNotificationId = @UserNotificationId
            AND UserId_FK = @UserID
            AND IsRead = 0;  -- Only if not already read
            
        SELECT @@ROWCOUNT AS RowsAffected;
    END
    
    -- Mark all notifications as read
    ELSE IF @Type = 'MarkAllRead'
    BEGIN
        UPDATE  dbo.UserNotifications
        SET 
            IsRead = 1,
            ReadUtc = GETUTCDATE()
        WHERE 
            UserId_FK = @UserID
            AND IsRead = 0
            AND ReadUtc IS NULL;
            
        SELECT @@ROWCOUNT AS RowsAffected;
    END
    
    -- Mark all notifications as clicked
    ELSE IF @Type = 'MarkAllClicked'
    BEGIN
        UPDATE  dbo.UserNotifications
        SET 
            IsClicked = 1,
            ClickUtc = GETUTCDATE(),
            IsRead = 1,
            ReadUtc = ISNULL(ReadUtc, GETUTCDATE())
        WHERE 
            UserId_FK = @UserID
            AND IsClicked = 0
            AND ClickUtc IS NULL;
            
        SELECT @@ROWCOUNT AS RowsAffected;
    END
END
