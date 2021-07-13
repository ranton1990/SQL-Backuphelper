# SQL-BackupHelper
Procedure that makes it easy to automatically restore Backups on SQL-Server.

This Procedure is meant to be used to for example transfer databases efficiently from one server to another without having to disconnect and copy any databases. The databases are created from backup files. The procedure expects the backup files to be in a format like this:
* \Backup\
* * \Backup\Database
* * * \Backup\Database\FULL
* * * \Backup\Database\DIFF
* * * \Backup\Database\LOG

This is also the structure you would get from Ola Hallengrens backup scripts.

Run this script on the receiving server.
