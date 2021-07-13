USE [master]
GO

/****** Object:  StoredProcedure [dbo].[Gevas_Wartung_DBAusBackupWiederherstellen]    Script Date: 13.07.2021 10:57:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ===============================================================================================================
-- Author:		Anton Maucher
-- Create date: 2019-05-29
-- Description:	Restores a database from a backup (inkl. Log)
-- Parameters:	
--				- @DBName : Database Name
--				- @BKFolder : Folder where the Backups are stored
-- Example:	
--    exec [Backuphelper_RestoreBackup] 'Database','\\server\Backup\Database\'

-- ===============================================================================================================
CREATE PROCEDURE [dbo].[Backuphelper_RestoreBackup]
	@DBName varchar(255)
	,
	@BKFolder varchar(255)

AS
	BEGIN

		SET NOCOUNT ON;

		-- Define your target folder for the restored files:
		DECLARE @Target varchar(255) = 'D:\DB\'

		,@FileName   varChar(255)
		,@cmdText    varChar(255)
		,@DataName   varchar(255)
		,@LogName    varchar(255)
		,@FullBackup bit = 0
		DECLARE @DirTree TABLE
			(
				subdirectory nvarchar(255)
			  , depth        INT
			)
			set @FileName = null
			set @cmdText  = null
			if not exists
			(
				select *
				from
					sys.databases
				where
					name = @DBName
			)
			BEGIN
				INSERT INTO @DirTree
					(subdirectory
					  , depth
					)
					exec ('EXEC master.sys.xp_dirtree ''' + @Target + @DBName + '\''')
					IF NOT EXISTS
					(
						SELECT
							1
						FROM
							@DirTree
						WHERE
							subdirectory = @DBName
					)
					exec ('EXEC master.dbo.xp_create_subdir ''' + @Target  + @DBName + '\''')
					
					
					DELETE
					FROM
						@DirTree
					exec ('create database [' + @DBName +'] ON PRIMARY
	(NAME = N'''+@DBName+''', FILENAME =  N''' + @Target + @DBName + '\' + @DBName + '.mdf'')
	LOG ON
	(NAME = N'''+@DBName+'_log'', FILENAME =  N''' + @Target + @DBName + '\' + @DBName + '_log.ldf'')
	')
					
				END
				select top 1
					@DataName = name
				FROM
					sys.master_files
				WHERE
					database_id = DB_ID(@DBName)
					and type    = 0
				select top 1
					@LogName = name
				FROM
					sys.master_files
				WHERE
					database_id = DB_ID(@DBName)
					and type    = 1
				create table #FileList
					(
						FileName  varchar(255)
					  , DepthFlag int
					  , FileFlag  int
					)
				insert into #FileList
				exec xp_dirtree @BKFolder
					,0
					,1
alter table #FileList
ADD 
    date varchar(8) ,
    time varchar(6);

update #FileList set date = substring(FileName,patindex('%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][_]%',FileName),8) where patindex('%[_][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][_]%',FileName) > 0
update #FileList set time = substring(FileName,patindex('%[0-9][0-9][0-9][0-9][0-9][0-9].___%',FileName),6) where patindex('%[_][0-9][0-9][0-9][0-9][0-9][0-9].___%',FileName) > 0

delete from #FileList where FileName like '%LOG%' and exists (select * from #FileList flinner where (flinner.FileName like '%DIFF%' or flinner.FileName like '%FULL%') and (flinner.date > #FileList.date or (flinner.date = #FileList.date and flinner.time >= #FileList.time)))



				exec('
ALTER DATABASE [' + @DBName + ']
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;')
				
				DECLARE backup_cursor CURSOR FOR
				select
					@BKFolder +
					case
						when FileName like '%DIFF%'
							then '\DIFF\'
							else case when FileName like '%LOG%'
							then '\LOG\'
							else '\FULL\'
							end
					END + FileName
					
				from
					#FileList
				where
					Filename like '%.bak' or Filename like '%.trn'
				order by
					--replace(replace(filename,'DIFF',''),'FULL','') asc
					date,time asc
				OPEN backup_cursor
				FETCH NEXT
				FROM
					backup_cursor
				INTO
					@filename
				WHILE @@FETCH_STATUS = 0
				BEGIN
					if @filename like '%FULL%'
					begin
						set @FullBackup = 1
					end
					
					if @FullBackup = 1 
					begin
						exec('
RESTORE DATABASE [' + @DBName + '] FROM  DISK = ''' + @filename + '''
WITH  MOVE N''' + @DataName + ''' TO N''' + @Target + @DBName + '\' + @DBName + '.mdf'', MOVE N''' + @LogName + ''' TO N''' + @Target + @DBName + '\' + @DBName + '_log.ldf'', NORECOVERY,  NOUNLOAD,  REPLACE,  STATS = 10')
						
					end



					FETCH NEXT
					FROM
						backup_cursor
					INTO
						@filename
				END
				CLOSE backup_cursor
				DEALLOCATE backup_cursor
				exec('
RESTORE DATABASE [' + @DBName + ']
WITH RECOVERY;
')
				
				DBCC SHRINKDATABASE (@DBName, 10)
				
				exec ('
ALTER DATABASE [' + @DBName + ']
SET RECOVERY SIMPLE;')
				
				exec ('
ALTER DATABASE [' + @DBName + ']
SET MULTI_USER WITH ROLLBACK IMMEDIATE;')
				
				drop table #FileList
				
			END
GO


