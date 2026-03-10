CREATE PROCEDURE [dbo].[sp_AiChat_SaveHistory]
    @UserId INT = NULL,
    @UserQuestion NVARCHAR(MAX),
    @AiAnswer NVARCHAR(MAX),
    @PageKey NVARCHAR(100) = NULL,
    @PageTitle NVARCHAR(200) = NULL,
    @PageUrl NVARCHAR(500) = NULL,
    @EntityKey NVARCHAR(100) = NULL,
    @Intent NVARCHAR(50) = NULL,
    @ResponseTimeMs INT = NULL,
    @CitationsCount INT = NULL,
    @IpAddress NVARCHAR(50) = NULL,
    @idaraID NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @StartedTran BIT = 0;
    DECLARE @NewID BIGINT = NULL;

    BEGIN TRY
        -- (اختياري) تحقق أعمال بسيط
  
        -- Transaction-safe
        IF @tc = 0
        BEGIN
            BEGIN TRAN;
            SET @StartedTran = 1;
        END

        INSERT INTO dbo.AiChatHistory
        (
            UserId, UserQuestion, AiAnswer, PageKey, PageTitle, PageUrl,
            EntityKey, Intent, ResponseTimeMs, CitationsCount, IpAddress,IdaraID
        )
        VALUES
        (
            @UserId, @UserQuestion, @AiAnswer, @PageKey, @PageTitle, @PageUrl,
            @EntityKey, @Intent, @ResponseTimeMs, @CitationsCount, @IpAddress,@idaraID
        );

        SET @NewID = CAST(SCOPE_IDENTITY() AS BIGINT);


          BEGIN TRY
            EXEC dbo.sp_AiChat_UpdateFrequentQuestions @ChatId = @NewID;
        END TRY
        BEGIN CATCH
            -- لا نوقف حفظ المحادثة إذا فشل تحديث الأسئلة الشائعة
            -- (اختياري) سجل الخطأ في جدول ErrorLog عندك
        END CATCH


        IF @StartedTran = 1
            COMMIT;

        SELECT
            1 AS IsSuccessful,
            N'تم اضافة البيانات بنجاح' AS Message_,
            @NewID AS ChatId;
    END TRY
    BEGIN CATCH
        IF @StartedTran = 1 AND XACT_STATE() <> 0
            ROLLBACK;

        ;THROW;
    END CATCH
END
