# DBCOPY-AZ2S3
Powershell 7 script that restores an Azure SQL database to a specified point-in-time backup, exports the restored database to the local machine, sends the .bacpac file to an Amazon S3 bucket, and moves the file to a folder. The program executes successfully via Windows Task Scheduler.

This script is built for automation, can be used with the task schedular to run at certain times on certain days in a predetermined schedule and can also be run manually.
