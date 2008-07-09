/****** Object:  StoredProcedure [dbo].[usp_del_ServerRole]    Script Date: 07/09/2008 12:08:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_del_ServerRole]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_del_ServerRole]
@histSize int = 3
AS
WITH nthlargest
AS
(
SELECT  timestamp,RANK() OVER (ORDER BY timestamp DESC) AS ''nth''
FROM dbo.ServerRole
GROUP BY timestamp
)
DELETE dbo.ServerRole WHERE timestamp <= 
(SELECT timestamp FROM nthlargest WHERE nth = @histSize);

' 
END
GO
