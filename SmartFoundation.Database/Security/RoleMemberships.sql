


GO
ALTER ROLE [db_owner] ADD MEMBER [NT AUTHORITY\NETWORK];


GO
ALTER ROLE [db_owner] ADD MEMBER [KFMCMODA\AppsAdmin];


GO
ALTER ROLE [db_owner] ADD MEMBER [KFMCMODA\Administrator];





GO
ALTER ROLE [db_datareader] ADD MEMBER [guest];


GO
ALTER ROLE [db_datareader] ADD MEMBER [BUILTIN\Users];


GO
ALTER ROLE [db_datareader] ADD MEMBER [NT AUTHORITY\NETWORK];


GO
ALTER ROLE [db_datawriter] ADD MEMBER [guest];


GO
ALTER ROLE [db_datawriter] ADD MEMBER [BUILTIN\Users];


GO
ALTER ROLE [db_datawriter] ADD MEMBER [NT AUTHORITY\NETWORK];

